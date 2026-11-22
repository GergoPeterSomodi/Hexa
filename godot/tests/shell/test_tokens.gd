## Tests for Studiolo UI tokens (docs/design/ui/design.md section 3; docs/architecture/ui-style-and-feedback-spec.md
## sections 4.2, 4.3, 4.7, 4.9 and 11).
extends GutTest

const TOKENS_PATH := "res://shell/ui/tokens.gd"
const ONE_LINE_REGEX := '^const ([A-Z][A-Z0-9_]*) := (?:Color\\("(#[0-9a-f]{6,8})"\\)|(\\d+(?:\\.\\d+)?))$'


func test_leather_and_panel_bg_contrast_ratios() -> void:
	for ground: Color in [Tokens.PANEL_BG, Tokens.LEATHER]:
		assert_gte(Tokens.contrast_ratio(Tokens.TEXT, ground), 4.5, "TEXT on leather/panel")
		assert_gte(Tokens.contrast_ratio(Tokens.MUTED, ground), 4.5, "MUTED on leather/panel")
		assert_gte(Tokens.contrast_ratio(Tokens.FAINT, ground), 4.5, "FAINT on leather/panel")
		assert_gte(Tokens.contrast_ratio(Tokens.GOLD, ground), 4.5, "GOLD on leather/panel")
		assert_gte(Tokens.contrast_ratio(Tokens.GOOD, ground), 4.5, "GOOD on leather/panel")
		assert_gte(Tokens.contrast_ratio(Tokens.BAD, ground), 4.5, "BAD on leather/panel")
		assert_gte(Tokens.contrast_ratio(Tokens.WARN, ground), 4.5, "WARN on leather/panel")
		assert_gte(Tokens.contrast_ratio(Tokens.INFO, ground), 4.5, "INFO on leather/panel")

	# Exact table targets from design.md section 3 on PANEL_BG (#221a14).
	assert_almost_eq(Tokens.contrast_ratio(Tokens.TEXT, Tokens.PANEL_BG), 14.1, 0.15)
	assert_almost_eq(Tokens.contrast_ratio(Tokens.MUTED, Tokens.PANEL_BG), 7.4, 0.15)
	assert_almost_eq(Tokens.contrast_ratio(Tokens.FAINT, Tokens.PANEL_BG), 5.2, 0.15)
	assert_almost_eq(Tokens.contrast_ratio(Tokens.GOLD, Tokens.PANEL_BG), 10.0, 0.15)
	assert_almost_eq(Tokens.contrast_ratio(Tokens.GOOD, Tokens.PANEL_BG), 8.7, 0.15)
	assert_almost_eq(Tokens.contrast_ratio(Tokens.BAD, Tokens.PANEL_BG), 6.5, 0.15)
	assert_almost_eq(Tokens.contrast_ratio(Tokens.WARN, Tokens.PANEL_BG), 8.5, 0.15)
	assert_almost_eq(Tokens.contrast_ratio(Tokens.INFO, Tokens.PANEL_BG), 8.3, 0.15)

	# Lightest allowed leather texel (#2f231a) keeps FAINT >= 4.5 (spec 4.4, design.md section 3).
	assert_gte(Tokens.contrast_ratio(Tokens.FAINT, Tokens.LEATHER_LIGHTEST), 4.5, "FAINT on lightest leather #2f231a")


