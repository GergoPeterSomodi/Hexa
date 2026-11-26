## Movement: the open land, the move points, the three checks (4.7 rows 1 to 9, halt, continue), the orders, the plan and the
## winter wait (D20), and walk_plan's stops on north Italy (docs/architecture/m6-build-spec.md sections 4.4, 4.7, 4.13 and 9;
## task L6). Every check case has a planted-fault twin (P). North Italy's 1480 game is ArmyFixture's (Genoa is the player).
## Moves in the month (moves-build-spec.md 8.2, MV4; R5, R17, R18): a march walks its first leg in the act, so the cases read the
## army's hex after the act (a one-step march arrives at once); a march that must stay unwalked comes from MovesFixture.standing.
extends GutTest

const SAV := &"SAV"
const TURIN := Vector2i(5, 9)
const VERCELLI := Vector2i(6, 9)
const SUSA := Vector2i(4, 9)
const MONT_CENIS := Vector2i(3, 9)
const SADDLE := Vector2i(3, 7)
const AOSTA := Vector2i(3, 8)
const SPRING_1480 := 1
const SUMMER_1480 := 2
const AUTUMN_1480 := 3
const WINTER_1480 := 4
const SPRING_1481 := 5

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()
	Movement.clear_test_hostility()


func after_each() -> void:
	Movement.clear_test_hostility()


## A Savoy army of `count` companies of pikemen on `hex`, raised at `raised` (0: never mustering).
func _sav(hex: Vector2i, count: int = 2, raised: int = 0) -> Army:
	return ArmyFixture.army(_g, SAV, hex, 0, count, raised)


func _march(a: Army, goal: Vector2i) -> Dictionary:
	return Movement.march(_g, {"army": a.id, "goal": goal, "tag": a.tag})


func _events(kind: String) -> Array:
	var out: Array = []
	for e: Dictionary in _g.events:
		if str(e.get("kind", "")) == kind:
			out.append(e)
	return out


## A land hex with no owner, or NO_HEX (none in the 1480 map at its start).
func _unowned_land() -> Vector2i:
	for i: int in _g.map.hex_count():
		if _g.map.land[i] == 1 and _g.state.owner[i] == 0:
			return _g.map.hex_of(i)
	return Movement.NO_HEX


func _sea() -> Vector2i:
	for i: int in _g.map.hex_count():
		if _g.map.land[i] == 0:
			return _g.map.hex_of(i)
	return Movement.NO_HEX


func test_move_points_are_the_slowest_company() -> void:
	var a := _sav(TURIN, 2)
	assert_eq(Movement.mp_of(_g, a), 12, "pikemen move 12 points a season")
	Armies.add_units(_g, a, 3, 1, 0, TURIN, 0, {})
	assert_eq(Movement.mp_of(_g, a), 8, "a battery of bombards holds the army to 8")


func test_open_land_is_own_or_unowned_and_hostile_only_when_registered() -> void:
	assert_true(Movement.open_to(_g, SAV, TURIN), "own land is open")
	var foreign := ArmyFixture.find_town(_g)
	assert_ne(foreign, Movement.NO_HEX)
	assert_false(Movement.open_to(_g, SAV, foreign), "another country's land is closed in peace")
	assert_false(Movement.open_to(_g, SAV, _sea()), "sea is never open")
	var free := _unowned_land()
	if free != Movement.NO_HEX:
		assert_true(Movement.open_to(_g, SAV, free), "unowned land is open")
	Movement.register_test_hostility(SAV, ArmyFixture.TAG)
	assert_true(Movement.open_to(_g, SAV, foreign), "a registered hostility opens the land")
	assert_true(Movement.open_to(_g, ArmyFixture.TAG, TURIN), "and both ways")


func test_open_mask_matches_open_to() -> void:
	var mask := Movement.open_mask(_g, SAV)
	for i: int in [_g.map.index_of(TURIN), _g.map.index_of(VERCELLI), _g.map.index_of(AOSTA)]:
		assert_eq(mask[i] == 1, Movement.open_to(_g, SAV, _g.map.hex_of(i)))
	var foreign := ArmyFixture.find_town(_g)
	assert_eq(mask[_g.map.index_of(foreign)], 0, "a foreign hex is closed in the mask")


