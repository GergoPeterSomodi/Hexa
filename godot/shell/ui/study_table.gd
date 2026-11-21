## StudyTable: the Studiolo's sortable data table (m4-5-build-spec.md 6.2; ui-style-and-feedback-spec.md section 5).
## A pure view over a plain Array of Dictionaries: it reads no game state.
##
## It is a VBoxContainer around one inner Tree (`tree()`, theme type StudyTree). The spec says "extends Tree", but a Tree
## already has a native set_columns(int), which a subclass cannot override with set_columns(Array); the wrapper is the one
## the M4.5 stub chose for that reason. Rows are built 100 at a time with a "Show more" row. Sorting compares the cell
## values and breaks ties by row id ascending, so equal values keep one order both ways. The sort is the table's own state;
## no signal reports it.
class_name StudyTable
extends VBoxContainer

const PAGE := 100
const KINDS: Array[StringName] = [&"text", &"number", &"delta", &"bar", &"spark", &"button"]
const _MORE := -1
const TEXT_PAD := 20.0
const HEAD_PAD := 16.0
const RATIO_UNIT := 16
const DELTA_ICON := 20.0
const CELL_PAD := 4.0
const BAR_H := 10.0
const TRACK_ALPHA := 0.4
const _UP_ARROW := "↑"
const _DOWN_ARROW := "↓"
const _SHOW_MORE_FORMAT := "Showing %d of %s · Enter: show %d more"
const _MINUS := "−"

signal row_activated(row: Dictionary)
signal row_selected(row: Dictionary)

## The caller's section title ("Districts"): the table's accessible name.
var section_title: String = "":
	set(value):
		section_title = value
		_update_accessibility()

var _grid: _StudyGrid = null
var _columns: Array[Dictionary] = []
var _rows: Array[Dictionary] = []
var _index_of_id: Dictionary = {}
var _order: Array[int] = []
var _sort_id: StringName = &""
var _sort_desc: bool = false
var _shown: int = PAGE
var _has_selection: bool = false
var _selected_id: int = 0
var _quiet: int = 0
var _refit_queued: bool = false


## A Tree that offers each key press to its owner while it has focus, before the Tree's own arrows (`on_key` returns
## true when the owner used the key, and the press is then handled). Godot does not expose the Tree's gui input to scripts.
class _StudyGrid extends Tree:
	var on_key: Callable = Callable()

	func _input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key == null or not key.pressed or key.echo or not on_key.is_valid() or not has_focus():
			return
		if bool(on_key.call(key)):
			get_viewport().set_input_as_handled()


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_grid = _StudyGrid.new()
	_grid.name = &"Grid"
	_grid.theme_type_variation = &"StudyTree"
	_grid.column_titles_visible = true
	_grid.select_mode = Tree.SELECT_ROW
	_grid.hide_root = true
	_grid.allow_reselect = true
	_grid.focus_mode = Control.FOCUS_ALL
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.on_key = _on_grid_key
	_grid.column_title_clicked.connect(_on_column_title_clicked)
	_grid.item_selected.connect(_on_item_selected)
	_grid.item_activated.connect(_on_item_activated)
	_grid.resized.connect(_on_grid_resized)
	_grid.button_clicked.connect(_on_button_clicked)
	add_child(_grid)


## The inner Tree (theme StudyTree). Tests and the page use it for focus only.
func tree() -> Tree:
	return _grid


## Defines the columns: `[{id, title, kind (text, number, delta, bar, spark, button), align ("left" or "right"),
## expand, min_width, ink (0 to 4, bar and spark), descending_first (default true for numeric kinds), sortable}]`.
## A column without a known kind is text; a non-Dictionary entry is skipped with an error.
func set_columns(cols: Array) -> void:
	_columns.clear()
	for c_var: Variant in cols:
		if typeof(c_var) != TYPE_DICTIONARY:
			push_error("StudyTable: a column must be a Dictionary; skipped")
			continue
		_columns.append(_normalize_column(c_var as Dictionary))
	if _sort_id != &"" and _column_index(_sort_id) < 0:
		_sort_id = &""
		_sort_desc = false
	_grid.columns = maxi(1, _columns.size())
	_apply_headers()
	_resort()


