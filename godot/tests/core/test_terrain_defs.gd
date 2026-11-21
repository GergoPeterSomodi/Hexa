## TerrainDef and the grounds of GameDefs (core/defs/terrain_def.gd; docs/architecture/m6-build-spec.md sections 4.3, 5.0 A2,
## 5.1 and 9): the eight committed files against table 4.3, the cover keys against MapTiles and ImproveRules, and planted
## faults (P).
extends GutTest

const MilitaryTables := preload("res://tools/military_tables.gd")

## Table 4.3: cover id, key, name, move points to enter, forage permille.
const TABLE: Array = [
	[0, "farmland", "Farmland", 2, 250],
	[1, "grassland", "Grassland", 2, 250],
	[2, "woods", "Woods", 3, 200],
	[3, "marsh", "Marsh", 4, 150],
	[4, "rock", "Rock", 4, 150],
	[5, "snow", "Snow", 6, 0],
	[6, "tundra", "Tundra", 3, 100],
	[7, "sand", "Sand", 2, 150],
]


func _has(errors: Array[String], fragment: String) -> bool:
	for e: String in errors:
		if e.contains(fragment):
			return true
	return false


func _load_terrain(key: String) -> TerrainDef:
	return ResourceLoader.load(
		"res://data/defs/terrain/%s.tres" % key, "", ResourceLoader.CACHE_MODE_IGNORE
	) as TerrainDef


func _committed_defs() -> GameDefs:
	return ResourceLoader.load(
		"res://data/defs/game_defs.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	) as GameDefs


func test_committed_terrains_load_validate_and_equal_table_4_3() -> void:
	for row: Array in TABLE:
		var key: String = row[1]
		var t := _load_terrain(key)
		assert_not_null(t, "%s loads" % key)
		if t == null:
			continue
		assert_eq(t.validate(), [] as Array[String], "%s validates" % key)
		assert_eq(t.id, row[0], "%s id" % key)
		assert_eq(String(t.key), key, "%s key" % key)
		assert_eq(t.name, row[2], "%s name" % key)
		assert_eq(t.move, row[3], "%s move" % key)
		assert_eq(t.forage_permille, row[4], "%s forage" % key)


func test_game_defs_lists_eight_terrains_in_cover_order() -> void:
	var defs := _committed_defs()
	assert_eq(defs.terrains.size(), 8)
	for row: Array in TABLE:
		assert_eq(String(defs.terrains[row[0]].key), row[1], "terrains[%d]" % row[0])
		assert_eq(defs.terrain(row[0]), defs.terrains[row[0]])
	assert_null(defs.terrain(8))
	assert_null(defs.terrain(-1))
	assert_eq(defs.validate(), [] as Array[String])


## A2: TerrainDef keeps its own KEYS; they are the map's cover words.
func test_keys_equal_the_map_cover_words() -> void:
	var words: Array[String] = []
	for key: StringName in TerrainDef.KEYS:
		words.append(String(key))
	assert_eq(words, MapTiles.COVERS)
	assert_eq(words, ImproveRules.COVER_WORDS)
	assert_eq(words, HexCard.COVER_WORDS)
	assert_eq(TerrainDef.COUNT, TerrainDef.KEYS.size())


func test_the_ground_table_rows() -> void:
	var rows := MilitaryTables.terrain_rows(_committed_defs())
	assert_eq(rows.size(), 9, "header and eight covers")
	assert_eq(rows[1], "0 farmland  move 2 forage 250")
	assert_eq(rows[6], "5 snow      move 6 forage   0")
	assert_eq(rows[8], "7 sand      move 2 forage 150")


func test_planted_fault_a_cover_id_out_of_order() -> void:
	var t := _load_terrain("woods")
	t.id = 3
	assert_true(_has(t.validate(), "key 'woods' should be 'marsh' for id 3"), "wrong id for the key refused")
	t = _load_terrain("woods")
	t.id = 8
	assert_true(_has(t.validate(), "id 8 is outside 0 to 7"), "id 8 refused")
	var defs := _committed_defs()
	var terrains: Array[TerrainDef] = defs.terrains.duplicate()
	var first: TerrainDef = terrains[0]
	terrains[0] = terrains[1]
	terrains[1] = first
	defs.terrains = terrains
	assert_true(_has(defs.validate(), "terrains[0]: id 1 should be 0"), "swapped covers refused through GameDefs")


func test_planted_fault_forage_over_1000() -> void:
	var t := _load_terrain("farmland")
	t.forage_permille = 1001
	assert_true(_has(t.validate(), "forage_permille is 1001, expected 0 to 1000"), "forage 1001 refused")
	t = _load_terrain("snow")
	t.forage_permille = -1
	assert_true(_has(t.validate(), "forage_permille is -1"), "negative forage refused")


func test_planted_fault_move_and_name() -> void:
	var t := _load_terrain("marsh")
	t.move = 0
	assert_true(_has(t.validate(), "move is 0, expected 1 to 20"), "move 0 refused")
	t = _load_terrain("marsh")
	t.move = 21
	assert_true(_has(t.validate(), "move is 21, expected 1 to 20"), "move 21 refused")
	t = _load_terrain("marsh")
	t.name = ""
	assert_true(_has(t.validate(), "name is empty"), "empty name refused")


func test_planted_fault_terrain_count() -> void:
	var defs := _committed_defs()
	var terrains: Array[TerrainDef] = defs.terrains.duplicate()
	terrains.pop_back()
	defs.terrains = terrains
	assert_true(_has(defs.validate(), "terrains has 7 entries, expected 8"), "seven terrains refused")


func test_planted_fault_highway_over_road_cap() -> void:
	var defs := _committed_defs()
	defs.highway_cap = 3
	assert_true(_has(defs.validate(), "highway_cap 3 should not be over road_cap 2"), "highway over road refused")
	defs = _committed_defs()
	var slow: Array[TerrainDef] = []
	for t: TerrainDef in defs.terrains:
		var c := t.duplicate() as TerrainDef
		c.move = 20
		slow.append(c)
	defs.terrains = slow
	assert_true(_has(defs.validate(), "is under the cheapest ground step 20"), "unit slower than the cheapest step refused")