func test_march_refusals_come_in_the_order_of_the_table() -> void:
	var a := _sav(TURIN)
	var none := Movement.march_check(_g, {"tag": SAV, "goal": VERCELLI})
	assert_eq(none.reason, "no army given")
	var no_goal := Movement.march_check(_g, {"army": a.id, "tag": SAV})
	assert_eq(no_goal.reason, "no goal given")
	assert_eq(Movement.march_check(_g, {"army": 999, "tag": SAV, "goal": VERCELLI}).reason, "no army 999")
	var theirs := Movement.march_check(_g, {"army": a.id, "tag": ArmyFixture.TAG, "goal": VERCELLI})
	assert_string_contains(theirs.reason, "not your army")
	assert_eq(Movement.march_check(_g, {"army": a.id, "tag": SAV, "goal": Vector2i(-3, -3)}).reason, "that is off the map")
	assert_eq(Movement.march_check(_g, {"army": a.id, "tag": SAV, "goal": _sea()}).reason, "armies cannot walk on water")
	assert_eq(Movement.march_check(_g, {"army": a.id, "tag": SAV, "goal": TURIN}).reason, "the army stands there already")
	var foreign := ArmyFixture.find_town(_g)
	assert_string_contains(Movement.march_check(_g, {"army": a.id, "tag": SAV, "goal": foreign}).reason, "not your land")


func test_planted_fault_hostility_opens_a_foreign_goal() -> void:
	var a := _sav(TURIN)
	Movement.register_test_hostility(SAV, ArmyFixture.TAG)
	var foreign := ArmyFixture.find_town(_g)
	assert_true(bool(Movement.march_check(_g, {"army": a.id, "tag": SAV, "goal": foreign}).ok),
		"with a registered hostility the foreign goal is open: the row is the land's, not the army's")


func test_march_refused_when_another_country_stands_on_the_goal() -> void:
	var a := _sav(TURIN)
	var other := ArmyFixture.army(_g, ArmyFixture.TAG, VERCELLI, 0, 1, 0)
	var verdict := Movement.march_check(_g, {"army": a.id, "tag": SAV, "goal": VERCELLI})
	assert_string_contains(str(verdict.reason), "another country's army stands at")
	assert_ne(other.id, 0)


func test_march_longer_than_the_season_limit_is_too_far() -> void:
	var a := _sav(TURIN, 2)
	_g.defs.march_seasons_max = 1
	_g.version += 1
	var verdict := Movement.march_check(_g, {"army": a.id, "tag": SAV, "goal": AOSTA})
	assert_string_contains(str(verdict.reason), "too far: more than 1 seasons' march",
		"the Turin road to Aosta is 15 points: more than one pikemen season of 12")
	_g.defs.march_seasons_max = 12
	_g.version += 1
	assert_true(bool(Movement.march_check(_g, {"army": a.id, "tag": SAV, "goal": AOSTA}).ok),
		"with twelve seasons it is a march")


func test_accepted_march_sets_order_route_and_event() -> void:
	var a := _sav(TURIN)
	var before := Armies.digest(_g)
	assert_true(bool(Movement.march_check(_g, {"army": a.id, "tag": SAV, "goal": VERCELLI}).ok))
	var res := _march(a, VERCELLI)
	assert_true(bool(res.ok))
	# moves in the month (R1, R17): the one step over the bridge is walked in the act; on arrival the army holds.
	assert_eq(a.hex, VERCELLI, "one step over the bridge, walked now")
	assert_eq(a.order, Army.ORDER_HOLD)
	assert_eq(a.goal, Movement.NO_HEX)
	assert_eq(int(res.walk.steps), 1, "the act's walk took the one step")
	assert_eq(StringName(res.walk.stopped), WalkNow.ARRIVED)
	assert_eq(int(res.army), a.id)
	var last: Dictionary = _events("army_changed").back()
	assert_eq(int(last.get("army", -1)), a.id)
	assert_ne(Armies.digest(_g), before)


func test_refused_march_changes_nothing() -> void:
	var a := _sav(TURIN)
	var before := Armies.digest(_g)
	var log_before := _g.events.size()
	var verdict := _march(a, Vector2i(-3, -3))
	assert_false(bool(verdict.ok))
	assert_eq(Armies.digest(_g), before, "a refused march leaves the armies as they were")
	assert_eq(_g.events.size(), log_before)


func test_halt_keeps_the_goal_and_continue_resumes_it() -> void:
	var a := _sav(VERCELLI)
	assert_true(bool(_march(a, AOSTA).ok))
	var route_before := a.route.duplicate()
	assert_true(bool(Movement.halt_check(_g, {"army": a.id, "tag": SAV}).ok))
	assert_true(bool(Movement.halt(_g, {"army": a.id, "tag": SAV}).ok))
	assert_eq(a.order, Army.ORDER_NONE, "a halted march has no order")
	assert_eq(a.goal, AOSTA, "its goal is kept")
	assert_eq(a.route, route_before, "and its route")
	assert_true(bool(Movement.continue_check(_g, {"army": a.id, "tag": SAV}).ok), "R continues a halted march")
	assert_true(bool(Movement.continue_march(_g, {"army": a.id, "tag": SAV}).ok))
	assert_eq(a.order, Army.ORDER_MARCH)
	assert_eq(a.goal, AOSTA)


