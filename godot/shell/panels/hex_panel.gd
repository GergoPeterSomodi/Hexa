## Studiolo inspected-hex side panel (docs/architecture/m1-build-spec.md section 11, T14;
## docs/architecture/ui-style-and-feedback-plan.md H1; the contract is HexPanelContract).
## Framed in PanelContainer at width Tokens.PANEL_W with a Cartouche title, SectionHead ledgers driven
## by HexCard word tables, and KitButton actions. M3 (spec 6.8): a "Work under way" section with
## Cancel the work, and "N seasons" on the build, upgrade and clear buttons.
## M4 (spec 6.4): the rows come from ImprovePreview.options_of (a KitButton with its cost text, an (i) button, up to
## three DeltaChips from the row's chips, the reason when refused). A row click follows game/confirm_works. Gives and
## Worth are read here. The panel asks the App through works_requested(what, args), as app_requested does:
##   &"works_card"  {hex, option}                 open the works card for the row
##   &"begin_work"  {hex, option}                 begin the work of the row
##   &"cancel_work" {hex, tag, refund, refund_goods}  cancel the work under way (refund: what it gives back)
## A request nobody listens to is acted on here instead for begin_work and cancel_work (the M3 behaviour); a card
## request with no listener does nothing, so no work is begun by a click that asked for the card.
class_name HexPanel
extends HexPanelContract

## The Owner row's link was pressed: the owner's tag (the dock shows that country).
signal country_requested(tag: StringName)
## A request for the App (see the class comment): what, and its arguments.
signal works_requested(what: StringName, args: Dictionary)
## The pointer or the keyboard is on a row: the App shows the row's card and ghost. option is {action, family}.
signal row_hovered(hex: Vector2i, option: Dictionary)
signal row_unhovered

const MAX_CHIPS := 3

@onready var _cartouche: Cartouche = $Body/Cartouche
@onready var _subtitle: Label = $Body/Subtitle
@onready var _piece_box: VBoxContainer = $Body/PieceBox
@onready var _piece_rows: GridContainer = $Body/PieceBox/Rows
@onready var _ground_box: VBoxContainer = $Body/GroundBox
@onready var _ground_rows: GridContainer = $Body/GroundBox/Rows
@onready var _owner_row: HBoxContainer = $Body/OwnerRow
@onready var _owner_value: HBoxContainer = $Body/OwnerRow/Value
@onready var _gives_row: HBoxContainer = $Body/GivesRow
@onready var _gives_value: Label = $Body/GivesRow/Value
@onready var _worth_row: HBoxContainer = $Body/WorthRow
@onready var _worth_value: HBoxContainer = $Body/WorthRow/Value
@onready var _rule: HSeparator = $Body/Rule
@onready var _home_box: VBoxContainer = $Body/HomeReason
@onready var _work_box: VBoxContainer = $Body/WorkBox
@onready var _work_text: Label = $Body/WorkBox/Text
@onready var _work_progress: Label = $Body/WorkBox/Progress
@onready var _work_actions: VBoxContainer = $Body/WorkBox/Actions
@onready var _actions_box: VBoxContainer = $Body/ActionsBox
@onready var _actions_heading: Label = $Body/ActionsBox/Heading
@onready var _actions: VBoxContainer = $Body/ActionsBox/Actions

## The App's settings (game/confirm_works is read from them on each refresh); null reads the shipped default.
var settings: Settings = null

var _hex := NO_HEX
var _retired: Array[Node] = []
var _refresh_queued := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = float(Tokens.PANEL_W)
	visible = false
	for pair: Array in _wiring():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		sig.connect(handler)


func _exit_tree() -> void:
	for pair: Array in _wiring():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)
	PanelKit.free_retired(_retired)


## The signals that change what the panel shows; each one reads the game again through refresh().
func _wiring() -> Array:
	return [
		[Events.hex_changed, _on_hex_changed],
		[Events.owners_changed, _on_owners_changed],
		[Events.country_chosen, _on_country_chosen],
		[Events.work_started, _on_work_changed],
		[Events.work_finished, _on_work_changed],
		[Events.work_cancelled, _on_work_cancelled],
		[Events.season_ended, _on_season_ended],
	]


func show_hex(hex: Vector2i) -> void:
	_hex = hex
	refresh()


func clear() -> void:
	_hex = NO_HEX
	visible = false


func shown_hex() -> Vector2i:
	return _hex


## Gives the panel the App's settings, read for game/confirm_works on each refresh.
func set_settings(p_settings: Settings) -> void:
	settings = p_settings


## Returns the KitButtons of the work and action rows in display order: Cancel the work first, then the rows
## (Build, or Upgrade and Clear). The (i) buttons are plain Buttons and are not listed.
func action_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for box: VBoxContainer in [_work_actions, _actions]:
		if box != null:
			_collect_kit_buttons(box, out)
	return out


static func _collect_kit_buttons(node: Node, out: Array[Button]) -> void:
	for child: Node in node.get_children():
		if child is KitButton:
			out.append(child as Button)
		else:
			_collect_kit_buttons(child, out)


## Returns the Cartouche header node.
func cartouche() -> Cartouche:
	return _cartouche


