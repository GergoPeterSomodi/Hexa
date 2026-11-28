## Tests for the generated Studiolo Theme and High-Contrast Theme
## (docs/architecture/ui-style-and-feedback-spec.md sections 4.3, 4.7, 4.9 and 11).
extends GutTest

const SYMBOLS_ALL := "−·×%"
const SYMBOLS_ARROWS := "→↑↓"


func _load_pieces() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KitTheme.KIT_JSON))
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "ui_kit.json reads as Dictionary")
	return (parsed as Dictionary).get("pieces", {}) as Dictionary


func _collect_geography_chars() -> PackedStringArray:
	var seen: Dictionary[String, bool] = {}
	var dir := DirAccess.open("res://data/geography")
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if entry.ends_with(".json"):
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/geography/" + entry))
				_walk_json_strings(parsed, seen)
			entry = dir.get_next()
		dir.list_dir_end()
	var out: PackedStringArray = []
	for ch: String in seen:
		out.append(ch)
	out.sort()
	return out


func _walk_json_strings(node: Variant, seen: Dictionary[String, bool]) -> void:
	if typeof(node) == TYPE_STRING:
		var s := str(node)
		for i: int in s.length():
			if s.unicode_at(i) >= 0x20 and s.unicode_at(i) != 0xAD:
				seen[s[i]] = true
	elif typeof(node) == TYPE_ARRAY:
		for item: Variant in (node as Array):
			_walk_json_strings(item, seen)
	elif typeof(node) == TYPE_DICTIONARY:
		var dict := node as Dictionary
		for k: Variant in dict:
			var ks := str(k)
			if ks in ["name", "names", "title", "label", "capital", "city", "town", "region", "country", "river", "pass", "tribe", "market"] or typeof(dict[k]) in [TYPE_ARRAY, TYPE_DICTIONARY]:
				_walk_json_strings(dict[k], seen)


func test_both_themes_load_and_contain_all_variations() -> void:
	var studiolo := load(KitTheme.THEME_PATH) as Theme
	var hc := load(KitTheme.HIGH_CONTRAST_PATH) as Theme
	assert_not_null(studiolo, "theme.tres loads")
	assert_not_null(hc, "theme_high_contrast.tres loads")
	if studiolo == null or hc == null:
		return

	for label: String in ["studiolo", "high_contrast"]:
		var theme := studiolo if label == "studiolo" else hc
		for var_name: String in Tokens.TYPE_VARIATIONS:
			var tname := StringName(var_name)
			assert_true(theme.has_font(&"font", tname), "%s has font for %s" % [label, var_name])
			assert_true(theme.has_font_size(&"font_size", tname), "%s has font_size for %s" % [label, var_name])
			assert_true(theme.has_color(&"font_color", tname), "%s has font_color for %s" % [label, var_name])

		for alias_name: String in ["HexTitle", "HexSection", "HexKey", "HexValue", "HexReason"]:
			var aname := StringName(alias_name)
			assert_eq(theme.get_type_variation_base(aname), &"", "%s removed Hex alias %s" % [label, alias_name])
			assert_false(Array(theme.get_type_list()).has(alias_name), "%s has no Hex alias type %s" % [label, alias_name])

		for style_name: String in Tokens.STYLE_VARIATIONS:
			var spec: Dictionary = Tokens.STYLE_VARIATIONS[style_name]
			var base_type := str(spec["base_type"])
			var sname := StringName(style_name)
			if style_name != base_type:
				assert_eq(theme.get_type_variation_base(sname), StringName(base_type), "%s %s base_type" % [label, style_name])
			if base_type == "PanelContainer":
				assert_true(theme.has_stylebox(&"panel", sname), "%s %s has panel stylebox" % [label, style_name])
			elif base_type == "Button":
				assert_true(theme.has_stylebox(&"normal", sname), "%s %s has normal stylebox" % [label, style_name])
				assert_true(theme.has_stylebox(&"pressed", sname), "%s %s has pressed stylebox" % [label, style_name])
			elif base_type == "Tree":
				assert_true(theme.has_stylebox(&"selected", sname), "%s %s has selected stylebox" % [label, style_name])
				assert_true(theme.has_color(&"guide_color", sname), "%s %s has guide_color" % [label, style_name])

		for extra_panel: StringName in [&"PanelPlate", &"PanelDebug", &"PanelShade", &"KeyCapPanel", &"KeyCapPanelWait", &"PanelMinimap"]:
			assert_true(theme.has_stylebox(&"panel", extra_panel), "%s has %s" % [label, str(extra_panel)])
		if label == "studiolo":
			var minimap_sb := theme.get_stylebox(&"panel", &"PanelMinimap") as StyleBoxTexture
			assert_not_null(minimap_sb, "studiolo PanelMinimap is StyleBoxTexture")
			if minimap_sb != null:
				assert_true(minimap_sb.texture.resource_path.ends_with("minimap_frame.png"), "PanelMinimap uses minimap_frame.png")
		else:
			assert_true(theme.get_stylebox(&"panel", &"PanelMinimap") is StyleBoxFlat, "HC PanelMinimap is StyleBoxFlat")
		assert_eq(theme.get_type_variation_base(&"KitSwitch"), &"CheckButton", "%s has KitSwitch" % label)

		var chart_colors: Dictionary = (Tokens.STYLE_VARIATIONS["InkChart"] as Dictionary)["colors"]
		for ckey: String in chart_colors:
			assert_true(theme.has_color(StringName(ckey), &"InkChart"), "%s InkChart has color %s" % [label, ckey])
		assert_true(theme.has_font(&"font", &"InkChart"), "%s InkChart has font" % label)

		for base_ctrl: StringName in [&"Label", &"RichTextLabel", &"Button", &"CheckButton", &"OptionButton", &"LineEdit", &"HSlider", &"ProgressBar", &"ScrollContainer", &"VScrollBar", &"HScrollBar", &"HSeparator", &"VSeparator", &"PanelContainer", &"PopupPanel", &"PopupMenu", &"TooltipPanel", &"TooltipLabel", &"Tree"]:
			assert_true(
				theme.get_stylebox_list(base_ctrl).size() > 0 or theme.get_font_list(base_ctrl).size() > 0 or theme.get_icon_list(base_ctrl).size() > 0,
				"%s styles base control %s" % [label, str(base_ctrl)]
			)


