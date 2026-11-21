## Unit and Army state (core/state/unit.gd, army.gd; docs/architecture/m6-build-spec.md 5.2, 9): round trips, the digest
## text, mustering and the refusals of a bad dict.
extends GutTest


func _unit(id: int) -> Unit:
	var u := Unit.new()
	u.id = id
	u.kind = 2
	u.men = 40 + id
	u.home = Vector2i(5, 9)
	u.raised_turn = 3
	u.paid = 120
	u.paid_goods = {"grain": 2, "horses": 1}
	return u


func _army() -> Army:
	var a := Army.new()
	a.id = 4
	a.tag = &"SAV"
	a.name = "First Army of Turin"
	a.hex = Vector2i(5, 9)
	a.units.append(_unit(1))
	a.units.append(_unit(3))
	a.order = Army.ORDER_MARCH
	a.goal = Vector2i(7, 8)
	a.route = PackedInt32Array([501, 502, 640])
	a.waiting = &"winter"
	a.halt_why = &"blocked"
	a.halt_text = "No way"
	a.moved_from = Vector2i(4, 9)
	a.supply = 1
	a.lost_last = 3
	a.created_turn = 3
	return a


func test_unit_round_trip_in_both_forms() -> void:
	var src := _unit(7)
	for form: int in 2:
		var d := src.to_dict()
		var back: Unit
		if form == 0:
			back = Unit.from_dict(JSON.parse_string(JSON.stringify(d)) as Dictionary)
		else:
			back = Unit.from_dict(bytes_to_var(var_to_bytes(d)) as Dictionary)
		assert_not_null(back, "form %d" % form)
		assert_eq(back.digest_text(), src.digest_text())
		assert_eq(back.home, Vector2i(5, 9))
		assert_eq(back.paid_goods, src.paid_goods)
		assert_eq(var_to_bytes(back.to_dict()), var_to_bytes(d), "save, load, save equal")


func test_unit_digest_text_and_each_field() -> void:
	var u := _unit(1)
	var first := "horses:1,grain:2" if GoodDef.KEYS.find(&"horses") < GoodDef.KEYS.find(&"grain") else "grain:2,horses:1"
	assert_eq(u.digest_text(), "1|2|41|5,9|3|120|" + first, "goods in good id order, not insertion order")
	var base := u.digest_text()
	var edits: Array[Callable] = [
		func(x: Unit) -> void: x.id += 1,
		func(x: Unit) -> void: x.kind += 1,
		func(x: Unit) -> void: x.men -= 1,
		func(x: Unit) -> void: x.home = Vector2i(5, 10),
		func(x: Unit) -> void: x.raised_turn += 1,
		func(x: Unit) -> void: x.paid += 1,
		func(x: Unit) -> void: x.paid_goods["grain"] = 3,
		func(x: Unit) -> void: x.paid_goods.erase("horses"),
	]
	var seen := {base: true}
	for edit: Callable in edits:
		var x := _unit(1)
		edit.call(x)
		assert_false(seen.has(x.digest_text()), "one field moves the digest")
		seen[x.digest_text()] = true


func test_unit_refusals() -> void:
	var good := _unit(1).to_dict()
	assert_not_null(Unit.from_dict(good))
	var wrong := good.duplicate()
	wrong["schema"] = "hexa-godot/unit/2"
	assert_null(Unit.from_dict(wrong), "P: a wrong schema")
	var text := good.duplicate()
	text["men"] = "40"
	assert_null(Unit.from_dict(text), "P: a string for men")
	var missing := good.duplicate()
	missing.erase("kind")
	assert_null(Unit.from_dict(missing), "P: a dict missing kind")
	var frac := good.duplicate()
	frac["men"] = 4.5
	assert_null(Unit.from_dict(frac))
	var neg := good.duplicate()
	neg["paid"] = -1
	assert_null(Unit.from_dict(neg))
	var bad_good := good.duplicate(true)
	bad_good["paid_goods"] = {"unobtainium": 1}
	assert_null(Unit.from_dict(bad_good), "an unknown good")
	var bad_home := good.duplicate()
	bad_home["home"] = [1]
	assert_null(Unit.from_dict(bad_home))
	assert_null(Unit.from_dict({}))


func test_army_round_trip_in_both_forms() -> void:
	var src := _army()
	for form: int in 2:
		var d := src.to_dict()
		var back: Army
		if form == 0:
			back = Army.from_dict(JSON.parse_string(JSON.stringify(d)) as Dictionary)
		else:
			back = Army.from_dict(bytes_to_var(var_to_bytes(d)) as Dictionary)
		assert_not_null(back, "form %d" % form)
		assert_eq(back.digest_text(), src.digest_text())
		assert_eq(back.route, src.route)
		assert_eq(typeof(back.tag), TYPE_STRING_NAME)
		assert_eq(back.units.size(), 2)
		assert_eq(back.units[1].id, 3)
		assert_eq(back.goal, Vector2i(7, 8))
		assert_eq(back.moved_from, Vector2i(4, 9))
		assert_eq(var_to_bytes(back.to_dict()), var_to_bytes(d), "save, load, save equal")
	assert_true(src.to_dict()["route"] is PackedInt32Array, "the route stays packed")
	assert_true(src.to_dict()["tag"] is String, "plain: a StringName goes out as text")


