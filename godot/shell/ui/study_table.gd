## Sortable Studiolo data table wrapping a `Tree` with `StudyTree` variation, right-aligned
## tabular numeric columns, stable sorting with tie-breaking by `id`, header sort arrows,
## and row activation (docs/architecture/ui-style-and-feedback-spec.md section 5).
##
## Note: Extends `VBoxContainer` around an inner `Tree` (`tree()`) because Godot 4's `Tree`
## reserves `set_columns(int)` natively, which conflicts with `set_columns(cols: Array)`.
class_name StudyTable
extends VBoxContainer

signal row_activated(row: Dictionary)
signal sort_changed(id: StringName, descending: bool)

var _tree: Tree = null
var _columns: Array[Dictionary] = []
var _rows: Array[Dictionary] = []
var _sort_id: StringName = &""
var _sort_desc: bool = false


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(_on_self_focus_entered)

	_tree = Tree.new()
	_tree.name = &"Tree"
	_tree.theme_type_variation = &"StudyTree"
	_tree.column_titles_visible = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.hide_root = true
	_tree.allow_reselect = true
	_tree.focus_mode = Control.FOCUS_ALL
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.column_title_clicked.connect(_on_column_title_clicked)
	_tree.item_activated.connect(_on_item_activated)
	add_child(_tree)


## Defines the table columns: `[{id: StringName, title: String, kind?: StringName, align?: HorizontalAlignment}]`.
func set_columns(cols: Array) -> void:
	_columns.clear()
	for c_var: Variant in cols:
		if typeof(c_var) != TYPE_DICTIONARY:
			continue
		var col := c_var as Dictionary
		var col_id := StringName(str(col.get("id", "")))
		var title := str(col.get("title", ""))
		var kind := StringName(str(col.get("kind", "")))
		var align := HORIZONTAL_ALIGNMENT_RIGHT if kind == &"number" else HORIZONTAL_ALIGNMENT_LEFT
		if col.has("align") and col["align"] != null:
			align = int(col["align"]) as HorizontalAlignment
		_columns.append({
			"id": col_id,
			"title": title,
			"kind": kind,
			"align": align,
		})

	_tree.columns = maxi(1, _columns.size())
	_apply_column_headers()
	_rebuild_tree()


## Replaces all table rows (`[{id: Variant, hex?: Vector2i, ...}]`).
func set_rows(rows: Array) -> void:
	_rows.clear()
	for r_var: Variant in rows:
		if typeof(r_var) == TYPE_DICTIONARY:
			_rows.append((r_var as Dictionary).duplicate())
	if _sort_id != &"":
		_apply_sort(_sort_id, _sort_desc)
	_rebuild_tree()


## Sorts rows stably by column `id` (breaking ties by row `id`), updates header arrow, and emits `sort_changed`.
func sort_by(id: StringName, descending: bool = false) -> void:
	if _find_column(id).is_empty():
		return
	_sort_id = id
	_sort_desc = descending
	_apply_sort(id, descending)
	_apply_column_headers()
	_rebuild_tree()
	sort_changed.emit(_sort_id, _sort_desc)


## Returns the ordered array of row `id` values currently displayed.
func sorted_ids() -> Array:
	var out: Array = []
	for row: Dictionary in _rows:
		out.append(row.get("id", null))
	return out


## Returns the displayed header title for column `index` (including any active sort arrow).
func column_header(index: int) -> String:
	if index < 0 or index >= _tree.columns:
		return ""
	return _tree.get_column_title(index)


## Returns the underlying Tree node configured with `StudyTree`.
func tree() -> Tree:
	return _tree


func _find_column(id: StringName) -> Dictionary:
	for col: Dictionary in _columns:
		if (col["id"] as StringName) == id:
			return col
	return {}


func _apply_column_headers() -> void:
	for i: int in _columns.size():
		var col := _columns[i]
		var col_id := col["id"] as StringName
		var base_title := str(col["title"])
		if col_id == _sort_id and _sort_id != &"":
			_tree.set_column_title(i, "%s %s" % [base_title, "↓" if _sort_desc else "↑"])
		else:
			_tree.set_column_title(i, base_title)
		_tree.set_column_title_alignment(i, col["align"] as HorizontalAlignment)
		_tree.set_column_expand(i, true)


func _apply_sort(id: StringName, descending: bool) -> void:
	if _rows.size() <= 1:
		return
	var col := _find_column(id)
	var is_num := (col.get("kind", &"") as StringName) == &"number"
	var key_str := String(id)

	var tagged: Array[Dictionary] = []
	for i: int in _rows.size():
		tagged.append({"idx": i, "row": _rows[i]})

	tagged.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := a["row"] as Dictionary
		var rb := b["row"] as Dictionary
		var va: Variant = ra.get(id, ra.get(key_str, ""))
		var vb: Variant = rb.get(id, rb.get(key_str, ""))
		var cmp := _compare_values(va, vb, is_num)
		if cmp != 0:
			return cmp > 0 if descending else cmp < 0
		var id_cmp := _compare_ids(ra.get("id", null), rb.get("id", null))
		if id_cmp != 0:
			return id_cmp < 0
		return int(a["idx"]) < int(b["idx"])
	)

	var sorted_rows: Array[Dictionary] = []
	for entry: Dictionary in tagged:
		sorted_rows.append(entry["row"] as Dictionary)
	_rows = sorted_rows


func _compare_values(a: Variant, b: Variant, force_num: bool) -> int:
	var num_a := typeof(a) in [TYPE_INT, TYPE_FLOAT]
	var num_b := typeof(b) in [TYPE_INT, TYPE_FLOAT]
	if force_num or (num_a and num_b):
		var fa := float(a)
		var fb := float(b)
		if fa < fb:
			return -1
		if fa > fb:
			return 1
		return 0
	var sa := str(a)
	var sb := str(b)
	var ncmp := sa.nocasecmp_to(sb)
	if ncmp != 0:
		return -1 if ncmp < 0 else 1
	if sa < sb:
		return -1
	if sa > sb:
		return 1
	return 0


func _compare_ids(a: Variant, b: Variant) -> int:
	if a == null and b == null:
		return 0
	if a == null:
		return -1
	if b == null:
		return 1
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		var fa := float(a)
		var fb := float(b)
		if fa < fb:
			return -1
		if fa > fb:
			return 1
		return 0
	var sa := str(a)
	var sb := str(b)
	if sa < sb:
		return -1
	if sa > sb:
		return 1
	return 0


func _rebuild_tree() -> void:
	_tree.clear()
	var root := _tree.create_item()
	for r_idx: int in _rows.size():
		var row := _rows[r_idx]
		var item := _tree.create_item(root)
		item.set_metadata(0, r_idx)
		for c_idx: int in _columns.size():
			var col := _columns[c_idx]
			var col_id := col["id"] as StringName
			var key_str := String(col_id)
			var val: Variant = row.get(col_id, row.get(key_str, ""))
			item.set_text(c_idx, str(val))
			item.set_text_alignment(c_idx, col["align"] as HorizontalAlignment)


func _on_self_focus_entered() -> void:
	_tree.grab_focus()


func _on_column_title_clicked(column: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	if column < 0 or column >= _columns.size():
		return
	var col_id := _columns[column]["id"] as StringName
	var next_desc := (not _sort_desc) if col_id == _sort_id else false
	sort_by(col_id, next_desc)


func _on_item_activated() -> void:
	var sel := _tree.get_selected()
	if sel == null:
		return
	var idx := int(sel.get_metadata(0))
	if idx >= 0 and idx < _rows.size():
		row_activated.emit(_rows[idx])
