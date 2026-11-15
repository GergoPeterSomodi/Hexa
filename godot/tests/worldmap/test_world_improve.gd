## The improvement step of the normal map (core/worldmap/world_improve.gd): every land hex has one option; the places of
## the data keep their level; the cell rules and the pair rules hold on every seed; the same seed gives the same map
## and another seed another; most of the map stays wild; the search undoes dead ends (checked on small instances, since
## "none" may stand anywhere and the region needs no backtrack). The hex table is built from the map core
## (improve_table.gd), so the tests need no baked art.
extends GutTest

const SEEDS: Array[int] = [1, 7, 1480, 20251115]

var _table: Array[Dictionary] = []
var _runs: Array[WorldImprove] = []


func before_all() -> void:
	_table = ImproveTable.region_table()
	if _table.is_empty():
		return
	for s: int in SEEDS:
		_runs.append(WorldImprove.build(_table, s))


func _ready_or_fail() -> bool:
	if _runs.is_empty():
		fail_test("the heights and the region must read")
		return false
	return true


func _row(c: int, r: int, cover: String, more: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {
		"c": c, "r": r, "land": true, "cover": cover, "height_m": 100.0, "coast": false, "sea_angle": 0.0,
		"climate": "frost", "river_edges": [], "road": false, "pass": false, "place": null,
	}
	for key: Variant in more.keys():
		row[key] = more[key]
	return row


func _place(level: int, port: bool = false, mode: String = "seaside") -> Dictionary:
	return {"name": "Place", "level": level, "port": port, "port_mode": mode, "landmark": null}


# ----- the option table and the rules as functions ------------------------------------------------------------------


func test_the_options_are_none_the_settlements_the_castles_and_twelve_goods() -> void:
	assert_eq(WorldImprove.option_count(), 1 + 5 + 3 + 12 * 3, "45 options: they fit the bits of one integer")
	assert_eq(WorldImprove.option_of(WorldImprove.NONE, 0), 0)
	assert_eq(WorldImprove.option_of(WorldImprove.SETTLEMENT, 5), 5)
	assert_eq(WorldImprove.option_of(WorldImprove.CASTLE, 1), 6)
	assert_eq(WorldImprove.option_of(WorldImprove.HARBOUR, 3), 44)
	assert_eq(WorldImprove.option_of(WorldImprove.WHEAT, 4), -1, "goods have three levels")
	assert_false(WorldImprove.NAMES.has("furs"), "furs have no place in north Italy")
	assert_false(WorldImprove.NAMES.has("cotton"), "cotton has no place in north Italy")


func test_the_cell_rules_put_each_family_on_its_ground() -> void:
	var plain := {"cover": WorldCover.FARMLAND, "height_m": 90.0, "climate": "frost", "place_distance": 2,
		"town_distance": 2, "road": true, "river": false, "coast": false}
	assert_true(WorldImprove.cell_allowed(WorldImprove.WHEAT, 3, plain), "wheat on the plain near a town")
	assert_false(WorldImprove.cell_allowed(WorldImprove.HEMP, 1, plain), "hemp needs a river edge")
	var wet := plain.duplicate()
	wet["river"] = true
	assert_true(WorldImprove.cell_allowed(WorldImprove.HEMP, 1, wet), "hemp at a river")
	assert_false(WorldImprove.cell_allowed(WorldImprove.TIMBER, 1, plain), "timber only in woods")
	assert_false(WorldImprove.cell_allowed(WorldImprove.OLIVES, 1, plain), "olives only in the mild winter")
	assert_false(WorldImprove.cell_allowed(WorldImprove.MINES, 1, plain), "mines on rock or high ground")
	assert_false(WorldImprove.cell_allowed(WorldImprove.SALT, 1, plain), "salt only on the coast")
	assert_false(WorldImprove.cell_allowed(WorldImprove.HARBOUR, 1, plain), "a fishing harbour only on the coast")
	assert_false(WorldImprove.cell_allowed(WorldImprove.DYES, 1, plain), "dye works stand beside a town")
	assert_true(WorldImprove.cell_allowed(WorldImprove.SILK, 1, plain), "silk within two hexes of a town")
	var far := plain.duplicate()
	far["town_distance"] = 5
	far["place_distance"] = 5
	far["road"] = false
	assert_true(WorldImprove.cell_allowed(WorldImprove.WHEAT, 1, far), "level 1 anywhere on its ground")
	assert_false(WorldImprove.cell_allowed(WorldImprove.WHEAT, 2, far), "level 2 needs a place or a road")
	assert_false(WorldImprove.cell_allowed(WorldImprove.WHEAT, 3, far), "level 3 needs a town")
	assert_false(WorldImprove.cell_allowed(WorldImprove.SILK, 1, far), "no silk far from a town")
	var coast_hill := {"cover": WorldCover.GRASSLAND, "height_m": 300.0, "climate": "mild", "place_distance": 1,
		"town_distance": 1, "road": false, "river": false, "coast": true, "port_near": false}
	assert_true(WorldImprove.cell_allowed(WorldImprove.OLIVES, 2, coast_hill), "olives on a warm coast hill")
	assert_true(WorldImprove.cell_allowed(WorldImprove.VINEYARD, 2, coast_hill), "vines on a hill")
	assert_true(WorldImprove.cell_allowed(WorldImprove.HARBOUR, 1, coast_hill), "a fishing harbour on the coast")
	coast_hill["port_near"] = true
	assert_false(WorldImprove.cell_allowed(WorldImprove.HARBOUR, 1, coast_hill), "no fishing harbour beside a port")
	var rock := {"cover": WorldCover.ROCK, "height_m": 1500.0, "climate": "snow", "place_distance": 2,
		"town_distance": 2, "road": false, "river": false, "coast": false}
	assert_true(WorldImprove.cell_allowed(WorldImprove.MINES, 2, rock), "a mine on rock")
	assert_false(WorldImprove.cell_allowed(WorldImprove.MINES, 3, rock), "the smelter needs a road")
	assert_false(WorldImprove.cell_allowed(WorldImprove.VINEYARD, 1, rock), "no vines on rock")
	for f: int in range(1, WorldImprove.FAMILIES):
		var snow := {"cover": WorldCover.SNOW, "height_m": 2000.0, "climate": "snow", "place_distance": 1,
			"town_distance": 1, "road": true, "river": true, "coast": true}
		assert_false(WorldImprove.cell_allowed(f, 1, snow), "%s never on snow and ice" % WorldImprove.NAMES[f])


func test_the_pair_rules_are_symmetric_and_none_touches_everything() -> void:
	var n := WorldImprove.option_count()
	var imp := WorldImprove.new()
	imp._make_options()
	for a: int in n:
		assert_true(WorldImprove.pair_allowed(WorldImprove.NONE, 0, imp._opt_family[a], imp._opt_level[a], 1))
		for b: int in n:
			for radius: int in [1, 2]:
				assert_eq(
					WorldImprove.pair_allowed(imp._opt_family[a], imp._opt_level[a], imp._opt_family[b], imp._opt_level[b], radius),
					WorldImprove.pair_allowed(imp._opt_family[b], imp._opt_level[b], imp._opt_family[a], imp._opt_level[a], radius),
					"options %d and %d at %d" % [a, b, radius])
	assert_false(WorldImprove.pair_allowed(WorldImprove.SETTLEMENT, 3, WorldImprove.SETTLEMENT, 4, 1), "towns apart")
	assert_true(WorldImprove.pair_allowed(WorldImprove.SETTLEMENT, 2, WorldImprove.SETTLEMENT, 4, 1), "a village may")
	assert_false(WorldImprove.pair_allowed(WorldImprove.CASTLE, 1, WorldImprove.CASTLE, 2, 2), "castles two apart")
	assert_true(WorldImprove.pair_allowed(WorldImprove.WHEAT, 2, WorldImprove.WHEAT, 2, 1), "fields form districts")
	assert_false(WorldImprove.pair_allowed(WorldImprove.WHEAT, 3, WorldImprove.VINEYARD, 3, 1), "two top stages")
	assert_true(WorldImprove.pair_allowed(WorldImprove.WHEAT, 3, WorldImprove.VINEYARD, 3, 2), "but two hexes apart")
	assert_false(WorldImprove.pair_allowed(WorldImprove.MINES, 1, WorldImprove.QUARRY, 1, 1), "mine and quarry")
	for rule: Array in WorldImprove.PAIR_RULES:
		assert_eq(rule.size(), 6, "a rule is two sides, a radius and its reason")
		assert_ne(str(rule[5]), "", "every rule says why")


func test_pick_gives_neighbours_of_one_family_different_pictures() -> void:
	# The kit's numbers (tools/worldmap/pieces/kit.py pick): the same hex, the same answer.
	assert_eq(WorldImprove.pick(Vector2i(7, 9), 2), WorldImprove.pick(Vector2i(7, 9), 2))
	for variants: int in [2, 3]:
		for r: int in range(0, 12):
			for c: int in range(0, 12):
				var hex := Vector2i(c, r)
				var mine := WorldImprove.pick(hex, variants)
				assert_true(mine.x >= 0 and mine.x < variants, "a layout the family has")
				for d: int in 6:
					var other := WorldImprove.pick(WorldImprove.neighbour(hex, d), variants)
					assert_ne(mine, other, "%s and its neighbour %d with %d layouts" % [hex, d, variants])


func test_the_sea_side_is_the_nearest_of_the_eight() -> void:
	assert_eq(WorldImprove.sea_side(0.0), "E")
	assert_eq(WorldImprove.sea_side(90.0), "S")
	assert_eq(WorldImprove.sea_side(80.0), "S")
	assert_eq(WorldImprove.sea_side(50.0), "SE")
	assert_eq(WorldImprove.sea_side(130.0), "SW")
	assert_eq(WorldImprove.sea_side(179.0), "W")
	assert_eq(WorldImprove.sea_side(-179.0), "W")
	assert_eq(WorldImprove.sea_side(-90.0), "N")
	assert_eq(WorldImprove.sea_side(-60.0), "NE")
	assert_eq(WorldImprove.sea_side(270.0), "N", "angles wrap")


func test_neighbours_and_distances_follow_the_grid() -> void:
	var grid := WorldGrid.new(28.0, 111.2, 45.25, 5.6, 47.3)
	for hex: Vector2i in [Vector2i(3, 4), Vector2i(3, 5), Vector2i(0, 0), Vector2i(9, 11)]:
		for d: int in 6:
			assert_eq(WorldImprove.neighbour(hex, d), grid.neighbour(hex, d), "%s direction %d" % [hex, d])
			assert_eq(WorldImprove.hex_distance(hex, grid.neighbour(hex, d)), 1)
		assert_eq(WorldImprove.hex_distance(hex, hex + Vector2i(5, 3)), WorldPlaces.hex_distance(hex, hex + Vector2i(5, 3)))


# ----- the region ---------------------------------------------------------------------------------------------------


func test_every_land_hex_has_one_option_and_no_sea_hex_has_one() -> void:
	if not _ready_or_fail():
		return
	var land := 0
	for row: Dictionary in _table:
		land += int(bool(row["land"]))
	for imp: WorldImprove in _runs:
		assert_eq(imp.hexes.size(), land, "every land hex")
		assert_eq(imp.family.size(), land)
		for row: Dictionary in _table:
			var hex := Vector2i(int(row["c"]), int(row["r"]))
			if not bool(row["land"]):
				assert_false(imp.family.has(hex), "sea hex %s has no option" % [hex])
				assert_true(imp.piece_at(hex).is_empty())
				continue
			var f := imp.family_at(hex)
			var lv := imp.level_at(hex)
			assert_true(f >= 0 and f < WorldImprove.FAMILIES, "a family for %s" % [hex])
			assert_true(lv >= 0 and lv <= WorldImprove.TOP_LEVEL[f], "a level of the family for %s" % [hex])
			assert_eq(f == WorldImprove.NONE, lv == 0, "level 0 is no piece, and only that")


func test_the_places_of_the_data_keep_their_level_and_nothing_else_is_a_settlement() -> void:
	if not _ready_or_fail():
		return
	for imp: WorldImprove in _runs:
		var places := 0
		for row: Dictionary in _table:
			if not bool(row["land"]):
				continue
			var hex := Vector2i(int(row["c"]), int(row["r"]))
			if typeof(row["place"]) == TYPE_DICTIONARY:
				var place: Dictionary = row["place"]
				places += 1
				assert_eq(imp.family_at(hex), WorldImprove.SETTLEMENT, "%s is a settlement" % place["name"])
				assert_eq(imp.level_at(hex), int(place["level"]), "%s keeps its level" % place["name"])
				var piece := imp.piece_at(hex)
				var shore_port := bool(place["port"]) and bool(row["coast"])
				assert_eq(int(piece["addon"]) > 0, shore_port, "a port on the shore, and only that, has the harbour add-on")
				if shore_port:
					assert_eq(str(piece["addon_mode"]), str(place["port_mode"]), "the port mode of the data")
			else:
				assert_ne(imp.family_at(hex), WorldImprove.SETTLEMENT, "no settlement the data do not have (%s)" % [hex])
		assert_eq(imp.count_of(WorldImprove.SETTLEMENT), places)


func test_castles_stand_only_on_passes_and_never_at_the_top_level() -> void:
	if not _ready_or_fail():
		return
	var passes := 0
	for row: Dictionary in _table:
		passes += int(bool(row["land"]) and bool(row.get("pass", false)) and typeof(row["place"]) != TYPE_DICTIONARY)
	assert_gt(passes, 0, "the region has passes")
	for imp: WorldImprove in _runs:
		for hex: Vector2i in imp.hexes:
			if imp.family_at(hex) != WorldImprove.CASTLE:
				continue
			assert_true(bool(imp.facts_at(hex)["pass"]), "the castle at %s holds a pass" % [hex])
			assert_lt(imp.level_at(hex), 3, "a watchtower or a castle, not a fortress")
		assert_lte(imp.count_of(WorldImprove.CASTLE), passes)


func test_the_cell_rules_hold_on_every_hex_of_every_seed() -> void:
	if not _ready_or_fail():
		return
	for imp: WorldImprove in _runs:
		for hex: Vector2i in imp.hexes:
			var f := imp.family_at(hex)
			if f == WorldImprove.NONE or f == WorldImprove.SETTLEMENT or f == WorldImprove.CASTLE:
				continue
			var facts := imp.facts_at(hex)
			var cover := int(facts["cover"])
			var lv := imp.level_at(hex)
			assert_true(WorldImprove.cell_allowed(f, lv, facts), "%s %d at %s" % [WorldImprove.NAMES[f], lv, hex])
			# The rules of the brief, checked from the facts and not through cell_allowed.
			match f:
				WorldImprove.WHEAT, WorldImprove.HEMP:
					assert_eq(cover, WorldCover.FARMLAND, "%s on plain farmland" % WorldImprove.NAMES[f])
				WorldImprove.TIMBER:
					assert_eq(cover, WorldCover.WOODS, "timber in woods")
				WorldImprove.GRAZING:
					assert_true(cover == WorldCover.GRASSLAND or (cover == WorldCover.WOODS
						and float(facts["height_m"]) >= WorldImprove.UPLAND_M), "grazing on grass or in the upland")
				WorldImprove.OLIVES:
					assert_eq(str(facts["climate"]), "mild", "olives only in the mild winter")
				WorldImprove.SALT, WorldImprove.HARBOUR:
					assert_true(bool(facts["coast"]), "%s on the coast" % WorldImprove.NAMES[f])
				WorldImprove.MINES, WorldImprove.QUARRY:
					assert_true(cover == WorldCover.ROCK or float(facts["height_m"]) >= WorldImprove.UPLAND_M, "rock or high ground")
				WorldImprove.DYES:
					assert_lte(int(facts["town_distance"]), 1, "dye works beside a town")
				WorldImprove.SILK:
					assert_lte(int(facts["town_distance"]), 2, "silk near a town")
			if f == WorldImprove.HEMP:
				assert_true(bool(facts["river"]), "hemp at a river")
			if lv == 3:
				assert_lte(int(facts["town_distance"]), 2, "the top stage only near a town")
			assert_true(cover != WorldCover.SNOW and cover != WorldCover.MARSH or f == WorldImprove.SALT,
				"snow and marsh stay wild")


func test_the_pair_rules_hold_on_every_seed() -> void:
	if not _ready_or_fail():
		return
	for imp: WorldImprove in _runs:
		assert_eq(imp.violations(), [] as Array[String], "no rule broken")
		# The same from the result alone: castles two hexes apart, no two top stages side by side, towns apart
		# (but for the pairs of places the data put side by side, which are listed and left).
		for a: Vector2i in imp.hexes:
			var fa := imp.family_at(a)
			if fa == WorldImprove.NONE:
				continue
			for b: Vector2i in imp.hexes:
				var distance := WorldImprove.hex_distance(a, b)
				if distance < 1 or distance > 2:
					continue
				var fb := imp.family_at(b)
				if fa == WorldImprove.CASTLE:
					assert_ne(fb, WorldImprove.CASTLE, "castles %s and %s are %d apart" % [a, b, distance])
				if distance == 1 and fa >= WorldImprove.WHEAT and fb >= WorldImprove.WHEAT:
					assert_false(imp.level_at(a) == 3 and imp.level_at(b) == 3, "two top stages touch: %s %s" % [a, b])
				if distance == 1 and (fa == WorldImprove.MINES or fa == WorldImprove.QUARRY):
					assert_false(fb == WorldImprove.MINES or fb == WorldImprove.QUARRY, "mines and quarries apart")
				if distance == 1 and fa == WorldImprove.SALT:
					assert_ne(fb, WorldImprove.SALT, "salt pans apart")


func test_the_same_seed_gives_the_same_map_and_another_seed_another() -> void:
	if not _ready_or_fail():
		return
	var again := WorldImprove.build(_table, SEEDS[0])
	assert_eq(again.family, _runs[0].family, "the same families")
	assert_eq(again.level, _runs[0].level, "the same levels")
	var differ := 0
	for hex: Vector2i in _runs[0].hexes:
		if _runs[0].family_at(hex) != _runs[1].family_at(hex) or _runs[0].level_at(hex) != _runs[1].level_at(hex):
			differ += 1
	assert_gt(differ, 10, "another seed moves the districts")


func test_the_search_needs_no_fallback_on_the_region() -> void:
	if not _ready_or_fail():
		return
	for imp: WorldImprove in _runs:
		assert_eq(imp.last_resort.size(), 0, "no fallback")
		assert_eq(imp.restarts, 0, "solved on the first attempt")
		assert_eq(imp.input_dead_ends, 0, "every hex has an option")


func test_most_of_the_map_stays_wild_and_the_counts_are_sensible() -> void:
	if not _ready_or_fail():
		return
	for imp: WorldImprove in _runs:
		var free := imp.hexes.size() - imp.count_of(WorldImprove.SETTLEMENT)
		var goods := 0
		var top := 0
		for f: int in range(WorldImprove.WHEAT, WorldImprove.FAMILIES):
			goods += imp.count_of(f)
			top += imp.count_at(f, 3)
		var share := float(goods) / float(free)
		assert_between(share, 0.12, 0.38, "goods on 12 to 38 percent of the free hexes (%d of %d)" % [goods, free])
		assert_lte(top * 5, goods + 4, "the top stage is rare: at most a fifth of the goods (%d of %d)" % [top, goods])
		assert_gt(imp.count_of(WorldImprove.WHEAT), 3, "wheat on the plain")
		assert_gt(imp.count_of(WorldImprove.TIMBER), 3, "timber in the woods")
		assert_lte(imp.count_of(WorldImprove.DYES), 8, "dye works are rare")
		assert_lte(imp.count_of(WorldImprove.MINES) + imp.count_of(WorldImprove.QUARRY), 16, "a few mines")
		var summary := imp.summary()
		assert_eq(int(summary["pieces"]) + int(summary["wild"]), imp.hexes.size(), "pieces and wild hexes add up")


func test_identical_neighbours_are_rarer_than_chance_and_families_cluster() -> void:
	if not _ready_or_fail():
		return
	var same_family := 0
	var identical := 0
	for imp: WorldImprove in _runs:
		for hex: Vector2i in imp.hexes:
			var f := imp.family_at(hex)
			if f < WorldImprove.WHEAT:
				continue
			for d: int in 3:
				var nb := WorldImprove.neighbour(hex, d)
				if imp.family_at(nb) == f:
					same_family += 1
					identical += int(imp.level_at(nb) == imp.level_at(hex))
	assert_gt(same_family, 8, "districts: neighbours of one family exist")
	assert_lt(identical * 2, same_family + 1, "and most of them differ in level (%d of %d the same)" % [identical, same_family])


# ----- small tables: fixed cells and rules at work ------------------------------------------------------------------


func test_a_port_gets_the_harbour_add_on_by_its_level_and_mode() -> void:
	var table: Array[Dictionary] = [
		_row(0, 0, "grassland", {"coast": true, "place": _place(5, true, "carved")}),
		_row(3, 0, "grassland", {"coast": true, "place": _place(2, true)}),
		_row(6, 0, "farmland", {"place": _place(4)}),
	]
	var imp := WorldImprove.build(table, 5)
	var genoa := imp.piece_at(Vector2i(0, 0))
	assert_eq(str(genoa["family"]), "settlements")
	assert_eq(int(genoa["level"]), 5)
	assert_eq(int(genoa["addon"]), 3, "a city's port is the great harbour")
	assert_eq(str(genoa["addon_mode"]), "carved")
	var village := imp.piece_at(Vector2i(3, 0))
	assert_eq(int(village["addon"]), 1, "a village's port is a jetty")
	assert_eq(str(village["addon_mode"]), "seaside")
	assert_eq(int(imp.piece_at(Vector2i(6, 0))["addon"]), 0, "an inland city has none")


func test_two_passes_side_by_side_never_both_take_a_castle() -> void:
	var castles := 0
	for s: int in range(1, 40):
		var table: Array[Dictionary] = [
			_row(0, 0, "rock", {"pass": true, "road": true, "height_m": 1900.0}),
			_row(1, 0, "rock", {"pass": true, "road": true, "height_m": 1900.0}),
			_row(2, 0, "rock", {"pass": true, "road": true, "height_m": 1900.0}),
		]
		var imp := WorldImprove.build(table, s)
		var here := imp.count_of(WorldImprove.CASTLE)
		assert_lte(here, 1, "three passes within two hexes: one castle at most (seed %d)" % s)
		castles += here
	assert_gt(castles, 5, "and some seeds build one")


func test_a_plain_round_a_city_is_worked_and_the_far_plain_mostly_wild() -> void:
	var near := 0
	var far := 0
	for s: int in range(1, 9):
		var table: Array[Dictionary] = []
		for r: int in 9:
			for c: int in 18:
				table.append(_row(c, r, "farmland", {"place": _place(5) if (c == 4 and r == 4) else null}))
		var imp := WorldImprove.build(table, s)
		for hex: Vector2i in imp.hexes:
			if imp.family_at(hex) < WorldImprove.WHEAT:
				continue
			var distance := WorldImprove.hex_distance(hex, Vector2i(4, 4))
			near += int(distance == 1)
			far += int(distance >= 5)
	# Six hexes round the city on eight seeds: 48; the far plain is about 90 hexes a seed.
	assert_gt(near, 28, "most of the six hexes round a city are worked (%d of 48)" % near)
	assert_lt(float(far) / 8.0 / 90.0, 0.33, "far from every town a quarter of the plain at most is worked")


func test_the_table_reads_names_numbers_and_missing_fields() -> void:
	var table: Array = [
		{"c": 0, "r": 0, "land": true, "cover": "Woods", "height_m": 300},
		{"c": 1, "r": 0, "land": 1, "cover": "Snow and ice", "height_m": 3000.0, "pass": "Great St Bernard"},
		{"c": 2, "r": 0, "land": false},
		"not a row",
	]
	var imp := WorldImprove.build(table, 1)
	assert_eq(imp.hexes.size(), 2)
	assert_eq(int(imp.facts_at(Vector2i(0, 0))["cover"]), WorldCover.WOODS)
	assert_eq(int(imp.facts_at(Vector2i(1, 0))["cover"]), WorldCover.SNOW)
	assert_true(bool(imp.facts_at(Vector2i(1, 0))["pass"]), "a pass name is a pass")
	assert_true(imp.family_at(Vector2i(0, 0)) in [WorldImprove.NONE, WorldImprove.TIMBER])


# ----- the search, on small synthetic instances (white box: the search fields set by hand) ---------------------------


## Cells on a row with the given neighbour pairs and starting domains, where an option may touch every option but
## itself, and nothing reaches two hexes.
func _synthetic(domains: Array[int], edges: Array[Vector2i]) -> WorldImprove:
	var out := WorldImprove.new()
	out._make_options()
	var n := domains.size()
	var options := WorldImprove.option_count()
	for i: int in n:
		out._cells.append(Vector2i(i, 0))
		out._index[Vector2i(i, 0)] = i
		out._facts.append({})
		out._ring2.append(PackedInt32Array())
	out._fixed.resize(n)
	out._fixed.fill(0)
	out._nbr.resize(n * 6)
	out._nbr.fill(-1)
	out._prior.resize(n * options)
	out._prior.fill(1.0)
	out._initial.resize(n)
	for i: int in n:
		out._initial[i] = domains[i]
	for e: Vector2i in edges:
		out._nbr[e.x * 6 + _free_slot(out, e.x)] = e.y
		out._nbr[e.y * 6 + _free_slot(out, e.y)] = e.x
	for a: int in options:
		out._compat1[a] = out._all & ~(1 << a)
		out._compat2[a] = out._all
	return out


func _free_slot(out: WorldImprove, cell: int) -> int:
	for d: int in 6:
		if out._nbr[cell * 6 + d] < 0:
			return d
	return 0


func _three() -> int:
	return (1 << WorldImprove.option_of(WorldImprove.WHEAT, 1)) | (1 << WorldImprove.option_of(WorldImprove.TIMBER, 1)) \
		| (1 << WorldImprove.option_of(WorldImprove.GRAZING, 1))


func test_a_satisfiable_instance_is_solved_without_a_fallback() -> void:
	var domains: Array[int] = []
	var edges: Array[Vector2i] = []
	for i: int in 6:
		domains.append(_three())
		if i > 0:
			edges.append(Vector2i(i - 1, i))
	var out := _synthetic(domains, edges)
	out._search(3)
	out._finish()
	assert_eq(out.last_resort.size(), 0, "no fallback")
	assert_eq(out.restarts, 0, "solved on the first attempt")
	for i: int in 5:
		assert_ne(out.family_at(Vector2i(i, 0)), out.family_at(Vector2i(i + 1, 0)), "cells %d and %d differ" % [i, i + 1])


func test_a_dead_end_is_undone_and_the_search_goes_on() -> void:
	# Three cells in a triangle with three options each, and a fourth cell that touches all three and may take one of
	# their options or a fourth one. It has the fewest options, so it is chosen first; when it takes the shared option
	# the triangle is left with two options for three cells: propagation sees nothing, the search runs into the dead
	# end, undoes it and strikes the choice. Every seed must end with a full answer.
	var undone := 0
	var shared := 1 << WorldImprove.option_of(WorldImprove.GRAZING, 1)
	var spare := 1 << WorldImprove.option_of(WorldImprove.VINEYARD, 1)
	var edges: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)]
	for s: int in range(1, 30):
		var domains: Array[int] = [_three(), _three(), _three(), shared | spare]
		var out := _synthetic(domains, edges)
		out._search(s)
		out._finish()
		undone += out.backtracks
		assert_eq(out.last_resort.size(), 0, "no fallback (seed %d)" % s)
		assert_eq(out.restarts, 0, "no restart (seed %d)" % s)
		assert_eq(out.family_at(Vector2i(3, 0)), WorldImprove.VINEYARD, "the fourth cell ends on its spare option")
		for e: Vector2i in edges:
			assert_ne(out.family_at(Vector2i(e.x, 0)), out.family_at(Vector2i(e.y, 0)), "edge %s (seed %d)" % [e, s])
	assert_gt(undone, 10, "about half of the seeds ran into the dead end and undid it (%d backtracks)" % undone)


