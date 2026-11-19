## The season table (docs/architecture/m3-build-spec.md 4.2, 9).
extends GutTest


func test_phases_are_pinned() -> void:
	assert_eq(Season.PHASES, [&"works", &"stats", &"calendar"] as Array[StringName])


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
	var last := g.action_log[g.action_log.size() - 1]
	assert_eq(last["action"], "end_season")
	assert_eq(int(last["turn"]), 1, "the season that ended")


func test_run_phase_unknown_does_nothing() -> void:
	var g := ScenarioFixture.game()
	var before := g.digest()
	Season.run_phase(g, &"nonsense")
	assert_eq(g.digest(), before)
	Season.run_phase(g, &"calendar")
	assert_eq(g.turn, 2)
	Season.run_phase(g, &"works")
	Season.run_phase(g, &"stats")
	assert_eq(g.turn, 2)
