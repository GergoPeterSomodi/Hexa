## Action-based map input controller (docs/architecture/ui-and-controls-spec.md sections 3.3, 4.1, 4.2, 4.5).
## Turns pointer clicks, hover and InputMap actions into intent signals; knows no game rules or tiles.
## Camera movement and zoom belong exclusively to CameraRig.
class_name MapInput
extends Node

signal select_requested(map_px: Vector2)
## A left click (no Shift) released on one of the viewer's unit tokens: `screen` is the viewport point. The token is
## hit before the hex (unit_at_func), so the hex under a unit is not selected by that click (MapArmies picks the unit).
signal unit_requested(screen: Vector2)
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
## `echo` is true for a held key's repeat; the receiver (SeasonFlow) refuses echoes.
signal end_season_requested(echo: bool)
signal report_requested
## `set` true stores the view in slot `index` (1 to 9); false goes to it.
signal bookmark_requested(index: int, set: bool)
signal undo_work_requested
## I opens the Statesman's Study on its last page (page &""), L on the Economy page (&"economy"): the App pushes it.
signal study_requested(page: StringName)
## Tab: select the next army that needs orders.
signal next_army_requested
## R: `continue_march` for the selected army.
signal continue_march_requested
## Alt+arrows: `direction` is a CURSOR_* value; `cursor_step` gives the hex it moves to.
signal cursor_moved(direction: int)
## O or Shift+F10: a right click at the cursor (or the selection).
signal command_key_requested
## Shift+O: storm at the cursor (M7 6.1).
signal storm_key_requested
## Shift+right click while `storm_ready` says an army of yours is selected: storm at that hex (else command_requested).
signal storm_requested(map_px: Vector2)
## Shift+left click while `waypoint_ready` says an army of yours is selected: add or remove a stop at that hex
## (moves-build-spec.md R58; else the plain select).
signal waypoint_requested(map_px: Vector2)
## V: the same at the order cursor or the hovered hex (R62).
signal waypoint_key_requested
## B: open the dock on the last battle of yours (M7 6.1).
signal battle_requested
## A click (select or command) while `orders_blocked` says so: it selects and orders nothing (M6 6.4: the replay's skip).
signal blocked_click(map_px: Vector2)

## An order the map would take is refused while the countries move or the replay plays (block_orders): the reason to toast,
## at most once a second. M8 6.2, D36.
signal blocked(reason: String)

## () -> bool, asked on a click's release: true while a movement replay runs, so the click is `blocked_click` instead.
var orders_blocked: Callable = Callable()
## () -> bool: skips a running live walk (MoveReplay.skip_live; moves-build-spec.md R49) and says whether it did. A click on the map
## and the keys that order skip it and then act; the End turn keys (Space, Enter) only skip it and do nothing more.
var live_skip: Callable = Callable()
## () -> bool, asked on a Shift+right click: true while an army of yours is selected, so the click storms. Unset: no army.
var storm_ready: Callable = Callable()
## () -> bool, asked on a Shift+left click: true while an army of yours is selected, so the click stages a stop. Unset: no army.
var waypoint_ready: Callable = Callable()
## Callable(screen: Vector2) -> bool, asked on a left click's release: true while one of the viewer's unit tokens stands
## under the viewport point (its screen rect, the zoom included). Unset: no units, every click is a hex click.
var unit_at_func := Callable()

const CURSOR_LEFT := 0
const CURSOR_RIGHT := 1
const CURSOR_UP := 2
const CURSOR_DOWN := 3
const CLICK_SLOP := 6.0
const NO_HEX := Vector2i(-9999, -9999)
const BLOCKED_GAP_MS := 1000

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
var _block_reason := ""
var _blocked_at := -BLOCKED_GAP_MS * 10
## () -> int, milliseconds, for the once-a-second rule; tests inject a fake.
var clock: Callable = Callable()


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


## While `reason` is not empty, select, command, the command key, upgrade, Tab, R, Ctrl+Z, Shift+O, Shift+right click,
## Shift+left click, V, B and J emit `blocked(reason)` and nothing else; the camera, the modes, the grid and names keys and the hover work.
## "" lifts it.
func block_orders(reason: String) -> void:
	_block_reason = reason


## True when the intent is refused: says so (once a second at most).
func _refuses() -> bool:
	if _block_reason.is_empty():
		return false
	var now := int(clock.call()) if clock.is_valid() else SimClock.msec()
	if now - _blocked_at >= BLOCKED_GAP_MS:
		_blocked_at = now
		blocked.emit(_block_reason)
	return true


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
	var orders := released_action == &"map_select" or released_action == &"map_command"
	if orders and _refuses():
		_mark_handled()
		return
	if orders and orders_blocked.is_valid() and bool(orders_blocked.call()):
		blocked_click.emit(map_px)
		_mark_handled()
		return
	_skip_live()
	if released_action == &"map_select":
		if _stages(mb):
			waypoint_requested.emit(map_px)
		elif _on_unit(mb):
			unit_requested.emit(mb.position)
		else:
			select_requested.emit(map_px)
		_mark_handled()
	elif released_action == &"map_command":
		if _storms(mb):
			storm_requested.emit(map_px)
		else:
			command_requested.emit(map_px)
		_mark_handled()


## Skips a running live walk before an input that acts; true when one was skipped.
func _skip_live() -> bool:
	return live_skip.is_valid() and bool(live_skip.call())


## True for a left click (no Shift) on a unit token: the unit is the target, not the hex under it.
func _on_unit(mb: InputEventMouseButton) -> bool:
	return not mb.shift_pressed and unit_at_func.is_valid() and bool(unit_at_func.call(mb.position))