func test_an_unsatisfiable_instance_is_undone_restarted_and_reported() -> void:
	# Four cells all touching each other, each allowed three options that must all differ: no such colouring.
	var domains: Array[int] = [_three(), _three(), _three(), _three()]
	var edges: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3)]
	var out := _synthetic(domains, edges)
	out._search(3)
	out._finish()
	assert_gt(out.backtracks, 0, "dead ends were undone")
	assert_gt(out.contradictions, 0, "found by propagation")
	assert_eq(out.restarts, WorldImprove.RETRIES + 1, "every attempt failed and was restarted")
	assert_gt(out.last_resort.size(), 0, "the fallback placed the open cells and listed them")


# ----- the changes of the player: build, upgrade, clear -------------------------------------------------------------


## A 5 x 5 block of one ground with the given places, every hex wild but the places (the search's choices are cleared).
func _bare(cover: String, height: float, places: Dictionary = {}, more: Dictionary = {}) -> WorldImprove:
	var table: Array[Dictionary] = []
	for r: int in 5:
		for c: int in 5:
			var extra := more.duplicate()
			extra["height_m"] = height
			if places.has(Vector2i(c, r)):
				extra["place"] = _place(int(places[Vector2i(c, r)]))
			table.append(_row(c, r, cover, extra))
	var imp := WorldImprove.build(table, 3)
	for hex: Vector2i in imp.hexes:
		if not imp.is_fixed(hex):
			imp._put(hex, WorldImprove.NONE, 0)
	return imp


