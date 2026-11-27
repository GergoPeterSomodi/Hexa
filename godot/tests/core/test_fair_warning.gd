## Fair warning for every country (docs/architecture/moves-build-spec.md R73, D24; MV20): in the season a country declares a war none
## of its armies enters that enemy's land. The order checks (march, Continue, storm) refuse a goal there with the words and the hint;
## both walks (at once and the movement phase) stop before the first such hex (warned: no halt, the points kept, the march standing)
## and walk on next season; the country declared on is not bound; no computer army meets the check in an all-AI game of 20 seasons
## (its orders are never refused by it; the walk's stop is its backstop, D24).
## North Italy's duel (MovesFixture.declared_now: Savoy declares on Milan this season), the fixture's armies taken off so a
## scene holds only the armies placed here. Every case names its planted fault (P).
extends GutTest

const SAV := MovesFixture.SAVOY
const MLO := MovesFixture.MILAN
## Savoy's walk east: START, then (5, 7), LAST_OWN, then Milan's BORDER and DEEP, then Savoy's own BEYOND.
const START := Vector2i(4, 7)
const LAST_OWN := Vector2i(6, 7)
const BORDER := Vector2i(7, 8)
const DEEP := Vector2i(7, 9)
const BEYOND := Vector2i(6, 9)
## A Milanese fortress with men.
const FORT := Vector2i(9, 9)
const WORDS := "You declared war on the Duchy of Milan this season. Your armies may not enter its land until next season."
const HINT := "Hint: march to your own or unclaimed land, or wait for the next season."
const REFUSAL := WORDS + "\n" + HINT
const SEASONS := 20
## An all-AI seed whose first 20 seasons declare wars (checked by the test itself).
const AI_SEED := 1

var _g: Game


func before_each() -> void:
	_g = MovesFixture.declared_now()
	for a: Army in _g.armies.duplicate():
		Armies.remove(_g, a)
	Sight.refresh(_g)


func _army(tag: StringName, hex: Vector2i) -> Army:
	var a := ArmyFixture.army(_g, tag, hex, 0, 1, 0)
	Sight.refresh(_g)
	return a


func _owner(hex: Vector2i) -> StringName:
	return Territory.owner_tag(_g, hex)


func _march_args(a: Army, goal: Vector2i) -> Dictionary:
	return {"army": a.id, "goal": goal, "tag": a.tag}


func _cost(from: Vector2i, hexes: Array) -> int:
	var m := _g.map
	var steps := StepCosts.of(m, _g.defs)
	var total := 0
	var prev := from
	for h: Vector2i in hexes:
		total += steps.cost(m.index_of(prev), Movement.direction(m, m.index_of(prev), m.index_of(h)), false)
		prev = h
	return total


func _events(kind: String) -> Array:
	var out: Array = []
	for e: Dictionary in _g.events:
		if str(e.get("kind", "")) == kind:
			out.append(e)
	return out


## The scene's facts: the war is Savoy's, of this season; the border and the deep hex are Milan's, the others Savoy's; the route
## from START to BEYOND crosses them and is short enough for one season.
func _assert_scene(a: Army) -> void:
	var war := Wars.war_between(_g, SAV, MLO)
	assert_eq(war.a, SAV, "Savoy declared")
	assert_eq(war.start_turn, _g.turn, "this season")
	assert_eq([_owner(START), _owner(LAST_OWN), _owner(BORDER), _owner(DEEP), _owner(BEYOND)], [SAV, SAV, MLO, MLO, SAV])
	var plan := Movement.plan(_g, a, BEYOND)
	assert_true(bool(plan.ok), "the route is planned through the enemy's land")
	var hexes: Array = []
	for i: int in plan.hexes:
		hexes.append(_g.map.hex_of(i))
	assert_eq(hexes, [Vector2i(5, 7), LAST_OWN, BORDER, DEEP, BEYOND])
	assert_true(_cost(START, hexes) <= a.points, "one season's walk but for the rule")