func test_high_contrast_uses_flat_styleboxes_and_no_menu_art_in_theme() -> void:
	var hc := load(KitTheme.HIGH_CONTRAST_PATH) as Theme
	for type_name: StringName in hc.get_stylebox_type_list():
		for sb_name: StringName in hc.get_stylebox_list(type_name):
			var sb := hc.get_stylebox(sb_name, type_name)
			assert_false(sb is StyleBoxTexture, "high contrast %s/%s must not be StyleBoxTexture" % [type_name, sb_name])

	var panel_sb := hc.get_stylebox(&"panel", &"PanelContainer") as StyleBoxFlat
	assert_not_null(panel_sb, "HC PanelContainer is StyleBoxFlat")
	assert_eq(panel_sb.bg_color, Color("#000000"))
	assert_eq(panel_sb.border_color, Color("#ffd646"))
	assert_eq(panel_sb.border_width_left, 2)
	assert_eq(hc.get_color(&"font_color", &"Label"), Color("#ffffff"))

	var focus_sb := hc.get_stylebox(&"focus", &"Button") as StyleBoxFlat
	assert_not_null(focus_sb, "HC focus is StyleBoxFlat")
	assert_eq(focus_sb.border_color, Tokens.HIGH_CONTRAST["INFO"])
	assert_eq(focus_sb.border_width_left, 3)

	var theme_text := FileAccess.get_file_as_string(KitTheme.THEME_PATH)
	assert_false(theme_text.contains("menu_bg.png"), "theme.tres does not preload menu_bg")
	assert_false(theme_text.contains("menu_shade.png"), "theme.tres does not preload menu_shade")