## Replaces the rows: `[{id: int, cells: {column id: value | {value, text, tone, icon}}, hex?: Vector2i, mine?: bool,
## data?: Variant}]`. A row without an int id, or with an id already used, is refused with an error and skipped. The
## selection stays on its id; the number of rows shown stays (never under one page).
func set_rows(rows: Array) -> void:
	_rows.clear()
	_index_of_id.clear()
	for r_var: Variant in rows:
		if typeof(r_var) != TYPE_DICTIONARY:
			push_error("StudyTable: a row must be a Dictionary; skipped")
			continue
		var row := (r_var as Dictionary).duplicate()
		var rid: Variant = row.get("id", null)
		if typeof(rid) != TYPE_INT:
			push_error("StudyTable: a row needs an int id; skipped")
			continue
		if _index_of_id.has(int(rid)):
			push_error("StudyTable: duplicate row id %d; skipped" % int(rid))
			continue
		_index_of_id[int(rid)] = _rows.size()
		_rows.append(row)
	_resort()


## Sorts by column `id` (a sortable column; others are ignored), ties by row id ascending, and shows the arrow in its title.
func sort_by(id: StringName, descending: bool = false) -> void:
	var c := _column_index(id)
	if c < 0 or not bool(_columns[c]["sortable"]):
		return
	_sort_id = id
	_sort_desc = descending
	_apply_headers()
	_resort()


## The sort as `{id, descending}`; an empty id means the rows keep the order they were given.
func sort_state() -> Dictionary:
	return {"id": _sort_id, "descending": _sort_desc}


## Restores a sort from `sort_state()`.
func set_sort_state(state: Dictionary) -> void:
	var id := StringName(str(state.get("id", "")))
	if id == &"":
		_sort_id = &""
		_sort_desc = false
		_apply_headers()
		_resort()
		return
	sort_by(id, bool(state.get("descending", false)))


## Every row id in display order (all rows, not only the shown ones).
func sorted_ids() -> Array:
	var out: Array = []
	for ri: int in _order:
		out.append(_row_id(ri))
	return out


## The header text of column `index`, with its sort arrow.
func column_header(index: int) -> String:
	if index < 0 or index >= _grid.columns:
		return ""
	return _grid.get_column_title(index)


## Selects the row with `id` (quietly: no row_selected). Clears the selection when no row has that id.
func select_id(id: int) -> void:
	_has_selection = true
	_selected_id = id
	_rebuild()


## The selected row (a copy), or an empty Dictionary.
func selected_row() -> Dictionary:
	if not _has_selection or not _index_of_id.has(_selected_id):
		return {}
	return _rows[int(_index_of_id[_selected_id])].duplicate()


## Shows the next PAGE rows.
func show_more() -> void:
	var total := _order.size()
	var have := shown_count()
	if have >= total:
		return
	_shown = mini(have + PAGE, total)
	_rebuild()


## How many data rows are built now.
func shown_count() -> int:
	return mini(_shown, _order.size())


## How many rows the table holds.
func total_count() -> int:
	return _order.size()


## One row's accessible text: "Genoa (you), A year 41, Gain 12" (the first text cell, then the other cells with their titles).
func row_name(id: int) -> String:
	if not _index_of_id.has(id):
		return ""
	var row: Dictionary = _rows[int(_index_of_id[id])]
	var parts: PackedStringArray = PackedStringArray()
	for c: int in _columns.size():
		var col: Dictionary = _columns[c]
		if col["kind"] == &"button":
			continue
		var text := _display(col, _cell(row, col))
		if bool(row.get("mine", false)) and c == _first_text_column():
			text += " (you)"
		if c == _first_text_column() or text == "":
			parts.append(text)
		else:
			parts.append("%s %s" % [str(col["title"]), text])
	return ", ".join(parts)


