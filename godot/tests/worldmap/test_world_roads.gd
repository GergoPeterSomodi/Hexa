## The roads of the map prototype region (core/worldmap/world_roads.gd): every town and every fixed place of level 2 or more is on
## the network, every link routes, every pass with a saddle carries a road (the three Alpine routes over two sides), no road
## lies on a crest except over a pass, every road over water has a crossing that fits its edge (none on the six edges of a
## river city), the bridges over the Ticino and the Po at Pavia are there, and the qualities and crossing kinds are in their
## ranges. The counts pin what the first build showed.
extends GutTest

const HEIGHTS := "res://data/worldmap/heights_alps_po.json"
const REGION := "res://data/worldmap/region_alps_po.json"

var _grid: WorldGrid = null
var _region: WorldRegion = null
var _relief: WorldRelief = null
var _water: WorldWater = null
var _cover: WorldCover = null
var _places: WorldPlaces = null
var _roads: WorldRoads = null


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
	_roads = WorldRoads.build(_grid, _relief, _water, _places, _region)


func _ready_or_fail() -> bool:
	if _roads == null:
		fail_test("the heights and the region must read")
		return false
	return true


func _pass_index(pass_name: String) -> int:
	for p: int in _region.passes.size():
		if _region.passes[p]["name"] == pass_name:
			return p
	return -1


func test_every_town_and_city_is_on_the_network() -> void:
	if not _ready_or_fail():
		return
	for pl: Dictionary in _places.places:
		var hex: Vector2i = pl["hex"]
		if int(pl["level"]) >= 3:
			assert_true(_roads.network.has(hex), "%s (level %d) is on the network" % [pl["name"], pl["level"]])
		elif int(pl["level"]) == 2 and not bool(pl["generated"]):
			assert_true(_roads.network.has(hex), "%s (fixed village) is on the network" % pl["name"])


func test_every_link_routes_and_the_capital_reaches_its_cities() -> void:
	if not _ready_or_fail():
		return
	assert_eq(_roads.link_failures.size(), 0, "every link finds a route")
	var by_kind: Dictionary = _roads.summary()["links_by_kind"]
	assert_gte(int(by_kind.get("capital", 0)), 5, "Milan links to the cities within reach")
	assert_gte(int(by_kind.get("coast", 0)), 2, "the Riviera ports are chained")
	assert_gte(int(by_kind.get("pass", 0)), 20, "the passes are routed on both sides")


func test_every_pass_with_a_saddle_carries_a_road() -> void:
	if not _ready_or_fail():
		return
	for p: int in _places.pass_saddles.keys():
		assert_gte(_roads.road_edges_of_pass(p), 1, "%s carries a road" % _region.passes[p]["name"])


func test_the_three_alpine_routes_cross_their_passes_on_both_sides() -> void:
	if not _ready_or_fail():
		return
	for pass_name: String in ["Great St Bernard", "Simplon", "Gotthard"]:
		var p := _pass_index(pass_name)
		assert_gte(p, 0, "%s is in the region" % pass_name)
		assert_true(_places.pass_saddles.has(p), "%s has a saddle" % pass_name)
		assert_gte(_roads.road_edges_of_pass(p), 2, "%s: a road over the pass on both sides" % pass_name)
		var saddle: Vector2i = _places.pass_saddles[p]
		assert_true(_roads.network.has(saddle), "%s: its saddle is on the network" % pass_name)


func test_no_road_lies_on_a_crest_except_over_a_pass() -> void:
	if not _ready_or_fail():
		return
	assert_eq(_roads.crest_violations().size(), 0, "no road on a crest outside a pass")
	for e: Vector4i in _roads.quality.keys():
		if _relief.crest_edges.has(e):
			assert_true(_places.pass_edges.has(e), "%s is a pass edge" % str(e))


func test_every_road_over_water_has_a_crossing_that_fits_its_edge() -> void:
	if not _ready_or_fail():
		return
	assert_eq(_roads.crossing_violations().size(), 0, "no crossing on a dry edge, no wet road without one")
	for e: Vector4i in _roads.quality.keys():
		if _water.river_edge.has(e) and not _is_city_edge(e):
			assert_ne(_roads.crossing_of(e), "none", "%s: a river edge with a road has a crossing" % str(e))


func test_river_cities_are_crossed_inside_the_city() -> void:
	if not _ready_or_fail():
		return
	for city: String in _water.city_hex.keys():
		var hex: Vector2i = _water.city_hex[city]
		assert_true(_roads.network.has(hex), "%s is on the network" % city)
		for d: int in 6:
			var e := WorldGrid.edge_key(hex, _grid.neighbour(hex, d))
			assert_ne(_roads.crossing_of(e), "bridge_wood", "%s: no wooden bridge on its edges" % city)
			assert_ne(_roads.crossing_of(e), "bridge_stone", "%s: no stone bridge on its edges" % city)
			assert_ne(_roads.crossing_of(e), "ford", "%s: no ford on its edges" % city)
			assert_ne(_roads.crossing_of(e), "ferry", "%s: no ferry on its edges" % city)


