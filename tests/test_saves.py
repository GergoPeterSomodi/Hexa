"""Save, load and settings tests (they use a temporary HEXA_HOME). Run with:
python -m unittest discover -s tests -t ."""
import contextlib
import errno
import importlib.util
import io
import json
import operator
import os
import pickle
import sys
import unittest
from unittest import mock

from hexa import settings
from hexa.campaign import saves
from hexa.campaign.game import GameManager
from hexa.campaign.data import GENERAL, troop
from hexa.campaign.world import WORLD_DEFAULTS, WORLD_REQUIRED, CampaignWorld
from tests.support.home import TempHome
from tests.support.worlds import fresh, play_seasons


class NotAnObjectTest(TempHome):
    """Valid JSON that isn't an object counts as a missing file (issue #7)."""

    def test_save_header_that_is_not_an_object_is_an_empty_slot(self):
        os.makedirs(saves.folder())
        with open(saves.path("1"), "wb") as f:       # a readable save next to the bad one
            f.write(b'{"version": %d, "saved": 5.0, "date": "Spring 1480", "map": "Europe 1480", '
                    b'"country": "Portugal"}\n' % saves.VERSION)
        for header in (b"1", b"null", b"[]", b'"text"', b"true"):
            with self.subTest(header=header):
                with open(saves.path("2"), "wb") as f:
                    f.write(header + b"\n")
                self.assertIsNone(saves.meta("2"))
                self.assertIsNone(saves.load("2"))
                self.assertIsNone(dict(saves.listing())["2"])
                self.assertEqual(saves.latest(), "1", "the start menu still finds the good save")

    def test_settings_file_that_is_not_an_object_gives_defaults(self):
        for content in ("[]", "null", "1", '"text"', "true"):
            with self.subTest(content=content):
                with open(os.path.join(self.home, "settings.json"), "w", encoding="utf-8") as f:
                    f.write(content)
                self.assertEqual(settings.load(), settings.DEFAULTS)


class SaveTest(TempHome):
    def test_a_saved_game_comes_back_exactly(self):
        w = play_seasons(fresh(), 2, player_ai=False)
        w.countries["POR"].treasury = 1234.5
        meta = saves.save(w, "3")
        self.assertEqual(meta["country"], "Portugal")
        back = saves.load("3")
        self.assertEqual(back.turn, w.turn)
        self.assertEqual(back.player, "POR")
        self.assertEqual(back.countries["POR"].treasury, 1234.5)
        self.assertEqual({p: q.owner for p, q in back.provinces.items()}, {p: q.owner for p, q in w.provinces.items()})
        self.assertEqual(len(back.units), len(w.units))
        self.assertTrue(any(u.kind is GENERAL for u in back.units) == any(u.kind is GENERAL for u in w.units))
        self.assertTrue(all(u.kind is troop(u.kind.branch, u.kind.era) for u in back.units if u.kind.war),
                        "unit kinds are the game's own objects again")
        self.assertIs(back.geo, w.geo)
        # the loaded game keeps playing
        new = back._add_unit(troop("infantry", 1), "POR", back.countries["POR"].capital)
        self.assertNotIn(new.id, {u.id for u in w.units})
        back.end_round()
        self.assertEqual(back.turn, w.turn + 1)

    def test_random_worlds_save_too(self):
        w = CampaignWorld(9, player=None, map="random")
        tag = next(iter(w.countries))
        w.player = tag
        saves.save(w, "quick")
        back = saves.load("quick")
        self.assertEqual(back.terrain, w.terrain)
        self.assertEqual(back.geo.name, w.geo.name)

    def test_slots_listing_and_latest(self):
        self.assertIsNone(saves.latest())
        self.assertTrue(all(m is None for _, m in saves.listing()))
        w = CampaignWorld(player="ENG")
        saves.save(w, "1")
        saves.save(w, "auto")
        listed = dict(saves.listing())
        self.assertEqual(listed["1"]["tag"], "ENG")
        self.assertIsNone(listed["2"])
        self.assertIn(saves.latest(), ("1", "auto"))
        self.assertIsNone(saves.load("5"), "an empty slot loads nothing")
        with open(saves.path("6"), "wb") as f:
            f.write(b"not a save")
        with contextlib.redirect_stderr(io.StringIO()):          # load() says why on stderr
            self.assertIsNone(saves.load("6"), "a broken file loads nothing")
        self.assertIsNone(saves.meta("6"))


