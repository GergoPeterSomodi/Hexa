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
	assert_eq(Stats.SERIES.size(), 49)
	assert_eq(Stats.SERIES.slice(35, 40), ["people_towns", "people_grew", "people_starved", "people_left", "food_need"],
			"the five of M5 come before M6's two")
	assert_eq(Stats.SERIES.slice(40, 42), ["army_raised", "army_starved"], "the two of M6 come before M7's seven")
	assert_eq(Stats.SERIES.slice(42), ["battle_losses", "battles_won", "battles_lost", "districts_held", "districts_lost", "garrison_men", "garrison_lost"], "the seven of M7 are appended last")
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
	# The save lacks the last fifteen series (districts_harbour, the five of M5, the two of M6 and the seven of M7) and has one the game does not know, first.
	var old: Array[String] = ["gone"]
	old.append_array(Stats.SERIES.slice(0, Stats.SERIES.size() - 15))
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
	Season.begin(g)
	Season.run_phase(g, &"production")
	Season.run_phase(g, &"income")
	Season.run_phase(g, &"works")
	var now := StatsSystem.row_now(g, &"AAA")  # what the stats phase is about to write
	Season.run_phase(g, &"stats")
	Season.run_phase(g, &"calendar")
	Season.finish(g)
	assert_eq(g.stats.row(&"AAA", 1), now)
	var land_total := 0
	for tag: StringName in [&"AAA", &"BBB", &"OUT"]:
		var id := _id_of(g, tag)
		assert_eq(g.stats.value(tag, 1, "land"), Territory.count(g, id))
		land_total += g.stats.value(tag, 1, "land")
		var by_family := 0
		for col: int in range(Stats.DISTRICTS_FIRST, Stats.DISTRICTS_FIRST + FamilyIds.COUNT - 1):
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
	var alpha := Countries.by_tag(g, &"AAA")
	assert_eq(g.stats.value(&"AAA", 1, "treasury"), alpha.treasury, "the closing treasury")
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


# ----- the M4 values (m4-build-spec.md 4.20) -------------------------------------------------------------------------


func test_the_money_goods_and_people_series_of_genoas_first_season() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	g.act("build", {"hex": EconomyFixture.VINEYARD_HEX, "family": ImproveRules.VINEYARD, "tag": &"GEN"})
	Season.run(g)
	var s := g.stats
	assert_eq(s.goods, 16, "Stats.create takes the goods of the defs")
	assert_eq(s.value(&"GEN", 1, "treasury"), 658)
	assert_eq(s.value(&"GEN", 1, "income_people"), 65)
	assert_eq(s.value(&"GEN", 1, "income_goods"), 7)
	assert_eq(s.value(&"GEN", 1, "income_dues"), 30)
	assert_eq(s.value(&"GEN", 1, "upkeep_districts"), 10)
	assert_eq(s.value(&"GEN", 1, "upkeep_walls"), 4)
	assert_eq(s.value(&"GEN", 1, "spending"), 40, "the work, less refunds, positive")
	assert_eq(s.value(&"GEN", 1, "people"), 82700)
	assert_eq(s.value(&"GEN", 1, "food_made"), 3 + 6, "grain 3 and fish 6")
	assert_eq(s.value(&"GEN", 1, "food_eaten"), 4)
	assert_eq(s.value(&"GEN", 1, "income_trade"), 0)
	assert_eq(s.value(&"GEN", 1, "upkeep_army"), 0)
	# The goods ring: made, used, closing stock of grain (0) and fish (1) and wine (3).
	var base := ((s.index_of(&"GEN") * Stats.RING + 1) * s.goods) * 3
	assert_eq([s.goods_ring[base], s.goods_ring[base + 1], s.goods_ring[base + 2]], [3, 0, 16], "grain")
	assert_eq([s.goods_ring[base + 3], s.goods_ring[base + 4], s.goods_ring[base + 5]], [6, 4, 0], "fish")
	assert_eq([s.goods_ring[base + 9], s.goods_ring[base + 10], s.goods_ring[base + 11]], [0, 1, 3], "wine")


