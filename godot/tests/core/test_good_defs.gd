## GoodDef and the goods of GameDefs (core/defs/good_def.gd, core/defs/game_defs.gd; docs/architecture/m4-build-spec.md
## sections 4.2, 5.1 and 9): the 16 committed files against table 4.2, the goods list of GameDefs, and planted faults (P).
extends GutTest

## Table 4.2: id, key, name, kind, price (milli), need (milli), need weight, food order, fixed reserve, harvest word, icon.
const TABLE: Array = [
	[0, "grain", "Grain", "food", 1000, 0, 0, 1, 0, "harvest", "good_grain"],
	[1, "fish", "Fish", "food", 1000, 0, 0, 0, 0, "catch", "good_fish"],
	[2, "oil", "Olive oil", "staple", 2500, 10, 100, -1, 0, "olive harvest", "good_oil"],
	[3, "wine", "Wine", "staple", 2500, 20, 100, -1, 0, "vintage", "good_wine"],
	[4, "salt", "Salt", "staple", 2000, 10, 100, -1, 0, "salt season", "good_salt"],
	[5, "hemp", "Hemp and flax", "ware", 1200, 0, 0, -1, 0, "", "good_hemp"],
	[6, "silk", "Silk", "ware", 6000, 0, 0, -1, 0, "", "good_silk"],
	[7, "dyes", "Dyes", "ware", 5000, 0, 0, -1, 0, "", "good_dyes"],
	[8, "wool", "Wool", "ware", 1500, 0, 0, -1, 0, "", "good_wool"],
	[9, "cattle", "Cattle", "ware", 1500, 0, 0, -1, 0, "", "good_cattle"],
	[10, "horses", "Horses", "ware", 3000, 0, 0, -1, 0, "", "good_horses"],
	[11, "timber", "Timber", "material", 1000, 0, 0, -1, 40, "", "good_timber"],
	[12, "stone", "Stone", "material", 1000, 0, 0, -1, 40, "", "good_stone"],
	[13, "iron", "Iron", "material", 2000, 0, 0, -1, 20, "", "good_iron"],
	[14, "copper", "Copper", "ware", 2500, 0, 0, -1, 0, "", "good_copper"],
	[15, "silver", "Silver", "ware", 7000, 0, 0, -1, 0, "", "good_silver"],
]


func _has(errors: Array[String], fragment: String) -> bool:
	for e: String in errors:
		if e.contains(fragment):
			return true
	return false


## A fresh copy of one committed good (not the cached one, so a planted fault never leaks into another test).
func _load_good(key: String) -> GoodDef:
	return ResourceLoader.load(
		"res://data/defs/goods/%s.tres" % key, "", ResourceLoader.CACHE_MODE_IGNORE
	) as GoodDef


