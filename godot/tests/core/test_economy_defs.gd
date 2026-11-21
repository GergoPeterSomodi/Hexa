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
	var levels := Tables.level_rows(defs)
	var people := Tables.people_rows(defs)
	assert_eq(Tables.tables(defs).size(), goods.size() + families.size() + settle.size() + levels.size()
		+ people.size() + wild.size() + money.size())


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


## M5 spec 4.4 (the people numbers) and 5.1 (the eight fields), and the people tables of tools/economy_tables.gd.
func test_committed_people_numbers_equal_spec() -> void:
	var defs := _committed_defs()
	assert_eq(defs.validate(), [] as Array[String], "committed defs validate")
	assert_eq(Array(defs.growth_bp), [125, 100, 50], "growth by tax level Low, Normal, High (4.4)")
	assert_eq(Array(defs.growth_percent), [100, 100, 100, 0, 50, 100], "growth share by slot (4.4)")
	assert_eq(defs.hunger_bp, 400, "hunger at no food, 4 % (4.4)")
	assert_eq(Array(defs.hunger_percent), [100, 100, 100, 150, 125, 100], "hunger share by slot (4.4)")
	assert_eq(defs.left_bp, 200, "crowding leaves 2 % a season (4.4)")
	assert_eq(defs.town_floor, 200, "hunger never takes a town below 200 (4.4)")
	assert_eq(defs.people_top_level, 3, "the people raise a settlement to level 3 (4.4)")
	assert_eq(defs.levy_permille, 100, "M6's levy share (4.20)")


func test_people_defaults_match_the_spec() -> void:
	var g := GameDefs.new()
	assert_eq(Array(g.growth_bp), [125, 100, 50], "growth by tax level (4.4)")
	assert_eq(Array(g.growth_percent), [100, 100, 100, 0, 50, 100], "growth share by slot (4.4)")
	assert_eq(Array(g.hunger_percent), [100, 100, 100, 150, 125, 100], "hunger share by slot (4.4)")
	assert_eq(g.hunger_bp, 400)
	assert_eq(g.left_bp, 200)
	assert_eq(g.town_floor, 200)
	assert_eq(g.people_top_level, 3)
	assert_eq(g.levy_permille, 100)


func test_people_tables_rows_match_the_spec() -> void:
	var defs := _committed_defs()
	var people := "\n".join(Tables.people_rows(defs))
	assert_true(people.contains("growth_bp [125, 100, 50]"), "growth by tax level printed")
	assert_true(people.contains("growth_percent [100, 100, 100, 0, 50, 100]"), "growth shares printed")
	assert_true(people.contains("hunger_bp 400; hunger_percent [100, 100, 100, 150, 125, 100]"), "hunger printed")
	assert_true(people.contains("left_bp 200; town_floor 200; people_top_level 3; levy_permille 100"),
		"crowding, floor, top level and levy printed")
	var levels := Tables.level_rows(defs)
	assert_eq(levels.size(), 1 + 5, "header and five levels")
	assert_true(String(levels[1]).contains("start 1000 room 2000 falls never cost 0 no goods"), "hamlet: no fall, no cost")
	assert_true(String(levels[2]).contains("start 3000 room 4000 falls 1000 cost 60 timber 10"),
		"village: falls under 1,000, costs 60 ducats and 10 timber")
	assert_true(String(levels[3]).contains("start 10000 room 20000 falls 2000 cost 200 timber 20, stone 10"),
		"town: falls under 2,000, costs 200 ducats, 20 timber and 10 stone")
	assert_true(String(levels[4]).contains("start 30000 room 45000 falls never cost 700 timber 20, stone 60"),
		"walled town never falls")
	assert_true(String(levels[5]).contains("start 60000 room 100000 falls never cost 1000 timber 20, stone 40"),
		"city never falls")


func test_planted_fault_growth_percent_of_five_entries() -> void:
	var defs := _committed_defs()
	defs.growth_percent = PackedInt32Array([100, 100, 100, 0, 50])
	assert_true(_has(defs.validate(), "growth_percent has 5 entries, expected 6"), "five growth shares refused")


func test_planted_fault_hunger_bp_negative() -> void:
	var defs := _committed_defs()
	defs.hunger_bp = -1
	assert_true(_has(defs.validate(), "hunger_bp is -1, expected 0 to 2000"), "negative hunger refused")


func test_planted_fault_people_top_level_six() -> void:
	var defs := _committed_defs()
	defs.people_top_level = 6
	assert_true(_has(defs.validate(), "people_top_level is 6, expected 1 to 5"), "top level 6 refused")


func test_planted_fault_falls_below_above_people_top_level() -> void:
	# A settlement above people_top_level never falls: with a top of 2, the town's falls_below of 2,000 is a fault.
	var defs := _committed_defs()
	defs.people_top_level = 2
	assert_true(_has(defs.validate(), "settlements: falls_below[3] is 2000 above people_top_level 2"),
		"a level 3 that falls, above a top of 2, refused")


func test_planted_fault_other_people_numbers() -> void:
	var defs := _committed_defs()
	defs.growth_bp = PackedInt32Array([125, 100])
	assert_true(_has(defs.validate(), "growth_bp has 2 entries, expected 3"), "two tax levels of growth refused")
	defs = _committed_defs()
	var shares: PackedInt32Array = defs.hunger_percent.duplicate()
	shares[3] = 401
	defs.hunger_percent = shares
	assert_true(_has(defs.validate(), "hunger_percent[3] is 401, expected 0 to 400"), "hunger share over 400 refused")
	defs = _committed_defs()
	defs.growth_bp[0] = 1001
	assert_true(_has(defs.validate(), "growth_bp[0] is 1001, expected 0 to 1000"), "growth over 1000 refused")
	defs = _committed_defs()
	defs.left_bp = 5001
	assert_true(_has(defs.validate(), "left_bp is 5001, expected 0 to 5000"), "crowding over 5000 refused")
	defs = _committed_defs()
	defs.town_floor = -1
	assert_true(_has(defs.validate(), "town_floor is -1, expected 0 or more"), "negative floor refused")
	defs = _committed_defs()
	defs.levy_permille = 1001
	assert_true(_has(defs.validate(), "levy_permille is 1001, expected 0 to 1000"), "levy over 1000 refused")
