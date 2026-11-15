## Builds the fixed map of north Italy (docs/architecture/m1-build-spec.md sections 4 and 14): the geography and heights of
## data/worldmap/ through core/mapgen into one MapData file, data/maps/north_italy.tres.
## Run (from the repository root, GODOT set):
##   "$GODOT" --headless --path godot -s res://tools/build_map.gd              writes the file and prints its digest
##   "$GODOT" --headless --path godot -s res://tools/build_map.gd -- --check   builds and compares with the committed file (CI)
## Options: --out=<res:// or absolute path> writes elsewhere.
## The hexes of the odd rows' last column (c = 20) are not in the heights file: the map is a rectangle, so each repeats
## the hex beside it in its row (land, cover, height, depth; no rivers, roads or places).
extends SceneTree

const HEIGHTS := "res://data/worldmap/heights_alps_po.json"
const REGION := "res://data/worldmap/region_alps_po.json"
const SHORELINE := "res://data/worldmap/shoreline_alps_po.json"
const HEIGHT_GRID := "res://data/worldmap/height_grid_alps_po.json"
const OUT := "res://data/maps/north_italy.tres"
const MAP_ID := "north_italy"
const COLS := 21
const ROWS := 19
const DEPTH_OF := {"shelf": 0, "lagoon": 0, "sea": 1, "deep": 2}


func _initialize() -> void:
	var out_path := OUT
	var check := false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--check":
			check = true
		elif arg.begins_with("--out="):
			out_path = arg.substr(6)
	var built := build_files()
	if built.has("error"):
		printerr("build_map: ", built["error"])
		quit(1)
		return
	var map: MapData = built["map"]
	var problems := map.validate()
	if not problems.is_empty():
		printerr("build_map: the map does not validate: ", problems.slice(0, 10))
		quit(1)
		return
	if check:
		var committed := load(out_path) as MapData
		if committed == null or committed.digest() != map.digest():
			printerr("build_map: %s is not what the build gives (digest %s)" % [out_path, map.digest()])
			quit(1)
			return
		print("build_map: %s is current (digest %s)" % [out_path, map.digest()])
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var err := ResourceSaver.save(map, out_path)
	if err != OK:
		printerr("build_map: cannot save %s (error %d)" % [out_path, err])
		quit(1)
		return
	print("build_map: wrote %s, %d x %d hexes, digest %s" % [out_path, map.cols, map.rows, map.digest()])
	quit(0)


## Builds from the project's data files. Returns {map, relief, water, cover, places, roads, ...} or {error}.
static func build_files() -> Dictionary:
	return build(FileAccess.get_file_as_string(HEIGHTS), FileAccess.get_file_as_string(REGION),
		FileAccess.get_file_as_string(SHORELINE), FileAccess.get_file_as_string(HEIGHT_GRID))


## Builds from the texts of the four data files. The mapgen objects come back with the map so a test can compare.
static func build(heights_text: String, region_text: String, shoreline_text: String, grid_text: String) -> Dictionary:
	var heights := WorldHeights.from_text(heights_text)
	var region := WorldRegion.from_text(region_text)
	if heights == null or region == null:
		return {"error": "the heights or the region file does not read"}
	var shoreline_doc: Variant = JSON.parse_string(shoreline_text)
	var raster_doc: Variant = JSON.parse_string(grid_text)
	if typeof(shoreline_doc) != TYPE_DICTIONARY or typeof(raster_doc) != TYPE_DICTIONARY:
		return {"error": "the shoreline or the height grid file does not read"}
	var grid := HexGrid.new(region.hex_w_km, region.deg_km, region.ref_lat, region.lon_west, region.lat_north)
	var relief := WorldRelief.build(grid, heights, region)
	var water := WorldWater.build(grid, relief, heights, region)
	var cover := WorldCover.build(grid, relief, heights, water, region.cover_seed)
	var places := WorldPlaces.build(grid, relief, water, cover, region)
	var roads := WorldRoads.build(grid, relief, water, places, region)
	var map := MapData.new()
	map.id = MAP_ID
	map.hex_w_km = region.hex_w_km
	map.lon_west = region.lon_west
	map.lat_north = region.lat_north
	map.ref_lat = region.ref_lat
	map.deg_km = region.deg_km
	map.allocate(COLS, ROWS)
	map.shoreline = _shoreline_of(shoreline_doc)
	_fill_hexes(map, grid, relief, water, cover, heights)
	_fill_places(map, places)
	_fill_passes(map, region, relief, places)
	_fill_edges(map, relief, water, places, roads)
	_fill_rivers(map, water, region)
	_fill_height_grid(map, raster_doc)
	return {"map": map, "relief": relief, "water": water, "cover": cover, "places": places, "roads": roads,
		"heights": heights, "region": region, "grid": grid}


