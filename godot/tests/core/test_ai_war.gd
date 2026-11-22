## The AI at war, part one (docs/architecture/m8-build-spec.md 4.9, 4.10, 4.16 (b) and (c), D22 to D26, 9): when it declares (every
## condition, the busy bonus, the ratio cap, the prize, one roll a think turn), the worked examples on the duel
## (AiFixture.duel), the standing order, shaken and hungry armies, and the besieger's storm. The aims, fair warning, the keeping
## of a march, refused marches and the fog are in test_ai_war_aims.gd. The steps run one at a time on a seat's brief
## (AiWar.war, AiWar.war_army); a planted fault (P) is a number changed on a duplicate of a temperament or of the shared numbers.
@warning_ignore_start("integer_division")
extends GutTest

const S := preload("res://tests/core/ai_war_scene.gd")
const M := AiWarScene.M
const GEN := AiWarScene.GEN
const VEN := AiWarScene.VEN
const WALLS := AiWarScene.WALLS
const FORT := AiWarScene.FORT
const STAND := AiWarScene.STAND


func _army(g: Game, id: int) -> Army:
	return Armies.by_id(g, id)


func _non_depot(g: Game) -> Vector2i:
	var depots := AiKnow.depots(g, M)
	for i: int in AiKnow.land_of(g, M):
		var hex := AiKnow.hex_of(g, i)
		if AiKnow.is_land(g, hex) and not depots.has(hex):
			return hex
	return Army.NO_HEX


func _depot_near(g: Game, from: Vector2i) -> Vector2i:
	var best := Army.NO_HEX
	var least := 1 << 30
	for hex: Vector2i in AiKnow.depots(g, M):
		if AiKnow.hex_distance(from, hex) < least:
			least = AiKnow.hex_distance(from, hex)
			best = hex
	return best


## The luck state after one draw of 1 to 1,000 from `before`.
func _after_one_roll(before: int) -> int:
	var probe := Rng.new()
	probe.set_state(before)
	probe.randi_range(1, 1000)
	return probe.get_state()


# ----- 4.9: every condition ---------------------------------------------------------------------------------------------------


func test_it_declares_on_the_weak_neighbour_when_every_condition_holds_with_one_roll() -> void:
	var g := S.ready_duel()
	var before := S.luck(g)
	assert_true(S.declares(g), "Milan declares")
	assert_true(Wars.at_war(g, M, GEN), "on Genoa")
	assert_eq(S.luck(g), _after_one_roll(before), "one draw of the AI's own stream")
	assert_eq(S.acts.size(), 1)
	assert_eq(S.acts[0]["action"], "declare_war")


func test_p_max_wars_the_declaration_waits_for_a_free_war() -> void:
	var g := S.ready_duel()
	WarFixture.at_war(g, M, VEN)
	assert_true(S.declares(g), "one war of two: it declares")
	var full := S.ready_duel()
	WarFixture.at_war(full, M, VEN)
	WarFixture.at_war(full, M, &"FER")
	var before := S.luck(full)
	assert_false(S.declares(full), "two wars: the opportunist's limit")
	assert_eq(S.luck(full), before, "and no roll")
	S.temper(full, {"max_wars": 3})
	assert_true(S.declares(full), "P: the limit is the temperament's number")


func test_p_rest_the_declaration_waits_for_the_rest_seasons_after_a_peace() -> void:
	var g := S.ready_duel()
	g.turn = 11
	WarFixture.ended(g, M, VEN, g.turn - 3)
	var before := S.luck(g)
	assert_false(S.declares(g), "a peace 3 seasons ago: rests 8")
	assert_eq(S.luck(g), before, "no roll")
	var later := S.ready_duel()
	later.turn = 11
	WarFixture.ended(later, M, VEN, later.turn - 8)
	assert_true(S.declares(later), "8 seasons after it may")
	var other := S.ready_duel()
	other.turn = 11
	WarFixture.ended(other, M, VEN, other.turn - 3)
	S.temper(other, {"rest_seasons": 2})
	assert_true(S.declares(other), "P: the rest is the temperament's number")


