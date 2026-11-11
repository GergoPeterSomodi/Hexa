"""settings.json: what load() makes of any file, what save() does when it can't write, window_size().

Related tests that live in tests/test_saves.py: the options page and F11 when the file can't be written (#10),
and the non-object file check next to the save header one (#7). Random damage to the file is in
tests/test_fuzz_files.py. Every test uses a temporary HEXA_HOME. Run with: python -m unittest tests.test_settings
"""
import contextlib
import io
import json
import os
import stat
import sys
import unittest
from unittest import mock

from hexa import settings
from tests.support.home import TempHome


def write(home, content):
    """Put raw content (str or bytes) in settings.json under the given folder."""
    mode = "wb" if isinstance(content, bytes) else "w"
    with open(os.path.join(home, "settings.json"), mode) as f:
        f.write(content)


class LoadTest(TempHome):
    def test_no_file_gives_the_defaults_and_a_copy(self):
        s = settings.load()
        self.assertEqual(s, settings.DEFAULTS)
        s["scroll"] = "fast"
        self.assertEqual(settings.DEFAULTS["scroll"], "normal", "changing the options leaves DEFAULTS alone")
        self.assertEqual(settings.load(), settings.DEFAULTS)

    def test_a_file_that_is_not_an_object_counts_as_missing(self):      # issue #7
        for content in ("[]", "[1, 2]", "null", "1", "2.5", '"text"', "true", "false", "NaN"):
            with self.subTest(content=content):
                write(self.home, content)
                self.assertEqual(settings.load(), settings.DEFAULTS)

    def test_unreadable_content_counts_as_missing(self):
        cases = {"empty": b"", "blanks": b" \n\t ", "truncated": b'{"scroll": "fa', "trailing comma": b'{"a": 1,}',
                 "garbage": bytes(range(256)), "bad utf-8": b'{"scroll": "\xff\xfe"}', "bom only": b"\xef\xbb\xbf",
                 "two objects": b'{"scroll": "fast"}{"scroll": "slow"}', "single quotes": b"{'scroll': 'fast'}"}
        for name, content in cases.items():
            with self.subTest(name):
                write(self.home, content)
                self.assertEqual(settings.load(), settings.DEFAULTS)

    @unittest.expectedFailure
    def test_very_deep_nesting_counts_as_missing(self):
        """New crash class, no GitHub issue filed yet. ``json.load`` raises RecursionError (not a ValueError)
        for a file nested deeper than the interpreter allows: about 1000 levels on Python 3.10, about 200000 on
        3.15, so a million is enough everywhere. load() only catches OSError and ValueError."""
        for content in ("[" * 1000000, '{"a":' * 1000000):
            with self.subTest(content=content[:5]):
                write(self.home, content)
                self.assertEqual(settings.load(), settings.DEFAULTS)

    def test_a_folder_in_place_of_the_file_counts_as_missing(self):
        os.mkdir(os.path.join(self.home, "settings.json"))
        self.assertEqual(settings.load(), settings.DEFAULTS)

    def test_unknown_keys_are_ignored(self):
        write(self.home, json.dumps({"scroll": "fast", "volume": 11, "__proto__": {}, "": 1, "Scroll": "slow"}))
        s = settings.load()
        self.assertEqual(s, dict(settings.DEFAULTS, scroll="fast"))
        self.assertEqual(set(s), set(settings.DEFAULTS), "only known options come back")

    def test_illegal_values_fall_back_one_option_at_a_time(self):
        write(self.home, json.dumps({"fullscreen": True, "window": "800x600", "autosave": "5 years",
                                     "scroll": "warp", "grid": False}))
        self.assertEqual(settings.load(), {"fullscreen": True, "window": "1280x720", "autosave": "5 years",
                                           "scroll": "normal", "grid": False})

    def test_values_of_the_wrong_type_fall_back_to_the_default(self):
        # JSON null, strings for booleans, numbers for strings, lists, objects, NaN, Infinity, huge numbers
        wrong = [None, "true", "false", "yes", "", 2, -1, 2 ** 70, 1e400, float("nan"), [], [True], {}, {"a": 1},
                 "1280x720 ", "1280X720", ["1280x720"]]
        for key in settings.DEFAULTS:
            for value in wrong:
                with self.subTest(key=key, value=value):
                    if value in settings.CHOICES[key]:      # "true" is no choice, but 2 is not either: skip real ones
                        continue
                    write(self.home, json.dumps({key: value}))     # NaN and Infinity are written as JS literals
                    self.assertEqual(settings.load(), settings.DEFAULTS)

    @unittest.expectedFailure
    def test_a_number_is_not_a_boolean_fullscreen(self):
        """New: no GitHub issue filed yet. 0 == False and 1 == True, so ``{"fullscreen": 0}`` passes the
        ``value in CHOICES`` check and load() hands out the number 0 (or 1.0) instead of a bool. Harmless
        today (it is only ever tested for truth and saved back as 0) but the option has the wrong type."""
        for value in (0, 1, 0.0, 1.0):
            with self.subTest(value=value):
                write(self.home, json.dumps({"fullscreen": value}))
                got = settings.load()["fullscreen"]
                self.assertIs(type(got), bool, f"{value!r} loaded as {got!r}")

    def test_a_number_as_fullscreen_still_works_as_a_switch(self):
        """Whatever the type issue above is fixed to, a 0 or 1 in the file must not break the game."""
        write(self.home, '{"fullscreen": 1}')
        s = settings.load()
        self.assertTrue(s["fullscreen"])
        settings.cycle(s, "fullscreen")
        self.assertFalse(s["fullscreen"])
        self.assertTrue(settings.save(s))
        self.assertFalse(settings.load()["fullscreen"])

    def test_a_repeated_key_uses_the_last_value(self):
        write(self.home, '{"scroll": "fast", "scroll": "slow"}')
        self.assertEqual(settings.load()["scroll"], "slow")

    def test_hexa_home_decides_where_the_file_is(self):
        write(self.home, '{"scroll": "fast"}')
        elsewhere = os.path.join(self.home, "other")
        os.mkdir(elsewhere)
        write(elsewhere, '{"scroll": "slow"}')
        self.assertEqual(settings.load()["scroll"], "fast")
        with mock.patch.dict(os.environ, {"HEXA_HOME": elsewhere}):
            self.assertEqual(settings.load()["scroll"], "slow")

    def test_without_hexa_home_the_file_is_in_the_dot_hexa_folder_of_the_user(self):
        os.mkdir(os.path.join(self.home, ".hexa"))
        write(os.path.join(self.home, ".hexa"), '{"scroll": "fast"}')
        for hexa_home in (None, ""):                    # unset, or set to nothing
            with self.subTest(hexa_home=hexa_home):
                env = {k: v for k, v in os.environ.items() if k != "HEXA_HOME"}
                if hexa_home is not None:
                    env["HEXA_HOME"] = hexa_home
                with mock.patch.dict(os.environ, env, clear=True), \
                        mock.patch("hexa.settings.os.path.expanduser", return_value=self.home):
                    self.assertEqual(settings.load()["scroll"], "fast")


