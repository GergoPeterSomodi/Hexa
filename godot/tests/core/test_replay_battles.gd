## The movement replay's battle marks and retreat walks (docs/architecture/m7-build-spec.md 5.6, B20): ReplayPlan.record_battle
## and marks(), and a retreat walk (one that starts on a battle hex after the battle's tick) laid after the movement's last tick.
## Pure: records and a fake clock; no game, no engine. Step times at normal speed are 0.2 s a shown tick.
extends GutTest

const A := Vector2i(1, 1)
const B := Vector2i(2, 1)
const C := Vector2i(3, 1)
const D := Vector2i(4, 1)
const X := Vector2i(5, 1)
const Y := Vector2i(6, 1)
const Z := Vector2i(7, 1)


func _p(hexes: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(hexes)
	return out


func _rec(army: int, path: Array[Vector2i], seen: Array, ticks: Array) -> Dictionary:
	return {"tag": &"SAV", "army": army, "path": path, "seen": PackedByteArray(seen), "ticks": PackedInt32Array(ticks)}


func _pose_of(poses: Array[Dictionary], army: int) -> Dictionary:
	for pose: Dictionary in poses:
		if int(pose["army"]) == army:
			return pose
	return {}


func test_a_battle_mark_shows_from_the_tick_it_began_at() -> void:
	var plan := ReplayPlan.new()
	plan.record_battle(C, 2)
	var records: Array[Dictionary] = [_rec(1, _p([A, B, C]), [1, 1, 1], [1, 2])]
	plan.setup(records, &"normal")
	assert_eq(plan.marks().size(), 0, "no mark before the clock starts")
	plan.advance(0.1)
	assert_eq(plan.marks().size(), 0, "the battle's tick (2) starts at 0.2 s")
	plan.advance(0.15)
	var marks := plan.marks()
	assert_eq(marks.size(), 1, "one mark from its tick")
	assert_eq(marks[0]["hex"], C)
	assert_true(bool(marks[0]["shown"]), "a battle the viewer may see is shown")


func test_a_battle_the_viewer_may_not_see_is_marked_hidden() -> void:
	var plan := ReplayPlan.new()
	plan.record_battle(C, 2, false)
	var records: Array[Dictionary] = [_rec(1, _p([A, B, C]), [1, 1, 1], [1, 2])]
	plan.setup(records, &"normal")
	plan.skip()
	var marks := plan.marks()
	assert_eq(marks.size(), 1)
	assert_false(bool(marks[0]["shown"]), "the shell does not draw a hidden battle")


func test_a_battle_at_tick_zero_is_refused() -> void:
	var plan := ReplayPlan.new()
	plan.record_battle(C, 0)
	var records: Array[Dictionary] = [_rec(1, _p([A, B, C]), [1, 1, 1], [1, 2])]
	plan.setup(records, &"normal")
	plan.skip()
	assert_eq(plan.marks().size(), 0, "no tick, no mark")


func test_a_retreat_walks_after_the_last_movement_tick() -> void:
	# Army 1 walks A, B, C and fights at C (tick 2). Army 2 marches to tick 4. Army 3 retreats from C on tick 3 (the
	# battle's tick + 1): it must wait until the movement's last tick (4) is over, so it starts on tick 5.
	var plan := ReplayPlan.new()
	plan.record_battle(C, 2)
	var records: Array[Dictionary] = [
		_rec(1, _p([A, B, C]), [1, 1, 1], [1, 2]),
		_rec(2, _p([X, Y, Z]), [1, 1, 1], [1, 4]),
		_rec(3, _p([C, D]), [1, 1], [3]),
	]
	plan.setup(records, &"normal")
	plan.advance(0.5)
	var waiting := _pose_of(plan.poses(), 3)
	assert_eq(waiting["from"], C, "the retreat stands on the battle hex while the movement goes on")
	assert_eq(waiting["to"], C, "and does not step yet")
	plan.advance(0.25)
	var walking := _pose_of(plan.poses(), 3)
	assert_eq(walking["from"], C, "at 0.75 s the retreat is on its first step")
	assert_eq(walking["to"], D)
	assert_gt(float(walking["t"]), 0.0)


func test_a_retreat_keeps_its_own_spacing() -> void:
	# A retreat of two steps with a gap (ticks 3 and 5) keeps the gap after the movement's last tick.
	var plan := ReplayPlan.new()
	plan.record_battle(C, 2)
	var records: Array[Dictionary] = [
		_rec(1, _p([A, B, C]), [1, 1, 1], [1, 2]),
		_rec(2, _p([X, Y, Z]), [1, 1, 1], [1, 4]),
		_rec(3, _p([C, D, A]), [1, 1, 1], [3, 5]),
	]
	plan.setup(records, &"normal")
	plan.skip()
	assert_true(plan.finished(), "the whole replay, retreat included, plays out")
	var end_pose := plan.poses()
	assert_eq(end_pose.size(), 0, "a finished walk leaves the poses")
	assert_gt(plan.duration(), 0.8, "the retreat's two steps come after tick 4")


func test_a_walk_that_does_not_start_on_a_battle_hex_is_not_moved() -> void:
	# Army 2 walks from X, not from the battle hex: it keeps its own ticks (no retreat rule).
	var plan := ReplayPlan.new()
	plan.record_battle(C, 2)
	var records: Array[Dictionary] = [
		_rec(1, _p([A, B, C]), [1, 1, 1], [1, 2]),
		_rec(2, _p([X, Y]), [1, 1], [1]),
	]
	plan.setup(records, &"normal")
	plan.advance(0.05)
	var pose := _pose_of(plan.poses(), 2)
	assert_eq(pose["to"], Y, "army 2 steps at tick 1, as the core recorded it")
	assert_gt(float(pose["t"]), 0.0)


## R50: a battle of the chained at-once walks does not make a later phase walk from its hex a retreat.
func test_a_phase_walk_from_an_at_once_battle_hex_is_not_a_retreat() -> void:
	var records: Array[Dictionary] = [
		_rec(1, _p([A, B, C]), [1, 1, 1], [1, 2]),
		_rec(2, _p([C, D]), [1, 1], [1]),
	]
	records[0]["now"] = true
	var chained := ReplayPlan.chain(records)
	var plan := ReplayPlan.new()
	plan.record_battle(C, 2)
	plan.setup(chained, &"normal")
	assert_almost_eq(plan.duration(), 0.6, 0.001, "ticks 1, 2 (at once) then 3 (phase): three shown ticks, no retreat laid after")
	plan.advance(0.5)
	var pose := _pose_of(plan.poses(), 2)
	assert_eq(pose["to"], D, "the phase walk steps on tick 3, as chained")
	assert_gt(float(pose["t"]), 0.0)
