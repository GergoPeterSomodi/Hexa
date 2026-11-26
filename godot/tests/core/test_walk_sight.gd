## Stop on sight (docs/architecture/moves-build-spec.md R6, R32 to R35, D6 to D8; MV7): a walk ends on the step after which an
## army at war that its country did not see when the walk began comes into the walking army's sight (halt sighted, the points
## kept), at once (WalkNow) and in the movement phase, where the test runs at every tick with the armies where they stand then; a
## zone of control on the same step wins (the season is over) and a step onto the goal arrives; Continue walks on with a new seen
## set. The words name only what the walker sees (R57). North Italy's duel (MovesFixture.duel: Savoy and Milan at war), with the
## fixture's own Milanese armies taken off so the scene holds only the armies placed here. Every case names its planted fault (P).
extends GutTest

const SAV := MovesFixture.SAVOY
const MLO := MovesFixture.MILAN
const KNIGHTS := 2
## The knights' scene (sight 2): Savoy's own land west of Turin, walked east; a Milanese army stands out of Savoy's sight two
## hexes from the second step.
const K_START := Vector2i(3, 7)
const K_GOAL := Vector2i(6, 7)
const K_SIGHTED_AT := Vector2i(5, 7)
const K_FOE := Vector2i(6, 5)
## The pikemen's scene (sight 1): a walk into Milan's land whose second step stands beside an unseen Milanese army.
const P_START := Vector2i(5, 7)
const P_GOAL := Vector2i(7, 5)
const P_BESIDE := Vector2i(7, 6)
const P_FOE := Vector2i(8, 6)

var _g: Game


func before_each() -> void:
	_g = MovesFixture.duel()
	for a: Army in _g.armies.duplicate():
		if a.tag == MLO:
			Armies.remove(_g, a)
	Sight.refresh(_g)
	Movement.clear_test_hostility()


func after_each() -> void:
	Movement.clear_test_hostility()


