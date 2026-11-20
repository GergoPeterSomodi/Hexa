## GUT tests for SeasonFlow (docs/architecture/m3-build-spec.md 6.3, section 9): the 400 ms guard at 399 and 401 ms with
## an injected clock, echo refused, the report modes, a refused check, show_season and the autosave rule, J at turn 1,
## count. The flow gets fake callables; the seasons are real.
extends GutTest

var _flow: SeasonFlow = null
var _settings: Settings = null
var _now: int = 1000
var _pushed: Array[Dictionary] = []
var _reopened: Array[bool] = []
var _toasts: Array[Array] = []
var _seasons: Array[Array] = []
var _saves: int = 0
var _states: Array[int] = []
var _prev_game: Game = null
var _prev_unsaved: int = 0


func before_each() -> void:
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the committed scenario starts")
	var verdict := Session.act("choose_country", {"tag": &"GEN"})
	assert_true(bool(verdict.get("ok", false)), "Genoa is chosen")
	_now = 1000
	_pushed = []
	_reopened = []
	_toasts = []
	_seasons = []
	_saves = 0
	_states = []
	_settings = Settings.new("Windows", false)
	_flow = SeasonFlow.new()
	_flow.settings = _settings
	_flow.clock = func() -> int: return _now
	_flow.push_report = func(summary: Dictionary, reopened: bool) -> bool:
		_pushed.append(summary)
		_reopened.append(reopened)
		return true
	_flow.toast = func(text: String, tone: StringName, key: StringName) -> void: _toasts.append([text, tone, key])
	_flow.show_season = func(season: int, fade: bool) -> void: _seasons.append([season, fade])
	_flow.autosave = func() -> void: _saves += 1
	_flow.state_changed.connect(func(s: int) -> void: _states.append(s))
	add_child_autofree(_flow)


func after_each() -> void:
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	_flow = null


func _settle() -> void:
	await wait_until(func() -> bool: return _flow.state() != SeasonFlow.State.RUNNING, 3)


func test_guard_refuses_at_399_and_accepts_at_401() -> void:
	_settings.set_value("game/season_report", "off")
	assert_true(_flow.request_end())
	await _settle()
	assert_eq(_flow.state(), SeasonFlow.State.IDLE, "Off returns to IDLE at once")
	assert_eq(_flow.guard_until, 1400, "the guard is clock + 400")
	_now = 1399
	assert_false(_flow.request_end(), "refused at 399 ms")
	assert_eq(_flow.state(), SeasonFlow.State.IDLE)
	_now = 1401
	assert_true(_flow.request_end(), "accepted at 401 ms")
	await _settle()
	assert_eq(Session.game.turn, 3, "two seasons were played")


func test_echo_and_non_idle_refused() -> void:
	assert_false(_flow.request_end(true), "an echo is refused")
	assert_eq(Session.game.turn, 1)
	assert_true(_flow.request_end())
	assert_eq(_flow.state(), SeasonFlow.State.RUNNING)
	assert_false(_flow.request_end(), "refused while RUNNING")
	await _settle()
	assert_eq(_flow.state(), SeasonFlow.State.REPORT, "Full waits for the report")
	assert_false(_flow.request_end(), "refused while the report is open")
	assert_eq(Session.game.turn, 2)


func test_full_pushes_and_close_returns_to_idle_with_guard() -> void:
	assert_true(_flow.request_end())
	await _settle()
	assert_eq(_pushed.size(), 1, "the report is pushed")
	assert_eq(int(_pushed[0].get("turn", 0)), 1, "the summary of the season that ended")
	assert_eq(_seasons.size(), 0, "no season swap until the report closes")
	_now = 5000
	_flow.report_closed()
	assert_eq(_flow.state(), SeasonFlow.State.IDLE)
	assert_eq(_flow.guard_until, 5400)
	assert_eq(_seasons, [[Calendar.SUMMER, true]], "Summer begins, with the fade")
	assert_eq(_states[0], SeasonFlow.State.RUNNING, "state_changed told the date it is busy")
	assert_eq(_states[-1], SeasonFlow.State.IDLE)


