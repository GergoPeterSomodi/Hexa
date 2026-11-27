## The property of the preview (moves-build-spec.md done-when 3, R45; plan MV14): for every accepted march on which no army the
## ordering country cannot see stands on or beside the leg (within the walking army's sight, at least one hex, of its start and
## of every hex of the leg), MovePreview's leg is the walk that follows: the same hexes, the same end, the same points left and
## the same reason. ORDERS seeded orders of Savoy on games made from the moves duel (north Italy): armies of every kind and size
## on both sides and on neutral land, some spent or shaken, a war on Milan sometimes declared this season, every season of the
## year, sometimes a thin explored set.
## The one difference allowed (R73, FairWarning): where the walk stops before land of a country declared war on this season
## whose next hex the country has not discovered, the preview does not cut the leg there; then the walk is the start of the leg.
## The test counts the orders that meet it.
## P: a leg that walks the route by its points alone (Movement.walk_season: no zone of control), put in the preview's place
## through the test's seam (`_leg_of`), differs from the walk.
extends GutTest

const S := MovesFixture.SAVOY
const M := MovesFixture.MILAN
const SEED := 1480
const ORDERS := 200
## Orders given in one game before the next is made, and the most games.
const PER_GAME := 8
const GAMES_MAX := 400
const SAVOY_ARMIES := 3
const FOE_ARMIES := 4
const NEUTRAL_ARMIES := 2
## Milanese armies set this close to an army of Savoy (in sight or just out of it).
const NEAR_FOES := 2
const NEAR_REACH := 3
## The farthest goal of an order, in hexes.
const GOAL_REACH := 10
## The morale of a shaken army (under WarDef.attack_morale).
const SHAKEN_MORALE := 300
## The preview's word of each stop of a walk.
const WHY_OF := {&"": MovePreview.WHY_ARRIVES, &"points": MovePreview.WHY_POINTS, &"battle": MovePreview.WHY_BATTLE,
	&"zoc": MovePreview.WHY_ZOC, &"winter": MovePreview.WHY_WINTER, &"fog": MovePreview.WHY_FOG,
	&"no_points": MovePreview.WHY_NO_POINTS, &"mustering": MovePreview.WHY_MUSTERING, &"blocked": MovePreview.WHY_BLOCKED,
	&"no_way": MovePreview.WHY_NO_WAY, &"warned": MovePreview.WHY_WARNED}


func _pick(rng: RandomNumberGenerator, list: Array) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)] if not list.is_empty() else null


## The land hexes of `owner` (an id; 0 for none) with no army on them.
func _free_land(g: Game, owner: int) -> Array:
	var out: Array = []
	for i: int in g.map.hex_count():
		if g.map.land[i] == 1 and int(g.state.owner[i]) == owner and Armies.at(g, g.map.hex_of(i)).is_empty():
			out.append(g.map.hex_of(i))
	return out


func _add_army(g: Game, rng: RandomNumberGenerator, tag: StringName, count: int) -> void:
	var hex: Variant = _pick(rng, _free_land(g, Countries.by_tag(g, tag).id))
	if hex != null:
		ArmyFixture.army(g, tag, hex, rng.randi_range(0, g.defs.units.size() - 1), count)


## One game of the property, made from `rng`.
func _scene(rng: RandomNumberGenerator) -> Game:
	var g := MovesFixture.duel()
	g.turn = rng.randi_range(2, 9)
	var war := Wars.war_between(g, S, M)
	war.start_turn = g.turn if rng.randi_range(0, 3) == 0 else g.turn - 1
	for _n: int in SAVOY_ARMIES:
		_add_army(g, rng, S, rng.randi_range(1, 7))
	for _n: int in FOE_ARMIES:
		_add_army(g, rng, M, rng.randi_range(1, 4))
	for _n: int in NEAR_FOES:
		var mine := _pick(rng, Armies.of_country(g, S)) as Army
		var close := _free_land(g, Countries.by_tag(g, M).id).filter(
			func(h: Vector2i) -> bool: return ImproveRules.hex_distance(h, mine.hex) <= NEAR_REACH)
		var spot: Variant = _pick(rng, close)
		if spot != null:
			ArmyFixture.army(g, M, spot, rng.randi_range(0, g.defs.units.size() - 1), rng.randi_range(1, 3))
	for _n: int in NEUTRAL_ARMIES:
		var other := g.countries[rng.randi_range(0, g.countries.size() - 1)].tag
		if other != S and other != M:
			_add_army(g, rng, other, 2)
	for a: Army in Armies.of_country(g, S):
		if rng.randi_range(0, 7) == 0:
			for u: Unit in a.units:
				Armies.set_morale(g, a, u.id, SHAKEN_MORALE)
	Sight.refresh(g)
	if rng.randi_range(0, 2) == 0:
		FogFixture.thin(g, S, rng.randi_range(0, 2))
	g.version += 1
	return g


