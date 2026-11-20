## Studiolo HUD frame coordinating TopBar, right Dock (HexPanel), bottom-right ZoomControl + ScaleBar
## (shifting left automatically when Dock opens), KeyHints, MapHover, LayersPopover, ToastHost, and DebugOverlay
## (docs/architecture/ui-and-controls-spec.md sections 3.1, 3.3, 7; ui-style-and-feedback-plan.md U14).
class_name Hud
extends CanvasLayer

signal zoom_step_requested(notches: float)
signal zoom_set_requested(zoom: float)
signal fit_requested
signal layer_toggled(layer_name: StringName, on: bool)
## F3's Look: 0 to 3 a season, -1 the calendar's (the console's `look` and the Look control).
signal season_preview_requested(index: int)
signal help_requested
signal menu_requested
signal new_seed_requested
signal debug_layer_toggled(layer_name: StringName, on: bool)
signal far_zoom_changed(value: float)
signal slice_ms_changed(ms: int)
signal hud_visibility_changed(shown: bool)
## The top bar's mode switch (0 Terrain, 1 Owner, 2 Relief).
signal mode_requested(mode: int)
## A country's name was asked for: the top bar's name, a neighbour link or the hex panel's owner link.
signal country_requested(tag: StringName)
signal country_play_requested(tag: StringName)
signal country_look_at_requested(hex: Vector2i)
## The minimap: a click glides the view to map_px, a drag jumps to it (map px).
signal look_at_requested(map_px: Vector2)
signal jump_requested(map_px: Vector2)
## What the HUD covers on screen changed (the dock, the left inset, a resize, the HUD shown or hidden): cover_rects().
signal cover_changed
## End season was pressed (the date and End season in the top bar) and the date's medallion: the last report.
signal end_season_requested
signal report_requested
## A row of the action log, a notification's Go or a task flag row asked to look at a hex and select it.
signal hex_look_requested(hex: Vector2i)
## The study was asked for (a chip, the study button, the country panel's button, a task flag line): `page` is &"economy"
## or &"" for the last page shown.
signal study_requested(page: StringName)

## The key hints' left offset in hud.tscn.
const KEY_HINTS_LEFT := 12.0

@onready var _root: Control = $Root
@onready var _top_bar: TopBar = $Root/Column/TopBar
@onready var _map_area: Control = $Root/Column/Main/MapArea
@onready var _debug_overlay: DebugOverlay = $Root/Column/Main/MapArea/DebugOverlay
@onready var _layers_popover: LayersPopover = $Root/Column/Main/MapArea/LayersPopover
@onready var _key_hints: KeyHints = $Root/Column/Main/MapArea/KeyHints
@onready var _scale_bar: ScaleBar = $Root/Column/Main/MapArea/BottomRight/ScaleBar
@onready var _minimap: Minimap = $Root/Column/Main/MapArea/BottomRight/RightColumn/Minimap
@onready var _zoom_control: ZoomControl = $Root/Column/Main/MapArea/BottomRight/RightColumn/ZoomControl
@onready var _action_log: ActionLog = $Root/Column/Main/MapArea/ActionLog
@onready var _task_flag: TaskFlag = $Root/Column/Main/MapArea/TopRight/TaskFlag
@onready var _notifications: Notifications = $Root/Column/Main/MapArea/TopRight/Notifications
@onready var _toasts: ToastHost = $Root/Column/Main/MapArea/Toasts
@onready var _map_hover: MapHover = $Root/Column/Main/MapArea/MapHover
@onready var _bottom_right: Control = $Root/Column/Main/MapArea/BottomRight
@onready var _dock: VBoxContainer = $Root/Column/Main/Dock
@onready var _hex_panel: HexPanel = $Root/Column/Main/Dock/HexPanel
@onready var _country_panel: CountryPanel = $Root/Column/Main/Dock/CountryPanel

var _ctx: ShellContext = null
var _settings: Settings = null
var _bound_rig: CameraRig = null
var _bound_map_input: MapInput = null
var _reduce_motion: bool = false
var _screen_cover: Array[Rect2] = []
var _cover_queued: bool = false


