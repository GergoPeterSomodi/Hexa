## The map scene (docs/architecture/m1-build-spec.md sections 5, 7 and 8): the camera, the tile view, the far picture, the
## input and the hex panel, around a Game that Session holds. North Italy opens on tiles. The scene holds no facts: the
## tile of every hex is MapCells.of_hex of the game's map and state; a change comes in as Events.hex_changed and redraws
## the hex and its six neighbours only (MapCells.touched_by); the player changes the game only through Session.act.
##
## Keys (MapInput): 1 to 4 the season, R a new seed, G the grid, F the whole map, H the panel, U upgrade the selected hex,
## Esc or a right click clears the selection; drag or WASD to move, the wheel to zoom. Below zoom 0.25 the far picture
## fades in over the tiles and below 0.20 it replaces them.
class_name MapScene
extends Node2D

const MAP_ID := "north_italy"
const START_SEED := 1480
const NO_HEX := Vector2i(-9999, -9999)
const SEA_COLOUR := Color("#3f7fae")
const START_SEASON := "summer"
const SELECT_TILE := "mark/select"
## A map of at most this many hexes is loaded at once when the game starts; a larger one a slice a frame.
const SYNC_LOAD_HEXES := 4000
## Milliseconds a frame the loading and a season swap may use (a layer or a chunk is never split, so one can pass it).
const SLICE_MS := 8.0
## Hexes a step of the sliced fill (the view's own is 4,000 a frame, about 100 ms on a big map).
const FILL_STEP := 120
const HELP := "1-4 season   R new seed   G grid   F whole map   H hide   U upgrade   Esc clear\nclick a hex   drag or WASD move   wheel zoom"

## The map the scene shows (a Session.new_game id); a tool may set it before the scene enters the tree.
var map_id := MAP_ID
var start_seed := START_SEED
var season := START_SEASON
## The selected hex, or NO_HEX.
var selected := NO_HEX
## Ask for the next season's pictures a moment ahead (a swap then does not wait for the disk).
var preload_next_season := true

var _tiles: TilesetBuilder = null
var _fps_clock := 0.0
var _line_queue: Array[Vector2i] = []
var _loading_map: MapData = null
var _loading_state: MapState = null
var _swap_queue: Array[String] = []
var _swap_tiles: TilesetBuilder = null

@onready var _camera: Camera2D = $Camera
@onready var _view: TileMapView = $View
@onready var _far: FarMap = $Far
@onready var _input: MapInput = $Input
@onready var _hud: CanvasLayer = $Hud
@onready var _panel: HexPanelContract = $Hud/Margin/Row/Panel
@onready var _title: Label = $Hud/Margin/Row/Info/Box/Title
@onready var _stats: Label = $Hud/Margin/Row/Info/Box/Stats
@onready var _help: Label = $Hud/Margin/Row/Info/Box/Help


func _ready() -> void:
	RenderingServer.set_default_clear_color(SEA_COLOUR)
	_help.text = HELP
	_input.camera = _camera
	_input.map_node = _view
	_input.select_requested.connect(_on_select_requested)
	_input.clear_selection_requested.connect(select_hex.bind(NO_HEX))
	_input.season_requested.connect(_on_season_requested)
	_input.new_seed_requested.connect(new_seed)
	_input.grid_toggled.connect(toggle_grid)
	_input.fit_requested.connect(fit)
	_input.hud_toggled.connect(func() -> void: _hud.visible = not _hud.visible)
	_input.upgrade_requested.connect(upgrade_selected)
	_tiles = TilesetBuilder.load_season(season)
	if _tiles.tile_set == null:
		push_warning("map scene: %s (bake the tiles and run tools/build_tileset.gd)" % _tiles.error)
		_tiles.tile_set = TileSet.new()
	_view.setup(_tiles)
	_far.visible = false
	Events.hex_changed.connect(_on_hex_changed)
	Events.game_started.connect(_on_game_started)
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


# ----- the game's side ----------------------------------------------------------------------------------------------


## A game began: every layer is filled again from the game's map and state, the far picture rebuilt, the selection gone.
func _on_game_started() -> void:
	var map := Session.game.map
	var state := Session.game.state
	select_hex(NO_HEX)
	_view.set_climates(map.cols, map.climate)
	_view.begin_fill(map.cols, map.rows, func(hex: Vector2i) -> Dictionary: return MapCells.of_hex(map, state, hex),
		_hex_under_camera())
	_view.set_process(false)  # the scene slices the fill by time (_load_step)
	_loading_map = map
	_loading_state = state
	_line_queue.clear()
	for chunk_y: int in ceili(float(map.rows) / EdgeLines.CHUNK):
		for chunk_x: int in ceili(float(map.cols) / EdgeLines.CHUNK):
			_line_queue.append(Vector2i(chunk_x, chunk_y))
	_far.begin(map, state)
	fit()
	if map.hex_count() <= SYNC_LOAD_HEXES:
		finish_loading()


## Whether the map is still being put on the view (tiles, lines, the far picture).
func is_loading() -> bool:
	return _view.is_filling() or not _line_queue.is_empty() or _far.is_building()


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
	while _view.is_filling() and Time.get_ticks_usec() < until:
		_view.fill_step(FILL_STEP)
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


## A hex changed: it and its neighbours are named again and only what differs is written.
func _on_hex_changed(hex: Vector2i) -> void:
	var map := Session.game.map
	var state := Session.game.state
	for touched: Vector2i in MapCells.touched_by(map, hex):
		_view.set_hex(touched, MapCells.of_hex(map, state, touched))
	_far.update_hex(hex)
	if _panel.shown_hex() != NO_HEX:
		_panel.refresh()


