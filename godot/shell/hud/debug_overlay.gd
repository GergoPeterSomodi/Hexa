## Studiolo F3 developer debug overlay showing engine, render, memory, camera, view, and game metrics
## plus diagnostic controls emitting typed intents (docs/architecture/ui-and-controls-spec.md section 7;
## ui-style-and-feedback-plan.md U14).
class_name DebugOverlay
extends PanelContainer

signal season_preview_requested(index: int)
signal new_seed_requested
signal debug_layer_toggled(layer_name: StringName, on: bool)
signal far_zoom_changed(value: float)
signal slice_ms_changed(ms: int)

const REFRESH_INTERVAL_SEC: float = 0.25
const SEASON_NAMES: Array[String] = ["spring", "summer", "autumn", "winter"]
const SEASON_LABELS: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
## The Look control: the calendar (-1) and the four seasons.
const LOOK_CALENDAR := -1
## The word for each weather kind (0 calm, 1 good, 2 poor) in the economy line.
const WEATHER_WORDS: Array[String] = ["calm", "good", "poor"]
const MODE_WORDS: Array[String] = ["Terrain", "Owner", "Relief", "Yields", "Food", "Supply"]
const LAYER_SPECS: Array[Array] = [
	[&"grid", "Grid"],
	[&"shade", "Shade"],
	[&"light", "Light"],
	[&"trees", "Trees"],
	[&"lines", "Lines"],
	[&"far_locked", "Far lock"],
]

@onready var _metrics_label: Label = $VBox/Metrics
@onready var _m3_label: Label = $VBox/M3Line
@onready var _m4_label: Label = $VBox/M4Line
var _army_label: Label = null
@onready var _console: DevConsole = $VBox/DevConsole
@onready var _season_seg: Segmented = $VBox/SeasonSeg
@onready var _new_seed_btn: KitButton = $VBox/ControlsTop/NewSeedButton
@onready var _layers_grid: GridContainer = $VBox/LayersGrid
@onready var _far_zoom_slider: KitSlider = $VBox/FarZoomRow/Slider
@onready var _slice_ms_slider: KitSlider = $VBox/SliceRow/Slider

var _switches: Dictionary[StringName, KitSwitch] = {}
var _settings: Settings = null
var _map_scene: Node = null
var _snapshot: Dictionary = {}
var _refresh_clock: float = 0.0
var _worst_clock: float = 0.0
var _worst_frame_ms: float = 0.0
var _syncing: bool = false
var _season_index: int = LOOK_CALENDAR
var _save_ms: float = -1.0
## The App's answer to "what did the study last build": () -> {page, tab, ms, warm}; {} (or unset) before a first open.
var study_info_func: Callable = Callable()
var _study_label: Label = null
## The M5 people line (spec 6.10) and what it counts: the levels changed in the last season played.
var _people_label: Label = null
var _grew_now: int = 0
var _declined_now: int = 0
var _grew_last: int = 0
var _declined_last: int = 0
var _hovered_hex: Vector2i = MapInput.NO_HEX


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_study_label = Label.new()
	_study_label.theme_type_variation = &"TableRow"
	_study_label.text = "no game"
	_study_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_m4_label.get_parent().add_child(_study_label)
	_m4_label.get_parent().move_child(_study_label, _m4_label.get_index() + 1)

	_people_label = Label.new()
	_people_label.theme_type_variation = &"TableRow"
	_people_label.text = "no game"
	_people_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_m4_label.get_parent().add_child(_people_label)
	_m4_label.get_parent().move_child(_people_label, _m4_label.get_index() + 1)

	_army_label = Label.new()
	_army_label.theme_type_variation = &"TableRow"
	_army_label.text = "no game"
	_army_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_m4_label.get_parent().add_child(_army_label)
	_m4_label.get_parent().move_child(_army_label, _m4_label.get_index() + 1)
	Events.town_grew.connect(_on_town_grew)
	Events.district_declined.connect(_on_district_declined)
	Events.season_ended.connect(_on_season_ended)
	Events.game_started.connect(_on_game_started)

	_season_seg.hud_mode = true
	var season_items: Array[Dictionary] = [{"id": LOOK_CALENDAR, "label": "Calendar"}]
	for i: int in SEASON_LABELS.size():
		season_items.append({"id": i, "label": SEASON_LABELS[i]})
	_season_seg.set_options(season_items)
	_season_seg.select(_season_index, false)
	_season_seg.changed.connect(_on_season_changed)

	_new_seed_btn.focus_mode = Control.FOCUS_NONE
	_new_seed_btn.pressed.connect(func() -> void: new_seed_requested.emit())

	_build_layer_switches()

	_far_zoom_slider.format_int = false
	_far_zoom_slider.set_bounds(0.05, 0.80, 0.01)
	_far_zoom_slider.set_slider_value(0.20, false)
	_far_zoom_slider.slider().focus_mode = Control.FOCUS_NONE
	_far_zoom_slider.value_changed.connect(_on_far_zoom_slider_changed)

	_slice_ms_slider.format_int = true
	_slice_ms_slider.suffix = " ms"
	_slice_ms_slider.set_bounds(2.0, 16.0, 1.0)
	_slice_ms_slider.set_slider_value(5.0, false)
	_slice_ms_slider.slider().focus_mode = Control.FOCUS_NONE
	_slice_ms_slider.value_changed.connect(_on_slice_ms_slider_changed)

	if _settings != null:
		_apply_settings(_settings)
	refresh_metrics()


