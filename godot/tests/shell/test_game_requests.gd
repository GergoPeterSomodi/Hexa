## GUT tests for the App's M3 requests (docs/architecture/m3-build-spec.md 6.15): undo, bookmarks, the console's `end` and
## `look`, Save and Load through the context, Continue falling back to an older save, the pause menu's Save while the season
## runs, the ribbons' node and the lock. The App runs headless in a SubViewport on a temporary save folder.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")

var _old_save_dir: String = ""
var _old_lock_path: String = ""
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_requests_saves"
	RunLock.path = "user://test_requests_running.lock"
	_clean()


func after_each() -> void:
	_clean()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Bindings.reset_defaults()


func _clean() -> void:
	for slot: String in SaveFile.SLOTS + SaveFile.AUTO_SLOTS:
		SaveFile.remove(slot, Session.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.save_dir))
	RunLock.clear()


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
	app.set_settings_override(s)
	vp.add_child(app)
	await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting())
	return app


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


func test_the_map_has_floaters_and_the_flow_is_a_child() -> void:
	var app := await _game_app()
	assert_not_null(app.map_scene().get_node_or_null("Names/Floaters") as Floaters)
	assert_not_null(app.requests().flow)
	assert_eq(app.requests().flow.get_parent(), app)
	assert_false(app.context().season_running())


func test_undo_cancels_the_work_begun_this_season_and_toasts() -> void:
	var app := await _game_app()
	var found := _buildable()
	assert_true(bool(Session.act("build", {"hex": found["hex"], "family": found["family"]})["ok"]))
	assert_true(app.hud().toast_host().messages().any(func(m: String) -> bool: return m.begins_with("Work begun: ")), "the begun toast")
	app.requests().undo_work()
	assert_eq(Session.game.state.works.size(), 0, "Ctrl+Z cancels the newest work")
	assert_true(app.hud().toast_host().messages().any(func(m: String) -> bool: return m.begins_with("Work cancelled: ")))
	app.requests().undo_work()
	assert_true(app.hud().toast_host().messages().has(GameRequests.UNDO_NOTHING), "nothing more to undo")


func test_bookmarks_set_go_and_empty() -> void:
	var app := await _game_app()
	app.requests().on_bookmark(3, false)
	assert_true(app.hud().toast_host().messages().any(func(m: String) -> bool: return m.begins_with("Bookmark 3 is empty")))
	var cam := app.map_scene().camera()
	var at := cam.position
	app.requests().on_bookmark(3, true)
	assert_true(app.hud().toast_host().messages().has("Bookmark 3 set."))
	cam.position = at + Vector2(200.0, 100.0)
	app.requests().on_bookmark(3, false)
	await get_tree().process_frame
	assert_lt(cam.position.distance_to(at), 60.0)
	assert_true((app.requests().ui_block()["bookmarks"] as Dictionary).has("3"), "the bookmarks are in the save's ui block")


func test_console_end_seasons_plays_n_seasons_and_one_report() -> void:
	var app := await _game_app()
	app.context().request(&"end_seasons", {"count": 3})
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is SeasonReport))
	assert_eq(Session.game.turn, 4, "three seasons were played")
	assert_eq(app.stack().count(), 1, "one report, after the last")


func test_dev_look_previews_and_the_next_season_ends_it() -> void:
	var app := await _game_app()
	app.context().request(&"dev_look", {"season": 3})
	await get_tree().process_frame
	assert_eq(app.map_scene().season, "winter")
	assert_eq(app.hud().debug_overlay().season_segmented().selected_id(), 3)
	app.context().request(&"dev_look", {"season": -1})
	await get_tree().process_frame
	assert_eq(app.map_scene().season, "spring", "Calendar goes back to the calendar's season")


func test_save_request_writes_the_slot_and_emits_saved() -> void:
	var app := await _game_app()
	var seen: Array = []
	app.context().saved.connect(func(slot: String, problem: String) -> void: seen.append([slot, problem]))
	app.context().request(&"save", {"slot": "3", "name": "Test"})
	assert_true(await _wait_until(func() -> bool: return not seen.is_empty(), 60))
	assert_eq(seen[0], ["3", ""])
	assert_eq(SaveFile.read_header("3", Session.save_dir)["state"], &"ok")
	assert_true(app.hud().toast_host().messages().has("Saved: Slot 3."))
	assert_eq(Session.unsaved_actions, 0)


