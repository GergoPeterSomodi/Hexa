## The map scene (docs/architecture/m1-build-spec.md sections 5, 7 and 8; ui-and-controls-spec.md sections 3.1, 3.3, 4.2 to 4.4):
## the camera, CameraRig, the tile view, the far picture, MapInput and MapLabels around Session.game.
## Any HexPanelContract is injected externally by App/Hud (or tests) and is null-safe when running standalone.
class_name MapScene
extends Node2D

signal refused(reason: String)
signal selection_changed(hex: Vector2i)
signal season_changed(season_name: String)
signal hud_toggle_requested

const MAP_ID := "north_italy"
const START_SEED := 1480
const NO_HEX := Vector2i(-9999, -9999)
const SEA_COLOUR := Color("#3f7fae")
const START_SEASON := "summer"
const SELECT_TILE := "mark/select"
## A map of at most this many hexes is loaded at once when the game starts; a larger one a slice a frame.
const SYNC_LOAD_HEXES := 4000
## Milliseconds a frame the loading and a season swap may use (a layer or a chunk is never split, so one can pass it).
const SLICE_MS := 5.0

## The map the scene shows (a Session.new_game id); a tool may set it before the scene enters the tree.
var map_id := MAP_ID
var start_seed := START_SEED
var season := START_SEASON
## The selected hex, or NO_HEX.
var selected := NO_HEX
## Ask for the next season's pictures a moment ahead (a swap then does not wait for the disk).
var preload_next_season := true
## Frame loading/swap slice budget in milliseconds (configurable via Settings "dev/slice_ms").
var slice_ms := SLICE_MS

var _tiles: TilesetBuilder = null
var _line_queue: Array[Vector2i] = []
var _loading_map: MapData = null
var _pending_season := ""  # a season asked for before its pictures were loaded: swapped when they are
var _loading_state: MapState = null
var _settings: Settings = null
var _grid_visible := false
var _grid_opacity := 1.0
var _far_locked := false
var _panel: HexPanelContract = null

@onready var _camera: Camera2D = $Camera
@onready var _rig: CameraRig = $CameraRig
@onready var _view: TileMapView = $View
@onready var _far: FarMap = $Far
@onready var _input: MapInput = $Input
@onready var _labels: MapLabels = $Names/Labels


func _ready() -> void:
	RenderingServer.set_default_clear_color(SEA_COLOUR)
	if not InputMap.has_action(&"map_select"):
		Bindings.ensure()
	_rig.setup(_camera, Vector2.ZERO)
	_rig.view_changed.connect(_on_view_changed)
	_input.camera = _camera
	_input.map_node = _view
	_input.select_requested.connect(_on_select_requested)
	_input.command_requested.connect(_on_command_requested)
	_input.season_requested.connect(_on_season_requested)
	_input.new_seed_requested.connect(new_seed)
	_input.grid_toggled.connect(toggle_grid)
	_input.names_toggled.connect(toggle_names)
	_input.hud_toggled.connect(func() -> void: hud_toggle_requested.emit())
	_input.upgrade_requested.connect(upgrade_selected)
	_tiles = TilesetBuilder.load_season(season)
	if _tiles.tile_set == null:
		push_warning("map scene: %s (bake the tiles and run tools/build_tileset.gd)" % _tiles.error)
		_tiles.tile_set = TileSet.new()
	_view.setup(_tiles)
	_set_grid_visible(_grid_visible)
	_far.visible = false
	Events.hex_changed.connect(_on_hex_changed)
	Events.game_started.connect(_on_game_started)
	if _settings != null:
		_apply_settings(_settings)
	if Session.game == null:
		Session.new_game(map_id, start_seed)
	else:
		_on_game_started()
	_request_next_season()


func _exit_tree() -> void:
	if Events.hex_changed.is_connected(_on_hex_changed):
		Events.hex_changed.disconnect(_on_hex_changed)
	if Events.game_started.is_connected(_on_game_started):
		Events.game_started.disconnect(_on_game_started)
	_disconnect_settings()


