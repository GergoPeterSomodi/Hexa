## The Economy page's History tab (docs/architecture/m4-5-build-spec.md 4.5 and 6.4): money in and out a season as a
## STACKED_BAR (12 or 40 seasons), the cursor's season as a ledger that adds up to its change (Left and Right move the
## cursor, a click sets it, the pointer over a column shows that season), and the treasury at each year's end as a LINE.
## Your land only: StudyEconomy.history for the tag it is given; "No data yet." for none. A work row asks
## action_requested([&"look_at", hex]). The span Segmented asks span_changed; the page writes the setting and refreshes.
class_name EconomyHistoryTab
extends VBoxContainer

signal action_requested(action: Array)
signal span_changed(span: int)

const NO_DATA := "No data yet."
const NO_SEASON := "No season has ended yet."
const NO_YEAR := "No year has ended yet."
const HINT := "Left and Right move the season. Numbers are kept for the last 40 seasons."
const CHART_CAPTION := "Money in and out, a season"
const YEAR_CAPTION := "The treasury at each year's end"
const MISSING := "works begun (no longer in the chronicle)"
const OTHER := "Other (developer)"
const ACTION_LOOK := &"look_at"
const NO_HEX := Vector2i(-1, -1)
const CHART_MIN := Vector2(360.0, 190.0)
const YEAR_MIN := Vector2(240.0, 150.0)
const BEGUN := "Begun: "
const INK_PEOPLE := 0
const INK_GOODS := 1
const INK_DUES := 3
const INK_UPKEEP := 2
const INK_SPENDING := 4

var span: int = 12
## The sum of the main ledger rows now shown (the season's change when the rows add up).
var ledger_sum: int = 0

var _built: bool = false
var _game: Game = null
var _message: Label = null
var _content: VBoxContainer = null
var _seg: Segmented = null
var _chart: InkChart = null
var _ledger: VBoxContainer = null
var _year_chart: InkChart = null
var _year_note: Label = null
var _seasons: Array = []
var _cursor: int = -1
var _shown: int = -1
var _last_turn: int = -1


func _ready() -> void:
	_ensure_built()


func set_span(value: int) -> void:
	_ensure_built()
	span = value
	if _seg.selected_id() != value:
		_seg.select(value)


## Fills the tab from `game` for `tag` (the player's country; &"" shows "No data yet."). The cursor goes to the newest
## season when a season has ended since the last refresh, else it stays.
func refresh(game: Game, tag: StringName) -> void:
	_ensure_built()
	_game = game
	if game == null or tag == &"" or not game.has_countries():
		_show_message(NO_DATA)
		return
	var country := Countries.by_tag(game, tag)
	if country == null or not country.alive:
		_show_message(NO_DATA)
		return
	_show_message("")
	var old_turn := -1
	var was_newest := true
	if _cursor >= 0 and _cursor < _seasons.size():
		old_turn = int((_seasons[_cursor] as Dictionary)["turn"])
		was_newest = _cursor == _seasons.size() - 1
	var h := StudyEconomy.history(game, tag, span)
	_seasons = h["seasons"] as Array
	_update_chart(game)
	var newest := int((_seasons.back() as Dictionary)["turn"]) if not _seasons.is_empty() else -1
	if newest != _last_turn or was_newest or old_turn < 0:
		_cursor = _seasons.size() - 1
	else:  # the same newest season: the cursor stays on its season, found again by turn
		_cursor = _seasons.size() - 1
		for i: int in _seasons.size():
			if int((_seasons[i] as Dictionary)["turn"]) == old_turn:
				_cursor = i
	_last_turn = newest
	_chart.set_cursor(_cursor)
	_show_season(_cursor)
	_update_years(h["years"] as Array)


## {turn}: puts the cursor on that season when it is in the span.
func focus(args: Dictionary) -> void:
	_ensure_built()
	if not args.has("turn"):
		return
	var turn := int(args["turn"])
	for i: int in _seasons.size():
		if int((_seasons[i] as Dictionary)["turn"]) == turn:
			_move_cursor(i)
			return


## The season index the cursor is on (-1 with no seasons).
func cursor() -> int:
	return _cursor


## The season index the ledger shows now (the cursor's, or the hovered column's).
func shown_season() -> int:
	return _shown


func chart() -> InkChart:
	_ensure_built()
	return _chart


func year_chart() -> InkChart:
	_ensure_built()
	return _year_chart


