"""Ridge crests and mountain passes (campaign world rule). Every hex can be entered, but the edge between two hexes
on opposite sides of a ridge crest (geo.MOUNTAINS) cannot be crossed, except at a pass: the passes are open in summer
and shut by snow in winter. Covers ridge_edges, pass_edges, edge_blocked, move_check, movement, routes, AI pathing,
ships, roads, ZOC, random worlds, old saves, and the app's reason and grid toggle. Headless. Run with:
    python -m unittest tests.test_passes"""
import os
import pickle
import shutil
import tempfile
import unittest
from collections import deque

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

try:
    import pygame  # noqa: E402
except ImportError:                     # the unit suite runs without pygame (the CI unit job): skip the module
    if os.environ.get("HEXA_REQUIRE_PYGAME") == "1":     # ... unless pygame tests must run (the ui job)
        raise
    raise unittest.SkipTest("pygame is not installed (HEXA_REQUIRE_PYGAME=1 makes this an error)") from None

from hexa.campaign import ai, geo  # noqa: E402
from hexa.campaign.app import CampaignApp  # noqa: E402
from hexa.campaign.data import CARAVEL, troop  # noqa: E402
from hexa.campaign.world import CampaignWorld, War  # noqa: E402
from hexa.hexgrid import distance, neighbors  # noqa: E402

GOTTHARD = geo.hex_of(8.56, 46.56)          # (149, 44) on the Europe map, next to the pass edge
PASS_N = (150, 44)                          # the Gotthard pass edge joins these two hexes: this one is Swiss
PASS_S = (149, 45)                          # ... and this one is Milan's
SUMMER, WINTER = 2, 4                       # data.date: turn 4 is Winter, turn 2 is Summer
REASON = "The Gotthard pass is closed by snow until spring."
RIDGE_REASON = "Nobody can cross the ridge here; armies need a pass."


def fresh(seed=1480, map="europe"):
    """A new world (the snapshot cache makes this cheap); safe to mutate."""
    return CampaignWorld(seed, map=map)


def infantry(world, pos, owner="SWI", moves=None):
    kind = troop("infantry", 1)
    return world._add_unit(kind, owner, pos, moves=kind.moves if moves is None else moves)


def land_of(w):
    return {p for p in w.terrain if w.is_land(p)}


def reach(start, land, walls, inside=None):
    """The hexes a walker reaches from start over `land` without taking a step in `walls`."""
    seen = {start}
    queue = deque([start])
    while queue:
        cur = queue.popleft()
        for n in neighbors(cur):
            if n in land and n not in seen and (cur, n) not in walls and (inside is None or n in inside):
                seen.add(n)
                queue.append(n)
    return seen


def pieces_per_landmass(w):
    """{landmass number: set of pieces}: the landmass cut by the ridges and passes shut (summer: passes open)."""
    land, walls = land_of(w), w._pass_data()[4]

    def label(blocked):
        ids, count = {}, 0
        for p in sorted(land):
            if p not in ids:
                count += 1
                for q in reach(p, land, blocked):
                    ids[q] = count
        return ids
    whole, flat = label(frozenset()), label(walls)
    found = {}
    for p in land:
        found.setdefault(whole[p], set()).add(flat[p])
    return found


