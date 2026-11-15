## M1 TRIAL (docs/design/map/m1_trial/notes.md): the north Italy view drawn with the tile stack (TileMapView), for
## the side-by-side with today's whole-map bake. It reads the trial's facts file (tools/worldmap/tileset_bake/
## trial_map.py; the build reads MapData instead), asks the improvement rules for the pieces exactly as today's scene
## does (same hex table, same seed), and lets core/views/map_tiles.gd name every tile.
## Drag or WASD moves, the wheel zooms, G shows the grid.
class_name TileTrial
extends Node2D

const TILES_DIR := "res://assets/tiles/trial/"
const FACTS := "res://assets/tiles/trial/trial_map.json"
const META := "res://assets/worldmap/north_italy/meta.json"
const SEA_COLOUR := Color("#3f7fae")
## Today's picture starts at km (70, 214) of the region and has 103.923 px a hex; the tile grid starts at km 0 with
## 104 px a hex. today_to_map() turns a pixel of today's picture into the tile map's.
const TODAY_ORIGIN := Vector2(259.81, 675.13)
const TODAY_HEX_W := 103.923

var seed_value := 1480
var view: TileMapView = null
var improve: WorldImprove = null
## Every tile name the view asked for (the trial bake reads this list to know what to draw).
var asked: Dictionary[String, bool] = {}
var stats: Dictionary = {}

var _facts: Dictionary[Vector2i, Dictionary] = {}
var _meta: Dictionary[Vector2i, Dictionary] = {}
var _road_dirs: Dictionary[Vector2i, int] = {}
var _crest: Dictionary[Vector2i, bool] = {}
var _camera: Camera2D = null
var _dragging := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(SEA_COLOUR)
	_camera = Camera2D.new()
	add_child(_camera)
	var tiles := TilesetBuilder.build(TILES_DIR)
	view = TileMapView.new()
	view.name = "MapView"
	add_child(view)
	if tiles.tile_set == null:
		push_warning("tile trial: %s (bake it with tools/worldmap/tileset_bake/bake_trial.py)" % tiles.error)
		tiles.tile_set = TileSet.new()
	view.setup(tiles)
	view.set_layer_visible("grid", true)
	if _load():
		_fill()
	frame_today(Vector2(640.0, 360.0), 1.0)


static func today_to_map(today_px: Vector2) -> Vector2:
	return Vector2((today_px.x + TODAY_ORIGIN.x) * float(MapTiles.CELL.x) / TODAY_HEX_W, today_px.y + TODAY_ORIGIN.y)


## The view that today's scene shows with frame_at(today_px, zoom).
func frame_today(today_px: Vector2, zoom: float) -> void:
	_camera.position = today_to_map(today_px)
	_camera.zoom = Vector2(zoom, zoom)


func _load() -> bool:
	var facts := _read(FACTS)
	var meta := _read(META)
	if facts.is_empty() or meta.is_empty():
		push_warning("tile trial: the facts file or the baked hex table is missing")
		return false
	var rows: Array = facts["hexes"]
	for entry: Variant in rows:
		var row: Dictionary = entry
		_facts[Vector2i(int(row["c"]), int(row["r"]))] = row
	var table: Array = meta["hexes"]
	for entry: Variant in table:
		var row: Dictionary = entry
		_meta[Vector2i(int(row["c"]), int(row["r"]))] = row
	improve = WorldImprove.build(load("res://data/maps/north_italy.tres") as MapData, seed_value, null, _meta)
	var crests: Array = facts["crests"]
	for entry: Variant in crests:
		var e: Array = entry
		_crest[Vector2i(int(e[0]), int(e[1]))] = true
		_crest[Vector2i(int(e[2]), int(e[3]))] = true
	var lines: Array[Dictionary] = []
	var steps: Array[Array] = []
	var road_edges: Array = facts["road_edges"]
	for entry: Variant in road_edges:
		var e: Array = entry
		var a := Vector2i(int(e[0]), int(e[1]))
		var b := Vector2i(int(e[2]), int(e[3]))
		steps.append([a, b, int(e[4])])
		if int(e[4]) < 2:
			continue  # a track (quality 1) is thin: the trees do not make way for it
		for d: int in 6:
			if ImproveRules.neighbour(a, d) == b:
				_road_dirs[a] = int(_road_dirs.get(a, 0)) | (1 << d)
				_road_dirs[b] = int(_road_dirs.get(b, 0)) | (1 << ((d + 3) % 6))
	var scale := Vector2(float(MapTiles.CELL.x) / float(facts["hex_w_km"]), MapTiles.ROW / float(facts["hex_h_km"]))
	var rivers: Array = facts["rivers"]
	for n: int in rivers.size():
		var river: Dictionary = rivers[n]
		var pts := PackedVector2Array()
		var raw: Array = river["pts_km"]
		for entry: Variant in raw:
			var p: Array = entry
			pts.append(Vector2(float(p[0]), float(p[1])) * scale)
		lines.append(EdgeLines.river(pts, int(river["class"]), float(n) * 1.7))
	var streams: Array = facts["streams"]
	for entry: Variant in streams:
		var e: Array = entry
		var a := Vector2i(int(e[0]), int(e[1]))
		var b := Vector2i(int(e[2]), int(e[3]))
		var mid := (MapTiles.cell_centre(a) + MapTiles.cell_centre(b)) / 2.0
		var across := MapTiles.cell_centre(b) - MapTiles.cell_centre(a)
		# The edge runs square to the line between the two middles on the untilted ground: 30 px either way.
		var along := Vector2(-across.y / 0.85, across.x).normalized() * 30.0
		along.y *= 0.85
		lines.append(EdgeLines.stream(mid - along, mid + along))
	lines.append_array(EdgeLines.roads(steps, MapTiles.cell_centre))
	view.set_lines(lines)
	stats["lines"] = lines.size()
	return true


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = parsed
	return out


