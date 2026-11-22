## The M4.5 App flow (docs/architecture/m4-5-build-spec.md 4.11, 6.9 and 9; m4-5-build-plan.md section 4): the owner's setup
## played through the App (Genoa on seed 1480: timber on (10, 13), seven seasons to Winter 1481, U and Enter on Genoa, five
## seasons to Spring 1483, with calm weather so the numbers are the spec's), then the five questions, each answered from the bare
## map in at most four inputs (every key, click and chart click is counted), then key 4, the legend, the console and a save.
## The App runs headless in a SubViewport on a temporary save folder.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const GENOA := Vector2i(8, 13)
const WOODS := Vector2i(10, 13)
const MOST_INPUTS := 4

var _prev_game: Game = null
var _old_save_dir: String = ""
var _old_lock_path: String = ""
var _inputs: int = 0


func before_each() -> void:
	Session.ai_enabled = false  # M3 to M7 pin a passive world (M8 D47)
	Bindings.reset_defaults()
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_flow_m45_saves"
	RunLock.path = "user://test_flow_m45_running.lock"
	_inputs = 0


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


# ----- helpers: the inputs are counted ---------------------------------------------------------------------------------------


func _wait_frames(frames: int = 3) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame


func _wait_until(done: Callable, limit: int = 3000) -> bool:
	var frames := 0
	while not bool(done.call()) and frames < limit:
		await get_tree().process_frame
		frames += 1
	return bool(done.call())


## A key of an action (its first event as the Bindings have it, Ctrl or Cmd included), pressed and released. One input.
func _press(vp: SubViewport, action: StringName) -> void:
	_inputs += 1
	var base := Bindings.events_for(action)[0] as InputEventKey
	for pressed: bool in [true, false]:
		var ev := base.duplicate() as InputEventKey
		ev.pressed = pressed
		vp.push_input(ev)


## A bare key that is not counted: the setup's Space and Enter, Esc to clear the screen.
func _key(vp: SubViewport, keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		vp.push_input(ev)


## A click on a button. One input.
func _click(button: BaseButton) -> void:
	_inputs += 1
	button.pressed.emit()


## The tab button of a page's strip, pressed. One input.
func _click_tab(page: StudyPage, tab: StringName) -> void:
	_inputs += 1
	var strip := page.get_node("TabStrip") as Segmented
	strip.button_for(tab).button_pressed = true


func _scenario_app(args: Array = ["--new-game", "--country=GEN", "--seed=1480"]) -> Dictionary:
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
	app.set_settings_override(s)
	vp.add_child(app)
	return {"vp": vp, "app": app}


## Genoa on seed 1480, no pick, the map ready, calm weather (a save carries the weather only from N5 on).
func _genoa_app() -> Dictionary:
	var env := await _scenario_app()
	var app := env["app"] as App
	app.settings().set_value("game/autosave", "off")
	app.settings().set_value("graphics/season_change", "instant")
	app.settings().set_value("game/season_report", "full")
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()), "the game is up")
	await _wait_frames(3)
	Session.game.defs = EconomyFixture.defs()
	return env


func _guard_over(app: App) -> bool:
	return Time.get_ticks_msec() > app.requests().flow.guard_until


## One season by the keys: Space, the report, Space.
func _play_season(vp: SubViewport, app: App) -> void:
	await _wait_until(func() -> bool: return _guard_over(app), 600)
	_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is SeasonReport), "the report opens")
	_key(vp, KEY_SPACE)
	assert_true(await _wait_until(func() -> bool: return app.stack().count() == 0), "the report closes")


