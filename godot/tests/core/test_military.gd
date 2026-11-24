## Military (core/systems/military.gd; docs/architecture/m6-build-spec.md 4.5, 4.6, 4.9, 5.0 A3 to A8, A10, A15, 9): every row of
## the raise, disband, split and merge check tables with its words, the raise's payments and levy order, the joining rule,
## the refund rule, the names with ordinals, the room of a hex, the refill and the upkeep, on a game this test builds.
extends GutTest

var _g: Game
var _hex: Vector2i
var _tag: StringName = ArmyFixture.TAG


func before_each() -> void:
	_g = ArmyFixture.game()
	_hex = ArmyFixture.find_town(_g)
	ArmyFixture.town(_g, _hex, 5, 20000)
	ArmyFixture.rich(_g)


## The raise arguments on `hex` (the test's town when null).
func _args(kind: int, count: int = 1, hex: Variant = null) -> Dictionary:
	var at: Vector2i = _hex if hex == null else hex
	return {"hex": at, "kind": kind, "count": count, "tag": _tag}


## The first land hex of `tag` for which `wanted` holds on the game (a test's search, not a rule).
func _hex_where(tag: StringName, wanted: Callable) -> Vector2i:
	var owner := ArmyFixture.id_of(_g, tag)
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.is_land(hex) and int(_g.state.owner[i]) == owner and wanted.call(i):
			return hex
	return ArmyFixture.NO_HEX


func _iron() -> int:
	return _g.defs.good_id(&"iron")


func _stock(good: int) -> int:
	return Countries.by_tag(_g, _tag).stock[good]


func _treasury() -> int:
	return Countries.by_tag(_g, _tag).treasury


func _people(hex: Vector2i) -> int:
	return _g.state.people[_g.map.index_of(hex)]


func _events(kind: String) -> Array:
	return _g.events.filter(func(e: Dictionary) -> bool: return e["kind"] == kind)


# ----- definitions and numbers -----------------------------------------------------------------------------------------


func test_cost_and_upkeep_of_a_company() -> void:
	var cost := Military.cost_of(_g, 0, 3)
	assert_eq(cost["ducats"], 75)
	assert_eq(cost["goods"], {"iron": 3})
	var knights := Military.cost_of(_g, 2, 1)
	assert_eq(knights["goods"], {"iron": 1, "horses": 3})
	var a := ArmyFixture.army(_g, _tag, _hex, 0, 1)
	assert_eq(Military.upkeep_of(_g, a), 6, "a full pikeman: 6 ducats")
	a.units[0].men = 250
	assert_eq(Military.upkeep_of(_g, a), 3, "ceil(6 x 250 / 500) = 3")
	ArmyFixture.army(_g, _tag, _hex, 2, 2)
	assert_eq(Military.upkeep_country(_g, _tag), 3 + 20, "the country's upkeep is its armies' sum")


func test_stack_limit_and_the_raise_cap_of_a_settlement() -> void:
	assert_eq(Military.stack_limit(_g, _tag), 8)
	assert_eq(Military.raise_cap(_g, _hex), 4, "a city raises 4 a season (level 5)")
	ArmyFixture.town(_g, _hex, 3)
	assert_eq(Military.raise_cap(_g, _hex), 2, "a town raises 2")
	assert_eq(Military.raise_cap(_g, ArmyFixture.NO_HEX), 0, "off the map raises nothing")


func test_raise_options_lists_every_kind_with_its_verdict() -> void:
	var rows := Military.raise_options(_g, _tag, _hex)
	assert_eq(rows.size(), 4)
	assert_eq(rows[0]["name"], "Pikemen")
	assert_eq(rows[0]["men"], 500)
	assert_true(str(rows[0]["cost_text"]).begins_with("25 · "))
	assert_true(bool(rows[0]["verdict"]["ok"]))


func test_hex_text_names_a_hex_with_its_coordinates() -> void:
	assert_true(Military.hex_text(_g, _hex).ends_with("(%d, %d)" % [_hex.x, _hex.y]))


# ----- raising: the verdicts -------------------------------------------------------------------------------------------