## The table's one-sentence summary, also its accessible description: "Districts: 1,043 rows, 100 shown, sorted by A year, highest first."
func summary() -> String:
	var head := section_title if section_title != "" else "Table"
	var text := "%s: %s rows, %d shown" % [head, InkMarks.grouped(_order.size()), shown_count()]
	if _sort_id != &"":
		var c := _column_index(_sort_id)
		if c >= 0:
			text += ", sorted by %s, %s" % [str(_columns[c]["title"]), "highest first" if _sort_desc else "lowest first"]
	return text + "."


func _normalize_column(d: Dictionary) -> Dictionary:
	var kind := StringName(str(d.get("kind", "text")))
	if not KINDS.has(kind):
		push_error("StudyTable: unknown column kind '%s'; text used" % String(kind))
		kind = &"text"
	var numeric := kind == &"number" or kind == &"delta" or kind == &"bar" or kind == &"spark"
	var align := HORIZONTAL_ALIGNMENT_RIGHT if (kind == &"number" or kind == &"delta") else HORIZONTAL_ALIGNMENT_LEFT
	var align_text := str(d.get("align", ""))
	if align_text == "right":
		align = HORIZONTAL_ALIGNMENT_RIGHT
	elif align_text == "left":
		align = HORIZONTAL_ALIGNMENT_LEFT
	var id := StringName(str(d.get("id", "")))
	return {
		"id": id,
		"title": str(d.get("title", str(id))),
		"kind": kind,
		"align": align,
		"expand": bool(d.get("expand", kind == &"text")),
		"min_width": int(d.get("min_width", 0)),
		"ink": posmod(int(d.get("ink", 0)), InkMarks.FILLS.size()),
		"descending_first": bool(d.get("descending_first", numeric)),
		"sortable": bool(d.get("sortable", kind != &"button")),
	}


func _column_index(id: StringName) -> int:
	for i: int in _columns.size():
		if (_columns[i]["id"] as StringName) == id:
			return i
	return -1


func _first_text_column() -> int:
	for i: int in _columns.size():
		if _columns[i]["kind"] == &"text":
			return i
	return 0


func _row_id(ri: int) -> int:
	return int(_rows[ri]["id"])


func _cell(row: Dictionary, col: Dictionary) -> Variant:
	var cells: Variant = row.get("cells", {})
	if typeof(cells) != TYPE_DICTIONARY:
		return null
	var d := cells as Dictionary
	var key := col["id"] as StringName
	if d.has(key):
		return d[key]
	return d.get(String(key), null)


## The value a cell sorts by: a number, a text, or for a spark the last point.
func _sort_value(ri: int, c: int) -> Variant:
	var cell: Variant = _cell(_rows[ri], _columns[c])
	if typeof(cell) == TYPE_DICTIONARY:
		var d := cell as Dictionary
		cell = d["value"] if d.has("value") else d.get("text", "")
	if cell is PackedInt32Array:
		var pa := cell as PackedInt32Array
		return pa[pa.size() - 1] if not pa.is_empty() else 0
	if cell is Array:
		var arr := cell as Array
		return arr[arr.size() - 1] if not arr.is_empty() else 0
	return cell


func _before(a: int, b: int, c: int, desc: bool) -> bool:
	var numeric: bool = _columns[c]["kind"] != &"text"
	var cmp := _compare(_sort_value(a, c), _sort_value(b, c), numeric)
	if cmp != 0:
		return cmp > 0 if desc else cmp < 0
	return _row_id(a) < _row_id(b)


func _compare(a: Variant, b: Variant, numeric: bool) -> int:
	if numeric:
		var fa := _number(a)
		var fb := _number(b)
		return -1 if fa < fb else (1 if fa > fb else 0)
	var sa := _text_of(a)
	var sb := _text_of(b)
	var cmp: int = signi(sa.naturalnocasecmp_to(sb))
	return cmp