func test_card_slot_wood_and_control_contrast_ratios() -> void:
	for ground: Color in [Tokens.CARD_BG, Tokens.SLOT]:
		assert_gte(Tokens.contrast_ratio(Tokens.TEXT, ground), 4.5, "TEXT on card/slot")
		assert_gte(Tokens.contrast_ratio(Tokens.MUTED, ground), 4.5, "MUTED on card/slot")
		assert_gte(Tokens.contrast_ratio(Tokens.FAINT, ground), 4.5, "FAINT on card/slot")

	assert_almost_eq(Tokens.contrast_ratio(Tokens.TEXT, Tokens.CARD_BG), 15.4, 0.15)
	assert_almost_eq(Tokens.contrast_ratio(Tokens.MUTED, Tokens.CARD_BG), 8.1, 0.15)
	assert_almost_eq(Tokens.contrast_ratio(Tokens.FAINT, Tokens.CARD_BG), 5.7, 0.15)
	assert_almost_eq(Tokens.contrast_ratio(Tokens.TEXT, Tokens.SLOT), 16.2, 0.15)
	assert_almost_eq(Tokens.contrast_ratio(Tokens.MUTED, Tokens.SLOT), 8.5, 0.15)

	# Walnut (WOOD #4a2f1c and PANEL_HEAD #3a2416): TEXT, MUTED, BRASS_HI (design.md section 3).
	assert_gte(Tokens.contrast_ratio(Tokens.TEXT, Tokens.WOOD), 10.0, "TEXT on WOOD")
	assert_almost_eq(Tokens.contrast_ratio(Tokens.TEXT, Tokens.PANEL_HEAD), 11.9, 0.15, "TEXT on PANEL_HEAD")
	assert_almost_eq(Tokens.contrast_ratio(Tokens.MUTED, Tokens.WOOD), 5.3, 0.15, "MUTED on WOOD")
	assert_almost_eq(Tokens.contrast_ratio(Tokens.MUTED, Tokens.PANEL_HEAD), 6.3, 0.15, "MUTED on PANEL_HEAD")
	assert_almost_eq(Tokens.contrast_ratio(Tokens.BRASS_HI, Tokens.WOOD), 9.6, 0.15, "BRASS_HI on WOOD")

	# Button faces, ribbon and key cap (design.md section 3).
	assert_gte(Tokens.contrast_ratio(Tokens.TEXT, Tokens.BUTTON), 9.0, "TEXT on BUTTON")
	assert_gte(Tokens.contrast_ratio(Tokens.TEXT, Tokens.BUTTON_HOT), 7.0, "TEXT on BUTTON_HOT")
	assert_gte(Tokens.contrast_ratio(Tokens.TEXT, Tokens.DANGER), 6.5, "TEXT on DANGER")
	assert_gte(Tokens.contrast_ratio(Tokens.TEXT, Tokens.DANGER_HOT), 4.5, "TEXT on DANGER_HOT")
	assert_gte(Tokens.contrast_ratio(Tokens.PRIMARY_INK, Tokens.PRIMARY), 8.0, "PRIMARY_INK on PRIMARY")
	assert_gte(Tokens.contrast_ratio(Tokens.BRASS_HI, Tokens.VELVET), 10.0, "BRASS_HI on VELVET ribbon")


func test_vellum_and_chart_ink_contrast_ratios() -> void:
	assert_gte(
		Tokens.relative_luminance(Tokens.VELLUM_DARKEST),
		Tokens.VELLUM_MIN_LUMINANCE,
		"darkest vellum blotch #e1d5b8 keeps luminance >= 0.66"
	)

	var inks: Array[Color] = [
		Tokens.VELLUM_INK,
		Tokens.VELLUM_MUTED,
		Tokens.GOOD_INK,
		Tokens.BAD_INK,
		Tokens.WARN_INK,
		Tokens.GOLD_INK,
		Tokens.CHART_IRON,
		Tokens.CHART_LAPIS,
		Tokens.CHART_MADDER,
		Tokens.CHART_VERDIGRIS,
		Tokens.CHART_OCHRE,
	]
	for ink: Color in inks:
		assert_gte(Tokens.contrast_ratio(ink, Tokens.VELLUM), 4.5, "ink >= 4.5:1 on VELLUM")
		assert_gte(Tokens.contrast_ratio(ink, Tokens.VELLUM_DARKEST), 4.5, "ink >= 4.5:1 on darkest vellum blotch")

	assert_eq(Tokens.CHART_INKS.size(), 5, "five chart inks")
	for chart_ink: Color in Tokens.CHART_INKS:
		assert_gte(Tokens.contrast_ratio(chart_ink, Tokens.VELLUM), 4.5, "CHART_INKS entry >= 4.5:1 on VELLUM")
		assert_gte(Tokens.contrast_ratio(chart_ink, Tokens.VELLUM_DARKEST), 4.5, "CHART_INKS entry >= 4.5:1 on blotch")


func test_high_contrast_and_lapis_sets() -> void:
	var hc_text: Color = Tokens.HIGH_CONTRAST["TEXT"]
	var hc_bg: Color = Tokens.HIGH_CONTRAST["BG"]
	assert_almost_eq(Tokens.contrast_ratio(hc_text, hc_bg), 21.0, 0.01, "HIGH_CONTRAST TEXT on BG is 21:1")
	assert_almost_eq(
		Tokens.contrast_ratio(Tokens.HIGH_CONTRAST["VELLUM_INK"], Tokens.HIGH_CONTRAST["VELLUM"]),
		21.0,
		0.01,
		"HIGH_CONTRAST vellum is also 21:1"
	)
	assert_eq(Tokens.HIGH_CONTRAST["LINE"], Color("#ffd646"))
	assert_eq(Tokens.HIGH_CONTRAST["GOLD"], Color("#ffd646"))
	assert_eq(Tokens.HIGH_CONTRAST["BRASS"], Color("#ffd646"))
	assert_eq(Tokens.HIGH_CONTRAST["GOOD_INK"], Tokens.GOOD)
	assert_eq(Tokens.HIGH_CONTRAST["BAD_INK"], Tokens.BAD)
	assert_eq(Tokens.HIGH_CONTRAST["WARN_INK"], Tokens.WARN)

	for key: String in ["PANEL_BG", "PANEL_HEAD", "CARD_BG", "TOGGLE", "ROW_HOVER", "LEATHER"]:
		assert_true(Tokens.LAPIS_AND_GILT.has(key), "LAPIS_AND_GILT has " + key)
	assert_gte(Tokens.contrast_ratio(Tokens.FAINT, Tokens.LAPIS_AND_GILT["PANEL_BG"]), 4.5)
	assert_gte(Tokens.contrast_ratio(Tokens.FAINT, Tokens.LAPIS_AND_GILT["LEATHER"]), 4.5)


