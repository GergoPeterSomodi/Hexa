## The computer builds barracks (docs/design/recruitment-queue.md section 7; task RQ4): the wanted number per country, what
## counts toward it, the reserve (waived with none), one at a time, the work slot, the place and the step's turn before the
## works. The step runs alone on a brief whose front, threats, seen armies and reserve a test plants. Every planted number
## of the AI is in a duplicate of the sub-resource: the committed ones are shared and never mutated.
@warning_ignore_start("integer_division")
extends GutTest

const MLO := &"MLO"
const SAV := &"SAV"
const GEN := &"GEN"
## The first settlement level a barracks is built in.
const TOWN := 3
## The ducats of a barracks (decision 20).
const COST := 150
## The seasons of the short AI-only game.
const SEASONS := 8


## The 1480 game, calm, nobody's turn run yet.
func _game() -> Game:
	return AiFixture.watch()


func _brief(g: Game, tag: StringName = MLO) -> AiBrief:
	return AiBrief.make(g, tag)


## Runs the barracks step alone; {acts: the hexes it built on, line: its note, refusals}.
func _step(g: Game, b: AiBrief) -> Dictionary:
	var hook := AiTurn.new()
	var built: Array[Vector2i] = []
	hook.judge = func(_t: StringName, action: String, args: Dictionary, verdict: Dictionary, result: Dictionary) -> void:
		if action == "build_barracks" and bool(verdict.get("ok", false)) and bool(result.get("ok", false)):
			built.append(args["hex"] as Vector2i)
	AiBarracks.barracks(hook, g, b, 0)
	var line := ""
	for text: String in hook.trace_of(b.tag):
		if text.begins_with("barracks:"):
			line = text
	return {"acts": built, "line": line, "refusals": hook.refusals()}


## The settlements of `tag` of a town or larger with no barracks, hex index order.
func _free_towns(g: Game, tag: StringName = MLO) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in Territory.districts(g, Countries.by_tag(g, tag).id):
		if int(g.state.main_use[i]) == ImproveRules.SETTLEMENT and g.state.barracks[i] == 0 and int(g.state.level[i]) >= TOWN:
			out.append(g.map.hex_of(i))
	return out


## The hex of `hexes` nearest to `to` (`far`: farthest from it); ties: the lower hex index (the list's order).
func _pick(hexes: Array[Vector2i], to: Vector2i, far: bool = false) -> Vector2i:
	var best := Army.NO_HEX
	var best_d := 0
	for hex: Vector2i in hexes:
		var d := ImproveRules.hex_distance(hex, to)
		if best == Army.NO_HEX or (d > best_d if far else d < best_d):
			best = hex
			best_d = d
	return best


## Sets a country's treasury through the developer's door.
func _money(g: Game, ducats: int, tag: StringName = MLO) -> void:
	g.dev_money(tag, ducats - Countries.by_tag(g, tag).treasury)


## Takes every barracks of a country away (a test's state).
func _strip(g: Game, tag: StringName = MLO) -> void:
	for i: int in Territory.districts(g, Countries.by_tag(g, tag).id):
		g.state.barracks[i] = 0
	g.districts.clear()
	g.version += 1


func _front(g: Game, b: AiBrief, hexes: Array[Vector2i]) -> void:
	var out := PackedInt32Array()
	for hex: Vector2i in hexes:
		out.append(g.map.index_of(hex))
	out.sort()
	b.front = out


## Begins builds and upgrades away from the free towns (the barracks' places) until `leave` of Milan's work slots are free;
## the hexes begun on.
func _fill_slots(g: Game, leave: int = 0) -> Array[Vector2i]:
	g.dev_money(MLO, 5000)
	for good: int in g.defs.goods.size():
		g.dev_goods(MLO, good, 100)
	var spared := _free_towns(g)
	var begun: Array[Vector2i] = []
	for hex: Vector2i in AiKnow.work_candidates(g, MLO):
		if AiKnow.slots_free(g, MLO) <= leave:
			break
		if spared.has(hex):
			continue
		var done := false
		if AiKnow.use_at(g, hex).x != 0:
			done = bool(g.act("upgrade", {"hex": hex, "tag": MLO})["ok"])
		else:
			for option: Dictionary in Improve.build_options(g, hex):
				if not done and bool(option.get("ok", false)):
					done = bool(g.act("build", {"hex": hex, "family": int(option["family_id"]), "tag": MLO})["ok"])
		if done:
			begun.append(hex)
	return begun