## Applies display, map, graphics, controls and developer settings and listens for live changes.
func configure(settings: Settings) -> void:
	if settings == _settings:
		if settings != null and is_node_ready():
			_apply_settings(settings)
		return
	_disconnect_settings()
	_settings = settings
	if _settings == null:
		if is_node_ready():
			_rig.configure(null)
			_input.configure(null)
		return
	_settings.changed.connect(_on_setting_changed)
	if is_node_ready():
		_apply_settings(_settings)


func _apply_settings(settings: Settings) -> void:
	_set_grid_visible(bool(settings.get_value("map/grid")))
	_grid_opacity = clampf(float(settings.get_value("map/grid_opacity")) / 100.0, 0.0, 1.0)
	_labels.set_visible(bool(settings.get_value("map/place_names")))
	var shading := bool(settings.get_value("graphics/relief_shading"))
	_view.set_layer_visible("shade", shading)
	_view.set_layer_visible("light", shading)
	preload_next_season = bool(settings.get_value("graphics/preload_next_season"))
	_far.set_zoom_switch(float(settings.get_value("dev/far_zoom")))
	slice_ms = clampf(float(settings.get_value("dev/slice_ms")), 2.0, 16.0)
	_rig.configure(settings)
	_input.configure(settings)
	_apply_zoom()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if _settings == null or not is_node_ready():
		return
	if key in [
		"map/grid", "map/grid_opacity", "map/place_names",
		"graphics/relief_shading", "graphics/preload_next_season",
		"dev/far_zoom", "dev/slice_ms"
	]:
		_apply_settings(_settings)


func _disconnect_settings() -> void:
	if _settings != null and _settings.changed.is_connected(_on_setting_changed):
		_settings.changed.disconnect(_on_setting_changed)
	_settings = null


# ----- the game's side ----------------------------------------------------------------------------------------------


## A game began: every layer is filled again from the game's map and state, the far picture rebuilt, the selection gone.
func _on_game_started() -> void:
	var map := Session.game.map
	var state := Session.game.state
	select_hex(NO_HEX)
	_labels.setup(map)
	_view.set_climates(map.cols, map.climate)
	_view.begin_fill(map.cols, map.rows, func(hex: Vector2i, names: PackedStringArray) -> void: MapCells.fill_hex(map, state, hex, names),
		_hex_under_camera(), MapCells.LAYERS)
	_view.set_process(false)  # the scene slices the fill by time (_load_step)
	_loading_map = map
	_loading_state = state
	_line_queue.clear()
	for chunk_y: int in ceili(float(map.rows) / EdgeLines.CHUNK):
		for chunk_x: int in ceili(float(map.cols) / EdgeLines.CHUNK):
			_line_queue.append(Vector2i(chunk_x, chunk_y))
	_far.begin(map, state)
	_rig.set_map_size(map_size())
	fit()
	if map.hex_count() <= SYNC_LOAD_HEXES:
		finish_loading()


## Whether the map is still being put on the view (tiles, lines, the far picture).
func is_loading() -> bool:
	return _view.is_filling() or not _line_queue.is_empty() or _far.is_building()


func fill_progress() -> float:
	return _view.fill_progress()


## Does all the loading now (a small map, a test, a tool).
func finish_loading() -> void:
	_far.step(1.0e9)
	while _view.fill_step(100000):
		pass
	_line_step(1.0e9)


## Up to `budget_ms` of loading: the far picture first (it is what a zoomed-out start shows), then the tiles nearest the
## camera first, then the lines. A row, a block or a chunk is never split, so a step can pass its budget by one of them.
func _load_step(budget_ms: float) -> void:
	var until := Time.get_ticks_usec() + int(budget_ms * 1000.0)
	if _far.is_building():
		_far.step(budget_ms)
	if _view.is_filling():
		_view.fill_for(float(until - Time.get_ticks_usec()) / 1000.0)
	if Time.get_ticks_usec() < until:
		_line_step(float(until - Time.get_ticks_usec()) / 1000.0)


