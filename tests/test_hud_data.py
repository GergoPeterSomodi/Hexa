"""The data behind the resource bar, the floating text and the action log (campaign/resources.py, campaign/feed.py).
Pygame-free.

Run with: python -m unittest tests.test_hud_data
"""
import ast
import os
import pickle
import unittest
from unittest import mock

from hexa.campaign import feed, resources
from hexa.campaign.data import troop
from hexa.campaign.game import GameManager
from hexa.campaign.tech import TECHS
from hexa.campaign.world import CampaignWorld
from hexa.events import CAMPAIGN_KINDS
from tests.support.worlds import fresh


def sentences(world, filter="all"):
    return [i.sentence for _, _, items in feed.of(world).entries(filter) for i in items]


class ResourcesTest(unittest.TestCase):
    def setUp(self):
        self.w = fresh("POR")
        self.game = GameManager(self.w)
        self.prov = self.w.provinces_of("POR")[0]

    def test_names_and_a_fresh_game_has_no_change(self):
        snap = resources.snapshot(self.w, "POR")
        self.assertEqual(tuple(snap), resources.NAMES)
        for name, (value, delta, lines) in snap.items():
            self.assertEqual(delta, 0, name)
            self.assertEqual(lines, [], name)
        self.assertEqual(snap["ducats"].value, self.w.countries["POR"].treasury)
        market = self.w.provinces[self.w.countries["POR"].capital].market
        self.assertEqual(snap["horses"].value, round(market.price["horses"], 2))

    def test_raising_troops_is_a_one_off_in_ducats_and_regiments(self):
        before = resources.snapshot(self.w, "POR")
        unit = self.w.recruit("POR", self.prov, troop("infantry", 1))
        self.assertTrue(unit)
        snap = resources.snapshot(self.w, "POR")
        cost = before["ducats"].value - snap["ducats"].value
        self.assertGreater(cost, 0)
        self.assertEqual(snap["ducats"].delta, -cost)
        self.assertEqual([(l.group, l.amount, l.pos) for l in snap["ducats"].lines], [("oneoff", -cost, unit.pos)])
        self.assertIn("Raising troops", snap["ducats"].lines[0].label)
        self.assertEqual(snap["regiments"].delta, 1)
        self.assertEqual([(l.amount, l.pos) for l in snap["regiments"].lines], [(1, unit.pos)])

    def test_lines_of_a_season_add_up_to_the_delta(self):
        self.w.recruit("POR", self.prov, troop("infantry", 1))
        self.game.end_season()
        snap = resources.snapshot(self.w, "POR")["ducats"]
        groups = {l.group for l in snap.lines}
        self.assertIn("income", groups)
        self.assertIn("spending", groups)
        self.assertAlmostEqual(sum(l.amount for l in snap.lines), snap.delta, delta=0.01)
        self.assertAlmostEqual(snap.delta, self.w.countries["POR"].treasury - self.game.tracker.start["POR"]["ducats"],
                               delta=0.01)
        for line in snap.lines:
            if line.group != "oneoff":
                self.assertEqual(line.amount > 0, line.group == "income")

    def test_new_season_resets_the_one_offs(self):
        self.w.recruit("POR", self.prov, troop("infantry", 1))
        self.game.end_season()
        snap = resources.snapshot(self.w, "POR")
        self.assertEqual(snap["regiments"].lines, [])
        self.assertEqual(snap["regiments"].delta, 0)

    def test_every_purchase_goes_through_spend(self):
        w = self.w
        w.countries["POR"].treasury = 5000
        w.recruit("POR", self.prov, troop("infantry", 1))
        self.assertTrue(w.fund_research("POR"))
        spent = [(e.get("reason"), e.get("amount")) for e in w.bus.of("money_spent")]
        self.assertEqual([r for r, _ in spent], ["raise", "research"])
        self.assertEqual(sum(a for _, a in spent), 5000 - w.countries["POR"].treasury)
        self.assertIn("Funding research", [l.label for l in resources.snapshot(w, "POR")["ducats"].lines])

    def test_events_fill_the_other_ledgers(self):
        w, bus = self.w, self.w.bus
        pos = self.prov.pos
        key = next(iter(TECHS))
        bus.emit("unit_lost", "POR", pos, what="Pikemen", why="battle")
        bus.emit("unit_lost", "POR", pos, what="Pikemen", why="deserted")
        bus.emit("unit_lost", "POR", pos, what="Colonist", why="sunk")        # not a regiment
        bus.emit("unit_raised", "POR", pos, what="Wagon", id=1)               # not a regiment
        bus.emit("province_captured", "POR", pos, loser="CAS", by="peace")
        bus.emit("province_captured", "POR", pos, loser="CAS", by="siege")
        bus.emit("debt_seized", "POR", what="castle at X", saving=3.0)
        bus.emit("tech_researched", "POR", key=key, cost=20)
        snap = resources.snapshot(w, "POR")
        self.assertEqual(sorted(l.amount for l in snap["regiments"].lines), [-1, -1])
        self.assertEqual(sorted(l.label.split(":")[0] for l in snap["provinces"].lines), ["Gained in peace", "Occupied"])
        self.assertEqual(resources.snapshot(w, "CAS")["provinces"].lines[0].amount, -1)
        self.assertIn("Creditors seized: castle at X (saves 3/season)", [l.label for l in snap["ducats"].lines])
        research = snap["research"].lines
        self.assertEqual(research[-1].amount, -20)
        self.assertTrue(research[-1].label.startswith("Finished"))

    def test_history_is_bounded_and_ends_with_now(self):
        for _ in range(resources.HISTORY + 3):
            self.game.end_season()
        series = self.game.tracker.series("POR", "ducats")
        self.assertEqual(len(series), resources.HISTORY)
        self.assertEqual(series[-1], self.w.countries["POR"].treasury)
        self.assertEqual(len(self.game.tracker.series("FRA", "provinces")), resources.HISTORY)       # the AI too
        for ledger in self.game.tracker.ledger.values():
            self.assertLessEqual(len(ledger), resources.LEDGER)

    def test_expected_change(self):
        self.game.end_season()
        self.assertEqual(resources.expected(self.w, "POR")["ducats"], self.w.countries["POR"].balance)

    def test_not_saved(self):
        self.game.end_season()
        state = self.w.save_state()
        self.assertFalse(any(isinstance(v, (resources.Tracker, feed.Feed)) for v in state.values()))
        loaded = CampaignWorld.from_state(pickle.loads(pickle.dumps(state)))
        self.assertTrue(all(r.delta == 0 for r in resources.snapshot(loaded, "POR").values()))

    def test_a_broken_tap_cannot_stop_the_game(self):
        self.w.bus.tap(lambda e: 1 / 0)
        with self.assertLogs("hexa", "ERROR"):                  # it is logged, not printed to the player
            self.game.end_season()
        self.assertTrue(self.w.bus.tap_errors)
        self.assertLessEqual(len(self.w.bus.tap_errors), 5)

    def test_a_broken_tap_is_raised_when_hexa_debug_is_set(self):
        self.w.bus.tap(lambda e: 1 / 0)
        with mock.patch.dict(os.environ, {"HEXA_DEBUG": "1"}), self.assertLogs("hexa", "ERROR"):
            with self.assertRaises(ZeroDivisionError):
                self.w.bus.emit("forage", "POR", self.prov.pos)
        with mock.patch.dict(os.environ, {"HEXA_DEBUG": "0"}), self.assertNoLogs("hexa", "ERROR"):
            self.w.bus.emit("forage", "POR", self.prov.pos)         # anything but 1 keeps the game going (the
                                                                    # traceback of this tap and kind was logged)

    def test_the_history_counts_the_start_once(self):
        tracker = self.game.tracker
        self.assertEqual(len(tracker.series("POR", "ducats")), 1, "the start, which is also now")
        for seasons in (1, 2, 3):
            self.game.end_season()
            series = tracker.series("POR", "ducats")
            self.assertEqual(len(series), seasons + 1, "the start, each season's baseline, then now")
            self.assertEqual(series[-1], self.w.countries["POR"].treasury)
        self.assertEqual(len(tracker.history["POR"]["ducats"]), 3, "no baseline is stored twice")

    def test_a_seizure_is_a_label_with_its_saving_and_no_amount(self):
        self.w.bus.emit("debt_seized", "POR", what="castle at X", saving=3.0)
        line = next(l for l in resources.snapshot(self.w, "POR")["ducats"].lines if l.label.startswith("Creditors"))
        self.assertEqual(line.amount, 0.0, "the saving is in the season's upkeep line already")
        self.assertIn("(saves 3/season)", line.label)

    def test_the_ducats_lines_add_up_to_the_change_after_a_seizure(self):
        """A real seizure, set up as the behaviour oracle's debt state does: castles to take, no troops, deep debt."""
        w = self.w
        w.disband("POR", 1e9)
        for prov in w.provinces_of("POR"):
            prov.castle, prov.settlement = 3, max(prov.settlement, 2)
        w.countries["POR"].treasury = -200000.0
        self.game.end_season()
        self.assertTrue(w.bus.of("debt_seized"), "the creditors seized something")
        reading = resources.snapshot(w, "POR")["ducats"]
        self.assertTrue(any(l.label.startswith("Creditors seized") for l in reading.lines))
        self.assertAlmostEqual(sum(l.amount for l in reading.lines), reading.delta, delta=0.01)
        self.assertNotIn("Other", [l.label for l in reading.lines], "nothing is left unexplained")

    def test_a_tap_that_keeps_failing_is_logged_once_per_kind_and_counted_every_time(self):
        self.w.bus.tap(lambda e: 1 / 0)
        with self.assertLogs("hexa", "ERROR") as first:
            self.w.bus.emit("forage", "POR", self.prov.pos)
        self.assertEqual(len(first.records), 1)
        with self.assertNoLogs("hexa", "ERROR"):
            self.w.bus.emit("forage", "POR", self.prov.pos)
        with self.assertLogs("hexa", "ERROR"):                  # another kind: another line
            self.w.bus.emit("native_raid", "POR", self.prov.pos)
        self.assertEqual(len(self.w.bus.tap_errors), 3)

    def test_new_kinds_are_listed(self):
        for kind in ("money_spent", "forage", "native_raid"):
            self.assertIn(kind, CAMPAIGN_KINDS)