## The plan's setup (section 4): timber on (10, 13); seven seasons; U and Enter on Genoa; five seasons: Spring 1483.
func _play_setup(vp: SubViewport, app: App) -> void:
	app.map_scene().select_hex(WOODS)
	await _wait_frames(3)
	var timber := AppFlowHelpers.row_button(app, "Build woodland")
	assert_not_null(timber, "the woods by the sea: a timber row")
	timber.pressed.emit()
	await _wait_frames(3)
	assert_eq(Session.game.state.works.size(), 1, "the timber works began")
	for _n: int in 7:
		await _play_season(vp, app)
	assert_eq(Session.game.date_text(), "Winter 1481", "seven seasons: Winter 1481")
	app.map_scene().select_hex(GENOA)
	await _wait_frames(3)
	_key(vp, KEY_U)
	await _wait_frames(3)
	assert_true(app.stack().top() is WorksPreview, "U opens the card of the walled town's upgrade (it is expensive)")
	_key(vp, KEY_ENTER)
	await _wait_frames(3)
	assert_true(AppFlowHelpers.has_toast(app, "1,000 ducats"), str(AppFlowHelpers.toasts(app)))
	for _n: int in 5:
		await _play_season(vp, app)
	assert_eq(Session.game.date_text(), "Spring 1483")
	assert_eq(app.stack().count(), 0, "the bare map")
	app.map_scene().select_hex(MapScene.NO_HEX)
	await _wait_frames(2)


func _study(app: App) -> Study:
	return app.stack().top() as Study


## The words on a study's page: every label and button, and each table's row names.
func _words(node: Node) -> String:
	var parts := AppFlowHelpers.labels_under(node)
	for table: Node in node.find_children("*", "StudyTable", true, false):
		for id: Variant in (table as StudyTable).sorted_ids():
			parts.append((table as StudyTable).row_name(int(id)))
	return " | ".join(parts)


# ----- the setup ----------------------------------------------------------------------------------------------------------


func test_the_setup_played_through_the_app_is_the_calm_fixture_game() -> void:
	var env := await _genoa_app()
	await _play_setup(env["vp"] as SubViewport, env["app"] as App)
	assert_eq(Session.game.turn, 13)
	assert_eq(Session.game.digest(), InsightsFixture.genoa_1483().digest(), "the keys played what the fixture plays")


# ----- the five questions ---------------------------------------------------------------------------------------------------


func test_the_five_questions_are_each_answered_in_at_most_four_inputs() -> void:
	var env := await _genoa_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	await _play_setup(vp, app)
	var counts: Array[int] = []
	counts.append(await _question_1(vp, app))
	counts.append(await _question_2(vp, app))
	counts.append(await _question_3(vp, app))
	counts.append(await _question_4(vp, app))
	counts.append(await _question_5(vp, app))
	print("m4.5 five questions, inputs: ", counts)
	for q: int in counts.size():
		assert_lte(counts[q], MOST_INPUTS, "question %d: %d inputs" % [q + 1, counts[q]])


## Closes whatever is open and starts counting from the bare map.
func _bare_map(vp: SubViewport, app: App) -> void:
	if app.stack().count() > 0:
		_key(vp, KEY_ESCAPE)
		await _wait_frames(3)
	if app.hud().action_log().is_open():
		app.hud().action_log().close()
	assert_eq(app.stack().count(), 0, "nothing open")
	_inputs = 0


## 1. Which of your districts earns the most? L, Ctrl+]: the first row is Genoa; Show on the map: Yields, Genoa the darkest.
func _question_1(vp: SubViewport, app: App) -> int:
	await _bare_map(vp, app)
	_press(vp, &"game_ledger")
	await _wait_frames(3)
	var study := _study(app)
	assert_not_null(study, "L opens the study")
	if study == null:
		return 99
	assert_eq(study.current_page_id(), &"economy")
	assert_eq(study.current_page().current_tab(), &"this_season", "L opens Economy on This season")
	_press(vp, &"study_tab_next")
	await _wait_frames(3)
	assert_eq(study.current_page().current_tab(), &"districts", "Ctrl+] is Districts")
	var tab := study.current_page().get_node("districts") as EconomyDistrictsTab
	var first := tab.table().selected_row()
	assert_eq(first["hex"], GENOA, "the first row is Genoa")
	assert_true(tab.table().row_name(int(first["id"])).contains("Genoa"), tab.table().row_name(int(first["id"])))
	_click(tab.show_button())
	await _wait_frames(3)
	assert_eq(app.stack().count(), 0, "Show on the map closes the study")
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.YIELDS), "in Yields")
	assert_true(app.hud().mode_legend().visible, "the legend shows")
	var bytes := app.map_scene().overlay().yields_bytes()
	var genoa := int(bytes[Session.game.map.index_of(GENOA)])
	assert_gt(genoa, 2, "Genoa earns")
	assert_eq(genoa, int(Array(bytes).max()), "Genoa is the darkest green")
	return _inputs