class PassRuleTest(unittest.TestCase):
    def test_gotthard_is_closed_in_winter_only(self):
        w = fresh()
        self.assertEqual(w.pass_name(PASS_N), "Gotthard")
        self.assertEqual(w._pass_data()[2][frozenset((PASS_N, PASS_S))][0], "Gotthard")
        w.turn = WINTER
        self.assertTrue(w.winter())
        self.assertTrue(w.pass_closed(PASS_N))
        self.assertTrue(w.edge_blocked(PASS_N, PASS_S))
        w.turn = SUMMER
        self.assertFalse(w.winter())
        self.assertFalse(w.pass_closed(PASS_N))
        self.assertFalse(w.edge_blocked(PASS_N, PASS_S))
        self.assertTrue(w.pass_closed(PASS_N, winter=True))        # an explicit season overrides the turn
        self.assertTrue(w.edge_blocked(PASS_N, PASS_S, winter=True))

    def test_pass_edges_and_ridge_edges_for_the_map_art(self):
        w = fresh()
        passes = w.pass_edges()
        self.assertTrue(passes)
        names = {name for name, pid, edge, closed in passes}
        for name in ("Gotthard", "Brenner", "Mont Cenis", "Simplon", "Great St Bernard", "Roncesvalles"):
            self.assertIn(name, names)
        for name, pid, edge, closed in passes:
            a, b = sorted(edge)
            self.assertIn(b, neighbors(a))
            self.assertTrue(w.is_land(a) and w.is_land(b))
            self.assertFalse(closed)                               # turn 1 is spring
            self.assertNotIn(edge, w.ridge_edges())
        w.turn = WINTER
        self.assertTrue(all(closed for _, _, _, closed in w.pass_edges()))
        for edge in w.ridge_edges():
            self.assertIsInstance(edge, frozenset)
            a, b = sorted(edge)
            self.assertIn(b, neighbors(a))
        # a pass has a name and an id, and names are unique to a pass
        by_name = {}
        for name, pid, edge, closed in passes:
            by_name.setdefault(name, set()).add(pid)
        self.assertTrue(all(len(v) == 1 for v in by_name.values()), by_name)

    def test_land_unit_cannot_cross_the_pass_in_winter_and_is_told_why(self):
        w = fresh()
        w.provinces[PASS_S].owner = "SWI"
        w.turn = WINTER
        unit = infantry(w, PASS_N)
        self.assertEqual(w.move_check([unit], PASS_S), (False, REASON))
        self.assertFalse(w.may_enter(unit, PASS_S))
        self.assertNotIn(PASS_S, w.reachable(unit))
        self.assertNotIn(PASS_S, w.plan([unit], 99))
        self.assertFalse(w.move_group([unit], PASS_S))
        self.assertEqual(unit.pos, PASS_N)
        self.assertEqual(w.step_cost(PASS_N, PASS_S), float("inf"))

    def test_land_unit_can_cross_the_pass_in_summer(self):
        w = fresh()
        w.provinces[PASS_S].owner = "SWI"
        w.turn = SUMMER
        unit = infantry(w, PASS_N, moves=99)
        self.assertEqual(w.move_check([unit], PASS_S), (True, ""))
        self.assertTrue(w.may_enter(unit, PASS_S))
        self.assertIn(PASS_S, w.plan([unit], 99))
        self.assertTrue(w.move_group([unit], PASS_S))
        self.assertEqual(unit.pos, PASS_S)

    def test_a_ridge_crest_is_never_crossable_but_every_hex_can_be_entered(self):
        w = fresh()
        w.turn = SUMMER
        a, b = sorted(next(iter(sorted(w.ridge_edges(), key=sorted))))
        for pos in (a, b):
            w.provinces[pos].owner = "SWI"
        w.units = [u for u in w.units if u.pos not in (a, b)]
        unit = infantry(w, a, moves=99)
        self.assertEqual(w.move_check([unit], b), (False, RIDGE_REASON))
        self.assertFalse(w.may_enter(unit, b))
        self.assertEqual(w.step_cost(a, b), float("inf"))
        self.assertFalse(w.move_group([unit], b))
        self.assertEqual(unit.pos, a)
        # hexes stay open: the unit can stand on both sides, and on mountains and snow
        for pos in (a, b):
            self.assertTrue(w.can_stand([unit], pos))
        other = infantry(w, b, moves=99)
        self.assertEqual(other.pos, b)

    def test_a_swiss_army_walks_into_the_alpine_valleys(self):
        w = fresh()
        w.turn = SUMMER
        unit = infantry(w, w.countries["SWI"].capital, moves=99)
        found = w.plan([unit], 99)
        high = [p for p in found if w.terrain[p] in ("mountains", "snow")]
        self.assertGreaterEqual(len(high), 5)
        w.turn = WINTER                                           # nothing is stranded in winter either
        self.assertGreaterEqual(len([p for p in w.plan([unit], 99) if w.terrain[p] in ("mountains", "snow")]), 5)

    def test_unit_beside_the_pass_stays_free_in_winter(self):
        w = fresh()
        w.turn = WINTER
        unit = infantry(w, PASS_N, moves=99)
        free = [n for n in neighbors(PASS_N) if n != PASS_S and not w.edge_blocked(PASS_N, n)]
        self.assertTrue(free)
        self.assertTrue(any(n in w.plan([unit], 99) for n in free if w.may_enter(unit, n)))

    def test_winter_closes_the_pass_and_the_way_round_is_long(self):
        w = fresh()
        zurich, milan = geo.hex_of(8.55, 47.37), geo.hex_of(9.19, 45.46)
        w.turn = SUMMER
        summer = w.cost_field(milan)[zurich]
        w.turn = WINTER
        winter = w.cost_field(milan).get(zurich)
        self.assertTrue(winter is None or winter - summer > 5, (summer, winter))
        for a, b in ((geo.hex_of(11.58, 48.14), geo.hex_of(10.99, 45.44)),          # Munich to Verona, the Brenner
                     (geo.hex_of(-1.47, 43.5), geo.hex_of(-1.64, 42.8))):           # Bayonne to Pamplona
            w.turn = SUMMER
            summer = w.cost_field(b)[a]
            w.turn = WINTER
            winter = w.cost_field(b).get(a)
            self.assertTrue(winter is None or winter - summer > 5, (summer, winter))

    def test_route_goes_around_the_pass_in_winter(self):
        w = fresh()
        w.provinces[PASS_S].owner = "SWI"
        w.turn = WINTER
        unit = infantry(w, PASS_N, moves=99)
        goal = (150, 46)
        w.provinces[goal].owner = "SWI"
        w.units = [u for u in w.units if u.pos != goal]
        path = w.route([unit], goal)
        self.assertEqual(path[0], PASS_N)
        for a, b in zip(path, path[1:]):
            self.assertFalse(w.edge_blocked(a, b), (a, b))

    def test_ai_pathing_never_steps_across_a_shut_edge(self):
        w = fresh()
        w.turn = WINTER
        unit = infantry(w, PASS_N, moves=99)
        for goal in (PASS_S, (149, 46), (150, 46)):
            step = w.step_toward_group([unit], goal)
            self.assertFalse(distance(step, unit.pos) == 1 and w.edge_blocked(unit.pos, step), goal)
        original = w.move_group
        crossed = []

        def guarded(group, dest, *args, **kwargs):
            ok = original(group, dest, *args, **kwargs)
            if ok and not group[0].naval and w.last_move:
                path = w.last_move[1]
                crossed.extend((a, b) for a, b in zip(path, path[1:]) if w.edge_blocked(a, b))
            return ok
        w.move_group = guarded
        for tag in ("SWI", "MLO", "SAV", "FRA"):
            if tag in w.countries:
                ai.run(w, tag)
        self.assertEqual(crossed, [])

    def test_a_winter_march_waits_for_spring_instead_of_a_long_detour(self):
        w = fresh()
        w.provinces[PASS_S].owner = "SWI"
        w.units = [u for u in w.units if u.pos not in (PASS_N, PASS_S)]
        unit = infantry(w, PASS_N, moves=99)
        w.turn = SUMMER
        self.assertEqual(w.pass_wait([unit], PASS_S), "")
        w.turn = WINTER
        self.assertEqual(w.pass_wait([unit], PASS_S), "Gotthard")
        self.assertEqual(w.pass_blocks([unit], PASS_S), "Gotthard")
        self.assertFalse(w.move_toward_group([unit], PASS_S))
        self.assertEqual(unit.pos, PASS_N, "it did not walk off on the long way round")
        w.turn = WINTER + 4
        self.assertEqual(w.pass_wait([unit], (150, 43)), "")              # a goal this side of the ridge: no waiting
        w.turn = SUMMER + 4
        self.assertTrue(w.move_toward_group([unit], PASS_S))
        self.assertEqual(unit.pos, PASS_S)

    def test_the_ai_does_not_march_behind_a_closed_pass_in_winter(self):
        w = fresh()
        w.turn = WINTER
        w.provinces[PASS_S].owner = "SWI"
        w.units = [u for u in w.units if u.pos not in (PASS_N, PASS_S)]
        unit = infantry(w, PASS_N, moves=99)
        before = unit.pos
        w.move_toward_group([unit], PASS_S)
        self.assertEqual(unit.pos, before)

    def test_a_recruit_never_appears_across_a_crest_and_support_stops_at_it(self):
        w = fresh()
        a, b = sorted(next(iter(sorted(w.ridge_edges(), key=sorted))))
        tag = "SWI"
        for pos in (a, b):
            w.provinces[pos].owner = w.provinces[pos].controller = tag
        w.units = [u for u in w.units if u.pos not in (a, b)]
        kind = troop("infantry", 1)
        real = w.can_stand
        w.can_stand = lambda group, pos, others=None: pos != a and real(group, pos, others)    # province a is full
        self.assertNotEqual(w._land_spot(tag, w.provinces[a], kind), b)
        w.can_stand = real
        walls = w._walls()
        self.assertTrue(w._within_reach(a, a))
        self.assertFalse(w._within_reach(a, b))                       # next to each other, but a crest between them
        self.assertTrue((a, b) in walls)
        free = next(n for n in neighbors(a) if (a, n) not in walls)
        self.assertTrue(w._within_reach(a, free))

    def test_ships_are_not_affected(self):
        w = fresh()
        w.turn = WINTER
        ship = w._add_unit(CARAVEL, "SWI", (10, 0), moves=CARAVEL.moves)
        self.assertEqual(w.move_check([ship], (11, 0)), (True, ""))
        self.assertTrue(w.may_enter(ship, (11, 0)))
        self.assertIn((11, 0), w.plan([ship], 3))

    def test_roads_and_zoc_do_not_cross_a_ridge(self):
        w = fresh()
        walls = w._pass_data()[4]
        for path in w.road_paths:
            for a, b in zip(path, path[1:]):
                self.assertNotIn((a, b), walls)
        w.turn = SUMMER
        for prov in w.provinces.values():
            prov.garrison = 0
        a, b = sorted(next(iter(sorted(w.ridge_edges(), key=sorted))))
        owner = w.provinces[a].owner or next(iter(w.countries))
        enemy = next(t for t in w.countries if t != owner)
        w.wars.append(War(enemy, owner, 1))
        prov = w.provinces[a]
        prov.owner = prov.controller = owner
        prov.castle, prov.garrison = 1, 10
        w._castle_list = None
        zoc = w.zoc(enemy)
        self.assertNotIn(b, zoc)
        self.assertTrue(set(neighbors(a)) - {b} - set(n for n in neighbors(a) if (a, n) in walls) <= zoc)

    def test_random_worlds_do_not_crash(self):
        for seed in (5, 9):
            w = fresh(seed, map="random")
            land = [p for p in w.terrain if w.is_land(p)][:40]
            for turn in (WINTER, SUMMER):
                w.turn = turn
                self.assertIsInstance(w.passes(), dict)
                for pos in land:
                    self.assertEqual(w.pass_closed(pos), turn == WINTER and pos in w.passes())
                unit = infantry(w, land[0], owner=next(iter(w.countries)))
                w.plan([unit], 12)
                w.move_check([unit], land[1])


