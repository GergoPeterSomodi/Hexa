## The AI's turn and the seat's brief (docs/architecture/m8-build-spec.md 4.2, 4.5, 4.12, 5.5, 9): the seats and their order, the
## step queue and what a step may append, the progress counts, clear(), the dispatch of an army's step, a turn run a step at a
## time equal to the turn run at once; and AiBrief.make field by field with post_of. The step modules are empty in this frame
## (group C fills them), so the turn acts nothing yet: the equality is of the digest, the log and the briefs.
@warning_ignore_start("integer_division")
extends GutTest

const STEPS: Array[String] = ["brief", "peace", "war", "works_scan", "works_scan", "works_card", "works_card", "works_card",
	"works_card", "works_act", "forces", "tax", "done"]


## The names of a seat's trace lines in order ("works_scan 1" -> "works_scan"; an army line -> "army").
func _names(hook: AiTurn, tag: StringName) -> Array[String]:
	var out: Array[String] = []
	for line: String in hook.trace_of(tag):
		out.append(line.split(" ")[0])
	return out




func test_seats_are_every_living_country_in_id_order_from_the_rotating_start() -> void:
	var g := AiFixture.watch()
	var hook := g.orders as AiTurn
	hook.begin(g)
	assert_eq(hook.seats(), 13, "AI-only: every country")
	assert_eq(hook.seats_done(), 0)
	var starts: Array[int] = []
	for turn: int in [1, 2, 3, 14]:
		g.turn = turn
		var h := AiTurn.new()
		h.begin(g)
		h.step(g)
		for c: Country in g.countries:
			if not h.trace_of(c.tag).is_empty():
				starts.append(c.id)
	assert_eq(starts, [1, 2, 3, 1] as Array[int], "(turn - 1) mod 13, ids from 1")


func test_the_rotation_walks_every_seat_once_in_id_order() -> void:
	var g := AiFixture.watch()
	g.turn = 5
	var hook := AiTurn.new()
	hook.begin(g)
	var ids: Array[int] = []
	var seen := {}
	while not hook.step(g):
		for c: Country in g.countries:
			if not hook.trace_of(c.tag).is_empty() and not seen.has(c.tag):
				seen[c.tag] = true
				ids.append(c.id)
	for c: Country in g.countries:
		if not hook.trace_of(c.tag).is_empty() and not seen.has(c.tag):
			ids.append(c.id)
	assert_eq(ids, [5, 6, 7, 8, 9, 10, 11, 12, 13, 1, 2, 3, 4] as Array[int])


func test_the_player_and_the_passive_seats_are_out() -> void:
	var g := ArmyFixture.game()
	var hook := AiPlayers.attach(g)
	hook.begin(g)
	assert_eq(hook.seats(), 12, "the player's country is no seat")
	var skip: Array[StringName] = [&"FRA", &"MLO"]
	hook = AiPlayers.attach(g, skip)
	hook.begin(g)
	assert_eq(hook.seats(), 10)
	while not hook.step(g):
		pass
	for tag: StringName in [&"GEN", &"FRA", &"MLO"]:
		assert_true(hook.trace_of(tag).is_empty(), "no step for " + String(tag))


func test_no_seat_with_the_ai_disabled_and_the_turn_is_over_at_once() -> void:
	var g := AiFixture.watch()
	var hook := g.orders as AiTurn
	hook.enabled = false
	hook.begin(g)
	assert_eq([hook.seats(), hook.seats_done()], [0, 0])
	assert_true(hook.step(g))


func test_p_a_country_with_no_temperament_is_no_seat() -> void:
	var g := AiFixture.watch()
	g.scenario = g.scenario.duplicate() as ScenarioDef
	var fewer: Array[StringName] = []
	fewer.assign(g.scenario.tempers.slice(0, 12))
	g.scenario.tempers = fewer
	var hook := g.orders as AiTurn
	hook.begin(g)
	assert_eq(hook.seats(), 12, "the thirteenth has none")


func test_a_seat_runs_the_steps_of_4_2_in_order() -> void:
	var g := AiFixture.duel()
	var hook := g.orders as AiTurn
	hook.begin(g)
	assert_eq(hook.seats(), 1)
	var log_size := g.action_log.size()
	var turn_over := false
	var steps := 0
	while not turn_over:
		turn_over = hook.step(g)
		steps += 1
	assert_eq(_names(hook, AiFixture.MILAN), STEPS)
	assert_eq(steps, STEPS.size())
	assert_eq(hook.steps_done(), STEPS.size())
	assert_eq([hook.seats(), hook.seats_done()], [1, 1])
	assert_eq(g.action_log.size(), log_size, "the empty steps act nothing")
	var works_cards := 0
	for name: String in _names(hook, AiFixture.MILAN):
		works_cards += 1 if name == "works_card" else 0
	assert_lte(works_cards, g.defs.ai.works_cards, "works cards at most 4")
	assert_true(hook.step(g), "a turn that is over stays over")


