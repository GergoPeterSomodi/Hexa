## The map scene (docs/architecture/m1-build-spec.md sections 5, 7 and 8; m2-build-spec.md sections 6.1 to 6.5;
## ui-and-controls-spec.md sections 3.1, 3.3, 4.2 to 4.4): the camera, CameraRig, TileMapView, FarMap, ModeOverlay,
## CapitalMarks, MapInput, CountryLabels and MapLabels around Session.game.
## Any HexPanelContract is injected externally by App/Hud (or tests) and is null-safe when running standalone.
class_name MapScene
extends Node2D

signal refused(reason: String)
signal selection_changed(hex: Vector2i)
signal season_changed(season_name: String)
signal hud_toggle_requested
signal country_clicked(tag: StringName)
signal country_hovered(tag: StringName)
signal mode_changed(mode: int)
signal map_mode_refused(mode: int)
signal country_requested
signal find_place_requested
## U with a selection: the App opens the works card for the hex's upgrade (or its first build), or begins the work at once
## by game/confirm_works (docs/architecture/m4-build-spec.md 6.1, 6.12). With no listener the scene begins the upgrade itself.
signal upgrade_requested

const MAP_ID := "north_italy"
const START_SEED := 1480
const NO_HEX := Vector2i(-9999, -9999)
const SEA_COLOUR := Color("#3f7fae")
const START_SEASON := MapSeasons.START_SEASON
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
## Texture quality ("full" or "half"): half loads 0.5x atlases scaled x2 in TileMapView.
var texture_quality := "full"
## Frame loading/swap slice budget in milliseconds (configurable via Settings "dev/slice_ms").
var slice_ms := SLICE_MS
## Number of border chunk mesh rebuilds performed since ready (for tests).
var border_chunk_rebuilds := 0
## Chunks rebuilt in the most recent border update batch (for tests).
var last_rebuilt_border_chunks: Array[Vector2i] = []

var _seasons := MapSeasons.new(self)
var _line_queue: Array[Vector2i] = []
var _border_queue: Array[Vector2i] = []
var _loading_map: MapData = null
var _loading_state: MapState = null
var _settings: Settings = null
var _grid_visible := false
var _grid_opacity := 1.0
var _far_locked := false
var _panel: HexPanelContract = null

var _mode: MapModes.Mode = MapModes.Mode.TERRAIN
var _persisted_mode: MapModes.Mode = MapModes.Mode.TERRAIN
var _tint_on := true
var _borders_visible := true
var _colour_blind := false
var _active_palette := PackedColorArray()
var _last_hovered_country := &""

@onready var _camera: Camera2D = $Camera
@onready var _rig: CameraRig = $CameraRig
@onready var _view: TileMapView = $View
@onready var _far: FarMap = $Far
@onready var _overlay: ModeOverlay = $Overlay
@onready var _capitals: CapitalMarks = $Capitals
@onready var _input: MapInput = $Input
@onready var _country_labels: CountryLabels = $Names/CountryLabels
@onready var _labels: MapLabels = $Names/Labels
@onready var _fade: SeasonFade = $SeasonFade
@onready var _work_marks: WorkMarks = $WorkMarks
@onready var _preview: PreviewMarks = $PreviewMarks


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
	_input.hover_changed.connect(_on_hover_changed)
	_input.mode_requested.connect(_on_mode_requested)
	_input.country_requested.connect(_on_country_requested)
	_input.find_place_requested.connect(_on_find_place_requested)
	_input.new_seed_requested.connect(new_seed)
	_input.grid_toggled.connect(toggle_grid)
	_input.names_toggled.connect(toggle_names)
	_input.hud_toggled.connect(func() -> void: hud_toggle_requested.emit())
	_input.upgrade_requested.connect(_on_upgrade_key)
	_fade.world = self
	_view.setup(_seasons.open())
	_preview.setup(_view)
	_set_grid_visible(_grid_visible)
	_far.visible = false
	Events.hex_changed.connect(_on_hex_changed)
	Events.game_started.connect(_on_game_started)
	Events.owners_changed.connect(_on_owners_changed)
	Events.country_chosen.connect(_on_country_chosen)
	Events.season_ended.connect(_on_season_ended)
	for sig: Signal in [Events.work_started, Events.work_finished, Events.work_cancelled, Events.tax_set]:
		sig.connect(_on_yields_event)
	if _settings != null:
		_apply_settings(_settings)
	if Session.game == null:
		Session.new_game(map_id, start_seed)
	else:
		_on_game_started()
	add_child(MapPeople.new()); add_child(MapArmies.new()); add_child(MapWars.new())  # after the game's first fill: the people relay the plates, the armies draw, the wars mark
	if _settings != null: ($MapArmies as MapArmies).set_path_look(str(_settings.get_value("map/path_look")))
	_seasons.request_next()


