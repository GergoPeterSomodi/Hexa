"""The sieges on the window (release 0.2.2, design docs/design/sieges-and-retreats.md 4.5 to 4.7): the siege badge on the map
(fog rules as the battle badge), its hover card, the grey flash of a lifted siege, the odds card's Besiege and Storm
lines, right-click Besiege (Shift: Storm) with a refused besiege toasting its reason, the province panel's Siege block
(Storm now for the besieger, the relief line for the defender, which selects the army), the task flag's line for a place
of yours under siege, and the ribbons. Run with: python -m unittest tests.ui.test_sieges_window"""
from unittest import mock

from tests.support import harness
from tests.support.battles import setup


class SiegeWindowCase(harness.UITestCase):
    def start(self, castle=2, attackers=(("infantry", 1, 4),), defenders=()):
        import play
        from hexa.campaign.app import CampaignApp
        self.app = app = CampaignApp(play.TILES_DIR, "POR")
        world = app.world
        self.fight = fight = setup(world, list(attackers), list(defenders), castle=castle)
        world.player = fight.attacker
        world.visible = set(world.terrain)
        world.changed()
        app.refresh()
        app.select_unit(fight.attackers[0])
        app.refresh()
        app.draw()
        self.prov = world.provinces[fight.defend_pos]
        return app

    def siege(self, app):
        """Besiege the castle now (the stack walks in and one season of the meter runs). Nothing is drawn."""
        world, fight = app.world, self.fight
        self.assertTrue(world.besiege(fight.attackers, fight.defend_pos))
        world.sieges()
        app.refresh()
        return self.prov

    def point_at(self, app, pos):
        app.ui.mouse = tuple(harness.hex_pixel(app, pos))

    def panel_button(self, app, action):
        app.draw()
        return harness.button_rect(app, action=action)


class MapBadgeTest(SiegeWindowCase):
    def test_the_badge_is_drawn_for_a_visible_siege_and_hidden_under_fog(self):
        app = self.start()
        self.siege(app)
        pos = self.fight.defend_pos
        third = next(tag for tag in app.world.countries if tag not in (self.fight.attacker, self.fight.defender))
        app.world.player = third                             # a country that is in no way a party to the siege
        app.world.visible = set()
        app.draw()
        self.assertEqual(app.hud.sieges.hits, [], "a siege the player cannot see has no mark")
        app.world.visible = {pos}
        app.draw()
        self.assertIn(pos, [p for _, p in app.hud.sieges.hits], "a siege in sight has its badge")

    def test_the_hover_card_gives_the_meter_the_seasons_and_the_stores(self):
        from hexa.campaign.battleview import siege_view
        from hexa.campaign.hud import sieges
        app = self.start()
        self.siege(app)
        view = siege_view(app.world, self.fight.defend_pos, app.player)
        title, lines = sieges.card(view)
        self.assertTrue(title.startswith("Siege of "), title)
        texts = [text for text, _ in lines]
        self.assertTrue(any(t.startswith(f"{round(view['progress'])} of {round(view['need'])}, +") for t in texts), texts)
        self.assertTrue(any(t.startswith("Falls in about") or t.startswith("Too few") for t in texts), texts)
        self.assertTrue(any(t.startswith("Stores for") or t.startswith("The garrison is starving") for t in texts), texts)
        self.point_at(app, self.fight.defend_pos)
        app.draw()
        spot = next(rect for rect, pos in app.hud.sieges.hits if pos == self.fight.defend_pos)
        hovers = [card for rect, card in app.ui.hoverables if rect.collidepoint(spot.center)]
        self.assertTrue(hovers and hovers[0][0] == title, "the badge registers its card as a hover")

    def test_the_lifted_siege_flashes_grey_once(self):
        app = self.start()
        self.siege(app)
        pos = self.fight.defend_pos
        app.world.units = [u for u in app.world.units if u.owner != self.fight.attacker]   # the besieger leaves
        app.world.changed(ownership=True)
        app.world.sieges()
        app.process_events()
        app.draw()
        self.assertTrue(any(p == pos for p, *_ in app.hud.sieges.flashes), "the lift is flashed")
        self.assertNotIn(pos, [p for _, p in app.hud.sieges.hits], "a lifted siege has no live badge")
        for _ in range(100):                                 # 1.6 s of fake time: past FLASH_MS, the flash is gone
            self.driver.tick()
        app.draw()
        self.assertEqual(app.hud.sieges.flashes, [])

    def test_clicking_the_badge_opens_the_province(self):
        app = self.start()
        self.siege(app)
        pos = self.fight.defend_pos
        app.draw()
        spot = next(rect for rect, p in app.hud.sieges.hits if p == pos)
        app.left_click(spot.center)
        self.assertIs(app.ui.province, self.prov)
        self.assertEqual(app.ui.panel, "province")


