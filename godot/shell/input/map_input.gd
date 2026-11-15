## The mouse and keyboard of the map as intents (docs/architecture/m1-build-spec.md section 8). It moves and zooms the
## camera itself (that is all it changes) and tells the scene what the player means with signals; it knows no rules and
## no tiles. The scene hands it the camera and the node whose local mouse position is a map position.
##
## Left click (a press that moves less than CLICK_SLOP px) selects; right click or Esc clears; a drag with any button, or
## WASD and the arrows, moves; the wheel zooms about the pointer. Keys: 1 to 4 the season, R a new seed, G the grid,
## F the whole map, H the panel and help, U upgrade the selected hex.
class_name MapInput
extends Node

signal select_requested(map_px: Vector2)
signal clear_selection_requested
signal season_requested(index: int)
signal new_seed_requested
signal grid_toggled
signal fit_requested
signal hud_toggled
signal upgrade_requested

const ZOOM_MIN := 0.03
const ZOOM_MAX := 4.0
const ZOOM_STEP := 1.15
const PAN_SPEED := 700.0  # map px a second at zoom 1, with the keys
## A press that moves less than this many screen px before it is let go is a click, not a drag.
const CLICK_SLOP := 6.0

var camera: Camera2D = null
## Any node of the map (at the map's origin): the window's points are turned into its coordinates.
var map_node: Node2D = null
## Off while a screen or a text field wants the keys.
var enabled := true

var _press_at := Vector2.ZERO
var _dragging := false


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or camera == null:
		return
	if event is InputEventMouseButton:
		_on_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _dragging:
		camera.position -= (event as InputEventMouseMotion).relative / camera.zoom.x
	elif event is InputEventKey:
		_on_key(event as InputEventKey)


func _on_button(button: InputEventMouseButton) -> void:
	if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
		zoom_about(button.position, ZOOM_STEP)
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
		zoom_about(button.position, 1.0 / ZOOM_STEP)
	elif button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
		_dragging = button.pressed
		if button.pressed:
			_press_at = button.position
		elif button.position.distance_to(_press_at) < CLICK_SLOP:
			if button.button_index == MOUSE_BUTTON_LEFT:
				select_requested.emit(map_px_of(button.position))
			elif button.button_index == MOUSE_BUTTON_RIGHT:
				clear_selection_requested.emit()


func _on_key(key: InputEventKey) -> void:
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			season_requested.emit(int(key.keycode) - int(KEY_1))
		KEY_R:
			new_seed_requested.emit()
		KEY_U:
			upgrade_requested.emit()
		KEY_F:
			fit_requested.emit()
		KEY_H:
			hud_toggled.emit()
		KEY_G:
			grid_toggled.emit()
		KEY_ESCAPE:
			clear_selection_requested.emit()


func _process(delta: float) -> void:
	if camera == null:
		return
	if _dragging and not (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		_dragging = false  # the release went to the panel, not here
	if not enabled:
		return
	var step := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		step.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		step.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		step.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		step.y += 1.0
	if step != Vector2.ZERO:
		camera.position += step * PAN_SPEED * delta / camera.zoom.x


## The map position under a point of the window.
func map_px_of(screen: Vector2) -> Vector2:
	return map_node.get_global_transform_with_canvas().affine_inverse() * screen


## Zooms so that the map point under a screen position stays under it.
func zoom_about(screen: Vector2, factor: float) -> void:
	var view := camera.get_viewport_rect().size
	var before := camera.position + (screen - view / 2.0) / camera.zoom.x
	var z := clampf(camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(z, z)
	camera.position = before - (screen - view / 2.0) / z
