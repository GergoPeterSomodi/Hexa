## Camera rig (docs/architecture/ui-and-controls-spec.md sections 3.3, 4.2 to 4.4):
## the only node that moves and zooms the map Camera2D. Handles mouse wheel,
## trackpad pan/magnify gestures, drag past CLICK_SLOP, action-based key pan/zoom/fit,
## edge pan, smooth zoom easing, look_at glide, and map-bounds clamping via ZoomModel.
class_name CameraRig
extends Node

signal view_changed(zoom: float, visible_map_rect: Rect2)

const CLICK_SLOP := 6.0
const GESTURE_PAN_PX := 20.0
const WHEEL_PAN_PX := 64.0
const EDGE_PAN_MARGIN_PX := 8.0
const KEY_ZOOM_NOTCHES := 2.0

var camera: Camera2D = null
var map_size := Vector2.ZERO
var free_rect := Rect2()
var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			_clear_active_inputs()

# Settings-driven parameters (defaults match Settings.SCHEMA).
var wheel_action := "zoom"
var gesture_action := "pan"
var invert_scroll := false
var pan_speed := 100
var zoom_speed := 100
var zoom_smoothing := true
var zoom_anchor := "pointer"
var edge_pan := false
var edge_pan_speed := 100
var reduce_motion := false

var _settings: Settings = null
var _current_zoom := 1.0
var _target_zoom := 1.0
var _zoom_anchor_screen := Vector2.ZERO
var _mouse_down := false
var _drag_active := false
var _saw_hardware_button := false
var _press_button: MouseButton = MOUSE_BUTTON_NONE
var _last_drag_pos := Vector2.ZERO
var _pending_drag := Vector2.ZERO
var _held_actions: Dictionary[StringName, bool] = {}
var _saw_hardware_actions: Dictionary[StringName, bool] = {}
var _gliding := false
var _glide_from := Vector2.ZERO
var _glide_to := Vector2.ZERO
var _glide_elapsed := 0.0
var _window_focused := true
var _last_emitted_zoom := -1.0
var _last_emitted_rect := Rect2()
var _connected_viewport: Viewport = null


func _ready() -> void:
	if not InputMap.has_action(&"cam_pan_left"):
		Bindings.ensure()
	_connect_viewport()
	if camera != null:
		_current_zoom = camera.zoom.x
		_target_zoom = _current_zoom
		_zoom_anchor_screen = _free_centre_screen()


func _exit_tree() -> void:
	_disconnect_viewport()
	_disconnect_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_focused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false
		_clear_active_inputs()


## Binds the Camera2D, map pixel size, and optional free-area rect (window minus top bar).
func setup(p_camera: Camera2D, p_map_size: Vector2, p_free_rect: Rect2 = Rect2()) -> void:
	camera = p_camera
	map_size = p_map_size
	free_rect = p_free_rect
	if camera != null:
		_current_zoom = camera.zoom.x
		_target_zoom = _current_zoom
		_zoom_anchor_screen = _free_centre_screen()


func set_map_size(p_map_size: Vector2) -> void:
	map_size = p_map_size
	_clamp_state_to_bounds()


func set_free_rect(p_free_rect: Rect2) -> void:
	free_rect = p_free_rect
	_clamp_state_to_bounds()


## Applies player control and accessibility settings, and listens for live updates.
func configure(settings: Settings) -> void:
	if settings == _settings and settings != null:
		_apply_settings(settings)
		return
	_disconnect_settings()
	_settings = settings
	if _settings == null:
		return
	_settings.changed.connect(_on_setting_changed)
	_apply_settings(_settings)