class OldAndBrokenSavesTest(TempHome):
    def _write(self, slot, state, version=saves.VERSION):
        os.makedirs(saves.folder(), exist_ok=True)
        meta = {"version": version, "slot": slot, "saved": 1.0, "date": "Spring 1480", "turn": 1,
                "map": "Europe 1480", "tag": "POR", "country": "Portugal", "treasury": 0}
        with open(saves.path(slot), "wb") as f:
            f.write(json.dumps(meta).encode("utf-8") + b"\n" + pickle.dumps(state))

    def test_a_removed_unit_kind_means_cant_load_not_a_crash(self):
        from hexa.campaign import data
        w = fresh()
        saves.save(w, "2")
        gone = next(u.kind.key for u in w.units if u.kind.war)
        with mock.patch.dict(data.UNIT_KINDS):
            del data.UNIT_KINDS[gone]
            with contextlib.redirect_stderr(io.StringIO()):      # load() says why on stderr
                self.assertIsNone(saves.load("2"))
        self.assertIsNotNone(saves.load("2"), "the same save loads once the kind is back")

    def test_an_older_save_gets_defaults_for_newer_fields(self):
        w = fresh()
        state = pickle.loads(pickle.dumps(w.save_state()))
        for key in ("over", "wars", "_castle_list", "_known_world"):
            state.pop(key, None)
        prov = next(iter(state["provinces"].values()))
        del prov.__dict__["queue"]
        del state["countries"]["POR"].__dict__["memory"]
        del state["units"][0].__dict__["supplies"]
        self._write("3", state)
        back = saves.load("3")
        self.assertIsNotNone(back)
        self.assertFalse(back.over)
        self.assertEqual(back.wars, [])
        self.assertEqual(back.provinces[prov.pos].queue, [])
        self.assertEqual(back.countries["POR"].memory, {})
        self.assertEqual(back.units[0].supplies, 0)
        back.end_round()                         # and the game plays on

    def test_saves_from_a_newer_version_are_refused(self):
        w = fresh()
        self._write("4", w.save_state(), version=saves.VERSION + 1)
        self.assertIsNone(saves.meta("4"))
        self.assertIsNone(saves.load("4"))

    def _refused(self, slot, why):
        """load() gives None for the slot and says why on stderr; returns what it said."""
        said = io.StringIO()
        with contextlib.redirect_stderr(said):
            self.assertIsNone(saves.load(slot), why)
        self.assertIn(f"Could not load save {slot!r}", said.getvalue())
        return said.getvalue()

    def test_a_state_that_is_not_a_whole_world_is_refused(self):
        """Issue #6 (fixed): a save whose body is not a whole world is refused instead of crashing Continue,
        Load or F9."""
        self._write("1", {})                                      # the example in issue #6
        self._refused("1", "an empty state")
        self._write("2", [1, 2, 3])
        self._refused("2", "a state that is not a dict")
        w = fresh()
        for slot, name in (("3", "countries"), ("4", "markets"), ("5", "turn"), ("6", "cols")):
            state = w.save_state()
            del state[name]
            self._write(slot, state)
            self.assertIn(name, self._refused(slot, f"a world without {name}"))

    def test_a_player_country_that_is_not_in_the_world_is_refused(self):
        w = fresh()
        w.player = "XXX"                    # load_world() would look up its capital and crash
        saves.save(w, "1")
        self.assertIn("'XXX'", self._refused("1", "a world without the player's country"))

    def test_errors_while_unpickling_are_refused(self):
        class Fails:                        # pickles as a call that raises when the save is read back
            def __init__(self, func, *args):
                self.call = (func, args)

            def __reduce__(self):
                return self.call
        self._write("1", Fails(int, "1", 2, 3))
        self.assertIn("TypeError", self._refused("1", "a TypeError while unpickling"))
        self._write("2", Fails(operator.getitem, (), 0))
        self.assertIn("IndexError", self._refused("2", "an IndexError while unpickling"))

    def test_every_saved_attribute_is_required_or_has_a_default(self):
        state = fresh().save_state()
        restored = {"map", "seed", "_next_id"}           # _restore() handles these itself
        lazy = {"_explored_from"}                        # added when first needed
        self.assertEqual(set(state) - set(WORLD_REQUIRED) - set(WORLD_DEFAULTS) - restored - lazy, set(),
                         "a new world attribute must go into WORLD_REQUIRED or WORLD_DEFAULTS")
        self.assertTrue(set(WORLD_REQUIRED) <= set(state), "WORLD_REQUIRED only names real attributes")


