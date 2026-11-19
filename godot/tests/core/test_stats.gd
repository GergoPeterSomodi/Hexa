## Stats and the stats phase (docs/architecture/m3-build-spec.md 4.6, 5.2, 5.3, 9).
extends GutTest


func _row(v: int) -> PackedInt32Array:
	var r := PackedInt32Array()
	r.resize(Stats.SERIES.size())
	r.fill(v)
	return r


func _write(st: Stats, turn: int, v: int) -> void:
	for c: int in st.tags.size():
		st.set_row(c, turn, _row(v + c))
	st.commit(turn)


func test_series_shape() -> void:
	assert_eq(Stats.SERIES.size(), 35)
	assert_eq(Stats.column("treasury"), 0)
	assert_eq(Stats.column("land"), 12)
	assert_eq(Stats.column("nonsense"), -1)
	assert_eq(Stats.SERIES[Stats.DISTRICTS_FIRST], "districts_settlements")
	for f: int in range(1, FamilyIds.COUNT):
		assert_eq(Stats.SERIES[Stats.DISTRICTS_FIRST + f - 1], "districts_" + FamilyIds.NAMES[f])


func test_ring_wraps_at_forty() -> void:
	var st := Stats.create(PackedStringArray(["AAA", "BBB"]), 0)
	for t: int in range(1, 42):
		_write(st, t, t)
	assert_eq(st.count, 41)
	assert_true(st.row(&"AAA", 1).is_empty(), "the 1st row was overwritten by the 41st")
	assert_eq(st.value(&"AAA", 41, "treasury"), 41)
	assert_eq(st.value(&"BBB", 41, "treasury"), 42)
	assert_eq(st.value(&"AAA", 2, "treasury"), 2)
	assert_true(st.row(&"AAA", 42).is_empty(), "not written yet")
	var s := st.series(&"AAA", "treasury", 40)
	assert_eq(s.size(), 40)
	assert_eq(s[0], 2)
	assert_eq(s[39], 41)
	assert_eq(st.series(&"AAA", "treasury", 3), PackedInt32Array([39, 40, 41]))
	assert_eq(st.value(&"ZZZ", 41, "treasury"), 0)
	assert_eq(st.value(&"AAA", 41, "nonsense"), 0)


func test_year_rows_in_winter_only() -> void:
	var g := ScenarioFixture.game()
	g.act("choose_country", {"tag": &"AAA"})
	for _i: int in 3:
		Season.run(g)
	assert_eq(g.stats.count, 3)
	assert_eq(g.stats.years.size(), 0)
	Season.run(g)  # Winter
	assert_eq(g.stats.year_count(), 1)
	assert_eq(g.stats.year_row(&"AAA", 0), g.stats.row(&"AAA", 4))
	assert_true(g.stats.year_row(&"AAA", 1).is_empty())
	for _i: int in 4:
		Season.run(g)
	assert_eq(g.stats.year_count(), 2)
	assert_eq(g.stats.count, 8)


func test_missing_and_unknown_series() -> void:
	var st := Stats.create(PackedStringArray(["AAA"]), 0)
	_write(st, 1, 5)
	st.append_year()
	var d := st.to_dict()
	# The save has one series fewer (the last) and one the game does not know, first.
	var old: Array[String] = ["gone"]
	old.append_array(Stats.SERIES.slice(0, Stats.SERIES.size() - 1))
	var old_s := old.size()
	var ring := PackedInt32Array()
	ring.resize(Stats.RING * old_s)
	ring.fill(0)
	var slot := 1 * old_s
	for i: int in old_s:
		ring[slot + i] = 9 if i == 0 else 7
	var years := PackedInt32Array()
	for i: int in old_s:
		years.append(9 if i == 0 else 7)
	d["series"] = PackedStringArray(old)
	d["ring"] = ring
	d["years"] = years
	var back := Stats.from_dict(d)
	assert_not_null(back)
	assert_eq(back.value(&"AAA", 1, "treasury"), 7)
	assert_eq(back.value(&"AAA", 1, "districts_salt"), 7)
	assert_eq(back.value(&"AAA", 1, "districts_harbour"), 0, "missing series is zeros")
	assert_eq(back.year_row(&"AAA", 0).size(), Stats.SERIES.size())
	assert_eq(back.year_row(&"AAA", 0)[Stats.column("districts_harbour")], 0)
	assert_eq(back.ring.size(), Stats.RING * Stats.SERIES.size())