## A Shift+right click (no Ctrl, Alt or Meta) with an army of yours selected: a storm, not a command (M7 6.1).
func _storms(mb: InputEventMouseButton) -> bool:
	return _shift_only(mb) and storm_ready.is_valid() and bool(storm_ready.call())


## A Shift+left click (no Ctrl, Alt or Meta) with an army of yours selected: a stop of its march, not a selection (R58).
func _stages(mb: InputEventMouseButton) -> bool:
	return _shift_only(mb) and waypoint_ready.is_valid() and bool(waypoint_ready.call())


## True when Shift is held and no other modifier.
static func _shift_only(mb: InputEventMouseButton) -> bool:
	return mb.shift_pressed and not (mb.ctrl_pressed or mb.alt_pressed or mb.meta_pressed)


func _on_mouse_motion(motion: InputEventMouseMotion) -> void:
	if _press_button != MOUSE_BUTTON_NONE and motion.position.distance_to(_press_at) >= CLICK_SLOP:
		_slop_broken = true
	if _slop_broken or _is_gui_hovered():
		_set_hover(NO_HEX)
		return
	_set_hover(_hex_at(map_px_of(motion.position)))


func _on_key(key: InputEventKey) -> void:
	if not key.pressed or _is_text_input_focused():
		return
	if event_is_exact_action(key, &"game_end_season", true):
		if _skip_live():  # Space and Enter end a live walk and do nothing more (R49)
			_mark_handled()
			return
		end_season_requested.emit(key.echo)
		_mark_handled()
		return
	if key.echo:
		return
	if _on_game_key(key):
		return
	if allow_dev_actions and _is_action_pressed_exact(key, &"dev_new_seed"):
		new_seed_requested.emit()
		_mark_handled()
		return
	var mode_actions: Array[StringName] = [&"view_mode_1", &"view_mode_2", &"view_mode_3", &"view_mode_4", &"view_mode_5", &"view_mode_6"]
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
		if not _refuses():
			upgrade_requested.emit()
		_mark_handled()


## The M3 to M7 keys: report, bookmarks, cancel work, the study, the army keys. Returns true when one fired. While orders
## are blocked the keys that order, select or open a report emit `blocked` instead.
func _on_game_key(key: InputEventKey) -> bool:
	var gated := _gated_key(key)
	if gated != &"":
		if _refuses():
			_mark_handled()
			return true
		_skip_live()
		_emit_gated(gated)
		_mark_handled()
		return true
	var fired := true
	if _is_action_pressed_exact(key, &"game_study"):
		study_requested.emit(&"")
	elif _is_action_pressed_exact(key, &"game_ledger"):
		study_requested.emit(&"economy")
	elif _cursor_direction(key) >= 0:
		cursor_moved.emit(_cursor_direction(key))
	else:
		var slot := _bookmark_slot(key)
		if slot.x == 0:
			fired = false
		else:
			bookmark_requested.emit(slot.x, slot.y == 1)
	if fired:
		_mark_handled()
	return fired


## The action of the keys that order or select (the ones block_orders gates), or &"".
func _gated_key(key: InputEventKey) -> StringName:
	for action: StringName in [&"game_report", &"game_undo_work", &"game_next_unit", &"game_continue_march",
			&"map_command_storm", &"game_battle", &"map_command_key", &"map_waypoint_key"]:
		if _is_action_pressed_exact(key, action):
			return action
	return &""


func _emit_gated(action: StringName) -> void:
	match action:
		&"game_report":
			report_requested.emit()
		&"game_undo_work":
			undo_work_requested.emit()
		&"game_next_unit":
			next_army_requested.emit()
		&"game_continue_march":
			continue_march_requested.emit()
		&"map_command_storm":
			storm_key_requested.emit()
		&"game_battle":
			battle_requested.emit()
		&"map_command_key":
			command_key_requested.emit()
		&"map_waypoint_key":
			waypoint_key_requested.emit()


## The CURSOR_* value of the Alt+arrow action the key presses, or -1.
func _cursor_direction(key: InputEventKey) -> int:
	var actions: Array[StringName] = [&"map_cursor_left", &"map_cursor_right", &"map_cursor_up", &"map_cursor_down"]
	for i: int in actions.size():
		if _is_action_pressed_exact(key, actions[i]):
			return i
	return -1


## The hex one Alt+arrow step from `hex` (odd rows sit half a hex to the right). Left and right are W and E; up and down
## keep the column: even rows go NE and SE, odd rows NW and SW, which is the same column and one row away.
static func cursor_step(hex: Vector2i, direction: int) -> Vector2i:
	match direction:
		CURSOR_LEFT:
			return hex + Vector2i(-1, 0)
		CURSOR_RIGHT:
			return hex + Vector2i(1, 0)
		CURSOR_UP:
			return hex + Vector2i(0, -1)
		CURSOR_DOWN:
			return hex + Vector2i(0, 1)
	return hex


## (index, 1 if set else 0) of the bookmark action the key presses, or (0, 0).
func _bookmark_slot(key: InputEventKey) -> Vector2i:
	for i: int in range(1, 10):
		if _is_action_pressed_exact(key, StringName("cam_bookmark_set_%d" % i)):
			return Vector2i(i, 1)
		if _is_action_pressed_exact(key, StringName("cam_bookmark_go_%d" % i)):
			return Vector2i(i, 0)
	return Vector2i.ZERO


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
	return event_is_exact_action(event, action, false)


## Exact-modifier match; `echo_ok` lets a held key's repeats through.
func event_is_exact_action(event: InputEvent, action: StringName, echo_ok: bool) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action, echo_ok, true)


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
