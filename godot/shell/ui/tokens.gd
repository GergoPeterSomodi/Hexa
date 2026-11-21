## Studiolo UI design tokens (docs/design/ui/design.md section 3; docs/architecture/ui-style-and-feedback-spec.md
## sections 4.2, 4.3, 4.7 and 4.9).
##
## Every scalar colour and size constant sits on its own line in the form `const NAME := Color("#...")` or
## `const NAME := <int>` so both GDScript and the Python UI bake's regex parser read the same source of truth.
class_name Tokens
extends RefCounted

# Base tokens (design.md section 3, ui-and-controls-spec.md section 3.4)
const BG := Color("#14100c")
const PANEL_BG := Color("#221a14")
const PANEL_HEAD := Color("#3a2416")
const CARD_BG := Color("#15110e")
const LINE := Color("#6b5637")
const TEXT := Color("#f2e8d0")
const MUTED := Color("#b9a987")
const FAINT := Color("#9c8c70")
const GOLD := Color("#e8c15a")
const GOOD := Color("#7fc98a")
const BAD := Color("#f0806a")
const WARN := Color("#f0a850")
const INFO := Color("#8fb8ea")
const INK := Color("#0b0806")
const SHADE := Color("#070504b8")
const ROW_HOVER := Color("#33271c")
const RULE := Color("#6b563780")

# Button tokens (design.md section 3)
const BUTTON := Color("#4a3120")
const BUTTON_HOT := Color("#5e4029")
const BUTTON_OFF := Color("#2a221b")
const TOGGLE := Color("#2b221a")
const TOGGLE_HOT := Color("#382c21")
const PRIMARY := Color("#d9a93a")
const PRIMARY_HOT := Color("#f0c85a")
const PRIMARY_INK := Color("#1c1206")
const DANGER := Color("#8e2618")
const DANGER_HOT := Color("#ad3420")

# Material tokens (design.md section 3)
const LEATHER := Color("#2a1d15")
const WOOD := Color("#4a2f1c")
const WOOD_DARK := Color("#2c1a0f")
const BRASS := Color("#c9a04a")
const BRASS_HI := Color("#f6e3a1")
const BRASS_LO := Color("#7a5a1e")
const SLOT := Color("#0e0a08")
const VELLUM := Color("#efe3c4")
const VELLUM_INK := Color("#2b2219")
const VELLUM_MUTED := Color("#5c4d3a")
const SEAL := Color("#a3241a")
const LAPIS := Color("#1f3f7a")
const VELVET := Color("#5a1420")
const GLOW := Color("#ffd98a73")

# Texture bounds for bake contrast assertions (ui-style-and-feedback-spec.md section 4.4)
const LEATHER_LIGHTEST := Color("#2f231a")
const VELLUM_DARKEST := Color("#e1d5b8")

# Ink on vellum tokens (ui-style-and-feedback-spec.md section 4.2)
const GOOD_INK := Color("#12605a")
const BAD_INK := Color("#a8321a")
const WARN_INK := Color("#8f4a08")
const GOLD_INK := Color("#75510f")
const INK_LINE := Color("#1f181152")

# Chart inks (ui-style-and-feedback-spec.md section 4.2)
const CHART_IRON := Color("#2b2219")
const CHART_LAPIS := Color("#1f3f7a")
const CHART_MADDER := Color("#a8321a")
const CHART_VERDIGRIS := Color("#12605a")
const CHART_OCHRE := Color("#75510f")

# Map tokens (ui-style-and-feedback-spec.md section 4.2)
const MAP_SELECT := Color("#ffd646")
const MAP_REACH := Color("#ffd64633")
const MAP_REACH_NEXT := Color("#ffd64614")
const MAP_PATH := Color("#f6e3a1")
const MAP_PATH_WARN := Color("#f0806a")
const MAP_PATH_INK := Color("#0b0806")

# Sizes in logical pixels (ui-style-and-feedback-spec.md section 4.2)
const S1 := 4
const S2 := 8
const S3 := 12
const S4 := 16
const S5 := 20
const S6 := 24
const BAR_H := 40
const BUTTON_H := 28
const BUTTON_SM_H := 24
const BUTTON_LG_H := 32
const BUTTON_MENU_H := 42
const MEDAL := 64
const MEDAL_SM := 30
const PANEL_W := 296
const TARGET_MIN := 24
const MENU_COLUMN_X := 270

## Minimum relative luminance allowed inside a baked vellum content rect (spec 4.4).
const VELLUM_MIN_LUMINANCE: float = 0.66

