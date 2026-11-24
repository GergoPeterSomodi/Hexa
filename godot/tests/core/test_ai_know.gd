## AiKnow, the AI's door (docs/architecture/m8-build-spec.md 4.3, 5.5, 9): every function's filter, the act that checks first, and
## the draws that touch only the AI's stream. Each planted fault (P) is a situation the rule must refuse. Every game has its
## own copies of the definitions (ArmyFixture / AiFixture).
extends GutTest

var _hits := 0


func after_each() -> void:
	Actions.clear_test_actions()


func _game() -> Game:
	return AiFixture.duel()


## A Venetian army of `count` companies on `hex`, the sight refreshed.
func _venetian(g: Game, hex: Vector2i, count: int) -> Army:
	var a := WarFixture.army_at(g, AiFixture.VENICE, hex, count)
	Sight.refresh(g)
	return a


func test_seen_enemies_are_only_the_seen_and_banded_without_the_army() -> void:
	var g := _game()
	WarFixture.at_war(g, AiFixture.MILAN, AiFixture.VENICE)
	var seen_army := _venetian(g, AiKnow.hex_of(g, AiKnow.land_of(g, AiFixture.MILAN)[0]), 3)
	var ids: Array[int] = []
	for e: Dictionary in AiKnow.seen_enemies(g, AiFixture.MILAN):
		ids.append(int(e["army"]))
		assert_eq(e["men"], Knowledge.band(int(e["men"])), "banded")
		assert_false(e.has("order") or e.has("route") or e.has("kind") or e.get("army") is Army, "no order, route or kind")
		assert_true(Knowledge.sees(g, AiFixture.MILAN, e["hex"]), "only what it sees")
	assert_true(ids.has(seen_army.id), "the army on Milan's own land is seen")


func test_p_an_unseen_army_is_absent() -> void:
	var g := _game()
	WarFixture.at_war(g, AiFixture.MILAN, AiFixture.VENICE)
	var far := AiFixture.land_hex(g, AiFixture.VENICE, AiFixture.MILAN)
	assert_ne(far, Army.NO_HEX, "Venice has a hex Milan does not see")
	var hidden := _venetian(g, far, 5)
	assert_false(Knowledge.sees(g, AiFixture.MILAN, far))
	for e: Dictionary in AiKnow.seen_enemies(g, AiFixture.MILAN):
		assert_ne(int(e["army"]), hidden.id)


func test_seen_enemies_leave_out_armies_not_at_war_with_the_seat() -> void:
	var g := _game()
	var hex := AiKnow.hex_of(g, AiKnow.land_of(g, AiFixture.MILAN)[0])
	var guest := _venetian(g, hex, 2)
	assert_true(Knowledge.sees(g, AiFixture.MILAN, hex), "Milan sees it")
	for e: Dictionary in AiKnow.seen_enemies(g, AiFixture.MILAN):
		assert_ne(int(e["army"]), guest.id, "at peace: not an enemy")
	WarFixture.at_war(g, AiFixture.MILAN, AiFixture.VENICE)
	var ids: Array[int] = []
	for e: Dictionary in AiKnow.seen_enemies(g, AiFixture.MILAN):
		ids.append(int(e["army"]))
	assert_true(ids.has(guest.id), "at war: an enemy")


## AiFixture.duel with every country thin (its land sight only): far countries are unknown (FG5; north Italy knows all).
func _game_thin() -> Game:
	var g := AiFixture.duel()
	for c: Country in g.countries:
		if c != null and c.tag != &"":
			FogFixture.thin(g, c.tag, 0)
	return g


func test_men_of_is_minus_one_for_a_country_it_does_not_know() -> void:
	var g := _game_thin()
	var stranger := &""
	for c: Country in g.countries:
		if c.tag != AiFixture.MILAN and not Knowledge.knows(g, AiFixture.MILAN, c.tag):
			stranger = c.tag
			break
	assert_ne(stranger, &"", "a country Milan does not know")
	assert_eq(AiKnow.men_of(g, AiFixture.MILAN, stranger), -1)
	for n: StringName in AiKnow.neighbours(g, AiFixture.MILAN):
		assert_eq(AiKnow.men_of(g, AiFixture.MILAN, n), Knowledge.men_of(g, AiFixture.MILAN, n), "a neighbour is known, banded")
		assert_gte(AiKnow.men_of(g, AiFixture.MILAN, n), 0)


