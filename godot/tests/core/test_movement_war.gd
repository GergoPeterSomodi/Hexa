## Movement in war (docs/architecture/m7-build-spec.md 4.7, 4.8, D21, D22, D39, D40; M7 plan B12): the open land follows a war at
## once, the mask closes a hostile garrisoned fortress but the goal, zones of control beside enemies and fortresses, the storm order
## (its check rows, its halt, the assault on arrival), the standing order's rows, can_stand per side, the tick's engage, shaken and
## blocked stops, determinism and the conservation of men. North Italy's 1480 game (ArmyFixture); Savoy (SAV) and Milan (MLO) are
## at war by WarFixture.at_war in the tests that need it. Every case has its planted twin where the rule is a refusal.
extends GutTest

const SAV := &"SAV"
const MLO := &"MLO"

var _g: Game


func before_each() -> void:
	_g = ArmyFixture.game()
	Movement.clear_test_hostility()


func after_each() -> void:
	Movement.clear_test_hostility()


func _sav(hex: Vector2i, count: int = 2) -> Army:
	return ArmyFixture.army(_g, SAV, hex, 0, count, 0)


func _country_id(tag: StringName) -> int:
	return Countries.by_tag(_g, tag).id


## A land hex of Milan's (its owner byte) that Savoy's army may not stand on before the war.
func _milan_hex() -> Vector2i:
	var mlo := _country_id(MLO)
	for i: int in _g.map.hex_count():
		if _g.map.land[i] == 1 and int(_g.state.owner[i]) == mlo:
			return _g.map.hex_of(i)
	return Movement.NO_HEX


## A pair (Savoy's land hex, Milan's land hex beside it), or [] when the map has none.
func _clash_pair() -> Array:
	var sav := _country_id(SAV)
	var mlo := _country_id(MLO)
	for i: int in _g.map.hex_count():
		if _g.map.land[i] != 1 or int(_g.state.owner[i]) != sav:
			continue
		var a := _g.map.hex_of(i)
		for d: int in 6:
			var b := _g.map.neighbour(a, d)
			var j := _g.map.index_of(b)
			if j >= 0 and _g.map.land[j] == 1 and int(_g.state.owner[j]) == mlo:
				return [a, b]
	return []


## A Milan fortress with men in it (the controller Milan), or NO_HEX.
func _milan_fortress() -> Vector2i:
	for i: int in _g.war_cache.fortresses(_g):
		var h := _g.map.hex_of(i)
		if Occupation.controller_tag(_g, h) == MLO and Occupation.garrison_of(_g, h) > 0:
			return h
	return Movement.NO_HEX


## A land hex beside `hex` that Savoy may stand on (its own or unowned), or NO_HEX.
func _own_neighbour(hex: Vector2i) -> Vector2i:
	var sav := _country_id(SAV)
	for d: int in 6:
		var n := _g.map.neighbour(hex, d)
		var j := _g.map.index_of(n)
		if j >= 0 and _g.map.land[j] == 1 and (int(_g.state.owner[j]) == sav or int(_g.state.owner[j]) == 0):
			return n
	return Movement.NO_HEX


## A land hex of Savoy's own (the first in index order), or NO_HEX.
func _home() -> Vector2i:
	var sav := _country_id(SAV)
	for i: int in _g.map.hex_count():
		if _g.map.land[i] == 1 and int(_g.state.owner[i]) == sav:
			return _g.map.hex_of(i)
	return Movement.NO_HEX


func _events(kind: String) -> Array:
	var out: Array = []
	for e: Dictionary in _g.events:
		if str(e.get("kind", "")) == kind:
			out.append(e)
	return out


func _men_total() -> int:
	var total := 0
	for a: Army in _g.armies:
		total += a.men()
	return total


# --- the open land and the war -----------------------------------------------------------------------------------------------


