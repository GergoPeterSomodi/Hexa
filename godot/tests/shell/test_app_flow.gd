## End-to-end M1.5 App flow test:
## Boot to MainMenu -> Sandbox -> first-run HelpOverlay -> Esc ladder (Help -> Selection clear -> PauseMenu)
## -> Options -> Back -> Build (unsaved_actions > 0) -> MainMenu Confirm -> Sandbox again, with zero orphans
## (docs/architecture/ui-and-controls-spec.md section 9; ui-and-controls-plan.md U15).
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")

var _prev_game: Game = null
var _prev_unsaved: int = 0
var _old_max_fps: int = 0
var _old_low_proc: bool = false
var _old_tooltip_delay: float = 0.5
var _old_save_dir: String = ""
var _old_lock_path: String = ""


func before_each() -> void:
	Session.ai_enabled = false  # M3 to M7 pin a passive world (M8 D47)
	Bindings.reset_defaults()
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	_old_max_fps = Engine.max_fps
	_old_low_proc = OS.low_processor_usage_mode
	_old_tooltip_delay = float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5))
	# Never the real user://saves or running.lock.
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_flow_saves"
	RunLock.path = "user://test_flow_running.lock"
	_clean_disk()


func _clean_disk() -> void:
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()


func after_each() -> void:
	_clean_disk()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Bindings.reset_defaults()
	Engine.max_fps = _old_max_fps
	OS.low_processor_usage_mode = _old_low_proc
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", _old_tooltip_delay)
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


func _wait_frames(frames: int = 2) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame


func _send_key(vp: SubViewport, keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	vp.push_input(press)

	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	vp.push_input(release)


func _first_buildable_hex() -> Vector2i:
	var g := Session.game
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 0 or not Improve.piece_at(g, hex).is_empty():
			continue
		for opt: Dictionary in Improve.build_options(g, hex):
			if bool(opt["ok"]):
				return hex
	return MapScene.NO_HEX


func test_full_m1_5_app_flow_and_esc_ladder() -> void:
	await _wait_frames(2)
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child(vp)

	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	var s := Settings.new("macOS", true)
	s.set_value("graphics/preload_next_season", false)
	app.set_settings_override(s)
	vp.add_child(app)
	await _wait_frames(2)

	await _verify_boot_and_sandbox_launch(app, s, "1492", true)
	await _verify_esc_ladder_and_options(vp, app)
	await _verify_build_confirm_menu_and_relaunch(vp, app)

	remove_child(vp)
	vp.queue_free()
	await _wait_frames(4)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	assert_eq(orphans_after, orphans_before, "full flow teardown leaves zero orphan nodes")


func _verify_boot_and_sandbox_launch(app: App, s: Settings, seed_str: String, expect_help: bool) -> void:
	var main_menu := app.stack().top() as MainMenu
	assert_not_null(main_menu, "on MainMenu")
	assert_true(app.hides_world())
	assert_true(app.wants_pause())
	assert_null(app.map_scene())

	main_menu.sandbox_button().pressed.emit()
	await _wait_frames(2)
	var sandbox := app.stack().top() as Sandbox
	assert_not_null(sandbox, "Sandbox screen opened")
	sandbox.seed_input().text = seed_str
	sandbox.start_button().pressed.emit()
	await _wait_frames(5)

	assert_not_null(Session.game)
	assert_eq(Session.game.seed_value, seed_str.to_int())
	assert_not_null(app.map_scene(), "MapScene created inside World")
	assert_eq(app.world_host().get_child_count(), 1)
	assert_false(app.hides_world())
	assert_false(app.wants_pause())
	assert_true(app.hud().visible)
	if expect_help:
		assert_not_null(app.stack().top(), "HelpOverlay auto-opens on first sandbox entry")
		assert_eq(app.stack().top().screen_id, &"help")
		assert_true(bool(s.get_value("state/help_seen")))
	else:
		assert_eq(app.stack().count(), 0, "HelpOverlay does not re-open when state/help_seen is true")


func _verify_esc_ladder_and_options(vp: SubViewport, app: App) -> void:
	var map_scene := app.map_scene()

	# Esc ladder step 1: Esc closes HelpOverlay
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0, "first Esc closes HelpOverlay")
	assert_false(app.wants_pause())

	# Esc ladder step 2: select hex -> the tile window opens -> Esc clears selection
	var hex := _first_buildable_hex()
	assert_ne(hex, MapScene.NO_HEX)
	map_scene.select_hex(hex)
	await _wait_frames(2)
	assert_eq(map_scene.selected, hex)
	assert_true(app.hud().tile_window().visible)
	assert_true(app.hud().is_dock_open())

	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	assert_eq(map_scene.selected, MapScene.NO_HEX, "second Esc clears hex selection")
	assert_false(app.hud().tile_window().visible)
	assert_eq(app.stack().count(), 0)

	# Esc ladder step 3: Esc with no selection opens PauseMenu -> Options -> Back
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	var pause := app.stack().top() as PauseMenu
	assert_not_null(pause, "third Esc opens PauseMenu")
	assert_true(app.wants_pause())

	pause.options_button().pressed.emit()
	await _wait_frames(2)
	var options := app.stack().top() as Options
	assert_not_null(options, "Options pushed onto stack")
	options.select_page(&"map")
	await _wait_frames(1)
	var grid_sw := options.option_row("map/grid").control() as KitSwitch
	grid_sw.button_pressed = true
	assert_true(map_scene.view().layer("grid").visible, "Map grid option updates MapScene live")

	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	assert_eq(app.stack().top(), pause, "Esc returns from Options to PauseMenu")


