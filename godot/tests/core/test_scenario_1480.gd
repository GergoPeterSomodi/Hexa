## Committed 1480 Italy scenario data (docs/architecture/m2-build-spec.md sections 4.1 to 4.7 and 10):
## deep validation, district/town/city counts, playable vs outside powers, regions, passes, neighbours,
## normal and colour-blind contrast thresholds, and the full 21x19 owner grid.
extends GutTest

const DEFS_PATH := "res://data/defs/game_defs.tres"
const MAP_PATH := "res://data/maps/north_italy.tres"
const SCEN_PATH := "res://data/scenarios/north_italy_1480.tres"

const EXPECTED_ORDER: Array[StringName] = [
	&"FRA", &"AUS", &"SWI", &"SAV", &"MLO", &"VEN", &"GEN",
	&"TUS", &"PAP", &"MAN", &"FER", &"SIE", &"LUC",
]

# [tag, districts, towns, cities (level 4+), capital_hex, capital_name]
const EXPECTED_COUNTRIES := [
	[&"FRA", 34, 3, 0, Vector2i(-1, -1), "Paris"],
	[&"AUS", 37, 3, 0, Vector2i(-1, -1), "Vienna"],
	[&"SWI", 45, 8, 0, Vector2i(5, 0), ""],
	[&"SAV", 58, 13, 1, Vector2i(5, 9), ""],
	[&"MLO", 52, 20, 2, Vector2i(9, 9), ""],
	[&"VEN", 42, 10, 4, Vector2i(18, 7), ""],
	[&"GEN", 14, 2, 1, Vector2i(8, 13), ""],
	[&"TUS", 14, 3, 2, Vector2i(15, 15), ""],
	[&"PAP", 20, 4, 1, Vector2i(-1, -1), "Rome"],
	[&"MAN", 3, 1, 0, Vector2i(14, 10), ""],
	[&"FER", 12, 2, 1, Vector2i(16, 10), ""],
	[&"SIE", 7, 1, 0, Vector2i(16, 16), ""],
	[&"LUC", 2, 1, 0, Vector2i(12, 15), ""],
]

const EXPECTED_PASS_OWNERS := {
	"Great St Bernard": &"SWI",
	"Simplon": &"SWI",
	"Gotthard": &"SWI",
	"Furka": &"SWI",
	"Splugen": &"SWI",
	"Julier": &"SWI",
	"Little St Bernard": &"SAV",
	"Mont Cenis": &"SAV",
	"Mont Genevre": &"SAV",
	"Col di Tenda": &"SAV",
	"Lukmanier": &"MLO",
	"San Bernardino": &"MLO",
	"Maloja": &"MLO",
	"Bernina": &"MLO",
	"Stelvio": &"MLO",
	"Tonale": &"MLO",
	"Aprica": &"MLO",
	"Cisa": &"MLO",
	"Resia": &"AUS",
	"Brenner": &"AUS",
	"Arlberg": &"AUS",
	"Cadibona": &"GEN",
	"Giovi": &"GEN",
	"Col de Larche": &"FRA",
}

const EXPECTED_NEIGHBOURS: Array[String] = [
	"AUS-MLO", "AUS-SWI", "AUS-VEN",
	"FER-LUC", "FER-MAN", "FER-MLO", "FER-PAP", "FER-TUS", "FER-VEN",
	"FRA-SAV", "FRA-SWI",
	"GEN-MLO", "GEN-SAV",
	"LUC-MLO", "LUC-TUS",
	"MAN-MLO", "MAN-VEN",
	"MLO-SAV", "MLO-SWI", "MLO-VEN",
	"PAP-TUS", "PAP-VEN",
	"SAV-SWI",
	"SIE-TUS",
]

const GRID_LETTERS := {
	"~": &"",
	"R": &"FRA", "A": &"AUS", "H": &"SWI", "S": &"SAV", "M": &"MLO",
	"V": &"VEN", "G": &"GEN", "F": &"TUS", "P": &"PAP", "N": &"MAN",
	"E": &"FER", "I": &"SIE", "L": &"LUC",
}

