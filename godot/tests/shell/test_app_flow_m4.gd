## The other M4 App tests (docs/architecture/m4-build-spec.md 6.1, 6.9, 6.12; the owner's playtest checklist 12, 16, 17 of
## m4-build-plan.md section 4): U in the three Confirm works modes (with Always a work must not begin without the card), a
## cancel with its refund, the options steering a row click and the map marks, the sandbox with no treasury, the console's
## money, goods and tax, and every way into the study. The spec's end-to-end flow is in test_app_flow.gd. The App runs
## headless in a SubViewport on a temporary save folder.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const GENOA := Vector2i(8, 13)
const VINEYARD := Vector2i(7, 12)
const WOODS := Vector2i(10, 13)

var _prev_game: Game = null
var _old_save_dir: String = ""
var _old_lock_path: String = ""


func before_each() -> void:
	Session.ai_enabled = false  # M3 to M7 pin a passive world (M8 D47)
	Bindings.reset_defaults()
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_flow_m4_saves"
	RunLock.path = "user://test_flow_m4_running.lock"


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


func _wait_frames(frames: int = 2) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame


func _wait_until(done: Callable, limit: int = 3000) -> bool:
	var frames := 0
	while not bool(done.call()) and frames < limit:
		await get_tree().process_frame
		frames += 1
	return bool(done.call())


func _send_key(vp: SubViewport, keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		vp.push_input(ev)


## An App in a SubViewport; the command line arguments boot a game.
func _scenario_app(cli_args: PackedStringArray) -> Dictionary:
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


## A Genoa game on seed 1480, no pick, the map ready and the top bar fitted.
func _genoa_app() -> Dictionary:
	var env := await _scenario_app(PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"]))
	var app := env["app"] as App
	app.settings().set_value("game/autosave", "off")
	app.settings().set_value("graphics/season_change", "instant")
	app.settings().set_value("game/season_report", "full")
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()), "the game is up")
	await _wait_frames(3)  # the HUD lays out: the top bar is fitted to the window
	return env


## U in the three Confirm works modes (the reviewer's finding: with Always a work must not begin without the card).
func _u_on(app: App, vp: SubViewport, hex: Vector2i) -> void:
	app.map_scene().select_hex(hex)
	await _wait_frames(2)
	_send_key(vp, KEY_U)
	await _wait_frames(3)


func test_u_with_confirm_works_always_opens_the_card_and_begins_nothing() -> void:
	var env := await _genoa_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	app.settings().set_value("game/confirm_works", "always")
	await _u_on(app, vp, VINEYARD)
	var card := app.stack().top() as WorksPreview
	assert_not_null(card, "Always: the card opens")
	assert_eq(str(card.shown_option()["action"]), "upgrade")
	assert_eq(Session.game.state.works.size(), 0, "no work begun without the confirmation")
	assert_eq(Session.unsaved_actions, 0, "no action was done")
	# Enter on the card (Begin is focused) begins it.
	_send_key(vp, KEY_ENTER)
	await _wait_frames(3)
	assert_eq(Session.game.state.works.size(), 1, "Begin the work")
	assert_eq(app.stack().count(), 0, "the card closed")
	assert_true(AppFlowHelpers.has_toast(app, "Work begun"), str(AppFlowHelpers.toasts(app)))
	# On wild land U opens the card of the first allowed build.
	await _u_on(app, vp, WOODS)
	card = app.stack().top() as WorksPreview
	assert_not_null(card, "wild land: the first build opens the card")
	assert_eq(str(card.shown_option()["action"]), "build")
	assert_eq(Session.game.state.works.size(), 1)


func test_u_with_confirm_works_off_begins_the_work_at_once() -> void:
	var env := await _genoa_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	app.settings().set_value("game/confirm_works", "off")
	await _u_on(app, vp, VINEYARD)
	assert_eq(app.stack().count(), 0, "Off: no card")
	assert_eq(Session.game.state.works.size(), 1, "the upgrade began")
	assert_true(AppFlowHelpers.has_toast(app, "Work begun"), str(AppFlowHelpers.toasts(app)))
	# An upgrade the treasury cannot pay is refused with its words, not opened.
	await _u_on(app, vp, GENOA)
	assert_eq(app.stack().count(), 0)
	assert_eq(Session.game.state.works.size(), 1)
	assert_true(AppFlowHelpers.has_toast(app, "Not enough ducats"), str(AppFlowHelpers.toasts(app)))


