## Non-blocking Studiolo hover card displaying a title, optional subtitle, rule, and
## [text, tone, amount] rows with right-aligned tabular amounts
## (docs/architecture/ui-and-controls-spec.md section 3.5).
class_name HoverCard
extends PanelContainer

const _TONE_VARIATIONS: Dictionary[StringName, StringName] = {
	&"good": &"NumberGood",
	&"bad": &"NumberBad",
	&"warn": &"NumberWarn",
	&"muted": &"Hint",
	&"plain": &"Label",
}

var _title_label: Label = null
var _subtitle_label: Label = null
var _rule: HSeparator = null
var _rows: VBoxContainer = null
var _refs_bound: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_refs()


## Populates and shows the card from `card` (matching `HexCard.of` or `{title, subtitle, lines}`),
## or clears and hides the card when `card` is empty.
func show_card(card: Dictionary) -> void:
	_ensure_refs()
	PanelKit.clear_children(_rows)
	if card.is_empty():
		_title_label.text = ""
		_subtitle_label.text = ""
		visible = false
		return

	var title_text := str(card.get("title", ""))
	var sub_text := str(card.get("subtitle", ""))
	_title_label.text = title_text
	_title_label.visible = not title_text.is_empty()
	_subtitle_label.text = sub_text
	_subtitle_label.visible = not sub_text.is_empty()

	var raw_lines: Variant = card.get("lines", card.get("rows", []))
	var lines: Array = raw_lines if raw_lines is Array else []
	_rule.visible = (_title_label.visible or _subtitle_label.visible) and not lines.is_empty()

	for raw_row: Variant in lines:
		if not (raw_row is Array):
			continue
		var row := raw_row as Array
		if row.size() < 2:
			continue
		var row_text := str(row[0])
		var tone := StringName(str(row[1]))
		var amount_text := str(row[2]) if row.size() >= 3 else ""
		if tone == &"rule":
			var sep := HSeparator.new()
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_rows.add_child(sep)
			continue
		_rows.add_child(_build_row(row_text, tone, amount_text))

	accessibility_name = title_text
	visible = true


## Clears all rows and hides the hover card.
func clear() -> void:
	show_card({})


## Returns the VBoxContainer holding the rendered row nodes.
func rows_container() -> VBoxContainer:
	_ensure_refs()
	return _rows


func _ensure_refs() -> void:
	if _refs_bound:
		return
	_title_label = get_node("VBox/Title") as Label
	_subtitle_label = get_node("VBox/Subtitle") as Label
	_rule = get_node("VBox/Rule") as HSeparator
	_rows = get_node("VBox/Rows") as VBoxContainer
	_refs_bound = true


func _build_row(row_text: String, tone: StringName, amount_text: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var text_lbl := Label.new()
	text_lbl.name = &"Text"
	text_lbl.text = row_text
	text_lbl.theme_type_variation = &"Hint" if tone == &"muted" else &"TableRow"
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_lbl)

	if not amount_text.is_empty():
		var amt_lbl := Label.new()
		amt_lbl.name = &"Amount"
		amt_lbl.text = amount_text
		amt_lbl.theme_type_variation = _TONE_VARIATIONS.get(tone, &"Label")
		amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(amt_lbl)

	return hbox