func test_open_land_follows_a_declared_war_at_once() -> void:
	var hex := _milan_hex()
	assert_ne(hex, Movement.NO_HEX)
	assert_false(Movement.open_to(_g, SAV, hex), "in peace Milan's land is closed to Savoy")
	assert_eq(Movement.open_mask(_g, SAV)[_g.map.index_of(hex)], 0, "and so is its mask")
	WarFixture.at_war(_g, SAV, MLO)
	assert_true(Movement.open_to(_g, SAV, hex), "a war opens the land at once")
	assert_eq(Movement.open_mask(_g, SAV)[_g.map.index_of(hex)], 1, "the cached mask is not stale: the war state is in its key")


func test_planted_fault_an_ended_war_closes_the_land_again() -> void:
	var hex := _milan_hex()
	WarFixture.ended(_g, SAV, MLO, _g.turn)
	assert_false(Movement.open_to(_g, SAV, hex), "a war that ended opens nothing")
	assert_eq(Movement.open_mask(_g, SAV)[_g.map.index_of(hex)], 0)


func test_hostility_is_the_war_and_the_test_seam_still_wins() -> void:
	assert_false(Movement.hostile(_g, SAV, MLO), "no war, no hostility")
	WarFixture.at_war(_g, SAV, MLO)
	assert_true(Movement.hostile(_g, SAV, MLO), "a live war is hostility")
	assert_false(Movement.hostile(_g, SAV, SAV), "a country is never hostile to itself")
	Movement.clear_test_hostility()
	Movement.register_test_hostility(SAV, &"GEN")
	assert_true(Movement.hostile(_g, SAV, &"GEN"), "a registered pair is hostile too")


# --- the mask, the fortress and the zone of control --------------------------------------------------------------------------


func test_a_hostile_garrisoned_fortress_is_closed_but_for_the_goal() -> void:
	var fort := _milan_fortress()
	if fort == Movement.NO_HEX:
		pending("the 1480 map has no Milan fortress with men in it")
		return
	WarFixture.at_war(_g, SAV, MLO)
	var i := _g.map.index_of(fort)
	assert_true(Movement.open_to(_g, SAV, fort), "the fortress is land of an enemy: open_to says yes")
	assert_eq(Movement.open_mask(_g, SAV)[i], 0, "but the mask closes it")
	var near := _own_neighbour(fort)
	if near == Movement.NO_HEX:
		pending("no Savoy hex beside the fortress")
		return
	var a := _sav(near)
	var res := Movement.plan(_g, a, fort)
	assert_true(bool(res.ok), "a march ends on the fortress: the plan adds the goal")
	assert_eq(_g.map.index_of(fort), int((res.hexes as PackedInt32Array)[-1]))


func test_planted_fault_a_fortress_without_war_is_not_closed() -> void:
	var fort := _milan_fortress()
	if fort == Movement.NO_HEX:
		pending("the 1480 map has no Milan fortress with men in it")
		return
	assert_false(Movement.closed_fortress(_g, SAV, fort), "no war: nothing is closed")
	assert_false(Movement.open_to(_g, SAV, fort), "and the land stays closed in peace")


func test_zone_of_control_beside_an_enemy_army_needs_a_war() -> void:
	var pair := _clash_pair()
	if pair.is_empty():
		pending("no clash pair on the map")
		return
	ArmyFixture.army(_g, MLO, pair[1], 0, 1, 0)
	assert_false(Movement.zoc_halts(_g, SAV, pair[0]), "in peace an enemy army beside is no zone of control")
	WarFixture.at_war(_g, SAV, MLO)
	assert_true(Movement.zoc_halts(_g, SAV, pair[0]), "at war it is")
	assert_string_contains(Movement.zoc_text(_g, SAV, pair[0]), "stands beside it")


