"""The event bus (hexa/events.py) and the events the campaign world emits. Pygame-free.

Run with: python -m unittest tests.test_events
"""
import pickle
import unittest

from hexa import events
from hexa.campaign import tech
from hexa.campaign.data import COLONIST, troop
from hexa.campaign.systems import battle as battlesys
from hexa.campaign.world import CampaignWorld, Unit
from hexa.events import CAMPAIGN_KINDS, Event, EventBus
from hexa.hexgrid import neighbors
from tests.support.worlds import fresh


class BusTest(unittest.TestCase):
    def test_emit_queues_and_records_history(self):
        bus = EventBus()
        event = bus.emit("battle_started", "POR", (3, 4), defender="ESP")
        self.assertEqual(event, Event("battle_started", "POR", (3, 4), {"defender": "ESP"}))
        self.assertEqual(event.get("defender"), "ESP")
        self.assertIsNone(event.get("nothing"))
        self.assertEqual(list(bus.queue), [event])
        self.assertEqual(list(bus.history), [event])

    def test_drain_dispatches_oldest_first_and_empties_the_queue(self):
        bus, seen = EventBus(), []
        bus.subscribe("a", lambda e: seen.append(("a", e.tag)))
        bus.subscribe(None, lambda e: seen.append(("all", e.kind)))
        bus.emit("a", 1)
        bus.emit("b", 2)
        bus.emit("a", 3)
        self.assertEqual(seen, [], "nothing is delivered before the drain")
        done = bus.drain()
        self.assertEqual([e.tag for e in done], [1, 2, 3])
        self.assertEqual(seen, [("a", 1), ("all", "a"), ("all", "b"), ("a", 3), ("all", "a")])
        self.assertEqual(bus.drain(), [])
        self.assertEqual(len(bus.history), 3, "the history outlives the drain")

    def test_events_a_handler_emits_wait_for_the_next_drain(self):
        bus, seen = EventBus(), []
        bus.subscribe("a", lambda e: bus.emit("b"))
        bus.subscribe("b", lambda e: seen.append("b"))
        bus.emit("a")
        bus.drain()
        self.assertEqual(seen, [])
        bus.drain()
        self.assertEqual(seen, ["b"])

    def test_unsubscribe(self):
        bus, seen = EventBus(), []
        handler = bus.subscribe("a", seen.append)
        bus.unsubscribe("a", handler)
        bus.unsubscribe("a", handler)           # twice is fine
        bus.emit("a")
        bus.drain()
        self.assertEqual(seen, [])

    def test_a_raising_handler_leaves_the_later_events_queued(self):
        bus = EventBus()

        def boom(event):
            raise RuntimeError("x")
        bus.subscribe("a", boom)
        bus.emit("a")
        bus.emit("b")
        with self.assertRaises(RuntimeError):
            bus.drain()
        self.assertEqual([e.kind for e in bus.queue], ["b"])

    def test_history_and_queue_are_bounded(self):
        bus = EventBus(history=3)
        for i in range(5):
            bus.emit("a", i)
        self.assertEqual([e.tag for e in bus.history], [2, 3, 4])
        bus.QUEUE = 2
        bus.emit("a", 5)
        self.assertEqual([e.tag for e in bus.queue], [4, 5])
        self.assertEqual(bus.dropped, 4)

    def test_of_and_clear(self):
        bus = EventBus()
        bus.emit("a")
        bus.emit("b")
        self.assertEqual([e.kind for e in bus.of("b")], ["b"])
        bus.clear()
        self.assertEqual((len(bus.queue), len(bus.history)), (0, 0))


