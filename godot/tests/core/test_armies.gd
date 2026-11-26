## The armies' door (core/systems/armies.gd; docs/architecture/m6-build-spec.md 5.0 R2, R11, A6, 5.3, 9): ids and the sorted lists,
## add and remove, the proportional loss (A6) with unit_lost, the setters, the save body (to_dict, from_dict with every
## refusal of R11) and the digest.
extends GutTest

var _g: Game
var _hex: Vector2i


func before_each() -> void:
	_g = ArmyFixture.game()
	_hex = ArmyFixture.find_town(_g)


func _sea_hex() -> Vector2i:
	for i: int in _g.map.hex_count():
		if not _g.map.is_land(_g.map.hex_of(i)):
			return _g.map.hex_of(i)
	return ArmyFixture.NO_HEX


## A valid saved body of one army of TAG with two companies of pikemen.
func _body() -> Dictionary:
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 2)
	Armies.set_order(_g, a, Army.ORDER_HOLD, ArmyFixture.NO_HEX, PackedInt32Array())
	return Armies.to_dict(_g)


## Refused, and the game's armies untouched by the refusal.
func _refused(d: Dictionary) -> void:
	var before := Armies.digest(_g)
	var problem := Armies.from_dict(d, _g)
	assert_eq(problem, Armies.PROBLEM_BODY)
	assert_eq(Armies.digest(_g), before, "a refused body changes nothing")


# ----- ids, sorted lists, lookups --------------------------------------------------------------------------------------


func test_ids_grow_from_one_and_are_never_reused() -> void:
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 1)
	var b := ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 1)
	assert_eq([a.id, b.id], [1, 2])
	Armies.remove(_g, a)
	var c := ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 1)
	assert_eq(c.id, 3, "a removed id is not used again")
	assert_eq(_g.next_army_id, 4)
	assert_eq(_g.next_unit_id, 4, "one company each for a, b and c: unit ids 1 to 3, the next is 4")


func test_by_id_is_a_binary_search_over_the_sorted_list() -> void:
	var made: Array[Army] = []
	for _n: int in 9:
		made.append(ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 1))
	Armies.remove(_g, made[4])
	for a: Army in made:
		if a == made[4]:
			assert_null(Armies.by_id(_g, a.id))
		else:
			assert_eq(Armies.by_id(_g, a.id), a)
	assert_null(Armies.by_id(_g, 0))
	assert_null(Armies.by_id(_g, 99))
	var ids: Array[int] = []
	for a: Army in _g.armies:
		ids.append(a.id)
	var sorted := ids.duplicate()
	sorted.sort()
	assert_eq(ids, sorted, "the list stays in id order")
	assert_eq(ids.size(), 8)


func test_lookups_by_country_hex_and_leaving() -> void:
	var mine := ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 2)
	var other := ArmyFixture.army(_g, ArmyFixture.other_tag(_g), _hex, 0, 1)
	ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 1, 3)
	assert_eq(Armies.of_country(_g, ArmyFixture.TAG).size(), 2)
	assert_eq(Armies.at(_g, _hex).size(), 3, "every country's armies on the hex, in id order")
	assert_eq(Armies.units_at(_g, ArmyFixture.TAG, _hex), 5)
	assert_eq(Armies.units_at(_g, ArmyFixture.TAG, _hex, PackedInt32Array([mine.id])), 3, "leaving drops an army")
	assert_eq(Armies.units_at(_g, ArmyFixture.other_tag(_g), _hex), 1)
	assert_eq(other.id, 2)
	assert_eq(Armies.men_of_country(_g, ArmyFixture.TAG), 5 * 500)


# ----- units -----------------------------------------------------------------------------------------------------------


func test_add_units_gives_full_men_and_the_raising_facts() -> void:
	var a := Armies.create(_g, ArmyFixture.TAG, _hex, "Army of test")
	var ids := Armies.add_units(_g, a, 2, 2, 7, _hex, 120, {"iron": 1, "horses": 3})
	assert_eq(ids.size(), 2)
	assert_eq(a.units.size(), 2)
	var u := a.units[0]
	assert_eq([u.kind, u.men, u.raised_turn, u.paid], [2, 250, 7, 120])
	assert_eq(u.paid_goods, {"iron": 1, "horses": 3})
	assert_eq(u.home, _hex)
	assert_true(a.units[1].id > a.units[0].id, "units in id order")
	assert_eq(Armies.add_units(_g, a, 9, 1, 7, _hex, 0, {}).size(), 0, "an unknown kind adds nothing")
	assert_eq(Armies.add_units(_g, a, 0, 0, 7, _hex, 0, {}).size(), 0, "a count under 1 adds nothing")


