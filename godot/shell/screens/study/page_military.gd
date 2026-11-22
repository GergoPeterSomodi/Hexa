## The Military page of the Statesman's Study (docs/architecture/m6-build-spec.md 6.9; L21). It shows StudyMilitary.of for the
## player's country: a head line (men under arms, armies, companies, the upkeep a season and its share of the income) and the
## span (12 or 40 seasons, state/study_span, shared with Rankings, Economy and People). Below: Your armies (a StudyTable of the
## armies, men highest first, with Look there and Show on the map for the selected one), the upkeep and the losses as two
## vellum charts side by side (stacked below CHARTS_MIN_W of page width), and Foreign armies in sight (the armies the player
## sees: banded men, no ids). It changes nothing: Look there (or Enter, a double click or Go on a row) asks [&"look_at", hex]
## and Show on the map [&"map_mode", &"supply", hex]; the Study turns them into ctx.request calls. Before any army the head
## says where to raise one. Built on the first refresh; the Study refreshes it on season_ended and on every open.
## M7 (spec 6.9, B27): between the charts and the foreign armies, the Wars table (enemy, since, score, battles, losses, held,
## state; Go asks [&"country", tag]) and the Battles table (battle, result, losses; Open asks [&"battle", record], which the
## Study passes on to the App's battle request). The war rows come from StudyMilitary's `wars` and `battles`.
class_name PageMilitary
extends StudyPage

const NO_DATA := "No data yet."
const NO_ARMY := "You have no army. Raise companies in your towns and villages (the hex panel's Raise tab)."
const NO_SEEN := "No foreign army in sight."
const SPAN_KEY := "state/study_span"
const SPAN_CHOICES: Array[int] = [12, 40]
const SPAN_LABEL := "Seasons the charts look back over"
const ACTION_LOOK := &"look_at"
const ACTION_MAP_MODE := &"map_mode"
const MODE_SUPPLY := &"supply"
const OWN_TITLE := "Your armies"
const SEEN_TITLE := "Foreign armies in sight"
const UPKEEP_CAPTION := "Upkeep and income, a season"
const LOSSES_CAPTION := "Men lost, a season"
const UPKEEP_NAME := "Army upkeep"
const INCOME_NAME := "Left-over income"
const HUNGER_NAME := "Hunger"
const LOOK_TEXT := "Look there"
const MAP_TEXT := "Show on the map"
const GO_TEXT := "Go"
const TABLE_MIN_H := 120.0
const SEEN_MIN_H := 90.0
const CHARTS_MIN_W := 400.0
const CHART_MIN := Vector2(300.0, 130.0)
const TOWNS_MIN_W := 560.0
const WAR_TITLE := "Wars"
const BATTLE_TITLE := "Battles"
const NO_WAR := "No war yet."
const NO_BATTLE := "No battle yet."
const OPEN_TEXT := "Open"
const BATTLE_ACTION := &"battle"
const COUNTRY_ACTION := &"country"
const BATTLE_LOSSES_NAME := "Battle"
const WARS_MIN_H := 100.0
const BATTLES_MIN_H := 100.0

## The seasons the charts look back over: 12 or 40. The Study may pass the shell's settings, and then the span is read from
## and written to state/study_span.
var span: int = 12
var settings: Settings = null

var _built: bool = false
var _head: Label = null
var _span_seg: Segmented = null
var _table: StudyTable = null
var _no_army: Label = null
var _look: KitButton = null
var _map: KitButton = null
var _upkeep_chart: InkChart = null
var _upkeep_none: Label = null
var _losses_chart: InkChart = null
var _losses_none: Label = null
var _seen: StudyTable = null
var _no_seen: Label = null
var _wars: StudyTable = null
var _no_war: Label = null
var _battles: StudyTable = null
var _no_battle: Label = null
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
	var data := StudyMilitary.of(null, &"", span)
	if game != null and game.player != &"":
		data = StudyMilitary.of(game, game.player, span)
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
	_build_own(flow)
	_build_charts(flow)
	_build_wars(flow)
	_build_battles(flow)
	_build_seen(flow)


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


