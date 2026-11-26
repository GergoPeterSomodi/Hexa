## The walk at once (docs/architecture/moves-build-spec.md R1, R2, R5, R17 to R25, D1, D4, D5; MV4): a march walks before its act
## returns, a second march walks with the points left, a route past the season's points leaves a standing march, an order that
## cannot walk now is stored (mustering, no points, a winter wait), the wade and the costly step only for a fresh army, the room
## cut, the blocked words in and out of sight, and the zone of control that ends the season. North Italy's 1480 game
## (ArmyFixture: Savoy's own land by Turin) and the duel (MovesFixture). Every case names its planted fault (P).
extends GutTest

const SAV := &"SAV"
const MLO := &"MLO"
const TURIN := Vector2i(5, 9)
const VERCELLI := Vector2i(6, 9)
const SUSA := Vector2i(4, 9)
const MONT_CENIS := Vector2i(3, 9)
const SADDLE := Vector2i(3, 7)
const AOSTA := Vector2i(3, 8)
const SUMMER_1480 := 2
const AUTUMN_1480 := 3
const WINTER_1480 := 4
const BOMBARDS := 3

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()
	_g.turn = SUMMER_1480
	Movement.clear_test_hostility()


func after_each() -> void:
	Movement.clear_test_hostility()


func _sav(hex: Vector2i, count: int = 2, raised: int = 0, kind: int = 0) -> Army:
	return ArmyFixture.army(_g, SAV, hex, kind, count, raised)


func _march(a: Army, goal: Vector2i) -> Dictionary:
	return _g.act("march", {"army": a.id, "goal": goal, "tag": a.tag})


## The cost of the step from `a` to its neighbour `b` in summer (StepCosts).
func _cost(a: Vector2i, b: Vector2i) -> int:
	var m := _g.map
	var steps := StepCosts.of(m, _g.defs)
	return steps.cost(m.index_of(a), Movement.direction(m, m.index_of(a), m.index_of(b)), false)


func _events(kind: String) -> Array:
	var out: Array = []
	for e: Dictionary in _g.events:
		if str(e.get("kind", "")) == kind:
			out.append(e)
	return out


# --- R1, R17, R19: the act walks ----------------------------------------------------------------------------------------


func test_a_march_walks_before_its_act_returns() -> void:
	var a := _sav(TURIN)
	var before := _g.digest()
	assert_true(bool(_g.check("march", {"army": a.id, "goal": SUSA, "tag": SAV}).ok))
	assert_eq(_g.digest(), before, "P: a check that moves the army")
	assert_eq(a.hex, TURIN)
	var res := _march(a, SUSA)
	assert_true(bool(res.ok), str(res.reason))
	assert_eq(a.hex, SUSA, "P: a march that only stores its order")
	assert_eq(a.order, Army.ORDER_HOLD, "it arrived and holds")
	var walk: Dictionary = res.walk
	assert_eq([int(walk.steps), walk.from, walk.to, StringName(walk.stopped)], [1, TURIN, SUSA, WalkNow.ARRIVED])
	assert_eq(int(walk.points), 12 - _cost(TURIN, SUSA), "the step's cost is spent")
	assert_eq(int(walk.full), 12)
	assert_false(bool(walk.standing))
	assert_eq(int(walk.battle), -1)
	assert_eq(int(res.army), a.id)


func test_the_walk_emits_unit_moved_now_then_army_changed_and_explores_its_steps() -> void:
	var a := _sav(TURIN)
	_g.events.clear()
	assert_true(bool(_march(a, SUSA).ok))
	var kinds: Array[String] = []
	for e: Dictionary in _g.events:
		kinds.append(str(e.get("kind", "")))
	var moved := kinds.find("unit_moved")
	assert_true(moved >= 0, "P: an at-once walk with no unit_moved")
	assert_true(kinds.find("army_changed") > moved, "army_changed comes after unit_moved")
	var e: Dictionary = _events("unit_moved")[0]
	assert_true(bool(e.now), "unit_moved says the walk is at once")
	assert_eq([(e.path as Array).size(), e.path[0], e.path[1]], [2, TURIN, SUSA], "the path: the start, then the step")
	assert_true(Sight.explored(_g, SAV, SUSA), "the step is explored")


