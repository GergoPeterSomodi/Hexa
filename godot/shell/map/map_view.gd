## The map view (0.3.0 item 6): the tile layers at the tile zoom, the far maps below it, ridges, passes and names, the
## camera (drag, wheel, keys, smooth zoom clamped to the Python zoom range) and the two views: terrain (key 1) and
## countries (key 2). It reads the map and the atlas and changes neither: all the game's state stays in core/.
class_name MapView
extends Node2D

signal view_changed(mode: String)
signal hover_changed(text: String)

const VIEW_TERRAIN := "terrain"
const VIEW_COUNTRIES := "countries"
const ZOOM_MIN := 3.0 / 60.0  # Python's far radius 3, as a fraction of the baked radius 60
const ZOOM_MAX := 34.0 / 60.0  # Python's closest radius 34 (the close landscape comes later)
const TILE_ZOOM := 13.0 / 60.0  # Python's first tile radius: below it the far maps show
const ZOOM_STEP := 1.15  # per wheel notch
const ZOOM_EASE := 14.0  # how fast the zoom follows its target (per second)
const PAN_SPEED := 800.0  # screen pixels a second with the keys

var view_mode: String = VIEW_TERRAIN
var map: MapData
var atlas: AtlasIndex
var plan: TilePlan
var style: TerrainStyle

var _camera: Camera2D
var _tiles: Node2D
var _layers: Dictionary[String, TileMapLayer] = {}
var _far_terrain: FarMap
var _far_countries: FarMap
var _overlay: FarMap
var _marks: MapMarks
var _names: MapNames
var _map_size := Vector2.ZERO
var _target_zoom := ZOOM_MIN
var _anchored := false
var _anchor_world := Vector2.ZERO
var _anchor_screen := Vector2.ZERO
var _dragging := false
var _hover := Vector2i(-1, -1)
var _far := false


## Builds every layer for the map. Call once, after the node is in the tree.
func setup(p_map: MapData, p_atlas: AtlasIndex) -> void:
	map = p_map
	atlas = p_atlas
	style = TerrainStyle.load_default()
	plan = TilePlan.build(map, atlas)
	_map_size = MapGeometry.map_size(map.cols, map.rows)
	_build_tiles()
	_build_far()
	_marks = MapMarks.new()
	_marks.map = map
	_marks.borders = Political.border_items(map)
	_marks.capitals = Political.capitals(map)
	add_child(_marks)
	_names = MapNames.new()
	_names.map = map
	_names.countries = Political.name_points(map)
	add_child(_names)
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	_camera.make_current()
	var fit := minf(_view_size().x / _map_size.x, _view_size().y / _map_size.y)
	_target_zoom = clampf(fit, ZOOM_MIN, ZOOM_MAX)
	frame(_map_size * 0.5, _target_zoom)


## Moves the camera at once: the centre in world pixels and the zoom (clamped). Used by the probe and the tests.
func frame(centre: Vector2, zoom_to: float) -> void:
	_target_zoom = clampf(zoom_to, ZOOM_MIN, ZOOM_MAX)
	_anchored = false
	_camera.zoom = Vector2(_target_zoom, _target_zoom)
	_camera.position = centre
	_clamp_camera()
	_refresh()


func zoom() -> float:
	return _camera.zoom.x


func camera_centre() -> Vector2:
	return _camera.position


## Switches the view: "terrain" or "countries". Other names are ignored.
func set_view(mode: String) -> void:
	if mode != VIEW_TERRAIN and mode != VIEW_COUNTRIES:
		return
	if mode == view_mode:
		return
	view_mode = mode
	_refresh()
	view_changed.emit(mode)


## The hex under a point of the screen (the viewport's pixels), or Vector2i(-1, -1) off the map.
func hex_at_screen(screen: Vector2) -> Vector2i:
	var hex := MapGeometry.pixel_to_hex(_world_at(screen))
	return hex if map.has_hex(hex) else Vector2i(-1, -1)


## Number of cells on each tile layer, by layer name (the probe and the tests read it).
func layer_cells() -> Dictionary:
	var out: Dictionary = {}
	for layer_name: String in TilePlan.LAYERS:
		out[layer_name] = _layers[layer_name].get_used_cells().size()
	return out


