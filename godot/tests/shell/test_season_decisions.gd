## SeasonFlow's DECISIONS state (docs/architecture/m7-build-spec.md 6.6, B20): after the replay (or straight after the season
## with no replay) the flow shows the decisions, then the report. With none queued the report follows at once; decisions_done
## outside DECISIONS does nothing; a replay with a decision waiting stays in DECISIONS until decisions_done.
extends GutTest

var _flow: SeasonFlow = null
var _settings: Settings = null
var _pushed: Array[Dictionary] = []
var _states: Array[int] = []
var _asked := 0
var _done: Callable = Callable()
var _prev_game: Game = null
var _prev_unsaved: int = 0


func before_each() -> void:
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the committed scenario starts")
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"}).get("ok", false)), "Genoa is chosen")
	_pushed = []
	_states = []
	_asked = 0
	_done = Callable()
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
	_flow.state_changed.connect(func(s: int) -> void: _states.append(s))
	add_child_autofree(_flow)


func after_each() -> void:
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	_flow = null


## A replay that started and runs (its start callable says yes); the season is run through the flow's own request.
func _in_replay() -> void:
	_flow.replay_start = func(_speed: StringName) -> bool: return true
	_flow.request_end(false)
	await wait_until(func() -> bool: return _flow.state() != SeasonFlow.State.RUNNING, 3)
	assert_eq(_flow.state(), SeasonFlow.State.REPLAY, "the replay runs")


## The decision callable: one pending decision that the test answers by calling _done.
func _with_one_decision() -> void:
	_flow.decisions_start = func(on_done: Callable) -> bool:
		_asked += 1
		_done = on_done
		return true


func test_no_decision_goes_from_the_replay_to_the_report() -> void:
	await _in_replay()
	_flow.replay_done()
	assert_eq(_flow.state(), SeasonFlow.State.REPORT, "nothing queued: the report at once")
	assert_eq(_pushed.size(), 1, "the report screen is pushed")
	assert_true(_states.has(SeasonFlow.State.DECISIONS), "the state passes through DECISIONS")


func test_a_pending_decision_holds_the_flow_until_it_is_answered() -> void:
	_with_one_decision()
	await _in_replay()
	_flow.replay_done()
	assert_eq(_flow.state(), SeasonFlow.State.DECISIONS, "the decision is shown")
	assert_eq(_asked, 1)
	assert_eq(_pushed.size(), 0, "no report while a decision is up")
	_done.call()
	assert_eq(_flow.state(), SeasonFlow.State.REPORT, "the queue emptied: the report")
	assert_eq(_pushed.size(), 1)


func test_decisions_done_outside_decisions_does_nothing() -> void:
	_flow.decisions_done()
	assert_eq(_flow.state(), SeasonFlow.State.IDLE)
	assert_eq(_pushed.size(), 0)


func test_no_replay_and_no_decision_reports_as_before() -> void:
	_flow.replay_start = func(_speed: StringName) -> bool: return false
	_flow.request_end(false)
	await wait_until(func() -> bool: return _flow.state() != SeasonFlow.State.RUNNING, 3)
	assert_eq(_pushed.size(), 1, "the season's report (M3) with no replay and no decision")
	assert_eq(_flow.state(), SeasonFlow.State.REPORT)


func test_no_replay_with_a_decision_shows_it_first() -> void:
	_with_one_decision()
	_flow.replay_start = func(_speed: StringName) -> bool: return false
	_flow.request_end(false)
	await wait_until(func() -> bool: return _flow.state() != SeasonFlow.State.RUNNING, 3)
	assert_eq(_flow.state(), SeasonFlow.State.DECISIONS, "the decision comes before the report")
	assert_eq(_pushed.size(), 0)
	_done.call()
	assert_eq(_pushed.size(), 1, "then the report")