func test_p_war_chest_the_treasury_must_reach_seasons_of_upkeep() -> void:
	var g := S.ready_duel()
	var b := S.brief(g)
	var chest := 8 * maxi(b.upkeep, b.ai.min_upkeep)
	b.treasury = chest - 1
	var before := S.luck(g)
	assert_false(S.declares(g, b), "a ducat short")
	assert_eq(S.luck(g), before)
	b.treasury = chest
	assert_true(S.declares(g, b), "the chest reached")
	var low := S.ready_duel()
	S.temper(low, {"war_chest_seasons": 1})
	var c := S.brief(low)
	c.treasury = chest - 1
	assert_true(S.declares(low, c), "P: the chest is the temperament's number")


func test_p_war_men_the_army_must_reach_the_minimum() -> void:
	var g := S.ready_duel()
	var b := S.brief(g)
	b.men = b.ai.min_war_men - 1
	var before := S.luck(g)
	assert_false(S.declares(g, b), "999 men")
	assert_eq(S.luck(g), before)
	b.men = b.ai.min_war_men
	assert_true(S.declares(g, b), "1,000 men")


func test_p_hungry_a_hungry_seat_does_not_declare() -> void:
	var g := S.ready_duel()
	var b := S.brief(g)
	b.hungry = true
	var before := S.luck(g)
	assert_false(S.declares(g, b))
	assert_eq(S.luck(g), before, "no roll")
	b.hungry = false
	assert_true(S.declares(g, b))


func test_it_thinks_only_on_its_think_turns() -> void:
	var g := S.ready_duel()
	g.turn = 4
	var b := S.brief(g)
	assert_false(b.think)
	var before := S.luck(g)
	assert_false(S.declares(g, b), "turn 4 is not a think turn")
	assert_eq(S.luck(g), before)
	g.turn = 7
	assert_true(S.brief(g).think, "turn 7 is")


func test_no_target_no_roll() -> void:
	var g := S.ready_duel()
	S.stats(g, 2000, {GEN: 2000})
	var before := S.luck(g)
	assert_false(S.declares(g), "every neighbour near equal: ratio 1,000 under 1,500")
	assert_eq(S.luck(g), before, "a roll only with a target")


func test_the_roll_is_one_a_think_turn_and_a_failed_roll_declares_nothing() -> void:
	var g := S.ready_duel(0)
	var before := S.luck(g)
	assert_false(S.declares(g), "a chance of 0 never passes")
	assert_eq(S.luck(g), _after_one_roll(before), "but the roll was drawn, once")
	assert_eq(Wars.enemies(g, M).size(), 0)


# ----- targets: the ratio, the prize, the busy bonus ---------------------------------------------------------------------------


func test_the_ratio_is_capped_at_4000() -> void:
	assert_eq(AiWar.ratio_of(2000, 0), 4000, "Genoa's 0 men count as 1: 2,000,000, capped")
	assert_eq(AiWar.ratio_of(3000, 1), 4000)
	assert_eq(AiWar.ratio_of(2000, 2000), 1000)
	assert_eq(AiWar.ratio_of(3300, 2000), 1650)


func test_the_prize_counts_open_districts_in_range_and_two_for_each_strong_fortress() -> void:
	var g := S.ready_duel()
	var b := S.brief(g)
	assert_eq(AiWar.prize_of(g, b, GEN), 2, "Genoa's walls (8, 13), 3 hexes from Milan's (11, 13), count 2")
	var swiss := AiWar.prize_of(g, b, &"SWI")
	var open := Vector2i(9, 2)
	assert_eq([AiKnow.area_state(g, open), AiKnow.owner_of(g, open)], [&"open", &"SWI"], "a Swiss district 1 hex from Milan's land")
	WarFixture.set_occupier(g, open, M)
	g.districts.clear()
	g.version += 1
	assert_eq(AiWar.prize_of(g, S.brief(g), &"SWI"), swiss - 1, "a district Milan already holds is no prize")
	var near := S.ready_duel()
	S.ai(near, {"prize_range": 1})
	assert_lt(AiWar.prize_of(near, S.brief(near), &"SWI"), swiss, "P: only land within prize_range counts")