func test_raise_check_refuses_in_the_table_order() -> void:
	assert_eq(Military.raise_check(_g, {"kind": 0, "tag": _tag}), {"ok": false, "reason": "no hex given"})
	assert_eq(Military.raise_check(_g, {"hex": _hex, "tag": _tag}), {"ok": false, "reason": "no kind given"})
	assert_eq(Military.raise_check(_g, _args(0, 0))["reason"], "count the companies: 1 or more")
	var sandbox := Game.new_game(EconomyFixture.map(), 1, ArmyFixture.defs())
	assert_eq(Military.raise_check(sandbox, {"hex": _hex, "kind": 0, "count": 1})["reason"], "the sandbox has no armies")
	var foreign := _hex_where(ArmyFixture.other_tag(_g), func(_i: int) -> bool: return true)
	var foreign_reason := str(Military.raise_check(_g, _args(0, 1, foreign))["reason"])
	assert_true(foreign_reason.begins_with("not your land: the "), "%s at %s" % [foreign_reason, foreign])
	var plain := _hex_where(_tag, func(i: int) -> bool: return int(_g.state.main_use[i]) == 0)
	assert_eq(Military.raise_check(_g, _args(0, 1, plain))["reason"],
		"companies are raised in towns and villages: no settlement here")
	assert_eq(Military.raise_check(_g, _args(9))["reason"], "no such kind of company")
	ArmyFixture.town(_g, _hex, 1)
	assert_eq(Military.raise_check(_g, _args(2))["reason"], "Knights are raised in a village or larger")
	assert_eq(Military.raise_check(_g, _args(0))["ok"], true)


func test_raise_cap_per_season_and_its_words() -> void:
	ArmyFixture.town(_g, _hex, 3)
	assert_true(bool(Military.raise_check(_g, _args(1, 2))["ok"]), "two of a cap of two")
	Military.raise(_g, _args(1, 1))
	assert_eq(Military.raise_check(_g, _args(1, 2))["reason"],
		"%s can raise 1 more company this season" % Military.hex_text(_g, _hex))
	Military.raise(_g, _args(1, 1))
	assert_eq(Military.raise_check(_g, _args(1, 1))["reason"],
		"%s has raised its 2 companies this season" % Military.hex_text(_g, _hex))


func test_room_on_the_hex_refuses_by_can_stand_words() -> void:
	ArmyFixture.army(_g, _tag, _hex, 0, 8, _g.turn - 1)
	assert_eq(Military.raise_check(_g, _args(0))["reason"],
		"no room at %s: 9 of 8 companies" % Military.hex_text(_g, _hex))


func test_another_countrys_army_on_the_hex_refuses() -> void:
	ArmyFixture.army(_g, ArmyFixture.other_tag(_g), _hex, 0, 1)
	assert_eq(Military.raise_check(_g, _args(0))["reason"],
		"another country's army stands at %s" % Military.hex_text(_g, _hex))


func test_men_at_hand_counts_the_hex_and_its_ring_held_by_the_country() -> void:
	ArmyFixture.people_at(_g, _hex, 0)
	for d: int in 6:
		ArmyFixture.people_at(_g, ImproveRules.neighbour(_hex, d), 0)
	assert_eq(Military.men_at_hand(_g, _tag, _hex), 0)
	assert_eq(Military.raise_check(_g, _args(0))["reason"], "only 0 men can be raised here this season: 500 are needed")
	ArmyFixture.people_at(_g, ImproveRules.neighbour(_hex, 3), 20000)
	assert_eq(Military.men_at_hand(_g, _tag, _hex), 2000, "a ring hex held by the country counts")


func test_ducats_and_goods_refuse_in_their_words() -> void:
	Countries.by_tag(_g, _tag).treasury = 10
	assert_eq(Military.raise_check(_g, _args(0))["reason"], "not enough ducats: 25 needed, 10 in the treasury")
	ArmyFixture.rich(_g)
	Countries.by_tag(_g, _tag).stock[_iron()] = 0
	assert_eq(Military.raise_check(_g, _args(0))["reason"], "not enough iron: 1 needed, 0 in store")


# ----- raising: the action ----------------------------------------------------------------------------------------------