func _fortress(g: Game) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if Occupation.fortress_level(g, hex) > 0 and not Occupation.is_occupied(g, hex):
			return hex
	return Army.NO_HEX


func test_garrison_estimate_is_exact_for_the_holder_and_full_for_a_stranger() -> void:
	var g := _game()
	var hex := _fortress(g)
	assert_ne(hex, Army.NO_HEX, "the scenario has a fortress")
	var holder := Occupation.controller_tag(g, hex)
	Occupation.set_garrison(g, hex, 60)
	assert_eq(AiKnow.garrison_estimate(g, holder, hex), 60, "own: exact")
	for c: Country in g.countries:
		# FG5 (R19): a discovered fortress is exact for every viewer; an undiscovered one is -1 (unknown), never the full garrison.
		var want := Occupation.garrison_of(g, hex) if Knowledge.discovered(g, c.tag, hex) else -1
		assert_eq(AiKnow.garrison_estimate(g, c.tag, hex), want, "a discovered fortress is exact; an undiscovered one is -1")
		assert_eq(AiKnow.garrison_estimate(g, c.tag, hex), int(Knowledge.garrison_known(g, c.tag, hex)["men"]))
	assert_eq(AiKnow.garrison_estimate(g, holder, Army.NO_HEX), 0, "no fortress, none")


func test_forecast_uses_the_estimate_and_p_the_real_garrison_does_not_move_it() -> void:
	var g := _game()
	var hex := _fortress(g)
	var holder := Occupation.controller_tag(g, hex)
	var viewer := &""
	for c: Country in g.countries:
		if c.tag != holder and not Sight.sees(g, c.tag, hex):
			viewer = c.tag
			break
	assert_ne(viewer, &"")
	var estimate := AiKnow.garrison_estimate(g, viewer, hex)
	assert_eq(AiKnow.forecast(g, viewer, hex, 2000, 2), Sieges.forecast_for(g, hex, estimate, 2000, 2, 0, 0))
	var before := AiKnow.forecast(g, viewer, hex, 2000, 2)
	Occupation.set_garrison(g, hex, 1)
	g.version += 1
	assert_eq(AiKnow.forecast(g, viewer, hex, 2000, 2), before, "an unseen fortress is counted full whatever it holds")


func test_act_checks_first_and_never_acts_on_a_refusal() -> void:
	var g := _game()
	var hook := AiFixture.solo(g, AiFixture.MILAN)
	_hits = 0
	Actions.register_test_action("ai_probe", func(_g: Game, _a: Dictionary) -> Dictionary: return {"ok": false, "reason": "no"},
		func(_g: Game, _a: Dictionary) -> Dictionary:
			_hits += 1
			return {"ok": true, "reason": ""})
	var verdict := AiKnow.act(hook, g, AiFixture.MILAN, "ai_probe", {})
	assert_false(bool(verdict["ok"]))
	assert_eq(_hits, 0, "its do is not called")
	assert_eq(hook.refusals(), 1)


func test_act_calls_the_judge_adds_the_seats_tag_and_logs_the_act() -> void:
	var g := _game()
	var hook := AiFixture.solo(g, AiFixture.MILAN)
	var told: Array[Dictionary] = []
	hook.judge = func(t: StringName, action: String, args: Dictionary, verdict: Dictionary, result: Dictionary) -> void:
		told.append({"tag": t, "action": action, "args": args, "verdict": verdict, "result": result})
	var seen_tag := []
	Actions.register_test_action("ai_probe", func(_g: Game, _a: Dictionary) -> Dictionary: return {"ok": true, "reason": ""},
		func(_g: Game, a: Dictionary) -> Dictionary:
			seen_tag.append(a.get("tag"))
			return {"ok": true, "reason": ""})
	var log_before := g.action_log.size()
	var result := AiKnow.act(hook, g, AiFixture.MILAN, "ai_probe", {"n": 1})
	assert_true(bool(result["ok"]))
	assert_eq(seen_tag, [AiFixture.MILAN], "the tag is added")
	assert_eq(told.size(), 1)
	assert_eq([told[0]["tag"], told[0]["action"], told[0]["args"]["tag"]], [AiFixture.MILAN, "ai_probe", AiFixture.MILAN])
	assert_true(bool(told[0]["verdict"]["ok"]) and bool(told[0]["result"]["ok"]))
	assert_eq(g.action_log.size(), log_before + 1, "through the game's own act")
	assert_eq(hook.refusals(), 0)


