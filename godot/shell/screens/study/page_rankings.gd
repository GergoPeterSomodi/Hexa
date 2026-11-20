## The Rankings page of the Statesman's Study (docs/architecture/m4-5-build-spec.md 4.6 and 6.5; the mockup
## study_rankings.png). It shows StudyRankings.of for the player's country: a head line, a span Segmented (12 or 40
## seasons) and one column per measure shown by the milestone: a SectionHead, a StudyTable (Rank, Country, Value, a bar,
## Go), "You are 3rd of 3." and a vellum inset with a LINE chart (you, and the largest you know about, with the rank marks).
## It changes nothing: a row's Enter, double click or Go asks action_requested([&"country", tag]) and the Study opens that
## country's panel. The viewer is the player only: with no player (the pick, the sandbox) it shows "No data yet.", never
## the viewer &"" (which sees every country exact).
class_name PageRankings
extends StudyPage

const NO_DATA := "No data yet."
const NO_SEASON := "No season has ended yet."
const SPAN_KEY := "state/study_span"
const SPAN_CHOICES: Array[int] = [12, 40]
const SPAN_LABEL := "Seasons the lists look back over"
const ACTION_COUNTRY := &"country"
const CHART_YOU := "You"
const CHART_BEST := "The largest you know (about)"
const TABLE_MIN_H := 140.0
const COLUMN_MIN_W := 460.0
const CHART_MIN := Vector2(430.0, 180.0)
const GO_TEXT := "Go"
const RANK_TITLE := "Rank"
const COUNTRY_TITLE := "Country"
const VALUE_TITLE := "Value"

## The seasons the lists and charts look back over: 12 or 40. The Study may pass the shell's settings, and then the span
## is read from and written to state/study_span.
var span: int = 12
var settings: Settings = null

var _built: bool = false
var _head: Label = null
var _span_seg: Segmented = null
var _message: Label = null
var _flow: HBoxContainer = null
var _columns: Dictionary = {}
var _last_game: Game = null


func _ready() -> void:
	_ensure_built()


## Fills the page from `game` for the player's country; `tag` says why and is not used.
func refresh(game: Game, _tag: StringName) -> void:
	_ensure_built()
	_last_game = game
	_read_span()
	if game == null or game.player == &"":
		_show_message(NO_DATA)
		return
	var data := StudyRankings.of(game, game.player, span)
	if not bool(data["has_data"]):
		_show_message(NO_SEASON)
		return
	_head.text = str(data["head"])
	_head.visible = true
	_message.visible = false
	_flow.visible = true
	var shown: Array[StringName] = []
	for m: Dictionary in data["measures"]:
		var id := StringName(str(m["id"]))
		if not _is_shown(id):
			continue
		shown.append(id)
		_fill_column(_column_for(m), m)
	for key: Variant in _columns.keys():
		(_columns[key]["box"] as Control).visible = shown.has(StringName(str(key)))


# ----- building ------------------------------------------------------------------------------------------------------


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.name = "Top"
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(top)
	_head = PanelKit.label("", &"Hint")
	_head.name = "Head"
	_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_head)
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
	_message = PanelKit.label("", &"Hint")
	_message.name = "Message"
	_message.visible = false
	add_child(_message)
	_flow = HBoxContainer.new()
	_flow.name = "Lists"
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_flow)


## The column of one measure, built on its first refresh (a measure is added to the page, not rebuilt; the two
## columns sit side by side in the HBox, a third one would wrap as M5 adds it).
func _column_for(m: Dictionary) -> Dictionary:
	var id := StringName(str(m["id"]))
	if not _columns.has(id):
		_columns[id] = _build_column(id, str(m["title"]))
	return _columns[id] as Dictionary


