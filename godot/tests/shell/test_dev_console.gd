## GUT tests for the DevConsole node (docs/architecture/m3-build-spec.md section 6.13): the LineEdit and 8 output lines,
## Enter, a history of 20 walked with Up and Down, F2 focus through the F3 panel and no key firing while it has focus.
extends GutTest

const DEBUG_SCENE := preload("res://shell/hud/debug_overlay.tscn")

var _harness: UIHarness = null
var _overlay: DebugOverlay = null
var _console: DevConsole = null
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	Session.new_scenario("north_italy_1480", 5, &"GEN")
	_harness = UIHarness.new()
	_harness.mount(self)
	_overlay = DEBUG_SCENE.instantiate() as DebugOverlay
	_overlay.theme = KitTheme.load_for(1.0)
	_overlay.configure(_harness.settings)
	_harness.viewport.add_child(_overlay)
	_overlay.setup_console(_harness.ctx)
	_console = _overlay.console()


func after_each() -> void:
	_overlay = null
	_console = null
	_harness = null
	Session.game = _prev_game
	Bindings.reset_defaults()


func test_the_console_sits_inside_the_f3_panel() -> void:
	assert_not_null(_console)
	assert_true(_overlay.is_ancestor_of(_console))
	assert_not_null(_console.line_edit())


func test_enter_runs_the_line_and_prints_the_answer() -> void:
	_console.line_edit().text = "seed"
	_console.line_edit().text_submitted.emit("seed")
	assert_eq(_console.output_lines(), PackedStringArray(["> seed", "5"]))
	assert_eq(_console.line_edit().text, "", "the field is emptied")
	assert_eq(_console.history(), PackedStringArray(["seed"]))


func test_a_bad_line_prints_its_problem_and_an_empty_line_nothing() -> void:
	_console.submit("end 41")
	assert_eq(_console.output_lines()[1], "end takes 1 to 40 seasons.")
	var before := _console.output_lines().size()
	_console.submit("   ")
	assert_eq(_console.output_lines().size(), before)
	assert_eq(_console.history().size(), 1)


func test_end_goes_to_the_app_as_a_request() -> void:
	var sent: Array = []
	_harness.ctx.app_requested.connect(func(what: StringName, args: Dictionary) -> void: sent.append([what, args]))
	_console.submit("end 4")
	assert_eq(sent, [[&"end_seasons", {"count": 4}]])


func test_only_the_last_eight_output_lines_stay() -> void:
	for i: int in 12:
		_console.submit("seed")
	assert_eq(_console.output_lines().size(), 8)
	assert_eq(_console.output_lines()[7], "5")
	assert_eq(_console.history().size(), 1, "the same line twice in a row is kept once")


func test_history_keeps_20_and_walks_with_up_and_down() -> void:
	for i: int in 25:
		_console.submit("end %d" % (i + 1))
	assert_eq(_console.history().size(), 20)
	assert_eq(_console.history()[0], "end 6", "the oldest five dropped")
	_console.line_edit().text = "dra"
	_console.walk(-1)
	assert_eq(_console.line_edit().text, "end 25")
	_console.walk(-1)
	assert_eq(_console.line_edit().text, "end 24")
	_console.walk(1)
	assert_eq(_console.line_edit().text, "end 25")
	_console.walk(1)
	assert_eq(_console.line_edit().text, "dra", "past the newest the draft returns")
	for i: int in 30:
		_console.walk(-1)
	assert_eq(_console.line_edit().text, "end 6", "Up stops at the oldest")


func test_up_and_down_keys_in_the_field_walk_the_history() -> void:
	_console.submit("seed")
	_console.submit("digest")
	var up := InputEventKey.new()
	up.keycode = KEY_UP
	up.pressed = true
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	_console.line_edit().gui_input.emit(up)
	assert_eq(_console.line_edit().text, "digest")
	_console.line_edit().gui_input.emit(up)
	assert_eq(_console.line_edit().text, "seed")
	_console.line_edit().gui_input.emit(down)
	assert_eq(_console.line_edit().text, "digest")


func test_f2_opens_the_panel_and_focuses_the_field() -> void:
	assert_false(_overlay.visible)
	assert_true(_overlay.focus_console())
	await _harness.wait_frames(self, 1)
	assert_true(_overlay.visible)
	assert_true(_console.has_line_focus())
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	_console.line_edit().gui_input.emit(esc)
	assert_false(_console.has_line_focus(), "Esc leaves the field")


func test_f2_does_nothing_with_developer_tools_off() -> void:
	_harness.settings.set_value("dev/developer_tools", false)
	assert_false(_overlay.focus_console())
	assert_false(_overlay.visible)
	assert_false(_console.has_line_focus())


func test_no_key_fires_while_the_field_has_focus() -> void:
	var app_input := AppInput.new()
	_harness.viewport.add_child(app_input)
	app_input.configure(_harness.settings)
	var fired: Array[String] = []
	app_input.debug_toggled.connect(func() -> void: fired.append("f3"))
	app_input.help_toggled.connect(func() -> void: fired.append("help"))
	app_input.quicksave_requested.connect(func() -> void: fired.append("save"))
	app_input.console_requested.connect(func() -> void: fired.append("console"))
	_overlay.set_open(true)
	_console.focus_line()
	await _harness.wait_frames(self, 1)
	assert_true(_console.has_line_focus())
	for action: StringName in [&"dev_debug", &"app_help", &"game_quicksave", &"dev_console"]:
		var ev := Bindings.events_for(action)[0] as InputEventKey
		assert_false(app_input.handle_key_event(ev), "%s does not fire while typing" % action)
	assert_eq(fired, [])
	_console.release_focus_line()
	await _harness.wait_frames(self, 1)
	var f3 := Bindings.events_for(&"dev_debug")[0] as InputEventKey
	assert_true(app_input.handle_key_event(f3), "and fires again once the field lets go")
	assert_eq(fired, ["f3"])