class WorldBusTest(unittest.TestCase):
    """Every event kind of the campaign is emitted where the state changes, with the fields the module lists."""

    def setUp(self):
        self.w = fresh("POR")
        self.w.bus.clear()

    def kinds(self, kind):
        return self.w.bus.of(kind)

    def one(self, kind):
        found = self.kinds(kind)
        self.assertEqual(len(found), 1, f"{kind}: {[e.kind for e in self.w.bus.history]}")
        return found[0]

    def neighbour(self, tag="POR"):
        w = self.w
        return sorted(t for t in w.neighbours_of(tag) if t != tag and w.countries[t].alive)[0]

    def test_a_few_seasons_only_emit_listed_kinds(self):
        from tests.support.worlds import play_seasons
        play_seasons(self.w, 6)
        kinds = {e.kind for e in self.w.bus.history}
        self.assertTrue(kinds <= set(CAMPAIGN_KINDS), kinds - set(CAMPAIGN_KINDS))
        self.assertIn("season_ended", kinds)

    def test_kind_message(self):
        self.w.message("hello", "POR")
        self.w.message("secret", "FRA")
        first, second = self.kinds("message")
        self.assertEqual((first.tag, first.get("text"), first.get("shown")), ("POR", "hello", True))
        self.assertFalse(second.get("shown"))
        self.assertIn("hello", self.w.log)
        self.assertNotIn("secret", self.w.log)

    def test_kind_war_declared(self):
        enemy = self.neighbour()
        self.assertTrue(self.w.declare_war(enemy, "POR"))
        event = self.one("war_declared")
        self.assertEqual((event.tag, event.get("target")), (enemy, "POR"))

    def test_kind_peace_made(self):
        enemy = self.neighbour()
        self.w.declare_war("POR", enemy)
        self.w.peace("POR", enemy)
        event = self.one("peace_made")
        self.assertEqual((event.tag, event.get("b"), event.get("moved")), ("POR", enemy, 0))

    def test_kind_province_captured_by_peace(self):
        w = self.w
        enemy = self.neighbour()
        w.declare_war("POR", enemy)
        prov = w.provinces_of(enemy)[0]
        prov.controller = "POR"
        w.peace("POR", enemy, winner="POR")
        event = self.kinds("province_captured")[0]
        self.assertEqual((event.tag, event.pos, event.get("loser"), event.get("by")), ("POR", prov.pos, enemy, "peace"))
        self.assertEqual(prov.owner, "POR")

    def test_kind_province_captured_and_siege_progress(self):
        w = self.w
        enemy = self.neighbour()
        w.declare_war("POR", enemy)
        prov = next(p for p in w.provinces_of(enemy) if not p.castle)
        w.units[:] = [u for u in w.units if u.pos != prov.pos]
        troops = Unit(9001, troop("infantry", 1), "POR", prov.pos, hp=10)
        w.units.append(troops)
        for _ in range(12):
            w.sieges()
            if prov.controller == "POR":
                break
        progress = self.kinds("siege_progress")
        self.assertTrue(progress)
        self.assertEqual((progress[0].tag, progress[0].pos), ("POR", prov.pos))
        self.assertGreaterEqual(progress[-1].get("progress"), progress[-1].get("need"))
        event = self.one("province_captured")
        self.assertEqual((event.tag, event.pos, event.get("loser"), event.get("by")), ("POR", prov.pos, enemy, "siege"))

    def test_kind_battle(self):
        w = self.w
        enemy = self.neighbour()
        w.declare_war("POR", enemy)
        prov = next(p for p in w.provinces_of(enemy) if not p.castle)
        w.units[:] = [u for u in w.units if u.pos != prov.pos]
        foe = Unit(9002, troop("infantry", 1), enemy, prov.pos, hp=10)
        mine = Unit(9003, troop("infantry", 1), "POR", prov.pos, hp=10)
        w.units += [foe, mine]
        mine.pos, mine.moves_left = next(n for n in sorted(neighbors(prov.pos)) if w.is_land(n)), 2
        w.attack_group([mine], prov.pos)
        event = self.one("battle_started")
        self.assertEqual((event.tag, event.pos, event.get("defender"), event.get("assault")), ("POR", prov.pos, enemy, False))
        self.assertTrue(event.get("name").startswith("Battle of "), event.get("name"))

    def test_kind_unit_raised(self):
        w = self.w
        prov = next(p for p in w.provinces_of("POR") if w.recruit_check("POR", p, troop("infantry", 1))[0])
        unit = w.recruit("POR", prov, troop("infantry", 1))
        event = self.one("unit_raised")
        self.assertEqual((event.tag, event.pos, event.get("id")), ("POR", unit.pos, unit.id))

    def test_kind_unit_lost(self):
        w = self.w
        unit = w.units_of("POR")[0]
        w._kill(unit)
        w._kill(unit)                       # already gone: no second event
        event = self.one("unit_lost")
        self.assertEqual((event.tag, event.pos, event.get("what")), ("POR", unit.pos, unit.kind.name))

    def test_unit_lost_says_why(self):
        w = self.w
        enemy = self.neighbour()
        w.declare_war("POR", enemy)
        prov = next(p for p in w.provinces_of(enemy) if not p.castle)
        w.units[:] = [u for u in w.units if u.pos != prov.pos]
        here = Unit(9010, COLONIST, enemy, prov.pos)
        w.units.append(here)
        mine = Unit(9011, troop("infantry", 1), "POR", w.countries["POR"].capital, hp=10)
        w.units.append(mine)
        mine.pos, mine.moves_left = next(n for n in sorted(neighbors(prov.pos)) if w.is_land(n)), 2
        w.attack_group([mine], prov.pos)     # only an unarmed colonist defends: overrun
        lost = self.kinds("unit_lost")
        self.assertEqual([(e.tag, e.get("why")) for e in lost], [(enemy, "overrun")])
        self.assertNotIn(here, w.units)

    def test_unit_lost_by_storm_and_disbanding(self):
        w = self.w
        foe = self.neighbour()
        w.declare_war("POR", foe)
        prov = next(p for p in w.provinces_of(foe) if not p.castle)
        w.units[:] = [u for u in w.units if u.pos != prov.pos]
        weak = Unit(9012, troop("infantry", 1), foe, prov.pos, hp=1)
        home = w.countries["POR"].capital
        strong = [Unit(9013 + i, troop("infantry", 1), "POR", home, hp=40) for i in range(3)]
        w.units += [weak] + strong
        for unit in strong:
            unit.pos, unit.moves_left = next(n for n in sorted(neighbors(prov.pos)) if w.is_land(n)), 2
        w.attack_group(strong, prov.pos)
        for _ in range(2):                               # the battle is fought to its end in one battles phase (0.2.1)
            if w.battle_at(prov.pos) is None:
                break
            battlesys.battle_season(w)
        whys = {e.get("why") for e in self.kinds("unit_lost") if e.tag == foe}
        self.assertTrue(whys <= {"battle", "storm"} and whys, whys)
        w.bus.clear()
        w.disband("POR", 1e9)
        self.assertEqual({e.get("why") for e in self.kinds("unit_lost")}, {"disbanded"})

    def test_kind_unit_deserted_and_debt_seized(self):
        w = self.w
        country = w.countries["POR"]
        country.treasury = -10_000_000
        country.income = {"upkeep": -500.0}
        for prov in w.provinces_of("POR"):
            prov.castle = max(prov.castle, 1)
        w._unpaid()
        gone = self.kinds("unit_deserted")
        self.assertTrue(gone)
        self.assertEqual(gone[0].tag, "POR")
        self.assertGreater(gone[0].get("count"), 0)
        self.assertTrue(self.kinds("debt_seized"))
        self.assertEqual(self.kinds("debt_seized")[0].tag, "POR")

    def test_kind_pass_closed_and_opened(self):
        w = self.w
        w.turn = 3                          # the round ends into turn 4, a winter
        w.end_round()
        closed = self.kinds("pass_closed")
        self.assertTrue(closed)
        self.assertEqual({e.get("name") for e in closed}, {p[0] for p in w.pass_edges()})
        self.assertFalse(self.kinds("pass_opened"))
        w.bus.clear()
        w.end_round()                       # turn 5, spring
        self.assertEqual(len(self.kinds("pass_opened")), len(closed))
        self.assertFalse(self.kinds("pass_closed"))
        w.bus.clear()
        w.end_round()                       # no change of winter
        self.assertFalse(self.kinds("pass_opened") or self.kinds("pass_closed"))

    def test_kind_tech_researched(self):
        w = self.w
        country = w.countries["POR"]
        key = next(k for k in tech.available(country.techs, country.era))
        country.researching, country.research = key, 10 ** 6
        w._finish_research("POR")
        event = self.kinds("tech_researched")[0]
        self.assertEqual((event.tag, event.get("key")), ("POR", key))

    def test_kind_era_reached(self):
        w = self.w
        before = w.countries["POR"].era
        w._new_age("POR")
        event = self.one("era_reached")
        self.assertEqual((event.tag, event.get("era")), ("POR", before + 1))

    def test_kind_colony_founded(self):
        w = self.w
        spot = next(p for p in w.provinces.values() if p.owner is None and p.terrain != "desert" and w.in_old_world(p.pos))
        unit = Unit(9004, COLONIST, "POR", spot.pos, moves_left=1)
        w.units.append(unit)
        self.assertTrue(w.found(unit))
        event = self.one("colony_founded")
        self.assertEqual((event.tag, event.pos, event.get("what")), ("POR", spot.pos, "colony"))

    def test_kind_building_done_and_investment_done(self):
        w = self.w
        prov = w.provinces_of("POR")[0]
        prov.queue.append(["marketplace", 1])
        w.grow()
        event = self.one("building_done")
        self.assertEqual((event.tag, event.pos, event.get("what")), ("POR", prov.pos, "marketplace"))
        prov.works = 0
        w.countries["POR"].treasury = 10 ** 7
        invest = next((p for p in w.provinces_of("POR") if w.invest_check("POR", p)[0]), None)
        self.assertIsNotNone(invest)
        self.assertTrue(w.invest("POR", invest))
        event = self.one("investment_done")
        self.assertEqual((event.tag, event.pos, event.get("level")), ("POR", invest.pos, invest.works))