func test_move_and_remove_units_keep_both_lists_sorted() -> void:
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 3)
	var b := ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 1)
	var first := a.units[0].id
	var last := a.units[2].id
	Armies.move_units(_g, a, b, PackedInt32Array([first]))
	assert_eq(a.units.size(), 2)
	assert_eq(b.units.size(), 2)
	assert_true(b.units[0].id < b.units[1].id, "the receiving army stays sorted")
	assert_eq(b.units[0].id, first)
	var gone := Armies.remove_units(_g, a, PackedInt32Array([last, 999]))
	assert_eq(gone.size(), 1, "an id the army does not hold is skipped")
	assert_eq(a.units.size(), 1)


func test_add_men_is_capped_at_full_strength() -> void:
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 1)
	var u := a.units[0]
	u.men = 400
	assert_eq(Armies.add_men(_g, a, u.id, 300), 100, "capped at the kind's 500")
	assert_eq(u.men, 500)
	assert_eq(Armies.add_men(_g, a, u.id, 10), 0, "a full company takes nothing")
	assert_eq(Armies.add_men(_g, a, 999, 10), 0, "an unknown company takes nothing")


# ----- losses (A6) ----------------------------------------------------------------------------------------------------


func test_losses_split_in_proportion_and_remove_the_empty() -> void:
	var a := Armies.create(_g, ArmyFixture.TAG, _hex, "Army of test")
	Armies.add_units(_g, a, 0, 1, 1, _hex, 0, {})
	Armies.add_units(_g, a, 0, 1, 1, _hex, 0, {})
	a.units[1].men = 250
	var lost := Armies.lose_men(_g, a, 75, &"starved")
	assert_eq(lost, 75)
	assert_eq(a.units[0].men, 500 - 50, "floor(75 x 500 / 750) = 50")
	assert_eq(a.units[1].men, 250 - 25, "floor(75 x 250 / 750) = 25")
	assert_eq(_g.events.filter(func(e: Dictionary) -> bool: return e["kind"] == "unit_lost").size(), 0)


func test_the_remainder_goes_one_man_each_in_id_order_and_a_company_at_zero_is_lost() -> void:
	var a := Armies.create(_g, ArmyFixture.TAG, _hex, "Army of test")
	Armies.add_units(_g, a, 0, 3, 1, _hex, 0, {})
	for u: Unit in a.units:
		u.men = 1
	var lost := Armies.lose_men(_g, a, 2, &"starved")
	assert_eq(lost, 2)
	assert_eq(a.units.size(), 1, "the two companies at 0 are removed")
	assert_eq(a.units[0].men, 1)
	var losses := _g.events.filter(func(e: Dictionary) -> bool: return e["kind"] == "unit_lost")
	assert_eq(losses.size(), 2)
	assert_eq(losses[0]["army_left"], 2, "units left after the first removal")
	assert_eq(losses[1]["army_left"], 1)
	assert_eq(losses[0]["why"], &"starved")


func test_an_army_with_no_company_left_is_removed() -> void:
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 1)
	a.units[0].men = 3
	var id := a.id
	assert_eq(Armies.lose_men(_g, a, 99, &"starved"), 3, "cut to the army's men")
	assert_null(Armies.by_id(_g, id))
	assert_eq(_g.armies.size(), 0)


# ----- setters ---------------------------------------------------------------------------------------------------------