func test_a_second_halt_of_a_halted_march_is_a_hold() -> void:
	var a := _sav(VERCELLI)
	assert_true(bool(_march(a, AOSTA).ok))
	assert_true(bool(Movement.halt(_g, {"army": a.id, "tag": SAV}).ok))
	assert_true(bool(Movement.halt_check(_g, {"army": a.id, "tag": SAV}).ok), "a halted march can be halted again")
	assert_true(bool(Movement.halt(_g, {"army": a.id, "tag": SAV}).ok))
	assert_eq(a.order, Army.ORDER_HOLD, "the second halt holds the army")
	assert_eq(a.goal, Movement.NO_HEX, "and clears the goal")
	assert_eq(a.route.size(), 0, "and the route")
	assert_string_contains(str(Movement.continue_check(_g, {"army": a.id, "tag": SAV}).reason), "no march to continue")
	assert_string_contains(str(Movement.halt_check(_g, {"army": a.id, "tag": SAV}).reason), "holds already")


func test_halted_march_arrives_after_continue() -> void:
	_g.turn = SUMMER_1480
	var a := _sav(TURIN)
	# moves in the month: a standing march (an act would walk it now), halted before the phase.
	assert_true(MovesFixture.standing(_g, a, VERCELLI))
	assert_true(bool(Movement.halt(_g, {"army": a.id, "tag": SAV}).ok))
	MovementPhase.season(_g)
	assert_eq(a.hex, TURIN, "a halted army does not walk")
	assert_true(bool(Movement.continue_march(_g, {"army": a.id, "tag": SAV}).ok))
	# moves in the month (R17): Continue walks at once.
	assert_eq(a.hex, VERCELLI, "the continued march arrives")
	assert_eq(a.order, Army.ORDER_HOLD)
	assert_eq(a.goal, Movement.NO_HEX)


func test_march_to_a_new_goal_replaces_a_halted_march() -> void:
	var a := _sav(TURIN)
	assert_true(MovesFixture.standing(_g, a, VERCELLI))  # moves in the month: a standing march, halted unwalked
	assert_true(bool(Movement.halt(_g, {"army": a.id, "tag": SAV}).ok))
	assert_true(bool(_march(a, SUSA).ok), "a march to a new goal is taken while halted")
	# moves in the month (R17): the new march walks its one step now and holds on arrival.
	assert_eq(a.hex, SUSA)
	assert_eq(a.order, Army.ORDER_HOLD)
	assert_eq(a.halt_why, &"", "the new march clears the halt")


func test_the_hold_order_is_unaffected() -> void:
	var a := _sav(TURIN)
	assert_true(bool(Movement.halt(_g, {"army": a.id, "tag": SAV}).ok), "an idle army is halted into hold")
	assert_eq(a.order, Army.ORDER_HOLD)
	assert_eq(a.goal, Movement.NO_HEX)
	assert_string_contains(str(Movement.halt_check(_g, {"army": a.id, "tag": SAV}).reason), "holds already")
	assert_string_contains(str(Movement.continue_check(_g, {"army": a.id, "tag": SAV}).reason), "no march to continue")


func test_planted_fault_a_marching_army_does_not_continue() -> void:
	var a := _sav(VERCELLI)
	assert_true(bool(_march(a, AOSTA).ok))
	assert_string_contains(str(Movement.continue_check(_g, {"army": a.id, "tag": SAV}).reason),
		"the march goes on by itself")
	assert_false(bool(Movement.halt_check(_g, {"army": a.id, "tag": ArmyFixture.TAG}).ok), "not your army")


func test_plan_in_winter_waits_at_a_closed_pass() -> void:
	_g.turn = WINTER_1480
	var a := _sav(VERCELLI)
	var res := Movement.plan(_g, a, AOSTA)
	assert_true(bool(res.ok))
	assert_ne(str(res.waits), "", "the summer route crosses the closed Little St Bernard edge: the army waits for spring")
	var steps: PackedInt32Array = res.hexes
	assert_eq(_g.map.hex_of(steps[steps.size() - 1]), AOSTA, "the goal is the last hex")
	assert_eq(res.cost, 15, "the summer route costs 15: Turin (2), then over the saddle; Milan holds the east road")


