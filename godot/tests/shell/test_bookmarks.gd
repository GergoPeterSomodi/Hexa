## Tests for Bookmarks (docs/architecture/m3-build-spec.md section 6.12 and section 9).
extends GutTest


func test_count_is_nine() -> void:
	assert_eq(Bookmarks.COUNT, 9)


func test_empty_slot_gives_empty_dict() -> void:
	var b := Bookmarks.new()
	assert_eq(b.get_at(1), {})
	assert_eq(b.get_at(9), {})


func test_set_then_get_returns_centre_and_zoom() -> void:
	var b := Bookmarks.new()
	b.set_at(3, Vector2(120.5, -40.0), 2.5)
	var got := b.get_at(3)
	assert_eq(got["centre"], Vector2(120.5, -40.0))
	assert_eq(got["zoom"], 2.5)


func test_set_overwrites_slot() -> void:
	var b := Bookmarks.new()
	b.set_at(2, Vector2(1, 1), 1.0)
	b.set_at(2, Vector2(5, 6), 3.0)
	assert_eq(b.get_at(2)["centre"], Vector2(5, 6))
	assert_eq(b.get_at(2)["zoom"], 3.0)


func test_slots_are_independent() -> void:
	var b := Bookmarks.new()
	b.set_at(1, Vector2(1, 2), 1.0)
	b.set_at(9, Vector2(3, 4), 2.0)
	assert_eq(b.get_at(1)["centre"], Vector2(1, 2))
	assert_eq(b.get_at(9)["centre"], Vector2(3, 4))
	assert_eq(b.get_at(5), {})


func test_out_of_range_index_is_ignored() -> void:
	var b := Bookmarks.new()
	b.set_at(0, Vector2(1, 1), 1.0)
	b.set_at(10, Vector2(1, 1), 1.0)
	b.set_at(-1, Vector2(1, 1), 1.0)
	assert_eq(b.get_at(0), {})
	assert_eq(b.get_at(10), {})
	assert_eq(b.to_dict(), {})


func test_non_positive_or_non_finite_zoom_is_ignored() -> void:
	var b := Bookmarks.new()
	b.set_at(1, Vector2(1, 1), 0.0)
	b.set_at(2, Vector2(1, 1), -1.0)
	b.set_at(3, Vector2(1, 1), INF)
	b.set_at(4, Vector2(1, 1), NAN)
	assert_eq(b.to_dict(), {})


func test_round_trip_through_dict() -> void:
	var b := Bookmarks.new()
	b.set_at(1, Vector2(10, 20), 1.5)
	b.set_at(7, Vector2(-3.25, 0.5), 4.0)
	var restored := Bookmarks.from_dict(b.to_dict())
	assert_eq(restored.get_at(1), b.get_at(1))
	assert_eq(restored.get_at(7), b.get_at(7))
	assert_eq(restored.get_at(4), {})
	assert_eq(restored.to_dict(), b.to_dict())


func test_round_trip_survives_json() -> void:
	var b := Bookmarks.new()
	b.set_at(5, Vector2(12.0, 34.0), 2.0)
	var text := JSON.stringify(b.to_dict())
	var parsed: Variant = JSON.parse_string(text)
	var restored := Bookmarks.from_dict(parsed)
	assert_eq(restored.get_at(5)["centre"], Vector2(12.0, 34.0))
	assert_eq(restored.get_at(5)["zoom"], 2.0)


func test_from_dict_drops_bad_keys() -> void:
	var d := {
		"0": {"centre": [1, 1], "zoom": 1.0},
		"10": {"centre": [1, 1], "zoom": 1.0},
		"abc": {"centre": [1, 1], "zoom": 1.0},
		"2.0": {"centre": [1, 1], "zoom": 1.0},
		"4": {"centre": [1, 1], "zoom": 1.0},
	}
	var b := Bookmarks.from_dict(d)
	assert_eq(b.to_dict().keys().size(), 1)
	assert_eq(b.get_at(4)["zoom"], 1.0)


func test_from_dict_drops_bad_entries() -> void:
	var d := {
		"1": "not a dict",
		"2": {"centre": [1, 1]},
		"3": {"zoom": 1.0},
		"4": {"centre": [1, 1, 1], "zoom": 1.0},
		"5": {"centre": ["a", "b"], "zoom": 1.0},
		"6": {"centre": [1, 1], "zoom": "big"},
		"7": {"centre": [1, 1], "zoom": 0.0},
		"8": {"centre": [1, 1], "zoom": -2.0},
		"9": {"centre": [INF, 1], "zoom": 1.0},
	}
	var b := Bookmarks.from_dict(d)
	assert_eq(b.to_dict(), {})


func test_from_dict_keeps_good_entries_beside_bad() -> void:
	var d := {
		"1": {"centre": [3, 4], "zoom": 2.0},
		"2": {"centre": "oops", "zoom": 2.0},
		"3": {"centre": [5, 6], "zoom": 1.0},
	}
	var b := Bookmarks.from_dict(d)
	assert_eq(b.get_at(1)["centre"], Vector2(3, 4))
	assert_eq(b.get_at(2), {})
	assert_eq(b.get_at(3)["centre"], Vector2(5, 6))


func test_from_dict_empty_gives_empty() -> void:
	var b := Bookmarks.from_dict({})
	assert_eq(b.to_dict(), {})
	assert_eq(b.get_at(1), {})
