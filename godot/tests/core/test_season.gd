## The season table (docs/architecture/m3-build-spec.md 4.2, 9; m4-build-spec.md 4.13).
extends GutTest


func test_phases_are_pinned() -> void:
	# M8 (m8-build-spec.md 4.2): fourteen phases, ai_orders before movement; M7: battles after movement, sieges after supply,
	# war before production.
	assert_eq(Season.PHASES, [&"ai_orders", &"movement", &"battles", &"supply", &"sieges", &"war", &"production", &"income",
		&"works", &"people", &"stats", &"calendar", &"ready_units", &"vision"] as Array[StringName])


func test_end_check_rows() -> void:
	var g := ScenarioFixture.game()
	var before := g.digest()
	var verdict := Season.end_check(g)
	assert_false(bool(verdict["ok"]))
	assert_eq(str(verdict["reason"]), "choose your country first")
	var refused := Season.run(g)
	assert_false(bool(refused["ok"]))
	assert_eq(g.digest(), before, "nothing changed")
	assert_eq(g.action_log.size(), 0)
	g.act("choose_country", {"tag": &"AAA"})
	assert_true(bool(Season.end_check(g)["ok"]))
	var sandbox := Game.new_game(ScenarioFixture.build()["map"] as MapData, 1)
	assert_true(bool(Season.end_check(sandbox)["ok"]))


func test_run_logs_and_advances() -> void:
	var g := ScenarioFixture.game()
	g.act("choose_country", {"tag": &"AAA"})
	assert_true(bool(Season.run(g)["ok"]))
	assert_eq(g.turn, 2)
	var last := g.action_log[g.action_log.size() - 2]
	assert_eq(last["action"], "end_season")
	assert_eq(g.action_log[g.action_log.size() - 1]["action"], "orders_done", "the mark closes the season's records")
	assert_eq(int(last["turn"]), 1, "the season that ended")


func test_run_phase_unknown_does_nothing() -> void:
	var g := ScenarioFixture.game()
	var before := g.digest()
	Season.run_phase(g, &"nonsense")
	assert_eq(g.digest(), before)
	Season.run_phase(g, &"calendar")
	assert_eq(g.turn, 2)
	Season.run_phase(g, &"production")
	Season.run_phase(g, &"income")
	Season.run_phase(g, &"works")
	Season.run_phase(g, &"stats")
	assert_eq(g.turn, 2)


func test_a_paid_town_upgrade_finishing_in_season_t_gives_its_room_in_ts_people_phase() -> void:
	# The works phase runs before the people phase: a village whose upgrade finishes in season T already has the town's room
	# (20,000) when T's people phase grows it, so it passes the village's 4,000 in T; one season earlier it stopped at 4,000.
	var alba := Vector2i(6, 11)
	var g := PeopleFixture.genoa(PeopleFixture.always_fed())
	var i := g.map.index_of(alba)
	var tag := Territory.owner_tag(g, alba)
	assert_ne(tag, &"", "Alba has an owner")
	assert_eq(int(g.state.level[i]), 2, "a village")
	assert_true(g.dev_money(tag, 5000))
	assert_true(g.dev_goods(tag, g.defs.good_id(&"timber"), 100))
	assert_true(g.dev_goods(tag, g.defs.good_id(&"stone"), 100))
	var verdict := g.act("upgrade", {"hex": alba, "tag": tag})
	assert_true(bool(verdict["ok"]), str(verdict.get("reason", "")))
	var work := g.state.work_at(alba)
	assert_not_null(work, "the upgrade is under way")
	assert_gt(work.paid, 0, "a paid upgrade")
	while work.seasons_left > 1:
		assert_true(g.dev_people(alba, 3999))
		Season.run(g)
		assert_lte(g.state.people[i], 4000, "under way: the village's room holds it at 4,000")
		assert_eq(int(g.state.level[i]), 2)
	assert_true(g.dev_people(alba, 3999))
	var finishing := g.turn
	Season.run(g)
	assert_eq(int(g.state.level[i]), 3, "the town stands from season %d" % finishing)
	assert_gt(g.state.people[i], 4000, "its room was the town's in the people phase of the same season")


# ----- M8: the ai_orders phase and the hook (m8-build-spec.md 4.2) --------------------------------------------------------


func test_run_phase_ai_orders_calls_begin_steps_and_end_and_logs_the_mark() -> void:
	var g := OrdersFixture.watched()
	var hook := g.orders as OrdersFixture.Stub
	Season.run_phase(g, &"ai_orders")
	assert_eq(hook.calls, ["begin", "step", "step", "step"] as Array[String])
	var last := g.action_log[g.action_log.size() - 1]
	assert_eq([last["action"], int(last["turn"])], ["orders_done", 1])
	assert_eq(g.turn, 1, "the phase moves no calendar")


func test_with_no_hook_only_the_mark_is_logged_every_season() -> void:
	var g := ScenarioFixture.game()
	g.act("choose_country", {"tag": &"AAA"})
	assert_null(g.orders)
	Season.run(g)
	Season.run(g)
	var names: Array[String] = []
	for r: Dictionary in g.action_log:
		names.append(str(r["action"]))
	assert_eq(names, ["choose_country", "end_season", "orders_done", "end_season", "orders_done"] as Array[String])
	var sandbox := Game.new_game(ScenarioFixture.build()["map"] as MapData, 1)
	Season.run(sandbox)
	assert_eq(str(sandbox.action_log[1]["action"]), "orders_done", "a map-only game too")


func test_end_check_with_ai_only() -> void:
	var g := ScenarioFixture.game()
	assert_false(bool(Season.end_check(g)["ok"]), "P: countries, no player, not AI-only: refused")
	assert_true(g.watch())
	assert_true(bool(Season.end_check(g)["ok"]))
	assert_true(bool(Season.run(g)["ok"]))
	assert_eq(g.turn, 2)
