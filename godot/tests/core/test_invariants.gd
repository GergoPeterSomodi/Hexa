## The invariants of the soak (docs/architecture/m8-build-spec.md 4.17, 9): three AI-only seasons break none, and each invariant has a
## planted fault that breaks it (P each): a turn that did not move, a treasury edited outside a ledger, a stock below 0, a hex below
## 0 people, a person from nowhere, a land hex with no owner, a company at 0 men, two countries on a hex, a live battle at idle, a
## garrison over full, a morale past 1,000, a war past 40 seasons (two live wars of a pair, a war in a truce), a chronicle out of
## turn order, a stats row missing, the judge's problem and the logger's error. The soak's counting judge is read too.
extends GutTest


func _has(lines: PackedStringArray, name: String) -> bool:
	for line: String in lines:
		if line.begins_with(name + ":"):
			return true
	return false


## True when the planted fault breaks `name`. `pre` plants before the season (and gets the before dictionary), else after it.
func _breaks(name: String, plant: Callable, pre: bool = false) -> bool:
	var g := AiFixture.watch()
	g.events.clear()
	var before := Invariants.before(g)
	if pre:
		plant.call(g, before)
	Season.run(g)
	if not pre:
		plant.call(g, before)
	var lines := Invariants.check(g, before)
	if not _has(lines, name):
		gut.p("planted %s: %s" % [name, str(lines)])
	return _has(lines, name)


func _land_hex(g: Game) -> int:
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1:
			return i
	return -1


func _milan_hex(g: Game) -> Vector2i:
	return g.map.hex_of(AiKnow.land_of(g, AiFixture.MILAN)[0])


func test_a_clean_game_breaks_nothing_and_the_checks_change_nothing() -> void:
	var g := AiFixture.watch()
	for _n: int in 3:
		g.events.clear()
		var before := Invariants.before(g)
		var digest := g.digest()
		assert_eq(g.digest(), digest, "before changes nothing")
		Season.run(g)
		var lines := Invariants.check(g, before)
		assert_eq(lines.size(), 0, "no invariant broken: %s" % str(lines))
	assert_eq(Invariants.NAMES.size(), 15)


func test_p_turn() -> void:
	assert_true(_breaks("turn", func(g: Game, _b: Dictionary) -> void: g.turn += 1))


func test_p_money_a_treasury_edited_outside_a_ledger() -> void:
	assert_true(_breaks("money", func(g: Game, _b: Dictionary) -> void: g.countries[0].treasury += 5, true))


func test_p_money_a_line_with_a_reason_not_in_the_list() -> void:
	assert_true(_breaks("money", func(g: Game, _b: Dictionary) -> void:
		(g.countries[0].ledger_closed["lines"] as Array).append({"why": &"bogus", "hex": Vector2i(-1, -1), "amount": 0, "count": 1})))


func test_p_goods_a_stock_below_zero() -> void:
	assert_true(_breaks("goods", func(g: Game, _b: Dictionary) -> void: g.countries[0].stock[0] = -1))


func test_p_goods_a_stock_changed_outside_its_flows() -> void:
	assert_true(_breaks("goods", func(g: Game, _b: Dictionary) -> void: g.countries[0].goods_closed["closing"][0] += 3))


func test_p_people_below_zero_and_on_the_sea() -> void:
	assert_true(_breaks("people", func(g: Game, _b: Dictionary) -> void: g.state.people[_land_hex(g)] = -4))
	assert_true(_breaks("people", func(g: Game, _b: Dictionary) -> void:
		for i: int in g.map.hex_count():
			if g.map.land[i] != 1:
				g.state.people[i] = 7
				return))


func test_p_men_a_person_from_nowhere() -> void:
	assert_true(_breaks("men", func(g: Game, _b: Dictionary) -> void: g.state.people[_land_hex(g)] += 1))


func test_p_districts_no_owner_a_stranger_occupier_a_changed_land_count() -> void:
	assert_true(_breaks("districts", func(g: Game, _b: Dictionary) -> void: g.state.owner[_land_hex(g)] = 0))
	assert_true(_breaks("districts", func(g: Game, _b: Dictionary) -> void:
		var i := _land_hex(g)
		g.state.occupier[i] = g.countries[0].id if int(g.state.owner[i]) != g.countries[0].id else g.countries[1].id
		g.wars.clear()))
	assert_true(_breaks("districts", func(_g: Game, b: Dictionary) -> void: b["land"] = int(b["land"]) + 1))