func test_pavia_is_bridged_over_the_ticino_and_the_po() -> void:
	if not _ready_or_fail():
		return
	var pavia: Vector2i = _places.find("Pavia")["hex"]
	var ticino := ""
	var po := ""
	for e: Vector4i in _water.river_edge.keys():
		var river: String = _water.rivers[int(_water.river_edge[e])]["name"]
		var pair := WorldGrid.edge_hexes(e)
		# The Ticino meets the Po two hexes west of Pavia (the Po's mouths moved in step 5b), so its reach is two hexes.
		var reach := 2 if river == "Ticino" else 1
		var near := WorldPlaces.hex_distance(pavia, pair[0]) <= reach or WorldPlaces.hex_distance(pavia, pair[1]) <= reach
		if not near or _roads.quality_of(e) == 0:
			continue
		if river == "Ticino":
			ticino = _roads.crossing_of(e)
		elif river == "Po":
			po = _roads.crossing_of(e)
	assert_true(ticino.begins_with("bridge"), "a road bridges the Ticino within two hexes of Pavia (%s)" % ticino)
	assert_true(po.begins_with("bridge"), "a road bridges the Po beside Pavia (%s)" % po)


func test_highways_run_from_milan_and_tracks_climb_the_passes() -> void:
	if not _ready_or_fail():
		return
	var highways := 0
	for e: Vector4i in _roads.quality.keys():
		if _roads.quality_of(e) == 3:
			highways += 1
	assert_gte(highways, 20, "the trunks from Milan are highways")
	for e: Vector4i in _places.pass_edges.keys():
		if _roads.quality.has(e):
			assert_eq(_roads.quality_of(e), 1, "a pass edge is a track in 1480")


func test_qualities_and_crossings_are_in_their_ranges() -> void:
	if not _ready_or_fail():
		return
	for e: Vector4i in _roads.quality.keys():
		var q := _roads.quality_of(e)
		assert_true(q >= 1 and q <= 3, "%s: quality 1 to 3" % str(e))
		var pair := WorldGrid.edge_hexes(e)
		if _relief.level_at(pair[0]) >= 5 or _relief.level_at(pair[1]) >= 5:
			assert_lte(q, 2, "%s: a mountain edge is at most a road" % str(e))
		assert_true(WorldRoads.CROSSING_KINDS.has(_roads.crossing_of(e)), "%s: a known crossing" % str(e))
	var kinds: Dictionary = _roads.summary()["crossings"]
	assert_gte(int(kinds.get("ford", 0)), 1, "fords")
	assert_gte(int(kinds.get("bridge_wood", 0)), 1, "wooden bridges")
	assert_gte(int(kinds.get("bridge_stone", 0)), 1, "stone bridges")
	assert_gte(int(kinds.get("ferry", 0)), 1, "ferries")


func test_every_quay_has_a_port_at_its_hex() -> void:
	if not _ready_or_fail():
		return
	for e: Vector4i in _places.quay_edges.keys():
		var hex: Vector2i = _places.quay_edges[e]
		assert_true(_places.place_at(hex).has("port") and bool(_places.place_at(hex)["port"]),
			"the quay at %s belongs to a port" % str(hex))


func test_the_build_is_repeatable_and_the_counts_are_the_first_build_counts() -> void:
	if not _ready_or_fail():
		return
	var again := WorldRoads.build(_grid, _relief, _water, _places, _region)
	assert_eq(again.summary(), _roads.summary(), "the same inputs give the same network")
	var s := _roads.summary()
	assert_eq(int(s["edges"]), 233, "233 road edges")
	assert_eq(int(s["links"]), 158, "158 links")
	assert_eq(int(s["link_failures"]), 0, "no link failures")
	assert_eq(int(s["network_hexes"]), 199, "199 hexes on a road")
	var q: Array = s["qualities"]
	assert_eq(int(q[1]), 98, "98 track edges (spurs to villages and hamlets, passes without a hospice)")
	assert_eq(int(q[2]), 88, "88 road edges (joins between towns, the coast, the passes with a hospice)")
	assert_eq(int(q[3]), 47, "47 highway edges (from Milan and between the cities)")


func test_main_roads_join_towns_and_cross_hospice_passes() -> void:
	if not _ready_or_fail():
		return
	for ln: Dictionary in _roads.links:
		if str(ln["kind"]) == "join":
			var a: Vector2i = ln["from"]
			var b: Vector2i = ln["to"]
			if _places.level_at(a) >= 3 and _places.level_at(b) >= 3:
				for i: int in (ln["path"] as Array).size() - 1:
					var e := WorldGrid.edge_key((ln["path"] as Array)[i], (ln["path"] as Array)[i + 1])
					if not _places.pass_edges.has(e):
						assert_gte(_roads.quality_of(e), 2, "a join between towns of level 3+ is a road")
		if str(ln["kind"]) == "pass":
			var p := _pass_index(str(ln["via"]))
			if p < 0 or int(_region.passes[p]["metres"]) < WorldPlaces.HOSPICE_MIN_METRES:
				continue
			for i: int in (ln["path"] as Array).size() - 1:
				var e2 := WorldGrid.edge_key((ln["path"] as Array)[i], (ln["path"] as Array)[i + 1])
				if not _places.pass_edges.has(e2):
					assert_gte(_roads.quality_of(e2), 2, "%s: the link to a hospice pass is a road" % ln["via"])
	for p: int in _places.pass_saddles.keys():
		assert_gte(_roads.road_edges_of_pass(p), 1, "%s: a road over the pass" % _region.passes[p]["name"])
	assert_gte(_roads.road_edges_of_pass(_pass_index("Furka")), 2, "Furka: a road on both sides")
	assert_gte(_roads.road_edges_of_pass(_pass_index("Bernina")), 2, "Bernina: a road on both sides")


func _is_city_edge(e: Vector4i) -> bool:
	for city: String in _water.city_hex.keys():
		var hex: Vector2i = _water.city_hex[city]
		for d: int in 6:
			if WorldGrid.edge_key(hex, _grid.neighbour(hex, d)) == e:
				return true
	return false
