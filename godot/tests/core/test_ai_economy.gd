## The AI's money and works (docs/architecture/m8-build-spec.md 4.6, 4.7, 4.16 (a), 9): every row of the tax table with a planted
## fault each, the prior of the four kinds of candidate, the scan's window and offset, the cards (order, jitter draws, payback
## limit, reserve, works a season, W), the priorities, works at war, fortify, and Genoa's first turn. Every planted number is in
## a duplicate of the sub-resource (the AI def, a temperament): the committed ones are shared and never mutated.
@warning_ignore_start("integer_division")
extends GutTest

const GEN := &"GEN"
const MLO := &"MLO"
const SAV := &"SAV"
const LOW := 0
const NORMAL := 1
const HIGH := 2


func _hook() -> AiTurn:
	return AiTurn.new()


func _country(g: Game, tag: StringName = GEN) -> Country:
	return Countries.by_tag(g, tag)


## 1-company armies of `tag` on distinct land hexes of its own: each costs 6 ducats a season.
func _burden(g: Game, tag: StringName, count: int, size: int = 1) -> void:
	var made := 0
	for i: int in AiKnow.land_of(g, tag):
		var hex := g.map.hex_of(i)
		if g.map.is_land(hex) and made < count:
			WarFixture.army_at(g, tag, hex, size)
			made += 1


## Runs the tax step alone: the treasury, the level, a war with Milan, the armies' burden and the brief's flags as given; the
## row it chose (from the trace), the level after and whether it acted.
func _tax(money: int, level: int, war: bool = false, armies: int = 0, flags: Dictionary = {}) -> Dictionary:
	var g := AiFixture.watch()
	var hook := _hook()
	var b := AiBrief.make(g, GEN)
	if war:
		WarFixture.at_war(g, GEN, MLO)
	_burden(g, GEN, armies)
	if bool(flags.get("heavy", false)):
		_burden(g, GEN, 4, 8)
	_country(g).treasury = money
	_country(g).tax = level
	b.reserve = 96
	b.hungry = bool(flags.get("hungry", false))
	b.food_soon = bool(flags.get("food_soon", false))
	b.wanted_cost = int(flags.get("wanted", 0))
	g.version += 1  # the planted state is a change as an action makes it: the brief's cached previews must not serve the old one
	AiEconomy.tax(hook, g, b, 0)
	var line := ""
	var acted := false
	for text: String in hook.trace_of(GEN):
		if text.begins_with("tax:"):
			line = text
		if text.begins_with("did set_tax"):
			acted = true
	var row := int(line.split("row ")[1].split(" ")[0])
	return {"row": row, "level": AiKnow.tax_level(g, GEN), "acted": acted, "line": line}


func _assert_tax(got: Dictionary, row: int, level: int, label: String) -> void:
	assert_eq([got["row"], got["level"]], [row, level], "%s: %s" % [label, got["line"]])


# ----- 4.6's table: every row, and the neighbours of each row's edge ---------------------------------------------------------


func test_row_1_a_negative_treasury_is_high() -> void:
	_assert_tax(_tax(-1, NORMAL), 1, HIGH, "T under 0")
	var at_zero := _tax(0, NORMAL)
	assert_ne(at_zero["row"], 1, "0 is not under 0")


func test_row_2_at_war_under_the_reserve_is_high() -> void:
	_assert_tax(_tax(95, NORMAL, true), 2, HIGH, "war, T 95 < R 96")
	_assert_tax(_tax(96, NORMAL, true), 7, NORMAL, "war, T = R")
	_assert_tax(_tax(95, NORMAL, false), 7, NORMAL, "P: at peace T < R is not row 2")


func test_row_3_a_losing_season_under_twice_the_reserve_is_high() -> void:
	_assert_tax(_tax(191, NORMAL, false, 0, {"heavy": true}), 3, HIGH, "N_normal < 0, T 191 < 2R")
	var at_edge := _tax(192, NORMAL, false, 0, {"heavy": true})
	assert_ne(at_edge["row"], 3, "T = 2R is not row 3: " + String(at_edge["line"]))
	var healthy := _tax(191, NORMAL, false, 0)
	assert_ne(healthy["row"], 3, "P: a season that earns is not row 3")


