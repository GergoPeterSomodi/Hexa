## Tests for CameraRig (docs/architecture/ui-and-controls-spec.md sections 4.2 to 4.4 and 9).
extends GutTest

const VIEW_SIZE := Vector2i(1280, 720)
const NORTH_ITALY_SIZE := Vector2(2236.0, 1708.5)
const EUROPE_SIZE := Vector2(51428.0, 18921.0)

var _vp: SubViewport = null
var _camera: Camera2D = null
var _rig: CameraRig = null


func before_each() -> void:
	Bindings.reset_defaults()
	_vp = SubViewport.new()
	_vp.size = VIEW_SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.gui_disable_input = false
	add_child_autofree(_vp)

	_camera = Camera2D.new()
	_rig = CameraRig.new()
	_vp.add_child(_camera)
	_vp.add_child(_rig)
	_rig.setup(_camera, NORTH_ITALY_SIZE, Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)))
	_rig.fit()


func after_each() -> void:
	Bindings.reset_defaults()
	_rig = null
	_camera = null
	_vp = null


func _wheel(button: MouseButton, pos: Vector2, factor: float = 1.0, ctrl: bool = false, shift: bool = false, meta: bool = false) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.position = pos
	ev.global_position = pos
	ev.factor = factor
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = shift
	ev.meta_pressed = meta
	ev.pressed = true
	return ev


func _mouse_btn(button: MouseButton, pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.position = pos
	ev.global_position = pos
	ev.pressed = pressed
	return ev


func _mouse_motion(pos: Vector2, rel: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = rel
	return ev


func test_fit_and_zoom_limits_clamp_min_and_max() -> void:
	var expected_fit := ZoomModel.fit_zoom(Vector2(VIEW_SIZE), NORTH_ITALY_SIZE)
	assert_almost_eq(_rig.zoom(), expected_fit, 1.0e-4)
	assert_eq(_camera.position, NORTH_ITALY_SIZE * 0.5)

	var settings := Settings.new("macOS", false)
	settings.set_value("controls/zoom_smoothing", false)
	_rig.configure(settings)

	_rig.zoom_to(9.0)
	assert_eq(_rig.zoom(), ZoomModel.ZOOM_MAX, "zoom clamped to ZOOM_MAX (2.0)")
	_rig.zoom_to(0.01)
	assert_almost_eq(_rig.zoom(), _rig.min_zoom(), 1.0e-5, "zoom clamped to min_zoom")


func test_wheel_with_factor_zooms_about_pointer_and_smooths() -> void:
	_rig.frame_at(NORTH_ITALY_SIZE * 0.5, 1.0)
	var pointer := Vector2(900.0, 500.0)
	var offset := pointer - Vector2(VIEW_SIZE) * 0.5
	var map_pt_before := _camera.position + offset / _rig.zoom()

	_rig._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP, pointer, 2.0))
	var expected_target := ZoomModel.clamp_zoom(1.0 * ZoomModel.notch_factor(100.0, 2.0), Vector2(VIEW_SIZE), NORTH_ITALY_SIZE)
	assert_almost_eq(_rig.target_zoom(), expected_target, 1.0e-4)
	assert_lt(_rig.zoom(), expected_target, "smoothing does not jump on first event")

	for _i: int in range(60):
		_rig._process(1.0 / 60.0)
	assert_almost_eq(_rig.zoom(), expected_target, 1.0e-4, "smooth zoom converges to target")
	var map_pt_after := _camera.position + offset / _rig.zoom()
	assert_almost_eq(map_pt_after.x, map_pt_before.x, 0.01, "map X under pointer stays fixed")
	assert_almost_eq(map_pt_after.y, map_pt_before.y, 0.01, "map Y under pointer stays fixed")