func test_p_armies_no_men_two_countries_too_many_companies_the_sea() -> void:
	assert_true(_breaks("armies", func(g: Game, _b: Dictionary) -> void:
		WarFixture.army_at(g, AiFixture.MILAN, _milan_hex(g), 1).units[0].men = 0))
	assert_true(_breaks("armies", func(g: Game, _b: Dictionary) -> void:
		WarFixture.army_at(g, AiFixture.MILAN, _milan_hex(g), 1)
		WarFixture.army_at(g, AiFixture.GENOA, _milan_hex(g), 1)))
	assert_true(_breaks("armies", func(g: Game, _b: Dictionary) -> void:
		WarFixture.army_at(g, AiFixture.MILAN, _milan_hex(g), g.defs.stack_limit + 1)))
	assert_true(_breaks("armies", func(g: Game, _b: Dictionary) -> void:
		var a := WarFixture.army_at(g, AiFixture.MILAN, _milan_hex(g), 1)
		for i: int in g.map.hex_count():
			if g.map.land[i] != 1:
				a.hex = g.map.hex_of(i)
				return))


func test_p_battles_a_live_battle_at_idle() -> void:
	assert_true(_breaks("battles", func(g: Game, _b: Dictionary) -> void: g.battles.append(Battle.new())))


func test_p_garrisons_over_full_and_an_occupied_fortress_still_held() -> void:
	assert_true(_breaks("garrisons", func(g: Game, _b: Dictionary) -> void:
		var i := g.war_cache.fortresses(g)[0]
		g.state.garrison[i] = Occupation.garrison_full(g, g.map.hex_of(i)) + 1))
	assert_true(_breaks("garrisons", func(g: Game, _b: Dictionary) -> void:
		var i := g.war_cache.fortresses(g)[0]
		g.state.garrison[i] = 5
		g.state.occupier[i] = g.countries[0].id if int(g.state.owner[i]) != g.countries[0].id else g.countries[1].id))


func test_p_morale_past_the_top() -> void:
	assert_true(_breaks("morale", func(g: Game, _b: Dictionary) -> void:
		WarFixture.army_at(g, AiFixture.MILAN, _milan_hex(g), 1).units[0].morale = 1001))


func test_p_wars_past_forty_two_live_wars_and_a_war_in_a_truce() -> void:
	assert_true(_breaks("wars", func(g: Game, _b: Dictionary) -> void:
		WarFixture.at_war(g, AiFixture.MILAN, AiFixture.GENOA).start_turn = g.turn - 41))
	assert_true(_breaks("wars", func(g: Game, _b: Dictionary) -> void:
		WarFixture.at_war(g, AiFixture.MILAN, AiFixture.VENICE)
		WarFixture.at_war(g, AiFixture.VENICE, AiFixture.MILAN)))
	assert_true(_breaks("wars", func(g: Game, _b: Dictionary) -> void:
		WarFixture.ended(g, AiFixture.MILAN, AiFixture.GENOA, g.turn)
		WarFixture.at_war(g, AiFixture.MILAN, AiFixture.GENOA)))


func test_p_chronicle_out_of_order_and_too_long() -> void:
	assert_true(_breaks("chronicle", func(g: Game, _b: Dictionary) -> void:
		g.chronicle.entries.append({"kind": "x", "turn": 9})
		g.chronicle.entries.append({"kind": "x", "turn": 2})))
	assert_true(_breaks("chronicle", func(g: Game, _b: Dictionary) -> void:
		for _n: int in Chronicle.KEEP + 1:
			g.chronicle.entries.append({"kind": "x", "turn": 99})))


func test_p_stats_a_row_missing() -> void:
	assert_true(_breaks("stats", func(g: Game, _b: Dictionary) -> void: g.stats.count -= 1))


func test_p_contract_and_errors_come_from_the_soak() -> void:
	var g := AiFixture.watch()
	var before := Invariants.before(g)
	Season.run(g)
	var lines := Invariants.check(g, before, {"contract": PackedStringArray(["MLO build acted on a refused check"]), "errors": 2})
	assert_true(_has(lines, "contract"))
	assert_true(_has(lines, "errors"))


func test_the_soaks_judge_counts_a_broken_contract() -> void:
	var judge := SoakGame.Judge.new()
	judge.on_act(&"MLO", "build", {"tag": &"MLO"}, {"ok": true}, {"ok": true})
	assert_eq(judge.problems.size(), 0, "a good act")
	assert_eq(int(judge.works["MLO"]), 1)
	judge.on_act(&"MLO", "march", {"tag": &"MLO"}, {"ok": false}, {"ok": true})
	judge.on_act(&"MLO", "march", {"tag": &"MLO"}, {"ok": true}, {"ok": false, "reason": "no"})
	judge.on_act(&"MLO", "march", {"tag": &"GEN"}, {"ok": true}, {"ok": true})
	assert_eq(judge.take_problems().size(), 3, "a refused check acted on, a failed act, another seat's tag")
	assert_eq(judge.problems.size(), 0, "taken")
