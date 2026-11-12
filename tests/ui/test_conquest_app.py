"""The Conquest window (play.App) driven through its own run() loop: selection, moving, fighting, training,
building, the enemy turn on fake time, and the R / M / Esc keys.

Every test starts map #42 the way the window does (play.App(42)), sometimes moves a unit or fills the stock
before the loop starts, then plays the scenario with real mouse and keyboard events and checks the world and the
window state. Map #42 at the start:

    your castle (1, 6) with a soldier in it, your scout (2, 6), your worker (0, 7) on grassland;
    the enemy castle (13, 4) with a soldier, the enemy scout (12, 4) and worker (13, 3), all out of sight.

Run with: python -m unittest tests.ui.test_conquest_app
"""
import random
import unittest
from unittest import mock

from hexa.hexgrid import distance, within
from hexa.rules import AI, PLAYER, SCOUT, SETTLER, SOLDIER, START_STOCK, UNIT_TYPES, WORKER
from tests.support import harness
from tests.support.harness import click, hex_pixel, hover, key
from tests.support.invariants import check_conquest

SEED = 42
RICH = {"food": 30, "wood": 30, "stone": 30}


class ConquestCase(harness.UITestCase):
    def start(self, seed=SEED):
        import play
        self.app = play.App(seed)
        self.world = self.app.world
        return self.app

    def unit(self, kind, owner=PLAYER):
        found = [u for u in self.world.units if u.type is kind and u.owner == owner]
        self.assertEqual(len(found), 1, f"map #{SEED} should have one {owner} {kind.key}")
        return found[0]

    def on_hex(self, pos, button=1):
        """A click on map hex pos (computed when its frame comes)."""
        return lambda: click(hex_pixel(self.app, pos), button)

    def play(self, frames, until=None):
        """Run the window's real loop on the script so far; return what run() returned."""
        self.driver.run_for(frames, until)
        result = self.app.run()
        check_conquest(self.world)
        return result


class SelectTest(ConquestCase):
    def test_tab_cycles_through_the_units_that_can_still_move(self):
        app = self.start()
        soldier, scout, worker = self.unit(SOLDIER), self.unit(SCOUT), self.unit(WORKER)
        self.assertIsNone(app.ui.selected)
        seen = []
        for i in range(4):
            self.driver.at(2 * i, key("tab"))
            self.driver.at(2 * i + 1, lambda: seen.append(app.ui.selected))
        self.play(8)
        self.assertEqual(seen, [soldier, scout, worker, soldier])
        self.assertEqual(app.ui.reach, self.world.reachable(soldier), "the reach shown is the soldier's")
        self.assertTrue(app.ui.status.startswith("Soldier"), app.ui.status)

    def test_tab_skips_a_unit_that_has_used_all_its_moves(self):
        app = self.start()
        soldier, scout, worker = self.unit(SOLDIER), self.unit(SCOUT), self.unit(WORKER)
        far = min(p for p, cost in self.world.reachable(scout).items() if cost == SCOUT.moves)
        self.driver.at(0, self.on_hex(scout.pos))
        self.driver.at(1, self.on_hex(far))                   # all four moves
        seen = []
        for i in range(3):
            self.driver.at(3 + 2 * i, key("tab"))
            self.driver.at(4 + 2 * i, lambda: seen.append(app.ui.selected))
        self.play(10)
        self.assertEqual((scout.pos, scout.moves_left), (far, 0))
        self.assertEqual(seen, [soldier, worker, soldier])

    def test_a_click_selects_a_unit_and_a_right_click_deselects_it(self):
        app = self.start()
        scout = self.unit(SCOUT)
        picked = []
        self.driver.at(0, self.on_hex(scout.pos))
        self.driver.at(1, lambda: picked.append((app.ui.selected, dict(app.ui.reach))))
        self.driver.at(1, self.on_hex((7, 1), button=3))
        self.play(3)
        self.assertEqual(picked, [(scout, self.world.reachable(scout))])
        self.assertIsNone(app.ui.selected)
        self.assertEqual(app.ui.reach, {})


