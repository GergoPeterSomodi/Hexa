"""Fuzz the files the game reads back: settings.json and the save files in the saves folder.

Each case damages or distorts a valid file in a seeded random way (truncation, flipped bytes, wrong JSON types at
every key, non-object JSON, empty and binary files, NaN and huge numbers, a good header followed by garbage or a
well-formed pickle of the wrong shape) and calls the public entry points. They must either succeed or fail the
documented way: "treated as missing" (defaults, None, an empty slot) or "refused" (``saves.load`` gives None).
Anything else, an exception that escapes, fails the test.

    HEXA_FUZZ_CASES=2000                                  more cases per test (default 300)
    HEXA_FUZZ_SEED=123 HEXA_FUZZ_CASES=1 python3 -m unittest tests.test_fuzz_files
                                                          replay one case: case N uses seed BASE+N, and a failure
                                                          prints the seed (and this command) to use

Every crash fails loudly, with its seed: no crash class is excused any more.

Needs no pygame. Everything happens in a temporary HEXA_HOME.
"""
import contextlib
import io
import json
import os
import pickle
import random
import shutil
import sys
import tempfile
import time
import traceback
import unittest
from unittest import mock

from hexa import settings
from hexa.campaign import saves
from hexa.campaign.world import CampaignWorld
from tests.support.home import TempHome
from tests.support.worlds import fresh

CASES = int(os.environ.get("HEXA_FUZZ_CASES", "300"))
BASE_SEED = int(os.environ.get("HEXA_FUZZ_SEED", "20260101"))
SHOWN = 8                                  # failures listed in the message
DEEP = 1000000                             # nesting that overflows json on every Python version we support

# ----- generating values -------------------------------------------------------------------------------------

def rand_scalar(rng):
    kind = rng.randrange(9)
    if kind == 0:
        return None
    if kind == 1:
        return rng.choice((True, False))
    if kind == 2:
        return rng.choice((0, 1, -1, 2, 7, 2 ** 31, 2 ** 63, 2 ** 70, 10 ** 30, rng.randrange(-10 ** 6, 10 ** 6)))
    if kind == 3:
        return rng.choice((0.0, 1.0, -0.5, 1e308, 1e-320, 1e30, float("nan"), float("inf"), float("-inf"),
                           rng.random() * 1e12))
    if kind == 4:
        return rng.choice(("", " ", "x", "true", "null", "1280x720", "1280x720\n", "yes", "é中\U0001f600",
                           "\x00", "\ud800", "a" * rng.choice((10, 1000, 100000)), "-1", "NaN"))
    if kind == 5:
        return rng.choice(settings.WINDOWS + settings.AUTOSAVE + tuple(settings.SCROLL))
    if kind == 6:
        return time.time() + rng.choice((0, 1, -1, 86400 * 365, -86400 * 365 * 100))
    if kind == 7:
        return rng.choice(("Spring 1480", "Europe 1480", "Portugal", "POR", "Random world #9"))
    return rng.randrange(0, 4000)


def rand_value(rng, depth=0):
    """Any JSON-able value: scalars mostly, lists and objects with real keys, nested a little."""
    kind = rng.randrange(10)
    if depth < 3 and kind == 0:
        return [rand_value(rng, depth + 1) for _ in range(rng.randrange(4))]
    if depth < 3 and kind == 1:
        keys = list(settings.DEFAULTS) + ["version", "saved", "x"]
        return {rng.choice(keys): rand_value(rng, depth + 1) for _ in range(rng.randrange(4))}
    return rand_scalar(rng)


def dumps(value):
    return json.dumps(value).encode("utf-8")          # allow_nan: NaN and Infinity come out as JS literals



def flip_bytes(rng, data, count):
    data = bytearray(data)
    for _ in range(count if data else 0):
        data[rng.randrange(len(data))] ^= 1 << rng.randrange(8)
    return bytes(data)