# --- R2: many moves a season ----------------------------------------------------------------------------------------------


func test_a_second_march_walks_with_the_points_left() -> void:
	var a := _sav(TURIN)
	var c1 := _cost(TURIN, SUSA)
	var c2 := _cost(SUSA, MONT_CENIS)
	assert_true(c1 + c2 <= 12, "the two steps fit one season")
	assert_true(bool(_march(a, SUSA).ok))
	assert_eq(a.points, 12 - c1)
	var res := _march(a, MONT_CENIS)
	assert_true(bool(res.ok), str(res.reason))
	assert_eq(a.hex, MONT_CENIS, "the second march walks")
	assert_eq(a.points, 12 - c1 - c2, "P: a second march that walks with the full points")
	var back := _cost(MONT_CENIS, SUSA)
	if back <= a.points:
		pending("the way back is cheap enough to walk")
		return
	var third := _march(a, TURIN)
	assert_true(bool(third.ok), "an order with too few points left is accepted")
	assert_eq(a.hex, MONT_CENIS, "and walks nothing: the step costs more than the points left")
	assert_eq(StringName(third.walk.stopped), WalkNow.POINTS)
	assert_true(bool(third.walk.standing), "the march stands for the next season")
	assert_eq(a.order, Army.ORDER_MARCH)


# --- R5, R22: the standing rest ------------------------------------------------------------------------------------------


func test_a_route_past_the_seasons_points_walks_one_leg_now_and_stands() -> void:
	var a := _sav(VERCELLI)
	var res := _march(a, AOSTA)
	assert_true(bool(res.ok), str(res.reason))
	assert_eq(a.hex, SADDLE, "ten of its twelve points take it to the saddle now")
	assert_eq(StringName(res.walk.stopped), WalkNow.POINTS)
	assert_true(bool(res.walk.standing))
	assert_eq(a.order, Army.ORDER_MARCH)
	assert_eq(a.route.size(), 1, "the rest of the route is stored")
	assert_eq(a.points, 2)
	MovementPhase.season(_g)
	assert_eq(a.hex, SADDLE, "P: an army that walks two legs in one season (R5, R21)")
	_g.turn = AUTUMN_1480
	Allowance.refill(_g)
	MovementPhase.season(_g)
	assert_eq(a.hex, AOSTA, "the next season's phase walks the rest")
	assert_eq(a.order, Army.ORDER_HOLD)


# --- R20, D4: orders that cannot walk now are stored --------------------------------------------------------------------------


func test_a_mustering_army_stores_its_order() -> void:
	var a := _sav(TURIN, 2, SUMMER_1480)
	var res := _march(a, SUSA)
	assert_true(bool(res.ok), "P: a mustering army's march refused")
	assert_eq(StringName(res.walk.stopped), WalkNow.MUSTERING)
	assert_eq(a.hex, TURIN)
	assert_eq(a.order, Army.ORDER_MARCH, "the order stands")
	assert_eq(a.points, 12, "nothing is spent")


func test_an_army_with_no_points_stores_its_order() -> void:
	var a := _sav(TURIN)
	ArmyFixture.spent(_g, a, 0)
	var res := _march(a, SUSA)
	assert_true(bool(res.ok), "P: a march with no points refused")
	assert_eq(StringName(res.walk.stopped), WalkNow.NO_POINTS)
	assert_eq(a.hex, TURIN)
	assert_eq(a.order, Army.ORDER_MARCH)
	assert_true(bool(res.walk.standing))


func test_a_winter_wait_at_the_first_step_is_stored() -> void:
	_g.turn = WINTER_1480
	var a := _sav(SADDLE)
	var res := _march(a, AOSTA)
	assert_true(bool(res.ok), "P: a winter wait refused")
	assert_eq(StringName(res.walk.stopped), Movement.WHY_WINTER)
	assert_ne(str(res.walk.text), "", "the pass's name")
	assert_eq(a.hex, SADDLE)
	assert_eq(a.waiting, Movement.WHY_WINTER, "waiting is set as today")
	assert_eq(a.order, Army.ORDER_MARCH)
	assert_eq(a.points, 12, "a wait spends nothing")


# --- R18, R21: the wade and the costly step only fresh --------------------------------------------------------------------------


