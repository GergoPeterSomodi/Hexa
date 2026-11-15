## The ground cover of the map prototype region (core/mapgen/world_cover.gd): every land hex has one cover; the cell rules
## and the adjacency table hold everywhere; the same seed gives the same cover and another seed a different one; the
## counts are in sane ranges; the search undoes dead ends and reports what it cannot solve (checked on a small
## synthetic instance, since the region itself needs no backtrack).
extends GutTest

const HEIGHTS := "res://data/worldmap/heights_alps_po.json"
const REGION := "res://data/worldmap/region_alps_po.json"

var _grid: HexGrid = null
var _heights: WorldHeights = null
var _region: WorldRegion = null
var _relief: WorldRelief = null
var _water: WorldWater = null
var _cover: WorldCover = null


func before_all() -> void:
	_heights = WorldHeights.from_text(FileAccess.get_file_as_string(HEIGHTS))
	_region = WorldRegion.from_text(FileAccess.get_file_as_string(REGION))
	if _heights == null or _region == null:
		return
	_grid = HexGrid.new(_region.hex_w_km, _region.deg_km, _region.ref_lat, _region.lon_west, _region.lat_north)
	_relief = WorldRelief.build(_grid, _heights, _region)
	_water = WorldWater.build(_grid, _relief, _heights, _region)
	_cover = WorldCover.build(_grid, _relief, _heights, _water, _region.cover_seed)


func _ready_or_fail() -> bool:
	if _cover == null:
		fail_test("the heights and the region must read")
		return false
	return true


func _lat_of(hex: Vector2i) -> float:
	return _grid.lonlat_of(_grid.centre_km(hex)).y


func _lon_of(hex: Vector2i) -> float:
	return _grid.lonlat_of(_grid.centre_km(hex)).x


func _land_count() -> int:
	var n := 0
	for hex: Vector2i in _relief.levels.keys():
		if _relief.level_at(hex) != ReliefLevels.SEA:
			n += 1
	return n


func test_every_land_hex_has_one_cover_and_no_sea_hex_has_one() -> void:
	if not _ready_or_fail():
		return
	assert_eq(_cover.cover.size(), _land_count(), "one cover per land hex")
	for hex: Vector2i in _relief.levels.keys():
		if _relief.level_at(hex) == ReliefLevels.SEA:
			assert_eq(_cover.cover_at(hex), -1, "sea hex %s has no cover" % [hex])
		else:
			var c := _cover.cover_at(hex)
			assert_true(c >= 0 and c < WorldCover.COUNT, "a valid cover for %s" % [hex])


func test_the_cell_rules_hold_on_every_hex() -> void:
	if not _ready_or_fail():
		return
	for hex: Vector2i in _cover.cover.keys():
		var ok := WorldCover.cell_allowed(_cover.cover_at(hex), _relief.level_at(hex),
			float(_heights.height_m.get(hex, 0.0)), _cover.is_coastal(hex), _cover.is_cliff(hex), _lat_of(hex))
		assert_true(ok, "cell rule for %s (%s on level %d)" % [hex, WorldCover.NAMES[_cover.cover_at(hex)],
			_relief.level_at(hex)])


func test_snow_only_on_the_highest_ground() -> void:
	if not _ready_or_fail():
		return
	for hex: Vector2i in _cover.cover.keys():
		if _cover.cover_at(hex) != WorldCover.SNOW:
			continue
		var level := _relief.level_at(hex)
		var metres := float(_heights.height_m.get(hex, 0.0))
		assert_eq(level, 6, "snow at %s is on the highest ground (%d m)" % [hex, metres])


func test_woods_stop_at_the_tree_line_and_rock_fills_the_bare_ground_above_it() -> void:
	if not _ready_or_fail():
		return
	for hex: Vector2i in _cover.cover.keys():
		var metres := float(_heights.height_m.get(hex, 0.0))
		if _cover.cover_at(hex) == WorldCover.WOODS and _relief.level_at(hex) == 5:
			assert_lt(metres, WorldCover.TREE_LINE_M, "woods on level 5 only below the tree line at %s" % [hex])
		if _relief.level_at(hex) == 5 and metres >= WorldCover.TREE_LINE_M:
			assert_ne(_cover.cover_at(hex), WorldCover.WOODS, "no woods above the tree line at %s" % [hex])