# ----- the wanted number -------------------------------------------------------------------------------------------------


func test_the_wanted_number_of_each_country_at_the_start() -> void:
	var g := _game()
	var got := {}
	for c: Country in g.countries:
		got[c.tag] = AiBarracks.wanted(g, _brief(g, c.tag))
	var want := {}
	for c: Country in g.countries:
		want[c.tag] = 1
	want[&"MLO"] = 3
	want[&"VEN"] = 3
	want[&"SAV"] = 2
	want[&"SWI"] = 2
	assert_eq(got, want, "section 7: Milan and Venice 3, Savoy and Switzerland 2, the rest 1")


func test_the_war_goal_over_four_companies_rounded_up_at_least_one() -> void:
	var g := _game()
	assert_eq(AiKnow.company_men(g), 500, "a company of pikemen")
	var b := _brief(g)
	b.temper = b.temper.duplicate() as AiTemperDef
	b.temper.war_army_permille = 0  # the goal is then the least army alone
	b.ai = b.ai.duplicate() as AiDef
	var got: Array[int] = []
	for goal: int in [0, 1, 2000, 2001, 4000, 4001]:
		b.ai.min_army_men = goal
		got.append(AiBarracks.wanted(g, b))
	assert_eq(got, [1, 1, 1, 2, 2, 3] as Array[int])
	b.ai.companies_per_barracks = 1
	assert_eq(AiBarracks.wanted(g, b), 9, "4,001 men over 500 a barracks")


func test_the_war_goal_is_used_in_peace_too() -> void:
	var g := _game()
	var peace := _brief(g)
	assert_eq(peace.enemies, [] as Array[StringName], "precondition: Milan at peace")
	var at_peace := AiBarracks.wanted(g, peace)
	WarFixture.at_war(g, MLO, SAV)
	g.version += 1
	assert_eq(AiBarracks.wanted(g, _brief(g)), at_peace)
	var goal := maxi(peace.ai.min_army_men, peace.people * peace.temper.war_army_permille / 1000)
	assert_eq(at_peace, ceili(float(goal) / 2000.0))
	assert_gt(peace.temper.war_army_permille, peace.temper.army_permille, "the war share is the larger one")


# ----- what counts -------------------------------------------------------------------------------------------------------


func test_the_usable_barracks_are_the_countrys_own_unoccupied_ones() -> void:
	var g := _game()
	var capital := Countries.by_tag(g, MLO).capital
	assert_eq(AiKnow.usable_barracks(g, MLO), [capital] as Array[Vector2i])
	WarFixture.at_war(g, SAV, MLO)
	var s := Siege.new()
	s.hex = capital
	s.besieger = SAV
	g.sieges.append(s)
	g.version += 1
	assert_eq(AiKnow.usable_barracks(g, MLO), [capital] as Array[Vector2i], "a besieged one still counts")
	g.sieges.clear()
	var theirs := AiKnow.usable_barracks(g, SAV)
	Occupation.capture(g, capital, SAV, &"walk", {})
	g.version += 1
	assert_eq(AiKnow.usable_barracks(g, MLO), [] as Array[Vector2i], "occupied")
	assert_eq(AiKnow.usable_barracks(g, SAV), theirs, "and not the occupier's")
	g.dev_transfer([capital] as Array[Vector2i], Countries.by_tag(g, SAV).id)
	assert_true(AiKnow.usable_barracks(g, SAV).has(capital), "ceded: the winner's")


func test_the_works_under_way_count_while_the_land_is_the_countrys() -> void:
	var g := _game()
	var town := _free_towns(g)[0]
	assert_eq(AiKnow.barracks_under_way(g, MLO), 0)
	assert_eq(_fill_slots(g, Works.slots(g, MLO) - 1).size(), 1, "precondition: another work runs")
	assert_eq(AiKnow.barracks_under_way(g, MLO), 0, "an upgrade or a build is no barracks")
	assert_true(bool(g.act("build_barracks", {"hex": town, "tag": MLO})["ok"]))
	assert_eq([AiKnow.barracks_under_way(g, MLO), AiKnow.barracks_under_way(g, SAV)], [1, 0])
	WarFixture.at_war(g, SAV, MLO)
	var s := Siege.new()
	s.hex = town
	s.besieger = SAV
	g.sieges.append(s)
	g.version += 1
	assert_eq(AiKnow.barracks_under_way(g, MLO), 1, "halted by a siege: still under way")
	g.sieges.clear()
	Occupation.capture(g, town, SAV, &"walk", {})
	g.version += 1
	assert_eq([AiKnow.barracks_under_way(g, MLO), AiKnow.barracks_under_way(g, SAV)], [0, 0], "occupied: nobody's")
	g.dev_transfer([town] as Array[Vector2i], Countries.by_tag(g, SAV).id)
	assert_eq([AiKnow.barracks_under_way(g, MLO), AiKnow.barracks_under_way(g, SAV)], [0, 0],
		"lost land: the work is lost with it, and is not the winner's")