class SaveTest(unittest.TestCase):
    def test_the_bus_is_not_saved(self):
        w = fresh("POR")
        w.message("x", "POR")
        self.assertIn("bus", vars(w))
        state = w.save_state()
        self.assertNotIn("bus", state)
        data = pickle.dumps(state)
        self.assertNotIn(b"EventBus", data)
        self.assertNotIn(b"hexa.events", data)

    def test_a_loaded_world_has_a_fresh_empty_bus(self):
        w = fresh("POR")
        w.message("x", "POR")
        loaded = CampaignWorld.from_state(pickle.loads(pickle.dumps(w.save_state())))
        self.assertIsInstance(loaded.bus, EventBus)
        self.assertEqual(len(loaded.bus.history), 0)
        self.assertIsNot(loaded.bus, w.bus)
        loaded.message("y", "POR")
        self.assertEqual(len(loaded.bus.history), 1)

    def test_an_old_save_without_a_bus_loads(self):
        state = fresh("POR").save_state()
        state.pop("bus", None)
        self.assertIsInstance(CampaignWorld.from_state(state).bus, EventBus)

    def test_a_new_world_starts_with_an_empty_bus(self):
        self.assertEqual(len(CampaignWorld(player="POR").bus.history), 0)
        self.assertEqual(len(CampaignWorld(player="POR").bus.history), 0)      # built, then restored

    def test_a_new_world_from_the_snapshot_has_its_own_bus(self):
        a, b = CampaignWorld(player="POR"), CampaignWorld(player="POR")
        self.assertIsNot(a.bus, b.bus)


class ModuleTest(unittest.TestCase):
    def test_the_events_module_is_pygame_free(self):
        with open(events.__file__, encoding="utf-8") as f:
            self.assertNotIn("pygame", f.read())


if __name__ == "__main__":
    unittest.main()
