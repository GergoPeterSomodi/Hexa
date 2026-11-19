## Action-based map input controller (docs/architecture/ui-and-controls-spec.md sections 3.3, 4.1, 4.2, 4.5).
## Turns pointer clicks, hover and InputMap actions into intent signals; knows no game rules or tiles.
## Camera movement and zoom belong exclusively to CameraRig.
class_name MapInput
extends Node

signal select_requested(map_px: Vector2)
signal command_requested(map_px: Vector2)
signal hover_changed(hex: Vector2i)
signal mode_requested(mode: int)
signal country_requested
signal find_place_requested
signal grid_toggled
signal names_toggled
signal hud_toggled
signal upgrade_requested
signal new_seed_requested

const CLICK_SLOP := 6.0
const NO_HEX := Vector2i(-9999, -9999)

var camera: Camera2D = null
## Any node at the map's origin (usually TileMapView); viewport points are transformed to its local space.
var map_node: Node2D = null
## Optional override Callable(map_px: Vector2) -> Vector2i for tests; defaults to TileMapView.hex_at.
var hex_at_func := Callable()
## Optional override Callable(hex: Vector2i) -> bool; defaults to Session.game.map.has(hex).
var hex_valid_func := Callable()
## Gates developer-only actions such as dev_new_seed (configured via Settings "dev/developer_tools").
var allow_dev_actions := true
## Off while a screen or text field blocks map interaction.
var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			_reset_press()
			_set_hover(NO_HEX)

var _settings: Settings = null
var _press_action := &""
var _press_button: MouseButton = MOUSE_BUTTON_NONE
var _press_at := Vector2.ZERO
var _slop_broken := false
var _saw_hardware_button := false
var _last_hover := NO_HEX


func _ready() -> void:
	if not InputMap.has_action(&"map_select"):
		Bindings.ensure()


func _exit_tree() -> void:
	_disconnect_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_set_hover(NO_HEX)


## Applies relevant settings (developer tools gating) and listens for live updates.
func configure(settings: Settings) -> void:
	if settings == _settings and settings != null:
		allow_dev_actions = bool(settings.get_value("dev/developer_tools"))
		return
	_disconnect_settings()
	_settings = settings
	if _settings == null:
		return
	_settings.changed.connect(_on_setting_changed)
	allow_dev_actions = bool(_settings.get_value("dev/developer_tools"))


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "dev/developer_tools":
		allow_dev_actions = bool(value)


func _disconnect_settings() -> void:
	if _settings != null and _settings.changed.is_connected(_on_setting_changed):
		_settings.changed.disconnect(_on_setting_changed)
	_settings = null


func current_hover() -> Vector2i:
	return _last_hover


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventKey:
		_on_key(event as InputEventKey)


func _on_mouse_button(mb: InputEventMouseButton) -> void:
	var action := _pointer_action_of(mb)
	if action == &"":
		return
	if mb.pressed:
		_press_action = action
		_press_button = mb.button_index
		_press_at = mb.position
		_slop_broken = false
		_saw_hardware_button = Input.is_mouse_button_pressed(mb.button_index)
		return
	if mb.button_index != _press_button:
		return
	var within_slop := not _slop_broken and mb.position.distance_to(_press_at) < CLICK_SLOP
	var released_action := _press_action
	_reset_press()
	if not within_slop or _is_gui_hovered():
		return
	var map_px := map_px_of(mb.position)
	if released_action == &"map_select":
		select_requested.emit(map_px)
		_mark_handled()
	elif released_action == &"map_command":
		command_requested.emit(map_px)
		_mark_handled()


func _on_mouse_motion(motion: InputEventMouseMotion) -> void:
	if _press_button != MOUSE_BUTTON_NONE and motion.position.distance_to(_press_at) >= CLICK_SLOP:
		_slop_broken = true
	if _slop_broken or _is_gui_hovered():
		_set_hover(NO_HEX)
		return
	_set_hover(_hex_at(map_px_of(motion.position)))


func _on_key(key: InputEventKey) -> void:
	if not key.pressed or key.echo or _is_text_input_focused():
		return
	if allow_dev_actions and _is_action_pressed_exact(key, &"dev_new_seed"):
		new_seed_requested.emit()
		_mark_handled()
		return
	var mode_actions: Array[StringName] = [&"view_mode_1", &"view_mode_2", &"view_mode_3"]
	for i: int in mode_actions.size():
		if _is_action_pressed_exact(key, mode_actions[i]):
			mode_requested.emit(i)
			_mark_handled()
			return
	if _is_action_pressed_exact(key, &"ui_find_place"):
		find_place_requested.emit()
		_mark_handled()
	elif _is_action_pressed_exact(key, &"game_country"):
		country_requested.emit()
		_mark_handled()
	elif _is_action_pressed_exact(key, &"view_grid"):
		grid_toggled.emit()
		_mark_handled()
	elif _is_action_pressed_exact(key, &"view_names"):
		names_toggled.emit()
		_mark_handled()
	elif _is_action_pressed_exact(key, &"view_hud"):
		hud_toggled.emit()
		_mark_handled()
	elif _is_action_pressed_exact(key, &"game_upgrade"):
		upgrade_requested.emit()
		_mark_handled()


func _process(_delta: float) -> void:
	if _press_button != MOUSE_BUTTON_NONE and _saw_hardware_button:
		if not Input.is_mouse_button_pressed(_press_button):
			_reset_press()
	if not enabled or _is_gui_hovered():
		_set_hover(NO_HEX)


## Converts a viewport pixel to map space (local coordinates of `map_node`).
func map_px_of(screen: Vector2) -> Vector2:
	if map_node == null:
		return screen
	return map_node.get_global_transform_with_canvas().affine_inverse() * screen


func _hex_at(map_px: Vector2) -> Vector2i:
	var hex := NO_HEX
	if hex_at_func.is_valid():
		hex = hex_at_func.call(map_px) as Vector2i
	elif map_node is TileMapView:
		hex = (map_node as TileMapView).hex_at(map_px)
	else:
		return NO_HEX
	if hex_valid_func.is_valid():
		return hex if bool(hex_valid_func.call(hex)) else NO_HEX
	if Session.game != null and Session.game.map != null:
		return hex if Session.game.map.has(hex) else NO_HEX
	return hex


func _set_hover(hex: Vector2i) -> void:
	if hex == _last_hover:
		return
	_last_hover = hex
	hover_changed.emit(hex)


func _pointer_action_of(mb: InputEventMouseButton) -> StringName:
	if InputMap.has_action(&"map_select") and mb.is_action(&"map_select"):
		return &"map_select"
	if InputMap.has_action(&"map_command") and mb.is_action(&"map_command"):
		return &"map_command"
	return &""


func _is_action_pressed_exact(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action, false, true)


func _is_gui_hovered() -> bool:
	if not is_inside_tree():
		return false
	var vp := get_viewport()
	return vp != null and vp.gui_get_hovered_control() != null


func _is_text_input_focused() -> bool:
	if not is_inside_tree():
		return false
	var vp := get_viewport()
	if vp == null:
		return false
	var owner := vp.gui_get_focus_owner()
	return owner is LineEdit or owner is TextEdit


func _reset_press() -> void:
	_press_action = &""
	_press_button = MOUSE_BUTTON_NONE
	_slop_broken = false
	_saw_hardware_button = false


func _mark_handled() -> void:
	if is_inside_tree():
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