func test_check_adds_the_tag_and_changes_nothing() -> void:
	var g := _game()
	var before := g.digest()
	var verdict := AiKnow.check(g, AiFixture.MILAN, "set_tax", {"level": 1})
	assert_true(verdict.has("ok"))
	assert_eq(g.digest(), before)
	assert_false(bool(AiKnow.check(g, AiFixture.MILAN, "no_such_action", {})["ok"]))


func test_roll_and_jitter_draw_only_the_ai_stream() -> void:
	var g := _game()
	var world := g.luck.world.get_state()
	var decor := g.luck.decor.get_state()
	var ai := g.luck.ai.get_state()
	for _n: int in 20:
		var r := AiKnow.roll(g)
		assert_true(r >= 1 and r <= 1000)
		var j := AiKnow.jitter(g, 50)
		assert_true(j >= 950 and j <= 1050)
	assert_ne(g.luck.ai.get_state(), ai, "the AI's stream moved")
	assert_eq(g.luck.world.get_state(), world, "P: the world's luck is untouched")
	assert_eq(g.luck.decor.get_state(), decor)


func test_the_own_country_reads() -> void:
	var g := _game()
	var m := AiFixture.MILAN
	assert_eq(AiKnow.treasury(g, m), Countries.by_tag(g, m).treasury)
	assert_eq(AiKnow.army_upkeep(g, m), Military.upkeep_country(g, m))
	assert_eq(AiKnow.slots_free(g, m), Works.slots(g, m) - Works.in_use(g, m))
	assert_true(AiKnow.upkeep(g, m) >= 0)
	assert_gt(AiKnow.people(g, m), 0)
	var settlements := AiKnow.settlements(g, m)
	assert_gt(settlements.size(), 0)
	for k: int in range(1, settlements.size()):
		assert_gt(g.map.index_of(settlements[k]), g.map.index_of(settlements[k - 1]), "hex index order")
	for hex: Vector2i in AiKnow.depots(g, m):
		assert_true(settlements.has(hex) and Supply.is_depot(g, m, hex))
	assert_eq(AiKnow.tax_level(g, m), Countries.by_tag(g, m).tax)


func test_work_candidates_are_owned_free_and_in_index_order() -> void:
	var g := _game()
	var m := AiFixture.MILAN
	var list := AiKnow.work_candidates(g, m)
	assert_gt(list.size(), 0)
	var last := -1
	for hex: Vector2i in list:
		var i := g.map.index_of(hex)
		assert_gt(i, last, "hex index order")
		last = i
		assert_eq(AiKnow.owner_of(g, hex), m)
		assert_null(g.state.work_at(hex))
	var busy := list[0]
	var w := Work.new()
	w.hex = busy
	w.tag = m
	g.state.works.append(w)
	assert_false(AiKnow.work_candidates(g, m).has(busy), "a hex with a work under way is no candidate")


func test_capital_off_the_map_is_no_hex_and_the_public_reads() -> void:
	var g := _game()
	var m := AiFixture.MILAN
	var c := Countries.by_tag(g, m)
	assert_eq(AiKnow.capital_of(g, m), c.capital)
	c.capital = Country.NO_HEX
	assert_eq(AiKnow.capital_of(g, m), Army.NO_HEX)
	assert_eq(AiKnow.enemies(g, m).size(), 0)
	WarFixture.at_war(g, m, AiFixture.VENICE)
	assert_eq(AiKnow.enemies(g, m), [AiFixture.VENICE] as Array[StringName])
	assert_eq(AiKnow.wars_of(g, m)[0]["enemy"], AiFixture.VENICE)
	assert_false(AiKnow.at_war_with_other(g, m, AiFixture.VENICE), "Venice's only war is Milan's")
	WarFixture.at_war(g, AiFixture.VENICE, AiFixture.GENOA)
	assert_true(AiKnow.at_war_with_other(g, m, AiFixture.VENICE))
	assert_eq(AiKnow.score(g, m, AiFixture.VENICE), Wars.score(g, m, AiFixture.VENICE))
	assert_eq(AiKnow.hex_distance(Vector2i(2, 2), Vector2i(2, 2)), 0)
