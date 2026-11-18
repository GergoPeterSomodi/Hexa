## GUT tests for CountryArms procedural heraldic shield rendering
## (docs/architecture/m2-build-spec.md sections 4.7, 7.2 and 10).
extends GutTest

const COUNTRY_ARMS_SPECS: Array[Dictionary] = [
	{"tag": &"SAV", "division": &"cross", "field": &"gules", "charge": &"argent"},
	{"tag": &"GEN", "division": &"cross", "field": &"argent", "charge": &"gules"},
	{"tag": &"MLO", "division": &"quarterly", "field": &"or", "charge": &"azure"},
	{"tag": &"VEN", "division": &"bordure", "field": &"gules", "charge": &"or"},
	{"tag": &"TUS", "division": &"per_pale", "field": &"argent", "charge": &"gules"},
	{"tag": &"SWI", "division": &"bend", "field": &"gules", "charge": &"or"},
	{"tag": &"MAN", "division": &"fess", "field": &"or", "charge": &"sable"},
	{"tag": &"FER", "division": &"per_bend", "field": &"azure", "charge": &"argent"},
	{"tag": &"SIE", "division": &"per_fess", "field": &"argent", "charge": &"sable"},
	{"tag": &"LUC", "division": &"per_fess", "field": &"argent", "charge": &"gules"},
	{"tag": &"PAP", "division": &"saltire", "field": &"gules", "charge": &"or"},
	{"tag": &"AUS", "division": &"fess", "field": &"gules", "charge": &"argent"},
	{"tag": &"FRA", "division": &"pale", "field": &"azure", "charge": &"or"},
]


class RecordingArms extends CountryArms:
	var recorded_polygons: Array[Dictionary] = []
	var recorded_lines: Array[Dictionary] = []
	var recorded_rims: Array[Dictionary] = []

	func reset_recording() -> void:
		recorded_polygons.clear()
		recorded_lines.clear()
		recorded_rims.clear()

	func _paint_polygon(pts: PackedVector2Array, col: Color) -> void:
		recorded_polygons.append({"points": pts, "color": col})
		super._paint_polygon(pts, col)

	func _paint_polyline(pts: PackedVector2Array, col: Color, width: float) -> void:
		recorded_lines.append({"points": pts, "color": col, "width": width})
		super._paint_polyline(pts, col, width)

	func _paint_rim(rect: Rect2, is_small: bool) -> void:
		var icon_key := &"shield_rim_sm" if is_small else &"shield_rim"
		var has_icon := has_theme_icon(icon_key, &"Kit")
		var tex := get_theme_icon(icon_key, &"Kit") if has_icon else null
		recorded_rims.append({"rect": rect, "small": is_small, "icon": icon_key, "has_icon": has_icon, "texture": tex})
		super._paint_rim(rect, is_small)


var _harness: UIHarness = null
var _root: Control = null
var _tinctures: Dictionary[StringName, Color] = {}


func before_each() -> void:
	_tinctures = GameDefs.default_tinctures()
	_harness = UIHarness.new()
	_harness.mount(self)
	_root = Control.new()
	_root.theme = KitTheme.load_for(1.0)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_harness.viewport.add_child(_root)


func after_each() -> void:
	_root = null
	_harness = null


func _assert_points_inside_shield(pts: PackedVector2Array, shield: PackedVector2Array, label: String) -> void:
	assert_gt(pts.size(), 0, "%s has points" % label)
	for i: int in pts.size():
		var p := pts[i]
		assert_true(
			Geometry2D.is_point_in_polygon(p, shield),
			"%s vertex %d %s lies inside SHIELD" % [label, i, str(p)]
		)
	if pts.size() >= 3:
		for i: int in pts.size():
			var mid := (pts[i] + pts[(i + 1) % pts.size()]) * 0.5
			assert_true(
				Geometry2D.is_point_in_polygon(mid, shield),
				"%s edge midpoint %d %s lies inside SHIELD" % [label, i, str(mid)]
			)