## 2. Why did the treasury fall in Winter 1481? L, History, Winter 1481's column: "Your spending", "Begun: walled town to city".
func _question_2(vp: SubViewport, app: App) -> int:
	await _bare_map(vp, app)
	_press(vp, &"game_ledger")
	await _wait_frames(3)
	var study := _study(app)
	if study == null:
		return 99
	_click_tab(study.current_page(), &"history")
	await _wait_frames(3)
	var tab := study.current_page().get_node("history") as EconomyHistoryTab
	var winter := Calendar.FIRST_TURN + 7
	var seasons := StudyEconomy.history(Session.game, &"GEN", 12)["seasons"] as Array
	var at := -1
	for i: int in seasons.size():
		if int((seasons[i] as Dictionary)["turn"]) == winter:
			at = i
	assert_gte(at, 0, "Winter 1481 is on the chart")
	_inputs += 1  # the click on its column
	tab.chart().point_activated.emit(at)
	await _wait_frames(2)
	var ledger := " | ".join(AppFlowHelpers.labels_under(tab.ledger()))
	assert_true(ledger.contains("Winter 1481"), ledger)
	assert_true(ledger.contains("Your spending"), ledger)
	assert_true(ledger.contains("walled town to city"), ledger)
	assert_true(ledger.contains("Begun: "), ledger)
	return _inputs


## 3. Which good runs short? L, Goods: the first row is Salt, none left, and the note says none of your land makes it.
func _question_3(vp: SubViewport, app: App) -> int:
	await _bare_map(vp, app)
	_press(vp, &"game_ledger")
	await _wait_frames(3)
	var study := _study(app)
	if study == null:
		return 99
	_click_tab(study.current_page(), &"goods")
	await _wait_frames(3)
	var tab := study.current_page().get_node("goods") as EconomyGoodsTab
	var row := tab.table().row_name(int(tab.table().sorted_ids()[0]))
	assert_true(row.begins_with("Salt"), row)
	assert_true(row.contains("none left"), row)
	assert_eq(tab.note_label().text, "Your towns need 1 salt a season; none of your land makes it.")
	return _inputs


## 4. Where do you rank on land and income? L, ]: "You are 3rd of 3." under Land, others banded, the unknown counted.
func _question_4(vp: SubViewport, app: App) -> int:
	await _bare_map(vp, app)
	_press(vp, &"game_ledger")
	await _wait_frames(3)
	var study := _study(app)
	if study == null:
		return 99
	_press(vp, &"study_page_next")
	await _wait_frames(3)
	assert_eq(study.current_page_id(), &"military", "] is Military (M6 puts it second)")
	_press(vp, &"study_page_next")
	await _wait_frames(3)
	assert_eq(study.current_page_id(), &"people", "] ] is People (M5)")
	_press(vp, &"study_page_next")
	await _wait_frames(3)
	assert_eq(study.current_page_id(), &"rankings", "] ] ] is Rankings")
	var words := _words(study.current_page())
	assert_true(words.contains("You are 3rd of 3."), words)
	assert_true(words.contains("about 58") and words.contains("about 52"), words)
	assert_true(words.contains("10 countries unknown"), words)
	return _inputs


