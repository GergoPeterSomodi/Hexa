## The random input of the UI monkey (test_ui_monkey.gd extends this, which extends MonkeyMoves): a bound key, a click on the
## viewport, the wheel, a trackpad gesture and a drag. Split out of the monkey to keep it under the lint's 1,200 lines.
class_name MonkeyInput
extends MonkeyMoves

const SAFE_KEYS: Array[Key] = [
	KEY_ESCAPE,
	KEY_M,
	KEY_F1,
	KEY_F3,
	KEY_1,
	KEY_2,
	KEY_3,
	KEY_4,
	KEY_5,
	KEY_G,
	KEY_N,
	KEY_H,
	KEY_U,
	KEY_I,
	KEY_L,
	KEY_BRACKETLEFT,
	KEY_BRACKETRIGHT,
	KEY_F,
	KEY_EQUAL,
	KEY_MINUS,
	KEY_W,
	KEY_A,
	KEY_S,
	KEY_D,
	KEY_TAB,
	KEY_C,
	KEY_ENTER,
	KEY_UP,
	KEY_DOWN,
]


func _send_random_key(rng: Rng, vp: SubViewport) -> void:
	var key := SAFE_KEYS[rng.randi_range(0, SAFE_KEYS.size() - 1)]
	# Ctrl+F (place search) is F with Ctrl; plain F is Fit whole map.
	var ctrl := key == KEY_F and rng.randi_range(0, 2) == 0
	var press := InputEventKey.new()
	press.keycode = key
	press.physical_keycode = key
	press.pressed = true
	press.ctrl_pressed = ctrl
	vp.push_input(press)

	var release := InputEventKey.new()
	release.keycode = key
	release.physical_keycode = key
	release.pressed = false
	release.ctrl_pressed = ctrl
	vp.push_input(release)


func _send_random_viewport_click(rng: Rng, vp: SubViewport) -> void:
	var pos := Vector2(
		float(rng.randi_range(12, vp.size.x - 12)),
		float(rng.randi_range(8, vp.size.y - 12))
	)
	var button := MOUSE_BUTTON_LEFT if rng.randi_range(0, 3) != 0 else MOUSE_BUTTON_RIGHT
	_send_click(vp, pos, button)


func _send_random_wheel(rng: Rng, vp: SubViewport) -> void:
	var pos := Vector2(
		float(rng.randi_range(60, vp.size.x - 60)),
		float(rng.randi_range(60, vp.size.y - 60))
	)
	var wheel_buttons: Array[MouseButton] = [
		MOUSE_BUTTON_WHEEL_UP,
		MOUSE_BUTTON_WHEEL_DOWN,
		MOUSE_BUTTON_WHEEL_LEFT,
		MOUSE_BUTTON_WHEEL_RIGHT,
	]
	var factors: Array[float] = [0.5, 1.0, 2.0]
	var ev := InputEventMouseButton.new()
	ev.button_index = wheel_buttons[rng.randi_range(0, wheel_buttons.size() - 1)]
	ev.factor = factors[rng.randi_range(0, factors.size() - 1)]
	ev.position = pos
	ev.global_position = pos
	ev.pressed = true
	ev.ctrl_pressed = rng.randi_range(0, 5) == 0
	ev.shift_pressed = rng.randi_range(0, 5) == 0
	vp.push_input(ev)
	# A wheel tick is a press and a release (as the window sends it): left pressed, it would hold the viewport's mouse grab and
	# every later click would go to the control under the wheel.
	var release := ev.duplicate() as InputEventMouseButton
	release.pressed = false
	vp.push_input(release)


func _send_random_gesture(rng: Rng, vp: SubViewport) -> void:
	var pos := Vector2(
		float(rng.randi_range(100, vp.size.x - 100)),
		float(rng.randi_range(80, vp.size.y - 80))
	)
	if rng.randi_range(0, 1) == 0:
		var pan := InputEventPanGesture.new()
		pan.position = pos
		pan.delta = Vector2(float(rng.randi_range(-8, 8)), float(rng.randi_range(-8, 8)))
		vp.push_input(pan)
	else:
		var mag := InputEventMagnifyGesture.new()
		mag.position = pos
		mag.factor = 0.85 if rng.randi_range(0, 1) == 0 else 1.15
		vp.push_input(mag)


func _send_random_drag(rng: Rng, vp: SubViewport) -> void:
	var start := Vector2(
		float(rng.randi_range(120, vp.size.x - 120)),
		float(rng.randi_range(100, vp.size.y - 100))
	)
	var delta := Vector2(float(rng.randi_range(-90, 90)), float(rng.randi_range(-70, 70)))
	var mid := start + delta * 0.5
	var end := start + delta

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = start
	press.global_position = start
	press.pressed = true
	vp.push_input(press)

	for pt: Vector2 in [mid, end]:
		var motion := InputEventMouseMotion.new()
		motion.position = pt
		motion.global_position = pt
		motion.relative = pt - start
		vp.push_input(motion)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = end
	release.global_position = end
	release.pressed = false
	vp.push_input(release)