func test_u_with_confirm_works_expensive_opens_the_card_only_for_an_expensive_work() -> void:
	var env := await _genoa_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	assert_eq(str(app.settings().get_value("game/confirm_works")), "expensive", "the default")
	var row := WorksFlow.upgrade_row(Session.game, &"GEN", WOODS)
	assert_false(row.is_empty(), "the first allowed build of the woods")
	assert_false(bool(row["expensive"]), "40 ducats of 610 is not over a quarter")
	await _u_on(app, vp, WOODS)
	assert_eq(app.stack().count(), 0, "a cheap work begins at once")
	assert_eq(Session.game.state.works.size(), 1)
	await _u_on(app, vp, GENOA)
	assert_true(app.stack().top() is WorksPreview, "Genoa's city is expensive: the card")
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	# Less money makes the same row expensive.
	assert_true(Session.act("cancel_work", {"hex": WOODS})["ok"])
	assert_true(Session.dev_money(&"GEN", -550))
	app.hud().refresh_economy()
	row = WorksFlow.upgrade_row(Session.game, &"GEN", WOODS)
	assert_true(bool(row["expensive"]), "the same work with 60 ducats is over a quarter")
	await _u_on(app, vp, WOODS)
	assert_true(app.stack().top() is WorksPreview, "now it is expensive: the card")
	assert_eq(Session.game.state.works.size(), 0)


func test_u_with_no_selection_toasts_nothing_to_build() -> void:
	var env := await _genoa_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	await _u_on(app, vp, MapScene.NO_HEX)
	assert_true(AppFlowHelpers.has_toast(app, WorksFlow.NOTHING_TO_BUILD), "no selection")


func test_u_on_the_sea_toasts_nothing_to_build() -> void:
	var env := await _genoa_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	var game := Session.game
	var sea := Vector2i(-1, -1)
	for i: int in game.map.hex_count():
		if game.map.land[i] == 0:
			sea = game.map.hex_of(i)
			break
	assert_ne(sea, Vector2i(-1, -1))
	await _u_on(app, vp, sea)
	assert_eq(app.stack().count(), 0)
	assert_eq(game.state.works.size(), 0)
	assert_true(AppFlowHelpers.has_toast(app, WorksFlow.NOTHING_TO_BUILD), "the sea")


func test_a_work_cancelled_in_its_first_season_names_the_refund_and_a_later_one_does_not() -> void:
	var env := await _genoa_app()
	var app := env["app"] as App
	var vp := env["vp"] as SubViewport
	await _u_on(app, vp, WOODS)
	assert_eq(Session.game.state.works.size(), 1, "a work began")
	var cancel := AppFlowHelpers.row_button(app, "Cancel the work")
	assert_not_null(cancel, "Cancel the work")
	var before := Countries.by_tag(Session.game, &"GEN").treasury
	cancel.pressed.emit()
	await _wait_frames(2)
	assert_eq(Session.game.state.works.size(), 0)
	assert_true(AppFlowHelpers.has_toast(app, "+40 ducats back"), str(AppFlowHelpers.toasts(app)))
	assert_eq(Countries.by_tag(Session.game, &"GEN").treasury, before + 40, "the ducats came back")
	# A work cancelled in a later season gives nothing back and says nothing of it.
	await _u_on(app, vp, WOODS)
	assert_eq(Session.game.state.works.size(), 1)
	assert_true(bool(Session.end_season()["ok"]))
	await _wait_frames(3)
	app.map_scene().select_hex(WOODS)
	await _wait_frames(3)
	var late := Countries.by_tag(Session.game, &"GEN").treasury
	AppFlowHelpers.row_button(app, "Cancel the work").pressed.emit()
	await _wait_frames(2)
	assert_eq(Session.game.state.works.size(), 0)
	assert_eq(Countries.by_tag(Session.game, &"GEN").treasury, late, "nothing back in a later season")
	assert_true(AppFlowHelpers.toasts(app).any(func(m: String) -> bool: return m.begins_with("Work cancelled: ") and not m.contains("back")), str(AppFlowHelpers.toasts(app)))