func test_row_4_high_stays_until_one_and_a_half_reserves_and_a_season_that_earns() -> void:
	_assert_tax(_tax(143, HIGH), 4, HIGH, "High, T 143 < 1.5 R")
	_assert_tax(_tax(144, HIGH), 7, NORMAL, "P: High is not kept at T = 1.5 R with a net that earns")
	_assert_tax(_tax(400, HIGH, false, 0, {"heavy": true}), 4, HIGH, "High, T 400 but N_normal < 0")
	var back := _tax(144, HIGH)
	assert_true(back["acted"], "the level changed: set_tax is asked")


func test_row_5_low_at_peace_with_two_reserves_and_nothing_wanted() -> void:
	var got := _tax(192, NORMAL)
	_assert_tax(got, 5, LOW, "T = 2R")
	assert_true(got["acted"])
	_assert_tax(_tax(191, NORMAL), 7, NORMAL, "T 191 < 2R")
	_assert_tax(_tax(300, NORMAL, true), 7, NORMAL, "P: a Low is never taken at war")
	_assert_tax(_tax(300, NORMAL, false, 0, {"hungry": true}), 7, NORMAL, "hungry")
	_assert_tax(_tax(300, NORMAL, false, 0, {"food_soon": true}), 7, NORMAL, "food soon")
	_assert_tax(_tax(300, NORMAL, false, 0, {"wanted": 40}), 7, NORMAL, "works wanted (W 40)")
	_assert_tax(_tax(300, NORMAL, false, 11), 7, NORMAL, "N_low under 0 (11 armies: low -3, normal +18)")


func test_row_6_low_stays_at_peace_with_one_and_a_half_reserves() -> void:
	var stays := _tax(144, LOW)
	_assert_tax(stays, 6, LOW, "Low, T = 1.5 R")
	assert_false(stays["acted"], "the level is the same: no set_tax")
	_assert_tax(_tax(143, LOW), 7, NORMAL, "T 143 < 1.5 R")
	_assert_tax(_tax(144, LOW, true), 7, NORMAL, "at war")
	_assert_tax(_tax(144, LOW, false, 0, {"wanted": 1}), 7, NORMAL, "W > 0")


func test_row_7_otherwise_normal() -> void:
	var stays := _tax(100, NORMAL)
	_assert_tax(stays, 7, NORMAL, "Normal stays")
	assert_false(stays["acted"])
	_assert_tax(_tax(100, LOW), 7, NORMAL, "Low rises to Normal")


func test_the_first_row_that_applies_wins() -> void:
	_assert_tax(_tax(-50, HIGH, true, 0, {"heavy": true}), 1, HIGH, "rows 1 to 4 all apply: row 1")
	_assert_tax(_tax(50, LOW, true), 2, HIGH, "rows 2 and 7: row 2")


func test_the_tax_line_names_its_numbers() -> void:
	var line: String = _tax(192, NORMAL)["line"]
	for part: String in ["T 192", "R 96", "W 0", "N_low 63", "N_normal 85", "at peace", "level Normal", "row 5", "Low"]:
		assert_true(line.contains(part), "%s in %s" % [part, line])


# ----- the prior ------------------------------------------------------------------------------------------------------------


