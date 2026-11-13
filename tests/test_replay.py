"""The movement replay without a window: the ``unit_moved`` event the world emits (path and what the player saw), and
the replay's own schedule (campaign/replay.py): visible steps only, countries in turn order, the time budget, skipping,
the ribbons waiting for a hex. Pygame-free. The window's side is in tests/ui/test_replay_window.py.
Run with: python -m unittest tests.test_replay"""
import unittest

from hexa.campaign.replay import MAX_FRAME, MIN_STEP, PACE, Replay
from hexa.events import Event
from tests.support.digests import quick_digest
from tests.support.worlds import fresh


def moved(tag, path, seen=None, ids=(1,)):
    seen = tuple([True] * len(path)) if seen is None else tuple(seen)
    return Event("unit_moved", tag, path[-1], {"ids": list(ids), "path": tuple(path), "seen": seen})


def row(n, start=0):
    return [(start + i, 5) for i in range(n)]


def run_out(replay, step=16):
    """Advance until the replay ends; return the ms it took."""
    t = 0
    while replay.active and t < 60000:
        replay.advance(step)
        t += step
    return t


class EventTest(unittest.TestCase):
    """world.move_group tells the bus where a stack walked and which hexes of it the player could see."""

    def setUp(self):
        self.w = fresh("POR")
        self.w.bus.clear()

    def walker(self, tag):
        """(units of tag, a hex 3 or more steps away they can reach) for a land stack that can walk far."""
        for unit in self.w.units_of(tag):
            if unit.naval:
                continue
            group = [u for u in self.w.units_at(unit.pos) if u.owner == tag]
            reach = self.w.reachable_group(group)
            far = [p for p, cost in reach.items() if len(self.w.route(group, p)) >= 4]
            if far:
                return group, sorted(far)[0]
        self.fail(f"{tag} has no stack that can walk 3 hexes")

    def test_a_move_emits_unit_moved_with_the_whole_path(self):
        group, dest = self.walker("POR")
        start = group[0].pos
        self.assertTrue(self.w.move_group(group, dest))
        (event,) = self.w.bus.of("unit_moved")
        self.assertEqual((event.tag, event.pos), ("POR", dest))
        self.assertEqual(event.get("ids"), [u.id for u in group])
        path = event.get("path")
        self.assertEqual((path[0], path[-1]), (start, dest))
        self.assertEqual(path, tuple(self.w.last_move[1]), "the path the move recorded")
        self.assertFalse(event.get("naval"))
        self.assertEqual(event.get("seen"), (True,) * len(path), "every hex of the player's own walk is seen")

    def test_other_countries_walks_are_seen_only_where_the_player_sees(self):
        group, dest = self.walker("CAS")
        path = self.w.route(group, dest)
        self.w.visible = {path[1], path[2]}               # the player sees the middle of the walk only
        self.assertTrue(self.w.move_group(group, dest))
        seen = self.w.bus.of("unit_moved")[0].get("seen")
        self.assertEqual(seen, tuple(p in {path[1], path[2]} for p in path))

    def test_a_move_that_goes_nowhere_or_is_refused_emits_nothing(self):
        group, dest = self.walker("POR")
        self.w.move_group(group, group[0].pos)
        self.assertEqual(self.w.bus.of("unit_moved"), [])
        self.assertFalse(self.w.move_group(group, (0, 0)))
        self.assertEqual(self.w.bus.of("unit_moved"), [])

    def test_ships_say_they_are_naval(self):
        ship = next(u for u in self.w.units_of("POR") if u.naval)
        reach = self.w.reachable_group([ship])
        self.assertTrue(self.w.move_group([ship], max(reach, key=reach.get)))
        self.assertTrue(self.w.bus.of("unit_moved")[0].get("naval"))

    def test_emitting_changes_nothing_in_the_game(self):
        """The same moves with and without a listener on the bus leave the same state (the bus is never state)."""
        a, b = fresh("POR"), fresh("POR")
        b.bus.tap(lambda event: None)
        for w in (a, b):
            for unit in w.units_of("POR"):
                reach = w.reachable_group([unit])
                if reach:
                    w.move_group([unit], max(reach, key=reach.get))
        self.assertEqual(quick_digest(a), quick_digest(b))
        self.assertEqual(len(a.bus.of("unit_moved")), len(b.bus.of("unit_moved")))


class RecordTest(unittest.TestCase):
    def test_a_walk_nobody_saw_is_not_recorded(self):
        r = Replay()
        r.record(moved("FRA", row(4), [False] * 4))
        self.assertFalse(r.active)

    def test_steps_are_played_where_either_end_was_seen(self):
        r = Replay()
        r.record(moved("FRA", row(5), [False, False, True, False, False]))
        (leg,) = r.pending
        self.assertEqual(leg.vis, (False, True, True, False), "the two steps that touch the seen hex")
        self.assertEqual(leg.count, 2)

    def test_speed_off_records_nothing(self):
        r = Replay()
        r.record(moved("FRA", row(4)), "off")
        self.assertFalse(r.active)

    def test_a_one_hex_path_or_missing_data_is_ignored(self):
        r = Replay()
        r.record(moved("FRA", row(1)))
        r.record(Event("unit_moved", "FRA", (1, 1), {}))
        self.assertFalse(r.active)


