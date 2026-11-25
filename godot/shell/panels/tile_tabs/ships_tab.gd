## The Ships tab of the tile window (tile-window spec R23, D5; TW13). It shows only on the player's own port settlements
## (TileView's own_port: the own case and Improve.is_port), as one empty bordered box: "No ships yet" and a line saying
## the ships and shipyards come later. No button, no list, and it is never dimmed (D5). Pure text and theme variations.
class_name ShipsTab
extends TileTab

const ID := &"ships"
const LABEL := "Ships"
const ORDER := 40

const HEADING := "No ships yet"
const NOTE := "Ships and shipyards arrive with a later milestone. This tab is here so ports have a place for them."

var _retired: Array[Node] = []


static func applies(view: Dictionary) -> bool:
	return bool(view.get("own_port", false))


static func dimmed(_view: Dictionary) -> String:
	return ""


## Fills the box for the hex. The hex and the game are not read: the box says the same for every own port.
func fill(_game: Game, _viewer: StringName, _hex: Vector2i, _view: Dictionary) -> void:
	PanelKit.clear_children(self, _retired)
	var box := PanelContainer.new()
	box.name = &"EmptyBox"
	box.theme_type_variation = &"PanelSlot"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var column := VBoxContainer.new()
	column.name = &"Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(column)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.custom_minimum_size.y = 96.0
	var heading := PanelKit.label(HEADING, &"TileName")
	heading.name = &"Heading"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var note := PanelKit.reason(NOTE)
	note.name = &"Note"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)


func _exit_tree() -> void:
	PanelKit.free_retired(_retired)