func test_woods_never_on_high_peaks_and_marsh_only_on_lowland_and_plain() -> void:
	if not _ready_or_fail():
		return
	for hex: Vector2i in _cover.cover.keys():
		var level := _relief.level_at(hex)
		if _cover.cover_at(hex) == WorldCover.WOODS:
			assert_lt(level, 6, "no woods on level 6 at %s" % [hex])
		if _cover.cover_at(hex) == WorldCover.MARSH:
			assert_true(level == 1 or level == 2, "marsh at %s is on lowland or plain" % [hex])


func test_the_adjacency_table_holds_between_every_pair_of_neighbours() -> void:
	if not _ready_or_fail():
		return
	var pairs := 0
	for hex: Vector2i in _cover.cover.keys():
		for nb: Vector2i in _grid.neighbours(hex):
			if not _cover.cover.has(nb):
				continue
			pairs += 1
			assert_true(WorldCover.pair_allowed(_cover.cover_at(hex), _cover.cover_at(nb)),
				"%s beside %s: %s and %s" % [hex, nb, WorldCover.NAMES[_cover.cover_at(hex)], WorldCover.NAMES[_cover.cover_at(nb)]])
	assert_gt(pairs, 1000, "every land edge was checked (%d ordered pairs)" % pairs)


func test_the_same_seed_gives_the_same_cover() -> void:
	if not _ready_or_fail():
		return
	var again := WorldCover.build(_grid, _relief, _heights, _water, _region.cover_seed)
	assert_eq(again.cover, _cover.cover, "same relief, water and seed: same covers")
	assert_eq(again.summary(), _cover.summary(), "and the same statistics")


func test_another_seed_gives_another_cover() -> void:
	if not _ready_or_fail():
		return
	var other := WorldCover.build(_grid, _relief, _heights, _water, 7)
	var differ := 0
	for hex: Vector2i in _cover.cover.keys():
		if other.cover_at(hex) != _cover.cover_at(hex):
			differ += 1
	assert_gt(differ, 20, "a different seed changes the cover (%d hexes differ)" % differ)


func test_the_search_finds_every_cover_without_a_fallback() -> void:
	if not _ready_or_fail():
		return
	assert_eq(_cover.input_dead_ends, 0, "no hex has no allowed cover before the search")
	assert_eq(_cover.last_resort.size(), 0, "the search needed no greedy fallback")
	assert_eq(_cover.last_resort_violations, 0, "and so allowed no forbidden pair")


func test_counts_per_cover_are_in_sane_ranges() -> void:
	if not _ready_or_fail():
		return
	var land := float(_land_count())
	var share := func(c: int) -> float: return float(_cover.count_of(c)) / land
	assert_between(share.call(WorldCover.FARMLAND), 0.10, 0.30, "farmland share (the Po plain, the valleys)")
	assert_between(share.call(WorldCover.GRASSLAND), 0.15, 0.40, "grassland share")
	assert_between(share.call(WorldCover.WOODS), 0.12, 0.30, "woods share (the Apennines, the Alpine flanks)")
	assert_between(share.call(WorldCover.ROCK), 0.08, 0.25, "rock share")
	assert_between(share.call(WorldCover.SNOW), 0.12, 0.30, "snow and ice share (the high Alps)")
	assert_between(share.call(WorldCover.MARSH), 0.0, 0.05, "marsh is rare: the window has little low wet ground")
	assert_eq(_cover.count_of(WorldCover.TUNDRA), 0, "no tundra south of 58 degrees")
	var total := 0
	for c: int in WorldCover.COUNT:
		total += _cover.count_of(c)
	assert_eq(total, _land_count(), "the counts add up to the land hexes")