func _verify_build_confirm_menu_and_relaunch(vp: SubViewport, app: App) -> void:
	var map_scene := app.map_scene()
	var hex := _first_buildable_hex()

	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0)
	map_scene.select_hex(hex)
	await _wait_frames(1)
	var build_btn: Button = null
	for b: Button in app.hud().tile_window().action_buttons():
		if not b.disabled and b.text.begins_with("Build"):
			build_btn = b
			break
	assert_not_null(build_btn, "the tile window has an enabled Build hammer")
	build_btn.pressed.emit()
	await _wait_frames(1)
	assert_eq(Session.unsaved_actions, 1, "a window build increments Session.unsaved_actions")

	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(1)
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	var pause := app.stack().top() as PauseMenu
	assert_not_null(pause)

	pause.main_menu_button().pressed.emit()
	await _wait_frames(2)
	var confirm := app.stack().top() as Confirm
	assert_not_null(confirm, "Main menu asks Confirm when unsaved_actions > 0")
	confirm.button_for(&"confirm").pressed.emit()
	await _wait_frames(3)

	assert_null(Session.game, "Session.end_game cleared game")
	assert_eq(Session.unsaved_actions, 0)
	assert_null(app.map_scene(), "World freed cleanly")
	assert_eq(app.world_host().get_child_count(), 0)
	assert_false(app.hud().visible)
	assert_true(app.hides_world())

	await _verify_boot_and_sandbox_launch(app, app.settings(), "1500", false)


# ----- M2: new game, the pick, Play as, the country panel (docs/architecture/m2-build-spec.md sections 7.11 and 10) -----


func _scenario_app(cli_args: PackedStringArray = PackedStringArray()) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = cli_args
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	app.set_settings_override(s)
	vp.add_child(app)
	return {"vp": vp, "app": app}


## Waits until `done` is true, at most `limit` frames; returns whether it became true.
func _wait_until(done: Callable, limit: int = 3000) -> bool:
	var frames := 0
	while not bool(done.call()) and frames < limit:
		await get_tree().process_frame
		frames += 1
	return bool(done.call())


