## The AI at war, part two (docs/architecture/m8-build-spec.md 4.10, D23, D24, 9): each aim of an army on small scenes of the duel
## (retake, relief by attack and by rally, attack by the odds, walk-ins fanned out by claims, approach), fair warning, the keeping
## of a march under the switch, the refused marches, that nothing the seat cannot see moves its aims, and that the step stays in
## its door. The declaring, the worked examples, the standing order and the storms are in test_ai_war.gd. A planted fault (P) is a
## number changed on a duplicate of a temperament or of the shared numbers.
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


# ----- retake, relief, attack -----------------------------------------------------------------------------------------------


func test_retake_comes_first_and_gives_way_to_a_stronger_seen_army_there() -> void:
	var g := S.at_war(VEN)
	var army := WarFixture.army_at(g, M, Vector2i(9, 8), 4)
	var lost := Vector2i(9, 6)
	WarFixture.set_occupier(g, lost, VEN)
	g.districts.clear()
	var list := AiWar.aims(g, S.brief(g), army)
	assert_eq([list[0]["kind"], list[0]["goal"], list[0]["score"]], [AiWar.RETAKE, lost, 1000 - 10 * AiKnow.hex_distance(army.hex, lost)])
	var held := WarFixture.army_at(g, VEN, lost, 4)
	assert_true(S.kinds(AiWar.aims(g, S.brief(g), army)).has(AiWar.RETAKE), "an equal army there: still retaken")
	Armies.remove(g, held)
	WarFixture.army_at(g, VEN, lost, 6)
	assert_false(S.kinds(AiWar.aims(g, S.brief(g), army)).has(AiWar.RETAKE), "P: 3,000 seen men there outweigh its 2,000")


func _siege_scene(own_comps: int, besiegers: int, progress: int, seasons: int) -> Dictionary:
	var g := S.at_war(VEN)
	var army := WarFixture.army_at(g, M, Vector2i(9, 7), own_comps)
	WarFixture.army_at(g, VEN, FORT, besiegers)
	S.siege(g, FORT, VEN, progress, seasons)
	return {"g": g, "army": army}


## The neighbour of the fortress Milan holds, nearest the army (ties: hex index).
func _rally_hex(g: Game, army: Army) -> Vector2i:
	var best := Army.NO_HEX
	for beside: Vector2i in AiKnow.land_neighbours(g, FORT):
		if AiKnow.controller_of(g, beside) != M:
			continue
		if best == Army.NO_HEX or AiKnow.hex_distance(army.hex, beside) < AiKnow.hex_distance(army.hex, best):
			best = beside
	return best


func test_relief_attacks_with_force_enough_and_rallies_without() -> void:
	var s := _siege_scene(4, 2, 0, 1)
	var list := AiWar.aims(s["g"], S.brief(s["g"]), s["army"])
	var relief := S.aim_of(list, AiWar.RELIEVE)
	assert_eq([relief["goal"], relief["score"]], [FORT, 900 - 10 * AiKnow.hex_distance(Vector2i(9, 7), FORT)], "2,000 over 1,000 x 0.9")
	assert_eq(list[0]["kind"], AiWar.RELIEVE)
	var weak := _siege_scene(2, 3, 0, 1)
	var g: Game = weak["g"]
	var army: Army = weak["army"]
	var aims := AiWar.aims(g, S.brief(g), army)
	assert_false(S.kinds(aims).has(AiWar.RELIEVE), "1,000 under 1,500 x 0.9")
	var rally := S.aim_of(aims, AiWar.RALLY)
	var best := _rally_hex(g, army)
	assert_eq(rally["goal"], best, "the neighbour nearest the army that Milan holds")
	assert_eq(rally["score"], 850 - 10 * AiKnow.hex_distance(army.hex, best))
	WarFixture.army_at(g, M, best, 2)
	assert_true(S.kinds(AiWar.aims(g, S.brief(g), army)).has(AiWar.RELIEVE), "the army on the rally hex joins its force: 2,000 over 1,500 x 0.9")