func test_zoom_anchor_centre_ignores_pointer_offset() -> void:
	var settings := Settings.new("macOS", false)
	settings.set_value("controls/zoom_smoothing", false)
	settings.set_value("controls/zoom_anchor", "centre")
	_rig.configure(settings)
	_rig.frame_at(NORTH_ITALY_SIZE * 0.5, 1.0)
	var start_pos := _camera.position
	_rig._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP, Vector2(1100.0, 650.0), 1.0))
	assert_gt(_rig.zoom(), 1.0)
	assert_eq(_camera.position, start_pos, "centre anchor keeps camera centre fixed")


func test_ctrl_wheel_always_zooms_even_when_wheel_action_is_pan() -> void:
	var settings := Settings.new("Windows", false)
	settings.set_value("controls/wheel_action", "pan")
	settings.set_value("controls/zoom_smoothing", false)
	_rig.configure(settings)
	_rig.set_map_size(EUROPE_SIZE)
	_rig.frame_at(EUROPE_SIZE * 0.5, 1.0)

	var pos_before := _camera.position
	_rig._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN, Vector2(640.0, 360.0), 1.0))
	assert_eq(_rig.zoom(), 1.0, "plain wheel pans when wheel_action is pan")
	assert_gt(_camera.position.y, pos_before.y)

	_rig._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP, Vector2(640.0, 360.0), 1.0, true, false))
	assert_gt(_rig.zoom(), 1.0, "Ctrl+wheel always zooms")

	var z_after_ctrl := _rig.zoom()
	_rig._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP, Vector2(640.0, 360.0), 1.0, false, false, true))
	assert_gt(_rig.zoom(), z_after_ctrl, "Cmd+wheel always zooms")


func test_shift_wheel_and_tilt_wheel_pan_sideways_and_invert_scroll() -> void:
	var settings := Settings.new("Windows", false)
	_rig.configure(settings)
	_rig.set_map_size(EUROPE_SIZE)
	_rig.frame_at(EUROPE_SIZE * 0.5, 1.0)

	var x0 := _camera.position.x
	_rig._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN, Vector2(640.0, 360.0), 1.0, false, true))
	assert_almost_eq(_camera.position.x - x0, CameraRig.WHEEL_PAN_PX, 0.01, "Shift+wheel down pans right")
	_rig._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_LEFT, Vector2(640.0, 360.0), 1.0))
	assert_almost_eq(_camera.position.x, x0, 0.01, "WHEEL_LEFT pans left")

	settings.set_value("controls/invert_scroll", true)
	_rig._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_RIGHT, Vector2(640.0, 360.0), 1.0))
	assert_almost_eq(x0 - _camera.position.x, CameraRig.WHEEL_PAN_PX, 0.01, "invert_scroll flips wheel pan")


func test_pan_gesture_pans_and_ctrl_switches_to_zoom() -> void:
	var settings := Settings.new("macOS", false)
	settings.set_value("controls/pan_speed", 150)
	_rig.configure(settings)
	_rig.set_map_size(EUROPE_SIZE)
	_rig.frame_at(EUROPE_SIZE * 0.5, 1.0)

	var pos0 := _camera.position
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(2.0, -1.0)
	pan.position = Vector2(640.0, 360.0)
	_rig._unhandled_input(pan)
	var expected_delta := Vector2(2.0, -1.0) * CameraRig.GESTURE_PAN_PX * 1.5
	assert_almost_eq(_camera.position.x, pos0.x + expected_delta.x, 0.01)
	assert_almost_eq(_camera.position.y, pos0.y + expected_delta.y, 0.01)

	var ctrl_pan := InputEventPanGesture.new()
	ctrl_pan.delta = Vector2(0.0, -1.0)
	ctrl_pan.position = Vector2(640.0, 360.0)
	ctrl_pan.ctrl_pressed = true
	_rig._unhandled_input(ctrl_pan)
	assert_gt(_rig.zoom(), 1.0, "Ctrl+PanGesture switches to zoom when default is pan")