func test_quicksave_saves_the_running_game_and_is_refused_without_one() -> void:
	var app := await _game_app()
	app.requests().quicksave()
	assert_true(await _wait_until(func() -> bool: return FileAccess.file_exists(Session.save_dir.path_join("quick.sav")), 60))
	Session.end_game()
	app.requests().quicksave()
	assert_true(app.hud().toast_host().messages().has(GameRequests.NO_GAME_TO_SAVE))


func test_quickload_with_no_quicksave_toasts() -> void:
	var app := await _game_app()
	app.requests().quickload()
	assert_true(app.hud().toast_host().messages().has(GameRequests.NO_QUICKSAVE))


func test_continue_falls_back_to_the_next_newest_save() -> void:
	var app := await _game_app()
	assert_eq(Session.save_game("1", null, {}), "")
	await get_tree().process_frame
	assert_eq(Session.save_game("2", null, {}), "")
	# Damage the newest save's body (the header stays readable), so only the load fails.
	var path := Session.save_dir.path_join("2.sav")
	var bytes := FileAccess.get_file_as_bytes(path)
	bytes[bytes.size() - 3] = (bytes[bytes.size() - 3] + 1) % 256
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	var header1 := SaveFile.read_header("1", Session.save_dir)["header"] as Dictionary
	app.context().request(&"main_menu")
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is MainMenu, 60))
	app.context().request(&"continue")
	assert_true(await _wait_until(func() -> bool: return Session.game != null and app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()))
	assert_eq(Session.game.digest(), str(header1["digest"]), "the older save was loaded")


func test_a_load_that_fails_with_no_game_running_shows_the_main_menu() -> void:
	var app := await _game_app()
	app.context().request(&"main_menu")
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is MainMenu, 60))
	app.context().request(&"load", {"slot": "7"})
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is MainMenu, 120))
	assert_null(Session.game)


func test_the_lock_is_written_when_a_game_starts_and_cleared_on_the_main_menu() -> void:
	var app := await _game_app()
	assert_true(FileAccess.file_exists(RunLock.path), "written at game start")
	app.context().request(&"main_menu")
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is MainMenu, 60))
	assert_false(FileAccess.file_exists(RunLock.path), "cleared on the main menu")


func test_the_pause_menu_greys_save_while_the_season_runs() -> void:
	var app := await _game_app()
	app.requests().flow.request_end(false)
	assert_true(app.context().season_running())
	var pause := ScreenIds.make(&"pause_menu") as PauseMenu
	app.stack().push(pause)
	assert_true(pause.save_button().disabled, "Save is greyed while the season runs")
	await _wait_until(func() -> bool: return app.stack().top() is SeasonReport)
	assert_false(app.context().season_running())


func test_esc_releases_the_console_before_anything_else() -> void:
	var app := await _game_app()
	app.settings().set_value("dev/developer_tools", true)
	assert_true(app.hud().debug_overlay().focus_console())
	await get_tree().process_frame
	assert_true(app.hud().debug_overlay().console().has_line_focus())
	app.app_input().back_requested.emit()
	assert_false(app.hud().debug_overlay().console().has_line_focus(), "Esc lets go of the console first")
	assert_eq(app.stack().count(), 0, "no pause menu was opened")


func test_ten_more_seasons_after_a_load_give_the_digest_of_ten_seasons_without_saving() -> void:
	var app := await _game_app()
	var found := _buildable()
	Session.act("build", {"hex": found["hex"], "family": found["family"]})
	assert_eq(Session.save_game("1", null, {}), "")
	var start_digest := Session.game.digest()
	for _i: int in 10:
		assert_true(bool(Session.end_season()["ok"]))
	var straight := Session.game.digest()
	assert_eq(Session.load_game("1"), "")
	assert_eq(Session.game.digest(), start_digest, "the load gives the saved digest")
	for _i: int in 10:
		assert_true(bool(Session.end_season()["ok"]))
	assert_eq(Session.game.digest(), straight, "ten seasons from the loaded game equal ten without saving")


func test_the_sandbox_plays_seasons_too() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = PackedStringArray(["--sandbox", "--seed=1480"])
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("graphics/season_change", "instant")
	app.set_settings_override(s)
	vp.add_child(app)
	await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting())
	assert_false(Session.game.has_countries())
	assert_true(app.requests().flow.request_end(false))
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is SeasonReport))
	assert_eq(Session.game.turn, 2)