class SaveTest(TempHome):
    def test_round_trip_and_the_folder_is_made(self):
        home = os.path.join(self.home, "new", "folder")
        s = dict(settings.DEFAULTS, scroll="slow", fullscreen=True)
        with mock.patch.dict(os.environ, {"HEXA_HOME": home}):
            self.assertTrue(settings.save(s))
            self.assertEqual(settings.load(), s)
        self.assertEqual(os.listdir(home), ["settings.json"], "no temporary file is left behind")

    def test_only_the_known_options_are_written(self):
        s = dict(settings.DEFAULTS, junk=[1, 2], other=None)
        self.assertTrue(settings.save(s))
        with open(os.path.join(self.home, "settings.json"), encoding="utf-8") as f:
            self.assertEqual(json.load(f), settings.DEFAULTS)

    def test_saving_replaces_a_damaged_file(self):
        write(self.home, b"\xff garbage")
        self.assertTrue(settings.save(dict(settings.DEFAULTS, autosave="off")))
        self.assertEqual(settings.load()["autosave"], "off")

    def test_hexa_home_being_a_file_is_reported_not_raised(self):         # issue #10
        os.environ["HEXA_HOME"] = os.path.join(self.home, "blocker")
        with open(os.environ["HEXA_HOME"], "w") as f:
            f.write("not a folder")
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            self.assertFalse(settings.save(dict(settings.DEFAULTS)))
        self.assertIn("Could not save options to", err.getvalue())
        self.assertEqual(os.listdir(self.home), ["blocker"], "nothing was created next to the blocker")

    @unittest.skipIf(sys.platform == "win32" or (hasattr(os, "geteuid") and os.geteuid() == 0),
                     "folder permissions are not enforced here")
    def test_a_read_only_folder_is_reported_and_keeps_the_old_file(self):   # issue #10
        s = dict(settings.DEFAULTS, scroll="fast")
        self.assertTrue(settings.save(s))
        os.chmod(self.home, stat.S_IRUSR | stat.S_IXUSR)
        self.addCleanup(os.chmod, self.home, stat.S_IRWXU)
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            self.assertFalse(settings.save(dict(s, scroll="slow")))
        self.assertIn("Could not save options to", err.getvalue())
        self.assertEqual(settings.load()["scroll"], "fast", "the old file is left as it was")
        self.assertEqual(os.listdir(self.home), ["settings.json"])

    def test_a_failed_replace_removes_the_temporary_file(self):
        with mock.patch("hexa.settings.os.replace", side_effect=PermissionError("denied")):
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertFalse(settings.save(dict(settings.DEFAULTS)))
        self.assertEqual(os.listdir(self.home), [])

    def test_a_folder_in_place_of_the_file_is_reported(self):
        os.mkdir(os.path.join(self.home, "settings.json"))        # os.replace() cannot put a file over a folder
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertFalse(settings.save(dict(settings.DEFAULTS)))
        self.assertEqual(os.listdir(self.home), ["settings.json"])