GOOD_HEADER = {"version": saves.VERSION, "slot": "1", "saved": 1.0, "date": "Spring 1480", "turn": 1,
               "map": "Europe 1480", "tag": "POR", "country": "Portugal", "treasury": 0}


def put(slot, header, body=b""):
    """Write a save file: a header (bytes as they are, or a dict as JSON) on one line, then the body bytes."""
    os.makedirs(saves.folder(), exist_ok=True)
    if not isinstance(header, bytes):
        header = json.dumps(header).encode("utf-8")
    with open(saves.path(slot), "wb") as f:
        f.write(header + b"\n" + body)


class UnreadableSaveTest(TempHome):
    """Files that are not saves, or not saves this version reads: an empty slot, never a crash."""

    def _assert_empty_slot(self, slot):
        self.assertIsNone(saves.meta(slot))
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertIsNone(saves.load(slot))
        self.assertIsNone(dict(saves.listing())[slot])
        self.assertIsNone(saves.latest())

    def test_headers_that_are_no_save_header_are_an_empty_slot(self):
        headers = {"number": b"1", "null": b"null", "list": b"[]", "string": b'"text"', "true": b"true",  # #7
                   "nothing": b"", "not utf-8": b"\xff\xfe\x00", "cut off": b'{"version": 1, "saved": ',
                   "empty object": b"{}", "no version": json.dumps({k: v for k, v in GOOD_HEADER.items()
                                                                       if k != "version"}).encode(),
                   "version 0": b'{"version": 0}', "negative version": b'{"version": -1}',
                   "huge version": b'{"version": %d}' % 2 ** 70, "text version": b'{"version": "1"}',
                   "null version": b'{"version": null}', "float version": b'{"version": 1.0}',
                   "list version": b'{"version": [1]}', "NaN version": b'{"version": NaN}',
                   "version from the future": b'{"version": %d}' % (saves.VERSION + 1)}
        for name, header in headers.items():
            with self.subTest(name):
                put("2", header, b"x")
                self._assert_empty_slot("2")

    def test_a_very_deeply_nested_header_is_an_empty_slot(self):
        """New crash class, no GitHub issue filed yet: ``json.loads`` raises RecursionError (not a ValueError)
        for a header nested deeper than the interpreter allows (about 1000 levels on Python 3.10, about 200000
        on 3.15), and meta() only catches OSError and ValueError."""
        for header in (b"[" * 1000000, b'{"a":' * 1000000):
            with self.subTest(header=header[:5]):
                put("2", header, b"x")
                self._assert_empty_slot("2")

    def test_a_save_from_a_newer_version_is_refused_quietly(self):
        put("2", dict(GOOD_HEADER, version=saves.VERSION + 1), pickle.dumps({}))
        said = io.StringIO()
        with contextlib.redirect_stderr(said):
            self.assertIsNone(saves.load("2"))
        self.assertEqual(said.getvalue(), "", "a version mismatch is not an error worth printing")
        self.assertIsNone(saves.meta("2"))

    def test_a_file_without_any_newline_is_read_as_a_header(self):
        os.makedirs(saves.folder())
        with open(saves.path("3"), "wb") as f:
            f.write(json.dumps(GOOD_HEADER).encode())
        self.assertEqual(saves.meta("3")["country"], "Portugal")
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertIsNone(saves.load("3"), "there is no world after the header")

    def test_a_good_header_with_a_body_of_the_wrong_shape_is_refused(self):       # issue #6
        bodies = {"no body": b"", "text": b"not a pickle", "empty pickle": pickle.dumps(None),
                  "number": pickle.dumps(5), "string": pickle.dumps("world"), "list": pickle.dumps([1, 2]),
                  "empty dict": pickle.dumps({}), "dict of nonsense": pickle.dumps({"a": 1, "turn": "x"}),
                  "set": pickle.dumps({1, 2}), "bytes": pickle.dumps(b"world"),
                  "truncated pickle": pickle.dumps({"turn": 1, "units": list(range(100))})[:30],
                  "pickle then junk": pickle.dumps({}) + b"junk", "protocol 0": pickle.dumps({}, protocol=0)}
        for name, body in bodies.items():
            with self.subTest(name):
                put("4", GOOD_HEADER, body)
                said = io.StringIO()
                with contextlib.redirect_stderr(said):
                    world = saves.load("4")
                self.assertIsNone(world)
                self.assertIn("Could not load save '4'", said.getvalue())
                self.assertIsNotNone(saves.meta("4"), "the header is fine, so the slot still lists")

    def test_a_real_save_cut_short_is_refused(self):
        w = fresh()
        saves.save(w, "5")
        with open(saves.path("5"), "rb") as f:
            whole = f.read()
        header_end = whole.index(b"\n") + 1
        for cut in (header_end, header_end + 1, header_end + 100, len(whole) // 2, len(whole) - 1):
            with self.subTest(cut=cut):
                with open(saves.path("5"), "wb") as f:
                    f.write(whole[:cut])
                with contextlib.redirect_stderr(io.StringIO()):
                    self.assertIsNone(saves.load("5"))
        with open(saves.path("5"), "wb") as f:
            f.write(whole)
        self.assertEqual(saves.load("5").turn, w.turn, "the whole file loads")

    def test_a_folder_or_a_file_in_the_wrong_place_is_an_empty_slot(self):
        os.makedirs(saves.path("6"))                             # a folder called 6.sav
        self._assert_empty_slot("6")
        os.rmdir(saves.path("6"))
        os.rmdir(saves.folder())
        with open(saves.folder(), "w") as f:                     # "saves" is a file, not a folder
            f.write("not a folder")
        self.assertTrue(all(m is None for _, m in saves.listing()))
        self.assertIsNone(saves.latest())
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertIsNone(saves.load("1"))

    def test_the_newest_readable_save_is_the_latest(self):
        put("1", dict(GOOD_HEADER, saved=100.0))
        put("2", dict(GOOD_HEADER, saved=300.5))
        put("quick", dict(GOOD_HEADER, saved=200.0))
        put("auto", b"damaged")
        put("3", dict(GOOD_HEADER, saved=999.0, version=saves.VERSION + 1))
        self.assertEqual(saves.latest(), "2")

    def test_a_failed_pickle_leaves_the_old_save_and_no_tmp_file(self):
        w = fresh()
        saves.save(w, "1")
        w.turn += 3
        w.junk = lambda: 0                                       # cannot be pickled
        with self.assertRaises(saves.SAVE_ERRORS):
            saves.save(w, "1")
        self.assertEqual(os.listdir(saves.folder()), ["1.sav"])
        self.assertEqual(saves.meta("1")["turn"], w.turn - 3)

    @unittest.skipIf(sys.platform == "win32" or (hasattr(os, "geteuid") and os.geteuid() == 0),
                     "folder permissions are not enforced here")
    def test_a_read_only_saves_folder_raises_a_save_error_and_keeps_old_saves(self):     # issue #5
        w = fresh()
        saves.save(w, "1")
        os.chmod(saves.folder(), 0o500)
        self.addCleanup(os.chmod, saves.folder(), 0o700)
        with self.assertRaises(saves.SAVE_ERRORS) as caught:
            saves.save(w, "2")
        self.assertIsInstance(caught.exception, PermissionError)
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(saves.failure(caught.exception), os.strerror(errno.EACCES).lower())
        with self.assertRaises(saves.SAVE_ERRORS):
            saves.save(w, "1")                                   # also over an existing save
        self.assertEqual(os.listdir(saves.folder()), ["1.sav"])
        self.assertIsNotNone(saves.load("1"))


class HeaderFieldsTest(TempHome):
    """What the load page and the start menu read from a header that meta() accepts: ``saved``, ``country``,
    ``date`` and ``map``. meta() only checks ``version``, so a header with a missing or odd field is a slot that
    lists fine and then crashes the screen that shows it.

    New crash classes found by the file fuzzer (tests/test_fuzz_files.py); no GitHub issue filed yet."""

    BAD_SAVED = {"text": "yesterday", "list": [1], "object": {}, "infinity": float("inf"), "NaN": float("nan"),
                 "too big": 1e30, "int too big": 2 ** 70}

    def _use_everything_the_screens_use(self):
        """The calls the start menu (latest + meta) and the load page (listing + describe) make."""
        slot = saves.latest()
        info = saves.meta(slot) if slot else None
        for _, info in saves.listing():
            if info:
                saves.describe(info)
        return slot

    def test_a_header_without_saved_does_not_crash_latest(self):
        """New crash class, no GitHub issue filed yet: ``latest()`` raises KeyError: 'saved' for a header with the
        right version and no ``saved``, so the start menu would crash at launch."""
        put("1", {"version": saves.VERSION})
        self._use_everything_the_screens_use()

    def test_a_saved_of_the_wrong_type_does_not_crash_latest_or_describe(self):
        """New crash class, no GitHub issue filed yet: ``describe()`` raises TypeError (text, list, object),
        OverflowError (infinity, too big) or ValueError (NaN) from time.localtime, and ``latest()`` raises
        TypeError comparing a text ``saved`` with a number."""
        put("2", GOOD_HEADER)                                   # a good save next to the bad one
        failures = []
        for name, saved in self.BAD_SAVED.items():
            put("1", dict(GOOD_HEADER, saved=saved))
            try:
                self._use_everything_the_screens_use()
            except Exception as error:                          # noqa: BLE001 - collect every kind
                failures.append(f"{name}: {type(error).__name__}")
        self.assertEqual(failures, [])

    def test_a_header_without_the_fields_describe_reads_does_not_crash(self):
        """New crash class, no GitHub issue filed yet: ``describe()`` raises KeyError for a header with the right
        version but no country, date or map (the start menu reads country and date the same way)."""
        failures = []
        for missing in ("saved", "country", "date", "map"):
            put("1", {k: v for k, v in GOOD_HEADER.items() if k != missing})
            try:
                self._use_everything_the_screens_use()
            except Exception as error:                          # noqa: BLE001
                failures.append(f"no {missing}: {type(error).__name__}")
        self.assertEqual(failures, [])

    def test_describe_of_a_complete_header(self):
        text = saves.describe(dict(GOOD_HEADER, saved=0.0))
        self.assertTrue(text.startswith("Portugal, Spring 1480  -  Europe 1480  -  saved "), text)
        self.assertTrue(saves.describe(dict(GOOD_HEADER, country="")).startswith("no country, "))


def _gamemenu():
    """hexa.campaign.gamemenu without needing pygame: these tests never draw or open a window."""
    import sys
    try:
        import pygame  # noqa: F401
    except ImportError:
        with mock.patch.dict(sys.modules, {"pygame": mock.MagicMock()}):
            from hexa.campaign import gamemenu
            return gamemenu
    from hexa.campaign import gamemenu
    return gamemenu


class FailedSaveTest(TempHome):
    """A save that can't be written is reported, and the game goes on (issue #5)."""
    def tearDown(self):
        if os.path.isfile(self.home):
            os.remove(self.home)
        super().tearDown()

    def _unwritable(self):
        os.rmdir(self.home)
        with open(self.home, "w") as f:     # HEXA_HOME is a file: no saves folder can be made, even as root
            f.write("not a folder")

    def _game(self, world):
        class Game(_gamemenu().GameMenu):
            def __init__(self):
                self.game, self.settings, self.toasts = GameManager(world), settings.load(), []

            @property
            def world(self):
                return self.game.world

            @property
            def player(self):
                return self.world.player

            def toast(self, text):
                self.toasts.append(text)
        return Game()

    def test_an_unwritable_folder_raises_a_save_error(self):
        self._unwritable()
        with self.assertRaises(saves.SAVE_ERRORS) as caught:
            saves.save(fresh(), "1")
        self.assertIsInstance(caught.exception, OSError)
        with contextlib.redirect_stderr(io.StringIO()):          # failure() prints the whole error there
            self.assertTrue(saves.failure(caught.exception))

    def test_a_failed_write_keeps_the_old_save_and_leaves_no_tmp_file(self):
        import errno
        w = fresh()
        saves.save(w, "1")
        w.turn += 4
        full = OSError(errno.ENOSPC, os.strerror(errno.ENOSPC))
        with mock.patch.object(saves.os, "replace", side_effect=full):
            with self.assertRaises(OSError) as caught:
                saves.save(w, "1")
        self.assertEqual(os.listdir(saves.folder()), ["1.sav"], "the half-written .tmp file is removed")
        self.assertEqual(saves.meta("1")["turn"], w.turn - 4, "the slot keeps its previous save")
        with contextlib.redirect_stderr(io.StringIO()):          # failure() prints the whole error there
            self.assertEqual(saves.failure(caught.exception), os.strerror(errno.ENOSPC).lower())

    def test_a_world_that_cannot_be_pickled_raises_a_save_error(self):
        w = fresh()
        for junk in (lambda: 0, (i for i in ())):    # PicklingError, TypeError
            with self.subTest(junk=junk):
                w.junk = junk
                with self.assertRaises(saves.SAVE_ERRORS) as caught:
                    saves.save(w, "2")
                self.assertEqual(os.listdir(saves.folder()), [])
                with contextlib.redirect_stderr(io.StringIO()):  # failure() prints the whole error there
                    self.assertEqual(saves.failure(caught.exception), "the game could not be written")

    def test_f5_that_fails_says_why_and_the_game_goes_on(self):
        game = self._game(fresh())
        self._unwritable()
        with contextlib.redirect_stderr(io.StringIO()):          # the whole error goes to stderr
            self.assertFalse(game.save_to("quick"))
        self.assertEqual(len(game.toasts), 1)
        self.assertTrue(game.toasts[0].startswith("Could not save Quicksave: "), game.toasts[0])

    def test_an_autosave_that_fails_does_not_crash_the_season(self):
        w = fresh()
        w.turn = 5                                  # "every year" autosaves on turns 5, 9, 13...
        game = self._game(w)
        self._unwritable()
        with contextlib.redirect_stderr(io.StringIO()):          # the whole error goes to stderr
            game.autosave()
        self.assertEqual(len(game.toasts), 1)
        self.assertTrue(game.toasts[0].startswith("Could not autosave: "), game.toasts[0])

    def test_saving_still_works(self):
        w = fresh()
        w.turn = 5
        game = self._game(w)
        self.assertTrue(game.save_to("quick"))
        game.autosave()
        self.assertEqual(game.toasts, [f"Saved: Quicksave ({w.date()}).", "Autosaved."])
        self.assertEqual(saves.meta("auto")["turn"], 5)


@unittest.skipUnless(importlib.util.find_spec("pygame"), "needs pygame")
class AppLoadingTest(TempHome):
    @classmethod
    def setUpClass(cls):
        os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
        import pygame
        pygame.init()

    def test_a_failed_continue_does_not_start_another_game(self):
        from hexa.campaign.app import CampaignApp
        with self.assertRaises(saves.LoadError):
            CampaignApp(load="5")

    def test_f9_asks_first_then_loads_and_closes_the_menu(self):
        from hexa.campaign.app import CampaignApp
        app = CampaignApp(player="POR")
        app.toast = lambda text: setattr(app, "last_toast", text)
        app.quickload()
        self.assertIn("No quicksave", app.last_toast)
        saves.save(app.world, "quick")
        turn = app.world.turn
        app.world.end_round()
        app.open_menu("load")
        self.assertFalse(app.quickload(), "the first F9 only asks")
        self.assertEqual(app.world.turn, turn + 1)
        self.assertIn("F9 again", app.last_toast)
        self.assertTrue(app.quickload())
        self.assertEqual(app.world.turn, turn)
        self.assertIsNone(app.menu)
        app.world.end_round()
        self.assertFalse(app.quickload(), "the confirmation does not last forever")

    def test_a_failed_save_or_autosave_keeps_the_game_running(self):
        import pygame
        from hexa.campaign.app import CampaignApp
        app = CampaignApp(player="POR")
        toasts = []
        app.toast = toasts.append
        os.rmdir(self.home)
        with open(self.home, "w") as f:
            f.write("not a folder")
        try:
            app.handle(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_F5, mod=0, unicode="", scancode=0))
            self.assertIn("Could not save Quicksave", toasts[-1])
            for _ in range(4):                      # Space x4: the autosave at the start of the next year
                app.end_turn()
            self.assertEqual(app.world.turn, 5)
            self.assertIn("Could not autosave", toasts[-1])
            self.assertTrue(app.running)
        finally:
            os.remove(self.home)


