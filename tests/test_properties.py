"""Property tests for all three game modes: determinism, save/load continuation, check/action agreement and the
world invariants of tests/support/invariants.py.

    Determinism   the same seed gives the same game in two processes with different PYTHONHASHSEED values
    Save/load     a campaign saved and loaded plays on exactly like the original
    Agreement     a seeded random player tries every x_check / x pair, legal and illegal (tests/support/agents.py):
                  a refused action changes nothing, an allowed one succeeds
    Invariants    checked after every turn of those same random games

Random games: HEXA_PROP_GAMES per mode (default 20) with seeds HEXA_PROP_SEED, HEXA_PROP_SEED + 1, ... (default 0).
Conquest games run to the end, Colonisation games COLONY_ROUNDS rounds, campaign games CAMPAIGN_SEASONS seasons.
A failing game prints its seed, its first problem and a command that replays only that game, e.g.

    HEXA_PROP_SEED=7 HEXA_PROP_GAMES=1 python3 -m unittest tests.test_properties.ColonyGamesTest

Open bugs these properties catch are pinned in KnownBugsTest as expectedFailure tests.
Needs no pygame. Run with:  python3 -m unittest tests.test_properties
"""
import contextlib
import math
import os
import random
import subprocess
import sys
import traceback
import unittest
from collections import Counter
from unittest import mock

from hexa.campaign import geo, saves
from hexa.campaign.data import CARAVEL, GARRISON_HP, STACK_LIMIT, troop
from hexa.campaign.world import War
from hexa.colony.rules import (BRAVE, CRIMSON, CROWN, GOAL_ENDLESS, GOAL_INDEPENDENCE, GOAL_SURVIVE, MAX_POP,
                               NATIVES, PLAYER as C_PLAYER, REGULAR, SCOUT as C_SCOUT, SHIP, SOLDIER as C_SOLDIER,
                               START_LAND, START_SEA, TENSION_PEACE, TENSION_WAR)
from hexa.colony.world import Colony, ColonyWorld
from hexa.hexgrid import distance, neighbors, within
from hexa.rules import AI, PLAYER, SCOUT, SOLDIER, TURN_LIMIT
from hexa.world import World
from tests.support.agents import Judge, campaign_player, colony_player, conquest_player
from tests.support.digests import canonical, quick_digest, world_digest
from tests.support.games import play_colony, play_conquest
from tests.support.home import TempHome
from tests.support.invariants import (KNOWN_OPEN, campaign_problems, check_campaign, check_colony, check_conquest,
                                      colony_problems, conquest_problems, known_open)
from tests.support.slow import slow
from tests.support.worlds import fresh, play_seasons

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES = int(os.environ.get("HEXA_PROP_GAMES", "20"))
BASE_SEED = int(os.environ.get("HEXA_PROP_SEED", "0"))
COLONY_ROUNDS = 10              # Colonisation games last this many rounds (every side moves once a round)
CAMPAIGN_SEASONS = 3            # campaign games last this many seasons
CAMPAIGN_DIGESTED = 5           # every 5th campaign game also digests the world around refused actions (40 ms each)


class BrokenMixin:
    def assertBroken(self, check, world, name):
        """check(world) must fail, and one of the broken invariants it lists must be `name`."""
        with self.assertRaises(AssertionError) as caught:
            check(world)
        lines = str(caught.exception).splitlines()[1:]
        self.assertTrue(any(line.startswith(name + ":") for line in lines),
                        f"expected a broken {name!r} invariant, got:\n{caught.exception}")


