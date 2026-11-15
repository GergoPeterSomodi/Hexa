## M1 helper: writes the fixture of tests/core/test_map_cells.gd: the trial scene's north Italy facts as MapData arrays,
## the improvement of one seed as MapState arrays, and the tile name the trial scene puts on every layer of every
## hex it draws today. The test builds the map and the state again and asks MapCells for the same names.
## Headless:  godot --headless --path godot -s res://tools/mapview/dump_trial_cells.gd -- --out=<absolute file> [--seed=N]
extends SceneTree

const LAYER_NAMES: Array[String] = [
	"grid", "ground", "shade", "light", "sea", "coast", "relief", "trees0", "trees1", "trees2", "trees3", "trees4",
	"trees5", "piece_ground", "piece_shadow", "piece_back", "piece_front", "addon_ground", "addon_shadow", "addon",
]

var _trial: TileTrial = null
var _out := ""
var _frames := 0


func _initialize() -> void:
	var seed_value := 1480
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--seed="):
			seed_value = int(arg.substr(7))
	_trial = TileTrial.new()
	_trial.seed_value = seed_value
	root.add_child(_trial)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	if _out == "":
		printerr("dump_trial_cells: needs --out=<file>")
		quit(1)
		return true
	var cols := 21
	var rows := 19
	var names := _names_by_cell()
	var land := []
	var height := []
	var relief := []
	var cover := []
	var depth := []
	var place_id := []
	var main_use := []
	var level := []
	var places := []
	var window := []
	var expected := {}
	for r: int in rows:
		for c: int in cols:
			var hex := Vector2i(c, r)
			var row: Dictionary = _trial._facts.get(hex, {})
			var is_land := not row.is_empty() and bool(row["land"])
			land.append(1 if is_land else 0)
			height.append(roundi(float(row.get("height_m", 0.0))) if is_land else 0)
			relief.append(int(row.get("level", 0)) if is_land else 0)
			var cover_text := str(row.get("cover", ""))
			cover.append(MapTiles.COVERS.find(cover_text) if is_land else 255)
			var depth_text := str(row.get("depth", ""))
			depth.append(1 if depth_text == "sea" else (2 if depth_text == "deep" else 0))
			var meta: Dictionary = _trial._meta.get(hex, {})
			var place: Variant = meta.get("place", null)
			if typeof(place) == TYPE_DICTIONARY:
				var p: Dictionary = place
				var mode: Variant = p.get("port_mode", null)
				var landmark: Variant = p.get("landmark", null)
				place_id.append(places.size())
				places.append({"name": str(p.get("name", "")), "hex": [c, r], "level": int(p.get("level", 1)),
					"port": bool(p.get("port", false)), "port_mode": "" if mode == null else str(mode),
					"landmark": "" if landmark == null else str(landmark)})
			else:
				place_id.append(-1)
			main_use.append(_trial.improve.family_at(hex) if is_land else 0)
			level.append(_trial.improve.level_at(hex) if is_land else 0)
			if not row.is_empty() and bool(row["window"]):
				window.append([c, r])
				var cells := {}
				for layer_name: String in LAYER_NAMES:
					var layer_cells: Dictionary = names[layer_name]
					var tile_name := str(layer_cells.get(hex, ""))
					if tile_name != "":
						cells[layer_name] = tile_name
				expected["%d,%d" % [c, r]] = cells
	var edges := _edges(cols, rows)
	var file := FileAccess.open(_out, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"seed": _trial.seed_value, "cols": cols, "rows": rows, "land": land, "height": height, "relief": relief,
		"cover": cover, "depth": depth, "place_id": place_id, "places": places, "main_use": main_use, "level": level,
		"river": edges["river"], "crest": edges["crest"], "road": edges["road"], "window": window,
		"expected": expected,
	}))
	file.close()
	print("dump_trial_cells: %d hexes drawn, %d places -> %s" % [window.size(), places.size(), _out])
	quit(0)
	return true


## {layer: {hex: tile name}} read back from the trial's TileMapLayers.
func _names_by_cell() -> Dictionary:
	var tiles := TilesetBuilder.build(TileTrial.TILES_DIR)
	var back: Dictionary = {}
	for tile_name: String in tiles.names:
		var at: Vector3i = tiles.names[tile_name]
		back[at] = tile_name
	var out: Dictionary = {}
	for layer_name: String in LAYER_NAMES:
		var layer: TileMapLayer = _trial.view.layer(layer_name)
		var cells := {}
		for hex: Vector2i in layer.get_used_cells():
			var atlas := layer.get_cell_atlas_coords(hex)
			cells[hex] = str(back.get(Vector3i(layer.get_cell_source_id(hex), atlas.x, atlas.y), "?"))
		out[layer_name] = cells
	return out


## The edge facts as lists: river [col, row, direction, class], crest [col, row, direction], road [col, row, direction, quality].
func _edges(cols: int, rows: int) -> Dictionary:
	var grid := HexGrid.new(28.0, 111.2, 45.0, 0.0, 0.0)
	var river := []
	var crest := []
	var road := []
	for hex: Vector2i in _trial._meta:
		var meta: Dictionary = _trial._meta[hex]
		var rivers: Array = meta.get("river_edges", [])
		for d: Variant in rivers:
			river.append([hex.x, hex.y, int(d), 1])
		var streams: Array = meta.get("stream_edges", [])
		for d: Variant in streams:
			river.append([hex.x, hex.y, int(d), 4])
	var facts := _trial._read(TileTrial.FACTS)
	var crests: Array = facts["crests"]
	for entry: Variant in crests:
		var e: Array = entry
		var a := Vector2i(int(e[0]), int(e[1]))
		crest.append([a.x, a.y, grid.direction_of(a, Vector2i(int(e[2]), int(e[3])))])
	var steps: Array = facts["road_edges"]
	for entry: Variant in steps:
		var e: Array = entry
		var a := Vector2i(int(e[0]), int(e[1]))
		road.append([a.x, a.y, grid.direction_of(a, Vector2i(int(e[2]), int(e[3]))), int(e[4])])
	return {"river": river, "crest": crest, "road": road, "cols": cols, "rows": rows}
