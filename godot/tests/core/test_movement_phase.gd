## The movement phase (docs/architecture/m6-build-spec.md sections 4.4, 5.0 R1, R6, D12, D20, D22 and 9; task L6): the legs within
## the move points, mustering, the winter wait (one march_halted, then the spring step), a halt with no way, the ticks and the
## block of a hostile army (with its planted twin), the stack limit at the phase's end, unit_moved's fields, the explored hexes
## along a walk, and determinism. North Italy, the 1480 game (ArmyFixture); Savoy's armies walk its own and unowned land.
## Moves in the month (moves-build-spec.md 8.2, MV4): a march walks its first leg at once now, so the phase has nothing left to
## walk after an act: the cases give their armies standing marches through MovesFixture.standing; the phase walks with the points
## left (R22), the zone of control ends the season (R25), and unit_moved gains `now` (false in the phase).
extends GutTest

const SAV := &"SAV"
const TURIN := Vector2i(5, 9)
const VERCELLI := Vector2i(6, 9)
const SADDLE := Vector2i(3, 7)
const AOSTA := Vector2i(3, 8)
const SEVEN_NINE := Vector2i(7, 9)
const AUTUMN_1480 := 3
const WINTER_1480 := 4
const SPRING_1481 := 5
const SUMMER_1480 := 2
const MLO := &"MLO"

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()
	Movement.clear_test_hostility()


func after_each() -> void:
	Movement.clear_test_hostility()


func _sav(hex: Vector2i, count: int = 2, raised: int = 0) -> Army:
	return ArmyFixture.army(_g, SAV, hex, 0, count, raised)


## moves in the month: a standing march (the order and route stored, nothing walked), as the phase finds it next season.
func _march(a: Army, goal: Vector2i) -> Dictionary:
	return {"ok": MovesFixture.standing(_g, a, goal)}


func _events(kind: String) -> Array:
	var out: Array = []
	for e: Dictionary in _g.events:
		if str(e.get("kind", "")) == kind:
			out.append(e)
	return out


func _moved_for(army_id: int) -> Array:
	var out: Array = []
	for e: Dictionary in _events("unit_moved"):
		if int(e.army) == army_id:
			out.append(e)
	return out


func _halts_for(army_id: int) -> Array:
	var out: Array = []
	for e: Dictionary in _events("march_halted"):
		if int(e.army) == army_id:
			out.append(e)
	return out


func _companies_on(hex: Vector2i) -> int:
	return Armies.units_at(_g, SAV, hex) + Armies.units_at(_g, ArmyFixture.TAG, hex)


func test_an_army_walks_within_its_move_points() -> void:
	_g.turn = AUTUMN_1480
	var a := _sav(VERCELLI)
	assert_true(bool(_march(a, AOSTA).ok))
	MovementPhase.season(_g)
	assert_eq(a.hex, SADDLE, "ten of its twelve points take it to the saddle; the 5-point step waits")
	assert_eq(a.order, Army.ORDER_MARCH, "the march goes on next season")
	assert_eq(a.route.size(), 1, "one step is left on the stored route")
	# moves in the month (R40): the walk keeps where it set out in season_from; moved_from comes at ready_units.
	assert_eq(a.season_from, VERCELLI)
	# moves in the month (R22): the phase spends the points: two of its twelve are left.
	assert_eq(a.points, 2, "ten of twelve spent")
	assert_eq(a.waiting, &"", "no winter wait in autumn")
	var moved := _moved_for(a.id)
	assert_eq(moved.size(), 1)
	var path: Array = moved[0].path
	assert_eq(path.size(), 5, "the start and four steps: Turin, the Mont Cenis road, the saddle")
	assert_eq(path[0], VERCELLI)
	assert_eq(path[path.size() - 1], SADDLE)
	assert_eq(Array(moved[0].ticks), [1, 2, 3, 4], "one tick a step")
	assert_false(bool(moved[0].arrived))
	assert_false(bool(moved[0].now), "moves in the month: a phase walk is not an at-once walk")


