## The north Italy normal map (docs/design/map/pieces/GUIDE.md, 06-growing-map.md): the baked ground of the style frame
## with an improvement piece on the hexes the wave function collapse chose (core/worldmap/world_improve.gd).
##
## Reads res://assets/worldmap/north_italy/ (tools/worldmap/godot_bake): meta.json (the hex table), ground_ and
## overlay_<season>.png, land_mask.png, wild.json with its atlases, pieces/index.json with its atlases, and
## placements.json (the pieces cut to their own shore, for the ports and the coast hexes it has).
##
## Draw order, the compositor's (tools/worldmap/pieces_in_map/compose.py): the ground; the pieces' ground detail
## (clipped at the sea, but for coast pieces, whose quays lie on the water); rivers and roads; one shadow pass; every
## standing thing, wild or built, back to front by the y of its foot. A wild tree whose foot lies in a piece's
## footprint is left out, and so are a rounded hill in a hex that takes a piece and a peak in front of a footprint.
##
## Keys: 1 to 4 the season, R a new seed, V the unnamed villages on or off, G the hex grid, F the whole map, H the panel;
## drag or WASD to move, the wheel to zoom.
## Shell only: what stands where is the core's answer; this file looks pictures up and puts them down.
class_name NorthItalyMap
extends Node2D

const DEFAULT_DIR := "res://assets/worldmap/north_italy/"
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const START_SEED := 1480
const ZOOM_MIN := 0.3
const ZOOM_MAX := 4.0
const PAN_SPEED := 700.0  # map px a second at zoom 1, with the keys
## Where a coast family expects its shore: px out from the middle of its canvas (the modules' COAST["y0"]).
const COAST_Y0 := {"harbour": 13.0, "harbour_addon": 13.0, "salt": 15.0}
## The hex of the pieces: radius 60 px, squashed to 85% (the kit's in_hex).
const HEX_INNER := 51.96
const TILT := 0.85
## A peak is left out when a footprint lies under its foot or this many px behind it (compose.py, relief rule K).
const RANGE_FRONT: Array[float] = [0.0, 10.0, 20.0, 30.0]
const SEA_COLOUR := Color("#3f7fae")

## The folder of the bake (with the last slash). A tool may point it at another bake before the scene enters the tree.
var art_dir: String = DEFAULT_DIR
## False leaves out the places without a name (the generated hamlets and villages of the hex table): only the named
## towns are fixed, and the improvement step has their hexes to itself. The owner's "less crowded" switch (key V).
var with_villages: bool = true
var seed_value: int = START_SEED
var season: String = "summer"
var improve: WorldImprove = null
## Counts of the last build, for the panel and the tools.
var stats: Dictionary = {}

var _loaded := false
var _error := ""
var _map_size := Vector2(1280.0, 720.0)
var _hex_rows: Array = []
var _row_of: Dictionary[Vector2i, Dictionary] = {}
var _wild: Array = []
var _pieces: Dictionary = {}
var _exact: Dictionary[String, Dictionary] = {}  # "c,r,family" -> the placement cut to that hex's own shore
var _textures: Dictionary[String, Texture2D] = {}
var _images: Dictionary[String, Image] = {}
var _land: Image = null
var _grid: HexGridLayer = null
var _dragging := false
var _wfc_ms := 0.0
var _fps_shown := 0.0
var _fps_clock := 0.0

@onready var _ground: Sprite2D = $Ground
@onready var _piece_ground: WorldSpriteLayer = $PieceGround
@onready var _coast_ground: WorldSpriteLayer = $CoastGround
@onready var _overlay: Sprite2D = $Overlay
@onready var _shadows: WorldSpriteLayer = $ShadowGroup/Shadows
@onready var _standing: WorldSpriteLayer = $Standing
@onready var _camera: Camera2D = $Camera
@onready var _hud: CanvasLayer = $Hud
@onready var _title: Label = $Hud/Margin/Panel/Box/Title
@onready var _stats_label: Label = $Hud/Margin/Panel/Box/Stats
@onready var _fps_label: Label = $Hud/Margin/Panel/Box/Fps


func _ready() -> void:
	RenderingServer.set_default_clear_color(SEA_COLOUR)
	_loaded = _load_data()
	if not _loaded:
		_title.text = "North Italy map: the baked art is missing"
		_stats_label.text = _error + "\nBake it with tools/worldmap/godot_bake/bake.py, then import the project."
		return
	_add_grid()
	_run_wfc()
	_rebuild()
	frame_all()