func test_a_work_on_occupied_land_holds_back_no_new_barracks() -> void:
	var g := _game()
	_money(g, 5000)
	var town := _free_towns(g)[0]
	assert_true(bool(g.act("build_barracks", {"hex": town, "tag": MLO})["ok"]))
	WarFixture.at_war(g, SAV, MLO)
	Occupation.capture(g, town, SAV, &"walk", {})
	g.version += 1
	var got := _step(g, _brief(g))
	assert_eq((got["acts"] as Array).size(), 1, str(got["line"]))
	assert_string_starts_with(str(got["line"]), "barracks: wanted 3, usable 1, under way 0: builds at ")


# ----- the step ----------------------------------------------------------------------------------------------------------


func test_a_country_short_of_barracks_builds_one() -> void:
	var g := _game()
	var b := _brief(g)
	var got := _step(g, b)
	assert_eq((got["acts"] as Array).size(), 1, str(got["line"]))
	assert_eq(AiKnow.barracks_under_way(g, MLO), 1)
	assert_eq(g.action_log.back()["action"], "build_barracks", "through the player's door")
	assert_string_starts_with(str(got["line"]), "barracks: wanted 3, usable 1, under way 0: builds at ")


func test_a_country_with_enough_builds_none() -> void:
	var g := _game()
	var b := _brief(g, GEN)
	_money(g, 5000, GEN)
	var before := g.digest()
	var got := _step(g, b)
	assert_eq(got["line"], "barracks: wanted 1, usable 1, under way 0: enough")
	assert_eq(g.digest(), before)


func test_never_above_the_wanted_number() -> void:
	var g := _game()
	_money(g, 5000)
	var towns := _free_towns(g)
	assert_true(g.dev_barracks(towns[0]))
	assert_true(g.dev_barracks(towns[1]))
	var got := _step(g, _brief(g))
	assert_eq(got["line"], "barracks: wanted 3, usable 3, under way 0: enough")
	assert_true(g.dev_barracks(towns[2]))
	assert_eq(_step(g, _brief(g))["acts"], [] as Array[Vector2i], "over it (ceded land): none either")


func test_fewer_than_wanted_one_at_a_time() -> void:
	var g := _game()
	_money(g, 5000)
	assert_eq((_step(g, _brief(g))["acts"] as Array).size(), 1)
	var got := _step(g, _brief(g))
	assert_eq(got["line"], "barracks: wanted 3, usable 1, under way 1: one at a time")
	assert_eq(AiKnow.barracks_under_way(g, MLO), 1)


func test_a_work_under_way_counts_as_one() -> void:
	var g := _game()
	_strip(g, GEN)
	_money(g, 5000, GEN)
	assert_eq((_step(g, _brief(g, GEN))["acts"] as Array).size(), 1, "Genoa with none builds")
	var got := _step(g, _brief(g, GEN))
	assert_eq(got["line"], "barracks: wanted 1, usable 0, under way 1: enough")


func test_with_fewer_than_wanted_the_reserve_is_kept() -> void:
	var g := _game()
	_money(g, COST + 96 - 1)
	var b := _brief(g)
	b.reserve = 96
	var got := _step(g, b)
	assert_eq(got["acts"], [] as Array[Vector2i])
	assert_string_ends_with(str(got["line"]), "T 245 - cost 150 under the reserve R 96")
	_money(g, COST + 96)
	assert_eq((_step(g, b)["acts"] as Array).size(), 1, "exactly the reserve left is enough")
	assert_eq(Countries.by_tag(g, MLO).treasury, 96)


