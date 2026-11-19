## Chronicle tests (docs/architecture/m3-build-spec.md 4.4, 5.2, 9).
extends GutTest


func test_add_and_of_turn() -> void:
	var c := Chronicle.new()
	c.add({"kind": "work_started", "turn": 1})
	c.add({"kind": "work_finished", "turn": 2})
	c.add({"kind": "work_started", "turn": 2})
	assert_eq(c.of_turn(2).size(), 2)
	assert_eq(c.of_turn(1).size(), 1)
	assert_eq(c.of_turn(3).size(), 0)
	assert_eq(str(c.of_turn(2)[0]["kind"]), "work_finished", "oldest first")


func test_keeps_the_newest_3000() -> void:
	var c := Chronicle.new()
	for i: int in 3001:
		c.add({"kind": "work_started", "turn": i})
	assert_eq(c.entries.size(), 3000)
	assert_eq(int(c.entries[0]["turn"]), 1)
	assert_eq(int(c.entries[2999]["turn"]), 3000)


func test_plain_types() -> void:
	var p := Chronicle.plain({"kind": &"owners_changed", "tag": &"GEN", "others": [&"LUC", &"VEN"],
		"hexes": [Vector2i(1, 2)], "nested": {"a": &"b"}})
	assert_true(p["kind"] is String)
	assert_true(p["tag"] is String)
	assert_true(p["others"] is PackedStringArray)
	assert_eq(p["others"], PackedStringArray(["LUC", "VEN"]))
	assert_eq(p["hexes"], [Vector2i(1, 2)])
	assert_true(p["nested"]["a"] is String)


func test_round_trip_through_bytes_gives_equal_digest() -> void:
	var c := Chronicle.new()
	c.add({"kind": &"owners_changed", "turn": 3, "tag": &"GEN", "others": [&"LUC"], "hexes": [Vector2i(1, 2)]})
	var back := Chronicle.from_dict(bytes_to_var(var_to_bytes(c.to_dict())) as Dictionary)
	assert_not_null(back)
	assert_eq(back.digest(), c.digest())


func test_wrong_schema_gives_null() -> void:
	var d := Chronicle.new().to_dict()
	d["schema"] = "nope"
	assert_null(Chronicle.from_dict(d))