func test_a_failed_load_from_a_running_game_keeps_it() -> void:
	var app := await _game_app()
	assert_eq(Session.save_game("1", null, {}), "")
	var path := Session.save_dir.path_join("1.sav")
	var bytes := FileAccess.get_file_as_bytes(path)
	bytes[bytes.size() - 3] = (bytes[bytes.size() - 3] + 1) % 256
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	var game := Session.game
	var digest := game.digest()
	app.context().request(&"load", {"slot": "1"})
	assert_true(await _wait_until(func() -> bool: return not app.is_starting() and not app.stack().has_screen(&"loading"), 120))
	assert_eq(Session.game, game, "the running game was not replaced")
	assert_eq(Session.game.digest(), digest)
	assert_not_null(app.map_scene(), "its map is still there")
	assert_false(app.stack().top() is MainMenu)


func test_the_lock_of_another_live_instance_is_not_deleted() -> void:
	var app := await _game_app()
	var old_check := RunLock.is_running
	RunLock.is_running = func(_pid: int) -> bool: return true
	var f := FileAccess.open(RunLock.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"started_unix": 5, "map_id": "north_italy", "pid": OS.get_process_id() + 1}))
	f.close()
	app.requests().clear_lock()
	assert_true(FileAccess.file_exists(RunLock.path), "a foreign live lock stays")
	app.context().request(&"main_menu")
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is MainMenu, 60))
	assert_true(FileAccess.file_exists(RunLock.path), "the main menu leaves it too")
	RunLock.write("north_italy", 1)
	app.requests().clear_lock()
	assert_false(FileAccess.file_exists(RunLock.path), "this process's own lock goes")
	RunLock.is_running = old_check


func test_a_bad_ui_block_does_not_break_a_load() -> void:
	var app := await _game_app()
	assert_eq(Session.save_game("1", null, {"bookmarks": 5, "camera": "x", "map_mode": "y"}), "")
	app.context().request(&"load", {"slot": "1"})
	assert_true(await _wait_until(func() -> bool: return Session.current_slot == "1" and not app.is_starting() and app.stack().count() == 0, 900))
	assert_eq(app.requests().bookmarks.get_at(1), {}, "no bookmark from a bad block")
	assert_not_null(app.map_scene())
	assert_eq(Session.save_game("2", null, {"bookmarks": {"3": "no", "x": {"centre": 1}}, "camera": {"centre": [1], "zoom": "a"}}), "")
	app.context().request(&"load", {"slot": "2"})
	assert_true(await _wait_until(func() -> bool: return Session.current_slot == "2" and not app.is_starting() and app.stack().count() == 0, 900))
	assert_eq(app.requests().bookmarks.get_at(3), {})


func test_an_autosave_that_came_due_inside_a_run_is_made() -> void:
	var app := await _game_app()
	app.settings().set_value("game/autosave", "yearly")
	app.context().request(&"end_seasons", {"count": 2})
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is SeasonReport))
	assert_eq(Session.game.turn, 3)
	app.stack().back()
	await get_tree().process_frame
	assert_eq(SaveFile.read_header("auto1", Session.save_dir)["state"], &"empty", "no Spring was reached yet")
	await _wait_until(func() -> bool: return Time.get_ticks_msec() > app.requests().flow.guard_until, 600)
	app.context().request(&"end_seasons", {"count": 3})  # turns 3, 4, 5 end: Spring 1481 (turn 5) begins on the way
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is SeasonReport))
	assert_eq(Session.game.turn, 6)
	app.stack().back()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(SaveFile.read_header("auto1", Session.save_dir)["state"], &"ok", "the Spring passed on the way is autosaved")


func test_the_pick_and_the_search_start_under_the_real_bottom_of_the_top_bar() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = PackedStringArray(["--new-game", "--seed=1480"])
	var s := Settings.new("macOS", true)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	app.set_settings_override(s)
	vp.add_child(app)
	await _wait_until(func() -> bool: return app.stack().top() is CountryPick)
	await get_tree().process_frame
	await get_tree().process_frame
	var bottom := Hud.screen_rect(app.hud().top_bar()).end.y
	assert_gt(bottom, float(Tokens.BAR_H), "the bar is taller than BAR_H with the medallion")
	var pick := app.stack().top() as CountryPick
	assert_gte((pick.get("_left") as Control).global_position.y, bottom, "the list is under the bar")
	assert_gte((pick.get("_top") as Control).global_position.y, bottom, "the banner is under the bar")
	var find := ScreenIds.make(&"find_place") as FindPlace
	app.stack().push(find)
	await get_tree().process_frame
	assert_gte((find.get("_card") as Control).global_position.y, bottom, "the search card is under the bar")
	# The bar changes height: the screens follow.
	app.context().top_bar_bottom_func = func() -> float: return 120.0
	app.context().top_inset_changed.emit()
	assert_gte((find.get("_card") as Control).offset_top, 120.0)
