## The parchment's colour tokens (docs/architecture/map-overview-build-spec.md R4, R6, R26, R27, D9): the text and line
## contrast pairs and the goods ramp's lightness steps, standard and high contrast. A see-through ink is measured as it
## shows: laid over what is under it. In the standard set the district dots and the mountain marks are the approved
## mockup's faint inks, under R27's 3:1 for lines; they are pinned, and held above FAINT_MIN. In high contrast every
## line is 3:1. Each planted case (P) feeds a check a pair or a ramp it must report.
extends GutTest

const TEXT_MIN := 4.5
const LINE_MIN := 3.0
## The least a faint ink of the standard set shows against the land (it must not fade away).
const FAINT_MIN := 1.8
const FAINT: Array[StringName] = [&"district", &"mountain"]
const STEP_MIN := 15.0
const TEXT_PAIRS: Array[Array] = [[&"name_ink", &"halo"], [&"town_ink", &"halo"]]
const LINES: Array[StringName] = [&"district", &"mountain", &"border", &"coast", &"dot_edge"]
const RAMP: Array[StringName] = [&"goods_1", &"goods_2", &"goods_3"]
const ROLES: Array[StringName] = [&"sea", &"speckle", &"hatch", &"land", &"unknown", &"district", &"mountain",
	&"border", &"coast", &"name_ink", &"town_ink", &"halo", &"dot_fill", &"dot_edge", &"disc", &"disc_edge", &"pip",
	&"goods_1", &"goods_2", &"goods_3", &"reach_ink", &"reach_light"]
const SEE_THROUGH: Array[StringName] = [&"speckle", &"hatch"]


## CIE L* of a colour.
func _lightness(c: Color) -> float:
	var y := Tokens.relative_luminance(c)
	return 116.0 * pow(y, 1.0 / 3.0) - 16.0 if y > 0.008856 else 903.3 * y


## `top` laid over the opaque `under` by its alpha.
func _over(top: Color, under: Color) -> Color:
	return under.lerp(Color(top, 1.0), top.a)


## The pairs of a set under their contrast: name inks on the halo; lines on the land (the faint inks of the standard set
## against FAINT_MIN); the borders and the coast on every shade of the goods ramp.
func _contrast_problems(set_of: Dictionary, high: bool) -> Array[String]:
	var pairs: Array[Array] = []
	for pair: Array in TEXT_PAIRS:
		pairs.append([pair[0], set_of[pair[0]], pair[1], set_of[pair[1]], TEXT_MIN])
	for line: StringName in LINES:
		var least := FAINT_MIN if FAINT.has(line) and not high else LINE_MIN
		pairs.append([line, set_of[line], &"land", set_of[&"land"], least])
	for line: StringName in [&"border", &"coast"]:
		for shade: StringName in RAMP:
			pairs.append([line, set_of[line], shade, set_of[shade], LINE_MIN])
	var out: Array[String] = []
	for p: Array in pairs:
		var ratio := Tokens.contrast_ratio(_over(p[1], p[3]), p[3])
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
			var see_through := SEE_THROUGH.has(role) or (FAINT.has(role) and not high)
			assert_eq(set_of[role].a < 1.0, see_through, "%s: the washes and the faint inks only" % role)
		set_of[&"land"] = Color.BLACK
		assert_ne(ParchmentTokens.colours(high)[&"land"], Color.BLACK, "a new dictionary each time")


func test_text_and_line_contrast_pairs() -> void:
	assert_eq(_contrast_problems(ParchmentTokens.colours(false), false), [] as Array[String], "standard")
	assert_eq(_contrast_problems(ParchmentTokens.colours(true), true), [] as Array[String], "high contrast")


func test_the_faint_inks_are_the_mockups_and_under_the_line_contrast() -> void:
	# The approved mockup: district dots #8a7a64 at 0.7 and 0.8 px, mountain marks #7d6a52 at 0.6.
	assert_eq([ParchmentTokens.DISTRICT.to_html(true), ParchmentTokens.MOUNTAIN.to_html(true)],
		["8a7a64b3", "7d6a5299"])
	var land := ParchmentTokens.LAND
	for ink: Color in [ParchmentTokens.DISTRICT, ParchmentTokens.MOUNTAIN]:
		assert_almost_eq(Tokens.contrast_ratio(_over(ink, land), land), 2.13, 0.05, "about 2.1:1 on the land")


func test_p_a_faint_pair_is_reported() -> void:
	var set_of := ParchmentTokens.colours(false)
	set_of[&"district"] = Color(set_of[&"district"], 0.4)  # fainter than the mockup's: under the floor
	assert_gt(_contrast_problems(set_of, false).size(), 0, "P: a district line fading away")
	set_of = ParchmentTokens.colours(false)
	set_of[&"border"] = Color(set_of[&"border"], 0.4)  # its colour alone would pass
	assert_gt(_contrast_problems(set_of, false).size(), 0, "P: a see-through border is measured as it shows")
	assert_gt(_contrast_problems(ParchmentTokens.colours(false), true).size(), 0,
		"P: the faint inks in a high-contrast set")
	set_of = ParchmentTokens.colours(false)
	set_of[&"name_ink"] = Color("#8a7a64")
	assert_eq(_contrast_problems(set_of, false).size(), 1, "P: a name ink under 4.5:1 on its halo")


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
	assert_eq([ParchmentTokens.BORDER_DASH_PX, ParchmentTokens.BORDER_GAP_PX], [9.0, 6.0])
	assert_eq([ParchmentTokens.district_px(false), ParchmentTokens.district_px(true)], [0.8, 1.0])
	assert_eq(ParchmentTokens.OWNER_MIX, 0.46)
	assert_eq(ParchmentTokens.HALO_PX, 4)