func test_raise_pays_levies_and_forms_a_new_army() -> void:
	var ducats := _treasury()
	var iron := _stock(_iron())
	var men := _people(_hex)
	var verdict := Military.raise(_g, _args(0, 2))
	assert_eq(verdict["ok"], true)
	assert_eq(_treasury(), ducats - 50)
	assert_eq(_stock(_iron()), iron - 2)
	assert_eq(_people(_hex), men - 1000, "the men are levied from the hex")
	assert_eq(Armies.of_country(_g, _tag).size(), 1)
	var a := Armies.of_country(_g, _tag)[0]
	assert_eq(a.hex, _hex)
	assert_eq(a.order, Army.ORDER_NONE)
	assert_eq(a.units.size(), 2)
	assert_eq(a.units[0].men, 500)
	assert_eq(a.units[0].raised_turn, _g.turn)
	assert_eq(a.units[0].paid, 25)
	assert_eq(a.units[0].paid_goods, {"iron": 1})
	var raised := _events("army_raised")
	assert_eq(raised.size(), 1)
	assert_eq([raised[0]["count"], raised[0]["men"], raised[0]["ducats"]], [2, 1000, 50])


func test_raise_takes_men_from_the_ring_when_the_hex_has_too_few() -> void:
	ArmyFixture.people_at(_g, _hex, 0)
	var n := ImproveRules.neighbour(_hex, 0)
	ArmyFixture.people_at(_g, n, 20000)
	assert_eq(Military.raise(_g, _args(0))["ok"], true)
	assert_eq(_people(n), 20000 - 500, "the first ring hex in direction order gives the men")
	assert_eq(_people(_hex), 0)


func test_raise_joins_the_first_army_that_does_not_march() -> void:
	Military.raise(_g, _args(0))
	var first := Armies.of_country(_g, _tag)[0]
	Military.raise(_g, _args(0))
	assert_eq(Armies.of_country(_g, _tag).size(), 1, "joins the army on the hex")
	assert_eq(first.units.size(), 2)
	Armies.set_order(_g, first, Army.ORDER_MARCH, _hex, PackedInt32Array())
	Military.raise(_g, _args(0))
	assert_eq(Armies.of_country(_g, _tag).size(), 2, "a marching army is not joined")
	assert_eq(Armies.of_country(_g, _tag)[1].units.size(), 1, "the new army holds the company")


func test_a_raise_that_passes_the_check_changes_no_other_country() -> void:
	var other := ArmyFixture.other_tag(_g)
	var before := Countries.by_id(_g, ArmyFixture.id_of(_g, other)).treasury
	Military.raise(_g, _args(0))
	assert_eq(Countries.by_id(_g, ArmyFixture.id_of(_g, other)).treasury, before)


func test_raise_through_the_door_is_refused_when_the_check_refuses() -> void:
	Countries.by_tag(_g, _tag).treasury = 0
	var res := _g.act("raise", _args(0))
	assert_eq(res["ok"], false)
	assert_eq(Armies.of_country(_g, _tag).size(), 0)


# ----- names -----------------------------------------------------------------------------------------------------------


func test_army_names_run_in_ordinals_and_then_numbers() -> void:
	var base := Military.army_name(_g, _tag, _hex)
	assert_true(base.begins_with("Army of "), base)
	var names: Array[String] = []
	for _n: int in 12:
		var fresh := Military.army_name(_g, _tag, _hex)
		names.append(fresh)
		Armies.create(_g, _tag, _hex, fresh)
	assert_eq(names[0], base)
	assert_eq(names[1], "Second " + base)
	assert_eq(names[8], "Ninth " + base)
	assert_eq(names[9], "Tenth " + base)
	assert_eq(names[10], "11th " + base)
	assert_eq(names[11], "12th " + base)


func test_a_name_is_the_army_of_its_place_or_its_country() -> void:
	var name := Military.army_name(_g, _tag, _hex)
	assert_true(name.begins_with("Army of "), name)
	assert_true(name.length() > "Army of ".length(), "a place or a country name follows")


# ----- disbanding ------------------------------------------------------------------------------------------------------


func test_disband_refunds_a_company_raised_this_season_and_returns_its_men() -> void:
	Military.raise(_g, _args(0))
	var a := Armies.of_country(_g, _tag)[0]
	var ducats := _treasury()
	var iron := _stock(_iron())
	var men := _people(_hex)
	var verdict := Military.disband(_g, {"army": a.id, "unit": -1, "tag": _tag})
	assert_eq(verdict["ok"], true)
	assert_eq(_treasury(), ducats + 25, "the company's 25 ducats come back")
	assert_eq(_stock(_iron()), iron + 1)
	assert_eq(_people(_hex), men + 500, "the men go home")
	assert_null(Armies.by_id(_g, a.id))
	var gone := _events("army_disbanded")
	assert_eq(gone.size(), 1)
	assert_eq([gone[0]["men"], gone[0]["refund"]], [500, 25])