## Returns the subtitle Label.
func subtitle_label() -> Label:
	return _subtitle


func refresh() -> void:
	var game := Session.game
	if _hex == NO_HEX or game == null or not game.map.has(_hex):
		visible = false
		return
	var map := game.map
	var i := map.index_of(_hex)
	if map.land[i] == 0:
		_show_sea()
		return
	var piece := Improve.piece_at(game, _hex)
	var place := Improve.place_of(map, _hex)
	var ground := HexCard.cover_words(int(map.cover[i]))
	var place_name := str(place.get("name", ""))
	_cartouche.text = place_name if place_name != "" else ground.capitalize()
	_subtitle.text = "Hex %d, %d" % [_hex.x, _hex.y]
	_refresh_piece(piece)
	_refresh_ground(map)
	_refresh_owner(game)
	_refresh_gives(game)
	_refresh_worth(game)
	_rule.visible = true
	var home := Territory.at_home_check(game, Session.player_tag(), _hex)
	_refresh_home(home)
	_refresh_work(game)
	if bool(home["ok"]):
		_write_actions(game, piece)
	else:
		PanelKit.clear_children(_actions, _retired)
		_actions_box.visible = false
	visible = true


## A sea hex: the cartouche says so and no row of the panel shows.
func _show_sea() -> void:
	_cartouche.text = "Sea"
	_subtitle.text = "Hex %d, %d, open sea" % [_hex.x, _hex.y]
	_piece_box.visible = false
	_ground_box.visible = false
	_owner_row.visible = false
	_gives_row.visible = false
	_worth_row.visible = false
	_rule.visible = false
	_home_box.visible = false
	_work_box.visible = false
	_actions_box.visible = false
	PanelKit.clear_children(_work_actions, _retired)
	PanelKit.clear_children(_actions, _retired)
	visible = true


## The Owner row: the owner's long name as a link to its country, "no one" for unowned land; hidden where
## HexCard.owner_of gives nothing (a map-only game).
func _refresh_owner(game: Game) -> void:
	var owner_text := HexCard.owner_of(game, _hex)
	PanelKit.clear_children(_owner_value, _retired)
	_owner_row.visible = owner_text != ""
	if owner_text == "":
		return
	var otag := Territory.owner_tag(game, _hex)
	if otag == &"":
		_owner_value.add_child(PanelKit.label(owner_text, &"TableRow"))
		return
	var link := KitButton.new()
	link.kind = KitButton.Kind.SMALL
	link.text = owner_text
	link.tooltip_text = "Show this country"
	link.focus_mode = Control.FOCUS_ALL
	link.pressed.connect(func() -> void: country_requested.emit(otag))
	_owner_value.add_child(link)


## The Gives row (spec 6.4): what the hex gives, from the hex card's Gives line; hidden where it gives nothing.
func _refresh_gives(game: Game) -> void:
	var gives := str(HexCard.of(game, _hex).get("gives", ""))
	_gives_row.visible = gives != ""
	_gives_value.text = gives


## The Worth row (spec 6.4): this season's worth of the hex to the player's country (EconomyPreview.worth_of), as a
## DeltaChip; hidden for a hex the country does not hold, and in a game with no countries.
func _refresh_worth(game: Game) -> void:
	PanelKit.clear_children(_worth_value, _retired)
	_worth_row.visible = false
	var tag := Session.player_tag()
	if tag == &"" or not game.has_countries():
		return
	var row := EconomyPreview.worth_of(game, tag, _hex)  # one hex only: worth_by_hex builds the whole country (0.4 s on the largest)
	if row.is_empty():
		return
	var chip := DeltaChip.new()
	chip.set_delta(int(row["worth"]))
	_worth_value.add_child(chip)
	_worth_row.visible = true


## The home rule: the works section is shown only on the player's land; elsewhere one reason line says why.
func _refresh_home(home: Dictionary) -> void:
	PanelKit.clear_children(_home_box, _retired)
	var blocked := not bool(home["ok"])
	_home_box.visible = blocked
	if blocked:
		_home_box.add_child(PanelKit.reason(str(home["reason"])))


## The Work section (spec 6.8): the work under way on the hex, its progress and ready season ("stopped for the
## winter" while halted), and Cancel the work for the player's own work only; another country's work has no button.
func _refresh_work(game: Game) -> void:
	PanelKit.clear_children(_work_actions, _retired)
	var at := WorksView.at(game, _hex)
	_work_box.visible = not at.is_empty()
	if at.is_empty():
		return
	_work_text.text = str(at["label"])
	var when := "stopped for the winter" if bool(at["halted"]) else str(at["progress"])
	_work_progress.text = "%s, ready %s" % [when, str(at["ready"])]
	var tag: StringName = at["tag"]
	var work := game.state.work_at(_hex)
	if tag != Session.player_tag() or work == null:
		return
	var verdict := Session.check("cancel_work", {"hex": _hex, "tag": tag})
	var args := {"hex": _hex, "tag": tag, "refund": Works.refund(game, work), "refund_goods": Works.refund_goods(game, work)}
	var button := _new_button("Cancel the work", KitButton.Kind.SECONDARY)
	_work_actions.add_child(button)
	button.set_verdict(verdict)
	if bool(verdict["ok"]):
		button.pressed.connect(_on_cancel_pressed.bind(args))