func test_zone_of_control_beside_a_hostile_fortress() -> void:
	var fort := _milan_fortress()
	if fort == Movement.NO_HEX:
		pending("the 1480 map has no Milan fortress with men in it")
		return
	var beside := Movement.NO_HEX
	for d: int in 6:
		var n := _g.map.neighbour(fort, d)
		var j := _g.map.index_of(n)
		if j >= 0 and _g.map.land[j] == 1 and int(_g.state.owner[j]) == _country_id(SAV):
			beside = n
			break
	if beside == Movement.NO_HEX:
		pending("no Savoy hex beside the fortress")
		return
	assert_false(Movement.zoc_halts(_g, SAV, beside), "no war: no zone of control from a fortress")
	WarFixture.at_war(_g, SAV, MLO)
	assert_true(Movement.zoc_halts(_g, SAV, beside), "at war a garrisoned enemy fortress beside ends the leg")


# --- the storm order: rows, halt and the assault -----------------------------------------------------------------------------


func test_storm_check_rows_before_and_after_the_war() -> void:
	var fort := _milan_fortress()
	if fort == Movement.NO_HEX:
		pending("the 1480 map has no Milan fortress with men in it")
		return
	var beside := _own_neighbour(fort)
	if beside == Movement.NO_HEX:
		pending("no Savoy hex beside the fortress")
		return
	var a := _sav(beside)
	var args := {"army": a.id, "goal": fort, "tag": SAV}
	var plain := _own_neighbour(beside)
	assert_string_contains(str(Movement.storm_check(_g, {"army": a.id, "goal": beside, "tag": SAV}).reason), "no walls to storm")
	assert_string_contains(str(Movement.storm_check(_g, {"army": a.id, "goal": plain, "tag": SAV}).reason), "no walls to storm")
	assert_string_contains(str(Movement.storm_check(_g, args).reason), "not at war with")
	assert_false(bool(Movement.storm(_g, args).ok), "a refused storm changes nothing")
	assert_eq(a.order, Army.ORDER_NONE)
	WarFixture.at_war(_g, SAV, MLO)
	assert_true(bool(Movement.storm_check(_g, args).ok), "at war with the walls' controller the storm is ok")
	assert_true(bool(Movement.storm(_g, args).ok))
	assert_eq(a.order, Army.ORDER_STORM)
	assert_eq(a.goal, fort)
	assert_eq(a.route.size(), 1, "the route: the fortress, one step")
	Occupation.set_garrison(_g, fort, 0)
	assert_string_contains(str(Movement.storm_check(_g, args).reason), "its garrison is gone")


## 4.15: a place the country cannot see gets one refusal whatever is there (walls or none, war or none), so the reason tells
## nothing; the same fortress seen gives the real reason. The console's `storm` and `as` go through this check too.
func test_storm_check_gives_one_sentence_for_a_place_it_cannot_see() -> void:
	var start := _milan_hex()
	var a := _sav(_own_neighbour(_milan_hex()) if _own_neighbour(_milan_hex()) != Movement.NO_HEX else start)
	var fort_unseen := Movement.NO_HEX
	var plain_unseen := Movement.NO_HEX
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.land[i] != 1 or Sight.sees(_g, SAV, hex) or Territory.owner_tag(_g, hex) == SAV or Occupation.controller_tag(_g, hex) == SAV:
			continue
		if Occupation.fortress_level(_g, hex) > 0 and fort_unseen == Movement.NO_HEX:
			fort_unseen = hex
		elif Occupation.fortress_level(_g, hex) == 0 and plain_unseen == Movement.NO_HEX:
			plain_unseen = hex
	assert_ne(fort_unseen, Movement.NO_HEX, "an unseen fortress exists")
	assert_ne(plain_unseen, Movement.NO_HEX, "an unseen plain hex exists")
	var fort_said := Movement.storm_check(_g, {"army": a.id, "goal": fort_unseen, "tag": SAV})
	var plain_said := Movement.storm_check(_g, {"army": a.id, "goal": plain_unseen, "tag": SAV})
	assert_eq(str(fort_said.reason), "You cannot see that place.", "an unseen fortress")
	assert_eq(str(plain_said.reason), str(fort_said.reason), "an unseen plain hex says the same")
	WarFixture.at_war(_g, SAV, MLO)
	assert_eq(str(Movement.storm_check(_g, {"army": a.id, "goal": fort_unseen, "tag": SAV}).reason), "You cannot see that place.", "war or none")
	assert_false(bool(Movement.storm(_g, {"army": a.id, "goal": fort_unseen, "tag": SAV}).ok), "and nothing is ordered")
	assert_eq(a.order, Army.ORDER_NONE)
	var seen := _own_neighbour(a.hex)
	if seen != Movement.NO_HEX:
		assert_string_contains(str(Movement.storm_check(_g, {"army": a.id, "goal": seen, "tag": SAV}).reason), "no walls to storm", "a seen hex gives its real reason")


