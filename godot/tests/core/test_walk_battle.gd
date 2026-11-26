## Battles at once (docs/architecture/moves-build-spec.md R8, R26 to R31, D10 to D13, D23; MV4): a march onto an enemy army fights
## the battle in the act (the record kept, game.battles empty), every army of both sides that fought ends its season, a refused
## contact stops before the hex, a storm with points left is fought now and one with none waits for the battles phase, the winner
## is halted, and checks and previews draw no luck. The duel of MovesFixture (Savoy and Milan at war on north Italy). Every case
## names its planted fault (P).
extends GutTest

const SAV := MovesFixture.SAVOY
const MLO := MovesFixture.MILAN

var _g: Game


func before_each() -> void:
	_g = MovesFixture.duel()
	Movement.clear_test_hostility()


func after_each() -> void:
	Movement.clear_test_hostility()


func _events(kind: String) -> Array:
	var out: Array = []
	for e: Dictionary in _g.events:
		if str(e.get("kind", "")) == kind:
			out.append(e)
	return out


## A free land hex beside `hex` (no army on it), or NO_HEX.
func _free_beside(hex: Vector2i) -> Vector2i:
	for d: int in 6:
		var n := _g.map.neighbour(hex, d)
		if _g.map.index_of(n) >= 0 and _g.map.is_land(n) and Armies.at(_g, n).is_empty():
			return n
	return Army.NO_HEX


## A free land hex beside `hex` from which the step onto `hex` is a plain one (no ridge, wade or closed pass), or NO_HEX.
func _plain_step_to(hex: Vector2i) -> Vector2i:
	var steps := StepCosts.of(_g.map, _g.defs)
	var m := _g.map
	for d: int in 6:
		var n := m.neighbour(hex, d)
		if m.index_of(n) < 0 or not m.is_land(n) or not Armies.at(_g, n).is_empty():
			continue
		var c := steps.cost(m.index_of(n), Movement.direction(m, m.index_of(n), m.index_of(hex)), false)
		if c >= 1 and c <= 6:
			return n
	return Army.NO_HEX


## A Savoyard army of two companies beside the near Milanese army, one plain step from it; the sight refreshed.
func _beside_near() -> Army:
	var near := MovesFixture.named(_g, MovesFixture.NAME_NEAR)
	var at := _plain_step_to(near.hex)
	assert_ne(at, Army.NO_HEX, "a free hex beside the Milanese army")
	var a := ArmyFixture.army(_g, SAV, at, 0, 2, 0)
	Sight.refresh(_g)
	return a


## A Milanese fortress with men in it, or NO_HEX.
func _milan_fortress() -> Vector2i:
	for i: int in _g.war_cache.fortresses(_g):
		var h := _g.map.hex_of(i)
		if Occupation.controller_tag(_g, h) == MLO and Occupation.garrison_of(_g, h) > 0 and Armies.at(_g, h).is_empty():
			return h
	return Army.NO_HEX


# --- R26, R27: a march onto the enemy is fought in the act -----------------------------------------------------------------


func test_a_march_onto_an_enemy_army_fights_in_the_act() -> void:
	var a := _beside_near()
	var near := MovesFixture.named(_g, MovesFixture.NAME_NEAR)
	var target := near.hex
	var both: Array[Army] = [a, near]
	var res := _g.act("march", {"army": a.id, "goal": target, "tag": SAV})
	assert_true(bool(res.ok), str(res.reason))
	assert_eq(_g.battles.size(), 0, "P: a battle left in game.battles after the act")
	assert_eq(StringName(res.walk.stopped), WalkNow.FOUGHT)
	var id := int(res.walk.battle)
	assert_true(id >= 1, "the walk names the record")
	var rec := Battles.record(_g, id)
	assert_not_null(rec, "the record is kept")
	if rec != null:
		assert_eq(rec.hex, target)
		assert_eq(rec.attacker, SAV)
	assert_eq(_events("battle_started").size(), 1)
	assert_eq(_events("battle_ended").size(), 1, "P: the battle left for the battles phase")
	var moved := _events("unit_moved")
	assert_true(moved.size() >= 1 and bool(moved[0].now), "the walk onto the hex is at once")
	for x: Army in both:
		if Armies.by_id(_g, x.id) != null:
			assert_eq(x.points, 0, "P: army %d keeps points after the battle (R27)" % x.id)


func test_a_beaten_army_does_not_walk_again_in_the_season() -> void:
	var a := _beside_near()
	var near := MovesFixture.named(_g, MovesFixture.NAME_NEAR)
	assert_true(bool(_g.act("march", {"army": a.id, "goal": near.hex, "tag": SAV}).ok))
	for x: Army in [a, near]:
		var alive := Armies.by_id(_g, x.id)
		if alive == null:
			continue
		var away := _free_beside(alive.hex)
		if away == Army.NO_HEX or not Movement.open_to(_g, alive.tag, away):
			continue
		Armies.set_order(_g, alive, Army.ORDER_MARCH, away, PackedInt32Array([_g.map.index_of(away)]))
		var from := alive.hex
		var w := WalkNow.walk(_g, alive)
		assert_eq(StringName(w.stopped), WalkNow.NO_POINTS, "P: a fought army that walks again in the same season")
		assert_eq(alive.hex, from)


# --- R30, D12: the winner is halted -----------------------------------------------------------------------------------------