class OptionsTest(unittest.TestCase):
    def test_every_default_is_a_legal_choice(self):
        self.assertEqual(set(settings.DEFAULTS), set(settings.CHOICES))
        for key, value in settings.DEFAULTS.items():
            self.assertIn(value, settings.CHOICES[key], key)

    def test_cycle_visits_every_choice_and_wraps_round(self):
        for key, choices in settings.CHOICES.items():
            with self.subTest(key):
                s = dict(settings.DEFAULTS)
                seen = [s[key]] + [settings.cycle(s, key) for _ in choices]
                self.assertEqual(seen[-1], seen[0], "back where it started after one full turn")
                self.assertEqual(set(seen), set(choices))

    def test_window_size_reads_every_window_choice(self):
        for window in settings.WINDOWS:
            with self.subTest(window):
                w, h = window.split("x")
                self.assertEqual(settings.window_size({"window": window}), (int(w), int(h)))
        self.assertEqual(settings.window_size(settings.DEFAULTS), (1280, 720))
        self.assertEqual(settings.window_size({"window": "1600x900"}), (1600, 900))

    def test_window_size_gives_positive_whole_numbers(self):
        for window in settings.WINDOWS:
            size = settings.window_size({"window": window})
            self.assertTrue(all(type(n) is int and n > 0 for n in size), size)

    def test_scroll_and_autosave_tables_cover_every_choice(self):
        self.assertEqual(set(settings.SCROLL), set(settings.CHOICES["scroll"]))
        self.assertEqual(set(settings.AUTOSAVE_TURNS), set(settings.CHOICES["autosave"]))


class WindowSizeAfterLoadTest(TempHome):
    def test_whatever_the_file_says_window_size_can_be_computed(self):
        for content in ('{"window": "800x600"}', '{"window": null}', '{"window": 1280}', "[]", "garbage",
                        '{"window": "1920x1080"}'):
            with self.subTest(content=content):
                write(self.home, content)
                w, h = settings.window_size(settings.load())
                self.assertIn(f"{w}x{h}", settings.WINDOWS)


if __name__ == "__main__":
    unittest.main()