func _apply_settings(settings: Settings) -> void:
	wheel_action = str(settings.get_value("controls/wheel_action"))
	gesture_action = str(settings.get_value("controls/gesture_action"))
	invert_scroll = bool(settings.get_value("controls/invert_scroll"))
	pan_speed = int(settings.get_value("controls/pan_speed"))
	zoom_speed = int(settings.get_value("controls/zoom_speed"))
	zoom_smoothing = bool(settings.get_value("controls/zoom_smoothing"))
	zoom_anchor = str(settings.get_value("controls/zoom_anchor"))
	edge_pan = bool(settings.get_value("controls/edge_pan"))
	edge_pan_speed = int(settings.get_value("controls/edge_pan_speed"))
	reduce_motion = bool(settings.get_value("accessibility/reduce_motion"))
	if reduce_motion or not zoom_smoothing:
		_snap_zoom_to_target()
	if reduce_motion and _gliding:
		_snap_glide_to_target()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if _settings == null:
		return
	if key.begins_with("controls/") or key == "accessibility/reduce_motion":
		_apply_settings(_settings)


func _disconnect_settings() -> void:
	if _settings != null and _settings.changed.is_connected(_on_setting_changed):
		_settings.changed.disconnect(_on_setting_changed)
	_settings = null


func _connect_viewport() -> void:
	var vp := get_viewport()
	if vp == _connected_viewport:
		return
	_disconnect_viewport()
	_connected_viewport = vp
	if _connected_viewport != null and not _connected_viewport.size_changed.is_connected(_on_viewport_size_changed):
		_connected_viewport.size_changed.connect(_on_viewport_size_changed)


func _disconnect_viewport() -> void:
	if _connected_viewport != null and _connected_viewport.size_changed.is_connected(_on_viewport_size_changed):
		_connected_viewport.size_changed.disconnect(_on_viewport_size_changed)
	_connected_viewport = null


func _on_viewport_size_changed() -> void:
	_clamp_state_to_bounds()


func zoom() -> float:
	if camera != null:
		return camera.zoom.x
	return _current_zoom


func get_zoom() -> float:
	return zoom()


func target_zoom() -> float:
	return _target_zoom


func min_zoom() -> float:
	return ZoomModel.min_zoom(_free_size(), map_size)


func max_zoom() -> float:
	return ZoomModel.ZOOM_MAX


func fit_zoom() -> float:
	return ZoomModel.fit_zoom(_free_size(), map_size)


func pixels_per_hex() -> float:
	return float(MapTiles.CELL.x) * zoom()


func visible_map_rect() -> Rect2:
	if camera == null:
		return Rect2()
	var z := maxf(camera.zoom.x, 1.0e-5)
	var view_size := _viewport_size()
	var span := view_size / z
	return Rect2(camera.position - span * 0.5, span)


## Frames the entire map inside the free area immediately.
func fit() -> void:
	if camera == null:
		return
	_gliding = false
	var z := fit_zoom()
	var centre := map_size * 0.5
	_set_camera_immediate(centre, z)


## Programmatic/test framing at a specific centre and zoom (allows far-zoom values below min_zoom).
func frame_at(centre: Vector2, zoom_val: float) -> void:
	if camera == null:
		return
	_gliding = false
	var min_allowed := minf(min_zoom(), 0.02)
	var z := clampf(zoom_val, min_allowed, ZoomModel.ZOOM_MAX)
	_current_zoom = z
	_target_zoom = z
	camera.zoom = Vector2(z, z)
	camera.position = centre
	camera.force_update_scroll()


## Adjusts zoom when UI scale changes so the same map area remains visible.
func apply_ui_scale_change(old_scale: float, new_scale: float) -> void:
	if camera == null:
		return
	var scaled := ZoomModel.scale_for_ui_change(_target_zoom, old_scale, new_scale)
	var clamped := ZoomModel.clamp_zoom(scaled, _free_size(), map_size)
	_set_camera_immediate(camera.position, clamped)


## Zooms by `notches` (positive zooms in, negative zooms out) around `anchor_screen` or the free centre.
func zoom_by(notches: float, anchor_screen: Variant = null) -> void:
	if camera == null or is_zero_approx(notches):
		return
	var base_notch := ZoomModel.notch_factor(float(zoom_speed), 1.0)
	var factor := pow(base_notch, notches)
	_request_zoom_factor(factor, anchor_screen, true)