# ----- the invariant checkers themselves ----------------------------------------------------------------------
class ConquestInvariantsTest(BrokenMixin, unittest.TestCase):
    def setUp(self):
        self.w = World(7)

    def unit(self, side=PLAYER, kind=None):
        return next(u for u in self.w.units if u.owner == side and (kind is None or u.type is kind))

    def test_a_new_game_passes(self):
        for seed in range(5):
            check_conquest(World(seed))

    def test_checking_changes_nothing(self):
        before = world_digest(self.w)
        check_conquest(self.w)
        self.assertEqual(world_digest(self.w), before)

    def test_units_stand_on_passable_land(self):
        lake = next((p for p, t in self.w.terrain.items() if t in ("water", "mountain")), None)
        self.unit().pos = lake if lake else (99, 99)
        self.assertBroken(check_conquest, self.w, "unit-hex")

    def test_units_off_the_map(self):
        self.unit().pos = (-3, 40)
        self.assertBroken(check_conquest, self.w, "unit-hex")

    def test_one_unit_per_hex(self):
        self.unit(PLAYER, SCOUT).pos = self.unit(PLAYER, SOLDIER).pos
        self.assertBroken(check_conquest, self.w, "one-unit-per-hex")

    def test_hp_stays_within_range(self):
        for hp in (0, -2, SOLDIER.max_hp + 1):
            self.unit(PLAYER, SOLDIER).hp = hp
            self.assertBroken(check_conquest, self.w, "unit-hp")

    def test_moves_stay_within_range(self):
        self.unit().moves_left = -1
        self.assertBroken(check_conquest, self.w, "unit-moves")

    def test_units_belong_to_a_side(self):
        self.unit().owner = "martians"
        self.assertBroken(check_conquest, self.w, "unit-owner")

    def test_unit_ids_are_unique(self):
        self.unit(PLAYER).id = self.unit(AI).id
        self.assertBroken(check_conquest, self.w, "unit-id")

    def test_stock_is_whole_and_never_negative(self):
        for value in (-1, 2.5, None):
            self.w.stock[AI]["wood"] = value
            self.assertBroken(check_conquest, self.w, "stock")
        self.w.stock[AI] = {"food": 1, "wood": 1}
        self.assertBroken(check_conquest, self.w, "stock")

    def test_towns_stand_on_land_one_per_hex(self):
        self.w.towns[1].pos = self.w.towns[0].pos
        self.assertBroken(check_conquest, self.w, "town-hex")

    def test_each_side_keeps_one_castle_until_the_end(self):
        self.w.capital_of(AI).capital = False
        self.assertBroken(check_conquest, self.w, "capital")
        self.w.winner, self.w.win_reason = PLAYER, "test"
        check_conquest(self.w)

    def test_buildings_match_their_terrain_and_never_sit_under_a_town(self):
        forest = next(p for p, t in self.w.terrain.items() if t == "forest")
        self.w.improvements[forest] = "farm"
        self.assertBroken(check_conquest, self.w, "improvement")
        del self.w.improvements[forest]
        self.w.improvements[self.w.capital_of(PLAYER).pos] = "farm"
        self.assertBroken(check_conquest, self.w, "improvement")

    def test_turn_and_side_to_move(self):
        self.w.turn = TURN_LIMIT + 1
        self.assertBroken(check_conquest, self.w, "turn")
        self.w.turn, self.w.current = 3, "nobody"
        self.assertBroken(check_conquest, self.w, "turn")

    def test_time_never_runs_backwards(self):
        self.w.turn = 5
        check_conquest(self.w)
        self.w.turn = 4
        self.assertBroken(check_conquest, self.w, "turn")

    def test_winner(self):
        self.w.winner, self.w.win_reason = "martians", "test"
        self.assertBroken(check_conquest, self.w, "winner")
        self.w.winner, self.w.win_reason = AI, ""
        self.assertBroken(check_conquest, self.w, "winner")

    def test_fog(self):
        self.w.visible.add((99, 99))
        self.assertBroken(check_conquest, self.w, "fog")

    def test_the_message_lists_every_broken_invariant(self):
        self.unit().hp = 0
        self.w.stock[PLAYER]["food"] = -1
        with self.assertRaises(AssertionError) as caught:
            check_conquest(self.w)
        text = str(caught.exception)
        self.assertIn("2 Conquest invariant(s) broken", text)
        self.assertIn("unit-hp:", text)
        self.assertIn("stock:", text)