func is_far() -> bool:
	return _far


func _build_tiles() -> void:
	var tile_set := MapTileSet.build(atlas)
	_tiles = Node2D.new()
	_tiles.name = "Tiles"
	add_child(_tiles)
	for layer_name: String in TilePlan.LAYERS:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = tile_set
		layer.scale = MapGeometry.tile_layer_scale()
		layer.position = MapGeometry.tile_layer_offset()
		var cells: Dictionary = plan.layers[layer_name]
		for pos: Vector2i in cells.keys():
			var key: String = cells[pos]
			layer.set_cell(pos, atlas.page_of(key), atlas.cell_of(key))
		_tiles.add_child(layer)
		_layers[layer_name] = layer


func _build_far() -> void:
	_far_terrain = FarMap.new()
	_far_terrain.name = "FarTerrain"
	add_child(_far_terrain)
	_far_terrain.setup(style.far_colours(map, false), map.cols, map.rows, _map_size, 1.0)
	_far_countries = FarMap.new()
	_far_countries.name = "FarCountries"
	add_child(_far_countries)
	_far_countries.setup(style.far_colours(map, true), map.cols, map.rows, _map_size, 1.0)
	_overlay = FarMap.new()
	_overlay.name = "CountriesOverlay"
	add_child(_overlay)
	_overlay.setup(style.overlay_colours(map), map.cols, map.rows, _map_size, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if map == null:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_at(button.position, ZOOM_STEP)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_at(button.position, 1.0 / ZOOM_STEP)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_camera.position -= motion.relative / _camera.zoom.x
		_anchored = false
		_clamp_camera()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_1:
				set_view(VIEW_TERRAIN)
			elif key.keycode == KEY_2:
				set_view(VIEW_COUNTRIES)


func _process(delta: float) -> void:
	if map == null:
		return
	var current := _camera.zoom.x
	var eased := lerpf(current, _target_zoom, 1.0 - exp(-ZOOM_EASE * delta))
	if absf(eased - _target_zoom) < 0.00005:
		eased = _target_zoom
	_camera.zoom = Vector2(eased, eased)
	if _anchored:
		_camera.position = _anchor_world - (_anchor_screen - _half_view()) / eased
		if eased == _target_zoom:
			_anchored = false
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		_camera.position += dir.normalized() * PAN_SPEED * delta / eased
		_anchored = false
	_clamp_camera()
	_refresh()
	var hex := hex_at_screen(get_viewport().get_mouse_position())
	if hex != _hover:
		_hover = hex
		hover_changed.emit(HexInfo.describe(map, hex, style) if hex.x >= 0 else "")


func _zoom_at(screen: Vector2, factor: float) -> void:
	_anchor_screen = screen
	_anchor_world = _world_at(screen)
	_anchored = true
	_target_zoom = clampf(_target_zoom * factor, ZOOM_MIN, ZOOM_MAX)


func _refresh() -> void:
	var zoom_now := _camera.zoom.x
	_far = zoom_now < TILE_ZOOM
	_tiles.visible = not _far
	_far_terrain.visible = _far and view_mode == VIEW_TERRAIN
	_far_countries.visible = _far and view_mode == VIEW_COUNTRIES
	_overlay.visible = not _far and view_mode == VIEW_COUNTRIES
	# Decorations (trees, rocks) belong to the countries view only: Python's MapView draws them when not bare,
	# and its terrain mode is bare.
	_layers[TilePlan.DECO].visible = view_mode == VIEW_COUNTRIES
	_names.set_zoom(zoom_now)
	var top_left := _world_at(Vector2.ZERO)
	_names.view_rect = Rect2(top_left, _view_size() / zoom_now).grow(120.0)
	_marks.show_borders = view_mode == VIEW_COUNTRIES
	_names.queue_redraw()
	_marks.hover = _hover
	_marks.queue_redraw()


func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _half_view() -> Vector2:
	return _view_size() * 0.5


func _world_at(screen: Vector2) -> Vector2:
	return _camera.position + (screen - _half_view()) / _camera.zoom.x


func _clamp_camera() -> void:
	_camera.position = Vector2(clampf(_camera.position.x, 0.0, _map_size.x),
			clampf(_camera.position.y, 0.0, _map_size.y))
