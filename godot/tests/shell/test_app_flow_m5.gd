## The M5 App flow (docs/architecture/m5-build-spec.md 6.10 and 9; done-when 7): New game as Genoa -> the People and Food chips ->
## key 5 (the Food mode and its legend) -> `people 6 11 3990` on the console -> a season with its report and its People section ->
## the People page from each chip, "Show on the map" -> F5, the main menu, Continue (the people, the chips and the mode come
## back) -> one more season. A second test: the pick and the sandbox have no Food mode, no chips and refuse `people`.
## The App runs headless in a SubViewport on a temporary save folder.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const VILLAGE := Vector2i(6, 11)

var _prev_game: Game = null
var _old_save_dir: String = ""
var _old_lock_path: String = ""


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_flow_m5_saves"
	RunLock.path = "user://test_flow_m5_running.lock"


func after_each() -> void:
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Bindings.reset_defaults()
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


func _wait_frames(frames: int = 3) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame


func _wait_until(done: Callable, limit: int = 3000) -> bool:
	var frames := 0
	while not bool(done.call()) and frames < limit:
		await get_tree().process_frame
		frames += 1
	return bool(done.call())


func _key(vp: SubViewport, keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		vp.push_input(ev)


## The first key of an action as the Bindings have it.
func _press(vp: SubViewport, action: StringName) -> void:
	var base := Bindings.events_for(action)[0] as InputEventKey
	for pressed: bool in [true, false]:
		var ev := base.duplicate() as InputEventKey
		ev.pressed = pressed
		vp.push_input(ev)


func _app_with(args: Array) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = PackedStringArray(args)
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("game/autosave", "off")
	s.set_value("graphics/season_change", "instant")
	s.set_value("game/season_report", "full")
	app.set_settings_override(s)
	vp.add_child(app)
	return {"vp": vp, "app": app}


func _guard_over(app: App) -> bool:
	return Time.get_ticks_msec() > app.requests().flow.guard_until


## Space, then the report is up.
func _end_season(vp: SubViewport, app: App) -> void:
	await _wait_until(func() -> bool: return _guard_over(app), 600)
	_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is SeasonReport), "the report opens")


func _close_report(vp: SubViewport, app: App) -> void:
	_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "the report closes")


func _words(node: Node) -> String:
	return " | ".join(AppFlowHelpers.labels_under(node))


func _people_of(tag: StringName) -> int:
	return int(PeopleView.totals(Session.game, tag).get("people", 0))


func _village_people() -> int:
	return int(Session.game.state.people[Session.game.map.index_of(VILLAGE)])


func _village_level() -> int:
	return int(Session.game.state.level[Session.game.map.index_of(VILLAGE)])


## One long flow, in the order of spec 9.
func test_m5_flow_chips_key_5_console_season_page_save_load_continue() -> void:
	var env := await _app_with(["--new-game", "--country=GEN", "--seed=1480"])
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()), "the game is up")
	await _wait_frames(3)
	await _chips_and_key_5(vp, app)
	await _console_and_a_season(vp, app)
	await _page_and_show_on_the_map(vp, app)
	await _save_and_continue(vp, app)


func _chips_and_key_5(vp: SubViewport, app: App) -> void:
	var chips := app.hud().chips()
	assert_true(chips.people_chip().visible and chips.food_chip().visible, "a real game: the People and Food chips")
	assert_eq(chips.people_chip().value_label().text, Words.number(_people_of(&"GEN")), "the chip shows the country's people")
	var seg := app.hud().top_bar().mode_segmented()
	assert_not_null(seg.button_for(int(MapModes.Mode.FOOD)), "five segments in a real game (six with Supply, M6)")
	_press(vp, &"view_mode_5")
	await _wait_frames(3)
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.FOOD), "key 5 is the Food mode")
	assert_eq(app.hud().mode_legend().mode(), int(MapModes.Mode.FOOD), "with its legend")
	assert_true(seg.button_for(int(MapModes.Mode.FOOD)).button_pressed, "the top bar shows Food")
	assert_false(seg.button_for(int(MapModes.Mode.YIELDS)).button_pressed, "and not Yields")
	_press(vp, &"view_mode_6")  # M6: key 6 is Supply, with its legend
	await _wait_frames(3)
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.SUPPLY), "key 6 is the Supply mode")
	assert_eq(app.hud().mode_legend().mode(), int(MapModes.Mode.SUPPLY), "with its legend")
	assert_true(seg.button_for(int(MapModes.Mode.SUPPLY)).button_pressed, "the top bar shows Supply")
	_press(vp, &"view_mode_5")
	await _wait_frames(3)
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.FOOD), "back to Food for the rest of the flow")