class ColonyInvariantsTest(BrokenMixin, unittest.TestCase):
    def setUp(self):
        self.w = ColonyWorld(5, START_LAND)

    def unit(self, side=C_PLAYER, kind=None):
        return next(u for u in self.w.units if u.owner == side and (kind is None or u.type is kind))

    def ocean(self):
        return next(p for p in sorted(self.w.terrain) if self.w.is_ocean(p) and self.w.unit_at(p) is None)

    def test_new_games_pass(self):
        for seed, start in ((1, START_SEA), (2, START_LAND), (3, START_SEA)):
            check_colony(ColonyWorld(seed, start))
        check_colony(ColonyWorld(4, START_SEA, GOAL_INDEPENDENCE))

    def test_checking_changes_nothing(self):
        before = world_digest(self.w)
        check_colony(self.w)
        self.assertEqual(world_digest(self.w), before)

    def test_land_units_on_land_and_ships_at_sea(self):
        self.unit(C_PLAYER, C_SOLDIER).pos = self.ocean()
        self.assertBroken(check_colony, self.w, "unit-hex")
        w = ColonyWorld(5, START_LAND)
        ship = next(u for u in w.units if u.type is SHIP and u.owner == C_PLAYER)
        ship.pos = w.capital_of(C_PLAYER).pos
        self.assertBroken(check_colony, w, "unit-hex")

    def test_ship_cargo_within_capacity(self):
        w = ColonyWorld(5, START_SEA)
        ship = next(u for u in w.units if u.type is SHIP and u.owner == C_PLAYER)
        check_colony(w)
        for _ in range(SHIP.capacity + 1 - len(w.cargo(ship))):
            w._new_unit(C_SOLDIER, C_PLAYER, ship.pos, carrier=ship)
        self.assertBroken(check_colony, w, "cargo")

    def test_passengers_ride_a_living_ship_of_their_own_side(self):
        w = ColonyWorld(5, START_SEA)
        ship = next(u for u in w.units if u.type is SHIP and u.owner == C_PLAYER)
        w.units.remove(ship)
        self.assertBroken(check_colony, w, "cargo")
        w = ColonyWorld(5, START_SEA)
        passenger = next(u for u in w.units if u.carrier is not None)
        passenger.pos = (0, 0)
        self.assertBroken(check_colony, w, "cargo")

    def test_one_unit_per_hex(self):
        self.unit(C_PLAYER, C_SOLDIER).pos = self.unit(CRIMSON, C_SOLDIER).pos
        self.assertBroken(check_colony, self.w, "one-unit-per-hex")

    def test_hp_and_moves(self):
        self.unit().hp = 0
        self.assertBroken(check_colony, self.w, "unit-hp")
        self.w = ColonyWorld(5, START_LAND)
        self.unit().moves_left = 99
        self.assertBroken(check_colony, self.w, "unit-moves")

    def test_units_match_their_side(self):
        self.unit(NATIVES, BRAVE).owner = C_PLAYER
        self.assertBroken(check_colony, self.w, "unit-owner")
        self.w = ColonyWorld(5, START_LAND)
        self.unit(NATIVES, BRAVE).home = None
        self.assertBroken(check_colony, self.w, "unit-owner")

    def test_stock_and_favour(self):
        self.w.stock[CRIMSON]["gold"] = -3
        self.assertBroken(check_colony, self.w, "stock")
        self.w = ColonyWorld(5, START_LAND)
        self.w.favour[C_PLAYER] = -1
        self.assertBroken(check_colony, self.w, "favour")

    def test_colonies(self):
        colony = self.w.capital_of(C_PLAYER)
        for pop in (0, MAX_POP + 1):
            colony.pop = pop
            self.assertBroken(check_colony, self.w, "colony-pop")
        colony.pop = 2
        colony.pos = self.ocean()
        self.assertBroken(check_colony, self.w, "colony-hex")
        colony.pos = self.w.capital_of(CRIMSON).pos
        self.assertBroken(check_colony, self.w, "colony-hex")

    def test_colony_owners_and_capitals(self):
        self.w.capital_of(CRIMSON).owner = NATIVES
        self.assertBroken(check_colony, self.w, "colony-owner")
        self.w = ColonyWorld(5, START_LAND)
        self.w.capital_of(CRIMSON).capital = False
        self.assertBroken(check_colony, self.w, "colony-capital")

    def test_tension_and_war_go_together(self):
        self.w.tension[0][C_PLAYER] = TENSION_WAR + 51
        self.assertBroken(check_colony, self.w, "tension")
        self.w.tension[0][C_PLAYER] = TENSION_WAR
        self.assertBroken(check_colony, self.w, "tension")
        self.w.tension[0][C_PLAYER] = TENSION_PEACE - 1
        self.w.war[0].add(C_PLAYER)
        self.assertBroken(check_colony, self.w, "tension")

    def test_buildings(self):
        forest = next(p for p, t in self.w.terrain.items() if t == "forest")
        self.w.improvements[forest] = "farm"
        self.assertBroken(check_colony, self.w, "improvement")
        del self.w.improvements[forest]
        self.w.improvements[self.w.capital_of(C_PLAYER).pos] = "farm"
        self.assertBroken(check_colony, self.w, "improvement")

    def test_turn_winner_and_dead_sides(self):
        self.w.turn = 41
        self.assertBroken(check_colony, self.w, "turn")
        self.w = ColonyWorld(5, START_LAND)
        self.w.winner = NATIVES
        self.assertBroken(check_colony, self.w, "winner")
        self.w = ColonyWorld(5, START_LAND)
        self.w.dead.add(CRIMSON)
        self.assertBroken(check_colony, self.w, "dead")

    def test_sides_out_of_the_game_leave_no_units_while_it_goes_on(self):
        for colony in self.w.colonies_of(CRIMSON):
            self.w.colonies.remove(colony)
        self.w.dead.add(CRIMSON)                       # eliminated: no colony and no colonist left
        self.assertBroken(check_colony, self.w, "dead-side-units")
        self.w.winner = C_PLAYER
        check_colony(self.w)

    def test_time_never_runs_backwards(self):
        self.w.turn = 6
        check_colony(self.w)
        self.w.turn = 5
        self.assertBroken(check_colony, self.w, "turn")

    def test_independence(self):
        self.w.declared = 1
        self.assertBroken(check_colony, self.w, "independence")
        self.w = ColonyWorld(5, START_LAND)
        self.w.royal_waves = 1
        self.assertBroken(check_colony, self.w, "independence")
        self.w = ColonyWorld(5, START_LAND)
        self.w._new_unit(REGULAR, CROWN, self.unit().pos)
        self.assertBroken(check_colony, self.w, "independence")

    def test_fog(self):
        self.w.visible.add((-5, -5))
        self.assertBroken(check_colony, self.w, "fog")


