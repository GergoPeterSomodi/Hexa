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


func test_people_at_reads_the_base_and_with_people_overlays() -> void:
	var s := _state(40)
	s.people.resize(40)
	s.people_start.resize(40)
	s.people_end.resize(40)
	for i: int in 40:
		s.people[i] = i * 10
	var v := StateView.of(s)
	assert_eq(v.people_at(7), 70)
	assert_eq(v.people_at(-1), 0, "off the state reads 0")
	assert_eq(v.people_at(40), 0)
	var w := v.with_people({7: 5000, 8: 0})
	assert_eq(w.people_at(7), 5000)
	assert_eq(w.people_at(8), 0)
	assert_eq(w.people_at(9), 90, "the rest falls through")
	assert_eq(v.people_at(7), 70, "the old view is untouched")
	assert_eq(s.people[7], 70, "the base is untouched")
	assert_eq(w.people_changed(), PackedInt32Array([7, 8]))
	assert_eq(w.changed().size(), 0, "people are not main use or level changes")


func test_with_people_keeps_the_other_changes_and_later_numbers_win() -> void:
	var s := _state(40)
	s.people.resize(40)
	var a := StateView.of(s).with({3: Vector2i(4, 2)}).with_people({5: 100})
	assert_eq(a.main_use_at(3), 4, "the main use change is kept")
	assert_eq(a.level_at(3), 2)
	assert_eq(a.people_at(5), 100)
	var b := a.with({6: Vector2i(1, 1)}).with_people({5: 250, 6: 7})
	assert_eq(b.people_at(5), 250, "a later number wins")
	assert_eq(b.people_at(6), 7)
	assert_eq(b.main_use_at(3), 4, "with() after with_people keeps the people too")
	assert_eq(b.changed(), PackedInt32Array([3, 6]))
	var c := a.with({9: Vector2i(2, 2)})
	assert_eq(c.people_at(5), 100, "with() keeps the people overlay")
	assert_eq(a.people_at(6), 0, "the earlier view is untouched")
	assert_eq(a.people_at(5), 100)


func test_with_people_drops_bad_entries() -> void:
	var s := _state(10)
	s.people.resize(10)
	var v := StateView.of(s).with_people({-1: 5, 10: 5, 3: -4, 4: "7", 5: 2.5, "6": 9, 7: 12})
	assert_eq(v.people_changed(), PackedInt32Array([7]), "P: off the state, negative, text, float and text keys")
	assert_eq(v.people_at(7), 12)


func test_base_people_never_change_after_many_overlay_writes() -> void:
	var s := _state(200)
	s.people.resize(200)
	for i: int in 200:
		s.people[i] = i
	var before := s.digest()
	var v := StateView.of(s)
	for round_i: int in 300:
		v = v.with_people({(round_i * 7) % 200: round_i})
	assert_gt(v.people_changed().size(), 20)
	assert_eq(s.digest(), before)