func _hexes(indices: PackedInt32Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in indices:
		out.append(_g.map.hex_of(i))
	return out


func _cost(a: Vector2i, b: Vector2i) -> int:
	var m := _g.map
	return StepCosts.of(m, _g.defs).cost(m.index_of(a), Movement.direction(m, m.index_of(a), m.index_of(b)), false)


func _events(kind: String) -> Array:
	var out: Array = []
	for e: Dictionary in _g.events:
		if str(e.get("kind", "")) == kind:
			out.append(e)
	return out


## The knights' scene: the knights on K_START and a Milanese army on `foe_hex` (K_FOE unless given), Savoy's sight refreshed; the
## preconditions asserted (the foe out of Savoy's sight, the route K_START to K_GOAL through K_SIGHTED_AT).
func _knights_scene(foe_tag: StringName = MLO) -> Dictionary:
	var k := ArmyFixture.army(_g, SAV, K_START, KNIGHTS, 1, 0)
	var foe := ArmyFixture.army(_g, foe_tag, K_FOE, 0, 1, 0)
	Sight.refresh(_g)
	assert_false(Sight.sees(_g, SAV, K_FOE), "the foe stands out of Savoy's sight")
	assert_eq(MarchLeg.army_sight(_g, k), 2, "knights see two hexes")
	var plan := Movement.plan(_g, k, K_GOAL)
	assert_true(bool(plan.ok))
	assert_eq(_hexes(plan.hexes), [Vector2i(4, 7), K_SIGHTED_AT, K_GOAL] as Array[Vector2i], "the route")
	assert_eq(ImproveRules.hex_distance(K_SIGHTED_AT, K_FOE), 2, "the second step brings the foe into sight")
	assert_gt(ImproveRules.hex_distance(Vector2i(4, 7), K_FOE), 2, "the first does not")
	assert_gt(ImproveRules.hex_distance(K_START, K_FOE), 2)
	assert_gt(ImproveRules.hex_distance(K_GOAL, K_FOE), 1, "no zone of control on the way")
	return {"k": k, "foe": foe}


func _sighted_words(foe: Army) -> String:
	return "an army of %s came into sight at %s" % [Movement.country_name(_g, MLO), Military.hex_text(_g, foe.hex)]


# --- R32: at once -----------------------------------------------------------------------------------------------------------


func test_an_army_that_comes_into_sight_ends_the_walk_at_once_with_the_points_kept() -> void:
	var s := _knights_scene()
	var k: Army = s.k
	_g.events.clear()
	var res := _g.act("march", {"army": k.id, "goal": K_GOAL, "tag": SAV})
	assert_true(bool(res.ok), str(res.reason))
	assert_eq(k.hex, K_SIGHTED_AT, "P: a walk that goes on past a newly seen enemy army")
	var walk: Dictionary = res.walk
	assert_eq(StringName(walk.stopped), WalkNow.SIGHTED)
	assert_eq(int(walk.steps), 2)
	assert_eq(k.halt_why, Movement.WHY_SIGHTED, "a halt")
	assert_eq(k.order, Army.ORDER_NONE, "order none")
	assert_eq(k.goal, K_GOAL, "the goal kept")
	assert_eq(k.points, 16 - _cost(K_START, Vector2i(4, 7)) - _cost(Vector2i(4, 7), K_SIGHTED_AT), "the points left are kept")
	assert_gt(k.points, 0)
	assert_eq(k.halt_text, _sighted_words(s.foe))
	assert_eq(str(walk.text), k.halt_text)
	var halts := _events("march_halted")
	assert_eq(halts.size(), 1)
	assert_eq(str(halts[0].why), "sighted")
	assert_true(Movement.HALT_WHYS.has(Movement.WHY_SIGHTED))


func test_the_sighted_words_name_only_what_the_walker_sees() -> void:
	var s := _knights_scene()
	var res := _g.act("march", {"army": (s.k as Army).id, "goal": K_GOAL, "tag": SAV})
	var text := str(res.walk.text)
	assert_string_contains(text, Movement.country_name(_g, MLO))
	for h: Vector2i in MovePreview.named_hexes(text):
		assert_true(Sight.sees(_g, SAV, h), "P: a halt that names a place out of sight (%s)" % str(h))
	var toast := MoveWords.of(_g, SAV, (s.k as Army).id, res.walk)
	assert_string_contains(str(toast.text), "came into sight", "the toast keeps the engine's words in sight")


func test_an_army_at_peace_does_not_stop_the_walk() -> void:
	var s := _knights_scene(&"GEN")
	assert_false(Wars.at_war(_g, SAV, &"GEN"))
	var res := _g.act("march", {"army": (s.k as Army).id, "goal": K_GOAL, "tag": SAV})
	assert_eq((s.k as Army).hex, K_GOAL, "P: a stop for an army that is not at war")
	assert_eq(StringName(res.walk.stopped), WalkNow.ARRIVED)


func test_an_army_seen_when_the_walk_began_does_not_stop_it() -> void:
	var s := _knights_scene()
	var k: Army = s.k
	# A Savoyard watcher beside the foe: Savoy sees it before the walk, so it is in the seen set.
	var watch := ArmyFixture.army(_g, SAV, Vector2i(6, 6), 0, 1, 0)
	Sight.refresh(_g)
	assert_true(Sight.sees(_g, SAV, K_FOE), "the foe is seen at the start")
	var res := _g.act("march", {"army": k.id, "goal": K_GOAL, "tag": SAV})
	assert_eq(k.hex, K_GOAL, "P: a halt for an army the country saw when the walk began")
	assert_eq(StringName(res.walk.stopped), WalkNow.ARRIVED)
	assert_not_null(watch)


# --- R34: in the phase --------------------------------------------------------------------------------------------------------


func test_the_phase_stops_a_standing_march_on_sight() -> void:
	var s := _knights_scene()
	var k: Army = s.k
	assert_true(MovesFixture.standing(_g, k, K_GOAL))
	MovementPhase.season(_g)
	assert_eq(k.hex, K_SIGHTED_AT, "P: a phase walk that goes on")
	assert_eq(k.halt_why, Movement.WHY_SIGHTED)
	assert_eq(k.order, Army.ORDER_NONE)
	assert_gt(k.points, 0, "the points are kept")
	assert_eq(k.halt_text, _sighted_words(s.foe))


## The foe starts far out of the knights' sight and walks into it during the phase: the test at each tick reads where it stands then.
func test_the_phase_stops_a_walk_when_an_enemy_walks_into_its_sight() -> void:
	var k := ArmyFixture.army(_g, SAV, K_START, KNIGHTS, 1, 0)
	var path: Array[Vector2i] = [K_START, Vector2i(4, 7), K_SIGHTED_AT, K_GOAL]
	var from := Army.NO_HEX
	for d: int in 6:
		var q := _g.map.neighbour(K_FOE, d)
		if _g.map.index_of(q) < 0 or Territory.owner_tag(_g, q) != MLO or Sight.sees(_g, SAV, q):
			continue
		var far := true
		for h: Vector2i in path:
			far = far and ImproveRules.hex_distance(q, h) > 2
		if far:
			from = q
			break
	assert_ne(from, Army.NO_HEX, "a Milanese hex next to the foe's goal, far from the knights' walk")
	var foe := ArmyFixture.army(_g, MLO, from, 0, 1, 0)
	Sight.refresh(_g)
	assert_true(MovesFixture.standing(_g, k, K_GOAL))
	assert_true(MovesFixture.standing(_g, foe, K_FOE))
	assert_lt(k.id, foe.id, "the knights step first in each tick")
	MovementPhase.season(_g)
	assert_eq(foe.hex, K_FOE, "the foe walked")
	assert_ne(k.hex, K_GOAL, "P: a phase walk that passes an army that walked into its sight")
	assert_eq(k.halt_why, Movement.WHY_SIGHTED)
	assert_eq(k.halt_text, _sighted_words(foe))
	assert_gt(k.points, 0)


# --- R33, D8: the zone of control wins; the goal arrives ---------------------------------------------------------------------------


## The pikemen and the foe beside its second step; the preconditions asserted.
func _pikemen_scene(goal: Vector2i) -> Army:
	var p := ArmyFixture.army(_g, SAV, P_START, 0, 1, 0)
	ArmyFixture.army(_g, MLO, P_FOE, 0, 1, 0)
	Sight.refresh(_g)
	assert_false(Sight.sees(_g, SAV, P_FOE), "the foe stands out of Savoy's sight")
	var plan := Movement.plan(_g, p, goal)
	assert_true(bool(plan.ok))
	var route := _hexes(plan.hexes)
	assert_eq(route[0], Vector2i(6, 7))
	assert_eq(route[1], P_BESIDE, "the second step stands beside the foe")
	assert_gt(ImproveRules.hex_distance(Vector2i(6, 7), P_FOE), 1)
	return p


func test_the_zone_of_control_wins_over_sight_at_once() -> void:
	var p := _pikemen_scene(P_GOAL)
	var res := _g.act("march", {"army": p.id, "goal": P_GOAL, "tag": SAV})
	assert_true(bool(res.ok), str(res.reason))
	assert_eq(p.hex, P_BESIDE)
	assert_eq(StringName(res.walk.stopped), WalkNow.ZOC, "zone of control, not sighted")
	assert_eq(p.points, 0, "P: a sighted halt that keeps points beside the enemy")
	assert_eq(p.halt_why, &"", "no halt")
	assert_eq(p.order, Army.ORDER_MARCH, "the march stands")


func test_the_zone_of_control_wins_over_sight_in_the_phase() -> void:
	var p := _pikemen_scene(P_GOAL)
	assert_true(MovesFixture.standing(_g, p, P_GOAL))
	MovementPhase.season(_g)
	assert_eq(p.hex, P_BESIDE)
	assert_eq(p.points, 0, "P: a sighted halt that keeps points beside the enemy")
	assert_eq(p.halt_why, &"")
	assert_eq(p.order, Army.ORDER_MARCH)


func test_a_step_onto_the_goal_arrives_though_an_enemy_comes_into_sight() -> void:
	var p := _pikemen_scene(P_BESIDE)
	var res := _g.act("march", {"army": p.id, "goal": P_BESIDE, "tag": SAV})
	assert_eq(p.hex, P_BESIDE)
	assert_eq(StringName(res.walk.stopped), WalkNow.ARRIVED, "P: a sighted halt on the goal")
	assert_eq(p.order, Army.ORDER_HOLD)
	assert_eq(p.halt_why, &"")


# --- R35: Continue --------------------------------------------------------------------------------------------------------------


func test_continue_after_a_sighted_halt_walks_on_with_the_points_left() -> void:
	var s := _knights_scene()
	var k: Army = s.k
	assert_true(bool(_g.act("march", {"army": k.id, "goal": K_GOAL, "tag": SAV}).ok))
	assert_eq(k.halt_why, Movement.WHY_SIGHTED)
	var left := k.points
	assert_true(Sight.sees(_g, SAV, K_FOE), "the army seen is in the new seen set")
	var res := _g.act("continue_march", {"army": k.id, "tag": SAV})
	assert_true(bool(res.ok), str(res.reason))
	assert_eq(k.hex, K_GOAL, "P: Continue that halts at once on the same army")
	assert_eq(StringName(res.walk.stopped), WalkNow.ARRIVED)
	assert_eq(k.points, left - _cost(K_SIGHTED_AT, K_GOAL), "it walks with the points it kept")


func test_a_standing_march_does_not_stop_again_for_an_army_already_seen() -> void:
	var s := _knights_scene()
	var k: Army = s.k
	assert_true(bool(_g.act("march", {"army": k.id, "goal": K_GOAL, "tag": SAV}).ok))
	assert_true(MovesFixture.standing(_g, k, K_GOAL))
	MovementPhase.season(_g)
	assert_eq(k.hex, K_GOAL, "the phase's seen set, taken at its start, holds the army seen")
	assert_eq(k.halt_why, &"")


# --- R45, R57: the preview never gives sighted --------------------------------------------------------------------------------


func test_the_preview_never_stops_on_sight_and_is_equal_without_the_unseen_army() -> void:
	var s := _knights_scene()
	var k: Army = s.k
	var with_foe := MovePreview.to(_g, SAV, k.id, K_GOAL)
	assert_eq(StringName(with_foe.leg.why), MovePreview.WHY_ARRIVES, "the preview knows nothing of the unseen army")
	assert_ne(StringName(with_foe.leg.why), MovePreview.WHY_SIGHTED)
	assert_eq(MovePreview.WHY_SIGHTED, Movement.WHY_SIGHTED)
	var twin := MovesFixture.duel()
	for a: Army in twin.armies.duplicate():
		if a.tag == MLO:
			Armies.remove(twin, a)
	var k2 := ArmyFixture.army(twin, SAV, K_START, KNIGHTS, 1, 0)
	Sight.refresh(twin)
	var without := MovePreview.to(twin, SAV, k2.id, K_GOAL)
	assert_eq(with_foe.leg, without.leg, "P: a leg that moves with an unseen army")
	assert_eq(with_foe.lines, without.lines)
	assert_eq(with_foe.risks, without.risks)