## 5. What happened in Spring 1481? The log's bar, its header Spring 1481: History there, "Your towns ran short of salt".
func _question_5(vp: SubViewport, app: App) -> int:
	await _bare_map(vp, app)
	var action_log := app.hud().action_log()
	_inputs += 1  # a click on the bar
	action_log._toggle.pressed.emit()
	await _wait_frames(3)
	assert_true(action_log.is_open(), "the bar opens the card")
	var header: Button = null
	for button: Button in action_log.header_buttons():
		if button.text == "Spring 1481":
			header = button
	assert_not_null(header, "the card lists Spring 1481 as a button: %s" % str(action_log.season_titles()))
	if header == null:
		return _inputs
	_click(header)
	await _wait_frames(3)
	var study := _study(app)
	assert_not_null(study, "the header opens the study")
	if study == null:
		return 99
	assert_eq(study.current_page_id(), &"history")
	var page := study.current_page() as PageHistory
	assert_eq(page.cursor_turn(), Calendar.FIRST_TURN + 4, "at Spring 1481")
	var words := page.season_head_text() + " | " + page.season_line_text() + " | " + _words(page)
	assert_true(words.contains("Spring 1481"), words)
	assert_true(words.contains("Your towns ran short of salt: 0 of 1."), words)
	return _inputs


# ----- the rest of the wiring --------------------------------------------------------------------------------------------------


func test_pages_keys_chips_the_country_button_and_the_page_actions_land_where_the_spec_says() -> void:
	var env := await _genoa_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	# I opens the last page, L Economy on This season, [ ] step the pages, Ctrl+[ ] the tabs.
	_press(vp, &"game_study")
	await _wait_frames(3)
	assert_eq(_study(app).current_page_id(), &"economy")
	_press(vp, &"study_page_next")
	await _wait_frames(2)
	assert_eq(_study(app).current_page_id(), &"military", "M6: Military is second")
	_press(vp, &"study_page_next")
	await _wait_frames(2)
	assert_eq(_study(app).current_page_id(), &"people")
	_press(vp, &"study_page_next")
	await _wait_frames(2)
	assert_eq(_study(app).current_page_id(), &"rankings")
	_press(vp, &"game_study")
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0, "I closes it")
	_press(vp, &"game_study")
	await _wait_frames(3)
	assert_eq(_study(app).current_page_id(), &"rankings", "I opens the last page")
	_press(vp, &"game_study")
	await _wait_frames(2)
	_press(vp, &"game_ledger")
	await _wait_frames(3)
	assert_eq(_study(app).current_page_id(), &"economy", "L opens Economy")
	assert_eq(_study(app).current_page().current_tab(), &"this_season")
	_press(vp, &"study_tab_next")
	_press(vp, &"study_tab_next")
	await _wait_frames(2)
	assert_eq(_study(app).current_page().current_tab(), &"goods")
	_press(vp, &"study_tab_prev")
	await _wait_frames(2)
	assert_eq(_study(app).current_page().current_tab(), &"districts")
	_press(vp, &"game_study")
	await _wait_frames(2)
	_press(vp, &"game_ledger")
	await _wait_frames(3)
	assert_eq(_study(app).current_page().current_tab(), &"this_season", "L always opens This season")
	_press(vp, &"game_study")
	await _wait_frames(2)
	# The chips and the country panel's button open Economy.
	app.hud().chips().ducats_chip().pressed.emit()
	await _wait_frames(3)
	assert_eq(_study(app).current_page_id(), &"economy", "the Ducats chip opens Economy")
	assert_eq(_study(app).current_page().current_tab(), &"this_season", "on This season")
	_press(vp, &"game_study")
	await _wait_frames(2)
	app.hud().chips().stores_chip().pressed.emit()
	await _wait_frames(3)
	assert_eq(_study(app).current_page_id(), &"economy", "the Stores chip opens Economy")
	assert_eq(_study(app).current_page().current_tab(), &"goods", "on Goods")
	_press(vp, &"game_study")
	await _wait_frames(2)
	app.hud().study_requested.emit(&"economy")
	await _wait_frames(3)
	assert_eq(_study(app).current_page_id(), &"economy", "the country panel's button opens Economy")
	# The page actions: a country pops the study and opens its panel; a mode with a hex pops it and sets the mode.
	_study(app).current_page().request([&"country", &"MLO"])
	await _wait_frames(3)
	assert_eq(app.stack().count(), 0, "a country pops the study")
	assert_true(app.hud().country_panel().visible, "and opens its panel")
	_press(vp, &"game_ledger")
	await _wait_frames(3)
	_study(app).current_page().request([&"map_mode", &"yields", GENOA])
	await _wait_frames(3)
	assert_eq(app.stack().count(), 0, "a map mode pops the study")
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.YIELDS), "and sets the mode")
	assert_true(app.hud().mode_legend().visible)
	_press(vp, &"game_ledger")
	await _wait_frames(3)
	_study(app).current_page().request([&"look_at", Vector2i(7, 12)])
	await _wait_frames(3)
	assert_eq(app.stack().count(), 0, "a look pops the study")
	assert_eq(app.map_scene().selected, Vector2i(7, 12), "and selects the place")