class CampaignInvariantsTest(BrokenMixin, unittest.TestCase):
    def setUp(self):
        self.w = fresh()

    def army(self, tag="POR"):
        return [u for u in self.w.units if u.owner == tag and u.kind.war and u.carrier is None]

    def sea(self):
        return next(p for p in sorted(self.w.terrain) if self.w.is_sea(p) and not self.w.units_at(p))

    def test_a_new_world_passes(self):
        check_campaign(self.w)
        check_campaign(fresh(None))

    def test_checking_changes_nothing(self):
        before = quick_digest(self.w)
        check_campaign(self.w)
        self.assertEqual(quick_digest(self.w), before)

    def test_one_country_per_hex(self):
        self.army("CAS")[0].pos = self.army("POR")[0].pos
        self.assertBroken(check_campaign, self.w, "one-country-per-hex")

    def test_stacks_keep_to_the_limit(self):
        pos = self.army()[0].pos
        for _ in range(STACK_LIMIT[1] + 1):
            self.w._add_unit(troop("infantry", 1), "POR", pos)
        self.assertBroken(check_campaign, self.w, "stack-limit")

    def test_armies_on_land_and_ships_at_sea(self):
        self.army()[0].pos = self.sea()
        self.assertBroken(check_campaign, self.w, "unit-hex")
        w = fresh()
        ship = next(u for u in w.units if u.naval)
        ship.pos = w.countries[ship.owner].capital
        self.assertBroken(check_campaign, w, "unit-hex")

    def test_cargo_within_capacity(self):
        ship = next(u for u in self.w.units if u.naval)
        for _ in range(ship.kind.capacity + 1):
            self.w._add_unit(troop("infantry", 1), ship.owner, ship.pos).carrier = ship
        self.assertBroken(check_campaign, self.w, "cargo")

    def test_passengers_need_a_ship(self):
        soldier = self.army()[0]
        soldier.carrier = next(u for u in self.w.units if u.owner == "CAS" and u.kind.war)
        self.assertBroken(check_campaign, self.w, "cargo")

    def test_hp_moves_and_ids(self):
        # one world, one more corruption each time: every new kind must show up in the list
        self.army()[0].hp = 0
        self.assertBroken(check_campaign, self.w, "unit-hp")
        unit = self.army("CAS")[0]
        unit.moves_left = unit.kind.moves + 1
        self.assertBroken(check_campaign, self.w, "unit-moves")
        self.w.units[3].id = self.w.units[2].id
        self.assertBroken(check_campaign, self.w, "unit-id")

    def test_units_belong_to_living_countries(self):
        self.army()[0].owner = "XXX"
        self.assertBroken(check_campaign, self.w, "unit-owner")

    def test_province_owners_are_living_countries(self):
        prov = next(p for p in self.w.provinces.values() if p.owner == "CAS")
        prov.owner = "XXX"
        self.assertBroken(check_campaign, self.w, "province-owner")
        w = fresh()
        empty = next(p for p in w.provinces.values() if p.owner is None)
        empty.controller = "CAS"
        self.assertBroken(check_campaign, w, "province-owner")

    def test_the_ownership_cache_follows_the_owners(self):
        self.w.provinces_of("CAS")                       # fills the cache
        prov = next(p for p in self.w.provinces.values() if p.owner == "CAS" and p.pos != self.w.countries["CAS"].capital)
        prov.owner = prov.controller = "POR"            # without changed(ownership=True)
        self.assertBroken(check_campaign, self.w, "ownership-cache")
        self.w.changed(ownership=True)
        check_campaign(self.w)

    def test_population_garrison_and_treasury(self):
        prov = next(p for p in self.w.provinces.values() if p.owner)
        prov.peasants = -1.0
        self.assertBroken(check_campaign, self.w, "population")
        castle = next(p for p in self.w.provinces.values() if p.castle)
        castle.garrison = castle.castle * GARRISON_HP + 1
        self.assertBroken(check_campaign, self.w, "garrison")
        self.w.countries["POR"].treasury = math.nan
        self.assertBroken(check_campaign, self.w, "treasury")

    def test_capitals_belong_to_their_country(self):
        self.w.countries["POR"].capital = self.w.countries["CAS"].capital
        self.assertBroken(check_campaign, self.w, "capital")

    def test_techs_are_real_techs(self):
        self.w.countries["POR"].techs.add("no_such_tech")
        self.assertBroken(check_campaign, self.w, "tech")
        w = fresh()
        w.countries["CAS"].researching = "no_such_tech"
        self.assertBroken(check_campaign, w, "tech")

    def test_wars(self):
        self.w.wars.append(War("POR", "POR", 1))
        self.assertBroken(check_campaign, self.w, "war")
        w = fresh()
        neighbour = sorted(w.neighbours_of("POR"))[0]
        w.declare_war("POR", neighbour)
        w.wars.append(War(neighbour, "POR", 1))
        self.assertBroken(check_campaign, w, "war")

    def test_prices_stay_between_floor_and_cap(self):
        market = self.w.markets[0]
        market.price["timber"] = 0.01
        self.assertBroken(check_campaign, self.w, "prices")
        w = fresh()
        w.markets[0].price["gold"] = 11.0
        self.assertBroken(check_campaign, w, "prices")

    def test_fog_and_the_end_of_the_game(self):
        self.w.visible.add((-1, -1))
        self.assertBroken(check_campaign, self.w, "fog")
        self.w.over = True
        self.assertBroken(check_campaign, self.w, "over")
        w = fresh(None)
        w.visible = set()
        self.assertBroken(check_campaign, w, "fog")

    def test_time_and_version_never_run_backwards(self):
        self.w.version += 5
        check_campaign(self.w)
        self.w.version -= 1
        self.assertBroken(check_campaign, self.w, "version")
        self.w.turn = 9
        check_campaign(self.w)
        self.w.turn = 8
        self.assertBroken(check_campaign, self.w, "turn")