## Ordered five-series chart palette (spec 4.2).
const CHART_INKS: Array[Color] = [
	CHART_IRON,
	CHART_LAPIS,
	CHART_MADDER,
	CHART_VERDIGRIS,
	CHART_OCHRE,
]

## Non-colour second cues (dash pattern and point marker) for each chart ink (spec 4.2).
const CHART_CUES: Array[Dictionary] = [
	{"id": "iron", "color": CHART_IRON, "dash": "solid", "marker": "dot"},
	{"id": "lapis", "color": CHART_LAPIS, "dash": "dash", "marker": "square"},
	{"id": "madder", "color": CHART_MADDER, "dash": "dotted", "marker": "triangle"},
	{"id": "verdigris", "color": CHART_VERDIGRIS, "dash": "dash_dot", "marker": "diamond"},
	{"id": "ochre", "color": CHART_OCHRE, "dash": "long_dash", "marker": "cross"},
]

## Fallback "Lapis and gilt" blue-black leather deltas (design.md section 2, spec 4.2).
const LAPIS_AND_GILT: Dictionary[String, Color] = {
	"PANEL_BG": Color("#141d30"),
	"PANEL_HEAD": Color("#1b2946"),
	"CARD_BG": Color("#0c111c"),
	"TOGGLE": Color("#18233a"),
	"ROW_HOVER": Color("#22304e"),
	"LEATHER": Color("#16233a"),
}

## High-contrast flat palette (spec 4.2 and 4.9): black fields, white text (21:1), #ffd646 borders.
const HIGH_CONTRAST: Dictionary[String, Color] = {
	"BG": Color("#000000"),
	"PANEL_BG": Color("#000000"),
	"PANEL_HEAD": Color("#000000"),
	"CARD_BG": Color("#000000"),
	"LEATHER": Color("#000000"),
	"WOOD": Color("#000000"),
	"WOOD_DARK": Color("#000000"),
	"SLOT": Color("#000000"),
	"VELLUM": Color("#000000"),
	"BUTTON": Color("#000000"),
	"BUTTON_HOT": Color("#000000"),
	"BUTTON_OFF": Color("#000000"),
	"TOGGLE": Color("#000000"),
	"TOGGLE_HOT": Color("#000000"),
	"ROW_HOVER": Color("#000000"),
	"INK": Color("#000000"),
	"SHADE": Color("#000000e0"),
	"TEXT": Color("#ffffff"),
	"VELLUM_INK": Color("#ffffff"),
	"PRIMARY_INK": Color("#000000"),
	"MUTED": Color("#d0d0d0"),
	"FAINT": Color("#d0d0d0"),
	"VELLUM_MUTED": Color("#d0d0d0"),
	"LINE": Color("#ffd646"),
	"RULE": Color("#ffd646"),
	"INK_LINE": Color("#ffd646"),
	"GOLD": Color("#ffd646"),
	"GOLD_INK": Color("#ffd646"),
	"BRASS": Color("#ffd646"),
	"BRASS_HI": Color("#ffd646"),
	"BRASS_LO": Color("#ffd646"),
	"PRIMARY": Color("#ffd646"),
	"PRIMARY_HOT": Color("#ffffff"),
	"MAP_SELECT": Color("#ffd646"),
	"MAP_REACH": Color("#ffd64633"),
	"MAP_REACH_NEXT": Color("#ffd64614"),
	"MAP_PATH": Color("#f6e3a1"),
	"MAP_PATH_WARN": BAD,
	"MAP_PATH_INK": Color("#000000"),
	"GOOD": GOOD,
	"BAD": BAD,
	"WARN": WARN,
	"INFO": INFO,
	"GOOD_INK": GOOD,
	"BAD_INK": BAD,
	"WARN_INK": WARN,
	"DANGER": BAD,
	"DANGER_HOT": BAD,
	"CHART_IRON": Color("#ffffff"),
	"CHART_LAPIS": INFO,
	"CHART_MADDER": BAD,
	"CHART_VERDIGRIS": GOOD,
	"CHART_OCHRE": WARN,
}

