## Tests for action-based MapInput (docs/architecture/ui-and-controls-spec.md sections 3.3, 4.1, 4.2, 4.5, 9).
extends GutTest

const VIEW_SIZE := Vector2i(1280, 720)

var _vp: SubViewport = null
var _map_node: Node2D = null
var _input: MapInput = null
var _t := 0


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


func test_a_unit_under_the_pointer_takes_the_click_before_the_hex() -> void:
	var units: Array[Vector2] = []
	var hexes: Array[Vector2] = []
	_input.unit_at_func = func(screen: Vector2) -> bool: return screen.x < 150.0
	_input.unit_requested.connect(func(screen: Vector2) -> void: units.append(screen))
	_input.select_requested.connect(func(px: Vector2) -> void: hexes.append(px))
	_input._unhandled_input(_btn(MOUSE_BUTTON_LEFT, Vector2(100.0, 100.0), true))
	_input._unhandled_input(_btn(MOUSE_BUTTON_LEFT, Vector2(100.0, 100.0), false))
	_input._unhandled_input(_btn(MOUSE_BUTTON_LEFT, Vector2(400.0, 100.0), true))
	_input._unhandled_input(_btn(MOUSE_BUTTON_LEFT, Vector2(400.0, 100.0), false))
	assert_eq(units, [Vector2(100.0, 100.0)], "a click on a unit is the unit's")
	assert_eq(hexes, [Vector2(400.0, 100.0)], "a click off the units is the hex's")
	var shift := _btn(MOUSE_BUTTON_LEFT, Vector2(100.0, 100.0), true)
	shift.shift_pressed = true
	_input._unhandled_input(shift)
	shift = _btn(MOUSE_BUTTON_LEFT, Vector2(100.0, 100.0), false)
	shift.shift_pressed = true
	_input._unhandled_input(shift)
	assert_eq(hexes.back(), Vector2(100.0, 100.0), "Shift+click is the hex's, units or not")
	_input.unit_at_func = Callable()


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
	_input._unhandled_input(_key(KEY_4))  # Yields (M4.5)
	_input._unhandled_input(_key(KEY_5))  # Food (M5)
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

	assert_eq(log, ["mode:0", "mode:1", "mode:2", "mode:3", "mode:4", "country", "find_place", "grid", "names", "hud", "upgrade", "seed"])

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


func test_i_and_l_ask_for_the_study_on_its_last_page_and_on_economy() -> void:
	var log: Array[String] = []
	_input.study_requested.connect(func(page: StringName) -> void: log.append("study:%s" % page))
	_input._unhandled_input(_key(KEY_I))
	_input._unhandled_input(_key(KEY_L))
	_input._unhandled_input(_key(KEY_I, true))  # Ctrl+I is not the key
	assert_eq(log, ["study:", "study:economy"])
	var held := _key(KEY_I)
	held.echo = true
	_input._unhandled_input(held)
	assert_eq(log.size(), 2, "a held key does not repeat")


func test_the_study_keys_are_silent_under_a_line_edit_and_when_disabled() -> void:
	var log: Array[String] = []
	_input.study_requested.connect(func(page: StringName) -> void: log.append(String(page)))
	var edit := LineEdit.new()
	_vp.add_child(edit)
	edit.grab_focus()
	_input._unhandled_input(_key(KEY_I))
	_input._unhandled_input(_key(KEY_L))
	assert_true(log.is_empty(), "typing an I or an L in the console is not a key")
	edit.release_focus()
	_input.enabled = false
	_input._unhandled_input(_key(KEY_I))
	assert_true(log.is_empty(), "nothing while disabled")