class RidgeTest(unittest.TestCase):
    """The crest of every ridge is a continuous wall, with gaps only at the passes."""

    def test_the_share_of_blocked_edges_is_small(self):
        w = fresh()
        land = land_of(w)
        total = sum(1 for a in land for b in neighbors(a) if b in land and a < b)
        crest = len(w.ridge_edges()) + len(w.pass_edges())
        self.assertGreater(crest, 200)
        self.assertLess(crest / total, 0.03)

    def test_it_is_deterministic(self):
        first = fresh().ridge_edges()
        again = fresh()
        again._pass_cache = None                                      # rebuilt from the geography
        self.assertEqual(again.ridge_edges(), first)

    def test_no_route_crosses_the_central_alps_except_through_a_pass(self):
        w = fresh()
        # west of 13 E and north of 44.6 N: the ridge ends near 15 E and at the Riviera, where you can walk round it
        land = {p for p in land_of(w) if geo.lonlat(p)[0] <= 13.0 and geo.lonlat(p)[1] >= 44.6}
        summer, winter = w._pass_data()[4], w._pass_data()[5]
        for a, b in (((8.55, 47.37), (9.19, 45.46)), ((11.58, 48.14), (12.34, 45.44))):
            ha, hb = geo.hex_of(*a), geo.hex_of(*b)
            self.assertIn(hb, reach(ha, land, summer), "summer: no way through the passes")
            self.assertNotIn(hb, reach(ha, land, winter), "winter: the shut passes leave no way through")
            ridge_only = frozenset(p for e in w.ridge_edges() for x, y in (sorted(e),) for p in ((x, y), (y, x)))
            self.assertEqual(ridge_only, summer)

    def test_the_crest_has_no_leaks_along_any_ridge(self):
        """Walk a short way either side of every ridge hex: with the passes shut you cannot get across."""
        w = fresh()
        land, winter = land_of(w), w._pass_data()[5]
        pass_hexes = set(w.passes())
        checked = 0
        for line in w.geo.MOUNTAINS:
            pts = [w._unit_point(*p) for p in line]
            length = sum(((x1 - x0) ** 2 + (y1 - y0) ** 2) ** 0.5 for (x0, y0), (x1, y1) in zip(pts, pts[1:]))
            if length < 10:
                continue
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                seg = ((x1 - x0) ** 2 + (y1 - y0) ** 2) ** 0.5
                nx, ny = -(y1 - y0) / seg, (x1 - x0) / seg
                for k in range(int(seg)):
                    t = (k + 0.5) / int(seg)
                    cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                    if min(((cx - x) ** 2 + (cy - y) ** 2) ** 0.5 for x, y in (pts[0], pts[-1])) < 5:
                        continue                        # a ridge end: the way round it is open by design
                    ends = []
                    for sign in (1, -1):
                        px, py = cx + nx * 0.9 * sign, cy + ny * 0.9 * sign
                        ends.append(geo.hex_of(geo.LON0 + px * geo.COL_DEG, geo.inv_merc(geo.Y_TOP - py * geo.COL_DEG)))
                    a, b = ends
                    if a == b or a not in land or b not in land:
                        continue
                    centre = geo.hex_of(geo.LON0 + cx * geo.COL_DEG, geo.inv_merc(geo.Y_TOP - cy * geo.COL_DEG))
                    window = {p for p in land if distance(p, centre) <= 3}
                    if any(p in pass_hexes for p in window):
                        continue
                    checked += 1
                    self.assertNotIn(b, reach(a, land, winter, inside=window), (line[0], a, b))
        self.assertGreater(checked, 30)

    def test_every_walled_edge_is_crossed_an_odd_number_of_times_by_a_ridge(self):
        """A ridge that bends round an edge crosses it twice and does not separate its hexes: that edge is not walled."""
        for seed, map in ((1480, "europe"), (7, "random")):
            w = fresh(seed, map)
            for edge in set(w.ridge_edges()) | {e for _, _, e, _ in w.pass_edges()}:
                (ax, ay), (bx, by) = (w._unit_centre(p) for p in sorted(edge))
                odd = False
                for line in w.geo.MOUNTAINS:
                    pts = [w._unit_point(lon, lat) for lon, lat in line]
                    shift = (1.3e-6, 2.1e-6)
                    n = sum(w._cross(x0 + shift[0], y0 + shift[1], x1 + shift[0], y1 + shift[1], ax, ay, bx, by)
                            for (x0, y0), (x1, y1) in zip(pts, pts[1:]))
                    odd = odd or n % 2 == 1
                self.assertTrue(odd, (seed, sorted(edge)))

    def test_the_edge_cache_is_keyed_on_the_geography(self):
        w = fresh()
        key = w._pass_data()[0]
        self.assertEqual(key[0], 4)
        state = pickle.loads(pickle.dumps(w.save_state()))
        state["_pass_cache"] = (("x", "other geography"), frozenset(), {}, {}, frozenset(), frozenset())
        self.assertEqual(CampaignWorld.from_state(state).ridge_edges(), w.ridge_edges())
        self.assertNotEqual(fresh(5, "random")._pass_data()[0], key)

    def test_every_landmass_stays_in_one_piece_in_summer(self):
        for seed, map in ((1480, "europe"), (2, "random"), (5, "random"), (7, "random")):
            per_land = pieces_per_landmass(fresh(seed, map))
            self.assertTrue(all(len(v) == 1 for v in per_land.values()), (seed, per_land))

    def test_geo_passes_sit_on_the_crest_with_one_or_two_edges_and_unique_names(self):
        w = fresh()
        for k, (name, lon, lat) in enumerate(geo.PASSES, 1):
            edges = [e for n, pid, e, c in w.pass_edges() if pid == k]
            self.assertIn(len(edges), (1, 2), name)
            self.assertTrue(all(n == name for n, pid, e, c in w.pass_edges() if pid == k))
        names = [name for name, pid, e, c in w.pass_edges()]
        ids = {}
        for name, pid, e, c in w.pass_edges():
            ids.setdefault(name, set()).add(pid)
        self.assertTrue(all(len(v) == 1 for v in ids.values()), "two passes share a name")
        self.assertNotIn("Mountain", names)

    def test_old_saves_rebuild_their_edges(self):
        w = fresh()
        want = w.ridge_edges()
        state = pickle.loads(pickle.dumps(w.save_state()))
        state["_pass_hexes"] = {GOTTHARD: "Gotthard"}                 # the old one-hex cache
        state.pop("_pass_cache", None)
        loaded = CampaignWorld.from_state(state)
        self.assertNotIn("_pass_hexes", loaded.__dict__)
        self.assertEqual(loaded.ridge_edges(), want)
        state = pickle.loads(pickle.dumps(w.save_state()))
        state["_pass_cache"] = (2, frozenset(), {})                    # a cache of an older pass rule
        self.assertEqual(CampaignWorld.from_state(state).ridge_edges(), want)
        self.assertTrue(all(w.is_land(u.pos) for u in loaded.units if not u.naval))


