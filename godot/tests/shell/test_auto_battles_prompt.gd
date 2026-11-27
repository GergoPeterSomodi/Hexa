## The End season battle prompt (docs/architecture/moves-build-spec.md R74, D40; MV21). In a game of this build there is no
## battle to ask about (BattlesAtEnd.count is 0) and the Options row is hidden. With a stub count the prompt goes up before the
## season runs: Yes and No run it, Esc does not, and the box keeps the answer as game/battles_at_end. The prompt writes a
## setting and nothing else.
## Planted faults: a prompt with a count of 0; a prompt with the setting auto or board; a box that keeps nothing; a prompt
## that acts on the game.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")
const SETTLE_FRAMES := 5000
const KEY := AutoBattlesAsk.SETTING

var _harness: UIHarness = null
var _flow: SeasonFlow = null
var _asked: Array[AutoBattlesAsk] = []
var _answers: Array[StringName] = []
var _battles: int = 2
var _now: int = 1000
var _temp: String = ""
var _prev_game: Game = null
var _prev_unsaved: int = 0
var _prev_ai: bool = true
var _old_save_dir := ""
var _old_lock_path := ""


func before_each() -> void:
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	_prev_ai = Session.ai_enabled
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_auto_battles_saves"
	RunLock.path = "user://test_auto_battles_running.lock"
	Bindings.reset_defaults()
	_asked = []
	_answers = []
	_battles = 2
	_now = 1000
	_temp = ""
	_harness = UIHarness.new()  # turns Session.ai_enabled off
	_harness.settings.set_value("accessibility/reduce_motion", true)
	_harness.settings.set_value("game/season_report", "off")
	_harness.mount(self)
	_harness.stack.theme = KitTheme.load_for(1.0)
	_new_game()
	_flow = _make_flow()


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	_harness = null
	_flow = null
	Session.end_game()
	RunLock.clear()
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Session.ai_enabled = _prev_ai
	Bindings.reset_defaults()
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)
	if not _temp.is_empty() and FileAccess.file_exists(_temp):
		DirAccess.remove_absolute(_temp)


func _new_game() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the committed scenario starts")
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"}).get("ok", false)), "Genoa is chosen")


## A flow on the harness's stack and settings; battle_count is left to the shipped seam.
func _make_flow() -> SeasonFlow:
	var flow := SeasonFlow.new()
	flow.settings = _harness.settings
	flow.clock = func() -> int: return _now
	flow.push_ask = func(screen: Screen) -> void:
		var ask := screen as AutoBattlesAsk
		ask.answered.connect(func(choice: StringName) -> void: _answers.append(choice))
		_asked.append(ask)
		_harness.stack.push(screen)
	add_child_autofree(flow)
	return flow


## The same flow with a stub count of _battles.
func _stub_count() -> void:
	_flow.battle_count = func() -> int: return _battles


func _settle() -> void:
	var frames := 0
	while _flow.state() == SeasonFlow.State.RUNNING and frames < SETTLE_FRAMES:
		await get_tree().process_frame
		frames += 1
	assert_ne(_flow.state(), SeasonFlow.State.RUNNING, "the flow settles within %d frames" % SETTLE_FRAMES)


func _frames(count: int) -> void:
	for _i: int in count:
		await get_tree().process_frame


## The state the prompt must not touch: the game's digest, its version, its action log and the actions not yet saved.
func _state() -> Array:
	var g := Session.game
	return [g.digest(), g.version, g.turn, g.action_log.duplicate(true), Session.unsaved_actions]


# ----- this build: nothing to ask about ---------------------------------------------------------------------------------


func test_the_seam_says_there_is_no_battle_board() -> void:
	assert_false(BattlesAtEnd.available(), "no board: the Options row stays hidden")
	assert_eq(BattlesAtEnd.count(Session.game, Session.player_tag()), 0, "P: a battle to ask about before the board")


func test_a_game_of_this_build_asks_nothing() -> void:
	assert_true(_flow.request_end(), "the season begins at once")
	assert_eq(_asked.size(), 0, "P: a prompt with a count of 0")
	assert_eq(_harness.stack.count(), 0)
	await _settle()
	assert_eq(Session.game.turn, 2)


func test_a_stub_count_of_zero_asks_nothing() -> void:
	_stub_count()
	_battles = 0
	assert_true(_flow.request_end())
	assert_eq(_asked.size(), 0, "P: a prompt with a count of 0")
	await _settle()


# ----- when it is wanted ------------------------------------------------------------------------------------------------


func test_wanted_needs_a_battle_the_setting_ask_and_the_board_not_on_auto() -> void:
	var s := Settings.new("Windows", false)
	assert_false(AutoBattlesAsk.wanted(s, 0), "no battle")
	assert_true(AutoBattlesAsk.wanted(s, 1))
	assert_true(AutoBattlesAsk.wanted(s, 3))
	assert_false(AutoBattlesAsk.wanted(s, 3, true), "Your battles: Auto")
	for value: String in ["auto", "board"]:
		assert_true(s.set_value(KEY, value))
		assert_false(AutoBattlesAsk.wanted(s, 3), "answered: " + value)