class FeedTest(unittest.TestCase):
    def setUp(self):
        self.w = fresh("POR")
        self.game = GameManager(self.w)
        self.bus = self.w.bus
        self.feed = feed.of(self.w)
        self.mine = self.w.provinces_of("POR")[0].pos
        self.fog = next(p for p in self.w.provinces if p not in self.w.visible)
        self.seen = next(p for p in self.w.visible if p in self.w.provinces and self.w.provinces[p].owner != "POR")

    def one(self, kind, tag, pos=None, **data):
        self.feed.clear()
        self.bus.emit(kind, tag, pos, **data)
        items = [i for _, _, group in self.feed.entries() for i in group]
        floating = self.feed.take_floating()
        return (items[0] if items else floating[0] if floating else None), floating

    def test_colour_kinds_are_the_six(self):
        self.assertEqual(feed.COLOUR_KINDS, ("war", "siege", "gain", "own", "loss", "other"))

    def test_item_per_kind_and_colour(self):
        cases = [
            (("unit_raised", "POR", self.mine, dict(what="Pikemen", id=1)), "own", "Recruited"),
            (("forage", "POR", self.mine, {}), "own", "Foraged"),
            (("battle_started", "POR", self.mine, dict(defender="CAS", assault=False, name="Battle of Y, 1480")), "war",
             "Battle!"),
            (("battle_ended", "POR", self.mine, dict(attacker="POR", defender="CAS", winner="POR", loser="CAS",
                                                     name="Battle of Y, 1480", seasons=2,
                                                     killed={"POR": 300, "CAS": 900})), "gain", "Victory!"),
            (("battle_fought", "POR", self.mine, dict(defender="CAS", days=2, morale={"POR": 0.5, "CAS": 0.4},
                                                      killed={"POR": 300, "CAS": 900}, wounded={})), "war", "Fought"),
            (("siege_progress", "POR", self.mine, dict(progress=2, need=5)), "siege", "Siege 2/5"),
            (("province_captured", "POR", self.mine, dict(loser="CAS", by="siege")), "gain", "Captured!"),
            (("province_captured", "CAS", self.mine, dict(loser="POR", by="storm")), "loss", "Lost!"),
            (("province_captured", "FRA", self.seen, dict(loser="CAS", by="siege")), "war", "Captured"),
            (("unit_lost", "POR", self.mine, dict(what="Pikemen", why="battle")), "loss", "Lost"),
            (("unit_lost", "POR", self.mine, dict(what="Pikemen", why="deserted")), "loss", "Deserted"),
            (("unit_lost", "POR", self.mine, dict(what="Pikemen", why="disbanded")), "own", "Disbanded"),
            (("war_declared", "CAS", None, dict(target="POR")), "war", "War!"),
            (("peace_made", "POR", None, dict(b="CAS", winner=None, moved=0)), "other", "Peace"),
            (("tech_researched", "POR", None, dict(key="x", cost=1)), "gain", "Researched"),
            (("era_reached", "POR", None, dict(era=2)), "gain", "New age!"),
            (("building_done", "POR", self.mine, dict(what="weaver")), "gain", "Built"),
            (("investment_done", "POR", self.mine, dict(level=2)), "own", "Upgraded"),
            (("colony_founded", "POR", self.mine, dict(what="colony")), "own", "Founded"),
            (("colony_founded", "FRA", self.seen, dict(what="colony")), "other", "Colony"),
            (("native_raid", "POR", self.mine, {}), "loss", "Raided!"),
            (("debt_seized", "POR", None, dict(what="castle at X", saving=1)), "loss", "Seized"),
            (("unit_deserted", "POR", None, dict(count=2, kinds={"Pikemen": 2})), "loss", "Deserted"),
            (("money_spent", "POR", self.mine, dict(amount=50, reason="build")), "own", "Building"),
            (("forage", "FRA", self.seen, {}), "other", "Foraged"),
        ]
        for (kind, tag, pos, data), colour, text in cases:
            item, _ = self.one(kind, tag, pos, **data)
            self.assertIsNotNone(item, (kind, text))
            self.assertEqual((item.colour_kind, item.text), (colour, text), kind)
            self.assertEqual(item.kind, kind)
            self.assertEqual(item.pos, pos)
            self.assertEqual(item.season, self.w.turn)
            self.assertTrue(item.sentence.endswith((".", "!")), item.sentence)

    def test_sentences_name_places_and_countries(self):
        item, _ = self.one("battle_ended", "POR", self.mine, attacker="POR", defender="CAS", winner="POR", loser="CAS",
                           name="Battle of Y, 1480", seasons=2, killed={"POR": 300, "CAS": 1200}, how="broke",
                           cause="centre")
        self.assertIn("Battle of Y, 1480 ends: Portugal wins, centre broke after 2 seasons.", item.sentence)
        self.assertIn("Portugal lost 300 men, Castile lost 1,200 men", item.sentence)

    def test_battle_ends_name_the_way_it_was_decided(self):
        cases = [(dict(how="broke", cause="lanes"), "two lanes broke"), (dict(how="broke", cause="morale"), "the army broke"),
                 (dict(how="withdrew"), "the loser withdrew"), (dict(how="surrendered"), "the loser surrendered"),
                 (dict(how="destroyed"), "the loser was destroyed")]
        for extra, words in cases:
            item, _ = self.one("battle_ended", "FRA", self.seen, defender="CAS", winner="FRA", loser="CAS",
                               name="Battle of Y, 1480", seasons=1, killed={}, **extra)
            self.assertIn(f"Battle of Y, 1480 ends: France wins, {words} after 1 season.", item.sentence, extra)

    def test_a_battle_has_a_ribbon_for_the_player_and_war_news_for_the_rest(self):
        ends = {"victory": ("POR", "CAS", "gain", "Victory!"), "defeat": ("CAS", "POR", "loss", "Defeat!"),
                "others won": ("FRA", "CAS", "war", "Battle won"), "draw": (None, None, "war", "Battle over")}
        for label, (winner, loser, colour, text) in ends.items():
            item, _ = self.one("battle_ended", "FRA", self.seen, defender="CAS", winner=winner, loser=loser,
                               how="peace" if winner is None else "withdrew", seasons=1, killed={})
            self.assertEqual((item.colour_kind, item.text), (colour, text), label)
        item, _ = self.one("battle_started", "FRA", self.seen, defender="CAS", assault=True,
                           name="Battle of Y, 1480")
        self.assertEqual(item.sentence, "Battle of Y, 1480 begins: France attacked Castile in its castle.")

    def test_costs_join_the_sentence(self):
        self.feed.clear()
        self.bus.emit("money_spent", "POR", self.mine, amount=36, reason="raise")
        self.assertEqual(sentences(self.w), [])
        self.bus.emit("unit_raised", "POR", self.mine, what="Pikemen", id=1)
        self.assertIn("for 36 ducats", sentences(self.w)[0])

    def test_real_recruit_makes_one_log_line_and_one_floating_text(self):
        self.feed.clear()
        self.w.recruit("POR", self.w.provinces_of("POR")[0], troop("infantry", 1))
        self.assertEqual(len(sentences(self.w)), 1)
        self.assertEqual([f.text for f in self.feed.take_floating()], ["Recruited"])
        self.assertEqual(self.feed.take_floating(), [])

    def test_visibility(self):
        # the other countries' doings are told only inside the player's vision
        self.assertIsNone(self.one("battle_ended", "FRA", self.fog, defender="CAS", winner=None, loser=None)[0])
        self.assertIsNotNone(self.one("battle_ended", "FRA", self.seen, defender="CAS", winner=None, loser=None)[0])
        self.assertIsNone(self.one("forage", "FRA", self.fog)[0])
        self.assertIsNone(self.one("province_captured", "FRA", self.fog, loser="CAS", by="siege")[0])
        # ... but a party is told wherever it is, and the text floats
        item, floating = self.one("battle_ended", "FRA", self.fog, defender="POR", winner=None, loser=None)
        self.assertIsNotNone(item)
        self.assertEqual(len(floating), 1)
        # the AI's recruiting, building and research are never told
        for kind, data in (("unit_raised", dict(what="Pikemen", id=2)), ("building_done", dict(what="weaver")),
                           ("tech_researched", dict(key="x", cost=1)), ("money_spent", dict(amount=1, reason="build"))):
            self.assertIsNone(self.one(kind, "FRA", self.seen, **data)[0], kind)
        self.assertIsNone(self.one("war_declared", "FRA", None, target="CAS")[0])
        # seen but not a party: logged and floated, not "mine"
        item, floating = self.one("battle_ended", "FRA", self.seen, defender="CAS", winner=None, loser=None)
        self.assertFalse(item.mine)
        self.assertEqual(len(floating), 1)

    def test_without_a_player_everything_with_a_place_is_told(self):
        w = fresh(None)
        feed.of(w)
        w.bus.emit("battle_ended", "FRA", w.provinces_of("FRA")[0].pos, defender="CAS", winner=None, loser=None)
        self.assertEqual(len(feed.of(w).entries()), 1)

    def test_siege_lines_only_for_the_players_sieges(self):
        item, floating = self.one("siege_progress", "FRA", self.seen, progress=1, need=4)
        self.assertEqual((item.log, len(floating)), (False, 1))
        self.assertEqual(self.feed.entries(), [])

    def test_passes_once_a_season(self):
        self.feed.clear()
        for _ in range(5):
            self.bus.emit("pass_closed", None, (1, 1), name="p", id=1)
        self.assertEqual(sentences(self.w), ["Winter closes the mountain passes."])

    def test_filters_and_grouping(self):
        self.feed.clear()
        self.bus.emit("battle_ended", "FRA", self.seen, defender="CAS", winner=None, loser=None)
        self.bus.emit("money_spent", "POR", self.mine, amount=5, reason="build")
        self.bus.emit("forage", "FRA", self.seen)
        self.w.turn += 1
        self.bus.emit("siege_progress", "POR", self.mine, progress=1, need=3)
        groups = self.feed.entries()
        self.assertEqual([g[0] for g in groups], [self.w.turn, self.w.turn - 1])       # newest season first
        self.assertEqual(len(groups[1][2]), 3)
        self.assertEqual(groups[1][2][0].kind, "forage")                                # newest line first
        kinds = lambda f: [i.kind for _, _, g in self.feed.entries(f) for i in g]
        self.assertEqual(kinds("war"), ["siege_progress", "battle_ended"])
        self.assertEqual(kinds("money"), ["money_spent"])
        self.assertEqual(kinds("mine"), ["siege_progress", "money_spent"])
        self.assertEqual(self.feed.unread, 4)
        self.feed.mark_read()
        self.assertEqual(self.feed.unread, 0)

    def test_bounded(self):
        self.feed.clear()
        for _ in range(feed.PER_SEASON + 30):
            self.bus.emit("forage", "POR", self.mine)
        self.assertEqual(len(self.feed.groups[self.w.turn]), feed.PER_SEASON)
        self.assertEqual(len(self.feed._floating), feed.FLOATING)
        for _ in range(feed.KEEP_SEASONS + 4):
            self.w.turn += 1
            self.bus.emit("forage", "POR", self.mine)
        self.assertEqual(len(self.feed.groups), feed.KEEP_SEASONS)
        self.assertIn(self.w.turn, self.feed.groups)

    def test_played_seasons_feed_the_log_without_errors(self):
        w = fresh("POR")
        game = GameManager(w)
        for tag in w.neighbours_of("POR"):
            if w.declare_war("POR", tag):
                break
        for _ in range(4):
            game.end_season()
        self.assertEqual(w.bus.tap_errors, [])
        for _, _, items in feed.of(w).entries():
            for item in items:
                self.assertIn(item.colour_kind, feed.COLOUR_KINDS)
                self.assertTrue(item.sentence)