func test_progress_counts_seats_done_one_by_one() -> void:
	var g := AiFixture.watch()
	var hook := g.orders as AiTurn
	hook.begin(g)
	var done: Array[int] = []
	while not hook.step(g):
		if done.is_empty() or done.back() != hook.seats_done():
			done.append(hook.seats_done())
	assert_eq(done, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] as Array[int])
	assert_eq(hook.seats_done(), 13)
	assert_eq(hook.steps_done(), 13 * STEPS.size())


func test_army_steps_one_an_army_and_a_refusal_adds_one_up_to_order_tries() -> void:
	var g := AiFixture.duel()
	var hook := g.orders as AiTurn
	hook.begin(g)
	while hook.trace_of(AiFixture.MILAN).is_empty() or _names(hook, AiFixture.MILAN).back() != "forces":
		hook.step(g)
	hook.push_step(AiTurn.ARMY, 7)
	hook.push_step(AiTurn.ARMY, 8)
	hook.step(g)
	assert_eq(hook.trace_of(AiFixture.MILAN)[-1], "army 7 peace")
	assert_true(hook.army_retry(g, AiFixture.MILAN, 7), "the first march was refused: one more")
	hook.step(g)
	assert_eq(hook.trace_of(AiFixture.MILAN)[-1], "army 7 peace", "the same army again, before the next")
	assert_false(hook.army_retry(g, AiFixture.MILAN, 7), "order_tries 2 is spent")
	while not hook.step(g):
		pass
	var tail: Array[String] = []
	tail.assign(Array(hook.trace_of(AiFixture.MILAN)).slice(-5))
	assert_eq(tail, ["army 7 peace", "army 7 peace", "army 8 peace", "tax 0", "done 0"] as Array[String])


func test_an_army_step_goes_to_the_war_module_at_war_and_the_peace_one_at_peace() -> void:
	var g := AiFixture.duel()
	var hook := g.orders as AiTurn
	WarFixture.at_war(g, AiFixture.MILAN, AiFixture.VENICE)
	hook.begin(g)
	while _names(hook, AiFixture.MILAN).is_empty() or _names(hook, AiFixture.MILAN).back() != "forces":
		hook.step(g)
	hook.push_step(AiTurn.ARMY, 3)
	hook.step(g)
	assert_eq(hook.trace_of(AiFixture.MILAN)[-1], "army 3 war")


func test_clear_drops_the_turn() -> void:
	var g := AiFixture.watch()
	var hook := g.orders as AiTurn
	hook.begin(g)
	hook.step(g)
	hook.step(g)
	hook.clear()
	assert_eq([hook.seats(), hook.seats_done(), hook.steps_done(), hook.refusals()], [0, 0, 0, 0])
	assert_true(hook.step(g))
	assert_true(hook.trace_of(AiFixture.MILAN).is_empty())
	assert_null(hook.brief_of(AiFixture.MILAN))


func test_a_turn_stepped_one_at_a_time_equals_the_turn_at_once() -> void:
	var once := AiFixture.watch()
	var piece := AiFixture.watch()
	var before := once.digest()
	Season.run_phase(once, &"ai_orders")
	Season.orders_begin(piece)
	var steps := 0
	while not Season.orders_step(piece):
		steps += 1
	Season.orders_end(piece)
	assert_gt(steps, 100, "13 seats of 13 steps, one at a time")
	assert_eq(piece.digest(), once.digest())
	assert_eq(JSON.stringify(piece.action_log), JSON.stringify(once.action_log))
	assert_eq(piece.digest(), before, "empty steps change nothing")
	var a := once.orders as AiTurn
	var b := piece.orders as AiTurn
	for c: Country in once.countries:
		assert_eq(b.trace_of(c.tag), a.trace_of(c.tag))
		assert_eq([b.brief_of(c.tag).treasury, b.brief_of(c.tag).net, b.brief_of(c.tag).goal_men, b.brief_of(c.tag).posts],
			[a.brief_of(c.tag).treasury, a.brief_of(c.tag).net, a.brief_of(c.tag).goal_men, a.brief_of(c.tag).posts])
	for _n: int in 3:
		Season.run(once)
		Season.run(piece)
	assert_eq(piece.digest(), once.digest(), "and over whole seasons")
	assert_eq(JSON.stringify(piece.action_log), JSON.stringify(once.action_log))


func test_the_hook_is_not_state() -> void:
	var plain := ArmyFixture.game()
	var hooked := ArmyFixture.game()
	AiPlayers.attach(hooked)
	assert_eq(hooked.digest(), plain.digest(), "attaching changes nothing in the digest")


# ----- the brief (4.5) ------------------------------------------------------------------------------------------------


func _milan_at_war() -> Game:
	var g := AiFixture.duel()
	WarFixture.at_war(g, AiFixture.MILAN, AiFixture.VENICE)
	return g


