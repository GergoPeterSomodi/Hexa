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


func test_notable_holds_the_money_kinds() -> void:
	assert_true(Chronicle.NOTABLE.has("goods_short"))
	assert_true(Chronicle.NOTABLE.has("tax_set"))


func test_money_events_are_stored_plain() -> void:
	var c := Chronicle.new()
	c.add({"kind": &"goods_short", "turn": 2, "tag": &"GEN", "good": &"salt", "need": 1, "taken": 0, "witnesses": [&"GEN"]})
	c.add({"kind": &"tax_set", "turn": 2, "tag": &"GEN", "level": 2, "from": 1})
	var short := c.of_turn(2)[0]
	assert_true(short["good"] is String)
	assert_eq(short["witnesses"], PackedStringArray(["GEN"]))
	assert_eq(c.of_turn(2)[1]["level"], 2)


func test_notable_holds_the_people_kinds_and_the_five_army_kinds() -> void:
	assert_true(Chronicle.NOTABLE.has("town_grew"))
	assert_true(Chronicle.NOTABLE.has("district_declined"))
	# M6 (m6-build-spec.md 4.11, D38): the five notable army kinds; army_changed and unit_moved are not notable.
	for kind: String in ["army_raised", "army_disbanded", "march_halted", "army_starved", "unit_lost"]:
		assert_true(Chronicle.NOTABLE.has(kind), kind)
	assert_false(Chronicle.NOTABLE.has("army_changed"))
	assert_false(Chronicle.NOTABLE.has("unit_moved"))
	assert_eq(Chronicle.NOTABLE.size(), 20, "M7 adds six war kinds (4.14)")


func test_people_events_are_stored_plain() -> void:
	var c := Chronicle.new()
	c.add({"kind": &"town_grew", "turn": 3, "tag": &"GEN", "hex": Vector2i(6, 13), "level": 3, "from": 2, "people": 4000})
	c.add({"kind": &"district_declined", "turn": 3, "tag": &"GEN", "hex": Vector2i(6, 13), "family": 1, "level": 2, "from": 3,
		"people": 1900, "why": &"hunger"})
	var back := Chronicle.from_dict(c.to_dict())
	assert_eq(back.entries[0]["tag"], "GEN")
	assert_eq(back.entries[1]["why"], "hunger")
	assert_eq(back.entries[1]["hex"], Vector2i(6, 13))
	assert_eq(back.digest(), c.digest())