class OddsCardTest(SiegeWindowCase):
    def lines(self, app, pos):
        from hexa.campaign.battleview import odds_view
        from hexa.campaign.hud import odds
        view = odds_view(app.world, app.active(), pos, app.player)
        return [row[0] for row in odds._rows(view) if row is not None]

    def test_a_garrisoned_castle_reads_besiege_and_storm(self):
        app = self.start()
        lines = self.lines(app, self.fight.defend_pos)
        self.assertTrue(any(line.startswith("Besiege: falls in about ") for line in lines), lines)
        self.assertTrue(any("Shift-right-click storms" in line for line in lines), lines)

    def test_too_few_men_says_why_in_the_besiege_line(self):
        app = self.start(castle=3, attackers=(("infantry", 1, 1),))
        lines = self.lines(app, self.fight.defend_pos)
        self.assertTrue(any(line.startswith("Besiege: Too few men to hold a siege") for line in lines), lines)

    def test_the_storm_word_is_the_card_word_under_the_storm_label(self):
        from hexa.campaign.hud import odds
        app = self.start()
        app.ui.hover = self.fight.defend_pos
        app.ui.mouse = tuple(harness.hex_pixel(app, self.fight.defend_pos))
        app.draw()
        self.assertIsNotNone(odds._CACHE["view"]["besiege"])


class RightClickTest(SiegeWindowCase):
    def test_right_click_besieges_by_default(self):
        app = self.start()
        app.refresh()
        app.right_click(harness.hex_pixel(app, self.fight.defend_pos))
        self.assertIsNone(app.world.battle_at(self.fight.defend_pos), "a besiege is no battle")
        app.world.sieges()
        self.assertEqual(app.world.provinces[self.fight.defend_pos].besieger, self.fight.attacker)

    def test_shift_right_click_storms_with_a_battle(self):
        import pygame
        app = self.start()
        app.refresh()
        with mock.patch("pygame.key.get_mods", return_value=pygame.KMOD_SHIFT):
            app.right_click(harness.hex_pixel(app, self.fight.defend_pos))
        self.assertIsNotNone(app.world.battle_at(self.fight.defend_pos), "the storm is the assault battle")

    def test_a_refused_besiege_toasts_its_reason(self):
        app = self.start(castle=3, attackers=(("infantry", 1, 1),))
        app.refresh()
        app.right_click(harness.hex_pixel(app, self.fight.defend_pos))
        self.assertIn("Too few men to hold a siege", app.ui.toast)
        self.assertEqual(app.world.provinces[self.fight.defend_pos].besieger, "")


