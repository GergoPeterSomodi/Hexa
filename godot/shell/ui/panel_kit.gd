## Pieces the shell's panels build from: a label of a Studiolo Theme type (`TitlePanel`, `SectionHead`, `Hint`,
## `TableRow`, `Reason`), the grey reason line under a refused action, a key and value ledger grid, and clearing a
## container without leaking detached orphans. Static: holds no state and reads no game.
class_name PanelKit
extends RefCounted


## A label of a Studiolo Theme variation (`TitlePanel`, `SectionHead`, `Hint`, `TableRow`, `Reason`, etc.).
static func label(text: String, variation: StringName) -> Label:
	var out := Label.new()
	out.text = text
	out.theme_type_variation = variation
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return out


## The short grey line under a refused action (or any note); it wraps within its container.
static func reason(text: String) -> Label:
	var out := label(text, &"Reason")
	out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return out


## Fills a two-column ledger grid with key (`Hint`) and value (`TableRow`) labels; pairs holds key, value, ...
static func fill_rows(grid: GridContainer, pairs: Array[String], retired: Array[Node] = []) -> void:
	clear_children(grid, retired)
	for at: int in range(0, pairs.size(), 2):
		grid.add_child(label(pairs[at], &"Hint"))
		var value := label(pairs[at + 1], &"TableRow")
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)


## Takes every child off a node and queues it for deletion. When `retired` is supplied, detached nodes are tracked
## so the owning panel can free any remaining valid nodes synchronously in `_exit_tree()` (zero orphans).
static func clear_children(node: Node, retired: Array[Node] = []) -> void:
	prune_retired(retired)
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
		retired.append(child)


## Frees every still-valid node in `retired` (typically called from `_exit_tree()`) and clears the array.
static func free_retired(retired: Array[Node]) -> void:
	for child: Node in retired:
		if is_instance_valid(child):
			child.free()
	retired.clear()


## Removes already-freed entries from `retired`.
static func prune_retired(retired: Array[Node]) -> void:
	var idx := retired.size() - 1
	while idx >= 0:
		if not is_instance_valid(retired[idx]):
			retired.remove_at(idx)
		idx -= 1