## Checklist 12: the options of the Game page steer a row click, and the map marks follow Preview on the map.
func test_the_works_options_steer_a_row_click_and_the_map_marks() -> void:
	var env := await _genoa_app()
	var app := env["app"] as App
	var vp := env["vp"] as SubViewport
	app.map_scene().select_hex(WOODS)
	await _wait_frames(3)
	app.settings().set_value("game/confirm_works", "always")
	AppFlowHelpers.row_button(app, "Build olive").pressed.emit()
	await _wait_frames(3)
	assert_true(app.stack().top() is WorksPreview, "Always: a row click opens the card")
	assert_eq(Session.game.state.works.size(), 0)
	_send_key(vp, KEY_ESCAPE)
	await _wait_frames(2)
	app.settings().set_value("game/confirm_works", "off")
	AppFlowHelpers.row_button(app, "Build olive").pressed.emit()
	await _wait_frames(3)
	assert_eq(app.stack().count(), 0, "Off: no card")
	assert_eq(Session.game.state.works.size(), 1, "a click begins the work")
	assert_true(Session.act("cancel_work", {"hex": WOODS})["ok"])
	await _wait_frames(3)
	app.settings().set_value("game/preview_on_map", false)
	var marks := app.map_scene().preview_marks()
	AppFlowHelpers.row_button(app, "Build woodland").mouse_entered.emit()
	await _wait_frames(2)
	assert_true(app.stack().top() is WorksPreview, "the card still opens")
	assert_false(marks.shown(), "Preview on the map off: no ghost and no marks")
	app.settings().set_value("game/preview_on_map", true)
	AppFlowHelpers.row_button(app, "Build woodland").mouse_entered.emit()
	await _wait_frames(2)
	assert_true(marks.shown(), "on again: the ghost is there")


## Checklist 16: the map sandbox has no chips, a card with no money, and I says so.
func test_the_sandbox_has_no_chips_and_i_toasts_that_it_has_no_treasury() -> void:
	var env := await _scenario_app(PackedStringArray(["--sandbox", "--seed=1480"]))
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	assert_true(await _wait_until(func() -> bool: return app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()))
	await _wait_frames(3)
	assert_false(app.hud().chips().visible, "no chips in the sandbox")
	assert_false(app.hud().top_bar().study_button().visible, "no study button")
	_send_key(vp, KEY_I)
	await _wait_frames(2)
	assert_eq(app.stack().count(), 0, "no study")
	assert_true(AppFlowHelpers.has_toast(app, WorksFlow.NO_TREASURY), str(AppFlowHelpers.toasts(app)))
	var game := Session.game
	var wild := Vector2i(-1, -1)
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if game.map.land[i] == 1 and Improve.piece_at(game, hex).is_empty() and not ImprovePreview.options_of(game, &"", hex).is_empty():
			wild = hex
			break
	assert_ne(wild, Vector2i(-1, -1))
	app.map_scene().select_hex(wild)
	await _wait_frames(3)
	var rows := app.hud().hex_panel().action_buttons()
	assert_gt(rows.size(), 0, "rows in the sandbox")
	rows[0].mouse_entered.emit()
	await _wait_frames(2)
	var card := app.stack().top() as WorksPreview
	assert_not_null(card, "the card opens")
	assert_eq(int((card.preview()["cost"] as Dictionary)["ducats"]), 0, "no money in the sandbox")
	assert_gt((card.preview()["by_season"] as Array).size(), 0, "the goods by season")