class MoveTest(ConquestCase):
    def test_clicking_a_highlighted_hex_moves_the_unit_and_reveals_the_map(self):
        app = self.start()
        world = self.world
        scout = self.unit(SCOUT)
        reach = world.reachable(scout)
        explored = set(world.explored)
        # the hex three moves away that shows the most of the map not seen yet
        dest = max(sorted(p for p, cost in reach.items() if cost == 3),
                   key=lambda p: len({q for q in within(p, SCOUT.sight) if world.in_bounds(q)} - explored))
        self.driver.at(0, self.on_hex(scout.pos))
        self.driver.at(1, self.on_hex(dest))
        self.play(3)
        self.assertEqual((scout.pos, scout.moves_left), (dest, SCOUT.moves - reach[dest]))
        self.assertIs(app.ui.selected, scout, "a unit with moves left stays selected")
        self.assertEqual(app.ui.reach, world.reachable(scout), "the reach is shown from where it stands now")
        sight = {p for p in within(dest, SCOUT.sight) if world.in_bounds(p)}
        self.assertLessEqual(sight, world.visible)
        self.assertGreater(len(world.explored), len(explored), "moving revealed new hexes")
        self.assertIn(f"Moves 1/{SCOUT.moves}", app.ui.status)

    def test_a_click_outside_the_reach_moves_nothing_and_deselects(self):
        app = self.start()
        scout = self.unit(SCOUT)
        start = scout.pos
        far = (9, 9)
        self.assertNotIn(far, self.world.reachable(scout))
        self.driver.at(0, self.on_hex(scout.pos))
        self.driver.at(1, self.on_hex(far))
        self.play(3)
        self.assertEqual((scout.pos, scout.moves_left), (start, SCOUT.moves))
        self.assertIsNone(app.ui.selected)


class AttackTest(ConquestCase):
    def test_clicking_a_red_outlined_enemy_walks_next_to_it_and_attacks(self):
        app = self.start()
        world = self.world
        soldier, enemy = self.unit(SOLDIER), self.unit(WORKER, AI)
        enemy.pos = (2, 4)                                   # two hexes from the castle, in sight
        world.update_visibility()
        options = world.attack_options(soldier)
        self.assertIn(enemy.pos, options)
        stand = options[enemy.pos]
        self.assertEqual(distance(soldier.pos, stand), 1, "the soldier has to walk one hex first")
        shown = []
        self.driver.at(0, self.on_hex(soldier.pos))           # the soldier stands in the castle: it is picked first
        self.driver.at(1, lambda: shown.append(dict(app.ui.attacks)))
        self.driver.at(1, self.on_hex(enemy.pos))
        self.play(3)
        self.assertEqual(shown, [options], "the enemy was outlined as a target")
        # A soldier hits for at least 4 (attack 5, at least 0.8 of it), a worker on grassland has 4 HP.
        self.assertNotIn(enemy, world.units)
        self.assertIn("destroyed", world.log[-1])
        self.assertEqual(soldier.pos, stand)
        self.assertEqual((soldier.moves_left, soldier.attacked), (0, True))
        self.assertEqual(app.ui.attacks, {}, "it can't attack again this turn")


class TrainTest(ConquestCase):
    def test_keys_1_to_4_train_each_unit_type_once_per_turn(self):
        for hotkey in ("1", "2", "3", "4"):
            kind = next(t for t in UNIT_TYPES.values() if t.hotkey == hotkey)
            with self.subTest(key=hotkey, unit=kind.key):
                self.driver.reset()
                app = self.start()
                world = self.world
                world.stock[PLAYER] = dict(RICH)
                castle = world.capital_of(PLAYER)
                before = list(world.units)
                self.driver.at(0, self.on_hex(castle.pos))     # the soldier standing in the castle ...
                self.driver.at(1, self.on_hex(castle.pos))     # ... clicked again: the castle itself
                self.driver.at(2, key(hotkey))
                self.driver.at(3, key("2" if hotkey == "1" else "1"))      # a second unit this turn: refused
                self.play(5)
                new = [u for u in world.units if u not in before]
                self.assertEqual([u.type for u in new], [kind])
                self.assertEqual(world.stock[PLAYER], {r: n - kind.cost.get(r, 0) for r, n in RICH.items()})
                self.assertEqual((new[0].owner, new[0].moves_left), (PLAYER, 0), "it acts next turn")
                self.assertLessEqual(distance(new[0].pos, castle.pos), 2)
                self.assertTrue(castle.trained)
                self.assertIs(app.ui.town, castle)
                self.assertFalse(any(b.enabled for b in app.ui.buttons), "every train button is now disabled")

    def test_clicking_a_unit_button_trains_it(self):
        app = self.start()
        castle = self.world.capital_of(PLAYER)
        before = len(self.world.units)
        self.driver.at(0, self.on_hex(castle.pos))
        self.driver.at(1, self.on_hex(castle.pos))
        self.driver.at(2, lambda: click(harness.button_rect(app, "Scout").center))
        self.play(4)
        self.assertEqual(len(self.world.units), before + 1)
        self.assertIs(self.world.units[-1].type, SCOUT)
        self.assertEqual(self.world.stock[PLAYER], {r: n - SCOUT.cost.get(r, 0) for r, n in START_STOCK.items()})

    def test_a_town_short_of_resources_trains_nothing_and_says_why(self):
        app = self.start()
        self.world.stock[PLAYER] = {"food": 1, "wood": 0, "stone": 0}
        castle = self.world.capital_of(PLAYER)
        before = len(self.world.units)
        self.driver.at(0, self.on_hex(castle.pos))
        self.driver.at(1, self.on_hex(castle.pos))
        self.driver.at(2, key("2"))
        self.driver.at(3, lambda: hover(harness.button_rect(app, "Soldier").center))
        self.play(5)
        self.assertEqual(len(self.world.units), before)
        self.assertEqual(self.world.stock[PLAYER], {"food": 1, "wood": 0, "stone": 0})
        self.assertFalse(castle.trained)
        self.assertEqual(app.ui.hover_button.hint, "Not enough resources")