func test_the_setting_auto_or_board_asks_nothing() -> void:
	_stub_count()
	for value: String in ["auto", "board"]:
		assert_true(_harness.settings.set_value(KEY, value))
		var turn := Session.game.turn
		assert_true(_flow.request_end(), "the season begins at once with " + value)
		assert_eq(_asked.size(), 0, "P: a prompt shown with the setting " + value)
		await _settle()
		assert_eq(Session.game.turn, turn + 1)
		_now += 1000


func test_your_battles_on_auto_asks_nothing() -> void:
	_stub_count()
	_flow.battles_on_auto = func() -> bool: return true
	assert_true(_flow.request_end())
	assert_eq(_asked.size(), 0, "P: a prompt with Your battles on Auto")
	await _settle()


# ----- the prompt -------------------------------------------------------------------------------------------------------


func test_the_question_its_answers_and_the_box() -> void:
	assert_eq(AutoBattlesAsk.question(1), "Fight your battle automatically?")
	assert_eq(AutoBattlesAsk.question(3), "Fight your 3 battles automatically?")
	_stub_count()
	var before := _state()
	assert_false(_flow.request_end(), "the season waits for the answer")
	await _frames(3)
	assert_eq(_asked.size(), 1)
	var ask := _asked[0]
	assert_eq(_harness.stack.top(), ask)
	assert_eq(ask.screen_id, &"auto_battles_ask")
	assert_eq(ask.kind, Screen.Kind.MODAL)
	assert_eq(ask.sheet().title, "Fight your 2 battles automatically?")
	assert_eq(ask.button_for(AutoBattlesAsk.YES).text, "Yes, fight automatically")
	assert_eq(ask.button_for(AutoBattlesAsk.NO).text, "No, I will play them")
	assert_eq(ask.box().text, "Don't ask again")
	assert_false(ask.box().button_pressed, "the box starts unticked")
	assert_true(ask.box().is_visible_in_tree())
	assert_eq(_harness.viewport.gui_get_focus_owner(), ask.button_for(AutoBattlesAsk.NO), "No has the focus")
	assert_eq(_flow.state(), SeasonFlow.State.IDLE, "no season runs while the question is up")
	assert_false(_flow.request_end(), "a second End season is refused")
	assert_eq(_asked.size(), 1, "and asks no second question")
	assert_eq(_state(), before, "P: the prompt acted on the game")


func test_yes_and_no_without_the_box_run_the_season_and_keep_nothing() -> void:
	_stub_count()
	for choice: StringName in [AutoBattlesAsk.YES, AutoBattlesAsk.NO]:
		var turn := Session.game.turn
		assert_false(_flow.request_end())
		var ask: AutoBattlesAsk = _asked.back()
		var before := _state()
		ask.button_for(choice).pressed.emit()
		assert_eq(_state(), before, "P: the answer itself acted on the game")
		assert_eq(_flow.state(), SeasonFlow.State.RUNNING, "%s runs the season" % choice)
		assert_eq(_harness.stack.count(), 0, "the question is gone")
		await _settle()
		assert_eq(Session.game.turn, turn + 1)
		assert_eq(_harness.settings.get_value(KEY), "ask", "no box, nothing kept")
		_now += 1000
	assert_eq(_answers, [AutoBattlesAsk.YES, AutoBattlesAsk.NO] as Array[StringName])
	assert_eq(_asked.size(), 2, "asked again the next season")


func test_yes_with_the_box_keeps_auto_and_asks_no_more() -> void:
	await _check_the_box_keeps(AutoBattlesAsk.YES, "auto")


func test_no_with_the_box_keeps_board_and_asks_no_more() -> void:
	await _check_the_box_keeps(AutoBattlesAsk.NO, "board")


func _check_the_box_keeps(choice: StringName, kept: String) -> void:
	_stub_count()
	assert_false(_flow.request_end())
	var ask := _asked[0]
	var before := _state()
	ask.box().button_pressed = true
	assert_eq(_harness.settings.get_value(KEY), "ask", "the box alone keeps nothing")
	ask.button_for(choice).pressed.emit()
	assert_eq(_harness.settings.get_value(KEY), kept, "P: a box that keeps nothing")
	assert_eq(_state(), before, "P: keeping the answer touched the game, its log or its unsaved actions")
	await _settle()
	assert_eq(Session.game.turn, 2)
	_temp = OS.get_temp_dir().path_join("test_auto_battles_%d.cfg" % Time.get_ticks_usec())
	assert_true(_harness.settings.save_to(_temp))
	assert_eq(Settings.load_from(_temp, "Windows", false).get_value(KEY), kept, "the setting reads back")
	_now += 1000
	assert_true(_flow.request_end(), "the next End season begins at once")
	assert_eq(_asked.size(), 1)
	await _settle()