func zoom_in() -> void:
	zoom_by(KEY_ZOOM_NOTCHES)


func zoom_out() -> void:
	zoom_by(-KEY_ZOOM_NOTCHES)


func zoom_reset() -> void:
	fit()


## Zooms to an explicit target zoom value (clamped) around `anchor_screen` or the free centre.
func zoom_to(new_zoom: float, anchor_screen: Variant = null) -> void:
	if camera == null:
		return
	var clamped := ZoomModel.clamp_zoom(new_zoom, _free_size(), map_size)
	_target_zoom = clamped
	_zoom_anchor_screen = _resolve_anchor(anchor_screen)
	if reduce_motion or not zoom_smoothing:
		_snap_zoom_to_target()


## Pans the camera by `screen_px` screen pixels (positive moves camera right/down) and clamps bounds.
func pan_by(screen_px: Vector2) -> void:
	if camera == null or screen_px == Vector2.ZERO:
		return
	_gliding = false
	var z := maxf(_current_zoom, 1.0e-5)
	camera.position += screen_px / z
	_clamp_centre()


## Glides (or jumps under reduce_motion/instant) the camera centre to `map_px`, optionally changing zoom.
func look_at(map_px: Vector2, new_zoom: float = -1.0, instant: bool = false) -> void:
	if camera == null:
		return
	var eff_zoom := _current_zoom
	if new_zoom > 0.0:
		eff_zoom = ZoomModel.clamp_zoom(new_zoom, _free_size(), map_size)
		_target_zoom = eff_zoom
		_zoom_anchor_screen = _free_centre_screen()
	var dest := _clamped_centre_for(map_px, eff_zoom)
	if instant or reduce_motion:
		_gliding = false
		_set_camera_immediate(dest, eff_zoom)
		return
	_glide_from = camera.position
	_glide_to = dest
	_glide_elapsed = 0.0
	_gliding = true
	if not zoom_smoothing and new_zoom > 0.0:
		_snap_zoom_to_target()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or camera == null:
		return
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventMagnifyGesture:
		_on_magnify_gesture(event as InputEventMagnifyGesture)
	elif event is InputEventPanGesture:
		_on_pan_gesture(event as InputEventPanGesture)
	elif event is InputEventKey:
		_on_key(event as InputEventKey)


func _on_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		if mb.pressed:
			_on_wheel(mb)
		return
	if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
		if mb.pressed:
			_mouse_down = true
			_drag_active = false
			_press_button = mb.button_index
			_saw_hardware_button = Input.is_mouse_button_pressed(mb.button_index)
			_last_drag_pos = mb.position
			_pending_drag = Vector2.ZERO
		elif mb.button_index == _press_button or not _mouse_down:
			_mouse_down = false
			_drag_active = false
			_saw_hardware_button = false
			_press_button = MOUSE_BUTTON_NONE
			_pending_drag = Vector2.ZERO


func _on_mouse_motion(motion: InputEventMouseMotion) -> void:
	if not _mouse_down:
		return
	var step := motion.relative if motion.relative != Vector2.ZERO else (motion.position - _last_drag_pos)
	_last_drag_pos = motion.position
	if step == Vector2.ZERO:
		return
	if not _drag_active:
		_pending_drag += step
		if _pending_drag.length() < CLICK_SLOP:
			return
		_drag_active = true
		pan_by(-_pending_drag)
		_pending_drag = Vector2.ZERO
		return
	pan_by(-step)


