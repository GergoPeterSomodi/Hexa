## The Buildings tab of the tile window (tile-window spec R19, R20, D8, D14; build plan TW11): on any land tile, live on
## own land (the sandbox too) and dimmed elsewhere with the reason of Territory.at_home_check. The tab shows the summary line
## ("Buildings here make +N a year · upkeep -M"), a search box, a filter (All, Can build, Built), and the rows of
## TileBuildings.of grouped by category; each row is a BuildingRow. The rows come first without their gains; the gains and
## the upkeep fill one row a frame (_process), then the summary. finish_now() fills them all at once (tests).
##
## The hammer runs the works rule of BuildRows (game/confirm_works through `settings`, the card or the begin request). The
## tab never changes the game: a begin is a works_requested request, which the App answers (WorksFlow, begin_work). U is not
## handled here: the map scene's U key reaches the App, which begins the first upgrade (the old panel did the same); the
## upgrade hammer keeps the game_upgrade hotkey of the old rows.
extends TileTab

const ID := &"buildings"
const LABEL := "Buildings"
const ORDER := 20
const FILTER_ALL := &"all"
const FILTER_READY := &"ready"
const FILTER_BUILT := &"built"
const FILTERS: Array[StringName] = [FILTER_ALL, FILTER_READY, FILTER_BUILT]
const FILTER_LABELS := {&"all": "All", &"ready": "Can build", &"built": "Built"}
const SEARCH_HINT := "Search buildings"
const NOT_YOURS := "Not your land"
const WORKING_OUT := "Working out the year's gains"

## The Settings the hammer's rule reads (game/confirm_works); the window passes App.settings(). Null: the shipped default.
var settings: Settings = null

var _game: Game = null
var _tag: StringName = &""
var _hex: Vector2i = Vector2i.ZERO
var _groups: Array = []
var _rows_by_id: Dictionary = {}
var _order: Array[StringName] = []
var _numbers: Dictionary = {}
var _nodes: Dictionary = {}
var _queue: Array[StringName] = []
var _filter: StringName = FILTER_ALL
var _query := ""
var _done := false
var _make := 0
var _upkeep := 0
var _summary: Label
var _search: LineEdit
var _segment: Segmented
var _list: VBoxContainer
var _note: Label


## Live on any land case (sea and unexplored have no strip and no buildings). Static, as the registry asks.
static func applies(view: Dictionary) -> bool:
	var case_id := StringName(str(view.get("case", "")))
	return case_id != &"" and case_id != &"sea" and case_id != &"unexplored"


## Dimmed when the home rule refuses building here (foreign or unowned land): its reason, else a plain one.
static func dimmed(view: Dictionary) -> String:
	var build: Dictionary = view.get("build", {})
	if bool(build.get("offered", false)):
		return ""
	var reason := str(build.get("reason", ""))
	return reason if reason != "" else NOT_YOURS


## The numbers of one row, from its option's works card (TileBuildings' rule, read in one place): an option row's gain and
## upkeep are the card's year.gain and lands.upkeep; a built row's are the clearing card's, turned round. Null when a card has
## no year or no lands. Static and pure; the tests compare it with TileBuildings.of(full = true).
static func numbers_of(game: Game, tag: StringName, hex: Vector2i, row: Dictionary) -> Dictionary:
	var state := StringName(str(row.get("state", "")))
	if state == &"built":
		var piece := Improve.piece_at(game, hex)
		if piece.is_empty():
			return {"gain": null, "upkeep": null}
		var clear := ImprovePreview.of(game, tag, hex, {"action": Works.CLEAR, "family": int(piece["family_id"])})
		return {"gain": _turned(clear, "year", "gain"), "upkeep": _turned(clear, "lands", "upkeep")}
	if state == &"building" or (row.get("option", {}) as Dictionary).is_empty():
		return {"gain": null, "upkeep": null}
	var card := ImprovePreview.of(game, tag, hex, row["option"] as Dictionary)
	return {"gain": _field(card, "year", "gain", 1), "upkeep": _field(card, "lands", "upkeep", 1)}


## Fills the tab: the controls, then the rows of TileBuildings (light), then the gains one row a frame.
func fill(game: Game, viewer: StringName, hex: Vector2i, view: Dictionary) -> void:
	_game = game
	_tag = viewer
	_hex = hex
	_numbers = {}
	_queue = []
	_done = false
	_build_controls()
	var model := TileBuildings.of(game, viewer, hex, false)
	if model.is_empty():
		_summary.text = ""
		_note.text = dimmed(view)
		_note.visible = true
		return
	_index(model.get("groups", []))
	for id: StringName in _order:
		var row: Dictionary = _rows_by_id[id]
		if StringName(str(row["state"])) != &"building" and (not (row["option"] as Dictionary).is_empty() or StringName(str(row["state"])) == &"built"):
			_queue.append(id)
	_refresh_list()
	if _queue.is_empty():
		_finish()
	else:
		_summary.text = WORKING_OUT
		set_process(true)


