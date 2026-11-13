"""The movement replay in the Age of Discovery window: the moves the player can see are walked hex by hex after End
season (and for the player's own long orders), moves in fog stay instant, Space skips, End season waits, the option
turns it off, and drawing the frames never changes the game. The schedule itself is in tests/test_replay.py.

The tests make another country walk on the player's map with the world's own move_group (the way the AI does inside
``ai.run``), so they do not depend on what the AI would decide. Run with: python -m unittest tests.ui.test_replay_window"""
import unittest
from types import SimpleNamespace
from unittest import mock

from tests.support import harness
from tests.support.digests import quick_digest
from tests.support.harness import FRAME_MS, click, drag, hex_pixel, key


class ReplayCase(harness.UITestCase):
    def start(self, movement="normal", tag="POR"):
        import play
        from hexa.campaign.app import CampaignApp
        self.app = app = CampaignApp(play.TILES_DIR, tag)
        app.settings["movement"] = movement
        self.world = app.world
        return app

    def stack(self, tag):
        """(a land stack of `tag` that can walk 3 or more hexes, a hex 3 or more steps away it can reach)."""
        w = self.world
        for unit in w.units_of(tag):
            if unit.naval:
                continue
            group = [u for u in w.units_at(unit.pos) if u.owner == tag]
            reach = w.reachable_group(group)
            far = [p for p in reach if len(w.route(group, p)) >= 4]
            if far:
                return group, sorted(far)[0]
        self.fail(f"{tag} has no stack that can walk 3 hexes")

    def season_with_walk(self, seen, tag="CAS"):
        """End the season while `tag`'s stack walks (inside ai.run, as the AI's would). `seen`: True shows the player
        the whole walk, False hides it. Returns (group, start, dest, path)."""
        from hexa.campaign import ai
        group, dest = self.stack(tag)
        start = group[0].pos
        path = self.world.route(group, dest)
        real = ai.run
        walked = []

        def run(world, who):
            if who == tag and not walked:
                walked.append(True)
                world.visible = (world.visible | set(path)) if seen else (world.visible - set(path))
                world.move_group(group, dest)
            return real(world, who)
        patcher = mock.patch.object(ai, "run", run)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.app.end_turn()
        self.assertTrue(walked)
        return group, start, dest, path

    def play(self, frames, until=None):
        """Run the window's loop again for frames (a loop that was told to quit is started anew)."""
        self.driver.reset()
        self.app.running, self.app.result = True, None
        self.driver.run_for(frames, until)
        return self.app.run()

    def play_script(self, frames, until=None):
        """Like play(), but keep the events already scripted with driver.at()."""
        self.app.running, self.app.result = True, None
        self.driver.run_for(frames, until)
        return self.app.run()