func test_round_trip_and_digest() -> void:
	var st := Stats.create(PackedStringArray(["AAA", "BBB"]), 0)
	for t: int in range(1, 9):
		_write(st, t, t * 3)
		if Calendar.is_winter(t):
			st.append_year()
	var d := st.to_dict()
	var back := Stats.from_dict(bytes_to_var(var_to_bytes(d)) as Dictionary)
	assert_not_null(back)
	assert_eq(back.digest(), st.digest())
	assert_eq(var_to_bytes(back.to_dict()), var_to_bytes(d), "save, load, save equal")
	var before := st.digest()
	st.set_row(0, 8, _row(1))
	assert_ne(st.digest(), before, "the digest moves with a row")


func test_from_dict_rejects_bad_input() -> void:
	var st := Stats.create(PackedStringArray(["AAA"]), 0)
	var d := st.to_dict()
	d["schema"] = "other"
	assert_null(Stats.from_dict(d))
	d = st.to_dict()
	d["count"] = "3"
	assert_null(Stats.from_dict(d))
	d = st.to_dict()
	d["ring"] = PackedInt32Array([1, 2])
	assert_null(Stats.from_dict(d))
	assert_null(Stats.from_dict({}))


func test_scenario_values() -> void:
	var g := ScenarioFixture.game()
	assert_eq(g.stats.tags, PackedStringArray(["AAA", "BBB", "OUT"]))
	g.act("choose_country", {"tag": &"AAA"})
	g.emit({"kind": "work_finished", "tag": &"AAA", "hex": Vector2i(0, 0), "work": {}})
	g.emit({"kind": "work_finished", "tag": &"BBB", "hex": Vector2i(1, 0), "work": {}})
	g.emit({"kind": "work_finished", "tag": &"AAA", "hex": Vector2i(2, 0), "work": {}})
	var now := StatsSystem.row_now(g, &"AAA")
	Season.run(g)
	assert_eq(g.stats.row(&"AAA", 1), now)
	var land_total := 0
	for tag: StringName in [&"AAA", &"BBB", &"OUT"]:
		var id := _id_of(g, tag)
		assert_eq(g.stats.value(tag, 1, "land"), Territory.count(g, id))
		land_total += g.stats.value(tag, 1, "land")
		var by_family := 0
		for col: int in range(Stats.DISTRICTS_FIRST, Stats.SERIES.size()):
			by_family += g.stats.row(tag, 1)[col]
		var expected := 0
		for hex_i: int in Territory.districts(g, id):
			if int(g.state.main_use[hex_i]) != 0:
				expected += 1
		assert_eq(by_family, expected)
	assert_gt(land_total, 0)
	assert_eq(g.stats.value(&"AAA", 1, "works_finished"), 2)
	assert_eq(g.stats.value(&"BBB", 1, "works_finished"), 1)
	assert_eq(g.stats.value(&"OUT", 1, "works_finished"), 0)
	assert_eq(g.stats.value(&"AAA", 1, "works_running"), 0)
	assert_eq(g.stats.value(&"AAA", 1, "treasury"), 0)
	assert_true(StatsSystem.row_now(g, &"ZZZ").is_empty())


func test_map_only_game_has_the_empty_tag() -> void:
	var m := ScenarioFixture.build()["map"] as MapData
	var g := Game.new_game(m, 1)
	assert_eq(g.stats.tags, PackedStringArray([""]))
	var land := 0
	for i: int in m.hex_count():
		if m.land[i] != 0:
			land += 1
	Season.run(g)
	assert_eq(g.stats.value(&"", 1, "land"), land)
	assert_eq(g.turn, 2)


func test_game_digest_includes_stats() -> void:
	var a := ScenarioFixture.game()
	var b := ScenarioFixture.game()
	assert_eq(a.digest(), b.digest())
	a.stats.set_row(0, 1, _row(1))
	assert_ne(a.digest(), b.digest())


func _id_of(g: Game, tag: StringName) -> int:
	for c: Country in g.countries:
		if c.tag == tag:
			return c.id
	return 0