func _on_wheel(mb: InputEventMouseButton) -> void:
	var factor := 1.0 if is_zero_approx(mb.factor) else mb.factor
	var has_ctrl_cmd := mb.ctrl_pressed or mb.meta_pressed or mb.is_command_or_control_pressed()
	var sign_mul := -1.0 if invert_scroll else 1.0
	var pan_px := WHEEL_PAN_PX * (float(pan_speed) / 100.0) * factor * sign_mul

	if mb.button_index == MOUSE_BUTTON_WHEEL_LEFT:
		pan_by(Vector2(-pan_px, 0.0))
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
		pan_by(Vector2(pan_px, 0.0))
		return

	var is_up := mb.button_index == MOUSE_BUTTON_WHEEL_UP
	if mb.shift_pressed and not has_ctrl_cmd:
		pan_by(Vector2(-pan_px if is_up else pan_px, 0.0))
		return

	if has_ctrl_cmd or wheel_action == "zoom":
		var notch := ZoomModel.notch_factor(float(zoom_speed), factor)
		_request_zoom_factor(notch if is_up else (1.0 / notch), mb.position, true)
	else:
		pan_by(Vector2(0.0, -pan_px if is_up else pan_px))


func _on_magnify_gesture(gesture: InputEventMagnifyGesture) -> void:
	if gesture.factor <= 0.0:
		return
	# Pinch follows fingers directly with no smoothing.
	_request_zoom_factor(gesture.factor, gesture.position, false)


func _on_pan_gesture(gesture: InputEventPanGesture) -> void:
	var has_ctrl_cmd := gesture.ctrl_pressed or gesture.meta_pressed or gesture.is_command_or_control_pressed()
	var wants_zoom := gesture_action == "zoom"
	if has_ctrl_cmd:
		wants_zoom = not wants_zoom
	if wants_zoom:
		if is_zero_approx(gesture.delta.y):
			return
		var base_notch := ZoomModel.notch_factor(float(zoom_speed), 1.0)
		var factor := pow(base_notch, -gesture.delta.y)
		_request_zoom_factor(factor, gesture.position, false)
		return
	var sign_mul := -1.0 if invert_scroll else 1.0
	var speed_mul := float(pan_speed) / 100.0
	pan_by(gesture.delta * GESTURE_PAN_PX * speed_mul * sign_mul)


func _on_key(key: InputEventKey) -> void:
	var has_non_shift_mod := key.ctrl_pressed or key.alt_pressed or key.meta_pressed
	for pan_action: StringName in [&"cam_pan_left", &"cam_pan_right", &"cam_pan_up", &"cam_pan_down", &"cam_pan_fast"]:
		if InputMap.has_action(pan_action) and key.is_action(pan_action):
			if key.pressed:
				if _is_text_input_focused():
					continue
				if pan_action != &"cam_pan_fast" and has_non_shift_mod:
					continue
				_held_actions[pan_action] = true
				_saw_hardware_actions[pan_action] = Input.is_action_pressed(pan_action)
			else:
				_held_actions.erase(pan_action)
				_saw_hardware_actions.erase(pan_action)
	if not key.pressed or _is_text_input_focused() or has_non_shift_mod:
		return
	if InputMap.has_action(&"cam_zoom_in") and key.is_action_pressed(&"cam_zoom_in", true):
		zoom_by(KEY_ZOOM_NOTCHES)
		_mark_handled()
		return
	if InputMap.has_action(&"cam_zoom_out") and key.is_action_pressed(&"cam_zoom_out", true):
		zoom_by(-KEY_ZOOM_NOTCHES)
		_mark_handled()
		return
	if not key.echo and InputMap.has_action(&"cam_fit") and key.is_action_pressed(&"cam_fit", false, true):
		fit()
		_mark_handled()


func _process(delta: float) -> void:
	if camera == null:
		return
	_sync_held_inputs()
	if enabled:
		_step_key_pan(delta)
		_step_edge_pan(delta)
	_step_glide(delta)
	_step_zoom(delta)
	_emit_view_if_changed()