func _exit_tree() -> void:
	for pair: Array in [[Events.hex_changed, _on_hex_changed], [Events.game_started, _on_game_started],
			[Events.owners_changed, _on_owners_changed], [Events.country_chosen, _on_country_chosen],
			[Events.season_ended, _on_season_ended]]:
		if (pair[0] as Signal).is_connected(pair[1] as Callable):
			(pair[0] as Signal).disconnect(pair[1] as Callable)
	for sig: Signal in [Events.work_started, Events.work_finished, Events.work_cancelled, Events.tax_set]:
		if sig.is_connected(_on_yields_event):
			sig.disconnect(_on_yields_event)
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
	set_borders(bool(settings.get_value("map/borders")))
	set_tint(bool(settings.get_value("map/owner_tint")))
	set_colour_blind(str(settings.get_value("accessibility/country_colours")) == "colour_blind"); _overlay.set_sight_veil(bool(settings.get_value("map/sight_veil")))
	_persisted_mode = _mode_from_string(str(settings.get_value("state/map_mode")))
	if not picking() and Session.game != null:
		_apply_mode(_clamp_mode_for_game(_persisted_mode), false)
	var shading := bool(settings.get_value("graphics/relief_shading"))
	_view.set_layer_visible("shade", shading)
	_view.set_layer_visible("light", shading)
	preload_next_season = bool(settings.get_value("graphics/preload_next_season"))
	_preview.set_enabled(bool(settings.get_value("game/preview_on_map")))
	var next_quality := str(settings.get_value("graphics/texture_quality"))
	if next_quality != texture_quality:
		texture_quality = next_quality
		_reload_season_quality()
	_far.set_zoom_switch(float(settings.get_value("dev/far_zoom")))
	slice_ms = clampf(float(settings.get_value("dev/slice_ms")), 2.0, 16.0)
	_rig.configure(settings)
	_input.configure(settings)
	if has_node("MapArmies"): ($MapArmies as MapArmies).set_path_look(str(settings.get_value("map/path_look")))
	_apply_zoom()


func _on_setting_changed(key: String, value: Variant) -> void:
	if _settings == null or not is_node_ready():
		return
	match key:
		"map/borders":
			set_borders(bool(value))
			return
		"map/owner_tint":
			set_tint(bool(value))
			return
		"accessibility/country_colours":
			set_colour_blind(str(value) == "colour_blind")
			return
		"state/map_mode":
			_persisted_mode = _mode_from_string(str(value))
			if not picking() and Session.game != null:
				_apply_mode(_clamp_mode_for_game(_persisted_mode), false)
			return
	if key in [
		"map/grid", "map/grid_opacity", "map/place_names", "map/sight_veil",
		"graphics/relief_shading", "graphics/preload_next_season", "graphics/texture_quality",
		"dev/far_zoom", "dev/slice_ms", "game/preview_on_map", "map/path_look"
	]:
		_apply_settings(_settings)


func _disconnect_settings() -> void:
	if _settings != null and _settings.changed.is_connected(_on_setting_changed):
		_settings.changed.disconnect(_on_setting_changed)
	_settings = null


# ----- the game's side ----------------------------------------------------------------------------------------------