func test_report_closed_outside_report_does_nothing() -> void:
	_flow.report_closed()
	assert_eq(_flow.state(), SeasonFlow.State.IDLE)
	assert_eq(_flow.guard_until, 0)
	assert_eq(_seasons.size(), 0)


func test_off_toasts_the_summary() -> void:
	_settings.set_value("game/season_report", "off")
	_flow.request_end()
	await _settle()
	assert_eq(_pushed.size(), 0)
	assert_eq(_toasts.size(), 1)
	assert_eq(_toasts[0][1], &"plain")
	assert_eq(_toasts[0][2], &"game_report")
	assert_false(String(_toasts[0][0]).is_empty(), "the toast has text")
	assert_eq(_seasons.size(), 1, "the season swap runs at once")


func test_brief_pushes_only_when_serious_or_swing() -> void:
	_settings.set_value("game/season_report", "brief")
	_flow.summarize = func(turn: int) -> Dictionary:
		return {"turn": turn, "serious": false, "swing_permille": 100, "toast": "Quiet."}
	_flow.request_end()
	await _settle()
	assert_eq(_pushed.size(), 0, "not serious, swing 100: a toast")
	assert_eq(_toasts[0][0], "Quiet.")
	_now = 3000
	_flow.summarize = func(turn: int) -> Dictionary:
		return {"turn": turn, "serious": true, "swing_permille": 0, "toast": "x"}
	_flow.request_end()
	await _settle()
	assert_eq(_pushed.size(), 1, "serious: pushed")
	_flow.report_closed()
	_now = 6000
	_flow.summarize = func(turn: int) -> Dictionary:
		return {"turn": turn, "serious": false, "swing_permille": 101, "toast": "x"}
	_flow.request_end()
	await _settle()
	assert_eq(_pushed.size(), 2, "swing over 100: pushed")


func test_refused_check_toasts_its_reason() -> void:
	Session.game.player = &""
	assert_false(_flow.request_end())
	assert_eq(_flow.state(), SeasonFlow.State.IDLE)
	assert_eq(_toasts.size(), 1)
	assert_eq(_toasts[0][1], &"bad")
	assert_false(String(_toasts[0][0]).is_empty(), "the reason is shown")
	assert_eq(Session.game.turn, 1)


func test_show_season_fade_follows_setting_and_reduce_motion() -> void:
	_settings.set_value("game/season_report", "off")
	_settings.set_value("graphics/season_change", "instant")
	_flow.request_end()
	await _settle()
	assert_eq(_seasons[-1], [Calendar.SUMMER, false], "instant setting")
	_settings.set_value("graphics/season_change", "fade")
	_now += 500
	_flow.request_end()
	await _settle()
	assert_eq(_seasons[-1], [Calendar.AUTUMN, true], "fade setting")
	_settings.set_value("accessibility/reduce_motion", true)
	_now += 500
	_flow.request_end()
	await _settle()
	assert_eq(_seasons[-1], [Calendar.WINTER, false], "reduce motion makes it instant")


func test_autosave_due_rule() -> void:
	assert_true(SeasonFlow.autosave_due(5, 1480, "yearly"), "Spring 1481 yearly")
	assert_false(SeasonFlow.autosave_due(2, 1480, "yearly"), "Summer is never due")
	assert_true(SeasonFlow.autosave_due(21, 1480, "five_years"), "Spring 1485")
	assert_false(SeasonFlow.autosave_due(5, 1480, "five_years"), "Spring 1481 not on five_years")
	assert_true(SeasonFlow.autosave_due(1, 1480, "five_years"), "the start year counts")
	assert_false(SeasonFlow.autosave_due(5, 1480, "off"), "never when off")
	assert_false(SeasonFlow.autosave_due(5, 1480, "weekly"), "unknown never")