class BuildTest(ConquestCase):
    def test_b_builds_with_the_selected_worker(self):
        app = self.start()
        world = self.world
        worker = self.unit(WORKER)
        improvement, reason = world.build_check(worker)
        self.assertIsNotNone(improvement, reason)
        self.driver.at(0, self.on_hex(worker.pos))
        self.driver.at(1, key("b"))
        self.play(3)
        self.assertEqual(world.improvements, {worker.pos: improvement.key})
        self.assertEqual(world.stock[PLAYER], {r: n - improvement.cost.get(r, 0) for r, n in START_STOCK.items()})
        self.assertEqual(worker.moves_left, 0)
        self.assertIs(app.ui.selected, worker)
        self.assertFalse(app.ui.buttons[0].enabled, "no moves left to build again")

    def test_b_founds_a_town_with_the_selected_settler(self):
        app = self.start()
        world = self.world
        settler = world.spawn(SETTLER, PLAYER, (5, 7))
        world.update_visibility()
        self.assertEqual(world.found_check(settler), (True, ""))
        spot = settler.pos
        self.driver.at(0, self.on_hex(spot))
        self.driver.at(1, key("b"))
        self.play(3)
        town = world.town_at(spot)
        self.assertIsNotNone(town)
        self.assertEqual((town.owner, town.capital), (PLAYER, False))
        self.assertNotIn(settler, world.units)
        self.assertIs(app.ui.town, town, "the new town is selected, ready to train")
        self.assertEqual([b.action[0] for b in app.ui.buttons], ["train"] * 4)


