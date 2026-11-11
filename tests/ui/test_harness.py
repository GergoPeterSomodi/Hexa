"""tests/support/harness.py itself: fake time, the frame script and budget, the patches and the helpers.

The UI tests rely on these rules (a single QUIT, nothing leaking into the next loop, deterministic frames), so
they are pinned here. Run with: python -m unittest tests.ui.test_harness
"""
import os
import shutil
import tempfile
import time
import unittest
from unittest import mock

from tests.support import harness
from tests.support.digests import world_digest
from tests.support.harness import click, drag, hover, key, wheel


def _drain():
    import pygame
    return [(e.type, getattr(e, "key", None)) for e in pygame.event.get()]


class FakeTimeTest(harness.UITestCase):
    def test_install_is_done_once(self):
        import pygame
        self.assertIs(harness.install(), self.driver)
        self.assertIs(pygame.time.Clock, harness.FakeClock)
        self.assertEqual(pygame.time.get_ticks(), harness.START_MS)

    def test_a_clock_tick_moves_fake_time_one_frame_and_never_sleeps(self):
        import pygame
        clock = pygame.time.Clock()
        began = time.perf_counter()
        for _ in range(1000):                  # a real Clock.tick(60) would take about 17 seconds
            clock.tick(60)
        self.assertLess(time.perf_counter() - began, 5)
        self.assertEqual(self.driver.frame, 1000)
        self.assertEqual(pygame.time.get_ticks(), harness.START_MS + 1000 * harness.FRAME_MS)

    def test_reset_restarts_the_clock_and_empties_the_event_queue(self):
        import pygame
        self.driver.run_for(1)
        pygame.time.Clock().tick()
        self.driver.at(5, key("space"))
        pygame.event.post(pygame.event.Event(pygame.USEREVENT))
        self.driver.reset()
        self.assertEqual((self.driver.frame, pygame.time.get_ticks(), self.driver.stopped_by),
                         (0, harness.START_MS, None))
        self.assertEqual(_drain(), [], "the QUIT and the user event are gone")
        for _ in range(10):
            pygame.time.Clock().tick()
        self.assertEqual(_drain(), [], "and so is the scripted key")


class ScriptTest(harness.UITestCase):
    def tick(self, n=1):
        import pygame
        clock = pygame.time.Clock()
        for _ in range(n):
            clock.tick()

    def test_events_are_posted_when_their_frame_comes(self):
        import pygame
        self.driver.at(0, key("a"))
        self.assertEqual(_drain(), [(pygame.KEYDOWN, pygame.K_a), (pygame.KEYUP, pygame.K_a)], "frame 0: at once")
        self.driver.at(3, key("b"))
        self.tick(2)
        self.assertEqual(_drain(), [])
        self.tick()
        self.assertEqual(_drain(), [(pygame.KEYDOWN, pygame.K_b), (pygame.KEYUP, pygame.K_b)])

    def test_a_callable_runs_when_its_frame_comes(self):
        seen = []
        self.driver.at(2, lambda: seen.append(self.driver.frame))
        self.tick(3)
        self.assertEqual(seen, [2])

    def test_the_budget_ends_with_exactly_one_quit_and_nothing_after_it(self):
        import pygame
        self.driver.at(3, key("x"))
        self.driver.at(4, key("y"))
        self.driver.run_for(3)
        self.tick(10)
        self.assertEqual(self.driver.stopped_by, "budget")
        self.assertEqual(_drain(), [(pygame.KEYDOWN, pygame.K_x), (pygame.KEYUP, pygame.K_x), (pygame.QUIT, None)])

    def test_until_ends_the_run_as_soon_as_it_is_true(self):
        import pygame
        self.driver.run_for(100, until=lambda: self.driver.frame == 7)
        self.tick(20)
        self.assertEqual(self.driver.stopped_by, "until")
        self.assertEqual(_drain(), [(pygame.QUIT, None)])

    def test_a_loop_that_ignores_quit_raises_instead_of_hanging(self):
        self.driver.run_for(5)
        with self.assertRaises(harness.RunawayLoop):
            self.tick(5 + harness.GRACE_FRAMES + 1)

    def test_the_grace_frames_count_from_an_early_quit_not_from_the_budget_end(self):
        self.driver.run_for(1000, until=lambda: self.driver.frame == 3)
        self.tick(3 + harness.GRACE_FRAMES)             # the QUIT came at frame 3: still within its grace
        self.assertEqual(self.driver.stopped_by, "until")
        with self.assertRaises(harness.RunawayLoop):
            self.tick()
        self.assertEqual(self.driver.frame, 3 + harness.GRACE_FRAMES + 1)