def mangle(rng, data):
    """Damage raw bytes: cut them short, flip bits, add junk, replace them with noise, or do nothing."""
    kind = rng.randrange(7)
    if kind == 0:
        return data[:rng.randrange(len(data) + 1)]
    if kind == 1:
        return flip_bytes(rng, data, rng.randrange(1, 6))
    if kind == 2:
        return data + bytes(rng.randrange(256) for _ in range(rng.randrange(1, 40)))
    if kind == 3:
        return bytes(rng.randrange(256) for _ in range(rng.choice((0, 1, 5, 200, 5000))))
    if kind == 4:
        return b""
    if kind == 5:
        return data.replace(b'"', b"'", 1)
    return data[rng.randrange(len(data) + 1):]


# ----- settings.json -----------------------------------------------------------------------------------------

def legal_choice(key, value):
    """The choice this stored value stands for, or None. A number equal to a boolean choice (0, 1, 0.0, 1.0)
    stands for that bool; everything else must be a choice of its own type."""
    for c in settings.CHOICES[key]:
        if isinstance(c, bool):
            if type(value) in (bool, int, float) and value == c:
                return c
        elif type(value) is type(c) and value == c:
            return c
    return None


def settings_file(rng):
    """(name, bytes) of a damaged settings.json."""
    good = {"fullscreen": rng.choice((True, False)), "window": rng.choice(settings.WINDOWS),
            "autosave": rng.choice(settings.AUTOSAVE), "scroll": rng.choice(tuple(settings.SCROLL))}
    text = json.dumps(good, indent=rng.choice((None, 2))).encode()
    kind = rng.randrange(12)
    if kind == 0:
        return "valid", text
    if kind == 1:
        key = rng.choice(list(good))
        return f"wrong value at {key}", dumps(dict(good, **{key: rand_value(rng)}))
    if kind == 2:
        return "wrong values everywhere", dumps({k: rand_value(rng) for k in good})
    if kind == 3:
        return "unknown keys", dumps(dict(good, **{rng.choice(("volume", "", "Scroll", "__class__", "a" * 50)):
                                                  rand_value(rng) for _ in range(3)}))
    if kind == 4:
        return "not an object", dumps(rand_value(rng))
    if kind == 5:
        return "truncated", text[:rng.randrange(len(text) + 1)]
    if kind == 6:
        return "flipped bytes", flip_bytes(rng, text, rng.randrange(1, 6))
    if kind == 7:
        return "binary garbage", bytes(rng.randrange(256) for _ in range(rng.choice((0, 1, 7, 300, 4000))))
    if kind == 8:
        return "mangled", mangle(rng, text)
    if kind == 9:
        return "huge or odd numbers", dumps({k: rng.choice((2 ** 70, 10 ** 30, float("nan"),
                                                           float("inf"), -0.0, 1e-320)) for k in good})
    if kind == 10:
        return "oversize", dumps({"window": "1" * 2000000, "scroll": ["x"] * 200000})
    return rng.choice((("deeply nested array", b"[" * DEEP), ("deeply nested objects", b'{"a":' * DEEP),
                       ("nested value", b'{"scroll": ' + b"[" * 3000 + b"]" * 3000 + b"}"),
                       ("object in a list", b"[" + text + b"]")))


def oracle_settings(raw):
    """(what load() must return for these bytes, the stored object or None), worked out without calling load()."""
    try:
        stored = json.loads(raw.decode("utf-8"))
    except (ValueError, RecursionError):
        return dict(settings.DEFAULTS), None
    if not isinstance(stored, dict):
        return dict(settings.DEFAULTS), None
    want = {}
    for key, default in settings.DEFAULTS.items():
        choice = legal_choice(key, stored[key]) if key in stored else None
        want[key] = default if choice is None else choice
    return want, stored


class Crash(Exception):
    """A call raised: ``site`` is the entry point, ``error`` what it raised."""

    def __init__(self, site, error):
        super().__init__(f"{site} raised {type(error).__name__}: {str(error)[:120]}")
        self.site, self.error = site, error


