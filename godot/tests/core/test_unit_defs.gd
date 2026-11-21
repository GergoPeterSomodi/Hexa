## UnitDef and the kinds of GameDefs (core/defs/unit_def.gd; docs/architecture/m6-build-spec.md sections 4.2, 5.1 and 9):
## the four committed files against table 4.2, the rows of tools/military_tables.gd, and planted faults (P).
extends GutTest

const MilitaryTables := preload("res://tools/military_tables.gd")

## Table 4.2: id, key, name, one, many, branch, men, raise, goods, upkeep, mp, sight, min level, refill.
const TABLE: Array = [
	[0, "pikemen", "Pikemen", "company of pikemen", "companies of pikemen", "infantry", 500, 25, {"iron": 1}, 6, 12, 1, 1, 50],
	[1, "crossbowmen", "Crossbowmen", "company of crossbowmen", "companies of crossbowmen", "missile", 500, 30,
		{"iron": 1, "timber": 1}, 7, 12, 1, 1, 50],
	[2, "knights", "Knights", "company of knights", "companies of knights", "cavalry", 250, 45,
		{"iron": 1, "horses": 3}, 10, 16, 2, 2, 25],
	[3, "bombards", "Bombards", "battery of bombards", "batteries of bombards", "artillery", 100, 60,
		{"iron": 5, "copper": 3}, 8, 8, 1, 3, 10],
]


func _has(errors: Array[String], fragment: String) -> bool:
	for e: String in errors:
		if e.contains(fragment):
			return true
	return false


func _load_unit(key: String) -> UnitDef:
	return ResourceLoader.load(
		"res://data/defs/units/%s.tres" % key, "", ResourceLoader.CACHE_MODE_IGNORE
	) as UnitDef


