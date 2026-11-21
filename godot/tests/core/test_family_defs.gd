## FamilyDef and the family part of GameDefs (core/defs/family_def.gd, core/defs/game_defs.gd;
## docs/architecture/m3-build-spec.md sections 4.3, 5.1 and 7; m4-build-spec.md sections 4.4, 5.1 and 9): the 14 committed
## files against table 4.3 and the M4 numbers of 4.4, the slot numbers, and planted faults (P) for each rule.
extends GutTest

## Table 4.3: key, id, work seasons to level 0..top, clear seasons.
const TABLE: Array = [
	["settlements", 1, [0, 4, 4, 8, 8, 8], 1],
	["castles", 2, [0, 4, 8, 16], 1],
	["wheat", 3, [0, 4, 8, 16], 1],
	["hemp", 4, [0, 4, 8, 16], 1],
	["silk", 5, [0, 4, 8, 16], 1],
	["dyes", 6, [0, 4, 8, 16], 1],
	["vineyard", 7, [0, 4, 8, 16], 1],
	["olives", 8, [0, 4, 8, 16], 1],
	["grazing", 9, [0, 4, 8, 16], 1],
	["timber", 10, [0, 4, 8, 16], 1],
	["mines", 11, [0, 4, 8, 16], 1],
	["quarry", 12, [0, 4, 8, 16], 1],
	["salt", 13, [0, 4, 8, 16], 1],
	["harbour", 14, [0, 4, 8, 16], 1],
]


## A family from the committed file of the same key (so the M4 numbers are whole), with the M3 fields replaced.
func _family(p_id: int, p_key: StringName, p_seasons: PackedInt32Array, p_clear: int = 1) -> FamilyDef:
	var f := _load_family(String(p_key))
	f.id = p_id
	f.key = p_key
	f.work_seasons = p_seasons
	f.clear_seasons = p_clear
	return f


func _valid_vineyard() -> FamilyDef:
	return _family(7, &"vineyard", PackedInt32Array([0, 4, 8, 16]))


func _committed_defs() -> GameDefs:
	return ResourceLoader.load(
		"res://data/defs/game_defs.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	) as GameDefs


func _committed_copy() -> GameDefs:
	var defs := _committed_defs()
	assert_eq(defs.validate(), [] as Array[String])
	return defs


func _load_family(key: String) -> FamilyDef:
	return ResourceLoader.load(
		"res://data/defs/families/%s.tres" % key, "", ResourceLoader.CACHE_MODE_IGNORE
	) as FamilyDef


func _has(errors: Array[String], fragment: String) -> bool:
	for e: String in errors:
		if e.contains(fragment):
			return true
	return false


func test_committed_files_load_and_match_table() -> void:
	for row: Array in TABLE:
		var key: String = row[0]
		var f := _load_family(key)
		assert_not_null(f, "%s loads" % key)
		if f == null:
			continue
		assert_eq(f.validate(), [] as Array[String], "%s validates" % key)
		assert_eq(f.id, row[1], "%s id" % key)
		assert_eq(String(f.key), key, "%s key" % key)
		assert_eq(f.work_seasons, PackedInt32Array(row[2]), "%s work_seasons" % key)
		assert_eq(f.clear_seasons, row[3], "%s clear_seasons" % key)


func test_committed_families_are_listed_in_game_defs() -> void:
	var defs := _committed_defs()
	assert_not_null(defs)
	assert_eq(defs.families.size(), 14)
	for row: Array in TABLE:
		var f := defs.family(row[1])
		assert_not_null(f, "family %d listed" % row[1])
		if f != null:
			assert_eq(String(f.key), row[0])
	assert_null(defs.family(0))
	assert_null(defs.family(15))
	assert_eq(defs.work_slots_base, 1)
	assert_eq(defs.work_slots_city_level, 4)
	assert_true(defs.works_halt_in_snow_winter)
	assert_eq(defs.validate(), [] as Array[String])


func test_duration_spot_checks() -> void:
	var defs := _committed_defs()
	# Settlements: 4 to level 1 (never begun), 4 to 2, 8 to 3 to 5.
	var s := defs.family(1)
	assert_eq(s.work_seasons[1], 4)
	assert_eq(s.work_seasons[3], 8)
	assert_eq(s.work_seasons.size(), 6)
	# Castles stop at level 3 with 16 seasons.
	var c := defs.family(2)
	assert_eq(c.work_seasons.size(), 4)
	assert_eq(c.work_seasons[3], 16)


func test_defaults() -> void:
	var f := FamilyDef.new()
	assert_eq(f.id, 0)
	assert_eq(f.key, &"")
	assert_eq(f.work_seasons.size(), 0)
	assert_eq(f.clear_seasons, 1)
	var g := GameDefs.new()
	assert_eq(g.families.size(), 0)
	assert_eq(g.work_slots_base, 1)
	assert_eq(g.work_slots_city_level, 4)
	assert_true(g.works_halt_in_snow_winter)


func test_valid_family_passes() -> void:
	assert_eq(_valid_vineyard().validate(), [] as Array[String])


func test_planted_fault_wrong_key() -> void:
	var f := _valid_vineyard()
	f.key = &"wine"
	var errors := f.validate()
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("key"), "error mentions key")