func test_new_game_pick_play_as_genoa_panel_and_pause() -> void:
	var env := await _scenario_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	await _wait_frames(2)

	var menu := app.stack().top() as MainMenu
	assert_not_null(menu)
	assert_true(menu.new_game_button().visible)
	menu.new_game_button().pressed.emit()
	await _wait_frames(2)
	var new_game := app.stack().top() as NewGame
	assert_not_null(new_game, "New game opens")
	new_game.seed_input().text = "1480"
	new_game.begin_button().pressed.emit()

	assert_true(await _wait_until(func() -> bool: return app.stack().top() is CountryPick), "the pick opens")
	assert_eq(Session.game.seed_value, 1480)
	assert_true(Session.game.has_countries())
	assert_eq(Session.player_tag(), &"", "nobody is chosen yet")
	assert_true(app.map_scene().picking())
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.OWNER), "the pick shows the map in Owner mode")
	assert_false(app.hides_world())

	var pick := app.stack().top() as CountryPick
	pick.row_button(&"GEN").pressed.emit()
	await _wait_frames(2)
	assert_eq(app.hud().country_panel().shown_tag(), &"GEN", "a row shows its panel in the dock")
	assert_eq(app.stack().top(), pick, "showing does not end the pick")
	pick.row_button(&"GEN").pressed.emit()
	await _wait_frames(3)

	assert_eq(Session.player_tag(), &"GEN")
	assert_eq(app.stack().count(), 0, "the pick ends once a country is chosen")
	assert_eq(Session.unsaved_actions, 0, "choosing a country is not unsaved work")
	assert_eq(app.hud().top_bar().country_button().text, "Republic of Genoa")
	assert_false(app.hud().country_panel().visible)
	assert_false(app.map_scene().picking())

	_send_key(vp, KEY_C)
	await _wait_frames(2)
	assert_eq(app.hud().country_panel().shown_tag(), &"GEN", "C opens your country's panel")
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	assert_false(app.hud().country_panel().visible, "Esc closes the panel")
	assert_eq(app.stack().count(), 0)
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	var pause := app.stack().top() as PauseMenu
	assert_not_null(pause, "the next Esc pauses")
	assert_eq(pause.subtitle_label().text, "Republic of Genoa · Spring 1480", "the subtitle names the country and the date")


func test_show_on_the_map_switches_to_owner_mode() -> void:
	var env := await _scenario_app(PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"]))
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and not app.map_scene().is_loading()))
	await _wait_until(func() -> bool: return app.stack().count() == 0)
	app.map_scene().set_mode(int(MapModes.Mode.TERRAIN))
	app.hud().country_look_at_requested.emit(Vector2i(10, 10))
	await _wait_frames(1)
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.OWNER))


func test_command_line_new_game_with_a_country_skips_the_pick() -> void:
	var env := await _scenario_app(PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"]))
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and not app.map_scene().is_loading()))
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "no pick, no loading")
	assert_eq(Session.player_tag(), &"GEN")
	assert_eq(Session.game.seed_value, 1480)
	assert_eq(Session.unsaved_actions, 0)
	assert_false(app.map_scene().picking())
	assert_false(app.hides_world())
	assert_eq(app.hud().top_bar().country_button().text, "Republic of Genoa")


func test_command_line_new_game_without_a_country_opens_the_pick() -> void:
	var env := await _scenario_app(PackedStringArray(["--new-game", "--seed=7"]))
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is CountryPick))
	assert_eq(Session.player_tag(), &"")


func test_a_scenario_the_rules_refuse_toasts_and_returns_to_the_main_menu() -> void:
	var env := await _scenario_app()
	var app := env["app"] as App
	await _wait_frames(2)
	var toasts: Array = []
	app.context().toast_requested.connect(func(text: String, tone: StringName) -> void: toasts.append([text, tone]))
	app.context().request(&"new_game", {"scenario": "no_such_scenario", "seed": 5})
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is MainMenu, 60))
	assert_eq(toasts.size(), 1)
	assert_eq((toasts[0] as Array)[1], &"bad")
	assert_null(app.map_scene())
	assert_true(app.hides_world())


# ----- M3: the whole flow (docs/architecture/m3-build-spec.md section 9) -------------------------------------------------


func _send_chord(vp: SubViewport, keycode: Key, ctrl: bool, shift: bool) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.ctrl_pressed = ctrl
		ev.shift_pressed = shift
		ev.pressed = pressed
		vp.push_input(ev)


func _buildable() -> Dictionary:
	var game := Session.game
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if game.map.land[i] == 0 or not Improve.piece_at(game, hex).is_empty():
			continue
		for option: Dictionary in Improve.build_options(game, hex):
			if bool(option["ok"]) and bool(Session.check("build", {"hex": hex, "family": int(option["family_id"])})["ok"]):
				return {"hex": hex, "family": int(option["family_id"])}
	return {}


func _report_up(app: App) -> bool:
	return app.stack().top() is SeasonReport


func _guard_over(app: App) -> bool:
	return Time.get_ticks_msec() > app.requests().flow.guard_until