func _sync_held_inputs() -> void:
	if _mouse_down and _saw_hardware_button:
		if not Input.is_mouse_button_pressed(_press_button):
			_mouse_down = false
			_drag_active = false
			_saw_hardware_button = false
			_press_button = MOUSE_BUTTON_NONE
			_pending_drag = Vector2.ZERO
	var to_erase: Array[StringName] = []
	for action: StringName in _held_actions:
		if _saw_hardware_actions.get(action, false) and not Input.is_action_pressed(action):
			to_erase.append(action)
	for action: StringName in to_erase:
		_held_actions.erase(action)
		_saw_hardware_actions.erase(action)


func _step_key_pan(delta: float) -> void:
	if delta <= 0.0 or _is_text_input_focused():
		return
	var dir := Vector2.ZERO
	if _is_action_active(&"cam_pan_left"):
		dir.x -= 1.0
	if _is_action_active(&"cam_pan_right"):
		dir.x += 1.0
	if _is_action_active(&"cam_pan_up"):
		dir.y -= 1.0
	if _is_action_active(&"cam_pan_down"):
		dir.y += 1.0
	if dir == Vector2.ZERO:
		return
	var speed := ZoomModel.PAN_BASE_PX_PER_SEC * (float(pan_speed) / 100.0)
	if _is_action_active(&"cam_pan_fast"):
		speed *= ZoomModel.PAN_FAST_MULT
	pan_by(dir.normalized() * speed * delta)


func _step_edge_pan(delta: float) -> void:
	if not edge_pan or delta <= 0.0 or not _window_focused or _mouse_down or _drag_active:
		return
	var vp := get_viewport()
	if vp == null:
		return
	if vp.gui_get_hovered_control() != null:
		return
	var view_size := _viewport_size()
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return
	var mouse := vp.get_mouse_position()
	if not Rect2(Vector2.ZERO, view_size).has_point(mouse):
		return
	var dir := Vector2.ZERO
	if mouse.x <= EDGE_PAN_MARGIN_PX:
		dir.x -= 1.0
	elif mouse.x >= view_size.x - EDGE_PAN_MARGIN_PX:
		dir.x += 1.0
	if mouse.y <= EDGE_PAN_MARGIN_PX:
		dir.y -= 1.0
	elif mouse.y >= view_size.y - EDGE_PAN_MARGIN_PX:
		dir.y += 1.0
	if dir == Vector2.ZERO:
		return
	var speed := ZoomModel.PAN_BASE_PX_PER_SEC * (float(pan_speed) / 100.0) * (float(edge_pan_speed) / 100.0)
	pan_by(dir.normalized() * speed * delta)


