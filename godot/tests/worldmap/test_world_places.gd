## The settlements of the map prototype region (core/worldmap/world_places.gd): every authored place snapped to a free land hex
## within one hex of its true position, the river cities on their pinned hexes, the levels, castles and capital of the named
## places, one hospice on each saddle of a pass with a crest at 2000 metres or more (no two passes share a saddle), generated
## places only at levels 1 and 2 and at least SPACING hexes apart, and every port with a quay on its own shore or lake edge.
## The counts pin what the first build showed.
extends GutTest

const HEIGHTS := "res://data/worldmap/heights_alps_po.json"
const REGION := "res://data/worldmap/region_alps_po.json"

var _grid: WorldGrid = null
var _region: WorldRegion = null
var _relief: WorldRelief = null
var _water: WorldWater = null
var _cover: WorldCover = null
var _places: WorldPlaces = null


func before_all() -> void:
	var heights := WorldHeights.from_text(FileAccess.get_file_as_string(HEIGHTS))
	_region = WorldRegion.from_text(FileAccess.get_file_as_string(REGION))
	if heights == null or _region == null:
		return
	_grid = WorldGrid.new(_region.hex_w_km, _region.deg_km, _region.ref_lat, _region.lon_west, _region.lat_north)
	_relief = WorldRelief.build(_grid, heights, _region)
	_water = WorldWater.build(_grid, _relief, heights, _region)
	_cover = WorldCover.build(_grid, _relief, heights, _water, _region.cover_seed)
	_places = WorldPlaces.build(_grid, _relief, _water, _cover, _region)


func _ready_or_fail() -> bool:
	if _places == null:
		fail_test("the heights and the region must read")
		return false
	return true


func test_authored_places_snap_within_one_hex_of_their_true_hex() -> void:
	if not _ready_or_fail():
		return
	assert_eq(_places.failures.size(), 0, "every authored place finds a free land hex")
	for raw: Dictionary in _region.places:
		var pname: String = raw["name"]
		var kind: String = raw["kind"]
		if kind == "hospice":
			continue
		var pos: Vector2 = raw["pos"]
		var true_hex := _grid.hex_of(pos.x, pos.y)
		if kind == "landmark":
			assert_true(_has_landmark(pname), "%s: the monastery is a landmark" % pname)
			continue
		var placed := _places.find(pname)
		assert_false(placed.is_empty(), "%s is placed" % pname)
		if placed.is_empty():
			continue
		var hex: Vector2i = placed["hex"]
		assert_lte(WorldPlaces.hex_distance(hex, true_hex), 1, "%s stays within one hex of its place" % pname)
		assert_true(_relief.level_at(hex) != ReliefLevels.SEA, "%s stands on land" % pname)


func test_river_cities_sit_on_their_pinned_hexes() -> void:
	if not _ready_or_fail():
		return
	assert_eq(_water.city_hex.size(), 4, "four river cities in the region")
	for city: String in _water.city_hex.keys():
		var placed := _places.find(city)
		assert_false(placed.is_empty(), "%s is placed" % city)
		if placed.is_empty():
			continue
		assert_eq(placed["hex"], _water.city_hex[city], "%s keeps the hex its river runs through" % city)
		assert_true(bool(placed["river_city"]), "%s is marked a river city" % city)


func test_the_named_levels_capital_and_castles() -> void:
	if not _ready_or_fail():
		return
	var milan := _places.find("Milan")
	assert_eq(int(milan["level"]), 5, "Milan is the great city")
	assert_true(bool(milan["capital"]), "Milan is the capital")
	assert_eq(int(milan["castle"]), 3, "Milan has a large castle")
	var capitals := 0
	for pl: Dictionary in _places.places:
		if bool(pl["capital"]):
			capitals += 1
	assert_eq(capitals, 1, "one capital in the region")
	assert_eq(int(_places.find("Genoa")["level"]), 4, "Genoa is a city")
	assert_true(bool(_places.find("Genoa")["port"]), "Genoa is a port")
	assert_eq(int(_places.find("Genoa")["castle"]), 2, "Genoa has a castle of level 2")
	var venice := _places.find("Venice")
	assert_eq(int(venice["level"]), 5, "Venice is a great city on the lagoon")
	assert_true(bool(venice["port"]), "Venice is a port (its quay is on the lagoon's sea edge)")
	assert_eq(int(_places.find("Padua")["level"]), 4, "Padua is a city")
	assert_eq(int(_places.find("Ferrara")["level"]), 4, "Ferrara is a city on the Po")
	assert_eq(int(_places.find("Turin")["level"]), 3, "Turin is a town (size 15)")
	assert_eq(int(_places.find("Bern")["level"]), 2, "Bern is a village (size 5)")
	assert_eq(int(_places.find("Pavia")["level"]), 4, "Pavia is a city")
	assert_eq(int(_places.find("Pavia")["castle"]), 2, "Pavia has a castle of level 2")
	assert_eq(int(_places.find("Bellinzona")["castle"]), 3, "Bellinzona has castle level 3")
	var standalone := 0
	for pl: Dictionary in _places.places:
		if int(pl["level"]) == 0 and int(pl["castle"]) > 0:
			standalone += 1
	assert_eq(standalone, 1, "the Bard fort stands alone")