func _console_and_a_season(vp: SubViewport, app: App) -> void:
	var said := DevCommands.run("people 6 11 3990", app.context())
	assert_true(said.begins_with("Done"), said)
	await _wait_frames(2)
	assert_eq(_village_people(), 3990)
	assert_eq(app.hud().chips().people_chip().value_label().text, Words.number(_people_of(&"GEN")), "the chip is Genoa's (the village is Savoy's)")
	var level_before := _village_level()
	var grew: Array = []
	var seen := func(_tag: StringName, hex: Vector2i, level: int) -> void: grew.append([hex, level])
	Events.town_grew.connect(seen)
	await _end_season(vp, app)
	Events.town_grew.disconnect(seen)
	var words := _words(app.stack().top())
	assert_true(words.contains("People"), "the report has its People section: " + words)
	assert_true(app.hud().chips().people_chip().delta_chip().visible, "a season has closed: People shows its change")
	assert_eq(app.hud().chips().people_chip().value_label().text, Words.number(_people_of(&"GEN")))
	assert_eq(level_before, 2, "a village")
	assert_eq(_village_level(), 3, "at 3,990 and fed it grew into a town in the season")
	assert_eq(grew, [[VILLAGE, 3]], "with its one town_grew")
	await _close_report(vp, app)


func _page_and_show_on_the_map(vp: SubViewport, app: App) -> void:
	app.hud().chips().people_chip().pressed.emit()
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is Study), "the People chip opens the study")
	var study := app.stack().top() as Study
	assert_eq(study.current_page_id(), &"people", "at the People page")
	_key(vp, KEY_ESCAPE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0))
	app.hud().chips().food_chip().pressed.emit()
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is Study), "the Food chip opens the study")
	study = app.stack().top() as Study
	assert_eq(study.current_page_id(), &"people", "at the People page too")
	app.map_scene().set_mode(int(MapModes.Mode.OWNER))
	(study.current_page().find_child("ShowOnMap", true, false) as BaseButton).pressed.emit()
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "Show on the map leaves the study")
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.FOOD), "and the map is in the Food mode")


func _save_and_continue(vp: SubViewport, app: App) -> void:
	var digest := Session.game.digest()
	var people := _people_of(&"GEN")
	var village := _village_people()
	_key(vp, KEY_F5)
	assert_true(await _wait_until(func() -> bool: return FileAccess.file_exists(Session.save_dir.path_join("quick.sav"))))
	await _wait_frames(2)
	app.context().request(&"main_menu")
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is MainMenu), "the main menu")
	app.context().request(&"continue")
	assert_true(await _wait_until(func() -> bool: return Session.game != null and app.map_scene() != null and app.stack().count() == 0 and not app.is_starting(), 900))
	await _wait_frames(3)
	assert_eq(Session.game.digest(), digest, "the same game")
	assert_eq(_people_of(&"GEN"), people)
	assert_eq(_village_people(), village)
	assert_eq(app.hud().chips().people_chip().value_label().text, Words.number(people), "the chip shows the saved people")
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.FOOD), "the Food mode comes back")
	await _end_season(vp, app)
	await _close_report(vp, app)
	assert_eq(app.hud().chips().people_chip().value_label().text, Words.number(_people_of(&"GEN")), "a season after the load")


## The pick and the sandbox: no Food mode, no chips, key 5 refused, and the console refuses `people`.
func test_the_pick_and_the_sandbox_have_no_food_mode_no_chips_and_refuse_people() -> void:
	var env := await _app_with(["--new-game", "--seed=1480"])
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and not app.is_starting()))
	await _wait_frames(3)
	assert_true(Session.game.has_countries(), "the pick: a game with countries and no player yet")
	assert_false(app.hud().chips().visible, "the pick: no chips")
	assert_null(app.hud().top_bar().mode_segmented().button_for(int(MapModes.Mode.FOOD)), "the pick: no Food segment")
	_press(vp, &"view_mode_5")
	await _wait_frames(3)
	assert_ne(app.map_scene().mode(), int(MapModes.Mode.FOOD), "key 5 does not turn it on while picking")
	assert_true(AppFlowHelpers.has_toast(app, "hoose your country"), str(AppFlowHelpers.toasts(app)))
	app.context().request(&"main_menu")
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is MainMenu))
	(app.stack().top() as MainMenu).sandbox_button().pressed.emit()
	await _wait_frames(2)
	(app.stack().top() as Sandbox).start_button().pressed.emit()
	assert_true(await _wait_until(func() -> bool: return Session.game != null and not Session.game.has_countries() and app.map_scene() != null and app.stack().count() == 0))
	await _wait_frames(3)
	assert_false(app.hud().chips().visible, "the sandbox: no chips")
	assert_null(app.hud().top_bar().mode_segmented().button_for(int(MapModes.Mode.FOOD)), "the sandbox: no Food segment")
	_press(vp, &"view_mode_5")
	await _wait_frames(3)
	assert_ne(app.map_scene().mode(), int(MapModes.Mode.FOOD), "key 5 changes nothing in the sandbox")
	var said := DevCommands.run("people 6 11 3990", app.context())
	assert_true(said.to_lower().contains("sandbox has no countries") or said.to_lower().contains("no countries"), said)