func _sum_is_right(imp: WorldImprove) -> void:
	var total := 0
	for f: int in WorldImprove.FAMILIES:
		total += imp.count_of(f)
	assert_eq(total, imp.hexes.size(), "every hex is counted once")
	var by_hex := {}
	for hex: Vector2i in imp.hexes:
		var key := imp.family_at(hex) * 6 + imp.level_at(hex)
		by_hex[key] = int(by_hex.get(key, 0)) + 1
	for f: int in WorldImprove.FAMILIES:
		for lv: int in range(0, 6):
			assert_eq(imp.count_at(f, lv), int(by_hex.get(f * 6 + lv, 0)), "count of family %d level %d" % [f, lv])


func test_build_lists_what_the_ground_allows_and_builds_level_one() -> void:
	var imp := _bare("farmland", 100.0, {Vector2i(2, 2): 2})
	var hex := Vector2i(3, 2)
	var options := imp.build_options(hex)
	var ids: Array[int] = []
	for o: Dictionary in options:
		ids.append(int(o["family_id"]))
		assert_eq(int(o["level"]), 1)
		assert_true(bool(o["ok"]), "nothing forbids it yet: %s" % o["family"])
	assert_true(ids.has(WorldImprove.WHEAT), "wheat on farmland")
	assert_false(ids.has(WorldImprove.TIMBER), "no timber on farmland")
	assert_false(ids.has(WorldImprove.CASTLE), "no castle off the passes")
	assert_true(imp.build_options(Vector2i(2, 2)).is_empty(), "a place has no build list")
	assert_true(imp.build_options(Vector2i(50, 50)).is_empty(), "nor does the sea")
	assert_false(bool(imp.build_check(hex, WorldImprove.TIMBER)["ok"]), "timber refused")
	assert_ne(str(imp.build_check(hex, WorldImprove.TIMBER)["reason"]), "", "with a reason")
	var done := imp.build_on(hex, WorldImprove.WHEAT)
	assert_true(bool(done["ok"]))
	assert_eq(imp.family_at(hex), WorldImprove.WHEAT)
	assert_eq(imp.level_at(hex), 1)
	assert_eq(str(imp.piece_at(hex)["family"]), "wheat")
	assert_false(bool(imp.build_check(hex, WorldImprove.WHEAT)["ok"]), "no second piece on one hex")
	assert_true(imp.build_options(hex).is_empty(), "a built hex has no build list")
	_sum_is_right(imp)