## The hex whose data a map hex takes: itself, or the hex beside it when the data has none (the odd rows' last column).
static func source_hex(relief: WorldRelief, hex: Vector2i) -> Vector2i:
	return hex if relief.levels.has(hex) else Vector2i(hex.x - 1, hex.y)


static func _shoreline_of(doc: Dictionary) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var lines: Array = doc["lines"]
	for item: Variant in lines:
		var line: Dictionary = item
		var pts := PackedVector2Array()
		var raw: Array = line["pts"]
		for p: Variant in raw:
			var xy: Array = p
			pts.append(Vector2(float(xy[0]), float(xy[1])))
		out.append(pts)
	return out


static func _fill_hexes(map: MapData, grid: HexGrid, relief: WorldRelief, water: WorldWater, cover: WorldCover,
		heights: WorldHeights) -> void:
	for i: int in map.hex_count():
		var hex := map.hex_of(i)
		var src := source_hex(relief, hex)
		var level := relief.level_at(src)
		if level == ReliefLevels.SEA:
			map.depth[i] = int(DEPTH_OF.get(str(water.sea_band.get(src, "sea")), 1))
			continue
		map.land[i] = 1
		map.relief[i] = level
		map.cover[i] = cover.cover_at(src)
		map.height_m[i] = roundi(float(heights.height_m.get(src, 0.0)))
		map.depth[i] = 0
		var centre := grid.centre_km(hex)
		map.climate[i] = MapClimate.winter_of(grid.lonlat_of(centre).y, float(heights.height_m.get(src, 0.0)),
			MapClimate.km_to_lines(centre, map.shoreline))


static func _fill_places(map: MapData, places: WorldPlaces) -> void:
	var landmark_at: Dictionary[Vector2i, String] = {}
	for lm: Dictionary in places.landmarks:
		landmark_at[lm["hex"]] = str(lm["kind"])
	for pl: Dictionary in places.places:
		var hex: Vector2i = pl["hex"]
		var sea_port: bool = bool(pl["port"]) and bool(pl["sea"])
		var level := int(pl["level"])
		map.places.append({
			"name": str(pl["name"]), "hex": hex, "level": level, "port": sea_port,
			"port_mode": ("carved" if level >= 4 else "seaside") if sea_port else "",
			"capital": bool(pl["capital"]), "landmark": str(landmark_at.get(hex, "")), "castle": int(pl["castle"]),
			"lake_port": bool(pl["port"]) and not bool(pl["sea"]), "river_city": bool(pl["river_city"]),
		})
		map.place_id[map.index_of(hex)] = map.places.size() - 1
	for lm: Dictionary in places.landmarks:  # a landmark on a hex without a place stands as a place of level 0
		var hex: Vector2i = lm["hex"]
		if map.place_id[map.index_of(hex)] >= 0:
			continue
		map.places.append({"name": str(lm["name"]), "hex": hex, "level": 0, "port": false, "port_mode": "",
			"capital": false, "landmark": str(lm["kind"]), "castle": 0, "lake_port": false, "river_city": false})
		map.place_id[map.index_of(hex)] = map.places.size() - 1


