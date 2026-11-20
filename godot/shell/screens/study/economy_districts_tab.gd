## The Economy page's Districts tab (docs/architecture/m4-5-build-spec.md 4.3 and 6.4): every piece of the player's land
## (a district, a town or a castle) in a StudyTable sorted by "A year", the wild land in one line, the realm's year, and
## the buttons Look there and Show on the map. Your land only: it reads StudyEconomy.districts for the tag it is given
## and shows "No data yet." for none. It changes nothing: a row asks action_requested([&"look_at", hex]) and Show on the
## map [&"map_mode", &"yields", hex] (no hex when no row is selected).
class_name EconomyDistrictsTab
extends VBoxContainer

signal action_requested(action: Array)

const NO_DATA := "No data yet."
const NO_LAND := "You hold no land."
const HINT := "Weather not counted. Click a heading to sort. Enter on a row looks at that place."
const TITLE := "Districts"
const LOOK := "Look there"
const SHOW_MAP := "Show on the map"
const WILD_NONE := "No wild land."
const ALL_LAND := "All your land:"
const ALL_NOTE := "(each place rounded down)"
const YEAR_UNIT := "a year"
const ACTION_LOOK := &"look_at"
const ACTION_MODE := &"map_mode"
const MODE_YIELDS := &"yields"
const NO_HEX := Vector2i(-1, -1)
const SPARK_INK := 0
const TABLE_MIN_H := 160.0

var _built: bool = false
var _message: Label = null
var _content: VBoxContainer = null
var _table: StudyTable = null
var _wild_row: HBoxContainer = null
var _all_row: HBoxContainer = null
var _look: KitButton = null
var _show: KitButton = null
var _selected_hex: Vector2i = NO_HEX
var _rows: Array[Dictionary] = []


func _ready() -> void:
	_ensure_built()


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
	var d := StudyEconomy.districts(game, tag)
	if not bool(d["has_land"]):
		_show_message(NO_LAND)
		return
	_show_message("")
	_rows = []
	var table_rows: Array = []
	for r: Dictionary in (d["rows"] as Array):
		_rows.append(r)
		table_rows.append({
			"id": int(r["id"]), "hex": r["hex"], "data": r,
			"cells": {
				&"place": str(r["place"]), &"what": str(r["what"]), &"gives": str(r["gives"]),
				&"season": int(r["season"]), &"year": int(r["year"]), &"upkeep": int(r["upkeep"]),
				&"seasons": r["seasons"],
			},
		})
	_table.set_rows(table_rows)
	if _table.selected_row().is_empty() and not _table.sorted_ids().is_empty():
		_table.select_id(int(_table.sorted_ids()[0]))
	_sync_selection()
	_fill_wild(d["wild"] as Dictionary)
	_fill_all(int(d["total_year"]))


## {hex}: selects that row. Other keys are not this tab's.
func focus(args: Dictionary) -> void:
	_ensure_built()
	if not args.has("hex"):
		return
	var hex: Vector2i = args["hex"]
	for r: Dictionary in _rows:
		if (r["hex"] as Vector2i) == hex:
			_table.select_id(int(r["id"]))
			_sync_selection()
			return


## The table (tests and the page read its rows and sort).
func table() -> StudyTable:
	_ensure_built()
	return _table


func look_button() -> KitButton:
	_ensure_built()
	return _look


func show_button() -> KitButton:
	_ensure_built()
	return _show


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
	var hint := PanelKit.label(HINT, &"Hint")
	hint.name = &"HintLine"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(hint)
	_table = StudyTable.new()
	_table.name = &"Table"
	_table.section_title = TITLE
	_table.custom_minimum_size.y = TABLE_MIN_H
	_table.set_columns([
		{"id": "place", "title": "Place", "kind": "text", "expand": true},
		{"id": "what", "title": "What", "kind": "text", "expand": true},
		{"id": "gives", "title": "Gives a year", "kind": "text", "expand": true},
		{"id": "season", "title": "This season", "kind": "delta"},
		{"id": "year", "title": "A year", "kind": "delta"},
		{"id": "upkeep", "title": "Upkeep a year", "kind": "delta"},
		{"id": "seasons", "title": "Seasons", "kind": "spark", "ink": SPARK_INK, "min_width": 90},
	])
	_table.sort_by(&"year", true)
	_table.row_selected.connect(_on_row_selected)
	_table.row_activated.connect(_on_row_activated)
	_content.add_child(_table)
	_wild_row = HBoxContainer.new()
	_wild_row.name = &"WildLine"
	_content.add_child(_wild_row)
	_all_row = HBoxContainer.new()
	_all_row.name = &"AllLine"
	_content.add_child(_all_row)
	var buttons := HBoxContainer.new()
	buttons.name = &"Buttons"
	_content.add_child(buttons)
	_look = _button(LOOK)
	_look.pressed.connect(_on_look)
	buttons.add_child(_look)
	_show = _button(SHOW_MAP)
	_show.pressed.connect(_on_show)
	buttons.add_child(_show)


func _button(text: String) -> KitButton:
	var btn := KitButton.new()
	btn.text = text
	btn.accessibility_name = text
	return btn


func _show_message(text: String) -> void:
	_message.text = text
	_message.accessibility_name = text
	_message.visible = text != ""
	_content.visible = text == ""


func _fill_wild(wild: Dictionary) -> void:
	PanelKit.clear_children(_wild_row)
	var count := int(wild["count"])
	if count == 0:
		_wild_row.add_child(PanelKit.label(WILD_NONE, &"Body"))
		return
	var text := "Wild land: %s" % Words.plural(count, "place", "places")
	var gives := str(wild["gives"])
	if gives != "":
		text += ", %s" % gives
	text += " a year,"
	_wild_row.add_child(PanelKit.label(text, &"Body"))
	_wild_row.add_child(_chip(int(wild["year"]), YEAR_UNIT))


func _fill_all(total: int) -> void:
	PanelKit.clear_children(_all_row)
	_all_row.add_child(PanelKit.label(ALL_LAND, &"Body"))
	_all_row.add_child(_chip(total, YEAR_UNIT))
	_all_row.add_child(PanelKit.label(ALL_NOTE, &"Hint"))


func _chip(amount: int, unit: String) -> DeltaChip:
	var chip := DeltaChip.new()
	chip.set_delta(amount, unit)
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = float(Tokens.S1)
	flat.content_margin_right = float(Tokens.S1)
	chip.add_theme_stylebox_override(&"panel", flat)
	return chip


# ----- signals -------------------------------------------------------------------------------------------------------


func _sync_selection() -> void:
	var row := _table.selected_row()
	_selected_hex = row["hex"] as Vector2i if row.has("hex") else NO_HEX
	_look.disabled = _selected_hex == NO_HEX


func _on_row_selected(row: Dictionary) -> void:
	_selected_hex = row["hex"] as Vector2i if row.has("hex") else NO_HEX
	_look.disabled = _selected_hex == NO_HEX


func _on_row_activated(row: Dictionary) -> void:
	if row.has("hex"):
		action_requested.emit([ACTION_LOOK, row["hex"] as Vector2i])


func _on_look() -> void:
	if _selected_hex != NO_HEX:
		action_requested.emit([ACTION_LOOK, _selected_hex])


func _on_show() -> void:
	if _selected_hex != NO_HEX:
		action_requested.emit([ACTION_MODE, MODE_YIELDS, _selected_hex])
	else:
		action_requested.emit([ACTION_MODE, MODE_YIELDS])