func test_upgrade_climbs_while_the_rules_allow_and_a_village_grows_into_a_town() -> void:
	var imp := _bare("farmland", 100.0, {Vector2i(2, 2): 2})
	var hex := Vector2i(3, 2)
	assert_false(bool(imp.upgrade_check(hex)["ok"]), "nothing to upgrade on a wild hex")
	imp.build_on(hex, WorldImprove.WHEAT)
	var look := imp.piece_at(hex)
	assert_true(bool(imp.upgrade(hex)["ok"]), "level 2 beside a village")
	assert_eq(imp.level_at(hex), 2)
	var no := imp.upgrade_check(hex)
	assert_false(bool(no["ok"]), "level 3 needs a town")
	assert_true(str(no["reason"]).contains("town"), str(no["reason"]))
	assert_false(bool(imp.upgrade(hex)["ok"]))
	assert_eq(imp.level_at(hex), 2, "a refused upgrade changes nothing")
	# The village (a place of the data) grows: a village of level 2 to a town of level 3 and on.
	var village := Vector2i(2, 2)
	assert_true(imp.is_fixed(village))
	assert_true(bool(imp.upgrade(village)["ok"]), "village to town")
	assert_eq(imp.level_at(village), 3)
	assert_eq(imp.count_at(WorldImprove.SETTLEMENT, 3), 1, "counts follow")
	assert_true(bool(imp.upgrade(hex)["ok"]), "the town opens level 3 beside it")
	assert_eq(imp.level_at(hex), 3)
	assert_false(bool(imp.upgrade(hex)["ok"]), "no level 4 for goods")
	assert_true(bool(imp.upgrade(village)["ok"]), "town to walled town")
	assert_true(bool(imp.upgrade(village)["ok"]), "walled town to city")
	assert_false(bool(imp.upgrade_check(village)["ok"]), "a city is the top")
	assert_eq(imp.level_at(village), 5)
	# The picture of the wheat did not jump.
	var after := imp.piece_at(hex)
	assert_eq(after["variant"], look["variant"])
	assert_eq(after["mirror"], look["mirror"])
	assert_eq(imp.piece_at(village)["family_id"], WorldImprove.SETTLEMENT)
	_sum_is_right(imp)