## A new seed: the same map, the next seed's improvement.
func new_seed() -> void:
	if Session.game != null:
		Session.new_game(map_id, Session.game.seed_value + 1)


func upgrade_selected() -> Dictionary:
	if selected == NO_HEX:
		return {"ok": false, "reason": "no hex is selected"}
	return Session.act("upgrade", {"hex": selected})


# ----- selection ----------------------------------------------------------------------------------------------------


func _on_select_requested(map_px: Vector2) -> void:
	select_hex(_view.hex_at(map_px))


## Selects a hex of the map (NO_HEX, or a hex off the map, clears the selection): the ring on the marks layer and the panel.
func select_hex(hex: Vector2i) -> void:
	if selected != NO_HEX:
		_view.set_tile("marks", selected, "")
	if hex == NO_HEX or Session.game == null or not Session.game.map.has(hex):
		selected = NO_HEX
		_panel.clear()
		return
	selected = hex
	_view.set_tile("marks", hex, SELECT_TILE)
	_panel.show_hex(hex)


# ----- seasons, grid, camera ----------------------------------------------------------------------------------------


func _on_season_requested(index: int) -> void:
	set_season(TilesetBuilder.SEASONS[clampi(index, 0, TilesetBuilder.SEASONS.size() - 1)])


## Swaps the season: the TileSet of every layer is replaced and no cell is written. Godot rebuilds a layer when its TileSet
## changes (about 1 ms a thousand cells), so a big map is swapped a few layers a frame (SLICE_MS); a small one in one frame.
func set_season(value: String) -> void:
	if value == season or not TilesetBuilder.SEASONS.has(value):
		return
	var tiles := TilesetBuilder.load_season(value)
	if tiles.tile_set == null:
		push_warning("map scene: %s" % tiles.error)
		return
	season = value
	_tiles = tiles
	_swap_tiles = tiles
	_swap_queue.clear()
	for layer_name: String in TileMapView.LAYERS:
		_swap_queue.append(layer_name)
	for layer_name: String in TileMapView.OVERLAYS:
		_swap_queue.append(layer_name)
	_swap_step(SLICE_MS)
	_request_next_season()


func is_swapping() -> bool:
	return not _swap_queue.is_empty()


## Does the rest of a season swap now.
func finish_swap() -> void:
	_swap_step(1.0e9)


func _swap_step(budget_ms: float) -> void:
	if _swap_tiles == null:
		return
	var until := Time.get_ticks_usec() + int(budget_ms * 1000.0)
	while not _swap_queue.is_empty():
		var layer_name: String = _swap_queue.pop_front()
		var layer := _view.layer(layer_name)
		layer.tile_set = _swap_tiles.tile_set
		layer.update_internals()  # the rebuild happens here, inside the slice, not at the end of the frame
		if Time.get_ticks_usec() >= until:
			break
	if _swap_queue.is_empty():
		_view.set_season(_swap_tiles)  # the layers have it: this only tells the view
		_swap_tiles = null


## The next season in the year's order is loaded on another thread, so the usual swap is quick.
func _request_next_season() -> void:
	if not preload_next_season or DisplayServer.get_name() == "headless":
		return
	var seasons := TilesetBuilder.SEASONS
	TilesetBuilder.request_season(seasons[(seasons.find(season) + 1) % seasons.size()])


func toggle_grid() -> void:
	_view.set_layer_visible("grid", not _view.layer("grid").visible)


func set_hud_visible(value: bool) -> void:
	_hud.visible = value


## The map's size in px.
func map_size() -> Vector2:
	var map := Session.game.map
	return Vector2((float(map.cols) + 0.5) * MapTiles.CELL.x, float(map.rows) * MapTiles.ROW + MapTiles.CELL.y - MapTiles.ROW)


## The whole map in the window.
func fit() -> void:
	var view := get_viewport_rect().size
	var size := map_size()
	var zoom := minf(view.x / size.x, view.y / size.y) * 0.96
	frame_at(size / 2.0, zoom)


## A view centred on a map pixel at a zoom (1 = the art's size).
func frame_at(centre: Vector2, zoom: float) -> void:
	var z := clampf(zoom, MapInput.ZOOM_MIN, MapInput.ZOOM_MAX)
	_camera.zoom = Vector2(z, z)
	_camera.position = centre
	_camera.force_update_scroll()
	_apply_zoom()


func zoom() -> float:
	return _camera.zoom.x


func view() -> TileMapView:
	return _view


func far() -> FarMap:
	return _far


func panel() -> HexPanelContract:
	return _panel


func camera() -> Camera2D:
	return _camera


func _hex_under_camera() -> Vector2i:
	if _camera == null or not is_inside_tree():
		return Vector2i.ZERO
	return _view.hex_at(_camera.position)


func _apply_zoom() -> void:
	_view.visible = _far.apply_zoom(_camera.zoom.x)


func _process(delta: float) -> void:
	_apply_zoom()
	if _swap_tiles != null:
		_swap_step(SLICE_MS)
	elif is_loading():
		_load_step(SLICE_MS)
	_fps_clock += delta
	if _fps_clock >= 0.5:
		_fps_clock = 0.0
		_title.text = "North Italy" if map_id == MAP_ID else map_id.capitalize()
		var game := Session.game
		_stats.text = "%s, seed %d, zoom %.2f\n%d frames a second%s" % [season, game.seed_value if game != null else 0,
			_camera.zoom.x, int(Engine.get_frames_per_second()),
			"\nfilling %d%%" % int(_view.fill_progress() * 100.0) if _view.is_filling() else ""]
