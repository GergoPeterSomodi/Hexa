## The number chips of the tile window (tile-window spec R10, D10; the owner's mockup v4): up to four cells of TileView.strip,
## each a rounded chip with a round icon (the Kit icon of the cell's key) and the value centred in the rest of the pill; the
## tooltip says the cell's label and its whole value ("People: 6,200"). The cells are given, never read from the game; a bad
## tone writes the value in red. With no cells the row hides itself. Issue 436 round 3 (M3): the chips share the row in equal parts
## (four quarters on land), a value too long for its pill clips with an ellipsis (the number never leaves its pill nor widens the
## window); the view's fog word is an eye struck through with "?", and its dash (none) an em dash in the muted colour. A cell with
## `muted` (the never discovered hex's one "Unexplored" chip) is a quiet pill.
class_name StripCells
extends HBoxContainer

## The most cells one strip shows (R10: four).
const MAX_CELLS := 4
## The Kit icon of each cell key; a key missing here shows an empty circle.
const ICONS := {"people": &"people", "food": &"food", "works": &"jobs", "ducats": &"ducats", "income": &"ducats",
	"garrison": &"walls", "buildings": &"settlement", "armies": &"army", "depth": &"wade", "winter": &"season_winter",
	"coast": &"district", "unexplored": &"study"}
## The view's words for "not seen now" and "none", and what the chip shows for them.
const FOG_WORD := "fog"
const NONE_WORDS: Array[String] = ["-", "none"]
const FOG_SHOWN := "?"
const NONE_SHOWN := "—"
const ICON_PX := Vector2(16, 16)
## What each chip's number means, under its label and value in the tooltip.
const MEANINGS := {"people": "The people living on this tile.", "food": "Food a year here: what is made less what is eaten.",
	"works": "Works crews in use, of your country's limit.", "ducats": "The ducats in your treasury.",
	"income": "What this tile brings in a year: its goods at price, dues and taxes, less its upkeep.",
	"depth": "How deep the water is here.", "winter": "How hard the winter is on these waters.",
	"coast": "Who holds the land on this coast.", "unexplored": "None of yours has ever seen this place.",
	"garrison": "The men in the fortress, of its full strength.", "buildings": "The buildings standing on this tile.",
	"armies": "The armies you can see here; fog: none of yours sees the tile now."}
## What the eye struck through means, under the chip's label.
const FOG_MEANING := "Not seen now: none of your armies or lands sees this tile."


## Replaces the cells with `cells` (Array of {key, value, label, tone}); the first MAX_CELLS are shown.
func show_cells(cells: Array) -> void:
	PanelKit.clear_children(self)
	add_theme_constant_override(&"separation", Tokens.S1 + 1)
	visible = not cells.is_empty()
	for i: int in mini(cells.size(), MAX_CELLS):
		add_child(_chip(cells[i] as Dictionary))


## The number of cells shown.
func cell_count() -> int:
	return get_child_count()


## The value texts of the shown cells, in order (tests and tools read them).
func values() -> PackedStringArray:
	var out := PackedStringArray()
	for chip: Node in get_children():
		out.append(str(chip.get_meta("value", "")))
	return out


## The Studiolo variation of a value of this tone (the old strip's; the chips write a bad value in red, the rest plain).
static func variation_of(tone: StringName) -> StringName:
	match tone:
		&"good":
			return &"NumberGood"
		&"bad":
			return &"NumberBad"
		&"warn":
			return &"NumberWarn"
	return &"Number"


func _chip(cell: Dictionary) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"PanelTileChip"
	# The chips share the row in equal parts (M3); the number clips with an ellipsis if its part is too narrow, and the tooltip
	# always says it whole.
	var value_text := str(cell.get("value", ""))
	var fog := value_text == FOG_WORD
	var none := NONE_WORDS.has(value_text)
	var muted := bool(cell.get("muted", false))
	if muted:
		chip.theme_type_variation = &"PanelTileChipMuted"
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.size_flags_stretch_ratio = 1.0
	chip.custom_minimum_size.x = 1.0
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var meaning := FOG_MEANING if fog else str(MEANINGS.get(str(cell.get("key", "")), ""))
	chip.tooltip_text = "%s: %s
%s" % [str(cell.get("label", "")), "none" if none else value_text, meaning]
	chip.set_meta("value", value_text)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", Tokens.S1 + 1)
	chip.add_child(line)
	var dot := PanelContainer.new()
	dot.theme_type_variation = &"PanelTileChipIcon"
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_PX
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta("kit_icon", ICONS.get(str(cell.get("key", "")), &""))
	dot.add_child(icon)
	line.add_child(dot)
	if fog or str(cell.get("key", "")) == "unexplored":
		var eye := TileGlyph.make(TileGlyph.EYE_SLASH, ICON_PX.x)
		icon.add_child(eye)
		eye.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.set_meta("kit_icon", &"")
	var tone := StringName(str(cell.get("tone", "plain")))
	var shown := FOG_SHOWN if fog else (NONE_SHOWN if none else value_text)
	var variation := &"TileValueBad" if tone == &"bad" else &"TileChip"
	if none or muted:
		variation = &"TileValueMuted"
	var value := PanelKit.label(shown, variation)
	value.name = &"Value"
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(value)
	icon.ready.connect(func() -> void: _fill_icon(icon))
	return chip


## The chip's Kit icon, from the theme it lives under (known once it is in the tree).
static func _fill_icon(icon: TextureRect) -> void:
	var icon_name := StringName(str(icon.get_meta("kit_icon", &"")))
	if icon_name != &"" and icon.has_theme_icon(icon_name, &"Kit"):
		icon.texture = icon.get_theme_icon(icon_name, &"Kit")
