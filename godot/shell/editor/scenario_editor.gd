## In-editor (@tool) and standalone scenario editor (docs/architecture/m2-build-spec.md section 8.4):
## displays a ScenarioDef over TileMapView + ModeOverlay + Borders + Seeds, edits pins on a TileMapLayer,
## regrows territory live via ScenarioGrowth.grow, writes .tres files, and runs deep validation.
@tool
class_name ScenarioEditor
extends Node2D

signal scenario_changed
signal regrown
signal checked(errors: Array[String])

enum Brush { INSPECT, PIN_COUNTRY, PIN_UNOWNED, ERASE_PIN, SEED_TOWN, SEED_ANCHOR, ERASE_SEED }

const DEFAULT_SCENARIO_PATH := "res://data/scenarios/north_italy_1480.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const MAPS_DIR := "res://data/maps"
const LARGE_MAP_HEXES := 10000
const PIN_SOURCE_ID := ScenarioEditorHelpers.PIN_SOURCE_ID
const UNOWNED_ALT_ID := ScenarioEditorHelpers.UNOWNED_ALT_ID
const OVERLAY_Z := 80
const SEEDS_Z := 88
const PINS_Z := 92
const SEA_COLOUR := Color("#3f7fae")
const TOWN_RADIUS := 7.0
const ANCHOR_RADIUS := 10.0
const SEED_INK := Color(0.08, 0.05, 0.03, 0.9)

@export var scenario: ScenarioDef = null:
	set(value):
		if scenario == value:
			return
		scenario = value
		_override_map = null
		_override_defs = null
		if is_node_ready():
			_reload_all()

@export var mode: MapModes.Mode = MapModes.Mode.OWNER:
	set(value):
		mode = value
		_apply_overlay_mode()
		_sync_ui()

@export var colour_blind := false:
	set(value):
		colour_blind = value
		_refresh_palette_and_visuals()
		_sync_ui()

@export var show_seeds := true:
	set(value):
		show_seeds = value
		_update_seeds_visibility()
		_sync_ui()

@export var live_regrow := true:
	set(value):
		live_regrow = value
		_sync_ui()

@export var inspect_hex := Vector2i(-1, -1):
	set(value):
		inspect_hex = value
		if is_node_ready():
			_update_facts_for(inspect_hex)

@export_multiline var facts := ""
@export var active_brush: Brush = Brush.PIN_COUNTRY
@export var active_country: StringName = &""

@export_tool_button("Regrow") var regrow_action := regrow
@export_tool_button("Write the scenario") var write_action := write
@export_tool_button("Check") var check_action := check

var _defs: GameDefs = null
var _map: MapData = null
var _override_defs: GameDefs = null
var _override_map: MapData = null
var _owner := PackedByteArray()
var _palette := PackedColorArray()
var _grown_costs := PackedInt32Array()
var _pin_coords := Vector2i(3, 0)
var _last_errors: Array[String] = []

var _view: TileMapView = null
var _overlay: ModeOverlay = null
var _seeds: Node2D = null
var _pins: TileMapLayer = null
var _camera: Camera2D = null
var _ui: ScenarioEditorUi = null

var _view_ready := false
var _loaded_map_id := ""
var _suppress_pins := false
var _pan_dragging := false
var _paint_dragging := false
var _last_painted_hex := Vector2i(-9999, -9999)


func _ready() -> void:
	_ensure_children()
	if not Engine.is_editor_hint():
		RenderingServer.set_default_clear_color(SEA_COLOUR)
		_setup_runtime_ui()
		if _camera != null:
			_camera.enabled = true
			_camera.make_current()
	elif _camera != null:
		_camera.enabled = false
	if scenario != null:
		_reload_all()
	if not Engine.is_editor_hint() and _map != null:
		fit_view()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _camera == null or _map == null:
		return
	var dir := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
		- float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
		- float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	if dir != Vector2.ZERO:
		var speed := ZoomModel.PAN_BASE_PX_PER_SEC / maxf(_camera.zoom.x, 0.1)
		_camera.position = ZoomModel.clamp_centre(
			_camera.position + dir.normalized() * speed * delta, map_size()
		)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _map == null:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventPanGesture:
		_pan_by((event as InputEventPanGesture).delta * 20.0)
	elif event is InputEventMagnifyGesture:
		var mag := event as InputEventMagnifyGesture
		_zoom_by_factor(mag.factor, mag.position)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)