func test_setters_write_their_fields_and_copy_the_route() -> void:
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 1)
	var route := PackedInt32Array([4, 5])
	Armies.set_order(_g, a, Army.ORDER_MARCH, Vector2i(1, 1), route)
	route[0] = 99
	assert_eq(a.route, PackedInt32Array([4, 5]), "the stored route is a copy")
	assert_eq([a.order, a.goal], [Army.ORDER_MARCH, Vector2i(1, 1)])
	# moves in the month (R40): set_hex keeps where the army set out in season_from; close_season (ready_units) gives moved_from.
	Armies.set_hex(_g, a, Vector2i(2, 2), _hex)
	Armies.set_hex(_g, a, Vector2i(2, 3), Vector2i(2, 2))
	assert_eq([a.hex, a.season_from, a.moved_from], [Vector2i(2, 3), _hex, Army.NO_HEX], "the first move of the season is kept")
	Armies.close_season(_g)
	assert_eq([a.moved_from, a.season_from], [_hex, Army.NO_HEX], "close_season: moved_from for the report, season_from cleared")
	Armies.close_season(_g)
	assert_eq(a.moved_from, Army.NO_HEX, "a season with no move")
	Armies.set_halt(_g, a, &"blocked", "the pass is shut")
	Armies.set_waiting(_g, a, &"winter")
	Armies.set_supply(_g, a, 2, 40)
	Armies.set_route(_g, a, PackedInt32Array([7]))
	assert_eq([a.halt_why, a.halt_text, a.waiting, a.supply, a.lost_last, a.route],
		[&"blocked", "the pass is shut", &"winter", 2, 40, PackedInt32Array([7])])


# ----- the save body ---------------------------------------------------------------------------------------------------


func test_round_trip_through_json_gives_the_same_digest() -> void:
	ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 2)
	ArmyFixture.army(_g, ArmyFixture.other_tag(_g), _hex, 3, 1)
	var a := _g.armies[0]
	Armies.set_order(_g, a, Army.ORDER_MARCH, _hex, PackedInt32Array([_g.map.index_of(_hex)]))
	var digest := Armies.digest(_g)
	var text := JSON.stringify(Armies.to_dict(_g))
	var d: Dictionary = JSON.parse_string(text)
	_g.armies = []
	assert_eq(Armies.from_dict(d, _g), "", "a saved body reads back")
	assert_eq(Armies.digest(_g), digest, "the digest is the same after a round trip")
	assert_eq(_g.next_army_id, 3)


func test_digest_moves_with_every_field() -> void:
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 1)
	var base := Armies.digest(_g)
	a.units[0].men -= 1
	assert_ne(Armies.digest(_g), base, "men")
	a.units[0].men += 1
	Armies.set_supply(_g, a, 1, 0)
	assert_ne(Armies.digest(_g), base, "supply")
	Armies.set_supply(_g, a, 0, 0)
	assert_eq(Armies.digest(_g), base)
	ArmyFixture.spent(_g, a, 5)
	assert_ne(Armies.digest(_g), base, "points (army/3, R56)")
	ArmyFixture.spent(_g, a, Allowance.full(_g, a))
	a.season_from = _hex  # the test sets it: its writer comes with the walks
	assert_ne(Armies.digest(_g), base, "season_from (army/3, R56)")


func test_set_points_clamps_to_zero_and_the_full() -> void:
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 1)
	assert_eq(a.points, 12, "a new army has its full points (pikemen: 12)")
	Armies.set_points(_g, a, 7)
	assert_eq(a.points, 7)
	Armies.set_points(_g, a, -3)
	assert_eq(a.points, 0, "never below 0 (R14)")
	Armies.set_points(_g, a, 99)
	assert_eq(a.points, 12, "never above the full (R14)")


func test_points_and_season_from_round_trip_through_json() -> void:
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 2)
	ArmyFixture.spent(_g, a, 5)
	a.season_from = _hex
	var digest := Armies.digest(_g)
	var d: Dictionary = JSON.parse_string(JSON.stringify(Armies.to_dict(_g)))
	_g.armies = []
	assert_eq(Armies.from_dict(d, _g), "")
	assert_eq(_g.armies[0].points, 5)
	assert_eq(_g.armies[0].season_from, _hex)
	assert_eq(Armies.digest(_g), digest)


func test_a_good_body_is_accepted() -> void:
	var d := _body()
	_g.armies = []
	assert_eq(Armies.from_dict(d, _g), "")
	assert_eq(_g.armies.size(), 1)


func test_refuses_a_wrong_schema_and_a_bad_counter() -> void:
	var d := _body()
	d["schema"] = "hexa-godot/armies/9"
	_refused(d)
	d = _body()
	d["next_army_id"] = 0
	_refused(d)
	d = _body()
	d["list"] = "x"
	_refused(d)


func test_refuses_a_duplicate_or_unsorted_army_id_and_an_id_at_the_counter() -> void:
	var d := _body()
	var list: Array = d["list"]
	list.append((list[0] as Dictionary).duplicate(true))
	_refused(d)
	d = _body()
	d["next_army_id"] = 1
	_refused(d)
	d = _body()
	(d["list"][0] as Dictionary)["id"] = 0
	_refused(d)