# --- the orders -----------------------------------------------------------------------------------------------------------


## P: a march into the declared enemy's land that is accepted or walks in; a refusal without the hint.
func test_a_march_into_the_enemys_land_is_refused_with_the_words_and_the_hint() -> void:
	var a := _army(SAV, START)
	_assert_scene(a)
	for goal: Vector2i in [BORDER, DEEP]:
		var before := _g.digest()
		var check := _g.check("march", _march_args(a, goal))
		assert_false(bool(check.ok), "the check refuses %s" % goal)
		assert_eq(str(check.reason), REFUSAL, "P: the words and the hint")
		var done := _g.act("march", _march_args(a, goal))
		assert_false(bool(done.ok), "P: the act refuses too")
		assert_eq(str(done.reason), REFUSAL)
		assert_eq(_g.digest(), before, "nothing changed")
		assert_eq(a.hex, START)


## P: the same march refused in the next season.
func test_the_same_march_is_taken_the_next_season() -> void:
	var a := _army(SAV, START)
	assert_false(bool(_g.check("march", _march_args(a, DEEP)).ok))
	_g.turn += 1
	_g.version += 1
	assert_true(bool(_g.check("march", _march_args(a, DEEP)).ok), "P: the land is open from the next season on")
	var r := _g.act("march", _march_args(a, DEEP))
	assert_true(bool(r.ok), str(r.get("reason", "")))
	assert_eq(a.hex, DEEP, "it walks in")
	assert_eq(r.walk.stopped, &"")


## P: the country the war was declared on is stopped; the declarer's rule read for the wrong side.
func test_the_country_declared_on_is_not_bound() -> void:
	_g.wars.clear()
	WarFixture.declared_now(_g, MLO, SAV)
	var mine := _army(SAV, START)
	var theirs := _army(MLO, Vector2i(11, 9))
	assert_eq(FairWarning.enemy_on(_g, SAV, BORDER), &"", "open to the country declared on")
	assert_eq(FairWarning.enemy_on(_g, MLO, LAST_OWN), SAV, "closed to the declarer")
	var refused := _g.check("march", _march_args(theirs, LAST_OWN))
	assert_eq(str(refused.reason), "You declared war on the Duchy of Savoy this season. Your armies may not enter its land until next season.\n" + HINT)
	var r := _g.act("march", _march_args(mine, DEEP))
	assert_true(bool(r.ok), "P: %s" % str(r.get("reason", "")))
	assert_eq(mine.hex, DEEP, "P: the defender walks into the declarer's land")


## P: a rule that also closes the land of an older war, or of a country at peace with the walker.
func test_an_older_war_and_a_third_country_are_not_closed() -> void:
	var war := Wars.war_between(_g, SAV, MLO)
	_g.turn += 3
	war.start_turn = _g.turn - 1
	assert_eq(FairWarning.enemy_on(_g, SAV, BORDER), &"", "declared last season")
	war.start_turn = _g.turn
	assert_eq(FairWarning.enemy_on(_g, SAV, BORDER), MLO)
	war.end_turn = _g.turn
	war.terms = &"white"
	assert_eq(FairWarning.enemy_on(_g, SAV, BORDER), &"", "an ended war closes nothing")
	assert_eq(FairWarning.enemy_on(_g, SAV, Vector2i(-1, -1)), &"")


## P: Continue that takes a halted march into the land.
func test_continue_is_refused_into_the_land_and_taken_toward_a_goal_beyond() -> void:
	var a := _army(SAV, START)
	Armies.set_order(_g, a, Army.ORDER_NONE, DEEP, PackedInt32Array())
	_g.version += 1
	var check := _g.check("continue_march", {"army": a.id, "tag": SAV})
	assert_eq(str(check.reason), REFUSAL)
	var before := _g.digest()
	assert_false(bool(_g.act("continue_march", {"army": a.id, "tag": SAV}).ok), "P")
	assert_eq(_g.digest(), before)
	Armies.set_order(_g, a, Army.ORDER_NONE, BEYOND, PackedInt32Array())
	_g.version += 1
	var r := _g.act("continue_march", {"army": a.id, "tag": SAV})
	assert_true(bool(r.ok), "a route across the land is accepted: %s" % str(r.get("reason", "")))
	assert_eq(a.hex, LAST_OWN)
	assert_eq(r.walk.stopped, &"warned")