func _build_own(flow: Container) -> void:
	var box := VBoxContainer.new()
	box.name = "Own"
	box.custom_minimum_size = Vector2(TOWNS_MIN_W, 0.0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_child(box)
	var title := PanelKit.label(OWN_TITLE, &"SectionHead")
	title.name = "Title"
	box.add_child(title)
	_table = StudyTable.new()
	_table.name = "Table"
	_table.section_title = OWN_TITLE
	_table.custom_minimum_size = Vector2(0.0, TABLE_MIN_H)
	_table.set_columns(_own_columns())
	_table.sort_by(&"men", true)
	_table.row_selected.connect(_on_row_selected)
	_table.row_activated.connect(_on_row_activated)
	box.add_child(_table)
	_no_army = PanelKit.label(NO_ARMY, &"Body")
	_no_army.name = "NoArmy"
	_no_army.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_no_army.visible = false
	box.add_child(_no_army)
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


func _build_charts(flow: Container) -> void:
	var charts := HFlowContainer.new()
	charts.name = "Charts"
	charts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_child(charts)
	var upkeep := _inset(charts, "UpkeepInset", "UpkeepChart", UPKEEP_CAPTION, InkChart.Kind.LINE_BARS)
	_upkeep_chart = upkeep[0] as InkChart
	_upkeep_none = upkeep[1] as Label
	var losses := _inset(charts, "LossesInset", "LossesChart", LOSSES_CAPTION, InkChart.Kind.STACKED_BAR)
	_losses_chart = losses[0] as InkChart
	_losses_none = losses[1] as Label


## A vellum inset with its caption, a chart and the "No data yet." line shown instead of the chart before a season.
func _inset(box: Container, inset_name: String, chart_name: String, caption_text: String, chart_kind: InkChart.Kind) -> Array:
	var inset := PanelContainer.new()
	inset.name = inset_name
	inset.theme_type_variation = &"PanelVellumInset"
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.custom_minimum_size = Vector2(CHARTS_MIN_W, 0.0)
	box.add_child(inset)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(inner)
	var caption := PanelKit.label(caption_text, &"LabelInkHead")
	caption.name = "Caption"
	inner.add_child(caption)
	var chart := InkChart.new()
	chart.name = chart_name
	chart.kind = chart_kind
	chart.ground = InkChart.Ground.VELLUM
	chart.legend = true
	chart.caption = caption_text
	chart.custom_minimum_size = CHART_MIN
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(chart)
	var none := PanelKit.label(NO_DATA, &"LabelInkHead")
	none.name = "NoData"
	none.visible = false
	inner.add_child(none)
	return [chart, none]


func _build_seen(flow: Container) -> void:
	var box := VBoxContainer.new()
	box.name = "Seen"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_child(box)
	var title := PanelKit.label(SEEN_TITLE, &"SectionHead")
	title.name = "Title"
	box.add_child(title)
	_seen = StudyTable.new()
	_seen.name = "Table"
	_seen.section_title = SEEN_TITLE
	_seen.custom_minimum_size = Vector2(0.0, SEEN_MIN_H)
	_seen.set_columns(_seen_columns())
	_seen.sort_by(&"country", false)
	_seen.row_activated.connect(_on_row_activated)
	box.add_child(_seen)
	_no_seen = PanelKit.label(NO_SEEN, &"Body")
	_no_seen.name = "NoSeen"
	_no_seen.visible = false
	box.add_child(_no_seen)


func _build_wars(flow: Container) -> void:
	var box := VBoxContainer.new()
	box.name = "Wars"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_child(box)
	var title := PanelKit.label(WAR_TITLE, &"SectionHead")
	title.name = "Title"
	box.add_child(title)
	_wars = StudyTable.new()
	_wars.name = "WarTable"
	_wars.section_title = WAR_TITLE
	_wars.custom_minimum_size = Vector2(0.0, WARS_MIN_H)
	_wars.set_columns(_war_columns())
	_wars.row_activated.connect(_on_request_row)
	box.add_child(_wars)
	_no_war = PanelKit.label(NO_WAR, &"Body")
	_no_war.name = "NoWar"
	_no_war.visible = false
	box.add_child(_no_war)


func _build_battles(flow: Container) -> void:
	var box := VBoxContainer.new()
	box.name = "Battles"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_child(box)
	var title := PanelKit.label(BATTLE_TITLE, &"SectionHead")
	title.name = "Title"
	box.add_child(title)
	_battles = StudyTable.new()
	_battles.name = "BattleTable"
	_battles.section_title = BATTLE_TITLE
	_battles.custom_minimum_size = Vector2(0.0, BATTLES_MIN_H)
	_battles.set_columns(_battle_columns())
	_battles.row_activated.connect(_on_request_row)
	box.add_child(_battles)
	_no_battle = PanelKit.label(NO_BATTLE, &"Body")
	_no_battle.name = "NoBattle"
	_no_battle.visible = false
	box.add_child(_no_battle)


func _own_columns() -> Array:
	return [
		{"id": &"army", "title": "Army", "kind": &"text", "min_width": 110},
		{"id": &"place", "title": "Place", "kind": &"text", "min_width": 110},
		{"id": &"men", "title": "Men", "kind": &"number", "expand": false, "min_width": 70},
		{"id": &"companies", "title": "Companies", "kind": &"number", "expand": false, "min_width": 90},
		{"id": &"upkeep", "title": "Upkeep", "kind": &"delta", "expand": false, "min_width": 90},
		{"id": &"supply", "title": "Supply", "kind": &"text", "min_width": 110},
		{"id": &"order", "title": "Order", "kind": &"text", "min_width": 130},
		{"id": &"go", "title": "", "kind": &"button", "expand": false, "min_width": 44},
	]


func _war_columns() -> Array:
	return [
		{"id": &"enemy", "title": "Enemy", "kind": &"text", "min_width": 120},
		{"id": &"since", "title": "Since", "kind": &"text", "expand": false, "min_width": 110},
		{"id": &"score", "title": "Score", "kind": &"delta", "expand": false, "min_width": 80},
		{"id": &"battles", "title": "Battles", "kind": &"text", "expand": false, "min_width": 110},
		{"id": &"yours", "title": "Your losses", "kind": &"number", "expand": false, "min_width": 100},
		{"id": &"theirs", "title": "Theirs", "kind": &"number", "expand": false, "min_width": 80},
		{"id": &"held", "title": "Held", "kind": &"text", "min_width": 150},
		{"id": &"state", "title": "State", "kind": &"text", "min_width": 150},
		{"id": &"go", "title": "", "kind": &"button", "expand": false, "min_width": 44},
	]


func _battle_columns() -> Array:
	return [
		{"id": &"battle", "title": "Battle", "kind": &"text", "min_width": 180},
		{"id": &"result", "title": "Result", "kind": &"text", "min_width": 160},
		{"id": &"yours", "title": "Your losses", "kind": &"number", "expand": false, "min_width": 100},
		{"id": &"theirs", "title": "Theirs", "kind": &"number", "expand": false, "min_width": 80},
		{"id": &"open", "title": "", "kind": &"button", "expand": false, "min_width": 44},
	]


func _seen_columns() -> Array:
	return [
		{"id": &"country", "title": "Country", "kind": &"text", "min_width": 120},
		{"id": &"place", "title": "Place", "kind": &"text", "min_width": 120},
		{"id": &"men", "title": "Men", "kind": &"text", "expand": false, "min_width": 110},
		{"id": &"go", "title": "", "kind": &"button", "expand": false, "min_width": 44},
	]


# ----- filling -------------------------------------------------------------------------------------------------------


func _fill(data: Dictionary) -> void:
	var has := bool(data["has_data"])
	var head: Dictionary = data["head"]
	_head.text = _head_text(head)
	_head.accessibility_name = _head.text
	_table.set_rows(_rows_of(data["rows"]))
	_keep_selection(data["rows"])
	_no_army.visible = (data["rows"] as Array).is_empty()
	_wars.set_rows(_war_rows_of(data["wars"]))
	_no_war.visible = (data["wars"] as Array).is_empty()
	_battles.set_rows(_battle_rows_of(data["battles"]))
	_no_battle.visible = (data["battles"] as Array).is_empty()
	_seen.set_rows(_seen_rows_of(data["seen"]))
	_no_seen.visible = (data["seen"] as Array).is_empty()
	var labels := PackedStringArray(data["labels"])
	var series: Dictionary = data["series"]
	_upkeep_chart.visible = has
	_upkeep_none.visible = not has
	_upkeep_chart.x_labels = labels
	_upkeep_chart.set_series([
		{"name": INCOME_NAME, "values": series["income"], "ink": 0, "role": "line"},
		{"name": UPKEEP_NAME, "values": series["upkeep_army"], "ink": 2, "role": "bar"},
	])
	_losses_chart.visible = has
	_losses_none.visible = not has
	_losses_chart.x_labels = labels
	_losses_chart.set_series([
		{"name": BATTLE_LOSSES_NAME, "values": series["battle_losses"], "ink": 1, "role": "out"},
		{"name": HUNGER_NAME, "values": series["army_starved"], "ink": 2, "role": "out"},
	])


## "1,000 men in 1 army, 2 companies; upkeep 12 ducats a season, 5 % of your income." Before any army: where to raise one.
func _head_text(head: Dictionary) -> String:
	if int(head["armies"]) == 0:
		return NO_ARMY
	return "%s in %s, %s; upkeep %s a season, %s of your income." % [Words.men(int(head["men"])),
		Words.plural(int(head["armies"]), "army", "armies"), Words.plural(int(head["units"]), "company", "companies"),
		Words.ducats(int(head["upkeep"])), _percent(int(head["share"]))]


## A permille share as a percentage: "5 %", or "5.5 %" when it is not a whole percent.
static func _percent(permille: int) -> String:
	if permille % 10 == 0:
		return "%d %%" % int(permille / 10.0)
	return "%.1f %%" % (permille / 10.0)


## The own table's rows: the cells keyed by the column ids; a row keeps its hex for the two actions. The upkeep is shown
## negative (a cost), as the Economy page shows its lines.
func _rows_of(rows: Array) -> Array:
	var out: Array = []
	for r: Dictionary in rows:
		out.append({"id": int(r["id"]), "hex": r["hex"], "cells": {
			&"army": str(r["name"]),
			&"place": str(r["place"]),
			&"men": int(r["men"]),
			&"companies": int(r["units"]),
			&"upkeep": -int(r["upkeep"]),
			&"supply": {"value": str(r["supply_text"]), "text": str(r["supply_text"]), "tone": StringName(str(r["tone"]))},
			&"order": str(r["order_text"]),
			&"go": {"text": GO_TEXT},
		}})
	return out


## The foreign armies: the row's id is its place in the list (an army has no id to the viewer), its hex for the actions.
func _seen_rows_of(seen: Array) -> Array:
	var out: Array = []
	for i: int in seen.size():
		var r := seen[i] as Dictionary
		out.append({"id": i, "hex": r["hex"], "cells": {
			&"country": str(r["country"]),
			&"place": str(r["place"]),
			&"men": str(r["men_text"]),
			&"go": {"text": GO_TEXT},
		}})
	return out


## The wars table's rows: the war's id; Go asks [&"country", enemy] (the country panel, where the war section is).
func _war_rows_of(wars: Array) -> Array:
	var out: Array = []
	for w: Dictionary in wars:
		out.append({"id": int(w["war"]), "request": [COUNTRY_ACTION, StringName(str(w["tag"]))], "cells": {
			&"enemy": str(w["country"]),
			&"since": str(w["since_text"]),
			&"score": {"value": int(w["score"])},
			&"battles": "%s won, %s lost" % [Words.number(int(w["won"])), Words.number(int(w["lost"]))],
			&"yours": int(w["yours_lost"]),
			&"theirs": int(w["theirs_lost"]),
			&"held": "%s of theirs · %s of yours" % [Words.number(int(w["held_theirs"])), Words.number(int(w["held_yours"]))],
			&"state": {"text": str(w["state_text"]), "tone": StringName(str(w["tone"]))},
			&"go": {"text": GO_TEXT},
		}})
	return out


## The battles table's rows: the record's id; Open asks [&"battle", record] (the battle dock).
func _battle_rows_of(battles: Array) -> Array:
	var out: Array = []
	for b: Dictionary in battles:
		out.append({"id": int(b["record"]), "request": [BATTLE_ACTION, int(b["record"])], "cells": {
			&"battle": str(b["name"]),
			&"result": {"text": str(b["result"]), "tone": StringName(str(b["tone"]))},
			&"yours": int(b["yours_lost"]),
			&"theirs": int(b["theirs_lost"]),
			&"open": {"text": OPEN_TEXT},
		}})
	return out


## A war or battle row's Go or Open: its own request (the page's action_requested).
func _on_request_row(row: Dictionary) -> void:
	if row.has("request"):
		request(row["request"] as Array)


## The selection stays on its row when the row is still there, else it is the first row (most men), else none.
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


## Enter, a double click or Go on a row (own or foreign) asks for its hex.
func _on_row_activated(row: Dictionary) -> void:
	if row.has("hex"):
		request([ACTION_LOOK, row["hex"]])


func _on_look_pressed() -> void:
	if not _selected.is_empty():
		request([ACTION_LOOK, _selected["hex"]])


func _on_map_pressed() -> void:
	if not _selected.is_empty():
		request([ACTION_MAP_MODE, MODE_SUPPLY, _selected["hex"]])