func test_refuses_a_duplicate_unit_id() -> void:
	var d := _body()
	var units: Array = d["list"][0]["units"]
	units[1]["id"] = units[0]["id"]
	_refused(d)


func test_refuses_a_tag_that_is_no_country() -> void:
	var d := _body()
	d["list"][0]["tag"] = "ZZZ"
	_refused(d)


func test_refuses_a_hex_off_the_map_or_at_sea() -> void:
	var d := _body()
	d["list"][0]["hex"] = [-3, 2]
	_refused(d)
	var sea := _sea_hex()
	if sea != ArmyFixture.NO_HEX:
		d = _body()
		d["list"][0]["hex"] = [sea.x, sea.y]
		_refused(d)


func test_refuses_a_kind_out_of_range_and_men_outside_one_to_full() -> void:
	var d := _body()
	d["list"][0]["units"][0]["kind"] = 4
	_refused(d)
	d = _body()
	d["list"][0]["units"][0]["men"] = 0
	_refused(d)
	d = _body()
	d["list"][0]["units"][0]["men"] = 501
	_refused(d)


func test_p_refuses_points_above_the_full_and_a_season_from_off_the_map() -> void:
	var d := _body()
	d["list"][0]["points"] = 12
	assert_eq(Armies.from_dict(d, _g), "", "the full itself is fine")
	d = _body()
	d["list"][0]["points"] = 13
	_refused(d)
	d = _body()
	d["list"][0]["points"] = -1
	_refused(d)
	d = _body()
	d["list"][0]["points"] = "12"
	_refused(d)
	d = _body()
	(d["list"][0] as Dictionary).erase("points")
	_refused(d)
	d = _body()
	d["list"][0]["season_from"] = [-3, 2]
	_refused(d)
	d = _body()
	d["list"][0]["season_from"] = [4294967299, 2]
	_refused(d)
	d = _body()
	d["list"][0]["season_from"] = [ArmyFixture.NO_HEX.x, ArmyFixture.NO_HEX.y]
	assert_eq(Armies.from_dict(d, _g), "", "no hex is the empty value")


func test_refuses_points_above_the_full_of_a_slow_company() -> void:
	# the full is the slowest company's: a bombard (8) in the army cuts it
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, _hex, 0, 1)
	Armies.add_units(_g, a, 3, 1, _g.turn - 1, _hex, 0, {})
	Armies.set_points(_g, a, Allowance.full(_g, a))
	var d := Armies.to_dict(_g)
	d["list"][0]["points"] = 9
	_refused(d)


func test_refuses_an_empty_army() -> void:
	var d := _body()
	d["list"][0]["units"] = []
	_refused(d)


func test_refuses_a_route_index_off_the_map_and_a_march_goal_off_the_map() -> void:
	var d := _body()
	d["list"][0]["route"] = [_g.map.hex_count()]
	_refused(d)
	d = _body()
	d["list"][0]["route"] = [-1]
	_refused(d)
	d = _body()
	d["list"][0]["order"] = "march"
	d["list"][0]["goal"] = [-5, 0]
	_refused(d)


func test_refuses_a_coordinate_outside_32_bits() -> void:
	var d := _body()
	d["list"][0]["hex"] = [4294967299, 2]
	_refused(d)


func test_refuses_an_unknown_order() -> void:
	var d := _body()
	d["list"][0]["order"] = "fly"
	_refused(d)


func test_refuses_a_float_coordinate_beyond_53_bits_and_the_lowest_integer() -> void:
	var d := _body()
	d["list"][0]["hex"] = [1e300, 2]
	_refused(d)
	d = _body()
	d["list"][0]["route"] = [1e300]
	_refused(d)
	var lowest: int = -9223372036854775807 - 1
	d = _body()
	d["list"][0]["hex"] = [lowest, 2]
	_refused(d)
	d = _body()
	d["list"][0]["units"][0]["home"] = [0, 1e300]
	_refused(d)


func test_unit_whole_refuses_floats_it_cannot_hold_exactly() -> void:
	assert_null(Unit.whole(1e300), "1e300 is not a count")
	assert_null(Unit.whole(9007199254740994.0), "past 2^53 a float is not exact")
	assert_null(Unit.whole(NAN))
	assert_eq(Unit.whole(4.0), 4)
	assert_eq(Unit.whole(9007199254740992.0), 9007199254740992, "2^53 itself is still exact")
	assert_null(Unit.whole(2.5))