## Builds the lines of the queued chunks, one at least, until the time is up.
func _line_step(budget_ms: float) -> void:
	var until := Time.get_ticks_usec() + int(budget_ms * 1000.0)
	while not _line_queue.is_empty():
		var chunk: Vector2i = _line_queue.pop_front()
		_view.set_chunk_lines(chunk, EdgeLines.for_chunk(_loading_map, _loading_state, chunk))
		if Time.get_ticks_usec() >= until:
			break


## Injects an external HexPanelContract (e.g. from Hud) or null for standalone/headless runs.
func set_panel(value: HexPanelContract) -> void:
	_panel = value
	if _panel == null:
		return
	if selected != NO_HEX and Session.game != null and Session.game.map != null and Session.game.map.has(selected):
		_panel.show_hex(selected)
	else:
		_panel.clear()


## Enables or disables map pointer/camera input (used while modal/opaque screens are up).
func set_input_enabled(on: bool) -> void:
	if _input != null:
		_input.enabled = on
	if _rig != null:
		_rig.enabled = on


## Applies developer debug layer switches from DebugOverlay.
func apply_debug_layer(layer_name: StringName, on: bool) -> void:
	if _view == null:
		return
	match layer_name:
		&"grid":
			_set_grid_visible(on)
		&"shade", &"light":
			_view.set_layer_visible(String(layer_name), on)
		&"trees":
			for i: int in range(6):
				_view.set_layer_visible("trees%d" % i, on)
		&"lines":
			var lines_node := _view.get_node_or_null("Lines") as CanvasItem
			if lines_node != null:
				lines_node.visible = on
		&"far_locked":
			_far_locked = on
			_apply_zoom()


## A hex changed: it and its neighbours are named again and only what differs is written.
func _on_hex_changed(hex: Vector2i) -> void:
	var map := Session.game.map
	var state := Session.game.state
	for touched: Vector2i in MapCells.touched_by(map, hex):
		_view.set_hex(touched, MapCells.of_hex(map, state, touched))
	_far.update_hex(hex)
	if _panel != null and _panel.shown_hex() != NO_HEX:
		_panel.refresh()


## A new seed: the same map, the next seed's improvement.
func new_seed() -> void:
	if Session.game != null:
		Session.new_game(map_id, Session.game.seed_value + 1)


func upgrade_selected() -> Dictionary:
	var verdict: Dictionary
	if selected == NO_HEX:
		verdict = {"ok": false, "reason": "no hex is selected"}
	else:
		verdict = Session.act("upgrade", {"hex": selected})
	if not bool(verdict.get("ok", false)):
		var reason := str(verdict.get("reason", ""))
		if reason != "":
			refused.emit(reason)
	return verdict


# ----- selection ----------------------------------------------------------------------------------------------------


func _on_select_requested(map_px: Vector2) -> void:
	select_hex(_view.hex_at(map_px))


func _on_command_requested(_map_px: Vector2) -> void:
	select_hex(NO_HEX)


## Selects a hex of the map (NO_HEX, or a hex off the map, clears the selection): the ring on the marks layer and the panel.
func select_hex(hex: Vector2i) -> void:
	if selected != NO_HEX:
		_view.set_tile("marks", selected, "")
	if hex == NO_HEX or Session.game == null or not Session.game.map.has(hex):
		var was_selected := selected != NO_HEX
		selected = NO_HEX
		if _panel != null:
			_panel.clear()
		if was_selected:
			selection_changed.emit(NO_HEX)
		return
	selected = hex
	_view.set_tile("marks", hex, SELECT_TILE)
	if _panel != null:
		_panel.show_hex(hex)
	selection_changed.emit(hex)


# ----- seasons, grid, camera ----------------------------------------------------------------------------------------


func _on_season_requested(index: int) -> void:
	set_season(TilesetBuilder.SEASONS[clampi(index, 0, TilesetBuilder.SEASONS.size() - 1)])


