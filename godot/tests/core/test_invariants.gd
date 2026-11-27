## The invariants of the soak (docs/architecture/m8-build-spec.md 4.17, 9): three AI-only seasons break none, and each invariant has a
## planted fault that breaks it (P each): a turn that did not move, a treasury edited outside a ledger, a stock below 0, a hex below
## 0 people, a person from nowhere, a land hex with no owner, a company at 0 men, two countries on a hex, a live battle at idle, a
## garrison over full, a morale past 1,000, a war past 40 seasons (two live wars of a pair, a war in a truce), a chronicle out of
## turn order, a stats row missing, the fog invariants (an explored hex lost; a controlled hex not explored by its controller,
## fog spec R4 and section 7), the judge's problem and the logger's error. The soak's counting judge is read too.
## Moves in the month (moves-build-spec.md 8.4): I1 to I8, each with its planted fault (points over the full, a second walk on
## points given back, points that grow outside ready_units, a battle open after an act, two countries on a hex after an act, a
## game that does not load, a player's walk at once in a season's records, a standing march without points that moves), the
## season of clean marches that breaks none, and the soak's `--plant=moves`.
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
	assert_eq(Invariants.NAMES.size(), 23)


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


func test_p_explored_only_grows_a_hex_lost() -> void:
	assert_true(_breaks("explored", func(g: Game, _b: Dictionary) -> void: _clear_far_hex(g, AiFixture.MILAN)))


func test_p_controlled_hex_must_be_explored_by_its_controller() -> void:
	assert_true(_breaks("controlled", func(g: Game, _b: Dictionary) -> void: _unexplore_controlled(g)))


func test_the_fog_plant_clears_once_and_is_named() -> void:
	var g := AiFixture.watch()
	var before := Invariants.before(g)
	Season.run(g)
	Invariants.planted = "fog"
	var lines := Invariants.check(g, before)
	assert_eq(Invariants.planted, "", "the plant fired and cleared itself")
	assert_true(_has(lines, "explored"), "named: %s" % str(lines))
	var again := Invariants.check(g, Invariants.before(g))
	assert_false(_has(again, "explored"), "no plant, nothing lost")


## Clears the first explored bit of `tag` that its sight does not reach: a hex it has discovered and lost.
func _clear_far_hex(g: Game, tag: StringName) -> void:
	var c := Countries.by_tag(g, tag)
	for i: int in g.map.hex_count():
		if SightCache.bit_is(c.explored, i) and not Sight.sees(g, tag, g.map.hex_of(i)):
			c.explored[i >> 3] = c.explored[i >> 3] & ~(1 << (i & 7))
			return


## Clears the explored bit of the owner of a land hex it holds itself (no occupier): the hex is controlled and unexplored.
func _unexplore_controlled(g: Game) -> void:
	for i: int in g.map.hex_count():
		if g.map.land[i] != 1 or int(g.state.owner[i]) == 0:
			continue
		if i < g.state.occupier.size() and g.state.occupier[i] != 0:
			continue
		var c := Countries.by_id(g, int(g.state.owner[i]))
		if c != null:
			c.explored[i >> 3] = c.explored[i >> 3] & ~(1 << (i & 7))
			return


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


# --- moves in the month (moves-build-spec.md 8.4): I1 to I8 -------------------------------------------------------------------


## The moves duel in peace with a march of Savoy's army that takes more than one season: {g, army, goal}.
func _marching() -> Dictionary:
	var g := MovesFixture.duel()
	g.wars.clear()
	g.version += 1
	var a := MovesFixture.named(g, MovesFixture.NAME_HOME)
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if Territory.owner_tag(g, hex) != MovesFixture.SAVOY or ImproveRules.hex_distance(hex, a.hex) < 4:
			continue
		var plan := Movement.plan(g, a, hex)
		if bool(plan.ok) and int(plan.cost) > Allowance.full(g, a) \
				and bool(g.check("march", _order(a, hex))["ok"]):
			return {"g": g, "army": a, "goal": hex}
	return {}


func _order(a: Army, goal: Vector2i) -> Dictionary:
	return {"army": a.id, "goal": goal, "tag": a.tag}


## A season phase by phase with the watch's look after each.
func _watched_season(g: Game, watch: Invariants.Moves) -> void:
	Season.begin(g)
	for phase: StringName in Season.PHASES:
		Season.run_phase(g, phase)
		watch.look(g, phase)
	Season.finish(g)


func test_clean_marches_over_two_seasons_break_no_move_invariant() -> void:
	var scene := _marching()
	assert_false(scene.is_empty(), "a long march was found")
	var g: Game = scene["g"]
	var a: Army = scene["army"]
	for season: int in 2:
		g.events.clear()
		var watch := Invariants.Moves.start(g)
		var from := a.hex
		if season == 0:
			assert_true(bool(g.act("march", _order(a, scene["goal"]))["ok"]))
			watch.look(g, Invariants.Moves.ACT)
			assert_ne(a.hex, from, "it walked at once")
		var before := Invariants.before(g)  # after the order: the player's walk is no record of the season
		_watched_season(g, watch)
		assert_eq(watch.lines, PackedStringArray(), "season %d" % season)
		var lines := Invariants.check(g, before, {"moves": watch, "reload": true})
		for name: String in ["points", "spent", "grown", "saved", "walks", "stood", "battles", "armies"]:
			assert_false(_has(lines, name), "season %d, %s: %s" % [season, name, str(lines)])