# ----- digests -------------------------------------------------------------------------------------------------
class DigestTest(TempHome):
    def test_sets_are_unordered_lists_and_dicts_are_not(self):
        self.assertEqual(canonical({"b", "a", "c"}), canonical({"c", "a", "b"}))
        self.assertNotEqual(canonical(["a", "b"]), canonical(["b", "a"]))
        self.assertNotEqual(canonical({"a": 1, "b": 2}), canonical({"b": 2, "a": 1}))
        self.assertNotEqual(canonical([1]), canonical([1.0]))
        self.assertNotEqual(canonical(("1",)), canonical((1,)))

    def test_a_shared_object_is_not_the_same_as_two_copies(self):
        ship = [1]
        self.assertNotEqual(canonical([ship, ship]), canonical([[1], [1]]))
        self.assertEqual(canonical([ship, ship]), canonical([[1]] * 2))

    def test_any_change_to_a_world_changes_both_digests(self):
        for world in (World(3), ColonyWorld(3)):
            before = world_digest(world), quick_digest(world)
            self.assertEqual((world_digest(world), quick_digest(world)), before, "digesting changes nothing")
            world.units[-1].hp -= 1
            after = world_digest(world), quick_digest(world)
            self.assertNotEqual(after[0], before[0])
            self.assertNotEqual(after[1], before[1])

    def test_hash_order_shows_between_processes_but_not_in_the_digest(self):
        """The determinism test can fail: a list made from a set of strings comes out in a different order under
        another PYTHONHASHSEED. canonical() of the set itself stays the same."""
        code = ("from tests.support.digests import canonical\n"
                "s = {f'tag{i}' for i in range(40)}\n"
                "print(canonical(list(s)), canonical(s))")
        out = [_python(["-c", code], hashseed).communicate(timeout=60)[0].split() for hashseed in (0, 1)]
        self.assertNotEqual(out[0][0], out[1][0])
        self.assertEqual(out[0][1], out[1][1])


def _python(args, hashseed):
    """Start `python3 <args>` in the repository with this PYTHONHASHSEED."""
    env = dict(os.environ, PYTHONHASHSEED=str(hashseed))
    return subprocess.Popen([sys.executable] + list(args), cwd=ROOT, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)


# ----- determinism across processes ----------------------------------------------------------------------------
class DeterminismTest(TempHome):
    """The same seed plays the same game whatever PYTHONHASHSEED is, so no outcome depends on set or str-hash
    order. Each check runs tests/support/digest_run.py twice, in parallel."""

    def assertSameUnderHashSeeds(self, mode, seeds, turns=None):
        args = [mode] + [str(s) for s in seeds] + (["--turns", str(turns)] if turns else [])
        runs = {h: _python(["-m", "tests.support.digest_run"] + args, h) for h in (0, 1)}
        out = {h: p.communicate(timeout=600) for h, p in runs.items()}
        for h, p in runs.items():
            self.assertEqual(p.returncode, 0, f"PYTHONHASHSEED={h} digest_run failed:\n{out[h][1]}")
            self.assertEqual(len(out[h][0].splitlines()), len(seeds), out[h][0])
        replay = " ".join(args)
        self.assertEqual(out[0][0], out[1][0],
                         f"{mode}: the same seeds ended differently under two hash seeds\n"
                         f"PYTHONHASHSEED=0:\n{out[0][0]}PYTHONHASHSEED=1:\n{out[1][0]}"
                         f"replay: PYTHONHASHSEED=0 python3 -m tests.support.digest_run {replay}   "
                         f"(and again with PYTHONHASHSEED=1)")

    def test_conquest_games_to_the_end(self):
        self.assertSameUnderHashSeeds("conquest", [0, 1, 3])     # 0 ends by capture, 1 and 3 on the turn limit

    @slow
    def test_colonisation_30_turns(self):
        self.assertSameUnderHashSeeds("colony", [5], 30)

    @slow
    def test_campaign_4_seasons(self):
        self.assertSameUnderHashSeeds("campaign", [1480], 4)


# ----- save, load and play on ----------------------------------------------------------------------------------
class SaveLoadTest(TempHome):
    @slow
    def test_a_loaded_campaign_plays_on_exactly_like_the_original(self):
        world = play_seasons(fresh("POR"), 3)
        saves.save(world, "1")
        copy = saves.load("1")
        self.assertIsNotNone(copy, "the save did not load")
        self.assertIsNot(copy, world)
        self.assertEqual(world_digest(copy), world_digest(world), "the loaded world differs from the saved one")
        play_seasons(world, 3)
        play_seasons(copy, 3)
        self.assertEqual((copy.turn, copy.version), (world.turn, world.version))
        self.assertEqual(world_digest(copy), world_digest(world),
                         "after 3 more seasons the loaded world played differently from the original")
        check_campaign(copy)


