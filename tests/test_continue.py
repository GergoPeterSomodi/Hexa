"""Continue on the start menu with a save that can't be loaded (issue #8). They use a temporary HEXA_HOME and
a stand-in for pygame, so they run headless and without pygame. Run with: python -m unittest tests.test_continue"""
import contextlib
import json
import os
import sys
import unittest
from unittest import mock

import hexa
import hexa.campaign
from hexa.campaign import saves
from tests.support.home import TempHome


@contextlib.contextmanager
def headless_window_code():
    """Import the window modules (campaign app, start menu) against a stand-in pygame; undone afterwards.
    Only code that runs before anything is drawn can be checked this way."""
    stub = mock.MagicMock()
    stub.display.get_desktop_sizes.return_value = [(1920, 1080)]
    stub.display.set_mode.return_value.get_size.return_value = (1280, 720)
    with mock.patch.dict(sys.modules, {"pygame": stub}), mock.patch.dict(hexa.__dict__), \
            mock.patch.dict(hexa.campaign.__dict__):
        for name in [n for n, m in sys.modules.items() if n.startswith("hexa.") and hasattr(m, "pygame")]:
            del sys.modules[name]
            parent, _, child = name.rpartition(".")
            package = sys.modules.get(parent)
            if package is not None:                 # `from hexa.campaign import app` would reuse the old one
                package.__dict__.pop(child, None)
        yield stub


def damage(slot):
    """A save whose header line is fine (so Continue offers it) but whose world after it is garbage."""
    os.makedirs(saves.folder(), exist_ok=True)
    meta = {"version": saves.VERSION, "slot": slot, "saved": 1.0, "date": "Spring 1481", "turn": 5,
            "map": "Random world #9", "tag": "SIA", "country": "Siam", "treasury": 100}
    with open(saves.path(slot), "wb") as f:
        f.write(json.dumps(meta).encode("utf-8") + b"\n" + b"garbage")


class ContinueTest(TempHome):
    def test_a_damaged_save_is_offered_but_does_not_load(self):
        damage("1")
        self.assertEqual(saves.latest(), "1", "the header is fine, so the start menu offers Continue")
        self.assertIsNone(saves.load("1"))

    def test_continue_never_starts_a_new_game_in_place_of_the_save(self):
        damage("1")
        with headless_window_code():
            from hexa.campaign import app
            with mock.patch.object(app.GameManager, "new", side_effect=AssertionError("started a new game")):
                with self.assertRaisesRegex(saves.LoadError, "Slot 1 could not be loaded"):
                    app.CampaignApp(load="1")

    def test_the_start_menu_shows_why_once(self):
        with headless_window_code():
            from hexa.menu import Menu
            menu = Menu(mock.MagicMock(), {"mode": "campaign", "start": "sea", "goal": "survive", "map": "europe",
                                           "error": "Slot 1 could not be loaded."})
        self.assertEqual(menu.error, "Slot 1 could not be loaded.")
        self.assertNotIn("error", menu.settings, "Start/Continue pass the settings on without the message")


if __name__ == "__main__":
    unittest.main()
