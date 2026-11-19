## Tests for action-based MapInput (docs/architecture/ui-and-controls-spec.md sections 3.3, 4.1, 4.2, 4.5, 9).
extends GutTest

const VIEW_SIZE := Vector2i(1280, 720)

var _vp: SubViewport = null
var _map_node: Node2D = null
var _input: MapInput = null


func before_each() -> void:
	Bindings.reset_defaults()
	_vp = SubViewport.new()
	_vp.size = VIEW_SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.gui_disable_input = false
	add_child_autofree(_vp)

	_map_node = Node2D.new()
	_input = MapInput.new()
	_vp.add_child(_map_node)
	_vp.add_child(_input)
	_input.map_node = _map_node
	_input.hex_at_func = func(map_px: Vector2) -> Vector2i:
		return Vector2i(int(floorf(map_px.x / 100.0)), int(floorf(map_px.y / 100.0)))
	_input.hex_valid_func = func(hex: Vector2i) -> bool:
		return hex.x >= 0 and hex.x < 10 and hex.y >= 0 and hex.y < 10


func after_each() -> void:
	Bindings.reset_defaults()
	_input = null
	_map_node = null
	_vp = null


func _btn(button: MouseButton, pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.position = pos
	ev.global_position = pos
	ev.pressed = pressed
	return ev


func _motion(pos: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	return ev


func _key(keycode: Key, ctrl: bool = false, meta: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.ctrl_pressed = ctrl
	ev.meta_pressed = meta
	ev.pressed = true
	return ev


func test_left_click_within_slop_selects_and_drag_does_not() -> void:
	var selected: Array[Vector2i] = []
	_input.select_requested.connect(func(px: Vector2) -> void: selected.append(Vector2i(int(px.x), int(px.y))))

	_input._unhandled_input(_btn(MOUSE_BUTTON_LEFT, Vector2(250.0, 350.0), true))
	_input._unhandled_input(_motion(Vector2(253.0, 352.0)))
	_input._unhandled_input(_btn(MOUSE_BUTTON_LEFT, Vector2(253.0, 352.0), false))
	assert_eq(selected, [Vector2i(253, 352)], "click within 6 px emits select_requested")

	selected.clear()
	_input._unhandled_input(_btn(MOUSE_BUTTON_LEFT, Vector2(250.0, 350.0), true))
	_input._unhandled_input(_motion(Vector2(265.0, 350.0)))
	_input._unhandled_input(_btn(MOUSE_BUTTON_LEFT, Vector2(250.0, 350.0), false))
	assert_true(selected.is_empty(), "drag past 6 px slop suppresses click even if released near start")


func test_right_click_emits_command_requested_only_within_slop() -> void:
	var commands: Array[Vector2] = []
	_input.command_requested.connect(func(px: Vector2) -> void: commands.append(px))

	_input._unhandled_input(_btn(MOUSE_BUTTON_RIGHT, Vector2(120.0, 220.0), true))
	_input._unhandled_input(_btn(MOUSE_BUTTON_RIGHT, Vector2(122.0, 221.0), false))
	assert_eq(commands, [Vector2(122.0, 221.0)])

	commands.clear()
	_input._unhandled_input(_btn(MOUSE_BUTTON_RIGHT, Vector2(120.0, 220.0), true))
	_input._unhandled_input(_motion(Vector2(140.0, 220.0)))
	_input._unhandled_input(_btn(MOUSE_BUTTON_RIGHT, Vector2(140.0, 220.0), false))
	assert_true(commands.is_empty())


func test_hover_changes_only_on_new_hex_and_clears_off_map_or_over_ui() -> void:
	var hovered: Array[Vector2i] = []
	_input.hover_changed.connect(func(hex: Vector2i) -> void: hovered.append(hex))

	_input._unhandled_input(_motion(Vector2(250.0, 350.0)))
	_input._unhandled_input(_motion(Vector2(260.0, 360.0)))  # still hex (2, 3)
	_input._unhandled_input(_motion(Vector2(350.0, 350.0)))  # hex (3, 3)
	_input._unhandled_input(_motion(Vector2(-50.0, 50.0)))   # off-map -> NO_HEX
	_input._unhandled_input(_motion(Vector2(-80.0, 50.0)))   # still off-map
	assert_eq(hovered, [Vector2i(2, 3), Vector2i(3, 3), MapInput.NO_HEX])

	# Move back onto map, then put a STOP panel under pointer and push motion through viewport.
	hovered.clear()
	_input._unhandled_input(_motion(Vector2(150.0, 150.0)))
	assert_eq(hovered, [Vector2i(1, 1)])

	var panel := Panel.new()
	panel.position = Vector2(100.0, 100.0)
	panel.size = Vector2(200.0, 200.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_vp.add_child(panel)
	_vp.push_input(_motion(Vector2(160.0, 160.0)))
	_input._process(0.016)
	assert_eq(_input.current_hover(), MapInput.NO_HEX, "hover clears when UI panel covers pointer")


func test_action_keys_and_rebinding_and_dev_gating() -> void:
	var log: Array[String] = []
	_input.mode_requested.connect(func(m: int) -> void: log.append("mode:%d" % m))
	_input.country_requested.connect(func() -> void: log.append("country"))
	_input.find_place_requested.connect(func() -> void: log.append("find_place"))
	_input.grid_toggled.connect(func() -> void: log.append("grid"))
	_input.names_toggled.connect(func() -> void: log.append("names"))
	_input.hud_toggled.connect(func() -> void: log.append("hud"))
	_input.upgrade_requested.connect(func() -> void: log.append("upgrade"))
	_input.new_seed_requested.connect(func() -> void: log.append("seed"))

	_input._unhandled_input(_key(KEY_1))
	_input._unhandled_input(_key(KEY_2))
	_input._unhandled_input(_key(KEY_3))
	_input._unhandled_input(_key(KEY_4))  # unbound / no-op in M2
	_input._unhandled_input(_key(KEY_2, true, true))  # modified chord must not trigger mode 2
	_input._unhandled_input(_key(KEY_C))
	var find_chord := Bindings.events_for(&"ui_find_place")[0].duplicate() as InputEventKey
	find_chord.pressed = true
	_input._unhandled_input(find_chord)
	_input._unhandled_input(_key(KEY_G))
	_input._unhandled_input(_key(KEY_N))
	_input._unhandled_input(_key(KEY_H))
	_input._unhandled_input(_key(KEY_U))
	_input._unhandled_input(_key(KEY_R))  # plain R must do nothing

	var seed_chord := Bindings.events_for(&"dev_new_seed")[0].duplicate() as InputEventKey
	seed_chord.pressed = true
	_input._unhandled_input(seed_chord)

	assert_eq(log, ["mode:0", "mode:1", "mode:2", "country", "find_place", "grid", "names", "hud", "upgrade", "seed"])

	# Rebind view_grid to K: G stops working, K works.
	log.clear()
	assert_true(bool(Bindings.apply_overrides({"view_grid": "K"})["ok"]))
	_input._unhandled_input(_key(KEY_G))
	_input._unhandled_input(_key(KEY_K))
	assert_eq(log, ["grid"])

	# Developer tools disabled gates dev_new_seed.
	log.clear()
	var settings := Settings.new("macOS", false)
	settings.set_value("dev/developer_tools", false)
	_input.configure(settings)
	_input._unhandled_input(seed_chord)
	assert_true(log.is_empty(), "dev_new_seed gated when dev/developer_tools is false")

	# Focused LineEdit gates map key shortcuts including chords.
	var edit := LineEdit.new()
	_vp.add_child(edit)
	edit.grab_focus()
	var settings_dev := Settings.new("macOS", false)
	settings_dev.set_value("dev/developer_tools", true)
	_input.configure(settings_dev)
	_input._unhandled_input(seed_chord)
	_input._unhandled_input(find_chord)
	_input._unhandled_input(_key(KEY_C))
	_input._unhandled_input(_key(KEY_G))
	assert_true(log.is_empty(), "focused LineEdit gates MapInput shortcuts")
	edit.release_focus()

	# Disabling MapInput clears hover and blocks intents.
	_input._unhandled_input(_motion(Vector2(250.0, 350.0)))
	assert_eq(_input.current_hover(), Vector2i(2, 3))
	_input.enabled = false
	assert_eq(_input.current_hover(), MapInput.NO_HEX)
	_input._unhandled_input(_key(KEY_N))
	assert_true(log.is_empty())


func _chord(action: StringName) -> InputEventKey:
	var ev := Bindings.events_for(action)[0].duplicate() as InputEventKey
	ev.pressed = true
	return ev


func test_m3_keys_emit_their_intents() -> void:
	var log: Array[String] = []
	_input.end_season_requested.connect(func(echo: bool) -> void: log.append("end:%s" % echo))
	_input.report_requested.connect(func() -> void: log.append("report"))
	_input.bookmark_requested.connect(func(i: int, set: bool) -> void: log.append("bm:%d:%s" % [i, set]))
	_input.undo_work_requested.connect(func() -> void: log.append("undo"))

	_input._unhandled_input(_key(KEY_SPACE))
	var held := _key(KEY_SPACE)
	held.echo = true
	_input._unhandled_input(held)
	_input._unhandled_input(_key(KEY_ENTER))
	_input._unhandled_input(_key(KEY_J))
	_input._unhandled_input(_chord(&"game_undo_work"))
	_input._unhandled_input(_chord(&"cam_bookmark_go_3"))
	_input._unhandled_input(_chord(&"cam_bookmark_set_7"))
	assert_eq(log, ["end:false", "end:true", "end:false", "report", "undo", "bm:3:false", "bm:7:true"])

	log.clear()
	_input._unhandled_input(_key(KEY_Z))  # plain Z does nothing
	_input._unhandled_input(_key(KEY_3, true))  # Ctrl+3 is a bookmark, not map mode 3
	assert_eq(log, ["bm:3:false"])


func test_m3_keys_are_silent_under_a_line_edit_and_when_disabled() -> void:
	var log: Array[String] = []
	_input.end_season_requested.connect(func(echo: bool) -> void: log.append("end:%s" % echo))
	_input.report_requested.connect(func() -> void: log.append("report"))
	_input.bookmark_requested.connect(func(i: int, _set: bool) -> void: log.append("bm:%d" % i))
	_input.undo_work_requested.connect(func() -> void: log.append("undo"))
	var edit := LineEdit.new()
	_vp.add_child(edit)
	edit.grab_focus()
	_input._unhandled_input(_key(KEY_SPACE))
	_input._unhandled_input(_key(KEY_J))
	_input._unhandled_input(_chord(&"game_undo_work"))
	_input._unhandled_input(_chord(&"cam_bookmark_go_1"))
	assert_true(log.is_empty(), "a focused LineEdit wins")
	edit.release_focus()
	_input.enabled = false
	_input._unhandled_input(_key(KEY_SPACE))
	_input._unhandled_input(_key(KEY_J))
	assert_true(log.is_empty(), "nothing while disabled")