# ----- random games: check/action agreement and invariants -----------------------------------------------------
class _Broken(Exception):
    """An invariant broke: the game stops here."""


class Game:
    """What one random game found: its first broken invariant or crash, and its first check/action disagreement."""

    def __init__(self, mode, seed):
        self.mode, self.seed = mode, seed
        self.invariant = self.agreement = None
        self.tried = Counter()
        self.turns = 0

    def watch(self, problems, where):
        if problems:
            raise _Broken(f"{where}: {problems[0]}" + (f"  [{len(problems) - 1} more]" if len(problems) > 1 else ""))

    def run(self, judge, play):
        try:
            play()
        except _Broken as broken:
            self.invariant = str(broken)
        except Exception as error:      # noqa: BLE001 - any crash is a finding, reported with the seed
            if not judge.crashed:
                frame = traceback.extract_tb(error.__traceback__)[-1]
                self.invariant = (f"crash: {type(error).__name__}: {error} "
                                  f"({os.path.basename(frame.filename)}:{frame.lineno} in {frame.name})")
        self.agreement = judge.problems[0] if judge.problems else None
        self.tried = judge.tried
        return self


def conquest_game(seed):
    """A Conquest game to the end: the random player tries 8 actions a turn; on even seeds the computer then
    finishes its turn (so both sides build up), on odd seeds it just loses."""
    game, world = Game("conquest", seed), World(seed)
    judge = Judge(world, quick_digest)

    def after_turn(w):
        game.turns += 1
        problems = conquest_problems(w)
        if not problems and not w.winner and game.turns > 2 * TURN_LIMIT:
            problems = [f"winner: nobody has won after turn {TURN_LIMIT}"]
        game.watch(problems, f"turn {w.turn}, before {w.current}'s move")

    def play():
        game.watch(conquest_problems(world), "the new game")
        play_conquest(world, after_turn, conquest_player(random.Random(seed), judge, then_ai=seed % 2 == 0))
    return game.run(judge, play)