class PatchTest(harness.UITestCase):
    def test_sysfont_is_the_bundled_font_whatever_the_name(self):
        import pygame
        font = pygame.font.SysFont("segoeui,arial", 17, bold=True)
        bundled = pygame.font.Font(None, 17)
        bundled.set_bold(True)
        self.assertTrue(font.get_bold())
        self.assertEqual(font.size("Hexa: Age of Discovery"), bundled.size("Hexa: Age of Discovery"))

    def test_the_desktop_is_full_hd_and_smoothscale_is_generic(self):
        import pygame
        self.assertEqual(pygame.display.get_desktop_sizes(), [harness.DESKTOP])
        self.assertEqual(pygame.transform.get_smoothscale_backend(), "GENERIC")
        self.assertEqual((os.environ["SDL_VIDEODRIVER"], os.environ["TZ"]), ("dummy", "UTC"))

    def test_uninstall_puts_the_originals_back_and_install_patches_again(self):
        import pygame
        real_clock = harness.original("Clock")
        try:
            harness.uninstall()
            self.assertIs(pygame.time.Clock, real_clock)
            self.assertIsNot(pygame.font.SysFont, harness.pinned_sysfont)
            with self.assertRaises(KeyError):
                harness.original("Clock")
        finally:
            self.driver = harness.install()
            self.driver.reset()
        self.assertIs(pygame.time.Clock, harness.FakeClock)
        self.assertIs(harness.original("Clock"), real_clock)


class EventHelperTest(harness.UITestCase):
    def test_key_accepts_a_name_or_a_code(self):
        import pygame
        down, up = key("space")
        self.assertEqual((down.type, down.key, down.unicode, up.type),
                         (pygame.KEYDOWN, pygame.K_SPACE, " ", pygame.KEYUP))
        self.assertEqual(key(pygame.K_F5)[0].key, pygame.K_F5)

    def test_click_moves_the_mouse_there_first(self):
        import pygame
        events = click((10.4, 20.6), button=3)
        self.assertEqual([e.type for e in events], [pygame.MOUSEMOTION, pygame.MOUSEBUTTONDOWN, pygame.MOUSEBUTTONUP])
        self.assertEqual({e.pos for e in events}, {(10, 21)})
        self.assertEqual(events[1].button, 3)
        self.assertEqual(len(click((1, 1), move=False)), 2)

    def test_drag_holds_the_button_and_its_moves_add_up(self):
        import pygame
        events = drag((100, 100), (40, 130), button=3, steps=3)
        moves = [e for e in events[2:] if e.type == pygame.MOUSEMOTION]
        self.assertEqual(len(moves), 3)
        self.assertTrue(all(e.buttons == (0, 0, 1) for e in moves))
        self.assertEqual((sum(e.rel[0] for e in moves), sum(e.rel[1] for e in moves)), (-60, 30))
        self.assertEqual((events[1].type, events[-1].type, events[-1].pos),
                         (pygame.MOUSEBUTTONDOWN, pygame.MOUSEBUTTONUP, (40, 130)))

    def test_wheel_and_hover(self):
        import pygame
        motion, turn = wheel(-1, pos=(5, 6))
        self.assertEqual((motion.type, motion.pos, turn.type, turn.y),
                         (pygame.MOUSEMOTION, (5, 6), pygame.MOUSEWHEEL, -1))
        self.assertEqual(hover((7, 8))[0].buttons, (0, 0, 0))