## A game began: every layer is filled again from the game's map and state, the far picture rebuilt, the selection gone.
func _on_game_started() -> void:
	var game := Session.game
	var map := game.map
	var state := game.state
	select_hex(NO_HEX)
	_last_hovered_country = &""
	_seasons.game_started()
	_work_marks.setup(game)
	_preview.clear_marks()
	_labels.setup(map, MapLabels.capitals_from(game))
	_view.set_climates(map.cols, map.climate)
	_view.begin_fill(map.cols, map.rows, func(hex: Vector2i, names: PackedStringArray) -> void: MapCells.fill_hex(map, state, hex, names),
		_hex_under_camera(), MapCells.LAYERS)
	_view.set_process(false)  # the scene slices the fill by time (_load_step)
	_loading_map = map
	_loading_state = state
	_line_queue.clear()
	_border_queue.clear()
	_enqueue_all_chunks(_line_queue, map)
	if game.has_countries():
		_enqueue_all_chunks(_border_queue, map)
	_setup_country_layers(game)
	_far.begin(map, state)
	_rig.set_map_size(map_size())
	fit()
	if map.hex_count() <= SYNC_LOAD_HEXES:
		finish_loading()


func _setup_country_layers(game: Game) -> void:
	_overlay.setup(game, _colour_blind)
	_overlay.set_tint(_tint_on)
	_overlay.set_hot(0)
	if game.has_countries():
		_active_palette = MapModes.palette(game, _colour_blind)
		_country_labels.setup(game)
		_capitals.setup(game, _colour_blind)
		_view.set_borders_visible(_borders_visible)
		var start_mode := MapModes.Mode.OWNER if picking() else _saved_mode_from_settings()
		_apply_mode(_clamp_mode_for_game(start_mode), false)
	else:
		_active_palette = PackedColorArray()
		_country_labels.setup(null)
		_capitals.setup(null, _colour_blind)
		_view.set_borders_visible(false)
		_apply_mode(_clamp_mode_for_game(_saved_mode_from_settings()), false)


## Whether the map is still being put on the view (tiles, lines, borders, the far picture).
func is_loading() -> bool:
	return _view.is_filling() or not _line_queue.is_empty() or not _border_queue.is_empty() or _far.is_building()


func fill_progress() -> float:
	return _view.fill_progress()


## Does all the loading now (a small map, a test, a tool).
func finish_loading() -> void:
	_far.step(1.0e9)
	while _view.fill_step(100000):
		pass
	_line_step(1.0e9)
	_border_step(1.0e9)


## Up to `budget_ms` of loading: the far picture first, then tiles nearest camera, then lines, then borders.
func _load_step(budget_ms: float) -> void:
	var until := SimClock.usec() + int(budget_ms * 1000.0)
	if _far.is_building():
		_far.step(budget_ms)
	if _view.is_filling():
		_view.fill_for(float(until - SimClock.usec()) / 1000.0)
	if SimClock.usec() < until and not _line_queue.is_empty():
		_line_step(float(until - SimClock.usec()) / 1000.0)
	if SimClock.usec() < until and not _border_queue.is_empty():
		_border_step(float(until - SimClock.usec()) / 1000.0)


## Builds the lines of the queued chunks, one at least, until the time is up.
func _line_step(budget_ms: float) -> void:
	var until := SimClock.usec() + int(budget_ms * 1000.0)
	while not _line_queue.is_empty():
		var chunk: Vector2i = _line_queue.pop_front()
		_view.set_chunk_lines(chunk, EdgeLines.for_chunk(_loading_map, _loading_state, chunk))
		if SimClock.usec() >= until:
			break


## Builds the borders of the queued chunks, one at least, until the time is up.
func _border_step(budget_ms: float) -> void:
	if _loading_map == null or _loading_state == null:
		_border_queue.clear()
		return
	var until := SimClock.usec() + int(budget_ms * 1000.0)
	while not _border_queue.is_empty():
		var chunk: Vector2i = _border_queue.pop_front()
		_view.set_chunk_borders(chunk, BorderLines.for_chunk(_loading_map, _loading_state.owner, chunk, _active_palette))
		border_chunk_rebuilds += 1
		last_rebuilt_border_chunks.append(chunk)
		if SimClock.usec() >= until:
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
		&"borders":
			set_borders(on)
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