func test_magnify_gesture_zooms_about_point_without_smoothing() -> void:
	_rig.set_map_size(EUROPE_SIZE)
	_rig.frame_at(EUROPE_SIZE * 0.5, 1.0)
	var at := Vector2(820.0, 260.0)
	var offset := at - Vector2(VIEW_SIZE) * 0.5
	var map_pt_before := _camera.position + offset / _rig.zoom()

	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 1.4
	pinch.position = at
	_rig._unhandled_input(pinch)
	assert_almost_eq(_rig.zoom(), 1.4, 1.0e-4, "magnify updates zoom immediately (no smoothing)")
	assert_almost_eq(_rig.target_zoom(), 1.4, 1.0e-4)
	var map_pt_after := _camera.position + offset / _rig.zoom()
	assert_almost_eq(map_pt_after.x, map_pt_before.x, 0.01)
	assert_almost_eq(map_pt_after.y, map_pt_before.y, 0.01)


func test_drag_does_not_move_inside_slop_and_pans_past_slop() -> void:
	_rig.set_map_size(EUROPE_SIZE)
	_rig.frame_at(EUROPE_SIZE * 0.5, 1.0)
	var start := _camera.position

	_rig._unhandled_input(_mouse_btn(MOUSE_BUTTON_LEFT, Vector2(500.0, 400.0), true))
	_rig._unhandled_input(_mouse_motion(Vector2(503.0, 402.0), Vector2(3.0, 2.0)))
	assert_eq(_camera.position, start, "camera does not move inside 6 px slop")

	_rig._unhandled_input(_mouse_motion(Vector2(520.0, 400.0), Vector2(17.0, -2.0)))
	assert_almost_eq(_camera.position.x, start.x - 20.0, 0.01, "camera catches up 1:1 once past slop")
	assert_almost_eq(_camera.position.y, start.y, 0.01)

	_rig._unhandled_input(_mouse_motion(Vector2(530.0, 410.0), Vector2(10.0, 10.0)))
	assert_almost_eq(_camera.position.x, start.x - 30.0, 0.01)
	assert_almost_eq(_camera.position.y, start.y - 10.0, 0.01)
	_rig._unhandled_input(_mouse_btn(MOUSE_BUTTON_LEFT, Vector2(530.0, 410.0), false))


func test_action_keys_pan_fast_zoom_and_fit() -> void:
	var settings := Settings.new("macOS", false)
	settings.set_value("controls/zoom_smoothing", false)
	_rig.configure(settings)
	_rig.set_map_size(EUROPE_SIZE)
	_rig.frame_at(EUROPE_SIZE * 0.5, 1.0)

	var press_d := InputEventKey.new()
	press_d.physical_keycode = KEY_D
	press_d.pressed = true
	_rig._unhandled_input(press_d)
	var x0 := _camera.position.x
	_rig._process(0.1)
	assert_almost_eq(_camera.position.x - x0, ZoomModel.PAN_BASE_PX_PER_SEC * 0.1, 0.1)

	var press_shift := InputEventKey.new()
	press_shift.keycode = KEY_SHIFT
	press_shift.pressed = true
	_rig._unhandled_input(press_shift)
	var x1 := _camera.position.x
	_rig._process(0.1)
	assert_almost_eq(_camera.position.x - x1, ZoomModel.PAN_BASE_PX_PER_SEC * ZoomModel.PAN_FAST_MULT * 0.1, 0.1)

	var rel_d := press_d.duplicate() as InputEventKey
	rel_d.pressed = false
	var rel_shift := press_shift.duplicate() as InputEventKey
	rel_shift.pressed = false
	_rig._unhandled_input(rel_d)
	_rig._unhandled_input(rel_shift)

	var zoom_in := InputEventKey.new()
	zoom_in.keycode = KEY_EQUAL
	zoom_in.pressed = true
	_rig._unhandled_input(zoom_in)
	assert_almost_eq(_rig.zoom(), pow(ZoomModel.BASE_NOTCH, 2.0), 1.0e-4, "zoom key steps 2 notches")

	var fit_key := InputEventKey.new()
	fit_key.keycode = KEY_F
	fit_key.pressed = true
	_rig._unhandled_input(fit_key)
	assert_almost_eq(_rig.zoom(), ZoomModel.fit_zoom(Vector2(VIEW_SIZE), EUROPE_SIZE), 1.0e-5)