## Checklist 17: money, goods and tax from F2 show on the chips and in the next report.
func test_the_console_money_goods_and_tax_show_on_the_chips_and_in_the_next_report() -> void:
	var env := await _genoa_app()
	var app := env["app"] as App
	var chips := app.hud().chips()
	var ctx := app.context()
	assert_eq(DevCommands.run("money 500", ctx), "Done: +500 ducats to GEN.")
	await _wait_frames(2)
	assert_eq(AppFlowHelpers.ducats_shown(app), "1,110", "the chip follows the console")
	var stone_before := Countries.by_tag(Session.game, &"GEN").stock[Session.game.defs.good_id(&"stone")]
	assert_eq(DevCommands.run("goods stone 40", ctx), "Done: +40 stone to GEN.")
	await _wait_frames(2)
	assert_eq(Countries.by_tag(Session.game, &"GEN").stock[Session.game.defs.good_id(&"stone")], stone_before + 40)
	assert_true(" | ".join(AppFlowHelpers.card_lines(chips.stores_card())).contains(Words.number(stone_before + 40)), "the Stores card shows it")
	assert_eq(DevCommands.run("tax low", ctx), "Done: tax low.")
	await _wait_frames(2)
	assert_eq(Countries.by_tag(Session.game, &"GEN").tax, 0)
	assert_true(AppFlowHelpers.has_toast(app, "Taxes set to Low"), str(AppFlowHelpers.toasts(app)))
	assert_true(bool(Session.end_season()["ok"]))
	var found := false
	for section: Dictionary in SeasonSummary.of(Session.game, &"GEN", 1)["sections"]:
		if section["id"] == &"treasury":
			for line: Dictionary in section["lines"]:
				if int(line.get("amount", 0)) == 500 and not bool(line.get("sub", false)):
					found = true
	assert_true(found, "the next report carries the 500 ducats")


## A chip, the study button, the country panel, L and a task flag line each open the study on Economy.
func test_every_way_to_the_study_opens_the_economy_page() -> void:
	var env := await _genoa_app()
	var vp := env["vp"] as SubViewport
	var app := env["app"] as App
	var ways: Array[Callable] = [
		func() -> void: app.hud().chips().ducats_chip().pressed.emit(),
		func() -> void: app.hud().chips().stores_chip().pressed.emit(),
		func() -> void: app.hud().top_bar().study_button().pressed.emit(),
		func() -> void: app.hud().country_panel().study_requested.emit(),
		func() -> void: _send_key(vp, KEY_L),
		func() -> void: _send_key(vp, KEY_I),
		func() -> void: app.context().request(&"study", {"page": &"economy"}),
	]
	for way: Callable in ways:
		way.call()
		await _wait_frames(3)
		var study := app.stack().top() as Study
		assert_not_null(study, "the study opens")
		if study != null:
			assert_eq(study.current_page_id(), &"economy")
			assert_true(app.hides_world(), "the world is hidden while it is up")
		_send_key(vp, KEY_ESCAPE)
		await _wait_frames(2)
		assert_eq(app.stack().count(), 0, "Esc closes it")
		assert_false(app.hides_world())
	# A task flag line with the study action.
	var flag := app.hud().task_flag()
	flag._lines = [{"kind": &"treasury_empty", "severity": 2, "hint": "", "hex": WorksView.NO_HEX, "text": "The treasury is empty.",
		"action": Reminders.STUDY_ACTION.duplicate(), "action_label": "Open the study"}]
	assert_true(flag.choose_row(0))
	await _wait_frames(3)
	assert_true(app.stack().top() is Study, "the flag's study action opens the study")


## Checklist 18: on to Winter 1489 with no error; the study's chart holds twelve seasons.
func test_playing_to_winter_1489_gives_no_error_and_the_study_chart_fills_twelve_seasons() -> void:
	var env := await _genoa_app()
	var app := env["app"] as App
	app.context().request(&"end_seasons", {"count": 39})
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is SeasonReport, 6000), "one report after the run")
	assert_eq(Session.game.turn, 40, "Winter 1489")
	assert_eq(Session.game.date_text(), "Winter 1489")
	app.stack().back()
	await _wait_frames(2)
	app.requests().works.open_study(&"economy")
	await _wait_frames(3)
	var study := app.stack().top() as Study
	assert_not_null(study)
	var chart := study.find_child("Chart", true, false) as InkChart
	assert_not_null(chart)
	var chart_data := (StudyEconomy.this_season(Session.game, &"GEN")["chart"] as Dictionary)
	assert_eq((chart_data["labels"] as Array).size(), 12, "twelve seasons")