func test_a_neighbouring_top_stage_and_a_neighbouring_town_refuse_the_upgrade() -> void:
	var imp := _bare("farmland", 100.0, {Vector2i(2, 2): 3})
	imp.build_on(Vector2i(3, 2), WorldImprove.WHEAT)
	imp.upgrade(Vector2i(3, 2))
	imp.upgrade(Vector2i(3, 2))
	assert_eq(imp.level_at(Vector2i(3, 2)), 3)
	imp.build_on(Vector2i(4, 2), WorldImprove.VINEYARD)
	assert_true(bool(imp.upgrade(Vector2i(4, 2))["ok"]), "level 2 is fine beside a level 3")
	var no := imp.upgrade_check(Vector2i(4, 2))
	assert_false(bool(no["ok"]), "two level 3 districts never touch")
	assert_true(str(no["reason"]).contains("top stage"), str(no["reason"]))
	assert_eq(str(imp.upgrade(Vector2i(4, 2))["reason"]), str(no["reason"]), "the action says what the check says")
	assert_eq(imp.level_at(Vector2i(4, 2)), 2)
	# Two towns side by side: a village beside a town may not become a town.
	var table: Array[Dictionary] = [
		_row(0, 0, "farmland", {"place": _place(3)}), _row(1, 0, "farmland", {"place": _place(2)}),
	]
	var two := WorldImprove.build(table, 1)
	var refused := two.upgrade_check(Vector2i(1, 0))
	assert_false(bool(refused["ok"]), "no two towns side by side")
	assert_true(str(refused["reason"]).contains("town"), str(refused["reason"]))
	assert_eq(two.level_at(Vector2i(1, 0)), 2)


