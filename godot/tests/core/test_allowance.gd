## The move allowance (core/systems/allowance.gd; docs/architecture/moves-build-spec.md 3.1, R12 to R16, D3, D14, 8.1): the full
## points by the slowest company, the refill in the ready_units phase, split, merge, disband and raise (R15), the clamps (R14) and
## the invariant. Planted faults are marked P. Nothing spends points yet (the walks come with MV4): these tests set them with
## ArmyFixture.spent.
extends GutTest

const PIKEMEN := 0
const KNIGHTS := 2
const BOMBARDS := 3

var _g: Game
var _hex: Vector2i
var _tag: StringName = ArmyFixture.TAG


func before_each() -> void:
	_g = ArmyFixture.game()
	_hex = ArmyFixture.find_town(_g)
	ArmyFixture.town(_g, _hex, 5, 20000)
	ArmyFixture.rich(_g)


func _split_off(army: Army, unit_index: int) -> Army:
	var verdict := _g.act("split_army", {"army": army.id, "units": PackedInt32Array([army.units[unit_index].id]), "tag": _tag})
	assert_true(bool(verdict["ok"]), str(verdict["reason"]))
	return Armies.by_id(_g, int(verdict["army"]))


func test_full_is_the_slowest_company() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	assert_eq(Allowance.full(_g, a), 12, "pikemen 12")
	Armies.add_units(_g, a, KNIGHTS, 1, _g.turn - 1, _hex, 0, {})
	assert_eq(Allowance.full(_g, a), 12, "knights (16) do not speed up the pikemen")
	Armies.add_units(_g, a, BOMBARDS, 1, _g.turn - 1, _hex, 0, {})
	assert_eq(Allowance.full(_g, a), 8, "a bombard (8) slows the army")
	assert_eq(Allowance.full(_g, ArmyFixture.army(_g, _tag, _hex, KNIGHTS, 1)), 16)
	assert_eq(Allowance.full(_g, Army.new()), 0, "no company, no points")


func test_a_new_army_is_fresh_and_a_spent_one_is_not() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	assert_true(Allowance.fresh(_g, a), "a new army has its full points")
	assert_eq(Allowance.left(a), 12)
	ArmyFixture.spent(_g, a, 11)
	assert_false(Allowance.fresh(_g, a), "one point spent")
	ArmyFixture.spent(_g, a, 0)
	assert_false(Allowance.fresh(_g, a), "0 is never fresh")
	assert_false(Allowance.fresh(_g, Army.new()), "an army with no company is not fresh")


func test_refill_gives_every_army_its_full_in_the_ready_units_phase() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	var b := ArmyFixture.army(_g, _tag, _hex, BOMBARDS, 1)
	var foreign := ArmyFixture.army(_g, ArmyFixture.other_tag(_g), _hex + Vector2i(2, 0), KNIGHTS, 1)
	ArmyFixture.spent(_g, a, 3)
	ArmyFixture.spent(_g, b, 0)
	ArmyFixture.spent(_g, foreign, 1)
	Allowance.refill(_g)
	assert_eq([a.points, b.points, foreign.points], [12, 8, 16], "every army, its own full")
	ArmyFixture.spent(_g, a, 3)
	Season.run_phase(_g, &"ready_units")
	assert_eq(a.points, 12, "the season's ready_units phase refills (R13)")


func test_p_no_other_phase_refills() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	ArmyFixture.spent(_g, a, 2)
	for phase: StringName in Season.PHASES:
		if phase != &"ready_units":
			Season.run_phase(_g, phase)
	assert_eq(a.points, 2, "P: points that grow outside ready_units")


func test_the_actions_that_are_not_moves_never_give_points() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 2)
	ArmyFixture.spent(_g, a, 5)
	assert_true(bool(_g.act("set_standing", {"army": a.id, "standing": "withdraw", "tag": _tag})["ok"]))
	assert_eq(a.points, 5, "P: points that grow inside an action")


# ----- the clamps (R14) -------------------------------------------------------------------------------------------------------