func test_disband_gives_no_refund_for_an_older_company() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, 0, 1, _g.turn - 1)
	var ducats := _treasury()
	var men := _people(_hex)
	Military.disband(_g, {"army": a.id, "unit": a.units[0].id, "tag": _tag})
	assert_eq(_treasury(), ducats, "no refund")
	assert_eq(_people(_hex), men + 500, "its men still go home")


func test_disband_refusals_in_their_words() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, 0, 1)
	assert_eq(Military.disband_check(_g, {"tag": _tag})["reason"], "no army given")
	assert_eq(Military.disband_check(_g, {"army": 999, "tag": _tag})["reason"], "no army 999")
	# R23, R32: the army's country is named only when the actor sees the army's hex; this hex is not in the other
	# country's sight, so the refusal names no one.
	assert_true(str(Military.disband_check(_g, {"army": a.id, "tag": ArmyFixture.other_tag(_g)})["reason"]).begins_with(
		"not your army: another country commands it"))
	assert_eq(Military.disband_check(_g, {"army": a.id, "unit": 999, "tag": _tag})["reason"],
		"company 999 is not in the Army of test")
	var foreign := _hex_where(ArmyFixture.other_tag(_g), func(_i: int) -> bool: return true)
	Armies.set_hex(_g, a, foreign, Army.NO_HEX)
	assert_eq(Military.disband_check(_g, {"army": a.id, "tag": _tag})["reason"],
		"disband only in your own land: (%d, %d) is not yours" % [foreign.x, foreign.y])


func test_disband_refuses_when_neither_home_nor_the_army_can_take_the_men() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, 0, 1)
	ArmyFixture.people_at(_g, _hex, People.PEOPLE_MAX)
	assert_eq(Military.disband_check(_g, {"army": a.id, "tag": _tag})["reason"],
		"no room for 500 people at %s" % Military.hex_text(_g, _hex))
	assert_not_null(Armies.by_id(_g, a.id), "a refused disband changes nothing")


func test_a_set_of_companies_is_one_action_that_takes_them_all() -> void:
	var a := Armies.create(_g, _tag, _hex, "Army of test")
	Armies.add_units(_g, a, 0, 1, _g.turn, _hex, 25, {})
	Armies.add_units(_g, a, 0, 1, _g.turn - 1, _hex, 0, {})
	var ducats := _treasury()
	var men := _people(_hex)
	var ids := PackedInt32Array([a.units[0].id, a.units[1].id])
	var verdict := _g.act("disband", {"army": a.id, "units": ids, "tag": _tag})
	assert_eq(verdict["ok"], true, "the set is one action")
	assert_null(Armies.by_id(_g, a.id), "both companies are gone")
	assert_eq(_treasury(), ducats + 25, "the company raised this season is refunded; the older one gives nothing")
	assert_eq(_people(_hex), men + 1000, "both companies' men go home")
	var gone := _events("army_disbanded")
	assert_eq(gone.size(), 1, "one event for the set")
	assert_eq((gone[0]["units"] as Array).size(), 2)


func test_two_companies_with_room_for_one_refuse_as_a_whole_and_change_nothing() -> void:
	var a := Armies.create(_g, _tag, _hex, "Army of test")
	Armies.add_units(_g, a, 0, 2, _g.turn - 1, _hex, 0, {})
	var first := a.units[0]
	var second := a.units[1]
	ArmyFixture.people_at(_g, _hex, People.PEOPLE_MAX - first.men)
	var ids := PackedInt32Array([first.id, second.id])
	var digest := Armies.digest(_g)
	var people := _people(_hex)
	assert_eq(Military.disband_check(_g, {"army": a.id, "units": ids, "tag": _tag})["reason"],
		"no room for %d people at %s" % [second.men, Military.hex_text(_g, _hex)],
		"the second company finds no room once the first has taken its place")
	var verdict := _g.act("disband", {"army": a.id, "units": ids, "tag": _tag})
	assert_eq(verdict["ok"], false, "P: a set that cannot all go is refused by the act too")
	assert_eq(Armies.by_id(_g, a.id).units.size(), 2, "no company is gone: never half a disband")
	assert_eq(_people(_hex), people, "no man moved")
	assert_eq(Armies.digest(_g), digest, "the army changed nothing")
	assert_true(_events("army_disbanded").is_empty(), "no disband event")
	assert_true(bool(Military.disband_check(_g, {"army": a.id, "unit": first.id, "tag": _tag})["ok"]),
		"one of them alone is fine: it is the pair that fails")