func _exit_tree() -> void:
	_disconnect_settings()
	for pair: Array in [[Events.town_grew, _on_town_grew], [Events.district_declined, _on_district_declined],
			[Events.season_ended, _on_season_ended], [Events.game_started, _on_game_started]]:
		if (pair[0] as Signal).is_connected(pair[1] as Callable):
			(pair[0] as Signal).disconnect(pair[1] as Callable)


func _on_town_grew(_tag: StringName, _hex: Vector2i, _level: int) -> void:
	_grew_now += 1


func _on_district_declined(_tag: StringName, _hex: Vector2i, _level: int, _why: StringName) -> void:
	_declined_now += 1


## The season's events came before this signal: what was counted is the last season's, and the count starts again.
func _on_season_ended(_turn: int) -> void:
	_grew_last = _grew_now
	_declined_last = _declined_now
	_grew_now = 0
	_declined_now = 0
	if visible:
		refresh_metrics()


func _on_game_started() -> void:
	_grew_now = 0
	_declined_now = 0
	_grew_last = 0
	_declined_last = 0


func _process(delta: float) -> void:
	var frame_ms := delta * 1000.0
	if frame_ms > _worst_frame_ms:
		_worst_frame_ms = frame_ms
	_worst_clock += delta
	if _worst_clock >= 1.0:
		_worst_clock = 0.0
		_worst_frame_ms = frame_ms
	if not visible:
		return
	_refresh_clock += delta
	if _refresh_clock >= REFRESH_INTERVAL_SEC:
		_refresh_clock = 0.0
		refresh_metrics()


func toggle() -> void:
	set_open(not visible)


func set_open(on: bool) -> void:
	if on and _settings != null and not bool(_settings.get_value("dev/developer_tools")):
		visible = false
		return
	visible = on
	if visible:
		_refresh_clock = 0.0
		refresh_metrics()


func is_open() -> bool:
	return visible


func configure(settings: Settings) -> void:
	if settings == _settings:
		if settings != null and is_node_ready():
			_apply_settings(settings)
		return
	_disconnect_settings()
	_settings = settings
	if _settings == null:
		return
	_settings.changed.connect(_on_setting_changed)
	if is_node_ready():
		_apply_settings(_settings)


func bind_map_scene(scene: Node) -> void:
	_map_scene = scene
	if visible:
		refresh_metrics()


func set_snapshot(data: Dictionary) -> void:
	_snapshot = data.duplicate()
	if data.has("hovered_hex") and data["hovered_hex"] is Vector2i:
		_hovered_hex = data["hovered_hex"] as Vector2i
	if is_node_ready():
		refresh_metrics()