## One row's gain and upkeep per frame (the one-row-a-frame fill of R20); the summary when the queue is empty.
func _process(_delta: float) -> void:
	if _queue.is_empty():
		set_process(false)
		return
	_step()


## Fills every row now (tests and the monkey; the frame does it one row at a time otherwise).
func finish_now() -> void:
	while not _queue.is_empty():
		_step()


## True once every row has its numbers and the summary is worked out.
func is_done() -> bool:
	return _done


## The summary line's text (tests read it).
func summary_text() -> String:
	return _summary.text if _summary != null else ""


## The rows still waiting for their gains (the fill takes one a frame).
func pending() -> int:
	return _queue.size()


## The row nodes shown, by row id (tests and tools read them).
func row_nodes() -> Dictionary:
	return _nodes.duplicate()


## The row data of one id, as TileBuildings gave it (tests read it).
func row_data(id: StringName) -> Dictionary:
	return (_rows_by_id.get(id, {}) as Dictionary).duplicate()


## The search box and the filter, for tests and the keys.
func search_box() -> LineEdit:
	return _search


func filter_control() -> Segmented:
	return _segment


## Sets the search text (the box's own signal runs the same rule).
func set_query(text: String) -> void:
	_search.text = text
	_on_query_changed(text)


## Picks a filter (FILTER_ALL, FILTER_READY or FILTER_BUILT).
func set_filter(id: StringName) -> void:
	_segment.select(id, true)


## The shown filter id.
func filter() -> StringName:
	return _filter


## The rows that show now, in order, as their ids.
func visible_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _nodes:
		out.append(id)
	out.sort()
	return out


## Begins a row's work or opens its card, by the works rule of BuildRows (the hammer and the menu's Build here).
func begin_option(option: Dictionary, expensive: bool) -> void:
	_click(option, expensive)


## The hammer's click on a row: enabled rows only (the row refuses a disabled press).
func press_row(id: StringName) -> void:
	var node := _nodes.get(id) as BuildingRow
	if node != null:
		node.press_hammer()


# --- the controls -------------------------------------------------------------------------------------------------------


func _build_controls() -> void:
	PanelKit.clear_children(self)
	_summary = PanelKit.label("", &"LabelInk")
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary)
	_search = LineEdit.new()
	_search.placeholder_text = SEARCH_HINT
	_search.clear_button_enabled = true
	_search.custom_minimum_size.y = float(Tokens.BUTTON_H)
	_search.text_changed.connect(_on_query_changed)
	add_child(_search)
	_segment = Segmented.new()
	var options: Array = []
	for id: StringName in FILTERS:
		options.append({"id": id, "label": FILTER_LABELS[id]})
	_segment.set_options(options)
	_segment.changed.connect(_on_filter_changed)
	_segment.select(FILTER_ALL)
	add_child(_segment)
	_note = PanelKit.label("", &"Reason")
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	add_child(_note)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", Tokens.S2)
	add_child(_list)
	_filter = FILTER_ALL
	_query = ""
	_nodes = {}


func _on_query_changed(text: String) -> void:
	_query = text.strip_edges()
	_refresh_list()


func _on_filter_changed(id: Variant) -> void:
	_filter = StringName(str(id))
	_refresh_list()


# --- the rows -----------------------------------------------------------------------------------------------------------


func _index(groups: Array) -> void:
	_groups = groups
	_rows_by_id = {}
	_order = []
	var offers := ImprovePreview.options_of(_game, _tag, _hex)
	for group: Variant in groups:
		for row: Variant in (group as Dictionary)["rows"]:
			var data := (row as Dictionary).duplicate()
			var option := data["option"] as Dictionary
			data["expensive"] = false
			if not option.is_empty():
				data["expensive"] = _expensive_of(offers, option)
			var id := StringName(str(data["id"]))
			_rows_by_id[id] = data
			_order.append(id)


## The expensive flag of an option from ImprovePreview.options_of (the rule of the card's click).
func _expensive_of(offers: Array, option: Dictionary) -> bool:
	for row: Dictionary in offers:
		if StringName(str(row["action"])) == StringName(str(option["action"])) and int(row["family"]) == int(option["family"]):
			return bool(row["expensive"])
	return false