func test_a_set_names_each_company_it_cannot_find_and_an_empty_set_none() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, 0, 1)
	assert_eq(Military.disband_check(_g, {"army": a.id, "units": PackedInt32Array([999]), "tag": _tag})["reason"],
		"company 999 is not in the Army of test")
	assert_eq(Military.disband_check(_g, {"army": a.id, "units": PackedInt32Array(), "tag": _tag})["reason"],
		"no companies given")
	assert_eq(Military.disband_check(_g, {"army": a.id, "units": PackedInt32Array([a.units[0].id, a.units[0].id]), "tag": _tag})["ok"],
		true, "a repeated id is one company")


# ----- splitting and merging -------------------------------------------------------------------------------------------


func test_split_makes_a_hold_army_on_the_same_hex() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, 0, 3)
	var keep := a.units[1].id
	var give := a.units[0].id
	var verdict := Military.split_army(_g, {"army": a.id, "units": PackedInt32Array([give]), "tag": _tag})
	assert_eq(verdict["ok"], true)
	var fresh := Armies.by_id(_g, int(verdict["army"]))
	assert_eq(fresh.hex, _hex)
	assert_eq(fresh.order, Army.ORDER_HOLD)
	assert_eq(fresh.units.size(), 1)
	assert_eq(fresh.units[0].id, give)
	assert_eq(a.units.size(), 2)
	assert_eq(a.units[0].id, keep)
	assert_eq(_events("army_changed").size(), 2)


func test_split_refusals_in_their_words() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, 0, 2)
	assert_eq(Military.split_check(_g, {"army": a.id, "units": PackedInt32Array(), "tag": _tag})["reason"],
		"no companies given")
	assert_eq(Military.split_check(_g, {"army": a.id, "units": PackedInt32Array([999]), "tag": _tag})["reason"],
		"company 999 is not in the Army of test")
	var all := PackedInt32Array([a.units[0].id, a.units[1].id])
	assert_eq(Military.split_check(_g, {"army": a.id, "units": all, "tag": _tag})["reason"],
		"a split must leave at least one company behind")
	assert_eq(Military.split_check(_g, {"units": all, "tag": _tag})["reason"], "no army given")


func test_merge_joins_every_company_and_keeps_the_target_order() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, 0, 1)
	var b := ArmyFixture.army(_g, _tag, _hex, 0, 2)
	Armies.set_order(_g, b, Army.ORDER_HOLD, Army.NO_HEX, PackedInt32Array())
	var verdict := Military.merge_armies(_g, {"army": a.id, "into": b.id, "tag": _tag})
	assert_eq(verdict["ok"], true)
	assert_null(Armies.by_id(_g, a.id))
	assert_eq(b.units.size(), 3)
	assert_true(b.units[0].id < b.units[1].id and b.units[1].id < b.units[2].id, "sorted by id")
	assert_eq(b.order, Army.ORDER_HOLD)
	var changed := _events("army_changed")
	assert_eq(changed.size(), 2)
	assert_eq(changed[0]["gone"], true)


func test_merge_refusals_in_their_words() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, 0, 1)
	var b := ArmyFixture.army(_g, _tag, _hex, 0, 1)
	assert_eq(Military.merge_check(_g, {"army": a.id, "into": a.id, "tag": _tag})["reason"],
		"an army cannot join itself")
	assert_eq(Military.merge_check(_g, {"army": a.id, "into": 999, "tag": _tag})["reason"], "no army 999")
	assert_eq(Military.merge_check(_g, {"into": b.id, "tag": _tag})["reason"], "no army given")
	var away := ArmyFixture.army(_g, _tag, _hex + Vector2i(1, 0), 0, 1)
	assert_eq(Military.merge_check(_g, {"army": a.id, "into": away.id, "tag": _tag})["reason"],
		"the armies stand on different hexes")


