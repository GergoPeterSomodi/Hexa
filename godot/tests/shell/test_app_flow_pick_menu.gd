## The pause menu while choosing a country: M, the top bar's menu button and Esc open the same menu as during play
## (docs/architecture/ui-and-controls-spec.md sections 3.3 and 5.2; m2-build-spec.md section 7.5), and it goes back
## to the pick.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")

var _prev_game: Game = null
var _prev_unsaved: int = 0
var _old_save_dir: String = ""
var _old_lock_path: String = ""


func before_each() -> void:
	Session.ai_enabled = false
	Bindings.reset_defaults()
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	# Never the real user://saves or running.lock.
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_pick_menu_saves"
	RunLock.path = "user://test_pick_menu_running.lock"


func after_each() -> void:
	Session.ai_enabled = true
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Session.save_dir = _old_save_dir
	if FileAccess.file_exists(RunLock.path):
		DirAccess.remove_absolute(RunLock.path)
	RunLock.path = _old_lock_path
	Bindings.reset_defaults()


## The App on a new game with no country: it opens the pick. Returns {vp, app, pick}.
func _open_pick() -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = PackedStringArray(["--new-game", "--seed=1480"])
	var s := Settings.new("Windows", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	app.set_settings_override(s)
	vp.add_child(app)
	var frames := 0
	while not app.stack().top() is CountryPick and frames < 3000:
		await get_tree().process_frame
		frames += 1
	assert_true(app.stack().top() is CountryPick, "the pick opens")
	await _frames(3)
	return {"vp": vp, "app": app, "pick": app.stack().top()}


func _frames(count: int = 2) -> void:
	for _i: int in count:
		await get_tree().process_frame


func _key(vp: SubViewport, keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		vp.push_input(ev)
	await _frames()


## A real left click on the middle of `control`, through the viewport (so anything covering it takes the click).
func _click(vp: SubViewport, control: Control) -> void:
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	vp.push_input(motion, true)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = at
		ev.global_position = at
		ev.pressed = pressed
		vp.push_input(ev, true)
	await _frames()


func _assert_pick_alone(app: App, pick: CountryPick, why: String) -> void:
	assert_eq(app.stack().count(), 1, why)
	assert_eq(app.stack().top(), pick, why)
	assert_false(app.wants_pause(), why)
	assert_true(app.map_scene().picking(), why)


func test_m_opens_and_closes_the_pause_menu_during_the_pick() -> void:
	var env := await _open_pick()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	var pick := env["pick"] as CountryPick

	await _key(vp, KEY_M)
	var pause := app.stack().top() as PauseMenu
	assert_not_null(pause, "M opens the pause menu over the pick")
	if pause == null:
		return
	assert_eq(app.stack().count(), 2, "the pick stays under it")
	assert_true(app.wants_pause())
	assert_eq(pause.subtitle_label().text, "%s · %s" % [Session.game.scenario.name, Session.game.date_text()])
	await _key(vp, KEY_M)
	_assert_pick_alone(app, pick, "M closes it again")


func test_the_menu_button_opens_the_pause_menu_during_the_pick() -> void:
	var env := await _open_pick()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	var pick := env["pick"] as CountryPick
	var button := app.hud().top_bar().menu_button()
	assert_true(button.is_visible_in_tree(), "the top bar's menu button shows during the pick")

	await _click(vp, button)
	var pause := app.stack().top() as PauseMenu
	assert_not_null(pause, "the menu button opens the pause menu")
	if pause == null:
		return
	pause.resume_button().pressed.emit()
	await _frames()
	_assert_pick_alone(app, pick, "Resume goes back to the pick")


func test_esc_closes_the_country_panel_then_opens_the_menu_then_goes_back() -> void:
	var env := await _open_pick()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	var pick := env["pick"] as CountryPick

	await _key(vp, KEY_ESCAPE)
	assert_true(app.stack().top() is PauseMenu, "Esc with no panel opens the menu")
	await _key(vp, KEY_ESCAPE)
	_assert_pick_alone(app, pick, "Esc goes back to the pick")

	await _click(vp, pick.row_button(&"GEN"))
	assert_true(app.hud().country_panel().visible, "a row shows its panel")
	await _key(vp, KEY_ESCAPE)
	assert_false(app.hud().country_panel().visible, "the first Esc closes the panel")
	_assert_pick_alone(app, pick, "and no menu yet")
	await _key(vp, KEY_ESCAPE)
	assert_true(app.stack().top() is PauseMenu, "the next Esc opens the menu")


func test_the_menu_of_the_pick_reaches_options_load_and_the_main_menu() -> void:
	var env := await _open_pick()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App

	await _key(vp, KEY_M)
	var pause := app.stack().top() as PauseMenu
	assert_not_null(pause)
	if pause == null:
		return
	assert_true(pause.quit_button().is_visible_in_tree())

	pause.options_button().pressed.emit()
	await _frames()
	assert_true(app.stack().top() is Options)
	await _key(vp, KEY_ESCAPE)
	assert_eq(app.stack().top(), pause, "Back from Options returns to the menu")

	pause.load_button().pressed.emit()
	await _frames()
	assert_true(app.stack().top() is SaveLoad)
	await _key(vp, KEY_ESCAPE)
	assert_eq(app.stack().top(), pause, "Back from Load returns to the menu")

	pause.main_menu_button().pressed.emit()
	await _frames()
	assert_true(app.stack().top() is MainMenu, "nothing is unsaved: straight to the main menu")
	assert_null(app.map_scene())