func test_stylebox_texture_margins_match_ui_kit_json() -> void:
	var studiolo := load(KitTheme.THEME_PATH) as Theme
	var pieces := _load_pieces()
	var checked := 0
	for type_name: StringName in studiolo.get_stylebox_type_list():
		for sb_name: StringName in studiolo.get_stylebox_list(type_name):
			var sb := studiolo.get_stylebox(sb_name, type_name)
			if not (sb is StyleBoxTexture):
				continue
			var sbt := sb as StyleBoxTexture
			assert_not_null(sbt.texture, "%s/%s StyleBoxTexture has texture" % [type_name, sb_name])
			var piece_name := sbt.texture.resource_path.get_file().get_basename()
			assert_true(pieces.has(piece_name), "ui_kit.json has piece " + piece_name)
			if not pieces.has(piece_name):
				continue
			var piece: Dictionary = pieces[piece_name]
			var margin: Array = piece["margin"]
			var expand: Array = piece["expand"]
			assert_eq(sbt.texture_margin_left, float(margin[0]), "%s margin left" % piece_name)
			assert_eq(sbt.texture_margin_top, float(margin[1]), "%s margin top" % piece_name)
			assert_eq(sbt.texture_margin_right, float(margin[2]), "%s margin right" % piece_name)
			assert_eq(sbt.texture_margin_bottom, float(margin[3]), "%s margin bottom" % piece_name)
			assert_eq(sbt.expand_margin_left, float(expand[0]), "%s expand left" % piece_name)
			assert_eq(sbt.expand_margin_top, float(expand[1]), "%s expand top" % piece_name)
			assert_eq(sbt.expand_margin_right, float(expand[2]), "%s expand right" % piece_name)
			assert_eq(sbt.expand_margin_bottom, float(expand[3]), "%s expand bottom" % piece_name)
			checked += 1
	assert_gt(checked, 20, "verified all StyleBoxTextures against ui_kit.json")


func test_fonts_pass_has_char_and_tabular_digits_and_tracking() -> void:
	var studiolo := load(KitTheme.THEME_PATH) as Theme
	var geo_chars := _collect_geography_chars()
	assert_gt(geo_chars.size(), 50, "collected geography characters")

	for var_name: String in Tokens.TYPE_VARIATIONS:
		var spec: Dictionary = Tokens.TYPE_VARIATIONS[var_name]
		var font := studiolo.get_font(&"font", StringName(var_name))
		assert_not_null(font, "font exists for " + var_name)
		for cp: int in range(0x20, 0x7F):
			assert_true(font.has_char(cp), "%s has ASCII %d" % [var_name, cp])
		for cp: int in range(0xA0, 0x180):
			assert_true(font.has_char(cp), "%s has Latin-1/Ext-A U+%04X" % [var_name, cp])
		for i: int in SYMBOLS_ALL.length():
			assert_true(font.has_char(SYMBOLS_ALL[i].unicode_at(0)), "%s has %s" % [var_name, SYMBOLS_ALL[i]])
		if str(spec["font"]) != "cinzel_bold":
			for i: int in SYMBOLS_ARROWS.length():
				assert_true(font.has_char(SYMBOLS_ARROWS[i].unicode_at(0)), "%s has arrow %s" % [var_name, SYMBOLS_ARROWS[i]])
		for ch: String in geo_chars:
			assert_true(font.has_char(ch.unicode_at(0)), "%s has geo char %s" % [var_name, ch])

		if str(spec["font"]) == "cinzel_bold":
			var fv := font as FontVariation
			assert_not_null(fv, var_name + " is FontVariation")
			var expected_px := roundi(float(spec["size"]) * float(spec["tracking_em"]))
			assert_eq(fv.spacing_glyph, expected_px, "%s tracking_glyph=%d" % [var_name, expected_px])

	var num_font := studiolo.get_font(&"font", &"Number")
	var num_size := studiolo.get_font_size(&"font_size", &"Number")
	var w1 := num_font.get_string_size("1111", HORIZONTAL_ALIGNMENT_LEFT, -1, num_size).x
	var w0 := num_font.get_string_size("0000", HORIZONTAL_ALIGNMENT_LEFT, -1, num_size).x
	var w8 := num_font.get_string_size("8888", HORIZONTAL_ALIGNMENT_LEFT, -1, num_size).x
	assert_almost_eq(w1, w0, 0.01, "Number 1111 width equals 0000 width")
	assert_almost_eq(w1, w8, 0.01, "Number 1111 width equals 8888 width")