func test_the_prior_of_the_four_kinds_of_candidate_of_4_16_a() -> void:
	var g := AiFixture.watch()
	var b := AiBrief.make(g, GEN)
	var timber := {"action": &"build", "family": 10}
	assert_eq(AiEconomy.prior(g, b, Vector2i(8, 11), timber), 300, "timber first stage on frost woods: 12 over 40")
	assert_eq(AiEconomy.prior(g, b, Vector2i(8, 12), timber), 300)
	assert_eq(AiEconomy.prior(g, b, Vector2i(9, 12), timber), 300)
	assert_eq(AiEconomy.prior(g, b, Vector2i(10, 13), timber), 300, "mild: the same 18 loads")
	assert_eq(AiEconomy.prior(g, b, Vector2i(7, 12), {"action": &"upgrade", "family": 7}), 106, "the vineyard's third stage: 31 over 290")
	assert_eq(AiEconomy.prior(g, b, Vector2i(8, 13), {"action": &"upgrade", "family": 1}), 245, "walled town to city: 260 over 1,060")
	assert_eq(AiEconomy.prior(g, b, Vector2i(9, 13), {"action": &"upgrade", "family": 10}), 55, "timber's third stage")
	assert_eq(AiEconomy.prior(g, b, Vector2i(8, 11), {"action": &"build", "family": 2}), 0, "a castle is a fortify candidate only")
	assert_eq(AiEconomy.prior(g, b, Vector2i(8, 11), {"action": &"build", "family": 0}), 0, "no family")


func test_p_a_planted_price_moves_the_prior() -> void:
	var d := EconomyFixture.defs(true, true)
	var goods: Array[GoodDef] = []
	for good: GoodDef in d.goods:
		goods.append(good.duplicate() as GoodDef)
	d.goods = goods
	d.goods[d.good_id(&"timber")].price_milli = 2000
	var g := AiFixture.watch(d)
	var b := AiBrief.make(g, GEN)
	assert_gt(AiEconomy.prior(g, b, Vector2i(8, 11), {"action": &"build", "family": 10}), 300, "dearer timber is worth more")


# ----- the scan -------------------------------------------------------------------------------------------------------------


func _small_scan_game() -> Game:
	var d := EconomyFixture.defs(true, true)
	d.ai = d.ai.duplicate() as AiDef
	d.ai.scan_hexes = 6
	d.ai.scan_per_step = 3
	return AiFixture.watch(d)


func _hexes_of(b: AiBrief) -> Dictionary:
	var out := {}
	for e: Dictionary in b.cards:
		out[e["hex"]] = true
	return out


func test_the_scan_looks_at_its_window_from_the_turn_offset() -> void:
	for turn: int in [1, 2]:
		var g := _small_scan_game()
		g.turn = turn
		var hook := _hook()
		var b := AiBrief.make(g, GEN)
		var list := AiKnow.work_candidates(g, GEN)
		assert_eq(list.size(), 11, "Genoa's candidates in 1480")
		var offset := (turn * 6) % 11
		var first: Dictionary = {}
		var second: Dictionary = {}
		for j: int in 3:
			first[list[(offset + j) % 11]] = true
			second[list[(offset + 3 + j) % 11]] = true
		AiEconomy.works_scan(hook, g, b, 0)
		assert_false(b.cards.is_empty())
		for hex: Vector2i in _hexes_of(b):
			assert_true(first.has(hex), "turn %d step 0 looked at %s" % [turn, hex])
		AiEconomy.works_scan(hook, g, b, 1)
		for hex: Vector2i in _hexes_of(b):
			assert_true(first.has(hex) or second.has(hex), "turn %d step 1 looked at %s" % [turn, hex])
		assert_false(_hexes_of(b).has(list[(offset + 6) % 11]), "the hex after the window is not scanned")
		assert_true(hook.trace_of(GEN)[0].contains("offset %d" % offset), hook.trace_of(GEN)[0])


func test_with_the_real_numbers_one_scan_covers_the_eleven_once() -> void:
	var g := AiFixture.watch()
	var hook := _hook()
	var b := AiBrief.make(g, GEN)
	AiEconomy.works_scan(hook, g, b, 0)
	AiEconomy.works_scan(hook, g, b, 1)
	var seen := _hexes_of(b)
	for hex: Vector2i in AiKnow.work_candidates(g, GEN):
		assert_true(seen.has(hex), "scanned %s" % hex)
	var keys := {}
	for e: Dictionary in b.cards:
		var key := "%s:%d" % [e["hex"], int(e["option"]["family"])]
		assert_false(keys.has(key), "no option twice: " + key)
		keys[key] = true
		assert_gt(int(e["prior"]), 0, "a prior of 0 or less is never kept")