## P: a storm of a fortress in the declared enemy's land accepted in the season of the declaration.
func test_a_storm_is_refused_until_the_next_season() -> void:
	var beside := Army.NO_HEX
	for d: int in 6:
		var n := _g.map.neighbour(FORT, d)
		if _g.map.index_of(n) >= 0 and _g.map.is_land(n) and Occupation.fortress_level(_g, n) == 0:
			beside = n
			break
	var a := _army(SAV, beside)
	assert_eq(_owner(FORT), MLO)
	assert_gt(Occupation.garrison_of(_g, FORT), 0)
	var args := _march_args(a, FORT)
	assert_eq(str(_g.check("storm", args).reason), REFUSAL)
	var before := _g.digest()
	assert_false(bool(_g.act("storm", args).ok), "P")
	assert_eq(_g.digest(), before)
	Armies.set_halt(_g, a, Movement.WHY_STORM, Movement.STORM_HALT_TEXT)
	Armies.set_order(_g, a, Army.ORDER_NONE, FORT, PackedInt32Array())
	_g.version += 1
	assert_eq(str(_g.check("continue_march", {"army": a.id, "tag": SAV}).reason), REFUSAL, "a halted storm too")
	_g.turn += 1
	_g.version += 1
	assert_true(bool(_g.check("storm", args).ok), str(_g.check("storm", args).reason))


## R73 (fog): an order reads the owner of a hex only where the country has discovered it; the walk still stops. P: a refusal that
## tells whose land an undiscovered hex is.
func test_an_undiscovered_goal_is_not_refused_and_the_walk_stops_at_the_border() -> void:
	var a := _army(SAV, START)
	var goal := _unseen_enemy_goal(a)
	assert_ne(goal, Army.NO_HEX, "a Milanese hex out of Savoy's sight with a way there")
	assert_eq(str(_g.check("march", _march_args(a, goal)).reason), REFUSAL, "explored: refused")
	var c := Countries.by_tag(_g, SAV)
	var bits := c.explored.duplicate()
	var i := _g.map.index_of(goal)
	bits[i >> 3] = bits[i >> 3] & ~(1 << (i & 7))
	c.explored = bits
	_g.version += 1
	assert_false(Sight.explored(_g, SAV, goal), "no longer explored")
	assert_eq(FairWarning.refusal(_g, SAV, goal), "")
	var r := _g.act("march", _march_args(a, goal))
	assert_true(bool(r.ok), "P: %s" % str(r.get("reason", "")))
	assert_eq(r.walk.stopped, &"warned", "the walk stops at the border")
	assert_eq(_owner(_g.map.hex_of(a.route[0])), MLO, "its next step is Milan's land")
	assert_ne(_owner(a.hex), MLO)


## The first Milanese land hex out of Savoy's sight, with no fortress, that `a` can be ordered to but for the rule.
func _unseen_enemy_goal(a: Army) -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if not _g.map.is_land(hex) or _owner(hex) != MLO or Sight.sees(_g, SAV, hex) or Occupation.fortress_level(_g, hex) > 0:
			continue
		if bool(Movement.goal_verdict(_g, a, SAV, hex).ok):
			return hex
	return Army.NO_HEX


# --- the walks ------------------------------------------------------------------------------------------------------------