class SettingsTest(TempHome):
    def test_defaults_cycle_and_persist(self):
        s = settings.load()
        self.assertEqual(s, settings.DEFAULTS)
        self.assertEqual(settings.cycle(s, "window"), "1600x900")
        settings.cycle(s, "fullscreen")
        settings.save(s)
        again = settings.load()
        self.assertTrue(again["fullscreen"])
        self.assertEqual(settings.window_size(again), (1600, 900))
        with open(os.path.join(self.home, "settings.json"), "w") as f:
            f.write('{"scroll": "warp", "autosave": "off"}')
        odd = settings.load()
        self.assertEqual(odd["scroll"], "normal", "unknown values fall back to the default")
        self.assertEqual(odd["autosave"], "off")


def _gamemenu():
    """hexa.campaign.gamemenu without needing pygame: these tests never draw or open a window."""
    try:
        import pygame  # noqa: F401
    except ImportError:
        with mock.patch.dict(sys.modules, {"pygame": mock.MagicMock()}):
            from hexa.campaign import gamemenu
            return gamemenu
    from hexa.campaign import gamemenu
    return gamemenu


class UnsavedOptionsTest(TempHome):
    """Options that can't be written to settings.json still apply to this game (issue #10)."""
    def _unwritable(self):
        blocker = os.path.join(self.home, "a-file")
        with open(blocker, "w") as f:
            f.write("not a folder")
        os.environ["HEXA_HOME"] = blocker       # writing under it fails with an OSError, even as root

    def test_an_unwritable_folder_is_reported_not_raised(self):
        self._unwritable()
        s = settings.load()
        settings.cycle(s, "scroll")
        with contextlib.redirect_stderr(io.StringIO()):          # save() says why on stderr
            self.assertFalse(settings.save(s))
        self.assertEqual(s["scroll"], "fast", "the change stays in memory")

    def test_a_failed_write_keeps_the_old_file(self):
        s = settings.load()
        settings.cycle(s, "autosave")
        self.assertTrue(settings.save(s))
        settings.cycle(s, "autosave")
        with mock.patch("hexa.settings.json.dump", side_effect=OSError(errno.ENOSPC, "No space left on device")), \
                contextlib.redirect_stderr(io.StringIO()):     # save() says why on stderr
            self.assertFalse(settings.save(s))
        self.assertEqual(settings.load()["autosave"], "5 years", "the last good options survive a full disk")
        self.assertEqual(os.listdir(self.home), ["settings.json"], "no temporary file is left behind")

    def test_f11_and_the_options_page_still_change_the_option(self):
        gamemenu = _gamemenu()

        class Game(gamemenu.GameMenu):
            def __init__(self):
                self.settings, self.toasts, self.displays = settings.load(), [], 0

            def apply_display(self):
                self.displays += 1

            def toast(self, text):
                self.toasts.append(text)

        game = Game()
        game.toggle_fullscreen()
        self.assertEqual(game.toasts, [], "no warning when the options were saved")
        self.assertTrue(settings.load()["fullscreen"])
        self._unwritable()
        with contextlib.redirect_stderr(io.StringIO()):          # each failed settings.save() says why there
            game.toggle_fullscreen()                              # F11
            self.assertFalse(game.settings["fullscreen"])
            self.assertEqual(game.displays, 2, "the screen mode still changes")
            game.menu_press(("option", "scroll"))                 # Menu -> Options
            game.menu_press(("option", "window"))
        self.assertEqual((game.settings["scroll"], game.settings["window"]), ("fast", "1600x900"))
        self.assertEqual(game.displays, 3)
        self.assertEqual(len(game.toasts), 3)
        self.assertTrue(all("next time" in t for t in game.toasts), game.toasts)


if __name__ == "__main__":
    unittest.main()