## Injects custom `ScenarioDef`, `MapData`, and `GameDefs` (used by tests on fixture maps).
func setup_for(p_scenario: ScenarioDef, p_map: MapData, p_defs: GameDefs) -> void:
	_override_map = p_map
	_override_defs = p_defs
	scenario = p_scenario
	_override_map = p_map
	_override_defs = p_defs
	if is_node_ready():
		_reload_all()


## Reads pins from `Pins`, regrows ownership, and updates `Overlay` and `View` borders live.
func regrow() -> void:
	if scenario == null or _map == null:
		return
	_sync_pins_from_layer()
	var prev := _owner.duplicate()
	_owner = ScenarioGrowth.grow(_map, scenario)
	scenario.owner = _owner
	scenario.map_digest = _map.digest()
	_grown_costs = ScenarioEditorHelpers.compute_growth_costs(_map, scenario)
	_apply_owner_diff(prev)
	_apply_overlay_mode()
	if _seeds != null:
		_seeds.queue_redraw()
	if _map.has(inspect_hex):
		_update_facts_for(inspect_hex)
	_sync_ui()
	regrown.emit()
	scenario_changed.emit()


## Drops redundant pins matching pure growth, saves `scenario` to its `resource_path`, and runs `check()`.
func write() -> void:
	if scenario == null:
		return
	var target := scenario.resource_path
	if target.is_empty():
		facts = "Cannot write: scenario has no resource_path (use write_to(path))"
		print("ScenarioEditor: %s" % facts)
		_sync_ui()
		return
	write_to(target)


## Drops redundant pins, regrows, saves `scenario` to `path`, and runs `check()`.
func write_to(path: String) -> int:
	if scenario == null or _map == null:
		return ERR_UNCONFIGURED
	_sync_pins_from_layer()
	scenario.pins = ScenarioEditorHelpers.filter_non_redundant_pins(_map, scenario)
	_populate_pins_layer()
	var prev := _owner.duplicate()
	_owner = ScenarioGrowth.grow(_map, scenario)
	scenario.owner = _owner
	scenario.map_digest = _map.digest()
	_grown_costs = ScenarioEditorHelpers.compute_growth_costs(_map, scenario)
	_apply_owner_diff(prev)
	var dir_path := path.get_base_dir()
	if not dir_path.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var err := ResourceSaver.save(scenario, path)
	if err != OK:
		facts = "Write failed for %s (error %d)" % [path, err]
		print("ScenarioEditor: %s" % facts)
		_sync_ui()
		return err
	check()
	return OK


## Deep-validates `scenario` against `_map` and `_defs`, placing any problem lines into `facts` and stdout.
func check() -> void:
	if scenario == null or _map == null or _defs == null:
		_last_errors = ["scenario, map, or defs is missing"]
		facts = _last_errors[0]
		print("ScenarioEditor: %s" % facts)
		_update_status(false, "Missing data")
		_sync_ui()
		checked.emit(_last_errors)
		return
	_last_errors = scenario.validate(_map, _defs, true)
	if _last_errors.is_empty():
		facts = ""
		_update_status(true, "Valid (0 issues)")
	else:
		facts = "\n".join(_last_errors)
		for err: String in _last_errors:
			print("ScenarioEditor: %s" % err)
		_update_status(false, "%d issue(s)" % _last_errors.size())
	_sync_ui()
	checked.emit(_last_errors)


## Paints a pin for `tag` (&"" = grey "no one") on `hex` and regrows when `live_regrow` is true.
func paint_pin(hex: Vector2i, tag: StringName) -> void:
	if _pins == null or _map == null or not _map.is_land(hex):
		return
	var alt := pin_alternative_for(tag)
	if alt < 0:
		return
	_pins.set_cell(hex, PIN_SOURCE_ID, _pin_coords, alt)
	if live_regrow:
		regrow()


## Erases any pin cell on `hex` and regrows when `live_regrow` is true.
func erase_pin(hex: Vector2i) -> void:
	if _pins == null or _map == null or not _map.has(hex):
		return
	if _pins.get_cell_source_id(hex) == -1:
		return
	_pins.erase_cell(hex)
	if live_regrow:
		regrow()