func test_size_mouse_filter_and_empty_dict_draws_nothing() -> void:
	var arms := RecordingArms.new()
	assert_eq(arms.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(arms.custom_minimum_size, Vector2(48.0, 56.0))
	assert_false(arms.has_arms())
	_root.add_child(arms)

	await _harness.wait_frames(self, 2)
	assert_eq(arms.recorded_polygons.size(), 0, "unconfigured shield draws no polygons")
	assert_eq(arms.recorded_lines.size(), 0, "unconfigured shield draws no lines")
	assert_eq(arms.recorded_rims.size(), 0, "unconfigured shield draws no rim")

	arms.set_country({"division": &"cross", "field": _tinctures[&"gules"], "charge": _tinctures[&"argent"]})
	assert_true(arms.has_arms())
	await _harness.wait_frames(self, 2)
	assert_gt(arms.recorded_polygons.size(), 0)
	assert_eq(arms.recorded_rims.size(), 1)

	arms.reset_recording()
	arms.set_country({})
	assert_false(arms.has_arms())
	await _harness.wait_frames(self, 2)
	assert_eq(arms.recorded_polygons.size(), 0, "empty dict clears polygons")
	assert_eq(arms.recorded_lines.size(), 0, "empty dict clears lines")
	assert_eq(arms.recorded_rims.size(), 0, "empty dict clears rim")

	arms.small = true
	assert_eq(arms.custom_minimum_size, Vector2(20.0, 24.0))


func test_all_twelve_divisions_large_and_small_inside_shield_and_use_tinctures() -> void:
	var field_col := _tinctures[&"gules"]
	var charge_col := _tinctures[&"or"]
	var arms := RecordingArms.new()
	_root.add_child(arms)

	for is_small: bool in [false, true]:
		arms.small = is_small
		var expected_size := Vector2(20.0, 24.0) if is_small else Vector2(48.0, 56.0)
		var expected_icon := &"shield_rim_sm" if is_small else &"shield_rim"
		var shield := CountryArms.scaled_shield(is_small)
		assert_eq(arms.custom_minimum_size, expected_size)

		for div_name: StringName in CountryDef.DIVISIONS:
			arms.reset_recording()
			arms.set_country({"division": div_name, "field": field_col, "charge": charge_col})
			await _harness.wait_frames(self, 2)

			var tag := "%s(%s)" % [String(div_name), "sm" if is_small else "lg"]
			assert_eq(arms.division(), div_name, tag)
			assert_gt(arms.recorded_polygons.size(), 0, "%s draws field" % tag)

			var drew_field := false
			var drew_charge := false
			for p_idx: int in arms.recorded_polygons.size():
				var poly_rec: Dictionary = arms.recorded_polygons[p_idx]
				var pts := poly_rec["points"] as PackedVector2Array
				var col := poly_rec["color"] as Color
				_assert_points_inside_shield(pts, shield, "%s poly %d" % [tag, p_idx])
				assert_true(col == field_col or col == charge_col, "%s poly %d colour is a tincture" % [tag, p_idx])
				if col == field_col:
					drew_field = true
				if col == charge_col:
					drew_charge = true

			assert_true(drew_field, "%s draws field tincture" % tag)
			if div_name == &"plain":
				assert_false(drew_charge, "plain draws no charge")
				assert_eq(arms.recorded_lines.size(), 0, "plain draws no division lines")
			else:
				assert_true(drew_charge, "%s draws charge tincture" % tag)
				assert_gt(arms.recorded_lines.size(), 0, "%s draws division lines" % tag)
				for l_idx: int in arms.recorded_lines.size():
					var line_rec: Dictionary = arms.recorded_lines[l_idx]
					var lpts := line_rec["points"] as PackedVector2Array
					_assert_points_inside_shield(lpts, shield, "%s line %d" % [tag, l_idx])
					assert_eq(line_rec["color"], Tokens.INK_LINE, "%s line colour" % tag)
					assert_almost_eq(float(line_rec["width"]), 1.0, 0.01, "%s line width" % tag)

			assert_gte(arms.recorded_rims.size(), 1, "%s draws rim" % tag)
			var rim_rec: Dictionary = arms.recorded_rims[-1]
			assert_eq(rim_rec["rect"], Rect2(Vector2.ZERO, expected_size), "%s rim rect" % tag)
			assert_eq(rim_rec["icon"], expected_icon, "%s rim icon key" % tag)
			assert_true(bool(rim_rec["has_icon"]), "%s Kit has rim icon" % tag)
			var tex := rim_rec["texture"] as Texture2D
			assert_not_null(tex, "%s rim texture non-null" % tag)
			assert_eq(tex.get_size(), expected_size, "%s rim texture size" % tag)


func test_all_thirteen_countries_from_spec_and_2x_theme() -> void:
	var theme_2x := KitTheme.load_for(2.0, &"2x", false)
	var hc_theme := KitTheme.load_for(1.0, &"plain", true)
	var arms := RecordingArms.new()
	_root.add_child(arms)

	for spec: Dictionary in COUNTRY_ARCS_OR_SPECS():
		var c_tag := spec["tag"] as StringName
		var div_name := spec["division"] as StringName
		var field_name := spec["field"] as StringName
		var charge_name := spec["charge"] as StringName
		var field_col := _tinctures[field_name]
		var charge_col := _tinctures[charge_name]

		for is_small: bool in [false, true]:
			arms.theme = theme_2x
			arms.small = is_small
			arms.reset_recording()
			arms.set_country({"division": div_name, "field": field_col, "charge": charge_col})
			await _harness.wait_frames(self, 2)

			var expected_size := Vector2(20.0, 24.0) if is_small else Vector2(48.0, 56.0)
			assert_gte(arms.recorded_rims.size(), 1, "%s 2x rim drawn" % String(c_tag))
			var tex := arms.recorded_rims[-1]["texture"] as Texture2D
			assert_not_null(tex)
			assert_eq(tex.get_size(), expected_size, "%s 2x logical size" % String(c_tag))
			assert_eq(
				tex.get_image().get_size(),
				Vector2i(int(expected_size.x) * 2, int(expected_size.y) * 2),
				"%s 2x backing pixels" % String(c_tag)
			)

			var cols: Array[Color] = []
			for poly_rec: Dictionary in arms.recorded_polygons:
				cols.append(poly_rec["color"] as Color)
			assert_true(cols.has(field_col), "%s drew field" % String(c_tag))
			assert_true(cols.has(charge_col), "%s drew charge" % String(c_tag))

	# High-contrast theme renders cleanly without error.
	arms.theme = hc_theme
	arms.small = false
	arms.reset_recording()
	arms.set_country({"division": &"quarterly", "field": _tinctures[&"or"], "charge": _tinctures[&"azure"]})
	await _harness.wait_frames(self, 2)
	assert_gte(arms.recorded_rims.size(), 1)
	assert_eq(arms.recorded_polygons.size(), 3 * arms.recorded_rims.size())

	# Settled control does not redraw on idle frames.
	arms.reset_recording()
	await _harness.wait_frames(self, 3)
	assert_eq(arms.recorded_rims.size(), 0, "no idle redraws after settling")


func test_invalid_division_and_string_tincture_fallbacks() -> void:
	var arms := RecordingArms.new()
	_root.add_child(arms)

	arms.set_country({"division": &"nonexistent_division", "field": &"gules", "charge": &"argent"})
	await _harness.wait_frames(self, 2)
	assert_true(arms.has_arms())
	assert_eq(arms.division(), &"plain", "unknown division falls back to plain")
	assert_eq(arms.field_color(), _tinctures[&"gules"], "StringName tincture resolves")
	assert_eq(arms.charge_color(), _tinctures[&"argent"], "StringName charge resolves")
	assert_eq(arms.recorded_polygons.size(), 1)
	assert_eq(arms.recorded_polygons[0]["color"], _tinctures[&"gules"])
	assert_eq(arms.recorded_lines.size(), 0)
	assert_eq(arms.recorded_rims.size(), 1)


func COUNTRY_ARCS_OR_SPECS() -> Array[Dictionary]:
	return COUNTRY_ARMS_SPECS
