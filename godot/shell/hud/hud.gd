## Studiolo HUD frame coordinating TopBar, right Dock (HexPanel), bottom-right ZoomControl + ScaleBar
## (shifting left automatically when Dock opens), KeyHints, MapHover, LayersPopover, ToastHost, and DebugOverlay
## (docs/architecture/ui-and-controls-spec.md sections 3.1, 3.3, 7; ui-style-and-feedback-plan.md U14).
class_name Hud
extends CanvasLayer

signal zoom_step_requested(notches: float)
signal zoom_set_requested(zoom: float)
signal fit_requested
signal layer_toggled(layer_name: StringName, on: bool)
signal season_preview_requested(index: int)
signal help_requested
signal menu_requested
signal new_seed_requested
signal debug_layer_toggled(layer_name: StringName, on: bool)
signal far_zoom_changed(value: float)
signal slice_ms_changed(ms: int)
signal hud_visibility_changed(shown: bool)

@onready var _root: Control = $Root
@onready var _top_bar: TopBar = $Root/Column/TopBar
@onready var _map_area: Control = $Root/Column/Main/MapArea
@onready var _debug_overlay: DebugOverlay = $Root/Column/Main/MapArea/DebugOverlay
@onready var _layers_popover: LayersPopover = $Root/Column/Main/MapArea/LayersPopover
@onready var _key_hints: KeyHints = $Root/Column/Main/MapArea/KeyHints
@onready var _scale_bar: ScaleBar = $Root/Column/Main/MapArea/BottomRight/ScaleBar
@onready var _zoom_control: ZoomControl = $Root/Column/Main/MapArea/BottomRight/ZoomControl
@onready var _toasts: ToastHost = $Root/Column/Main/MapArea/Toasts
@onready var _map_hover: MapHover = $Root/Column/Main/MapArea/MapHover
@onready var _dock: VBoxContainer = $Root/Column/Main/Dock
@onready var _hex_panel: HexPanel = $Root/Column/Main/Dock/HexPanel

var _ctx: ShellContext = null
var _settings: Settings = null
var _bound_rig: CameraRig = null
var _bound_map_input: MapInput = null
var _reduce_motion: bool = false


func _ready() -> void:
	_layers_popover.anchor_button = _top_bar.layers_button()

	_top_bar.season_preview_requested.connect(_on_season_preview_selected)
	_top_bar.layers_toggled.connect(_on_top_bar_layers_toggled)
	_top_bar.help_requested.connect(func() -> void: help_requested.emit())
	_top_bar.menu_requested.connect(func() -> void: menu_requested.emit())

	_layers_popover.layer_toggled.connect(func(lname: StringName, on: bool) -> void: layer_toggled.emit(lname, on))
	_layers_popover.season_preview_requested.connect(_on_season_preview_selected)
	_layers_popover.closed.connect(_on_layers_popover_closed)

	_zoom_control.zoom_step_requested.connect(func(notches: float) -> void: zoom_step_requested.emit(notches))
	_zoom_control.zoom_set_requested.connect(func(z: float) -> void: zoom_set_requested.emit(z))
	_zoom_control.fit_requested.connect(func() -> void: fit_requested.emit())

	_debug_overlay.season_preview_requested.connect(_on_season_preview_selected)
	_debug_overlay.new_seed_requested.connect(func() -> void: new_seed_requested.emit())
	_debug_overlay.debug_layer_toggled.connect(func(lname: StringName, on: bool) -> void: debug_layer_toggled.emit(lname, on))
	_debug_overlay.far_zoom_changed.connect(func(v: float) -> void: far_zoom_changed.emit(v))
	_debug_overlay.slice_ms_changed.connect(func(ms: int) -> void: slice_ms_changed.emit(ms))

	_dock.child_entered_tree.connect(_on_dock_child_entered)
	for child: Node in _dock.get_children():
		_watch_dock_child(child)
	_sync_dock_visibility()


func _exit_tree() -> void:
	_disconnect_ctx()
	_disconnect_settings()
	_unbind_rig()
	_unbind_map_input()