## An accepted march of one of Savoy's armies: {army, goal}, or {} when none was found.
func _order(g: Game, rng: RandomNumberGenerator) -> Dictionary:
	var army: Variant = _pick(rng, Armies.of_country(g, S))
	if army == null:
		return {}
	var a := army as Army
	if rng.randi_range(0, 4) == 0:
		ArmyFixture.spent(g, a, rng.randi_range(0, Allowance.full(g, a)))
		g.version += 1
	var goals: Array = []
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 1 and ImproveRules.hex_distance(hex, a.hex) in range(1, GOAL_REACH + 1):
			goals.append(hex)
	var foes: Array = goals.filter(func(h: Vector2i) -> bool: return Sight.sees(g, S, h) and Movement.enemy_army_at(g, S, h))
	for attempt: int in 40:
		# one order in three aims at an enemy army in sight, when there is one
		var goal: Variant = _pick(rng, foes if attempt == 0 and rng.randi_range(0, 2) == 0 and not foes.is_empty() else goals)
		if goal != null and bool(g.check("march", {"army": a.id, "goal": goal, "tag": S})["ok"]):
			return {"army": a, "goal": goal}
	return {}


## True when an army Savoy does not see stands on or beside the leg: within the walking army's sight (at least 1) of its start
## or of a hex of the leg.
func _unseen_near(g: Game, a: Army, hexes: Array) -> bool:
	var radius := maxi(MarchLeg.army_sight(g, a), 1)
	var way: Array = [a.hex]
	way.append_array(hexes)
	for other: Army in g.armies:
		if other.tag == S or Sight.sees(g, S, other.hex):
			continue
		for h: Vector2i in way:
			if ImproveRules.hex_distance(h, other.hex) <= radius:
				return true
	return false


## The preview's leg of the order.
func _preview_leg(g: Game, a: Army, goal: Vector2i) -> Dictionary:
	return MovePreview.leg_of(g, S, a.id, goal)


## Gives the order and compares the leg `leg` with the walk: {why (the walk's), problem ("" when equal), warned (the documented
## difference of R73)}.
func _walk_against(g: Game, a: Army, goal: Vector2i, leg: Dictionary) -> Dictionary:
	var id := a.id
	var from := a.hex
	var spent := a.points
	var seen_before := {}
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if Sight.explored(g, S, hex) or Sight.sees(g, S, hex):
			seen_before[hex] = true
	g.events.clear()
	var res := g.act("march", {"army": id, "goal": goal, "tag": S})
	if not bool(res["ok"]):
		return {"why": &"", "problem": "the checked march was refused: %s" % res["reason"], "warned": false}
	var walk := res["walk"] as Dictionary
	var path: Array[Vector2i] = []
	for e: Dictionary in g.events:
		if e["kind"] == "unit_moved" and int(e["army"]) == id and str(e["why"]) == "march":
			path.assign((e["path"] as Array).slice(1))
	var stopped := walk["stopped"] as StringName
	var why: StringName = WHY_OF.get(stopped, stopped)
	var hexes: Array[Vector2i] = []
	hexes.assign(leg["hexes"] as Array)
	var after := Armies.by_id(g, id)
	if why == MovePreview.WHY_WARNED and StringName(leg["why"]) != MovePreview.WHY_WARNED and after != null \
			and not after.route.is_empty():
		var next := g.map.hex_of(after.route[0])
		if not seen_before.has(next) and FairWarning.enemy_on(g, S, next) != &"" and hexes.slice(0, path.size()) == path:
			return {"why": why, "problem": "", "warned": true}
	var wrong := PackedStringArray()
	if hexes != path:
		wrong.append("hexes %s, walked %s" % [hexes, path])
	var end: Vector2i = path.back() if not path.is_empty() else from
	if leg["end"] != end:
		wrong.append("end %s, walked to %s" % [leg["end"], end])
	if after != null and int(leg["points_after"]) != int(walk["points"]):
		wrong.append("points after %d, walk left %d" % [leg["points_after"], walk["points"]])
	if StringName(leg["why"]) != why:
		wrong.append("why %s, walk stopped %s (%s)" % [leg["why"], why, walk["text"]])
	var problem := ""
	if not wrong.is_empty():
		problem = "turn %d, army %d (%d points) at %s to %s: %s" % [g.turn, id, spent, from, goal, "; ".join(wrong)]
	return {"why": why, "problem": problem, "warned": false}


## Runs orders seeded with `seed_value` until `wanted` of them count (no unseen army near), comparing `leg_fn`'s leg with the walk: {counted,
## problems, whys (reason -> count), warned, skipped}.
func _property(leg_fn: Callable, wanted: int, seed_value: int = SEED) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := {"counted": 0, "problems": [] as Array[String], "whys": {}, "warned": 0, "skipped": 0}
	for n: int in GAMES_MAX:
		var g := _scene(rng)
		for _k: int in PER_GAME:
			var order := _order(g, rng)
			if order.is_empty():
				continue
			var a := order["army"] as Army
			var goal := order["goal"] as Vector2i
			var leg := leg_fn.call(g, a, goal) as Dictionary
			if _unseen_near(g, a, _preview_leg(g, a, goal)["hexes"] as Array):
				out["skipped"] = int(out["skipped"]) + 1
				continue
			var got := _walk_against(g, a, goal, leg)
			out["counted"] = int(out["counted"]) + 1
			out["warned"] = int(out["warned"]) + (1 if bool(got["warned"]) else 0)
			var why := String(got["why"])
			(out["whys"] as Dictionary)[why] = int((out["whys"] as Dictionary).get(why, 0)) + 1
			if str(got["problem"]) != "":
				(out["problems"] as Array[String]).append("game %d: %s" % [n, got["problem"]])
			if int(out["counted"]) >= wanted:
				return out
	return out


