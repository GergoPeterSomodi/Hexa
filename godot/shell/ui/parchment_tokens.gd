## The parchment map's colours and line sizes (docs/architecture/map-overview-build-spec.md R4, R6, R7, R26, R27, D9),
## in a standard and a high-contrast set. The only file of the parchment that holds a colour literal (tools/lint_godot.py,
## UI_STYLE_ALLOWLIST): the map node, its shaders, the labels, the goods card and the legend read these.
class_name ParchmentTokens
extends RefCounted

# The paper: the sea and its speckle, the hatched water along the coasts, the land, the paper nobody has explored.
const SEA := Color("#e8cfae")
const SPECKLE := Color("#8a654624")
const HATCH := Color("#8a65469e")
const LAND := Color("#e6e0d4")
const UNKNOWN := Color("#c3ab85")

# The lines on the land. The borders and the coast are 3:1 or more against it. The district dots and the mountain marks
# are the approved mockup's faint inks: see-through and about 2:1; high contrast draws them opaque, 3:1 or more.
const DISTRICT := Color("#8a7a64b3")
const MOUNTAIN := Color("#7d6a5299")
const BORDER := Color("#3a2a1c")
const COAST := Color("#2e2117")

# The names (4.5:1 or more on the halo), the town dots, the goods icon discs and their pips.
const NAME_INK := Color("#17454a")
const TOWN_INK := Color("#231a10")
const HALO := Color("#efe6d4")
const DOT_FILL := Color("#9c938a")
const DOT_EDGE := Color("#3a2a1c")
const DISC := Color("#f7ecd5")
const DISC_EDGE := Color("#8a5a28")
const PIP := Color("#3a2a1c")

## The goods ramp, stage 1 (light) to 3 (dark): one hue, 15 L* or more between stages.
const GOODS_1 := Color("#a8d8b6")
const GOODS_2 := Color("#64b17a")
const GOODS_3 := Color("#39864f")

# The army's next-season reach, hatched over the paper (amendment of 2026-11-28): a dark stripe and a pale one beside
# it, so one of the two is 3:1 or more against every land colour.
const REACH_INK := Color("#4a2f00")
const REACH_LIGHT := Color("#fff3b8")

# High contrast: darker ink, a paler land and halo, a darker unknown paper. A role not named here is as above.
const HC_LAND := Color("#ece7dc")
const HC_UNKNOWN := Color("#b49a72")
const HC_DISTRICT := Color("#4e4030")
const HC_MOUNTAIN := Color("#4e4030")
const HC_BORDER := Color("#1e140b")
const HC_COAST := Color("#140c05")
const HC_NAME_INK := Color("#0b2b2f")
const HC_TOWN_INK := Color("#0f0a05")
const HC_HALO := Color("#f8f3e6")
const HC_DOT_EDGE := Color("#1e140b")
const HC_DISC_EDGE := Color("#4a2e12")
const HC_PIP := Color("#1e140b")
const HC_REACH_INK := Color("#140c05")
const HC_REACH_LIGHT := Color("#fffbe0")

## Owner mode: this much of the country's colour is mixed into the land (R6).
const OWNER_MIX := 0.46

# Line sizes in screen px, whatever the zoom (R4); high contrast draws the coast and the borders HC_EXTRA_PX thicker.
const COAST_PX := 3.0
const BORDER_PX := 2.0
const BORDER_DASH_PX := 9.0
const BORDER_GAP_PX := 6.0
const DISTRICT_PX := 0.8
const HC_DISTRICT_PX := 1.0
const HC_EXTRA_PX := 1.0
## The paper halo round a name (R8).
const HALO_PX := 4
## The next-season reach's hatch: from stripe to stripe, the dark stripe's width and the pale one's; high contrast draws
## the dark one HC_EXTRA_PX wider.
const REACH_PERIOD_PX := 9.0
const REACH_INK_PX := 2.5
const REACH_LIGHT_PX := 1.5


## Every colour by role, for the standard or the high-contrast set: sea, speckle, hatch, land, unknown, district,
## mountain, border, coast, name_ink, town_ink, halo, dot_fill, dot_edge, disc, disc_edge, pip, goods_1, goods_2,
## goods_3, reach_ink, reach_light. A new dictionary each time.
static func colours(high_contrast: bool) -> Dictionary[StringName, Color]:
	var out: Dictionary[StringName, Color] = {
		&"sea": SEA, &"speckle": SPECKLE, &"hatch": HATCH, &"land": LAND, &"unknown": UNKNOWN,
		&"district": DISTRICT, &"mountain": MOUNTAIN, &"border": BORDER, &"coast": COAST, &"name_ink": NAME_INK,
		&"town_ink": TOWN_INK, &"halo": HALO, &"dot_fill": DOT_FILL, &"dot_edge": DOT_EDGE, &"disc": DISC,
		&"disc_edge": DISC_EDGE, &"pip": PIP, &"goods_1": GOODS_1, &"goods_2": GOODS_2, &"goods_3": GOODS_3,
		&"reach_ink": REACH_INK, &"reach_light": REACH_LIGHT,
	}
	if high_contrast:
		out.merge({
			&"land": HC_LAND, &"unknown": HC_UNKNOWN, &"district": HC_DISTRICT, &"mountain": HC_MOUNTAIN,
			&"border": HC_BORDER, &"coast": HC_COAST, &"name_ink": HC_NAME_INK, &"town_ink": HC_TOWN_INK,
			&"halo": HC_HALO, &"dot_edge": HC_DOT_EDGE, &"disc_edge": HC_DISC_EDGE, &"pip": HC_PIP,
			&"reach_ink": HC_REACH_INK, &"reach_light": HC_REACH_LIGHT,
		}, true)
	return out


## The fill of a district of the chosen good: stage 1 to 3 of the ramp (a higher stage as 3); the land for stage 0 or
## less (it makes none).
static func stage_colour(stage: int, high_contrast: bool) -> Color:
	if stage <= 0:
		return HC_LAND if high_contrast else LAND
	if stage == 1:
		return GOODS_1
	return GOODS_2 if stage == 2 else GOODS_3


static func coast_px(high_contrast: bool) -> float:
	return COAST_PX + (HC_EXTRA_PX if high_contrast else 0.0)


static func border_px(high_contrast: bool) -> float:
	return BORDER_PX + (HC_EXTRA_PX if high_contrast else 0.0)


static func reach_ink_px(high_contrast: bool) -> float:
	return REACH_INK_PX + (HC_EXTRA_PX if high_contrast else 0.0)


static func district_px(high_contrast: bool) -> float:
	return HC_DISTRICT_PX if high_contrast else DISTRICT_PX