## A wading edge of north Italy (a river of class 2 with no crossing) between two land hexes open to their owner, or {}.
func _wade_edge() -> Dictionary:
	var steps := StepCosts.of(_g.map, _g.defs)
	for i: int in _g.map.hex_count():
		if _g.map.land[i] != 1:
			continue
		for d: int in 6:
			var j := StepCosts.neighbour_index(_g.map.cols, _g.map.rows, i, d)
			if j < 0 or _g.map.land[j] != 1 or steps.cost(i, d, false) != StepCosts.WADE:
				continue
			var tag := Territory.owner_tag(_g, _g.map.hex_of(j))
			if tag != &"" and tag == Territory.owner_tag(_g, _g.map.hex_of(i)):
				return {"i": i, "j": j, "tag": tag}
	return {}


func test_a_wade_is_taken_only_by_a_fresh_army() -> void:
	var edge := _wade_edge()
	if edge.is_empty():
		pending("no wading edge inside one country on north Italy")
		return
	var from := _g.map.hex_of(int(edge.i))
	var to := _g.map.hex_of(int(edge.j))
	var fresh := ArmyFixture.army(_g, StringName(edge.tag), from, 0, 1, 0)
	Armies.set_order(_g, fresh, Army.ORDER_MARCH, to, PackedInt32Array([int(edge.j)]))
	var w := WalkNow.walk(_g, fresh)
	assert_eq(fresh.hex, to, "a fresh army wades")
	assert_eq(fresh.points, 0, "and spends all its points")
	assert_eq(int(w.steps), 1)
	Armies.remove(_g, fresh)
	var walked := ArmyFixture.army(_g, StringName(edge.tag), from, 0, 1, 0)
	ArmyFixture.spent(_g, walked, 11)
	Armies.set_order(_g, walked, Army.ORDER_MARCH, to, PackedInt32Array([int(edge.j)]))
	var w2 := WalkNow.walk(_g, walked)
	assert_eq(walked.hex, from, "P: a wade taken by an army that walked already this season")
	assert_eq(StringName(w2.stopped), WalkNow.POINTS)
	assert_eq(walked.points, 11, "nothing is spent")


func test_a_step_dearer_than_the_points_is_taken_only_fresh() -> void:
	var c := _cost(SUSA, MONT_CENIS)
	var guns := _sav(SUSA, 1, 0, BOMBARDS)
	var full := Allowance.full(_g, guns)
	if c <= full:
		pending("the Mont Cenis step is not dearer than the bombards' points")
		return
	assert_true(bool(_march(guns, MONT_CENIS).ok))
	assert_eq(guns.hex, MONT_CENIS, "a fresh army takes the dear first step")
	assert_eq(guns.points, 0, "and spends all its points")
	var spent := _sav(SUSA, 1, 0, BOMBARDS)
	ArmyFixture.spent(_g, spent, full - 1)
	var res := _march(spent, MONT_CENIS)
	assert_true(bool(res.ok))
	assert_eq(spent.hex, SUSA, "P: a dear step taken by an army that is not fresh")
	assert_eq(spent.points, full - 1)


# --- R23: the room cut ---------------------------------------------------------------------------------------------------------


func test_a_walk_onto_a_full_hex_ends_on_the_last_hex_with_room() -> void:
	var a := _sav(TURIN, 2)
	assert_true(MovesFixture.standing(_g, a, SUSA))
	_sav(SUSA, 4)
	_sav(SUSA, 4)
	var w := WalkNow.walk(_g, a)
	assert_eq(a.hex, TURIN, "the step onto the full hex is stepped back")
	assert_eq(Armies.units_at(_g, SAV, SUSA), 8, "P: nine companies of one country on a hex after a walk")
	assert_eq(StringName(w.stopped), WalkNow.ROOM)
	assert_true(bool(w.standing), "the march stands")
	assert_eq(a.points, 12, "the step not kept is not spent")


# --- R24: the blocked words ---------------------------------------------------------------------------------------------------


