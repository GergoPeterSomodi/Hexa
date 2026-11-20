## StateView tests (docs/architecture/m4-build-spec.md 5.2): reads fall through, an overlay never changes its base.
extends GutTest


func _state(n: int) -> MapState:
	var s := MapState.new()
	s.main_use.resize(n)
	s.level.resize(n)
	s.owner.resize(n)
	for i: int in n:
		s.main_use[i] = i % 5
		s.level[i] = i % 4
		s.owner[i] = 1 + i % 3
	return s


func test_plain_view_reads_the_base() -> void:
	var s := _state(40)
	var v := StateView.of(s)
	for i: int in 40:
		assert_eq(v.main_use_at(i), s.main_use[i])
		assert_eq(v.level_at(i), s.level[i])
	assert_eq(v.changed().size(), 0)
	assert_eq(v.state, s)


func test_overlay_wins_and_the_rest_falls_through() -> void:
	var s := _state(40)
	var v := StateView.of(s).with({7: Vector2i(3, 2), 12: Vector2i(0, 0)})
	assert_eq(v.main_use_at(7), 3)
	assert_eq(v.level_at(7), 2)
	assert_eq(v.main_use_at(12), 0)
	assert_eq(v.level_at(12), 0)
	for i: int in 40:
		if i != 7 and i != 12:
			assert_eq(v.main_use_at(i), s.main_use[i])
			assert_eq(v.level_at(i), s.level[i])


func test_changed_is_ascending() -> void:
	var v := StateView.of(_state(40)).with({30: Vector2i(1, 1), 2: Vector2i(1, 1), 17: Vector2i(2, 1)})
	assert_eq(v.changed(), PackedInt32Array([2, 17, 30]))


func test_with_returns_a_new_view_and_leaves_the_old_one() -> void:
	var s := _state(40)
	var a := StateView.of(s)
	var b := a.with({5: Vector2i(4, 3)})
	assert_ne(a, b)
	assert_eq(a.changed().size(), 0)
	assert_eq(a.main_use_at(5), s.main_use[5])
	assert_eq(b.main_use_at(5), 4)
	var c := b.with({5: Vector2i(1, 1), 6: Vector2i(2, 2)})
	assert_eq(b.main_use_at(5), 4, "chaining does not change the earlier view")
	assert_eq(b.changed(), PackedInt32Array([5]))
	assert_eq(c.main_use_at(5), 1)
	assert_eq(c.level_at(6), 2)
	assert_eq(c.changed(), PackedInt32Array([5, 6]))


func test_the_changes_dictionary_is_not_aliased() -> void:
	var changes := {3: Vector2i(2, 2)}
	var v := StateView.of(_state(10)).with(changes)
	changes[3] = Vector2i(4, 4)
	changes[4] = Vector2i(1, 1)
	assert_eq(v.main_use_at(3), 2)
	assert_eq(v.changed(), PackedInt32Array([3]))


func test_out_of_range_changes_are_dropped() -> void:
	var v := StateView.of(_state(10)).with({-1: Vector2i(1, 1), 10: Vector2i(1, 1), 9: Vector2i(2, 1)})
	assert_eq(v.changed(), PackedInt32Array([9]))


func test_base_never_changes_after_many_overlay_writes() -> void:
	var s := _state(200)
	var before := s.digest()
	var main_before := s.main_use.duplicate()
	var level_before := s.level.duplicate()
	var owner_before := s.owner.duplicate()
	var v := StateView.of(s)
	for round_i: int in 300:
		var ch := {}
		for k: int in 5:
			ch[(round_i * 7 + k * 31) % 200] = Vector2i((round_i + k) % 6, (round_i * k) % 4)
		v = v.with(ch)
		assert_eq(v.main_use_at((round_i * 7) % 200), ch[(round_i * 7) % 200].x)
	assert_gt(v.changed().size(), 50)
	assert_eq(s.digest(), before)
	assert_eq(s.main_use, main_before)
	assert_eq(s.level, level_before)
	assert_eq(s.owner, owner_before)
	assert_eq(StateView.of(s).changed().size(), 0)