func test_planted_fault_size_does_not_fit_top_level() -> void:
	# Vineyard tops out at level 3: four entries fit, five and three do not.
	var long := _family(7, &"vineyard", PackedInt32Array([0, 4, 8, 16, 16]))
	var errors := long.validate()
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("work_seasons"))
	var short := _family(7, &"vineyard", PackedInt32Array([0, 4, 8]))
	errors = short.validate()
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("work_seasons"))
	# Settlements top out at level 5: six entries fit, five do not.
	var settle := _family(1, &"settlements", PackedInt32Array([0, 4, 4, 8, 8]))
	errors = settle.validate()
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("work_seasons"))


func test_planted_fault_zero_season() -> void:
	var f := _family(7, &"vineyard", PackedInt32Array([0, 4, 0, 16]))
	var errors := f.validate()
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("work_seasons[2]"))
	# A nonzero entry at 0 is also refused.
	var zero_base := _family(7, &"vineyard", PackedInt32Array([1, 4, 8, 16]))
	errors = zero_base.validate()
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("work_seasons[0]"))
	# Clearing takes 1 to 64 seasons.
	var no_clear := _family(7, &"vineyard", PackedInt32Array([0, 4, 8, 16]), 0)
	errors = no_clear.validate()
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("clear_seasons"))


func test_seasons_range_is_one_to_sixty_four() -> void:
	var over := _family(7, &"vineyard", PackedInt32Array([0, 4, 8, 65]))
	assert_eq(over.validate().size(), 1)
	var top := _family(7, &"vineyard", PackedInt32Array([0, 1, 8, 64]), 64)
	assert_eq(top.validate(), [] as Array[String])


func test_planted_fault_id_out_of_range() -> void:
	for bad_id: int in [0, 15]:
		var f := _family(bad_id, &"vineyard", PackedInt32Array([0, 4, 8, 16]))
		var errors := f.validate()
		assert_eq(errors.size(), 1, "id %d refused" % bad_id)
		assert_true(errors[0].contains("id"))


func test_planted_fault_two_families_one_id() -> void:
	var defs := _committed_copy()
	var fams: Array[FamilyDef] = defs.families.duplicate()
	fams[2] = _family(1, &"settlements", PackedInt32Array([0, 4, 4, 8, 8, 8]))
	defs.families = fams
	assert_true(_has(defs.validate(), "duplicate family id 1"), "duplicate id reported")


func test_planted_fault_family_count() -> void:
	var defs := _committed_copy()
	var fams: Array[FamilyDef] = defs.families.duplicate()
	fams.pop_back()
	defs.families = fams
	assert_true(_has(defs.validate(), "families has 13 entries, expected 14"), "13 families reported")


func test_planted_fault_work_slots() -> void:
	var defs := _committed_copy()
	defs.work_slots_base = 0
	assert_true(_has(defs.validate(), "work_slots_base"), "base 0 reported")
	defs.work_slots_base = 1
	defs.work_slots_city_level = 6
	assert_true(_has(defs.validate(), "work_slots_city_level"), "city level 6 reported")
	defs.work_slots_city_level = 0
	assert_true(_has(defs.validate(), "work_slots_city_level"), "city level 0 reported")
	defs.work_slots_city_level = 5
	assert_eq(defs.validate(), [] as Array[String], "city level 5 is allowed")