## Adds or updates a seed at `hex` (`&"town"` or `&"anchor"`), redraws `Seeds`, and regrows if `live_regrow`.
func set_seed(hex: Vector2i, tag: StringName, kind: StringName = &"town", note: String = "") -> void:
	if scenario == null or _map == null or not _map.is_land(hex):
		return
	if scenario.id_of(tag) <= 0 or (kind != &"town" and kind != &"anchor"):
		return
	var updated := false
	for i: int in scenario.seeds.size():
		var entry: Dictionary = scenario.seeds[i]
		if entry.get("hex", ScenarioDef.NO_HEX) == hex:
			var next_note := note if not note.is_empty() else str(entry.get("note", ""))
			scenario.seeds[i] = {"hex": hex, "tag": tag, "kind": kind, "note": next_note}
			updated = true
			break
	if not updated:
		scenario.seeds.append({"hex": hex, "tag": tag, "kind": kind, "note": note})
	if _seeds != null:
		_seeds.queue_redraw()
	if live_regrow:
		regrow()


## Removes any seed at `hex`, redraws `Seeds`, and regrows if `live_regrow`.
func erase_seed(hex: Vector2i) -> void:
	if scenario == null:
		return
	var next: Array[Dictionary] = []
	var removed := false
	for entry: Dictionary in scenario.seeds:
		if entry.get("hex", ScenarioDef.NO_HEX) == hex:
			removed = true
			continue
		next.append(entry)
	if not removed:
		return
	scenario.seeds = next
	if _seeds != null:
		_seeds.queue_redraw()
	if live_regrow:
		regrow()


## Applies `active_brush` with `active_country` at `hex` and inspects it.
func apply_brush(hex: Vector2i) -> void:
	if _map == null or not _map.has(hex):
		return
	match active_brush:
		Brush.INSPECT:
			pass
		Brush.PIN_COUNTRY:
			if active_country != &"":
				paint_pin(hex, active_country)
		Brush.PIN_UNOWNED:
			paint_pin(hex, &"")
		Brush.ERASE_PIN:
			erase_pin(hex)
		Brush.SEED_TOWN:
			if active_country != &"":
				set_seed(hex, active_country, &"town")
		Brush.SEED_ANCHOR:
			if active_country != &"":
				set_seed(hex, active_country, &"anchor")
		Brush.ERASE_SEED:
			erase_seed(hex)
	inspect_hex = hex


func set_active_brush(brush_id: int) -> void:
	active_brush = clampi(brush_id, 0, Brush.ERASE_SEED) as Brush
	_sync_ui()


func set_active_country(tag: StringName) -> void:
	active_country = tag
	_sync_ui()


## Fits the whole map inside the unobstructed runtime viewport area.
func fit_view() -> void:
	if _camera == null or _map == null:
		return
	var msize := map_size()
	var vp := _free_view_size()
	var avail := vp - Vector2(344.0, 68.0) if (_ui != null and vp.x > 640.0 and vp.y > 240.0) else vp
	var z := ZoomModel.fit_zoom(avail, msize)
	_camera.zoom = Vector2(z, z)
	var offset_px := Vector2(168.0, -30.0) / z if (_ui != null and vp.x > 640.0 and vp.y > 240.0) else Vector2.ZERO
	_camera.position = msize * 0.5 + offset_px


func map_size() -> Vector2:
	if _map == null:
		return Vector2.ZERO
	return Vector2(
		(float(_map.cols) + 0.5) * float(MapTiles.CELL.x),
		float(_map.rows) * MapTiles.ROW + float(MapTiles.CELL.y) - MapTiles.ROW
	)


func defs() -> GameDefs:
	return _defs


func map_data() -> MapData:
	return _map


func view() -> TileMapView:
	return _view


func overlay() -> ModeOverlay:
	return _overlay


func seeds_layer() -> Node2D:
	return _seeds


func pins_layer() -> TileMapLayer:
	return _pins


func camera() -> Camera2D:
	return _camera


func last_check_errors() -> Array[String]:
	return _last_errors.duplicate()


func owner_at(hex: Vector2i) -> int:
	if _map == null or not _map.has(hex):
		return 0
	var idx := _map.index_of(hex)
	return int(_owner[idx]) if idx >= 0 and idx < _owner.size() else 0