def call(site, function, *args):
    try:
        return function(*args)
    except Exception as error:                  # noqa: BLE001 - the whole point is to see every kind
        raise Crash(site, error) from error


def describe_failure(seed, name, error, test):
    last = ""
    tb = error.__cause__.__traceback__ if isinstance(error, Crash) and error.__cause__ else error.__traceback__
    if tb is not None:
        frame = traceback.extract_tb(tb)[-1]
        last = f" at {os.path.basename(frame.filename)}:{frame.lineno}"
    return (f"seed {seed} ({name}): {error}{last}\n    replay: HEXA_FUZZ_SEED={seed} HEXA_FUZZ_CASES=1 "
            f"python3 -m unittest tests.test_fuzz_files.{test}")


def report(testcase, failures):
    if failures:
        shown = "\n  ".join(failures[:SHOWN])
        more = f"\n  ... and {len(failures) - SHOWN} more" if len(failures) > SHOWN else ""
        testcase.fail(f"{len(failures)} of {CASES} cases hit an unexpected failure (base seed {BASE_SEED}):\n  "
                      f"{shown}{more}")


def run_cases(testcase, run_case, what, test):
    """Run CASES seeded cases; fail with every unexpected crash listed with its seed and a replay command."""
    failures = []
    for i in range(CASES):
        seed = BASE_SEED + i
        try:
            run_case(seed)
        except Exception as error:              # noqa: BLE001 - anything unexpected is what we are looking for
            failures.append(describe_failure(seed, what, error, test))
    report(testcase, failures)


class FuzzSettingsTest(TempHome):
    def run_case(self, seed):
        rng = random.Random(seed)
        name, raw = settings_file(rng)
        with open(os.path.join(self.home, "settings.json"), "wb") as f:
            f.write(raw)
        want, _ = oracle_settings(raw)
        got = call("settings.load", settings.load)
        if set(got) != set(settings.DEFAULTS):
            raise AssertionError(f"load() returned keys {sorted(got)}")
        for key, value in got.items():
            if value == want[key] and type(value) is type(want[key]):
                continue
            raise AssertionError(f"{key}: loaded {value!r}, expected {want[key]!r}")
        w, h = call("settings.window_size", settings.window_size, got)
        if f"{w}x{h}" not in settings.WINDOWS:
            raise AssertionError(f"window_size gave {(w, h)}")
        for key in settings.CHOICES:
            copy = dict(got)
            call("settings.cycle", settings.cycle, copy, key)
        if not call("settings.save", settings.save, got):
            raise AssertionError("save() failed in a writable folder")
        if call("settings.load again", settings.load) != got:
            raise AssertionError("options changed by a save/load round trip")
        if os.listdir(self.home) != ["settings.json"]:
            raise AssertionError(f"files left behind: {os.listdir(self.home)}")

    def test_damaged_settings_json_never_raises(self):
        run_cases(self, self.run_case, "settings.json",
                  "FuzzSettingsTest.test_damaged_settings_json_never_raises")


# ----- save files --------------------------------------------------------------------------------------------

GOOD_HEADER = {"version": saves.VERSION, "slot": "1", "saved": 1.7e9, "date": "Spring 1480", "turn": 1,
               "map": "Europe 1480", "tag": "POR", "country": "Portugal", "treasury": 100}
HEADER_KEYS = tuple(GOOD_HEADER)
ALL_SLOTS = saves.SPECIAL + saves.SLOTS
_REAL = {}