func _ready() -> void:
	for watched: Control in [_top_bar, _bottom_right, _dock]:
		watched.resized.connect(_queue_cover)
		watched.visibility_changed.connect(_queue_cover)
	get_viewport().size_changed.connect(_queue_cover)
	_layers_popover.anchor_button = _top_bar.layers_button()

	_top_bar.layers_toggled.connect(_on_top_bar_layers_toggled)
	_top_bar.help_requested.connect(func() -> void: help_requested.emit())
	_top_bar.menu_requested.connect(func() -> void: menu_requested.emit())
	_top_bar.mode_requested.connect(func(mode: int) -> void: mode_requested.emit(mode))
	_top_bar.country_requested.connect(func(tag: StringName) -> void: country_requested.emit(tag))
	_top_bar.date_end().end_season_requested.connect(func() -> void: end_season_requested.emit())
	_top_bar.date_end().report_requested.connect(func() -> void: report_requested.emit())
	_action_log.report_requested.connect(func() -> void: report_requested.emit())
	_action_log.line_activated.connect(func(hex: Vector2i) -> void: hex_look_requested.emit(hex))
	_task_flag.go_requested.connect(func(hex: Vector2i) -> void: hex_look_requested.emit(hex))
	_task_flag.study_requested.connect(func(page: StringName) -> void: study_requested.emit(page))
	_top_bar.study_requested.connect(func(page: StringName) -> void: study_requested.emit(page))
	_notifications.go_requested.connect(func(hex: Vector2i) -> void: hex_look_requested.emit(hex))
	Events.game_started.connect(_on_game_started)
	Events.season_ended.connect(_on_season_ended)

	_minimap.look_at_requested.connect(func(map_px: Vector2) -> void: look_at_requested.emit(map_px))
	_minimap.jump_requested.connect(func(map_px: Vector2) -> void: jump_requested.emit(map_px))

	_country_panel.play_requested.connect(func(tag: StringName) -> void: country_play_requested.emit(tag))
	_country_panel.look_at_requested.connect(func(hex: Vector2i) -> void: country_look_at_requested.emit(hex))
	_country_panel.country_requested.connect(func(tag: StringName) -> void: country_requested.emit(tag))
	_country_panel.study_requested.connect(func() -> void: study_requested.emit(&"economy"))
	_hex_panel.country_requested.connect(func(tag: StringName) -> void: country_requested.emit(tag))
	_hex_panel.visibility_changed.connect(_on_hex_panel_visibility_changed)

	_layers_popover.layer_toggled.connect(func(lname: StringName, on: bool) -> void: layer_toggled.emit(lname, on))
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
	if _settings != null:
		_minimap.configure(_settings)
		_hex_panel.set_settings(_settings)


func _exit_tree() -> void:
	for pair: Array in [[Events.game_started, _on_game_started], [Events.season_ended, _on_season_ended]]:
		if (pair[0] as Signal).is_connected(pair[1] as Callable):
			(pair[0] as Signal).disconnect(pair[1] as Callable)
	_disconnect_ctx()
	_disconnect_settings()
	_unbind_rig()
	_unbind_map_input()


func setup(context: ShellContext) -> void:
	_disconnect_ctx()
	_ctx = context
	if _ctx != null:
		_ctx.toast_requested.connect(_on_ctx_toast_requested)
		_debug_overlay.setup_console(_ctx)
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
		_hex_panel.set_settings(_settings)
		_layers_popover.configure(_settings)
		_debug_overlay.configure(_settings)
		_map_hover.configure(_settings)
		_key_hints.configure(_settings)
		_minimap.configure(_settings)
		_action_log.bind_settings(_settings)
		_task_flag.settings = _settings
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
		_minimap.unbind()
		_top_bar.refresh_game()
		return
	if Session.game != null:
		var map_label := "North Italy" if map_scene.map_id == MapScene.MAP_ID else map_scene.map_id.capitalize()
		set_map_info(map_label, Session.game.seed_value)
	if map_scene.camera_rig() != null:
		bind_camera_rig(map_scene.camera_rig())
	_unbind_map_input()
	_bound_map_input = map_scene.map_input()
	if _bound_map_input != null:
		_bound_map_input.hover_changed.connect(_on_map_hover_changed)
	_minimap.bind_map_scene(map_scene)
	_top_bar.refresh_game()
	_top_bar.set_mode(map_scene.mode())
	if not map_scene.mode_changed.is_connected(_top_bar.set_mode):
		map_scene.mode_changed.connect(_top_bar.set_mode)


## Shows the country `tag` in the dock (its panel replaces the hex panel). `picking` adds the tip and "Play as".
func show_country(tag: StringName, picking: bool) -> void:
	_hex_panel.clear()
	_country_panel.show_country(tag, picking)


## Closes whichever panel the dock shows.
func close_dock() -> void:
	_hex_panel.clear()
	_country_panel.clear()


## The resource chips of the top bar (null-safe use is the caller's: the bar always has them).
func chips() -> Chips:
	return _top_bar.chips()