func test_bounds_clamp_and_look_at_glide_and_view_changed() -> void:
	_rig.set_map_size(EUROPE_SIZE)
	_rig.frame_at(EUROPE_SIZE * 0.5, 1.0)
	_rig.pan_by(Vector2(-100000.0, 100000.0))
	assert_eq(_camera.position, Vector2(0.0, EUROPE_SIZE.y), "camera centre clamped inside map")

	var emitted: Array[int] = [0]
	_rig.view_changed.connect(func(_z: float, _r: Rect2) -> void: emitted[0] += 1)
	_rig.pan_by(Vector2(50.0, -50.0))
	_rig.pan_by(Vector2(10.0, -10.0))
	assert_eq(emitted[0], 0)
	_rig._process(0.016)
	assert_eq(emitted[0], 1, "view_changed emitted at most once per frame")

	var dest := Vector2(12000.0, 8000.0)
	_rig.look_at(dest)
	_rig._process(0.1)
	assert_ne(_camera.position, dest, "glide eases over GLIDE_TIME")
	_rig._process(0.3)
	assert_almost_eq(_camera.position.x, dest.x, 0.1)
	assert_almost_eq(_camera.position.y, dest.y, 0.1)

	var settings := Settings.new("macOS", false)
	settings.set_value("accessibility/reduce_motion", true)
	_rig.configure(settings)
	var dest2 := Vector2(20000.0, 9000.0)
	_rig.look_at(dest2)
	assert_eq(_camera.position, dest2, "reduce_motion jumps immediately")


func test_disabled_and_text_focus_gate_camera_input() -> void:
	_rig.set_map_size(EUROPE_SIZE)
	_rig.frame_at(EUROPE_SIZE * 0.5, 1.0)
	var pos0 := _camera.position
	_rig.enabled = false
	_rig._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP, Vector2(640.0, 360.0), 1.0))
	assert_eq(_rig.zoom(), 1.0, "disabled rig ignores wheel")

	_rig.enabled = true
	var edit := LineEdit.new()
	_vp.add_child(edit)
	edit.grab_focus()
	var press_d := InputEventKey.new()
	press_d.physical_keycode = KEY_D
	press_d.pressed = true
	_rig._unhandled_input(press_d)
	_rig._process(0.1)
	assert_eq(_camera.position, pos0, "focused LineEdit gates key pan")


func test_edge_pan_and_small_axis_centring() -> void:
	# Small map at fit zoom centres on map_size * 0.5 even after pan_by.
	_rig.fit()
	_rig.pan_by(Vector2(400.0, 400.0))
	assert_eq(_camera.position, NORTH_ITALY_SIZE * 0.5, "small map stays centred on both axes")

	# Edge pan moves when enabled and pointer is within 8 px edge band.
	_rig.set_map_size(EUROPE_SIZE)
	_rig.frame_at(EUROPE_SIZE * 0.5, 1.0)
	var settings := Settings.new("macOS", false)
	settings.set_value("controls/edge_pan", true)
	settings.set_value("controls/edge_pan_speed", 100)
	_rig.configure(settings)
	_vp.push_input(_mouse_motion(Vector2(2.0, 360.0), Vector2.ZERO))
	var x0 := _camera.position.x
	_rig._process(0.1)
	assert_lt(_camera.position.x, x0, "edge pan left edge moves camera left")

	# Edge pan off disables it.
	settings.set_value("controls/edge_pan", false)
	var x1 := _camera.position.x
	_rig._process(0.1)
	assert_eq(_camera.position.x, x1, "edge pan disabled stops moving")
