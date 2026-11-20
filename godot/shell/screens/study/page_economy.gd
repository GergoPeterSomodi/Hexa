## The Economy page of the Statesman's Study, "This season" (docs/architecture/m4-build-spec.md 6.7; the mockup
## study_econ.jpg). It draws StudyEconomy.this_season for the player's country: the closed ledger (Money in, Money out,
## Left over, Your spending, Treasury this season), the season in play (Expected), the tax levels and the 12-season chart
## with Earns most and Costs most. It changes nothing: a tax level is asked for as action_requested([&"set_tax", level])
## and a row as action_requested([&"look_at", hex]); the App routes both.
## `treasury_only` is the shell's game/gain_treasury_only switch, set by the study before refresh (docs/architecture/
## m4-build-spec.md 5.0 R2): true shows the treasury's measure, false the realm's.
class_name PageEconomy
extends StudyPage

const NO_SEASON := "No season has ended yet."
const NO_TREASURY := "The sandbox has no treasury."
const NO_LINES := "Nothing this season."
const NO_HEX := Vector2i(-1, -1)
const HEAD_IN := "Money in"
const HEAD_OUT := "Money out"
const LEFT_OVER := "Left over, a season"
const SPENDING := "Your spending"
const TREASURY_ROW := "Treasury this season"
const EXPECTED := "Expected this season"
const TAX_LABEL := "Tax"
const CHART_TITLE := "The last 12 seasons"
const CHART_CAPTION := "bars: change a season · line: treasury"
const CHART_MIN := Vector2(360.0, 200.0)
const EARNS := "Earns most"
const COSTS := "Costs most"
const SIGN_GAIN := 1
const SIGN_COST := -1
const ACTION_TAX := &"set_tax"
const ACTION_LOOK := &"look_at"

## The gains in the treasury's measure (true) or the realm's (false).
var treasury_only: bool = false

var _built: bool = false
var _message: Label = null
var _columns: HBoxContainer = null
var _left: VBoxContainer = null
var _right: VBoxContainer = null
var _extras: VBoxContainer = null
var _chart: InkChart = null
var _tax_seg: Segmented = null
var _tax_hint: Label = null
var _tax_notes: Dictionary = {}


func _ready() -> void:
	_ensure_built()


## Fills the page from `game`; `tag` says why (open, season_ended, ...) and is not used: the page shows the player's country.
func refresh(game: Game, _tag: StringName) -> void:
	_ensure_built()
	if game == null:
		_show_message("", false)
		return
	if not game.has_countries():
		_show_message(NO_TREASURY, false)
		return
	_show_message("", true)
	var s := StudyEconomy.this_season(game, game.player)
	var has := bool(s["has_season"])
	_fill_left(s, has)
	_right.visible = has
	if has:
		_update_chart(s["chart"] as Dictionary)
	_fill_extras(s, has)


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
	_columns = HBoxContainer.new()
	_columns.name = &"Columns"
	_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_columns)
	_left = _column(&"Left")
	_right = _column(&"Right")
	_build_chart_inset()
	_extras = VBoxContainer.new()
	_extras.name = &"Extras"
	_extras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_child(_extras)


func _column(column_name: StringName) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = column_name
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_columns.add_child(box)
	return box


func _build_chart_inset() -> void:
	var inset := PanelContainer.new()
	inset.name = &"ChartInset"
	inset.theme_type_variation = &"PanelVellumInset"
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_child(inset)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(box)
	box.add_child(PanelKit.label(CHART_TITLE, &"LabelInkHead"))
	_chart = InkChart.new()
	_chart.name = &"Chart"
	_chart.kind = InkChart.Kind.LINE_BARS
	_chart.ground = InkChart.Ground.VELLUM
	_chart.caption = CHART_CAPTION
	_chart.custom_minimum_size = CHART_MIN
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_chart)


func _show_message(text: String, show_columns: bool) -> void:
	_message.text = text
	_message.accessibility_name = text
	_message.visible = text != ""
	_columns.visible = show_columns


# ----- the left column: the ledger, Expected and Tax -----------------------------------------------------------------


func _fill_left(s: Dictionary, has: bool) -> void:
	PanelKit.clear_children(_left)
	if has:
		_add_ledger(HEAD_IN, s["money_in"] as Dictionary)
		_add_ledger(HEAD_OUT, s["money_out"] as Dictionary)
		_left.add_child(_plain_row(LEFT_OVER, int(s["left_over"])))
		_add_ledger(SPENDING, s["spending"] as Dictionary)
		_left.add_child(_plain_row(TREASURY_ROW, int(s["change"])))
	else:
		_left.add_child(PanelKit.label(NO_SEASON, &"Hint"))
	_add_expected(s["expected"] as Dictionary)
	_add_tax(s["tax"] as Dictionary)


func _add_ledger(head: String, group: Dictionary) -> void:
	_left.add_child(_head_row(head, int(group["total"])))
	var lines: Array = group["lines"]
	if lines.is_empty():
		_left.add_child(PanelKit.label(NO_LINES, &"Hint"))
	for entry: Dictionary in lines:
		_left.add_child(_line_row(entry, SIGN_GAIN))


func _add_expected(expected: Dictionary) -> void:
	var value := _measure(int(expected["net"]), int(expected["realm"]))
	var row := _plain_row(EXPECTED, value)
	var label := row.get_child(0) as Label
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.tooltip_text = _expected_tip(expected["lines"] as Array)
	label.accessibility_name = "%s: %s" % [EXPECTED, label.tooltip_text.replace("\n", ", ")]
	_left.add_child(row)