func _build_column(id: StringName, title: String) -> Dictionary:
	var box := VBoxContainer.new()
	box.name = String(id)
	box.custom_minimum_size = Vector2(COLUMN_MIN_W, 0.0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.add_child(box)
	var head := PanelKit.label(title, &"SectionHead")
	head.name = "Title"
	box.add_child(head)
	var table := StudyTable.new()
	table.name = "Table"
	table.section_title = title
	table.custom_minimum_size = Vector2(0.0, TABLE_MIN_H)
	table.set_columns(_columns_def())
	table.sort_by(&"rank", false)
	table.row_activated.connect(_on_row_activated)
	box.add_child(table)
	var you := PanelKit.label("", &"Body")
	you.name = "You"
	box.add_child(you)
	var inset := PanelContainer.new()
	inset.name = "ChartInset"
	inset.theme_type_variation = &"PanelVellumInset"
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(inset)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(inner)
	var caption := PanelKit.label("", &"LabelInkHead")
	caption.name = "Caption"
	inner.add_child(caption)
	var chart := InkChart.new()
	chart.name = "Chart"
	chart.kind = InkChart.Kind.LINE
	chart.ground = InkChart.Ground.VELLUM
	chart.legend = true
	chart.custom_minimum_size = CHART_MIN
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(chart)
	return {"box": box, "table": table, "you": you, "caption": caption, "chart": chart}


func _columns_def() -> Array:
	return [
		{"id": &"rank", "title": RANK_TITLE, "kind": &"number", "expand": false, "min_width": 56},
		{"id": &"country", "title": COUNTRY_TITLE, "kind": &"text", "min_width": 120},
		{"id": &"value", "title": VALUE_TITLE, "kind": &"number", "expand": false, "min_width": 110},
		{"id": &"bar", "title": "", "kind": &"bar", "ink": 0, "sortable": false, "min_width": 120},
		{"id": &"go", "title": "", "kind": &"button", "expand": false, "min_width": 44},
	]


# ----- filling -------------------------------------------------------------------------------------------------------


func _fill_column(col: Dictionary, m: Dictionary) -> void:
	(col["table"] as StudyTable).set_rows(_rows_of(m))
	(col["you"] as Label).text = str(m["you_text"])
	var line: Dictionary = m["line"]
	(col["caption"] as Label).text = str(line["caption"])
	var chart := col["chart"] as InkChart
	chart.caption = str(line["caption"])
	chart.x_labels = PackedStringArray(line["labels"])
	chart.set_series(_series_of(line))
	chart.set_marks(line["marks"])


## The table rows of a measure: the cells keyed by the column ids; the row keeps its tag for the Go action.
func _rows_of(m: Dictionary) -> Array:
	var rows: Array = []
	for r: Dictionary in m["rows"]:
		var cells := {
			&"rank": int(r["rank"]),
			&"country": str(r["short"]),
			&"value": {"value": int(r["value"]), "text": str(r["text"])},
			&"bar": {"value": int(r["bar"])},
			&"go": {"text": GO_TEXT},
		}
		rows.append({"id": int(r["id"]), "tag": StringName(str(r["tag"])), "mine": bool(r["mine"]), "cells": cells})
	return rows


## Your line, and the largest you know (about) when there is another country to show.
func _series_of(line: Dictionary) -> Array:
	var series: Array = [{"name": CHART_YOU, "values": line["you"], "ink": 0}]
	var best: PackedInt32Array = line["best"]
	if not best.is_empty():
		series.append({"name": CHART_BEST, "values": best, "ink": 1})
	return series


func _is_shown(id: StringName) -> bool:
	if not milestone.is_valid_float():
		return false
	for def: Dictionary in StudyRankings.MEASURES:
		if StringName(str(def["id"])) == id:
			return str(def.get("since", "0")).to_float() <= milestone.to_float()
	return false


func _show_message(text: String) -> void:
	_head.text = ""
	_head.visible = false
	_flow.visible = false
	_message.text = text
	_message.accessibility_name = text
	_message.visible = true


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


## Enter, a double click or Go on a row asks for that country's panel. The table is not refilled here.
func _on_row_activated(row: Dictionary) -> void:
	var tag := StringName(str(row.get("tag", "")))
	if tag == &"":
		return
	request([ACTION_COUNTRY, tag])