func test_planted_fault_null_family_entry() -> void:
	var defs := _committed_copy()
	var fams: Array[FamilyDef] = defs.families.duplicate()
	fams[0] = null
	defs.families = fams
	assert_true(_has(defs.validate(), "families[0]: entry is null"), "null entry reported")


## M4 spec 4.4, the goods families: key, good, base, season percents, weather, keep wild, jobs, upkeep, cost, cost_goods,
## ground line. The wheat-style costs are shared by the families that spec 4.4 marks "same".
func _m4_rows() -> Array:
	var wheat_cost := [0, 40, 100, 250]
	var wheat_goods := [{}, {}, {"timber": 10}, {"timber": 20, "stone": 20}]
	var mines_cost := [0, 60, 150, 350]
	var mines_goods := [{}, {"timber": 10}, {"timber": 20}, {"timber": 30, "stone": 20}]
	var jobs := [0, 1000, 2000, 4000]
	var upkeep := [0, 1, 2, 4]
	var harbour_upkeep := [0, 2, 3, 5]
	var zero := [0, 0, 0, 0]
	var keep := [0, 50, 25, 0]
	var none := {}
	return [
		["wheat", "grain", none, [0, 10, 20, 32], [20, 100, 40, 0, 0, 10], true, zero, jobs, upkeep, wheat_cost, wheat_goods, "low farmland, up to 600 m"],
		["hemp", "hemp", none, [0, 10, 20, 32], [0, 50, 100, 0, 0, 0], true, keep, jobs, upkeep, wheat_cost, wheat_goods, "farmland at a river or stream, up to 400 m"],
		["silk", "silk", none, [0, 3, 6, 10], [100, 50, 0, 0, 0, 0], true, keep, jobs, upkeep, wheat_cost, wheat_goods, "farmland or meadow within two hexes of a town, up to 600 m, no snow winter"],
		["dyes", "dyes", none, [0, 2, 4, 7], [50, 100, 50, 0, 0, 0], true, keep, jobs, upkeep, wheat_cost, wheat_goods, "farmland or meadow beside a town, up to 500 m"],
		["vineyard", "wine", none, [0, 12, 24, 40], [0, 0, 100, 0, 0, 0], true, keep, jobs, upkeep, wheat_cost, wheat_goods, "farmland or meadow, 100–900 m, no snow winter"],
		["olives", "oil", none, [0, 8, 16, 28], [0, 0, 50, 0, 0, 100], true, keep, jobs, upkeep, wheat_cost, wheat_goods, "the mild winter, on the coast or up to 900 m"],
		["grazing", "", {"sheep": &"wool", "cattle": &"cattle", "horses": &"horses"}, [0, 8, 16, 26], [100, 120, 60, 0, 30, 30], true, zero, jobs, upkeep, wheat_cost, wheat_goods, "meadow, or woods from 700 m"],
		["timber", "timber", none, [0, 6, 12, 20], [50, 50, 50, 0, 150, 150], false, zero, jobs, upkeep, wheat_cost, wheat_goods, "woods up to 1,800 m"],
		["mines", "", {"iron": &"iron", "copper": &"copper", "silver": &"silver"}, [0, 4, 8, 14], [100, 100, 100, 0, 70, 100], false, zero, jobs, harbour_upkeep, mines_cost, mines_goods, "rock, or high ground from 1,000 m"],
		["quarry", "stone", none, [0, 6, 12, 20], [100, 100, 100, 0, 70, 100], false, zero, jobs, upkeep, wheat_cost, wheat_goods, "rock, or upland from 700 m"],
		["salt", "salt", none, [0, 4, 8, 14], [50, 150, 100, 0, 0, 20], true, zero, jobs, upkeep, wheat_cost, wheat_goods, "a low shore"],
		["harbour", "fish", none, [0, 4, 8, 14], [100, 100, 100, 30, 50, 70], false, zero, [0, 500, 1000, 2000], harbour_upkeep, mines_cost, mines_goods, "a coast with no port beside it"],
	]


func _goods_array(items: Array[Dictionary]) -> Array:
	var out: Array = []
	for item: Dictionary in items:
		out.append(item.duplicate())
	return out