## Moves in the month (R22): the phase walks a standing march with the points the army has left, and none with no points.
func test_the_phase_walks_with_the_points_left_and_not_at_all_with_none() -> void:
	_g.turn = AUTUMN_1480
	var a := _sav(VERCELLI)
	assert_true(bool(_march(a, AOSTA).ok))
	ArmyFixture.spent(_g, a, 4)
	var b := _sav(TURIN)
	assert_true(bool(_march(b, AOSTA).ok))
	ArmyFixture.spent(_g, b, 0)
	MovementPhase.season(_g)
	assert_ne(a.hex, VERCELLI, "four points take it a step or two")
	assert_true(a.points >= 0 and a.points < 4, "and are spent")
	assert_ne(a.hex, SADDLE, "P: a phase that walks with the full points reaches the saddle")
	assert_eq(b.hex, TURIN, "P: a phase that walks an army that spent its points at once")
	assert_eq(_moved_for(b.id).size(), 0)
	assert_eq(b.order, Army.ORDER_MARCH, "its march stands for next season")


func test_a_mustering_army_stands_for_its_season() -> void:
	_g.turn = SUMMER_1480
	var a := _sav(TURIN, 2, SUMMER_1480)
	# moves in the month (R20): the order is accepted and stored while it musters (march would store it too, unwalked).
	assert_true(bool(Movement.march(_g, {"army": a.id, "goal": VERCELLI, "tag": SAV}).ok), "orders are taken while it musters")
	assert_eq(a.hex, TURIN, "and the act walks nothing")
	MovementPhase.season(_g)
	assert_eq(a.hex, TURIN, "it musters in the season it was raised")
	assert_eq(_moved_for(a.id).size(), 0)
	assert_eq(a.order, Army.ORDER_MARCH)


func test_the_winter_wait_is_one_halt_then_the_spring_step_arrives() -> void:
	_g.turn = WINTER_1480
	var a := _sav(SADDLE)
	assert_true(bool(_march(a, AOSTA).ok))
	MovementPhase.season(_g)
	assert_eq(a.hex, SADDLE, "the closed pass holds it")
	assert_eq(a.waiting, Movement.WHY_WINTER)
	assert_eq(a.order, Army.ORDER_MARCH, "it keeps its order and waits")
	var halts := _halts_for(a.id)
	assert_eq(halts.size(), 1)
	assert_eq(str(halts[0].why), "winter")
	assert_true(bool(halts[0].waits))
	assert_ne(str(halts[0].reason), "", "the pass's name is the reason")
	MovementPhase.season(_g)
	assert_eq(_halts_for(a.id).size(), 1, "a second winter season adds no second halt")
	_g.turn = SPRING_1481
	MovementPhase.season(_g)
	assert_eq(a.hex, AOSTA, "the spring step is taken")
	assert_eq(a.order, Army.ORDER_HOLD, "on arrival it holds")
	assert_eq(a.goal, Movement.NO_HEX)
	assert_eq(a.waiting, &"")
	var moved := _moved_for(a.id)
	assert_true(bool(moved[moved.size() - 1].arrived))


func test_a_march_with_no_way_left_halts_and_keeps_its_goal() -> void:
	_g.turn = SUMMER_1480
	var a := _sav(TURIN)
	assert_true(bool(_march(a, VERCELLI).ok))
	var gen := ArmyFixture.id_of(_g, ArmyFixture.TAG)
	var hexes: Array[Vector2i] = [VERCELLI]
	assert_eq(Territory.transfer(_g, hexes, gen), 1, "the goal passes to another country")
	MovementPhase.season(_g)
	assert_eq(a.hex, TURIN, "it does not move")
	assert_eq(a.order, Army.ORDER_NONE, "a halt holds no order")
	assert_eq(a.goal, VERCELLI, "the goal is kept")
	assert_eq(a.halt_why, Movement.WHY_NO_WAY)
	assert_string_contains(a.halt_text, "no way to")
	var halts := _halts_for(a.id)
	assert_eq(halts.size(), 1)
	assert_eq(str(halts[0].why), "no_way")
	assert_false(bool(halts[0].waits))