def real_save():
    """(header line, body) of a genuine save of the Europe world, made once per process."""
    if not _REAL:
        old = os.environ.get("HEXA_HOME")
        home = tempfile.mkdtemp()
        os.environ["HEXA_HOME"] = home
        try:
            saves.save(fresh(), "1")
            with open(saves.path("1"), "rb") as f:
                head, body = f.read().split(b"\n", 1)
        finally:
            shutil.rmtree(home, ignore_errors=True)
            if old is None:
                os.environ.pop("HEXA_HOME", None)
            else:
                os.environ["HEXA_HOME"] = old
        _REAL["header"], _REAL["body"] = head, body
    return _REAL["header"], _REAL["body"]


def header_line(rng):
    """(name, bytes): one damaged header line."""
    kind = rng.randrange(13)
    good = dict(GOOD_HEADER, saved=time.time() - rng.randrange(0, 10 ** 7), slot=rng.choice(ALL_SLOTS))
    if kind <= 1:
        return "valid", dumps(good)
    if kind == 2:
        key = rng.choice(HEADER_KEYS)
        return f"wrong value at {key}", dumps(dict(good, **{key: rand_value(rng)}))
    if kind == 3:
        key = rng.choice(HEADER_KEYS)
        return f"no {key}", dumps({k: v for k, v in good.items() if k != key})
    if kind == 4:
        return "saved of a wrong kind", dumps(dict(good, saved=rng.choice(
            ("yesterday", None, [1], {}, float("nan"), float("inf"), 1e30, -1e30, 2 ** 70, True, "", "1.5"))))
    if kind == 5:
        return "odd version", dumps(dict(good, version=rng.choice(
            (0, -1, 2, saves.VERSION + 1, 2 ** 70, 1.0, 1.5, "1", None, True, [1], {}, float("nan")))))
    if kind == 6:
        return "wrong values everywhere", dumps({k: rand_value(rng) for k in HEADER_KEYS})
    if kind == 7:
        return "not an object", dumps(rand_value(rng))
    if kind == 8:
        text = dumps(good)
        return "mangled", mangle(rng, text)
    if kind == 9:
        return "binary garbage", bytes(rng.randrange(256) for _ in range(rng.choice((0, 1, 7, 300))))
    if kind == 10:
        return "huge or odd numbers", dumps(dict(good, **{k: rng.choice((2 ** 70, 10 ** 30, float("nan"),
                                                                        float("inf"), -1e30, 1e-320))
                                                          for k in rng.sample(HEADER_KEYS, 3)}))
    if kind == 11:
        return "extra keys", dumps(dict(good, **{"junk": rand_value(rng), "": 1}))
    return rng.choice((("deeply nested array", b"[" * DEEP), ("deeply nested objects", b'{"a":' * DEEP),
                       ("header only, bad utf-8", b'{"version": 1, "country": "\xff"}')))



class FuzzSaveHeaderTest(TempHome):
    """Headers of save files, with a junk body, in one to three slots."""

    def run_case(self, seed):
        rng = random.Random(seed)
        shutil.rmtree(saves.folder(), ignore_errors=True)
        os.makedirs(saves.folder())
        for slot in rng.sample(ALL_SLOTS, rng.randrange(1, 4)):
            _, raw = header_line(rng)
            body = rng.choice((b"", b"x", b"garbage\n" * 3, pickle.dumps({})))
            with open(saves.path(slot), "wb") as f:
                f.write(raw + b"\n" + body)

        infos = {slot: call(f"saves.meta({slot!r})", saves.meta, slot) for slot in ALL_SLOTS}
        for slot, info in infos.items():
            version = info.get("version") if info is not None else saves.VERSION
            if not (isinstance(version, int) and 1 <= version <= saves.VERSION):
                raise AssertionError(f"meta({slot!r}) accepted {info!r}")
        listed = call("saves.listing", saves.listing)
        if [s for s, _ in listed] != list(ALL_SLOTS):
            raise AssertionError("listing() lost slots")

        readable = {s: m for s, m in infos.items() if m}
        latest = call("saves.latest", saves.latest)
        if latest not in readable and not (latest is None and not readable):
            raise AssertionError(f"latest() gave {latest!r} for the readable slots {sorted(readable)}")
        if readable:
            best = max((saves._saved_time(m) or 0.0, s) for s, m in readable.items())[1]
            if latest != best:
                raise AssertionError(f"latest() gave {latest!r}, the newest save is {best!r}")
        for slot, info in readable.items():
            text = call(f"saves.describe({slot!r})", saves.describe, info)
            if not isinstance(text, str):
                raise AssertionError(f"describe({slot!r}) gave {text!r}")
        for slot in ALL_SLOTS:
            with contextlib.redirect_stderr(io.StringIO()):
                world = call(f"saves.load({slot!r})", saves.load, slot)
            if world is not None:
                raise AssertionError(f"load({slot!r}) made a world out of a junk body")

    def test_damaged_save_headers_never_raise(self):
        run_cases(self, self.run_case, "save header", "FuzzSaveHeaderTest.test_damaged_save_headers_never_raise")


