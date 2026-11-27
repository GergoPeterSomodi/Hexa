## The End-turn leg (GitHub issue 474, owner playtest 2026-11-27; docs/architecture/moves-build-spec.md R5, R22, R22a): every End
## turn moves a marching army one leg along its route. An army that spent its points at once walks its next leg at End turn with
## the NEXT season's points (the march_on phase: MovementPhase.next_leg; ready_units keeps them), so after End turn they show spent;
## an army that still had points and a standing order walks those in the movement phase as before and keeps the new season's
## points; never two legs of one season. North Italy's 1480 game (ArmyFixture: Genoa the player, a Savoyard army at Vercelli).
## The replay lays the End-turn leg after the phase's walks and their retreats (ReplayPlan, MovementPhase.NEXT_LEG_TICK).
extends GutTest

const SAV := &"SAV"
const VERCELLI := Vector2i(6, 9)
const SUMMER_1480 := 2
const NO_HEX := Vector2i(-1, -1)

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()
	_g.turn = SUMMER_1480
	Movement.clear_test_hostility()


func after_each() -> void:
	Movement.clear_test_hostility()


func _sav(hex: Vector2i = VERCELLI, raised: int = -1) -> Army:
	return ArmyFixture.army(_g, SAV, hex, 0, 2, raised)


## The nearest goal (in hex index order, 6 to 20 hexes away) the army reaches in exactly `seasons` seasons from this one with
## its full points (Movement.walk_plan); NO_HEX when none.
func _goal_in(a: Army, seasons: int) -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		var d := ImproveRules.hex_distance(a.hex, hex)
		if d < 6 or d > 20 or not _g.map.is_land(hex):
			continue
		if not bool(Movement.march_check(_g, {"army": a.id, "goal": hex, "tag": a.tag}).ok):
			continue
		var plan := Movement.plan(_g, a, hex)
		if int(Movement.walk_plan(_g, a, plan.hexes as PackedInt32Array, _g.turn).seasons) == seasons:
			return hex
	return NO_HEX


## Where the season-by-season plan has the army at the end of season k (0: this one).
func _stop_hex(a_start: Vector2i, route: PackedInt32Array, stops: Array, k: int) -> Vector2i:
	var idx := int((stops[k] as Dictionary).index)
	return a_start if idx <= 0 else _g.map.hex_of(route[idx - 1])


func _unit_moved_of(army_id: int) -> Array:
	var out: Array = []
	for e: Dictionary in _g.events:
		if str(e.get("kind", "")) == "unit_moved" and int(e.get("army", -1)) == army_id:
			out.append(e)
	return out


# --- the bug: End turn does not move an army that walked at once ------------------------------------------------------------


func test_every_end_turn_moves_a_marching_army_one_leg() -> void:
	var a := _sav()
	var full := Allowance.full(_g, a)
	var goal := _goal_in(a, 3)
	assert_ne(goal, NO_HEX, "a goal three seasons away")
	var start := a.hex
	var route := Movement.plan(_g, a, goal).hexes as PackedInt32Array
	var stops: Array = Movement.walk_plan(_g, a, route, _g.turn).stops
	var res := _g.act("march", {"army": a.id, "goal": goal, "tag": SAV})
	assert_true(bool(res.ok), str(res.reason))
	assert_eq(a.hex, _stop_hex(start, route, stops, 0), "the first leg walks at the click")
	assert_true(a.points < full, "and spends this season's points")
	assert_true(bool(Season.run(_g).ok))
	assert_eq(a.hex, _stop_hex(start, route, stops, 1), "P: End turn does not move a marching army (issue 474)")
	assert_eq(a.order, Army.ORDER_MARCH, "the march still stands")
	assert_true(a.points < full, "the End-turn leg spent the new season's points: %d of %d" % [a.points, full])
	assert_true(bool(Season.run(_g).ok))
	assert_eq(a.hex, goal, "the next End turn walks the last leg: one leg a season, as the plan says")
	assert_eq(a.order, Army.ORDER_HOLD)


func test_the_end_turn_leg_never_walks_two_legs_of_one_season() -> void:
	var a := _sav()
	var goal := _goal_in(a, 4)
	if goal == NO_HEX:
		pending("no goal four seasons away")
		return
	var start := a.hex
	var route := Movement.plan(_g, a, goal).hexes as PackedInt32Array
	var stops: Array = Movement.walk_plan(_g, a, route, _g.turn).stops
	assert_true(bool(_g.act("march", {"army": a.id, "goal": goal, "tag": SAV}).ok))
	for k: int in range(1, 4):
		assert_true(bool(Season.run(_g).ok))
		assert_eq(a.hex, _stop_hex(start, route, stops, k), "P: two legs in one season (season %d)" % k)


