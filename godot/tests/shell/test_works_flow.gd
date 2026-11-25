## GUT tests for the App's works flow (docs/architecture/m4-build-spec.md 6.9 and 6.12): the card's life on the stack and with
## the map marks, Begin and its refusal, the tax toast, and the study's life across a game. The App runs headless in a
## SubViewport on a temporary save folder.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const WOODS := Vector2i(10, 13)
const GENOA := Vector2i(8, 13)

var _old_save_dir: String = ""
var _old_lock_path: String = ""
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_works_flow_saves"
	RunLock.path = "user://test_works_flow_running.lock"


func after_each() -> void:
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


func _frames(count: int = 3) -> void:
	for _i: int in count:
		await get_tree().process_frame


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
	await _frames(3)
	return app


func _row(app: App, prefix: String) -> Button:
	return AppFlowHelpers.row_button(app, prefix)


func _has_toast(app: App, part: String) -> bool:
	return app.hud().toast_host().messages().any(func(m: String) -> bool: return m.contains(part))


func test_the_card_closes_with_a_new_selection_and_takes_its_marks_off_the_map() -> void:
	var app := await _game_app()
	app.map_scene().select_hex(WOODS)
	await _frames()
	AppFlowHelpers.hover_card(app, WOODS, _row(app, "Build woodland"))
	await _frames(2)
	assert_true(app.stack().top() is WorksPreview)
	assert_true(app.map_scene().preview_marks().shown())
	app.map_scene().select_hex(GENOA)
	await _frames(2)
	assert_eq(app.stack().count(), 0, "a new selection closes the card")
	assert_false(app.map_scene().preview_marks().shown(), "and its marks")


func test_a_row_that_loses_its_panel_while_the_card_is_up_is_harmless() -> void:
	var app := await _game_app()
	app.map_scene().select_hex(WOODS)
	await _frames()
	AppFlowHelpers.hover_card(app, WOODS, _row(app, "Build woodland"))
	await _frames(2)
	app.stack().clear()  # the card is freed with the stack
	await _frames(2)
	app.requests().works.on_row_unhovered()  # the panel's row lets go after the card is gone
	app.requests().works.close_card()
	assert_eq(app.stack().count(), 0)
	AppFlowHelpers.hover_card(app, WOODS, _row(app, "Build woodland"))  # and a new hover makes a new card
	await _frames(2)
	assert_true(app.stack().top() is WorksPreview)


func test_the_card_is_not_pushed_over_another_screen() -> void:
	var app := await _game_app()
	app.map_scene().select_hex(WOODS)
	await _frames()
	app.context().request(&"pause")
	await _frames(2)
	assert_true(app.stack().top() is PauseMenu)
	app.requests().works.show_card(WOODS, {"action": "build", "family": ImproveRules.TIMBER}, true)
	assert_true(app.stack().top() is PauseMenu, "no card over a menu")
	assert_eq(app.stack().count(), 1)


func test_a_screen_pushed_over_the_card_closes_it_and_its_marks() -> void:
	var app := await _game_app()
	app.map_scene().select_hex(WOODS)
	await _frames()
	AppFlowHelpers.hover_card(app, WOODS, _row(app, "Build woodland"))
	await _frames(2)
	assert_true(app.stack().top() is WorksPreview)
	assert_true(app.map_scene().preview_marks().shown())
	app.context().request(&"pause")
	await _frames(3)
	assert_true(app.stack().top() is PauseMenu)
	assert_false(app.stack().has_screen(&"works_preview"), "the card closed under the menu")
	assert_false(app.map_scene().preview_marks().shown(), "and its marks")
	app.stack().back()
	await _frames(3)
	assert_eq(app.stack().count(), 0, "the card does not come back after Esc")
	assert_false(app.map_scene().preview_marks().shown())


func test_u_on_a_hex_with_a_work_under_way_says_so() -> void:
	var app := await _game_app()
	var cheap := {"action": "build", "family": ImproveRules.TIMBER}
	app.context().request(&"begin_work", {"hex": WOODS, "option": cheap})
	await _frames(2)
	assert_eq(Session.game.state.works.size(), 1)
	app.map_scene().select_hex(WOODS)
	await _frames(2)
	app.requests().works.on_upgrade_requested()
	assert_true(_has_toast(app, "A work is under way here"), str(app.hud().toast_host().messages()))
	assert_false(_has_toast(app, WorksFlow.NOTHING_TO_BUILD))


