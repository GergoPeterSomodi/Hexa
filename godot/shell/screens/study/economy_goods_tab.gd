## The Economy page's Goods tab (docs/architecture/m4-5-build-spec.md 4.4 and 6.4): a StudyTable of every good in store,
## made or used (sorted by Lasts, soonest first), and for the selected good a LINE_BARS chart (made a season as bars, in
## store as a line) with its note. Your land only: StudyEconomy.goods for the tag it is given; "No data yet." for none.
## It sends nothing (a good has no place). The span Segmented (12 or 40 seasons) asks span_changed; the page writes the
## setting and refreshes.
class_name EconomyGoodsTab
extends VBoxContainer

signal action_requested(action: Array)
signal span_changed(span: int)

const NO_DATA := "No data yet."
const HINT := "Which good runs short. Click a heading to sort."
const TITLE := "Goods"
const NO_GOODS := "No goods yet."
## The table keeps room for 7 whole rows (a 46 px header and 7 rows of 28 px); the chart below gives way first.
const TABLE_ROWS := 7
const TABLE_MIN_H := 46.0 + 28.0 * TABLE_ROWS + 4.0
const CHART_MIN := Vector2(360.0, 120.0)
const INK_STOCK := 0
const INK_MADE := 3
const SPARK_INK := 0

var span: int = 12

var _built: bool = false
var _message: Label = null
var _content: VBoxContainer = null
var _hint: Label = null
var _seg: Segmented = null
var _table: StudyTable = null
var _chart_title: Label = null
var _chart: InkChart = null
var _note: Label = null
var _data: Dictionary = {}
var _selected_id: int = -1


func _ready() -> void:
	_ensure_built()


## Sets the span shown (12 or 40) without asking for a refresh; the page calls it before refresh.
func set_span(value: int) -> void:
	_ensure_built()
	span = value
	if _seg.selected_id() != value:
		_seg.select(value)


## Fills the tab from `game` for `tag` (the player's country; &"" shows "No data yet.").
func refresh(game: Game, tag: StringName) -> void:
	_ensure_built()
	if game == null or tag == &"" or not game.has_countries():
		_show_message(NO_DATA)
		return
	var country := Countries.by_tag(game, tag)
	if country == null or not country.alive:
		_show_message(NO_DATA)
		return
	_show_message("")
	_data = StudyEconomy.goods(game, tag, span)
	var rows: Array = []
	for r: Dictionary in (_data["rows"] as Array):
		rows.append({
			"id": int(r["id"]), "data": r,
			"cells": {
				&"good": str(r["name"]), &"stock": int(r["stock"]), &"change": int(r["change"]),
				&"made": int(r["made_year"]), &"used": int(r["used_year"]),
				&"lasts": {"value": int(r["lasts"]), "text": str(r["lasts_text"])},
				&"trend": r["stock_series"],
			},
		})
	_table.set_rows(rows)
	var sel := _table.selected_row()
	if sel.is_empty() and not _table.sorted_ids().is_empty():
		_table.select_id(int(_table.sorted_ids()[0]))
		sel = _table.selected_row()
	_selected_id = int(sel["id"]) if not sel.is_empty() else -1
	_update_detail()


## {good}: selects that good (its id, or its key or name).
func focus(args: Dictionary) -> void:
	_ensure_built()
	if not args.has("good"):
		return
	var want: Variant = args["good"]
	for r: Dictionary in (_data.get("rows", []) as Array):
		var hit := false
		if typeof(want) == TYPE_INT:
			hit = int(r["id"]) == int(want)
		else:
			var text := str(want).to_lower()
			hit = str(r["key"]).to_lower() == text or str(r["name"]).to_lower() == text
		if hit:
			_table.select_id(int(r["id"]))
			_selected_id = int(r["id"])
			_update_detail()
			return


func table() -> StudyTable:
	_ensure_built()
	return _table


func chart() -> InkChart:
	_ensure_built()
	return _chart


func note_label() -> Label:
	_ensure_built()
	return _note


func span_control() -> Segmented:
	_ensure_built()
	return _seg


