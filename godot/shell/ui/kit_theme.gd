## Studiolo Theme builder and 1x / 2x / high-contrast loader (docs/architecture/ui-style-and-feedback-spec.md
## sections 4.3, 4.7, 4.8 and 4.9).
##
## Builds `theme.tres` (1x Studiolo textures + fonts) and `theme_high_contrast.tres` (flat `StyleBoxFlat`
## high-contrast / low-memory theme), and swaps 1x kit textures for 2x `ImageTexture`s with
## `set_size_override(logical_size)` when UI scale >= 1.5 or `kit_mode == &"2x"`.
class_name KitTheme
extends RefCounted

const THEME_PATH := "res://shell/ui/theme.tres"
const HIGH_CONTRAST_PATH := "res://shell/ui/theme_high_contrast.tres"
const KIT_JSON := "res://assets/ui/kit/ui_kit.json"
const KIT_1X_DIR := "res://assets/ui/kit/1x/"
const KIT_2X_DIR := "res://assets/ui/kit/2x/"

const KIT_DIRECT_ICONS: Array[String] = [
	"seal",
	"stud",
	"glow_soft",
	"rule_diamond",
	"rose",
	"wordmark",
	"switch_off",
	"switch_on",
	"grabber",
	"grabber_hot",
	"icons_base",
	"shield_rim",
	"shield_rim_sm",
	"pennant_pole",
	"pennant_cloth",
]

## Names of the 24 px `icons` atlas registered as Kit theme icons (the action log's button).
const KIT_GRID_ICONS: Array[String] = ["log"]

const ICON_ALIASES: Dictionary[String, String] = {
	"fit": "zoom_fit",
}

const PANEL_VARIATION_PIECES: Dictionary[String, String] = {
	"PanelModal": "panel_modal",
	"PanelVellum": "panel_vellum",
	"PanelVellumInset": "vellum_inset",
	"PanelCard": "panel_card",
	"PanelBar": "panel_bar",
	"PanelRibbon": "ribbon",
	"PanelToast": "toast",
	"PanelCartouche": "cartouche",
	"PanelMinimap": "minimap_frame",
	"PanelSlot": "slot",
	"PanelPlate": "plate",
	"PanelStripCell": "strip_cell",
	"PanelStripCellNow": "strip_cell_now",
	"KeyCapPanel": "keycap",
	"KeyCapPanelWait": "keycap_wait",
}


## Builds the full 1x Studiolo Theme from `Tokens`, `ui_kit.json`, and the imported static fonts.
static func build_studiolo() -> Theme:
	return _build(false)


## Builds the flat `StyleBoxFlat` high-contrast / low-memory Theme from `Tokens.HIGH_CONTRAST`.
## Uses black fields, 21:1 white text, 2 px `#ffd646` borders, 3 px `INFO` focus rings, and icon atlases only.
static func build_high_contrast() -> Theme:
	return _build(true)


## Returns the Theme matching `ui_scale`, `kit_mode` (`"auto"`, `"1x"`, `"2x"`, `"plain"`), and `high_contrast`.
## For 2x, duplicates `theme.tres` and wraps every 2x texture with `ImageTexture.set_size_override(logical_size)`
## so 9-slice margins and layouts remain identical while 2x pixels sample 1:1.
static func load_for(ui_scale: float, kit_mode: StringName = &"auto", high_contrast: bool = false) -> Theme:
	if high_contrast or kit_mode == &"plain":
		if ResourceLoader.exists(HIGH_CONTRAST_PATH):
			var hc := load(HIGH_CONTRAST_PATH) as Theme
			if hc != null:
				return hc
		return build_high_contrast()

	var base: Theme = null
	if ResourceLoader.exists(THEME_PATH):
		base = load(THEME_PATH) as Theme
	if base == null:
		base = build_studiolo()

	var use_2x := (kit_mode == &"2x") or (kit_mode == &"auto" and ui_scale >= 1.5)
	if not use_2x:
		return base

	var theme_2x := base.duplicate(true) as Theme
	_apply_2x_textures(theme_2x, _load_kit_pieces())
	return theme_2x


static func _build(hc: bool) -> Theme:
	var theme := Theme.new()
	var pieces := _load_kit_pieces()
	var font_cache := _build_font_cache()
	var tex_cache: Dictionary[String, Texture2D] = {}

	theme.default_font = _get_font_var(font_cache, "alegreya_sans_medium", 0, true)
	theme.default_font_size = 14

	_apply_typography(theme, font_cache, hc)
	_apply_base_controls(theme, font_cache, pieces, tex_cache, hc)
	_apply_panels(theme, pieces, tex_cache, hc)
	_apply_buttons(theme, font_cache, pieces, tex_cache, hc)
	_apply_composites(theme, font_cache, hc)
	_apply_kit_icons(theme, pieces, tex_cache, hc)
	return theme


static func _load_kit_pieces() -> Dictionary:
	if not FileAccess.file_exists(KIT_JSON):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KIT_JSON))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var pieces_var: Variant = (parsed as Dictionary).get("pieces", {})
	if typeof(pieces_var) != TYPE_DICTIONARY:
		return {}
	return pieces_var as Dictionary


static func _build_font_cache() -> Dictionary:
	var base_fonts: Dictionary[String, FontFile] = {}
	for key: String in Tokens.FONTS:
		var f := load(Tokens.FONTS[key]) as FontFile
		if f != null:
			base_fonts[key] = f
	var ts := TextServerManager.get_primary_interface()
	var variations: Dictionary[String, FontVariation] = {}
	return {
		"base": base_fonts,
		"noto": base_fonts.get("fallback", null),
		"lnum": ts.name_to_tag("lnum"),
		"tnum": ts.name_to_tag("tnum"),
		"variations": variations,
	}