func ledger() -> VBoxContainer:
	_ensure_built()
	return _ledger


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
	var hint := PanelKit.label(HINT, &"Hint")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hint)
	_seg = Segmented.new()
	_seg.name = &"Span"
	_seg.accessibility_name = "Span in seasons"
	var items: Array = []
	for n: int in StudyEconomy.SPANS:
		items.append({"id": n, "label": "%d seasons" % n})
	_seg.set_options(items)
	_seg.select(span)
	_seg.changed.connect(_on_span_pressed)
	top.add_child(_seg)
	_chart = _inset_chart(_content, &"MoneyInset", &"Chart", InkChart.Kind.STACKED_BAR, CHART_MIN)
	_chart.legend = true
	_chart.caption = CHART_CAPTION
	_chart.point_hovered.connect(_on_hovered)
	_chart.point_activated.connect(_on_activated)
	_chart.cursor_keyed.connect(_on_keyed)
	var bottom := HBoxContainer.new()
	bottom.name = &"Bottom"
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(bottom)
	_ledger = VBoxContainer.new()
	_ledger.name = &"Ledger"
	_ledger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_ledger)
	var right := VBoxContainer.new()
	right.name = &"Years"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(right)
	_year_chart = _inset_chart(right, &"YearInset", &"YearChart", InkChart.Kind.LINE, YEAR_MIN)
	_year_chart.caption = YEAR_CAPTION
	_year_note = PanelKit.label(NO_YEAR, &"Hint")
	_year_note.name = &"YearNote"
	right.add_child(_year_note)


func _inset_chart(parent: Control, inset_name: StringName, chart_name: StringName, kind: InkChart.Kind, min_size: Vector2) -> InkChart:
	var inset := PanelContainer.new()
	inset.name = inset_name
	inset.theme_type_variation = &"PanelVellumInset"
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(inset)
	var chart := InkChart.new()
	chart.name = chart_name
	chart.kind = kind
	chart.ground = InkChart.Ground.VELLUM
	chart.custom_minimum_size = min_size
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(chart)
	return chart


func _show_message(text: String) -> void:
	_message.text = text
	_message.accessibility_name = text
	_message.visible = text != ""
	_content.visible = text == ""


# ----- the charts ----------------------------------------------------------------------------------------------------


func _update_chart(game: Game) -> void:
	var labels := PackedStringArray()
	var people := PackedInt32Array()
	var goods := PackedInt32Array()
	var dues := PackedInt32Array()
	var upkeep := PackedInt32Array()
	var spending := PackedInt32Array()
	var marks: Array[Dictionary] = []
	for i: int in _seasons.size():
		var s := _seasons[i] as Dictionary
		labels.append(str(s["title"]))
		people.append(int(s["people"]))
		goods.append(int(s["goods"]))
		dues.append(int(s["dues"]) + int(s["trade"]))
		upkeep.append(int(s["upkeep"]) + int(s["walls"]) + int(s["army"]))
		spending.append(int(s["spending"]))
		var mark := _mark_of(game, s, i)
		if not mark.is_empty():
			marks.append(mark)
	_chart.x_labels = labels
	_chart.set_series([
		{"name": "Taxes on people", "values": people, "ink": INK_PEOPLE},
		{"name": "Taxes on goods", "values": goods, "ink": INK_GOODS},
		{"name": "Port dues", "values": dues, "ink": INK_DUES},
		{"name": "Upkeep and walls", "values": upkeep, "ink": INK_UPKEEP, "role": "out"},
		{"name": "Your spending", "values": spending, "ink": INK_SPENDING, "role": "out"},
	])
	_chart.set_marks(marks)


## A mark on a season with spending: its largest work's words, bad when the treasury fell.
func _mark_of(game: Game, season: Dictionary, index: int) -> Dictionary:
	if int(season["spending"]) == 0:
		return {}
	var best: Dictionary = {}
	for w: Dictionary in (season["works"] as Array):
		if int(w["amount"]) < 0 and (best.is_empty() or int(w["amount"]) < int(best["amount"])):
			best = w
	var text := MISSING
	if not best.is_empty():
		text = _work_words(game, best)
	var fell := int(season["change"]) < 0
	return {"index": index, "text": text, "tone": &"bad" if fell else &"warn"}


