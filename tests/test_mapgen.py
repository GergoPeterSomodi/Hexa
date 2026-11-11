"""Map generation tests: wave function collapse, rivers, roads and random worlds.
Run with:  python -m unittest discover -s tests -t ."""
import random
import unittest
from collections import deque

from hexa.campaign import geo, wfc
from hexa.campaign.data import TERRAIN, troop
from hexa.campaign.world import FORBIDDEN, CampaignWorld
from hexa.hexgrid import neighbors

EUROPE = CampaignWorld()


class CollapseTest(unittest.TestCase):
    def test_forbidden_pairs_never_touch_when_avoidable(self):
        cells = [(c, r) for c in range(20) for r in range(20)]
        prior = {p: {"a": 1.0, "b": 1.0, "c": 1.0} for p in cells}
        fixed = {(0, 0): "a", (19, 19): "c"}
        out = wfc.collapse(cells, prior, [("a", "c")], neighbors, random.Random(1), fixed=fixed)
        self.assertEqual(set(out), set(cells))
        self.assertEqual(out[(0, 0)], "a")
        clashes = [(p, n) for p in cells for n in neighbors(p) if n in out and {out[p], out[n]} == {"a", "c"}]
        self.assertFalse(clashes)

    def test_like_clumps_with_like(self):
        cells = [(c, r) for c in range(30) for r in range(30)]
        prior = {p: {"a": 1.0, "b": 1.0} for p in cells}
        out = wfc.collapse(cells, prior, [], neighbors, random.Random(2), affinity=3.0)
        same = sum(out[p] == out[n] for p in cells for n in neighbors(p) if n in out)
        pairs = sum(1 for p in cells for n in neighbors(p) if n in out)
        self.assertGreater(same / pairs, 0.6, "more alike neighbours than a coin flip")


class EuropeMapTest(unittest.TestCase):
    def test_the_map_is_finer(self):
        self.assertEqual(geo.SCALE, 2)
        self.assertGreater(len(EUROPE.provinces), 12000)

    def test_terrain_follows_the_rules(self):
        w = EUROPE
        bad = 0
        for pos, t in w.terrain.items():
            for n in neighbors(pos):
                if (t, w.terrain.get(n)) in FORBIDDEN:
                    bad += 1
        self.assertLess(bad / len(w.provinces), 0.01, "almost no forbidden neighbours")
        kinds = {p.terrain for p in w.provinces.values()}
        self.assertTrue({"marsh", "taiga", "savanna", "beach", "snow"} <= kinds, kinds)
        self.assertEqual(w.terrain[geo.hex_of(9.5, 46.5)], "mountains", "the Alps")
        self.assertIn(w.terrain[geo.hex_of(-1, 25)], ("desert", "steppe"), "the Sahara")

    def test_rivers_run_through_land(self):
        w = EUROPE
        for name in ("Rhine", "Danube", "Nile", "Mississippi"):
            path = w.rivers[name]
            self.assertGreater(len(path), 8, name)
            self.assertTrue(all(w.is_land(p) for p in path), name)
            self.assertTrue(all(b in neighbors(a) for a, b in zip(path, path[1:])), f"{name} is unbroken")

    def test_roads_join_towns_and_speed_up_armies(self):
        w = CampaignWorld(player="FRA")
        self.assertGreater(len(w.road_paths), 50)
        paris = w.countries["FRA"].capital
        self.assertIn(paris, w.roads)
        a, b = next((a, b) for path in w.road_paths for a, b in zip(path, path[1:])
                    if TERRAIN[w.terrain[b]].move > 1 and w.provinces[a].owner == w.provinces[b].owner == "FRA")
        self.assertEqual(w.step_cost(a, b), 1)
        w.units = []
        stack = [w._add_unit(troop("infantry", 1), "FRA", a, moves=troop("infantry", 1).moves)]
        self.assertIn(b, w.reachable_group(stack))