func test_the_target_is_the_best_score_and_each_needs_its_check_and_its_ratio() -> void:
	var g := S.ready_duel()
	var found := AiWar.targets(g, S.brief(g))
	assert_eq(found.size(), 1, "only Genoa: the others' ratio 1,000 is under 1,500")
	assert_eq(found[0]["target"], GEN)
	assert_eq(found[0]["ratio"], 4000)
	assert_eq(found[0]["score"], int(found[0]["prize"]) * 4000 / 1000)
	S.stats(g, 0)
	found = AiWar.targets(g, S.brief(g))
	assert_gt(found.size(), 1, "with every neighbour at 0 men all are candidates")
	assert_eq(found[0]["target"], &"SWI", "the best prize (24) first")
	for k: int in found.size() - 1:
		assert_gte(int(found[k]["score"]), int(found[k + 1]["score"]))
	WarFixture.ended(g, M, &"SWI", g.turn - 1)
	for t: Dictionary in AiWar.targets(g, S.brief(g)):
		assert_ne(t["target"], &"SWI", "P: a truce (the check refuses) is no target")


func test_the_busy_bonus_lowers_the_ratio_a_target_at_war_elsewhere_needs() -> void:
	var g := S.ready_duel()
	S.stats(g, 5000, {VEN: 1600, GEN: 5000})
	assert_eq(AiWar.ratio_of(2000, 1600), 1250, "between 1,100 and 1,500")
	assert_eq(AiWar.targets(g, S.brief(g)).size(), 0, "Venice alone: 1,250 is under 1,500")
	WarFixture.at_war(g, VEN, &"FER")
	var found := AiWar.targets(g, S.brief(g))
	assert_eq(found.size(), 1, "at war with a third: the need is 1,500 - 400")
	assert_eq([found[0]["target"], found[0]["need"]], [VEN, 1100])
	S.temper(g, {"busy_bonus": 0})
	assert_eq(AiWar.targets(g, S.brief(g)).size(), 0, "P: the bonus is the temperament's number")


# ----- 4.16 (b) and (c) ---------------------------------------------------------------------------------------------------------


func test_4_16_b_milan_declares_on_a_passive_genoa_on_the_think_turn_its_roll_allows() -> void:
	var g := S.duel()
	WarFixture.army_at(g, M, Vector2i(9, 9), 4)
	S.stats(g, 2000)
	var probe := Rng.new()
	probe.set_state(S.luck(g))
	var turn := 3
	while probe.randi_range(1, 1000) > 450:
		turn += 4
	var b := S.brief(g)
	assert_eq([b.men, b.treasury >= 8 * b.upkeep, b.hungry], [2000, true, false], "M 2,000, the chest reached, fed")
	var found := AiWar.targets(g, b)
	assert_eq(found.size(), 1, "Genoa is the only candidate: 2,000 over 2,000 is 1,000")
	assert_eq([found[0]["target"], found[0]["ratio"]], [GEN, 4000])
	assert_gte(int(found[0]["prize"]), 2)
	var declared := 0
	for t: int in range(3, turn + 1, 4):
		g.turn = t
		var step := S.brief(g)
		AiWar.war(S.hook(g), g, step, 0)
		if not step.declared_now.is_empty():
			declared = t
			break
	assert_eq(declared, turn, "the turn the seed's rolls give (a chance of 450)")
	assert_eq(declared, 19, "pinned: the rolls of turns 3, 7, 11 and 15 fail, turn 19's passes")
	assert_true(Wars.at_war(g, M, GEN))
	assert_eq(AiKnow.wars_of(g, M)[0]["start_turn"], declared)


func test_4_16_c_milans_army_before_genoa_besieges_the_walls_it_counts_full() -> void:
	var g := S.at_war(GEN)
	var army := WarFixture.army_at(g, M, STAND, 4)
	var b := S.brief(g)
	assert_false(Sight.sees(g, M, WALLS), "the walls are beyond Milan's sight")
	assert_eq(AiKnow.garrison_estimate(g, M, WALLS), 800, "an unseen garrison is the full 400 x 2")
	assert_eq(AiKnow.forecast(g, M, WALLS, 2000, 0), 4, "need 10, crowd 2, stores 3: 2, 4, 6, 10 is 4 seasons")
	var list := AiWar.aims(g, b, army)
	assert_eq([list[0]["kind"], list[0]["goal"]], [AiWar.BESIEGE, WALLS])
	assert_eq(list[0]["score"], 650 - 100 + 100 - 10 * 3, "650 - 25 x 4 + 100 (the capital) - 10 d")
	assert_lt(int(S.aim_of(list, AiWar.WALK_IN)["score"]), int(list[0]["score"]), "it beats the walk-in")
	S.step(g, b, army)
	assert_eq([_army(g, army.id).order, _army(g, army.id).goal], [Army.ORDER_MARCH, WALLS], "the army marches to besiege Genoa")
	var guns := S.at_war(GEN)
	var by_siege := WarFixture.army_at(guns, M, STAND, 4)
	S.temper(guns, {"siege_max": 3})
	assert_false(S.kinds(AiWar.aims(guns, S.brief(guns), by_siege)).has(AiWar.BESIEGE), "P: 4 seasons is over a siege_max of 3")


