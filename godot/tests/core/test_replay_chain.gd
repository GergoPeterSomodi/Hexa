## ReplayPlan.chain (docs/architecture/moves-build-spec.md R50, D20): the at-once walks of the computer (records with `now`) are
## laid one after another in arrival order, a retreat right after its battle's walk, then the phase's walks after the last of
## them. Pure: records and a fake clock; no game, no engine. A shown tick takes 0.2 s at normal speed.
extends GutTest

const A := Vector2i(1, 1)
const B := Vector2i(2, 1)
const C := Vector2i(3, 1)
const D := Vector2i(4, 1)
const E := Vector2i(5, 1)
const F := Vector2i(6, 1)
const G := Vector2i(7, 1)


func _p(hexes: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(hexes)
	return out


func _rec(army: int, path: Array[Vector2i], ticks: Array, now: bool = false) -> Dictionary:
	var seen := PackedByteArray()
	seen.resize(path.size())
	seen.fill(1)
	return {"tag": &"SAV", "army": army, "path": path, "seen": seen, "ticks": PackedInt32Array(ticks), "now": now}


func _pose_of(poses: Array[Dictionary], army: int) -> Dictionary:
	for pose: Dictionary in poses:
		if int(pose["army"]) == army:
			return pose
	return {}


func _ticks_of(records: Array[Dictionary], army: int) -> Array:
	for r: Dictionary in records:
		if int(r["army"]) == army:
			return Array(r["ticks"] as PackedInt32Array)
	return []


func test_records_with_no_now_are_unchanged() -> void:
	var records: Array[Dictionary] = [_rec(1, _p([A, B, C]), [1, 2]), _rec(2, _p([D, E]), [1])]
	var chained := ReplayPlan.chain(records)
	assert_eq(chained.size(), 2)
	assert_eq(_ticks_of(chained, 1), [1, 2], "the phase's ticks are as they were")
	assert_eq(_ticks_of(chained, 2), [1])
	assert_false(bool(chained[0].get("fixed", false)), "a phase walk is not fixed")


func test_two_at_once_walks_on_the_same_ticks_are_laid_one_after_another() -> void:
	var records: Array[Dictionary] = [_rec(1, _p([A, B, C]), [1, 2], true), _rec(2, _p([D, E, F]), [1, 2], true)]
	var chained := ReplayPlan.chain(records)
	assert_eq(_ticks_of(chained, 1), [1, 2])
	assert_eq(_ticks_of(chained, 2), [3, 4], "P: the second walk starts after the first one ended")
	assert_true(bool(chained[1]["fixed"]), "a chained walk is fixed")


func test_a_retreat_comes_right_after_its_battles_walk_and_before_the_next_walk() -> void:
	# Army 1 walks A, B, C (ticks 1, 2) and fights at C; army 3 retreats from C (ticks 3, 4); army 2 then walks D, E (tick 1).
	var records: Array[Dictionary] = [
		_rec(1, _p([A, B, C]), [1, 2], true),
		_rec(3, _p([C, D, E]), [3, 4], true),
		_rec(2, _p([F, G]), [1], true)]
	var chained := ReplayPlan.chain(records)
	assert_eq(_ticks_of(chained, 3), [3, 4], "the retreat keeps its place after the battle")
	assert_eq(_ticks_of(chained, 2), [5], "the next walk comes after the retreat")


func test_the_phases_walks_come_after_the_last_at_once_walk_in_their_own_order() -> void:
	var records: Array[Dictionary] = [
		_rec(4, _p([A, B, C]), [1, 2]),
		_rec(1, _p([D, E]), [1], true),
		_rec(5, _p([F, G]), [2])]
	var chained := ReplayPlan.chain(records)
	assert_eq(_ticks_of(chained, 1), [1])
	assert_eq(_ticks_of(chained, 4), [2, 3], "the phase's spacing is kept after the at-once walk")
	assert_eq(_ticks_of(chained, 5), [3])
	assert_eq(chained[0]["army"], 1, "the at-once walks come first, then the phase's in record order")
	assert_eq(chained[1]["army"], 4)


func test_chain_leaves_its_input_alone() -> void:
	var records: Array[Dictionary] = [_rec(1, _p([A, B]), [1], true), _rec(2, _p([C, D]), [1], true)]
	ReplayPlan.chain(records)
	assert_eq(Array(records[1]["ticks"] as PackedInt32Array), [1], "the records the caller holds keep their ticks")
	assert_false(records[1].has("fixed"))


func test_an_empty_list_chains_to_nothing() -> void:
	var none: Array[Dictionary] = []
	assert_eq(ReplayPlan.chain(none).size(), 0)


func test_chained_walks_play_one_after_another_not_together() -> void:
	var records: Array[Dictionary] = [_rec(1, _p([A, B]), [1], true), _rec(2, _p([C, D]), [1], true)]
	var plan := ReplayPlan.new()
	plan.setup(ReplayPlan.chain(records), &"normal")
	assert_almost_eq(plan.duration(), 0.4, 0.001, "two steps, one after the other")
	plan.advance(0.1)
	var poses := plan.poses()
	assert_almost_eq(float(_pose_of(poses, 1)["t"]), 0.5, 0.01, "the first walk is half way")
	var second := _pose_of(poses, 2)
	assert_eq(second["from"], C, "P: the second walk waits on its first hex")
	assert_eq(second["to"], C)
	assert_eq(float(second["t"]), 0.0)
	plan.advance(0.2)
	poses = plan.poses()
	assert_true(_pose_of(poses, 1).is_empty(), "the first walk has finished")
	assert_almost_eq(float(_pose_of(poses, 2)["t"]), 0.5, 0.01, "the second walk is half way")


func test_unchained_the_same_walks_play_together() -> void:
	# The unchained plan (what a season of two at-once walks showed before R50): both walks on tick 1.
	var records: Array[Dictionary] = [_rec(1, _p([A, B]), [1]), _rec(2, _p([C, D]), [1])]
	var plan := ReplayPlan.new()
	plan.setup(records, &"normal")
	assert_almost_eq(plan.duration(), 0.2, 0.001, "one tick: the armies would pass each other that never met")


func test_an_at_once_retreat_is_not_moved_after_a_later_walks_ticks() -> void:
	# Fight at C (tick 2) then the retreat (ticks 3, 4), then another walk of ticks 1..3: the retreat stays after its battle.
	var records: Array[Dictionary] = [
		_rec(1, _p([A, B, C]), [1, 2], true),
		_rec(3, _p([C, D, E]), [3, 4], true),
		_rec(2, _p([F, G, F]), [1, 2], true)]
	var plan := ReplayPlan.new()
	plan.record_battle(C, 2)
	plan.setup(ReplayPlan.chain(records), &"normal")
	plan.advance(0.7)
	var poses := plan.poses()
	assert_eq(_pose_of(poses, 3)["to"], E, "the retreat is on its second step: it was not pushed after the later walk")
	assert_eq(_pose_of(poses, 2)["from"], F, "the later walk has not begun to move")
	assert_eq(_pose_of(poses, 2)["to"], F)


func test_a_phase_battle_after_at_once_walks_still_has_its_retreat_after_the_movement() -> void:
	# At-once walk (tick 1); the phase: army 4 walks to C (ticks 2, 3 after the shift) and fights there (battle tick 3);
	# army 5 retreats from C with ticks 4.. ; army 6 walks on to tick 5. The retreat is laid after the last movement tick.
	var records: Array[Dictionary] = [
		_rec(1, _p([A, B]), [1], true),
		_rec(4, _p([D, E, C]), [1, 2]),
		_rec(6, _p([F, G]), [4]),
		_rec(5, _p([C, B]), [3])]
	var chained := ReplayPlan.chain(records)
	var plan := ReplayPlan.new()
	plan.record_battle(C, 3)
	plan.setup(chained, &"normal")
	plan.advance(0.7)
	var poses := plan.poses()
	assert_eq(_pose_of(poses, 5)["from"], C, "army 5 still stands on the battle hex while the movement goes on")
	assert_eq(_pose_of(poses, 5)["to"], C)
