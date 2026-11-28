## The AI's turn and the seat's brief (docs/architecture/m8-build-spec.md 4.2, 4.5, 4.12, 5.5, 9): the seats and their order, the
## step queue and what a step may append, the progress counts, clear(), the dispatch of an army's step, a turn run a step at a
## time equal to the turn run at once; and AiBrief.make field by field with post_of. The step modules act (group C filled them): a
## step's own trace lines ("works_card 0: ...", "did build ...", "tax: ...") sit between the step lines, so the tests read the step
## lines only (_steps); the equality is of the digest, the log, the traces and the briefs.
@warning_ignore_start("integer_division")
extends GutTest

const LIMIT := 5000
const STEPS: Array[String] = ["brief", "peace", "war", "barracks", "works_scan", "works_scan", "works_card", "works_card",
	"works_card", "works_card", "works_act", "forces", "tax", "done"]


## The names of a seat's trace lines in order ("works_scan 1" -> "works_scan"; an army line -> "army").
func _names(hook: AiTurn, tag: StringName) -> Array[String]:
	var out: Array[String] = []
	for line: String in _steps(hook, tag):
		out.append(line.split(" ")[0])
	return out


## A seat's step lines ("war 0", "army 7 peace"), without the acts ("did ...", "refused ..."), the steps' own notes (a colon, or
## "army 9 aim walk_in ...", "army 9 standing ..."): a step line is a name and a number, or "army <id> war|peace".
func _steps(hook: AiTurn, tag: StringName) -> Array[String]:
	var out: Array[String] = []
	for line: String in hook.trace_of(tag):
		if line.begins_with("did ") or line.begins_with("refused ") or line.contains(":"):
			continue
		var parts := line.split(" ")
		if parts.size() == 2 or (parts.size() == 3 and parts[0] == "army" and (parts[2] == "war" or parts[2] == "peace")):
			out.append(line)
	return out


## The fixed steps of a seat: its step names without the army steps.
func _fixed(hook: AiTurn, tag: StringName) -> Array[String]:
	var out: Array[String] = []
	for name: String in _names(hook, tag):
		if name != "army":
			out.append(name)
	return out


## Steps until the turn is over, at most LIMIT (a hung turn fails, it never hangs the run); the steps taken.
func _run_out(hook: AiTurn, g: Game) -> int:
	var steps := 0
	while steps < LIMIT and not hook.step(g):
		steps += 1
	assert_lt(steps, LIMIT, "the turn ends within the guard")
	return steps + 1


## Steps until the seat's last step line starts with WANT, at most LIMIT; true when it got there.
func _run_to(hook: AiTurn, g: Game, tag: StringName, want: String) -> bool:
	for _n: int in LIMIT:
		var lines := _steps(hook, tag)
		if not lines.is_empty() and (lines[-1] as String).begins_with(want):
			return true
		if hook.step(g):
			return false
	return false




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
	var guard := 0
	while guard < LIMIT and not hook.step(g):
		guard += 1
		for c: Country in g.countries:
			if not hook.trace_of(c.tag).is_empty() and not seen.has(c.tag):
				seen[c.tag] = true
				ids.append(c.id)
	assert_lt(guard, LIMIT, "the turn ends within the guard")
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
	_run_out(hook, g)
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
	var steps := _run_out(hook, g)
	var order := _names(hook, AiFixture.MILAN)
	var armies := order.count("army")
	assert_eq(_fixed(hook, AiFixture.MILAN), STEPS, "the fixed steps in the order of 4.2")
	if armies > 0:
		var first := order.find("army")
		assert_eq(order[first - 1], "forces", "the army steps follow the forces step")
		assert_eq(order[first + armies], "tax", "and come before the tax")
	assert_eq(steps, STEPS.size() + armies, "the fixed steps and the armies appended")
	assert_eq(hook.steps_done(), steps)
	assert_eq([hook.seats(), hook.seats_done()], [1, 1])
	for entry: Dictionary in g.action_log.slice(log_size):
		assert_eq(str((entry["args"] as Dictionary).get("tag", "MLO")), "MLO", "only Milan's seat acts: " + str(entry))
	var works_cards := _names(hook, AiFixture.MILAN).count("works_card")
	assert_lte(works_cards, g.defs.ai.works_cards, "works cards at most 4")
	assert_true(hook.step(g), "a turn that is over stays over")