func test_the_po_plain_is_farmland_and_grass() -> void:
	if not _ready_or_fail():
		return
	var plain := 0
	var open := 0
	var farmland := 0
	for hex: Vector2i in _cover.cover.keys():
		var lat := _lat_of(hex)
		var lon := _lon_of(hex)
		if _relief.level_at(hex) > 2 or lat < 44.9 or lat > 45.6 or lon < 8.0 or lon > 10.5:
			continue
		plain += 1
		if _cover.cover_at(hex) == WorldCover.FARMLAND or _cover.cover_at(hex) == WorldCover.GRASSLAND:
			open += 1
		if _cover.cover_at(hex) == WorldCover.FARMLAND:
			farmland += 1
	assert_gt(plain, 15, "the Po plain window has lowland and plain hexes (%d)" % plain)
	# v2 (tree-line woods) moves woods onto the lowest prealp hexes, so the bar is 70% (v1 was 80%+).
	assert_gte(float(open) / float(plain), 0.7, "at least 70%% of the plain is farmland or grass (%d of %d)" % [open, plain])
	assert_gt(farmland, 0, "some farmland on the plain")


func test_the_high_alps_are_rock_or_snow() -> void:
	if not _ready_or_fail():
		return
	var peaks := 0
	var bare := 0
	var snow := 0
	for hex: Vector2i in _cover.cover.keys():
		if _relief.level_at(hex) != 6:
			continue
		peaks += 1
		var c := _cover.cover_at(hex)
		if c == WorldCover.ROCK or c == WorldCover.SNOW:
			bare += 1
		if c == WorldCover.SNOW:
			snow += 1
	assert_gt(peaks, 0, "the window has high peaks")
	assert_eq(bare, peaks, "every high peak is rock or snow")
	assert_gt(snow * 2, peaks, "most high peaks carry snow")


func test_blend_is_the_cover_edge_value() -> void:
	if not _ready_or_fail():
		return
	var blends := 0
	var sames := 0
	for hex: Vector2i in _cover.cover.keys():
		for nb: Vector2i in _grid.neighbours(hex):
			if not _cover.cover.has(nb):
				continue
			var differ := _cover.cover_at(hex) != _cover.cover_at(nb)
			assert_eq(_cover.is_blend(hex, nb), differ, "blend flag of %s-%s" % [hex, nb])
			if differ:
				blends += 1
			else:
				sames += 1
	assert_gt(blends, 0, "some edges blend")
	assert_gt(sames, 0, "some edges join two hexes of one cover")


func test_covers_cluster_into_patches() -> void:
	if not _ready_or_fail():
		return
	# A neighbour is the same cover about twice as often as that cover's share of the land (or more): patches, not noise.
	var land := float(_land_count())
	for c: int in [WorldCover.FARMLAND, WorldCover.WOODS, WorldCover.ROCK, WorldCover.SNOW]:
		var base := float(_cover.count_of(c)) / land
		var same := 0
		var pairs := 0
		for hex: Vector2i in _cover.cover.keys():
			if _cover.cover_at(hex) != c:
				continue
			for nb: Vector2i in _grid.neighbours(hex):
				if not _cover.cover.has(nb):
					continue
				pairs += 1
				if _cover.cover_at(nb) == c:
					same += 1
		var chance := float(same) / float(maxi(pairs, 1))
		assert_gte(chance, 2.0 * base, "%s: a neighbour is %s in %.2f of the pairs (its share of the land %.2f)"
			% [WorldCover.NAMES[c], WorldCover.NAMES[c], chance, base])


func test_the_relief_shade_stays_within_its_range() -> void:
	if not _ready_or_fail():
		return
	var lo := 0.0
	var hi := 0.0
	for hex: Vector2i in _cover.shade.keys():
		lo = minf(lo, float(_cover.shade[hex]))
		hi = maxf(hi, float(_cover.shade[hex]))
	assert_gte(lo, -0.2, "the darkest shade")
	assert_lte(hi, 0.2, "the lightest shade")
	assert_lt(lo, -0.05, "some slopes face away from the light")
	assert_gt(hi, 0.05, "some slopes face the light")