func test_no_two_places_share_a_hex() -> void:
	if not _ready_or_fail():
		return
	var seen: Dictionary[Vector2i, bool] = {}
	for pl: Dictionary in _places.places:
		var hex: Vector2i = pl["hex"]
		assert_false(seen.has(hex), "%s: one place per hex" % str(hex))
		seen[hex] = true


func test_each_pass_with_a_crest_has_its_own_saddle() -> void:
	if not _ready_or_fail():
		return
	var crest_passes := 0
	for p: int in _region.passes.size():
		if bool(_relief.pass_has_crest.get(p, false)):
			crest_passes += 1
	assert_eq(_places.pass_saddles.size(), crest_passes, "every pass with a crest has a saddle")
	assert_eq(_places.failures.size(), 0, "no pass lacks a free crest hex")
	var seen: Dictionary[Vector2i, bool] = {}
	for p: int in _places.pass_saddles.keys():
		var s: Vector2i = _places.pass_saddles[p]
		assert_false(seen.has(s), "%s: no two passes share a saddle" % _region.passes[p]["name"])
		seen[s] = true
	assert_true(_places.pass_saddles.has(_pass_index("Great St Bernard")), "Great St Bernard has a saddle")
	assert_true(_places.pass_saddles.has(_pass_index("Simplon")), "Simplon has a saddle")
	assert_true(_places.pass_saddles.has(_pass_index("Gotthard")), "Gotthard has a saddle")


func test_a_hospice_stands_on_each_saddle_of_a_high_pass() -> void:
	if not _ready_or_fail():
		return
	var expected := 0
	for p: int in _places.pass_saddles.keys():
		var ps: Dictionary = _region.passes[p]
		if int(ps["metres"]) < WorldPlaces.HOSPICE_MIN_METRES:
			continue
		expected += 1
		var saddle: Vector2i = _places.pass_saddles[p]
		assert_true(_has_hospice_at(saddle), "%s has its hospice on the saddle" % ps["name"])
	var hospices := 0
	for lm: Dictionary in _places.landmarks:
		if str(lm["kind"]) == "hospice":
			hospices += 1
	assert_eq(hospices, expected, "one hospice per pass of 2000 metres or more with a saddle")
	assert_eq(expected, 11, "eleven such passes in the region")


func test_generated_places_are_villages_and_hamlets_kept_apart() -> void:
	if not _ready_or_fail():
		return
	var generated: Array[Dictionary] = []
	for pl: Dictionary in _places.places:
		if bool(pl["generated"]):
			generated.append(pl)
			assert_true(int(pl["level"]) == 1 or int(pl["level"]) == 2,
				"generated place %s is a hamlet or a village" % str(pl["hex"]))
	assert_gte(generated.size(), 15, "the region gets generated villages")
	# Villages keep SPACING hexes from every village and every authored place; hamlets only take their own hex (spacing 1),
	# so they may stand beside a place and the countryside is not empty.
	for pl: Dictionary in _places.places:
		if not bool(pl["generated"]) or int(pl["level"]) != 2:
			continue
		var a: Vector2i = pl["hex"]
		for other: Dictionary in _places.places:
			var b: Vector2i = other["hex"]
			if b == a or int(other["level"]) < 2:
				continue
			assert_gte(WorldPlaces.hex_distance(a, b), WorldPlaces.SPACING,
				"village %s and %s are kept apart" % [str(a), str(b)])
	for pl: Dictionary in _places.places:
		if not bool(pl["generated"]):
			continue
		var a: Vector2i = pl["hex"]
		for other: Dictionary in _places.places:
			if other["hex"] == a:
				assert_true(other == pl, "%s: one place per hex" % str(a))


func test_generated_places_avoid_the_river_cities_and_landmarks() -> void:
	if not _ready_or_fail():
		return
	for pl: Dictionary in _places.places:
		if not bool(pl["generated"]):
			continue
		var hex: Vector2i = pl["hex"]
		for lm: Dictionary in _places.landmarks:
			assert_ne(lm["hex"], hex, "a generated place is not on a landmark")
		for city: String in _water.city_hex.keys():
			assert_ne(_water.city_hex[city], hex, "a generated place is not on %s" % city)