func test_progress_counts_seats_done_one_by_one() -> void:
	var g := AiFixture.watch()
	var hook := g.orders as AiTurn
	hook.begin(g)
	var done: Array[int] = []
	var guard := 0
	done.append(hook.seats_done())
	while guard < LIMIT and not hook.step(g):
		guard += 1
		if done.back() != hook.seats_done():
			done.append(hook.seats_done())
	assert_lt(guard, LIMIT, "the turn ends within the guard")
	assert_eq(done, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] as Array[int])
	assert_eq(hook.seats_done(), 13)
	var armies := 0
	for c: Country in g.countries:
		armies += _names(hook, c.tag).count("army")
	assert_eq(hook.steps_done(), 13 * STEPS.size() + armies, "13 fixed steps a seat and the army steps the forces appended")


func test_army_steps_one_an_army_and_a_refusal_adds_one_up_to_order_tries() -> void:
	var g := AiFixture.watch()
	var hook := g.orders as AiTurn
	hook.begin(g)
	_run_out(hook, g)
	var tries: int = g.defs.ai.order_tries
	var armies := 0
	var retried := 0
	var any_retry := false
	for c: Country in g.countries:
		var seen := {}
		var last := -1
		for line: String in _steps(hook, c.tag):
			if not line.begins_with("army "):
				continue
			var id := int(line.split(" ")[1])
			seen[id] = int(seen.get(id, 0)) + 1
			assert_lte(int(seen[id]), tries, "an army has at most order_tries steps a season: " + line)
			if seen[id] == 1:
				assert_gt(id, last, "the first steps of the armies run in id order")
				last = id
				armies += 1
			else:
				retried += 1
				any_retry = true
	if any_retry:
		assert_gt(hook.refusals(), 0, "an army's second step answers a refusal")
	assert_gt(armies, 0, "the seats have armies to step")
	assert_eq(hook.steps_done(), 13 * STEPS.size() + armies + retried)


func test_a_pushed_army_step_runs_next_and_army_retry_stops_at_order_tries() -> void:
	var g := AiFixture.duel()
	var hook := g.orders as AiTurn
	hook.begin(g)
	assert_true(_run_to(hook, g, AiFixture.MILAN, "tax"), "the seat reaches its tax step")
	hook.push_step(AiTurn.ARMY, 9999)
	hook.push_step(AiTurn.ARMY, 9998)
	hook.step(g)
	assert_eq(_steps(hook, AiFixture.MILAN)[-1], "army 9999 peace")
	assert_true(hook.army_retry(g, AiFixture.MILAN, 9999), "the first march was refused: one more")
	hook.step(g)
	assert_eq(_steps(hook, AiFixture.MILAN)[-1], "army 9999 peace", "the same army again, before the next")
	assert_false(hook.army_retry(g, AiFixture.MILAN, 9999), "order_tries 2 is spent")
	_run_out(hook, g)
	var tail: Array[String] = []
	tail.assign(Array(_steps(hook, AiFixture.MILAN)).slice(-4))
	assert_eq(tail, ["army 9999 peace", "army 9999 peace", "army 9998 peace", "done 0"] as Array[String])


func test_an_army_step_goes_to_the_war_module_at_war_and_the_peace_one_at_peace() -> void:
	var g := AiFixture.duel()
	var hook := g.orders as AiTurn
	WarFixture.at_war(g, AiFixture.MILAN, AiFixture.VENICE)
	hook.begin(g)
	assert_true(_run_to(hook, g, AiFixture.MILAN, "tax"))
	hook.push_step(AiTurn.ARMY, 9999)
	hook.step(g)
	assert_eq(_steps(hook, AiFixture.MILAN)[-1], "army 9999 war")


func test_clear_drops_the_turn() -> void:
	var g := AiFixture.watch()
	var hook := g.orders as AiTurn
	hook.begin(g)
	hook.step(g)
	hook.step(g)
	assert_gt(hook.steps_done(), 0)
	hook.clear()
	assert_eq([hook.seats(), hook.seats_done(), hook.steps_done(), hook.refusals()], [0, 0, 0, 0])
	assert_true(hook.step(g))
	assert_true(hook.trace_of(AiFixture.MILAN).is_empty())
	assert_null(hook.brief_of(AiFixture.MILAN))


func test_a_turn_stepped_one_at_a_time_equals_the_turn_at_once() -> void:
	var once := AiFixture.watch()
	var piece := AiFixture.watch()
	Season.run_phase(once, &"ai_orders")
	Season.orders_begin(piece)
	var steps := 0
	while steps < LIMIT and not Season.orders_step(piece):
		steps += 1
	assert_lt(steps, LIMIT, "the turn ends within the guard")
	Season.orders_end(piece)
	assert_gt(steps, 13 * STEPS.size() - 1, "13 seats of 14 fixed steps and the army steps, one at a time")
	assert_eq((piece.orders as AiTurn).steps_done(), steps + 1)
	assert_eq(piece.digest(), once.digest())
	assert_eq(JSON.stringify(piece.action_log), JSON.stringify(once.action_log))
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