class SeasonReplayTest(ReplayCase):
    def test_a_walk_the_player_sees_is_replayed_hex_by_hex_after_end_season(self):
        app = self.start()
        group, start, dest, path = self.season_with_walk(seen=True)
        replay = app.ui.replay
        self.assertEqual(self.world.turn, 2, "the season was computed in full, at once")
        self.assertEqual(group[0].pos, dest, "the world already has the stack at its goal")
        self.assertTrue(replay.active)
        self.assertEqual(len(replay.pending), 1)
        steps = len(path) - 1
        self.play(steps * 20 + 10, until=lambda: not replay.active)
        self.assertEqual(self.driver.stopped_by, "until")
        self.assertFalse(replay.active)

    def test_the_figure_is_drawn_between_hexes_until_the_replay_ends(self):
        app = self.start()
        group, start, dest, path = self.season_with_walk(seen=True)
        drawn = []
        real = app.view._draw_stack

        def spy(screen, stack, top, point, selected, side=None):
            if group[0] in stack:
                drawn.append(point)
            return real(screen, stack, top, point, selected, side)
        app.view._draw_stack = spy
        app.look_at(path[len(path) // 2])
        app.draw()
        first = drawn.pop()
        replay = app.ui.replay
        centre = lambda pos: hex_pixel(app, pos)                  # noqa: E731
        self.assertEqual((round(first[0]), round(first[1])), centre(start), "waits on the hex it left")
        replay.t = replay.legs[0].step * 1.5
        app.draw()
        mid = drawn.pop()
        a, b = centre(path[1]), centre(path[2])
        self.assertAlmostEqual(mid[0], (a[0] + b[0]) / 2, delta=2)
        self.assertAlmostEqual(mid[1], (a[1] + b[1]) / 2, delta=2)
        self.assertNotEqual((round(mid[0]), round(mid[1])), centre(dest), "not where the world has it")
        replay.skip()
        app.draw()
        end = drawn.pop()
        self.assertEqual((round(end[0]), round(end[1])), centre(dest), "after the replay: at its goal")

    def test_a_walk_in_fog_is_instant(self):
        app = self.start()
        self.season_with_walk(seen=False)
        self.assertFalse(app.ui.replay.active, "nothing to show: the player saw none of it")
        self.assertEqual(app.ui.replay.pending, [])

    def test_a_walk_seen_in_part_replays_only_that_part(self):
        from hexa.campaign import ai
        app = self.start()
        group, dest = self.stack("CAS")
        path = self.world.route(group, dest)
        real = ai.run

        def run(world, who):
            if who == "CAS" and group[0].pos == path[0]:
                world.visible = (world.visible - set(path)) | {path[-1]}
                world.move_group(group, dest)
            return real(world, who)
        with mock.patch.object(ai, "run", run):
            app.end_turn()
        (leg,) = app.ui.replay.pending
        self.assertEqual(leg.count, 1, "only the last step touches a hex the player saw")

    def test_the_option_off_means_no_replay(self):
        app = self.start("off")
        self.season_with_walk(seen=True)
        self.assertFalse(app.ui.replay.active)
        app.ui.replay.schedule()
        self.assertEqual(app.ui.replay.legs, [])

    def test_slow_is_slower_than_normal(self):
        from hexa.campaign.replay import PACE
        app = self.start("slow")
        self.season_with_walk(seen=True)
        app.ui.replay.schedule()
        self.assertEqual(app.ui.replay.legs[0].step, PACE["slow"][0])


class InputDuringReplayTest(ReplayCase):
    def test_space_skips_the_replay_and_the_next_space_ends_the_next_season(self):
        app = self.start()
        self.season_with_walk(seen=True)
        self.assertTrue(app.ui.replay.active)
        self.driver.at(1, key("space"))
        self.play_script(4, until=lambda: not app.ui.replay.active)
        self.assertFalse(app.ui.replay.active, "skipped")
        self.assertEqual(self.world.turn, 2, "skipping the replay did not end a season")
        self.driver.at(1, key("space"))
        self.play_script(40, until=lambda: self.world.turn == 3)
        self.assertEqual(self.world.turn, 3, "and a second Space ends the next season")

    def test_the_end_season_button_is_blocked_while_the_replay_runs(self):
        app = self.start()
        self.season_with_walk(seen=True)
        self.driver.at(2, lambda: click(harness.end_turn_rect(app).center))
        self.driver.at(4, lambda: click(harness.end_turn_rect(app).center))
        self.play_script(8)
        self.assertEqual(self.world.turn, 2, "two clicks, no new season")
        self.assertTrue(app.ui.replay.active)
        self.assertIn("still playing", app.ui.toast)
        replay = app.ui.replay
        self.play(2000, until=lambda: not replay.active)
        self.assertFalse(replay.active)
        self.driver.at(1, lambda: click(harness.end_turn_rect(app).center))
        self.play_script(40, until=lambda: self.world.turn == 3)
        self.assertEqual(self.world.turn, 3, "when it is over the button works again")

    def test_the_map_can_be_panned_and_zoomed_during_the_replay(self):
        app = self.start()
        self.season_with_walk(seen=True)
        zoom, camera = app.view.zoom, list(app.camera)
        self.driver.at(1, key("-"))
        self.driver.at(2, drag((600, 300), (400, 300)))
        self.play_script(6)
        self.assertEqual(app.view.zoom, zoom - 1)
        self.assertNotEqual(list(app.camera), camera)
        self.assertTrue(app.ui.replay.active, "still playing")
        self.assertEqual(self.world.turn, 2)

    def test_the_clock_waits_while_a_screen_is_up(self):
        app = self.start()
        self.season_with_walk(seen=True)
        app.open_menu()
        self.play(10)
        self.assertEqual(app.ui.replay.t, 0.0, "the pause menu holds the replay")


class OwnMovesTest(ReplayCase):
    def test_the_players_own_long_move_walks_and_blocks_end_season(self):
        app = self.start()
        w = self.world
        group, dest = self.stack("POR")
        w.visible = set(w.terrain)
        app.select_unit(group[0])
        w.bus.drain()
        w.move_group(group, dest)
        app.process_events()
        replay = app.ui.replay
        self.assertTrue(replay.active)
        app.end_turn()
        self.assertEqual(w.turn, 1, "End season waits")
        steps = len(w.last_move[1]) - 1
        self.play(steps * 20 + 20, until=lambda: not replay.active)
        self.assertFalse(replay.active)

    def test_one_step_moves_are_replayed_too_and_are_short(self):
        app = self.start()
        w = self.world
        unit = w.units_of("POR")[0]
        near = next(p for p in w.reachable_group([unit]) if p != unit.pos)
        w.bus.drain()
        w.move_group([unit], near)
        app.process_events()
        self.assertEqual(app.ui.replay.pending[0].count, 1)


class HoverAndSelectionTest(ReplayCase):
    def test_no_hover_or_pick_on_the_destination_of_a_walking_stack_and_it_is_not_drawn_selected(self):
        app = self.start()
        group, start, dest, path = self.season_with_walk(seen=True)
        app.look_at(path[len(path) // 2])
        app.draw()
        pixel = hex_pixel(app, dest)
        self.assertIsNone(app.hex_under(pixel), "the stack is still walking: nothing there")
        drawn = []
        real = app.view._draw_stack
        app.view._draw_stack = lambda screen, stack, top, point, selected, side=None: (
            drawn.append((group[0] in stack, selected)), real(screen, stack, top, point, selected, side))
        app.ui.replay.t = app.ui.replay.legs[0].step * 1.5
        app.draw()
        self.assertIn((True, False), drawn, "an enemy stack walking is not drawn as the player's selection")
        app.ui.replay.skip()
        self.assertEqual(app.hex_under(pixel), dest)


class ShippedDefaultsTest(harness.UITestCase):
    def test_seasons_with_the_shipped_options_go_through_the_reminders_and_the_replay(self):
        from unittest import mock
        import play
        from hexa import settings
        from hexa.campaign import ai
        from hexa.campaign.app import CampaignApp
        from hexa.campaign.screens.reminders import ReminderScreen
        from tests import SHIPPED_DEFAULTS
        settings.save(dict(SHIPPED_DEFAULTS))
        app = CampaignApp(play.TILES_DIR, "POR")
        w = app.world
        self.assertEqual((app.settings["movement"], app.settings["reminders"]), ("normal", True))
        group = next(g for g in ([u for u in w.units_at(x.pos) if u.owner == "CAS"] for x in w.units_of("CAS")
                                 if not x.naval) if any(len(w.route(g, p)) >= 4 for p in w.reachable_group(g)))
        dest = next(p for p in sorted(w.reachable_group(group)) if len(w.route(group, p)) >= 4)
        path = w.route(group, dest)
        real, walked = ai.run, []

        def run(world, who):
            if who == "CAS" and not walked:
                walked.append(1)
                world.visible = world.visible | set(path)
                world.move_group(group, dest)
            return real(world, who)

        def loop(frames, *steps, until=None):
            self.driver.reset()
            app.running, app.result = True, None
            for frame, events in steps:
                self.driver.at(frame, events)
            self.driver.run_for(frames, until)
            app.run()
        with mock.patch.object(ai, "run", run):
            loop(6, (1, harness.key("space")))
            self.assertIsInstance(app.screens.top, ReminderScreen)
            self.assertEqual(w.turn, 1)
            loop(10, (1, harness.key("return")), until=lambda: w.turn == 2)
        self.assertEqual(w.turn, 2)
        self.assertTrue(app.ui.replay.active, "the walk of the other country is being shown")
        loop(30, (1, harness.key("space")))                      # the first Space skips the replay
        self.assertFalse(app.ui.replay.active)
        self.assertEqual(w.turn, 2)
        loop(6, (1, harness.key("space")))
        self.assertIsInstance(app.screens.top, ReminderScreen)
        loop(20, (1, harness.key("return")), until=lambda: w.turn == 3)
        self.assertEqual(w.turn, 3)


class DrawingTest(ReplayCase):
    def test_drawing_frames_never_changes_the_world(self):
        import pickle
        app = self.start()
        self.season_with_walk(seen=True)
        w = self.world
        before = (quick_digest(w), pickle.dumps(w.save_state(), protocol=pickle.HIGHEST_PROTOCOL), w.version)
        replay = app.ui.replay
        for _ in range(60):
            replay.advance(FRAME_MS)
            app.draw()
        replay.skip()
        app.draw()
        after = (quick_digest(w), pickle.dumps(w.save_state(), protocol=pickle.HIGHEST_PROTOCOL), w.version)
        self.assertEqual(before[0], after[0])
        self.assertEqual(before[1], after[1], "save_state is the same bytes")
        self.assertEqual(before[2], after[2], "no redraw invalidation either")


class RibbonTest(harness.UITestCase):
    """The floating text of a battle or a capture waits until the replay has got to its hex (hud.Hud._timed)."""

    def setUp(self):
        super().setUp()
        from hexa.campaign.hud import Hud
        from hexa.campaign.replay import Replay
        self.hud, self.r = Hud(), Replay()
        self.ctx = SimpleNamespace(ui=SimpleNamespace(replay=self.r))

    @staticmethod
    def walk(row, ids=(1,)):
        from hexa.events import Event
        return Event("unit_moved", "FRA", row[-1], {"ids": list(ids), "path": tuple(row), "seen": (True,) * len(row)})

    def test_ready_at_is_when_a_walk_ends_on_or_next_to_the_hex(self):
        from hexa.campaign.replay import PACE
        self.r.record(self.walk([(i, 5) for i in range(4)]))
        end = 3 * PACE["normal"][0]
        self.assertEqual(self.r.ready_at((3, 5)), end)
        self.assertEqual(self.r.ready_at((4, 5)), end, "the hex the army attacks, next door")
        self.assertEqual(self.r.ready_at((30, 30)), 0.0, "no walk ends there: nothing to wait for")

    def test_a_ribbon_waits_then_floats_and_skipping_releases_it(self):
        item = SimpleNamespace(pos=(4, 5))
        self.r.record(self.walk([(i, 5) for i in range(4)]))
        self.assertEqual(self.hud._timed(self.ctx, [item]), [], "the army has not arrived")
        self.r.t = 5000
        self.assertEqual(self.hud._timed(self.ctx, []), [item], "now it has")
        self.r.record(self.walk([(i, 9) for i in range(4)], ids=(2,)))
        again = SimpleNamespace(pos=(4, 9))
        self.assertEqual(self.hud._timed(self.ctx, [again]), [])
        self.r.skip()
        self.assertEqual(self.hud._timed(self.ctx, []), [again])

    def test_with_no_replay_ribbons_float_at_once(self):
        item = SimpleNamespace(pos=(4, 5))
        self.assertEqual(self.hud._timed(self.ctx, [item]), [item])


class OptionsTest(ReplayCase):
    def test_the_options_page_has_the_movement_speed_row_and_it_cycles(self):
        app = self.start()
        w = self.world
        app.pause.open(app, "options")
        app.draw()
        rect = harness.pause_button_rect(app, ("option", "movement"))
        shown = []
        for _ in range(3):
            app.pause.press(app, ("option", "movement"))
            shown.append(app.settings["movement"])
        self.assertEqual(shown, ["slow", "off", "normal"])
        self.assertIsNotNone(rect)
        self.assertEqual(w.turn, 1)
        from hexa import settings
        self.assertEqual(settings.load()["movement"], "normal", "saved for next time")


if __name__ == "__main__":
    unittest.main()