func test_a_hostile_army_on_the_road_blocks_the_walk() -> void:
	var holder := Territory.owner_tag(_g, SEVEN_NINE)
	assert_ne(holder, SAV, "the road's hex is another country's")
	Movement.register_test_hostility(SAV, holder)
	_g.turn = SUMMER_1480
	var blocker := ArmyFixture.army(_g, holder, SEVEN_NINE, 0, 1, 0)
	var a := _sav(VERCELLI)
	assert_true(bool(_march(a, AOSTA).ok))
	MovementPhase.season(_g)
	assert_eq(a.hex, VERCELLI, "the step into the hostile army is not taken")
	assert_eq(a.halt_why, Movement.WHY_BLOCKED)
	assert_eq(str(_halts_for(a.id)[0].why), "blocked")
	assert_string_contains(a.halt_text, "is at")
	assert_eq(blocker.hex, SEVEN_NINE)


func test_planted_fault_without_hostility_the_road_stays_closed() -> void:
	var holder := Territory.owner_tag(_g, SEVEN_NINE)
	_g.turn = SUMMER_1480
	var a := _sav(VERCELLI)
	assert_true(bool(_march(a, AOSTA).ok))
	MovementPhase.season(_g)
	assert_ne(holder, SAV)
	assert_eq(_halts_for(a.id).size(), 0, "no hostility: nothing blocks, and the route avoids the foreign hex")
	var moved := _moved_for(a.id)
	assert_eq(moved.size(), 1)
	for hex: Vector2i in moved[0].path:
		assert_ne(hex, SEVEN_NINE, "the walk never enters the foreign land")


func test_the_stack_limit_is_kept_at_the_phase_end() -> void:
	_g.turn = SUMMER_1480
	var goal := ArmyFixture.find_town(_g)
	assert_ne(goal, Movement.NO_HEX)
	var starts: Array[Vector2i] = []
	for d: int in 6:
		if starts.size() < 3:
			starts.append(_g.map.neighbour(goal, d))
	var armies: Array[Army] = []
	for hex: Vector2i in starts:
		armies.append(ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 4, 0))
	for a: Army in armies.slice(0, 2):
		assert_true(bool(_march(a, goal).ok), "two armies of four fit")
	var third := armies[2]
	var route := Movement.plan(_g, third, goal)
	Armies.set_order(_g, third, Army.ORDER_MARCH, goal, route.hexes)
	MovementPhase.season(_g)
	assert_eq(_companies_on(goal), 8, "eight companies stand on the hex, no more")
	assert_true(Movement.direction(_g.map, _g.map.index_of(third.hex), _g.map.index_of(goal)) >= 0,
		"the last army stepped back one hex along its leg, still beside the goal")
	assert_eq(third.route[0], _g.map.index_of(goal), "and its route still reaches the goal")
	assert_eq(third.order, Army.ORDER_MARCH, "its march goes on next season")


func test_unit_moved_carries_path_ticks_seen_and_witnesses() -> void:
	_g.turn = SUMMER_1480
	_g.player = SAV
	var a := _sav(TURIN)
	assert_true(bool(_march(a, VERCELLI).ok))
	MovementPhase.season(_g)
	var moved := _moved_for(a.id)
	assert_eq(moved.size(), 1)
	var e: Dictionary = moved[0]
	assert_eq((e.path as Array).size(), 2, "the start and the one step")
	assert_eq(e.path[0], TURIN)
	assert_eq(e.path[1], VERCELLI)
	assert_eq(Array(e.ticks), [1])
	var seen: PackedByteArray = e.seen
	assert_eq(seen.size(), (e.path as Array).size(), "one seen flag a hex of the path")
	assert_eq(e.seen[0], 1, "the player's own army is seen")
	assert_true(bool(e.arrived))
	assert_true(Array(e.witnesses).has(String(SAV)), "the actor witnesses its own walk")


func test_seen_is_all_ones_with_no_player() -> void:
	_g.turn = SUMMER_1480
	_g.player = &""
	var a := _sav(TURIN)
	assert_true(bool(_march(a, VERCELLI).ok))
	MovementPhase.season(_g)
	var e: Dictionary = _moved_for(a.id)[0]
	for v: int in e.seen:
		assert_eq(v, 1, "with no player every step is seen")


