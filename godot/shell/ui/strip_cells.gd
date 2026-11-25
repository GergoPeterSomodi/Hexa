## The number strip of the tile window (tile-window spec R10, D10): up to four cells of TileView.strip, each a value over
## its caption, in equal columns. The cells are given, never read from the game; a tone picks the value's Studiolo variation
## (plain, good, bad, warn). With no cells the strip hides itself (sea, unexplored).
class_name StripCells
extends HBoxContainer

## The most cells one strip shows (R10: four).
const MAX_CELLS := 4


## Replaces the cells with `cells` (Array of {key, value, label, tone}); the first MAX_CELLS are shown.
func show_cells(cells: Array) -> void:
	PanelKit.clear_children(self)
	visible = not cells.is_empty()
	for i: int in mini(cells.size(), MAX_CELLS):
		var cell := cells[i] as Dictionary
		add_child(_cell_box(cell))


## The number of cells shown.
func cell_count() -> int:
	return get_child_count()


## The value texts of the shown cells, in order (tests and tools read them).
func values() -> PackedStringArray:
	var out := PackedStringArray()
	for box: Node in get_children():
		var value := box.get_child(0) as Label
		out.append(value.text if value != null else "")
	return out


## The Studiolo variation of a value of this tone.
static func variation_of(tone: StringName) -> StringName:
	match tone:
		&"good":
			return &"NumberGood"
		&"bad":
			return &"NumberBad"
		&"warn":
			return &"NumberWarn"
	return &"Number"


func _cell_box(cell: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tone := StringName(str(cell.get("tone", "plain")))
	var value := PanelKit.label(str(cell.get("value", "")), variation_of(tone))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.clip_text = true
	box.add_child(value)
	var caption := PanelKit.label(str(cell.get("label", "")), &"Hint")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.clip_text = true
	box.add_child(caption)
	return box