func test_a_build_beside_a_neighbour_is_listed_greyed_with_the_rule() -> void:
	var imp := _bare("rock", 1500.0, {}, {"climate": "snow"})
	assert_true(bool(imp.build_on(Vector2i(2, 2), WorldImprove.MINES)["ok"]))
	var found := {}
	for o: Dictionary in imp.build_options(Vector2i(3, 2)):
		found[int(o["family_id"])] = o
	assert_true(found.has(WorldImprove.MINES) and found.has(WorldImprove.QUARRY), "both fit rock")
	var mines: Dictionary = found[WorldImprove.MINES]
	assert_false(bool(mines["ok"]), "one mining district per valley")
	assert_ne(str(mines["reason"]), "")
	var quarry: Dictionary = found[WorldImprove.QUARRY]
	assert_false(bool(quarry["ok"]), "mine and quarry apart")
	assert_false(bool(imp.build_on(Vector2i(3, 2), WorldImprove.MINES)["ok"]))
	assert_eq(imp.family_at(Vector2i(3, 2)), WorldImprove.NONE, "a refused build changes nothing")
	for o: Dictionary in imp.build_options(Vector2i(4, 4)):
		assert_true(bool(o["ok"]), "two hexes or more away nothing is forbidden: %s" % o["family"])
	_sum_is_right(imp)