func test_key_4_the_legend_the_console_and_a_save_keep_yields_in_step() -> void:
	var env := await _genoa_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	var legend := app.hud().mode_legend()
	assert_false(legend.visible, "Terrain: no legend")
	_press(vp, &"view_mode_4")
	await _wait_frames(3)
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.YIELDS))
	assert_true(legend.visible)
	assert_eq(legend.mode(), int(MapModes.Mode.YIELDS))
	_press(vp, &"view_mode_1")
	await _wait_frames(3)
	assert_false(legend.visible, "1 is Terrain: the legend is gone")
	_press(vp, &"view_mode_4")
	await _wait_frames(2)
	# The console's money and goods: the Yields texture is synced (the version has not moved for money).
	var overlay := app.map_scene().overlay()
	var fresh := MapModes.yield_bytes(Session.game, &"GEN")
	var stale := PackedByteArray()
	stale.resize(fresh.size())
	overlay.update_yields(stale)  # a stale picture
	assert_ne(overlay.yields_bytes(), fresh)
	Session.game.dev_money(&"GEN", 100)
	app.context().request(&"refresh_hud")
	await _wait_frames(2)
	assert_eq(overlay.yields_bytes(), MapModes.yield_bytes(Session.game, &"GEN"), "refresh_hud syncs the Yields texture")
	# F3: the study line follows the last page built and the warm queue.
	_press(vp, &"game_study")
	await _wait_frames(3)
	var debug := app.hud().debug_overlay()
	debug.refresh_metrics()
	assert_true(debug.study_text().begins_with("study economy"), debug.study_text())
	assert_true(debug.study_text().contains(" ms · warm queue "), debug.study_text())
	_press(vp, &"game_study")
	await _wait_frames(2)
	# F5, the main menu, Continue: the map is in Yields again and the legend shows.
	_key(vp, KEY_F5)
	assert_true(await _wait_until(func() -> bool: return FileAccess.file_exists(Session.save_dir.path_join("quick.sav"))))
	await _wait_frames(2)
	app.context().request(&"main_menu")
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is MainMenu), "the main menu")
	app.context().request(&"continue")
	assert_true(await _wait_until(func() -> bool: return Session.game != null and app.map_scene() != null and app.stack().count() == 0 and not app.is_starting(), 900))
	await _wait_frames(3)
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.YIELDS), "Continue restores the mode")
	assert_true(app.hud().mode_legend().visible, "and the legend")
	app.map_scene().set_mode(int(MapModes.Mode.OWNER))
	await _wait_frames(2)
	assert_false(app.hud().mode_legend().visible, "Owner: no legend")


func test_the_warm_queue_follows_the_season_and_the_study_times_its_open() -> void:
	var env := await _genoa_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	var warm := app.requests().warm
	assert_not_null(warm, "the App has its StudyWarm")
	assert_eq(warm.get_parent(), app)
	await _play_season(vp, app)
	await _wait_until(func() -> bool: return warm.pending() == 0, 600)
	assert_eq(warm.pending(), 0, "the queue ran out, a view a frame")
	_press(vp, &"game_study")
	await _wait_frames(3)
	var study := _study(app)
	assert_not_null(study)
	if study != null:
		assert_gt(study.last_open_ms, 0.0)
	_press(vp, &"game_study")
	await _wait_frames(2)