func test_storm_refuses_its_own_walls_and_a_shaken_army() -> void:
	var fort := _milan_fortress()
	if fort == Movement.NO_HEX:
		pending("the 1480 map has no Milan fortress with men in it")
		return
	var beside := _own_neighbour(fort)
	if beside == Movement.NO_HEX:
		pending("no Savoy hex beside the fortress")
		return
	WarFixture.at_war(_g, SAV, MLO)
	var a := _sav(beside)
	WarFixture.set_occupier(_g, fort, SAV)
	assert_string_contains(str(Movement.storm_check(_g, {"army": a.id, "goal": fort, "tag": SAV}).reason), "your own walls")
	WarFixture.set_occupier(_g, fort, MLO)
	for u: Unit in a.units:
		Armies.set_morale(_g, a, u.id, 0)
	assert_string_contains(str(Movement.storm_check(_g, {"army": a.id, "goal": fort, "tag": SAV}).reason), "too shaken to attack")
	assert_false(bool(Movement.storm(_g, {"army": a.id, "goal": fort, "tag": SAV}).ok), "a shaken army is refused the storm")
	assert_eq(a.order, Army.ORDER_NONE)


func test_raise_is_refused_on_land_held_by_an_enemy() -> void:
	var home := _home()
	assert_ne(home, Movement.NO_HEX)
	WarFixture.set_occupier(_g, home, MLO)
	assert_string_contains(str(Military.raise_check(_g, {"hex": home, "kind": 0, "count": 1, "tag": SAV}).reason),
		"held by the")
	WarFixture.set_occupier(_g, home, &"")
	assert_false(str(Military.raise_check(_g, {"hex": home, "kind": 0, "count": 1, "tag": SAV}).reason).contains("held by"),
		"planted twin: the same hex, not held, is not refused for that")


func test_a_storm_order_halts_like_a_march_and_a_second_halt_holds() -> void:
	var fort := _milan_fortress()
	if fort == Movement.NO_HEX:
		pending("the 1480 map has no Milan fortress with men in it")
		return
	var beside := _own_neighbour(fort)
	if beside == Movement.NO_HEX:
		pending("no Savoy hex beside the fortress")
		return
	WarFixture.at_war(_g, SAV, MLO)
	var a := _sav(beside)
	assert_true(bool(Movement.storm(_g, {"army": a.id, "goal": fort, "tag": SAV}).ok))
	assert_true(bool(Movement.halt(_g, {"army": a.id, "tag": SAV}).ok), "a storm halts")
	assert_eq(a.order, Army.ORDER_NONE, "as a march does: no order")
	assert_eq(a.goal, fort, "and its goal is kept")
	assert_true(bool(Movement.halt(_g, {"army": a.id, "tag": SAV}).ok), "a second halt")
	assert_eq(a.order, Army.ORDER_HOLD, "is a hold")
	assert_eq(a.goal, Movement.NO_HEX)