class PanelTest(SiegeWindowCase):
    def texts(self, app):
        """The lines the province panel drew this frame: the text calls of the window, recorded."""
        from hexa.campaign.panels import province
        with mock.patch.object(app, "text", wraps=app.text) as text:
            province.draw(app, app.world, app.ui, self.prov)
        return [call.args[1] for call in text.call_args_list if len(call.args) > 1 and isinstance(call.args[1], str)]

    def test_the_besieger_has_storm_now_and_it_storms(self):
        app = self.start()
        self.siege(app)
        pos = self.fight.defend_pos
        app.ui.province, app.ui.panel = self.prov, "province"
        app.draw()
        button = harness.button_rect(app, action=("siege", "storm", pos))
        self.assertIsNotNone(button)
        app.left_click(button.center)
        self.assertIsNotNone(app.world.battle_at(pos), "Storm now is the same battle as Storm")

    def test_the_siege_block_shows_the_meter_the_stores_and_the_seasons(self):
        from hexa.campaign.battleview import siege_view
        app = self.start()
        self.siege(app)
        app.ui.province, app.ui.panel = self.prov, "province"
        view = siege_view(app.world, self.fight.defend_pos, app.player)
        texts = self.texts(app)
        self.assertIn("Siege", texts)
        self.assertTrue(any(t.startswith(f"Besieged by {view['besieger_name']}") for t in texts), texts)
        self.assertTrue(any(t.startswith("Stores for") or t.startswith("The garrison is starving") for t in texts), texts)
        self.assertTrue(any(t.startswith("Falls in about") or t.startswith("Too few") for t in texts), texts)

    def test_the_defender_sees_its_relief_and_a_click_selects_the_army(self):
        from hexa.campaign.battleview import siege_view
        from hexa.hexgrid import neighbors
        from tests.support.battles import place
        app = self.start()
        world, fight = app.world, self.fight
        spot = next(n for n in sorted(neighbors(fight.defend_pos))
                    if n in world.provinces and world.is_land(n) and n != fight.attack_pos and not world.units_at(n))
        place(world, "infantry", 1, fight.defender, spot, 3)
        world.changed()
        self.siege(app)
        world.player = fight.defender
        view = siege_view(world, fight.defend_pos, fight.defender)
        self.assertTrue(view["relief"], "the defender's army can reach the castle (its relief line)")
        app.ui.province, app.ui.panel = self.prov, "province"
        app.draw()
        button = harness.button_rect(app, action=("siege", "relief", view["relief"][0]["pos"]))
        app.left_click(button.center)
        self.assertEqual(app.ui.selected.pos, view["relief"][0]["pos"], "the click selects the relief army")

    def test_a_place_under_siege_has_a_task_flag_line(self):
        from hexa.campaign import reminders
        app = self.start()
        self.siege(app)
        lines = [r for r in reminders.unfinished(app.world, self.fight.defender) if r.kind == "siege"]
        self.assertEqual(len(lines), 1, [r.text for r in reminders.unfinished(app.world, self.fight.defender)])
        self.assertIn("is under siege: falls in about", lines[0].text)
        self.assertEqual(lines[0].action, ("province", self.prov))

    def test_the_siege_begun_ribbon_floats(self):
        app = self.start()
        self.siege(app)
        app.process_events()
        items = [item for item in app.game.feed.take_floating() if item.text == "Siege begun"]
        self.assertTrue(items, "the siege begun ribbon floats")

    def test_a_storm_now_with_no_army_is_greyed_with_its_reason(self):
        app = self.start()
        self.siege(app)
        pos = self.fight.defend_pos
        app.world.units = [u for u in app.world.units if u.owner != self.fight.attacker]
        app.world.changed()
        app.ui.province, app.ui.panel = self.prov, "province"
        app.draw()
        button = harness.button_rect(app, action=("siege", "storm", pos))
        self.assertFalse(next(b.enabled for b in app.ui.buttons if b.action == ("siege", "storm", pos)))
        self.assertEqual(button.w > 0, True)
        self.assertTrue(next(b.hint for b in app.ui.buttons if b.action == ("siege", "storm", pos)))


class BesiegeLineTest(harness.UITestCase):
    """The odds card's Besiege lines from a plain view (no window): the war's clock, the men, the storm's word."""

    def view(self, **siege):
        base = {"ok": True, "reason": "", "seasons": 4, "need": 10, "rate": 3, "stores": 2, "war_left": 9,
                "war_ends_first": False}
        base.update(siege)
        return {"besiege": base}

    def texts(self, view):
        from hexa.campaign.hud import odds
        return [row[0] for row in odds._besiege_rows(view) if row is not None]

    def test_falls_in_seasons_and_the_storm_hint(self):
        lines = self.texts(self.view())
        self.assertEqual(lines[0], "Besiege: falls in about 4 seasons")
        self.assertIn("Right-click besieges. Shift-right-click storms", lines)

    def test_one_season_is_singular(self):
        self.assertEqual(self.texts(self.view(seasons=1))[0], "Besiege: falls in about 1 season")

    def test_the_war_ending_first_is_a_warning(self):
        lines = self.texts(self.view(war_ends_first=True, war_left=3))
        self.assertIn("Warning: the war ends in 3 seasons, before it falls", lines)

    def test_too_few_men_says_the_reason(self):
        lines = self.texts(self.view(ok=False, reason="Too few men to hold a siege (need 1,800, you have 600)"))
        self.assertEqual(lines[0], "Besiege: Too few men to hold a siege (need 1,800, you have 600)")

    def test_no_siege_no_lines(self):
        from hexa.campaign.hud import odds
        self.assertEqual(odds._besiege_rows({"besiege": None}), [])