func _step_glide(delta: float) -> void:
	if not _gliding:
		return
	if reduce_motion or ZoomModel.GLIDE_TIME <= 0.0:
		_snap_glide_to_target()
		return
	_glide_elapsed += maxf(delta, 0.0)
	var t := clampf(_glide_elapsed / ZoomModel.GLIDE_TIME, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	camera.position = _glide_from.lerp(_glide_to, eased)
	_clamp_centre()
	if t >= 1.0:
		_gliding = false


func _step_zoom(delta: float) -> void:
	if is_equal_approx(_current_zoom, _target_zoom):
		if _current_zoom != _target_zoom:
			_snap_zoom_to_target()
		return
	var next_z := ZoomModel.step_smooth(_current_zoom, _target_zoom, delta, reduce_motion, zoom_smoothing)
	_apply_zoom_step(next_z)


func _request_zoom_factor(factor: float, anchor_screen: Variant, allow_smoothing: bool) -> void:
	var next_target := ZoomModel.clamp_zoom(_target_zoom * factor, _free_size(), map_size)
	_target_zoom = next_target
	_zoom_anchor_screen = _resolve_anchor(anchor_screen)
	if not allow_smoothing or reduce_motion or not zoom_smoothing:
		_snap_zoom_to_target()


func _snap_zoom_to_target() -> void:
	if camera == null:
		_current_zoom = _target_zoom
		return
	_apply_zoom_step(_target_zoom)


func _snap_glide_to_target() -> void:
	_gliding = false
	if camera == null:
		return
	camera.position = _glide_to
	_clamp_centre()


func _apply_zoom_step(next_z: float) -> void:
	var anchor_offset := _zoom_anchor_screen - _viewport_size() * 0.5
	camera.position = ZoomModel.zoom_about(camera.position, _current_zoom, next_z, anchor_offset)
	_current_zoom = next_z
	camera.zoom = Vector2(next_z, next_z)
	_clamp_centre()


func _set_camera_immediate(centre: Vector2, zoom_val: float) -> void:
	_current_zoom = zoom_val
	_target_zoom = zoom_val
	camera.zoom = Vector2(zoom_val, zoom_val)
	camera.position = _clamped_centre_for(centre, zoom_val)
	camera.force_update_scroll()


func _clamp_state_to_bounds() -> void:
	if camera == null:
		return
	_target_zoom = ZoomModel.clamp_zoom(_target_zoom, _free_size(), map_size)
	_current_zoom = ZoomModel.clamp_zoom(_current_zoom, _free_size(), map_size)
	camera.zoom = Vector2(_current_zoom, _current_zoom)
	_clamp_centre()


func _clamp_centre() -> void:
	if camera == null:
		return
	camera.position = _clamped_centre_for(camera.position, _current_zoom)
	camera.force_update_scroll()


func _clamped_centre_for(centre: Vector2, z: float) -> Vector2:
	if map_size == Vector2.ZERO:
		return centre
	return ZoomModel.clamp_centre_for_view(centre, z, _free_size(), map_size)


func _resolve_anchor(anchor_screen: Variant) -> Vector2:
	if zoom_anchor == "centre" or anchor_screen == null:
		return _free_centre_screen()
	if anchor_screen is Vector2:
		return anchor_screen as Vector2
	return _free_centre_screen()


func _viewport_size() -> Vector2:
	if camera != null and camera.is_inside_tree():
		var rect := camera.get_viewport_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			return rect.size
	if is_inside_tree():
		var rect := get_viewport().get_visible_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			return rect.size
	if free_rect.size.x > 0.0 and free_rect.size.y > 0.0:
		return free_rect.size
	return Vector2(1280.0, 720.0)


func _free_size() -> Vector2:
	if free_rect.size.x > 0.0 and free_rect.size.y > 0.0:
		return free_rect.size
	return _viewport_size()


func _free_centre_screen() -> Vector2:
	if free_rect.size.x > 0.0 and free_rect.size.y > 0.0:
		return free_rect.get_center()
	return _viewport_size() * 0.5


func _is_action_active(action: StringName) -> bool:
	if bool(_held_actions.get(action, false)):
		return true
	if InputMap.has_action(action) and Input.is_action_pressed(action):
		if action != &"cam_pan_fast" and (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_META)):
			return false
		return true
	return false


func _is_text_input_focused() -> bool:
	if not is_inside_tree():
		return false
	var vp := get_viewport()
	if vp == null:
		return false
	var owner := vp.gui_get_focus_owner()
	return owner is LineEdit or owner is TextEdit


func _clear_active_inputs() -> void:
	_mouse_down = false
	_drag_active = false
	_saw_hardware_button = false
	_press_button = MOUSE_BUTTON_NONE
	_pending_drag = Vector2.ZERO
	_held_actions.clear()
	_saw_hardware_actions.clear()


func _mark_handled() -> void:
	if is_inside_tree():
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


func _emit_view_if_changed() -> void:
	var rect := visible_map_rect()
	if not is_equal_approx(_current_zoom, _last_emitted_zoom) or rect != _last_emitted_rect:
		_last_emitted_zoom = _current_zoom
		_last_emitted_rect = rect
		view_changed.emit(_current_zoom, rect)
