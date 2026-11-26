## MarchLeg (MV1, moves-build-spec D2): the walk engine split out of MovementPhase. The phase's own cases are in
## test_movement_phase.gd and its neighbours, unedited; this file checks the engine's own surface: the same season walked by hand
## through MarchLeg (leg, step, room, apply) equals MovementPhase.season, and `points` limits a leg without changing its rules.
## North Italy, the 1480 game (ArmyFixture).
extends GutTest

const SAV := &"SAV"
const VERCELLI := Vector2i(6, 9)
const AOSTA := Vector2i(3, 8)
const SADDLE := Vector2i(3, 7)
const AUTUMN_1480 := 3
const WINTER_1480 := 4

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()
	Movement.clear_test_hostility()


func after_each() -> void:
	Movement.clear_test_hostility()


## Savoy's army on `hex`, marching to `goal` (the order stored through the door).
func _march(g: Game, hex: Vector2i, goal: Vector2i, count: int = 2) -> Army:
	var a := ArmyFixture.army(g, SAV, hex, 0, count, 0)
	assert_true(bool(Movement.march(g, {"army": a.id, "goal": goal, "tag": SAV}).ok), "the march is ordered")
	return a


## The movement phase's season, written out with MarchLeg's four calls, with `points` handed to every leg (-1: the full points).
func _by_hand(g: Game, points: int = -1) -> void:
	Armies.clear_moved(g)
	var steps := StepCosts.of(g.map, g.defs)
	var winter := Movement.winter_now(g)
	var occ := {}
	for army: Army in g.armies:
		occ[g.map.index_of(army.hex)] = Countries.by_tag(g, army.tag).id
	Movement.begin_index(g)
	var walks: Array = []
	var by_id: Dictionary = {}
	for army: Army in g.armies:
		if army.order != Army.ORDER_MARCH or army.mustering(g.turn):
			continue
		var w := MarchLeg.leg(g, steps, army, winter, points)
		walks.append(w)
		by_id[army.id] = w
	var longest := 0
	for w: MarchLeg in walks:
		longest = maxi(longest, w.walked.size())
	for k: int in longest:
		for w: MarchLeg in walks:
			if w.walked.size() > k:
				MarchLeg.step(g, w, k, occ)
	Movement.end_index()
	MarchLeg.room(g, walks, by_id)
	MarchLeg.apply(g, walks, {})
	Sight.refresh(g)


func _two_games(turn: int) -> Array[Game]:
	var out: Array[Game] = []
	for _n: int in 2:
		var g := ArmyFixture.game()
		g.turn = turn
		_march(g, VERCELLI, AOSTA)
		out.append(g)
	return out


func test_the_engine_by_hand_equals_the_phase_in_autumn() -> void:
	var gs := _two_games(AUTUMN_1480)
	MovementPhase.season(gs[0])
	_by_hand(gs[1])
	assert_eq(gs[1].digest(), gs[0].digest(), "the same state after the season")
	assert_eq(gs[1].events.size(), gs[0].events.size(), "and the same events")
	assert_eq(gs[1].armies[0].hex, SADDLE, "ten of its twelve points take it to the saddle")


func test_the_engine_by_hand_equals_the_phase_in_winter() -> void:
	var gs := _two_games(WINTER_1480)
	for g: Game in gs:
		g.armies[0].hex = SADDLE
	MovementPhase.season(gs[0])
	_by_hand(gs[1])
	assert_eq(gs[1].digest(), gs[0].digest(), "the closed pass holds the army the same way")
	assert_eq(gs[1].armies[0].waiting, Movement.WHY_WINTER)


func test_the_default_points_are_the_armys_full_points() -> void:
	_g.turn = AUTUMN_1480
	var a := _march(_g, VERCELLI, AOSTA)
	var steps := StepCosts.of(_g.map, _g.defs)
	var plain := MarchLeg.leg(_g, steps, a, false)
	var full := MarchLeg.leg(_g, steps, a, false, Movement.mp_of(_g, a))
	assert_eq(plain.walked, full.walked, "no points given is the full points")
	assert_eq(plain.end, full.end)
	assert_eq(plain.rem, full.rem)


func test_fewer_points_walk_less_and_none_walk_nothing() -> void:
	_g.turn = AUTUMN_1480
	var a := _march(_g, VERCELLI, AOSTA)
	var steps := StepCosts.of(_g.map, _g.defs)
	var full := MarchLeg.leg(_g, steps, a, false)
	var some := MarchLeg.leg(_g, steps, a, false, 4)
	var none := MarchLeg.leg(_g, steps, a, false, 0)
	assert_true(some.walked.size() > 0 and some.walked.size() < full.walked.size(), "four points take fewer steps than twelve")
	assert_true(none.walked.is_empty(), "no points, no steps")
	assert_eq(none.end, none.start)
	assert_eq(none.rem, a.route, "the route is kept whole")
	assert_eq(a.hex, VERCELLI, "a leg only plans: the army has not moved")
