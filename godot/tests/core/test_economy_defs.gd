## The economy's numbers in GameDefs (core/defs/game_defs.gd; docs/architecture/m4-build-spec.md sections 4.3 to 4.12 and 5.1),
## the rows of tools/economy_tables.gd, and planted faults (P) for each rule of 9 (weather odds, covers, family goods).
extends GutTest

const Tables := preload("res://tools/economy_tables.gd")

## Table 4.4: the wild yield per cover (farmland first) over the six slots.
const WILD_YIELD: Array = [
	[1, 3, 2, 0, 0, 1],
	[0, 1, 1, 0, 0, 0],
	[0, 0, 1, 0, 1, 1],
	[0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0],
]


func _has(errors: Array[String], fragment: String) -> bool:
	for e: String in errors:
		if e.contains(fragment):
			return true
	return false


func _committed_defs() -> GameDefs:
	return ResourceLoader.load(
		"res://data/defs/game_defs.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	) as GameDefs


## The committed defs with a fresh copy of wheat's family (the cached one is shared by every test).
func _defs_with_fresh_wheat() -> GameDefs:
	var defs := _committed_defs()
	var wheat := ResourceLoader.load(
		"res://data/defs/families/wheat.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	) as FamilyDef
	var families: Array[FamilyDef] = defs.families.duplicate()
	for i: int in families.size():
		if families[i].id == 3:
			families[i] = wheat
	defs.families = families
	return defs


func test_committed_economy_numbers_equal_spec() -> void:
	var defs := _committed_defs()
	assert_eq(defs.validate(), [] as Array[String], "committed defs validate")
	assert_eq(defs.hands_permille, 300)
	assert_eq(defs.food_need_milli, 100)
	assert_eq(defs.food_weight, 700)
	assert_eq(defs.content_floor, 750)
	assert_eq(defs.reserve_seasons, 4)
	assert_eq(defs.town_tax_milli, 1000)
	assert_eq(defs.country_tax_milli, 600)
	assert_eq(Array(defs.tax_permille), [700, 1000, 1400])
	assert_eq(Array(defs.goods_share_permille), [500, 700, 900])
	assert_eq(Array(defs.output_permille), [1050, 1000, 900])
	assert_eq(Array(defs.port_dues_percent), [100, 110, 100, 70, 70, 70])
	assert_eq(Array(defs.fishing_percent), [100, 100, 100, 30, 50, 70])
	assert_eq(defs.start_treasury_base, 200)
	assert_eq(defs.start_treasury_per_1000, 5)
	assert_eq(Array(defs.weather_odds), [60, 20, 20])
	assert_eq(Array(defs.weather_permille), [1000, 1200, 750])
	assert_eq(defs.expensive_permille, 250)
	assert_eq(defs.expensive_seasons, 8)
	assert_eq(Array(defs.country_people), [8000, 5000, 2500, 1500, 600, 0, 0, 1500])
	assert_eq(Array(defs.wild_good), [&"grain", &"grain", &"timber", &"", &"", &"", &"", &""])


func test_committed_wild_yield_equals_table_4_4() -> void:
	var defs := _committed_defs()
	assert_eq(defs.wild_yield.size(), 48)
	for cover: int in WILD_YIELD.size():
		for slot: int in 6:
			assert_eq(defs.wild_yield[cover * 6 + slot], WILD_YIELD[cover][slot],
				"cover %d slot %d" % [cover, slot])


func test_defaults_match_the_spec() -> void:
	var g := GameDefs.new()
	assert_eq(g.hands_permille, 300)
	assert_eq(g.food_need_milli, 100)
	assert_eq(g.food_weight, 700)
	assert_eq(g.content_floor, 750)
	assert_eq(g.reserve_seasons, 4)
	assert_eq(g.town_tax_milli, 1000)
	assert_eq(g.country_tax_milli, 600)
	assert_eq(g.start_treasury_base, 200)
	assert_eq(g.start_treasury_per_1000, 5)
	assert_eq(g.expensive_permille, 250)
	assert_eq(g.expensive_seasons, 8)
	assert_eq(g.goods.size(), 0)


func test_economy_tables_rows_match_the_spec() -> void:
	var defs := _committed_defs()
	var goods := Tables.goods_rows(defs)
	assert_eq(goods.size(), 17, "header and 16 goods")
	# Row 0 is the header: grain, fish, oil, wine, salt are rows 1 to 5.
	assert_true(String(goods[5]).contains("salt"), "row 5 is salt")
	assert_true(String(goods[5]).contains("'salt season'"), "salt's harvest word")
	# Grain keeps four seasons of food, fish keeps none (4.2).
	assert_true(String(goods[1]).contains("reserve 4 seasons"), "grain keeps four seasons")
	assert_true(String(goods[2]).contains("reserve 0"), "fish has no reserve")
	var families := Tables.family_rows(defs)
	assert_eq(families.size(), 1 + 14 + 12, "header, 14 families and the 12 goods families' ground lines")
	var settle := Tables.settlement_rows(defs)
	assert_eq(settle.size(), 1 + 5, "header and five levels")
	assert_true(String(settle[5]).contains("60000"), "city has 60,000 people")
	var wild := Tables.wild_rows(defs)
	assert_eq(wild.size(), 1 + 8, "header and eight covers")
	assert_true(String(wild[1]).contains("[1, 3, 2, 0, 0, 1]"), "farmland's yields")
	var money := Tables.money_rows(defs)
	assert_eq(money.size(), 9)
	assert_true(String(money[3]).contains("1400"), "High taxes 1400")
	assert_eq(Tables.tables(defs).size(), goods.size() + families.size() + settle.size() + wild.size() + money.size())


func test_economy_tables_report_the_committed_defs_as_valid() -> void:
	var defs := _committed_defs()
	assert_eq(defs.validate(), [] as Array[String])
	var text := "\n".join(Tables.tables(defs))
	assert_true(text.contains("grazing"), "families printed")
	assert_true(text.contains("weather odds calm/good/poor [60, 20, 20]"), "weather printed")


func test_planted_fault_weather_odds_adding_to_99() -> void:
	var defs := _committed_defs()
	defs.weather_odds = PackedInt32Array([60, 20, 19])
	assert_true(_has(defs.validate(), "weather_odds add to 99, expected 100"), "odds of 99 refused")


func test_planted_fault_seven_covers() -> void:
	var defs := _committed_defs()
	var covers: Array[StringName] = defs.wild_good.duplicate()
	covers.pop_back()
	defs.wild_good = covers
	assert_true(_has(defs.validate(), "wild_good has 7 entries, expected 8"), "seven covers refused")
	defs = _committed_defs()
	var seven := PackedInt32Array()
	for index: int in 42:
		seven.append(defs.wild_yield[index])
	defs.wild_yield = seven
	assert_true(_has(defs.validate(), "wild_yield has 42 entries, expected 48"), "seven covers of wild output refused")


func test_planted_fault_family_naming_an_unknown_good() -> void:
	var defs := _defs_with_fresh_wheat()
	defs.family(3).good = &"maize"
	assert_true(_has(defs.validate(), "family wheat names unknown good 'maize'"), "unknown good refused")
	defs = _defs_with_fresh_wheat()
	defs.family(3).cost_goods[2]["gold"] = 3
	assert_true(_has(defs.validate(), "family wheat cost_goods[2] names unknown good 'gold'"), "unknown cost good refused")


func test_planted_fault_wild_good_unknown() -> void:
	var defs := _committed_defs()
	var covers: Array[StringName] = defs.wild_good.duplicate()
	covers[0] = &"maize"
	defs.wild_good = covers
	assert_true(_has(defs.validate(), "wild_good[0] names unknown good 'maize'"), "unknown wild good refused")


func test_planted_fault_weights_in_tax_arrays() -> void:
	var defs := _committed_defs()
	defs.tax_permille = PackedInt32Array([700, 1000])
	assert_true(_has(defs.validate(), "tax_permille has 2 entries, expected 3"), "two tax levels refused")
