## Four-season strip showing seasonal goods output, notes, and gain DeltaChip per season,
## highlighting `now` with `PanelStripCellNow` and auto-hiding when all four seasons are equal
## (docs/architecture/ui-style-and-feedback-spec.md section 5; game-feedback-screens.md B.4).
class_name SeasonStrip
extends HBoxContainer

const CELL_COUNT: int = 4

var _cells: Array[PanelContainer] = []
var _heads: Array[Label] = []
var _lines: Array[VBoxContainer] = []
var _gains: Array[DeltaChip] = []
var _now_index: int = -1
var _refs_bound: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_refs()


## Populates the 4 seasonal cells from `{season, note, goods: [{name, before, after}], gain}`.
## Highlights `now` (0..3) with `PanelStripCellNow`, and hides the strip when all 4 cells match.
func set_seasons(cells: Array, now: int) -> void:
	_ensure_refs()
	_now_index = now
	if cells.is_empty():
		visible = false
		return

	var signatures: Array[String] = []
	for i: int in CELL_COUNT:
		var cell_panel := _cells[i]
		if i >= cells.size() or typeof(cells[i]) != TYPE_DICTIONARY:
			cell_panel.visible = false
			continue
		cell_panel.visible = true
		cell_panel.theme_type_variation = &"PanelStripCellNow" if i == now else &"PanelStripCell"

		var data := cells[i] as Dictionary
		var season_name := str(data.get("season", ""))
		var note := str(data.get("note", ""))
		var goods_raw: Variant = data.get("goods", [])
		var goods: Array = goods_raw if goods_raw is Array else []
		var gain := int(data.get("gain", 0))

		_heads[i].text = season_name
		_heads[i].theme_type_variation = &"LabelInkHead"
		var lines_box := _lines[i]
		PanelKit.clear_children(lines_box)

		if not note.is_empty():
			var note_lbl := Label.new()
			note_lbl.text = note
			note_lbl.theme_type_variation = &"LabelInkMuted"
			note_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note_lbl.custom_minimum_size.x = 40.0
			note_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lines_box.add_child(note_lbl)

		var goods_sig: PackedStringArray = []
		for g_var: Variant in goods:
			if typeof(g_var) != TYPE_DICTIONARY:
				continue
			var g := g_var as Dictionary
			var g_name := str(g.get("name", ""))
			var before := int(g.get("before", 0))
			var after := int(g.get("after", 0))
			goods_sig.append("%s:%d:%d" % [g_name, before, after])

			var row_lbl := Label.new()
			row_lbl.text = "%s %d > %d" % [g_name, before, after]
			row_lbl.theme_type_variation = &"LabelInkMuted" if (before == 0 and after == 0) else &"LabelInk"
			row_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row_lbl.custom_minimum_size.x = 40.0
			row_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lines_box.add_child(row_lbl)

		_gains[i].set_delta(gain)
		signatures.append("%d|%s|%s" % [gain, note, ";".join(goods_sig)])

	visible = not _all_equal(signatures)


## Returns the PanelContainer for cell `index` (0..3), or `null` if out of range.
func cell(index: int) -> PanelContainer:
	_ensure_refs()
	if index < 0 or index >= _cells.size():
		return null
	return _cells[index]


## Returns the `now` index last passed to `set_seasons()`.
func now_index() -> int:
	return _now_index


func _ensure_refs() -> void:
	if _refs_bound:
		return
	for i: int in CELL_COUNT:
		var cell_node := get_node("Cell%d" % i) as PanelContainer
		_cells.append(cell_node)
		_heads.append(cell_node.get_node("VBox/Head") as Label)
		_lines.append(cell_node.get_node("VBox/Lines") as VBoxContainer)
		_gains.append(cell_node.get_node("VBox/Gain") as DeltaChip)
	_refs_bound = true


func _all_equal(signatures: Array[String]) -> bool:
	if signatures.size() < CELL_COUNT:
		return false
	var first := signatures[0]
	for i: int in range(1, signatures.size()):
		if signatures[i] != first:
			return false
	return true