func _put(layer_name: String, hex: Vector2i, tile_name: String) -> void:
	if tile_name != "":
		asked[tile_name] = true
	view.set_tile(layer_name, hex, tile_name)


func _is_land(hex: Vector2i) -> bool:
	return _facts.has(hex) and bool(_facts[hex]["land"])


func _is_sea(hex: Vector2i) -> bool:
	return _facts.has(hex) and not bool(_facts[hex]["land"])


func _fill() -> void:
	var pieces := 0
	for hex: Vector2i in _facts:
		var row := _facts[hex]
		if not bool(row["window"]):
			continue
		_put("grid", hex, "grid/line")
		var sea_near: Array[bool] = []
		var heights := PackedFloat32Array()
		var covers: Array[String] = []
		var height := float(row["height_m"])
		for d: int in 6:
			var n := ImproveRules.neighbour(hex, d)
			sea_near.append(_is_sea(n))
			heights.append(float(_facts[n]["height_m"]) if _is_land(n) else height)
			covers.append(str(_facts[n]["cover"]) if _is_land(n) else "")
		if not bool(row["land"]):
			var beside := false
			for d: int in 6:
				beside = beside or _is_land(ImproveRules.neighbour(hex, d))
			_put("sea", hex, MapTiles.sea(str(row["depth"]), beside, hex))
			continue
		var cover := str(row["cover"])
		var level := int(row["level"])
		var meta: Dictionary = _meta.get(hex, {})
		var piece: Dictionary = improve.piece_at(hex) if improve != null else {}
		var built := not piece.is_empty()
		var mask := MapTiles.coast_mask(sea_near)
		var place: Variant = meta.get("place", null)
		var port := typeof(place) == TYPE_DICTIONARY and bool((place as Dictionary).get("port", false))
		var carved := built and str(piece["addon_mode"]) == "carved" and MapTiles.bay_fits(mask)
		_put("ground", hex, MapTiles.ground(cover, height, hex))
		var tone := MapTiles.slope_tone(height, heights)
		_put("shade", hex, "shade/%d" % tone.x if tone.x > 0 else "")
		_put("light", hex, "light/%d" % tone.y if tone.y > 0 else "")
		_put("coast", hex, MapTiles.coast(mask, hex, level, port, carved))
		var road_mask := int(_road_dirs.get(hex, 0))
		var river_mask := 0
		for key: String in ["river_edges", "stream_edges"]:
			var edges: Variant = meta.get(key, null)
			if typeof(edges) == TYPE_ARRAY:
				for d: Variant in (edges as Array):
					river_mask |= 1 << int(d)
		var relief := MapTiles.relief(level, _crest.has(hex), built, road_mask != 0, hex)
		_put("relief", hex, relief)
		for d: int in 6:
			_put("trees%d" % d, hex, MapTiles.trees(d, cover, height, covers[d], (river_mask >> d) & 1 == 1,
				(road_mask >> d) & 1 == 1, built, relief != "", hex))
		if not built:
			continue
		pieces += 1
		var family := str(piece["family"])
		var extra := str(piece["extra"])
		if family == "harbour" or family == "salt":
			extra = MapTiles.sea_side(mask)
		for part: String in ["ground", "shadow", "back", "front"]:
			_put("piece_" + part, hex, MapTiles.piece(family, int(piece["level"]), int(piece["variant"]), bool(piece["mirror"]),
				extra, part))
		if int(piece["addon"]) > 0 and mask != 0:
			var side := "carved" if carved else MapTiles.sea_side(mask)
			for part: String in ["ground", "shadow", "front"]:  # a harbour's standing things are one tile
				var layer_name := "addon" if part == "front" else "addon_" + part
				_put(layer_name, hex, MapTiles.piece("harbour_addon", int(piece["addon"]), int(piece["variant"]),
					bool(piece["mirror"]), side, part))
	stats["pieces"] = pieces
	stats["cells"] = view.cell_count()
	stats["missing"] = view.missing_names().size()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_camera.zoom *= 1.15
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_camera.zoom /= 1.15
		else:
			_dragging = button.pressed
	elif event is InputEventMouseMotion and _dragging:
		_camera.position -= (event as InputEventMouseMotion).relative / _camera.zoom.x
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_G:
		view.set_layer_visible("grid", not view.layer("grid").visible)