func test_a_storm_that_arrives_starts_an_assault() -> void:
	var fort := _milan_fortress()
	if fort == Movement.NO_HEX:
		pending("the 1480 map has no Milan fortress with men in it")
		return
	var beside := _own_neighbour(fort)
	if beside == Movement.NO_HEX:
		pending("no Savoy hex beside the fortress")
		return
	WarFixture.at_war(_g, SAV, MLO)
	var a := _sav(beside)
	assert_true(bool(Movement.storm(_g, {"army": a.id, "goal": fort, "tag": SAV}).ok))
	MovementPhase.season(_g)
	assert_eq(a.hex, fort, "the army walks onto the fortress")
	var b := Battles.at(_g, fort)
	assert_not_null(b, "and the step starts the battle: the storm")
	if b != null:
		assert_true(b.assault, "an assault")
	assert_eq(_events("battle_started").size(), 1)


# --- the standing order ------------------------------------------------------------------------------------------------------


func test_standing_check_rows() -> void:
	var a := _sav(_home())
	assert_string_contains(str(Military.standing_check(_g, {"army": a.id, "standing": "", "tag": SAV}).reason),
		"no standing order given")
	assert_string_contains(str(Military.standing_check(_g, {"army": a.id, "standing": "fight", "tag": SAV}).reason),
		"no such standing order: hold or withdraw")
	assert_string_contains(str(Military.standing_check(_g, {"army": a.id, "standing": "hold", "tag": SAV}).reason),
		"already holds when attacked")
	assert_string_contains(str(Military.standing_check(_g, {"army": a.id, "standing": "hold", "tag": ArmyFixture.TAG}).reason),
		"not your army")
	assert_true(bool(Military.standing_check(_g, {"army": a.id, "standing": "withdraw", "tag": SAV}).ok))


func test_set_standing_writes_the_army_and_refuses_the_same_order() -> void:
	var a := _sav(_home())
	assert_eq(a.standing, Army.STANDING_HOLD)
	assert_true(bool(Military.set_standing(_g, {"army": a.id, "standing": "withdraw", "tag": SAV}).ok))
	assert_eq(a.standing, Army.STANDING_WITHDRAW)
	assert_string_contains(str(Military.set_standing(_g, {"army": a.id, "standing": "withdraw", "tag": SAV}).reason),
		"already withdraws when attacked")
	assert_eq(a.standing, Army.STANDING_WITHDRAW, "a refused order changes nothing")


func test_can_stand_counts_only_the_side_own_companies() -> void:
	var pair := _clash_pair()
	if pair.is_empty():
		pending("no clash pair on the map")
		return
	ArmyFixture.army(_g, MLO, pair[1], 0, 2, 0)
	assert_ne(Military.can_stand(_g, SAV, pair[1], 1), "", "in peace another country's army stands there")
	WarFixture.at_war(_g, SAV, MLO)
	assert_eq(Military.can_stand(_g, SAV, pair[1], 1), "", "at war it is a battle hex: only Savoy's companies count")


# --- the tick: engage, shaken, determinism -----------------------------------------------------------------------------------


## The clash of north Italy: Savoy's army on its own hex, a Milan army beside it, the war declared, Savoy marching in.
func _clash() -> Dictionary:
	var pair := _clash_pair()
	if pair.is_empty():
		return {}
	WarFixture.at_war(_g, SAV, MLO)
	var a := _sav(pair[0], 2)
	ArmyFixture.army(_g, MLO, pair[1], 0, 2, 0)
	var res := Movement.march(_g, {"army": a.id, "goal": pair[1], "tag": SAV})
	assert_true(bool(res.ok), "a march to the enemy army is an attack: %s" % str(res.reason))
	return {"army": a, "hex": pair[1]}


