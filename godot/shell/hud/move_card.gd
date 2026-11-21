## The move card (docs/architecture/m6-build-spec.md 6.7; L20, issue #210): a hover card with the words of a march to the hex
## under the pointer (or at the order cursor), while an army of yours is selected. MapHover shows it in place of the hex card
## and calls show_move with MovePreview.to's preview: the title (the place), its lines in their tones, and the way out of a
## refusal. It only shows: no buttons, it ignores the mouse and never takes the focus. Ordering is MapArmies' right click and O.
class_name MoveCard
extends PanelContainer

const CARD_W: float = 300.0
const TONE_VARIATIONS: Dictionary[StringName, StringName] = {
	&"good": &"NumberGood",
	&"bad": &"NumberBad",
	&"warn": &"NumberWarn",
	&"muted": &"Hint",
	&"plain": &"Label",
}

@onready var _title: Label = $VBox/Title
@onready var _rows: VBoxContainer = $VBox/Rows
@onready var _way: Label = $VBox/Way

var _open: bool = false


func _ready() -> void:
	custom_minimum_size.x = CARD_W
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	hide_card()


## Shows the words of `preview` (MovePreview.to): the title, one label a line in its tone, and the way out of a refusal.
func show_move(preview: Dictionary) -> void:
	_fill(preview)
	_open = true
	visible = true


## Places the card by `anchor` (the pointer, or the order cursor's hex centre), kept inside `bounds` (MapHover's clamp).
func place(anchor: Vector2, bounds: Rect2) -> void:
	size = Vector2(CARD_W, get_combined_minimum_size().y)
	position = MapHover.clamp_card_position(anchor, size, bounds)


func hide_card() -> void:
	_open = false
	visible = false


func is_open() -> bool:
	return _open


func title_text() -> String:
	return _title.text


func way_text() -> String:
	return _way.text if _way.visible else ""


## The texts of the line labels, in order (the preview's lines).
func line_texts() -> Array[String]:
	var out: Array[String] = []
	for child: Node in _rows.get_children():
		out.append((child as Label).text)
	return out


func _fill(preview: Dictionary) -> void:
	_title.text = str(preview.get("title", ""))
	_title.visible = not _title.text.is_empty()
	_clear_rows()
	for raw: Variant in preview.get("lines", []) as Array:
		var line := raw as Array
		if line.size() < 2:
			continue
		_rows.add_child(_line_label(str(line[0]), StringName(str(line[1]))))
	var way := str(preview.get("way_out", ""))
	_way.text = way
	_way.visible = not way.is_empty()


func _line_label(text: String, tone: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	label.theme_type_variation = TONE_VARIATIONS.get(tone, &"Label")
	return label


func _clear_rows() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.free()  # not in the tree any more: freed now, so no line label outlives its card