func test_with_none_the_reserve_is_waived() -> void:
	var g := _game()
	_strip(g)
	_money(g, COST)
	var b := _brief(g)
	b.reserve = 96
	var got := _step(g, b)
	assert_eq((got["acts"] as Array).size(), 1, str(got["line"]))
	assert_string_ends_with(str(got["line"]), "(waived: it has none)")
	assert_eq(Countries.by_tag(g, MLO).treasury, 0)


func test_with_none_it_waits_until_it_can_pay() -> void:
	var g := _game()
	_strip(g)
	_money(g, COST - 1)
	var before := g.digest()
	var got := _step(g, _brief(g))
	assert_eq(got["acts"], [] as Array[Vector2i])
	assert_eq(got["refusals"], 0, "no act is asked that the check refuses")
	assert_string_contains(str(got["line"]), "cannot pay (not enough ducats")
	assert_eq(g.digest(), before)
	_money(g, COST)
	g.dev_goods(MLO, g.defs.good_id(&"stone"), -1000)
	got = _step(g, _brief(g))
	assert_eq(got["acts"], [] as Array[Vector2i])
	assert_string_contains(str(got["line"]), "stone")
	g.dev_goods(MLO, g.defs.good_id(&"stone"), 10)
	assert_eq((_step(g, _brief(g))["acts"] as Array).size(), 1)


func test_it_takes_a_free_work_slot_only() -> void:
	var g := _game()
	var begun := _fill_slots(g)
	assert_eq(AiKnow.slots_free(g, MLO), 0, "precondition: every slot taken")
	var got := _step(g, _brief(g))
	assert_eq(got["line"], "barracks: wanted 3, usable 1, under way 0: no free work slot")
	assert_eq([got["acts"], got["refusals"]], [[] as Array[Vector2i], 0])
	g.act("cancel_work", {"hex": begun[0], "tag": MLO})
	assert_eq((_step(g, _brief(g))["acts"] as Array).size(), 1)
	assert_eq(AiKnow.slots_free(g, MLO), 0, "the barracks holds the slot")


func test_the_step_comes_before_the_works_and_has_the_first_claim_on_a_slot() -> void:
	var g := AiFixture.watch()
	_fill_slots(g, 1)
	assert_eq(AiKnow.slots_free(g, MLO), 1, "precondition: one slot")
	var acts := AiFixture.seat(g, MLO)
	var works: Array[String] = []
	for act: Dictionary in acts:
		if ["build", "upgrade", "build_barracks"].has(act["action"]):
			works.append(str(act["action"]))
	assert_eq(works, ["build_barracks"] as Array[String])


# ----- the place ---------------------------------------------------------------------------------------------------------


func test_with_no_front_the_town_nearest_the_capital() -> void:
	var g := _game()
	_money(g, 5000)
	var b := _brief(g)
	b.front = PackedInt32Array()
	var want := _pick(_free_towns(g), Countries.by_tag(g, MLO).capital)
	assert_eq(_step(g, b)["acts"], [want] as Array[Vector2i])


func test_off_the_front_nearest_the_front_first() -> void:
	var g := _game()
	_money(g, 5000)
	var towns := _free_towns(g)
	var capital := Countries.by_tag(g, MLO).capital
	var edge := _pick(towns, capital, true)  # the town farthest from the capital is the front
	var b := _brief(g)
	_front(g, b, [edge] as Array[Vector2i])
	var behind := towns.duplicate()
	behind.erase(edge)
	var want := _pick(behind, edge)
	assert_ne(want, _pick(towns, capital), "precondition: the front changes the choice")
	assert_eq(AiBarracks.place_order(g, b).back(), edge, "the front town comes last")
	assert_eq(_step(g, b)["acts"], [want] as Array[Vector2i])


func test_a_town_on_the_front_only_when_no_other_will_do() -> void:
	var g := _game()
	_money(g, 5000)
	var towns := _free_towns(g)
	var spared := towns[towns.size() - 1]
	var line := towns.duplicate()
	line.erase(spared)
	var b := _brief(g)
	_front(g, b, line)
	b.seen = [{"hex": spared}] as Array[Dictionary]  # even with the enemy beside it
	assert_eq(_step(g, b)["acts"], [spared] as Array[Vector2i])