func test_with_no_free_slot_the_works_steps_end_at_once() -> void:
	var g := AiFixture.watch()
	var hook := _hook()
	AiFixture.seat(g, GEN)
	assert_eq(AiKnow.slots_free(g, GEN), 0, "two works begun fill the two slots")
	var again := AiBrief.make(g, GEN)
	for step: int in 2:
		AiEconomy.works_scan(hook, g, again, step)
	AiEconomy.works_card(hook, g, again, 0)
	AiEconomy.works_act(hook, g, again, 0)
	assert_true(again.cards.is_empty(), "nothing scanned")
	assert_eq(again.wanted_cost, 0, "W stays 0")
	assert_eq(hook.trace_of(GEN).size(), 4)
	assert_true(hook.trace_of(GEN)[0].contains("no free work slot"))


# ----- the cards and the acts -----------------------------------------------------------------------------------------------


func _cards_game() -> Dictionary:
	var g := AiFixture.watch()
	return {"g": g, "hook": _hook(), "b": AiBrief.make(g, GEN)}


func _scan_and_cards(w: Dictionary, count: int = 4) -> void:
	for step: int in 2:
		AiEconomy.works_scan(w["hook"], w["g"], w["b"], step)
	for k: int in count:
		AiEconomy.works_card(w["hook"], w["g"], w["b"], k)


func _carded(b: AiBrief) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in b.cards:
		if e.has("card"):
			out.append(e)
	out.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return int(a["rank"]) < int(c["rank"]))
	return out


func _trace(w: Dictionary, tag: StringName = GEN) -> String:
	return "\n".join((w["hook"] as AiTurn).trace_of(tag))


func test_the_cards_go_to_the_best_by_prior_one_a_hex_ties_by_index() -> void:
	var w := _cards_game()
	_scan_and_cards(w)
	var carded := _carded(w["b"])
	assert_eq(carded.size(), 4, "works_cards 4")
	var hexes: Array[Vector2i] = []
	var scores: Array[int] = []
	for e: Dictionary in carded:
		hexes.append(e["hex"])
		scores.append(int(e["score"]))
	assert_eq(hexes, [Vector2i(8, 12), Vector2i(10, 13), Vector2i(9, 11), Vector2i(10, 12)] as Array[Vector2i])
	assert_eq(scores, [750, 750, 700, 700] as Array[int], "grazing is the best stage here: 30 a year on 40")


func test_the_timber_woods_of_4_16_a_are_options_with_a_prior_of_300() -> void:
	var w := _cards_game()
	_scan_and_cards(w, 0)
	for hex: Vector2i in [Vector2i(8, 11), Vector2i(8, 12), Vector2i(10, 13)]:
		var found := false
		for e: Dictionary in w["b"].cards:
			if e["hex"] == hex and int(e["option"]["family"]) == 10:
				found = true
				assert_eq(int(e["prior"]), 300, str(hex))
		assert_true(found, "timber on %s is an option" % hex)


func test_each_card_draws_one_jitter_from_the_ai_stream_in_card_order() -> void:
	var w := _cards_game()
	var other := AiFixture.watch()
	var luck_before: int = (w["g"] as Game).luck.world.get_state()
	_scan_and_cards(w)
	for e: Dictionary in _carded(w["b"]):
		assert_eq(int(e["jitter"]), AiKnow.jitter(other, 50), "the next draw of the AI stream")
		assert_between(int(e["jitter"]), 950, 1050)
	assert_eq((w["g"] as Game).luck.world.get_state(), luck_before, "luck.world untouched")


