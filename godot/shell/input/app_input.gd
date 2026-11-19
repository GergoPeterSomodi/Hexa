## Global application-level shortcut dispatcher (docs/architecture/ui-and-controls-spec.md sections 3.1, 3.3, 4.1).
## Runs with PROCESS_MODE_ALWAYS so app shortcuts (Esc ladder, menu, help, debug, fullscreen, screenshot)
## remain active while the world tree is paused under modal or opaque screens.
class_name AppInput
extends Node

signal back_requested
signal menu_requested
signal help_toggled
signal debug_toggled
signal fullscreen_toggled
signal screenshot_requested
signal quicksave_requested
signal quickload_requested
signal console_requested

var allow_dev_actions: bool = true
var enabled: bool = true

var _settings: Settings = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action(&"app_back"):
		Bindings.ensure()


func _exit_tree() -> void:
	_disconnect_settings()


## Applies developer tools gating from Settings and listens for live updates.
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


func _shortcut_input(event: InputEvent) -> void:
	if not enabled:
		return
	var key := event as InputEventKey
	if key == null:
		return
	if handle_key_event(key):
		_mark_handled()


## Dispatches a single key event against app-level InputMap actions; returns true if handled.
func handle_key_event(key: InputEventKey) -> bool:
	if not enabled or key == null or not key.pressed or key.is_echo():
		return false
	if _is_action_pressed_exact(key, &"app_back"):
		back_requested.emit()
		return true
	if _is_text_input_focused():
		return false
	if _is_action_pressed_exact(key, &"app_menu"):
		menu_requested.emit()
		return true
	if _is_action_pressed_exact(key, &"app_help"):
		help_toggled.emit()
		return true
	if allow_dev_actions and _is_action_pressed_exact(key, &"dev_debug"):
		debug_toggled.emit()
		return true
	if _is_action_pressed_exact(key, &"app_fullscreen"):
		fullscreen_toggled.emit()
		return true
	if _is_action_pressed_exact(key, &"app_screenshot"):
		screenshot_requested.emit()
		return true
	if _is_action_pressed_exact(key, &"game_quicksave"):
		quicksave_requested.emit()
		return true
	if _is_action_pressed_exact(key, &"game_quickload"):
		quickload_requested.emit()
		return true
	if allow_dev_actions and _is_action_pressed_exact(key, &"dev_console"):
		console_requested.emit()
		return true
	return false


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "dev/developer_tools":
		allow_dev_actions = bool(value)


func _disconnect_settings() -> void:
	if _settings != null and _settings.changed.is_connected(_on_setting_changed):
		_settings.changed.disconnect(_on_setting_changed)
	_settings = null


func _is_action_pressed_exact(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action, false, true)


func _is_text_input_focused() -> bool:
	if not is_inside_tree():
		return false
	var vp := get_viewport()
	if vp == null:
		return false
	var owner := vp.gui_get_focus_owner()
	return owner is LineEdit or owner is TextEdit


func _mark_handled() -> void:
	if is_inside_tree():
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