func test_walks_explore_their_hexes() -> void:
	_g.turn = AUTUMN_1480
	var a := _sav(VERCELLI)
	assert_true(bool(_march(a, AOSTA).ok))
	MovementPhase.season(_g)
	assert_true(Sight.explored(_g, SAV, SADDLE), "the saddle the walk reached is explored")
	assert_true(Sight.explored(_g, SAV, Vector2i(7, 8)), "and so is every hex it passed")


func test_the_same_orders_give_the_same_armies() -> void:
	var first := _run_three_seasons()
	var second := _run_three_seasons()
	assert_eq(first, second, "same seed and same orders, same armies")


func _run_three_seasons() -> String:
	var g := ArmyFixture.game()
	var a := ArmyFixture.army(g, SAV, VERCELLI, 0, 2, 0)
	g.turn = AUTUMN_1480
	MovesFixture.standing(g, a, AOSTA)  # moves in the month: a standing march, walked by the phase
	for k: int in 3:
		g.turn += 1
		MovementPhase.season(g)
		Allowance.refill(g)  # moves in the month: ready_units refills the points each season
	var out := Armies.digest(g)
	Movement.clear_test_hostility()
	return out


## The wading edge of north Italy (a river of class 2 with no crossing) and a cheap step into its near hex, or {}.
func _wade_edge(steps: StepCosts) -> Dictionary:
	for i: int in _g.map.hex_count():
		if _g.map.land[i] != 1:
			continue
		for d: int in 6:
			var j := StepCosts.neighbour_index(_g.map.cols, _g.map.rows, i, d)
			if j >= 0 and _g.map.land[j] == 1 and steps.cost(i, d, false) == StepCosts.WADE:
				return {"i": i, "j": j}
	return {}


func _cheap_step_into(steps: StepCosts, i: int) -> Dictionary:
	for d: int in 6:
		var k := StepCosts.neighbour_index(_g.map.cols, _g.map.rows, i, d)
		if k < 0 or _g.map.land[k] != 1:
			continue
		var back := (d + 3) % 6
		var c := steps.cost(k, back, false)
		if c >= 1 and c < 12:
			return {"k": k}
	return {}


func test_wade_is_taken_only_as_the_first_step_of_a_season() -> void:
	var steps := StepCosts.of(_g.map, _g.defs)
	var edge := _wade_edge(steps)
	if edge.is_empty():
		pending("no wading edge on north Italy")
		return
	var i: int = edge.i
	var j: int = edge.j
	var first := Movement.walk_season(_g.map, steps, i, PackedInt32Array([j]), 0, 12, false)
	assert_eq(int(first.idx), 1, "a wade is taken as the first step of the season")
	assert_eq(int(first.pts), 0, "and it spends all the points")
	var cheap := _cheap_step_into(steps, i)
	if cheap.is_empty():
		pending("no cheap step into the wading edge's hex")
		return
	var second := Movement.walk_season(_g.map, steps, int(cheap.k), PackedInt32Array([i, j]), 0, 12, false)
	assert_eq(int(second.cur), i, "the cheap step is taken")
	assert_eq(int(second.idx), 1, "a wade after it waits for the next season")
	assert_gt(int(second.pts), 0)


func test_a_zone_of_control_ends_the_leg_but_is_not_a_halt() -> void:
	var path_set: Array[Vector2i] = [VERCELLI, Vector2i(7, 9), Vector2i(7, 8), Vector2i(6, 7), Vector2i(5, 7),
		Vector2i(4, 7), SADDLE, AOSTA]
	var beside := Movement.NO_HEX
	for d: int in 6:
		var n := _g.map.neighbour(Vector2i(7, 8), d)
		if _g.map.is_land(n) and not path_set.has(n):
			beside = n
			break
	assert_ne(beside, Movement.NO_HEX)
	Movement.register_test_hostility(SAV, MLO)
	_g.turn = SUMMER_1480
	var blocker := ArmyFixture.army(_g, MLO, beside, 0, 1, 0)
	var a := _sav(VERCELLI)
	assert_true(bool(_march(a, AOSTA).ok))
	assert_true(a.route.has(_g.map.index_of(Vector2i(7, 9))), "the march runs east, through Milan's land, once it is open")
	MovementPhase.season(_g)
	assert_ne(a.hex, VERCELLI, "the walk moved")
	assert_ne(a.hex, AOSTA, "and stopped short, beside the hostile army")
	assert_true(Movement.zoc_halts(_g, SAV, a.hex))
	assert_eq(a.halt_why, &"", "a zone of control is not a halt")
	assert_eq(a.order, Army.ORDER_MARCH, "the march goes on next season")
	# moves in the month (R25, D5): the zone of control ends the army's season too.
	assert_eq(a.points, 0, "P: points kept after a zone of control")
	assert_eq(blocker.hex, beside)