class PlayTest(unittest.TestCase):
    def test_a_stack_walks_hex_by_hex_at_the_normal_pace(self):
        r = Replay()
        r.record(moved("FRA", row(4)))                       # 3 steps
        step = PACE["normal"][0]
        self.assertTrue(r.active, "waiting counts as running: End season is blocked from the first moment")
        (pose,) = r.poses()
        self.assertEqual((pose.a, pose.f, pose.shown), ((0, 5), 0.0, True), "on its first hex, about to walk")
        r.t = step * 1.5
        (pose,) = r.poses()
        self.assertEqual((pose.a, pose.b), ((1, 5), (2, 5)))
        self.assertAlmostEqual(pose.f, 0.5)
        took = run_out(Replay_with(moved("FRA", row(4))))
        self.assertAlmostEqual(took, 3 * step, delta=2 * MAX_FRAME, msg="three steps take about 3 x 0.18 s")

    def test_hidden_steps_are_instant(self):
        r = Replay()
        r.record(moved("FRA", row(6), [False, False, False, True, True, True]))     # steps 2, 3, 4 are seen
        step = PACE["normal"][0]
        r.schedule()
        self.assertEqual(r.legs[0].end, 3 * step)
        r.t = 1
        (pose,) = r.poses()
        self.assertEqual((pose.a, pose.b), ((2, 5), (3, 5)), "the fogged steps are jumped, no time spent on them")

    def test_a_stack_waits_unseen_on_a_hex_the_player_cannot_see(self):
        r = Replay()
        r.record(moved("FRA", row(4), [False, False, True, True]))
        r.record(moved("ENG", row(3, 10), ids=(2,)))
        r.schedule()
        fra = next(p for p in r.poses() if p.ids == (1,))
        self.assertEqual((fra.a, fra.f, fra.shown), ((1, 5), 0.0, True), "the fogged first step is jumped")
        r2 = Replay()
        r2.record(moved("FRA", row(3), [False, False, True]))
        r2.record(moved("ENG", row(3, 10), ids=(2,)))
        r2.schedule()
        r2.legs[0].start = 5000                               # a later turn
        waiting = next(p for p in r2.poses() if p.ids == (1,))
        self.assertEqual((waiting.a, waiting.shown), ((0, 5), False), "not drawn: the player cannot see where it is")

    def test_countries_play_in_turn_order_and_stacks_of_a_country_together(self):
        r = Replay()
        r.record(moved("FRA", row(3), ids=(1,)))
        r.record(moved("ENG", row(3, 10), ids=(2,)))
        r.record(moved("FRA", row(3, 20), ids=(3,)))
        r.schedule()
        starts = {leg.ids: leg.start for leg in r.legs}
        self.assertEqual(starts[(1,)], starts[(3,)], "one country: together")
        self.assertEqual(starts[(2,)], starts[(1,)] + 2 * PACE["normal"][0], "the next country after")

    def test_two_walks_of_one_stack_follow_each_other(self):
        r = Replay()
        r.record(moved("FRA", row(3), ids=(7,)))
        r.record(moved("FRA", row(3, 2), ids=(7,)))
        r.schedule()
        first, second = r.legs
        self.assertEqual(second.start, first.end)
        r.t = first.end / 2
        self.assertEqual([p.ids for p in r.poses()], [(7,)], "a unit is in one pose only")

    def test_the_whole_replay_is_capped_by_playing_countries_together_then_by_speeding_up(self):
        cap = PACE["normal"][1]
        step = PACE["normal"][0]
        many = Replay()
        for i in range(8):                                    # 8 countries x 10 steps: 14.4 s one after the other
            many.record(moved(f"C{i}", row(11, 100 * i), ids=(i,)))
        many.schedule()
        end = max(leg.end for leg in many.legs)
        self.assertLessEqual(end, cap)
        self.assertEqual({leg.step for leg in many.legs}, {step}, "played together, not faster")
        self.assertGreater(len({leg.start for leg in many.legs}), 1, "still not all at once")
        long = Replay()
        long.record(moved("FRA", row(61)))                    # one stack, 60 hexes: 10.8 s at the normal pace
        long.schedule()
        self.assertLessEqual(long.legs[0].end, cap + 1)
        self.assertLess(long.legs[0].step, step)
        longer = Replay()
        longer.record(moved("FRA", row(400)))
        longer.schedule()
        self.assertEqual(longer.legs[0].step, MIN_STEP, "never faster than MIN_STEP a hex")

    def test_slow_is_slower(self):
        r = Replay()
        r.record(moved("FRA", row(4)), "slow")
        r.schedule()
        self.assertEqual(r.legs[0].step, PACE["slow"][0])
        self.assertGreater(PACE["slow"][0], PACE["normal"][0])

    def test_skip_ends_it_at_once(self):
        r = Replay()
        r.record(moved("FRA", row(30)))
        r.advance(16)
        self.assertTrue(r.active)
        r.skip()
        self.assertFalse(r.active)
        self.assertEqual(r.poses(), [])

    def test_the_replay_ends_by_itself_and_a_slow_frame_does_not_jump(self):
        r = Replay()
        r.record(moved("FRA", row(3)))
        r.advance(5000)                                       # one huge frame (a season had just been computed)
        self.assertEqual(r.t, MAX_FRAME)
        self.assertTrue(r.active)
        run_out(r)
        self.assertFalse(r.active)
        self.assertEqual(r.t, 0.0)

    def test_a_new_walk_during_a_replay_starts_now(self):
        r = Replay()
        r.record(moved("FRA", row(10), ids=(1,)))
        for _ in range(20):
            r.advance(16)
        now = r.t
        r.record(moved("POR", row(3, 50), ids=(2,)))
        r.schedule()
        self.assertEqual(r.legs[-1].start, now)


def Replay_with(event, speed="normal"):
    r = Replay()
    r.record(event, speed)
    return r


if __name__ == "__main__":
    unittest.main()