func _add_tax(tax: Dictionary) -> void:
	var level := int(tax["level"])
	var row := HBoxContainer.new()
	row.name = &"TaxRow"
	row.add_child(PanelKit.label(TAX_LABEL, &"Hint"))
	_tax_seg = Segmented.new()
	_tax_seg.name = &"TaxLevels"
	_tax_seg.accessibility_name = "Tax level"
	_tax_seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tax_notes = {}
	var items: Array = []
	for opt: Dictionary in tax["options"]:
		var id := int(opt["level"])
		var note := _tax_note(opt, level)
		_tax_notes[id] = note
		items.append({"id": id, "label": str(opt["label"]), "tooltip": note})
	_tax_seg.set_options(items)
	_tax_seg.select(level)
	_tax_seg.changed.connect(_on_tax_changed)
	row.add_child(_tax_seg)
	_left.add_child(row)
	_tax_hint = PanelKit.label(str(_tax_notes.get(level, "")), &"Hint")
	_tax_hint.name = &"TaxHint"
	_left.add_child(_tax_hint)
	for item: Dictionary in items:
		_connect_tax_hover(int(item["id"]), level)


func _connect_tax_hover(id: int, current: int) -> void:
	var btn := _tax_seg.button_for(id)
	if btn == null:
		return
	btn.mouse_entered.connect(_show_tax_note.bind(id))
	btn.focus_entered.connect(_show_tax_note.bind(id))
	btn.mouse_exited.connect(_show_tax_note.bind(current))
	btn.focus_exited.connect(_show_tax_note.bind(current))


## "Normal: as now" for the level in force, else "High: +38 ducats a season" (the measure the switch picks).
func _tax_note(opt: Dictionary, level: int) -> String:
	var label := str(opt["label"])
	if int(opt["level"]) == level:
		return "%s: as now" % label
	var amount := _measure(int(opt["change"]), int(opt["realm_change"]))
	return "%s: %s a season" % [label, Words.signed_ducats(amount)]


func _show_tax_note(id: int) -> void:
	if _tax_hint != null:
		_tax_hint.text = str(_tax_notes.get(id, ""))
		_tax_hint.accessibility_name = _tax_hint.text


func _on_tax_changed(id: Variant) -> void:
	request([ACTION_TAX, int(id)])


# ----- the right column: the chart, Earns most and Costs most --------------------------------------------------------


func _update_chart(chart: Dictionary) -> void:
	var labels: Array[String] = chart["labels"]
	_chart.x_labels = PackedStringArray(labels)
	_chart.set_series([
		{"name": "Treasury", "values": chart["treasury"], "ink": 0},
		{"name": "Change", "values": chart["change"], "role": "bar"},
	])
	_chart.set_marks(chart["marks"] as Array)


func _fill_extras(s: Dictionary, has: bool) -> void:
	PanelKit.clear_children(_extras)
	if not has:
		return
	var row := HBoxContainer.new()
	row.add_child(_list_column(EARNS, s["earns_most"] as Array, SIGN_GAIN))
	row.add_child(_list_column(COSTS, s["costs_most"] as Array, SIGN_COST))
	_extras.add_child(row)


func _list_column(head: String, entries: Array, sign: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(PanelKit.label(head, &"SectionHead"))
	if entries.is_empty():
		box.add_child(PanelKit.label(NO_LINES, &"Hint"))
	for entry: Dictionary in entries:
		box.add_child(_line_row(entry, sign))
	return box


# ----- rows ----------------------------------------------------------------------------------------------------------


## A section head ("Money in") with its total, and a rule under it.
func _head_row(head: String, total: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	var title := PanelKit.label(head, &"SectionHead")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_chip(total))
	box.add_child(row)
	box.add_child(HSeparator.new())
	return box


## A plain label and its signed chip, one row.
func _plain_row(text: String, amount: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := PanelKit.label(text, &"Body")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_chip(amount))
	return row


## A ledger or list line: a link button when the line has a hex (it asks look_at), else a label; its chip.
func _line_row(entry: Dictionary, sign: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text := str(entry.get("label", ""))
	var hex: Vector2i = entry.get("hex", NO_HEX)
	if hex != NO_HEX:
		row.add_child(_link(text, hex))
	else:
		var label := PanelKit.label(text, &"Body")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
	row.add_child(_chip(int(entry.get("amount", 0)) * sign))
	return row


func _link(text: String, hex: Vector2i) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.theme_type_variation = &"ButtonNav"
	btn.accessibility_name = "Look at %s" % text
	btn.pressed.connect(_look.bind(hex))
	return btn


func _chip(amount: int) -> DeltaChip:
	var chip := DeltaChip.new()
	chip.set_delta(amount)
	return chip


func _look(hex: Vector2i) -> void:
	request([ACTION_LOOK, hex])


# ----- helpers -------------------------------------------------------------------------------------------------------


func _measure(net: int, realm: int) -> int:
	return net if treasury_only else realm


## "Taxes on people +65" lines, one per ledger line of the season in play.
func _expected_tip(lines: Array) -> String:
	var parts: PackedStringArray = []
	for entry: Dictionary in lines:
		parts.append("%s %s" % [str(entry.get("label", "")), Words.signed(int(entry.get("amount", 0)))])
	return "\n".join(parts)