## The hex grid layer, just above the rivers and roads (the Overlay) and under the shadows and standing things.
func _add_grid() -> void:
	_grid = HexGridLayer.new()
	_grid.name = "HexGrid"
	add_child(_grid)
	move_child(_grid, _overlay.get_index() + 1)
	var centres: Array[Vector2] = []
	for row: Variant in _hex_rows:
		var at := _vec(_dict(row).get("centre_px", null), Vector2(-1.0, -1.0))
		if at.x >= 0.0:
			centres.append(at)
	_grid.set_hexes(centres, TILT)


func set_grid_visible(value: bool) -> void:
	if _grid != null:
		_grid.visible = value


# ----- what the tools and the keys call -----------------------------------------------------------------------------


func is_loaded() -> bool:
	return _loaded


func set_season(value: String) -> void:
	if not _loaded or not SEASONS.has(value) or value == season:
		return
	season = value
	_rebuild()


## The unnamed villages of the hex table on or off (see with_villages); the improvement is chosen again.
func set_villages(value: bool) -> void:
	with_villages = value
	if _loaded:
		_run_wfc()
		_rebuild()


## A new seed: the improvement is chosen again and the map drawn again.
func reroll(value: int) -> void:
	if not _loaded:
		return
	seed_value = value
	_run_wfc()
	_rebuild()


## The whole map in the window.
func frame_all() -> void:
	var view := get_viewport_rect().size
	var zoom := minf(view.x / _map_size.x, view.y / _map_size.y)
	frame_at(_map_size / 2.0, zoom)


## A view centred on a map pixel at a zoom (1 = the baked size: hex radius 60 px).
func frame_at(centre: Vector2, zoom: float) -> void:
	var z := clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	_camera.zoom = Vector2(z, z)
	_camera.position = centre


func set_hud_visible(value: bool) -> void:
	_hud.visible = value


func map_size() -> Vector2:
	return _map_size


## The map pixel of a hex centre (Vector2.ZERO when the hex is not in the table).
func centre_of(hex: Vector2i) -> Vector2:
	if not _row_of.has(hex):
		return Vector2.ZERO
	return _vec(_row_of[hex].get("centre_px", null))


# ----- input --------------------------------------------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_about(button.position, 1.15)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_about(button.position, 1.0 / 1.15)
		elif button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_dragging = button.pressed
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_camera.position -= motion.relative / _camera.zoom.x
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				set_season(SEASONS[int(key.keycode) - int(KEY_1)])
			KEY_R:
				reroll(seed_value + 1)
			KEY_V:
				set_villages(not with_villages)
			KEY_F:
				frame_all()
			KEY_H:
				set_hud_visible(not _hud.visible)
			KEY_G:
				set_grid_visible(_grid != null and not _grid.visible)


func _process(delta: float) -> void:
	var step := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		step.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		step.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		step.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		step.y += 1.0
	if step != Vector2.ZERO:
		_camera.position += step * PAN_SPEED * delta / _camera.zoom.x
	_fps_clock += delta
	if _fps_clock >= 0.5:
		_fps_clock = 0.0
		_fps_shown = Engine.get_frames_per_second()
		_fps_label.text = "%d frames a second" % int(_fps_shown)