## One season by the keys: Space, the report, Space.
func _play_season(vp: SubViewport, app: App) -> void:
	await _wait_until(func() -> bool: return _guard_over(app), 600)
	_send_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return _report_up(app)), "the report opens")
	_send_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "the report closes")


## New game, pick Genoa, build, Space (the report), Space (closes), a second Space inside the guard is refused, J (the same
## report), F5, a season more, F9 (asks), the same digest and the same report, bookmarks, the main menu and Continue.
func test_m3_flow_pick_build_space_report_j_quicksave_quickload_continue() -> void:
	var env := await _scenario_app(PackedStringArray(["--new-game", "--seed=1480"]))
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	var s := app.settings()
	s.set_value("game/autosave", "off")
	s.set_value("graphics/season_change", "instant")
	s.set_value("game/season_report", "full")
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is CountryPick), "the pick opens")

	# During the pick End season is refused with its reason, and Space plays nothing.
	var date_end := app.hud().date_end()
	assert_true(date_end.end_button().disabled, "End season is off during the pick")
	assert_ne(date_end.verdict_text(), "")
	_send_key(vp, KEY_SPACE)
	await _wait_frames(3)
	assert_eq(Session.game.turn, 1, "Space during the pick plays nothing")
	assert_true(app.stack().top() is CountryPick)

	(app.stack().top() as CountryPick).play(&"GEN")
	await _wait_frames(3)
	assert_eq(app.stack().count(), 0)
	assert_eq(date_end.date_button().text, "Spring 1480")
	assert_eq(date_end.season(), 0, "Spring")
	assert_false(date_end.end_button().disabled)
	Session.game.defs = EconomyFixture.defs()  # calm weather: a save carries the weather only from N5 on

	var found := _buildable()
	assert_true(bool(Session.act("build", {"hex": found["hex"], "family": found["family"]})["ok"]), "a work begins")
	assert_eq(Session.game.state.works.size(), 1)

	# Space: the season runs and the report opens.
	_send_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return _report_up(app)), "the first Space opens the report")
	assert_eq(Session.game.turn, 2)
	assert_eq(app.requests().flow.state(), SeasonFlow.State.REPORT)
	assert_eq(date_end.season(), 1, "the date follows the calendar: Summer")
	var report_summary := SeasonSummary.of(Session.game, Session.player_tag(), 1)

	# Space closes it; the map shows the calendar's season; a second Space inside the guard is refused. The flow's clock stands
	# still while the guard is tested (a slow machine must not let 400 ms go by), then the real clock is back.
	var frozen := [Time.get_ticks_msec()]
	app.requests().flow.clock = func() -> int: return frozen[0]
	_send_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "the second Space closes the report")
	assert_eq(app.requests().flow.state(), SeasonFlow.State.IDLE)
	assert_eq(app.map_scene().season, "summer", "the map changes season with the calendar")
	_send_key(vp, KEY_SPACE)
	await _wait_frames(3)
	assert_eq(Session.game.turn, 2, "a Space inside the 400 ms guard plays nothing")
	assert_eq(app.stack().count(), 0)
	app.requests().flow.clock = Callable(Time, "get_ticks_msec")

	# J: the same report again.
	await _wait_until(func() -> bool: return _guard_over(app), 600)
	_send_key(vp, KEY_J)
	assert_true(await _wait_until(func() -> bool: return _report_up(app)), "J reopens the last report")
	assert_eq(Session.game.turn, 2, "J plays nothing")
	var shown := app.stack().top() as SeasonReport
	assert_eq(shown.sheet().title, str(report_summary["title"]), "the same letter")
	_send_key(vp, KEY_ESCAPE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0))

	await _verify_save_load_bookmarks_and_continue(vp, app)


