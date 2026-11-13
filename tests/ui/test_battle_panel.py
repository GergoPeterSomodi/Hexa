"""The battle panel (battle slice 1, PR 7; hexa/campaign/screens/battle.py): opened from the press table for a battle the
player is a side of, Hold changes the stance, Withdraw is greyed with its reason when there is no retreat hex, Esc, a
right click and a click outside the panel close it, it closes by itself when the battle ends, and it fits 1280x720
and 1920x1080. The rules are in tests/test_battle.py, the view it reads in tests/test_battle_view.py.
Run with: python -m unittest tests.ui.test_battle_panel"""
from unittest import mock

from tests.support import harness
from tests.support.harness import click, key
from tests.test_battle import plain_battle


class BattlePanelCase(harness.UITestCase):
    def start(self):
        import play
        from hexa.campaign.app import CampaignApp
        self.app = app = CampaignApp(play.TILES_DIR, "POR")
        self.world = app.world
        self.fight, self.battle = plain_battle(self.world, [("infantry", 1, 4), ("cavalry", 1, 2)],
                                               [("infantry", 1, 4)])
        self.world.player = self.fight.attacker
        self.world.changed()
        app.press(("battle", self.battle.pos))
        app.draw()                                  # the panel makes its buttons on the first draw
        return app

    def run_loop(self, frames, *steps, until=None):
        """Run the window's loop for `frames`; each step is (frame, events)."""
        self.driver.reset()
        self.app.running, self.app.result = True, None
        for frame, events in steps:
            self.driver.at(frame, events)
        self.driver.run_for(frames, until)
        return self.app.run()

    def entry(self, action):
        return next(e for e in self.app.battle.buttons if e[1] == action)

    def is_open(self):
        return self.app.battle in self.app.screens


class OpenTest(BattlePanelCase):
    def test_the_press_table_opens_it_over_the_map(self):
        app = self.start()
        self.assertIs(app.screens.top, app.battle)
        self.assertEqual(app.battle.pos, self.battle.pos)
        self.assertFalse(app.battle.opaque, "the map shows under a shade")
        self.assertFalse(app.screens.hides_map)

    def test_a_battle_the_player_only_watches_does_not_open(self):
        app = self.start()
        app.screens.clear()
        self.world.player = next(t for t in self.world.countries
                                 if t not in (self.fight.attacker, self.fight.defender)
                                 and self.world.countries[t].alive)
        app.press(("battle", self.battle.pos))
        self.assertFalse(self.is_open())

    def test_no_battle_on_the_hex_does_not_open(self):
        app = self.start()
        app.screens.clear()
        app.press(("battle", (0, 0)))
        self.assertFalse(self.is_open())


class OrdersTest(BattlePanelCase):
    def test_hold_changes_the_stance_through_the_battle_order(self):
        self.start()
        self.run_loop(4, (1, click(self.entry(("stance", "hold"))[0].center)))
        self.assertEqual(self.battle.stance[self.fight.attacker], "hold")
        self.assertTrue(self.is_open(), "an order does not close the panel")

    def test_withdraw_is_greyed_with_its_reason_without_a_retreat_hex(self):
        from hexa.campaign.systems import battle as battlesys
        self.start()
        with mock.patch.object(battlesys, "retreat_spot", return_value=None):
            self.world.changed()                    # the view is cached on world.version: the patch needs a new one
            self.app.draw()
            rect, action, enabled, hint = self.entry(("stance", "withdraw"))
            self.assertFalse(enabled)
            self.assertEqual(hint, "Nowhere to withdraw to")
            self.run_loop(4, (1, click(rect.center)))
        self.assertEqual(self.battle.stance[self.fight.attacker], "attack", "a greyed order changes nothing")

    def test_the_standing_order_is_set_for_the_stack_when_it_is_offered(self):
        self.start()
        rect, action, enabled, hint = self.entry(("standing", "withdraw"))
        self.run_loop(4, (1, click(rect.center)))
        mine = [u for u in self.world.units_at(self.battle.pos) if u.owner == self.fight.attacker and u.kind.war]
        self.assertTrue(mine)
        if enabled:
            self.assertTrue(all(u.standing == "withdraw" for u in mine))
        else:
            self.assertTrue(all(u.standing == "hold" for u in mine), "a greyed standing order changes nothing")


class CloseTest(BattlePanelCase):
    def test_escape_closes(self):
        self.start()
        self.run_loop(4, (1, key("escape")))
        self.assertFalse(self.is_open())
        self.assertEqual(self.world.battle_at(self.battle.pos), self.battle, "closing changes no battle")

    def test_a_right_click_closes(self):
        self.start()
        self.run_loop(4, (1, click((640, 360), button=3)))
        self.assertFalse(self.is_open())

    def test_a_click_outside_closes_and_a_click_inside_does_not(self):
        self.start()
        self.run_loop(4, (1, click((640, 360))))
        self.assertTrue(self.is_open(), "a click inside the panel, on no button, keeps it open")
        self.run_loop(4, (1, click((4, 4))))
        self.assertFalse(self.is_open())

    def test_it_closes_when_the_player_is_no_side_of_it_any_more(self):
        self.start()
        self.world.player = next(t for t in self.world.countries
                                 if t not in (self.fight.attacker, self.fight.defender)
                                 and self.world.countries[t].alive)
        self.run_loop(3)
        self.assertFalse(self.is_open())

    def test_it_closes_when_the_battle_ends(self):
        self.start()
        self.world.battles.remove(self.battle)
        self.world.changed()
        self.run_loop(3)
        self.assertFalse(self.is_open())


class FitTest(BattlePanelCase):
    def test_every_button_is_inside_the_panel_at_both_sizes(self):
        import pygame
        from hexa.campaign.screens import battlelayout as lay
        self.start()
        for width, height in ((1280, 720), (1920, 1080)):
            with self.subTest(size=(width, height)):
                with mock.patch("hexa.campaign.app.open_window",
                                lambda settings: pygame.display.set_mode((width, height))):
                    self.app.apply_display()
                    self.app.draw()
                frame = pygame.Rect(lay.panel(width, height))
                self.assertTrue(pygame.Rect(0, 0, width, height).contains(frame))
                self.assertTrue(self.app.battle.buttons, "the panel drew its buttons")
                for rect, _, _, _ in self.app.battle.buttons:
                    self.assertTrue(frame.contains(rect), f"{rect} is outside {frame}")