func test_m4_goods_families_equal_table_4_4() -> void:
	var extra_permille := {"grazing": {"sheep": 1000, "cattle": 750, "horses": 375}, "mines": {"iron": 1000, "copper": 750, "silver": 250}}
	for row: Array in _m4_rows():
		var key: String = row[0]
		var f := _load_family(key)
		assert_not_null(f, "%s loads" % key)
		if f == null:
			continue
		assert_eq(String(f.good), row[1], "%s good" % key)
		assert_eq(f.by_extra, row[2], "%s by_extra" % key)
		assert_eq(Array(f.base), row[3], "%s base" % key)
		assert_eq(Array(f.season_percent), row[4], "%s season_percent" % key)
		assert_eq(f.weather_bound, row[5], "%s weather_bound" % key)
		assert_eq(Array(f.keep_wild), row[6], "%s keep_wild" % key)
		assert_eq(Array(f.jobs), row[7], "%s jobs" % key)
		assert_eq(Array(f.upkeep), row[8], "%s upkeep" % key)
		assert_eq(Array(f.walls), [0, 0, 0, 0], "%s walls" % key)
		assert_eq(Array(f.cost), row[9], "%s cost" % key)
		assert_eq(_goods_array(f.cost_goods), row[10], "%s cost_goods" % key)
		assert_eq(f.ground_text, row[11], "%s ground" % key)
		if extra_permille.has(key):
			assert_eq(f.extra_permille, extra_permille[key], "%s extra_permille" % key)
		assert_eq(f.validate(), [] as Array[String], "%s validates" % key)


func test_m4_settlement_and_castle_numbers_equal_table_4_4() -> void:
	var s := _load_family("settlements")
	assert_eq(Array(s.people), [0, 1000, 3000, 10000, 30000, 60000])
	assert_eq(Array(s.keep_wild), [0, 100, 100, 100, 75, 50])
	assert_eq(Array(s.jobs), [0, 0, 0, 0, 0, 0])
	assert_eq(Array(s.upkeep), [0, 0, 1, 2, 2, 5])
	assert_eq(Array(s.walls), [0, 0, 0, 0, 4, 6])
	assert_eq(Array(s.ring_lift), [0, 0, 0, 0, 100, 200])
	assert_eq(Array(s.port_fish), [0, 1, 2, 4, 6, 10])
	assert_eq(Array(s.port_dues), [0, 2, 5, 12, 30, 45])
	# M5 4.6 moves the costs of levels 2 and 3 to 60 and 200 (M4: 100 and 300); the M5 test checks them too.
	assert_eq(Array(s.cost), [0, 0, 60, 200, 700, 1000])
	assert_eq(_goods_array(s.cost_goods), [{}, {}, {"timber": 10}, {"timber": 20, "stone": 10}, {"timber": 20, "stone": 60}, {"timber": 20, "stone": 40}])
	assert_eq(s.base.size(), 0, "settlements make no goods")
	assert_eq(s.ground_text, "")
	var c := _load_family("castles")
	assert_eq(Array(c.keep_wild), [0, 100, 100, 100])
	assert_eq(Array(c.walls), [0, 2, 4, 8])
	assert_eq(Array(c.cost), [0, 60, 200, 500])
	assert_eq(_goods_array(c.cost_goods), [{}, {"timber": 10, "stone": 10}, {"stone": 40}, {"stone": 80, "iron": 10}])
	assert_eq(c.good, &"")
	assert_eq(c.validate(), [] as Array[String])
	assert_eq(s.validate(), [] as Array[String])


func test_m4_extras_are_the_improve_rules_lists() -> void:
	assert_eq(FamilyDef.ANIMAL_EXTRAS, ImproveRules.ANIMALS)
	assert_eq(FamilyDef.ORE_EXTRAS, ImproveRules.ORES)


func test_planted_fault_m4_wrong_array_size() -> void:
	var f := _load_family("wheat")
	f.season_percent = PackedInt32Array([20, 100, 40, 0, 0])
	assert_true(_has(f.validate(), "season_percent has 5 entries"), "five season percents refused")
	f = _load_family("wheat")
	f.base = PackedInt32Array([0, 10, 20])
	assert_true(_has(f.validate(), "base has 3 entries"), "three bases refused")
	f = _load_family("wheat")
	f.keep_wild = PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(_has(f.validate(), "keep_wild has 5 entries"), "five keep_wild refused")


