## The People page of the Statesman's Study (docs/architecture/m5-build-spec.md 6.6; StudyPeople is its read model). The head
## says how many people live in the towns and in the countryside and how many more the land holds, with the season's
## expected change and the span (12 or 40 seasons, state/study_span, shared with Rankings and Economy). Below: Towns (a
## StudyTable of your settlements, highest first, the countryside's line, Look there and Show on the map) at the page's full
## width (so the Outlook column has the room it needs), then Food (the report's food line) with two compact charts side by
## side (stacked below CHARTS_MIN_W of page width): Food (made, eaten and the towns' need) and Growth (a stacked chart of
## who came, who starved and who left). It changes nothing: Look there (or
## Enter, or a double click on a row) asks [&"look_at", hex] and Show on the map [&"map_mode", &"food", hex]; the Study turns
## them into ctx.request calls. Before a season has ended the table shows its rows without a change, the food line says
## "No season has ended yet." and the charts "No data yet.". Built on the first refresh; the Study refreshes it on
## season_ended and on every open (the view is cached by game.version).
class_name PagePeople
extends StudyPage

const NO_DATA := "No data yet."
const SPAN_KEY := "state/study_span"
const SPAN_CHOICES: Array[int] = [12, 40]
const SPAN_LABEL := "Seasons the charts look back over"
const ACTION_LOOK := &"look_at"
const ACTION_MAP_MODE := &"map_mode"
const MODE_FOOD := &"food"
const EXPECTED_LABEL := "Expected this season"
const TOWNS_TITLE := "Towns"
const FOOD_TITLE := "Food"
const FOOD_CAPTION := "Food, a season"
const GROWTH_CAPTION := "Growth and losses, a season"
const LOOK_TEXT := "Look there"
const MAP_TEXT := "Show on the map"
const TOWNS_MIN_W := 560.0
const CHARTS_MIN_W := 400.0
const TABLE_MIN_H := 120.0
const CHART_MIN := Vector2(300.0, 130.0)

## The seasons the charts look back over: 12 or 40. The Study may pass the shell's settings, and then the span is read from
## and written to state/study_span.
var span: int = 12
var settings: Settings = null

var _built: bool = false
var _head: Label = null
var _expected: DeltaChip = null
var _span_seg: Segmented = null
var _table: StudyTable = null
var _countryside: Label = null
var _look: KitButton = null
var _map: KitButton = null
var _food_line: Label = null
var _food_chart: InkChart = null
var _food_none: Label = null
var _growth_chart: InkChart = null
var _growth_none: Label = null
var _last_game: Game = null
var _selected: Dictionary = {}


func _ready() -> void:
	_ensure_built()


## Fills the page from `game` for the player's country; `tag` says why and is not used. With no game or no player the page
## is the empty one (no rows, "No data yet.").
func refresh(game: Game, _tag: StringName) -> void:
	_ensure_built()
	_last_game = game
	_read_span()
	var data: Dictionary = {}
	if game != null and game.player != &"":
		data = StudyPeople.of(game, game.player, span)
	if data.is_empty():
		data = StudyPeople.of(null, &"", span)
	_fill(data)


## The row the actions use now: {id, hex}, or {} with none.
func selected_row() -> Dictionary:
	return _selected.duplicate()


# ----- building ------------------------------------------------------------------------------------------------------


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_head()
	var flow := VBoxContainer.new()
	flow.name = "Flow"
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(flow)
	_build_towns(flow)
	_build_food(flow)


func _build_head() -> void:
	var top := HBoxContainer.new()
	top.name = "Top"
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(top)
	_head = PanelKit.label("", &"Hint")
	_head.name = "Head"
	_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_head)
	_expected = DeltaChip.new()
	_expected.name = "Expected"
	_expected.boxed = true
	_expected.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_expected.set_delta(0, "", EXPECTED_LABEL)
	top.add_child(_expected)
	_span_seg = Segmented.new()
	_span_seg.name = "Span"
	_span_seg.accessibility_name = SPAN_LABEL
	var items: Array = []
	for n: int in SPAN_CHOICES:
		items.append({"id": n, "label": "%d seasons" % n, "tooltip": SPAN_LABEL})
	_span_seg.set_options(items)
	_span_seg.select(span)
	_span_seg.changed.connect(_on_span_changed)
	top.add_child(_span_seg)