def colony_game(seed, rounds=COLONY_ROUNDS):
    """A Colonisation game of `rounds` rounds; start and goal vary with the seed."""
    start = (START_SEA, START_LAND)[seed % 2]
    goal = (GOAL_SURVIVE, GOAL_INDEPENDENCE, GOAL_ENDLESS)[seed // 2 % 3]
    game, world = Game("colony", seed), ColonyWorld(seed, start, goal)
    judge = Judge(world, quick_digest)

    def after_turn(w):
        game.watch(colony_problems(w), f"turn {w.turn}, before {w.current}'s move")

    def play():
        game.watch(colony_problems(world), "the new game")
        play_colony(world, rounds, after_turn, colony_player(random.Random(seed), judge))
    return game.run(judge, play)


def campaign_game(seed, seasons=CAMPAIGN_SEASONS):
    """A campaign game on the Europe map: the random player picks a country and tries 10 actions a season, then
    the computer moves everybody else. Every CAMPAIGN_DIGESTED-th seed also digests the world around refused
    actions; the others only check what the actions return."""
    rng = random.Random(seed)
    tag = rng.choice(sorted(geo.COUNTRIES))                  # every country of the 1480 map
    game, world = Game("campaign", seed), fresh(tag)
    judge = Judge(world, quick_digest if seed % CAMPAIGN_DIGESTED == 0 else None)
    player = campaign_player(rng, judge, tag)

    def play():
        game.watch(campaign_problems(world), f"the new game as {tag}")
        for _ in range(seasons):
            player(world)
            play_seasons(world, 1, player_ai=False)
            game.watch(campaign_problems(world), f"{world.date()} (turn {world.turn}), playing {tag}")
    return game.run(judge, play)


class GamesMixin:
    """Plays GAMES random games of one mode once (the first test that needs them) and reports on them."""
    mode = ""
    play = None             # seed -> Game
    both = ()               # actions the random player must have seen allowed and refused over the 20 games

    @classmethod
    def games(cls):
        if "_games" not in cls.__dict__:
            cls._games = [cls.play(seed) for seed in range(BASE_SEED, BASE_SEED + GAMES)]
        return cls._games

    def report(self, found, what):
        if not found:
            return
        lines = [f"{len(found)} of {GAMES} {self.mode} games {what} (seed: first problem, then a command that "
                 f"replays only that game):"]
        for game, problem in found:
            bug = known_open(self.mode, problem.split(": ", 1)[-1])
            lines.append(f"  seed {game.seed}: {problem}" + (f"\n    (known open bug: {bug})" if bug else ""))
            lines.append(f"    HEXA_PROP_SEED={game.seed} HEXA_PROP_GAMES=1 python3 -m unittest "
                         f"tests.test_properties.{type(self).__name__}")
        self.fail("\n".join(lines))

    def test_refused_actions_change_nothing_and_allowed_ones_succeed(self):
        self.report([(g, g.agreement) for g in self.games() if g.agreement],
                    "had a check and its action disagree")

    def test_invariants_hold_after_every_turn(self):
        self.report([(g, g.invariant) for g in self.games() if g.invariant], "broke an invariant")

    def test_the_random_player_hears_both_yes_and_no(self):
        if GAMES < 20 or BASE_SEED != 0:
            self.skipTest("checks the default games (HEXA_PROP_SEED=0, at least 20 of them)")
        tried = sum((g.tried for g in self.games()), Counter())
        missing = [name for name in self.both if not (tried[name, True] and tried[name, False])]
        self.assertFalse(missing, f"never both allowed and refused: {missing} (tried: {dict(tried)})")


@slow
class ConquestGamesTest(GamesMixin, unittest.TestCase):
    mode, play = "conquest", staticmethod(conquest_game)
    both = ("train", "build", "found_town", "move", "attack")


@slow
class ColonyGamesTest(GamesMixin, unittest.TestCase):
    mode, play = "colony", staticmethod(colony_game)
    both = ("train", "make_colonist", "grow", "build_stockade", "build", "found_colony", "join", "market", "trade",
            "move", "attack")


@slow
class CampaignGamesTest(GamesMixin, unittest.TestCase):
    mode, play = "campaign", staticmethod(campaign_game)
    # forage is allowed only for troops standing in foreign land, which random games reach rarely (2 of 20 games on
    # the pre-ridge map, 0 after the ridge and terrain change): too fragile for this check. The forage rules have
    # their own direct tests in test_campaign.
    both = ("invest", "recruit", "build", "declare_war", "move_group", "send_merchant")


class SmokeTest(unittest.TestCase):
    """One short random game per mode, so HEXA_FAST=1 still runs the agent, the judge and the checkers."""

    def test_one_short_random_game_per_mode(self):
        for game in (conquest_game(1), colony_game(0, rounds=3), campaign_game(0, seasons=1)):
            self.assertIsNone(game.invariant, f"{game.mode} seed {game.seed}")
            self.assertIsNone(game.agreement, f"{game.mode} seed {game.seed}")
            self.assertGreaterEqual(sum(game.tried.values()), 5, f"{game.mode}: the random player hardly played")

    def test_a_bad_game_is_reported_with_its_seed_and_a_replay_command(self):
        def broken(seed):
            game = Game("colony", seed)
            game.invariant = "turn 3, before golden's move: colony-capital: crimson has 0 capitals among 1 colonies"
            game.agreement = "step 4: grow(Fort Hope) returned True although the check refused it ('x')"
            return game

        class Sample(GamesMixin, unittest.TestCase):
            mode, play = "colony", staticmethod(broken)

        result = unittest.TestResult()
        # No real open bug is left to name, so make one up.
        with mock.patch.dict(KNOWN_OPEN, {("colony", "colony-capital:"): "a made-up open bug"}):
            unittest.defaultTestLoader.loadTestsFromTestCase(Sample).run(result)
        text = "\n".join(message for _, message in result.failures)
        self.assertEqual(len(result.failures), 2, text)
        self.assertIn(f"seed {BASE_SEED}: turn 3, before golden's move: colony-capital:", text)
        self.assertIn("known open bug: a made-up open bug", text)
        self.assertIn(f"seed {BASE_SEED}: step 4: grow(Fort Hope)", text)
        self.assertIn(f"HEXA_PROP_SEED={BASE_SEED} HEXA_PROP_GAMES=1 python3 -m unittest "
                      f"tests.test_properties.Sample", text)


# ----- open bugs these properties catch -------------------------------------------------------------------------
def overfill_scenario():
    """Issue #20 set-up: two Portuguese caravels on one sea hex, the first full (4/4), the second empty, and a
    2-unit Portuguese stack on the shore next to them."""
    w = fresh("POR")
    w.units = [u for u in w.units if u.owner != "POR"]
    shore, sea = next((p.pos, n) for p in w.provinces_of("POR") for n in sorted(neighbors(p.pos))
                      if w.is_sea(n) and not w.units_at(n) and not w.units_at(p.pos))
    pikes = troop("infantry", 1)
    full = w._add_unit(CARAVEL, "POR", sea, moves=CARAVEL.moves)
    empty = w._add_unit(CARAVEL, "POR", sea, moves=CARAVEL.moves)
    for _ in range(CARAVEL.capacity):
        w._add_unit(pikes, "POR", sea).carrier = full
    stack = [w._add_unit(pikes, "POR", shore, moves=pikes.moves) for _ in range(2)]
    return w, stack, sea, empty


def crowded_colony_scenario(seed=5):
    """Your capital (3 people, plenty of stock) whose only free land within 3 hexes is an enemy colony's hex."""
    w = ColonyWorld(seed, START_LAND)
    home = w.capital_of(C_PLAYER)
    home.pop = 3
    w.stock[C_PLAYER].update(food=50, wood=50, gold=50)
    free = [p for p in within(home.pos, 3) if w.is_land(p) and w.unit_at(p) is None and not w.village_at(p)]
    enemy = next(p for p in free if distance(p, home.pos) == 2)
    w.colonies.append(Colony(enemy, CRIMSON, "Enemy town"))
    for p in free:
        if p != enemy:
            w._new_unit(C_SCOUT, C_PLAYER, p)
    return w, home


def first_capture_scenario(seed=5):
    """A Crimson soldier next to your capital, which has no defender, while Crimson has no colony at all."""
    w = ColonyWorld(seed, START_LAND)
    target = w.capital_of(C_PLAYER)
    for colony in w.colonies_of(CRIMSON):
        w.colonies.remove(colony)
    w.units = [u for u in w.units if u.pos != target.pos]
    w.current = CRIMSON
    spot = next(p for p in sorted(neighbors(target.pos)) if w.is_land(p) and w.unit_at(p) is None
                and not w.village_at(p))
    return w, w._new_unit(C_SOLDIER, CRIMSON, spot), target


def knockout_scenario(seed=5):
    """Your soldier next to Crimson's only colony, which has no defender; Crimson has no colonist (a settled start
    gives it a soldier, a pioneer, a scout and a ship), so taking the colony knocks it out of the game."""
    w = ColonyWorld(seed, START_LAND)
    target = w.capital_of(CRIMSON)
    w.units = [u for u in w.units if u.pos != target.pos and not (u.owner == CRIMSON and u.type is C_SCOUT)]
    spot = next(p for p in sorted(neighbors(target.pos)) if w.is_land(p) and w.unit_at(p) is None
                and not w.village_at(p))
    return w, w._new_unit(C_SOLDIER, C_PLAYER, spot), target


class KnownBugsTest(unittest.TestCase):
    """Each open bug has a plain test that its set-up is sound (so the expected failure can't come from a broken
    set-up) and an expectedFailure test of the property it breaks. The fix removes the decorator."""

    def test_the_bug_set_ups_are_sound(self):
        w, stack, sea, empty = overfill_scenario()
        check_campaign(w)
        self.assertIn(sea, w.reachable_group(stack), "the stack may board at that hex")
        self.assertEqual((len(w.cargo(w.units_at(sea)[0])), len(w.cargo(empty))), (CARAVEL.capacity, 0))
        w, home = crowded_colony_scenario()
        check_colony(w)
        self.assertFalse(w.train_check(home, C_SOLDIER)[0], "the only free hex is an enemy colony's: no room")
        self.assertFalse(w.colonist_check(home)[0])
        w, raider, target = first_capture_scenario()
        check_colony(w)
        self.assertIn(target.pos, w.reachable(raider))
        w, raider, target = knockout_scenario()
        check_colony(w)
        self.assertIn(target.pos, w.reachable(raider))
        self.assertTrue(w.units_of(CRIMSON), "Crimson still has units elsewhere")

    def test_boarding_never_overfills_a_ship(self):
        """Issue #20 (fixed by PR #66): a stack boarded the first own ship on the hex, even when only another ship
        there had room (cargo invariant)."""
        w, stack, sea, _ = overfill_scenario()
        self.assertTrue(w.move_group(stack, sea))
        check_campaign(w)

    def test_training_only_counts_room_the_new_unit_can_use(self):
        """New bug, no GitHub issue filed yet: train_check() and colonist_check() count an enemy colony's hex as
        room for the new unit but spawn() does not, so train() and make_colonist() pay (gold, a colonist's
        population) and then raise AttributeError (check/action agreement)."""
        problems = []
        for job in ("train", "make_colonist"):
            w, home = crowded_colony_scenario()
            judge = Judge(w, quick_digest)
            if job == "train":
                check, action = (lambda: w.train_check(home, C_SOLDIER)), (lambda: w.train(home, C_SOLDIER))
            else:
                check, action = (lambda: w.colonist_check(home)), (lambda: w.make_colonist(home))
            with contextlib.suppress(AttributeError):
                judge.attempt(job, home.name, check, action)
            problems += judge.problems
        self.assertEqual(problems, [])

    def test_capturing_a_capital_as_your_first_colony_makes_it_your_capital(self):
        """New bug, no GitHub issue filed yet: _capture() asks capital_of(captor) after the colony already belongs
        to the captor, so a captured capital never becomes the captor's capital, and a side whose first colony it
        is ends up with none (colony-capital invariant). Long random games hit it when the royal army takes your
        capital (HEXA_PROP_SEED=26: seed 26 played for 40 rounds)."""
        w, raider, target = first_capture_scenario()
        self.assertTrue(w.move(raider, target.pos))
        self.assertEqual(target.owner, CRIMSON)
        check_colony(w)

    def test_a_company_knocked_out_leaves_no_units_behind(self):
        """New bug, no GitHub issue filed yet: when a company loses its last colony and has no colonist, check_end()
        puts it out of the game (it gets no more turns) but leaves its other units on the map. They never move
        again, block hexes and count as hostile (one left standing on your building stops it producing)
        (dead-side-units invariant; docs/testing/spec.md 3.2.4 "no units of dead sides")."""
        w, raider, target = knockout_scenario()
        self.assertTrue(w.move(raider, target.pos))
        self.assertIn(CRIMSON, w.dead)
        self.assertIsNone(w.winner, "the game goes on against the Golden Company")
        check_colony(w)


if __name__ == "__main__":
    unittest.main()