func test_set_points_clamps_and_check_names_the_army_that_breaks_the_range() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	Armies.set_points(_g, a, 50)
	assert_eq(a.points, 12)
	Armies.set_points(_g, a, -4)
	assert_eq(a.points, 0)
	assert_eq(Allowance.check(_g), PackedStringArray(), "a sound game says nothing")
	a.points = 13  # the planted fault: a writer that did not clamp
	var lines := Allowance.check(_g)
	assert_eq(lines.size(), 1, "P: points above the full are reported")
	assert_true(lines[0].begins_with("army %d " % a.id), lines[0])
	a.points = -1
	assert_eq(Allowance.check(_g).size(), 1, "P: points below 0 are reported")


func test_check_follows_the_slowest_company() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	Armies.add_units(_g, a, BOMBARDS, 1, _g.turn - 1, _hex, 0, {})  # the full is now 8 but the points are still 12
	assert_eq(Allowance.check(_g).size(), 1, "the army holds more than its slowest company allows")
	Armies.set_points(_g, a, 12)
	assert_eq(a.points, 8)
	assert_eq(Allowance.check(_g).size(), 0)


# ----- split, merge, disband (R15, D14) -----------------------------------------------------------------------------------------


func test_split_gives_both_armies_the_parents_points_cut_to_their_full() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 2)
	Armies.add_units(_g, a, BOMBARDS, 1, _g.turn - 1, _hex, 0, {})
	Armies.set_points(_g, a, 8)
	var guns := _split_off(a, 2)
	assert_eq([guns.points, a.points], [8, 8], "a fresh parent: the bombard army keeps 8, the pikemen get no more than 8")
	assert_true(Allowance.fresh(_g, guns))
	assert_false(Allowance.fresh(_g, a), "the pikemen (full 12) now hold 8: not fresh")
	var b := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	Armies.add_units(_g, b, KNIGHTS, 1, _g.turn - 1, _hex, 0, {})
	ArmyFixture.spent(_g, b, 5)
	var horse := _split_off(b, 1)
	assert_eq([horse.points, b.points], [5, 5], "a spent parent: both have 5, not their full")


func test_p_split_then_merge_never_gives_more_points() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	Armies.add_units(_g, a, KNIGHTS, 1, _g.turn - 1, _hex, 0, {})
	ArmyFixture.spent(_g, a, 3)
	var horse := _split_off(a, 1)
	var verdict := _g.act("merge_armies", {"army": horse.id, "into": a.id, "tag": _tag})
	assert_true(bool(verdict["ok"]), str(verdict["reason"]))
	assert_eq(a.points, 3, "P: split then merge that gives more points than either army had")
	assert_null(Armies.by_id(_g, horse.id))


func test_merge_takes_the_lower_of_the_two_cut_to_the_new_full() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	var b := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	ArmyFixture.spent(_g, a, 10)
	ArmyFixture.spent(_g, b, 6)
	assert_true(bool(_g.act("merge_armies", {"army": a.id, "into": b.id, "tag": _tag})["ok"]))
	assert_eq(b.points, 6, "the lower of 10 and 6")
	var c := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	var guns := ArmyFixture.army(_g, _tag, _hex, BOMBARDS, 1)
	assert_true(bool(_g.act("merge_armies", {"army": guns.id, "into": c.id, "tag": _tag})["ok"]))
	assert_eq(c.points, 8, "two fresh armies merge to 12 and 8: the lower, which is also the new full")
	assert_true(Allowance.fresh(_g, c))
	var d := ArmyFixture.army(_g, _tag, _hex, KNIGHTS, 1)
	var e := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	ArmyFixture.spent(_g, e, 12)
	assert_true(bool(_g.act("merge_armies", {"army": d.id, "into": e.id, "tag": _tag})["ok"]))
	assert_eq(e.points, 12, "the knights' 16 never lifts the pikemen's 12")