# ----- room and refill ---------------------------------------------------------------------------------------------------


func test_can_stand_counts_only_the_armies_that_stay() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, 0, 8)
	assert_ne(Military.can_stand(_g, _tag, _hex, 1), "")
	assert_eq(Military.can_stand(_g, _tag, _hex, 1, PackedInt32Array([a.id])), "")


func test_refill_takes_the_missing_men_from_the_hex_when_supplied() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, 0, 1)
	a.units[0].men = 300
	a.supply = 0
	var men := _people(_hex)
	Military.refill(_g)
	assert_eq(a.units[0].men, 350, "at most UnitDef.refill (50) a season")
	assert_eq(_people(_hex), men - 50)
	assert_eq(_events("army_changed").size(), 1)


func test_refill_skips_an_army_out_of_supply_or_on_foreign_land() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, 0, 1)
	a.units[0].men = 300
	a.supply = 2
	Military.refill(_g)
	assert_eq(a.units[0].men, 300)
	a.supply = 0
	var foreign := _hex_where(ArmyFixture.other_tag(_g), func(_i: int) -> bool: return true)
	Armies.set_hex(_g, a, foreign, Army.NO_HEX)
	Military.refill(_g)
	assert_eq(a.units[0].men, 300, "a country's land only")


func test_refill_stops_at_full_strength() -> void:
	var a := ArmyFixture.army(_g, _tag, _hex, 0, 1)
	a.units[0].men = 490
	Military.refill(_g)
	assert_eq(a.units[0].men, 500)


func test_a_raise_the_books_cannot_hold_is_refused_in_the_check() -> void:
	var c := Countries.by_tag(_g, _tag)
	var slot := Stores.FLOWS.find(&"raise") * c.stock.size() + _iron()
	c.flows_open[slot] = -Stores.LIMIT
	assert_eq(Military.raise_check(_g, _args(0))["reason"], "the stores cannot take that spending")
	assert_eq(Military.raise(_g, _args(0))["ok"], false, "the action refuses too, and moves nothing")
	assert_eq(Armies.of_country(_g, _tag).size(), 0)
	assert_eq(c.flows_open[slot], -Stores.LIMIT)


func test_a_refund_the_treasury_cannot_hold_is_refused_before_anything_moves() -> void:
	Military.raise(_g, _args(0))
	var a := Armies.of_country(_g, _tag)[0]
	var c := Countries.by_tag(_g, _tag)
	c.treasury = Treasury.LIMIT
	var men := _people(_hex)
	assert_eq(Military.disband_check(_g, {"army": a.id, "tag": _tag})["reason"], "the treasury cannot take that refund")
	assert_eq(Military.disband(_g, {"army": a.id, "tag": _tag})["ok"], false)
	assert_not_null(Armies.by_id(_g, a.id), "a refused disband keeps the army")
	assert_eq(_people(_hex), men, "and the men stay where they are")


func test_a_raise_is_one_ledger_line_with_its_count() -> void:
	Military.raise(_g, _args(0, 2))
	var lines := Countries.by_tag(_g, _tag).ledger_open
	var raised: Array = lines.filter(func(line: Dictionary) -> bool: return line["why"] == &"raise")
	assert_eq(raised.size(), 1)
	assert_eq([raised[0]["count"], raised[0]["amount"]], [2, -50], "two companies, 50 ducats, one line")


# ----- the scenario's starting armies (M8 5.3, D30) ---------------------------------------------------------------------------


const MILAN := &"MLO"


## The land hex of Milan where a levy can find the most men on the game `g` (a test's search, not a rule).
func _levy_hex(g: Game) -> Vector2i:
	var best := ArmyFixture.NO_HEX
	var most := -1
	for i: int in AiKnow.land_of(g, MILAN):
		var hex := g.map.hex_of(i)
		var here := Military.men_at_hand(g, MILAN, hex)
		if g.map.is_land(hex) and here > most:
			most = here
			best = hex
	return best


