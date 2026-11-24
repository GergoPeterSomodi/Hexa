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
	# The transfer bumps the version once, and the new holder's exploring of the hex (the fog build: a
	# capture or cession marks discovery at once) bumps it again so cached views see the new sight.
	assert_true(g.version >= before + 1, "a developer transfer bumps the version (cached views)")
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


# ----- M4: weather, the district cache, the developer transfers, the new game's purse (task N4) -------------------------


func test_a_new_game_is_calm_has_a_cache_and_the_door_fields() -> void:
	var g := ScenarioFixture.game()
	assert_eq(g.weather, PackedByteArray([0, 0, 0]))
	assert_true(g.districts is DistrictCache)
	assert_eq(g.districts.size(), 0)
	for field: String in ["events", "action_log", "chronicle", "version", "view_cache", "districts"]:
		assert_true(Game.DOOR_FIELDS.has(field), field)


func test_new_scenario_sets_up_the_purse_the_stores_and_the_stats() -> void:
	var g := EconomyFixture.game()
	var c := Countries.by_tag(g, &"GEN")
	assert_eq([c.treasury, c.tax, c.short_mask, c.ledger_from], [610, 1, 0, 610])
	assert_eq(c.stock[0], 16)
	assert_eq(c.stock_from, c.stock)
	assert_eq(g.stats.goods, 16)
	assert_eq(g.districts.size(), 0, "the cache starts empty")
	var sandbox := Game.new_game(EconomyFixture.map(), 1, EconomyFixture.committed())
	assert_eq(sandbox.stats.goods, 0, "a map-only game has no goods")


func test_emit_of_hex_changed_touches_the_cache() -> void:
	var g := EconomyFixture.game()
	var hex := Vector2i(8, 13)
	var land := 0
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1:
			g.districts.base_of(g, i)
			land += 1
	assert_eq(g.districts.size(), land)
	var gone := 1
	for d: int in 6:
		if g.map.is_land(g.map.neighbour(hex, d)):
			gone += 1
	g.emit({"kind": "work_started", "hex": hex})
	assert_eq(g.districts.size(), land, "only hex_changed forgets")
	g.emit({"kind": "hex_changed", "hex": hex})
	assert_eq(g.districts.size(), land - gone, "the hex and its land neighbours")


func test_with_state_and_new_scenario_start_with_an_empty_cache() -> void:
	var g := EconomyFixture.game()
	g.districts.base_of(g, g.map.index_of(Vector2i(8, 13)))
	var other := Game.with_state(g.map, g.state, 1, g.defs)
	assert_eq(other.districts.size(), 0)


func test_dev_money_moves_the_purse_logs_and_clamps() -> void:
	var g := EconomyFixture.game()
	var c := Countries.by_tag(g, &"GEN")
	var v := g.version
	assert_true(g.dev_money(&"GEN", 500))
	assert_eq(c.treasury, 1110)
	assert_eq(g.version, v + 1)
	assert_eq(g.action_log[g.action_log.size() - 1], {"turn": 1, "action": "dev_money", "args": {"tag": "GEN", "amount": 500}})
	assert_eq(c.ledger_open[c.ledger_open.size() - 1]["why"], &"dev")
	assert_true(g.dev_money(&"GEN", -2000))
	assert_eq(c.treasury, -890, "the treasury may go below zero")
	assert_true(g.dev_money(&"GEN", 5000000000))
	assert_eq(c.treasury, -890 + Game.DEV_LIMIT, "an amount past the limit is cut")
	assert_eq(g.action_log[g.action_log.size() - 1]["args"]["amount"], Game.DEV_LIMIT, "and the log holds what was done")
	var before := g.digest()
	assert_false(g.dev_money(&"ZZZ", 5), "an unknown tag")
	assert_false(g.dev_money(&"", 5))
	assert_eq(g.digest(), before, "a refusal changes nothing")
	var sandbox := Game.new_game(EconomyFixture.map(), 1, EconomyFixture.committed())
	assert_false(sandbox.dev_money(&"GEN", 5), "a map-only game has no treasury")
	assert_true(sandbox.action_log.is_empty())