func test_p_an_unseen_garrison_is_counted_full_whatever_it_really_holds() -> void:
	var g := S.at_war(GEN)
	var army := WarFixture.army_at(g, M, STAND, 4)
	var before := AiWar.aims(g, S.brief(g), army)
	Occupation.set_garrison(g, WALLS, 100)
	g.version += 1
	assert_eq(AiWar.aims(g, S.brief(g), army), before, "the weak garrison it cannot see changes no aim")
	assert_eq(AiKnow.forecast(g, M, WALLS, 2000, 0), 4)


# ----- the standing order -------------------------------------------------------------------------------------------------------


func test_it_withdraws_when_a_seen_enemy_near_outnumbers_it_by_the_ratio() -> void:
	var s := S.near_scene(6)
	var g: Game = s["g"]
	var mine: Army = s["mine"]
	S.step(g, S.brief(g), mine)
	assert_eq(_army(g, mine.id).standing, Army.STANDING_WITHDRAW, "3,000 x 1,000 over 2,000 x 1,300")
	var told := 0
	for act: Dictionary in S.acts:
		told += 1 if act["action"] == "set_standing" else 0
	assert_eq(told, 1)
	var even := S.near_scene(5)
	S.step(even["g"], S.brief(even["g"]), even["mine"])
	assert_eq((even["mine"] as Army).standing, Army.STANDING_HOLD, "2,500 is under the ratio: Hold")
	var data := S.near_scene(5)
	S.temper(data["g"], {"withdraw_ratio": 1000})
	S.step(data["g"], S.brief(data["g"]), data["mine"])
	assert_eq((data["mine"] as Army).standing, Army.STANDING_WITHDRAW, "P: the ratio is the temperament's number")


func test_the_standing_order_looks_threat_range_hexes_only_and_returns_to_hold() -> void:
	var s := S.near_scene(6, Vector2i(12, 5))
	var g: Game = s["g"]
	var mine: Army = s["mine"]
	S.ai(g, {"threat_range": 1})
	S.step(g, S.brief(g), mine)
	assert_eq(_army(g, mine.id).standing, Army.STANDING_HOLD, "2 hexes away is out of a range of 1")
	var near := S.near_scene(6)
	var h: Game = near["g"]
	S.step(h, S.brief(h), near["mine"])
	assert_eq((near["mine"] as Army).standing, Army.STANDING_WITHDRAW)
	Armies.remove(h, near["theirs"])
	h.version += 1
	S.step(h, S.brief(h), near["mine"])
	assert_eq((near["mine"] as Army).standing, Army.STANDING_HOLD, "the enemy gone: Hold again")


func test_p_an_army_on_its_own_fortress_or_besieging_keeps_to_hold() -> void:
	var g := S.at_war(VEN)
	var on_fort := WarFixture.army_at(g, M, FORT, 4)
	WarFixture.army_at(g, VEN, Vector2i(11, 9), 6)
	S.step(g, S.brief(g), on_fort)
	assert_eq(_army(g, on_fort.id).standing, Army.STANDING_HOLD, "behind its own walls")
	var h := S.at_war(GEN)
	var siege_army := WarFixture.army_at(h, M, WALLS, 4)
	S.siege(h, WALLS, M, 0, 1)
	WarFixture.army_at(h, GEN, AiKnow.land_neighbours(h, WALLS)[0], 6)
	S.step(h, S.brief(h), siege_army)
	assert_eq(_army(h, siege_army.id).standing, Army.STANDING_HOLD, "a besieger stays")


# ----- shaken, hungry -------------------------------------------------------------------------------------------------------------


