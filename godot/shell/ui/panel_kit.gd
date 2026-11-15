## Pieces the shell's panels build from: a label of a Theme type (the names are shell/ui/theme.tres's), the grey reason
## line that says why an action is refused, a key and value grid, and the clearing of a container. Static: holds no state
## and reads no game. The look is the Theme's; this file only picks the type and fills the text.
class_name PanelKit
extends RefCounted


## A label of a Theme type: HexTitle, HexSection, HexKey, HexValue or HexReason.
static func label(text: String, variation: StringName) -> Label:
	var out := Label.new()
	out.text = text
	out.theme_type_variation = variation
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return out


## The short grey line under a refused action (or any note); it wraps within its container.
static func reason(text: String) -> Label:
	var out := label(text, &"HexReason")
	out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return out


## Fills a two-column grid with key and value labels; pairs holds key, value, key, value, and so on.
static func fill_rows(grid: GridContainer, pairs: Array[String]) -> void:
	clear_children(grid)
	for at: int in range(0, pairs.size(), 2):
		grid.add_child(label(pairs[at], &"HexKey"))
		var value := label(pairs[at + 1], &"HexValue")
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)


## Takes every child off a node and frees it. The children leave the tree at once, so counts are right after the call.
static func clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