## F5 with a bookmark, a season more, F9, the same digest and J's report, Ctrl+1, the main menu and Continue.
func _verify_save_load_bookmarks_and_continue(vp: SubViewport, app: App) -> void:
	# Ctrl+Shift+1 sets a bookmark; F5 saves with it.
	_send_chord(vp, KEY_1, true, true)
	await _wait_frames(2)
	assert_gt(app.requests().bookmarks.get_at(1).size(), 0, "Ctrl+Shift+1 sets bookmark 1")
	_send_key(vp, KEY_F5)
	assert_true(await _wait_until(func() -> bool: return FileAccess.file_exists(Session.save_dir.path_join("quick.sav"))))
	await _wait_frames(2)
	assert_eq(Session.unsaved_actions, 0, "a save leaves nothing unsaved")
	var digest_saved := Session.game.digest()
	var summary_saved := SeasonSummary.of(Session.game, Session.player_tag(), Session.game.turn - 1)

	# Another season, then F9 asks before losing it.
	await _play_season(vp, app)
	assert_eq(Session.game.turn, 3)
	assert_gt(Session.unsaved_actions, 0)
	_send_key(vp, KEY_F9)
	await _wait_frames(2)
	var ask := app.stack().top() as Confirm
	assert_not_null(ask, "F9 asks before losing unsaved actions")
	ask.button_for(&"confirm").pressed.emit()
	assert_true(await _wait_until(func() -> bool: return Session.game.turn == 2 and app.stack().count() == 0 and not app.is_starting(), 900))
	assert_eq(Session.game.digest(), digest_saved, "the quickload gives the saved digest")
	assert_eq(app.map_scene().season, "summer", "the loaded map shows the calendar's season")
	assert_eq(SeasonSummary.of(Session.game, Session.player_tag(), Session.game.turn - 1), summary_saved, "J's report is the same after a load")
	assert_gt(app.requests().bookmarks.get_at(1).size(), 0, "the bookmarks come back from the save")

	# Ctrl+1 goes back to the bookmark (reduce motion: a jump).
	var cam := app.map_scene().camera()
	var at := app.requests().bookmarks.get_at(1)["centre"] as Vector2
	cam.position = at + Vector2(300.0, 200.0)
	_send_chord(vp, KEY_1, true, false)
	await _wait_frames(3)
	assert_lt(cam.position.distance_to(at), 60.0, "Ctrl+1 goes to bookmark 1")

	# Quit to the main menu (nothing unsaved: no question), then Continue gives the same digest.
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	var pause := app.stack().top() as PauseMenu
	assert_not_null(pause)
	pause.main_menu_button().pressed.emit()
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is MainMenu), "no question: it was saved")
	var menu := app.stack().top() as MainMenu
	assert_true(menu.continue_button().visible)
	menu.continue_button().pressed.emit()
	assert_true(await _wait_until(func() -> bool: return Session.game != null and app.map_scene() != null and app.stack().count() == 0 and not app.is_starting(), 900))
	assert_eq(Session.game.digest(), digest_saved, "Continue gives the same digest")


func test_autosave_runs_after_the_report_closes_when_due() -> void:
	var env := await _scenario_app(PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"]))
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0))
	app.settings().set_value("game/autosave", "yearly")
	app.settings().set_value("graphics/season_change", "instant")
	for _i: int in 4:
		await _play_season(vp, app)
	assert_eq(Session.game.turn, 5, "Spring 1481")
	await _wait_frames(2)
	assert_eq(SaveFile.read_header("auto1", Session.save_dir)["state"], &"ok", "Spring 1481 is autosaved")


func test_recovery_asks_when_the_lock_was_left_and_the_autosave_is_newest() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480, &"GEN"), "")
	assert_eq(Session.autosave_game(null, {}), "")
	var turn := Session.game.turn
	RunLock.write("north_italy", int(Time.get_unix_time_from_system()))
	Session.end_game()
	var env := await _scenario_app()
	var app := env["app"] as App
	await _wait_frames(3)
	var ask := app.stack().top() as Confirm
	assert_not_null(ask, "the question is pushed over the main menu")
	assert_false(FileAccess.file_exists(RunLock.path), "the lock is deleted either way")
	ask.button_for(&"confirm").pressed.emit()
	assert_true(await _wait_until(func() -> bool: return Session.game != null and app.map_scene() != null and app.stack().count() == 0, 900))
	assert_eq(Session.game.turn, turn)


func test_recovery_not_now_keeps_the_main_menu() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480, &"GEN"), "")
	assert_eq(Session.autosave_game(null, {}), "")
	RunLock.write("north_italy", int(Time.get_unix_time_from_system()))
	Session.end_game()
	var env := await _scenario_app()
	var app := env["app"] as App
	await _wait_frames(3)
	var ask := app.stack().top() as Confirm
	assert_not_null(ask)
	ask.button_for(&"cancel").pressed.emit()
	await _wait_frames(3)
	assert_true(app.stack().top() is MainMenu)
	assert_null(Session.game)
	assert_false(FileAccess.file_exists(RunLock.path))