func setup(context: ShellContext) -> void:
	_disconnect_ctx()
	_ctx = context
	if _ctx != null:
		_ctx.toast_requested.connect(_on_ctx_toast_requested)
		if _ctx.settings != null:
			configure(_ctx.settings)


func configure(settings: Settings) -> void:
	if settings == _settings:
		if settings != null and is_node_ready():
			_apply_settings(settings)
		return
	_disconnect_settings()
	_settings = settings
	if is_node_ready():
		_layers_popover.configure(_settings)
		_debug_overlay.configure(_settings)
		_map_hover.configure(_settings)
		_key_hints.configure(_settings)
	if _settings == null:
		return
	_settings.changed.connect(_on_setting_changed)
	if is_node_ready():
		_apply_settings(_settings)


func bind_camera_rig(rig: CameraRig) -> void:
	_unbind_rig()
	_bound_rig = rig
	if _bound_rig == null:
		return
	_bound_rig.view_changed.connect(_on_rig_view_changed)
	set_zoom(_bound_rig.zoom(), _bound_rig.min_zoom(), _bound_rig.max_zoom())


func bind_map_scene(scene: Node) -> void:
	_debug_overlay.bind_map_scene(scene)
	var map_scene := scene as MapScene
	if map_scene == null:
		return
	set_season(map_scene.season)
	if Session.game != null:
		var map_label := "North Italy" if map_scene.map_id == MapScene.MAP_ID else map_scene.map_id.capitalize()
		set_map_info(map_label, Session.game.seed_value)
	if map_scene.camera_rig() != null:
		bind_camera_rig(map_scene.camera_rig())
	_unbind_map_input()
	_bound_map_input = map_scene.map_input()
	if _bound_map_input != null:
		_bound_map_input.hover_changed.connect(_on_map_hover_changed)


func set_hud_visible(shown: bool) -> void:
	if not shown:
		_layers_popover.close()
	_root.visible = shown
	if shown and not _reduce_motion:
		_root.modulate.a = 1.0
	hud_visibility_changed.emit(shown)


func is_hud_visible() -> bool:
	return _root.visible


func toggle_hud() -> void:
	set_hud_visible(not is_hud_visible())


func set_debug_open(on: bool) -> void:
	_debug_overlay.set_open(on)


func toggle_debug() -> void:
	_debug_overlay.toggle()


func is_debug_open() -> bool:
	return _debug_overlay.is_open()


func set_layers_open(on: bool) -> void:
	_layers_popover.set_open(on)
	_top_bar.set_layers_open(_layers_popover.visible)


func is_layers_open() -> bool:
	return _layers_popover.visible


func has_open_popover() -> bool:
	return _layers_popover.visible


func close_popovers() -> bool:
	if _layers_popover.visible:
		_layers_popover.close()
		return true
	return false


func is_dock_open() -> bool:
	for child: Node in _dock.get_children():
		if child is CanvasItem and (child as CanvasItem).visible:
			return true
	return false


func set_zoom(zoom: float, min_zoom: float = 0.0, max_zoom: float = ZoomModel.ZOOM_MAX, hex_w_km: float = -1.0) -> void:
	_zoom_control.set_zoom(zoom, min_zoom, max_zoom)
	_scale_bar.set_zoom(zoom, hex_w_km)


func set_season_index(index: int) -> void:
	_top_bar.set_season(index)
	_layers_popover.set_season(index)
	_debug_overlay.set_season(index)


func set_season(season_name: String) -> void:
	var idx := TopBar.SEASONS.find(season_name.to_lower())
	if idx >= 0:
		set_season_index(idx)


func set_map_info(map_title: String, seed_value: int, mode_label: String = "Sandbox") -> void:
	_top_bar.set_map_info(map_title, seed_value, mode_label)


func on_hover_changed(hex: Vector2i, pointer_pos: Variant = null) -> void:
	_map_hover.on_hover_changed(hex, pointer_pos)
	_debug_overlay.set_hovered_hex(hex)


func toast(text: String, tone: StringName = &"plain", key_action: StringName = &"", kind: StringName = &"") -> void:
	_toasts.toast(text, tone, key_action, kind)