const EXPECTED_GRID: Array[String] = [
	"RRRHHHHHHHHHAAAAAAAAA",
	"RRHHHHHHHHHHAAAAAAAAA",
	"RRSHHHHHHHHHAAAAAAVAA",
	"SSSHHHHHMMHHMMAAAVVVV",
	"SSSHHHHMMMMMMMAAAVVVV",
	"SSHHHHMMMMMMMVAAAVVVV",
	"SSSHHSMMMMMMVVVAAVVVV",
	"SSSSSSSMMMMVVVVVVVV~~",
	"SSSSSSSMMMMVMMVVVVV~~",
	"RSSSSSSMMMMMMMNVVVV~~",
	"RRRSSSSSSSMMMNNEEEV~~",
	"RRRSSSSSGGMMMMEPEE~~~",
	"RRRRSSSGGGGMMEEPPVV~~",
	"RRRSSSGGGGGMMEEPPP~~~",
	"RRRSSSGG~~~~LEEFFPP~~",
	"RRRSSG~~~~~~LFFFFFPPP",
	"RRRSS~~~~~~~~FFFIFPPP",
	"RRR~~~~~~~~~~FIIIFPPP",
	"~~R~~~~~~~~~~~IIIFPPP",
]


func _load_bundle() -> Array:
	var defs := ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	var map := ResourceLoader.load(MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MapData
	var scen := ResourceLoader.load(SCEN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ScenarioDef
	assert_not_null(defs)
	assert_not_null(map)
	assert_not_null(scen)
	return [defs, map, scen]


func test_scenario_validates_deep_and_metadata_matches() -> void:
	var bundle := _load_bundle()
	var defs: GameDefs = bundle[0]
	var map: MapData = bundle[1]
	var scen: ScenarioDef = bundle[2]

	assert_eq(defs.validate(), [] as Array[String])
	assert_eq(scen.validate(map, defs, true), [] as Array[String])
	assert_eq(scen.id, "north_italy_1480")
	assert_eq(scen.name, "Italy, 1480")
	assert_eq(scen.map_id, "north_italy")
	assert_eq(scen.map_digest, map.digest())
	assert_eq(scen.year, 1480)
	assert_eq(scen.countries, EXPECTED_ORDER)
	assert_eq(scen.seeds.size(), 100)
	assert_true(scen.pins.is_empty())
	var defs_scen := defs.scenario("north_italy_1480")
	assert_not_null(defs_scen)
	assert_eq(defs_scen.digest(), scen.digest())


func test_district_town_city_counts_and_playable_powers() -> void:
	var bundle := _load_bundle()
	var defs: GameDefs = bundle[0]
	var map: MapData = bundle[1]
	var scen: ScenarioDef = bundle[2]

	var builder := load("res://tools/build_scenario.gd") as GDScript
	assert_not_null(builder)
	var rows: Array[Dictionary] = builder.call("summary_rows", map, defs, scen)
	assert_eq(rows.size(), 13)

	var total_districts := 0
	var total_towns := 0
	var playable_count := 0
	var outside_count := 0
	for i: int in EXPECTED_COUNTRIES.size():
		var exp: Array = EXPECTED_COUNTRIES[i]
		var tag: StringName = exp[0]
		var row: Dictionary = rows[i]
		var cdef := defs.country(tag)
		assert_not_null(cdef)
		assert_eq(row["tag"], String(tag))
		assert_eq(int(row["districts"]), int(exp[1]), "%s districts" % [tag])
		assert_eq(int(row["towns"]), int(exp[2]), "%s towns" % [tag])
		assert_eq(int(row["cities"]), int(exp[3]), "%s cities" % [tag])
		assert_eq(scen.capitals[i], exp[4], "%s capital" % [tag])
		assert_eq(cdef.capital_name, String(exp[5]), "%s capital_name" % [tag])
		if exp[4] == ScenarioDef.NO_HEX:
			assert_false(scen.playable(tag), "%s should be an outside power" % [tag])
			outside_count += 1
		else:
			assert_true(scen.playable(tag), "%s should be playable" % [tag])
			playable_count += 1
		total_districts += int(row["districts"])
		total_towns += int(row["towns"])

	assert_eq(playable_count, 10)
	assert_eq(outside_count, 3)
	assert_eq(total_districts, 340)
	assert_eq(total_towns, 71)

	for i: int in map.hex_count():
		if map.land[i] == 1:
			assert_gt(int(scen.owner[i]), 0, "land hex %s must be owned" % [map.hex_of(i)])
		else:
			assert_eq(int(scen.owner[i]), 0, "sea hex %s must be 0" % [map.hex_of(i)])


func test_regions_match_section_4_5() -> void:
	var bundle := _load_bundle()
	var map: MapData = bundle[1]
	var scen: ScenarioDef = bundle[2]

	for i: int in EXPECTED_COUNTRIES.size():
		var tag: StringName = EXPECTED_COUNTRIES[i][0]
		var expected_total: int = EXPECTED_COUNTRIES[i][1]
		var cid := scen.id_of(tag)
		var regs := ScenarioGrowth.regions(map, scen.owner, cid)
		var sizes: Array[int] = []
		for r: PackedInt32Array in regs:
			sizes.append(r.size())
		if tag == &"FRA":
			assert_eq(sizes, [7, 27] as Array[int], "FRA regions: Franche-Comte (7) and Dauphine-Provence (27)")
		elif tag == &"VEN":
			assert_eq(sizes, [40, 2] as Array[int], "VEN regions: mainland (40) and Ravenna (2)")
		else:
			assert_eq(sizes, [expected_total] as Array[int], "%s has one connected region" % [tag])


func test_pass_owners_match_section_4_5() -> void:
	var bundle := _load_bundle()
	var map: MapData = bundle[1]
	var scen: ScenarioDef = bundle[2]

	assert_eq(map.passes.size(), EXPECTED_PASS_OWNERS.size())
	var seen: Dictionary = {}
	for p: Dictionary in map.passes:
		var pname: String = p["name"]
		var hex: Vector2i = p["hex"]
		assert_true(EXPECTED_PASS_OWNERS.has(pname), "unexpected pass '%s'" % pname)
		var owner_tag := scen.tag_of(int(scen.owner[map.index_of(hex)]))
		assert_eq(owner_tag, EXPECTED_PASS_OWNERS[pname], "pass '%s' at %s" % [pname, hex])
		seen[pname] = true
	assert_eq(seen.size(), EXPECTED_PASS_OWNERS.size())


func test_neighbour_pairs_and_contrast_thresholds() -> void:
	var bundle := _load_bundle()
	var defs: GameDefs = bundle[0]
	var map: MapData = bundle[1]
	var scen: ScenarioDef = bundle[2]

	assert_eq(defs.min_contrast, 30.0)
	assert_eq(defs.min_contrast_cb, 20.0)

	var pairs := ScenarioGrowth.neighbour_pairs(map, scen.owner)
	var pair_names: Array[String] = []
	var min_normal := INF
	var min_cb := INF
	for pair: Vector2i in pairs:
		var tag_a := String(scen.tag_of(pair.x))
		var tag_b := String(scen.tag_of(pair.y))
		var lo := tag_a if tag_a < tag_b else tag_b
		var hi := tag_b if tag_a < tag_b else tag_a
		pair_names.append("%s-%s" % [lo, hi])

		var col_a := defs.country(StringName(tag_a)).colour
		var col_b := defs.country(StringName(tag_b)).colour
		var de := ColourContrast.delta_e(col_a, col_b)
		min_normal = minf(min_normal, de)
		assert_gte(de, 30.0, "normal contrast %s-%s" % [lo, hi])

		var cb_a := defs.cb_palette[int(scen.cb_colours[pair.x - 1])]
		var cb_b := defs.cb_palette[int(scen.cb_colours[pair.y - 1])]
		var cb_de := ColourContrast.worst_delta_e(cb_a, cb_b)
		min_cb = minf(min_cb, cb_de)
		assert_gte(cb_de, 20.0, "CB contrast %s-%s" % [lo, hi])

	pair_names.sort()
	assert_eq(pair_names, EXPECTED_NEIGHBOURS)
	assert_gte(min_normal, 30.0)
	assert_gte(min_cb, 20.0)


func test_owner_grid_matches_section_4_5_table() -> void:
	var bundle := _load_bundle()
	var map: MapData = bundle[1]
	var scen: ScenarioDef = bundle[2]

	assert_eq(map.rows, EXPECTED_GRID.size())
	for row: int in map.rows:
		var line := EXPECTED_GRID[row]
		assert_eq(line.length(), map.cols)
		for col: int in map.cols:
			var ch := line.substr(col, 1)
			var expected_tag: StringName = GRID_LETTERS[ch]
			var actual_tag := scen.tag_of(int(scen.owner[map.index_of(Vector2i(col, row))]))
			assert_eq(actual_tag, expected_tag, "hex (%d, %d)" % [col, row])
