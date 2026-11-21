## The movement replay's timeline (docs/architecture/m6-build-spec.md 6.4, 5.6; task L15): the walks laid on one clock. Pure
## records and a fake clock; no game, no engine. Ticks are played together, an unseen step takes no time, a shown step
## takes the speed's seconds, the whole replay stays within MAX_SECONDS and a step never below MIN_STEP. P: a malformed
## record is left out, a skip lands on the end.
extends GutTest

const A := Vector2i(1, 1)
const B := Vector2i(2, 1)
const C := Vector2i(3, 1)
const D := Vector2i(4, 1)


func _p(hexes: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(hexes)
	return out


func _rec(army: int, path: Array[Vector2i], seen: Array, ticks: Array) -> Dictionary:
	return {"tag": &"SAV", "army": army, "path": path, "seen": PackedByteArray(seen), "ticks": PackedInt32Array(ticks)}


func _plan(records: Array[Dictionary], speed: StringName = &"normal") -> ReplayPlan:
	var plan := ReplayPlan.new()
	plan.setup(records, speed)
	return plan


func _walk_abc() -> Array[Dictionary]:
	var path: Array[Vector2i] = [A, B, C]
	var out: Array[Dictionary] = [_rec(1, path, [1, 1, 1], [1, 2])]
	return out


func test_nothing_to_show_is_finished_at_once() -> void:
	var plan := _plan([])
	assert_eq(plan.duration(), 0.0)
	assert_true(plan.finished())
	assert_eq(plan.poses().size(), 0)


func test_a_walk_steps_hex_by_hex_on_the_clock() -> void:
	var plan := _plan(_walk_abc())
	assert_almost_eq(plan.duration(), 0.4, 0.0001, "two shown ticks at 0.2 s")
	var at_start := plan.poses()[0]
	assert_eq(at_start["from"], A)
	assert_eq(at_start["to"], B)
	assert_almost_eq(float(at_start["t"]), 0.0, 0.0001)
	plan.advance(0.1)
	assert_almost_eq(float(plan.poses()[0]["t"]), 0.5, 0.0001, "halfway through the first step")
	plan.advance(0.1)
	var second := plan.poses()[0]
	assert_eq(second["from"], B, "the second step starts where the first ends")
	assert_eq(second["to"], C)
	assert_almost_eq(float(second["t"]), 0.0, 0.0001)
	plan.advance(0.3)
	assert_true(plan.finished())
	assert_eq(plan.poses().size(), 0, "a finished walk leaves the poses: the core's hex stands")


func test_ticks_are_played_together_for_two_walks() -> void:
	var first: Array[Dictionary] = [_rec(1, _p([A, B]), [1, 1], [1])]
	var second: Array[Dictionary] = [_rec(2, _p([C, D]), [1, 1], [1])]
	var records: Array[Dictionary] = []
	records.append_array(first)
	records.append_array(second)
	var plan := _plan(records)
	assert_almost_eq(plan.duration(), 0.2, 0.0001, "one tick, not two")
	var poses := plan.poses()
	assert_eq(poses.size(), 2)
	plan.advance(0.1)
	poses = plan.poses()
	assert_almost_eq(float(poses[0]["t"]), 0.5, 0.0001)
	assert_almost_eq(float(poses[1]["t"]), 0.5, 0.0001, "the other walk is at the same fraction")


func test_an_unseen_step_takes_no_time_and_is_not_shown() -> void:
	var path: Array[Vector2i] = [A, B, C]
	var records: Array[Dictionary] = [_rec(1, path, [0, 0, 1], [1, 2])]
	var plan := _plan(records)
	assert_almost_eq(plan.duration(), 0.2, 0.0001, "only the second step (seen at C) takes time")
	var first := plan.poses()[0]
	assert_eq(first["from"], B, "the unseen first step is instant: the walker is already past B")
	assert_true(bool(first["shown"]))
	var hidden: Array[Dictionary] = [_rec(2, _p([A, B]), [0, 0], [1])]
	assert_eq(_plan(hidden).duration(), 0.0, "a walk the viewer did not see is nothing to show")


func test_a_step_is_shown_only_when_its_end_hex_is_seen() -> void:
	var path: Array[Vector2i] = [A, B]
	var records: Array[Dictionary] = [_rec(1, path, [0, 1], [1])]
	var plan := _plan(records)
	assert_true(bool(plan.poses()[0]["shown"]), "B is seen: the step is shown")
	var unseen_end: Array[Dictionary] = [_rec(2, _p([C, D]), [1, 0], [1])]
	assert_eq(_plan(unseen_end).duration(), 0.0, "P: an unseen end hex: the step is not shown, nothing to replay")


func test_strict_fog_never_shows_a_pose_on_an_unseen_hex() -> void:
	# A walks A -> B -> C; the viewer sees A and C but not B. The step into B is instant and hidden; the step to C is
	# hidden too (C is seen, so it is shown: the pose stands on C only).
	var path: Array[Vector2i] = [A, B, C]
	var records: Array[Dictionary] = [_rec(1, path, [1, 0, 1], [1, 2])]
	var plan := _plan(records)
	for step: int in range(0, 41):
		plan.advance(0.01)
		for pose: Dictionary in plan.poses():
			if bool(pose["shown"]):
				assert_ne(pose["to"], B, "P: a shown pose never stands on the unseen hex B (t %.2f)" % plan.time())
	assert_true(plan.finished())


func test_speed_sets_the_step_length() -> void:
	var slow := _plan(_walk_abc(), &"slow")
	assert_almost_eq(slow.duration(), 1.0, 0.0001, "slow: 0.5 s a step")
	var unknown := _plan(_walk_abc(), &"fast")
	assert_almost_eq(unknown.duration(), 0.4, 0.0001, "an unknown speed takes normal")


func test_the_whole_replay_is_capped_at_six_seconds() -> void:
	var path: Array[Vector2i] = [A, B]
	var records: Array[Dictionary] = []
	for t: int in range(1, 41):
		records.append(_rec(t, path, [1, 1], [t]))
	var plan := _plan(records)
	assert_almost_eq(plan.duration(), 6.0, 0.0001, "40 shown ticks share six seconds (0.15 s each)")


func test_a_step_is_never_shorter_than_min_step() -> void:
	var path: Array[Vector2i] = [A, B]
	var records: Array[Dictionary] = []
	for t: int in range(1, 201):
		records.append(_rec(t, path, [1, 1], [t]))
	var plan := _plan(records)
	assert_almost_eq(plan.duration(), 8.0, 0.0001, "200 ticks at MIN_STEP 0.04 win over the six-second cap")


func test_skip_lands_on_the_end() -> void:
	var plan := _plan(_walk_abc())
	plan.skip()
	assert_true(plan.finished())
	assert_eq(plan.poses().size(), 0)


func test_a_malformed_record_is_left_out() -> void:
	var short_seen: Array[Dictionary] = [_rec(1, _p([A, B]), [1], [1])]
	var missing_tick: Array[Dictionary] = [_rec(2, _p([A, B]), [1, 1], [])]
	var one_hex: Array[Dictionary] = [_rec(3, _p([A]), [1], [])]
	var records: Array[Dictionary] = []
	records.append_array(short_seen)
	records.append_array(missing_tick)
	records.append_array(one_hex)
	assert_eq(_plan(records).duration(), 0.0, "P: none of the three is shown")
	assert_eq(_plan(records).poses().size(), 0)


func test_the_clock_never_runs_past_the_end() -> void:
	var plan := _plan(_walk_abc())
	plan.advance(100.0)
	assert_almost_eq(plan.time(), plan.duration(), 0.0001)
	assert_true(plan.finished())