func test_clear_brings_the_hex_back_but_never_a_place_of_the_data() -> void:
	var imp := _bare("farmland", 100.0, {Vector2i(2, 2): 3})
	var hex := Vector2i(1, 2)
	assert_false(bool(imp.clear_check(hex)["ok"]), "nothing to clear")
	imp.build_on(hex, WorldImprove.WHEAT)
	imp.upgrade(hex)
	assert_true(bool(imp.clear(hex)["ok"]))
	assert_eq(imp.family_at(hex), WorldImprove.NONE)
	assert_eq(imp.level_at(hex), 0)
	assert_true(imp.piece_at(hex).is_empty())
	var town := imp.clear_check(Vector2i(2, 2))
	assert_false(bool(town["ok"]), "towns are not demolished")
	assert_ne(str(town["reason"]), "")
	assert_false(bool(imp.clear(Vector2i(2, 2))["ok"]))
	assert_eq(imp.family_at(Vector2i(2, 2)), WorldImprove.SETTLEMENT)
	imp.upgrade(Vector2i(2, 2))
	assert_false(bool(imp.clear_check(Vector2i(2, 2))["ok"]), "nor a town that grew")
	_sum_is_right(imp)


func test_a_pass_takes_a_watchtower_and_it_grows() -> void:
	var table: Array[Dictionary] = [_row(0, 0, "rock", {"pass": true, "height_m": 1800.0}), _row(1, 0, "farmland")]
	var imp := WorldImprove.build(table, 1)
	imp._put(Vector2i(0, 0), WorldImprove.NONE, 0)
	var options := imp.build_options(Vector2i(0, 0))
	assert_eq(options.size(), 1)
	assert_eq(int(options[0]["family_id"]), WorldImprove.CASTLE)
	assert_false(bool(imp.build_check(Vector2i(0, 0), WorldImprove.WHEAT)["ok"]), "no goods on a pass")
	assert_true(bool(imp.build_on(Vector2i(0, 0), WorldImprove.CASTLE)["ok"]))
	assert_true(bool(imp.upgrade(Vector2i(0, 0))["ok"]), "watchtower to castle")
	assert_true(bool(imp.upgrade(Vector2i(0, 0))["ok"]), "castle to fortress")
	assert_false(bool(imp.upgrade_check(Vector2i(0, 0))["ok"]), "the fortress is the top")
	assert_true(bool(imp.clear(Vector2i(0, 0))["ok"]), "a castle can be pulled down")
	assert_false(bool(imp.build_check(Vector2i(1, 0), WorldImprove.CASTLE)["ok"]), "no castle off a pass")