func test_the_adjusted_payback_is_the_payback_times_the_jitter_over_the_priority() -> void:
	var w := _cards_game()
	_scan_and_cards(w)
	for e: Dictionary in _carded(w["b"]):
		var payback := int(e["card"]["payback"])
		assert_eq(int(e["adjusted"]), payback * int(e["jitter"]) * 1000 / int(e["priority"]))


func _act(w: Dictionary) -> Array[Dictionary]:
	var acts: Array[Dictionary] = []
	(w["hook"] as AiTurn).judge = func(t: StringName, action: String, args: Dictionary, _v: Dictionary, _r: Dictionary) -> void:
		acts.append({"tag": t, "action": action, "args": args})
	AiEconomy.works_act(w["hook"], w["g"], w["b"], 0)
	return acts


func test_two_works_a_season_in_ascending_adjusted_payback() -> void:
	var w := _cards_game()
	_scan_and_cards(w)
	var order := _carded(w["b"])
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["adjusted"]) < int(b["adjusted"]))
	var acts := _act(w)
	assert_eq(acts.size(), 2, "works_per_season 2")
	assert_eq(acts[0]["args"]["hex"], order[0]["hex"])
	assert_eq(acts[1]["args"]["hex"], order[1]["hex"])
	assert_eq(acts[0]["action"], "build")
	assert_eq(AiKnow.slots_free(w["g"], GEN), 0)
	assert_eq((w["b"] as AiBrief).wanted_cost, 0)


func test_p_one_work_a_season_when_the_def_says_one() -> void:
	var w := _cards_game()
	var ai := (w["b"] as AiBrief).ai.duplicate() as AiDef
	ai.works_per_season = 1
	(w["b"] as AiBrief).ai = ai
	_scan_and_cards(w)
	assert_eq(_act(w).size(), 1)


func test_the_payback_limit_stops_a_slow_card() -> void:
	var w := _cards_game()
	var temper := (w["b"] as AiBrief).temper.duplicate() as AiTemperDef
	temper.payback_max = 5
	(w["b"] as AiBrief).temper = temper
	_scan_and_cards(w)
	assert_eq(_act(w).size(), 0, "the best payback is 8 seasons")
	assert_true(_trace(w).contains("over the limit 5"))
	var w2 := _cards_game()
	var t2 := (w2["b"] as AiBrief).temper.duplicate() as AiTemperDef
	t2.payback_max = 9
	(w2["b"] as AiBrief).temper = t2
	_scan_and_cards(w2)
	assert_eq(_act(w2).size(), 1, "only the 8-season card is inside 9")


func test_the_reserve_is_kept() -> void:
	var w := _cards_game()
	(w["b"] as AiBrief).reserve = 570
	_scan_and_cards(w)
	assert_eq(_act(w).size(), 1, "610 - 40 = 570 keeps R 570; the next would leave 530")
	assert_true(_trace(w).contains("under the reserve R 570"))
	var w2 := _cards_game()
	(w2["b"] as AiBrief).reserve = 571
	_scan_and_cards(w2)
	assert_eq(_act(w2).size(), 0, "P: one ducat more reserve, nothing begun")


func test_a_card_refused_for_money_sets_w_to_its_ducats() -> void:
	var w := _cards_game()
	_scan_and_cards(w)
	_country(w["g"]).treasury = 30
	(w["g"] as Game).version += 1
	assert_eq(_act(w).size(), 0)
	assert_eq((w["b"] as AiBrief).wanted_cost, 40, "the best card's ducats")
	assert_true(_trace(w).contains("W = 40"))


func test_w_is_not_set_by_a_card_that_would_never_pay() -> void:
	var w := _cards_game()
	var temper := (w["b"] as AiBrief).temper.duplicate() as AiTemperDef
	temper.payback_max = 2
	(w["b"] as AiBrief).temper = temper
	_scan_and_cards(w)
	_country(w["g"]).treasury = 30
	(w["g"] as Game).version += 1
	_act(w)
	assert_eq((w["b"] as AiBrief).wanted_cost, 0)


# ----- priorities -----------------------------------------------------------------------------------------------------------


