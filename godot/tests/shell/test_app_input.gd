## Tests for AppInput's M3 keys: quicksave, quickload, the console (m3-build-spec.md section 6.1).
extends GutTest

var _vp: SubViewport = null
var _input: AppInput = null


func before_each() -> void:
	Bindings.reset_defaults()
	_vp = SubViewport.new()
	_vp.size = Vector2i(640, 360)
	_vp.gui_disable_input = false
	add_child_autofree(_vp)
	_input = AppInput.new()
	_vp.add_child(_input)


func after_each() -> void:
	Bindings.reset_defaults()
	_input = null
	_vp = null


func _chord(action: StringName) -> InputEventKey:
	var ev := Bindings.events_for(action)[0].duplicate() as InputEventKey
	ev.pressed = true
	return ev


func _ctrl(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.ctrl_pressed = true
	ev.pressed = true
	return ev


func _watch(log: Array[String]) -> void:
	_input.quicksave_requested.connect(func() -> void: log.append("save"))
	_input.quickload_requested.connect(func() -> void: log.append("load"))
	_input.console_requested.connect(func() -> void: log.append("console"))


func test_f5_f9_f2_emit_and_ctrl_s_l_too() -> void:
	var log: Array[String] = []
	_watch(log)
	assert_true(_input.handle_key_event(_chord(&"game_quicksave")))
	assert_true(_input.handle_key_event(_chord(&"game_quickload")))
	assert_true(_input.handle_key_event(_chord(&"dev_console")))
	assert_true(_input.handle_key_event(_ctrl(KEY_S)))
	assert_true(_input.handle_key_event(_ctrl(KEY_L)))
	assert_eq(log, ["save", "load", "console", "save", "load"])


func test_keys_work_while_the_tree_is_paused() -> void:
	var log: Array[String] = []
	_watch(log)
	get_tree().paused = true
	_input._shortcut_input(_chord(&"game_quicksave"))
	var still_runs := _input.process_mode == Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	assert_true(still_runs, "AppInput keeps processing under the pause menu")
	assert_eq(log, ["save"])


func test_console_needs_developer_tools_and_a_line_edit_blocks_all() -> void:
	var log: Array[String] = []
	_watch(log)
	var settings := Settings.new("macOS", false)
	settings.set_value("dev/developer_tools", false)
	_input.configure(settings)
	assert_false(_input.handle_key_event(_chord(&"dev_console")))
	assert_true(_input.handle_key_event(_chord(&"game_quicksave")), "save is not a developer key")
	log.clear()
	var edit := LineEdit.new()
	_vp.add_child(edit)
	edit.grab_focus()
	_input.handle_key_event(_chord(&"game_quicksave"))
	_input.handle_key_event(_chord(&"game_quickload"))
	settings.set_value("dev/developer_tools", true)
	_input.handle_key_event(_chord(&"dev_console"))
	assert_true(log.is_empty(), "a focused LineEdit wins")
	edit.release_focus()
	var held := _chord(&"game_quicksave")
	held.echo = true
	assert_false(_input.handle_key_event(held), "a held key does not repeat a save")


func test_f5_and_f9_are_refused_with_a_reason_while_the_season_runs() -> void:
	var log: Array[String] = []
	_watch(log)
	var reasons: Array[String] = []
	_input.season_blocked.connect(func(reason: String) -> void: reasons.append(reason))
	var prev_game := Session.game
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	Session._in_season = true
	assert_true(_input.handle_key_event(_chord(&"game_quicksave")), "the key is still taken")
	assert_true(_input.handle_key_event(_chord(&"game_quickload")), "a quickload mid-season loads nothing")
	Session._in_season = false
	Session.game = prev_game
	assert_true(log.is_empty(), "no save or load request")
	assert_eq(reasons, ["Wait for the season to end", "Wait for the season to end"])
	assert_true(_input.handle_key_event(_chord(&"game_quicksave")))
	assert_eq(log, ["save"], "outside the season it works")