func test_esc_runs_nothing_and_keeps_nothing() -> void:
	_stub_count()
	assert_false(_flow.request_end())
	var before := _state()
	_asked[0].box().button_pressed = true
	assert_true(_harness.stack.back(), "Esc")
	await _frames(3)
	assert_eq(_answers, [AutoBattlesAsk.CANCEL] as Array[StringName])
	assert_eq(_harness.stack.count(), 0)
	assert_eq(_flow.state(), SeasonFlow.State.IDLE, "no season")
	assert_eq(_harness.settings.get_value(KEY), "ask", "a ticked box keeps nothing on Esc")
	assert_eq(_state(), before, "P: Esc acted on the game")
	assert_false(_flow.request_end(), "End season asks again")
	assert_eq(_asked.size(), 2)


func test_a_question_the_flow_dropped_starts_nothing() -> void:
	_stub_count()
	assert_false(_flow.request_end())
	_flow.reset()  # a new game or a load
	var before := _state()
	_asked[0].button_for(AutoBattlesAsk.YES).pressed.emit()
	await _frames(3)
	assert_eq(_flow.state(), SeasonFlow.State.IDLE, "P: a dropped question ran a season")
	assert_eq(_state(), before)


func test_a_question_removed_unanswered_does_not_block_end_season() -> void:
	_stub_count()
	assert_false(_flow.request_end())
	_harness.stack.clear()
	await _frames(3)
	assert_false(_flow.request_end())
	assert_eq(_asked.size(), 2, "asked again")


## A season played through the question is the season played without it: the prompt draws no luck and logs nothing.
func test_the_asked_season_equals_the_unasked_season() -> void:
	assert_true(_flow.request_end())
	await _settle()
	var plain := _state()
	_new_game()
	_now += 1000
	_stub_count()
	assert_false(_flow.request_end())
	_asked[0].box().button_pressed = true
	_asked[0].button_for(AutoBattlesAsk.YES).pressed.emit()
	await _settle()
	var asked := _state()
	assert_eq(asked[0], plain[0], "the same digest")
	assert_eq(asked[3], plain[3], "the same action log")


# ----- Options ----------------------------------------------------------------------------------------------------------


func test_the_options_row_is_hidden_and_its_words_turn_the_setting_back_to_ask() -> void:
	assert_true(_harness.settings.set_value(KEY, "auto"))
	var options := ScreenIds.make(&"options") as Options
	_harness.stack.push(options)
	await _frames(2)
	options.select_page(&"game")
	await _frames(2)
	var row := options.option_row(KEY)
	assert_not_null(row)
	assert_false(row.visible, "hidden while BattlesAtEnd.available() is false")
	assert_false(row.is_visible_in_tree())
	var opt := row.control() as OptionButton
	var words: Array[String] = []
	for i: int in opt.item_count:
		words.append(opt.get_item_text(i))
	assert_eq(words, ["Ask me", "Fight automatically", "Play on the board"] as Array[String])
	assert_eq(opt.selected, 1, "the row shows the kept answer")
	opt.select(0)
	opt.item_selected.emit(0)
	assert_eq(_harness.settings.get_value(KEY), "ask", "turned back to ask")
	opt.select(2)
	opt.item_selected.emit(2)
	assert_eq(_harness.settings.get_value(KEY), "board")


# ----- the App ----------------------------------------------------------------------------------------------------------


## The App's wiring: End season's button asks on the App's stack when there is a battle, and not otherwise.
func test_the_app_asks_on_its_stack_only_with_a_battle() -> void:
	Session.end_game()
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.cli_args_override = PackedStringArray(["--new-game", "--country=GEN", "--seed=1480"])
	var s := Settings.new("Windows", false)
	s.set_value("state/help_seen", true)
	s.set_value("graphics/preload_next_season", false)
	s.set_value("game/autosave", "off")
	s.set_value("game/season_report", "off")
	s.set_value("game/movement", "instant")
	app.set_settings_override(s)
	vp.add_child(app)
	var frames := 0
	while not (app.map_scene() != null and app.stack().count() == 0 and not app.is_starting()) and frames < SETTLE_FRAMES:
		await get_tree().process_frame
		frames += 1
	assert_not_null(app.map_scene(), "the game is up")
	await _frames(3)
	var flow := app.requests().flow
	flow.battle_count = func() -> int: return 1
	var before := _state()
	app.hud().date_end().end_season_requested.emit()
	await _frames(3)
	var ask := app.stack().top() as AutoBattlesAsk
	assert_not_null(ask, "the question is on the App's stack")
	if ask == null:
		return
	assert_eq(ask.sheet().title, "Fight your battle automatically?")
	assert_true(app.stack().back(), "Esc")
	await _frames(3)
	assert_eq(app.stack().count(), 0)
	assert_eq(_state(), before, "no season ran")
	flow.battle_count = Callable()  # the shipped seam
	app.hud().date_end().end_season_requested.emit()
	assert_eq(app.stack().count(), 0, "P: a prompt in a game of this build")
	assert_eq(flow.state(), SeasonFlow.State.RUNNING)
	_flow = flow
	await _settle()
	assert_eq(Session.game.turn, int(before[2]) + 1)