func test_the_stats_phase_closes_the_ledgers_and_the_flows() -> void:
	var g := EconomyFixture.game(&"GEN")
	var c := Countries.by_tag(g, &"GEN")
	Season.begin(g)
	Season.run_phase(g, &"production")
	Season.run_phase(g, &"income")
	assert_false(c.ledger_open.is_empty())
	assert_true(c.ledger_closed.is_empty())
	assert_ne(c.flows_open.count(0), c.flows_open.size())
	Season.run_phase(g, &"stats")
	assert_true(c.ledger_open.is_empty(), "the lines were closed")
	assert_eq(c.ledger_from, c.treasury)
	assert_eq(int(c.ledger_closed["closing"]), c.treasury)
	assert_eq(c.flows_open.count(0), c.flows_open.size(), "the flows start again from zero")
	assert_eq(c.stock_from, c.stock)
	assert_eq(int(c.goods_closed["turn"]), 1)


func _goods_stats(seasons: int) -> Stats:
	var st := Stats.create(PackedStringArray(["AAA", "BBB"]), 3)
	for t: int in range(1, seasons + 1):
		for c: int in 2:
			var base := (c * Stats.RING + posmod(t, Stats.RING)) * 3 * 3
			for g: int in 3:
				st.goods_ring[base + g * 3 + Stats.MADE] = t * 100 + c * 10 + g
				st.goods_ring[base + g * 3 + Stats.USED] = t * 100 + c * 10 + g + 1000
				st.goods_ring[base + g * 3 + Stats.STOCK] = t * 100 + c * 10 + g + 2000
		_write(st, t, t)
	return st


func test_goods_value_reads_the_ring() -> void:
	var st := _goods_stats(5)
	assert_eq(st.goods_value(&"AAA", 3, 2, Stats.MADE), 302)
	assert_eq(st.goods_value(&"BBB", 3, 1, Stats.USED), 1311)
	assert_eq(st.goods_value(&"BBB", 5, 0, Stats.STOCK), 2510)
	assert_eq(st.goods_value(&"AAA", 6, 0, Stats.MADE), 0, "not written yet")
	assert_eq(st.goods_value(&"AAA", 0, 0, Stats.MADE), 0)


func test_goods_value_and_series_give_nothing_for_the_unknown() -> void:
	var st := _goods_stats(5)
	assert_eq(st.goods_value(&"ZZZ", 3, 0, Stats.MADE), 0, "unknown tag")
	assert_eq(st.goods_value(&"AAA", 3, 3, Stats.MADE), 0, "unknown good")
	assert_eq(st.goods_value(&"AAA", 3, -1, Stats.MADE), 0)
	assert_eq(st.goods_value(&"AAA", 3, 0, 3), 0, "unknown part")
	assert_true(st.goods_series(&"ZZZ", 0, Stats.MADE, 5).is_empty())
	assert_true(st.goods_series(&"AAA", 9, Stats.MADE, 5).is_empty())
	assert_true(st.goods_series(&"AAA", 0, 7, 5).is_empty())
	assert_true(Stats.create(PackedStringArray(["AAA"]), 3).goods_series(&"AAA", 0, Stats.MADE, 5).is_empty(), "no season written")


func test_goods_series_spans_and_wraps() -> void:
	var st := _goods_stats(5)
	assert_eq(st.goods_series(&"AAA", 1, Stats.MADE, 3), PackedInt32Array([301, 401, 501]))
	assert_eq(st.goods_series(&"AAA", 1, Stats.MADE, 40), PackedInt32Array([101, 201, 301, 401, 501]), "a span longer than the seasons written")
	var long := _goods_stats(43)
	var s := long.goods_series(&"BBB", 2, Stats.STOCK, 40)
	assert_eq(s.size(), 40)
	assert_eq(s[0], 4 * 100 + 10 + 2 + 2000, "the oldest in the ring is turn 4")
	assert_eq(s[39], 43 * 100 + 10 + 2 + 2000)
	assert_eq(long.goods_value(&"AAA", 3, 0, Stats.MADE), 0, "out of the ring")
	assert_eq(long.goods_series(&"AAA", 0, Stats.MADE, 100).size(), 40, "never more than the ring")