func test_kit_icons_exist_in_theme_and_high_contrast() -> void:
	var studiolo := load(KitTheme.THEME_PATH) as Theme
	var hc := load(KitTheme.HIGH_CONTRAST_PATH) as Theme
	var pieces := _load_pieces()

	for icon_name: String in ["seal", "stud", "glow_soft", "rule_diamond", "rose", "wordmark", "switch_off", "switch_on", "grabber", "grabber_hot", "shield_rim", "shield_rim_sm", "pennant_pole", "pennant_cloth"]:
		assert_true(studiolo.has_icon(StringName(icon_name), &"Kit"), "studiolo Kit has " + icon_name)
		var tex := studiolo.get_icon(StringName(icon_name), &"Kit")
		assert_not_null(tex, "Kit icon %s is non-null" % icon_name)

	var m2_sizes: Dictionary[String, Vector2] = {
		"shield_rim": Vector2(48.0, 56.0),
		"shield_rim_sm": Vector2(20.0, 24.0),
		"pennant_pole": Vector2(24.0, 56.0),
		"pennant_cloth": Vector2(28.0, 20.0),
	}
	var theme_2x := KitTheme.load_for(2.0, &"2x", false)
	for m2_name: String in m2_sizes:
		var expected_sz: Vector2 = m2_sizes[m2_name]
		var tex_1x := studiolo.get_icon(StringName(m2_name), &"Kit")
		assert_eq(tex_1x.get_size(), expected_sz, "1x Kit icon %s size" % m2_name)
		var tex_2x := theme_2x.get_icon(StringName(m2_name), &"Kit")
		assert_not_null(tex_2x, "2x Kit icon %s non-null" % m2_name)
		assert_eq(tex_2x.get_size(), expected_sz, "2x Kit icon %s logical size override" % m2_name)
		assert_eq(tex_2x.get_image().get_size(), Vector2i(int(expected_sz.x) * 2, int(expected_sz.y) * 2), "2x Kit icon %s backing pixels" % m2_name)

	var minimap_sb_2x := theme_2x.get_stylebox(&"panel", &"PanelMinimap") as StyleBoxTexture
	assert_not_null(minimap_sb_2x, "2x PanelMinimap is StyleBoxTexture")
	assert_eq(minimap_sb_2x.texture.get_size(), Vector2(256.0, 144.0), "2x minimap_frame logical size")
	assert_eq(minimap_sb_2x.texture.get_image().get_size(), Vector2i(512, 288), "2x minimap_frame backing pixels")

	var base_icons: Array = (pieces["icons_base"] as Dictionary).get("icons", [])
	for name_var: Variant in base_icons:
		var iname := StringName(str(name_var))
		assert_true(studiolo.has_icon(iname, &"Kit"), "studiolo Kit has slice " + str(iname))
		assert_true(hc.has_icon(iname, &"Kit"), "HC Kit has slice " + str(iname))
		var atlas := studiolo.get_icon(iname, &"Kit") as AtlasTexture
		assert_not_null(atlas, "%s is AtlasTexture" % str(iname))
		assert_eq(atlas.get_size(), Vector2(16.0, 16.0), "%s logical size is 16x16" % str(iname))

	assert_true(studiolo.has_icon(&"fit", &"Kit"), "Kit has fit alias")
	assert_false(hc.has_icon(&"wordmark", &"Kit"), "HC low-memory skips heavy wordmark texture")
	assert_false(hc.has_icon(&"rose", &"Kit"), "HC low-memory skips heavy rose texture")


func test_committed_themes_match_live_builder_properties() -> void:
	var committed := load(KitTheme.THEME_PATH) as Theme
	var rebuilt := KitTheme.build_studiolo()
	for var_name: String in Tokens.TYPE_VARIATIONS:
		var tname := StringName(var_name)
		assert_eq(committed.get_font_size(&"font_size", tname), rebuilt.get_font_size(&"font_size", tname), var_name)
		assert_eq(committed.get_color(&"font_color", tname), rebuilt.get_color(&"font_color", tname), var_name)
	for style_name: String in Tokens.STYLE_VARIATIONS:
		var sname := StringName(style_name)
		assert_eq(committed.get_type_variation_base(sname), rebuilt.get_type_variation_base(sname), style_name)