func test_a_march_onto_an_enemy_army_engages_it_in_the_tick() -> void:
	var c := _clash()
	if c.is_empty():
		pending("no clash pair on the map")
		return
	var a: Army = c.army
	var men_before := _men_total()
	MovementPhase.season(_g)
	assert_eq(a.hex, c.hex, "the army is on the battle hex")
	assert_not_null(Battles.of_army(_g, a.id), "in a battle")
	assert_eq(_events("battle_started").size(), 1, "one battle started by the tick")
	assert_eq(_men_total(), men_before, "a walk loses no men")
	assert_eq(_events("march_halted").size(), 0, "an engaged walk halts nowhere: the battle tells it")


func test_a_marching_army_caught_in_a_battle_keeps_its_march() -> void:
	var pair := _clash_pair()
	if pair.is_empty():
		pending("no clash pair on the map")
		return
	var beyond := _own_neighbour(pair[0])
	if beyond == Movement.NO_HEX or beyond == pair[1]:
		pending("no own hex beyond the clash hex")
		return
	WarFixture.at_war(_g, SAV, MLO)
	# The Milan army has the lower id, so its step onto Savoy's marching army comes first in the tick.
	var attacker := ArmyFixture.army(_g, MLO, pair[1], 0, 2, 0)
	var defender := _sav(pair[0], 2)
	assert_true(bool(Movement.march(_g, {"army": attacker.id, "goal": pair[0], "tag": MLO}).ok))
	assert_true(bool(Movement.march(_g, {"army": defender.id, "goal": beyond, "tag": SAV}).ok))
	MovementPhase.season(_g)
	assert_not_null(Battles.of_army(_g, defender.id), "the marching army is in the battle")
	assert_eq(defender.hex, pair[0], "it does not walk out of the fight")
	assert_eq(defender.order, Army.ORDER_MARCH, "and keeps its march order")
	assert_eq(defender.goal, beyond, "and its goal")
	assert_eq(defender.halt_why, &"", "without a halt")
	for h: Dictionary in _events("march_halted"):
		assert_ne(int(h.get("army", 0)), defender.id, "no march_halted for it")


func test_planted_fault_a_shaken_army_stops_before_the_enemy() -> void:
	var c := _clash()
	if c.is_empty():
		pending("no clash pair on the map")
		return
	var a: Army = c.army
	var start := a.hex
	for u: Unit in a.units:
		Armies.set_morale(_g, a, u.id, 0)
	MovementPhase.season(_g)
	assert_eq(a.hex, start, "a shaken army does not step onto the enemy")
	assert_eq(a.halt_why, Movement.WHY_SHAKEN)
	assert_eq(_events("battle_started").size(), 0)
	var halts := _events("march_halted")
	assert_eq(halts.size(), 1)
	var halt: Dictionary = halts[0]
	assert_eq(str(halt.get("why", "")), "shaken", "march_halted says shaken")


func test_a_walk_into_a_hex_of_a_third_country_is_still_blocked() -> void:
	var pair := _clash_pair()
	if pair.is_empty():
		pending("no clash pair on the map")
		return
	# No war: a Milan army on the hex is not an attack; the march onto it is refused and the army stays where it is.
	var a := _sav(pair[0], 2)
	ArmyFixture.army(_g, MLO, pair[1], 0, 2, 0)
	var res := Movement.march(_g, {"army": a.id, "goal": pair[1], "tag": SAV})
	assert_false(bool(res.ok), "in peace the march onto another country's army is refused")
	assert_eq(a.hex, pair[0])


func test_the_same_clash_plays_the_same_twice() -> void:
	var first := _clash()
	if first.is_empty():
		pending("no clash pair on the map")
		return
	MovementPhase.season(_g)
	var digest_a := _g.digest()
	var second := ArmyFixture.game()
	var pair := _clash_pair()
	WarFixture.at_war(second, SAV, MLO)
	var a := ArmyFixture.army(second, SAV, pair[0], 0, 2, 0)
	ArmyFixture.army(second, MLO, pair[1], 0, 2, 0)
	Movement.march(second, {"army": a.id, "goal": pair[1], "tag": SAV})
	MovementPhase.season(second)
	assert_eq(second.digest(), digest_a, "the same walk gives the same state")


