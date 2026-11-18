## Raw trackpad/mouse gesture & wheel input probe for calibrating CameraRig.GESTURE_PAN_PX
## (docs/architecture/ui-and-controls-spec.md sections 4.2, 9; ui-and-controls-plan.md U16).
##
## Run windowed to inspect live trackpad gestures (press Esc or close window to exit):
##   godot --path godot -s res://tools/ui/probe_input.gd
## Run headless: verifies gesture/wheel calibration math and exits 0 cleanly.
extends SceneTree

var _event_count := 0
var _pan_sum := Vector2.ZERO
var _max_frames := 0
var _frames := 0


func _initialize() -> void:
	Bindings.ensure()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			_max_frames = int(arg.substr(9))
	print("probe_input: platform=%s GESTURE_PAN_PX=%.1f WHEEL_PAN_PX=%.1f CLICK_SLOP=%.1f" % [
		OS.get_name(), CameraRig.GESTURE_PAN_PX, CameraRig.WHEEL_PAN_PX, CameraRig.CLICK_SLOP
	])
	if DisplayServer.get_name() == "headless":
		_run_headless_check()
		quit(0)
		return
	var info := Label.new()
	info.text = "Hexa Input Probe (GESTURE_PAN_PX=%.1f) — scroll, pinch, click, or press Esc to quit." % CameraRig.GESTURE_PAN_PX
	info.position = Vector2(24.0, 24.0)
	root.add_child(info)


func _process(_delta: float) -> bool:
	_frames += 1
	if _max_frames > 0 and _frames >= _max_frames:
		print("probe_input: reached --frames=%d (events=%d)" % [_max_frames, _event_count])
		quit(0)
		return true
	return false


func _input_event(event: InputEvent) -> void:
	if event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		_event_count += 1
		var scaled := pan.delta * CameraRig.GESTURE_PAN_PX
		_pan_sum += scaled
		print("probe_input [#%d] PanGesture delta=%s scaled_px=%s total_px=%s ctrl=%s meta=%s pos=%s" % [
			_event_count, str(pan.delta), str(scaled), str(_pan_sum),
			str(pan.ctrl_pressed), str(pan.meta_pressed), str(pan.position)
		])
	elif event is InputEventMagnifyGesture:
		var mag := event as InputEventMagnifyGesture
		_event_count += 1
		print("probe_input [#%d] MagnifyGesture factor=%.4f pos=%s" % [
			_event_count, mag.factor, str(mag.position)
		])
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			_event_count += 1
			var factor := 1.0 if is_zero_approx(mb.factor) else mb.factor
			print("probe_input [#%d] Wheel btn=%d factor=%.3f notch=%.4f ctrl=%s shift=%s pos=%s" % [
				_event_count, mb.button_index, factor, ZoomModel.notch_factor(100.0, factor),
				str(mb.ctrl_pressed), str(mb.shift_pressed), str(mb.position)
			])
		elif mb.pressed:
			_event_count += 1
			print("probe_input [#%d] MouseButton btn=%d pos=%s ctrl=%s" % [
				_event_count, mb.button_index, str(mb.position), str(mb.ctrl_pressed)
			])
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			_event_count += 1
			print("probe_input [#%d] Key code=%d (%s) physical=%d" % [
				_event_count, key.keycode, Bindings.event_text(key), key.physical_keycode
			])
			if key.keycode == KEY_ESCAPE:
				quit(0)


func _run_headless_check() -> void:
	var sample_pan := InputEventPanGesture.new()
	sample_pan.delta = Vector2(1.5, -2.0)
	var scaled := sample_pan.delta * CameraRig.GESTURE_PAN_PX
	var sample_mag := InputEventMagnifyGesture.new()
	sample_mag.factor = 1.12
	print("probe_input: headless calibration sample pan_delta=%s -> %.1f,%.1f px; magnify_factor=%.2f; wheel_notch=%.4f" % [
		str(sample_pan.delta), scaled.x, scaled.y, sample_mag.factor, ZoomModel.notch_factor(100.0, 1.0)
	])