## P: a walk that enters; points spent at the border; a halt set; a march that does not go on next season.
func test_a_march_across_the_land_stops_at_the_border_and_walks_on_next_season() -> void:
	var a := _army(SAV, START)
	_assert_scene(a)
	var full := a.points
	var left := full - _cost(START, [Vector2i(5, 7), LAST_OWN])
	_g.events.clear()
	var r := _g.act("march", _march_args(a, BEYOND))
	assert_true(bool(r.ok), str(r.get("reason", "")))
	assert_eq(a.hex, LAST_OWN, "P: it stops before the first hex of the enemy's land")
	assert_eq(r.walk.stopped, &"warned")
	assert_eq(r.walk.to, LAST_OWN)
	assert_eq(int(r.walk.steps), 2)
	assert_eq(str(r.walk.text), "you declared war on the Duchy of Milan this season")
	assert_true(bool(r.walk.standing))
	assert_eq([a.points, int(r.walk.points)], [left, left], "P: the points are kept")
	assert_eq([a.order, a.goal, a.halt_why], [Army.ORDER_MARCH, BEYOND, &""], "P: the march stands, no halt")
	assert_eq(_g.map.hex_of(a.route[0]), BORDER)
	assert_true(_events("march_halted").is_empty(), "P: no halt event")
	_g.orders = null
	assert_true(bool(Season.run(_g).ok))
	assert_eq(a.hex, LAST_OWN, "P: the movement phase of the same End season does not take it in")
	assert_eq([a.order, a.halt_why, a.waiting], [Army.ORDER_MARCH, &"", &""])
	assert_true(_events("march_halted").is_empty())
	assert_true(bool(Season.run(_g).ok))
	assert_eq(a.hex, BEYOND, "P: it walks on through the land the next season")


## P: the movement phase takes a standing march in.
func test_the_movement_phase_stops_a_standing_march_at_the_border() -> void:
	var a := _army(SAV, START)
	assert_true(MovesFixture.standing(_g, a, BEYOND))
	var full := a.points
	_g.events.clear()
	MovementPhase.season(_g)
	assert_eq(a.hex, LAST_OWN, "P")
	assert_eq(a.points, full - _cost(START, [Vector2i(5, 7), LAST_OWN]), "P: the points left are kept")
	assert_eq([a.order, a.goal, a.halt_why], [Army.ORDER_MARCH, BEYOND, &""])
	assert_eq(_events("unit_moved").size(), 1)
	assert_true(_events("march_halted").is_empty())


## A walk whose first step is the border takes no step: nothing changes but a stale winter wait. P: a halt or points spent.
func test_a_walk_that_starts_at_the_border_takes_no_step() -> void:
	var a := _army(SAV, LAST_OWN)
	assert_true(MovesFixture.standing(_g, a, BEYOND))
	assert_eq(_g.map.hex_of(a.route[0]), BORDER)
	Armies.set_waiting(_g, a, Movement.WHY_WINTER)
	var full := a.points
	_g.events.clear()
	MovementPhase.season(_g)
	assert_eq([a.hex, a.points, a.order, a.halt_why, a.waiting], [LAST_OWN, full, Army.ORDER_MARCH, &"", &""])
	assert_true(_events("unit_moved").is_empty())
	var walk := WalkNow.walk(_g, a)
	assert_eq([walk.stopped, int(walk.steps), int(walk.points)], [&"warned", 0, full])


## The rule comes before the contact: an enemy army on its own land is not attacked in the season of the declaration; on the
## declarer's land it is. P: a battle in the enemy's land; an attack on own land refused.
func test_armies_fight_on_their_own_land_but_not_in_the_enemys() -> void:
	var a := _army(SAV, LAST_OWN)
	var guard := _army(MLO, BORDER)
	assert_eq(str(_g.check("march", _march_args(a, BORDER)).reason), REFUSAL)
	Armies.set_order(_g, a, Army.ORDER_MARCH, BEYOND, PackedInt32Array([_g.map.index_of(BORDER), _g.map.index_of(DEEP),
		_g.map.index_of(BEYOND)]))
	var walk := WalkNow.walk(_g, a)
	assert_eq([walk.stopped, int(walk.battle), a.hex, guard.hex], [&"warned", -1, LAST_OWN, BORDER], "P: no battle there")
	Armies.remove(_g, guard)
	var raider := _army(MLO, Vector2i(5, 7))
	var r := _g.act("march", _march_args(a, raider.hex))
	assert_true(bool(r.ok), str(r.get("reason", "")))
	assert_gt(int(r.walk.battle), -1, "P: an enemy army on Savoy's land is fought")