func test_planted_fault_m4_unknown_good_in_cost_goods() -> void:
	var f := _load_family("wheat")
	f.cost_goods[2]["gold"] = 3
	assert_true(_has(f.validate(), "unknown good 'gold'"), "unknown good in cost_goods refused")


func test_planted_fault_m4_keep_wild_101() -> void:
	var f := _load_family("wheat")
	f.keep_wild[2] = 101
	assert_true(_has(f.validate(), "keep_wild[2] is 101"), "keep_wild 101 refused")


func test_planted_fault_m4_settlement_arrays_on_a_goods_family() -> void:
	var f := _load_family("wheat")
	f.people = PackedInt32Array([0, 1000, 3000, 10000])
	assert_true(_has(f.validate(), "people is for settlements only"), "people on wheat refused")
	f = _load_family("wheat")
	f.port_fish = PackedInt32Array([0, 1, 2, 4])
	assert_true(_has(f.validate(), "port_fish is for settlements only"), "port_fish on wheat refused")


func test_planted_fault_m4_extra_not_in_animals_or_ores() -> void:
	var f := _load_family("grazing")
	f.by_extra["goats"] = &"wool"
	f.extra_permille["goats"] = 500
	assert_true(_has(f.validate(), "extra 'goats' is not an animal or an ore"), "goats refused")


func test_planted_fault_m4_goods_family_rules() -> void:
	var f := _load_family("wheat")
	f.good = &"gold"
	assert_true(_has(f.validate(), "good 'gold' is not a known good"), "unknown good refused")
	f = _load_family("wheat")
	f.ground_text = ""
	assert_true(_has(f.validate(), "ground_text is empty"), "goods family without ground line refused")
	f = _load_family("wheat")
	f.good = &""
	f.by_extra = {"sheep": &"wool"}
	assert_true(_has(f.validate(), "extra 'sheep' has no extra_permille"), "by_extra without extra_permille refused")


func test_resource_round_trip() -> void:
	var src := _valid_vineyard()
	var path := "user://test_family_def.tres"
	assert_eq(ResourceSaver.save(src, path), OK)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as FamilyDef
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_not_null(loaded)
	assert_eq(loaded.id, src.id)
	assert_eq(loaded.key, src.key)
	assert_eq(loaded.work_seasons, src.work_seasons)
	assert_eq(loaded.clear_seasons, src.clear_seasons)
	assert_eq(loaded.validate(), [] as Array[String])


## M5 spec 4.2, 4.5 and 4.6: the settlements' room, falls_below and the costs of levels 2 and 3.
func test_m5_settlement_people_equal_spec() -> void:
	var s := _load_family("settlements")
	assert_eq(s.validate(), [] as Array[String], "settlements validate")
	assert_eq(Array(s.room), [0, 2000, 4000, 20000, 45000, 100000], "room by level (4.2, 4.5)")
	assert_eq(Array(s.falls_below), [0, 0, 1000, 2000, 0, 0], "falls below by level (4.5): never at 1, 4 and 5")
	assert_eq(Array(s.cost), [0, 0, 60, 200, 700, 1000], "costs of levels 2 and 3 (4.6)")
	assert_eq(Array(s.people), [0, 1000, 3000, 10000, 30000, 60000], "start people unchanged (4.2)")
	assert_eq(s.work_seasons, PackedInt32Array([0, 4, 4, 8, 8, 8]), "durations unchanged (4.6)")
	var c := _load_family("castles")
	assert_eq(c.room.size(), 0, "castles have no room")
	assert_eq(c.falls_below.size(), 0, "castles do not fall")
	var w := _load_family("wheat")
	assert_eq(w.room.size(), 0, "goods families have no room")
	assert_eq(w.falls_below.size(), 0, "goods families do not fall")


func test_planted_fault_m5_room_under_start_people() -> void:
	var s := _load_family("settlements")
	var room: PackedInt32Array = s.room.duplicate()
	room[2] = 2000
	s.room = room
	assert_true(_has(s.validate(), "people[2] is 3000, over room 2000"), "a village's room under its start people refused")