func pin_tile_coords() -> Vector2i:
	return _pin_coords


## Alternative tile id on `Pins` for `tag` (0 for &"" "no one", country id 1..N for listed tags, -1 if unlisted).
func pin_alternative_for(tag: StringName) -> int:
	if tag == &"":
		return UNOWNED_ALT_ID
	if scenario == null:
		return -1
	var cid := scenario.id_of(tag)
	return cid if cid > 0 else -1


func _ensure_children() -> void:
	_view = get_node_or_null("View") as TileMapView
	if _view == null:
		_view = TileMapView.new()
		_view.name = "View"
		add_child(_view)
	_overlay = get_node_or_null("Overlay") as ModeOverlay
	if _overlay == null:
		_overlay = ModeOverlay.new()
		_overlay.name = "Overlay"
		add_child(_overlay)
	_overlay.z_index = OVERLAY_Z
	_seeds = get_node_or_null("Seeds") as Node2D
	if _seeds == null:
		_seeds = Node2D.new()
		_seeds.name = "Seeds"
		add_child(_seeds)
	_seeds.z_index = SEEDS_Z
	if not _seeds.draw.is_connected(_draw_seeds):
		_seeds.draw.connect(_draw_seeds)
	_pins = get_node_or_null("Pins") as TileMapLayer
	if _pins == null:
		_pins = TileMapLayer.new()
		_pins.name = "Pins"
		add_child(_pins)
	_pins.z_index = PINS_Z
	if not _pins.changed.is_connected(_on_pins_changed):
		_pins.changed.connect(_on_pins_changed)
	_camera = get_node_or_null("Camera") as Camera2D
	if _camera == null:
		_camera = Camera2D.new()
		_camera.name = "Camera"
		add_child(_camera)


func _setup_runtime_ui() -> void:
	if _ui != null:
		return
	_ui = ScenarioEditorUi.new()
	_ui.name = "EditorUI"
	add_child(_ui)
	_ui.setup(self)


func _reload_all() -> void:
	if scenario == null:
		return
	_defs = _override_defs if _override_defs != null else ResourceLoader.load(DEFS_PATH) as GameDefs
	if _override_map != null:
		_map = _override_map
	elif not scenario.map_id.is_empty():
		var map_path := MAPS_DIR.path_join("%s.tres" % scenario.map_id)
		if ResourceLoader.exists(map_path):
			_map = ResourceLoader.load(map_path) as MapData
	if _defs == null or _map == null:
		return
	live_regrow = _map.hex_count() <= LARGE_MAP_HEXES
	if (active_country == &"" or scenario.id_of(active_country) == 0) and not scenario.countries.is_empty():
		active_country = scenario.countries[0]
	_palette = MapModes.palette_from(scenario.colours(_defs, colour_blind), _defs.unowned_colour)
	_fill_tile_view()
	_rebuild_pins_tileset()
	_populate_pins_layer()
	_owner = PackedByteArray()
	regrow()
	_update_seeds_visibility()
	if not Engine.is_editor_hint():
		fit_view()
	_sync_ui()


func _fill_tile_view() -> void:
	if _view == null or _map == null:
		return
	if not _view_ready:
		var tiles := TilesetBuilder.load_season("summer", false)
		if tiles.tile_set == null:
			tiles.tile_set = TileSet.new()
		_view.setup(tiles)
		_view_ready = true
	if _loaded_map_id == _map.id and _view.cell_count() > 0:
		return
	_loaded_map_id = _map.id
	var wild := MapState.create(_map)
	_view.set_climates(_map.cols, _map.climate)
	_view.begin_fill(
		_map.cols, _map.rows,
		func(hex: Vector2i, names: PackedStringArray) -> void: MapCells.fill_hex(_map, wild, hex, names),
		Vector2i.ZERO, MapCells.LAYERS
	)
	while _view.fill_step(100000):
		pass
	var chunks_y := ceili(float(_map.rows) / float(EdgeLines.CHUNK))
	var chunks_x := ceili(float(_map.cols) / float(EdgeLines.CHUNK))
	for cy: int in chunks_y:
		for cx: int in chunks_x:
			var chunk := Vector2i(cx, cy)
			_view.set_chunk_lines(chunk, EdgeLines.for_chunk(_map, wild, chunk))
	var grid_layer := _view.layer("grid")
	if grid_layer != null:
		grid_layer.visible = true
		grid_layer.modulate.a = 0.45


