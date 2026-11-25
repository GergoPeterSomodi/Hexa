## The works rows of the Build tab (spec R17), moved out of hex_panel.gd in TW2 with their words, order and signal
## names unchanged. This script is the Actions box of the hex panel (the ActionsBox node): a heading, then one row per
## ImprovePreview.options_of option: a KitButton with its cost text, an (i) button for the works card, up to three
## DeltaChips and the reason under a refused row. A click follows game/confirm_works.
## The panel gives the rows: ask (the App's works requests, see HexPanel: true when a listener took the request, false
## when none listens and the row acts itself, the M3 path), retired (the panel's freed-later nodes), settings and the hex.
##   &"works_card"  {hex, option}   the (i) button, and a click under the "always" rule (or "expensive" for an expensive row)
##   &"begin_work"  {hex, option}   a click that begins the work
## row_hovered(hex, option) and row_unhovered tell the panel which row the pointer or the keyboard is on.
class_name BuildRows
extends VBoxContainer

## The pointer or the keyboard is on a row: the panel shows the row's card and ghost. option is {action, family}.
signal row_hovered(hex: Vector2i, option: Dictionary)
signal row_unhovered

const MAX_CHIPS := 3

## Asks the App for a works request: ask.call(what: StringName, args: Dictionary) -> bool (true: a listener took it).
var ask: Callable = Callable()
## The panel's retired-node list (PanelKit.clear_children frees the nodes later); shared with the panel, not copied.
var retired: Array[Node] = []
## The App's settings (game/confirm_works is read on each click); null reads the shipped default.
var settings: Settings = null

var _hex := HexPanelContract.NO_HEX

@onready var _heading: Label = $Heading
@onready var _rows: VBoxContainer = $Actions


## The hex the rows are for (the panel sets it with its shown hex).
func set_hex(hex: Vector2i) -> void:
	_hex = hex


## The box the row buttons sit in (the panel collects its buttons for the tests and the keyboard path).
func rows() -> VBoxContainer:
	return _rows


func clear_rows() -> void:
	PanelKit.clear_children(_rows, retired)


## Writes the heading and the rows of the hex. The panel clears the box and shows it first.
func write(game: Game, piece: Dictionary) -> void:
	_heading.text = "Build here" if piece.is_empty() else "Actions"
	var options := ImprovePreview.options_of(game, Session.player_tag(), _hex)
	if options.is_empty():
		_rows.add_child(PanelKit.reason("Nothing can be built on this ground."))
		return
	for row: Dictionary in options:
		_add_row(game, row)


## The click of a menu item on a row (the hex menu): the same rule as the row's button, game/confirm_works included.
func begin_option(option: Dictionary, expensive: bool) -> void:
	_on_row_pressed(option, expensive)


## One row: the KitButton (label, cost text, disabled with its reason when refused), an (i) button for the card, the
## row's chips (up to three), and the reason line under a refused row.
func _add_row(game: Game, row: Dictionary) -> void:
	var verdict: Dictionary = row["verdict"]
	var ok := bool(verdict["ok"])
	var option := {"action": row["action"], "family": row["family"]}
	var words := ImprovePreview.reason_words(game, _hex, option, verdict)
	var kind: KitButton.Kind = KitButton.Kind.DANGER if row["action"] == Works.CLEAR else KitButton.Kind.SECONDARY
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(box)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	var button := new_button(str(row["label"]), kind)
	if row["action"] == Works.UPGRADE:
		button.hotkey_action = &"game_upgrade"
	line.add_child(button)
	button.cost_text = str(row["cost_text"])
	# The cost sits on its own line under the button, never over its label (the button keeps it for its description).
	var overlay := button.get_node_or_null("CostLabel") as Label
	if overlay != null:
		overlay.visible = false
	button.set_verdict({"ok": ok, "reason": words})
	if ok:
		button.pressed.connect(_on_row_pressed.bind(option, bool(row["expensive"])))
	button.mouse_entered.connect(_on_row_entered.bind(option))
	button.focus_entered.connect(_on_row_entered.bind(option))
	button.mouse_exited.connect(_on_row_left)
	button.focus_exited.connect(_on_row_left)
	line.add_child(_info_button(str(row["label"]), option))
	if not button.cost_text.is_empty():
		var cost := PanelKit.label(button.cost_text, &"Hint")
		cost.name = &"RowCost"
		cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(cost)
	_add_chips(box, row["chips"])
	if not ok and words != "":
		box.add_child(PanelKit.reason(words))