## Swaps the season: the TileSet of every layer is replaced and no cell is written. Godot rebuilds a layer when its TileSet
## changes (about 1 ms a thousand cells), so the view swaps a chunk of a layer at a time (slice_ms a frame), the chunks on the
## screen first; a small map is done in the first step.
func set_season(value: String) -> void:
	_pending_season = ""
	if value == season or not TilesetBuilder.SEASONS.has(value):
		return
	if preload_next_season and DisplayServer.get_name() != "headless" and not TilesetBuilder.is_loaded(value):
		TilesetBuilder.request_season(value)  # not loaded yet (a key jumped over the next season): the frames go on meanwhile
		_pending_season = value
		return
	var tiles := TilesetBuilder.load_season(value)
	if tiles.tile_set == null:
		push_warning("map scene: %s" % tiles.error)
		return
	season = value
	_tiles = tiles
	_view.begin_season_swap(tiles, _hexes_on_screen())
	_view.swap_step(slice_ms)
	_request_next_season()
	season_changed.emit(season)


func is_swapping() -> bool:
	return _view.is_swapping()


## Does the rest of a season swap now.
func finish_swap() -> void:
	_view.swap_step(1.0e9)


## The hexes the camera sees (a Rect2i), for what is done nearest the screen first.
func _hexes_on_screen() -> Rect2i:
	var half := get_viewport_rect().size / (2.0 * _camera.zoom.x)
	var low := _view.hex_at(_camera.position - half)
	var high := _view.hex_at(_camera.position + half)
	return Rect2i(low, high - low + Vector2i.ONE).abs()


## The next season in the year's order is loaded on another thread, so the usual swap is quick.
func _request_next_season() -> void:
	if not preload_next_season or DisplayServer.get_name() == "headless":
		return
	var seasons := TilesetBuilder.SEASONS
	TilesetBuilder.request_season(seasons[(seasons.find(season) + 1) % seasons.size()])


func toggle_grid() -> void:
	_set_grid_visible(not _grid_visible)
	if _settings != null:
		_settings.set_value("map/grid", _grid_visible)


func _set_grid_visible(value: bool) -> void:
	_grid_visible = value
	if _view != null:
		_view.set_layer_visible("grid", _grid_visible)


func toggle_names() -> void:
	_labels.set_visible(not _labels.visible)
	if _settings != null:
		_settings.set_value("map/place_names", _labels.visible)


func set_hud_visible(_value: bool) -> void:
	# Kept as a safe no-op for standalone tools (HUD lives in App/Hud).
	pass


## The map's size in px.
func map_size() -> Vector2:
	var map := Session.game.map
	return Vector2((float(map.cols) + 0.5) * MapTiles.CELL.x, float(map.rows) * MapTiles.ROW + MapTiles.CELL.y - MapTiles.ROW)


## The whole map in the window.
func fit() -> void:
	_rig.set_map_size(map_size())
	_rig.fit()
	_apply_zoom()


## A view centred on a map pixel at a zoom (1 = the art's size).
func frame_at(centre: Vector2, zoom_val: float) -> void:
	_rig.set_map_size(map_size())
	_rig.frame_at(centre, zoom_val)
	_apply_zoom()


func zoom() -> float:
	return _camera.zoom.x


func view() -> TileMapView:
	return _view


func far() -> FarMap:
	return _far


func panel() -> HexPanelContract:
	return _panel


func labels() -> MapLabels:
	return _labels


func camera() -> Camera2D:
	return _camera


func camera_rig() -> CameraRig:
	return _rig


func map_input() -> MapInput:
	return _input


func _hex_under_camera() -> Vector2i:
	if _camera == null or not is_inside_tree():
		return Vector2i.ZERO
	return _view.hex_at(_camera.position)


func _on_view_changed(_zoom_val: float, _visible_rect: Rect2) -> void:
	_apply_zoom()


func _apply_zoom() -> void:
	var z := 0.0 if _far_locked else _camera.zoom.x
	_view.visible = _far.apply_zoom(z)
	var grid_layer := _view.layer("grid")
	if grid_layer != null:
		grid_layer.modulate.a = ZoomModel.grid_alpha(_camera.zoom.x, _grid_opacity)


func _process(_delta: float) -> void:
	_apply_zoom()
	if _pending_season != "" and TilesetBuilder.is_loaded(_pending_season):
		set_season(_pending_season)
	if _view.is_swapping():
		_view.swap_step(slice_ms)
	elif is_loading():
		_load_step(slice_ms)
