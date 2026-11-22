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


# ----- the peace alert (M8 spec 4.14, 6.4): the entry is the real producer's (Wars.end_war, what make_peace calls) ------------

func _neighbour() -> StringName:
	var nb := WarFixture.neighbour_of(Session.game, &"GEN")
	assert_ne(nb, &"", "Genoa has a neighbour in the committed scenario")
	return nb


## The first `n` districts of `tag` that are not its capital, in index order.
func _districts_of(tag: StringName, n: int) -> Array[Vector2i]:
	var g := Session.game
	var c := Countries.by_tag(g, tag)
	var out: Array[Vector2i] = []
	for i: int in Territory.districts(g, c.id):
		var hex := g.map.hex_of(i)
		if hex != c.capital and out.size() < n:
			out.append(hex)
	return out


## A peace ended by `actor` on `terms` with the neighbour, moving `n` districts: returns the chronicle's peace_made entry.
func _peace(terms: StringName, actor: StringName, n: int) -> Dictionary:
	var g := Session.game
	var nb := _neighbour()
	var war := WarFixture.at_war(g, &"GEN", nb)
	if terms == &"take":
		for hex: Vector2i in _districts_of(&"GEN", n):
			WarFixture.set_occupier(g, hex, nb)
	elif terms == &"yield":
		for hex: Vector2i in _districts_of(nb, n):
			WarFixture.set_occupier(g, hex, &"GEN")
	g.version += 1
	Wars.end_war(g, war, terms, actor)
	for i: int in range(g.chronicle.entries.size() - 1, -1, -1):
		if str(g.chronicle.entries[i].get("kind", "")) == "peace_made":
			return g.chronicle.entries[i]
	return {}


func test_the_peace_entry_of_the_producer_makes_the_alert() -> void:
	var nb := _neighbour()
	var entry := _peace(&"take", nb, 2)
	var d := DecisionQueue.peace_decision(entry, &"GEN")
	assert_eq(StringName(d.get("kind", &"")), DecisionQueue.KIND_PEACE)
	assert_eq(StringName(d.get("tag", &"")), nb, "the country that made the peace")
	assert_eq(StringName(d.get("target", &"")), &"GEN", "the player is the target")
	assert_eq(StringName(d.get("terms", &"")), &"take")
	assert_eq((d.get("moved", []) as Array).size(), 2, "the two districts that change hands")


func test_a_peace_the_player_made_is_no_alert() -> void:
	var entry := _peace(&"white", &"GEN", 0)
	assert_eq(DecisionQueue.peace_decision(entry, &"GEN").size(), 0, "the player's own peace makes no alert")


func test_a_take_alert_is_bad_toned_and_names_the_land_as_theirs() -> void:
	var nb := _neighbour()
	_queue.push(DecisionQueue.peace_decision(_peace(&"take", nb, 2), &"GEN"))
	assert_true(_queue.next(_ctx), "the peace alert is up")
	assert_eq(_top().get("_title"), "Peace", "the title")
	assert_true(bool(_top().get("_danger")), "a take is a bad tone")
	var body := str(_top().get("_body"))
	assert_true(body.contains("has made peace with you: "), "the first line names the peace")
	assert_true(body.contains(" become theirs."), "two districts become theirs")
	assert_true(body.contains("("), "each district is named with its hex")
	assert_false(body.contains("truce"), "no truce line for a take")


func test_a_yield_alert_is_plain_and_gives_the_truce_line() -> void:
	var nb := _neighbour()
	_queue.push(DecisionQueue.peace_decision(_peace(&"yield", nb, 1), &"GEN"))
	_queue.next(_ctx)
	assert_false(bool(_top().get("_danger")), "a yield is a plain tone")
	var body := str(_top().get("_body"))
	assert_true(body.contains(" becomes yours."), "one district becomes yours")
	assert_true(body.contains("A truce holds until "), "the truce line follows a yield")


func test_a_white_alert_says_every_district_returns() -> void:
	var nb := _neighbour()
	_queue.push(DecisionQueue.peace_decision(_peace(&"white", nb, 0), &"GEN"))
	_queue.next(_ctx)
	assert_false(bool(_top().get("_danger")), "a white peace is a plain tone")
	assert_true(str(_top().get("_body")).contains("every district returns to its owner."))


func test_the_war_alert_is_shown_before_the_peace_alert() -> void:
	var nb := _neighbour()
	_queue.push(DecisionQueue.peace_decision(_peace(&"white", nb, 0), &"GEN"))
	_queue.push(_war(&"SAV"))
	assert_true(_queue.next(_ctx))
	assert_eq(_top().get("_title"), "War!", "the war alert goes first, though pushed second")
	assert_eq(_queue.count(), 1, "the peace alert waits")


func test_show_on_the_peace_alert_asks_for_the_country() -> void:
	var nb := _neighbour()
	_queue.push(DecisionQueue.peace_decision(_peace(&"white", nb, 0), &"GEN"))
	_queue.next(_ctx)
	_top().call("_resolve", DecisionQueue.CHOICE_SHOW)
	assert_eq(_requests.size(), 1)
	assert_eq(_requests[0][0], &"country")
	assert_eq((_requests[0][1] as Dictionary)["tag"], nb, "the country that made the peace is asked for")
	assert_eq(_emptied, 1)