func _score_of(b: AiBrief, hex: Vector2i, family: int) -> int:
	for e: Dictionary in b.cards:
		if e["hex"] == hex and int(e["option"]["family"]) == family:
			return int(e["score"])
	return -1


func test_a_hungry_seat_ranks_food_above_an_equal_vineyard() -> void:
	var calm := _cards_game()
	_scan_and_cards(calm, 0)
	assert_eq([_score_of(calm["b"], Vector2i(10, 13), 14), _score_of(calm["b"], Vector2i(7, 12), 7)], [57, 106],
		"the harbour's prior 57 and the vineyard's 106 at rest")
	var hungry := _cards_game()
	(hungry["b"] as AiBrief).hungry = true
	_scan_and_cards(hungry, 0)
	assert_eq(_score_of(hungry["b"], Vector2i(10, 13), 14), 171, "food_priority 3,000 multiplies the rank")
	assert_gt(_score_of(hungry["b"], Vector2i(10, 13), 14), _score_of(hungry["b"], Vector2i(7, 12), 7), "hungry: the food wins")
	assert_eq(_score_of(hungry["b"], Vector2i(7, 12), 7), 106, "a vineyard has no priority")
	var soon := _cards_game()
	(soon["b"] as AiBrief).food_soon = true
	_scan_and_cards(soon, 0)
	assert_eq(_score_of(soon["b"], Vector2i(10, 13), 14), 171, "food soon counts too")


func test_a_towns_walls_are_ranked_up_when_its_town_is_full() -> void:
	var w := _cards_game()
	(w["b"] as AiBrief).town_full.append(Vector2i(8, 13))
	_scan_and_cards(w, 0)
	assert_eq(_score_of(w["b"], Vector2i(8, 13), 1), 490, "245 x walls_priority 2,000")
	var plain := _cards_game()
	_scan_and_cards(plain, 0)
	assert_eq(_score_of(plain["b"], Vector2i(8, 13), 1), 245)


func test_the_priority_is_the_divisor_of_the_adjusted_payback() -> void:
	var w := _cards_game()
	(w["b"] as AiBrief).hungry = true
	_scan_and_cards(w, 4)
	for e: Dictionary in _carded(w["b"]):
		assert_eq(int(e["priority"]), 3000 if [3, 14].has(int(e["option"]["family"])) else 1000)


# ----- works at war, and fortify --------------------------------------------------------------------------------------------


func test_a_seat_with_works_at_war_no_takes_only_food_at_war() -> void:
	var enemies: Array[StringName] = [MLO]
	var w := _cards_game()
	var b: AiBrief = w["b"]
	var temper := b.temper.duplicate() as AiTemperDef
	temper.works_at_war = false
	b.temper = temper
	b.enemies = enemies
	_scan_and_cards(w, 0)
	assert_false(b.cards.is_empty(), "the harbour is food")
	for e: Dictionary in b.cards:
		assert_true([3, 14].has(int(e["option"]["family"])), "only wheat or harbour: %s" % e["option"])
	var peace := _cards_game()
	var p: AiBrief = peace["b"]
	p.temper = temper
	_scan_and_cards(peace, 0)
	var families := {}
	for e: Dictionary in p.cards:
		families[int(e["option"]["family"])] = true
	assert_true(families.has(10), "P: at peace the same temper builds timber too")
	var with_works := _cards_game()
	var q: AiBrief = with_works["b"]
	q.enemies = enemies
	_scan_and_cards(with_works, 0)
	var every := {}
	for e: Dictionary in q.cards:
		every[int(e["option"]["family"])] = true
	assert_true(every.has(10), "a builder (works_at_war yes) builds timber at war")


func _fortify_game(fortify: bool, threats: bool = true) -> Dictionary:
	var g := AiFixture.watch()
	var b := AiBrief.make(g, SAV)
	_country(g, SAV).treasury = 100000
	b.reserve = 100
	if not fortify:
		var temper := b.temper.duplicate() as AiTemperDef
		temper.fortify = false
		b.temper = temper
	if threats:
		b.threats = AiKnow.neighbours(g, SAV)
	return {"g": g, "hook": _hook(), "b": b}