func _play(imp: WorldImprove, rolls: int) -> void:
	var rng := Rng.new()
	rng.seed_with(99)
	for _n: int in rolls:
		var hex: Vector2i = imp.hexes[rng.randi_range(0, imp.hexes.size() - 1)]
		var which := rng.randi_range(0, 9)
		if imp.family_at(hex) == WorldImprove.NONE:
			var options := imp.build_options(hex)
			if not options.is_empty():
				var o: Dictionary = options[rng.randi_range(0, options.size() - 1)]
				imp.build_on(hex, int(o["family_id"]))
		elif which < 7:
			imp.upgrade(hex)
		else:
			imp.clear(hex)


func test_after_many_changes_every_rule_still_holds_and_the_counts_are_right() -> void:
	if not _ready_or_fail():
		return
	for s: int in [0, 2]:
		var imp := WorldImprove.build(_table, SEEDS[s])
		var base := imp.violations().size()
		_play(imp, 1500)
		assert_eq(imp.violations().size(), base, "no new rule broken (seed %d)" % SEEDS[s])
		_sum_is_right(imp)
		var summary := imp.summary()
		assert_eq(int(summary["pieces"]) + int(summary["wild"]), int(summary["hexes"]))
		# A check that passes always acts, and one that refuses changes nothing.
		var tried := 0
		for hex: Vector2i in imp.hexes:
			var verdict := imp.upgrade_check(hex)
			var before := imp.level_at(hex)
			var done := imp.upgrade(hex)
			assert_eq(bool(done["ok"]), bool(verdict["ok"]), "check and action agree at %s" % hex)
			assert_eq(imp.level_at(hex), before + 1 if bool(verdict["ok"]) else before)
			tried += 1
			if bool(done["ok"]):
				assert_eq(imp.violations().size(), base, "an upgrade at %s kept the rules" % hex)
				break
		assert_gt(tried, 0)


func test_the_same_changes_give_the_same_map() -> void:
	if not _ready_or_fail():
		return
	var a := WorldImprove.build(_table, SEEDS[2])
	var b := WorldImprove.build(_table, SEEDS[2])
	_play(a, 400)
	_play(b, 400)
	for hex: Vector2i in a.hexes:
		assert_eq(a.family_at(hex), b.family_at(hex))
		assert_eq(a.level_at(hex), b.level_at(hex))
		assert_eq(a.piece_at(hex), b.piece_at(hex))