# --- the computer ---------------------------------------------------------------------------------------------------------


## R73, D24: the computer keeps its candidate filter and never meets the check: over 20 seasons of an all-AI game no order of a seat
## is refused by it and no army walks into the land of a country its own declared on that season. A route toward an allowed goal may
## still cross that land: the walk then stops at the border (the backstop), which is counted and printed, not forbidden.
## P: a computer army that enters in the season it declares.
func test_no_computer_army_meets_the_check_in_twenty_seasons() -> void:
	var defs := EconomyFixture.defs(false, false)
	var g := Game.new_scenario(EconomyFixture.map(), defs, defs.scenarios[defs.scenarios.size() - 1], AI_SEED)
	assert_true(g.watch())
	var tally := {"declared": 0, "acts": 0, "refused": 0, "walk_stops": 0, "phase_stops": 0, "entered": 0}
	var hook := AiPlayers.attach(g, [] as Array[StringName])
	hook.judge = func(_tag: StringName, action: String, _args: Dictionary, _verdict: Dictionary, result: Dictionary) -> void:
		tally.acts += 1
		if action == "declare_war":
			tally.declared += 1
		if StringName((result.get("walk", {}) as Dictionary).get("stopped", &"")) == FairWarning.WHY:
			tally.walk_stops += 1
	for _n: int in SEASONS:
		g.events.clear()
		Season.begin(g)
		for phase: StringName in Season.PHASES:
			if phase == &"movement":
				tally.refused += _refusals_by_the_check(g, hook)
			Season.run_phase(g, phase)
			if phase == &"movement":
				tally.phase_stops += _standing_at_a_border(g)
				tally.entered += _entries(g)
		Season.finish(g)
	gut.p("fair warning, AI seed %d, %d seasons: %s" % [AI_SEED, SEASONS, str(tally)])
	assert_gt(int(tally.declared), 0, "wars were declared, so the rule was live")
	assert_eq(int(tally.refused), 0, "P: no order of a seat refused by the check")
	assert_eq(int(tally.entered), 0, "P: no army entered in the season it declared")


## The seats' trace lines of this season's turn that hold the rule's refusal (no seat's trace is full, so none is lost).
func _refusals_by_the_check(g: Game, hook: AiTurn) -> int:
	var out := 0
	for c: Country in g.countries:
		assert_true(hook.trace_of(c.tag).size() < AiTrace.MAX_LINES, "the trace of %s holds every line" % c.tag)
		for line: String in hook.trace_of(c.tag):
			if line.contains(FairWarning.HINT_TEXT):
				out += 1
	return out


## After the movement phase: the marching armies with points left whose next step is closed to them (they were stopped by the rule).
func _standing_at_a_border(g: Game) -> int:
	var out := 0
	for a: Army in g.armies:
		if (a.order == Army.ORDER_MARCH or a.order == Army.ORDER_STORM) and a.points > 0 and not a.route.is_empty() \
				and FairWarning.enemy_on(g, a.tag, g.map.hex_of(a.route[0])) != &"":
			out += 1
	return out


## The steps of this season's moves (retreats aside) onto land closed to the walker.
func _entries(g: Game) -> int:
	var out := 0
	for e: Dictionary in g.events:
		if str(e.get("kind", "")) != "unit_moved" or str(e.get("why", "")) != "march":
			continue
		var path: Array = e["path"]
		for k: int in range(1, path.size()):
			if FairWarning.enemy_on(g, StringName(str(e["tag"])), path[k]) != &"":
				out += 1
	return out