# --- actions ------------------------------------------------------------------------------------------------------------------


func test_storm_and_set_standing_are_actions_with_pairs() -> void:
	assert_eq(Actions.pair_of("storm").size(), 2, "storm has a check and a do")
	assert_eq(Actions.pair_of("set_standing").size(), 2, "set_standing has a check and a do")
	assert_true(Actions.NAMES.has("storm"))
	assert_true(Actions.NAMES.has("set_standing"))


# --- a halted storm resumes as a storm (not a march) ----------------------------------------------------------------------

## A storm ordered, then halted: the army stands with no order, its goal kept and the storm marker on it.
func _halted_storm() -> Dictionary:
	var fort := _milan_fortress()
	if fort == Movement.NO_HEX:
		return {}
	var beside := _own_neighbour(fort)
	if beside == Movement.NO_HEX:
		return {}
	WarFixture.at_war(_g, SAV, MLO)
	var a := _sav(beside)
	assert_true(bool(Movement.storm(_g, {"army": a.id, "goal": fort, "tag": SAV}).ok))
	assert_true(bool(Movement.halt(_g, {"army": a.id, "tag": SAV}).ok))
	return {"army": a, "fort": fort}


func test_a_halted_storm_is_marked_and_continue_resumes_the_storm() -> void:
	var c := _halted_storm()
	if c.is_empty():
		pending("no Milan fortress with men in it beside Savoy's land")
		return
	var a: Army = c.army
	var fort: Vector2i = c.fort
	assert_eq(a.halt_why, Movement.WHY_STORM, "the halt keeps the storm in the army's halt")
	assert_eq(a.order, Army.ORDER_NONE)
	assert_eq(a.goal, fort, "and its goal")
	assert_true(bool(Movement.continue_march(_g, {"army": a.id, "tag": SAV}).ok))
	assert_eq(a.order, Army.ORDER_STORM, "continue resumes the storm, not a march")
	assert_eq(a.goal, fort)
	assert_eq(a.halt_why, &"", "and clears the halt")


func test_a_halted_storm_whose_checks_fail_is_refused_with_the_reason() -> void:
	var c := _halted_storm()
	if c.is_empty():
		pending("no Milan fortress with men in it beside Savoy's land")
		return
	var a: Army = c.army
	var fort: Vector2i = c.fort
	Occupation.set_garrison(_g, fort, 0)
	var verdict := Movement.continue_march(_g, {"army": a.id, "tag": SAV})
	assert_false(bool(verdict.ok), "the storm's checks fail: the continue is refused")
	assert_string_contains(str(verdict.reason), "its garrison is gone", "with the storm's words")
	assert_eq(a.order, Army.ORDER_NONE, "and the army stays halted")
	assert_eq(a.halt_why, Movement.WHY_STORM, "still marked")


func test_a_halted_storm_survives_a_save_and_a_load() -> void:
	var c := _halted_storm()
	if c.is_empty():
		pending("no Milan fortress with men in it beside Savoy's land")
		return
	var a: Army = c.army
	var fort: Vector2i = c.fort
	# The snapshot round trip the saves use (Snapshot.of, the file's bytes, Snapshot.restore).
	var body := bytes_to_var(var_to_bytes(Snapshot.of(_g))) as Dictionary
	var back := Snapshot.restore(body, _g.map, _g.defs)["game"] as Game
	assert_not_null(back)
	var loaded := Armies.by_id(back, a.id)
	assert_not_null(loaded)
	assert_eq(loaded.halt_why, Movement.WHY_STORM, "the marker survives the save")
	assert_eq(loaded.goal, fort)
	assert_true(bool(Movement.continue_march(back, {"army": a.id, "tag": SAV}).ok))
	assert_eq(loaded.order, Army.ORDER_STORM, "and after the load continue resumes the storm")
	assert_true(back.digest() != "", "the resumed game has a digest")
