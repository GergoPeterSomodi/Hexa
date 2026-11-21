## The movement replay's input (docs/architecture/m6-build-spec.md 6.4; task L15): a real click on the map goes through the
## scene's MapInput (its _unhandled_input, with the real pointer routing) while the replay runs. The click selects and orders
## nothing, shows "The moves are still playing: Space skips them." and does NOT skip; Space and Esc skip. The App runs headless
## in a SubViewport, as in test_game_requests.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")

var _old_save_dir: String = ""
var _old_lock_path: String = ""
var _prev_game: Game = null
## The army marched by _replay_running.
var _army_id := -1


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_replay_click_saves"
	RunLock.path = "user://test_replay_click_running.lock"


func after_each() -> void:
	Engine.time_scale = 1.0
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	RunLock.clear()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Bindings.reset_defaults()


func _wait_until(done: Callable, limit: int = 900) -> bool:
	var frames := 0
	while not bool(done.call()) and frames < limit:
		await get_tree().process_frame
		frames += 1
	return bool(done.call())


func _game_app() -> App:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"])
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("game/autosave", "off")
	s.set_value("graphics/season_change", "instant")
	s.set_value("game/movement", "normal")
	s.set_value("accessibility/reduce_motion", false)  # the replay runs at the normal speed, not instant
	app.set_settings_override(s)
	vp.add_child(app)
	await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting())
	return app


func _mouse(button: MouseButton, pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.position = pos
	ev.global_position = pos
	ev.pressed = pressed
	return ev


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev


## Starts a replay in the App: an army of Genoa marches one hex and the season ends through the request (as End season).
## Returns the army's hex.
func _replay_running(app: App) -> Vector2i:
	var game := Session.game
	var hex := ArmyFixture.find_town(game)
	var goal := game.map.neighbour(hex, 0)
	var a := ArmyFixture.army(game, ArmyFixture.TAG, hex, 0, 2, game.turn - 1)
	game.version += 1
	assert_true(bool(Session.act("march", {"army": a.id, "goal": goal}).get("ok", false)), "the march is ordered")
	_army_id = a.id
	app.context().request(&"end_seasons", {"count": 1})
	await get_tree().process_frame
	assert_true(await _wait_until(func() -> bool: return app._requests.replay.active()), "the replay runs")
	# The replay is one short step: slow the game clock so it is still playing while the test presses keys.
	Engine.time_scale = 0.01
	return hex


func _click_on(app: App, hex: Vector2i) -> void:
	var scene := app.map_scene()
	var view := scene.view()
	var pos := view.get_global_transform_with_canvas() * view.centre_of(hex)
	var input := scene.map_input()
	input._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, pos, true))
	input._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, pos, false))


func test_a_click_during_the_replay_says_so_selects_nothing_and_skips_nothing() -> void:
	var app := await _game_app()
	var hex := await _replay_running(app)
	var scene := app.map_scene()
	var before := Session.game.digest()
	_click_on(app, hex)
	assert_true(app._requests.replay.active(), "the click does not skip the replay")
	assert_true(app.context().season_running(), "the season still runs")
	assert_eq((scene.get_node("MapArmies") as MapArmies).selected_army(), -1, "the click selects no army")
	assert_eq(Session.game.digest(), before, "the click orders nothing")
	assert_true(app.hud().toast_host().messages().has("The moves are still playing: Space skips them."),
		"the spec's toast is shown")


func test_space_skips_the_replay_through_the_map_input() -> void:
	var app := await _game_app()
	await _replay_running(app)
	var input := app.map_scene().map_input()
	input._unhandled_input(_key(KEY_SPACE))
	assert_false(app._requests.replay.active(), "Space skips the replay")


func test_o_and_r_during_the_replay_give_no_order_and_say_so() -> void:
	var app := await _game_app()
	await _replay_running(app)
	var armies := app.map_scene().get_node("MapArmies") as MapArmies
	assert_true(armies.show_army(_army_id), "the army is selected")
	var input := app.map_scene().map_input()
	app.hud().toast_host().clear()
	var before := Session.game.digest()
	input._unhandled_input(_key(KEY_O))
	assert_true(app.hud().toast_host().messages().has(MapArmies.REPLAY_BLOCKED), "O is refused with the replay's line")
	app.hud().toast_host().clear()
	input._unhandled_input(_key(KEY_R))
	assert_true(app.hud().toast_host().messages().has(MapArmies.REPLAY_BLOCKED), "R is refused with the replay's line")
	assert_eq(Session.game.digest(), before, "neither key orders anything")
	assert_true(app._requests.replay.active(), "and neither skips the replay")


func test_f5_during_the_replay_is_refused_and_the_replay_plays_on() -> void:
	var app := await _game_app()
	await _replay_running(app)
	app.hud().toast_host().clear()
	assert_true(app.app_input().handle_key_event(_key(KEY_F5)), "F5 is taken")
	assert_true(app.hud().toast_host().messages().has("Could not save: Wait for the season to end."), "the save is refused")
	assert_true(app._requests.replay.active(), "the replay plays on")


func test_esc_over_a_screen_closes_the_screen_and_keeps_the_replay() -> void:
	var app := await _game_app()
	await _replay_running(app)
	app.app_input().menu_requested.emit()
	await get_tree().process_frame
	assert_true(app.stack().count() > 0, "the pause menu is open over the replay")
	for i: int in 4:
		if app.stack().count() == 0:
			break
		app.app_input().handle_key_event(_key(KEY_ESCAPE))
		await get_tree().process_frame
	assert_eq(app.stack().count(), 0, "Esc closed the screen")
	assert_true(app._requests.replay.active(), "Esc over the screen did not skip the replay")
	assert_true(app.app_input().handle_key_event(_key(KEY_ESCAPE)), "Esc is taken")
	assert_false(app._requests.replay.active(), "Esc over the bare map skips it")


func test_a_load_during_the_replay_is_allowed_and_cancels_it() -> void:
	var app := await _game_app()
	assert_eq(Session.save_game("1"), "", "there is a save to load")
	await _replay_running(app)
	app.context().request(&"load", {"slot": "1"})
	assert_true(await _wait_until(func() -> bool: return not app._requests.replay.active()),
		"the load goes through and cancels the replay")
	assert_eq(app._requests.flow.state(), SeasonFlow.State.IDLE, "the flow is idle after the load")


func test_esc_skips_the_replay_through_the_app_input() -> void:
	var app := await _game_app()
	await _replay_running(app)
	assert_true(app.app_input().handle_key_event(_key(KEY_ESCAPE)), "Esc is taken")
	assert_false(app._requests.replay.active(), "Esc skips the replay")