# ----- the search, on small synthetic instances (white box: the search fields set by hand) ---------------------------


## A cover with cells on a row, with the given neighbour pairs, starting domains (bit masks) and a "may touch" table.
func _synthetic(domains: Array[int], edges: Array[Vector2i], compat: PackedInt32Array) -> WorldCover:
	var out := WorldCover.new()
	var n := domains.size()
	for i: int in n:
		out._cells.append(Vector2i(i, 0))
	out._level.resize(n)
	out._level.fill(1)
	out._metres.resize(n)
	out._metres.fill(0.0)
	out._lat.resize(n)
	out._lat.fill(45.0)
	out._nbr.resize(n * 6)
	out._nbr.fill(-1)
	out._prior.resize(n * WorldCover.COUNT)
	out._prior.fill(1.0)
	out._initial.resize(n)
	for i: int in n:
		out._initial[i] = domains[i]
	for e: Vector2i in edges:
		out._nbr[e.x * 6 + _free_slot(out, e.x)] = e.y
		out._nbr[e.y * 6 + _free_slot(out, e.y)] = e.x
	out._compat = compat
	return out


func _free_slot(out: WorldCover, cell: int) -> int:
	for d: int in 6:
		if out._nbr[cell * 6 + d] < 0:
			return d
	return 0


## "Different covers" on every edge: the table where a cover may touch every cover but itself.
func _all_different() -> PackedInt32Array:
	var full := (1 << WorldCover.COUNT) - 1
	var out := PackedInt32Array()
	out.resize(WorldCover.COUNT)
	for a: int in WorldCover.COUNT:
		out[a] = full & ~(1 << a)
	return out


func test_a_satisfiable_instance_is_solved_without_a_fallback() -> void:
	# A path of six cells, each may be farmland, grassland or woods, neighbours must differ: always solvable.
	var three := (1 << WorldCover.FARMLAND) | (1 << WorldCover.GRASSLAND) | (1 << WorldCover.WOODS)
	var domains: Array[int] = []
	var edges: Array[Vector2i] = []
	for i: int in 6:
		domains.append(three)
		if i > 0:
			edges.append(Vector2i(i - 1, i))
	var out := _synthetic(domains, edges, _all_different())
	out._search(3)
	out._finish()
	assert_eq(out.last_resort.size(), 0, "no fallback")
	for i: int in 5:
		var a := out.cover_at(Vector2i(i, 0))
		var b := out.cover_at(Vector2i(i + 1, 0))
		assert_true(a >= 0 and b >= 0 and a != b, "cells %d and %d differ (%d, %d)" % [i, i + 1, a, b])
	assert_eq(out.restarts, 0, "solved on the first attempt")


func test_an_unsatisfiable_instance_is_undone_restarted_and_reported() -> void:
	# Four cells all touching each other, each allowed three covers that must all differ: K4 has no such colouring.
	var three := (1 << WorldCover.FARMLAND) | (1 << WorldCover.GRASSLAND) | (1 << WorldCover.WOODS)
	var domains: Array[int] = [three, three, three, three]
	var edges: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3)]
	var out := _synthetic(domains, edges, _all_different())
	out._search(3)
	out._finish()
	assert_gt(out.backtracks, 0, "dead ends were undone")
	assert_eq(out.restarts, WorldCover.RETRIES + 1, "every attempt failed and was restarted")
	assert_eq(out.last_resort.size(), 4, "the greedy fill placed every cell and listed it")
	assert_gt(out.last_resort_violations, 0, "and reported the pairs it had to allow")


func test_the_low_hexes_of_a_marsh_zone_are_marsh() -> void:
	var low := 0
	for hex: Vector2i in _water.marsh_zone.keys():
		var level := _relief.level_at(hex)
		if level == ReliefLevels.SEA or level > 2:
			continue
		low += 1
		assert_eq(_cover.cover_at(hex), WorldCover.MARSH, "the low hex %s of a marsh zone is marsh" % str(hex))
	assert_gt(low, 0, "the Po delta and the lagoon edges have low hexes")