func set_hovered_hex(hex: Vector2i) -> void:
	_hovered_hex = hex
	if visible:
		refresh_metrics()


func set_season(index: int) -> void:
	_season_index = clampi(index, LOOK_CALENDAR, SEASON_NAMES.size() - 1)
	if is_node_ready():
		_season_seg.select(_season_index, false)


func set_season_name(season_name: String) -> void:
	var idx := SEASON_NAMES.find(season_name.to_lower())
	if idx >= 0:
		set_season(idx)


func set_layer_switch(layer_name: StringName, on: bool) -> void:
	var sw := _switches.get(layer_name, null) as KitSwitch
	if sw != null:
		_syncing = true
		sw.set_pressed_no_signal(on)
		_syncing = false


## Gives the console its context (the App's) so `end`, `goto` and `look` reach the App.
func setup_console(ctx: ShellContext) -> void:
	_console.setup(ctx)


func console() -> DevConsole:
	return _console


## F2: opens the panel (with developer tools on) and puts the cursor in the console. False when it cannot open.
func focus_console() -> bool:
	if not visible:
		set_open(true)
	if not visible:
		return false
	_console.focus_line()
	return true


## The time of the last save in ms (the App measures it around `Session.save_game`); shown in the M3 line.
func record_save_ms(ms: float) -> void:
	_save_ms = ms
	if visible:
		refresh_metrics()


func metrics_text() -> String:
	return _metrics_label.text if is_node_ready() else ""


func m3_text() -> String:
	return _m3_label.text if is_node_ready() else ""


func m4_text() -> String:
	return _m4_label.text if is_node_ready() else ""


## The armies line's words (M6), for the tests.
func m6_text() -> String:
	return _army_label.text if is_node_ready() and _army_label != null else ""


func people_text() -> String:
	return _people_label.text if is_node_ready() and _people_label != null else ""


func study_text() -> String:
	return _study_label.text if is_node_ready() and _study_label != null else ""


func season_segmented() -> Segmented:
	return _season_seg


func new_seed_button() -> KitButton:
	return _new_seed_btn


func layer_switch(layer_name: StringName) -> KitSwitch:
	return _switches.get(layer_name, null) as KitSwitch


func far_zoom_slider() -> KitSlider:
	return _far_zoom_slider


func slice_ms_slider() -> KitSlider:
	return _slice_ms_slider


## Recomputes and formats all Spec §7 performance, camera, view, and game metrics.
func refresh_metrics() -> void:
	if not is_node_ready():
		return
	var data := _collect_metrics()
	var vis_rect: Rect2 = data["visible_rect"]
	var cam_pos: Vector2 = data["camera_pos"]
	var hex: Vector2i = data["hovered_hex"]
	var hex_str := "(%d, %d)" % [hex.x, hex.y] if hex != MapInput.NO_HEX else "none"
	var lines: PackedStringArray = [
		"FPS: %d  worst: %.1f ms  proc: %.2f ms" % [int(data["fps"]), float(data["worst_ms"]), float(data["proc_ms"])],
		"Draw calls: %d  Objects: %d" % [int(data["draw_calls"]), int(data["objects"])],
		"Mem static: %.1f MB  video: %.1f MB  tex: %.1f MB" % [
			float(data["static_mb"]), float(data["video_mb"]), float(data["texture_mb"])
		],
		"Camera zoom: %.2f  pos: (%.0f, %.0f)" % [float(data["zoom"]), cam_pos.x, cam_pos.y],
		"Visible rect: (%.0f, %.0f, %.0f x %.0f)" % [vis_rect.position.x, vis_rect.position.y, vis_rect.size.x, vis_rect.size.y],
		"Hex: %s  Season: %s  Seed: %d" % [hex_str, str(data["season"]), int(data["seed"])],
		"View chunks: %d  layers: %d  cells: %d  lines: %d" % [
			int(data["chunks"]), int(data["layers"]), int(data["cells"]), int(data["line_chunks"])
		],
		"On screen hexes: %d  fill: %d%%  swap: %s  slice: %d ms" % [
			int(data["hexes_on_screen"]), int(roundf(float(data["fill_progress"]) * 100.0)),
			"yes" if bool(data["swapping"]) else "no", int(data["slice_ms"])
		],
		"Digest: %s  Renderer: %s" % [str(data["digest"]), str(data["renderer"])],
		"countries %d · mode %s · border chunks %d · overlay %.1f KB" % [
			int(data["countries"]), str(data["mode"]), int(data["border_chunks"]), float(data["overlay_kb"])
		],
	]
	_metrics_label.text = "\n".join(lines)
	_m3_label.text = m3_line()
	_m4_label.text = m4_line()
	_army_label.text = m6_line()
	if _study_label != null:
		_study_label.text = study_line()
	if _people_label != null:
		_people_label.text = people_line()