func _refresh_list() -> void:
	PanelKit.clear_children(_list)
	_nodes = {}
	if _game == null:
		return
	var shown := 0
	for group: Variant in _groups:
		var g := group as Dictionary
		var rows: Array[Dictionary] = []
		for row: Variant in g["rows"]:
			# The indexed copy carries the `expensive` flag the hammer's rule reads.
			var data := _rows_by_id.get(StringName(str((row as Dictionary)["id"])), row) as Dictionary
			if _passes(data):
				rows.append(data)
		if rows.is_empty():
			continue
		var head := PanelKit.label(_heading_of(g), &"SectionHead")
		_list.add_child(head)
		for data: Dictionary in rows:
			_list.add_child(_row_node(data))
			shown += 1
	_note.text = "Nothing matches." if shown == 0 and _rows_by_id.size() > 0 else ""
	_note.visible = _note.text != ""


## The group's heading: its name, and "n of m slots" when the group has slots (none before M9.5).
static func _heading_of(group: Dictionary) -> String:
	var slots: Dictionary = group.get("slots", {})
	if slots.is_empty():
		return str(group["name"])
	return "%s  %d of %d slots" % [str(group["name"]), int(slots["used"]), int(slots["total"])]


func _passes(row: Dictionary) -> bool:
	var state := StringName(str(row["state"]))
	if _filter == FILTER_READY and state != &"ready":
		return false
	if _filter == FILTER_BUILT and state != &"built":
		return false
	if _query != "" and not str(row["name"]).to_lower().contains(_query.to_lower()):
		return false
	return true


func _row_node(data: Dictionary) -> BuildingRow:
	var id := StringName(str(data["id"]))
	var node := BuildingRow.new()
	node.setup(data)
	var numbers: Dictionary = _numbers.get(id, {})
	if not numbers.is_empty():
		node.set_numbers(numbers["gain"], numbers["upkeep"])
	node.hovered.connect(_on_row_hovered.bind(node))
	node.unhovered.connect(func() -> void: row_unhovered.emit())
	node.hammer_pressed.connect(_on_hammer_pressed)
	_nodes[id] = node
	return node


func _on_row_hovered(data: Dictionary, node: BuildingRow) -> void:
	var card := BuildingCard.of(_game, _tag, _hex, data["option"] as Dictionary)
	row_hovered.emit(card, node.get_global_rect())


func _on_hammer_pressed(data: Dictionary) -> void:
	var option := data["option"] as Dictionary
	if option.is_empty():
		return
	_click(option, bool(data.get("expensive", false)))


# --- the gains ----------------------------------------------------------------------------------------------------------


func _step() -> void:
	var id: StringName = _queue.pop_front()
	var row: Dictionary = _rows_by_id.get(id, {})
	if not row.is_empty():
		var numbers := numbers_of(_game, _tag, _hex, row)
		_numbers[id] = numbers
		var node := _nodes.get(id) as BuildingRow
		if node != null and is_instance_valid(node):
			node.set_numbers(numbers["gain"], numbers["upkeep"])
	if _queue.is_empty():
		_finish()


## The summary: the sum of the built rows' gains and upkeep (R19; the tests check it equals TileBuildings' summary).
func _finish() -> void:
	set_process(false)
	_make = 0
	_upkeep = 0
	for id: StringName in _numbers:
		var row: Dictionary = _rows_by_id.get(id, {})
		if StringName(str(row.get("state", ""))) != &"built":
			continue
		var numbers: Dictionary = _numbers[id]
		if numbers["gain"] != null:
			_make += int(numbers["gain"])
		if numbers["upkeep"] != null:
			_upkeep += int(numbers["upkeep"])
	_done = true
	_summary.text = "Buildings here make %s a year · upkeep %s" % [Words.signed(_make), _upkeep_words()]


func _upkeep_words() -> String:
	return "-" + Words.number(_upkeep) if _upkeep != 0 else "0"


# --- the click rule ----------------------------------------------------------------------------------------------------


## The works rule of BuildRows: the card when the mode asks for it, else the begin request. Both go to the App through
## works_requested, with the same names and args as the old rows (hex, option).
func _click(option: Dictionary, expensive: bool) -> void:
	var clean := {"action": option["action"], "family": option["family"]}
	if BuildRows.click_of(BuildRows.confirm_mode_of(settings), expensive) == &"card":
		works_requested.emit({"what": &"works_card", "args": {"hex": _hex, "option": clean}})
		return
	works_requested.emit({"what": &"begin_work", "args": {"hex": _hex, "option": clean}})


# --- helpers ------------------------------------------------------------------------------------------------------------


static func _field(card: Dictionary, block: String, key: String, sign: int) -> Variant:
	var part: Dictionary = card.get(block, {})
	if part.is_empty():
		return null
	return sign * int(part[key])


static func _turned(card: Dictionary, block: String, key: String) -> Variant:
	return _field(card, block, key, -1)
