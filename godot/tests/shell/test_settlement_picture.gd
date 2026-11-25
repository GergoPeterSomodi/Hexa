## Tests for the settlement picture (docs/architecture/tilewin-build-spec.md R28, R29; TW8): recipe cases per kind,
## harbour level, castle level and snow; same input same recipe; planted faults (a walled town without a wall, a port
## without masts, a comparison that must notice a nudged point); tokens only; the Control draws headless.
extends GutTest

const KIND_CASES: Array[Array] = [
	[&"hamlet", 1], [&"village", 1], [&"town", 1], [&"walled_town", 1], [&"city", 1],
	[&"castle", 1], [&"castle", 2], [&"castle", 3],
]
const OWNER := Tokens.LAPIS


class RecordingPicture extends SettlementPicture:
	var polygons: int = 0
	var lines: int = 0
	var max_x: float = 0.0
	var max_y: float = 0.0

	func _paint_polygon(pts: PackedVector2Array, col: Color) -> void:
		polygons += 1
		for p: Vector2 in pts:
			max_x = maxf(max_x, p.x)
			max_y = maxf(max_y, p.y)
		super._paint_polygon(pts, col)

	func _paint_line(a: Vector2, b: Vector2, col: Color) -> void:
		lines += 1
		super._paint_line(a, b, col)


func _count(rec: Array[Dictionary], part: StringName) -> int:
	var n := 0
	for s: Dictionary in rec:
		if s["part"] == part:
			n += 1
	return n


## Bodies drawn as two-tone pairs (a house, a chapel, a tower): one body is two shapes of its part.
func _bodies(rec: Array[Dictionary], part: StringName) -> int:
	return floori(float(_count(rec, part)) / 2.0)


