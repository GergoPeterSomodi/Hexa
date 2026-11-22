## The orders hook and LogOrders (docs/architecture/m8-build-spec.md 4.2, 4.15, 5.4, 9).
extends GutTest


func _log(actions: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Variant in actions:
		var name := str(a)
		var args := {}
		if name.begins_with("tax"):
			args = {"tag": "BBB", "level": int(name.substr(3))}
			name = "set_tax"
		out.append({"turn": 1, "action": name, "args": args})
	return out


func test_the_base_hook_does_nothing_and_is_done() -> void:
	var g := ScenarioFixture.game()
	var hook := OrdersHook.new()
	var before := g.digest()
	hook.begin(g)
	assert_true(hook.step(g))
	assert_eq([hook.seats(), hook.seats_done()], [0, 0])
	hook.clear()
	assert_eq(g.digest(), before)
	assert_eq(g.action_log.size(), 0)


func test_log_orders_plays_the_records_between_the_season_and_its_mark() -> void:
	var g := ScenarioFixture.game()
	g.watch()
	var log := _log(["end_season", "tax2", "tax1", "orders_done", "end_season"])
	var lo := LogOrders.over(log, 1)
	lo.begin(g)
	assert_eq(lo.index(), 4, "the record after the mark")
	assert_false(lo.step(g))
	assert_true(lo.step(g))
	assert_true(lo.step(g), "done stays done")
	assert_eq(g.countries[1].tax, 1, "the last one stands")
	var acts := 0
	for r: Dictionary in g.action_log:
		if r["action"] == "set_tax":
			acts += 1
	assert_eq(acts, 2, "played through Game.act")


func test_p_a_log_with_no_mark_plays_none() -> void:
	var g := ScenarioFixture.game()
	g.watch()
	var before := g.digest()
	for log: Array[Dictionary] in [_log(["end_season", "tax2", "end_season", "orders_done"]), _log(["end_season", "tax2"]),
			_log(["end_season"])]:
		var lo := LogOrders.over(log, 1)
		lo.begin(g)
		assert_true(lo.step(g))
		assert_eq(lo.index(), 1, "the start: nothing to skip")
	assert_eq(g.digest(), before)


func test_the_calls_are_the_same_through_run_phase_and_by_hand() -> void:
	var a := OrdersFixture.watched()
	var b := OrdersFixture.watched()
	Season.run_phase(a, &"ai_orders")
	Season.orders_begin(b)
	var n := 0
	while not Season.orders_step(b):
		n += 1
	Season.orders_end(b)
	assert_eq(n, 2)
	assert_eq((a.orders as OrdersFixture.Stub).calls, ["begin", "step", "step", "step"] as Array[String])
	assert_eq((b.orders as OrdersFixture.Stub).calls, (a.orders as OrdersFixture.Stub).calls)
	assert_eq(a.digest(), b.digest())
	assert_eq(a.action_log, b.action_log)
	assert_eq(str(a.action_log[a.action_log.size() - 1]["action"]), "orders_done")


func test_a_replayed_season_plays_the_logged_acts_to_the_same_digest() -> void:
	var g := OrdersFixture.watched()
	for n: int in 4:
		assert_true(bool(Season.run(g)["ok"]))
	var fx := ScenarioFixture.build()
	var again := Replay.run(fx["map"] as MapData, fx["defs"] as GameDefs, g.scenario.id, g.seed_value, g.action_log)
	assert_eq(again.digest(), g.digest(), "no hook attached in the replay")
	assert_eq(again.action_log, g.action_log)