func test_dev_people_sets_the_people_logs_and_refuses() -> void:
	var g := PeopleFixture.genoa()
	var c := Countries.by_tag(g, &"GEN")
	var hex := Vector2i(6, 13)
	var i := g.map.index_of(hex)
	var was := g.state.people[i]
	var free := Vector2i(7, 13)
	g.dev_transfer([free] as Array[Vector2i], 0)
	var v := g.version
	assert_true(g.dev_people(hex, 2100))
	assert_eq(g.state.people[i], 2100)
	assert_eq(c.people_flows[People.FLOWS.find(&"dev")], 2100 - was)
	assert_eq(g.version, v + 1)
	assert_eq(g.action_log[g.action_log.size() - 1], {"turn": 1, "action": "dev_people", "args": {"hex": hex, "people": 2100}})
	var before := g.digest()
	var logged := g.action_log.size()
	assert_false(g.dev_people(hex, -1), "below zero")
	var sea := 0
	while g.map.land[sea] == 1:
		sea += 1
	assert_false(g.dev_people(g.map.hex_of(sea), 5), "the sea")
	assert_false(g.dev_people(free, 5), "unowned land")
	assert_false(g.dev_people(Vector2i(-1, 0), 5), "off the map")
	assert_false(g.dev_people(hex, People.PEOPLE_MAX + 1), "over the maximum")
	assert_eq(g.digest(), before, "a refusal changes nothing")
	assert_eq(g.action_log.size(), logged, "and logs nothing")
	var sandbox := Game.new_game(EconomyFixture.map(), 1, EconomyFixture.committed())
	assert_false(sandbox.dev_people(hex, 5), "a map-only game")
	assert_true(sandbox.action_log.is_empty())


func test_people_are_set_up_before_the_purse_in_new_scenario() -> void:
	var g := PeopleFixture.genoa()
	assert_eq(g.state.people_start, g.state.people)
	assert_eq(g.state.people_end, g.state.people)
	assert_gt(g.state.people[g.map.index_of(Vector2i(8, 13))], 0)
	var c := Countries.by_tag(g, &"GEN")
	assert_eq([c.people_flows.size(), c.food_fed, c.food_need], [People.FLOWS.size(), 1000, 0])
	assert_eq(c.treasury, 610, "the start treasury counts the people as M4 did")


func test_dev_goods_moves_the_stores_logs_and_never_below_zero() -> void:
	var g := EconomyFixture.game()
	var c := Countries.by_tag(g, &"GEN")
	assert_true(g.dev_goods(&"GEN", 12, 40))
	assert_eq(c.stock[12], 80)
	assert_eq(Stores.flow(c, 12, &"dev"), 40)
	assert_eq(g.action_log[g.action_log.size() - 1], {"turn": 1, "action": "dev_goods", "args": {"tag": "GEN", "good": 12, "amount": 40}})
	assert_true(g.dev_goods(&"GEN", 12, -1000))
	assert_eq(c.stock[12], 0, "a take is cut to what the stores hold")
	assert_eq(g.action_log[g.action_log.size() - 1]["args"]["amount"], -80)
	assert_false(g.dev_goods(&"GEN", 99, 1), "an unknown good")
	assert_false(g.dev_goods(&"GEN", -1, 1))
	assert_false(g.dev_goods(&"ZZZ", 12, 1))
	assert_true(g.dev_goods(&"GEN", 12, 5000000000))
	assert_eq(c.stock[12], Game.DEV_LIMIT, "an amount past the limit is cut")
	var sandbox := Game.new_game(EconomyFixture.map(), 1, EconomyFixture.committed())
	assert_false(sandbox.dev_goods(&"GEN", 12, 5))


func test_the_digest_carries_the_weather_and_the_money() -> void:
	var g := EconomyFixture.game()
	var d0 := g.digest()
	g.weather[1] = 2
	var d1 := g.digest()
	assert_ne(d1, d0)
	g.weather[1] = 0
	assert_eq(g.digest(), d0)
	g.dev_money(&"GEN", 1)
	assert_ne(g.digest(), d0, "a treasury is in the digest")
	assert_eq(EconomyFixture.game().digest(), d0, "same seed, same digest")


# ----- M8: watch and ai_only (m8-build-spec.md 4.12, 5.4) -------------------------------------------------------------------


func test_watch_makes_the_game_ai_only_during_the_pick_and_logs_it() -> void:
	var g := ScenarioFixture.game()
	var d0 := g.digest()
	assert_false(g.ai_only)
	assert_true(g.watch())
	assert_true(g.ai_only)
	assert_eq(g.player, &"")
	assert_eq(g.action_log, [{"turn": 1, "action": "watch", "args": {}}] as Array[Dictionary])
	assert_ne(g.digest(), d0, "ai_only is in the digest")
	assert_false(g.watch(), "once")
	assert_eq(g.action_log.size(), 1)


func test_p_watch_after_a_choice_or_in_a_sandbox_is_refused_and_changes_nothing() -> void:
	var g := ScenarioFixture.game()
	g.act("choose_country", {"tag": &"AAA"})
	var before := g.digest()
	var logged := g.action_log.size()
	var v := g.version
	assert_false(g.watch())
	assert_false(g.ai_only)
	assert_eq([g.digest(), g.action_log.size(), g.version], [before, logged, v])
	var sandbox := Game.new_game(ScenarioFixture.build()["map"] as MapData, 1)
	assert_false(sandbox.watch())
	assert_true(sandbox.action_log.is_empty())


func test_the_hook_is_not_state() -> void:
	var g := ScenarioFixture.game()
	var d0 := g.digest()
	g.orders = OrdersHook.new()
	assert_eq(g.digest(), d0)
	assert_false((Snapshot.of(g)["game"] as Dictionary).has("orders"))