class FuzzSaveBodyTest(TempHome):
    """A good header followed by a body that was damaged, or is a pickle of the wrong shape."""
    REAL_SHARE = 0.04            # a genuine world body costs about 0.2 s to unpickle and to build

    def body(self, rng):
        _, real = real_save()
        kind = rng.randrange(10)
        if rng.random() < self.REAL_SHARE:
            if kind < 3:
                return "real body, truncated", real[:rng.randrange(len(real))]
            if kind < 6:
                return "real body, flipped bytes", flip_bytes(rng, real, rng.randrange(1, 5))
            if kind < 8:
                return "real body, junk after it", real + bytes(rng.randrange(256) for _ in range(20))
            state = pickle.loads(real)
            key = rng.choice(sorted(state))
            if rng.random() < 0.4:
                del state[key]
                return f"real state without {key}", pickle.dumps(state)
            value = rand_value(rng)
            if key in ("map", "seed") and value == "random":
                value = None                 # a real random map would take seconds to generate
            state[key] = value
            return f"real state with {key} replaced", pickle.dumps(state)
        if kind < 3:
            return "wrong-shape pickle", pickle.dumps(rand_value(rng))
        if kind < 5:
            return "partial state", pickle.dumps({k: rand_value(rng) for k in ("turn", "cols", "rows", "countries",
                                                                                "provinces", "units", "player")})
        if kind < 7:
            return "truncated small pickle", pickle.dumps({"turn": 1, "units": list(range(50))})[
                :rng.randrange(1, 60)]
        if kind < 8:
            return "small pickle, flipped bytes", flip_bytes(rng, pickle.dumps({"turn": 1, "units": [1, 2]}), 2)
        return "noise", bytes(rng.randrange(256) for _ in range(rng.choice((0, 1, 9, 400))))

    def run_case(self, seed):
        rng = random.Random(seed)
        shutil.rmtree(saves.folder(), ignore_errors=True)
        os.makedirs(saves.folder())
        _, body = self.body(rng)
        slot = rng.choice(ALL_SLOTS)
        header, _ = real_save()
        with open(saves.path(slot), "wb") as f:
            f.write(header + b"\n" + body)
        info = call(f"saves.meta({slot!r})", saves.meta, slot)
        if info is None or info["map"] != "Europe 1480":
            raise AssertionError("the header of the save is not read")
        if call("saves.latest", saves.latest) != slot:
            raise AssertionError("latest() does not offer the slot")
        call("saves.describe", saves.describe, info)
        with contextlib.redirect_stderr(io.StringIO()):
            world = call(f"saves.load({slot!r})", saves.load, slot)
        if world is not None and not isinstance(world, CampaignWorld):
            raise AssertionError(f"load() gave {world!r}")
        if os.listdir(saves.folder()) != [f"{slot}.sav"]:
            raise AssertionError(f"files left behind: {os.listdir(saves.folder())}")

    def test_damaged_save_bodies_never_raise(self):
        real_save()                             # built before the first case, not inside it
        run_cases(self, self.run_case, "save body", "FuzzSaveBodyTest.test_damaged_save_bodies_never_raise")