func test_disband_cuts_the_points_to_the_new_full_and_never_raises_them() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	Armies.add_units(_g, a, BOMBARDS, 1, _g.turn - 1, _hex, 0, {})
	Armies.set_points(_g, a, 8)
	var pikes := a.units[0].id
	assert_true(bool(_g.act("disband", {"army": a.id, "unit": a.units[1].id, "tag": _tag})["ok"]))
	assert_eq(Allowance.full(_g, a), 12, "without the bombard the full is 12")
	assert_eq(a.points, 8, "P: dropping the slow company must not raise the points (D3: what is left, not what was spent)")
	assert_false(Allowance.fresh(_g, a))
	var b := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	Armies.add_units(_g, b, KNIGHTS, 1, _g.turn - 1, _hex, 0, {})
	ArmyFixture.spent(_g, b, 12)
	assert_true(bool(_g.act("disband", {"army": b.id, "unit": b.units[0].id, "tag": _tag})["ok"]))
	assert_eq(Allowance.full(_g, b), 16)
	assert_eq(b.points, 12, "the knights alone could walk 16, the army has 12 left")
	assert_eq(pikes, a.units[0].id)


# ----- raise (R15) ----------------------------------------------------------------------------------------------------------


func _raise(kind: int) -> Army:
	var verdict := _g.act("raise", {"hex": _hex, "kind": kind, "count": 1, "tag": _tag})
	assert_true(bool(verdict["ok"]), str(verdict["reason"]))
	return Armies.by_id(_g, int(verdict["army"]))


func test_a_raise_makes_a_new_army_with_its_full_points() -> void:
	var a := _raise(PIKEMEN)
	assert_eq(a.points, 12)
	assert_true(Allowance.fresh(_g, a))


func test_a_raise_joins_a_fresh_army_and_the_points_follow_the_slowest_company() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	var joined := _raise(BOMBARDS)
	assert_same(joined, a, "the army is fresh and does not march: the company joins it")
	assert_eq(a.points, 8, "the full is 8 with a bombard in it, and it is still fresh")
	assert_true(Allowance.fresh(_g, a))
	assert_eq(_g.armies.size(), 1)


func test_p_a_raise_never_joins_an_army_that_has_walked() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	ArmyFixture.spent(_g, a, 11)
	var fresh_army := _raise(PIKEMEN)
	assert_ne(fresh_army.id, a.id, "P: a raise into an army that has walked")
	assert_eq(a.points, 11, "the spent army is not touched")
	assert_eq(fresh_army.points, 12)
	var b := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	ArmyFixture.spent(_g, b, 0)
	assert_ne(_raise(PIKEMEN).id, b.id, "an army with no points left is not joined either")


func test_a_raise_does_not_join_a_marching_army() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, PIKEMEN, 1)
	Armies.set_order(_g, a, Army.ORDER_MARCH, _hex, PackedInt32Array([_g.map.index_of(_hex)]))
	assert_ne(_raise(PIKEMEN).id, a.id, "a marching army is not joined (M6), fresh or not")


func test_the_scenarios_start_armies_have_their_full_points() -> void:
	var d := ArmyFixture.defs()
	var sc := d.scenarios[d.scenarios.size() - 1].duplicate(true) as ScenarioDef
	var plain := Game.new_scenario(EconomyFixture.map(), d, sc, EconomyFixture.SEED)
	var hex := AiFixture.land_hex(plain, AiFixture.GENOA)
	sc.start_armies = [
		{"tag": AiFixture.GENOA, "hex": hex, "kind": 1, "count": 1},
		{"tag": AiFixture.GENOA, "hex": hex, "kind": BOMBARDS, "count": 1},
	] as Array[Dictionary]
	var g := Game.new_scenario(EconomyFixture.map(), d, sc, EconomyFixture.SEED)
	assert_eq(g.armies.size(), 1, "the two entries join one fresh army")
	assert_eq(g.armies[0].points, 8, "a start army is fresh: its full, cut by the bombard")
	assert_true(Allowance.fresh(g, g.armies[0]))
	assert_eq(Allowance.check(g).size(), 0)