func _build_towns(flow: Container) -> void:
	var box := VBoxContainer.new()
	box.name = "Towns"
	box.custom_minimum_size = Vector2(TOWNS_MIN_W, 0.0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_child(box)
	var title := PanelKit.label(TOWNS_TITLE, &"SectionHead")
	title.name = "Title"
	box.add_child(title)
	_table = StudyTable.new()
	_table.name = "Table"
	_table.section_title = TOWNS_TITLE
	_table.custom_minimum_size = Vector2(0.0, TABLE_MIN_H)
	_table.set_columns(_columns_def())
	_table.sort_by(&"people", true)
	_table.row_selected.connect(_on_row_selected)
	_table.row_activated.connect(_on_row_activated)
	box.add_child(_table)
	_countryside = PanelKit.label("", &"Body")
	_countryside.name = "Countryside"
	_countryside.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_countryside)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	box.add_child(buttons)
	_look = _button(LOOK_TEXT, "Look", _on_look_pressed)
	buttons.add_child(_look)
	_map = _button(MAP_TEXT, "ShowOnMap", _on_map_pressed)
	buttons.add_child(_map)


func _button(text: String, node_name: String, handler: Callable) -> KitButton:
	var b := KitButton.new()
	b.name = node_name
	b.text = text
	b.accessibility_name = text
	b.pressed.connect(handler)
	return b


func _build_food(flow: Container) -> void:
	var box := VBoxContainer.new()
	box.name = "Food"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_child(box)
	var title := PanelKit.label(FOOD_TITLE, &"SectionHead")
	title.name = "Title"
	box.add_child(title)
	_food_line = PanelKit.label("", &"Body")
	_food_line.name = "FoodLine"
	_food_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_food_line)
	var charts := HFlowContainer.new()
	charts.name = "Charts"
	charts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(charts)
	var food := _inset(charts, "FoodInset", "FoodChart", InkChart.Kind.LINE)
	_food_chart = food[0] as InkChart
	_food_none = food[1] as Label
	var growth := _inset(charts, "GrowthInset", "GrowthChart", InkChart.Kind.STACKED_BAR)
	_growth_chart = growth[0] as InkChart
	_growth_none = growth[1] as Label


## A vellum inset with its caption, a chart and the "No data yet." line shown instead of the chart before a season.
func _inset(box: Container, inset_name: String, chart_name: String, chart_kind: InkChart.Kind) -> Array:
	var inset := PanelContainer.new()
	inset.name = inset_name
	inset.theme_type_variation = &"PanelVellumInset"
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.custom_minimum_size = Vector2(CHARTS_MIN_W, 0.0)
	box.add_child(inset)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(inner)
	var caption := PanelKit.label(FOOD_CAPTION if chart_kind == InkChart.Kind.LINE else GROWTH_CAPTION, &"LabelInkHead")
	caption.name = "Caption"
	inner.add_child(caption)
	var chart := InkChart.new()
	chart.name = chart_name
	chart.kind = chart_kind
	chart.ground = InkChart.Ground.VELLUM
	chart.legend = true
	chart.caption = caption.text
	chart.custom_minimum_size = CHART_MIN
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(chart)
	var none := PanelKit.label(NO_DATA, &"LabelInkHead")
	none.name = "NoData"
	none.visible = false
	inner.add_child(none)
	return [chart, none]


func _columns_def() -> Array:
	return [
		{"id": &"place", "title": "Place", "kind": &"text", "min_width": 110},
		{"id": &"what", "title": "What", "kind": &"text", "min_width": 100},
		{"id": &"people", "title": "People", "kind": &"number", "expand": false, "min_width": 70},
		{"id": &"room", "title": "Room", "kind": &"number", "expand": false, "min_width": 70},
		{"id": &"change", "title": "Last season", "kind": &"delta", "expand": false, "min_width": 90},
		{"id": &"outlook", "title": "Outlook", "kind": &"text", "min_width": 120},
	]


# ----- filling -------------------------------------------------------------------------------------------------------