class RandomPassTest(unittest.TestCase):
    """Random worlds get ridge crests and passes of their own (randomgeo), named and fixed per seed."""

    def test_seeds_5_7_9_have_passes_and_crests(self):
        for seed in (5, 7, 9):
            w = fresh(seed, map="random")
            self.assertGreaterEqual(len(w.passes()), 1, seed)
            self.assertGreater(len(w.ridge_edges()), 50, seed)
            for pos, name in w.passes().items():
                self.assertTrue(w.is_land(pos), (seed, name))
                self.assertTrue(name, seed)

    def test_passes_are_deterministic_per_seed(self):
        from hexa.campaign import randomgeo
        first = randomgeo.generate(5).PASSES
        self.assertEqual(first, randomgeo.generate(5).PASSES)
        self.assertNotEqual(first, randomgeo.generate(7).PASSES)

    def test_random_pass_blocks_land_units_in_winter_only(self):
        w = fresh(5, map="random")
        name, pid, edge, _ = w.pass_edges()[0]
        a, b = sorted(edge)
        owner = next(iter(w.countries))
        for pos in (a, b):
            w.provinces[pos].owner = owner
        w.units = [u for u in w.units if u.pos not in (a, b)]
        w.turn = WINTER
        unit = infantry(w, a, owner=owner, moves=99)
        ok, reason = w.move_check([unit], b)
        self.assertFalse(ok)
        self.assertIn(name, reason)
        self.assertFalse(w.may_enter(unit, b))
        w.turn = SUMMER
        self.assertTrue(w.move_check([unit], b)[0])
        self.assertTrue(w.may_enter(unit, b))