## Committed static TTF font paths (spec 4.3).
const FONTS: Dictionary[String, String] = {
	"cinzel_bold": "res://assets/fonts/cinzel/Cinzel-Bold.ttf",
	"alegreya_italic": "res://assets/fonts/alegreya/Alegreya-MediumItalic.ttf",
	"alegreya_sc_bold": "res://assets/fonts/alegreya_sc/AlegreyaSC-Bold.ttf",
	"alegreya_sans_regular": "res://assets/fonts/alegreya_sans/AlegreyaSans-Regular.ttf",
	"alegreya_sans_medium": "res://assets/fonts/alegreya_sans/AlegreyaSans-Medium.ttf",
	"alegreya_sans_bold": "res://assets/fonts/alegreya_sans/AlegreyaSans-Bold.ttf",
	"fallback": "res://assets/fonts/noto/NotoSans-Regular.ttf",
}

## Typography variations for `build_theme.gd` (spec 4.3).
## Cinzel never sets a number; Alegreya Sans and SC enable `lnum` and `tnum`.
const TYPE_VARIATIONS: Dictionary[String, Dictionary] = {
	"TitleRibbon": {
		"base_type": "Label",
		"font": "cinzel_bold",
		"size": 20,
		"color": BRASS_HI,
		"color_token": "BRASS_HI",
		"tracking_em": 0.14,
		"tabular": false,
		"uppercase": true,
	},
	"TitleModal": {
		"base_type": "Label",
		"font": "cinzel_bold",
		"size": 19,
		"color": BRASS_HI,
		"color_token": "BRASS_HI",
		"tracking_em": 0.10,
		"tabular": false,
		"uppercase": true,
	},
	"TitleBrand": {
		"base_type": "Label",
		"font": "cinzel_bold",
		"size": 17,
		"color": BRASS_HI,
		"color_token": "BRASS_HI",
		"tracking_em": 0.10,
		"tabular": false,
		"uppercase": true,
	},
	"TitlePanel": {
		"base_type": "Label",
		"font": "cinzel_bold",
		"size": 16,
		"color": BRASS_HI,
		"color_token": "BRASS_HI",
		"tracking_em": 0.10,
		"tabular": false,
		"uppercase": true,
	},
	"ButtonMenu": {
		"base_type": "Button",
		"font": "cinzel_bold",
		"size": 15,
		"color": TEXT,
		"color_token": "TEXT",
		"primary_color": PRIMARY_INK,
		"primary_color_token": "PRIMARY_INK",
		"tracking_em": 0.14,
		"tabular": false,
		"uppercase": true,
	},
	"SectionHead": {
		"base_type": "Label",
		"font": "alegreya_sc_bold",
		"size": 16,
		"color": GOLD,
		"color_token": "GOLD",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"TableHeader": {
		"base_type": "Label",
		"font": "alegreya_sc_bold",
		"size": 13,
		"color": GOLD,
		"color_token": "GOLD",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"Number": {
		"base_type": "Label",
		"font": "alegreya_sans_bold",
		"size": 16,
		"color": TEXT,
		"color_token": "TEXT",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"NumberGood": {
		"base_type": "Label",
		"font": "alegreya_sans_bold",
		"size": 16,
		"color": GOOD,
		"color_token": "GOOD",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"NumberBad": {
		"base_type": "Label",
		"font": "alegreya_sans_bold",
		"size": 16,
		"color": BAD,
		"color_token": "BAD",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"NumberWarn": {
		"base_type": "Label",
		"font": "alegreya_sans_bold",
		"size": 16,
		"color": WARN,
		"color_token": "WARN",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"Label": {
		"base_type": "Label",
		"font": "alegreya_sans_bold",
		"size": 14,
		"color": TEXT,
		"color_token": "TEXT",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"KeyCap": {
		"base_type": "Label",
		"font": "alegreya_sans_bold",
		"size": 12,
		"color": VELLUM_INK,
		"color_token": "VELLUM_INK",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"Body": {
		"base_type": "Label",
		"font": "alegreya_sans_medium",
		"size": 15,
		"color": TEXT,
		"color_token": "TEXT",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"TableRow": {
		"base_type": "Label",
		"font": "alegreya_sans_medium",
		"size": 14,
		"color": TEXT,
		"color_token": "TEXT",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"Hint": {
		"base_type": "Label",
		"font": "alegreya_sans_regular",
		"size": 13,
		"color": MUTED,
		"color_token": "MUTED",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"Reason": {
		"base_type": "Label",
		"font": "alegreya_sans_regular",
		"size": 13,
		"color": MUTED,
		"color_token": "MUTED",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"LabelInk": {
		"base_type": "Label",
		"font": "alegreya_sans_medium",
		"size": 16,
		"color": VELLUM_INK,
		"color_token": "VELLUM_INK",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"LabelInkMuted": {
		"base_type": "Label",
		"font": "alegreya_sans_medium",
		"size": 15,
		"color": VELLUM_MUTED,
		"color_token": "VELLUM_MUTED",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"LabelInkHead": {
		"base_type": "Label",
		"font": "alegreya_sc_bold",
		"size": 16,
		"color": GOLD_INK,
		"color_token": "GOLD_INK",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"NumberInk": {
		"base_type": "Label",
		"font": "alegreya_sans_bold",
		"size": 16,
		"color": VELLUM_INK,
		"color_token": "VELLUM_INK",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"NumberInkGood": {
		"base_type": "Label",
		"font": "alegreya_sans_bold",
		"size": 16,
		"color": GOOD_INK,
		"color_token": "GOOD_INK",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"NumberInkBad": {
		"base_type": "Label",
		"font": "alegreya_sans_bold",
		"size": 16,
		"color": BAD_INK,
		"color_token": "BAD_INK",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"NumberInkWarn": {
		"base_type": "Label",
		"font": "alegreya_sans_bold",
		"size": 16,
		"color": WARN_INK,
		"color_token": "WARN_INK",
		"tracking_em": 0.0,
		"tabular": true,
		"uppercase": false,
	},
	"LabelFlavour": {
		"base_type": "Label",
		"font": "alegreya_italic",
		"size": 17,
		"color": VELLUM_MUTED,
		"color_token": "VELLUM_MUTED",
		"leather_color": MUTED,
		"leather_color_token": "MUTED",
		"tracking_em": 0.0,
		"tabular": false,
		"uppercase": false,
	},
}

## Panel, button and composite Theme variations for `build_theme.gd` (spec 4.7, ui-and-controls-spec.md 3.4).
const STYLE_VARIATIONS: Dictionary[String, Dictionary] = {
	"PanelContainer": {"base_type": "PanelContainer", "kind": "texture", "texture": "panel_frame"},
	"PanelModal": {"base_type": "PanelContainer", "kind": "texture", "texture": "panel_modal"},
	"PanelVellum": {"base_type": "PanelContainer", "kind": "texture", "texture": "panel_vellum"},
	"PanelVellumInset": {"base_type": "PanelContainer", "kind": "texture", "texture": "vellum_inset"},
	"PanelCard": {"base_type": "PanelContainer", "kind": "texture", "texture": "panel_card"},
	"PanelBar": {"base_type": "PanelContainer", "kind": "texture", "texture": "panel_bar"},
	"PanelRibbon": {"base_type": "PanelContainer", "kind": "texture", "texture": "ribbon", "min_width": 230},
	"PanelToast": {"base_type": "PanelContainer", "kind": "texture", "texture": "toast"},
	"PanelCartouche": {"base_type": "PanelContainer", "kind": "texture", "texture": "cartouche"},
	"PanelMinimap": {"base_type": "PanelContainer", "kind": "texture", "texture": "minimap_frame"},
	"PanelSlot": {"base_type": "PanelContainer", "kind": "texture", "texture": "slot"},
	"PanelStripCell": {"base_type": "PanelContainer", "kind": "texture", "texture": "strip_cell"},
	"PanelStripCellNow": {"base_type": "PanelContainer", "kind": "texture", "texture": "strip_cell_now"},
	"TooltipPanel": {"base_type": "PanelContainer", "kind": "texture", "texture": "panel_card"},
	"Button": {
		"base_type": "Button",
		"kind": "texture",
		"texture_prefix": "button_secondary",
		"min_height": BUTTON_H,
		"font_color": TEXT,
		"font_color_token": "TEXT",
	},
	"ButtonSmall": {
		"base_type": "Button",
		"kind": "texture",
		"texture_prefix": "button_secondary",
		"min_height": BUTTON_SM_H,
		"font_color": TEXT,
		"font_color_token": "TEXT",
	},
	"ButtonPrimary": {
		"base_type": "Button",
		"kind": "texture",
		"texture_prefix": "button_primary",
		"min_height": BUTTON_H,
		"font_color": PRIMARY_INK,
		"font_color_token": "PRIMARY_INK",
	},
	"ButtonPrimaryLarge": {
		"base_type": "Button",
		"kind": "texture",
		"texture_prefix": "button_primary",
		"min_height": BUTTON_LG_H,
		"font_color": PRIMARY_INK,
		"font_color_token": "PRIMARY_INK",
	},
	"ButtonDanger": {
		"base_type": "Button",
		"kind": "texture",
		"texture_prefix": "button_danger",
		"min_height": BUTTON_H,
		"font_color": TEXT,
		"font_color_token": "TEXT",
	},
	"ButtonToggle": {
		"base_type": "Button",
		"kind": "texture",
		"texture_prefix": "button_toggle",
		"texture_pressed": "toggle_on",
		"min_height": BUTTON_H,
		"font_color": TEXT,
		"font_color_token": "TEXT",
	},
	"ButtonIcon": {
		"base_type": "Button",
		"kind": "texture",
		"texture_prefix": "button_secondary",
		"min_height": BUTTON_H,
		"font_color": TEXT,
		"font_color_token": "TEXT",
	},
	"ButtonMenu": {
		"base_type": "Button",
		"kind": "texture",
		"texture_prefix": "button_menu_secondary",
		"min_height": BUTTON_MENU_H,
		"font_color": TEXT,
		"font_color_token": "TEXT",
	},
	"ButtonMenuPrimary": {
		"base_type": "Button",
		"kind": "texture",
		"texture_prefix": "button_menu_primary",
		"min_height": BUTTON_MENU_H,
		"font_color": PRIMARY_INK,
		"font_color_token": "PRIMARY_INK",
	},
	"ButtonMenuDanger": {
		"base_type": "Button",
		"kind": "texture",
		"texture_prefix": "button_menu_danger",
		"min_height": BUTTON_MENU_H,
		"font_color": TEXT,
		"font_color_token": "TEXT",
	},
	"ButtonEndSeason": {
		"base_type": "Button",
		"kind": "texture",
		"texture_prefix": "endseason_plate",
		"min_height": 44,
		"font_color": PRIMARY_INK,
		"font_color_token": "PRIMARY_INK",
	},
	"ButtonMedallion": {
		"base_type": "Button",
		"kind": "empty",
		"min_height": MEDAL_SM,
		"font_color": BRASS_HI,
		"font_color_token": "BRASS_HI",
	},
	"ButtonNav": {
		"base_type": "Button",
		"kind": "hybrid",
		"texture_pressed": "nav_selected",
		"hover_color": ROW_HOVER,
		"font_color": MUTED,
		"font_pressed_color": GOLD,
	},
	"ButtonNavInk": {
		"base_type": "Button",
		"kind": "hybrid",
		"texture_pressed": "nav_selected_ink",
		"hover_color": ROW_HOVER,
		"font_color": VELLUM_INK,
		"font_pressed_color": VELLUM_INK,
	},
	"ButtonTab": {
		"base_type": "Button",
		"kind": "texture",
		"texture_prefix": "button_toggle",
		"texture_pressed": "toggle_on",
		"min_height": BUTTON_H,
		"font_color": TEXT,
		"font_color_token": "TEXT",
	},
	"StudyTree": {
		"base_type": "Tree",
		"kind": "flat",
		"header_variation": "TableHeader",
		"row_variation": "TableRow",
		"hover_color": ROW_HOVER,
		"guide_color": LINE,
	},
	"InkChart": {
		"base_type": "Control",
		"kind": "data",
		"font_variation": "Hint",
		"colors": {
			"ink_0": CHART_IRON,
			"ink_1": CHART_LAPIS,
			"ink_2": CHART_MADDER,
			"ink_3": CHART_VERDIGRIS,
			"ink_4": CHART_OCHRE,
			"axis": VELLUM_MUTED,
			"grid": INK_LINE,
			"good": GOOD_INK,
			"bad": BAD_INK,
			"ink_0_slot": TEXT,
			"ink_1_slot": INFO,
			"ink_2_slot": BAD,
			"ink_3_slot": GOOD,
			"ink_4_slot": GOLD,
			"axis_slot": MUTED,
			"grid_slot": RULE,
			"good_slot": GOOD,
			"bad_slot": BAD,
		},
	},
}


## WCAG 2.1 relative luminance for a colour in sRGB space (0.0 for black to 1.0 for white).
static func relative_luminance(c: Color) -> float:
	return (
		0.2126 * _channel_luminance(c.r)
		+ 0.7152 * _channel_luminance(c.g)
		+ 0.0722 * _channel_luminance(c.b)
	)


## WCAG 2.1 contrast ratio between two colours (1.0 to 21.0).
static func contrast_ratio(a: Color, b: Color) -> float:
	var lum_a := relative_luminance(a)
	var lum_b := relative_luminance(b)
	var lighter := maxf(lum_a, lum_b)
	var darker := minf(lum_a, lum_b)
	return (lighter + 0.05) / (darker + 0.05)


static func _channel_luminance(channel: float) -> float:
	if channel <= 0.04045:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)