func _committed_defs() -> GameDefs:
	return ResourceLoader.load(
		"res://data/defs/game_defs.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	) as GameDefs


## The committed defs with fresh goods, safe to break.
func _defs_copy() -> GameDefs:
	var defs := _committed_defs()
	var goods: Array[GoodDef] = []
	for row: Array in TABLE:
		goods.append(_load_good(row[1]))
	defs.goods = goods
	return defs


func test_committed_goods_load_validate_and_equal_table_4_2() -> void:
	for row: Array in TABLE:
		var key: String = row[1]
		var g := _load_good(key)
		assert_not_null(g, "%s loads" % key)
		if g == null:
			continue
		assert_eq(g.validate(), [] as Array[String], "%s validates" % key)
		assert_eq(g.id, row[0], "%s id" % key)
		assert_eq(String(g.key), key, "%s key" % key)
		assert_eq(g.name, row[2], "%s name" % key)
		assert_eq(String(g.kind), row[3], "%s kind" % key)
		assert_eq(g.price_milli, row[4], "%s price" % key)
		assert_eq(g.need_milli, row[5], "%s need" % key)
		assert_eq(g.need_weight, row[6], "%s weight" % key)
		assert_eq(g.food_order, row[7], "%s food order" % key)
		assert_eq(g.reserve_fixed, row[8], "%s reserve" % key)
		assert_eq(g.harvest_word, row[9], "%s harvest word" % key)
		assert_eq(String(g.icon), row[10], "%s icon" % key)


func test_game_defs_lists_16_goods_in_id_order() -> void:
	var defs := _committed_defs()
	assert_eq(defs.goods.size(), 16)
	for row: Array in TABLE:
		assert_eq(String(defs.goods[row[0]].key), row[1], "goods[%d] is %s" % [row[0], row[1]])
	assert_eq(String(defs.good(0).key), "grain")
	assert_null(defs.good(16), "no good 16")
	assert_null(defs.good(-1), "no good -1")
	assert_eq(defs.good_id(&"wine"), 3)
	assert_eq(defs.good_id(&"gold"), -1, "unknown key is -1")
	assert_eq(GoodDef.KEYS.size(), 16)
	for row: Array in TABLE:
		assert_eq(String(GoodDef.KEYS[row[0]]), row[1], "KEYS[%d]" % row[0])
	assert_eq(defs.validate(), [] as Array[String], "committed defs validate")


func test_defaults_and_kinds() -> void:
	assert_eq(GoodDef.KINDS, [&"food", &"staple", &"ware", &"material"] as Array[StringName])
	var g := GoodDef.new()
	assert_eq(g.food_order, -1)
	assert_eq(g.reserve_fixed, 0)
	assert_eq(g.need_milli, 0)


func test_planted_fault_ids_out_of_order() -> void:
	var defs := _defs_copy()
	var goods: Array[GoodDef] = defs.goods.duplicate()
	var first: GoodDef = goods[0]
	goods[0] = goods[1]
	goods[1] = first
	defs.goods = goods
	assert_true(_has(defs.validate(), "goods[0]: id 1 should be 0"), "swapped ids refused")


func test_planted_fault_goods_count() -> void:
	var defs := _defs_copy()
	var goods: Array[GoodDef] = defs.goods.duplicate()
	goods.pop_back()
	defs.goods = goods
	assert_true(_has(defs.validate(), "goods has 15 entries, expected 16"), "fifteen goods refused")


func test_planted_fault_price_of_zero() -> void:
	var g := _load_good("wine")
	g.price_milli = 0
	assert_true(_has(g.validate(), "price_milli is 0"), "price 0 refused")
	var defs := _defs_copy()
	defs.goods[3].price_milli = 0
	assert_true(_has(defs.validate(), "price_milli is 0"), "price 0 refused through GameDefs")


func test_planted_fault_food_with_a_need() -> void:
	var g := _load_good("fish")
	g.need_milli = 5
	assert_true(_has(g.validate(), "food has a need of its own"), "food with a need refused")
	g = _load_good("grain")
	g.need_weight = 100
	assert_true(_has(g.validate(), "food has a need of its own"), "food with a weight refused")


func test_planted_fault_weights_not_1000() -> void:
	var defs := _defs_copy()
	defs.food_weight = 600
	assert_true(_has(defs.validate(), "the four weights add to 900, expected 1000"), "weights 900 refused")
	defs = _defs_copy()
	defs.goods[2].need_weight = 200
	assert_true(_has(defs.validate(), "the four weights add to 1100, expected 1000"), "weights 1100 refused")


func test_planted_fault_unknown_kind() -> void:
	var g := _load_good("wool")
	g.kind = &"luxury"
	assert_true(_has(g.validate(), "kind 'luxury' is not one of"), "unknown kind refused")


func test_planted_fault_empty_icon() -> void:
	var g := _load_good("cattle")
	g.icon = &""
	assert_true(_has(g.validate(), "icon is empty"), "empty icon refused")


func test_planted_fault_key_and_id_and_name() -> void:
	var g := _load_good("grain")
	g.key = &"gold"
	assert_true(_has(g.validate(), "key 'gold' should be 'grain' for id 0"), "wrong key refused")
	g = _load_good("grain")
	g.id = 16
	assert_true(_has(g.validate(), "id 16 is outside 0 to 15"), "id 16 refused")
	g = _load_good("wine")
	g.name = " "
	assert_true(_has(g.validate(), "name is empty"), "empty name refused")


func test_planted_fault_food_order_and_fixed_reserve() -> void:
	var g := _load_good("wine")
	g.food_order = 0
	assert_true(_has(g.validate(), "food_order is 0, expected -1"), "food order on a staple refused")
	g = _load_good("grain")
	g.food_order = -1
	assert_true(_has(g.validate(), "food has food_order -1"), "food without order refused")
	g = _load_good("wine")
	g.reserve_fixed = 5
	assert_true(_has(g.validate(), "only materials keep a fixed reserve"), "reserve on a staple refused")
	g = _load_good("timber")
	g.price_milli = -1
	assert_true(_has(g.validate(), "price_milli is -1"), "negative price refused")