func test_the_attacker_ends_with_no_march_and_no_points() -> void:
	var a := _beside_near()
	var near := MovesFixture.named(_g, MovesFixture.NAME_NEAR)
	var target := near.hex
	assert_true(bool(_g.act("march", {"army": a.id, "goal": target, "tag": SAV}).ok))
	if Armies.by_id(_g, a.id) == null:
		pending("the attacker was destroyed this seed")
		return
	assert_ne(a.order, Army.ORDER_MARCH, "P: a winner that walks on in the same season")
	assert_eq(a.order, Army.ORDER_NONE, "today's state: order none")
	assert_eq(a.points, 0)
	if a.hex == target:
		assert_eq(a.goal, target, "a winner keeps its goal (D12)")


# --- R28: a refused contact stops before the hex ---------------------------------------------------------------------------


func test_a_shaken_army_stops_before_the_enemy() -> void:
	var a := _beside_near()
	var near := MovesFixture.named(_g, MovesFixture.NAME_NEAR)
	assert_true(MovesFixture.standing(_g, a, near.hex), "the standing march to the enemy")
	for u: Unit in a.units:
		Armies.set_morale(_g, a, u.id, 0)
	var from := a.hex
	var w := WalkNow.walk(_g, a)
	assert_eq(a.hex, from, "P: a shaken army that steps in")
	assert_eq(StringName(w.stopped), Movement.WHY_SHAKEN)
	assert_eq(a.halt_why, Movement.WHY_SHAKEN)
	assert_string_contains(str(w.text), "too shaken")
	assert_eq(_events("battle_started").size(), 0)
	assert_eq(a.points, Allowance.full(_g, a), "nothing was walked")


# --- R29, D13: storms ------------------------------------------------------------------------------------------------------


func test_a_storm_with_points_walks_and_is_fought_now() -> void:
	var fort := _milan_fortress()
	if fort == Army.NO_HEX:
		pending("no Milanese fortress with men in it")
		return
	var at := _free_beside(fort)
	if at == Army.NO_HEX:
		pending("no free hex beside the fortress")
		return
	var a := ArmyFixture.army(_g, SAV, at, 0, 4, 0)
	Sight.refresh(_g)
	var res := _g.act("storm", {"army": a.id, "goal": fort, "tag": SAV})
	assert_true(bool(res.ok), str(res.reason))
	assert_eq(_g.battles.size(), 0, "P: a storm with points left that waits for the battles phase")
	assert_eq(StringName(res.walk.stopped), WalkNow.FOUGHT)
	assert_true(int(res.walk.battle) >= 1)
	var started := _events("battle_started")
	assert_eq(started.size(), 1)
	if started.size() == 1:
		assert_true(bool(started[0].assault), "an assault")
	if Armies.by_id(_g, a.id) != null:
		assert_eq(a.points, 0, "the storm ends its season")


func test_a_storm_standing_on_its_fortress_is_fought_now() -> void:
	var fort := _milan_fortress()
	if fort == Army.NO_HEX:
		pending("no Milanese fortress with men in it")
		return
	var a := ArmyFixture.army(_g, SAV, fort, 0, 4, 0)
	Sight.refresh(_g)
	var res := _g.act("storm", {"army": a.id, "goal": fort, "tag": SAV})
	assert_true(bool(res.ok), str(res.reason))
	assert_eq(int(res.walk.steps), 0, "it walks nowhere")
	assert_true(int(res.walk.battle) >= 1, "the assault is fought in the act")
	assert_eq(_g.battles.size(), 0)


func test_a_storm_with_no_points_waits_for_the_battles_phase() -> void:
	var fort := _milan_fortress()
	if fort == Army.NO_HEX:
		pending("no Milanese fortress with men in it")
		return
	var a := ArmyFixture.army(_g, SAV, fort, 0, 4, 0)
	Sight.refresh(_g)
	ArmyFixture.spent(_g, a, 0)
	var res := _g.act("storm", {"army": a.id, "goal": fort, "tag": SAV})
	assert_true(bool(res.ok), str(res.reason))
	assert_eq(StringName(res.walk.stopped), WalkNow.NO_POINTS)
	assert_eq(_events("battle_started").size(), 0, "no assault in the act")
	assert_eq(a.order, Army.ORDER_STORM, "the storm is stored")
	Battles.season(_g)
	assert_eq(_events("battle_started").size(), 1, "the battles phase starts it (today's path)")


# --- R31, D23: luck ----------------------------------------------------------------------------------------------------------


func test_checks_and_previews_draw_no_luck() -> void:
	var a := _beside_near()
	var near := MovesFixture.named(_g, MovesFixture.NAME_NEAR)
	var luck := _g.luck.digest_text()
	var world := _g.luck.world.get_state()
	var digest := _g.digest()
	var goals: Array[Vector2i] = [near.hex, MovesFixture.named(_g, MovesFixture.NAME_HOME).hex]
	for d: int in 6:
		goals.append(_g.map.neighbour(a.hex, d))
	for k: int in 1000:
		var goal := goals[k % goals.size()]
		_g.check("march", {"army": a.id, "goal": goal, "tag": SAV})
		_g.check("storm", {"army": a.id, "goal": goal, "tag": SAV})
		if k % 10 == 0:
			MovePreview.to(_g, SAV, a.id, goal)
	assert_eq(_g.luck.world.get_state(), world, "P: 1,000 checks and previews that change game.luck")
	assert_eq(_g.luck.digest_text(), luck)
	assert_eq(_g.digest(), digest, "and nothing else")
	assert_true(bool(_g.act("march", {"army": a.id, "goal": near.hex, "tag": SAV}).ok))
	assert_ne(_g.luck.world.get_state(), world, "the act's battle draws the luck")