func test_slice3_kit_icons_and_end_season_plate() -> void:
	# Spec 4.5 slice 3: medallions, dial, hourglass and seal tones are Kit icons at their size, 1x and 2x.
	var studiolo := load(KitTheme.THEME_PATH) as Theme
	var pieces := _load_pieces()
	var sizes: Dictionary[String, Vector2] = {
		"medallion_64": Vector2(64.0, 64.0),
		"medallion_30": Vector2(30.0, 30.0),
		"dial_quarters": Vector2(64.0, 64.0),
		"dial_hand": Vector2(64.0, 64.0),
		"hourglass": Vector2(24.0, 24.0),
		"seal_good": Vector2(72.0, 72.0),
		"seal_plain": Vector2(72.0, 72.0),
		"seal_cracked": Vector2(72.0, 72.0),
	}
	var theme_2x := KitTheme.load_for(2.0, &"2x", false)
	for icon_name: String in sizes:
		var expected: Vector2 = sizes[icon_name]
		assert_true(studiolo.has_icon(StringName(icon_name), &"Kit"), "studiolo Kit has " + icon_name)
		var tex_1x := studiolo.get_icon(StringName(icon_name), &"Kit")
		assert_not_null(tex_1x, "1x Kit icon %s non-null" % icon_name)
		assert_eq(tex_1x.get_size(), expected, "1x %s size" % icon_name)
		var tex_2x := theme_2x.get_icon(StringName(icon_name), &"Kit")
		assert_not_null(tex_2x, "2x Kit icon %s non-null" % icon_name)
		assert_eq(tex_2x.get_size(), expected, "2x %s logical size" % icon_name)
		assert_eq(tex_2x.get_image().get_size(), Vector2i(int(expected.x) * 2, int(expected.y) * 2), "2x %s backing pixels" % icon_name)

	# End season plate: four states, the plate's own margins, a StyleBoxTexture on ButtonEndSeason.
	for state: String in ["normal", "hot", "pressed", "off"]:
		assert_true(pieces.has("endseason_plate_" + state), "ui_kit.json has endseason_plate_" + state)
	var end_piece: Dictionary = pieces["endseason_plate_normal"]
	assert_eq(end_piece["size"], [160.0, 44.0], "plate size")
	assert_eq(end_piece["margin"], [28.0, 22.0, 44.0, 22.0], "plate margins (spec 4.5)")
	assert_eq(end_piece["expand"], [0.0, 0.0, 0.0, 0.0], "plate expand")
	assert_eq(end_piece["slice"], 3, "plate is slice 3")
	var plate := studiolo.get_stylebox(&"normal", &"ButtonEndSeason") as StyleBoxTexture
	assert_not_null(plate, "ButtonEndSeason normal is a StyleBoxTexture")
	if plate != null:
		assert_eq(plate.texture.resource_path.get_file(), "endseason_plate_normal.png", "ButtonEndSeason uses the plate")


