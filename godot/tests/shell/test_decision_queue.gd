## DecisionQueue (docs/architecture/m7-build-spec.md 6.6, B20): the war Confirm per queued decision, in order; Show asks the country
## panel for the attacker; the last answer emits `emptied`; the idle label reads "To the map"; an unknown kind is skipped.
## The Confirm is answered through its own resolve (the same path its buttons take).
extends GutTest

var _stack: ScreenStack = null
var _ctx: ShellContext = null
var _requests: Array[Array] = []
var _emptied := 0
var _prev_game: Game = null
var _queue: DecisionQueue = null


func before_each() -> void:
	_prev_game = Session.game
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the committed scenario starts")
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"}).get("ok", false)), "Genoa is chosen")
	_stack = ScreenStack.new()
	add_child_autofree(_stack)
	_ctx = ShellContext.new(null, _stack)
	_ctx.app_requested.connect(func(what: StringName, args: Dictionary) -> void: _requests.append([what, args]))
	_requests = []
	_emptied = 0
	_queue = DecisionQueue.new()
	_queue.emptied.connect(func() -> void: _emptied += 1)


func after_each() -> void:
	Session.game = _prev_game


func _war(attacker: StringName) -> Dictionary:
	return {"kind": DecisionQueue.KIND_WAR, "tag": attacker, "target": &"GEN", "turn": 0}


func _top() -> Confirm:
	return _stack.top() as Confirm


func test_an_empty_queue_shows_nothing() -> void:
	assert_false(_queue.next(_ctx), "nothing is queued")
	assert_eq(_stack.top(), null, "no screen is pushed")
	assert_eq(_emptied, 0, "emptied is only emitted after an answer")


func test_a_war_on_the_player_shows_one_confirm() -> void:
	_queue.push(_war(&"SAV"))
	assert_eq(_queue.count(), 1)
	assert_true(_queue.next(_ctx), "the decision's Confirm is up")
	assert_eq(_queue.count(), 0, "the decision left the queue")
	assert_not_null(_top(), "the Confirm is the top screen")
	assert_eq(_top().screen_id, &"confirm")


func test_the_report_answer_empties_the_queue() -> void:
	_queue.push(_war(&"SAV"))
	_queue.next(_ctx)
	_top().call("_resolve", DecisionQueue.CHOICE_REPORT)
	assert_eq(_emptied, 1, "the last answer empties the queue once")
	assert_eq(_requests.size(), 0, "To the report asks for nothing")


func test_show_asks_the_country_panel_for_the_attacker() -> void:
	_queue.push(_war(&"SAV"))
	_queue.next(_ctx)
	_top().call("_resolve", DecisionQueue.CHOICE_SHOW)
	assert_eq(_requests.size(), 1)
	assert_eq(_requests[0][0], &"country")
	assert_eq((_requests[0][1] as Dictionary)["tag"], &"SAV", "the attacker's panel is asked for")
	assert_eq(_emptied, 1, "Show ends the queue too, when nothing is left")


func test_two_decisions_show_one_at_a_time_in_order() -> void:
	_queue.push(_war(&"SAV"))
	_queue.push(_war(&"FRA"))
	assert_true(_queue.next(_ctx))
	var first := _top()
	assert_eq(_queue.count(), 1, "one is still queued while the first is up")
	first.call("_resolve", DecisionQueue.CHOICE_SHOW)
	assert_eq(_requests[0][1]["tag"], &"SAV", "the first pushed is answered first")
	assert_eq(_emptied, 0, "the queue is not empty yet")
	assert_not_null(_top(), "the second Confirm is up")
	assert_ne(_top(), first, "a new Confirm replaced the first")
	_top().call("_resolve", DecisionQueue.CHOICE_SHOW)
	assert_eq(_requests[1][1]["tag"], &"FRA", "the second, after the first")
	assert_eq(_emptied, 1, "the last answer empties the queue")


func test_at_idle_the_last_choice_reads_to_the_map() -> void:
	_queue.push(_war(&"SAV"))
	_queue.next(_ctx, true)
	var report := _top().button_for(DecisionQueue.CHOICE_REPORT)
	assert_not_null(report)
	assert_eq(report.text, "To the map", "spec 6.6: at idle the choice reads To the map")


func test_during_a_season_the_last_choice_reads_to_the_report() -> void:
	_queue.push(_war(&"SAV"))
	_queue.next(_ctx)
	assert_eq(_top().button_for(DecisionQueue.CHOICE_REPORT).text, "To the report")


func test_an_unknown_kind_is_skipped() -> void:
	_queue.push({"kind": &"peace_offer", "tag": &"SAV", "target": &"GEN", "turn": 0})
	_queue.push(_war(&"FRA"))
	assert_true(_queue.next(_ctx), "the war after the unknown kind is shown")
	assert_eq(_queue.count(), 0, "the unknown one is dropped")


func test_clear_drops_what_is_queued() -> void:
	_queue.push(_war(&"SAV"))
	_queue.clear()
	assert_eq(_queue.count(), 0)
	assert_false(_queue.next(_ctx), "nothing is left to show")


func test_no_ctx_shows_nothing_and_keeps_the_queue() -> void:
	_queue.push(_war(&"SAV"))
	assert_false(_queue.next(null), "no stack, no Confirm")
	assert_eq(_queue.count(), 1, "the decision waits for a stack")