# ----- building ------------------------------------------------------------------------------------------------------


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message = PanelKit.label("", &"Hint")
	_message.name = &"Message"
	_message.visible = false
	add_child(_message)
	_content = VBoxContainer.new()
	_content.name = &"Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_content)
	var top := HBoxContainer.new()
	top.name = &"Top"
	_content.add_child(top)
	_hint = PanelKit.label(HINT, &"Hint")
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_hint)
	_seg = Segmented.new()
	_seg.name = &"Span"
	_seg.accessibility_name = "Span in seasons"
	_seg.set_options(_span_items())
	_seg.select(span)
	_seg.changed.connect(_on_span_pressed)
	top.add_child(_seg)
	_table = StudyTable.new()
	_table.name = &"Table"
	_table.section_title = TITLE
	_table.custom_minimum_size.y = TABLE_MIN_H
	_table.set_columns([
		{"id": "good", "title": "Good", "kind": "text", "expand": true},
		{"id": "stock", "title": "In store", "kind": "number"},
		{"id": "change", "title": "Change", "kind": "delta"},
		{"id": "made", "title": "Made a year", "kind": "number"},
		{"id": "used", "title": "Used a year", "kind": "number"},
		{"id": "lasts", "title": "Lasts", "kind": "number", "descending_first": false},
		{"id": "trend", "title": "Store", "kind": "spark", "ink": SPARK_INK, "min_width": 90},
	])
	_table.sort_by(&"lasts", false)
	_table.row_selected.connect(_on_row_selected)
	_content.add_child(_table)
	_build_chart_inset()
	_note = PanelKit.label("", &"Body")
	_note.name = &"Note"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_note)


static func _span_items() -> Array:
	var items: Array = []
	for n: int in StudyEconomy.SPANS:
		items.append({"id": n, "label": "%d seasons" % n})
	return items


func _build_chart_inset() -> void:
	var inset := PanelContainer.new()
	inset.name = &"ChartInset"
	inset.theme_type_variation = &"PanelVellumInset"
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(inset)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(box)
	_chart_title = PanelKit.label("", &"LabelInkHead")
	box.add_child(_chart_title)
	_chart = InkChart.new()
	_chart.name = &"Chart"
	_chart.kind = InkChart.Kind.LINE_BARS
	_chart.ground = InkChart.Ground.VELLUM
	_chart.legend = true
	_chart.custom_minimum_size = CHART_MIN
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_chart)


func _show_message(text: String) -> void:
	_message.text = text
	_message.accessibility_name = text
	_message.visible = text != ""
	_content.visible = text == ""


# ----- the selected good's chart and note ------------------------------------------------------------------------------


func _row_of(id: int) -> Dictionary:
	for r: Dictionary in (_data.get("rows", []) as Array):
		if int(r["id"]) == id:
			return r
	return {}


func _update_detail() -> void:
	var row := _row_of(_selected_id)
	var has := bool(_data.get("has_data", false))
	if row.is_empty():
		_chart_title.text = ""
		_chart.caption = ""
		_chart.set_series([])
		_note.text = NO_GOODS
	else:
		var seasons := mini(span, (_data["labels"] as Array).size()) if has else span
		var count := "season" if seasons == 1 else "%d seasons" % seasons
		var caption := "%s: made and in store, the last %s" % [str(row["name"]), count]
		_chart_title.text = caption
		_chart.caption = caption
		_chart.x_labels = PackedStringArray(_data["labels"] as Array)
		_chart.set_series([
			{"name": "In store", "values": row["stock_series"], "ink": INK_STOCK},
			{"name": "Made a season", "values": row["made_series"], "ink": INK_MADE, "role": "bar"},
		])
		_note.text = str(row["note"])
	_note.accessibility_name = _note.text


# ----- signals -------------------------------------------------------------------------------------------------------


func _on_row_selected(row: Dictionary) -> void:
	_selected_id = int(row["id"])
	_update_detail()


func _on_span_pressed(id: Variant) -> void:
	var value := int(id)
	if value == span:
		return
	span = value
	span_changed.emit(value)