func test_relief_when_the_place_falls_next_season_needs_only_relief_last_and_else_is_given_up() -> void:
	var s := _siege_scene(2, 3, 100, 3)
	var g: Game = s["g"]
	assert_eq(int(AiKnow.own_siege(g, M, FORT)["falls_in"]), 1, "it falls next season")
	assert_true(S.kinds(AiWar.aims(g, S.brief(g), s["army"])).has(AiWar.RELIEVE), "1,000 reaches 1,500 x 0.6")
	var lost := _siege_scene(2, 4, 100, 3)
	var aims := AiWar.aims(lost["g"], S.brief(lost["g"]), lost["army"])
	assert_false(S.kinds(aims).has(AiWar.RELIEVE) or S.kinds(aims).has(AiWar.RALLY), "P: 1,000 under 2,000 x 0.6: no relief, no rally")


func test_attack_by_the_odds_over_the_ground_factor() -> void:
	var s := S.near_scene(3)
	var g: Game = s["g"]
	var attack := S.aim_of(AiWar.aims(g, S.brief(g), s["mine"]), AiWar.ATTACK)
	assert_eq(attack["goal"], Vector2i(11, 5), "1,333 reaches the opportunist's 1,300")
	assert_eq(attack["score"], 700 + 33 / 10 - 10)
	var even := S.near_scene(4)
	assert_false(S.kinds(AiWar.aims(even["g"], S.brief(even["g"]), even["mine"])).has(AiWar.ATTACK), "ratio 1,000: no attack")
	S.temper(even["g"], {"attack_ratio": 1000})
	assert_true(S.kinds(AiWar.aims(even["g"], S.brief(even["g"]), even["mine"])).has(AiWar.ATTACK), "P: the ratio is the temperament's number")
	var far := S.near_scene(3)
	S.ai(far["g"], {"attack_range": 0})
	assert_false(S.kinds(AiWar.aims(far["g"], S.brief(far["g"]), far["mine"])).has(AiWar.ATTACK), "out of range")


# ----- walk-ins and the approach ---------------------------------------------------------------------------------------------


func test_walk_ins_are_fanned_out_by_claims_two_armies_two_hexes() -> void:
	var g := S.at_war(GEN)
	S.temper(g, {"siege_max": 1})
	var first := WarFixture.army_at(g, M, STAND, 2)
	var second := WarFixture.army_at(g, M, STAND, 2)
	var b := S.brief(g)
	assert_eq(AiWar.aims(g, b, first)[0]["kind"], AiWar.WALK_IN, "no siege in reach of the temperament: a walk-in")
	S.step(g, b, first)
	assert_eq(_army(g, first.id).order, Army.ORDER_MARCH)
	assert_eq(b.claims.size(), 1, "the hex is claimed")
	S.step(g, b, second)
	assert_eq(_army(g, second.id).order, Army.ORDER_MARCH)
	assert_eq(b.claims.size(), 2, "two armies, two hexes")
	assert_ne(_army(g, first.id).goal, _army(g, second.id).goal)
	assert_eq(AiWar.aims(g, S.brief(g), second)[0]["goal"], _army(g, first.id).goal, "P: without the claim both would walk in on one hex")


func test_a_walk_in_needs_militia_men_and_no_seen_army_on_the_hex() -> void:
	var g := S.at_war(GEN)
	S.temper(g, {"siege_max": 1})
	var small := WarFixture.army_at(g, M, STAND, 1)
	g.defs.war.militia_men = 600
	assert_false(S.kinds(AiWar.aims(g, S.brief(g), small)).has(AiWar.WALK_IN), "500 men are under 600")
	g.defs.war.militia_men = 250
	var walk := S.aim_of(AiWar.aims(g, S.brief(g), small), AiWar.WALK_IN)
	assert_false(walk.is_empty(), "250 or more")
	var there := WarFixture.army_at(g, GEN, walk["goal"], 1)
	var after := S.brief(g)
	assert_true(after.seen.size() > 0 or not Sight.sees(g, M, there.hex), "the army is seen, or it is not")
	for aim: Dictionary in AiWar.aims(g, after, small):
		assert_false(aim["kind"] == AiWar.WALK_IN and aim["goal"] == walk["goal"] and Sight.sees(g, M, there.hex), "P: not onto a seen army")


