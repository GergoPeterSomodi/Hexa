## The History page of the Statesman's Study (docs/architecture/m4-5-build-spec.md 4.7 and 6.6; the mockup
## tests/fixtures/mockup/study_history.png). It shows StudyHistory for the player's country (game.player) and nobody else's:
## a TimelineStrip over the whole game with one mark a season, the season at the cursor (its title and its line), the
## filters of the milestone, Older and Newest, and the chronicle as a StudyTable of whole seasons, newest first. It changes
## nothing: a row's Go asks request([&"look_at", hex]); a row, a hover or a key on the strip moves the cursor; a click or Enter
## on the strip shows the list from that season back. With no player (the pick, the sandbox) it says "No data yet.".
class_name PageHistory
extends StudyPage

const NO_DATA := "No data yet."
const NO_SEASON := "No season has ended yet."
const SECTION := "History"
const FILTER_LABEL: Dictionary = {"all": "All", "war": "War", "money": "Money", "works": "Works", "mine": "Mine"}
const ACTION_LOOK := &"look_at"
const NO_HEX := Vector2i(-1, -1)
const GO_COLUMN := 3
const GO_TEXT := "Go"
const OLDER_TEXT := "Older"
const NEWEST_TEXT := "Newest"
const SHOWN_FORMAT := "Showing %s of %s"
const TABLE_MIN_HEIGHT := 240.0
const COLUMNS: Array[Dictionary] = [
	{"id": &"season", "title": "Season", "kind": &"number", "align": "left", "expand": false, "min_width": 120},
	{"id": &"what", "title": "What", "kind": &"text", "expand": false, "min_width": 110},
	{"id": &"line", "title": "Line", "kind": &"text"},
	{"id": &"go", "title": "Go", "kind": &"button", "expand": false, "min_width": 56},
]

var _built: bool = false
var _game: Game = null
var _viewer: StringName = &""
var _filter: StringName = &"all"
var _filter_ids: Array[StringName] = []
## The cursor's turn; 0 when no season has ended yet.
var _cursor: int = 0
## The list shows the seasons up to this turn; 0 is the newest.
var _upto: int = 0
var _hover: int = -1
## A focus({turn}) waiting for the next refresh.
var _pending: int = 0
var _last: int = 0
var _seen_last: int = 0
var _older_turn: int = 0
## Row id -> hex (NO_HEX for a line without one), for the rows of the table in view.
var _hex_of: Dictionary = {}
var _message: Label = null
var _body: VBoxContainer = null
var _timeline: TimelineStrip = null
var _season_head: Label = null
var _season_line: Label = null
var _filters: Segmented = null
var _older: KitButton = null
var _newest: KitButton = null
var _count: Label = null
var _table: StudyTable = null


func _ready() -> void:
	_ensure_built()


## Fills the page from `game` for its player; `tag` says why (open, season_ended, ...) and is not used.
func refresh(game: Game, _tag: StringName) -> void:
	_ensure_built()
	_game = game
	_viewer = game.player if game != null else &""
	if _viewer == &"":
		_show_message(NO_DATA)
		return
	_show_message("")
	_sync_filters()
	var timeline := StudyHistory.timeline(game, _viewer)
	_last = int(timeline["last_turn"])
	_timeline.set_timeline(timeline)
	if _pending >= 1:
		_cursor = mini(_pending, _last)
		_upto = 0 if _cursor >= _last else _cursor
		_pending = 0
	elif _cursor < 1 or _cursor > _last or _cursor == _seen_last:
		_cursor = _last  # a new season has ended: a cursor on the newest season follows it
	if _upto > _last:
		_upto = 0
	_seen_last = _last
	_hover = -1
	_timeline.set_cursor(_cursor if _cursor >= 1 else -1)
	_refresh_season()
	_refresh_list()


## Moves the cursor to `args.turn` and shows the list from that season back (the list is refilled at once when a game is
## in view, else at the next refresh).
func focus(args: Dictionary) -> void:
	_ensure_built()
	if not args.has("turn"):
		return
	_pending = int(args["turn"])
	if _game != null:
		refresh(_game, &"focus")


# ----- accessors (tests read these; nothing here changes the page) ---------------------------------------------------


func cursor_turn() -> int:
	return _cursor


func list_upto() -> int:
	return _upto


func filter_id() -> StringName:
	return _filter


func filter_ids() -> Array[StringName]:
	return _filter_ids.duplicate()


func older_turn() -> int:
	return _older_turn


func table() -> StudyTable:
	return _table


func timeline() -> TimelineStrip:
	return _timeline


func filters_control() -> Segmented:
	return _filters


func older_button() -> KitButton:
	return _older


func newest_button() -> KitButton:
	return _newest


func count_text() -> String:
	return _count.text


func season_head_text() -> String:
	return _season_head.text


func season_line_text() -> String:
	return _season_line.text


func message_text() -> String:
	return _message.text


func body_visible() -> bool:
	return _body.visible


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
	_body = VBoxContainer.new()
	_body.name = &"Body"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_body)
	_build_timeline()
	_season_head = PanelKit.label("", &"SectionHead")
	_season_head.name = &"SeasonHead"
	_body.add_child(_season_head)
	_season_line = PanelKit.label("", &"Body")
	_season_line.name = &"SeasonLine"
	_season_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_season_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_season_line)
	_build_chronicle()


