## The deep-fog step (docs/architecture/moves-build-spec.md R7, R36 to R39, D9; MV7): a step onto a hex the walker's country has
## never explored (its EXPLORED bit, never the sight) is taken only by a fresh army and spends GameDefs.fog_step_cost (-1: all
## its points), at once (WalkNow) and in the movement phase; the vision phase explores the army's sight ring, so sight 1 advances
## about one hex a season and sight 2 about two; Movement.walk_plan estimates the fog steps; an undiscovered goal is accepted;
## nothing changes on north Italy, where every country has explored every hex at the start. The deep-fog cases run on
## MovesFixture.thin() (Savoy explored to two hexes past its land sight) with the duel's Milanese armies taken off. Every case
## names its planted fault (P).
extends GutTest

const SAV := MovesFixture.SAVOY
const MLO := MovesFixture.MILAN
const KNIGHTS := 2
## Milan's land east of Vercelli: (8, 7) and (9, 7) are explored, (10, 6) and (11, 6) are not; the plan from (8, 7) to (11, 6)
## runs (9, 7), (10, 6), (11, 6) on cheap ground (2 points a step), with no fortress beside it.
const INNER := Vector2i(8, 7)
const FRONT := Vector2i(9, 7)
const FOG_1 := Vector2i(10, 6)
const DEEP := Vector2i(11, 6)
## Row 4 runs east into Milan's hills: (8, 4) is explored, (9, 4) to (13, 4) are not (the pace case).
const ROW4_FRONT := Vector2i(8, 4)
## Far east, past Milan into Austria's land (at war with Savoy for the pace case only), for a march of more than four seasons.
const FAR_EAST := Vector2i(16, 4)
const AUSTRIA := &"AUS"
## Seasons of a pace run: summer and autumn 1480, spring and summer 1481 (no winter).
const PACE_TURNS: Array[int] = [2, 3, 5, 6]

var _g: Game


func before_each() -> void:
	_g = _thin()


func _thin(defs: GameDefs = null) -> Game:
	var g := MovesFixture.duel(defs)
	FogFixture.thin(g, SAV, 2)
	for a: Army in g.armies.duplicate():
		if a.tag == MLO:
			Armies.remove(g, a)
	Sight.refresh(g)
	g.turn = PACE_TURNS[0]
	return g


func _scene_holds(g: Game) -> void:
	assert_true(Sight.explored(g, SAV, INNER) and Sight.explored(g, SAV, FRONT), "the inner hexes are explored")
	for h: Vector2i in [FOG_1, DEEP]:
		assert_false(Sight.explored(g, SAV, h), "%s is unexplored" % str(h))


func _cost(a: Vector2i, b: Vector2i) -> int:
	var m := _g.map
	return StepCosts.of(m, _g.defs).cost(m.index_of(a), Movement.direction(m, m.index_of(a), m.index_of(b)), false)


func _march(a: Army, goal: Vector2i) -> Dictionary:
	return _g.act("march", {"army": a.id, "goal": goal, "tag": a.tag})


# --- R36: a fog step only fresh, spending all its points --------------------------------------------------------------------------


func test_a_fresh_army_takes_one_fog_step_and_spends_all_its_points_at_once() -> void:
	_scene_holds(_g)
	var a := ArmyFixture.army(_g, SAV, FRONT, 0, 1, 0)
	assert_true(_cost(FRONT, FOG_1) < 12, "the ground alone is cheap")
	var res := _march(a, DEEP)
	assert_true(bool(res.ok), "P: an undiscovered goal refused: %s" % str(res.reason))
	assert_eq(a.hex, FOG_1, "one step into the unmapped land")
	assert_eq(StringName(res.walk.stopped), WalkNow.FOG)
	assert_eq(a.points, 0, "P: a fog step at its normal cost")
	assert_true(bool(res.walk.standing), "the rest of the march stands")
	assert_eq(a.order, Army.ORDER_MARCH)
	assert_eq(a.halt_why, &"", "a fog step is no halt")
	assert_true(Sight.explored(_g, SAV, FOG_1), "the step explores its hex (R19)")