func test_autosave_called_when_season_begun_is_spring() -> void:
	_settings.set_value("game/season_report", "off")
	for i in 3:
		_flow.request_end()
		await _settle()
		_now += 500
	assert_eq(_saves, 0, "Summer, Autumn, Winter begin: no save")
	_flow.request_end()
	await _settle()
	assert_eq(_saves, 1, "yearly at Spring 1481")
	_settings.set_value("game/autosave", "off")
	_now += 500
	for i in 4:
		_flow.request_end()
		await _settle()
		_now += 500
	assert_eq(_saves, 1, "off never saves")


func test_j_at_turn_one_toasts() -> void:
	_flow.reopen_report()
	assert_eq(_toasts.size(), 1)
	assert_eq(_toasts[0][0], "No season has ended yet.")
	assert_eq(_toasts[0][1], &"plain")
	assert_eq(_pushed.size(), 0)
	assert_eq(_flow.state(), SeasonFlow.State.IDLE)


func test_j_reopens_last_report_and_close_sets_guard_only() -> void:
	_settings.set_value("game/season_report", "off")
	_flow.request_end()
	await _settle()
	_now = 9000
	_flow.reopen_report()
	assert_eq(_pushed.size(), 1)
	assert_eq(int(_pushed[0].get("turn", 0)), 1)
	assert_eq(_flow.state(), SeasonFlow.State.REPORT)
	var swaps := _seasons.size()
	_now = 9100
	_flow.report_closed()
	assert_eq(_flow.guard_until, 9500, "a reopened report also sets the guard")
	assert_eq(_seasons.size(), swaps, "no season swap for a reopened report")
	assert_eq(_saves, 0)


func test_count_plays_four_seasons_and_one_report() -> void:
	assert_true(_flow.request_end(false, 4))
	await _settle()
	assert_eq(Session.game.turn, 5, "four seasons")
	assert_eq(_pushed.size(), 1, "one report")
	assert_eq(int(_pushed[0].get("turn", 0)), 4, "of the last season")
	_flow.report_closed()
	assert_eq(_seasons, [[Calendar.SPRING, true]], "one swap, to the season that begins")
	assert_eq(_saves, 1, "Spring 1481 yearly")


func test_push_report_carries_the_reopened_flag() -> void:
	_flow.request_end()
	await _settle()
	assert_eq(_reopened, [false], "a report after a season")
	_flow.report_closed()
	_now += 500
	_flow.reopen_report()
	assert_eq(_reopened, [false, true], "J reopens")


func test_no_screen_goes_straight_to_idle() -> void:
	_flow.push_report = func(_s: Dictionary, _r: bool) -> bool: return false
	_flow.request_end()
	await _settle()
	assert_eq(_flow.state(), SeasonFlow.State.IDLE, "a refused push does not wait for a close")
	assert_eq(_seasons.size(), 1, "the season swap still runs")
	_now += 500
	_flow.push_report = Callable()
	assert_true(_flow.request_end(), "an invalid push callable too")
	await _settle()
	assert_eq(_flow.state(), SeasonFlow.State.IDLE)
	_flow.reopen_report()
	assert_eq(_flow.state(), SeasonFlow.State.IDLE, "J with no screen stays IDLE")


func test_reset_on_game_started_and_ended() -> void:
	_flow.request_end()
	await _settle()
	assert_eq(_flow.state(), SeasonFlow.State.REPORT)
	Events.game_ended.emit()
	assert_eq(_flow.state(), SeasonFlow.State.IDLE)
	assert_eq(_flow.guard_until, 0)
	_flow.request_end()
	await _settle()
	assert_eq(_flow.state(), SeasonFlow.State.REPORT)
	Events.game_started.emit()
	assert_eq(_flow.state(), SeasonFlow.State.IDLE)
	assert_true(_flow.request_end(), "End season works again at once")
	await _settle()


func test_game_ending_mid_run_stops_quietly() -> void:
	assert_true(_flow.request_end())
	Session.game = null
	Events.game_ended.emit()
	await wait_frames(3)
	assert_eq(_toasts.size(), 0, "no toast")
	assert_eq(_pushed.size(), 0)
	assert_eq(_flow.state(), SeasonFlow.State.IDLE)
	assert_false(_states.has(SeasonFlow.State.REPLAY), "no pass through REPLAY")
