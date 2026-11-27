## The boxes of the tile window's tabs (the owner's 540 banner design of 2026-11-26) and the window's fit rule. A box is a dark
## inset with a small-caps head and key and value rows; two boxes stand side by side in a pair. A box of a mechanic the game does
## not have yet is a placeholder: its head carries the dashed "soon" tag (SoonTag), its example values are muted, and it and each
## of its rows say "Example only: not in the game yet" on hover; a row whose value the game already knows (a garrison, an army's
## move points) shows that value in the plain value text and its own tooltip. Placeholders show only on your own land
## (`allowed`): never on foreign, unowned or undiscovered land, nor at sea, so no example ever stands where it could be read as
## another country's data.
##
## The fit (no scrollbar, the owner's rule): every box, pair or section a tab may give up when the window is short carries a rank
## (`rank`); `fit` hides the highest ranks first until the tab body fits the room. Placeholders rank highest; the real facts' sections
## rank low (hidden last); the building strips, the siege block and the raise rows carry no rank and never hide.
class_name TileBoxes
extends RefCounted

## The meta key of a node's fit rank: a higher rank hides first.
const RANK := &"fit_rank"
## The ranks the tabs use (higher hides first).
const RANK_FACTS := 10
const RANK_SHIPS := 70
const RANK_FACT_EXAMPLE := 72
const RANK_PAIR_LOW := 80
const RANK_PAIR_MID := 85
const RANK_PAIR_HIGH := 90
const RANK_PAIR_TOP := 95
## The gap between two boxes of a pair and between the rows of a tab, in logical pixels.
const GAP := 6
## A people-class bar's height and the class name's column, in logical pixels.
const BAR_H := 8.0
const CLASS_W := 92.0
const CLASS_VALUE_W := 44.0


## Whether placeholders may show for this TileView: your own land only.
static func allowed(view: Dictionary) -> bool:
	return StringName(str(view.get("case", ""))) == &"own"


## Marks `node` as one the fit may hide, at `value` (higher hides first); returns it.
static func rank(node: Control, value: int) -> Control:
	node.set_meta(RANK, value)
	return node


## Two boxes side by side, each half the width, ranked as one.
static func pair(left: Control, right: Control, rank_value: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = StringName("Pair" + str(left.name).trim_prefix("Box"))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", GAP)
	for side: Control in [left, right]:
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side.size_flags_stretch_ratio = 1.0
		row.add_child(side)
	rank(row, rank_value)
	return row


## A box: its head (the small-caps title, and the "soon" tag when `example`) and its rows. A row is a Control (kv, bar) or a
## [key, value, example] Array.
static func box(title: String, rows: Array, example: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = StringName("Box" + title.replace(" ", ""))
	panel.theme_type_variation = &"PanelTileBox"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.tooltip_text = SoonTag.EXAMPLE_TIP if example else ""
	if example:
		panel.set_meta(&"example", true)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 0)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_label := PanelKit.label(title, &"TileHead")
	title_label.uppercase = true
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title_label)
	if example:
		head.add_child(SoonTag.new())
	column.add_child(head)
	for raw: Variant in rows:
		if raw is Control:
			column.add_child(raw as Control)
		elif raw is Array:
			var cells := raw as Array
			column.add_child(kv(str(cells[0]), str(cells[1]), bool(cells[2]) if cells.size() > 2 else example))
	return panel


## One key and value line: the key at the left, the value at the right (muted and with the placeholder's tooltip when `example`;
## else the plain value, its tooltip "key: value", or `tip` when given), a dotted hairline under it.
static func kv(key: String, value: String, example: bool, tip: String = "") -> PanelContainer:
	var line := PanelContainer.new()
	line.theme_type_variation = &"PanelTileBoxLine"
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	line.tooltip_text = SoonTag.EXAMPLE_TIP if example else (tip if tip != "" else "%s: %s" % [key, value])
	if example:
		line.set_meta(&"example", true)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", Tokens.S2)
	line.add_child(row)
	var key_label := PanelKit.label(key, &"TileKey")
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_label.clip_text = true
	key_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	key_label.custom_minimum_size.x = 24.0
	row.add_child(key_label)
	# The value keeps its whole width; a long key gives way (its ellipsis, the row's tooltip).
	var value_label := PanelKit.label(value, &"TileValueMuted" if example else &"TileValue")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	return line


## One people-class line of a placeholder: the class, a muted bar of its share, the share in words.
static func bar(name: String, share: float) -> PanelContainer:
	var line := PanelContainer.new()
	line.theme_type_variation = &"PanelTileBoxLine"
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	line.tooltip_text = SoonTag.EXAMPLE_TIP
	line.set_meta(&"example", true)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", Tokens.S2)
	line.add_child(row)
	var key_label := PanelKit.label(name, &"TileKey")
	key_label.custom_minimum_size.x = CLASS_W
	key_label.clip_text = true
	row.add_child(key_label)
	var meter := Control.new()
	meter.name = &"Bar"
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.custom_minimum_size = Vector2(16.0, BAR_H)
	var fill := clampf(share, 0.0, 1.0)
	meter.draw.connect(func() -> void:
		meter.draw_rect(Rect2(Vector2.ZERO, meter.size), Tokens.TILE_LINE)
		meter.draw_rect(Rect2(Vector2.ZERO, Vector2(meter.size.x * fill, meter.size.y)), Tokens.TILE_DIM))
	row.add_child(meter)
	var value_label := PanelKit.label("%d%%" % roundi(fill * 100.0), &"TileValueMuted")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = CLASS_VALUE_W
	row.add_child(value_label)
	return line


## A small-caps head line of a tab's group ("Build a ship"), with the "soon" tag when `example`.
static func head(text: String, example: bool) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	line.tooltip_text = SoonTag.EXAMPLE_TIP if example else ""
	var label := PanelKit.label(text, &"TileHead")
	label.uppercase = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	if example:
		line.add_child(SoonTag.new())
	return line


# --- the fit ------------------------------------------------------------------------------------------------------------


## The ranked nodes under `root`, highest rank first; of equal ranks the later one in the tree first.
static func ranked(root: Node) -> Array[Control]:
	var found: Array[Array] = []
	_collect(root, found)
	found.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) != int(b[0]):
			return int(a[0]) > int(b[0])
		return int(a[1]) > int(b[1]))
	var out: Array[Control] = []
	for item: Array in found:
		out.append(item[2] as Control)
	return out


static func _collect(node: Node, found: Array[Array]) -> void:
	for child: Node in node.get_children():
		if child is Control and child.has_meta(RANK):
			found.append([int(child.get_meta(RANK)), found.size(), child])
		_collect(child, found)


## Shows every ranked node under `root`, then hides them highest rank first while `content`'s minimum height is over `room`.
## Returns the number hidden; `content` may still be over `room` when nothing ranked is left (the caller scrolls then).
static func fit(root: Node, content: Control, room: float) -> int:
	var nodes := ranked(root)
	for node: Control in nodes:
		node.visible = true
	var hidden := 0
	for node: Control in nodes:
		if content.get_combined_minimum_size().y <= room + 0.5:
			break
		node.visible = false
		hidden += 1
	return hidden