func test_an_army_that_has_walked_stops_before_a_fog_step_at_once() -> void:
	var a := ArmyFixture.army(_g, SAV, INNER, 0, 1, 0)
	var route := Movement.plan(_g, a, DEEP).hexes as PackedInt32Array
	assert_eq([_g.map.hex_of(route[0]), _g.map.hex_of(route[1])], [FRONT, FOG_1], "the route east")
	var res := _march(a, DEEP)
	assert_eq(a.hex, FRONT, "P: a fog step taken second in a season")
	assert_eq(StringName(res.walk.stopped), WalkNow.FOG)
	assert_eq(a.points, 12 - _cost(INNER, FRONT), "the points left are kept")
	assert_true(bool(res.walk.standing))
	var spent := ArmyFixture.army(_g, SAV, FRONT, 0, 1, 0)
	ArmyFixture.spent(_g, spent, 11)
	var res2 := _march(spent, DEEP)
	assert_true(bool(res2.ok))
	assert_eq(spent.hex, FRONT, "an army that is not fresh takes no fog step at all")
	assert_eq(StringName(res2.walk.stopped), WalkNow.FOG)
	assert_eq(spent.points, 11)


func test_the_phase_takes_a_fog_step_only_fresh() -> void:
	var fresh := ArmyFixture.army(_g, SAV, FRONT, 0, 1, 0)
	var walked := ArmyFixture.army(_g, SAV, INNER, 0, 1, 0)
	assert_true(MovesFixture.standing(_g, fresh, DEEP))
	assert_true(MovesFixture.standing(_g, walked, DEEP))
	ArmyFixture.spent(_g, walked, 11)
	MovementPhase.season(_g)
	assert_eq(fresh.hex, FOG_1, "the fresh army takes the fog step")
	assert_eq(fresh.points, 0, "P: a fog step at its normal cost in the phase")
	assert_eq(walked.hex, FRONT, "the other walks to the edge of the map it knows")
	assert_eq(walked.points, 11 - _cost(INNER, FRONT), "P: a fog step taken second in a season in the phase")
	assert_eq(fresh.order, Army.ORDER_MARCH)
	assert_eq(walked.order, Army.ORDER_MARCH)


func test_fog_step_cost_is_a_data_value() -> void:
	var d := ArmyFixture.defs()
	d.fog_step_cost = 5
	_g = _thin(d)
	var a := ArmyFixture.army(_g, SAV, FRONT, 0, 1, 0)
	var res := _march(a, DEEP)
	assert_eq(a.hex, FOG_1, "the fog step spends 5")
	assert_eq(a.points, 7)
	assert_eq(StringName(res.walk.stopped), WalkNow.FOG, "and the next fog step waits: the army is no longer fresh")


# --- R37: the pace through unmapped land ------------------------------------------------------------------------------------------


## The hexes walked in each of four seasons by an army of `kind` from ROW4_FRONT toward FAR_EAST, the phases run as the season runs
## them (the movement phase, then the vision phase's Sight.season, then the refill of the next season).
func _pace(kind: int) -> Array[int]:
	var g := _thin()
	WarFixture.at_war(g, SAV, AUSTRIA)
	var a := ArmyFixture.army(g, SAV, ROW4_FRONT, kind, 1, 0)
	assert_true(MovesFixture.standing(g, a, FAR_EAST), "a march of more than four seasons")
	var out: Array[int] = []
	for t: int in PACE_TURNS:
		g.turn = t
		Allowance.refill(g)
		var before := a.route.size()
		MovementPhase.season(g)
		Sight.season(g)
		out.append(before - a.route.size())
	return out


func test_sight_one_advances_one_hex_a_season_and_sight_two_about_two() -> void:
	var pikemen := _pace(0)
	var knights := _pace(KNIGHTS)
	gut.p("deep-fog pace over 4 seasons on MovesFixture.thin(): sight 1 %s, sight 2 %s" % [str(pikemen), str(knights)])
	assert_eq(pikemen, [1, 1, 1, 1] as Array[int], "sight 1: one hex a season")
	assert_eq(knights[0], 1, "the first season: one fog step")
	assert_true(knights[1] >= 2, "P: a sight-2 army that advances one hex a season through unmapped land")
	assert_true(knights[2] >= 2)
	var total := 0
	for n: int in knights:
		total += n
	assert_gt(total, 5, "about two hexes a season")