func test_a_walk_steps_back_more_than_one_hex_when_the_stack_overflows_twice() -> void:
	_g.turn = SUMMER_1480
	var goal := ArmyFixture.find_town(_g)
	var ring: Array[Vector2i] = []
	for d: int in 6:
		var nb := _g.map.neighbour(goal, d)
		if _g.map.is_land(nb) and Territory.owner_tag(_g, nb) == ArmyFixture.TAG:
			ring.append(nb)
	if ring.size() < 3:
		pending("the town has fewer than three neighbours of its own")
		return
	var n2 := ring[2]
	var far := Movement.NO_HEX
	for d: int in 6:
		var nb := _g.map.neighbour(n2, d)
		if _g.map.is_land(nb) and ImproveRules.hex_distance(nb, goal) == 2:
			far = nb
			break
	if far == Movement.NO_HEX:
		pending("no hex two away from the town beside its neighbour")
		return
	var gen := ArmyFixture.TAG
	var a := ArmyFixture.army(_g, gen, ring[0], 0, 4, 0)
	var b := ArmyFixture.army(_g, gen, ring[1], 0, 4, 0)
	ArmyFixture.army(_g, gen, n2, 0, 4, 0)
	ArmyFixture.army(_g, gen, n2, 0, 4, 0)
	var c := ArmyFixture.army(_g, gen, far, 0, 4, 0)
	for x: Army in [a, b]:
		var res: Dictionary = Movement.plan(_g, x, goal)
		Armies.set_order(_g, x, Army.ORDER_MARCH, goal, res.hexes)
	Armies.set_order(_g, c, Army.ORDER_MARCH, goal, PackedInt32Array([_g.map.index_of(n2), _g.map.index_of(goal)]))
	MovementPhase.season(_g)
	assert_eq(c.hex, far, "the last walk steps back twice: past the goal, then past the crowded hex")
	assert_eq(_companies_on(goal), 8)
	assert_eq(_companies_on(n2), 8, "the crowded hex holds its eight")
	assert_eq(_companies_on(far), 4)
	assert_eq(c.order, Army.ORDER_MARCH)


func test_a_winter_wait_stepped_back_for_the_stack_limit_resumes_next_season() -> void:
	_g.turn = WINTER_1480
	var north := Vector2i(4, 7)
	_sav(SADDLE, 4)
	_sav(SADDLE, 4)
	var a := _sav(north, 4)
	var route := PackedInt32Array([_g.map.index_of(SADDLE), _g.map.index_of(AOSTA)])
	Armies.set_order(_g, a, Army.ORDER_MARCH, AOSTA, route)
	MovementPhase.season(_g)
	assert_eq(a.hex, north, "the walk is stepped back off the crowded saddle")
	assert_eq(a.waiting, &"", "it is not waiting at the pass: it stands a hex short")
	assert_eq(a.order, Army.ORDER_MARCH, "its march goes on")
	assert_eq(_halts_for(a.id).size(), 0, "a stepped-back walk gets no halt event")
	assert_eq(a.route.size(), 2, "its route keeps the saddle and the goal")
	_g.turn = SPRING_1481
	MovementPhase.season(_g)
	assert_eq(a.hex, AOSTA, "next season it resumes and arrives")
	assert_eq(a.order, Army.ORDER_HOLD)