class AiRunsTest(unittest.TestCase):
    """The AI plays on with ridge crests: no exceptions, and no march ever steps across a blocked edge."""

    def run_seasons(self, seed, map, seasons):
        w = fresh(seed, map)
        w.player = None
        original = w.move_group
        crossed = []

        def guarded(group, dest, *args, **kwargs):
            season = w.winter()
            ok = original(group, dest, *args, **kwargs)
            if ok and not group[0].naval and w.last_move:
                path = w.last_move[1]
                crossed.extend((w.date(), a, b) for a, b in zip(path, path[1:])
                               if (a, b) in w._pass_data()[5 if season else 4])
            return ok
        w.move_group = guarded
        for _ in range(seasons):
            for tag in list(w.countries):
                ai.run(w, tag)
            w.end_round()
        self.assertEqual(crossed, [], (map, seed))

    def test_europe_ai_for_a_few_years(self):
        self.run_seasons(1480, "europe", 16)

    def test_random_world_ai_for_a_few_years(self):
        self.run_seasons(7, "random", 16)


class AppTest(unittest.TestCase):
    """The app's reason on a closed pass, the hover card, and the G key."""

    @classmethod
    def setUpClass(cls):
        pygame.init()

    def setUp(self):
        self.home_dir = tempfile.mkdtemp(prefix="hexa_passes_")
        self.old_home = os.environ.get("HEXA_HOME")
        os.environ["HEXA_HOME"] = self.home_dir
        self.app = CampaignApp(player="SWI")

    def tearDown(self):
        if self.old_home is None:
            os.environ.pop("HEXA_HOME", None)
        else:
            os.environ["HEXA_HOME"] = self.old_home
        shutil.rmtree(self.home_dir, ignore_errors=True)

    def test_hover_card_says_closed_in_winter(self):
        app = self.app
        app.world.turn = WINTER
        lines = app.province_card(PASS_N)[1]
        self.assertIn("The Gotthard pass (to the south-west) is closed by snow until spring", [text for text, _ in lines])
        app.world.turn = SUMMER
        lines = app.province_card(PASS_N)[1]
        self.assertFalse([text for text, _ in lines if "closed by snow" in text])

    def test_right_click_across_a_closed_pass_gives_the_reason_and_does_not_move(self):
        app, w = self.app, self.app.world
        w.turn = WINTER
        w.provinces[PASS_S].owner = "SWI"
        w.units = [u for u in w.units if u.pos != PASS_S]
        unit = infantry(w, PASS_N, moves=99)
        w.changed()
        app.select_unit(unit)
        cx, cy = app.view.center(PASS_S)
        vr = app.view_rect()
        app.right_click((vr.x + cx - app.camera[0], vr.y + cy - app.camera[1]))
        self.assertEqual(app.ui.toast, REASON)
        self.assertEqual(unit.pos, PASS_N)

    def test_a_march_behind_the_closed_pass_waits_and_says_so(self):
        app, w = self.app, self.app.world
        w.turn = WINTER
        w.provinces[PASS_S].owner = "SWI"
        w.units = [u for u in w.units if u.pos not in (PASS_N, PASS_S)]
        unit = infantry(w, PASS_N, moves=99)
        unit.goal = PASS_S
        app.ui.toast = ""
        app.continue_march([unit])
        self.assertEqual(unit.pos, PASS_N)
        self.assertEqual(unit.goal, PASS_S)
        self.assertEqual(app.ui.toast, "The Gotthard pass is closed by snow; the march waits for spring.")

    def test_g_key_toggles_the_grid_and_it_is_saved(self):
        app = self.app
        start = app.settings["grid"]
        app.handle(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_g, mod=0, unicode="g", scancode=0))
        self.assertEqual(app.settings["grid"], not start)
        app.handle(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_g, mod=0, unicode="g", scancode=0))
        self.assertEqual(app.settings["grid"], start)


if __name__ == "__main__":
    unittest.main()
