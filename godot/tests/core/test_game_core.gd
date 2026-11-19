## The door's bookkeeping (docs/architecture/m3-build-spec.md 4.4, 4.5, 5.4, 9): emit, act, version, the new fields,
## the digest, ViewCache.
extends GutTest


func test_emit_queues_all_and_chronicles_only_notable() -> void:
	var g := ScenarioFixture.game()
	g.emit({"kind": "hex_changed", "hex": Vector2i(1, 1)})
	g.emit({"kind": "country_chosen", "tag": &"AAA"})
	assert_eq(g.events.size(), 2)
	assert_eq(int(g.events[0]["turn"]), 1, "stamped with the turn")
	assert_eq(g.chronicle.entries.size(), 1)
	assert_eq(str(g.chronicle.entries[0]["kind"]), "country_chosen")
	g.turn = 5
	g.emit({"kind": "hex_changed", "hex": Vector2i(1, 1), "turn": 2})
	assert_eq(int(g.events[2]["turn"]), 2, "a given turn stays")


func test_act_records_only_accepted_actions() -> void:
	var g := ScenarioFixture.game()
	var v0 := g.version
	assert_false(bool(g.act("choose_country", {"tag": &"ZZZ"})["ok"]))
	assert_eq(g.action_log.size(), 0)
	assert_eq(g.version, v0)
	assert_true(bool(g.act("choose_country", {"tag": &"AAA"})["ok"]))
	assert_eq(g.action_log.size(), 1)
	assert_eq(g.action_log[0]["action"], "choose_country")
	assert_eq(int(g.action_log[0]["turn"]), 1)
	assert_true(g.action_log[0]["args"]["tag"] is String, "plain args")
	assert_eq(g.version, v0 + 1)
	assert_false(bool(g.act("choose_country", {"tag": &"BBB"})["ok"]))
	assert_eq(g.version, v0 + 1)


func test_version_rises_per_season() -> void:
	var g := ScenarioFixture.game()
	g.act("choose_country", {"tag": &"AAA"})
	var v := g.version
	Season.run(g)
	assert_eq(g.version, v + 1)


func test_new_game_and_new_scenario_fields() -> void:
	var f := ScenarioFixture.build()
	var sandbox := Game.new_game(f["map"] as MapData, 5)
	assert_eq(sandbox.start_year, 1480)
	assert_eq(sandbox.turn, 1)
	assert_not_null(sandbox.luck)
	assert_false(sandbox.has_countries())
	assert_null(sandbox.defs)
	var with_defs := Game.new_game(f["map"] as MapData, 5, f["defs"] as GameDefs)
	assert_not_null(with_defs.defs)
	var s := f["scenario"] as ScenarioDef
	s.year = 1500
	var g := Game.new_scenario(f["map"] as MapData, f["defs"] as GameDefs, s, 5)
	assert_eq(g.start_year, 1500)
	assert_eq(g.turn, 1)
	assert_not_null(g.luck)
	assert_true(g.has_countries())
	assert_eq(g.date_text(), "Spring 1500")
	assert_true(Game.DOOR_FIELDS.has("chronicle"))


func test_digest_moves_with_turn_chronicle_and_luck() -> void:
	var g := ScenarioFixture.game()
	var d0 := g.digest()
	g.turn = 2
	var d1 := g.digest()
	assert_ne(d1, d0)
	g.chronicle.add({"kind": "work_started", "turn": 2})
	var d2 := g.digest()
	assert_ne(d2, d1)
	g.luck.world.randi_range(0, 9)
	assert_ne(g.digest(), d2)
	assert_eq(ScenarioFixture.game().digest(), d0, "same seed, same digest")


func test_dev_transfer_logs() -> void:
	var g := ScenarioFixture.game()
	var hex := ScenarioFixture.BETA_CAPITAL
	var before := g.version
	assert_eq(g.dev_transfer([hex], 1), 1)
	assert_eq(g.version, before + 1, "a developer transfer bumps the version (cached views)")
	assert_eq(g.action_log.size(), 1)
	assert_eq(g.action_log[0]["action"], "dev_transfer")
	assert_eq(int(g.action_log[0]["args"]["to_id"]), 1)


func test_view_cache_holds_64() -> void:
	var c := ViewCache.new()
	for i: int in 70:
		c.get_or_make([i], func() -> int: return i)
	assert_eq(c.size(), ViewCache.SIZE)
	var calls := [0]
	c.get_or_make([69], func() -> int:
		calls[0] += 1
		return 0)
	assert_eq(calls[0], 0, "a held key is not made again")
	c.get_or_make([0], func() -> int:
		calls[0] += 1
		return 0)
	assert_eq(calls[0], 1, "the oldest was dropped")
	c.clear()
	assert_eq(c.size(), 0)