func _fill(data: Dictionary) -> void:
	var head: Dictionary = data["head"]
	_head.text = _head_text(head)
	_head.accessibility_name = _head.text
	_expected.set_delta(int(head["expected"]), "", EXPECTED_LABEL)
	_table.set_rows(_rows_of(data["rows"]))
	_keep_selection(data["rows"])
	_countryside.text = _countryside_text(data["countryside"], bool(data["has_data"]))
	var food: Dictionary = data["food"]
	var lasts := str(food["lasts_text"])
	_food_line.text = str(food["text"]) + ((" Lasts %s." % lasts) if lasts != "" and bool(data["has_data"]) else "")
	var has := bool(data["has_data"])
	var series: Dictionary = data["series"]
	var labels := PackedStringArray(data["labels"])
	_food_chart.visible = has
	_food_none.visible = not has
	_food_chart.x_labels = labels
	_food_chart.set_series([
		{"name": "Made", "values": series["food_made"], "ink": 0},
		{"name": "Eaten", "values": series["food_eaten"], "ink": 1},
		{"name": "The towns' need", "values": series["food_need"], "ink": 2},
	])
	_growth_chart.visible = has
	_growth_none.visible = not has
	_growth_chart.x_labels = labels
	_growth_chart.set_series([
		{"name": "Grew", "values": series["grew"], "ink": 3, "role": "in"},
		{"name": "Starved", "values": series["starved"], "ink": 2, "role": "out"},
		{"name": "Left", "values": series["left"], "ink": 4, "role": "out"},
	])


func _head_text(head: Dictionary) -> String:
	return "%s people: %s in towns, %s in the countryside; room for %s more." % [InkMarks.grouped(int(head["people"])),
		InkMarks.grouped(int(head["towns"])), InkMarks.grouped(int(head["countryside"])),
		InkMarks.grouped(int(head["room_left"]))]


func _countryside_text(c: Dictionary, has_data: bool) -> String:
	var text := "The countryside: %d places, %s people of %s room" % [int(c["count"]), InkMarks.grouped(int(c["people"])),
		InkMarks.grouped(int(c["room"]))]
	if not has_data:
		return text + "."
	var change := int(c["change"])
	var sign_text := "no change"
	if change > 0:
		sign_text = "▲ +%s" % InkMarks.grouped(change)
	elif change < 0:
		sign_text = "▼ −%s" % InkMarks.grouped(-change)
	return "%s, %s last season." % [text, sign_text]


## The table's rows: the cells keyed by the column ids; a row keeps its hex for the two actions. Before a season has ended
## `change` is 0 for every row, and the delta cell shows "0".
func _rows_of(rows: Array) -> Array:
	var out: Array = []
	for r: Dictionary in rows:
		out.append({"id": int(r["id"]), "hex": r["hex"], "cells": {
			&"place": str(r["place"]),
			&"what": str(r["what"]),
			&"people": int(r["people"]),
			&"room": int(r["room"]),
			&"change": int(r["change"]),
			&"outlook": {"value": str(r["outlook"]), "text": str(r["outlook"]), "tone": StringName(str(r["tone"]))},
		}})
	return out


## The selection stays on its row when the row is still there, else it is the first row (most people), else none.
func _keep_selection(rows: Array) -> void:
	var keep := -1
	for r: Dictionary in rows:
		if _selected.has("id") and int(r["id"]) == int(_selected["id"]):
			keep = int(r["id"])
	if keep < 0 and not rows.is_empty():
		keep = int((rows[0] as Dictionary)["id"])
	_selected = {}
	if keep >= 0:
		_table.select_id(keep)
		for r: Dictionary in rows:
			if int(r["id"]) == keep:
				_selected = {"id": keep, "hex": r["hex"]}
	_look.disabled = _selected.is_empty()
	_map.disabled = _selected.is_empty()


# ----- actions -------------------------------------------------------------------------------------------------------


func _read_span() -> void:
	if settings == null:
		return
	var v := int(settings.get_value(SPAN_KEY))
	if SPAN_CHOICES.has(v):
		span = v
	_span_seg.select(span)


func _on_span_changed(id: Variant) -> void:
	var v := int(id)
	if not SPAN_CHOICES.has(v):
		return
	span = v
	if settings != null:
		settings.set_value(SPAN_KEY, span)
	refresh(_last_game, &"span")


func _on_row_selected(row: Dictionary) -> void:
	_selected = {"id": int(row.get("id", -1)), "hex": row.get("hex", Vector2i.ZERO)}
	_look.disabled = false
	_map.disabled = false


func _on_row_activated(row: Dictionary) -> void:
	if row.has("hex"):
		request([ACTION_LOOK, row["hex"]])


func _on_look_pressed() -> void:
	if not _selected.is_empty():
		request([ACTION_LOOK, _selected["hex"]])


func _on_map_pressed() -> void:
	if not _selected.is_empty():
		request([ACTION_MAP_MODE, MODE_FOOD, _selected["hex"]])