func test_a_march_through_stops_walks_at_end_turn_too() -> void:
	var a := _sav()
	var goal := _goal_in(a, 3)
	assert_ne(goal, NO_HEX)
	var start := a.hex
	var route := Movement.plan(_g, a, goal).hexes as PackedInt32Array
	var stops: Array = Movement.walk_plan(_g, a, route, _g.turn).stops
	# A stop on the second leg, on the direct route: the joined route is the direct one.
	var first := int((stops[0] as Dictionary).index)
	var second := int((stops[1] as Dictionary).index)
	assert_true(second - first >= 2, "the second leg has a hex inside it")
	var stop := _g.map.hex_of(route[first])
	var res := _g.act("march", {"army": a.id, "goal": goal, "tag": SAV, "via": [stop]})
	assert_true(bool(res.ok), str(res.reason))
	assert_eq(a.via.size(), 1, "the stop is ahead")
	assert_true(bool(Season.run(_g).ok))
	assert_eq(a.hex, _stop_hex(start, route, stops, 1), "P: a multi-leg march that waits for a click")
	assert_true(a.via.is_empty(), "the stop was passed on the End-turn leg")
	assert_eq(a.order, Army.ORDER_MARCH)


# --- unspent points walk first, as before -------------------------------------------------------------------------------


func test_an_army_with_points_left_walks_them_and_keeps_the_new_seasons_points() -> void:
	var a := _sav()
	var full := Allowance.full(_g, a)
	var goal := _goal_in(a, 3)
	assert_ne(goal, NO_HEX)
	var start := a.hex
	var route := Movement.plan(_g, a, goal).hexes as PackedInt32Array
	var stops: Array = Movement.walk_plan(_g, a, route, _g.turn).stops
	assert_true(MovesFixture.standing(_g, a, goal), "a standing march with all its points: nothing walked yet")
	assert_true(bool(Season.run(_g).ok))
	assert_eq(a.hex, _stop_hex(start, route, stops, 0), "the movement phase walks the unspent points (one leg)")
	assert_eq(a.points, full, "P: a second leg with the new season's points in the same End turn (double speed)")
	assert_eq(a.order, Army.ORDER_MARCH)


func test_a_mustering_armys_stored_order_sets_out_at_end_turn() -> void:
	var a := _sav(VERCELLI, SUMMER_1480)
	var full := Allowance.full(_g, a)
	var goal := _goal_in(a, 4)  # the mustering season walks nothing
	assert_ne(goal, NO_HEX)
	var res := _g.act("march", {"army": a.id, "goal": goal, "tag": SAV})
	assert_eq(StringName(res.walk.stopped), WalkNow.MUSTERING, "stored")
	assert_eq(a.hex, VERCELLI)
	assert_true(bool(Season.run(_g).ok))
	assert_ne(a.hex, VERCELLI, "it sets out at End turn, with the new season's points")
	assert_true(a.points < full)


func test_an_army_with_no_points_and_a_stored_order_sets_out_at_end_turn() -> void:
	var a := _sav()
	var goal := _goal_in(a, 3)
	assert_ne(goal, NO_HEX)
	ArmyFixture.spent(_g, a, 0)
	var res := _g.act("march", {"army": a.id, "goal": goal, "tag": SAV})
	assert_eq(StringName(res.walk.stopped), WalkNow.NO_POINTS)
	assert_true(bool(Season.run(_g).ok))
	assert_ne(a.hex, VERCELLI, "P: a stored march that waits for a click")


# --- the report and the replay ------------------------------------------------------------------------------------------


func test_the_report_shows_the_end_turn_leg_and_the_next_season_starts_clean() -> void:
	var a := _sav()
	var goal := _goal_in(a, 3)
	assert_ne(goal, NO_HEX)
	assert_true(bool(_g.act("march", {"army": a.id, "goal": goal, "tag": SAV}).ok))
	assert_true(bool(Season.run(_g).ok))
	assert_eq(a.moved_from, VERCELLI, "the season's line runs from where it set out")
	assert_eq(a.season_from, NO_HEX, "the new season has no move yet: the End-turn leg is the report's")


func test_the_end_turn_legs_unit_moved_is_a_phase_walk_after_the_phases_ticks() -> void:
	var a := _sav()
	var goal := _goal_in(a, 3)
	assert_ne(goal, NO_HEX)
	assert_true(bool(_g.act("march", {"army": a.id, "goal": goal, "tag": SAV}).ok))
	_g.events.clear()
	assert_true(bool(Season.run(_g).ok))
	var moved := _unit_moved_of(a.id)
	assert_eq(moved.size(), 1, "one walk at End turn")
	var e: Dictionary = moved[0]
	assert_false(bool(e.now), "a phase walk, not an at-once one")
	var ticks := e.ticks as PackedInt32Array
	assert_true(ticks[0] > MovementPhase.NEXT_LEG_TICK, "its ticks count from the End-turn leg's base: %s" % str(ticks))