static func _get_font_var(cache: Dictionary, font_key: String, spacing_px: int, tabular: bool) -> FontVariation:
	var cache_key := "%s|%d|%s" % [font_key, spacing_px, str(tabular)]
	var variations: Dictionary = cache["variations"]
	if variations.has(cache_key):
		return variations[cache_key] as FontVariation
	var base_fonts: Dictionary = cache["base"]
	var fv := FontVariation.new()
	var base_font: FontFile = base_fonts.get(font_key, null) as FontFile
	if base_font != null:
		fv.base_font = base_font
	var noto: FontFile = cache["noto"] as FontFile
	if noto != null and font_key != "fallback":
		var fallbacks: Array[Font] = [noto]
		fv.fallbacks = fallbacks
	if tabular or font_key.begins_with("alegreya_sans") or font_key == "alegreya_sc_bold":
		fv.opentype_features = {int(cache["lnum"]): 1, int(cache["tnum"]): 1}
	if spacing_px != 0:
		fv.spacing_glyph = spacing_px
	variations[cache_key] = fv
	return fv


## Populates all typography variations from `Tokens.TYPE_VARIATIONS`.
## Note: Cinzel variations (`TitleRibbon`, `TitleModal`, `TitleBrand`, `TitlePanel`, `ButtonMenu`)
## expect upper-cased strings at call sites (spec 4.3).
static func _apply_typography(theme: Theme, font_cache: Dictionary, hc: bool) -> void:
	for var_name: String in Tokens.TYPE_VARIATIONS:
		var spec: Dictionary = Tokens.TYPE_VARIATIONS[var_name]
		var base_type := StringName(str(spec["base_type"]))
		var tname := StringName(var_name)
		if tname != base_type:
			theme.set_type_variation(tname, base_type)
		var font_size := int(spec["size"])
		var spacing_px := roundi(float(font_size) * float(spec["tracking_em"]))
		var fv := _get_font_var(font_cache, str(spec["font"]), spacing_px, bool(spec["tabular"]))
		theme.set_font(&"font", tname, fv)
		theme.set_font_size(&"font_size", tname, font_size)
		theme.set_color(&"font_color", tname, _tok(str(spec["color_token"]), spec["color"] as Color, hc))
		if tname == &"Label":
			theme.set_constant(&"line_spacing", tname, 2)


