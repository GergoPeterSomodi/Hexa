## The hover card of a tile window row (issue 436 round 3, H5): a building tile's or a company row's card (RowCard.hover_of) at a
## fixed 320 logical pixels wide. A title band in the window's title-bar style (the action, "Upgrade to city", in the title serif,
## with what stands now as its subtitle), then the sections: small-caps heads, rows of a label (at most 40 % of the width, with a
## small icon where the row has one: ducats, a good, the building time...) and a value that wraps rather than widen the card, a
## rule, and the verdict in its tone. Built in code; it takes no pointer. The Hud places it beside the hovered row (RowCard.place).
class_name TileHoverCard
extends PanelContainer

## The card's width, in logical pixels.
const WIDTH := 320.0
## The value column's share against the label's 1.0 (the label gets 40 %).
const VALUE_SHARE := 1.5
const ICON_PX := Vector2(16, 16)
## The tone of a value -> its variation.
const TONES := {&"good": &"TileValueGood", &"bad": &"TileValueBad", &"warn": &"TileValueMuted", &"muted": &"TileValueMuted"}
## The tone of a line with no value (the verdict) -> its variation.
const LINE_TONES := {&"good": &"TileHintGood", &"bad": &"TileHintBad", &"warn": &"TileHintWarn"}
## The Kit icon of a row by its label (lower case); a good's row takes the good's icon.
const ROW_ICONS := {"ducats": &"ducats", "profit a year": &"ducats", "upkeep a year": &"upkeep", "building time": &"hourglass",
	"payback": &"payback", "workers": &"jobs", "men": &"people", "men from the people": &"people", "food a season": &"food",
	"attack and defence": &"attack"}

var _title: Label
var _subtitle: Label
var _rows: VBoxContainer


func _init() -> void:
	name = &"TileHoverCard"
	theme_type_variation = &"PanelTileCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = WIDTH
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 0)
	add_child(column)
	var band := PanelContainer.new()
	band.theme_type_variation = &"PanelTileCardHead"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(band)
	var words := VBoxContainer.new()
	words.add_theme_constant_override(&"separation", 0)
	band.add_child(words)
	_title = _wrapped("", &"TileCardTitle")
	words.add_child(_title)
	_subtitle = _wrapped("", &"TileHint")
	words.add_child(_subtitle)
	var body := PanelContainer.new()
	body.theme_type_variation = &"PanelTileCardBody"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 4)
	body.add_child(_rows)


## Shows `card` ({title, subtitle, lines: [[text, tone, amount?]]}; tone &"head" is a section head, &"rule" a rule), or hides
## the card when it is empty.
func show_card(card: Dictionary) -> void:
	PanelKit.clear_children(_rows)
	visible = not card.is_empty()
	if card.is_empty():
		return
	_title.text = str(card.get("title", ""))
	_subtitle.text = str(card.get("subtitle", ""))
	_subtitle.visible = _subtitle.text != ""
	for raw: Variant in card.get("lines", []) as Array:
		var line := raw as Array
		if line.size() < 2:
			continue
		var tone := StringName(str(line[1]))
		if tone == &"rule":
			_rows.add_child(HSeparator.new())
		elif tone == &"head":
			var head := PanelKit.label(str(line[0]), &"TileHead")
			head.uppercase = true
			_rows.add_child(head)
		elif line.size() >= 3 and str(line[2]) != "":
			_rows.add_child(_row(str(line[0]), str(line[2]), tone))
		else:
			_rows.add_child(_wrapped(str(line[0]), LINE_TONES.get(tone, &"TileText")))
	accessibility_name = _title.text
	size = Vector2(WIDTH, 0.0)


## Takes the card away.
func clear() -> void:
	show_card({})


## The title shown (tests).
func title_text() -> String:
	return _title.text


## The row nodes (tests).
func rows_container() -> VBoxContainer:
	return _rows


func _row(label_text: String, value_text: String, tone: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", Tokens.S1 + 2)
	var icon_name := _icon_of(label_text)
	var key := HBoxContainer.new()
	key.add_theme_constant_override(&"separation", Tokens.S1)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	key.size_flags_stretch_ratio = 1.0
	if icon_name != &"" and has_theme_icon(icon_name, &"Kit"):
		var icon := TextureRect.new()
		icon.custom_minimum_size = ICON_PX
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		icon.texture = get_theme_icon(icon_name, &"Kit")
		key.add_child(icon)
	var label := _wrapped(label_text, &"TileText")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.add_child(label)
	row.add_child(key)
	var value := _wrapped(value_text, TONES.get(tone, &"TileValue"))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.size_flags_stretch_ratio = VALUE_SHARE
	row.add_child(value)
	return row


## A row's Kit icon: by its label, else the good it names ("Timber" -> good_timber); &"" for none.
func _icon_of(label_text: String) -> StringName:
	var key := label_text.to_lower()
	if ROW_ICONS.has(key):
		return ROW_ICONS[key]
	var good := StringName("good_" + key.replace(" ", "_"))
	return good if has_theme_icon(good, &"Kit") else &""


static func _wrapped(text: String, variation: StringName) -> Label:
	var label := PanelKit.label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size.x = 1.0
	return label