func test_approach_is_the_nearest_enemy_hex_when_nothing_else_is_in_reach() -> void:
	var g := S.at_war(GEN)
	S.ai(g, {"target_range": 1})
	var army := WarFixture.army_at(g, M, FORT, 4)
	var list := AiWar.aims(g, S.brief(g), army)
	assert_eq(S.kinds(list), [AiWar.APPROACH] as Array[StringName], "nothing within 1 hex but the approach")
	var least := 1 << 30
	for i: int in AiKnow.land_of(g, GEN):
		least = mini(least, AiKnow.hex_distance(army.hex, AiKnow.hex_of(g, i)))
	assert_eq(list[0]["score"], 100 - least)
	assert_eq(AiKnow.hex_distance(army.hex, list[0]["goal"]), least)
	assert_eq(AiKnow.owner_of(g, list[0]["goal"]), GEN)
	S.step(g, S.brief(g), army)
	assert_eq([_army(g, army.id).order, _army(g, army.id).goal], [Army.ORDER_MARCH, list[0]["goal"]])


# ----- fair warning -----------------------------------------------------------------------------------------------------------------


func test_fair_warning_an_army_takes_no_aim_in_the_land_just_declared_on_and_goes_to_its_post() -> void:
	var g := S.at_war(GEN)
	var army := WarFixture.army_at(g, M, STAND, 4)
	var b := S.brief(g)
	assert_eq(AiWar.aims(g, b, army)[0]["goal"], WALLS, "without the warning the army besieges the walls")
	b.declared_now.append(GEN)
	assert_eq(AiWar.aims(g, b, army), [] as Array[Dictionary], "no aim in Genoa's land this turn")
	S.step(g, b, army)
	var post := b.post_of(army.id)
	assert_eq([_army(g, army.id).order, _army(g, army.id).goal], [Army.ORDER_MARCH, post], "it marches to its post")
	assert_ne(AiKnow.owner_of(g, _army(g, army.id).goal), GEN, "P: never into the country declared on this turn")


func test_fair_warning_after_a_declaration_in_the_same_turn() -> void:
	var g := S.ready_duel()
	var army := Armies.of_country(g, M)[0]
	var b := S.brief(g)
	var hook := S.hook(g)
	AiWar.war(hook, g, b, 0)
	assert_eq(b.declared_now, [GEN] as Array[StringName], "declared this turn")
	AiWar.war_army(hook, g, b, army.id)
	assert_ne(AiKnow.owner_of(g, _army(g, army.id).goal), GEN, "the army is not ordered into Genoa's land")
	assert_eq(S.acts[0]["action"], "declare_war", "the declaration came first")


# ----- keeping a march --------------------------------------------------------------------------------------------------------------


func test_an_army_keeps_its_march_unless_a_new_aim_scores_the_switch_better() -> void:
	var g := S.at_war(GEN)
	S.temper(g, {"siege_max": 1})
	var army := WarFixture.army_at(g, M, STAND, 4)
	var list := AiWar.aims(g, S.brief(g), army)
	assert_gte(list.size(), 2)
	var worse: Dictionary = list[1]
	assert_true(bool(g.act("march", {"army": army.id, "goal": worse["goal"], "tag": M})["ok"]), "marching to the second aim")
	S.step(g, S.brief(g), army)
	assert_eq(_army(g, army.id).goal, worse["goal"], "440 against 430: under 30 % more: it keeps its march")
	assert_eq(S.acts.size(), 0, "no order told")
	S.ai(g, {"switch_permille": 1000})
	S.step(g, S.brief(g), army)
	assert_eq(_army(g, army.id).goal, list[0]["goal"], "P: with no switch a better aim wins")
	var bait := WarFixture.army_at(g, GEN, Vector2i(11, 12), 1)
	assert_true(bool(g.act("march", {"army": army.id, "goal": worse["goal"], "tag": M})["ok"]))
	S.ai(g, {"switch_permille": 1300})
	var c := S.brief(g)
	var top := AiWar.aims(g, c, army)[0]
	assert_eq([top["kind"], top["goal"]], [AiWar.ATTACK, bait.hex], "a seen army in reach scores far above a walk-in")
	S.step(g, c, army)
	assert_eq(_army(g, army.id).goal, bait.hex, "a new aim over the switch takes the army")