class BattleLogTest(unittest.TestCase):
    """The season's battle line for a real battle: its name, the last day's dice, the lanes broken now (battleview)."""

    def setUp(self):
        from tests.test_battle import plain_battle
        self.w = fresh("POR")
        self.feed = feed.of(self.w)
        self.fight, self.battle = plain_battle(self.w, [("infantry", 1, 3)], [("infantry", 1, 3)])
        self.a, self.d = self.fight.attacker, self.fight.defender
        self.w.player = self.a

    def fought(self, days=1):
        from hexa.campaign.systems import combat
        for _ in range(days):
            combat.fight_day(self.w, self.battle)
        self.w.changed()
        self.feed.clear()
        self.w.bus.emit("battle_fought", self.a, self.battle.pos, defender=self.d, days=days,
                        morale={self.a: 0.5, self.d: 0.4}, killed={self.a: 300, self.d: 900},
                        wounded={self.a: 100, self.d: 0})
        return [i for _, _, items in self.feed.entries() for i in items]

    def test_the_line_names_the_battle_and_gives_the_last_days_dice(self):
        items = self.fought()
        self.assertEqual([(i.kind, i.colour_kind, i.text) for i in items], [("battle_fought", "war", "Fought")])
        sentence = items[0].sentence
        self.assertTrue(sentence.startswith(f"{self.battle.name}, season 1: "), sentence)
        name = {tag: self.w.countries[tag].name for tag in (self.a, self.d)}
        self.assertIn(f"{name[self.a]} lost 300 men (100 wounded), {name[self.d]} lost 900 men (0 wounded).", sentence)
        rolls = [rec for rec in self.battle.log if isinstance(rec, dict) and rec["kind"] == "day"][-1]["rolls"]
        self.assertIn(f"Last day (1): {name[self.a]} rolled {rolls[self.a]}, {name[self.d]} rolled {rolls[self.d]}.",
                      sentence)

    def test_a_broken_lane_is_named_in_the_line(self):
        self.battle.broken[self.d] = [0]
        sentence = self.fought()[0].sentence
        self.assertIn(f"{self.w.countries[self.d].name} lost its left lane.", sentence)
        self.assertNotIn(f"{self.w.countries[self.a].name} lost its", sentence)

    def test_a_battle_the_player_only_watches_has_no_line(self):
        self.w.player = next(t for t in self.w.countries if t not in (self.a, self.d) and self.w.countries[t].alive)
        self.assertEqual(self.fought(), [])