static func _fill_passes(map: MapData, region: WorldRegion, relief: WorldRelief, places: WorldPlaces) -> void:
	for p: int in region.passes.size():
		var ps: Dictionary = region.passes[p]
		var hex: Vector2i = places.pass_saddles.get(p, relief.pass_hex.get(p, Vector2i(-1, -1)))
		map.passes.append({"name": str(ps["name"]), "hex": hex, "metres": int(ps["metres"])})
		var i := map.index_of(hex)
		if i >= 0 and map.pass_id[i] < 0:
			map.pass_id[i] = p


## The slot of the edge a Vector4i key names (smaller hex first), or -1.
static func _edge_of(map: MapData, key: Vector4i) -> int:
	var a := Vector2i(key.x, key.y)
	var b := Vector2i(key.z, key.w)
	if not map.has(a) or not map.has(b):
		return -1
	return map.edge_index(a, map.grid().direction_of(a, b))


static func _fill_edges(map: MapData, relief: WorldRelief, water: WorldWater, places: WorldPlaces,
		roads: WorldRoads) -> void:
	for key: Vector4i in water.stream_edge:
		var e := _edge_of(map, key)
		if e >= 0:
			map.river[e] = 4
	for key: Vector4i in water.river_edge:
		var e := _edge_of(map, key)
		if e >= 0:
			map.river[e] = clampi(int(water.rivers[water.river_edge[key]]["class"]), 1, 3)
	for key: Vector4i in relief.crest_edges:
		var e := _edge_of(map, key)
		if e >= 0:
			map.crest[e] = 1
	for key: Vector4i in places.pass_edges:
		var e := _edge_of(map, key)
		if e >= 0:
			map.pass_edge[e] = 1
	for key: Vector4i in roads.quality:
		var e := _edge_of(map, key)
		if e >= 0:
			map.road[e] = roads.quality[key]
			map.crossing[e] = maxi(0, WorldRoads.CROSSING_KINDS.find(roads.crossing_of(key)))


## Each river with its drawn course and the corners where it ends without reaching the sea along its edges: where it meets
## a lake, leaves the map by the window's edge, or runs through a river city's hex (no edge there). MapData.validate reads
## these as "open_ends".
static func _fill_rivers(map: MapData, water: WorldWater, region: WorldRegion) -> void:
	var leaves: Dictionary[String, bool] = {}
	for rv: Dictionary in region.rivers:
		leaves[str(rv["name"])] = str(rv["leaves"]) != ""
	for i: int in water.rivers.size():
		var river: Dictionary = water.rivers[i]
		var curve := WorldWater.smooth_line(water.river_points_km(i), water.river_pins(i), WorldWater.DRAW_ROUNDS)
		var open_ends := PackedVector2Array()
		for a: Dictionary in water.join_anchors:
			if str(a["host_kind"]) == "lake" and int(a["tributary"]) == i:
				open_ends.append(a["km"])
		var chain: Array[Vector3i] = river["corners"]
		var steps: Array[Vector4i] = river["steps"]
		if bool(leaves.get(str(river["name"]), false)):
			open_ends.append(water.corner_pos(chain[chain.size() - 1]))
		for j: int in steps.size():
			if steps[j] == WorldWater.NO_EDGE:
				open_ends.append(water.corner_pos(chain[j]))
				open_ends.append(water.corner_pos(chain[j + 1]))
		map.rivers.append({"name": str(river["name"]), "class": int(river["class"]), "corners": curve,
			"open_ends": open_ends})


static func _fill_height_grid(map: MapData, doc: Dictionary) -> void:
	var g: Dictionary = doc["grid"]
	map.height_grid_size = Vector2i(int(g["width"]), int(g["height"]))
	var origin: Array = g["origin_km"]
	map.height_grid_origin_km = Vector2(float(origin[0]), float(origin[1]))
	var values: Array = doc["values"]
	var out := PackedInt32Array()
	out.resize(values.size())
	for i: int in values.size():
		out[i] = int(values[i])
	map.height_grid = out