## "walled town to city" from "Begun: walled town to city, Genoa (8, 13)".
func _work_words(game: Game, work: Dictionary) -> String:
	var text := str(work["text"])
	if text.begins_with(BEGUN):
		text = text.substr(BEGUN.length())
	var suffix := ", %s" % Words.place(game, work["hex"] as Vector2i)
	if text.ends_with(suffix):
		text = text.left(text.length() - suffix.length())
	return text


func _update_years(years: Array) -> void:
	var labels := PackedStringArray()
	var values := PackedInt32Array()
	for y: Dictionary in years:
		labels.append(str(y["year"]))
		values.append(int(y["closing"]))
	_year_chart.x_labels = labels
	_year_chart.set_series([{"name": "Treasury", "values": values, "ink": 0}])
	var has := not years.is_empty()
	(_year_chart.get_parent() as Control).visible = has
	_year_note.visible = not has
	_year_note.text = NO_YEAR
	_year_note.accessibility_name = NO_YEAR


# ----- the cursor's season -------------------------------------------------------------------------------------------


func _move_cursor(index: int) -> void:
	_cursor = clampi(index, 0, maxi(0, _seasons.size() - 1))
	_chart.set_cursor(_cursor)
	_show_season(_cursor)


func _on_activated(index: int) -> void:
	_move_cursor(index)


## A key move sets the cursor for good (cursor_keyed); a pointer over a column only shows that season; -1 (the pointer
## left) shows the cursor's again.
func _on_hovered(index: int) -> void:
	if index < 0:
		_chart.set_cursor(_cursor)
		_show_season(_cursor)
		return
	_show_season(index)


func _on_keyed(index: int) -> void:
	_cursor = clampi(index, 0, maxi(0, _seasons.size() - 1))


func _show_season(index: int) -> void:
	PanelKit.clear_children(_ledger)
	_shown = -1
	ledger_sum = 0
	if _seasons.is_empty():
		_ledger.add_child(PanelKit.label(NO_SEASON, &"Hint"))
		return
	index = clampi(index, 0, _seasons.size() - 1)
	_shown = index
	var s := _seasons[index] as Dictionary
	var title := PanelKit.label(str(s["title"]), &"SectionHead")
	_ledger.add_child(title)
	var change := int(s["change"])
	var treasury := "Treasury %s → %s" % [Words.number(int(s["opening"])), Words.number(int(s["closing"]))]
	_ledger.add_child(_row(treasury, change, &"Treasury"))
	_ledger.add_child(HSeparator.new())
	_add_line("Taxes on people", int(s["people"]))
	_add_line("Taxes on goods", int(s["goods"]))
	_add_line("Port dues", int(s["dues"]))
	if int(s["trade"]) != 0:
		_add_line("Trade", int(s["trade"]))
	_add_line("District upkeep", -int(s["upkeep"]))
	_add_line("Walls", -int(s["walls"]))
	if int(s["army"]) != 0:
		_add_line("Army", -int(s["army"]))
	_add_line("Your spending", -int(s["spending"]))
	for w: Dictionary in (s["works"] as Array):
		_ledger.add_child(_work_row(w))
	if bool(s["works_missing"]):
		_ledger.add_child(PanelKit.label(MISSING, &"Hint"))
	if int(s["other"]) != 0:
		_add_line(OTHER, int(s["other"]))


func _add_line(text: String, amount: int) -> void:
	ledger_sum += amount
	_ledger.add_child(_row(text, amount, &""))


func _row(text: String, amount: int, row_name: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if row_name != &"":
		row.name = row_name
	var label := PanelKit.label(text, &"Body")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_chip(amount))
	return row


func _work_row(work: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn := Button.new()
	btn.text = str(work["text"])
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.theme_type_variation = &"ButtonNav"
	btn.accessibility_name = "Look at %s" % btn.text
	btn.pressed.connect(_on_work.bind(work["hex"] as Vector2i))
	row.add_child(btn)
	row.add_child(_chip(int(work["amount"])))
	return row


func _chip(amount: int) -> DeltaChip:
	var chip := DeltaChip.new()
	chip.set_delta(amount)
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = float(Tokens.S1)
	flat.content_margin_right = float(Tokens.S1)
	chip.add_theme_stylebox_override(&"panel", flat)
	return chip


func _on_work(hex: Vector2i) -> void:
	if hex != NO_HEX:
		action_requested.emit([ACTION_LOOK, hex])


func _on_span_pressed(id: Variant) -> void:
	var value := int(id)
	if value == span:
		return
	span = value
	span_changed.emit(value)
