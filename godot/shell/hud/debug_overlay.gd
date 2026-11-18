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
const LAYER_SPECS: Array[Array] = [
	[&"grid", "Grid"],
	[&"shade", "Shade"],
	[&"light", "Light"],
	[&"trees", "Trees"],
	[&"lines", "Lines"],
	[&"far_locked", "Far lock"],
]

@onready var _metrics_label: Label = $VBox/Metrics
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
var _season_index: int = 1
var _hovered_hex: Vector2i = MapInput.NO_HEX


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_season_seg.hud_mode = true
	var season_items: Array[Dictionary] = []
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
	_season_index = clampi(index, 0, SEASON_NAMES.size() - 1)
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


func metrics_text() -> String:
	return _metrics_label.text if is_node_ready() else ""


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
	]
	_metrics_label.text = "\n".join(lines)


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

	if _map_scene != null and is_instance_valid(_map_scene):
		var scene := _map_scene as MapScene
		if scene != null:
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
	var idx := clampi(int(id), 0, SEASON_NAMES.size() - 1)
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