func _committed_defs() -> GameDefs:
	return ResourceLoader.load(
		"res://data/defs/game_defs.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	) as GameDefs


func test_committed_units_load_validate_and_equal_table_4_2() -> void:
	var defs := _committed_defs()
	for row: Array in TABLE:
		var key: String = row[1]
		var u := _load_unit(key)
		assert_not_null(u, "%s loads" % key)
		if u == null:
			continue
		assert_eq(u.validate(defs), [] as Array[String], "%s validates" % key)
		assert_eq(u.id, row[0], "%s id" % key)
		assert_eq(String(u.key), key, "%s key" % key)
		assert_eq(u.name, row[2], "%s name" % key)
		assert_eq(u.one, row[3], "%s one" % key)
		assert_eq(u.many, row[4], "%s many" % key)
		assert_eq(String(u.branch), row[5], "%s branch" % key)
		assert_eq(u.era, 1, "%s era" % key)
		assert_eq(u.men, row[6], "%s men" % key)
		assert_eq(u.cost, row[7], "%s raise cost" % key)
		assert_eq(u.cost_goods, row[8] as Dictionary, "%s goods" % key)
		assert_eq(u.upkeep, row[9], "%s upkeep" % key)
		assert_eq(u.mp, row[10], "%s move points" % key)
		assert_eq(u.sight, row[11], "%s sight" % key)
		assert_eq(u.min_level, row[12], "%s raised from level" % key)
		assert_eq(u.refill, row[13], "%s refill" % key)
		assert_eq(String(u.figure), "fig_" + String(row[5]), "%s figure" % key)


func test_game_defs_lists_four_units_in_id_order() -> void:
	var defs := _committed_defs()
	assert_eq(defs.units.size(), 4)
	for row: Array in TABLE:
		assert_eq(String(defs.units[row[0]].key), row[1], "units[%d]" % row[0])
		assert_eq(defs.unit_def(row[0]), defs.units[row[0]])
	assert_null(defs.unit_def(4))
	assert_null(defs.unit_def(-1))
	assert_eq(UnitDef.BRANCHES, [&"infantry", &"missile", &"cavalry", &"artillery"] as Array[StringName])
	assert_eq(defs.validate(), [] as Array[String])


func test_goods_of_the_units_are_known() -> void:
	var defs := _committed_defs()
	for u: UnitDef in defs.units:
		for good_key: String in u.cost_goods:
			assert_gt(defs.good_id(StringName(good_key)), -1, "%s: %s is a good" % [u.key, good_key])


func test_the_kinds_table_rows() -> void:
	var rows := MilitaryTables.unit_rows(_committed_defs())
	assert_eq(rows.size(), 5, "header and four kinds")
	assert_true(String(rows[1]).begins_with("0 pikemen"), "pikemen first")
	assert_true(String(rows[1]).contains("men 500 raise 25 goods 1 iron "), "pikemen's numbers")
	assert_true(String(rows[3]).contains("mp 16 sight 2 level 2 refill 25"), "knights")
	assert_true(String(rows[4]).contains("goods 5 iron, 3 copper"), "bombards' goods")


func test_planted_fault_a_branch_unknown() -> void:
	var u := _load_unit("pikemen")
	u.branch = &"navy"
	assert_true(_has(u.validate(_committed_defs()), "branch 'navy' is not one of"), "unknown branch refused")


func test_planted_fault_men_zero() -> void:
	var u := _load_unit("pikemen")
	u.men = 0
	assert_true(_has(u.validate(_committed_defs()), "men is 0, expected 1 to 100000"), "men 0 refused")
	var defs := _committed_defs()
	var empty: Array[UnitDef] = defs.units.duplicate()
	empty[0] = empty[0].duplicate() as UnitDef
	empty[0].men = 0
	defs.units = empty
	assert_true(_has(defs.validate(), "men is 0"), "men 0 refused through GameDefs")


func test_planted_fault_refill_above_men() -> void:
	var u := _load_unit("bombards")
	u.refill = 101
	assert_true(_has(u.validate(_committed_defs()), "refill is 101, expected 1 to men 100"), "refill above men refused")
	u = _load_unit("bombards")
	u.refill = 0
	assert_true(_has(u.validate(_committed_defs()), "refill is 0"), "refill 0 refused")


func test_planted_fault_an_unknown_good_in_cost_goods() -> void:
	var u := _load_unit("knights")
	u.cost_goods["gold"] = 1
	assert_true(_has(u.validate(_committed_defs()), "cost_goods names unknown good 'gold'"), "unknown good refused")
	assert_true(_has(u.validate(), "cost_goods names unknown good 'gold'"), "refused without defs too")
	u = _load_unit("knights")
	u.cost_goods["horses"] = 0
	assert_true(_has(u.validate(_committed_defs()), "cost_goods horses is 0"), "0 loads refused")


func test_planted_fault_the_other_numbers() -> void:
	var defs := _committed_defs()
	var u := _load_unit("pikemen")
	u.key = &"Pike men"
	assert_true(_has(u.validate(defs), "key 'Pike men' should be lowercase"), "bad key refused")
	u = _load_unit("pikemen")
	u.sight = 4
	assert_true(_has(u.validate(defs), "sight is 4, expected 1 to 3"), "sight 4 refused")
	u = _load_unit("pikemen")
	u.min_level = 6
	assert_true(_has(u.validate(defs), "min_level is 6, expected 1 to 5"), "level 6 refused")
	u = _load_unit("pikemen")
	u.mp = 0
	u.upkeep = 0
	u.cost = 0
	var errors := u.validate(defs)
	assert_true(_has(errors, "mp is 0"), "mp 0 refused")
	assert_true(_has(errors, "upkeep is 0"), "upkeep 0 refused")
	assert_true(_has(errors, "cost is 0"), "cost 0 refused")
	u = _load_unit("pikemen")
	u.figure = &""
	assert_true(_has(u.validate(defs), "figure is empty"), "empty figure refused")


func test_planted_fault_ids_out_of_order_and_count() -> void:
	var defs := _committed_defs()
	var units: Array[UnitDef] = defs.units.duplicate()
	var first: UnitDef = units[0]
	units[0] = units[1]
	units[1] = first
	defs.units = units
	assert_true(_has(defs.validate(), "units[0]: id 1 should be 0"), "swapped kinds refused")
	defs = _committed_defs()
	var five: Array[UnitDef] = defs.units.duplicate()
	five.append(five[0])
	defs.units = five
	assert_true(_has(defs.validate(), "units has 5 entries, expected 4"), "five kinds refused")


func test_planted_fault_review_bounds() -> void:
	var defs := _committed_defs()
	var u := _load_unit("pikemen")
	u.era = 99
	assert_true(_has(u.validate(defs), "era is 99, expected 1 to 3"), "era 99 refused")
	u = _load_unit("pikemen")
	u.men = 100001
	assert_true(_has(u.validate(defs), "men is 100001"), "men over the maximum refused")
	u = _load_unit("pikemen")
	u.cost = 1000001
	u.upkeep = 1000001
	assert_true(_has(u.validate(defs), "cost is 1000001"), "cost over the maximum refused")
	assert_true(_has(u.validate(defs), "upkeep is 1000001"), "upkeep over the maximum refused")
	u = _load_unit("pikemen")
	u.mp = 1001
	assert_true(_has(u.validate(defs), "mp is 1001"), "mp over the maximum refused")
	u = _load_unit("pikemen")
	u.figure = &"fig_dragon"
	assert_true(_has(u.validate(defs), "figure 'fig_dragon' is not one of"), "an unknown figure refused")
	assert_eq(UnitDef.FIGURE_NAMES.size(), 4)


func test_planted_fault_duplicate_key_and_slow_unit() -> void:
	var defs := _committed_defs()
	var units: Array[UnitDef] = defs.units.duplicate()
	units[1] = _load_unit("pikemen")
	units[1].id = 1
	defs.units = units
	assert_true(_has(defs.validate(), "duplicate key 'pikemen'"), "a unit key twice refused")
	defs = _committed_defs()
	var slow_units: Array[UnitDef] = defs.units.duplicate()
	slow_units[0] = slow_units[0].duplicate() as UnitDef
	slow_units[0].mp = 1
	defs.units = slow_units
	assert_true(_has(defs.validate(), "mp 1 is under the cheapest ground step 2"), "mp under the cheapest step refused")