func test_every_port_has_a_quay_on_its_own_shore_or_lake_edge() -> void:
	if not _ready_or_fail():
		return
	var ports := 0
	for pl: Dictionary in _places.places:
		if not bool(pl["port"]):
			continue
		ports += 1
		var hex: Vector2i = pl["hex"]
		var quays := 0
		for e: Vector4i in _places.quay_edges.keys():
			if _places.quay_edges[e] != hex:
				continue
			quays += 1
			var pair := WorldGrid.edge_hexes(e)
			assert_true(pair.has(hex), "%s: the quay is on one of the port's edges" % pl["name"])
			assert_true(_water.shore_edge.has(e) or _water.lake_edge.has(e),
				"%s: the quay is on a shore or lake edge" % pl["name"])
		assert_eq(quays, 1, "%s has one quay" % pl["name"])
	assert_eq(ports, _places.quay_edges.size(), "every quay belongs to a port")
	assert_gte(ports, 10, "the region has a dozen ports or more")


func test_sea_ports_include_genoa_nice_and_pisa() -> void:
	if not _ready_or_fail():
		return
	for name: String in ["Genoa", "Nice", "Pisa"]:
		var pl := _places.find(name)
		assert_true(bool(pl["sea"]), "%s is a sea port" % name)


func test_site_score_prefers_the_plain_to_the_high_peaks() -> void:
	if not _ready_or_fail():
		return
	var peak_total := 0.0
	var peak_n := 0
	var plain_total := 0.0
	var plain_n := 0
	for hex: Vector2i in _places.site_score.keys():
		var level := _relief.level_at(hex)
		if level == 6:
			peak_total += _places.site_score[hex]
			peak_n += 1
		elif level == 2:
			plain_total += _places.site_score[hex]
			plain_n += 1
	assert_gt(peak_n, 0, "the region has high peaks")
	assert_gt(plain_n, 0, "the region has plains")
	assert_lt(peak_total / float(peak_n), plain_total / float(plain_n), "peaks score below plains on average")


func test_hex_distance_counts_steps_on_the_odd_row_grid() -> void:
	var hexes: Array[Vector2i] = [Vector2i(5, 4), Vector2i(5, 5), Vector2i(0, 0), Vector2i(7, 9)]
	for hex: Vector2i in hexes:
		assert_eq(WorldPlaces.hex_distance(hex, hex), 0, "a hex is zero steps from itself")
		for nb: Vector2i in _grid.neighbours(hex):
			assert_eq(WorldPlaces.hex_distance(hex, nb), 1, "a neighbour is one step away")
	assert_eq(WorldPlaces.hex_distance(Vector2i(0, 0), Vector2i(2, 0)), 2, "two steps along a row")
	assert_eq(WorldPlaces.hex_distance(Vector2i(0, 0), Vector2i(0, 2)), 2, "two rows down")


func test_the_build_is_repeatable() -> void:
	if not _ready_or_fail():
		return
	var again := WorldPlaces.build(_grid, _relief, _water, _cover, _region)
	assert_eq(again.summary(), _places.summary(), "the same inputs give the same counts")
	assert_eq(again.places.size(), _places.places.size(), "and the same number of places")
	for i: int in _places.places.size():
		assert_eq(again.places[i]["hex"], _places.places[i]["hex"], "place %d keeps its hex" % i)


func test_counts_are_the_first_build_counts() -> void:
	if not _ready_or_fail():
		return
	var s := _places.summary()
	assert_eq(s["places"], 183, "183 places (authored, castles, generated)")
	assert_eq(s["generated"], 124, "124 generated places: 24 villages and 100 hamlets")
	assert_eq(s["ports"], 31, "31 ports (the Riviera, the lagoon, the Adriatic coast)")
	assert_eq(s["capitals"], 1, "one capital")
	assert_eq(s["monasteries"], 1, "the Certosa")
	assert_eq(s["failures"], 0, "no failures")


func _pass_index(pass_name: String) -> int:
	for p: int in _region.passes.size():
		if _region.passes[p]["name"] == pass_name:
			return p
	return -1


func _has_landmark(lm_name: String) -> bool:
	for lm: Dictionary in _places.landmarks:
		if str(lm["name"]) == lm_name:
			return true
	return false


func _has_hospice_at(hex: Vector2i) -> bool:
	for lm: Dictionary in _places.landmarks:
		if str(lm["kind"]) == "hospice" and lm["hex"] == hex:
			return true
	return false