func _rebuild_pins_tileset() -> void:
	if _pins == null or scenario == null or _defs == null:
		return
	var built := ScenarioEditorHelpers.build_pins_tileset(scenario, _palette)
	_pin_coords = built["coords"] as Vector2i
	_pins.tile_set = built["tile_set"] as TileSet


func _populate_pins_layer() -> void:
	if _pins == null or scenario == null:
		return
	_suppress_pins = true
	_pins.clear()
	for pin: Dictionary in scenario.pins:
		var hv: Variant = pin.get("hex", ScenarioDef.NO_HEX)
		if not (hv is Vector2i):
			continue
		var alt := pin_alternative_for(StringName(pin.get("tag", &"")))
		if alt >= 0:
			_pins.set_cell(hv as Vector2i, PIN_SOURCE_ID, _pin_coords, alt)
	_suppress_pins = false


func _sync_pins_from_layer() -> void:
	if _pins == null or scenario == null:
		return
	var notes: Dictionary[String, String] = {}
	for entry: Dictionary in scenario.pins:
		var hv: Variant = entry.get("hex", ScenarioDef.NO_HEX)
		if hv is Vector2i:
			var h := hv as Vector2i
			notes["%d,%d:%s" % [h.x, h.y, str(entry.get("tag", ""))]] = str(entry.get("note", ""))
	var cells := _pins.get_used_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	var next_pins: Array[Dictionary] = []
	for cell: Vector2i in cells:
		var tag := _pin_tag_at(cell)
		var key := "%d,%d:%s" % [cell.x, cell.y, String(tag)]
		next_pins.append({"hex": cell, "tag": tag, "note": notes.get(key, "")})
	scenario.pins = next_pins


func _pin_tag_at(cell: Vector2i) -> StringName:
	var data := _pins.get_cell_tile_data(cell)
	if data != null:
		return StringName(str(data.get_custom_data("tag")))
	var alt := _pins.get_cell_alternative_tile(cell)
	if alt <= 0 or scenario == null or alt > scenario.countries.size():
		return &""
	return scenario.countries[alt - 1]


func _apply_owner_diff(prev: PackedByteArray) -> void:
	if _overlay == null or _view == null or _map == null:
		return
	var full_rebuild := (
		_overlay.owner_image() == null
		or _overlay.owner_image().get_size() != Vector2i(_map.cols, _map.rows)
		or prev.size() != _owner.size()
	)
	if full_rebuild:
		_overlay.setup_from(_map, _owner, _palette)
		_view.set_borders(_map, _owner, _palette)
		return
	var changed: Array[Vector2i] = []
	for i: int in _owner.size():
		if prev[i] != _owner[i]:
			changed.append(_map.hex_of(i))
	if changed.is_empty():
		return
	_overlay.update_hexes(changed, _owner)
	_view.rebuild_borders(_map, _owner, _palette, changed)


func _refresh_palette_and_visuals() -> void:
	if scenario == null or _defs == null or _map == null:
		return
	_palette = MapModes.palette_from(scenario.colours(_defs, colour_blind), _defs.unowned_colour)
	if _overlay != null:
		_overlay.set_palette_colours(_palette)
	if _view != null and _owner.size() == _map.hex_count():
		_view.set_borders(_map, _owner, _palette)
	_rebuild_pins_tileset()
	_populate_pins_layer()
	if _seeds != null:
		_seeds.queue_redraw()


func _apply_overlay_mode() -> void:
	if _overlay == null:
		return
	_overlay.set_mode(mode)
	_overlay.set_tint(true)


func _update_seeds_visibility() -> void:
	if _seeds != null:
		_seeds.visible = show_seeds


func _on_pins_changed() -> void:
	if _suppress_pins or not live_regrow:
		return
	regrow()