func refresh_bindings(platform: String = OS.get_name()) -> void:
	_key_hints.refresh_bindings(platform)
	_top_bar.refresh_hotkeys()
	_layers_popover.refresh_hotkeys()
	_zoom_control.refresh_hotkeys()


func top_bar() -> TopBar:
	return _top_bar


func layers_popover() -> LayersPopover:
	return _layers_popover


func zoom_control() -> ZoomControl:
	return _zoom_control


func scale_bar() -> ScaleBar:
	return _scale_bar


func map_hover() -> MapHover:
	return _map_hover


func debug_overlay() -> DebugOverlay:
	return _debug_overlay


func key_hints() -> KeyHints:
	return _key_hints


func toast_host() -> ToastHost:
	return _toasts


func hex_panel() -> HexPanel:
	return _hex_panel


func dock() -> VBoxContainer:
	return _dock


func map_area() -> Control:
	return _map_area


func root() -> Control:
	return _root


func _on_season_preview_selected(index: int) -> void:
	set_season_index(index)
	season_preview_requested.emit(index)


func _on_top_bar_layers_toggled(open: bool) -> void:
	_layers_popover.set_open(open)


func _on_layers_popover_closed() -> void:
	_top_bar.set_layers_open(false)


func _on_rig_view_changed(zoom: float, _visible_rect: Rect2) -> void:
	var min_z := _bound_rig.min_zoom() if _bound_rig != null else 0.0
	var max_z := _bound_rig.max_zoom() if _bound_rig != null else ZoomModel.ZOOM_MAX
	var hex_km := Session.game.map.hex_w_km if (Session.game != null and Session.game.map != null) else -1.0
	set_zoom(zoom, min_z, max_z, hex_km)


func _on_map_hover_changed(hex: Vector2i) -> void:
	var vp := get_viewport()
	var pos := vp.get_mouse_position() if vp != null else Vector2.ZERO
	on_hover_changed(hex, pos)


func _on_ctx_toast_requested(text: String, tone: StringName) -> void:
	toast(text, tone)


func _on_dock_child_entered(child: Node) -> void:
	_watch_dock_child(child)
	_sync_dock_visibility()


func _watch_dock_child(child: Node) -> void:
	if child is CanvasItem:
		var item := child as CanvasItem
		if not item.visibility_changed.is_connected(_sync_dock_visibility):
			item.visibility_changed.connect(_sync_dock_visibility)


func _sync_dock_visibility() -> void:
	if not is_node_ready():
		return
	var open := is_dock_open()
	_dock.visible = open
	_key_hints.set_context(open)


func _apply_settings(settings: Settings) -> void:
	_reduce_motion = bool(settings.get_value("accessibility/reduce_motion"))
	if not bool(settings.get_value("dev/developer_tools")):
		_debug_overlay.set_open(false)


func _on_setting_changed(key: String, _value: Variant) -> void:
	if _settings != null and (key == "accessibility/reduce_motion" or key == "dev/developer_tools"):
		_apply_settings(_settings)


func _disconnect_ctx() -> void:
	if _ctx != null and _ctx.toast_requested.is_connected(_on_ctx_toast_requested):
		_ctx.toast_requested.disconnect(_on_ctx_toast_requested)
	_ctx = null


func _disconnect_settings() -> void:
	if _settings != null and _settings.changed.is_connected(_on_setting_changed):
		_settings.changed.disconnect(_on_setting_changed)
	_settings = null


func _unbind_rig() -> void:
	if _bound_rig != null and is_instance_valid(_bound_rig) and _bound_rig.view_changed.is_connected(_on_rig_view_changed):
		_bound_rig.view_changed.disconnect(_on_rig_view_changed)
	_bound_rig = null


func _unbind_map_input() -> void:
	if _bound_map_input != null and is_instance_valid(_bound_map_input) and _bound_map_input.hover_changed.is_connected(_on_map_hover_changed):
		_bound_map_input.hover_changed.disconnect(_on_map_hover_changed)
	_bound_map_input = null