func test_the_end_turn_leg_never_enters_land_declared_on_this_season() -> void:
	var g := MovesFixture.declared_now()
	var a := MovesFixture.named(g, MovesFixture.NAME_HOME)
	ArmyFixture.spent(g, a, 0)
	var war := Wars.war_between(g, MovesFixture.SAVOY, MovesFixture.MILAN)
	assert_eq(war.start_turn, g.turn, "declared this season")
	var near := MovesFixture.named(g, MovesFixture.NAME_NEAR)
	# A goal in Milan's land, past the near army: an order now is refused (fair warning), so the order is planted.
	var goal := Vector2i(-1, -1)
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if Territory.owner_tag(g, hex) == MovesFixture.MILAN and ImproveRules.hex_distance(hex, a.hex) == 2 \
				and Movement.armies_on(g, hex).is_empty() and hex != near.hex:
			goal = hex
			break
	if goal == Vector2i(-1, -1) or not MovesFixture.standing(g, a, goal):
		pending("no Milanese goal two hexes away")
		return
	g.orders = null
	assert_true(bool(Season.run(g).ok))
	var on := Territory.owner_tag(g, a.hex)
	assert_ne(on, MovesFixture.MILAN, "P: the End-turn leg walks into the land of a war declared this season (fair warning)")
	assert_eq(a.order, Army.ORDER_MARCH, "the march stands: it goes on next season")


func test_a_battle_on_the_end_turn_leg_is_fought_in_this_end_turn_and_ends_the_next_season() -> void:
	var g := MovesFixture.duel()
	g.orders = null  # Milan stands still
	var a := MovesFixture.named(g, MovesFixture.NAME_HOME)
	var foe := MovesFixture.named(g, MovesFixture.NAME_NEAR)
	# A hex beside the Milanese army from which the attack is one step (no river or ridge between).
	var beside := NO_HEX
	var home := a.hex
	for d: int in 6:
		var n := g.map.neighbour(foe.hex, d)
		if not g.map.is_land(n) or not Movement.armies_on(g, n).is_empty() or not Movement.open_to(g, a.tag, n):
			continue
		Armies.set_hex(g, a, n, a.hex)
		g.version += 1
		var plan := Movement.plan(g, a, foe.hex)
		if bool(plan.ok) and (plan.hexes as PackedInt32Array).size() == 1:
			beside = n
			break
		Armies.set_hex(g, a, home, a.hex)
	if beside == NO_HEX:
		pending("no hex one step from the Milanese army")
		return
	Sight.refresh(g)
	ArmyFixture.spent(g, a, 0)
	var res := g.act("march", {"army": a.id, "goal": foe.hex, "tag": a.tag})
	assert_true(bool(res.ok), str(res.reason))
	assert_eq(StringName(res.walk.stopped), WalkNow.NO_POINTS, "stored: no points left this season")
	var turn := g.turn
	var records := g.battle_records.size()
	assert_true(bool(Season.run(g).ok))
	assert_eq(g.battle_records.size(), records + 1, "P: the End-turn leg's battle left for the next End turn")
	assert_eq(g.battle_records.back().turn, turn, "the battle is of the End turn that walked it (the report, the badges)")
	assert_true(g.battles.is_empty(), "no battle open at idle")
	var alive := Armies.by_id(g, a.id)
	if alive != null:
		assert_eq(alive.points, 0, "R27: the battle ends the army's next season too")


# --- ReplayPlan: the End-turn leg after the phase and its retreats ------------------------------------------------------------


func _p(hexes: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(hexes)
	return out


func _rec(army: int, path: Array[Vector2i], ticks: Array, now: bool = false) -> Dictionary:
	var seen := PackedByteArray()
	seen.resize(path.size())
	seen.fill(1)
	return {"tag": &"SAV", "army": army, "path": path, "seen": seen, "ticks": PackedInt32Array(ticks), "now": now}


func _pose_of(poses: Array[Dictionary], army: int) -> Dictionary:
	for pose: Dictionary in poses:
		if int(pose["army"]) == army:
			return pose
	return {}


func test_the_replay_plays_the_end_turn_leg_after_the_phase_and_its_retreats() -> void:
	var a1 := Vector2i(1, 1)
	var b1 := Vector2i(2, 1)
	var c1 := Vector2i(3, 1)
	var d1 := Vector2i(4, 1)
	var e1 := Vector2i(5, 1)
	var f1 := Vector2i(6, 1)
	var n := MovementPhase.NEXT_LEG_TICK
	# The phase: army 1 walks A, B, C (ticks 1, 2) and fights at C; army 2 retreats from C (tick 3). The End-turn leg: army 3
	# walks D, E, F (ticks n + 1, n + 2).
	var records: Array[Dictionary] = [
		_rec(1, _p([a1, b1, c1]), [1, 2]),
		_rec(2, _p([c1, b1]), [3]),
		_rec(3, _p([d1, e1, f1]), [n + 1, n + 2])]
	var plan := ReplayPlan.new()
	plan.record_battle(c1, 2)
	plan.setup(ReplayPlan.chain(records), &"normal")
	assert_almost_eq(plan.duration(), 1.0, 0.001, "five shown steps one after another: no empty ticks take time")
	plan.advance(0.5)
	var poses := plan.poses()
	assert_eq(_pose_of(poses, 2)["to"], b1, "the retreat plays after the phase's walk")
	assert_eq(_pose_of(poses, 3)["to"], d1, "P: the End-turn leg before the phase's retreat")
	plan.advance(0.2)
	poses = plan.poses()
	assert_true(_pose_of(poses, 2).is_empty(), "the retreat is done")
	assert_eq(_pose_of(poses, 3)["to"], e1, "then the End-turn leg walks")