# ----- the fuzzer itself -------------------------------------------------------------------------------------

class FuzzerSelfTest(TempHome):
    """The fuzzer has to see what it claims to see: replayable cases, every kind of damage, and a loud failure for
    any crash (none is excused)."""

    def test_the_same_seed_makes_the_same_file(self):
        for make in (settings_file, header_line):
            self.assertEqual(make(random.Random(5)), make(random.Random(5)))

    def test_cases_cover_every_kind_of_damage(self):
        names = {settings_file(random.Random(s))[0] for s in range(400)}
        for wanted in ("valid", "wrong value at", "not an object", "truncated", "binary garbage", "flipped bytes",
                       "unknown keys", "huge or odd numbers", "deeply nested array", "oversize"):
            self.assertTrue(any(n.startswith(wanted) for n in names), wanted)
        names = {header_line(random.Random(s))[0] for s in range(400)}
        for wanted in ("valid", "wrong value at", "no saved", "saved of a wrong kind", "odd version",
                       "not an object", "mangled", "binary garbage", "huge or odd numbers", "deeply nested"):
            self.assertTrue(any(n.startswith(wanted) for n in names), wanted)

    def _failures(self, run_case, seeds):
        failed = []
        for seed in seeds:
            try:
                run_case(seed)
            except Exception as error:          # noqa: BLE001
                failed.append((seed, error))
        return failed

    def test_a_crash_is_reported_with_its_seed_and_a_replay_command(self):
        with mock.patch.object(settings, "load", side_effect=KeyError("surprise")), \
                mock.patch.object(sys.modules[__name__], "CASES", 3):
            with self.assertRaises(AssertionError) as caught:
                fuzz = FuzzSettingsTest("test_damaged_settings_json_never_raises")
                fuzz.home = self.home
                run_cases(self, fuzz.run_case, "settings.json", "FuzzSettingsTest.x")
        text = str(caught.exception)
        self.assertIn("3 of 3 cases", text)
        self.assertIn(f"seed {BASE_SEED}", text)
        self.assertIn(f"HEXA_FUZZ_SEED={BASE_SEED} HEXA_FUZZ_CASES=1 python3 -m unittest tests.test_fuzz_files", text)
        self.assertIn("KeyError", text)

    def test_no_crash_is_excused_any_more(self):
        case = FuzzSaveHeaderTest("test_damaged_save_headers_never_raise").run_case
        for target, error in (("describe", OverflowError("year out of range")), ("latest", KeyError("saved")),
                              ("meta", RecursionError("deep"))):
            with self.subTest(target), mock.patch.object(saves, target, side_effect=error):
                self.assertTrue(self._failures(case, range(40)),
                                f"{type(error).__name__} out of {target}() went unnoticed")
        fuzz = FuzzSettingsTest("test_damaged_settings_json_never_raises")
        fuzz.home = self.home
        with mock.patch.object(settings, "load", side_effect=RecursionError("deep")):
            self.assertTrue(self._failures(fuzz.run_case, range(40)), "RecursionError out of load() went unnoticed")
        with mock.patch.object(saves, "latest", side_effect=ValueError("never seen before")):
            self.assertTrue(self._failures(case, range(40)), "a new kind of crash out of latest() went unnoticed")

    def test_the_oracle_matches_what_the_settings_module_promises(self):
        self.assertEqual(oracle_settings(b"[]"), (settings.DEFAULTS, None))
        want, stored = oracle_settings(b'{"fullscreen": 0, "scroll": "fast"}')
        self.assertEqual(want, dict(settings.DEFAULTS, scroll="fast"))
        self.assertEqual(stored, {"fullscreen": 0, "scroll": "fast"})
        self.assertEqual(oracle_settings(b"\xff")[0], settings.DEFAULTS)


if __name__ == "__main__":
    unittest.main()