func test_no_recovery_question_without_a_lock() -> void:
	var env := await _scenario_app()
	var app := env["app"] as App
	await _wait_frames(3)
	assert_true(app.stack().top() is MainMenu)


# ----- M4 (docs/architecture/m4-build-spec.md 9; the owner's playtest checklist 1 to 8 and 15 of m4-build-plan.md section 4) --
# The other M4 App tests (U in the three Confirm works modes, the options, the sandbox, the console) are in test_app_flow_m4.gd.

const GENOA := Vector2i(8, 13)
const SAVONA := Vector2i(6, 13)
const VINEYARD := Vector2i(7, 12)
const WOODS := Vector2i(10, 13)


## A Genoa game on seed 1480, no pick, the report on, the map ready and the top bar fitted.
func _genoa_app() -> Dictionary:
	var env := await _scenario_app(PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"]))
	var app := env["app"] as App
	app.settings().set_value("game/autosave", "off")
	app.settings().set_value("graphics/season_change", "instant")
	app.settings().set_value("game/season_report", "full")
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()), "the game is up")
	await _wait_frames(3)  # the HUD lays out: the top bar is fitted to the window
	return env


## New game as Genoa; the chips, the rows, the hover card, U, begin, undo, Space, the study, tax and F5 with Continue.
func test_m4_flow_chips_rows_card_begin_undo_report_study_tax_save_load() -> void:
	var env := await _genoa_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	await _m4_chips_and_gives(app)
	await _m4_hover_card(vp, app)
	await _m4_u_refusals(vp, app)
	await _m4_begin_and_undo(vp, app)
	var study := await _m4_report_and_study(vp, app)
	await _m4_tax_and_look(vp, app, study)
	await _m4_save_and_continue(vp, app)


## Checklist 1 and 2: the chips (610 ducats, the cards) and the vineyard's Gives row.
func _m4_chips_and_gives(app: App) -> void:
	var chips := app.hud().chips()
	assert_true(chips.visible, "the chips show for the player")
	assert_eq(AppFlowHelpers.ducats_shown(app), "610")
	var ducats_text := " | ".join(AppFlowHelpers.card_lines(chips.ducats_card()))
	assert_true(ducats_text.contains("No season has ended yet."), ducats_text)
	assert_true(ducats_text.contains("Expected this season"), ducats_text)
	assert_gt(AppFlowHelpers.card_lines(chips.stores_card()).size(), 4, "the stores card lists the goods in store")
	assert_true(app.hud().top_bar().study_button().visible, "the study button shows")
	app.map_scene().select_hex(VINEYARD)
	await _wait_frames(3)
	assert_true(app.hud().tile_window().show_tab(&"land"), "the Land tab is live on own land")
	var texts := AppFlowHelpers.labels_under(app.hud().tile_window().tab_node())
	for entry: Dictionary in (TileView.of(Session.game, &"GEN", VINEYARD)["land"] as Dictionary)["made"]:
		assert_true(texts.has("%d loads" % int(entry["loads"])), "the Land tab shows what the vineyard makes: %s" % str(texts))
	app.hud().tile_window().show_tab(&"buildings")  # the pick is remembered: the rows are on the Buildings tab