func test_a_steadfast_seat_fortifies_a_pass_first_one_a_season() -> void:
	var w := _fortify_game(true)
	assert_eq(AiKnow.fortify_candidates(w["g"], SAV, w["b"].threats).size(), 3)
	var acts := _act(w)
	assert_eq(acts.size(), 1, "one a season, no cards scanned")
	assert_eq(acts[0]["args"]["hex"], Vector2i(5, 14), "the first candidate its check allows: " + _trace(w, SAV))
	assert_true(_trace(w, SAV).contains("castles at (3, 7) skipped, refused (goods)"), "(3, 7) lacks the stone")
	assert_true(_trace(w, SAV).contains("castles at (3, 10) skipped, refused (rule)"), "(3, 10) is within two hexes of a castle")
	assert_true(_trace(w, SAV).contains("fortifies"), _trace(w, SAV))
	assert_true(_trace(w, SAV).contains("castles at (5, 14), cost 200"), _trace(w, SAV))


func test_p_fortify_is_for_the_steadfast_only_and_while_a_threat_exists() -> void:
	assert_eq(_act(_fortify_game(false)).size(), 0, "fortify no: nothing")
	assert_eq(_act(_fortify_game(true, false)).size(), 0, "no threat: nothing")
	var poor := _fortify_game(true)
	_country(poor["g"], SAV).treasury = 110
	(poor["g"] as Game).version += 1
	assert_eq(_act(poor).size(), 0, "T - cost under R: nothing")


# ----- Genoa's first turn (4.16 a) ------------------------------------------------------------------------------------------


func test_genoas_brief_is_4_16_a() -> void:
	var g := AiFixture.watch()
	var b := AiBrief.make(g, GEN)
	assert_eq([b.treasury, b.upkeep, b.reserve, b.net, b.people], [610, 17, 102, 85, 82700], "T, U, R, N, people")
	assert_eq(AiKnow.slots_free(g, GEN), 2)
	assert_eq(AiKnow.preview_net(g, GEN, 0), 63, "N_low")
	assert_eq(AiKnow.preview_net(g, GEN, 1), 85, "N_normal: 4.16 (a)'s +86, less the barracks' upkeep")
	assert_eq(AiKnow.work_candidates(g, GEN).size(), 11)


func test_genoas_first_turn_works_and_tax() -> void:
	var g := AiFixture.watch()
	var hook := AiFixture.solo(g, GEN)
	var acts := AiFixture.run(g, hook)
	var works: Array[String] = []
	var tax: Array[String] = []
	for a: Dictionary in acts:
		if a["action"] == "build":
			works.append("%s" % a["args"]["hex"])
		if a["action"] == "set_tax":
			tax.append(str(a["args"]["level"]))
	assert_eq(works, ["(8, 12)", "(10, 12)"] as Array[String], "two works begun, the jitter ordering them")
	assert_eq(tax, ["0"] as Array[String], "T well over 2R, at peace, not hungry, W 0, N_low >= 0: Low")
	assert_eq(AiKnow.tax_level(g, GEN), LOW)
	assert_eq(hook.brief_of(GEN).wanted_cost, 0, "W stays 0")
	var text := "\n".join(hook.trace_of(GEN))
	for part: String in ["works_scan 0: 11 candidates", "works_card 0: build grazing at (8, 12) prior 750 x priority 1000 = score 750",
			"payback 8 seasons x jitter", "works_act: takes build grazing at (8, 12), payback 8 (limit 40), cost 40",
			"works_act: 2 of 2 works begun, W 0", "tax: T ", " N_low 56 N_normal 77, at peace, level Normal: row 5 gives Low",
			"did build hex=(8, 12) family=9", "did set_tax level=0"]:
		assert_true(text.contains(part), "%s in the trace" % part)