func _on_hex_changed(_changed: Vector2i) -> void:
	_request_refresh()


func _on_owners_changed(_hexes: Array[Vector2i]) -> void:
	_request_refresh()


func _on_country_chosen(_tag: StringName) -> void:
	_request_refresh()


func _on_work_changed(_tag: StringName, _work_hex: Vector2i, _work: Dictionary) -> void:
	_request_refresh()


func _on_work_cancelled(_tag: StringName, _work_hex: Vector2i, _work: Dictionary, _why: StringName) -> void:
	_request_refresh()


func _on_season_ended(_turn: int) -> void:
	_request_refresh()


## Signals arrive in bursts (a season's works, the AI's dozens of changes): one refresh runs at the end of the frame
## however many signals came in before it.
func _request_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_flush_refresh")


func _flush_refresh() -> void:
	if not _refresh_queued:
		return
	_refresh_queued = false
	refresh()


func _refresh_piece(piece: Dictionary) -> void:
	_piece_box.visible = true
	PanelKit.fill_rows(_piece_rows, _pairs_of(HexCard.piece_rows(piece)), _retired)


func _refresh_ground(map: MapData) -> void:
	_ground_box.visible = true
	PanelKit.fill_rows(_ground_rows, _pairs_of(HexCard.ground_rows(map, _hex)), _retired)


## The rows of the hex (spec 6.4): ImprovePreview.options_of gives the build list on wild land, or Upgrade and Clear on
## a piece. A work under way on the hex hides the rows (the work section shows it).
func _write_actions(game: Game, piece: Dictionary) -> void:
	PanelKit.clear_children(_actions, _retired)
	_actions_box.visible = game.state.work_at(_hex) == null
	if not _actions_box.visible:
		return
	_actions_heading.text = "Build here" if piece.is_empty() else "Actions"
	var rows := ImprovePreview.options_of(game, Session.player_tag(), _hex)
	if rows.is_empty():
		_actions.add_child(PanelKit.reason("Nothing can be built on this ground."))
		return
	for row: Dictionary in rows:
		_add_row(game, row)


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
	_actions.add_child(box)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	var button := _new_button(str(row["label"]), kind)
	if row["action"] == Works.UPGRADE:
		button.hotkey_action = &"game_upgrade"
	line.add_child(button)
	button.cost_text = str(row["cost_text"])
	button.set_verdict({"ok": ok, "reason": words})
	if ok:
		button.pressed.connect(_on_row_pressed.bind(option, bool(row["expensive"])))
	button.mouse_entered.connect(_on_row_entered.bind(option))
	button.focus_entered.connect(_on_row_entered.bind(option))
	button.mouse_exited.connect(_on_row_left)
	button.focus_exited.connect(_on_row_left)
	line.add_child(_info_button(str(row["label"]), option))
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
	if _has_listener():
		works_requested.emit(&"works_card", {"hex": _hex, "option": option})


func _on_row_entered(option: Dictionary) -> void:
	row_hovered.emit(_hex, option)


func _on_row_left() -> void:
	row_unhovered.emit()


## A click on an enabled row, by game/confirm_works: "off" asks for the work at once; "expensive" asks for the card of an
## expensive row only, and the work of the others; "always" asks for the card.
func _on_row_pressed(option: Dictionary, expensive: bool) -> void:
	var mode := _confirm_mode()
	var want_card := mode == "always" or (mode == "expensive" and expensive)
	if want_card:
		if _has_listener():
			works_requested.emit(&"works_card", {"hex": _hex, "option": option})
		return
	_begin(option)


## Begins the row's work: the App begins it on begin_work; with no listener the panel does it (the M3 path).
func _begin(option: Dictionary) -> void:
	if _has_listener():
		works_requested.emit(&"begin_work", {"hex": _hex, "option": option})
		return
	var action := str(option["action"])
	var args := {"hex": _hex}
	if action == String(Works.BUILD):
		args["family"] = int(option["family"])
	Session.act(action, args)


## Cancel the work: the App cancels it and names the refund on cancel_work; with no listener the panel cancels it.
func _on_cancel_pressed(args: Dictionary) -> void:
	if _has_listener():
		works_requested.emit(&"cancel_work", args)
		return
	Session.act("cancel_work", {"hex": args["hex"], "tag": args["tag"]})


func _has_listener() -> bool:
	return works_requested.get_connections().size() > 0


func _confirm_mode() -> String:
	if settings == null:
		return "expensive"
	return str(settings.get_value("game/confirm_works"))


func _new_button(label_text: String, kind: KitButton.Kind) -> KitButton:
	var button := KitButton.new()
	button.kind = kind
	button.text = label_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


static func _pairs_of(rows: Array[Array]) -> Array[String]:
	var pairs: Array[String] = []
	for row: Array in rows:
		if row.size() >= 2:
			pairs.append(str(row[0]))
			pairs.append(str(row[1]))
	return pairs