func test_plan_takes_a_winter_detour_when_it_is_cheap_enough() -> void:
	_g.turn = WINTER_1480
	var a := _sav(VERCELLI)
	var waiting := Movement.plan(_g, a, AOSTA)
	assert_ne(str(waiting.waits), "")
	_g.defs.wait_ratio_percent = 5000
	_g.defs.wait_extra_seasons = 12
	_g.version += 1
	var detour := Movement.plan(_g, a, AOSTA)
	assert_true(bool(detour.ok))
	assert_eq(str(detour.waits), "", "a detour within the rule is taken")
	assert_eq(detour.cost, 53, "the winter route round by the Mont Cenis costs 53")


func test_plan_of_the_same_order_is_kept_per_version() -> void:
	var a := _sav(VERCELLI)
	var first := Movement.plan(_g, a, AOSTA)
	var again := Movement.plan(_g, a, AOSTA)
	assert_eq(first.hexes, again.hexes)
	assert_eq(first.cost, again.cost)


func test_walk_plan_stops_on_the_worked_pass_route() -> void:
	_g.turn = AUTUMN_1480
	var a := _sav(VERCELLI)
	var res := Movement.plan(_g, a, AOSTA)
	var walk := Movement.walk_plan(_g, a, res.hexes, AUTUMN_1480)
	var stops: Array = walk.stops
	assert_eq(stops.size(), 3, "Autumn, Winter, Spring")
	assert_eq(int(stops[0].index), 4, "Autumn: four steps to the saddle (10 points), the 5-point step waits")
	assert_eq(int(stops[1].index), 4, "Winter: the closed pass holds it")
	assert_eq(int(stops[2].index), 5, "Spring: the last step is taken")
	assert_eq(int(walk.arrives_turn), SPRING_1481)
	assert_eq(int(walk.seasons), 3)


func test_walk_plan_of_an_empty_route_is_no_season() -> void:
	var a := _sav(VERCELLI)
	var walk := Movement.walk_plan(_g, a, PackedInt32Array(), SUMMER_1480)
	assert_eq(int(walk.seasons), 0)
	assert_eq((walk.stops as Array).size(), 0)


func test_zone_of_control_needs_a_registered_hostility() -> void:
	var beside := _g.map.neighbour(VERCELLI, 0)
	var other := ArmyFixture.army(_g, ArmyFixture.TAG, beside, 0, 1, 0)
	assert_ne(other.id, 0)
	assert_false(Movement.zoc_halts(_g, SAV, VERCELLI), "no hostility, no zone of control")
	Movement.register_test_hostility(SAV, ArmyFixture.TAG)
	assert_true(Movement.zoc_halts(_g, SAV, VERCELLI), "a hostile army beside the hex halts a walk there")
	assert_false(Movement.zoc_halts(_g, ArmyFixture.TAG, VERCELLI), "an army is never hostile to its own country")


func test_cost_field_reaches_the_goal_at_zero() -> void:
	var field := Movement.cost_field(_g, SAV, AOSTA)
	assert_eq(field[_g.map.index_of(AOSTA)], 0)
	assert_eq(field[_g.map.index_of(VERCELLI)], 15)


func test_a_goal_walled_off_by_land_is_no_way() -> void:
	var a := _sav(VERCELLI)
	var goal := Movement.NO_HEX
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if not _g.map.is_land(hex) or Territory.owner_tag(_g, hex) != SAV or ImproveRules.hex_distance(hex, VERCELLI) < 3:
			continue
		if bool(Movement.replan(_g, SAV, VERCELLI, hex, 12).ok):
			goal = hex
			break
	assert_ne(goal, Movement.NO_HEX)
	assert_true(bool(Movement.march_check(_g, {"army": a.id, "tag": SAV, "goal": goal}).ok), "reachable before")
	var walls: Array[Vector2i] = []
	for d: int in 6:
		var nb := _g.map.neighbour(goal, d)
		if _g.map.is_land(nb):
			walls.append(nb)
	Territory.transfer(_g, walls, ArmyFixture.id_of(_g, ArmyFixture.TAG))
	_g.version += 1  # an owner change is a new version (dev_transfer does the same); the plan cache keys on it
	var verdict := Movement.march_check(_g, {"army": a.id, "tag": SAV, "goal": goal})
	assert_eq(str(verdict.reason), Movement.NO_WAY_TEXT, "its own land, closed in by another country's: no way")
	assert_false(bool(verdict.ok))