## Up to MAX_CHIPS DeltaChips: each shows its chip's text as the chip's label, sign and unit (the good's name and "a
## year", or a town's people).
func _add_chips(box: VBoxContainer, chips: Array) -> void:
	if chips.is_empty():
		return
	var strip := HBoxContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(strip)
	for at: int in mini(chips.size(), MAX_CHIPS):
		var chip: Dictionary = chips[at]
		var delta := DeltaChip.new()
		delta.boxed = true
		delta.set_delta(int(chip["amount"]), _chip_unit(chip), _chip_label(chip))
		strip.add_child(delta)


static func _chip_label(chip: Dictionary) -> String:
	var kind := StringName(str(chip["kind"]))
	if kind == &"people":
		return "people"
	if kind == &"good":
		return str(chip["text"]).get_slice(" ", 0)
	return ""


static func _chip_unit(chip: Dictionary) -> String:
	return "a year" if str(chip["text"]).ends_with("a year") else ""


## The (i) button of a row: opens the works card for it.
func _info_button(label_text: String, option: Dictionary) -> Button:
	var info := Button.new()
	info.focus_mode = Control.FOCUS_ALL
	info.tooltip_text = "Show the card"
	info.accessibility_name = "Show the card: %s" % label_text
	if has_theme_icon(&"info", &"Kit"):
		info.icon = get_theme_icon(&"info", &"Kit")
	else:
		info.text = "i"
	info.pressed.connect(_on_info_pressed.bind(option))
	return info


func _on_info_pressed(option: Dictionary) -> void:
	ask.call(&"works_card", {"hex": _hex, "option": option})


func _on_row_entered(option: Dictionary) -> void:
	row_hovered.emit(_hex, option)


func _on_row_left() -> void:
	row_unhovered.emit()


## A click on an enabled row, by game/confirm_works: "off" asks for the work at once; "expensive" asks for the card of an
## expensive row only, and the work of the others; "always" asks for the card.
func _on_row_pressed(option: Dictionary, expensive: bool) -> void:
	if click_of(confirm_mode_of(settings), expensive) == &"card":
		ask.call(&"works_card", {"hex": _hex, "option": option})
		return
	_begin(option)


## The click rule of a works row (the M4 rule, spec R19): &"card" opens the works card, &"begin" begins the work. "off"
## always begins; "expensive" asks for the card of an expensive row only; "always" asks for the card. Shared with the
## Buildings tab, whose hammers keep this rule.
static func click_of(mode: String, expensive: bool) -> StringName:
	var want_card := mode == "always" or (mode == "expensive" and expensive)
	return &"card" if want_card else &"begin"


## The game/confirm_works mode of a settings object; null reads the shipped default ("expensive").
static func confirm_mode_of(p_settings: Settings) -> String:
	if p_settings == null:
		return "expensive"
	return str(p_settings.get_value("game/confirm_works"))


## Begins the row's work: the App begins it on begin_work; with no listener the row does it (the M3 path).
func _begin(option: Dictionary) -> void:
	if bool(ask.call(&"begin_work", {"hex": _hex, "option": option})):
		return
	var action := str(option["action"])
	var args := {"hex": _hex}
	if action == String(Works.BUILD):
		args["family"] = int(option["family"])
	Session.act(action, args)


static func new_button(label_text: String, kind: KitButton.Kind) -> KitButton:
	var button := KitButton.new()
	button.kind = kind
	button.text = label_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button