## A game on a copy of the 1480 scenario whose start_armies is `list`; the definitions are the test's own copies.
func _started(list: Array[Dictionary]) -> Game:
	var d := ArmyFixture.defs()
	var s := d.scenarios[d.scenarios.size() - 1].duplicate(true) as ScenarioDef
	s.start_armies = list
	return Game.new_scenario(EconomyFixture.map(), d, s, EconomyFixture.SEED)


func test_a_start_list_raises_its_armies_through_the_door_with_their_men_levied() -> void:
	var plain := _started([] as Array[Dictionary])
	var hex := _levy_hex(plain)
	var elsewhere := AiFixture.land_hex(plain, AiFixture.GENOA)
	var list: Array[Dictionary] = [
		{"tag": MILAN, "hex": hex, "kind": 0, "count": 1},
		{"tag": MILAN, "hex": hex, "kind": 2, "count": 1},
		{"tag": AiFixture.GENOA, "hex": elsewhere, "kind": 1, "count": 2},
	]
	var g := _started(list)
	assert_eq(g.armies.size(), 2, "the two entries on one hex join one army; Genoa's is another")
	var milan := Armies.of_country(g, MILAN)
	assert_eq(milan.size(), 1)
	assert_eq(milan[0].hex, hex)
	assert_eq(milan[0].units.size(), 2)
	assert_eq(milan[0].men(), g.defs.unit_def(0).men + g.defs.unit_def(2).men, "every company at full men")
	for u: Unit in milan[0].units:
		assert_eq([u.raised_turn, u.paid, u.home], [0, 0, hex], "raised at turn 0, paid nothing, home the hex")
		assert_true(u.paid_goods.is_empty())
	var genoa := Armies.of_country(g, AiFixture.GENOA)[0]
	assert_eq([genoa.hex, genoa.units.size(), genoa.men()], [elsewhere, 2, 2 * g.defs.unit_def(1).men])
	assert_ne(milan[0].name, "")
	assert_eq(g.events.filter(func(e: Dictionary) -> bool: return e["kind"] == "army_raised").size(), 0, "no event for a start")
	assert_ne(Armies.digest(g), Armies.digest(plain))


func test_the_men_of_a_start_army_are_levied_from_the_hex_and_its_ring() -> void:
	var plain := _started([] as Array[Dictionary])
	var hex := _levy_hex(plain)
	var before := 0
	var spots: Array[Vector2i] = [hex]
	for d: int in 6:
		spots.append(ImproveRules.neighbour(hex, d))
	for spot: Vector2i in spots:
		var i := plain.map.index_of(spot)
		if i >= 0:
			before += plain.state.people[i]
	var g := _started([{"tag": MILAN, "hex": hex, "kind": 0, "count": 1}] as Array[Dictionary])
	var after := 0
	for spot: Vector2i in spots:
		var i := g.map.index_of(spot)
		if i >= 0:
			after += g.state.people[i]
	assert_eq(before - after, g.defs.unit_def(0).men, "the company's men, no more, left the people")
	var flows := Countries.by_tag(g, MILAN).people_flows
	assert_eq(flows[People.FLOWS.find(&"raised")], -g.defs.unit_def(0).men, "booked as the flow raised")


func test_1480s_empty_list_changes_nothing() -> void:
	var g := _started([] as Array[Dictionary])
	assert_eq(g.armies.size(), 0)
	assert_eq([g.next_army_id, g.next_unit_id], [1, 1])
	var reference := EconomyFixture.game()
	var same := _started([] as Array[Dictionary])
	assert_eq(same.digest(), reference.digest(), "the game of an empty list is the game 1480 always was")
	assert_eq(reference.armies.size(), 0)


func test_p_an_entry_the_game_cannot_raise_is_skipped_and_changes_nothing() -> void:
	var plain := _started([] as Array[Dictionary])
	var hex := _levy_hex(plain)
	var list: Array[Dictionary] = [
		{"tag": &"XXX", "hex": hex, "kind": 0, "count": 1},
		{"tag": MILAN, "hex": hex, "kind": 9, "count": 1},
		{"tag": MILAN, "hex": hex, "kind": 0, "count": 0},
		{"tag": MILAN, "kind": 0, "count": 1},
	]
	var g := _started(list)
	assert_eq(g.armies.size(), 0, "an unknown tag, kind, count or a missing hex raises nothing")
	assert_eq(g.digest(), plain.digest())