## M4.5 (spec 6.9): in the map sandbox key 4 toasts "No countries on this map" (the Owner refusal's words), I says the sandbox has
## no treasury, and no legend shows; while picking, key 4 asks to choose a country first.
func test_m45_key_4_toasts_in_the_sandbox_and_while_picking_and_the_sandbox_has_no_study() -> void:
	var env := await _scenario_app(["--sandbox", "--seed=1480"])
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()))
	await _wait_frames(3)
	_key(vp, KEY_4)
	await _wait_frames(2)
	assert_true(AppFlowHelpers.has_toast(app, "No countries on this map"), str(AppFlowHelpers.toasts(app)))
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.TERRAIN))
	_key(vp, KEY_2)
	await _wait_frames(2)
	assert_eq(AppFlowHelpers.toasts(app).count("No countries on this map"), 2, "Owner and Yields refuse in the same words")
	assert_false(app.hud().mode_legend().visible, "no legend in the sandbox")
	_key(vp, KEY_I)
	await _wait_frames(2)
	assert_true(AppFlowHelpers.has_toast(app, "The sandbox has no treasury."))
	assert_eq(app.stack().count(), 0, "no study in the sandbox")
	# The pick: Yields is refused with its own words.
	app.context().request(&"new_game", {"scenario": "north_italy_1480", "seed": 7})
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is CountryPick))
	app.map_scene().map_input().mode_requested.emit(int(MapModes.Mode.YIELDS))
	await _wait_frames(2)
	assert_true(AppFlowHelpers.has_toast(app, "Choose your country first"), str(AppFlowHelpers.toasts(app)))
	assert_eq(app.map_scene().mode(), int(MapModes.Mode.OWNER), "the pick stays in Owner mode")


## A bug the M4.5 monkey found (seed 1488, once the new keys changed its dice): a save made during the country pick has no player;
## loading it showed the map with no pick and no way to choose, and every later key found no player. The pick comes back.
func test_loading_a_save_made_during_the_pick_asks_for_the_country_again() -> void:
	var env := await _scenario_app(["--new-game", "--seed=7"])
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is CountryPick), "the pick opens")
	_key(vp, KEY_F5)
	assert_true(await _wait_until(func() -> bool: return FileAccess.file_exists(Session.save_dir.path_join("quick.sav"))))
	await _wait_frames(2)
	app.context().request(&"load", {"slot": SaveRows.QUICK_SLOT})
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and not app.is_starting() and app.stack().top() is CountryPick, 900), "the pick is asked again")
	assert_eq(Session.player_tag(), &"")


## What the monkey's digest check found under load (turn 12 -> 14, unsaved 4 -> 1, slot auto1): two seasons ended in one step with
## an autosave between them. The autosave resets unsaved to 0 and the second season makes it 1, so "unsaved is 0 after an autosave" is
## not the whole story: the monkey counts the season_ended events of a step as the accepted actions that changed the digest.
func test_a_season_after_an_autosave_leaves_one_unsaved_action_and_a_new_digest() -> void:
	var env := await _genoa_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	app.settings().set_value("game/autosave", "yearly")
	Session.game.turn = Calendar.FIRST_TURN + 3  # Winter: the next season ends in a Spring, an autosave turn
	await _play_season(vp, app)
	assert_true(await _wait_until(func() -> bool: return Session.current_slot.begins_with("auto"), 600), "the autosave of the spring")
	assert_eq(Session.unsaved_actions, 0, "an autosave leaves nothing unsaved")
	var digest := Session.game.digest()
	await _play_season(vp, app)
	assert_ne(Session.game.digest(), digest, "the next season changes the game")
	assert_eq(Session.unsaved_actions, 1, "and it is one unsaved action, the slot still an autosave")
	assert_true(Session.current_slot.begins_with("auto"))