func test_the_leg_is_the_walk_over_two_hundred_seeded_orders() -> void:
	var got := _property(_preview_leg, ORDERS)
	var problems := got["problems"] as Array[String]
	gut.p("orders %d, skipped for an unseen army %d, fair warning differences %d, stops %s" % [got["counted"], got["skipped"],
		got["warned"], str(got["whys"])])
	assert_eq(got["counted"], ORDERS)
	assert_eq(problems.size(), 0, "%d of %d orders differ:\n%s" % [problems.size(), ORDERS, "\n".join(problems.slice(0, 12))])
	for why: StringName in [MovePreview.WHY_ARRIVES, MovePreview.WHY_POINTS, MovePreview.WHY_ZOC, MovePreview.WHY_BATTLE]:
		assert_gt(int((got["whys"] as Dictionary).get(String(why), 0)), 0, "an order ends %s" % why)


## The property's case of a shaken army with an enemy army in sight on its way: the walk is refused the contact and stops
## before it (R28), and so does the preview's leg.
func test_a_shaken_armys_leg_stops_before_the_enemy_in_its_way_as_the_walk_does() -> void:
	var g := MovesFixture.duel()
	Armies.remove(g, MovesFixture.named(g, MovesFixture.NAME_NEAR))
	var army := MovesFixture.named(g, MovesFixture.NAME_HOME)
	for u: Unit in army.units:
		Armies.set_morale(g, army, u.id, SHAKEN_MORALE)
	g.version += 1
	var goal := _goal_past_a_seen_hex(g, army)
	assert_ne(goal, Army.NO_HEX, "a march past a hex in sight")
	var way := g.map.hex_of((Movement.plan(g, army, goal)["hexes"] as PackedInt32Array)[0])
	ArmyFixture.army(g, M, way, 0, 1)
	Sight.refresh(g)
	g.version += 1
	assert_true(Sight.sees(g, S, way), "the enemy army is in sight")
	var got := _walk_against(g, army, goal, _preview_leg(g, army, goal))
	assert_eq(got["why"], Movement.WHY_SHAKEN, "the walk is refused the attack")
	assert_eq(got["problem"], "", "the preview's leg is that walk")


## The first goal, three hexes or more away, whose route's first hex is in sight, empty, open to Milan, and not the goal.
func _goal_past_a_seen_hex(g: Game, army: Army) -> Vector2i:
	for i: int in g.map.hex_count():
		var goal := g.map.hex_of(i)
		if ImproveRules.hex_distance(goal, army.hex) < 3:
			continue
		var plan := Movement.plan(g, army, goal)
		if not bool(plan["ok"]) or (plan["hexes"] as PackedInt32Array).size() < 3:
			continue
		var first := g.map.hex_of((plan["hexes"] as PackedInt32Array)[0])
		if Sight.sees(g, S, first) and Armies.at(g, first).is_empty() and Movement.open_to(g, M, first) 				and bool(g.check("march", {"army": army.id, "goal": goal, "tag": S})["ok"]):
			return goal
	return Army.NO_HEX


## The planted leg: the stored route walked by the season's points alone, with no zone of control (Movement.walk_season).
func _leg_without_zoc(g: Game, a: Army, goal: Vector2i) -> Dictionary:
	var leg := _preview_leg(g, a, goal).duplicate(true)
	if StringName(leg["why"]) != MovePreview.WHY_ZOC:
		return leg
	var route := Movement.plan(g, a, goal)["hexes"] as PackedInt32Array
	var got := Movement.walk_season(g.map, StepCosts.of(g.map, g.defs), g.map.index_of(a.hex), route, 0, a.points,
		Movement.winter_now(g), Allowance.fresh(g, a), FogStep.mapped(g, a.tag), g.defs.fog_step_cost)
	var hexes: Array[Vector2i] = []
	for k: int in int(got["idx"]):
		hexes.append(g.map.hex_of(route[k]))
	leg["hexes"] = hexes
	leg["end"] = g.map.hex_of(int(got["cur"]))
	leg["points_after"] = int(got["pts"])
	leg["why"] = MovePreview.WHY_ARRIVES if leg["end"] == goal else MovePreview.WHY_POINTS
	return leg


func test_p_a_leg_that_ignores_the_zone_of_control_differs_from_the_walk() -> void:
	var got := _property(_leg_without_zoc, ORDERS)
	var found := (got["problems"] as Array[String]).filter(func(line: String) -> bool: return line.contains("walk stopped zoc"))
	assert_gt(found.size(), 0, "a leg past a zone of control is caught: %s" % str(got["whys"]))