func test_the_goods_accessors_change_nothing() -> void:
	var st := _goods_stats(5)
	var before := st.digest()
	st.goods_value(&"AAA", 3, 1, Stats.USED)
	st.goods_series(&"AAA", 1, Stats.USED, 40)
	assert_eq(st.digest(), before)


func test_a_save_without_the_people_series_loads_them_as_zeros() -> void:
	var st := Stats.create(PackedStringArray(["AAA"]), 0)
	_write(st, 1, 4)
	st.append_year()
	var d := st.to_dict()
	var old: Array[String] = []
	old.assign(Stats.SERIES.slice(0, 35))
	var ring := PackedInt32Array()
	ring.resize(Stats.RING * 35)
	ring.fill(0)
	for i: int in 35:
		ring[35 + i] = 6
	var years := PackedInt32Array()
	years.resize(35)
	years.fill(6)
	d["series"] = PackedStringArray(old)
	d["ring"] = ring
	d["years"] = years
	var back := Stats.from_dict(d)
	assert_not_null(back)
	assert_eq(back.value(&"AAA", 1, "people"), 6)
	for col_name: String in Stats.SERIES.slice(35):
		assert_eq(back.value(&"AAA", 1, col_name), 0, col_name)
		assert_eq(back.year_row(&"AAA", 0)[Stats.column(col_name)], 0, col_name)
	assert_eq(back.ring.size(), Stats.RING * Stats.SERIES.size())


func test_the_digest_moves_with_one_people_value() -> void:
	var st := Stats.create(PackedStringArray(["AAA"]), 0)
	_write(st, 1, 3)
	var before := st.digest()
	var row := st.row(&"AAA", 1)
	row[Stats.column("food_need")] += 1
	st.set_row(0, 1, row)
	assert_ne(st.digest(), before)


func test_the_digest_moves_with_each_army_series() -> void:
	for col_name: String in ["army_raised", "army_starved"]:
		var st := Stats.create(PackedStringArray(["AAA"]), 0)
		_write(st, 1, 3)
		var before := st.digest()
		var row := st.row(&"AAA", 1)
		row[Stats.column(col_name)] += 1
		st.set_row(0, 1, row)
		assert_ne(st.digest(), before, col_name)
		var back := Stats.from_dict(st.to_dict())
		assert_eq(back.value(&"AAA", 1, col_name), 4, "%s survives a round trip" % col_name)


func test_the_projected_size_at_winter_1650_for_sixty_countries() -> void:
	var tags := PackedStringArray()
	for c: int in 60:
		tags.append("C%02d" % c)
	var st := Stats.create(tags, 0)
	assert_eq(st.ring.size() * 4, 60 * 40 * 49 * 4, "the ring: 0.47 MB")
	assert_lt(st.ring.size() * 4, 500_000)
	for t: int in range(1, 171 * 4 + 1):
		_write(st, t, t)
		if Calendar.is_winter(t):
			st.append_year()
	assert_eq(st.year_count(), 171, "1480 to 1650")
	var year_bytes := st.years.size() * 4
	assert_gt(year_bytes, 1_650_000, "about 2.01 MB")
	assert_lt(year_bytes, 2_100_000)
	assert_lt(year_bytes + st.ring.size() * 4, 2_500_000, "under 2.5 MB in all")
	var back := Stats.from_dict(bytes_to_var(var_to_bytes(st.to_dict())) as Dictionary)
	assert_not_null(back, "a full 60-country game loads back")
	assert_eq(back.digest(), st.digest())


func test_from_dict_refuses_mistyped_series_arrays() -> void:
	var st := Stats.create(PackedStringArray(["AAA"]), 0)
	for key: String in ["ring", "years", "goods_ring"]:
		var d := st.to_dict()
		d[key] = "text"
		assert_null(Stats.from_dict(d), "P: %s as text" % key)
		d[key] = [1, 2, 3]
		assert_null(Stats.from_dict(d), "P: %s as an untyped list" % key)