func test_map_route_tokens_of_slice_5() -> void:
	# m6-build-spec.md 6.2: reach tints and the route colours.
	assert_eq(Tokens.MAP_REACH, Color("#ffd64633"))
	assert_eq(Tokens.MAP_REACH_NEXT, Color("#ffd64614"))
	assert_eq(Tokens.MAP_PATH, Color("#f6e3a1"))
	assert_eq(Tokens.MAP_PATH_WARN, Color("#f0806a"))
	assert_eq(Tokens.MAP_PATH_INK, Color("#0b0806"))
	assert_gte(Tokens.contrast_ratio(Tokens.MAP_PATH, Tokens.MAP_PATH_INK), 4.5, "the route reads on its ink")
	assert_gte(Tokens.contrast_ratio(Tokens.MAP_PATH_WARN, Tokens.MAP_PATH_INK), 4.5, "the warning leg reads on its ink")
	for key: String in ["MAP_REACH", "MAP_REACH_NEXT", "MAP_PATH", "MAP_PATH_WARN", "MAP_PATH_INK"]:
		assert_true(Tokens.HIGH_CONTRAST.has(key), "HIGH_CONTRAST has " + key)


func test_type_and_style_variation_tables_are_complete() -> void:
	assert_eq(Tokens.FONTS.size(), 7, "seven static font files")
	for font_key: String in Tokens.FONTS:
		var path: String = Tokens.FONTS[font_key]
		assert_true(path.begins_with("res://assets/fonts/") and path.ends_with(".ttf"), "valid font path: " + path)

	var expected_types: Array[String] = [
		"TitleRibbon", "TitleModal", "TitleBrand", "TitlePanel", "ButtonMenu",
		"SectionHead", "TableHeader",
		"Number", "NumberGood", "NumberBad", "NumberWarn",
		"Label", "KeyCap",
		"Body", "TableRow", "Hint", "Reason",
		"LabelInk", "LabelInkMuted", "LabelInkHead",
		"NumberInk", "NumberInkGood", "NumberInkBad", "NumberInkWarn",
		"LabelFlavour",
	]
	for var_name: String in expected_types:
		assert_true(Tokens.TYPE_VARIATIONS.has(var_name), "TYPE_VARIATIONS has " + var_name)
		var entry: Dictionary = Tokens.TYPE_VARIATIONS[var_name]
		var font_name := str(entry["font"])
		var size := int(entry["size"])
		assert_true(Tokens.FONTS.has(font_name), "%s references known font %s" % [var_name, font_name])
		if var_name == "KeyCap":
			assert_eq(size, 12, "KeyCap is 12 px")
		else:
			assert_gte(size, 13, "%s is >= 13 px" % var_name)
		if var_name.begins_with("Number"):
			assert_ne(font_name, "cinzel_bold", "Cinzel never sets a number: " + var_name)
			assert_true(bool(entry["tabular"]), "number variation uses tabular digits: " + var_name)

	for alias_name: String in ["HexTitle", "HexSection", "HexKey", "HexValue", "HexReason"]:
		assert_false(Tokens.TYPE_VARIATIONS.has(alias_name), "Hex* alias removed: " + alias_name)

	var expected_styles: Array[String] = [
		"PanelContainer", "PanelModal", "PanelVellum", "PanelVellumInset", "PanelCard", "PanelBar",
		"PanelRibbon", "PanelToast", "PanelCartouche", "PanelSlot", "PanelStripCell", "PanelStripCellNow",
		"Button", "ButtonSmall", "ButtonPrimary", "ButtonPrimaryLarge", "ButtonDanger", "ButtonToggle", "ButtonIcon",
		"ButtonMenu", "ButtonMenuPrimary", "ButtonMenuDanger", "ButtonEndSeason", "ButtonMedallion",
		"ButtonNav", "ButtonNavInk", "ButtonTab", "StudyTree", "InkChart",
	]
	for style_name: String in expected_styles:
		assert_true(Tokens.STYLE_VARIATIONS.has(style_name), "STYLE_VARIATIONS has " + style_name)

	var chart_colors: Dictionary = Tokens.STYLE_VARIATIONS["InkChart"]["colors"]
	for key: String in ["ink_0", "ink_1", "ink_2", "ink_3", "ink_4", "axis", "grid", "good", "bad"]:
		assert_true(chart_colors.has(key), "InkChart has " + key)
		assert_true(chart_colors.has(key + "_slot"), "InkChart has " + key + "_slot")

	var dashes: Dictionary[String, bool] = {}
	var markers: Dictionary[String, bool] = {}
	for cue: Dictionary in Tokens.CHART_CUES:
		dashes[str(cue["dash"])] = true
		markers[str(cue["marker"])] = true
	assert_eq(dashes.size(), 5, "five distinct chart dash patterns")
	assert_eq(markers.size(), 5, "five distinct chart markers")