## Checklist 3: a row's hover opens the card beside the panel and the marks on the map; Shift and pin keep it; Esc closes it.
func _m4_hover_card(vp: SubViewport, app: App) -> void:
	app.map_scene().select_hex(WOODS)
	await _wait_frames(3)
	var woods := AppFlowHelpers.row_button(app, "Build woodland")
	assert_not_null(woods, "a woodland row")
	assert_not_null(AppFlowHelpers.row_button(app, "Build harbour"), "a harbour row")
	AppFlowHelpers.hover_card(app, WOODS, woods)
	await _wait_frames(2)
	var card := app.stack().top() as WorksPreview
	assert_not_null(card, "the hover opens the card")
	assert_lt(card.card_rect().end.x, Hud.screen_rect(app.hud().tile_window()).position.x + 1.0, "left of the panel")
	var marks := app.map_scene().preview_marks()
	assert_true(marks.shown(), "the ghost and the marks are on the map")
	# M5 D18: hands count only Genoa's own hexes, so the new woodland at (10, 13), on Genoa's edge, is staffed a little less
	# than M4's +16 (which counted a neighbour's people): +10 a year.
	assert_true(marks.labels().any(func(l: Dictionary) -> bool: return str(l["text"]) == "+10 timber"), str(marks.labels()))
	card.hold(true)  # Shift
	AppFlowHelpers.hover_out(woods)
	await _wait_frames(2)
	assert_eq(app.stack().top(), card, "Shift keeps the card while the pointer is away")
	card.hold(false)
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0, "released, it goes")
	assert_false(marks.shown(), "and its marks with it")
	AppFlowHelpers.hover_card(app, WOODS, woods)
	await _wait_frames(2)
	card = app.stack().top() as WorksPreview
	card.pin(true)
	AppFlowHelpers.hover_out(woods)
	await _wait_frames(2)
	assert_eq(app.stack().top(), card, "a pinned card stays")
	AppFlowHelpers.hover_card(app, WOODS, AppFlowHelpers.row_button(app, "Build harbour"))
	await _wait_frames(2)
	assert_eq(app.stack().count(), 1, "the next option opens in the same card, beside the pinned one")
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0, "Esc closes the card")
	assert_false(marks.shown())


## Checklist 4 and 5: U on Genoa (refused for the ducats, everything shown) and on Savona (only the town rule).
func _m4_u_refusals(vp: SubViewport, app: App) -> void:
	app.map_scene().select_hex(GENOA)
	await _wait_frames(2)
	_send_key(vp, KEY_U)
	await _wait_frames(3)
	var card := app.stack().top() as WorksPreview
	assert_not_null(card, "U opens the card in the default Confirm works mode (the upgrade is expensive)")
	assert_eq(card.shown_hex(), GENOA)
	assert_eq(str(card.shown_option()["action"]), "upgrade")
	assert_eq(str(card.preview()["reason_words"]), "Not enough ducats: 1,000 needed, 610 in the treasury.")
	assert_gt((card.preview()["brings"] as Array).size(), 0, "everything is shown")
	assert_eq(Session.game.state.works.size(), 0, "nothing was begun")
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0)
	app.map_scene().select_hex(SAVONA)
	await _wait_frames(2)
	_send_key(vp, KEY_U)
	await _wait_frames(3)
	card = app.stack().top() as WorksPreview
	assert_not_null(card)
	assert_eq(str(card.preview()["reason_words"]), "Cuneo (5, 13) is a town beside Savona: two towns may not stand side by side.")
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)


## Checklist 6: begin woodland: the toast, 570, the stores unchanged; undo gives 610 back; begin it again.
func _m4_begin_and_undo(vp: SubViewport, app: App) -> void:
	app.map_scene().select_hex(WOODS)
	await _wait_frames(3)
	var stores_before := app.hud().chips().stores_card().duplicate(true)
	AppFlowHelpers.row_button(app, "Build woodland").pressed.emit()
	await _wait_frames(3)
	assert_true(AppFlowHelpers.has_toast(app, "−40 ducats"), str(AppFlowHelpers.toasts(app)))
	assert_eq(AppFlowHelpers.ducats_shown(app), "570")
	assert_eq(app.hud().chips().stores_card(), stores_before, "no goods for a first stage")
	assert_eq(app.stack().count(), 0)
	AppFlowHelpers.undo_key(vp)
	await _wait_frames(3)
	assert_true(AppFlowHelpers.has_toast(app, "+40 ducats back"), str(AppFlowHelpers.toasts(app)))
	assert_eq(AppFlowHelpers.ducats_shown(app), "610")
	AppFlowHelpers.row_button(app, "Build woodland").pressed.emit()
	await _wait_frames(3)
	assert_eq(AppFlowHelpers.ducats_shown(app), "570")