func test_slice4_icons_and_feedback_frames() -> void:
	# Spec 6.2: the icons of the `icons` atlas are 24 px Kit icons at 1x and 2x (study and info are `_24`, the 16 px names stay).
	# The atlas lists 49 names: the 48 of the spec, and `log` (the action log's button, kit_theme KIT_GRID_ICONS), added later.
	var studiolo := load(KitTheme.THEME_PATH) as Theme
	var hc := load(KitTheme.HIGH_CONTRAST_PATH) as Theme
	var pieces := _load_pieces()
	var names: Array = (pieces["icons"] as Dictionary)["icons"]
	assert_eq(names.size(), 49, "49 icons: the spec's 48 and log")
	var theme_2x := KitTheme.load_for(2.0, &"2x", false)
	for n: Variant in names:
		var iname := StringName(str(n) + "_24" if str(n) in ["study", "info"] else str(n))
		for pair: Array in [["studiolo", studiolo], ["hc", hc], ["2x", theme_2x]]:
			var th: Theme = pair[1]
			assert_true(th.has_icon(iname, &"Kit"), "%s has icon %s" % [pair[0], iname])
		assert_eq(studiolo.get_icon(iname, &"Kit").get_size(), Vector2(24.0, 24.0), "%s is 24 px" % iname)
		assert_eq(theme_2x.get_icon(iname, &"Kit").get_size(), Vector2(24.0, 24.0), "%s 2x logical size" % iname)
		assert_eq(theme_2x.get_icon(iname, &"Kit").get_image().get_size(), Vector2i(48, 48), "%s 2x pixels" % iname)
	assert_eq((studiolo.get_icon(&"study", &"Kit") as Texture2D).get_size(), Vector2(16.0, 16.0), "icons_base study stays 16 px")
	for frame: String in ["PanelVellumInset", "PanelStripCell", "PanelStripCellNow"]:
		var sb := studiolo.get_stylebox(&"panel", StringName(frame)) as StyleBoxTexture
		assert_not_null(sb, "%s is a baked StyleBoxTexture" % frame)
	var inset := studiolo.get_stylebox(&"panel", &"PanelVellumInset") as StyleBoxTexture
	assert_eq(inset.texture.resource_path.get_file(), "vellum_inset.png", "inset texture")
	assert_eq(inset.texture_margin_left, 16.0, "inset margin")
	var cell := studiolo.get_stylebox(&"panel", &"PanelStripCellNow") as StyleBoxTexture
	assert_eq(cell.texture_margin_left, 12.0, "strip cell margin")
	for colour: String in ["ink_0", "ink_4", "axis", "grid", "good", "bad", "ink_2_slot"]:
		assert_true(studiolo.has_color(StringName(colour), &"InkChart"), "InkChart has " + colour)


func test_slice5_army_pieces_are_kit_icons() -> void:
	# m6-build-spec.md 6.2: plate, ring, badge and route stop are whole icons; the figures (32 px) and army icons (24 px) are atlas cells.
	var studiolo := load(KitTheme.THEME_PATH) as Theme
	var hc := load(KitTheme.HIGH_CONTRAST_PATH) as Theme
	var theme_2x := KitTheme.load_for(2.0, &"2x", false)
	var pieces := _load_pieces()
	var direct: Dictionary = {"army_plate": Vector2(56, 48), "army_plate_ring": Vector2(64, 56), "army_badge": Vector2(36, 18), "path_stop": Vector2(20, 20)}
	for key: String in direct:
		var size: Vector2 = direct[key]
		for pair: Array in [["studiolo", studiolo], ["hc", hc], ["2x", theme_2x]]:
			var th: Theme = pair[1]
			assert_true(th.has_icon(StringName(key), &"Kit"), "%s has %s" % [pair[0], key])
			assert_eq(th.get_icon(StringName(key), &"Kit").get_size(), size, "%s logical size in %s" % [key, pair[0]])
		assert_eq(theme_2x.get_icon(StringName(key), &"Kit").get_image().get_size(), Vector2i(size * 2.0), "%s 2x pixels" % key)
	var atlases: Dictionary = {"figures": [4, 32], "icons_army": [16, 24]}
	for atlas: String in atlases:
		var names: Array = (pieces[atlas] as Dictionary)["icons"]
		assert_eq(names.size(), int((atlases[atlas] as Array)[0]), "%s has its cells" % atlas)
		var cell: int = (atlases[atlas] as Array)[1]
		for n: Variant in names:
			var iname := StringName(str(n))
			for pair: Array in [["studiolo", studiolo], ["hc", hc], ["2x", theme_2x]]:
				assert_true((pair[1] as Theme).has_icon(iname, &"Kit"), "%s has icon %s" % [pair[0], iname])
			assert_eq(studiolo.get_icon(iname, &"Kit").get_size(), Vector2(cell, cell), "%s is %d px" % [iname, cell])
			assert_eq(theme_2x.get_icon(iname, &"Kit").get_image().get_size(), Vector2i(cell * 2, cell * 2), "%s 2x pixels" % iname)