func test_a_step_onto_an_army_at_peace_is_not_taken_and_names_it_in_sight() -> void:
	var a := _sav(VERCELLI)
	var res := _g.check("march", {"army": a.id, "goal": AOSTA, "tag": SAV})
	assert_true(bool(res.ok))
	assert_true(MovesFixture.standing(_g, a, AOSTA))
	var blocker := ArmyFixture.army(_g, ArmyFixture.TAG, TURIN, 0, 1, 0)
	assert_eq(_g.map.hex_of(a.route[0]), TURIN, "the route's first step is Turin")
	var w := WalkNow.walk(_g, a)
	assert_eq(a.hex, VERCELLI, "the step onto the army at peace is not taken")
	assert_eq(StringName(w.stopped), Movement.WHY_BLOCKED)
	assert_eq(a.halt_why, Movement.WHY_BLOCKED)
	assert_true(Sight.sees(_g, SAV, TURIN), "Savoy sees Turin")
	assert_string_contains(a.halt_text, "an army of %s is at" % Movement.country_name(_g, ArmyFixture.TAG))
	assert_eq(a.points, 12, "the points are kept")
	assert_eq(blocker.hex, TURIN)


func test_the_blocked_words_name_no_country_out_of_sight() -> void:
	var g := MovesFixture.thin()
	var mlo := Countries.by_tag(g, MLO).id
	var known := Army.NO_HEX
	var unknown := Army.NO_HEX
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] != 1 or Sight.sees(g, MovesFixture.SAVOY, hex):
			continue
		if Sight.explored(g, MovesFixture.SAVOY, hex) and known == Army.NO_HEX:
			known = hex
		elif not Sight.explored(g, MovesFixture.SAVOY, hex) and unknown == Army.NO_HEX:
			unknown = hex
	assert_ne(known, Army.NO_HEX, "an explored hex out of sight")
	assert_ne(unknown, Army.NO_HEX, "an unexplored hex")
	var seen := MovesFixture.named(g, MovesFixture.NAME_HOME).hex
	var named := MarchLeg.blocked_text(g, MovesFixture.SAVOY, seen, mlo)
	assert_string_contains(named, Movement.country_name(g, MLO), "in sight the holder is named")
	var out_of_sight := MarchLeg.blocked_text(g, MovesFixture.SAVOY, known, mlo)
	assert_eq(out_of_sight.find(Movement.country_name(g, MLO)), -1, "P: the country named out of sight")
	assert_eq(out_of_sight, "another country's army stands at %s" % Military.hex_text(g, known))
	assert_eq(MarchLeg.blocked_text(g, MovesFixture.SAVOY, unknown, mlo),
		"another country's army stands at a place you cannot see", "an undiscovered place is not named")


# --- R25, D5: the zone of control ends the season ----------------------------------------------------------------------------


func test_a_zone_of_control_ends_the_walk_and_the_season() -> void:
	var path_set: Array[Vector2i] = [VERCELLI, Vector2i(7, 9), Vector2i(7, 8), Vector2i(6, 7), Vector2i(5, 7),
		Vector2i(4, 7), SADDLE, AOSTA]
	var beside := Army.NO_HEX
	for d: int in 6:
		var n := _g.map.neighbour(Vector2i(7, 8), d)
		if _g.map.is_land(n) and not path_set.has(n):
			beside = n
			break
	assert_ne(beside, Army.NO_HEX)
	Movement.register_test_hostility(SAV, MLO)
	ArmyFixture.army(_g, MLO, beside, 0, 1, 0)
	var a := _sav(VERCELLI)
	var res := _march(a, AOSTA)
	assert_true(bool(res.ok), str(res.reason))
	assert_ne(a.hex, VERCELLI, "the walk moved")
	assert_true(Movement.zoc_halts(_g, SAV, a.hex), "and stopped beside the hostile army")
	assert_eq(StringName(res.walk.stopped), WalkNow.ZOC)
	assert_string_contains(str(res.walk.text), "stands beside it")
	assert_eq(a.points, 0, "P: points kept after a zone of control")
	assert_eq(a.halt_why, &"", "no halt")
	assert_eq(a.order, Army.ORDER_MARCH, "the march stands")
	var again := _g.act("continue_march", {"army": a.id, "tag": SAV})
	assert_false(bool(again.ok), "a standing march needs no Continue")
	var stood := a.hex
	MovementPhase.season(_g)
	assert_eq(a.hex, stood, "the phase walks it no further this season")