## The people line (spec 6.10): "people 1.8 ms · grew 2 · declined 0 · hungry countries 1". The time is the people phase of
## the last season played ("none yet" before one), the two counts are the levels changed in it, and the hungry countries
## are those that went short of food (food_fed under 1,000). A sandbox has no people.
func people_line() -> String:
	var game := Session.game
	if game == null:
		return "no game"
	if not game.has_countries():
		return "no people in a map-only game"
	var hungry := 0
	for c: Country in game.countries:
		if c != null and c.food_fed < 1000:
			hungry += 1
	var time_text := "%.1f ms" % float(Session.last_phase_ms["people"]) if Session.last_phase_ms.has("people") else "none yet"
	return "people %s · grew %d · declined %d · hungry countries %d" % [time_text, _grew_last, _declined_last, hungry]


## The study's line (M4.5 spec 6.9): "study economy/districts built in 3.4 ms · warm queue 0". The page and the tab of the last
## open (a page without tabs shows its name only), its synchronous time, and the views the warmer still has to run.
func study_line() -> String:
	if Session.game == null:
		return "no game"
	var info: Dictionary = study_info_func.call() if study_info_func.is_valid() else {}
	var warm := int(info.get("warm", 0))
	if not info.has("page"):
		return "study not opened yet · warm queue %d" % warm
	var tab := str(info.get("tab", ""))
	var where := str(info["page"]) if tab.is_empty() else "%s/%s" % [str(info["page"]), tab]
	return "study %s built in %.1f ms · warm queue %d" % [where, float(info.get("ms", 0.0)), warm]


## "turn 9 · Spring 1482 · works 3 · phases works 0.4, stats 0.2, calendar 0.0 ms · save 32 ms".
func m3_line() -> String:
	var game := Session.game
	if game == null:
		return "no game"
	var works := game.state.works.size() if game.state != null else 0
	var phases: PackedStringArray = []
	for phase: String in Session.last_phase_ms:
		phases.append("%s %.1f" % [phase, float(Session.last_phase_ms[phase])])
	var phase_text := "none yet" if phases.is_empty() else ", ".join(phases) + " ms"
	var save_text := "none yet" if _save_ms < 0.0 else "%d ms" % roundi(_save_ms)
	return "turn %d · %s · works %d · phases %s · save %s" % [
		game.turn, game.date_text(), works, phase_text, save_text]


## The economy's line (spec 6.11): "production 3.1 ms · income 0.4 ms · districts cached 340 · weather calm, good, calm".
## The phase times are of the last season played ("none yet" before one); the weather is a word for each climate (snow,
## frost, mild).
func m4_line() -> String:
	var game := Session.game
	if game == null:
		return "no game"
	var times: PackedStringArray = []
	for phase: String in ["production", "income"]:
		times.append("%s %s" % [phase, "%.1f ms" % float(Session.last_phase_ms[phase]) if Session.last_phase_ms.has(phase) else "none yet"])
	var weather: PackedStringArray = []
	for climate: int in 3:
		weather.append(WEATHER_WORDS[clampi(int(game.weather[climate]), 0, WEATHER_WORDS.size() - 1)])
	return "%s · districts cached %d · weather %s" % [" · ".join(times), game.districts.size(), ", ".join(weather)]