func test_unit_figures_of_option_d_are_kit_icons() -> void:
	# recruitment-queue.md 12.2 UR1: every kind has its full and simplified figure, their tint cells and its far sign, in
	# every theme, at its logical size, with 2x pixels in the 2x theme. Problems are gathered, then asserted once.
	var studiolo := load(KitTheme.THEME_PATH) as Theme
	var hc := load(KitTheme.HIGH_CONTRAST_PATH) as Theme
	var theme_2x := KitTheme.load_for(2.0, &"2x", false)
	var pieces := _load_pieces()
	var problems: PackedStringArray = []
	var names: Array = []
	for kind: StringName in UnitDef.FIGURE_NAMES:
		for level: String in ["full", "simple"]:
			names.append(["%s_%s" % [kind, level], 64])
			names.append(["%s_%s_tint" % [kind, level], 64])
		names.append(["sign_%s" % str(kind).trim_prefix("fig_"), 24])
	for atlas: String in ["unit_figures", "unit_figures_tint", "unit_signs"]:
		for n: Variant in (pieces[atlas] as Dictionary)["icons"]:
			if not names.any(func(e: Array) -> bool: return str(e[0]) == str(n)):
				problems.append("%s names an unexpected cell %s" % [atlas, n])
	for entry: Array in names:
		var iname := StringName(str(entry[0]))
		var px: int = entry[1]
		for pair: Array in [["studiolo", studiolo], ["hc", hc], ["2x", theme_2x]]:
			if not (pair[1] as Theme).has_icon(iname, &"Kit"):
				problems.append("%s lacks %s" % [pair[0], iname])
		if studiolo.has_icon(iname, &"Kit") and studiolo.get_icon(iname, &"Kit").get_size() != Vector2(px, px):
			problems.append("%s is not %d px" % [iname, px])
		if theme_2x.has_icon(iname, &"Kit") and theme_2x.get_icon(iname, &"Kit").get_image().get_size() != Vector2i(px * 2, px * 2):
			problems.append("%s has no 2x pixels" % iname)
	assert_eq(names.size(), 20, "4 kinds x (2 levels x 2 layers + 1 sign)")
	assert_eq(problems, PackedStringArray(), "every unit figure, tint cell and sign is a Kit icon")


func test_the_map_views_delta_tints_are_the_token_colours() -> void:
	assert_eq(MapModes.DELTA_GOOD, Tokens.GOOD)
	assert_eq(MapModes.DELTA_BAD, Tokens.BAD)


func test_slice6_war_pieces_are_kit_icons() -> void:
	# m7-build-spec.md 6.2: two badges and the die face are whole icons; the war icons are 24 px atlas cells.
	var studiolo := load(KitTheme.THEME_PATH) as Theme
	var hc := load(KitTheme.HIGH_CONTRAST_PATH) as Theme
	var theme_2x := KitTheme.load_for(2.0, &"2x", false)
	var pieces := _load_pieces()
	var direct: Dictionary = {"badge_battle": Vector2(40, 40), "badge_siege": Vector2(40, 40), "die_face": Vector2(28, 28)}
	for key: String in direct:
		var size: Vector2 = direct[key]
		for pair: Array in [["studiolo", studiolo], ["hc", hc], ["2x", theme_2x]]:
			var th: Theme = pair[1]
			assert_true(th.has_icon(StringName(key), &"Kit"), "%s has %s" % [pair[0], key])
			assert_eq(th.get_icon(StringName(key), &"Kit").get_size(), size, "%s logical size in %s" % [key, pair[0]])
		assert_eq(theme_2x.get_icon(StringName(key), &"Kit").get_image().get_size(), Vector2i(size * 2.0), "%s 2x pixels" % key)
	var names: Array = (pieces["icons_war"] as Dictionary)["icons"]
	assert_eq(names.size(), 24, "icons_war has its 24 cells")
	for n: Variant in names:
		var iname := StringName(str(n))
		for pair: Array in [["studiolo", studiolo], ["hc", hc], ["2x", theme_2x]]:
			assert_true((pair[1] as Theme).has_icon(iname, &"Kit"), "%s has icon %s" % [pair[0], iname])
		assert_eq(studiolo.get_icon(iname, &"Kit").get_size(), Vector2(24, 24), "%s is 24 px" % iname)
		assert_eq(theme_2x.get_icon(iname, &"Kit").get_image().get_size(), Vector2i(48, 48), "%s 2x pixels" % iname)