func test_the_brief_of_a_seat_in_peace() -> void:
	var g := AiFixture.duel()
	var m := AiFixture.MILAN
	var b := AiBrief.make(g, m)
	assert_eq([b.tag, b.id], [m, 5] as Array)
	assert_eq(b.temper.key, &"opportunist", "the scenario's tempers, id 5")
	assert_eq(b.ai, g.defs.ai)
	assert_eq(b.treasury, Countries.by_tag(g, m).treasury)
	assert_eq(b.net, int(EconomyPreview.expected(g, m)["net"]))
	assert_eq(b.reserve, b.temper.reserve_seasons * maxi(b.upkeep, b.ai.min_upkeep))
	assert_eq(b.army_room, maxi(0, (b.net + Military.upkeep_country(g, m)) * b.temper.army_upkeep_share / 1000))
	assert_eq(b.men, Wars.men_under_arms(g, m))
	assert_eq(b.enemies.size(), 0)
	var permille := b.temper.war_army_permille if not b.threats.is_empty() else b.temper.army_permille
	assert_eq(b.goal_men, maxi(b.ai.min_army_men, b.people * permille / 1000))
	assert_eq(b.declared_now.size() + b.claims.size() + b.wanted_cost + b.cards.size(), 0)


func test_the_brief_at_war_has_the_enemy_as_a_threat_and_the_war_goal() -> void:
	var g := _milan_at_war()
	var m := AiFixture.MILAN
	var b := AiBrief.make(g, m)
	assert_eq(b.enemies, [AiFixture.VENICE] as Array[StringName])
	assert_true(b.threats.has(AiFixture.VENICE))
	assert_eq(b.goal_men, maxi(b.ai.min_army_men, b.people * b.temper.war_army_permille / 1000))
	var ids: Array[int] = []
	for t: StringName in b.threats:
		ids.append(AiKnow.id_of(g, t))
	var sorted := ids.duplicate()
	sorted.sort()
	assert_eq(ids, sorted, "threats in id order")


func test_think_is_turn_plus_id_modulo_think_every() -> void:
	var g := AiFixture.duel()
	var expect := {1: false, 3: true, 7: true, 4: false}
	for turn: int in expect:
		g.turn = turn
		assert_eq(AiBrief.make(g, AiFixture.MILAN).think, bool(expect[turn]), "turn %d + id 5" % turn)


func test_the_front_is_own_hexes_beside_a_threats_land() -> void:
	var g := _milan_at_war()
	var m := AiFixture.MILAN
	var b := AiBrief.make(g, m)
	var want: Array[int] = []
	for i: int in AiKnow.controlled(g, m):
		for beside: Vector2i in AiKnow.land_neighbours(g, g.map.hex_of(i)):
			if b.threats.has(AiKnow.owner_of(g, beside)) or b.threats.has(AiKnow.controller_of(g, beside)):
				want.append(i)
				break
	var got: Array[int] = []
	got.assign(b.front)
	assert_gt(got.size(), 0, "Milan borders Venice")
	assert_eq(got, want)
	for k: int in range(1, got.size()):
		assert_gt(got[k], got[k - 1], "hex index order")


func test_posts_are_the_depot_nearest_each_threat_then_the_capital_without_duplicates() -> void:
	var g := _milan_at_war()
	var m := AiFixture.MILAN
	var b := AiBrief.make(g, m)
	assert_gt(b.posts.size(), 0)
	var depots := AiKnow.depots(g, m)
	var best := Army.NO_HEX
	var best_d := 1 << 30
	for depot: Vector2i in depots:
		for i: int in AiKnow.land_of(g, AiFixture.VENICE):
			var d := AiKnow.hex_distance(depot, g.map.hex_of(i))
			if d < best_d:
				best_d = d
				best = depot
	var want: Array[Vector2i] = []
	if best != Army.NO_HEX:
		want.append(best)
	if AiKnow.capital_of(g, m) != Army.NO_HEX and not want.has(AiKnow.capital_of(g, m)):
		want.append(AiKnow.capital_of(g, m))
	assert_eq(b.posts, want)
	var plain := AiFixture.duel()
	var calm := AiBrief.make(plain, m)
	if AiKnow.capital_of(plain, m) != Army.NO_HEX and calm.threats.is_empty():
		assert_eq(calm.posts, [AiKnow.capital_of(plain, m)] as Array[Vector2i], "no threat: the capital")


func test_post_of_gives_the_armies_by_men_the_posts_round_robin() -> void:
	var g := _milan_at_war()
	var m := AiFixture.MILAN
	var held := AiKnow.land_of(g, m)
	var small := WarFixture.army_at(g, m, g.map.hex_of(held[0]), 1)
	var big := WarFixture.army_at(g, m, g.map.hex_of(held[1]), 5)
	var twin := WarFixture.army_at(g, m, g.map.hex_of(held[2]), 1)
	var mid := WarFixture.army_at(g, m, g.map.hex_of(held[3]), 3)
	var b := AiBrief.make(g, m)
	assert_gt(b.posts.size(), 0)
	var ranked: Array[Army] = [big, mid, small, twin]
	for i: int in ranked.size():
		assert_eq(b.post_of(ranked[i].id), b.posts[i % b.posts.size()], "army %d: by men, ties by id" % i)
	assert_eq(b.post_of(9999), Army.NO_HEX, "an unknown army has no post")


func test_p_a_seat_with_no_post_gives_no_hex() -> void:
	var g := AiFixture.duel()
	var b := AiBrief.make(g, AiFixture.MILAN)
	b.posts = []
	assert_eq(b.post_of(1), Army.NO_HEX)