## The armies line (M6 spec 6.11): "armies 3 · units 6 · movement 0.6 ms · supply 0.4 ms · vision 0.2 ms · steps filled 340".
## The phase times are of the last season played ("none yet" before one); the steps filled are the step table's (0 with no army).
func m6_line() -> String:
	var game := Session.game
	if game == null:
		return "no game"
	var units := 0
	for army: Army in game.armies:
		units += army.units.size()
	var times: PackedStringArray = []
	for phase: String in ["movement", "supply", "vision"]:
		times.append("%s %s" % [phase, "%.1f ms" % float(Session.last_phase_ms[phase]) if Session.last_phase_ms.has(phase) else "none yet"])
	var filled := StepCosts.of(game.map, game.defs).filled() if not game.armies.is_empty() else 0
	return "armies %d · units %d · %s · steps filled %d" % [game.armies.size(), units, " · ".join(times), filled]


func _collect_metrics() -> Dictionary:
	var fps := int(Engine.get_frames_per_second())
	var proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var static_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var video_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var texture_mb := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0

	var zoom_val := float(_snapshot.get("zoom", 1.0))
	var cam_pos := _snapshot.get("camera_pos", Vector2.ZERO) as Vector2
	var vis_rect := _snapshot.get("visible_rect", Rect2()) as Rect2
	var season_str := str(_snapshot.get("season", SEASON_NAMES[_season_index]))
	var seed_val := int(_snapshot.get("seed", Session.game.seed_value if Session.game != null else 0))
	var slice_val := int(_snapshot.get("slice_ms", _slice_ms_slider.value))
	var chunks := int(_snapshot.get("chunks", 0))
	var layers := int(_snapshot.get("layers", 0))
	var cells := int(_snapshot.get("cells", 0))
	var line_chunks := int(_snapshot.get("line_chunks", 0))
	var hexes_on_screen := int(_snapshot.get("hexes_on_screen", 0))
	var fill_prog := float(_snapshot.get("fill_progress", 1.0))
	var swapping := bool(_snapshot.get("swapping", false))
	var digest_str := str(_snapshot.get("digest", _game_digest()))
	var countries := Session.game.countries.size() if (Session.game != null and Session.game.has_countries()) else 0
	var mode_name := "Terrain"
	var border_chunks := 0
	var overlay_kb := 0.0

	if _map_scene != null and is_instance_valid(_map_scene):
		var scene := _map_scene as MapScene
		if scene != null:
			mode_name = MODE_WORDS[clampi(scene.mode(), 0, MODE_WORDS.size() - 1)]
			if scene.view() != null:
				border_chunks = scene.view().border_chunks().size()
			if scene.overlay() != null:
				overlay_kb = scene.overlay().texture_bytes() / 1024.0
			zoom_val = scene.zoom()
			if scene.camera() != null:
				cam_pos = scene.camera().position
			if scene.camera_rig() != null:
				vis_rect = scene.camera_rig().visible_map_rect()
			season_str = scene.season
			slice_val = roundi(scene.slice_ms)
			fill_prog = scene.fill_progress()
			swapping = scene.is_swapping()
			if scene.view() != null:
				var v := scene.view()
				cells = v.cell_count()
				line_chunks = v.line_chunks().size()
				layers = TileMapView.LAYERS.size() + TileMapView.OVERLAYS.size()
				chunks = maxi(1, line_chunks)
			if scene.map_input() != null:
				_hovered_hex = scene.map_input().current_hover()
			if Session.game != null and Session.game.map != null and vis_rect.has_area():
				var approx_hex_w := float(MapTiles.CELL.x)
				var approx_hex_h := MapTiles.ROW
				var cols_vis := ceili(vis_rect.size.x / maxf(approx_hex_w, 1.0)) + 1
				var rows_vis := ceili(vis_rect.size.y / maxf(approx_hex_h, 1.0)) + 1
				hexes_on_screen = clampi(cols_vis * rows_vis, 0, Session.game.map.hex_count())

	var renderer := "%s / %s" % [
		str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility")),
		RenderingServer.get_current_rendering_driver_name(),
	]
	return {
		"fps": fps,
		"worst_ms": _worst_frame_ms,
		"proc_ms": proc_ms,
		"draw_calls": draw_calls,
		"objects": objects,
		"static_mb": static_mb,
		"video_mb": video_mb,
		"texture_mb": texture_mb,
		"zoom": zoom_val,
		"camera_pos": cam_pos,
		"visible_rect": vis_rect,
		"hovered_hex": _hovered_hex,
		"season": season_str,
		"seed": seed_val,
		"chunks": chunks,
		"layers": layers,
		"cells": cells,
		"line_chunks": line_chunks,
		"hexes_on_screen": hexes_on_screen,
		"fill_progress": fill_prog,
		"swapping": swapping,
		"slice_ms": slice_val,
		"digest": digest_str,
		"renderer": renderer,
		"countries": countries,
		"mode": mode_name,
		"border_chunks": border_chunks,
		"overlay_kb": overlay_kb,
	}