# ----- refused marches ----------------------------------------------------------------------------------------------------------------


## Milan's army beside a Venetian one with a Mantuan one on its hex: an attack on it is refused ("another country's army").
func _blocked_scene() -> Dictionary:
	var s := S.near_scene(3)
	WarFixture.army_at(s["g"], &"MAN", Vector2i(11, 5), 1)
	return s


func _run_one_army(g: Game, army: Army) -> AiTurn:
	var hook := S.hook(g)
	Sight.refresh(g)
	g.version += 1
	hook.begin(g)
	hook.push_step(AiTurn.BRIEF, 0)
	hook.push_step(AiTurn.ARMY, army.id)
	var guard := 0
	while not hook.step(g) and guard < 10:
		guard += 1
	return hook


func test_a_refused_march_asks_for_the_next_aim_at_most_order_tries_times() -> void:
	var s := _blocked_scene()
	var hook := _run_one_army(s["g"], s["mine"])
	var refused := 0
	for line: String in hook.trace_of(M):
		refused += 1 if line.begins_with("refused march") else 0
	assert_eq(refused, 1, "the attack on an army another country stands beside is refused, the next aim is ordered")
	assert_eq(hook.refusals(), refused)
	assert_eq((s["mine"] as Army).order, Army.ORDER_MARCH, "and the army marches on the next aim")
	var all := S.at_war(GEN)
	var army := WarFixture.army_at(all, M, STAND, 4)
	all.defs.stack_limit = 3
	var tried := _run_one_army(all, army)
	assert_eq(tried.refusals(), 2, "every goal refused: two checks, then it holds")
	assert_ne(_army(all, army.id).order, Army.ORDER_MARCH)
	var one := S.at_war(GEN)
	var single := WarFixture.army_at(one, M, STAND, 4)
	one.defs.stack_limit = 3
	S.ai(one, {"order_tries": 1})
	assert_eq(_run_one_army(one, single).refusals(), 1, "P: the tries are the game's number")


# ----- what the seat cannot see ---------------------------------------------------------------------------------------------------------


func test_nothing_the_seat_cannot_see_changes_its_aims() -> void:
	var s := S.near_scene(3)
	var g: Game = s["g"]
	var mine: Army = s["mine"]
	var before := AiWar.aims(g, S.brief(g), mine)
	var far := AiFixture.land_hex(g, VEN, M)
	assert_ne(far, Army.NO_HEX)
	WarFixture.army_at(g, VEN, far, 8)
	for hex: Vector2i in AiKnow.fortresses_of(g, VEN):
		if not Sight.sees(g, M, hex):
			Occupation.set_garrison(g, hex, maxi(0, Occupation.garrison_of(g, hex) - 200))
	g.version += 1
	assert_eq(AiWar.aims(g, S.brief(g), mine), before, "unseen armies and garrisons move no aim")
	var seen := WarFixture.army_at(g, VEN, Vector2i(10, 6), 2)
	g.version += 1
	assert_ne(AiWar.aims(g, S.brief(g), mine), before, "P: an army where it is seen does")
	assert_true(Sight.sees(g, M, seen.hex))


func test_the_war_steps_call_only_the_door_the_brief_and_the_trace() -> void:
	var text := FileAccess.get_file_as_string("res://core/ai/ai_war.gd")
	assert_false(text.is_empty())
	for other: String in ["AiEconomy.", "AiForces.", "AiPeace.", "AiTurn.new", "game.luck", "Sieges.", "Wars."]:
		assert_false(text.contains(other), "ai_war.gd does not use " + other)
	assert_gte(text.count("AiKnow.act("), 4, "its acts go through the door")


func test_a_declaration_is_in_the_trace() -> void:
	var g := S.ready_duel()
	var hook := S.hook(g)
	AiWar.war(hook, g, S.brief(g), 0)
	var joined := "\n".join(hook.trace_of(M))
	assert_true(joined.contains("war: target GEN"), joined)
	assert_true(joined.contains("did declare_war"), joined)