func _without(rec: Array[Dictionary], part: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in rec:
		if s["part"] != part:
			out.append(s)
	return out


func _same(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	return var_to_str(a) == var_to_str(b)


func _nudged(rec: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = rec.duplicate(true)
	var pts: PackedVector2Array = out[0]["points"]
	pts[0] = pts[0] + Vector2(0.5, 0.0)
	out[0]["points"] = pts
	return out


func test_same_input_same_recipe_for_every_case() -> void:
	for case: Array in KIND_CASES:
		for hb: int in 4:
			for snow: bool in [false, true]:
				var a := SettlementPicture.recipe(case[0], case[1], hb, snow, OWNER)
				var b := SettlementPicture.recipe(case[0], case[1], hb, snow, OWNER)
				assert_true(_same(a, b), "%s %d harbour %d snow %s: two calls match" % [case[0], case[1], hb, snow])


func test_planted_fault_a_changed_point_is_noticed() -> void:
	# Planted fault: a recipe that differs by half a pixel between two calls must fail the comparison.
	var rec := SettlementPicture.recipe(&"town", 1, 2, true, OWNER)
	assert_false(_same(rec, _nudged(rec)), "a nudged point is caught by the comparison")


func test_different_inputs_give_different_recipes() -> void:
	var base := SettlementPicture.recipe(&"town", 1, 0, false, OWNER)
	assert_false(_same(base, SettlementPicture.recipe(&"town", 1, 1, false, OWNER)), "harbour changes the recipe")
	assert_false(_same(base, SettlementPicture.recipe(&"town", 1, 0, true, OWNER)), "snow changes the recipe")
	assert_false(_same(base, SettlementPicture.recipe(&"village", 1, 0, false, OWNER)), "kind changes the recipe")
	var c1 := SettlementPicture.recipe(&"castle", 1, 0, false, OWNER)
	var c2 := SettlementPicture.recipe(&"castle", 2, 0, false, OWNER)
	var c3 := SettlementPicture.recipe(&"castle", 3, 0, false, OWNER)
	assert_false(_same(c1, c2), "castle 1 and 2 differ")
	assert_false(_same(c2, c3), "castle 2 and 3 differ")


func test_house_counts_per_kind() -> void:
	assert_between(_bodies(SettlementPicture.recipe(&"hamlet", 1, 0, false, OWNER), &"house"), 2, 3, "hamlet 2 to 3 houses")
	assert_between(_bodies(SettlementPicture.recipe(&"village", 1, 0, false, OWNER), &"house"), 4, 5, "village 4 to 5 houses")
	assert_between(_bodies(SettlementPicture.recipe(&"town", 1, 0, false, OWNER), &"house"), 6, 8, "town 6 to 8 houses")


func test_village_has_chapel_town_has_church_tower() -> void:
	assert_eq(_bodies(SettlementPicture.recipe(&"village", 1, 0, false, OWNER), &"chapel"), 1, "village has a chapel")
	assert_gt(_bodies(SettlementPicture.recipe(&"town", 1, 0, false, OWNER), &"tower"), 0, "town has a church tower")


func test_walled_town_has_its_wall_planted_fault() -> void:
	var walled := SettlementPicture.recipe(&"walled_town", 1, 0, false, OWNER)
	assert_gt(_count(walled, &"wall"), 0, "walled town has a wall")
	assert_gt(_count(walled, &"gate"), 0, "walled town has a gate")
	# Planted fault: without its wall the walled town must fail the check.
	assert_eq(_count(_without(walled, &"wall"), &"wall"), 0, "a walled town without its wall is caught")
	assert_eq(_count(SettlementPicture.recipe(&"town", 1, 0, false, OWNER), &"wall"), 0, "an open town has no wall")


func test_city_has_four_towers_and_a_cathedral() -> void:
	var city := SettlementPicture.recipe(&"city", 1, 0, false, OWNER)
	assert_gte(_count(city, &"tower"), 4, "city has four towers")
	assert_gt(_count(city, &"cathedral"), 0, "city has a cathedral")
	assert_gt(_count(city, &"wall"), 0, "city has walls")


func test_castle_levels_add_their_parts() -> void:
	var c1 := SettlementPicture.recipe(&"castle", 1, 0, false, OWNER)
	var c2 := SettlementPicture.recipe(&"castle", 2, 0, false, OWNER)
	var c3 := SettlementPicture.recipe(&"castle", 3, 0, false, OWNER)
	assert_eq(_count(c1, &"keep"), 0, "watchtower has no keep")
	assert_eq(_bodies(c1, &"tower"), 1, "watchtower is one tower")
	assert_gt(_count(c2, &"keep"), 0, "castle has a keep")
	assert_gt(_count(c2, &"wall"), 0, "castle has a curtain wall")
	assert_gte(_count(c3, &"bastion"), 2, "fortress has bastions")
	assert_gte(_count(c3, &"tower"), 4, "fortress has four or more towers")
	assert_gt(_count(c3, &"keep"), 0, "fortress has a keep")


func test_harbour_levels_add_water_quay_and_masts() -> void:
	for hb: int in range(1, 4):
		var rec := SettlementPicture.recipe(&"town", 1, hb, false, OWNER)
		assert_eq(_count(rec, &"mast"), hb, "harbour %d has %d masts" % [hb, hb])
		assert_gt(_count(rec, &"water"), 0, "harbour %d has water" % hb)
		assert_gt(_count(rec, &"quay"), 0, "harbour %d has a quay" % hb)
	var inland := SettlementPicture.recipe(&"town", 1, 0, false, OWNER)
	assert_eq(_count(inland, &"mast"), 0, "no harbour, no masts")
	assert_eq(_count(inland, &"water"), 0, "no harbour, no water")
	# Planted fault: a port without its masts must fail the check.
	var port := SettlementPicture.recipe(&"town", 1, 2, false, OWNER)
	assert_eq(_count(_without(port, &"mast"), &"mast"), 0, "a port without masts is caught")


func test_snow_on_roofs_only_in_snow() -> void:
	assert_gt(_count(SettlementPicture.recipe(&"village", 1, 0, true, OWNER), &"snow"), 0, "snow caps the roofs")
	assert_eq(_count(SettlementPicture.recipe(&"village", 1, 0, false, OWNER), &"snow"), 0, "no snow without snow")
	for shape: Dictionary in SettlementPicture.recipe(&"city", 1, 0, true, OWNER):
		if shape["part"] == &"snow":
			assert_eq(shape["fill_token"], &"PIC_SNOW", "snow uses the snow token")


func test_pennant_in_owner_colour_on_the_tallest_tower() -> void:
	for case: Array in KIND_CASES:
		var rec := SettlementPicture.recipe(case[0], case[1], 0, false, OWNER)
		var pennants := 0
		var pole: Dictionary = {}
		var top := INF
		for s: Dictionary in rec:
			if s["part"] == &"pennant":
				pennants += 1
				assert_eq(s["colour"], OWNER, "%s pennant is the owner colour" % case[0])
			if s["part"] == &"pole":
				pole = s
			if SettlementPicture.PENNANT_PARTS.has(s["part"]):
				var pts: PackedVector2Array = s["points"]
				for p: Vector2 in pts:
					top = minf(top, p.y)
		assert_eq(pennants, 1, "%s has one pennant" % case[0])
		var pole_pts: PackedVector2Array = pole["points"]
		assert_almost_eq(pole_pts[0].y, top, 0.01, "%s pennant pole stands on the tallest tower" % case[0])


func test_owner_colour_changes_only_the_pennant() -> void:
	var a := SettlementPicture.recipe(&"city", 1, 1, true, Tokens.LAPIS)
	var b := SettlementPicture.recipe(&"city", 1, 1, true, Tokens.BAD)
	assert_eq(a.size(), b.size(), "same shapes")
	for i: int in a.size():
		if a[i]["part"] == &"pennant":
			assert_eq(b[i]["colour"], Tokens.BAD, "pennant takes the new owner")
		else:
			assert_eq(var_to_str(a[i]), var_to_str(b[i]), "shape %d unchanged" % i)


func test_colours_come_only_from_tokens() -> void:
	var tokens_src := FileAccess.get_file_as_string("res://shell/ui/tokens.gd")
	for case: Array in KIND_CASES:
		for s: Dictionary in SettlementPicture.recipe(case[0], case[1], 3, true, OWNER):
			var tok: StringName = s["fill_token"]
			assert_true(SettlementPicture.TOKEN_NAMES.has(tok), "%s is a known picture token" % tok)
			assert_eq(s["colour"], SettlementPicture.token_colour(tok, OWNER), "colour of %s comes from its token" % tok)
	for token_name: StringName in SettlementPicture.TOKEN_NAMES:
		if token_name == &"OWNER":
			continue
		assert_true(tokens_src.contains("const %s := Color(" % token_name), "%s is defined in tokens.gd" % token_name)


func test_script_has_no_colour_literal() -> void:
	var src := FileAccess.get_file_as_string("res://shell/ui/settlement_picture.gd")
	assert_false(src.contains("Color("), "settlement_picture.gd has no Color( literal")


func test_control_draws_headless_at_scale_two() -> void:
	var pic := RecordingPicture.new()
	add_child_autofree(pic)
	pic.show_picture(&"walled_town", 1, 2, true, OWNER)
	assert_eq(pic.current_recipe().size(), SettlementPicture.recipe(&"walled_town", 1, 2, true, OWNER).size(), "recipe kept")
	pic.size = SettlementPicture.LOGICAL_SIZE * 2.0
	await wait_process_frames(2)
	assert_gt(pic.polygons, 0, "polygons were drawn at scale 2")
	assert_gt(pic.lines, 0, "lines were drawn (masts, pole)")
	assert_lte(pic.max_x, pic.size.x + 0.01, "drawing stays inside the rect")
	assert_lte(pic.max_y, pic.size.y + 0.01, "drawing stays inside the rect (height)")