func test_a_shaken_army_marches_to_the_nearest_depot_and_holds_there() -> void:
	var g := S.at_war(GEN)
	var from := _non_depot(g)
	var army := WarFixture.army_at(g, M, from, 4)
	S.morale(g, army, 500)
	S.step(g, S.brief(g), army)
	var depot := _depot_near(g, from)
	assert_eq([_army(g, army.id).order, _army(g, army.id).goal], [Army.ORDER_MARCH, depot], "to the nearest depot")
	var home := WarFixture.army_at(g, M, depot, 4)
	S.morale(g, home, 500)
	S.step(g, S.brief(g), home)
	assert_ne(_army(g, home.id).order, Army.ORDER_MARCH, "on the depot it holds")
	var fit := WarFixture.army_at(g, M, from, 4)
	S.morale(g, fit, 700)
	S.step(g, S.brief(g), fit)
	assert_false(_army(g, fit.id).goal == depot and _army(g, fit.id).order == Army.ORDER_MARCH, "P: 700 is not shaken")


func test_a_hungry_army_goes_to_the_depot_unless_it_besieges_a_place_that_falls_within_two_seasons() -> void:
	var g := S.at_war(GEN)
	var from := _non_depot(g)
	var army := WarFixture.army_at(g, M, from, 4)
	Armies.set_supply(g, army, 2, 0)
	g.version += 1
	S.step(g, S.brief(g), army)
	assert_eq([_army(g, army.id).order, _army(g, army.id).goal], [Army.ORDER_MARCH, _depot_near(g, from)], "hungry: to the depot")
	var near := S.at_war(GEN)
	var holder := WarFixture.army_at(near, M, WALLS, 4)
	Armies.set_supply(near, holder, 2, 0)
	S.siege(near, WALLS, M, 5, 2)
	assert_eq(int(AiKnow.own_siege(near, M, WALLS)["falls_in"]), 2)
	S.step(near, S.brief(near), holder)
	assert_ne(_army(near, holder.id).order, Army.ORDER_MARCH, "the place falls in 2: it keeps the siege")
	var far := S.at_war(GEN)
	var starving := WarFixture.army_at(far, M, WALLS, 4)
	Armies.set_supply(far, starving, 2, 0)
	S.siege(far, WALLS, M, 0, 1)
	assert_gt(int(AiKnow.own_siege(far, M, WALLS)["falls_in"]), 2)
	S.step(far, S.brief(far), starving)
	assert_eq(_army(far, starving.id).order, Army.ORDER_MARCH, "P: it falls later than 2 seasons: the hungry army leaves")


# ----- storms ---------------------------------------------------------------------------------------------------------------------


func _storm_scene(progress: int, seasons: int) -> Dictionary:
	var g := S.at_war(GEN)
	var army := WarFixture.army_at(g, M, WALLS, 4)
	S.siege(g, WALLS, M, progress, seasons)
	return {"g": g, "army": army}


func test_a_besieger_storms_at_the_meter_the_seasons_and_the_odds() -> void:
	var s := _storm_scene(5, 2)
	var g: Game = s["g"]
	var army: Army = s["army"]
	assert_eq(int(AiKnow.own_siege(g, M, WALLS)["need"]), 10)
	S.step(g, S.brief(g), army)
	assert_eq([_army(g, army.id).order, _army(g, army.id).goal], [Army.ORDER_STORM, WALLS], "meter 5 of 10 is the opportunist's half")
	assert_eq(S.acts.size(), 1, "nothing else: the siege goes on")
	assert_eq(S.acts[0]["action"], "storm")


func test_p_no_storm_before_two_seasons_under_the_share_or_under_the_odds() -> void:
	var young := _storm_scene(8, 1)
	S.step(young["g"], S.brief(young["g"]), young["army"])
	assert_ne((young["army"] as Army).order, Army.ORDER_STORM, "season 1 of the siege: not yet, however the meter stands")
	var thin := _storm_scene(4, 3)
	S.step(thin["g"], S.brief(thin["g"]), thin["army"])
	assert_ne((thin["army"] as Army).order, Army.ORDER_STORM, "4 of 10 is under half")
	var odds := _storm_scene(5, 2)
	S.temper(odds["g"], {"storm_ratio": 5000})
	S.step(odds["g"], S.brief(odds["g"]), odds["army"])
	assert_ne((odds["army"] as Army).order, Army.ORDER_STORM, "the odds 2.2 are under a ratio of 5")
	var share := _storm_scene(4, 3)
	S.temper(share["g"], {"storm_share": 300})
	S.step(share["g"], S.brief(share["g"]), share["army"])
	assert_eq((share["army"] as Army).order, Army.ORDER_STORM, "P: the share is the temperament's number")
	for scene: Dictionary in [young, thin, odds]:
		assert_eq((scene["army"] as Army).route.size(), 0, "a besieger never marches away on its own aims")
