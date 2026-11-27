## The parchment's colour tokens (docs/architecture/map-overview-build-spec.md R4, R6, R26, R27, D9): the text and line
## contrast pairs and the goods ramp's lightness steps, standard and high contrast. Each planted case (P) feeds a check a
## pair or a ramp it must report.
extends GutTest

const TEXT_MIN := 4.5
const LINE_MIN := 3.0
const STEP_MIN := 15.0
const TEXT_PAIRS: Array[Array] = [[&"name_ink", &"halo"], [&"town_ink", &"halo"]]
const LINES: Array[StringName] = [&"district", &"mountain", &"border", &"coast", &"dot_edge"]
const RAMP: Array[StringName] = [&"goods_1", &"goods_2", &"goods_3"]
const ROLES: Array[StringName] = [&"sea", &"speckle", &"hatch", &"land", &"unknown", &"veil", &"district", &"mountain",
	&"border", &"coast", &"name_ink", &"town_ink", &"halo", &"dot_fill", &"dot_edge", &"disc", &"disc_edge", &"pip",
	&"goods_1", &"goods_2", &"goods_3"]
const SEE_THROUGH: Array[StringName] = [&"speckle", &"hatch", &"veil"]


## CIE L* of a colour.
func _lightness(c: Color) -> float:
	var y := Tokens.relative_luminance(c)
	return 116.0 * pow(y, 1.0 / 3.0) - 16.0 if y > 0.008856 else 903.3 * y


func _under_veil(c: Color, veil: Color) -> Color:
	return c.lerp(Color(veil, 1.0), veil.a)


## The pairs of a set under their contrast: name inks on the halo; lines on the land, bare and under the sight veil;
## the borders and the coast on every shade of the goods ramp.
func _contrast_problems(set_of: Dictionary) -> Array[String]:
	var pairs: Array[Array] = []
	for pair: Array in TEXT_PAIRS:
		pairs.append([pair[0], set_of[pair[0]], pair[1], set_of[pair[1]], TEXT_MIN])
	for line: StringName in LINES:
		pairs.append([line, set_of[line], &"land", set_of[&"land"], LINE_MIN])
		pairs.append([line, set_of[line], &"veiled land", _under_veil(set_of[&"land"], set_of[&"veil"]), LINE_MIN])
	for line: StringName in [&"border", &"coast"]:
		for shade: StringName in RAMP:
			pairs.append([line, set_of[line], shade, set_of[shade], LINE_MIN])
	var out: Array[String] = []
	for p: Array in pairs:
		var ratio := Tokens.contrast_ratio(p[1], p[3])
		if ratio < float(p[4]):
			out.append("%s on %s is %.2f, under %.1f" % [p[0], p[2], ratio, p[4]])
	return out


## The steps of a ramp (light to dark) under STEP_MIN L*.
func _ramp_problems(ramp: Array[Color]) -> Array[String]:
	var out: Array[String] = []
	for k: int in range(1, ramp.size()):
		var step := _lightness(ramp[k - 1]) - _lightness(ramp[k])
		if step < STEP_MIN:
			out.append("stage %d to %d is %.1f L*" % [k, k + 1, step])
	return out


func test_both_sets_hold_every_role() -> void:
	for high: bool in [false, true]:
		var set_of := ParchmentTokens.colours(high)
		var roles: Array = set_of.keys()
		roles.sort()
		var wanted: Array = ROLES.duplicate()
		wanted.sort()
		assert_eq(roles, wanted, "high contrast %s" % high)
		for role: StringName in ROLES:
			assert_eq(set_of[role].a < 1.0, SEE_THROUGH.has(role), "%s: only the washes are see-through" % role)
		set_of[&"land"] = Color.BLACK
		assert_ne(ParchmentTokens.colours(high)[&"land"], Color.BLACK, "a new dictionary each time")


func test_text_and_line_contrast_pairs() -> void:
	assert_eq(_contrast_problems(ParchmentTokens.colours(false)), [] as Array[String], "standard")
	assert_eq(_contrast_problems(ParchmentTokens.colours(true)), [] as Array[String], "high contrast")


func test_p_a_faint_pair_is_reported() -> void:
	var set_of := ParchmentTokens.colours(false)
	set_of[&"district"] = Color("#b9ad96")  # a faint ink on the land
	assert_gt(_contrast_problems(set_of).size(), 0, "P: a district line under 3:1")
	set_of = ParchmentTokens.colours(false)
	set_of[&"name_ink"] = Color("#8a7a64")
	assert_eq(_contrast_problems(set_of).size(), 1, "P: a name ink under 4.5:1 on its halo")


func test_the_goods_ramp_is_one_hue_with_clear_lightness_steps() -> void:
	for high: bool in [false, true]:
		var set_of := ParchmentTokens.colours(high)
		var ramp: Array[Color] = [set_of[&"goods_1"], set_of[&"goods_2"], set_of[&"goods_3"]]
		assert_eq(_ramp_problems(ramp), [] as Array[String], "15 L* or more between stages (R26)")
		for k: int in 3:
			assert_almost_eq(ramp[k].h, ramp[0].h, 5.0 / 360.0, "one hue")
			assert_eq(ParchmentTokens.stage_colour(k + 1, high), ramp[k])
		assert_gt(_lightness(set_of[&"land"]) - _lightness(ramp[0]), 5.0, "stage 1 is darker than bare land")
		assert_eq(ParchmentTokens.stage_colour(0, high), set_of[&"land"], "not here: the land")
		assert_eq(ParchmentTokens.stage_colour(9, high), ramp[2])


func test_p_a_ramp_with_a_small_step_is_reported() -> void:
	# The mockup's shades: about 8 and 14 L* apart.
	var ramp: Array[Color] = [Color("#b9e3bd"), Color("#7fd39a"), Color("#3fae6a")]
	assert_eq(_ramp_problems(ramp).size(), 2, "P: both steps are under 15")
	var one_short: Array[Color] = [ParchmentTokens.GOODS_1, ParchmentTokens.GOODS_2, ParchmentTokens.GOODS_2.darkened(0.08)]
	assert_eq(_ramp_problems(one_short).size(), 1, "P: one small step")


func test_high_contrast_is_darker_ink_and_one_px_thicker() -> void:
	var plain := ParchmentTokens.colours(false)
	var high := ParchmentTokens.colours(true)
	for role: StringName in [&"coast", &"border", &"district", &"mountain", &"name_ink", &"town_ink"]:
		assert_lt(_lightness(high[role]), _lightness(plain[role]), "%s is darker" % role)
	assert_eq(ParchmentTokens.coast_px(false), 3.0)
	assert_eq(ParchmentTokens.coast_px(true), 4.0)
	assert_eq(ParchmentTokens.border_px(false), 2.0)
	assert_eq(ParchmentTokens.border_px(true), 3.0)
	assert_eq([ParchmentTokens.BORDER_DASH_PX, ParchmentTokens.BORDER_GAP_PX, ParchmentTokens.DISTRICT_PX],
		[9.0, 6.0, 1.0])
	assert_eq(ParchmentTokens.OWNER_MIX, 0.46)
	assert_eq(ParchmentTokens.HALO_PX, 4)