class WhereTest(harness.UITestCase):
    """hex_pixel and the rect helpers agree with the windows' own hit tests."""

    def test_conquest(self):
        import play
        from hexa.hexgrid import pixel_to_hex
        from hexa.render import END_TURN_RECT, MAP_ORIGIN
        from hexa.rules import PLAYER, UNIT_TYPES
        app = play.App(42)
        for pos in ((0, 0), (3, 4), (app.world.cols - 1, app.world.rows - 1)):
            self.assertEqual(pixel_to_hex(harness.hex_pixel(app, pos), MAP_ORIGIN), pos)
        app.select(town=next(t for t in app.world.towns if t.owner == PLAYER))
        soldier = harness.button_rect(app, "Soldier")
        self.assertEqual(soldier, harness.button_rect(app, action=("train", UNIT_TYPES["soldier"])))
        self.assertNotEqual(soldier, harness.button_rect(app, action="train"), "the first train button is the scout")
        with self.assertRaisesRegex(LookupError, "Scout"):
            harness.button_rect(app, "Galleon")
        self.assertEqual(harness.end_turn_rect(app), END_TURN_RECT)
        self.driver.at(0, click(harness.end_turn_rect(app)))
        self.driver.run_for(300, until=lambda: app.world.turn == 2 and app.players_turn())
        app.run()
        self.assertEqual(self.driver.stopped_by, "until", "clicking End turn ended the turn")

    def test_colonisation_with_its_camera(self):
        import pygame
        import play
        from hexa.colony.app import ColonyApp
        from hexa.colony.render import END_TURN_RECT, WINDOW_SIZE
        app = ColonyApp(pygame.display.set_mode(WINDOW_SIZE), play.TILES_DIR, 5, "land", "survive")
        colony = app.world.colonies[0].pos
        app.look_at(colony)
        self.assertEqual(app.hex_at(harness.hex_pixel(app, colony)), colony)
        self.assertEqual(harness.end_turn_rect(app), END_TURN_RECT)

    def test_campaign_with_its_camera_and_zoom(self):
        import play
        from hexa.campaign.app import CampaignApp
        app = CampaignApp(play.TILES_DIR, "POR")
        capital = app.world.countries["POR"].capital
        for zoom in (1, 4):
            app.view.zoom = zoom
            app.look_at(capital)
            self.assertEqual(app.hex_under(harness.hex_pixel(app, capital)), capital, f"zoom {zoom}")
        app.draw()
        self.assertTrue(harness.end_turn_rect(app).collidepoint(harness.button_rect(app, "End season").center))
        app.open_menu()
        app.draw()
        self.assertTrue(app.menu_rect.contains(harness.pause_button_rect(app, ("page", "options"))))


class DeterminismTest(harness.UITestCase):
    def play_conquest(self):
        """Conquest seed 1 up to turn 7 through the real loop; the enemy is in sight on turns 6 and 7."""
        import play
        app = play.App(1)
        frames = []
        for turn in range(2, 8):
            start = self.driver.frame
            self.driver.at(start, key("space"))
            self.driver.run_for(3000, until=lambda: app.world.turn == turn and app.players_turn())
            app.running = True
            self.assertEqual(app.run(), "quit")
            self.assertEqual(self.driver.stopped_by, "until", f"turn {turn} never came")
            frames.append(self.driver.frame - start)
        return frames, world_digest(app.world)

    def test_the_same_script_plays_the_same_frames_twice(self):
        import play
        first = self.play_conquest()
        self.driver.reset()
        self.assertEqual(self.play_conquest(), first)
        pause = play.AI_STEP_MS // harness.FRAME_MS
        self.assertGreaterEqual(max(first[0]), pause, f"no visible enemy move paused the turn: {first[0]}")


class ArtifactTest(harness.UITestCase):
    """A failing UI test leaves its last frame in $HEXA_TEST_ARTIFACTS."""

    def test_the_last_frame_of_a_failing_test_is_saved(self):
        import pygame

        class Failing(harness.UITestCase):
            def test_it(self):
                pygame.display.set_mode((64, 48)).fill((200, 30, 30))
                self.fail("on purpose")

        folder = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, folder, True)
        result = unittest.TestResult()
        with mock.patch.dict(os.environ, {harness.ARTIFACTS_VAR: folder}), mock.patch("sys.stderr"):
            unittest.defaultTestLoader.loadTestsFromTestCase(Failing).run(result)
        self.assertEqual(len(result.failures), 1)
        saved = os.listdir(folder)
        self.assertEqual(len(saved), 1)
        self.assertRegex(saved[0], r"^tests\.ui\.test_harness\.ArtifactTest\.[\w.]+\._locals_\.Failing\.test_it\.png$")
        self.assertEqual(pygame.image.load(os.path.join(folder, saved[0])).get_at((5, 5))[:3], (200, 30, 30))


if __name__ == "__main__":
    unittest.main()