func _draw_seeds() -> void:
	if _seeds == null or scenario == null or _map == null:
		return
	for s: Dictionary in scenario.seeds:
		var hv: Variant = s.get("hex", ScenarioDef.NO_HEX)
		if not (hv is Vector2i):
			continue
		var hex := hv as Vector2i
		if not _map.has(hex):
			continue
		var pos := MapTiles.cell_centre(hex)
		var cid := scenario.id_of(StringName(s.get("tag", &"")))
		var col := _palette[cid] if cid > 0 and cid < _palette.size() else Color.WHITE
		if StringName(s.get("kind", &"")) == &"town":
			_seeds.draw_circle(pos, TOWN_RADIUS + 2.0, SEED_INK)
			_seeds.draw_circle(pos, TOWN_RADIUS, col)
		else:
			_seeds.draw_arc(pos, ANCHOR_RADIUS, 0.0, TAU, 24, SEED_INK, 4.5, true)
			_seeds.draw_arc(pos, ANCHOR_RADIUS, 0.0, TAU, 24, col, 2.5, true)


func _update_facts_for(hex: Vector2i) -> void:
	facts = ScenarioEditorHelpers.format_facts(_map, _defs, scenario, _owner, _grown_costs, hex)
	_sync_ui()


func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	if _ui != null and _ui.covers_point(mb.position) and mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
		_zoom_by_factor(ZoomModel.BASE_NOTCH, mb.position)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
		_zoom_by_factor(1.0 / ZoomModel.BASE_NOTCH, mb.position)
	elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
		_pan_dragging = mb.pressed
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and Input.is_key_pressed(KEY_SPACE):
			_pan_dragging = true
			return
		_paint_dragging = mb.pressed
		if not mb.pressed:
			_pan_dragging = false
			_last_painted_hex = Vector2i(-9999, -9999)
			return
		var hex := MapModes.hex_at_px(get_global_mouse_position())
		_last_painted_hex = hex
		apply_brush(hex)


func _handle_mouse_motion(mm: InputEventMouseMotion) -> void:
	if _pan_dragging:
		_pan_by(-mm.relative / maxf(_camera.zoom.x, 0.1))
		return
	var hex := MapModes.hex_at_px(get_global_mouse_position())
	if _ui != null and _map.has(hex):
		var oid := owner_at(hex)
		var tag_str := String(scenario.tag_of(oid)) if scenario != null and oid > 0 else "none"
		_ui.set_hover_text("Hex (%d, %d) · %s" % [hex.x, hex.y, tag_str])
	if _paint_dragging and hex != _last_painted_hex and _is_pin_brush(active_brush):
		_last_painted_hex = hex
		apply_brush(hex)


func _handle_key(key: InputEventKey) -> void:
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			mode = MapModes.Mode.TERRAIN
		KEY_2:
			mode = MapModes.Mode.OWNER
		KEY_3:
			mode = MapModes.Mode.RELIEF
		KEY_F:
			fit_view()
		KEY_R:
			regrow()
		KEY_S:
			if key.ctrl_pressed or key.meta_pressed:
				write()


func _pan_by(delta_map_px: Vector2) -> void:
	if _camera == null:
		return
	_camera.position = ZoomModel.clamp_centre(_camera.position + delta_map_px, map_size())


func _zoom_by_factor(factor: float, screen_pos: Vector2) -> void:
	if _camera == null or factor <= 0.0:
		return
	var fsize := _free_view_size()
	var old_z := _camera.zoom.x
	var next_z := ZoomModel.clamp_zoom(old_z * factor, fsize, map_size(), 3.0)
	if is_equal_approx(old_z, next_z):
		return
	var anchor := screen_pos - get_viewport_rect().size * 0.5
	_camera.position = ZoomModel.clamp_centre(
		ZoomModel.zoom_about(_camera.position, old_z, next_z, anchor), map_size()
	)
	_camera.zoom = Vector2(next_z, next_z)


func _free_view_size() -> Vector2:
	var vp := get_viewport_rect().size
	return vp if vp.x > 0.0 and vp.y > 0.0 else Vector2(1280.0, 720.0)


func _is_pin_brush(b: Brush) -> bool:
	return b == Brush.PIN_COUNTRY or b == Brush.PIN_UNOWNED or b == Brush.ERASE_PIN


func _sync_ui() -> void:
	if _ui != null:
		_ui.sync_from_editor()


func _update_status(ok: bool, text: String) -> void:
	if _ui != null:
		_ui.set_status(text, ok)