## Reads the money and the stores again after a change that sends no event (the console's money and goods): the chips, the
## hex panel and the country panel in view.
func refresh_economy() -> void:
	_top_bar.chips().refresh()
	if _hex_panel.visible:
		_hex_panel.refresh()
	if _country_panel.visible:
		_country_panel.refresh()


## What a screen over the map covers (viewport px, e.g. CountryPick's list and banner); [] when it leaves. The key
## hints start right of any of them that reaches the bottom edge.
func set_screen_cover(rects: Array[Rect2]) -> void:
	_screen_cover = rects.duplicate()
	var bottom := get_viewport().get_visible_rect().size.y - 2.0 * KEY_HINTS_LEFT
	var inset := 0.0
	for r: Rect2 in _screen_cover:
		if r.end.y >= bottom:
			inset = maxf(inset, r.end.x)
	var width := _key_hints.offset_right - _key_hints.offset_left
	_key_hints.offset_left = KEY_HINTS_LEFT + inset
	_key_hints.offset_right = _key_hints.offset_left + width
	_queue_cover()


## The screen rect (viewport px) of a Control, whatever CanvasLayer holds it.
static func screen_rect(c: Control) -> Rect2:
	var xf := c.get_global_transform_with_canvas()
	return Rect2(xf.origin, c.size * xf.get_scale())


## The screen rects (viewport px) covering the map: the top bar, the open dock, the minimap corner and what a screen
## over the map covers (set_screen_cover). Empty while the HUD is hidden.
func cover_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not _root.visible:
		return out
	for c: Control in [_top_bar, _minimap, _zoom_control, _scale_bar, _dock]:  # not BottomRight: mostly empty
		if c.is_visible_in_tree():
			out.append(screen_rect(c))
	out.append_array(_screen_cover)
	return out


func set_mode(mode: int) -> void:
	_top_bar.set_mode(mode)


func set_hud_visible(shown: bool) -> void:
	if not shown:
		_layers_popover.close()
	_root.visible = shown
	if shown and not _reduce_motion:
		_root.modulate.a = 1.0
	hud_visibility_changed.emit(shown)
	_queue_cover()


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


## An action log or task flag list is open (the Esc ladder's CLOSE_HUD_LIST step).
func has_open_list() -> bool:
	return _action_log.is_open() or _task_flag.is_list_open()


## Esc on an open list: closes the action log or the task flag list. True when one was open.
func close_lists() -> bool:
	var closed := _action_log.escape()
	if _task_flag.is_list_open():
		_task_flag.close_list()
		closed = true
	return closed


## A screen is up: `hides_world` hides the notifications (and the HUD with them), any screen hides the task flag.
func set_covered(hides_world: bool, any_screen: bool) -> void:
	_notifications.set_covered(hides_world)
	_task_flag.set_covered(any_screen)


## Esc while the console's field has the cursor: lets go of the field. True when it had it.
func release_console_focus() -> bool:
	var console := _debug_overlay.console()
	if console != null and console.has_line_focus():
		console.release_focus_line()
		return true
	return false


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


## Shows `index` on F3's Look control (-1 the calendar's season, 0 to 3 a season) without a signal.
func set_look(index: int) -> void:
	_debug_overlay.set_season(index)


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


func date_end() -> DateEnd:
	return _top_bar.date_end()


func action_log() -> ActionLog:
	return _action_log


func task_flag() -> TaskFlag:
	return _task_flag


func notifications() -> Notifications:
	return _notifications


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


func country_panel() -> CountryPanel:
	return _country_panel


func minimap() -> Minimap:
	return _minimap


func map_area() -> Control:
	return _map_area


func root() -> Control:
	return _root


## A hex panel shown (a hex selected) replaces the country panel in the dock.
func _on_hex_panel_visibility_changed() -> void:
	if _hex_panel.visible and _country_panel.visible:
		_country_panel.clear()


func _on_season_preview_selected(index: int) -> void:
	season_preview_requested.emit(index)


## A new game or a season that ended: F3's Look is back on the calendar (the preview ends with the season).
func _on_game_started() -> void:
	set_look(-1)


func _on_season_ended(_turn: int) -> void:
	set_look(-1)


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


## Containers settle a frame late: cover_changed goes out once, deferred.
func _queue_cover() -> void:
	if _cover_queued:
		return
	_cover_queued = true
	_emit_cover.call_deferred()


func _emit_cover() -> void:
	_cover_queued = false
	var room := screen_rect(_scale_bar).position.x - screen_rect(_key_hints).position.x - float(Tokens.S2)
	_key_hints.fit_width(room)
	cover_changed.emit()


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