func test_begin_work_acts_pops_the_card_and_a_refusal_is_a_toast() -> void:
	var app := await _game_app()
	var cheap := {"action": "build", "family": ImproveRules.TIMBER}
	app.requests().works.show_card(WOODS, cheap, true)
	await _frames(2)
	assert_true(app.stack().top() is WorksPreview)
	app.context().request(&"begin_work", {"hex": WOODS, "option": cheap})
	await _frames(2)
	assert_eq(app.stack().count(), 0, "the card is popped")
	assert_eq(Session.game.state.works.size(), 1)
	assert_true(_has_toast(app, "Work begun: "))
	# The same hex again: refused by the rules, with their words, and nothing more begins.
	app.context().request(&"begin_work", {"hex": WOODS, "option": cheap})
	await _frames(2)
	assert_eq(Session.game.state.works.size(), 1)
	assert_true(app.hud().toast_host().messages().size() >= 2, "a second toast: the refusal")
	# An upgrade the treasury cannot pay.
	var city := WorksFlow.upgrade_row(Session.game, &"GEN", GENOA)
	app.context().request(&"begin_work", {"hex": GENOA, "option": {"action": city["action"], "family": city["family"]}})
	await _frames(2)
	assert_true(_has_toast(app, "Not enough ducats: 1,000 needed, 570 in the treasury."), str(app.hud().toast_host().messages()))
	assert_eq(Session.game.state.works.size(), 1)


func _work(started: int, paid: int, goods: Dictionary) -> Work:
	var w := Work.new()
	w.id = 1
	w.tag = &"GEN"
	w.hex = Vector2i(7, 12)
	w.action = Works.BUILD
	w.family = ImproveRules.TIMBER
	w.level_to = 1
	w.started_turn = started
	w.seasons = 4
	w.seasons_left = 4
	w.paid = paid
	w.paid_goods = goods
	return w


func test_a_begun_work_toast_names_its_goods_and_a_cancel_gives_them_back() -> void:
	var app := await _game_app()
	var game := Session.game
	var words := app.requests()._paid_words(game, _work(1, 60, {"timber": 10, "stone": 5}))
	assert_eq(words, "−60 ducats, −10 timber, −5 stone", "ducats, then the goods in their order")
	assert_eq(app.requests()._paid_words(game, _work(1, 0, {})), "", "a free work says nothing")
	var back := app.requests()._refund_words(game, _work(game.turn, 60, {"timber": 10}))
	assert_eq(back, "+60 ducats, +10 timber", "all of it back in the season it began")
	assert_eq(app.requests()._refund_words(game, _work(game.turn - 1, 60, {"timber": 10})), "", "nothing in a later season")


func test_the_tax_toast_names_the_gain_over_the_old_level() -> void:
	var app := await _game_app()
	assert_true(bool(Session.act("set_tax", {"level": 2})["ok"]))
	assert_true(_has_toast(app, "Taxes set to High: about ▲ +"), str(app.hud().toast_host().messages()))
	assert_true(bool(Session.act("set_tax", {"level": 1})["ok"]))
	assert_true(_has_toast(app, "Taxes set to Normal: about ▼ −"), "going back is a fall: " + str(app.hud().toast_host().messages()))
	# Another country's tax is not the player's news.
	var before := app.hud().toast_host().messages().size()
	assert_true(bool(Session.act("set_tax", {"level": 0, "tag": &"MLO"})["ok"]))
	assert_eq(app.hud().toast_host().messages().size(), before)


func test_the_study_is_one_screen_for_the_game_and_a_new_game_makes_another() -> void:
	var app := await _game_app()
	app.requests().works.open_study(&"economy")
	await _frames(2)
	var first := app.stack().top() as Study
	assert_not_null(first)
	first.back()
	assert_eq(app.stack().count(), 0, "Esc closes it")
	app.requests().works.open_study(&"")
	await _frames(2)
	assert_eq(app.stack().top(), first, "the same instance: its page and scroll are kept")
	app.context().request(&"look_at", {"hex": GENOA, "select": true})
	await _frames(2)
	assert_eq(app.stack().count(), 0, "a look_at pops the study first")
	assert_eq(app.map_scene().selected, GENOA, "and then glides and selects")
	app.context().request(&"main_menu")
	assert_true(await _wait_until(func() -> bool: return app.stack().top() is MainMenu, 60))
	assert_false(is_instance_valid(first) and first.is_inside_tree(), "the study went with its game")