## Zooms so that the map point under the pointer stays under it.
func _zoom_about(screen: Vector2, factor: float) -> void:
	var view := get_viewport_rect().size
	var before := _camera.position + (screen - view / 2.0) / _camera.zoom.x
	var z := clampf(_camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	_camera.zoom = Vector2(z, z)
	_camera.position = before - (screen - view / 2.0) / z


# ----- loading ------------------------------------------------------------------------------------------------------


func _load_data() -> bool:
	var meta := _read_json(art_dir + "meta.json")
	var wild := _read_json(art_dir + "wild.json")
	var index := _read_json(art_dir + "pieces/index.json")
	if meta.is_empty() or wild.is_empty() or index.is_empty():
		return false
	_map_size = _vec(meta.get("size_px", null), _map_size)
	var hexes: Variant = meta.get("hexes", null)
	if typeof(hexes) != TYPE_ARRAY:
		_error = "meta.json has no hex table"
		return false
	_hex_rows = hexes
	for entry: Variant in _hex_rows:
		if typeof(entry) == TYPE_DICTIONARY:
			var row: Dictionary = entry
			_row_of[Vector2i(int(row.get("c", 0)), int(row.get("r", 0)))] = row
	var items: Variant = wild.get("items", null)
	if typeof(items) == TYPE_ARRAY:
		_wild = items
	var pieces: Variant = index.get("pieces", null)
	if typeof(pieces) == TYPE_DICTIONARY:
		_pieces = pieces
	var placements := _read_json(art_dir + "placements.json")
	var rows: Variant = placements.get("placements", null)
	if typeof(rows) == TYPE_ARRAY:
		var list: Array = rows
		for entry: Variant in list:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = entry
			if typeof(row.get("sea", null)) == TYPE_NIL or typeof(row.get("keys", null)) != TYPE_DICTIONARY:
				continue
			var hex := _vec(row.get("hex", null))
			var family := "harbour_addon" if bool(row.get("addon", false)) else str(row.get("family", ""))
			_exact["%d,%d,%s" % [int(hex.x), int(hex.y), family]] = row
	var mask := _texture(art_dir + "land_mask.png")
	if mask != null:
		_land = mask.get_image()
		if _land != null and _land.is_compressed():
			_land.decompress()
		var clip := _piece_ground.material as ShaderMaterial
		if clip != null:
			clip.set_shader_parameter("land_mask", mask)
			clip.set_shader_parameter("map_size", _map_size)
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_error = "%s is not there" % path
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_error = "%s does not read" % path
		return {}
	var out: Dictionary = parsed
	return out


## A texture of the bake by path: the imported one, or the PNG read as it is when the project was not imported since
## the bake.
func _texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null:
			texture = ImageTexture.create_from_image(image)
	_textures[path] = texture
	return texture


func _image(path: String) -> Image:
	if _images.has(path):
		return _images[path]
	var image: Image = null
	var texture := _texture(path)
	if texture != null:
		image = texture.get_image()
		if image != null and image.is_compressed():
			image.decompress()
	_images[path] = image
	return image


static func _vec(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var pair: Array = value
	if pair.size() < 2:
		return fallback
	return Vector2(float(pair[0]), float(pair[1]))


static func _rect(value: Variant) -> Rect2:
	if typeof(value) != TYPE_ARRAY:
		return Rect2()
	var four: Array = value
	if four.size() < 4:
		return Rect2()
	return Rect2(float(four[0]), float(four[1]), float(four[2]), float(four[3]))


static func _dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = value
	return out


# ----- the improvement and the pictures -----------------------------------------------------------------------------


func _run_wfc() -> void:
	var table := _hex_rows
	if not with_villages:
		table = []
		for entry: Variant in _hex_rows:
			var row := _dict(entry)
			if str(_dict(row.get("place", null)).get("name", "x")) == "":
				row = row.duplicate()
				row["place"] = null
			table.append(row)
	var start := Time.get_ticks_usec()
	improve = WorldImprove.build(table, seed_value)
	_wfc_ms = float(Time.get_ticks_usec() - start) / 1000.0


## The index key of a piece, or "" when the bake has no such picture. A picture that is missing in one layout or with
## one extra falls back to the nearest one the bake has.
func _find_key(family: String, level: int, climate: String, variant: int, mirror: int, extra: String) -> String:
	var winter := climate if season == "winter" else "-"
	for trial: Array in [[variant, mirror, extra], [0, mirror, extra], [variant, mirror, "-"], [0, mirror, "-"],
			[0, 0, extra], [0, 0, "-"]]:
		var key := "%s|%d|%s|%s|%d|%d|%s" % [family, level, season, winter, int(trial[0]), int(trial[1]), str(trial[2])]
		if _pieces.has(key):
			return key
	return ""


## Where a coast piece's canvas goes: so that the shore lies where the family expects it (y0 px out from the middle).
func _shore_anchor(row: Dictionary, family: String) -> Vector2:
	var centre := _vec(row.get("centre_px", null))
	var shore: Variant = row.get("shore", null)
	if typeof(shore) != TYPE_ARRAY or typeof(row.get("sea_angle", null)) == TYPE_NIL:
		return centre
	var angle := deg_to_rad(float(row.get("sea_angle", 90.0)))
	var out := Vector2(cos(angle), sin(angle))
	var along := Vector2(out.y, -out.x)
	var nearest := INF
	var reach := 0.0
	var points: Array = shore
	for entry: Variant in points:
		var p := _vec(entry)
		if absf(p.dot(along)) < nearest:
			nearest = absf(p.dot(along))
			reach = p.dot(out)
	if nearest == INF:
		return centre
	return (centre + out * (reach - float(COAST_Y0.get(family, 13.0)))).round()


## The pieces of the map for this seed and season: each {hex, centre, entry (of the index), coast, addon, town (the
## town's piece under a harbour add-on, or {})}.
func _placed_pieces() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var missing: Array[String] = []
	for hex: Vector2i in improve.hexes:
		var piece := improve.piece_at(hex)
		if piece.is_empty():
			continue
		var row := _row_of[hex]
		var family := str(piece["family"])
		var level := int(piece["level"])
		var climate := str(row.get("climate", "frost"))
		var variant := int(piece["variant"])
		var mirror := int(bool(piece["mirror"]))
		var coast_family := family == "harbour" or family == "salt"
		var extra := str(piece["sea"]) if coast_family else str(piece["extra"])
		var town := _one_piece(hex, row, family, level, climate, variant, mirror, extra, coast_family, false)
		if town.is_empty():
			missing.append("%s %d at %s" % [family, level, hex])
		else:
			out.append(town)
		var addon := int(piece["addon"])
		if addon > 0:
			var side := "carved" if str(piece["addon_mode"]) == "carved" else str(piece["sea"])
			var harbour := _one_piece(hex, row, "harbour_addon", addon, climate, variant, mirror, side, true, true)
			if harbour.is_empty():
				missing.append("harbour_addon %d %s at %s" % [addon, side, hex])
			else:
				harbour["town"] = town
				out.append(harbour)
	stats["missing_pictures"] = missing.size()
	stats["missing"] = missing
	return out


func _one_piece(hex: Vector2i, row: Dictionary, family: String, level: int, climate: String, variant: int, mirror: int,
		extra: String, coast: bool, addon: bool) -> Dictionary:
	var centre := _vec(row.get("centre_px", null))
	var key := ""
	if coast:
		# The piece cut to this hex's own shore, when the bake has it at this level; else the piece of the sea side.
		var exact: Dictionary = _exact.get("%d,%d,%s" % [hex.x, hex.y, family], {})
		if not exact.is_empty() and int(exact.get("level", 0)) == level:
			var keys := _dict(exact.get("keys", null))
			if _pieces.has(str(keys.get(season, ""))):
				key = str(keys.get(season, ""))
				centre = _vec(exact.get("centre", null), centre)
		if key == "":
			key = _find_key(family, level, climate, variant, mirror, extra)
			if extra != "carved":
				centre = _shore_anchor(row, family)
	else:
		key = _find_key(family, level, climate, variant, mirror, extra)
	if key == "":
		return {}
	return {"hex": hex, "centre": centre, "entry": _dict(_pieces[key]), "coast": coast, "addon": addon, "town": {},
		"key": key}


## Whether a point (px from the middle of a piece's canvas) lies in the piece's footprint.
func _in_footprint(entry: Dictionary, at: Vector2) -> bool:
	var footprint := _dict(entry.get("footprint", null))
	if footprint.is_empty():
		return false
	var region := _rect(footprint.get("rect", null))
	var local := at - _vec(footprint.get("offset", null))
	if local.x < 0.0 or local.y < 0.0 or local.x >= region.size.x or local.y >= region.size.y:
		return false
	var image := _image(art_dir + "pieces/" + str(footprint.get("atlas", "")) + ".png")
	if image == null:
		return false
	return image.get_pixel(int(region.position.x + local.x), int(region.position.y + local.y)).a > 0.5


func _is_land(at: Vector2) -> bool:
	if _land == null:
		return true
	var x := clampi(int(at.x * float(_land.get_width()) / _map_size.x), 0, _land.get_width() - 1)
	var y := clampi(int(at.y * float(_land.get_height()) / _map_size.y), 0, _land.get_height() - 1)
	return _land.get_pixel(x, y).r > 0.5


static func _in_hex(at: Vector2, margin: float) -> bool:
	var ax := absf(at.x)
	var ay := absf(at.y) / TILT
	var inner := HEX_INNER - margin
	return ax <= inner and ax * 0.5 + ay * 0.8660254 <= inner


func _rebuild() -> void:
	var rebuild_start := Time.get_ticks_usec()
	_ground.texture = _texture(art_dir + "ground_%s.png" % season)
	_overlay.texture = _texture(art_dir + "overlay_%s.png" % season)
	if _ground.texture == null:
		# An older bake without the two layers: the base has both, and the piece grounds then lie over the roads.
		_ground.texture = _texture(art_dir + "base_%s.png" % season)
	_piece_ground.clear_items()
	_coast_ground.clear_items()
	_shadows.clear_items()
	_standing.clear_items()
	var placed := _placed_pieces()
	var by_hex: Dictionary[Vector2i, Array] = {}
	for piece: Dictionary in placed:
		var hex: Vector2i = piece["hex"]
		var around: Array[Vector2i] = [hex]
		if bool(piece["addon"]):
			for d: int in 6:
				around.append(WorldImprove.neighbour(hex, d))
		for h: Vector2i in around:
			if not by_hex.has(h):
				by_hex[h] = []
			by_hex[h].append(piece)
	var things: Array[Array] = []  # [sort y, sort x, texture, region, position]
	var built := 0
	var left_out := 0
	for piece: Dictionary in placed:
		var centre: Vector2 = piece["centre"]
		var entry: Dictionary = piece["entry"]
		var coast := bool(piece["coast"])
		var ground := _dict(entry.get("ground", null))
		if not ground.is_empty():
			var layer := _coast_ground if coast else _piece_ground
			_add_sprite(layer, "pieces/", ground, centre)
		var shadow := _dict(entry.get("shadow", null))
		if not shadow.is_empty():
			_add_sprite(_shadows, "pieces/", shadow, centre)
		var standing: Variant = entry.get("standing", null)
		if typeof(standing) != TYPE_ARRAY:
			continue
		var list: Array = standing
		var piece_hex: Vector2i = piece["hex"]
		var home := _vec(_row_of[piece_hex].get("centre_px", null))
		var town: Dictionary = piece["town"]
		for n: int in list.size():
			var thing := _dict(list[n])
			var region := _rect(thing.get("rect", null))
			var offset := _vec(thing.get("offset", null))
			var foot_y := float(thing.get("foot_y", 0.0))
			var picture_foot := float(thing.get("pic_foot_y", minf(foot_y, offset.y + region.size.y)))
			var at := centre + offset
			var foot := Vector2(at.x + region.size.x / 2.0, centre.y + picture_foot)
			if not coast and foot_y < 60.0 and not (_is_land(Vector2(at.x + 1.0, foot.y)) and _is_land(foot)
					and _is_land(Vector2(at.x + region.size.x - 1.0, foot.y))):
				left_out += 1  # the map owns the shore: nothing of a land piece stands in the water
				continue
			if coast and not _in_hex(Vector2(offset.x + region.size.x / 2.0, picture_foot), 1.0):
				left_out += 1  # the shore pushed it out of its canvas hex
				continue
			if not town.is_empty() and _is_land(foot) and _in_footprint(_dict(town["entry"]), foot - home):
				left_out += 1  # a harbour thing inside the town
				continue
			var texture := _texture(art_dir + "pieces/" + str(thing.get("atlas", "")) + ".png")
			if texture != null:
				things.append([centre.y + foot_y + float(n) * 0.00001, centre.x, texture, region, at])
				built += 1
	var wild_shown := 0
	var wild_dropped := 0
	for entry: Variant in _wild:
		var item := _dict(entry)
		var foot := _vec(item.get("foot", null))
		var hex_xy := _vec(item.get("hex", null))
		var hex := Vector2i(int(hex_xy.x), int(hex_xy.y))
		if bool(item.get("removable", false)) and _cleared(item, foot, hex, by_hex):
			wild_dropped += 1
			continue
		var sprite := _dict(_dict(item.get("sprite", null)).get(season, null))
		var shadow := _dict(_dict(item.get("shadow", null)).get(season, null))
		if not shadow.is_empty():
			_add_sprite(_shadows, "", shadow, foot)
		if sprite.is_empty():
			continue
		var texture := _texture(art_dir + str(sprite.get("atlas", "")) + ".png")
		if texture != null:
			things.append([float(item.get("sort_y", foot.y)), float(item.get("sort_x", foot.x)), texture,
				_rect(sprite.get("rect", null)), foot + _vec(sprite.get("offset", null))])
			wild_shown += 1
	things.sort_custom(func(a: Array, b: Array) -> bool:
		var ay := float(a[0])
		var by := float(b[0])
		return ay < by or (ay == by and float(a[1]) < float(b[1])))
	for thing: Array in things:
		var texture: Texture2D = thing[2]
		var region: Rect2 = thing[3]
		var at: Vector2 = thing[4]
		_standing.add_item(texture, region, at)
	stats["pieces"] = placed.size()
	stats["built_things"] = built
	stats["built_left_out"] = left_out
	stats["wild_shown"] = wild_shown
	stats["wild_dropped"] = wild_dropped
	stats["sprites"] = _standing.item_count() + _shadows.item_count() + _piece_ground.item_count() \
		+ _coast_ground.item_count()
	stats["wfc_ms"] = _wfc_ms
	stats["rebuild_ms"] = float(Time.get_ticks_usec() - rebuild_start) / 1000.0
	_write_hud()


## Whether a wild thing gives way to a piece (the compositor's rules): a tree whose foot lies in a footprint; a rounded
## hill in a hex that takes a piece; a peak or a piece of a range that stands in a footprint or up to RANGE_FRONT px in
## front of one (a peak hides what lies behind it).
func _cleared(item: Dictionary, foot: Vector2, hex: Vector2i, by_hex: Dictionary[Vector2i, Array]) -> bool:
	var kind := str(item.get("kind", ""))
	var around: Array[Vector2i] = [hex]
	var behind: Array[float] = [0.0]
	if kind == "range":
		behind = RANGE_FRONT
		for d: int in 6:
			around.append(WorldImprove.neighbour(hex, d))
	var seen: Dictionary[String, bool] = {}
	for h: Vector2i in around:
		if not by_hex.has(h):
			continue
		for other: Variant in by_hex[h]:
			var piece: Dictionary = other
			if seen.has(str(piece["key"]) + str(piece["centre"])):
				continue
			seen[str(piece["key"]) + str(piece["centre"])] = true
			var centre: Vector2 = piece["centre"]
			var piece_hex: Vector2i = piece["hex"]
			if kind == "hill" and not bool(piece["addon"]) and piece_hex == hex:
				return true
			for back: float in behind:
				if _in_footprint(_dict(piece["entry"]), foot - Vector2(0.0, back) - centre):
					return true
	return false


func _add_sprite(layer: WorldSpriteLayer, folder: String, sprite: Dictionary, origin: Vector2) -> void:
	var texture := _texture(art_dir + folder + str(sprite.get("atlas", "")) + ".png")
	if texture != null:
		layer.add_item(texture, _rect(sprite.get("rect", null)), origin + _vec(sprite.get("offset", null)))


func _write_hud() -> void:
	var summary := improve.summary()
	var families := _dict(summary.get("by_family", null))
	var levels := _dict(summary.get("by_level", null))
	_title.text = "North Italy   seed %d   %s%s" % [seed_value, season, "" if with_villages else "   named towns only"]
	var lines: Array[String] = []
	lines.append("%d land hexes: %d with a piece, %d wild" % [int(summary["hexes"]), int(summary["pieces"]),
		int(summary["wild"])])
	for family_name: Variant in families.keys():
		if int(families[family_name]) > 0:
			lines.append("   %s %d   by level %s" % [str(family_name), int(families[family_name]), str(levels[family_name])])
	lines.append("search %.0f ms, %d backtracks, %d restarts; drawn in %.0f ms" % [_wfc_ms, int(summary["backtracks"]),
		int(summary["restarts"]), float(stats["rebuild_ms"])])
	lines.append("%d built things, %d left out at the shore" % [int(stats["built_things"]), int(stats["built_left_out"])])
	lines.append("%d wild things, %d cleared for pieces" % [int(stats["wild_shown"]), int(stats["wild_dropped"])])
	if int(stats.get("missing_pictures", 0)) > 0:
		lines.append("%d pieces have no picture in the bake" % int(stats["missing_pictures"]))
	lines.append("1-4 season   R new seed   V villages   G grid   F whole map   H hide")
	_stats_label.text = "\n".join(lines)