func test_all_on_the_front_the_farthest_from_a_seen_enemy() -> void:
	var g := _game()
	_money(g, 5000)
	var towns := _free_towns(g)
	var enemy := towns[0]
	var b := _brief(g)
	_front(g, b, AiKnow.settlements(g, MLO))
	b.threats = [] as Array[StringName]
	b.seen = [{"hex": enemy}] as Array[Dictionary]
	var want := _pick(towns, enemy, true)
	assert_ne(want, enemy)
	assert_eq(_step(g, b)["acts"], [want] as Array[Vector2i])


func test_all_on_the_front_the_farthest_from_the_threats_known_settlements() -> void:
	var g := _game()
	_money(g, 5000)
	var theirs := AiKnow.known_settlements(g, MLO, SAV)
	assert_gt(theirs.size(), 0, "precondition: Milan has discovered a settlement of Savoy")
	var b := _brief(g)
	_front(g, b, AiKnow.settlements(g, MLO))
	b.threats = [SAV] as Array[StringName]
	b.seen = [] as Array[Dictionary]
	var want := Army.NO_HEX
	var want_d := -1
	for hex: Vector2i in _free_towns(g):
		var d := ImproveRules.hex_distance(hex, _pick(theirs, hex))
		if d > want_d:
			want = hex
			want_d = d
	assert_eq(_step(g, b)["acts"], [want] as Array[Vector2i])


func test_the_known_settlements_are_the_discovered_ones() -> void:
	var g := _game()
	var viewer := Countries.by_tag(g, MLO)
	var shown: Array[Vector2i] = []
	var hidden := 0
	for i: int in Territory.districts(g, Countries.by_tag(g, SAV).id):
		if int(g.state.main_use[i]) != ImproveRules.SETTLEMENT:
			continue
		var hex := g.map.hex_of(i)
		if Sight.sees(g, MLO, hex):
			shown.append(hex)
		else:  # the start game has all of Savoy discovered: forget what Milan does not see now
			viewer.explored[i >> 3] &= ~(1 << (i & 7))
			hidden += 1
	g.version += 1
	assert_gt(shown.size(), 0, "precondition: Milan sees a settlement of Savoy")
	assert_gt(hidden, 0, "precondition: and does not see another")
	assert_eq(AiKnow.known_settlements(g, MLO, SAV), shown)


func test_a_place_the_check_refuses_is_passed_over() -> void:
	var g := _game()
	_money(g, 5000)
	var towns := _free_towns(g)
	var capital := Countries.by_tag(g, MLO).capital
	var first := _pick(towns, capital)
	var rest := towns.duplicate()
	rest.erase(first)
	WarFixture.at_war(g, SAV, MLO)
	var s := Siege.new()
	s.hex = first
	s.besieger = SAV
	g.sieges.append(s)
	g.version += 1
	var b := _brief(g)
	b.front = PackedInt32Array()
	b.reserve = 0
	var got := _step(g, b)
	assert_eq(got["acts"], [_pick(rest, capital)] as Array[Vector2i])
	assert_eq(got["refusals"], 0)


func test_no_town_no_barracks() -> void:
	var g := _game()
	_money(g, 5000)
	for hex: Vector2i in _free_towns(g):
		g.state.level[g.map.index_of(hex)] = TOWN - 1
	g.districts.clear()
	g.version += 1
	var got := _step(g, _brief(g))
	assert_eq(got["acts"], [] as Array[Vector2i])
	assert_string_ends_with(str(got["line"]), "no place for one")


# ----- whole turns -------------------------------------------------------------------------------------------------------


func test_in_an_ai_game_barracks_are_begun_only_under_the_wanted_number() -> void:
	var g := AiFixture.watch()
	var hook := g.orders as AiTurn
	var begun: Array[String] = []
	var over: Array[String] = []
	hook.judge = func(tag: StringName, action: String, args: Dictionary, _verdict: Dictionary, result: Dictionary) -> void:
		if action != "build_barracks" or not bool(result.get("ok", false)):
			return
		begun.append("%s %s turn %d" % [tag, str(args["hex"]), g.turn])
		# Counted after the act: the new work is among those under way.
		var have := AiKnow.usable_barracks(g, tag).size() + AiKnow.barracks_under_way(g, tag)
		if have > AiBarracks.wanted(g, hook.brief_of(tag)):
			over.append("%s has %d" % [tag, have])
	for _n: int in SEASONS:
		Season.run(g)
	assert_gt(begun.size(), 0, "some country begins a barracks")
	assert_eq(over, [] as Array[String], str(begun))