func _game_digest() -> String:
	if Session.game != null and Session.game.map != null:
		return Session.game.digest().substr(0, 8)
	return "--------"


func _build_layer_switches() -> void:
	for spec: Array in LAYER_SPECS:
		var layer_id := spec[0] as StringName
		var label_text := str(spec[1])
		var sw := KitSwitch.new()
		sw.name = StringName("Switch_" + String(layer_id))
		sw.text = label_text
		sw.focus_mode = Control.FOCUS_NONE
		var init_on := layer_id in [&"shade", &"light", &"trees", &"lines"]
		sw.set_pressed_no_signal(init_on)
		sw.toggled.connect(func(on: bool) -> void: _on_layer_switch(layer_id, on))
		_layers_grid.add_child(sw)
		_switches[layer_id] = sw


func _on_layer_switch(layer_id: StringName, on: bool) -> void:
	if _syncing:
		return
	debug_layer_toggled.emit(layer_id, on)


func _on_season_changed(id: Variant) -> void:
	var idx := clampi(int(id), LOOK_CALENDAR, SEASON_NAMES.size() - 1)
	_season_index = idx
	season_preview_requested.emit(idx)
	if visible:
		refresh_metrics()


func _on_far_zoom_slider_changed(new_value: float) -> void:
	if _syncing:
		return
	if _settings != null:
		_syncing = true
		_settings.set_value("dev/far_zoom", new_value)
		_syncing = false
	far_zoom_changed.emit(new_value)


func _on_slice_ms_slider_changed(new_value: float) -> void:
	if _syncing:
		return
	var ms := roundi(new_value)
	if _settings != null:
		_syncing = true
		_settings.set_value("dev/slice_ms", ms)
		_syncing = false
	slice_ms_changed.emit(ms)


func _apply_settings(settings: Settings) -> void:
	_syncing = true
	_far_zoom_slider.set_slider_value(float(settings.get_value("dev/far_zoom")), false)
	_slice_ms_slider.set_slider_value(float(settings.get_value("dev/slice_ms")), false)
	if _switches.has(&"grid"):
		(_switches[&"grid"] as KitSwitch).set_pressed_no_signal(bool(settings.get_value("map/grid")))
	var shading := bool(settings.get_value("graphics/relief_shading"))
	if _switches.has(&"shade"):
		(_switches[&"shade"] as KitSwitch).set_pressed_no_signal(shading)
	if _switches.has(&"light"):
		(_switches[&"light"] as KitSwitch).set_pressed_no_signal(shading)
	_syncing = false
	if not bool(settings.get_value("dev/developer_tools")):
		visible = false


func _on_setting_changed(key: String, _value: Variant) -> void:
	if _syncing or _settings == null or not is_node_ready():
		return
	if key in ["dev/far_zoom", "dev/slice_ms", "dev/developer_tools", "map/grid", "graphics/relief_shading"]:
		_apply_settings(_settings)
		if visible:
			refresh_metrics()


func _disconnect_settings() -> void:
	if _settings != null and _settings.changed.is_connected(_on_setting_changed):
		_settings.changed.disconnect(_on_setting_changed)
	_settings = null