func _build_timeline() -> void:
	var inset := PanelContainer.new()
	inset.name = &"TimelineInset"
	inset.theme_type_variation = &"PanelVellumInset"
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(inset)
	_timeline = TimelineStrip.new()
	_timeline.name = &"Timeline"
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.season_hovered.connect(_on_season_hovered)
	_timeline.season_activated.connect(_on_season_activated)
	_timeline.cursor_moved.connect(_on_cursor_moved)
	inset.add_child(_timeline)


func _build_chronicle() -> void:
	var row := HBoxContainer.new()
	row.name = &"FilterRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(row)
	_filters = Segmented.new()
	_filters.name = &"Filters"
	_filters.accessibility_name = "Lines to show"
	_filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filters.changed.connect(_on_filter_changed)
	row.add_child(_filters)
	_older = _page_button(OLDER_TEXT, "Show older lines", _on_older_pressed)
	row.add_child(_older)
	_newest = _page_button(NEWEST_TEXT, "Show the newest lines", _on_newest_pressed)
	row.add_child(_newest)
	_count = PanelKit.label("", &"Hint")
	_count.name = &"Count"
	row.add_child(_count)
	_table = StudyTable.new()
	_table.name = &"Table"
	_table.section_title = SECTION
	_table.custom_minimum_size = Vector2(0.0, TABLE_MIN_HEIGHT)
	_table.set_columns(COLUMNS)
	_table.row_selected.connect(_on_row_selected)
	_table.row_activated.connect(_on_row_activated)
	_body.add_child(_table)


func _page_button(text: String, accessible: String, on_press: Callable) -> KitButton:
	var btn := KitButton.new()
	btn.name = StringName(text)
	btn.text = text
	btn.kind = KitButton.Kind.SMALL
	btn.accessibility_name = accessible
	btn.pressed.connect(on_press)
	return btn


func _show_message(text: String) -> void:
	_message.text = text
	_message.accessibility_name = text
	_message.visible = text != ""
	_body.visible = text == ""


# ----- filling -------------------------------------------------------------------------------------------------------


## The filters of the milestone; the list keeps the filter in view when it is still shown, else All.
func _sync_filters() -> void:
	var ids := StudyHistory.filters(milestone)
	if ids == _filter_ids:
		return
	_filter_ids = ids
	var items: Array = []
	for id: StringName in ids:
		items.append({"id": id, "label": str(FILTER_LABEL.get(String(id), String(id).capitalize()))})
	_filters.set_options(items)
	if not ids.has(_filter):
		_filter = &"all"
	_filters.select(_filter)


func _refresh_season() -> void:
	var turn := _hover if _hover >= 1 else _cursor
	if _game == null or _viewer == &"" or turn < 1:
		_season_head.text = ""
		_season_line.text = NO_SEASON
	else:
		var season := StudyHistory.season(_game, _viewer, turn)
		_season_head.text = str(season["title"])
		_season_line.text = str(season["text"])
	_season_head.accessibility_name = _season_head.text
	_season_line.accessibility_name = _season_line.text


func _refresh_list() -> void:
	if _game == null or _viewer == &"":
		return
	var page := StudyHistory.chronicle(_game, _viewer, _filter, _upto)
	var rows: Array = page["rows"]
	_hex_of.clear()
	var table_rows: Array = []
	for r: Dictionary in rows:
		table_rows.append(_table_row(r))
	_table.set_rows(table_rows)
	_older_turn = int(page["older_turn"])
	_older.disabled = _older_turn == 0
	_newest.disabled = _upto == 0
	_count.text = SHOWN_FORMAT % [InkMarks.grouped(rows.size()), InkMarks.grouped(int(page["total"]))]
	_count.accessibility_name = _count.text


## One chronicle line as a table row: the season (sorted by turn), the keyword, the line; a Go cell when it has a hex.
func _table_row(r: Dictionary) -> Dictionary:
	var id := int(r["id"])
	var hex: Vector2i = r["hex"]
	_hex_of[id] = hex
	var cells := {
		"season": {"value": int(r["turn"]), "text": str(r["title"])},
		"what": str(r["keyword"]),
		"line": str(r["text"]),
	}
	if hex != NO_HEX:
		cells["go"] = {"text": GO_TEXT}
	return {"id": id, "turn": int(r["turn"]), "cells": cells, "hex": hex, "mine": bool(r["mine"])}


# ----- signals -------------------------------------------------------------------------------------------------------


## A row only moves the cursor: the list is not refilled from a row's signal.
func _on_row_selected(row: Dictionary) -> void:
	var turn := int(row.get("turn", 0))
	if turn < 1:
		return
	_cursor = turn
	_timeline.set_cursor(turn)
	_refresh_season()


func _on_row_activated(row: Dictionary) -> void:
	var hex: Vector2i = row.get("hex", NO_HEX)
	if hex != NO_HEX:
		request([ACTION_LOOK, hex])


func _on_season_hovered(turn: int) -> void:
	_hover = turn
	_refresh_season()


func _on_cursor_moved(turn: int) -> void:
	_cursor = turn
	_refresh_season()


## A click or Enter on the strip: the cursor goes there and the list shows from that season back.
func _on_season_activated(turn: int) -> void:
	_cursor = turn
	_upto = 0 if turn >= _last else turn
	_refresh_season()
	_refresh_list()


func _on_filter_changed(id: Variant) -> void:
	_filter = StringName(str(id))
	_refresh_list()


func _on_older_pressed() -> void:
	if _older_turn < 1:
		return
	_upto = _older_turn
	_refresh_list()


func _on_newest_pressed() -> void:
	_upto = 0
	_refresh_list()
