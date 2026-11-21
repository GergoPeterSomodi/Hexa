## SeasonFlow with the movement replay (docs/architecture/m6-build-spec.md 6.4; task L15): End season -> run -> replay ->
## report, the order of the states, the instant setting and reduce motion, the ribbons held for the season and its replay,
## input during the replay (End season skips it, never starts a second one) and a reset (a new game or load) that ends it.
## The replay and the ribbons are fakes that do what MoveReplay and Floaters do; the seasons are real.
extends GutTest

var _flow: SeasonFlow = null
var _settings: Settings = null
var _prev_game: Game = null
var _prev_unsaved: int = 0
var _states: Array[int] = []
var _pushed: Array[Dictionary] = []
var _speeds: Array[StringName] = []
var _holds: Array[bool] = []
var _skips: int = 0
var _replay_ok := true
var _skip_finishes := true


func before_each() -> void:
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the committed scenario starts")
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"}).get("ok", false)), "Genoa is chosen")
	_states = []
	_pushed = []
	_speeds = []
	_holds = []
	_skips = 0
	_replay_ok = true
	_skip_finishes = true
	_settings = Settings.new("Windows", false)
	_flow = SeasonFlow.new()
	_flow.settings = _settings
	_flow.clock = func() -> int: return 1000
	_flow.push_report = func(summary: Dictionary, _reopened: bool) -> bool:
		_pushed.append(summary)
		return true
	_flow.toast = func(_text: String, _tone: StringName, _key: StringName) -> void: pass
	_flow.show_season = func(_season: int, _fade: bool) -> void: pass
	_flow.autosave = func() -> void: pass
	_flow.replay_start = func(speed: StringName) -> bool:
		_speeds.append(speed)
		return _replay_ok and speed != &"instant"  # MoveReplay.start refuses instant (and drops the walks)
	_flow.replay_skip = func() -> void:
		_skips += 1
		if _skip_finishes:
			_flow.replay_done()
	_flow.hold_ribbons = func(on: bool) -> void: _holds.append(on)
	_flow.state_changed.connect(func(s: int) -> void: _states.append(s))
	add_child_autofree(_flow)


func after_each() -> void:
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	_flow = null


func _settle() -> void:
	await wait_until(func() -> bool: return _flow.state() != SeasonFlow.State.RUNNING, 3)


func test_the_order_is_running_replay_decisions_report() -> void:
	assert_true(_flow.request_end())
	await _settle()
	assert_eq(_flow.state(), SeasonFlow.State.REPLAY, "the replay runs before the report")
	assert_eq(_pushed.size(), 0, "no report while the moves play")
	assert_eq(_speeds, [&"normal"], "the setting's speed")
	_flow.replay_done()
	assert_eq(_flow.state(), SeasonFlow.State.REPORT, "then the report")
	assert_eq(_pushed.size(), 1)
	assert_eq(_states, [SeasonFlow.State.RUNNING, SeasonFlow.State.REPLAY, SeasonFlow.State.DECISIONS,
		SeasonFlow.State.REPORT], "RUNNING, REPLAY, DECISIONS, REPORT")
	_flow.report_closed()
	assert_eq(_flow.state(), SeasonFlow.State.IDLE)


func test_the_ribbons_are_held_for_the_season_and_released_at_idle() -> void:
	assert_true(_flow.request_end())
	await _settle()
	assert_eq(_holds, [true], "held when the season starts")
	_flow.replay_done()
	_flow.report_closed()
	assert_eq(_holds, [true, false], "released back at idle")


func test_end_season_during_the_replay_skips_it_and_starts_no_season() -> void:
	assert_true(_flow.request_end())
	await _settle()
	var turn := Session.game.turn
	assert_false(_flow.request_end(), "refused: the press skips the replay and starts nothing")
	assert_eq(_skips, 1, "the press asked for the skip")
	assert_eq(_speeds.size(), 1, "one replay only")
	assert_eq(Session.game.turn, turn, "no season was played")
	assert_eq(_flow.state(), SeasonFlow.State.REPORT, "the skip finished the replay: the report")
	assert_false(_flow.request_end(), "a press with the report open starts nothing")
	assert_eq(_skips, 1)
	assert_eq(_speeds.size(), 1)


func test_a_skip_that_does_not_finish_is_ended_by_the_flow() -> void:
	_skip_finishes = false
	assert_true(_flow.request_end())
	await _settle()
	assert_true(_flow.skip_replay())
	assert_eq(_skips, 1)
	assert_eq(_flow.state(), SeasonFlow.State.REPORT, "the flow ends a replay that its skip left running")


func test_a_skip_that_finishes_goes_on_to_the_report() -> void:
	assert_true(_flow.request_end())
	await _settle()
	assert_true(_flow.skip_replay(), "the skip is taken")
	assert_eq(_flow.state(), SeasonFlow.State.REPORT, "the report opens after the skip")
	assert_false(_flow.skip_replay(), "no replay to skip now")


func test_the_instant_setting_plays_no_replay() -> void:
	_settings.set_value("game/movement", "instant")
	assert_true(_flow.request_end())
	await _settle()
	assert_eq(_speeds, [&"instant"], "the flow asks for instant")
	assert_eq(_flow.state(), SeasonFlow.State.REPORT, "the report at once")
	assert_false(_states.has(SeasonFlow.State.REPLAY), "the replay state is never entered")


func test_reduce_motion_plays_no_replay() -> void:
	_settings.set_value("accessibility/reduce_motion", true)
	assert_true(_flow.request_end())
	await _settle()
	assert_eq(_speeds, [&"instant"], "reduce motion is instant")
	assert_false(_states.has(SeasonFlow.State.REPLAY))


func test_a_replay_that_shows_nothing_goes_straight_to_the_report() -> void:
	_replay_ok = false
	assert_true(_flow.request_end())
	await _settle()
	assert_eq(_flow.state(), SeasonFlow.State.REPORT)
	assert_false(_states.has(SeasonFlow.State.REPLAY))


func test_skip_outside_a_replay_does_nothing() -> void:
	assert_false(_flow.skip_replay())
	assert_eq(_skips, 0)


func test_a_reset_during_the_replay_ends_it_and_a_late_finish_is_ignored() -> void:
	assert_true(_flow.request_end())
	await _settle()
	_flow.reset()
	assert_eq(_flow.state(), SeasonFlow.State.IDLE, "a new game or load goes back to idle")
	assert_eq(_holds[-1], false, "the ribbons are released")
	_flow.replay_done()
	assert_eq(_flow.state(), SeasonFlow.State.IDLE, "a finish after the reset does nothing")
	assert_eq(_pushed.size(), 0, "no report")