func test_p_points_over_the_full() -> void:
	assert_true(_breaks("points", func(g: Game, _b: Dictionary) -> void:
		var a := WarFixture.army_at(g, AiFixture.MILAN, _milan_hex(g), 1)
		a.points = Allowance.full(g, a) + 1))
	var g := MovesFixture.duel()
	var watch := Invariants.Moves.start(g)
	MovesFixture.named(g, MovesFixture.NAME_HOME).points = -1
	watch.look(g, Invariants.Moves.ACT)
	assert_true(_has(watch.lines, "points"), str(watch.lines))


func test_p_spent_a_second_walk_on_points_given_back() -> void:
	var scene := _marching()
	var g: Game = scene["g"]
	var a: Army = scene["army"]
	var watch := Invariants.Moves.start(g)
	g.act("march", _order(a, scene["goal"]))
	watch.look(g, Invariants.Moves.ACT)
	assert_false(_has(watch.lines, "spent"), "one walk spends what it had at most: %s" % str(watch.lines))
	var halfway := a.hex
	a.points = Allowance.full(g, a)  # the fault: the points back in the middle of the season
	g.act("halt", {"army": a.id, "tag": a.tag})
	assert_true(bool(g.act("continue_march", {"army": a.id, "tag": a.tag})["ok"]))
	assert_ne(a.hex, halfway, "it walked again")
	watch.look(g, Invariants.Moves.ACT)
	assert_true(_has(watch.lines, "spent"), str(watch.lines))


func test_p_grown_points_outside_ready_units() -> void:
	var g := MovesFixture.duel()
	var a := MovesFixture.named(g, MovesFixture.NAME_HOME)
	for where: StringName in [Invariants.Moves.ACT, &"movement", &"supply", &"ready_units"]:
		ArmyFixture.spent(g, a, 1)
		var watch := Invariants.Moves.start(g)
		Armies.set_points(g, a, Allowance.full(g, a))
		watch.look(g, where)
		assert_eq(_has(watch.lines, "grown"), where != &"ready_units", "%s: %s" % [where, str(watch.lines)])


func test_p_a_battle_open_after_an_act() -> void:
	var g := MovesFixture.duel()
	var watch := Invariants.Moves.start(g)
	g.battles.append(Battle.new())
	watch.look(g, &"movement")
	assert_false(_has(watch.lines, "battles"), "the movement phase may leave one for the battles phase")
	watch.look(g, Invariants.Moves.ACT)
	assert_true(_has(watch.lines, "battles"), str(watch.lines))


func test_p_two_countries_on_a_hex_after_an_act() -> void:
	var g := MovesFixture.duel()
	var watch := Invariants.Moves.start(g)
	watch.look(g, Invariants.Moves.ACT)
	assert_false(_has(watch.lines, "armies"), str(watch.lines))
	Armies.set_hex(g, MovesFixture.named(g, MovesFixture.NAME_NEAR), MovesFixture.named(g, MovesFixture.NAME_HOME).hex,
		Army.NO_HEX)
	watch.look(g, Invariants.Moves.ACT)
	assert_true(_has(watch.lines, "armies"), str(watch.lines))


func test_p_saved_a_game_that_does_not_load() -> void:
	var g := AiFixture.watch()
	var before := Invariants.before(g)
	Season.run(g)
	assert_eq(Invariants.reload_lines(g), PackedStringArray(), "the season's game loads with its digest")
	g.battle_names["nowhere"] = Battles.NAME_COUNT_MAX + 1
	assert_false(_has(Invariants.check(g, before), "saved"), "only a reload reads it")
	var lines := Invariants.check(g, before, {"reload": true})
	assert_true(_has(lines, "saved"), str(lines))


func test_p_walks_a_players_walk_at_once_in_the_seasons_records() -> void:
	var g := MovesFixture.duel()
	g.events.clear()
	var before := Invariants.before(g)
	Season.run(g)
	g.events.clear()
	var walk := {"kind": "unit_moved", "tag": MovesFixture.SAVOY, "army": 1, "why": "march", "now": true}
	var foreign := walk.duplicate()
	foreign["tag"] = MovesFixture.MILAN
	var retreat := walk.duplicate()
	retreat["why"] = &"retreat"
	var later := walk.duplicate()
	later["now"] = false
	g.events.append_array([foreign, retreat, later])
	assert_false(_has(Invariants.check(g, before), "walks"), "a computer's walk, a retreat and a phase walk are records")
	g.events.append(walk)
	assert_true(_has(Invariants.check(g, before), "walks"))


func test_p_stood_a_standing_march_without_points_that_moves() -> void:
	var scene := _marching()
	var g: Game = scene["g"]
	var a: Army = scene["army"]
	assert_true(MovesFixture.standing(g, a, scene["goal"]))
	ArmyFixture.spent(g, a, 0)
	var watch := Invariants.Moves.start(g)
	watch.look(g, &"ai_orders")
	MovementPhase.season(g)
	watch.look(g, &"movement")
	assert_false(_has(watch.lines, "stood"), "the phase leaves it: %s" % str(watch.lines))
	Armies.set_hex(g, a, g.map.hex_of(a.route[0]), a.hex)  # the fault: a phase that walks it
	watch.look(g, &"movement")
	assert_true(_has(watch.lines, "stood"), str(watch.lines))


func test_the_soaks_moves_plant_is_caught_by_grown_and_spent() -> void:
	var clean := SoakGame.play("ai", 1, 6, SoakGame.SoakLogger.new())
	assert_eq(clean["failure"], [], "the same game without the plant breaks nothing")
	Invariants.planted = "moves"
	var rec := SoakGame.play("ai", 1, 6, SoakGame.SoakLogger.new(), "moves")
	assert_eq(Invariants.planted, "", "the plant found its army and cleared itself")
	Invariants.planted = ""
	var lines := PackedStringArray(rec["failure"])
	assert_true(_has(lines, "grown"), str(lines))
	assert_true(_has(lines, "spent"), str(lines))
