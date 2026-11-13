"""The odds card on the attack hover (battle slice 1, PR 7b; hexa/campaign/hud/odds.py): it shows when the selected stack
can attack the hex under the mouse, draws the view's word, is made once and then reused while nothing changes, and is
not shown without an attack hover. The timing options read "Clash (default)" and "Quick battles" (their stored values
are unchanged). Run with: python -m unittest tests.ui.test_odds_card"""
from unittest import mock

from tests.support import harness
from tests.support.battles import setup


class OddsCardCase(harness.UITestCase):
    def start(self):
        import play
        from hexa.campaign.app import CampaignApp
        self.app = app = CampaignApp(play.TILES_DIR, "POR")
        world = app.world
        self.fight = setup(world, [("infantry", 1, 3)], [("infantry", 1, 2)])
        world.player = self.fight.attacker
        world.visible = set(world.terrain)
        app.refresh()
        app.select_unit(self.fight.attackers[0])
        app.refresh()
        return app

    def point_at(self, app, pos):
        """The mouse over hex `pos` on the map (a hover needs the mouse there, not on the HUD)."""
        from hexa.campaign.hud.floating import screen_point
        app.ui.mouse = tuple(int(v) for v in screen_point(app, pos))


class HoverTest(OddsCardCase):
    def test_the_card_shows_on_the_attack_hover_and_is_cached(self):
        from hexa.campaign.hud import odds
        app = self.start()
        app.ui.hover = self.fight.defend_pos
        self.point_at(app, self.fight.defend_pos)
        self.assertIn(self.fight.defend_pos, app.ui.attacks)
        with mock.patch.object(odds, "_render", wraps=odds._render) as render:
            app.draw()
            app.draw()
            app.draw()
        self.assertEqual(render.call_count, 1, "the card is made once while the world does not change")
        self.assertEqual(odds._CACHE["view"]["word"], odds._CACHE["view"]["word"])
        self.assertIn(odds._CACHE["view"]["word"], odds.WORD_COLOUR)

    def test_no_card_without_an_attack_hover(self):
        from hexa.campaign.hud import odds
        app = self.start()
        app.ui.hover = None
        self.point_at(app, self.fight.defend_pos)
        odds._CACHE.update(view=None, surface=None)
        app.draw()
        self.assertIsNone(odds._CACHE["view"])

    def test_no_card_over_the_hud(self):
        from hexa.campaign.hud import odds
        app = self.start()
        app.ui.hover = self.fight.defend_pos
        app.ui.mouse = (app.view_rect().x + 2, 2)           # the top bar
        odds._CACHE.update(view=None, surface=None)
        app.draw()
        self.assertIsNone(odds._CACHE["view"])


class TimingLabelTest(harness.UITestCase):
    def test_the_timing_options_read_clash_default_and_quick_battles(self):
        from hexa.campaign.screens.gamemenu import OPTION_TEXT
        label, text = OPTION_TEXT["battle_timing"]
        self.assertEqual(label, "Battle timing")
        self.assertEqual(text("clash"), "Clash (default)")
        self.assertEqual(text("full"), "Quick battles")