class NoticeTest(unittest.TestCase):
    """The message lines that have no event of their own reach the action log (feed.NOTICES)."""

    def setUp(self):
        self.w = fresh("POR")
        self.game = GameManager(self.w)
        self.feed = self.game.feed

    def kinds(self, filter="all"):
        return [i.kind for _, _, items in self.feed.entries(filter) for i in items]

    def test_every_notice_becomes_a_log_line(self):
        for name, (colour, keyword) in feed.NOTICES.items():
            with self.subTest(notice=name):
                self.w.message(f"A line of the kind {name}.", "POR", name)
        self.assertEqual(sorted(self.kinds("mine")), sorted(list(feed.NOTICES) + ["start"]), "and the first line")
        for _, _, items in self.feed.entries():
            for item in items:
                self.assertFalse(item.floating, "a notice is a log line only")
                self.assertIn(item.sentence, self.w.log)

    def test_the_season_and_credit_lines_are_money(self):
        self.w.message("Treasury line.", None, "treasury")
        self.w.message("Credit line.", "POR", "credit")
        self.w.message("Idea line.", "POR", "idea")
        self.assertEqual(sorted(self.kinds("money")), ["credit", "treasury"])

    def test_a_line_for_another_country_is_not_told(self):
        self.w.message("Their idea.", "CAS", "idea")
        self.assertEqual(self.kinds(), ["start"], "only the first line")

    def test_a_played_season_tells_its_treasury_line(self):
        self.game.end_season()
        lines = [i.sentence for _, _, items in self.feed.entries("money") for i in items if i.kind == "treasury"]
        self.assertEqual(len(lines), 1)
        self.assertIn("Treasury", lines[0])
        self.assertEqual(lines[0], self.w.log[-1])

    def test_the_start_line_is_in_a_new_games_log(self):
        self.assertEqual(self.kinds(), ["start"])
        self.assertIn("age of discovery begins", self.feed.entries()[0][2][0].sentence)

    def test_a_place_makes_the_line_a_link(self):
        pos = self.w.provinces_of("POR")[0].pos
        self.w.message("Grew.", "POR", "growth", pos)
        item = self.feed.entries()[0][2][0]
        self.assertEqual((item.kind, item.pos), ("growth", pos))

    def test_every_message_call_of_the_rules_names_a_notice_or_has_an_event(self):
        """A new world.message(...) with no event of its own must name a notice, or the action log never shows it. The
        lines an event already tells (listed by a piece of their text) are the exception."""
        covered = ("disbands", "declared war on you", "Unpaid troops desert", "Creditors seize", "Natives raided",
                   "has grown into a {", "is finished", "finished.", "started ", "upgraded to", "raised {", "refitted",
                   "Researched ", "you can now raise", "foraged", "founded a", "declared war on {", "War: ",
                   "Peace between", "overran", "took control", "text + ")
        root = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hexa", "campaign")
        missing = []
        for name in ("world.py", "app.py", "ai.py"):
            with open(os.path.join(root, name), encoding="utf-8") as f:
                tree = ast.parse(f.read())
            for node in ast.walk(tree):
                if isinstance(node, ast.Call) and getattr(node.func, "attr", "") == "message" and node.args:
                    text = ast.unparse(node.args[0])
                    named = len(node.args) > 2 or any(k.arg == "notice" for k in node.keywords)
                    if not named and not any(piece in text for piece in covered):
                        missing.append(f"{name}:{node.lineno} {text[:60]}")
        self.assertEqual(missing, [], "these messages reach only world.log; name a notice or emit an event")
        for name in ("world.py", "app.py"):
            with open(os.path.join(root, name), encoding="utf-8") as f:
                for node in ast.walk(ast.parse(f.read())):
                    if isinstance(node, ast.Call) and getattr(node.func, "attr", "") == "message":
                        for kw in node.keywords:
                            if kw.arg == "notice":
                                self.assertIn(ast.literal_eval(kw.value), feed.NOTICES)
                        if len(node.args) > 2 and isinstance(node.args[2], ast.Constant):
                            self.assertIn(node.args[2].value, feed.NOTICES)


class FloatingAgeTest(unittest.TestCase):
    def test_what_is_older_than_the_limit_is_not_floated(self):
        w = fresh("POR")
        game = GameManager(w)
        pos = w.provinces_of("POR")[0].pos
        with mock.patch.object(feed.time, "monotonic", return_value=100.0):
            w.bus.emit("unit_raised", "POR", pos, what="Pikemen", id=1)
        with mock.patch.object(feed.time, "monotonic", return_value=101.0):
            w.bus.emit("unit_raised", "POR", pos, what="Knights", id=2)
        with mock.patch.object(feed.time, "monotonic", return_value=102.5):
            fresh_only = game.feed.take_floating(max_age=2.0)
        self.assertEqual(len(fresh_only), 1)
        self.assertEqual(game.feed.take_floating(), [], "the queue is empty after a take")

    def test_without_a_limit_everything_is_floated(self):
        w = fresh("POR")
        game = GameManager(w)
        pos = w.provinces_of("POR")[0].pos
        w.bus.emit("unit_raised", "POR", pos, what="Pikemen", id=1)
        self.assertEqual(len(game.feed.take_floating()), 1)


if __name__ == "__main__":
    unittest.main()