static func _apply_base_controls(theme: Theme, fc: Dictionary, pieces: Dictionary, tc: Dictionary[String, Texture2D], hc: bool) -> void:
	var f_med := _get_font_var(fc, "alegreya_sans_medium", 0, true)
	var f_bold := _get_font_var(fc, "alegreya_sans_bold", 0, true)
	var f_reg := _get_font_var(fc, "alegreya_sans_regular", 0, true)
	var f_ital := _get_font_var(fc, "alegreya_italic", 0, false)
	var f_sc := _get_font_var(fc, "alegreya_sc_bold", 0, true)

	_apply_text_controls(theme, f_med, f_bold, f_reg, f_ital, hc)
	theme.set_constant(&"separation", &"VBoxContainer", Tokens.S2)
	theme.set_constant(&"separation", &"HBoxContainer", Tokens.S2)
	theme.set_constant(&"h_separation", &"GridContainer", Tokens.S3)
	theme.set_constant(&"v_separation", &"GridContainer", Tokens.S1)

	var c_bg := _tok("BG", Tokens.BG, hc)
	var c_line := _tok("LINE", Tokens.LINE, hc)
	var sb_panel: StyleBox = _make_flat(c_bg, c_line, 2, 16.0, 16.0, 0) if hc else _sb_tex("panel_frame", pieces, tc)
	var sb_card: StyleBox = _make_flat(c_bg, c_line, 2, 10.0, 10.0, 0) if hc else _sb_tex("panel_card", pieces, tc)
	theme.set_type_variation(&"TooltipPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"PanelContainer", sb_panel)
	theme.set_stylebox(&"panel", &"PopupPanel", sb_card)
	theme.set_stylebox(&"panel", &"TooltipPanel", sb_card)

	var sb_focus := _focus_box(pieces, tc, hc)
	_apply_check_and_option(theme, f_med, pieces, tc, sb_focus, hc)
	_apply_slider_and_progress(theme, f_bold, pieces, tc, hc)
	_apply_scrollbars_and_separators(theme, hc)
	_apply_popup_and_tree(theme, f_med, f_sc, sb_card, pieces, tc, hc)


static func _apply_text_controls(theme: Theme, f_med: FontVariation, f_bold: FontVariation, f_reg: FontVariation, f_ital: FontVariation, hc: bool) -> void:
	var c_text := _tok("TEXT", Tokens.TEXT, hc)
	var c_muted := _tok("MUTED", Tokens.MUTED, hc)
	var c_slot := _tok("SLOT", Tokens.SLOT, hc)
	var c_line := _tok("LINE", Tokens.LINE, hc)
	var c_info := _tok("INFO", Tokens.INFO, hc)
	var bw := 2 if hc else 1
	var focus_bw := 3 if hc else 2
	var rad := 0 if hc else 2

	theme.set_font(&"normal_font", &"RichTextLabel", f_med)
	theme.set_font(&"bold_font", &"RichTextLabel", f_bold)
	theme.set_font(&"italics_font", &"RichTextLabel", f_ital)
	theme.set_font(&"bold_italics_font", &"RichTextLabel", f_ital)
	for fs: StringName in [&"normal_font_size", &"bold_font_size", &"italics_font_size", &"bold_italics_font_size"]:
		theme.set_font_size(fs, &"RichTextLabel", 15)
	theme.set_color(&"default_color", &"RichTextLabel", c_text)
	theme.set_stylebox(&"normal", &"RichTextLabel", _make_empty(0.0, 0.0))
	theme.set_stylebox(&"focus", &"RichTextLabel", _make_flat(Color(0, 0, 0, 0), c_info, focus_bw, 2.0, 2.0, 0))

	theme.set_font(&"font", &"LineEdit", f_med)
	theme.set_font_size(&"font_size", &"LineEdit", 14)
	theme.set_color(&"font_color", &"LineEdit", c_text)
	theme.set_color(&"font_placeholder_color", &"LineEdit", c_muted)
	theme.set_color(&"font_selected_color", &"LineEdit", _tok("PRIMARY_INK", c_text, hc))
	theme.set_color(&"selection_color", &"LineEdit", c_line if hc else Tokens.ROW_HOVER)
	theme.set_color(&"caret_color", &"LineEdit", _tok("GOLD", Tokens.GOLD, hc))
	theme.set_stylebox(&"normal", &"LineEdit", _make_flat(c_slot, c_line, bw, 8.0, 4.0, rad))
	theme.set_stylebox(&"focus", &"LineEdit", _make_flat(c_slot, c_info, focus_bw, 8.0, 4.0, rad))
	theme.set_stylebox(&"read_only", &"LineEdit", _make_flat(c_slot, c_muted, bw, 8.0, 4.0, rad))

	theme.set_font(&"font", &"TooltipLabel", f_reg)
	theme.set_font_size(&"font_size", &"TooltipLabel", 13)
	theme.set_color(&"font_color", &"TooltipLabel", c_text)


static func _apply_check_and_option(theme: Theme, f_med: FontVariation, pieces: Dictionary, tc: Dictionary[String, Texture2D], sb_focus: StyleBox, hc: bool) -> void:
	var c_text := _tok("TEXT", Tokens.TEXT, hc)
	var c_dis := _tok("MUTED", Tokens.FAINT, hc)
	var sb_empty := _make_empty(4.0, 2.0)
	var sw_on := null if hc else _load_kit_tex("switch_on", tc)
	var sw_off := null if hc else _load_kit_tex("switch_off", tc)

	for type_name: StringName in [&"CheckButton", &"KitSwitch"]:
		if type_name == &"KitSwitch":
			theme.set_type_variation(type_name, &"CheckButton")
		theme.set_font(&"font", type_name, f_med)
		theme.set_font_size(&"font_size", type_name, 14)
		for ck: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
			theme.set_color(ck, type_name, c_text)
		theme.set_color(&"font_disabled_color", type_name, c_dis)
		theme.set_constant(&"h_separation", type_name, Tokens.S2)
		for st: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			theme.set_stylebox(st, type_name, sb_empty)
		theme.set_stylebox(&"focus", type_name, sb_focus)
		if sw_on != null and sw_off != null:
			for icon_key: StringName in [&"checked", &"checked_disabled", &"checked_mirrored", &"checked_disabled_mirrored"]:
				theme.set_icon(icon_key, type_name, sw_on)
			for icon_key: StringName in [&"unchecked", &"unchecked_disabled", &"unchecked_mirrored", &"unchecked_disabled_mirrored"]:
				theme.set_icon(icon_key, type_name, sw_off)

	var arrow_down := _make_icon_subtex("arrow_down", pieces, tc)
	if arrow_down != null:
		theme.set_icon(&"arrow", &"OptionButton", arrow_down)


static func _apply_slider_and_progress(theme: Theme, f_bold: FontVariation, pieces: Dictionary, tc: Dictionary[String, Texture2D], hc: bool) -> void:
	var c_bg := _tok("BG", Tokens.SLOT, hc)
	var c_line := _tok("LINE", Tokens.LINE, hc)
	var sb_slot: StyleBox = _make_flat(c_bg, c_line, 2, 8.0, 4.0, 0) if hc else _sb_tex("slot", pieces, tc)
	var sb_fill: StyleBox = _make_flat(c_line, c_line, 1, 2.0, 2.0, 0) if hc else _sb_tex("progress_fill", pieces, tc)

	theme.set_stylebox(&"slider", &"HSlider", sb_slot)
	theme.set_stylebox(&"grabber_area", &"HSlider", sb_fill)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", sb_fill)
	if not hc:
		var grabber := _load_kit_tex("grabber", tc)
		var grabber_hot := _load_kit_tex("grabber_hot", tc)
		if grabber != null:
			theme.set_icon(&"grabber", &"HSlider", grabber)
			theme.set_icon(&"grabber_disabled", &"HSlider", grabber)
		if grabber_hot != null:
			theme.set_icon(&"grabber_highlight", &"HSlider", grabber_hot)

	theme.set_stylebox(&"background", &"ProgressBar", sb_slot)
	theme.set_stylebox(&"fill", &"ProgressBar", sb_fill)
	theme.set_font(&"font", &"ProgressBar", f_bold)
	theme.set_font_size(&"font_size", &"ProgressBar", 12)
	theme.set_color(&"font_color", &"ProgressBar", _tok("TEXT", Tokens.TEXT, hc))


static func _apply_scrollbars_and_separators(theme: Theme, hc: bool) -> void:
	var c_slot := _tok("SLOT", Tokens.SLOT, hc)
	var c_line := _tok("LINE", Tokens.LINE, hc)
	var c_brass := _tok("BRASS", Tokens.BRASS, hc)
	var c_gold := _tok("GOLD", Tokens.GOLD, hc)
	var c_info := _tok("INFO", Tokens.INFO, hc)
	var c_rule := _tok("RULE", Tokens.RULE, hc)

	theme.set_stylebox(&"panel", &"ScrollContainer", _make_empty(0.0, 0.0))
	var rad := 0 if hc else 4
	var bw := 1 if hc else 0
	for sb_type: StringName in [&"VScrollBar", &"HScrollBar"]:
		var is_v := (sb_type == &"VScrollBar")
		var mx := 4.0 if is_v else 0.0
		var my := 0.0 if is_v else 4.0
		theme.set_stylebox(&"scroll", sb_type, _make_flat(c_slot, c_line if hc else Color(0, 0, 0, 0), bw, mx, my, rad))
		theme.set_stylebox(&"scroll_focus", sb_type, _make_flat(c_slot, c_info, 2, mx, my, rad))
		theme.set_stylebox(&"grabber", sb_type, _make_flat(c_line, Color(0, 0, 0, 0), 0, mx, my, rad))
		theme.set_stylebox(&"grabber_highlight", sb_type, _make_flat(c_brass, Color(0, 0, 0, 0), 0, mx, my, rad))
		theme.set_stylebox(&"grabber_pressed", sb_type, _make_flat(c_gold, Color(0, 0, 0, 0), 0, mx, my, rad))

	theme.set_stylebox(&"separator", &"HSeparator", _make_flat(c_rule, Color(0, 0, 0, 0), 0, 0.0, 0.5, 0))
	theme.set_constant(&"separation", &"HSeparator", Tokens.S2)
	theme.set_stylebox(&"separator", &"VSeparator", _make_flat(c_rule, Color(0, 0, 0, 0), 0, 0.5, 0.0, 0))
	theme.set_constant(&"separation", &"VSeparator", Tokens.S2)


static func _apply_popup_and_tree(theme: Theme, f_med: FontVariation, f_sc: FontVariation, sb_card: StyleBox, pieces: Dictionary, tc: Dictionary[String, Texture2D], hc: bool) -> void:
	var c_text := _tok("TEXT", Tokens.TEXT, hc)
	var c_gold := _tok("GOLD", Tokens.GOLD, hc)
	var c_brass_hi := _tok("BRASS_HI", Tokens.BRASS_HI, hc)
	var c_hover := _tok("ROW_HOVER", Tokens.ROW_HOVER, hc)
	var c_line := _tok("LINE", Tokens.LINE, hc)
	var c_rule := _tok("RULE", Tokens.RULE, hc)

	theme.set_stylebox(&"panel", &"PopupMenu", sb_card)
	theme.set_stylebox(&"hover", &"PopupMenu", _make_flat(c_hover, c_text if hc else Color(0, 0, 0, 0), 2 if hc else 0, 8.0, 4.0, 0 if hc else 2))
	theme.set_stylebox(&"separator", &"PopupMenu", _make_flat(c_rule, Color(0, 0, 0, 0), 0, 4.0, 1.0, 0))
	theme.set_font(&"font", &"PopupMenu", f_med)
	theme.set_font_size(&"font_size", &"PopupMenu", 14)
	theme.set_color(&"font_color", &"PopupMenu", c_text)
	theme.set_color(&"font_hover_color", &"PopupMenu", c_brass_hi)
	theme.set_color(&"font_disabled_color", &"PopupMenu", _tok("MUTED", Tokens.FAINT, hc))
	var tick := _make_icon_subtex("tick", pieces, tc)
	if tick != null:
		theme.set_icon(&"checked", &"PopupMenu", tick)
		theme.set_icon(&"radio_checked", &"PopupMenu", tick)

	for type_name: StringName in [&"Tree", &"StudyTree"]:
		if type_name == &"StudyTree":
			theme.set_type_variation(type_name, &"Tree")
		theme.set_font(&"font", type_name, f_med)
		theme.set_font_size(&"font_size", type_name, 14)
		theme.set_font(&"title_button_font", type_name, f_sc)
		theme.set_font_size(&"title_button_font_size", type_name, 13)
		theme.set_color(&"font_color", type_name, c_text)
		theme.set_color(&"font_selected_color", type_name, c_brass_hi)
		theme.set_color(&"title_button_color", type_name, c_gold)
		theme.set_color(&"guide_color", type_name, c_line if (type_name == &"StudyTree" or hc) else c_rule)
		theme.set_color(&"relationship_line_color", type_name, c_line)
		theme.set_constant(&"draw_guides", type_name, 1)
		theme.set_constant(&"v_separation", type_name, Tokens.S1)
		theme.set_constant(&"h_separation", type_name, Tokens.S2)
		theme.set_stylebox(&"panel", type_name, _make_empty(0.0, 0.0))
		theme.set_stylebox(&"selected", type_name, _make_flat(c_hover, c_line if hc else Color(0, 0, 0, 0), 2 if hc else 0, 4.0, 2.0, 0))
		theme.set_stylebox(&"selected_focus", type_name, _make_flat(c_hover, c_gold, 2 if hc else 1, 4.0, 2.0, 0))
		theme.set_stylebox(&"title_button_normal", type_name, _make_empty(6.0, 4.0))
		theme.set_stylebox(&"title_button_hover", type_name, _make_flat(c_hover, Color(0, 0, 0, 0), 0, 6.0, 4.0, 0))
		theme.set_stylebox(&"title_button_pressed", type_name, _make_flat(c_hover, Color(0, 0, 0, 0), 0, 6.0, 4.0, 0))


static func _apply_panels(theme: Theme, pieces: Dictionary, tc: Dictionary[String, Texture2D], hc: bool) -> void:
	var c_bg := _tok("BG", Tokens.BG, hc)
	var c_line := _tok("LINE", Tokens.LINE, hc)

	for var_name: String in PANEL_VARIATION_PIECES:
		var tname := StringName(var_name)
		var piece_name := PANEL_VARIATION_PIECES[var_name]
		theme.set_type_variation(tname, &"PanelContainer")
		if hc:
			var pad := 16.0 if var_name in ["PanelModal", "PanelVellum"] else (6.0 if var_name.begins_with("KeyCap") else 8.0)
			theme.set_stylebox(&"panel", tname, _make_flat(c_bg, c_line, 2, pad, pad * 0.5, 0))
		elif pieces.has(piece_name):
			theme.set_stylebox(&"panel", tname, _sb_tex(piece_name, pieces, tc))
		elif var_name == "PanelVellumInset":
			theme.set_stylebox(&"panel", tname, _make_flat(Tokens.VELLUM_DARKEST, Tokens.INK_LINE, 1, 10.0, 10.0, 2))
		elif var_name == "PanelStripCell":
			theme.set_stylebox(&"panel", tname, _make_flat(Tokens.VELLUM, Tokens.INK_LINE, 1, 6.0, 6.0, 2))
		elif var_name == "PanelStripCellNow":
			theme.set_stylebox(&"panel", tname, _make_flat(Tokens.VELLUM, Tokens.BRASS, 2, 6.0, 6.0, 2))

	theme.set_type_variation(&"PanelDebug", &"PanelContainer")
	theme.set_stylebox(&"panel", &"PanelDebug", _make_flat(c_bg if hc else Color(Tokens.CARD_BG, 0.94), c_line, 2 if hc else 1, 8.0, 8.0, 0 if hc else 2))
	theme.set_type_variation(&"PanelShade", &"PanelContainer")
	theme.set_stylebox(&"panel", &"PanelShade", _make_flat(_tok("SHADE", Tokens.SHADE, hc), Color(0, 0, 0, 0), 0, 0.0, 0.0, 0))


static func _apply_buttons(theme: Theme, fc: Dictionary, pieces: Dictionary, tc: Dictionary[String, Texture2D], hc: bool) -> void:
	var f_bold := _get_font_var(fc, "alegreya_sans_bold", 0, true)
	var f_menu := _get_font_var(fc, "cinzel_bold", 2, false)
	var sb_focus := _focus_box(pieces, tc, hc)
	var end_prefix := "endseason_plate" if pieces.has("endseason_plate_normal") else "button_primary"

	var specs: Array[Dictionary] = [
		{"name": &"Button", "prefix": "button_secondary", "pressed": "", "font": f_bold, "size": 14, "kind": "sec", "pad": []},
		{"name": &"ButtonSmall", "prefix": "button_secondary", "pressed": "", "font": f_bold, "size": 13, "kind": "sec", "pad": [10.0, 2.0, 10.0, 2.0]},
		{"name": &"ButtonIcon", "prefix": "button_secondary", "pressed": "", "font": f_bold, "size": 14, "kind": "sec", "pad": [6.0, 4.0, 6.0, 4.0]},
		{"name": &"ButtonPrimary", "prefix": "button_primary", "pressed": "", "font": f_bold, "size": 14, "kind": "prim", "pad": []},
		{"name": &"ButtonPrimaryLarge", "prefix": "button_primary", "pressed": "", "font": f_bold, "size": 15, "kind": "prim", "pad": [16.0, 6.0, 16.0, 6.0]},
		{"name": &"ButtonDanger", "prefix": "button_danger", "pressed": "", "font": f_bold, "size": 14, "kind": "danger", "pad": []},
		{"name": &"ButtonToggle", "prefix": "button_toggle", "pressed": "toggle_on", "font": f_bold, "size": 14, "kind": "toggle", "pad": []},
		{"name": &"ButtonTab", "prefix": "button_toggle", "pressed": "toggle_on", "font": f_bold, "size": 14, "kind": "toggle", "pad": []},
		{"name": &"ButtonTabCompact", "prefix": "button_toggle", "pressed": "toggle_on", "font": f_bold, "size": 14, "kind": "toggle", "pad": [6.0, 4.0, 6.0, 4.0]},
		{"name": &"ButtonMenu", "prefix": "button_menu_secondary", "pressed": "", "font": f_menu, "size": 15, "kind": "sec", "pad": [34.0, 10.0, 34.0, 10.0]},
		{"name": &"ButtonMenuPrimary", "prefix": "button_menu_primary", "pressed": "", "font": f_menu, "size": 15, "kind": "prim", "pad": [34.0, 10.0, 34.0, 10.0]},
		{"name": &"ButtonMenuDanger", "prefix": "button_menu_danger", "pressed": "", "font": f_menu, "size": 15, "kind": "danger", "pad": [34.0, 10.0, 34.0, 10.0]},
		{"name": &"ButtonEndSeason", "prefix": end_prefix, "pressed": "", "font": f_bold, "size": 15, "kind": "prim", "pad": [18.0, 10.0, 18.0, 10.0]},
	]
	for spec: Dictionary in specs:
		var tname: StringName = spec["name"]
		var kind: String = str(spec["kind"])
		var font: FontVariation = spec["font"]
		var fsize := int(spec["size"])
		var pad: Array = spec["pad"]
		if hc:
			_apply_flat_button_spec(theme, tname, kind, font, fsize, pad, sb_focus)
		else:
			var fg := Tokens.PRIMARY_INK if kind == "prim" else Tokens.TEXT
			_set_tex_button(theme, tname, str(spec["prefix"]), str(spec["pressed"]), font, fsize, fg, pieces, tc, sb_focus, pad)

	_apply_medallion_button(theme, f_bold, sb_focus, hc)
	_apply_nav_button(theme, &"ButtonNav", "nav_selected", Tokens.MUTED, Tokens.TEXT, Tokens.GOLD, f_bold, pieces, tc, sb_focus, hc)
	_apply_nav_button(theme, &"ButtonNavInk", "nav_selected_ink", Tokens.VELLUM_INK, Tokens.TEXT, Tokens.VELLUM_INK, f_bold, pieces, tc, sb_focus, hc)


static func _apply_flat_button_spec(theme: Theme, tname: StringName, kind: String, font: FontVariation, fsize: int, pad: Array, sb_focus: StyleBox) -> void:
	if tname != &"Button":
		theme.set_type_variation(tname, &"Button")
	var hc_bg: Color = Tokens.HIGH_CONTRAST["BG"]
	var hc_text: Color = Tokens.HIGH_CONTRAST["TEXT"]
	var hc_muted: Color = Tokens.HIGH_CONTRAST["MUTED"]
	var hc_line: Color = Tokens.HIGH_CONTRAST["LINE"]
	var hc_prim: Color = Tokens.HIGH_CONTRAST["PRIMARY"]
	var hc_prim_ink: Color = Tokens.HIGH_CONTRAST["PRIMARY_INK"]
	var hc_bad: Color = Tokens.HIGH_CONTRAST["BAD"]

	var lr := float(pad[0]) if pad.size() == 4 else 14.0
	var tb := float(pad[1]) if pad.size() == 4 else 4.0
	var is_prim := (kind == "prim")
	var is_toggle := (kind == "toggle")
	var bg := hc_prim if is_prim else hc_bg
	var border := hc_text if is_prim else (hc_bad if kind == "danger" else hc_line)
	var fg := hc_prim_ink if is_prim else hc_text
	var fg_pressed := hc_prim_ink if (is_prim or is_toggle) else fg

	theme.set_stylebox(&"normal", tname, _make_flat(bg, border, 2, lr, tb, 0))
	theme.set_stylebox(&"hover", tname, _make_flat(hc_text if is_prim else hc_bg, hc_line if is_prim else hc_text, 2, lr, tb, 0))
	var sb_p := _make_flat(hc_line if is_toggle else bg, hc_text if is_toggle else border, 3, lr, tb, 0)
	theme.set_stylebox(&"pressed", tname, sb_p)
	theme.set_stylebox(&"hover_pressed", tname, sb_p)
	theme.set_stylebox(&"disabled", tname, _make_flat(hc_bg, hc_muted, 1, lr, tb, 0))
	theme.set_stylebox(&"focus", tname, sb_focus)
	_set_button_font_colors(theme, tname, font, fsize, fg, fg, fg_pressed, hc_muted)


static func _set_tex_button(theme: Theme, tname: StringName, prefix: String, pressed_override: String, font: FontVariation, fsize: int, fg: Color, pieces: Dictionary, tc: Dictionary[String, Texture2D], sb_focus: StyleBox, pad: Array) -> void:
	if tname != &"Button":
		theme.set_type_variation(tname, &"Button")
	var pressed_piece := pressed_override if pressed_override != "" else "%s_pressed" % prefix
	theme.set_stylebox(&"normal", tname, _sb_tex("%s_normal" % prefix, pieces, tc, pad))
	theme.set_stylebox(&"hover", tname, _sb_tex("%s_hot" % prefix, pieces, tc, pad))
	var sb_pressed := _sb_tex(pressed_piece, pieces, tc, pad)
	theme.set_stylebox(&"pressed", tname, sb_pressed)
	theme.set_stylebox(&"hover_pressed", tname, sb_pressed)
	theme.set_stylebox(&"disabled", tname, _sb_tex("%s_off" % prefix, pieces, tc, pad))
	theme.set_stylebox(&"focus", tname, sb_focus)
	_set_button_font_colors(theme, tname, font, fsize, fg, fg, fg, Tokens.FAINT)


static func _apply_medallion_button(theme: Theme, f_bold: FontVariation, sb_focus: StyleBox, hc: bool) -> void:
	theme.set_type_variation(&"ButtonMedallion", &"Button")
	var sb_empty := _make_empty(0.0, 0.0)
	for st: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		theme.set_stylebox(st, &"ButtonMedallion", sb_empty)
	theme.set_stylebox(&"focus", &"ButtonMedallion", sb_focus)
	var fg := _tok("BRASS_HI", Tokens.BRASS_HI, hc)
	_set_button_font_colors(theme, &"ButtonMedallion", f_bold, 14, fg, fg, fg, _tok("MUTED", Tokens.FAINT, hc))


static func _apply_nav_button(theme: Theme, tname: StringName, selected_piece: String, fg_norm: Color, fg_hover: Color, fg_press: Color, f_bold: FontVariation, pieces: Dictionary, tc: Dictionary[String, Texture2D], sb_focus: StyleBox, hc: bool) -> void:
	theme.set_type_variation(tname, &"Button")
	_set_button_font_colors(theme, tname, f_bold, 14, _tok("TEXT", fg_norm, hc), _tok("LINE", fg_hover, hc), _tok("LINE", fg_press, hc), _tok("MUTED", Tokens.FAINT, hc))
	theme.set_stylebox(&"normal", tname, _make_empty(10.0, 4.0))
	theme.set_stylebox(&"disabled", tname, _make_empty(10.0, 4.0))
	if hc:
		var hc_bg: Color = Tokens.HIGH_CONTRAST["BG"]
		theme.set_stylebox(&"hover", tname, _make_flat(hc_bg, Tokens.HIGH_CONTRAST["TEXT"], 2, 10.0, 4.0, 0))
		var sb_sel := _make_flat(hc_bg, Tokens.HIGH_CONTRAST["LINE"], 0, 10.0, 4.0, 0)
		sb_sel.border_width_left = 4
		theme.set_stylebox(&"pressed", tname, sb_sel)
		theme.set_stylebox(&"hover_pressed", tname, sb_sel)
	else:
		theme.set_stylebox(&"hover", tname, _make_flat(Tokens.ROW_HOVER, Color(0, 0, 0, 0), 0, 10.0, 4.0, 2))
		var sb_sel := _sb_tex(selected_piece, pieces, tc, [10.0, 4.0, 10.0, 4.0])
		theme.set_stylebox(&"pressed", tname, sb_sel)
		theme.set_stylebox(&"hover_pressed", tname, sb_sel)
	theme.set_stylebox(&"focus", tname, sb_focus)


static func _set_button_font_colors(theme: Theme, tname: StringName, font: FontVariation, fsize: int, fg: Color, fg_hover: Color, fg_pressed: Color, fg_disabled: Color) -> void:
	theme.set_font(&"font", tname, font)
	theme.set_font_size(&"font_size", tname, fsize)
	for pair: Array in [[&"font_color", fg], [&"icon_normal_color", fg], [&"font_focus_color", fg], [&"icon_focus_color", fg], [&"font_hover_color", fg_hover], [&"icon_hover_color", fg_hover], [&"font_pressed_color", fg_pressed], [&"font_hover_pressed_color", fg_pressed], [&"icon_pressed_color", fg_pressed], [&"icon_hover_pressed_color", fg_pressed], [&"font_disabled_color", fg_disabled], [&"icon_disabled_color", fg_disabled]]:
		theme.set_color(pair[0] as StringName, tname, pair[1] as Color)
	theme.set_constant(&"h_separation", tname, Tokens.S1)


static func _apply_composites(theme: Theme, font_cache: Dictionary, hc: bool) -> void:
	theme.set_type_variation(&"InkChart", &"Control")
	var f_hint := _get_font_var(font_cache, "alegreya_sans_regular", 0, true)
	var f_label := _get_font_var(font_cache, "alegreya_sans_bold", 0, true)
	theme.set_font(&"font", &"InkChart", f_hint)
	theme.set_font_size(&"font_size", &"InkChart", 13)
	theme.set_font(&"label_font", &"InkChart", f_label)
	theme.set_font_size(&"label_font_size", &"InkChart", 14)
	theme.set_font(&"keycap_font", &"InkChart", f_label)
	theme.set_font_size(&"keycap_font_size", &"InkChart", 12)

	if hc:
		var hc_map: Dictionary[String, String] = {
			"ink_0": "CHART_IRON", "ink_1": "CHART_LAPIS", "ink_2": "CHART_MADDER",
			"ink_3": "CHART_VERDIGRIS", "ink_4": "CHART_OCHRE",
			"axis": "MUTED", "grid": "LINE", "good": "GOOD", "bad": "BAD",
		}
		for key: String in hc_map:
			var col: Color = Tokens.HIGH_CONTRAST[hc_map[key]]
			theme.set_color(StringName(key), &"InkChart", col)
			theme.set_color(StringName(key + "_slot"), &"InkChart", col)
	else:
		var chart_colors: Dictionary = (Tokens.STYLE_VARIATIONS["InkChart"] as Dictionary)["colors"]
		for key: String in chart_colors:
			theme.set_color(StringName(key), &"InkChart", chart_colors[key] as Color)


static func _apply_kit_icons(
	theme: Theme,
	pieces: Dictionary,
	tex_cache: Dictionary[String, Texture2D],
	atlas_only: bool
) -> void:
	if not atlas_only:
		for icon_name: String in KIT_DIRECT_ICONS:
			var tex := _load_kit_tex(icon_name, tex_cache)
			if tex != null:
				theme.set_icon(StringName(icon_name), &"Kit", tex)

	if pieces.has("icons_base"):
		var icon_names: Array = (pieces["icons_base"] as Dictionary).get("icons", [])
		for idx: int in icon_names.size():
			var name := str(icon_names[idx])
			var sub := _make_icon_subtex(name, pieces, tex_cache)
			if sub != null:
				theme.set_icon(StringName(name), &"Kit", sub)
		for alias_name: String in ICON_ALIASES:
			var target := ICON_ALIASES[alias_name]
			if theme.has_icon(StringName(target), &"Kit"):
				theme.set_icon(StringName(alias_name), &"Kit", theme.get_icon(StringName(target), &"Kit"))
	# The 24 px icons atlas: only the names the shell uses are registered (the rest of it has no shell user yet).
	for grid_name: String in KIT_GRID_ICONS:
		var grid := _make_icon_subtex(grid_name, pieces, tex_cache, "icons")
		if grid != null:
			theme.set_icon(StringName(grid_name), &"Kit", grid)


static func _focus_box(pieces: Dictionary, tex_cache: Dictionary[String, Texture2D], hc: bool) -> StyleBox:
	if hc:
		return _make_flat(Color(0, 0, 0, 0), Tokens.HIGH_CONTRAST["INFO"], 3, 6.0, 4.0, 0)
	return _sb_tex("focus", pieces, tex_cache)


static func _load_kit_tex(piece_name: String, tex_cache: Dictionary[String, Texture2D]) -> Texture2D:
	if tex_cache.has(piece_name):
		return tex_cache[piece_name]
	var path := KIT_1X_DIR + piece_name + ".png"
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex != null:
		tex_cache[piece_name] = tex
	return tex


static func _make_icon_subtex(
	icon_name: String,
	pieces: Dictionary,
	tex_cache: Dictionary[String, Texture2D],
	piece_key: String = "icons_base"
) -> AtlasTexture:
	if not pieces.has(piece_key):
		return null
	var piece: Dictionary = pieces[piece_key]
	var icon_names: Array = piece.get("icons", [])
	var idx := icon_names.find(icon_name)
	if idx < 0:
		return null
	var cell: Array = piece.get("cell", [16, 16])
	var size: Array = piece.get("size", [128, 32])
	var cw := int(cell[0])
	var ch := int(cell[1])
	var cols := maxi(1, roundi(float(size[0]) / float(cw)))
	var col := idx % cols
	var row := int(float(idx) / float(cols))
	var atlas := _load_kit_tex(piece_key, tex_cache)
	if atlas == null:
		return null
	var sub := AtlasTexture.new()
	sub.atlas = atlas
	sub.region = Rect2(col * cw, row * ch, cw, ch)
	return sub


static func _sb_tex(
	piece_name: String,
	pieces: Dictionary,
	tex_cache: Dictionary[String, Texture2D],
	content_override: Array = []
) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _load_kit_tex(piece_name, tex_cache)
	if not pieces.has(piece_name):
		return sb
	var piece: Dictionary = pieces[piece_name]
	var margin: Array = piece.get("margin", [0, 0, 0, 0])
	sb.texture_margin_left = float(margin[0])
	sb.texture_margin_top = float(margin[1])
	sb.texture_margin_right = float(margin[2])
	sb.texture_margin_bottom = float(margin[3])

	var content: Array = content_override if content_override.size() == 4 else piece.get("content", [0, 0, 0, 0])
	sb.content_margin_left = float(content[0])
	sb.content_margin_top = float(content[1])
	sb.content_margin_right = float(content[2])
	sb.content_margin_bottom = float(content[3])

	var expand: Array = piece.get("expand", [0, 0, 0, 0])
	sb.expand_margin_left = float(expand[0])
	sb.expand_margin_top = float(expand[1])
	sb.expand_margin_right = float(expand[2])
	sb.expand_margin_bottom = float(expand[3])

	var axis := str(piece.get("axis", "stretch"))
	var h_mode := StyleBoxTexture.AXIS_STRETCH_MODE_TILE if axis in ["tile", "tile_x"] else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	var v_mode := StyleBoxTexture.AXIS_STRETCH_MODE_TILE if axis == "tile" else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_horizontal = h_mode
	sb.axis_stretch_vertical = v_mode
	return sb


static func _make_flat(bg: Color, border: Color, border_w: int, margin_lr: float, margin_tb: float, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin_lr
	sb.content_margin_right = margin_lr
	sb.content_margin_top = margin_tb
	sb.content_margin_bottom = margin_tb
	return sb


static func _make_empty(margin_lr: float, margin_tb: float) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = margin_lr
	sb.content_margin_right = margin_lr
	sb.content_margin_top = margin_tb
	sb.content_margin_bottom = margin_tb
	return sb


static func _tok(token_name: String, fallback: Color, hc: bool) -> Color:
	if hc and Tokens.HIGH_CONTRAST.has(token_name):
		return Tokens.HIGH_CONTRAST[token_name]
	return fallback


## Swaps every 1x kit texture and AtlasTexture sub-icon in `theme_2x` for its 2x counterpart wrapped in an
## `ImageTexture` with `set_size_override(logical_size)`.
static func _apply_2x_textures(theme_2x: Theme, pieces: Dictionary) -> void:
	var tex_2x_cache: Dictionary[String, ImageTexture] = {}
	var img_2x_cache: Dictionary[String, Image] = {}
	var sub_2x_cache: Dictionary[String, ImageTexture] = {}
	var swapped_boxes: Dictionary[int, bool] = {}

	for type_name: StringName in theme_2x.get_stylebox_type_list():
		for sb_name: StringName in theme_2x.get_stylebox_list(type_name):
			var sb := theme_2x.get_stylebox(sb_name, type_name)
			if not (sb is StyleBoxTexture):
				continue
			var sbt := sb as StyleBoxTexture
			if swapped_boxes.has(sbt.get_instance_id()):
				continue
			swapped_boxes[sbt.get_instance_id()] = true
			if sbt.texture == null or not sbt.texture.resource_path.begins_with(KIT_1X_DIR):
				continue
			var tex_2x := _get_2x_image_texture(sbt.texture.resource_path.get_file().get_basename(), pieces, tex_2x_cache, img_2x_cache)
			if tex_2x != null:
				sbt.texture = tex_2x

	for type_name: StringName in theme_2x.get_icon_type_list():
		for icon_name: StringName in theme_2x.get_icon_list(type_name):
			var ic := theme_2x.get_icon(icon_name, type_name)
			if ic is AtlasTexture:
				var at := ic as AtlasTexture
				if at.atlas == null or not at.atlas.resource_path.begins_with(KIT_1X_DIR):
					continue
				var sub_2x := _get_2x_sub_texture(at.atlas.resource_path.get_file().get_basename(), at.region, img_2x_cache, sub_2x_cache)
				if sub_2x != null:
					theme_2x.set_icon(icon_name, type_name, sub_2x)
			elif ic != null and ic.resource_path.begins_with(KIT_1X_DIR):
				var tex_2x := _get_2x_image_texture(ic.resource_path.get_file().get_basename(), pieces, tex_2x_cache, img_2x_cache)
				if tex_2x != null:
					theme_2x.set_icon(icon_name, type_name, tex_2x)


static func _get_2x_image(piece_name: String, img_2x_cache: Dictionary[String, Image]) -> Image:
	if img_2x_cache.has(piece_name):
		return img_2x_cache[piece_name]
	var path := KIT_2X_DIR + piece_name + ".png"
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img != null:
		img_2x_cache[piece_name] = img
	return img


static func _get_2x_image_texture(
	piece_name: String,
	pieces: Dictionary,
	tex_2x_cache: Dictionary[String, ImageTexture],
	img_2x_cache: Dictionary[String, Image]
) -> ImageTexture:
	if tex_2x_cache.has(piece_name):
		return tex_2x_cache[piece_name]
	var img := _get_2x_image(piece_name, img_2x_cache)
	if img == null:
		return null
	var itex := ImageTexture.create_from_image(img)
	var logical_size := Vector2i(roundi(float(img.get_width()) * 0.5), roundi(float(img.get_height()) * 0.5))
	if pieces.has(piece_name):
		var size_arr: Array = (pieces[piece_name] as Dictionary).get("size", [])
		if size_arr.size() == 2:
			logical_size = Vector2i(int(size_arr[0]), int(size_arr[1]))
	itex.set_size_override(logical_size)
	tex_2x_cache[piece_name] = itex
	return itex


static func _get_2x_sub_texture(
	piece_name: String,
	region_1x: Rect2,
	img_2x_cache: Dictionary[String, Image],
	sub_2x_cache: Dictionary[String, ImageTexture]
) -> ImageTexture:
	var key := "%s|%d,%d,%d,%d" % [
		piece_name,
		roundi(region_1x.position.x),
		roundi(region_1x.position.y),
		roundi(region_1x.size.x),
		roundi(region_1x.size.y),
	]
	if sub_2x_cache.has(key):
		return sub_2x_cache[key]
	var img_2x := _get_2x_image(piece_name, img_2x_cache)
	if img_2x == null:
		return null
	var lw := roundi(region_1x.size.x)
	var lh := roundi(region_1x.size.y)
	var r2 := Rect2i(roundi(region_1x.position.x) * 2, roundi(region_1x.position.y) * 2, lw * 2, lh * 2)
	var itex := ImageTexture.create_from_image(img_2x.get_region(r2))
	itex.set_size_override(Vector2i(lw, lh))
	sub_2x_cache[key] = itex
	return itex