class EnemyTurnTest(ConquestCase):
    def watch_the_enemy(self):
        """Record every enemy action as the window sees it: (fake ms, whether the player can see the unit).
        The last entry is (fake ms, None): the enemy has nothing more to do."""
        import pygame
        from hexa import ai
        real = ai.take_turn
        steps = []

        def watched(world, *args):
            for unit in real(world, *args):
                steps.append((pygame.time.get_ticks(), unit.pos in world.visible))
                yield unit
            steps.append((pygame.time.get_ticks(), None))

        patcher = mock.patch.object(ai, "take_turn", watched)
        patcher.start()
        self.addCleanup(patcher.stop)
        return steps

    def test_space_ends_the_turn_and_the_enemy_pauses_only_after_moves_you_can_see(self):
        import play
        app = self.start()
        world = self.world
        scout = self.unit(SCOUT)
        scout.pos = (10, 4)                         # watching the enemy castle at (13, 4)
        world.update_visibility()
        steps = self.watch_the_enemy()
        busy = []
        self.driver.at(0, key("space"))
        self.driver.at(5, lambda: busy.append(app.players_turn()))
        self.driver.at(5, key("space"))             # while the enemy moves: ignored
        self.driver.run_for(3000, until=lambda: world.turn == 2 and app.players_turn())
        self.assertEqual(app.run(), "quit")
        check_conquest(world)

        self.assertEqual(self.driver.stopped_by, "until", f"still turn {world.turn} after 3000 frames")
        self.assertEqual((world.turn, world.current), (2, PLAYER))
        self.assertEqual(busy, [False], "frame 5 was in the middle of the enemy turn")
        self.assertEqual(sum(1 for text in world.log if text.startswith("Turn 2.")), 1, "one turn ended, not two")
        seen = [ms for ms, visible in steps if visible]
        unseen = [ms for ms, visible in steps if visible is False]
        self.assertTrue(seen and unseen, f"the scenario needs both kinds of enemy action: {steps}")
        for (ms, visible), (next_ms, _) in zip(steps, steps[1:]):
            if visible:     # the window waits AI_STEP_MS, then goes on at the first frame after that
                self.assertGreaterEqual(next_ms - ms, play.AI_STEP_MS, steps)
                self.assertLess(next_ms - ms, play.AI_STEP_MS + harness.FRAME_MS, steps)
            else:           # no pause: the next action happens in the same frame
                self.assertEqual(next_ms, ms, steps)
        self.assertEqual(steps[0][0], harness.START_MS, "the enemy starts in the frame Space was pressed")
        self.assertEqual(steps[-1][0] - steps[0][0], len(seen) * 22 * harness.FRAME_MS,
                         "the turn took one 352 ms pause per visible action (350 ms rounded up to frames)")
        self.assertIn(app.ui.selected, world.units_of(PLAYER), "your first ready unit is selected again")

    def test_an_enemy_turn_you_cannot_see_takes_one_frame(self):
        app = self.start()
        world = self.world
        steps = self.watch_the_enemy()
        back = []

        def your_turn_again():
            if world.turn == 2 and app.players_turn():
                back.append(self.driver.frame)
            return bool(back)

        self.driver.at(0, key("space"))
        self.driver.run_for(100, until=your_turn_again)
        app.run()
        self.assertEqual((world.turn, world.current), (2, PLAYER))
        self.assertGreater(len(steps), 1, "the enemy did something")
        self.assertEqual({visible for _, visible in steps[:-1]}, {False})
        self.assertEqual(back[0], 1, "the whole enemy turn ran in the frame Space was pressed")


class KeysTest(ConquestCase):
    def test_r_starts_a_new_map(self):
        import pygame
        from hexa.world import World
        from tests.support.digests import world_digest
        app = self.start()
        old = self.world
        self.driver.at(0, key("tab"))
        self.driver.at(1, key("space"))
        self.driver.run_for(300, until=lambda: old.turn == 2 and app.players_turn())
        app.run()
        self.assertEqual(old.turn, 2)

        self.driver.reset()
        app.running = True
        self.driver.at(0, key("tab"))
        self.driver.at(1, key("r"))
        with mock.patch.object(random, "randrange", return_value=77):      # the seed a new map gets
            self.play(3)
        new = app.world
        check_conquest(new)
        self.assertIsNot(new, old)
        self.assertEqual((new.seed, new.turn, new.current), (77, 1, PLAYER))
        self.assertEqual(world_digest(new), world_digest(World(77)), "a fresh map #77")
        self.assertIsNone(app.ui.selected)
        self.assertIsNone(app.ai_turn)
        self.assertEqual(pygame.display.get_caption()[0], "Hexa conquest  -  map #77")

    def test_m_leaves_for_the_menu(self):
        app = self.start()
        self.driver.at(2, key("m"))
        self.assertEqual(self.play(30), "menu")
        self.assertIsNone(self.driver.stopped_by, "run() returned by itself")
        self.assertEqual(self.driver.frame, 3)

    def test_escape_deselects_first_and_quits_when_nothing_is_selected(self):
        app = self.start()
        castle = self.world.capital_of(PLAYER)
        state = []
        record = lambda: state.append((app.ui.selected, app.ui.town, app.running))    # noqa: E731
        self.driver.at(0, key("tab"))
        self.driver.at(1, key("escape"))
        self.driver.at(2, record)
        self.driver.at(2, self.on_hex(castle.pos))
        self.driver.at(2, self.on_hex(castle.pos))             # the castle itself
        self.driver.at(3, record)
        self.driver.at(3, key("escape"))
        self.driver.at(4, record)
        self.driver.at(4, key("escape"))
        self.assertEqual(self.play(30), "quit")
        self.assertIsNone(self.driver.stopped_by, "the last Esc quit, not the frame budget")
        self.assertEqual(state, [(None, None, True), (None, castle, True), (None, None, True)])
        self.assertEqual(self.driver.frame, 5)


if __name__ == "__main__":
    unittest.main()