class WalkingTest(unittest.TestCase):
    def test_moves_walk_the_route_and_clear_fog_on_the_way(self):
        from hexa.hexgrid import distance
        w = CampaignWorld(player="POR")
        ship = next(u for u in w.units_of("POR") if u.naval)
        reach = w.reachable_group([ship])
        unknown = [p for p in reach if p not in w.countries["POR"].explored]
        self.assertTrue(unknown, "the caravel can sail into the black fog")
        dest = max(unknown, key=lambda p: (distance(p, ship.pos), p))
        start = ship.pos
        path = w.route([ship], dest)
        self.assertEqual((path[0], path[-1]), (start, dest))
        self.assertTrue(all(b in neighbors(a) for a, b in zip(path, path[1:])), "one hex at a time")
        self.assertTrue(w.move_group([ship], dest))
        self.assertEqual(ship.pos, dest)
        explored = w.countries["POR"].explored
        self.assertTrue(all(p in explored for p in path), "every hex of the route was seen")
        self.assertEqual(w.last_move, ([ship.id], path))
        # armies walk too
        army = [u for u in w.units_of("POR") if u.kind.war]
        stack = [u for u in army if u.pos == army[0].pos]
        reach = w.reachable_group(stack)
        far = max(reach, key=lambda p: (reach[p], p))
        path = w.route(stack, far)
        self.assertTrue(all(b in neighbors(a) for a, b in zip(path, path[1:])))
        self.assertTrue(w.move_group(stack, far))
        self.assertTrue(all(u.pos == far for u in stack))

    def test_a_move_searches_its_path_once_and_looks_around_once_per_step(self):
        from unittest import mock
        w = CampaignWorld(player="POR")
        army = [u for u in w.units_of("POR") if u.kind.war]
        stack = [u for u in army if u.pos == army[0].pos]
        reach = w.reachable_group(stack)
        far = max(reach, key=lambda p: (reach[p], p))
        with mock.patch.object(w, "plan", wraps=w.plan) as plan,                 mock.patch.object(w, "see_from", wraps=w.see_from) as see:
            self.assertTrue(w.move_group(stack, far))
        self.assertEqual(plan.call_count, 1, "reach and route share one search")
        path = w.last_move[1]
        self.assertEqual(see.call_count, len(path) - 2 + len(stack))
        self.assertTrue(all(p in w.countries["POR"].explored for p in path))

    def test_a_land_army_next_to_a_ship_does_not_search_the_whole_map(self):
        from unittest import mock
        w = CampaignWorld(player="POR")
        ship = next(u for u in w.units_of("POR") if u.naval)
        army = next(u for u in w.units_of("POR") if u.kind.war and not u.naval and not u.carrier
                    and any(w.is_sea(n) for n in neighbors(u.pos)))
        stack = [u for u in w.units_at(army.pos) if u.owner == "POR"]
        for passenger in w.cargo(ship):
            passenger.carrier = None
            passenger.pos = army.pos
        ship.pos = next(n for n in neighbors(army.pos) if w.is_sea(n))
        reach = w.reachable_group(stack)
        self.assertIn(ship.pos, reach, "the army could board the ship")
        goal = w.countries["CAS"].capital
        full = w.cost_field(goal)
        with mock.patch.object(w, "cost_field", wraps=w.cost_field) as cost:
            w.step_toward_group(stack, goal)
        until = cost.call_args.kwargs["until"]
        self.assertTrue(all(w.is_land(p) for p in until), "only hexes a land field can settle")
        self.assertLess(len(w.cost_field(goal, until=until)), len(full), "the search stops early")


class RandomWorldTest(unittest.TestCase):
    def test_a_random_world_is_playable(self):
        w = CampaignWorld(11, map="random")
        self.assertTrue(w.geo.name.startswith("Random world"))
        self.assertGreaterEqual(len(w.countries), 25)
        for tag, country in w.countries.items():
            self.assertEqual(w.provinces[country.capital].owner, tag)
            self.assertGreater(w.army_strength(tag), 0)
        oceans = {w.sea_body[p] for p in w.terrain if w.terrain[p] == "ocean"}
        biggest = max(oceans, key=lambda b: sum(1 for v in w.sea_body.values() if v == b))
        self.assertTrue(w.colonial)
        for tag in w.colonial:
            ports = [p for p in w.provinces_of(tag) if p.level("port")]
            self.assertTrue(ports, tag)
        new_world = [p for p in w.provinces.values() if geo.lonlat(p.pos)[0] < -60]
        self.assertTrue(new_world and all(p.owner is None for p in new_world), "an unclaimed New World")
        self.assertTrue(any(w.sea_body.get(n) == biggest for p in new_world for n in neighbors(p.pos)))
        self.assertTrue(w.rivers and w.markets)

    def test_the_same_seed_gives_the_same_world_and_others_differ(self):
        a, b = CampaignWorld(3, map="random"), CampaignWorld(3, map="random")
        c = CampaignWorld(4, map="random")
        self.assertEqual(a.terrain, b.terrain)
        self.assertNotEqual(a.terrain, c.terrain)

    def test_ai_runs_on_a_random_world(self):
        from hexa.campaign import ai
        w = CampaignWorld(5, map="random")
        for _ in range(6):
            for tag in w.countries:
                ai.run(w, tag)
            w.end_round()
        for unit in w.units:
            if unit.carrier is None:
                self.assertTrue(w.is_sea(unit.pos) if unit.naval else w.is_land(unit.pos))


def _connected(cells):
    cells = set(cells)
    start = next(iter(cells))
    seen, queue = {start}, deque([start])
    while queue:
        for n in neighbors(queue.popleft()):
            if n in cells and n not in seen:
                seen.add(n)
                queue.append(n)
    return len(seen) == len(cells)


if __name__ == "__main__":
    unittest.main()