func test_planted_fault_m5_falls_below_not_under_lower_room() -> void:
	var s := _load_family("settlements")
	var below: PackedInt32Array = s.falls_below.duplicate()
	below[3] = 4000
	s.falls_below = below
	assert_true(_has(s.validate(), "falls_below[3] is 4000, expected under room[2] 4000"),
		"a town that falls at the village's room refused")
	s = _load_family("settlements")
	below = s.falls_below.duplicate()
	below[2] = 2000
	s.falls_below = below
	assert_true(_has(s.validate(), "falls_below[2] is 2000, expected under room[1] 2000"),
		"a village that falls at the hamlet's room refused")
	s = _load_family("settlements")
	below = s.falls_below.duplicate()
	below[1] = 500
	s.falls_below = below
	assert_true(_has(s.validate(), "falls_below[1] is 500, expected 0"), "a hamlet that falls refused")
	s = _load_family("settlements")
	below = s.falls_below.duplicate()
	below[2] = -1
	s.falls_below = below
	assert_true(_has(s.validate(), "falls_below[2] is -1, expected 0 or more"), "a negative fall refused")


func test_planted_fault_m5_falls_below_above_people_top_level() -> void:
	# With a top of 2, the level 3 town's falls_below of 2,000 is above the top: a fault checked by GameDefs.
	var defs := _committed_copy()
	defs.people_top_level = 2
	assert_true(_has(defs.validate(), "settlements: falls_below[3] is 2000 above people_top_level 2"),
		"a town that falls above a top of 2 refused")
	# A walled town never falls: a fallen level 4 is refused with the committed top of 3.
	defs = _committed_copy()
	var s := _load_family("settlements")
	var below: PackedInt32Array = s.falls_below.duplicate()
	below[4] = 1000
	s.falls_below = below
	var fams: Array[FamilyDef] = defs.families.duplicate()
	for i: int in fams.size():
		if fams[i].id == 1:
			fams[i] = s
	defs.families = fams
	assert_true(_has(defs.validate(), "settlements: falls_below[4] is 1000 above people_top_level 3"),
		"a walled town that falls refused")


func test_planted_fault_m5_room_on_other_families() -> void:
	var c := _load_family("castles")
	c.room = PackedInt32Array([0, 2000, 4000, 20000])
	assert_true(_has(c.validate(), "room and falls_below are for settlements only"), "a castle's room refused")
	var s := _load_family("settlements")
	s.room = PackedInt32Array([0, 2000, 4000])
	assert_true(_has(s.validate(), "room has 3 entries and falls_below 6, expected 6"), "a room of three entries refused")


## M6 spec 5.1: the companies a settlement may raise a season, by level.
func test_m6_settlements_raise_cap_equals_spec() -> void:
	var s := _load_family("settlements")
	assert_eq(s.validate(), [] as Array[String], "settlements validate")
	assert_eq(Array(s.raise_cap), [0, 1, 1, 2, 3, 4], "raise_cap by level")
	for key: String in ["castles", "wheat", "grazing", "mines", "harbour"]:
		assert_eq(_load_family(key).raise_cap.size(), 0, "%s has no raise_cap" % key)
	assert_eq(FamilyDef.new().raise_cap.size(), 0, "empty by default")


func test_planted_fault_m6_raise_cap_on_a_goods_family() -> void:
	var f := _load_family("wheat")
	f.raise_cap = PackedInt32Array([0, 1, 1, 2])
	assert_true(_has(f.validate(), "raise_cap is for settlements only"), "raise_cap on wheat refused")


func test_planted_fault_m6_raise_cap_shape() -> void:
	var s := _load_family("settlements")
	s.raise_cap = PackedInt32Array([0, 1, 1, 2, 3])
	assert_true(_has(s.validate(), "raise_cap has 5 entries, expected 6"), "five raise caps refused")
	s = _load_family("settlements")
	s.raise_cap = PackedInt32Array([1, 1, 1, 2, 3, 4])
	assert_true(_has(s.validate(), "raise_cap[0] is 1, expected 0"), "a raise cap at level 0 refused")
	s = _load_family("settlements")
	s.raise_cap = PackedInt32Array([0, 1, 1, 2, 3, 21])
	assert_true(_has(s.validate(), "raise_cap[5] is 21, expected 0 to 20"), "a raise cap of 21 refused")
	s = _load_family("settlements")
	s.raise_cap = PackedInt32Array([0, 1, 3, 2, 3, 4])
	assert_true(_has(s.validate(), "raise_cap[3] is 2, under raise_cap[2] 3"), "a falling raise cap refused")
