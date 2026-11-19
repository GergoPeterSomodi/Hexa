## Studiolo inspected-hex side panel (docs/architecture/m1-build-spec.md section 11, T14;
## docs/architecture/ui-style-and-feedback-plan.md H1; the contract is HexPanelContract).
## Framed in PanelContainer at width Tokens.PANEL_W with a Cartouche title, SectionHead ledgers driven
## by HexCard word tables, and KitButton actions using set_verdict.
class_name HexPanel
extends HexPanelContract

## The Owner row's link was pressed: the owner's tag (the dock shows that country).
signal country_requested(tag: StringName)

@onready var _cartouche: Cartouche = $Body/Cartouche
@onready var _subtitle: Label = $Body/Subtitle
@onready var _piece_box: VBoxContainer = $Body/PieceBox
@onready var _piece_rows: GridContainer = $Body/PieceBox/Rows
@onready var _ground_box: VBoxContainer = $Body/GroundBox
@onready var _ground_rows: GridContainer = $Body/GroundBox/Rows
@onready var _owner_row: HBoxContainer = $Body/OwnerRow
@onready var _owner_value: HBoxContainer = $Body/OwnerRow/Value
@onready var _rule: HSeparator = $Body/Rule
@onready var _home_box: VBoxContainer = $Body/HomeReason
@onready var _actions_box: VBoxContainer = $Body/ActionsBox
@onready var _actions_heading: Label = $Body/ActionsBox/Heading
@onready var _actions: VBoxContainer = $Body/ActionsBox/Actions

var _hex := NO_HEX
var _retired: Array[Node] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = float(Tokens.PANEL_W)
	visible = false
	Events.owners_changed.connect(_on_owners_changed)
	Events.country_chosen.connect(_on_country_chosen)


func _exit_tree() -> void:
	if Events.owners_changed.is_connected(_on_owners_changed):
		Events.owners_changed.disconnect(_on_owners_changed)
	if Events.country_chosen.is_connected(_on_country_chosen):
		Events.country_chosen.disconnect(_on_country_chosen)
	PanelKit.free_retired(_retired)


func show_hex(hex: Vector2i) -> void:
	_hex = hex
	refresh()


func clear() -> void:
	_hex = NO_HEX
	visible = false


func shown_hex() -> Vector2i:
	return _hex


## Returns the action KitButtons in display order.
func action_buttons() -> Array[Button]:
	var out: Array[Button] = []
	if _actions == null:
		return out
	for child: Node in _actions.get_children():
		if child is Button:
			out.append(child as Button)
	return out


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
		_cartouche.text = "Sea"
		_subtitle.text = "Hex %d, %d, open sea" % [_hex.x, _hex.y]
		_piece_box.visible = false
		_ground_box.visible = false
		_owner_row.visible = false
		_rule.visible = false
		_home_box.visible = false
		_actions_box.visible = false
		PanelKit.clear_children(_actions, _retired)
		visible = true
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
	_rule.visible = true
	var home := Territory.at_home_check(game, Session.player_tag(), _hex)
	_refresh_home(home)
	if bool(home["ok"]):
		_write_actions(piece)
	else:
		PanelKit.clear_children(_actions, _retired)
		_actions_box.visible = false
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
	link.focus_mode = Control.FOCUS_NONE
	link.pressed.connect(func() -> void: country_requested.emit(otag))
	_owner_value.add_child(link)


## The home rule: the works section is shown only on the player's land; elsewhere one reason line says why.
func _refresh_home(home: Dictionary) -> void:
	PanelKit.clear_children(_home_box, _retired)
	var blocked := not bool(home["ok"])
	_home_box.visible = blocked
	if blocked:
		_home_box.add_child(PanelKit.reason(str(home["reason"])))


func _on_owners_changed(_hexes: Array[Vector2i]) -> void:
	refresh()


func _on_country_chosen(_tag: StringName) -> void:
	refresh()


func _refresh_piece(piece: Dictionary) -> void:
	_piece_box.visible = true
	PanelKit.fill_rows(_piece_rows, _pairs_of(HexCard.piece_rows(piece)), _retired)


func _refresh_ground(map: MapData) -> void:
	_ground_box.visible = true
	PanelKit.fill_rows(_ground_rows, _pairs_of(HexCard.ground_rows(map, _hex)), _retired)


func _write_actions(piece: Dictionary) -> void:
	PanelKit.clear_children(_actions, _retired)
	_actions_box.visible = true
	if piece.is_empty():
		_actions_heading.text = "Build here"
		var options := Improve.build_options(Session.game, _hex)
		if options.is_empty():
			_actions.add_child(PanelKit.reason("Nothing can be built on this ground."))
			return
		for option: Dictionary in options:
			var btn_text := "Build " + HexCard.family_word(str(option["family"]), "-")
			var ok := bool(option["ok"])
			var reason := str(option["reason"])
			_add_action(btn_text, ok, reason, "build", {"hex": _hex, "family": int(option["family_id"])}, KitButton.Kind.SECONDARY)
		return
	_actions_heading.text = "Actions"
	var family_name := str(piece["family"])
	var level := int(piece["level"])
	var up := Session.check("upgrade", {"hex": _hex})
	var up_text := "Upgrade"
	if level < HexCard.top_level(family_name):
		up_text = "Upgrade to %s" % HexCard.level_name(family_name, level + 1)
	_add_action(up_text, bool(up["ok"]), str(up["reason"]), "upgrade", {"hex": _hex}, KitButton.Kind.SECONDARY, &"game_upgrade")
	var down := Session.check("clear", {"hex": _hex})
	_add_action("Clear", bool(down["ok"]), str(down["reason"]), "clear", {"hex": _hex}, KitButton.Kind.DANGER)


func _add_action(
	label_text: String,
	ok: bool,
	reason_msg: String,
	action_name: String,
	args: Dictionary,
	btn_kind: KitButton.Kind,
	hotkey: StringName = &""
) -> void:
	var button := KitButton.new()
	button.kind = btn_kind
	button.text = label_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if hotkey != &"":
		button.hotkey_action = hotkey
	_actions.add_child(button)
	button.set_verdict({"ok": ok, "reason": reason_msg})
	if ok:
		button.pressed.connect(func() -> void: Session.act(action_name, args))
	elif reason_msg != "":
		_actions.add_child(PanelKit.reason(reason_msg))


static func _pairs_of(rows: Array[Array]) -> Array[String]:
	var pairs: Array[String] = []
	for row: Array in rows:
		if row.size() >= 2:
			pairs.append(str(row[0]))
			pairs.append(str(row[1]))
	return pairs