func _number(v: Variant) -> float:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT:
			return float(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return float(str(v))
		TYPE_BOOL:
			return 1.0 if bool(v) else 0.0
	return 0.0


func _text_of(v: Variant) -> String:
	return "" if v == null else str(v)


func _resort() -> void:
	_order.clear()
	for i: int in _rows.size():
		_order.append(i)
	if _sort_id != &"":
		var c := _column_index(_sort_id)
		var desc := _sort_desc
		_order.sort_custom(func(a: int, b: int) -> bool: return _before(a, b, c, desc))
	_rebuild()


func _position_of(id: int) -> int:
	for k: int in _order.size():
		if _row_id(_order[k]) == id:
			return k
	return -1


func _rebuild() -> void:
	_quiet += 1
	_grid.clear()
	var root := _grid.create_item()
	var total := _order.size()
	# The requested page count is kept (a shorter refresh draws fewer rows, a longer one the same page again); only a
	# selected row beyond it grows the page, so it stays in view.
	var shown := maxi(_shown, PAGE)
	if _has_selection:
		var pos := _position_of(_selected_id)
		if pos >= shown:
			shown = (floori(float(pos) / PAGE) + 1) * PAGE
			_shown = shown
	var n := mini(shown, total)
	var sel_item: TreeItem = null
	for k: int in n:
		var ri := _order[k]
		var item := _grid.create_item(root)
		item.set_metadata(0, ri)
		_fill_row(item, _rows[ri])
		if _has_selection and _row_id(ri) == _selected_id:
			sel_item = item
	if total > n:
		var more := _grid.create_item(root)
		more.set_metadata(0, _MORE)
		more.set_text(0, _SHOW_MORE_FORMAT % [n, InkMarks.grouped(total), mini(PAGE, total - n)])
	if sel_item != null:
		_grid.set_selected(sel_item, 0)
	_fit_columns()
	_quiet -= 1
	_update_accessibility()


## Every column is at least as wide as its widest cell and its heading (with room for the sort arrow), so nothing is cut
## unless the page itself is too narrow; the free width goes to the expanding (text) columns in proportion to their need,
## and the number columns shrink to their content. The full text is also each text cell's tooltip.
func _fit_columns() -> void:
	if _columns.is_empty():
		return
	var font := _grid.get_theme_font(&"font", &"StudyTree")
	var size := _grid.get_theme_font_size(&"font_size", &"StudyTree")
	var head_font := _grid.get_theme_font(&"title_button_font", &"StudyTree")
	var head_size := _grid.get_theme_font_size(&"title_button_font_size", &"StudyTree")
	var n := mini(maxi(_shown, PAGE), _order.size())
	for c: int in _columns.size():
		var col: Dictionary = _columns[c]
		var kind: StringName = col["kind"]
		var head := str(col["title"])
		var need := 0.0
		if head != "":
			need = head_font.get_string_size(head + " " + _DOWN_ARROW, HORIZONTAL_ALIGNMENT_LEFT, -1, head_size).x + HEAD_PAD
		if kind == &"text" or kind == &"number" or kind == &"delta":
			var widest := 0.0
			for k: int in n:
				widest = maxf(widest, font.get_string_size(_display(col, _cell(_rows[_order[k]], col)), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
			need = maxf(need, widest + TEXT_PAD + (DELTA_ICON if kind == &"delta" else 0.0))
		var min_w := maxi(int(col["min_width"]), ceili(need))
		_grid.set_column_custom_minimum_width(c, min_w)
		if kind == &"text" and bool(col["expand"]):
			# Small ratios: the Tree shares its spare width only while that is at least the sum of the ratios.
			_grid.set_column_expand_ratio(c, maxi(1, roundi(float(min_w) / RATIO_UNIT)))


## The Tree shares its free width among the expanding columns when it is laid out; a resize after that (the page growing
## to its frame) leaves the old shares, so the columns are set again on the next idle frame.
func _on_grid_resized() -> void:
	if _refit_queued:
		return
	_refit_queued = true
	_refit.call_deferred()


func _refit() -> void:
	_refit_queued = false
	if not is_inside_tree():
		return
	for c: int in _columns.size():
		_grid.set_column_expand(c, not bool(_columns[c]["expand"]))
		_grid.set_column_expand(c, bool(_columns[c]["expand"]))
	_fit_columns()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_ENTER_TREE:
		if _grid != null:
			_fit_columns()


func _fill_row(item: TreeItem, row: Dictionary) -> void:
	for c: int in _columns.size():
		var col: Dictionary = _columns[c]
		var cell: Variant = _cell(row, col)
		var mine := bool(row.get("mine", false))
		match col["kind"]:
			&"number":
				_fill_number(item, c, col, cell, mine)
			&"delta":
				_fill_delta(item, c, col, cell)
			&"bar":
				_fill_bar(item, c, col, cell)
			&"spark":
				_fill_spark(item, c, col, cell)
			&"button":
				_fill_button(item, c, cell)
			_:
				_fill_text(item, c, col, cell, mine)


func _fill_text(item: TreeItem, c: int, col: Dictionary, cell: Variant, mine: bool) -> void:
	var text := _cell_text(cell)
	if mine and c == _first_text_column():
		text += " (you)"
	item.set_text(c, text)
	item.set_tooltip_text(c, text)
	item.set_text_alignment(c, col["align"] as HorizontalAlignment)
	if mine:
		item.set_custom_color(c, _mine_colour())
	elif typeof(cell) == TYPE_DICTIONARY and (cell as Dictionary).has("tone"):
		var tone := StringName(str((cell as Dictionary)["tone"]))
		if tone == &"good" or tone == &"bad" or tone == &"warn":
			item.set_custom_color(c, _tone_colour(tone))


func _fill_number(item: TreeItem, c: int, col: Dictionary, cell: Variant, mine: bool) -> void:
	var value := int(_number(_cell_value(cell)))
	item.set_text(c, _cell_text_or(cell, InkMarks.grouped(value)))
	item.set_text_alignment(c, col["align"] as HorizontalAlignment)
	if mine:
		item.set_custom_color(c, _mine_colour())


func _fill_delta(item: TreeItem, c: int, col: Dictionary, cell: Variant) -> void:
	var value := int(_number(_cell_value(cell)))
	var icon_name := &"dash"
	var tone := &"muted"
	if value > 0:
		icon_name = &"arrow_up"
		tone = &"good"
	elif value < 0:
		icon_name = &"arrow_down"
		tone = &"bad"
	if typeof(cell) == TYPE_DICTIONARY and (cell as Dictionary).has("tone"):
		tone = StringName(str((cell as Dictionary)["tone"]))
	var colour := _tone_colour(tone)
	item.set_text(c, _cell_text_or(cell, _signed_text(value)))
	item.set_text_alignment(c, col["align"] as HorizontalAlignment)
	item.set_icon(c, _icon(icon_name))
	item.set_icon_modulate(c, colour)
	item.set_custom_color(c, colour)


func _fill_bar(item: TreeItem, c: int, col: Dictionary, cell: Variant) -> void:
	var permille := clampi(int(_number(_cell_value(cell))), 0, 1000)
	var colour := _ink(int(col["ink"]))
	item.set_cell_mode(c, TreeItem.CELL_MODE_CUSTOM)
	item.set_custom_draw_callback(c, _draw_bar.bind(permille, colour))


func _fill_spark(item: TreeItem, c: int, col: Dictionary, cell: Variant) -> void:
	var values := PackedInt32Array()
	var raw: Variant = _cell_value(cell)
	if raw is PackedInt32Array:
		values = raw as PackedInt32Array
	elif raw is Array:
		for v: Variant in raw as Array:
			values.append(int(_number(v)))
	var colour := _ink(int(col["ink"]))
	item.set_cell_mode(c, TreeItem.CELL_MODE_CUSTOM)
	item.set_custom_draw_callback(c, _draw_spark.bind(values, colour))


## A row whose button cell is null or an empty string has no button (it opts out).
func _fill_button(item: TreeItem, c: int, cell: Variant) -> void:
	if cell == null or (typeof(cell) == TYPE_STRING and str(cell) == ""):
		return
	var tip := _cell_text_or(cell, "Go")
	item.add_button(c, _icon(&"go"), 0, false, tip)


func _draw_bar(_item: Object, rect: Rect2, permille: int, colour: Color) -> void:
	var h := minf(rect.size.y - 2.0 * CELL_PAD, BAR_H)
	var inner := Rect2(rect.position + Vector2(CELL_PAD, (rect.size.y - h) * 0.5), Vector2(rect.size.x - 2.0 * CELL_PAD, h))
	InkMarks.bar(_grid, inner, permille, colour, track_ink(_grid))
	_grid.draw_rect(inner.grow(-0.5), Tokens.RULE, false, 1.0)


func _draw_spark(_item: Object, rect: Rect2, values: PackedInt32Array, colour: Color) -> void:
	InkMarks.spark(_grid, rect.grow_individual(-CELL_PAD, -CELL_PAD, -CELL_PAD, -CELL_PAD), values, colour)


func _cell_value(cell: Variant) -> Variant:
	if typeof(cell) == TYPE_DICTIONARY:
		return (cell as Dictionary).get("value", 0)
	return cell if cell != null else 0


## The text a cell shows (and its accessible name carries): grouped numbers, signed deltas, a given text otherwise.
func _display(col: Dictionary, cell: Variant) -> String:
	var kind: StringName = col["kind"]
	if kind == &"number":
		return _cell_text_or(cell, InkMarks.grouped(int(_number(_cell_value(cell)))))
	if kind == &"delta":
		return _cell_text_or(cell, _signed_text(int(_number(_cell_value(cell)))))
	if kind == &"bar" or kind == &"spark" or kind == &"button":
		return _cell_text_or(cell, "")
	return _cell_text(cell)


func _signed_text(value: int) -> String:
	if value > 0:
		return "+" + InkMarks.grouped(value)
	if value < 0:
		return _MINUS + InkMarks.grouped(absi(value))
	return "0"


func _cell_text(cell: Variant) -> String:
	if typeof(cell) == TYPE_DICTIONARY:
		var d := cell as Dictionary
		if d.has("text"):
			return str(d["text"])
		return _text_of(d.get("value", ""))
	return _text_of(cell)


## A given cell text (an empty one counts as none) or the fallback.
func _cell_text_or(cell: Variant, fallback: String) -> String:
	if typeof(cell) == TYPE_DICTIONARY and (cell as Dictionary).has("text"):
		var given := str((cell as Dictionary)["text"])
		if given != "":
			return given
	return fallback


func _tone_colour(tone: StringName) -> Color:
	match tone:
		&"good":
			return Tokens.GOOD
		&"bad":
			return Tokens.BAD
		&"warn":
			return Tokens.WARN
	return Tokens.MUTED


func _mine_colour() -> Color:
	if _grid.has_theme_color(&"font_color", &"TableHeader"):
		return _grid.get_theme_color(&"font_color", &"TableHeader")
	return Tokens.GOLD


func _ink(index: int) -> Color:
	return cell_ink(_grid, index)


## The ink of a bar or spark cell: the light (leather-ground) form InkChart uses on a SLOT ground, since the table is dark.
static func cell_ink(ctrl: Control, index: int) -> Color:
	return InkChart.colour_of(ctrl, StringName("ink_%d" % posmod(index, InkMarks.FILLS.size())), InkChart.Ground.SLOT)


## The pale track behind a bar's filled part: the muted text colour, translucent, so it shows on the dark table.
static func track_ink(ctrl: Control) -> Color:
	var c := InkChart.colour_of(ctrl, &"axis", InkChart.Ground.SLOT)
	c.a = TRACK_ALPHA
	return c


func _icon(icon_name: StringName) -> Texture2D:
	if _grid.has_theme_icon(icon_name, &"Kit"):
		return _grid.get_theme_icon(icon_name, &"Kit")
	return null


func _apply_headers() -> void:
	for i: int in _columns.size():
		var col: Dictionary = _columns[i]
		var title := str(col["title"])
		if (col["id"] as StringName) == _sort_id and _sort_id != &"":
			title += " " + (_DOWN_ARROW if _sort_desc else _UP_ARROW)
		_grid.set_column_title(i, title)
		_grid.set_column_title_alignment(i, col["align"] as HorizontalAlignment)
		_grid.set_column_expand(i, bool(col["expand"]))
		_grid.set_column_custom_minimum_width(i, int(col["min_width"]))


func _update_accessibility() -> void:
	var text := summary()
	accessibility_name = section_title
	accessibility_description = text
	_grid.accessibility_name = section_title
	_grid.accessibility_description = text


func _on_column_title_clicked(column: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT or column < 0 or column >= _columns.size():
		return
	var col: Dictionary = _columns[column]
	if not bool(col["sortable"]):
		return
	var id := col["id"] as StringName
	if id == _sort_id:
		sort_by(id, not _sort_desc)
	else:
		sort_by(id, bool(col["descending_first"]))


func _on_item_selected() -> void:
	if _quiet > 0:
		return
	var item := _grid.get_selected()
	if item == null:
		return
	var meta := int(item.get_metadata(0))
	if meta == _MORE:
		_has_selection = false
		return
	_has_selection = true
	_selected_id = _row_id(meta)
	row_selected.emit(_rows[meta].duplicate())


func _on_item_activated() -> void:
	var item := _grid.get_selected()
	if item == null:
		return
	var meta := int(item.get_metadata(0))
	if meta == _MORE:
		var first_new := shown_count()
		show_more()
		_select_position(first_new)
		return
	row_activated.emit(_rows[meta].duplicate())


func _on_button_clicked(item: TreeItem, _column: int, _id: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT or item == null:
		return
	var meta := int(item.get_metadata(0))
	if meta == _MORE:
		return
	row_activated.emit(_rows[meta].duplicate())


## Selects the shown row at display position `k` (the Tree emits item_selected, so row_selected follows).
func _select_position(k: int) -> void:
	var root := _grid.get_root()
	if root == null:
		return
	var count := shown_count()
	if count == 0:
		return
	var at := clampi(k, 0, count - 1)
	var item := root.get_child(at)
	if item != null:
		_grid.set_selected(item, 0)


func _on_grid_key(key: InputEventKey) -> bool:
	var sort_mod := key.ctrl_pressed or key.meta_pressed
	match key.keycode:
		KEY_LEFT:
			if sort_mod:
				_step_sort_column(-1)
				return true
		KEY_RIGHT:
			if sort_mod:
				_step_sort_column(1)
				return true
		KEY_UP:
			if sort_mod:
				_set_direction(true)
				return true
		KEY_DOWN:
			if sort_mod:
				_set_direction(false)
				return true
		KEY_HOME:
			_select_position(0)
			return true
		KEY_END:
			_select_position(shown_count() - 1)
			return true
	return false


## Moves the sort to the next (dir 1) or previous (dir -1) sortable column; the first sort picks the first or last one.
func _step_sort_column(dir: int) -> void:
	var cur := _column_index(_sort_id)
	var i := (cur if cur >= 0 else (-1 if dir > 0 else _columns.size())) + dir
	while i >= 0 and i < _columns.size():
		if bool(_columns[i]["sortable"]):
			sort_by(_columns[i]["id"] as StringName, bool(_columns[i]["descending_first"]))
			return
		i += dir


## Sorts the current column (or the first sortable one) descending (true) or ascending (false).
func _set_direction(descending: bool) -> void:
	if _sort_id != &"":
		sort_by(_sort_id, descending)
		return
	for col: Dictionary in _columns:
		if bool(col["sortable"]):
			sort_by(col["id"] as StringName, descending)
			return