# --- R38: the plan's estimate, the undiscovered goal ---------------------------------------------------------------------------


func test_walk_plan_counts_the_fog_steps() -> void:
	var a := ArmyFixture.army(_g, SAV, FRONT, 0, 1, 0)
	var route := Movement.plan(_g, a, DEEP).hexes as PackedInt32Array
	var foggy := Movement.walk_plan(_g, a, route, _g.turn)
	assert_eq(int(foggy.stops[0].index), 1, "this season: the one fog step the walk takes")
	var mapped := MovesFixture.duel()
	var b := ArmyFixture.army(mapped, SAV, FRONT, 0, 1, 0)
	mapped.turn = _g.turn
	var clear := Movement.walk_plan(mapped, b, route, mapped.turn)
	assert_gt(int(foggy.arrives_turn), int(clear.arrives_turn), "P: a plan that counts a fog step at its normal cost")
	assert_eq(int(foggy.seasons), route.size(), "one hex a season, each step a fog step (the cautious estimate)")
	var steps := StepCosts.of(_g.map, _g.defs)
	var r := Movement.walk_season(_g.map, steps, _g.map.index_of(FRONT), route, 0, 12, false, true,
		FogStep.mapped(_g, SAV), -1)
	assert_eq([int(r.idx), int(r.pts)], [1, 0], "walk_season: one fog step, all the points")
	var r2 := Movement.walk_season(_g.map, steps, _g.map.index_of(FRONT), route, 0, 11, false, false,
		FogStep.mapped(_g, SAV), -1)
	assert_eq(int(r2.idx), 0, "not fresh: no fog step")


func test_an_undiscovered_goal_is_accepted_and_a_refusal_names_nothing_undiscovered() -> void:
	var a := ArmyFixture.army(_g, SAV, FRONT, 0, 1, 0)
	var ok := _g.check("march", {"army": a.id, "goal": Vector2i(13, 4), "tag": SAV})
	assert_true(bool(ok.ok), "P: an undiscovered goal refused: %s" % str(ok.reason))
	var venice := Vector2i(13, 5)
	assert_eq(Territory.owner_tag(_g, venice), &"VEN")
	assert_false(Sight.explored(_g, SAV, venice) or Sight.sees(_g, SAV, venice), "an undiscovered hex of a country at peace")
	var no := _g.check("march", {"army": a.id, "goal": venice, "tag": SAV})
	assert_false(bool(no.ok))
	assert_eq(str(no.reason).find(Movement.country_name(_g, &"VEN")), -1, "the owner of an undiscovered hex is not named")


# --- R39: north Italy --------------------------------------------------------------------------------------------------------------


func test_nothing_changes_on_north_italy_every_country_mapped_the_whole_map() -> void:
	var g := ArmyFixture.game()
	for c: Country in g.countries:
		var bits := FogStep.mapped(g, c.tag)
		assert_false(bits.is_empty(), "%s has an explored set" % String(c.tag))
		for i: int in g.map.hex_count():
			if g.map.land[i] == 1 and FogStep.is_fog(bits, i):
				fail_test("P: a fog step on north Italy: %s at %s" % [String(c.tag), str(g.map.hex_of(i))])
				return
	var d := MovesFixture.duel()
	for m: Army in d.armies.duplicate():
		if m.tag == MLO:
			Armies.remove(d, m)
	var a := ArmyFixture.army(d, SAV, FRONT, 0, 1, 0)
	var res := d.act("march", {"army": a.id, "goal": DEEP, "tag": SAV})
	assert_true(bool(res.ok), str(res.reason))
	assert_ne(StringName(res.walk.stopped), WalkNow.FOG, "the same march on the mapped map takes no fog step")
	assert_gt(int(res.walk.steps), 1)


func test_a_game_with_no_explored_set_has_no_fog_step() -> void:
	var c := Countries.by_tag(_g, SAV)
	c.explored = PackedByteArray()
	assert_true(FogStep.mapped(_g, SAV).is_empty())
	assert_false(FogStep.is_fog(FogStep.mapped(_g, SAV), _g.map.index_of(DEEP)))
	assert_eq(FogStep.after(-1, 9), 0)
	assert_eq(FogStep.after(4, 9), 5)
	assert_eq(FogStep.after(12, 9), 0)
