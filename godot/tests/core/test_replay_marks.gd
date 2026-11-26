## ReplayMarks (docs/architecture/m7-build-spec.md 5.6, B20): a battle the shell heard (battle_started, battle_joined) gets the
## movement tick of the walk that ends on its hex, and the viewer's flag. Pure: records and events, with no game (the fog and the
## battle sites need one; with none nothing is shown).
extends GutTest

const A := Vector2i(1, 1)
const B := Vector2i(2, 1)
const C := Vector2i(3, 1)
const D := Vector2i(4, 1)


func _p(hexes: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(hexes)
	return out


func _walk(tag: StringName, path: Array[Vector2i], ticks: Array) -> Dictionary:
	return {"tag": tag, "army": 1, "path": path, "seen": PackedByteArray(), "ticks": PackedInt32Array(ticks)}


func _event(hex: Vector2i, tag: StringName) -> Dictionary:
	return {"hex": hex, "tag": tag}


func test_the_tick_is_the_last_step_of_the_walk_that_ends_on_the_hex() -> void:
	var records: Array[Dictionary] = [_walk(&"SAV", _p([A, B, C]), [1, 2])]
	var events: Array[Dictionary] = [_event(C, &"SAV")]
	var out := ReplayMarks.battles(records, events, null, &"")
	assert_eq(out.size(), 1)
	assert_eq(out[0]["hex"], C)
	assert_eq(int(out[0]["tick"]), 2, "the step onto the battle hex is tick 2")
	assert_false(bool(out[0]["shown"]), "no game: nothing is shown")


func test_an_event_with_no_walk_on_its_hex_is_left_out() -> void:
	var records: Array[Dictionary] = [_walk(&"SAV", _p([A, B]), [1])]
	var events: Array[Dictionary] = [_event(D, &"SAV")]
	assert_eq(ReplayMarks.battles(records, events, null, &"").size(), 0)


func test_a_walk_of_another_country_does_not_match() -> void:
	var records: Array[Dictionary] = [_walk(&"MIL", _p([A, B, C]), [1, 2])]
	var events: Array[Dictionary] = [_event(C, &"SAV")]
	assert_eq(ReplayMarks.battles(records, events, null, &"").size(), 0)


func test_a_retreat_walk_does_not_match_its_battle() -> void:
	# A retreat starts on the battle hex and ends elsewhere: it never ends on the hex, so it is no tick for the battle.
	var records: Array[Dictionary] = [_walk(&"SAV", _p([C, D]), [3])]
	var events: Array[Dictionary] = [_event(C, &"SAV")]
	assert_eq(ReplayMarks.battles(records, events, null, &"").size(), 0)


func test_each_event_keeps_its_order_and_its_own_tick() -> void:
	var records: Array[Dictionary] = [
		_walk(&"SAV", _p([A, B]), [1]),
		_walk(&"MIL", _p([D, C]), [2]),
	]
	var events: Array[Dictionary] = [_event(B, &"SAV"), _event(C, &"MIL")]
	var out := ReplayMarks.battles(records, events, null, &"")
	assert_eq(out.size(), 2)
	assert_eq(out[0]["hex"], B)
	assert_eq(int(out[0]["tick"]), 1)
	assert_eq(out[1]["hex"], C)
	assert_eq(int(out[1]["tick"]), 2)


## R50: the marks of chained walks take the chained ticks, so the second at-once battle's mark comes after the first walk.
func test_the_tick_of_a_chained_walk_is_its_laid_tick() -> void:
	var records: Array[Dictionary] = [_walk(&"SAV", _p([A, B]), [1]), _walk(&"MIL", _p([D, C]), [1])]
	records[0]["now"] = true
	records[1]["now"] = true
	var events: Array[Dictionary] = [_event(B, &"SAV"), _event(C, &"MIL")]
	var out := ReplayMarks.battles(ReplayPlan.chain(records), events, null, &"")
	assert_eq(out.size(), 2)
	assert_eq(int(out[0]["tick"]), 1)
	assert_eq(int(out[1]["tick"]), 2, "P: both battles on tick 1 would be shown together")