func test_army_defaults_round_trip() -> void:
	var a := Army.new()
	a.id = 1
	var back := Army.from_dict(a.to_dict())
	assert_not_null(back)
	assert_eq(back.hex, Army.NO_HEX)
	assert_eq(back.order, Army.ORDER_NONE)
	assert_eq(back.digest_text(), a.digest_text())


func test_army_digest_moves_with_every_field() -> void:
	var base := _army().digest_text()
	var edits: Array[Callable] = [
		func(x: Army) -> void: x.id += 1,
		func(x: Army) -> void: x.tag = &"GEN",
		func(x: Army) -> void: x.name = "Other",
		func(x: Army) -> void: x.hex = Vector2i(5, 10),
		func(x: Army) -> void: x.created_turn += 1,
		func(x: Army) -> void: x.order = Army.ORDER_HOLD,
		func(x: Army) -> void: x.goal = Vector2i(7, 9),
		func(x: Army) -> void: x.route[1] += 1,
		func(x: Army) -> void: x.route = PackedInt32Array([501, 502]),
		func(x: Army) -> void: x.waiting = &"",
		func(x: Army) -> void: x.halt_why = &"no_way",
		func(x: Army) -> void: x.halt_text = "Other",
		func(x: Army) -> void: x.moved_from = Army.NO_HEX,
		func(x: Army) -> void: x.supply = 2,
		func(x: Army) -> void: x.lost_last += 1,
		func(x: Army) -> void: x.units[0].men += 1,
		func(x: Army) -> void: x.units[1].paid_goods["grain"] = 9,
		func(x: Army) -> void: x.units.remove_at(1),
		func(x: Army) -> void: x.units.append(_unit(5)),
	]
	var seen := {base: true}
	for edit: Callable in edits:
		var x := _army()
		edit.call(x)
		assert_false(seen.has(x.digest_text()), "one change moves the digest")
		seen[x.digest_text()] = true
	assert_eq(_army().digest_text(), base, "the same army, the same text")
	assert_true(base.begins_with("4|SAV|First Army of Turin|5,9|3|march|7,8|501,502,640|winter|blocked|No way|4,9|1|3|"))
	assert_true(base.ends_with(_army().units[1].digest_text()))


func test_men_unit_and_mustering() -> void:
	var a := _army()
	assert_eq(a.men(), 41 + 43)
	assert_eq(a.unit(3).men, 43)
	assert_null(a.unit(2), "not in it")
	assert_true(a.mustering(3))
	assert_false(a.mustering(4))
	assert_false(a.mustering(2))
	a.units[0].raised_turn = 4
	assert_true(a.mustering(4), "any one unit raised that turn")
	assert_true(a.mustering(3))
	assert_false(Army.new().mustering(0), "an empty army musters nothing")
	assert_eq(Army.new().men(), 0)


func test_army_refusals() -> void:
	var good := _army().to_dict()
	assert_not_null(Army.from_dict(good))
	var wrong := good.duplicate()
	wrong["schema"] = "hexa-godot/army/2"
	assert_null(Army.from_dict(wrong), "P: a wrong schema")
	var str_id := good.duplicate()
	str_id["id"] = "4"
	assert_null(Army.from_dict(str_id), "P: a string for id")
	var bad_hex := good.duplicate()
	bad_hex["hex"] = "5,9"
	assert_null(Army.from_dict(bad_hex), "P: a string for hex")
	var bad_route := good.duplicate()
	bad_route["route"] = ["a"]
	assert_null(Army.from_dict(bad_route), "P: a route of the wrong type")
	var bad_order := good.duplicate()
	bad_order["order"] = "charge"
	assert_null(Army.from_dict(bad_order), "an order not one of the three")
	var bad_supply := good.duplicate()
	bad_supply["supply"] = 3
	assert_null(Army.from_dict(bad_supply))
	var no_text := good.duplicate()
	no_text["halt_text"] = 5
	assert_null(Army.from_dict(no_text))
	var no_units := good.duplicate()
	no_units["units"] = "x"
	assert_null(Army.from_dict(no_units))
	var bad_unit := good.duplicate(true)
	var first: Dictionary = (bad_unit["units"] as Array)[0]
	first.erase("kind")
	assert_null(Army.from_dict(bad_unit), "P: a unit dict missing kind")
	var string_men := good.duplicate(true)
	var second: Dictionary = (string_men["units"] as Array)[1]
	second["men"] = "40"
	assert_null(Army.from_dict(string_men), "P: a string for a unit's men")
	var dup := good.duplicate(true)
	var twin: Dictionary = (dup["units"] as Array)[1]
	twin["id"] = 1
	assert_null(Army.from_dict(dup), "P: a duplicate unit id")
	var unsorted := good.duplicate(true)
	(unsorted["units"] as Array).reverse()
	assert_null(Army.from_dict(unsorted), "units stay in id order")
	assert_null(Army.from_dict({}))