func test_an_army_on_land_closed_to_it_marches_out() -> void:
	var a := _sav(TURIN)
	var hexes: Array[Vector2i] = [TURIN]
	assert_eq(_g.dev_transfer(hexes, ArmyFixture.id_of(_g, ArmyFixture.TAG)), 1, "its own hex passes to another country")
	assert_false(Movement.open_to(_g, SAV, TURIN), "its hex is no longer open to it")
	var verdict := Movement.march_check(_g, {"army": a.id, "tag": SAV, "goal": VERCELLI})
	assert_true(bool(verdict.ok), "it still marches out to its neighbour")
	assert_true(bool(_march(a, VERCELLI).ok))
	assert_eq(a.hex, VERCELLI, "moves in the month (R17): it walks out in the act")


func test_a_plan_follows_the_hostility_registered_after_it() -> void:
	var a := _sav(VERCELLI)
	var foreign := ArmyFixture.find_town(_g)
	assert_false(bool(Movement.plan(_g, a, foreign).ok), "no hostility: the foreign town is no way")
	Movement.register_test_hostility(SAV, ArmyFixture.TAG)
	assert_true(bool(Movement.plan(_g, a, foreign).ok), "a registration after a refusal is seen at once")
	Movement.clear_test_hostility()
	assert_false(bool(Movement.plan(_g, a, foreign).ok), "and a clear after an ok is seen at once")



func test_a_march_check_and_its_act_plan_once() -> void:
	var a := _sav(VERCELLI)
	var args := {"army": a.id, "goal": AOSTA, "tag": SAV}
	var table: Dictionary = _g.view_cache.pinned(&"plans", _g.version, func() -> Dictionary: return {}) as Dictionary
	assert_eq(table.size(), 0, "nothing planned yet")
	var check := Movement.march_check(_g, args)
	assert_true(bool(check.ok), str(check.reason))
	assert_eq(table.size(), 1, "the check searched once")
	var cached: Dictionary = table.values()[0] as Dictionary
	cached["marker"] = true
	var again := Movement.march_check(_g, args)
	assert_eq(again, check, "a second check gives the same verdict")
	assert_eq(table.size(), 1, "and does not search again")
	var res := Movement.march(_g, args)
	assert_true(bool(res.ok), str(res.reason))
	assert_true((table.values()[0] as Dictionary).has("marker"), "P: the act read the check's plan (a fresh search would drop the marker)")
	# moves in the month (R5): the act walks the cached route's head now and stores its tail.
	var hexes: PackedInt32Array = cached.hexes
	var head := hexes.size() - a.route.size()
	assert_eq(hexes.slice(head), a.route, "the order stores the cached route, less the steps walked now")
	assert_eq(_g.map.index_of(a.hex), hexes[head - 1], "and stands on the last step it walked")
	assert_eq(Movement.replan(_g, SAV, VERCELLI, AOSTA, Movement.mp_of(_g, a)).cost, cached.cost, "the result is the plain search's")


## R32 (D15): a refusal of an undiscovered foreign goal names no owner; a discovered one names it (P: an owner named).
func test_refusal_of_an_undiscovered_goal_names_no_owner() -> void:
	FogFixture.thin(_g, ArmyFixture.TAG, 1)
	var goal := Movement.NO_HEX
	var owner := &""
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		var o := int(_g.state.owner[i])
		if _g.map.land[i] == 1 and o > 0 and o != ArmyFixture.id_of(_g, ArmyFixture.TAG) and not Knowledge.discovered(_g, ArmyFixture.TAG, hex):
			goal = hex
			owner = Countries.by_id(_g, o).tag
			break
	assert_ne(goal, Movement.NO_HEX, "an undiscovered foreign land hex exists")
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, ArmyFixture.find_town(_g), 0, 1)
	var res := Movement.march_check(_g, {"army": a.id, "tag": ArmyFixture.TAG, "goal": goal})
	assert_false(bool(res.ok))
	assert_string_contains(str(res.reason), "another country holds it")
	assert_false(str(res.reason).contains(Movement.country_name(_g, owner)), "P: the undiscovered owner is not named")


func test_refusal_of_a_discovered_goal_names_its_owner() -> void:
	var goal := Movement.NO_HEX
	var owner := &""
	for i: int in _g.map.hex_count():
		var o := int(_g.state.owner[i])
		if _g.map.land[i] == 1 and o > 0 and o != ArmyFixture.id_of(_g, ArmyFixture.TAG):
			goal = _g.map.hex_of(i)
			owner = Countries.by_id(_g, o).tag
			break
	assert_ne(goal, Movement.NO_HEX, "a foreign land hex exists")
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, ArmyFixture.find_town(_g), 0, 1)
	var res := Movement.march_check(_g, {"army": a.id, "tag": ArmyFixture.TAG, "goal": goal})
	assert_string_contains(str(res.reason), Movement.country_name(_g, owner), "P: a discovered owner is named")