func _alt(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	ev.alt_pressed = true
	return ev


func _connect_m6(log: Array[String]) -> void:
	_input.next_army_requested.connect(func() -> void: log.append("next"))
	_input.continue_march_requested.connect(func() -> void: log.append("continue"))
	_input.cursor_moved.connect(func(d: int) -> void: log.append("cursor:%d" % d))
	_input.command_key_requested.connect(func() -> void: log.append("command"))
	_input.mode_requested.connect(func(m: int) -> void: log.append("mode:%d" % m))


func test_m6_keys_emit_their_intents() -> void:
	var log: Array[String] = []
	_connect_m6(log)
	_input._unhandled_input(_key(KEY_TAB))
	_input._unhandled_input(_key(KEY_R))
	_input._unhandled_input(_key(KEY_O))
	var f10 := InputEventKey.new()
	f10.keycode = KEY_F10
	f10.physical_keycode = KEY_F10
	f10.pressed = true
	f10.shift_pressed = true
	_input._unhandled_input(f10)
	_input._unhandled_input(_alt(KEY_LEFT))
	_input._unhandled_input(_alt(KEY_RIGHT))
	_input._unhandled_input(_alt(KEY_UP))
	_input._unhandled_input(_alt(KEY_DOWN))
	_input._unhandled_input(_key(KEY_6))
	assert_eq(log, ["next", "continue", "command", "command",
		"cursor:0", "cursor:1", "cursor:2", "cursor:3", "mode:5"])


func test_m6_keys_ignore_other_chords_and_held_repeats() -> void:
	var log: Array[String] = []
	_connect_m6(log)
	_input._unhandled_input(_key(KEY_TAB, true))
	_input._unhandled_input(_key(KEY_LEFT))
	_input._unhandled_input(_alt(KEY_O))
	var held := _key(KEY_TAB)
	held.echo = true
	_input._unhandled_input(held)
	var held_alt := _alt(KEY_LEFT)
	held_alt.echo = true
	_input._unhandled_input(held_alt)
	assert_true(log.is_empty(), "%s" % [log])


func test_m6_keys_are_silent_under_a_line_edit_and_when_disabled() -> void:
	var log: Array[String] = []
	_connect_m6(log)
	var edit := LineEdit.new()
	_vp.add_child(edit)
	edit.grab_focus()
	_input._unhandled_input(_key(KEY_TAB))
	_input._unhandled_input(_key(KEY_R))
	_input._unhandled_input(_key(KEY_O))
	_input._unhandled_input(_alt(KEY_LEFT))
	_input._unhandled_input(_key(KEY_6))
	assert_true(log.is_empty(), "a focused LineEdit wins")
	edit.release_focus()
	_input.enabled = false
	_input._unhandled_input(_key(KEY_TAB))
	_input._unhandled_input(_alt(KEY_UP))
	assert_true(log.is_empty(), "nothing while disabled")


func test_cursor_step_keeps_the_column_for_up_and_down() -> void:
	var even := Vector2i(4, 2)
	assert_eq(MapInput.cursor_step(even, MapInput.CURSOR_UP), even + HexGrid._EVEN_DIRS[1], "even row up is NE")
	assert_eq(MapInput.cursor_step(even, MapInput.CURSOR_DOWN), even + HexGrid._EVEN_DIRS[5], "even row down is SE")
	var odd := Vector2i(4, 3)
	assert_eq(MapInput.cursor_step(odd, MapInput.CURSOR_UP), odd + HexGrid._ODD_DIRS[2], "odd row up is NW")
	assert_eq(MapInput.cursor_step(odd, MapInput.CURSOR_DOWN), odd + HexGrid._ODD_DIRS[4], "odd row down is SW")
	assert_eq(MapInput.cursor_step(even, MapInput.CURSOR_LEFT), even + HexGrid._EVEN_DIRS[3])
	assert_eq(MapInput.cursor_step(odd, MapInput.CURSOR_RIGHT), odd + HexGrid._ODD_DIRS[0])


func _shift_btn(button: MouseButton, pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var ev := _btn(button, pos, pressed)
	ev.shift_pressed = true
	return ev


func _shift_key(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	ev.shift_pressed = true
	return ev


func _connect_m7(log: Array[String]) -> void:
	_input.storm_key_requested.connect(func() -> void: log.append("storm"))
	_input.command_key_requested.connect(func() -> void: log.append("command"))
	_input.battle_requested.connect(func() -> void: log.append("battle"))


func test_m7_shift_right_click_storms_only_with_an_army_selected() -> void:
	var storms: Array[Vector2] = []
	var commands: Array[Vector2] = []
	_input.storm_requested.connect(func(px: Vector2) -> void: storms.append(px))
	_input.command_requested.connect(func(px: Vector2) -> void: commands.append(px))
	var army := [false]
	_input.storm_ready = func() -> bool: return army[0]
	# no army selected: a Shift+right click is a right click
	_input._unhandled_input(_shift_btn(MOUSE_BUTTON_RIGHT, Vector2(120.0, 220.0), true))
	_input._unhandled_input(_shift_btn(MOUSE_BUTTON_RIGHT, Vector2(121.0, 220.0), false))
	assert_eq(commands, [Vector2(121.0, 220.0)], "Shift+right click with no army commands")
	assert_true(storms.is_empty(), "and does not storm")
	# an army of yours selected: the Shift+right click storms at that hex; a plain right click still commands
	commands.clear()
	army[0] = true
	_input._unhandled_input(_shift_btn(MOUSE_BUTTON_RIGHT, Vector2(120.0, 220.0), true))
	_input._unhandled_input(_shift_btn(MOUSE_BUTTON_RIGHT, Vector2(121.0, 220.0), false))
	assert_eq(storms, [Vector2(121.0, 220.0)], "Shift+right click storms at the hex")
	assert_true(commands.is_empty(), "and does not command")
	_input._unhandled_input(_btn(MOUSE_BUTTON_RIGHT, Vector2(120.0, 220.0), true))
	_input._unhandled_input(_btn(MOUSE_BUTTON_RIGHT, Vector2(120.0, 220.0), false))
	assert_eq(storms.size(), 1, "a plain right click does not storm")
	assert_eq(commands.size(), 1, "a plain right click commands")
	# an unset gate means no army
	storms.clear()
	commands.clear()
	_input.storm_ready = Callable()
	_input._unhandled_input(_shift_btn(MOUSE_BUTTON_RIGHT, Vector2(120.0, 220.0), true))
	_input._unhandled_input(_shift_btn(MOUSE_BUTTON_RIGHT, Vector2(120.0, 220.0), false))
	assert_true(storms.is_empty(), "an unset gate never storms")
	assert_eq(commands.size(), 1, "an unset gate is a right click")


func test_m7_keys_storm_and_battle_and_the_command_key_stays_plain() -> void:
	var log: Array[String] = []
	_connect_m7(log)
	_input._unhandled_input(_shift_key(KEY_O))
	_input._unhandled_input(_key(KEY_O))
	_input._unhandled_input(_key(KEY_B))
	_input._unhandled_input(_shift_key(KEY_B))
	_input._unhandled_input(_alt(KEY_O))
	assert_eq(log, ["storm", "command", "battle"], "Shift+O storms only; B opens the last battle; Shift+B and Alt+O do nothing")
	var held := _shift_key(KEY_O)
	held.echo = true
	_input._unhandled_input(held)
	assert_eq(log.size(), 3, "a held Shift+O is refused")


func test_m7_keys_are_silent_under_a_line_edit_and_when_disabled() -> void:
	var log: Array[String] = []
	_connect_m7(log)
	var edit := LineEdit.new()
	_vp.add_child(edit)
	edit.grab_focus()
	_input._unhandled_input(_shift_key(KEY_O))
	_input._unhandled_input(_key(KEY_B))
	_input._unhandled_input(_key(KEY_O))
	assert_true(log.is_empty(), "a focused LineEdit wins")
	edit.release_focus()
	_input.enabled = false
	_input._unhandled_input(_shift_key(KEY_O))
	_input._unhandled_input(_key(KEY_B))
	assert_true(log.is_empty(), "nothing while disabled")


## The signals of the intents block_orders gates (M8 6.2, D36), by the action that makes them.
func _watch_orders(log: Array[String]) -> void:
	_input.select_requested.connect(func(_p: Vector2) -> void: log.append("select"))
	_input.command_requested.connect(func(_p: Vector2) -> void: log.append("command"))
	_input.storm_requested.connect(func(_p: Vector2) -> void: log.append("storm"))
	_input.command_key_requested.connect(func() -> void: log.append("command_key"))
	_input.upgrade_requested.connect(func() -> void: log.append("upgrade"))
	_input.next_army_requested.connect(func() -> void: log.append("next"))
	_input.continue_march_requested.connect(func() -> void: log.append("continue"))
	_input.undo_work_requested.connect(func() -> void: log.append("undo"))
	_input.storm_key_requested.connect(func() -> void: log.append("storm_key"))
	_input.battle_requested.connect(func() -> void: log.append("battle"))
	_input.report_requested.connect(func() -> void: log.append("report"))


func _chord_of(action: StringName) -> InputEventKey:
	var ev := Bindings.events_for(action)[0].duplicate() as InputEventKey
	ev.pressed = true
	return ev


func _click_at(button: MouseButton, pos: Vector2, shift: bool = false) -> void:
	var down := _btn(button, pos, true)
	var up := _btn(button, pos, false)
	down.shift_pressed = shift
	up.shift_pressed = shift
	_input._unhandled_input(down)
	_input._unhandled_input(up)


func test_block_orders_emits_blocked_instead_of_each_order_and_changes_nothing() -> void:
	_t = 5000
	_input.clock = func() -> int: return _t
	var log: Array[String] = []
	var reasons: Array[String] = []
	_watch_orders(log)
	_input.blocked.connect(func(reason: String) -> void: reasons.append(reason))
	_input.storm_ready = func() -> bool: return true
	_input.block_orders("Countries are moving")
	var intents: Array[Callable] = [
		func() -> void: _click_at(MOUSE_BUTTON_LEFT, Vector2(250.0, 350.0)),
		func() -> void: _click_at(MOUSE_BUTTON_RIGHT, Vector2(250.0, 350.0)),
		func() -> void: _click_at(MOUSE_BUTTON_RIGHT, Vector2(250.0, 350.0), true),
	]
	for action: StringName in [&"map_command_key", &"game_upgrade", &"game_next_unit", &"game_continue_march",
			&"game_undo_work", &"map_command_storm", &"game_battle", &"game_report"]:
		intents.append(func() -> void: _input._unhandled_input(_chord_of(action)))
	for intent: Callable in intents:
		var before := reasons.size()
		_t += 1100  # past the once-a-second gap
		intent.call()
		assert_eq(reasons.size(), before + 1, "each blocked intent says why")
	assert_true(log.is_empty(), "and none of them did anything: %s" % str(log))
	assert_eq(reasons[0], "Countries are moving")


func test_blocked_is_said_once_a_second_at_most() -> void:
	_t = 10000
	_input.clock = func() -> int: return _t
	var reasons: Array[String] = []
	_input.blocked.connect(func(reason: String) -> void: reasons.append(reason))
	_input.block_orders("why")
	_click_at(MOUSE_BUTTON_LEFT, Vector2(250.0, 350.0))
	_t += 400
	_click_at(MOUSE_BUTTON_LEFT, Vector2(250.0, 350.0))
	_t += 400
	_input._unhandled_input(_chord_of(&"game_next_unit"))
	assert_eq(reasons.size(), 1, "inside a second: once")
	_t += 300
	_click_at(MOUSE_BUTTON_LEFT, Vector2(250.0, 350.0))
	assert_eq(reasons.size(), 2, "after it: again")


func test_camera_intents_still_work_while_blocked_and_empty_lifts_it() -> void:
	var seen: Array[String] = []
	var reasons: Array[String] = []
	_input.blocked.connect(func(reason: String) -> void: reasons.append(reason))
	_input.mode_requested.connect(func(_m: int) -> void: seen.append("mode"))
	_input.grid_toggled.connect(func() -> void: seen.append("grid"))
	_input.names_toggled.connect(func() -> void: seen.append("names"))
	_input.find_place_requested.connect(func() -> void: seen.append("find"))
	_input.bookmark_requested.connect(func(_i: int, _s: bool) -> void: seen.append("bookmark"))
	_input.study_requested.connect(func(_p: StringName) -> void: seen.append("study"))
	var hovered: Array[Vector2i] = []
	_input.hover_changed.connect(func(hex: Vector2i) -> void: hovered.append(hex))
	_input.block_orders("busy")
	for action: StringName in [&"view_mode_1", &"view_grid", &"view_names", &"ui_find_place", &"cam_bookmark_go_1",
			&"cam_bookmark_set_2", &"game_study"]:
		_input._unhandled_input(_chord_of(action))
	assert_eq(seen, ["mode", "grid", "names", "find", "bookmark", "bookmark", "study"], "every camera intent works")
	_input._unhandled_input(_motion(Vector2(250.0, 350.0)))
	assert_eq(hovered, [Vector2i(2, 3)], "the hover card works")
	assert_true(reasons.is_empty(), "none of them was blocked")
	var log: Array[String] = []
	_watch_orders(log)
	_input.block_orders("")
	_click_at(MOUSE_BUTTON_LEFT, Vector2(250.0, 350.0))
	_input._unhandled_input(_chord_of(&"game_next_unit"))
	assert_eq(log, ["select", "next"], "lifted")
	assert_true(reasons.is_empty())