## Checklist 7: Space: the report, 610 to 656; Open the study opens the Economy page and the report is gone.
func _m4_report_and_study(vp: SubViewport, app: App) -> Study:
	await _wait_until(func() -> bool: return _guard_over(app), 600)
	_send_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return _report_up(app)), "the report opens")
	var report := app.stack().top() as SeasonReport
	var treasury_total := ""
	for section: Dictionary in SeasonSummary.of(Session.game, &"GEN", 1)["sections"]:
		if section["id"] == &"treasury":
			treasury_total = str((section["total"] as Dictionary)["text"])
	assert_eq(treasury_total, "610 → 656")
	assert_true(AppFlowHelpers.labels_under(report).any(func(t: String) -> bool: return t.contains("656")), "the report shows it")
	var open_study := report.find_child("StudyButton", true, false) as Button
	assert_not_null(open_study, "Open the study")
	open_study.pressed.emit()
	await _wait_frames(3)
	var study := app.stack().top() as Study
	assert_not_null(study, "the study opens, the report is gone")
	assert_eq(study.current_page_id(), &"economy")
	assert_false(app.stack().has_screen(&"season_report"))
	var page_text := " | ".join(AppFlowHelpers.labels_under(study))
	for part: String in ["Money in", "Money out", "Left over, a season", "Expected this season", "Your spending"]:
		assert_true(page_text.contains(part), part + " in " + page_text)
	return study


## Checklist 8: tax High (the toast, Expected rises) and back to Normal; a place closes the study; I reopens the same one.
func _m4_tax_and_look(vp: SubViewport, app: App, study: Study) -> void:
	var tax := study.find_child("TaxLevels", true, false) as Segmented
	assert_not_null(tax)
	var expected_before := int((StudyEconomy.this_season(Session.game, &"GEN")["expected"] as Dictionary)["realm"])
	tax.button_for(2).button_pressed = true
	await _wait_frames(2)
	assert_true(AppFlowHelpers.has_toast(app, "Taxes set to High"), str(AppFlowHelpers.toasts(app)))
	assert_gt(int((StudyEconomy.this_season(Session.game, &"GEN")["expected"] as Dictionary)["realm"]), expected_before, "Expected rises")
	tax = study.find_child("TaxLevels", true, false) as Segmented
	tax.button_for(1).button_pressed = true
	await _wait_frames(2)
	assert_eq(Countries.by_tag(Session.game, &"GEN").tax, 1, "back to Normal")
	var link: Button = null
	for node: Node in study.find_children("*", "Button", true, false):
		if (node as Button).accessibility_name.begins_with("Look at"):
			link = node as Button
			break
	assert_not_null(link, "a row of Earns most or the ledger")
	link.pressed.emit()
	await _wait_frames(3)
	assert_eq(app.stack().count(), 0, "the study closes and the map glides there")
	_send_key(vp, KEY_I)
	await _wait_frames(3)
	assert_eq(app.stack().top(), study, "I reopens the same study")
	assert_eq(study.current_page_id(), &"economy")
	_send_key(vp, KEY_I)
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0, "I closes it")


## Checklist 15: F5, the main menu, Continue: the ducats and the stores as before, and the study opens.
func _m4_save_and_continue(vp: SubViewport, app: App) -> void:
	var treasury_saved := Countries.by_tag(Session.game, &"GEN").treasury
	var stock_saved := Countries.by_tag(Session.game, &"GEN").stock.duplicate()
	var digest_saved := Session.game.digest()
	_send_key(vp, KEY_F5)
	assert_true(await _wait_until(func() -> bool: return FileAccess.file_exists(Session.save_dir.path_join("quick.sav"))))
	await _wait_frames(2)
	app.context().request(&"main_menu")
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is MainMenu), "the main menu")
	app.context().request(&"continue")
	assert_true(await _wait_until(func() -> bool: return Session.game != null and app.map_scene() != null and app.stack().count() == 0 and not app.is_starting(), 900))
	assert_eq(Session.game.digest(), digest_saved)
	assert_eq(Countries.by_tag(Session.game, &"GEN").treasury, treasury_saved)
	assert_eq(Countries.by_tag(Session.game, &"GEN").stock, stock_saved)
	assert_eq(AppFlowHelpers.ducats_shown(app), Words.number(treasury_saved), "the chip shows the saved ducats")
	_send_key(vp, KEY_I)
	await _wait_frames(3)
	var study := app.stack().top() as Study
	assert_not_null(study, "the study opens after a load")
	assert_eq(study.current_page_id(), &"economy")