func test_every_one_line_const_parses_for_python_bake() -> void:
	var source := FileAccess.get_file_as_string(TOKENS_PATH)
	assert_ne(source, "", "tokens.gd is readable")
	var regex := RegEx.create_from_string(ONE_LINE_REGEX)
	var seen: Dictionary[String, bool] = {}
	for raw_line: String in source.split("\n"):
		var line := raw_line.strip_edges()
		if not line.begins_with("const ") or line.find(":=") == -1:
			continue
		var matched := regex.search(line)
		assert_not_null(matched, "bake regex must parse line: " + line)
		if matched != null:
			seen[matched.get_string(1)] = true

	for required: String in [
		"BG", "PANEL_BG", "PANEL_HEAD", "CARD_BG", "LINE", "TEXT", "MUTED", "FAINT",
		"GOLD", "GOOD", "BAD", "WARN", "INFO", "INK", "SHADE", "ROW_HOVER", "RULE",
		"BUTTON", "BUTTON_HOT", "BUTTON_OFF", "TOGGLE", "TOGGLE_HOT",
		"PRIMARY", "PRIMARY_HOT", "PRIMARY_INK", "DANGER", "DANGER_HOT",
		"LEATHER", "WOOD", "WOOD_DARK", "BRASS", "BRASS_HI", "BRASS_LO", "SLOT",
		"VELLUM", "VELLUM_INK", "VELLUM_MUTED", "SEAL", "LAPIS", "VELVET", "GLOW",
		"GOOD_INK", "BAD_INK", "WARN_INK", "GOLD_INK", "INK_LINE",
		"CHART_IRON", "CHART_LAPIS", "CHART_MADDER", "CHART_VERDIGRIS", "CHART_OCHRE",
		"MAP_SELECT", "MAP_REACH", "MAP_REACH_NEXT", "MAP_PATH", "MAP_PATH_WARN", "MAP_PATH_INK",
		"WAR_DIAL", "WAR_DIAL_TRACK", "AREA_INK_ALPHA",
		"S1", "S2", "S3", "S4", "S5", "S6",
		"BAR_H", "BUTTON_H", "BUTTON_SM_H", "BUTTON_LG_H", "BUTTON_MENU_H",
		"MEDAL", "MEDAL_SM", "PANEL_W", "TARGET_MIN", "MENU_COLUMN_X",
	]:
		assert_true(seen.has(required), "parsed one-line constant " + required)


func test_war_tokens_read_on_their_track_in_both_themes() -> void:
	# m7-build-spec.md 6.2: the siege dial reads on its track; the high-contrast pair keeps the same rule.
	assert_gte(Tokens.contrast_ratio(Tokens.WAR_DIAL, Tokens.WAR_DIAL_TRACK), 4.5, "the siege dial reads on its track")
	assert_gte(
		Tokens.contrast_ratio(Tokens.HIGH_CONTRAST["WAR_DIAL"], Tokens.HIGH_CONTRAST["WAR_DIAL_TRACK"]),
		3.0,
		"the high-contrast dial reads on its track (non-text, 3:1)",
	)
	assert_gte(
		Tokens.contrast_ratio(Tokens.HIGH_CONTRAST["WAR_DIAL_TRACK"], Tokens.HIGH_CONTRAST["PANEL_BG"]),
		3.0,
		"the empty track is visible on the high-contrast panel",
	)
	assert_almost_eq(Tokens.AREA_INK_ALPHA, 0.9, 0.0001, "castle-area ink alpha")