## Land changed owner: updates touched overlay texels, touched border chunks, country labels, and pennants.
func _on_owners_changed(hexes: Array[Vector2i]) -> void:
	if Session.game == null or Session.game.map == null or Session.game.state == null:
		return
	var map := Session.game.map
	if Session.game.has_countries():
		_overlay.update_hexes(hexes)
		_overlay.sync_modes(Session.game)
		var touched := BorderLines.chunks_touched(map, hexes)
		last_rebuilt_border_chunks.clear()
		for chunk: Vector2i in touched:
			if not _border_queue.has(chunk):
				_border_queue.append(chunk)
		_loading_map = map
		_loading_state = Session.game.state
		var budget := 1.0e9 if map.hex_count() <= SYNC_LOAD_HEXES else slice_ms
		_border_step(budget)
		_country_labels.on_owners_changed(hexes)
		_labels.set_obstacles(_country_labels.obstacles())
		_capitals.refresh()
	if _panel != null and _panel.shown_hex() != NO_HEX:
		_panel.refresh()


func _on_season_ended(_turn: int) -> void:
	_seasons.season_ended()


## Works and taxes change a hex's worth: the Yields and Food textures follow (only in their modes).
func _on_yields_event(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
	_overlay.sync_modes(Session.game)


## The player picked a country: ends picking highlight/pennants and restores the remembered map mode.
func _on_country_chosen(_tag: StringName) -> void:
	_last_hovered_country = &""
	_overlay.set_hot(0)
	_capitals.set_picking(false)
	_country_labels.set_picking(false)
	var restored := _clamp_mode_for_game(_saved_mode_from_settings())
	_apply_mode(restored, false)
	if _panel != null and _panel.shown_hex() != NO_HEX:
		_panel.refresh()


## A new seed: the same map or scenario, the next seed.
func new_seed() -> void:
	if Session.game == null:
		return
	if Session.game.has_countries():
		Session.reseed()
	else:
		Session.new_game(map_id, Session.game.seed_value + 1)


## The U key: the App's route (a card or a confirmed work); a scene on its own (no App) begins the upgrade directly.
func _on_upgrade_key() -> void:
	if upgrade_requested.get_connections().is_empty():
		upgrade_selected()
	else:
		upgrade_requested.emit()


## Begins the selected hex's upgrade through Session at once, with no card: the standalone path (the App answers
## upgrade_requested instead, so game/confirm_works holds; see WorksFlow).
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


# ----- modes, borders, tint, picking --------------------------------------------------------------------------------


## True when a scenario game with countries is active and the player has not yet chosen a country.
func picking() -> bool:
	return Session.game != null and Session.game.has_countries() and Session.game.player == &"" and not Session.game.ai_only


## Returns the active MapModes.Mode integer value.
func mode() -> int:
	return int(_mode)


## Switches map mode. A mode not in `MapModes.modes(game)` is ignored. Writes `state/map_mode` unless picking.
func set_mode(value: int) -> void:
	if not MapModes.modes(Session.game).has(value):
		return
	_apply_mode(value as MapModes.Mode, not picking())


## Shows or hides Terrain-mode owner tinting.
func set_tint(on: bool) -> void:
	_tint_on = on
	if _overlay != null:
		_overlay.set_tint(_tint_on)


## Shows or hides country border meshes.
func set_borders(on: bool) -> void:
	_borders_visible = on
	if _view != null:
		var has_c := Session.game != null and Session.game.has_countries()
		_view.set_borders_visible(_borders_visible and has_c)


## Switches overlay, pennants, and borders between standard and colour-blind safe palettes.
func set_colour_blind(on: bool) -> void:
	if on == _colour_blind:
		return
	_colour_blind = on
	if Session.game == null or not Session.game.has_countries():
		return
	_active_palette = MapModes.palette(Session.game, _colour_blind)
	_overlay.set_palette(_colour_blind)
	_capitals.set_colour_blind(_colour_blind)
	_queue_all_borders(Session.game.map)


## Glides the camera smoothly to the middle of `hex`.
func glide_to_hex(hex: Vector2i, new_zoom: float = -1.0, instant: bool = false) -> void:
	if _rig != null and _view != null:
		_rig.look_at(_view.centre_of(hex), new_zoom, instant)


func _on_mode_requested(requested_mode: int) -> void:
	if not MapModes.modes(Session.game).has(requested_mode):
		map_mode_refused.emit(requested_mode)
		if Session.game == null or not Session.game.has_countries():
			refused.emit("No countries on this map")
		return
	set_mode(requested_mode)


func _on_country_requested() -> void:
	if Session.game == null or not Session.game.has_countries():
		refused.emit("No countries on this map")
		return
	country_requested.emit()


func _on_find_place_requested() -> void:
	find_place_requested.emit()


func _apply_mode(target: MapModes.Mode, persist: bool) -> void:
	var changed := _mode != target
	_mode = target
	if _overlay != null:
		_overlay.set_mode(_mode)
		_overlay.sync_modes(Session.game, true)
	var is_picking := picking()
	if _capitals != null:
		_capitals.set_picking(is_picking)
		_capitals.set_mode(_mode)
	if _country_labels != null:
		_country_labels.set_picking(is_picking)
		_country_labels.set_mode(_mode)
	_sync_country_labels()
	if persist:
		_persisted_mode = _mode
		if _settings != null:
			var mode_str := _mode_to_string(_mode)
			if str(_settings.get_value("state/map_mode")) != mode_str:
				_settings.set_value("state/map_mode", mode_str)
	if changed:
		mode_changed.emit(int(_mode))


func _queue_all_borders(map: MapData) -> void:
	if map == null:
		return
	_border_queue.clear()
	last_rebuilt_border_chunks.clear()
	_enqueue_all_chunks(_border_queue, map)
	_loading_map = map
	_loading_state = Session.game.state if Session.game != null else null
	if map.hex_count() <= SYNC_LOAD_HEXES:
		_border_step(1.0e9)


static func _enqueue_all_chunks(queue: Array[Vector2i], map: MapData) -> void:
	var chunks_y := ceili(float(map.rows) / EdgeLines.CHUNK)
	var chunks_x := ceili(float(map.cols) / EdgeLines.CHUNK)
	for chunk_y: int in chunks_y:
		for chunk_x: int in chunks_x:
			queue.append(Vector2i(chunk_x, chunk_y))


func _saved_mode_from_settings() -> MapModes.Mode:
	if _settings != null:
		return _mode_from_string(str(_settings.get_value("state/map_mode")))
	return _persisted_mode


func _clamp_mode_for_game(candidate: MapModes.Mode) -> MapModes.Mode:
	return candidate if MapModes.modes(Session.game).has(int(candidate)) else MapModes.Mode.TERRAIN


static func _mode_from_string(name: String) -> MapModes.Mode:
	return maxi(MapModes.mode_of(StringName(name)), 0) as MapModes.Mode


static func _mode_to_string(m: MapModes.Mode) -> String:
	return String(MapModes.MODE_KEYS[int(m)])


# ----- selection & picking ------------------------------------------------------------------------------------------


func _on_select_requested(map_px: Vector2) -> void:
	var hex := _view.hex_at(map_px)
	if picking():
		var tag := Territory.owner_tag(Session.game, hex)
		if tag != &"":
			country_clicked.emit(tag)
		return
	select_hex(hex)


func _on_command_requested(map_px: Vector2) -> void:
	if picking():
		return
	if not ($MapArmies as MapArmies).command(_view.hex_at(map_px)): select_hex(NO_HEX)


func _on_hover_changed(hex: Vector2i) -> void:
	if not picking():
		if _last_hovered_country != &"":
			_last_hovered_country = &""
			_overlay.set_hot(0)
			country_hovered.emit(&"")
		return
	var oid := Territory.owner_id(Session.game, hex)
	var tag := Territory.owner_tag(Session.game, hex)
	_overlay.set_hot(oid)
	if tag != _last_hovered_country:
		_last_hovered_country = tag
		country_hovered.emit(tag)


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


func is_half_textures() -> bool:
	return texture_quality == "half"


func _reload_season_quality() -> void:
	if _view != null:
		_seasons.reload_quality()


## Swaps the TileSet to the named season, no cell written (MapSeasons has the slicing and the preload).
func set_season(value: String) -> void:
	_seasons.set_season(value)


## A card's preview on the map (ImprovePreview's dictionary: ghost, map_marks); PreviewMarks draws it (nothing when the
## setting game/preview_on_map is off).
func show_preview(card: Dictionary) -> void:
	_preview.show_preview(card)


func clear_marks() -> void:
	_preview.clear_marks()


## The calendar's season (0 Spring to 3 Winter) with the fade when `fade`; ignored while a look preview is on.
func show_season(index: int, fade: bool) -> void:
	_fade.reduce_motion = _settings != null and bool(_settings.get_value("accessibility/reduce_motion"))
	_seasons.show_season(index, fade)


## F3's Look: 0 to 3 a season, -1 back to the calendar's; it ends at the next season_ended.
func preview_season(index: int) -> void:
	_seasons.preview(index)


func is_swapping() -> bool:
	return _view.is_swapping()


## Does the rest of a season swap now.
func finish_swap() -> void:
	_view.swap_step(1.0e9)


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
	_sync_country_labels()


## A view centred on a map pixel at a zoom (1 = the art's size).
func frame_at(centre: Vector2, zoom_val: float) -> void:
	_rig.set_map_size(map_size())
	_rig.frame_at(centre, zoom_val)
	_apply_zoom()
	_sync_country_labels()


func zoom() -> float: return _camera.zoom.x
func view() -> TileMapView: return _view
func far() -> FarMap: return _far
func overlay() -> ModeOverlay: return _overlay
func capital_marks() -> CapitalMarks: return _capitals
func country_labels() -> CountryLabels: return _country_labels
func panel() -> HexPanelContract: return _panel
func labels() -> MapLabels: return _labels
func work_marks() -> WorkMarks: return _work_marks
func preview_marks() -> PreviewMarks: return _preview
func season_fade() -> SeasonFade: return _fade
func camera() -> Camera2D: return _camera
func camera_rig() -> CameraRig: return _rig
func map_input() -> MapInput: return _input


## The hexes the camera sees: the replay's focus (M8 6.3; the public form of MapSeasons' view rect).
func view_hexes() -> Rect2i:
	var half := get_viewport_rect().size / (2.0 * _camera.zoom.x)
	var low := _view.hex_at(_camera.position - half)
	return Rect2i(low, _view.hex_at(_camera.position + half) - low + Vector2i.ONE).abs()


## The country pick is over (the console's watch): the pick's marks go and the remembered mode returns.
func end_pick() -> void:
	_on_country_chosen(&"")


func _hex_under_camera() -> Vector2i:
	if _camera == null or not is_inside_tree():
		return Vector2i.ZERO
	return _view.hex_at(_camera.position)


func _on_view_changed(_zoom_val: float, _visible_rect: Rect2) -> void:
	_apply_zoom()
	_sync_country_labels()


## The HUD's covering rects (Hud.cover_rects): country names keep clear of them.
func set_screen_cover(rects: Array[Rect2]) -> void:
	if _country_labels != null and _labels != null:
		_country_labels.set_cover(rects)
		_labels.set_obstacles(_country_labels.obstacles())


func _sync_country_labels() -> void:
	MapLabelSync.sync(_country_labels, _labels, _camera, get_viewport_rect().size if is_inside_tree() else Vector2.ZERO)


func _apply_zoom() -> void:
	var z := 0.0 if _far_locked else _camera.zoom.x
	_view.visible = _far.apply_zoom(z)
	_work_marks.set_zoom(_camera.zoom.x)
	_preview.set_zoom(_camera.zoom.x)
	var grid_layer := _view.layer("grid")
	if grid_layer != null:
		grid_layer.modulate.a = ZoomModel.grid_alpha(_camera.zoom.x, _grid_opacity)


func _process(_delta: float) -> void:
	_apply_zoom()
	_overlay.sync_discovered(Session.game)  # R36: the deep fog follows the explored set (one compare while it holds)
	if _seasons.tick():
		return
	if is_loading():
		_load_step(slice_ms)
