## Studiolo inspected-hex side panel (docs/architecture/m1-build-spec.md section 11, T14;
## docs/architecture/ui-style-and-feedback-plan.md H1; the contract is HexPanelContract).
## Framed in PanelContainer at width Tokens.PANEL_W with a Cartouche title, SectionHead ledgers driven
## by HexCard word tables, and KitButton actions using set_verdict. M3 (spec 6.8): a "Work under way" section with
## Cancel the work, and "N seasons" on the build, upgrade and clear buttons.
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
@onready var _work_box: VBoxContainer = $Body/WorkBox
@onready var _work_text: Label = $Body/WorkBox/Text
@onready var _work_progress: Label = $Body/WorkBox/Progress
@onready var _work_actions: VBoxContainer = $Body/WorkBox/Actions
@onready var _actions_box: VBoxContainer = $Body/ActionsBox
@onready var _actions_heading: Label = $Body/ActionsBox/Heading
@onready var _actions: VBoxContainer = $Body/ActionsBox/Actions

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


## Returns the work and action KitButtons in display order: Cancel the work first, then the actions.
func action_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for box: VBoxContainer in [_work_actions, _actions]:
		if box == null:
			continue
		for child: Node in box.get_children():
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
		_work_box.visible = false
		_actions_box.visible = false
		PanelKit.clear_children(_work_actions, _retired)
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
	_refresh_work(game)
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
	if tag != Session.player_tag():
		return
	var args := {"hex": _hex, "tag": tag}
	_add_action(_work_actions, "Cancel the work", Session.check("cancel_work", args), "cancel_work", args,
		KitButton.Kind.SECONDARY)


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


## The build list on wild land, or Upgrade and Clear on a piece. Each verdict is Session.check of the action, so a
## full slot or a work under way gives its reason; each build, upgrade and clear says its seasons.
func _write_actions(piece: Dictionary) -> void:
	PanelKit.clear_children(_actions, _retired)
	_actions_box.visible = true
	var game := Session.game
	if piece.is_empty():
		_actions_heading.text = "Build here"
		var options := Improve.build_options(game, _hex)
		if options.is_empty():
			_actions.add_child(PanelKit.reason("Nothing can be built on this ground."))
			return
		for option: Dictionary in options:
			var option_family := int(option["family_id"])
			var btn_text := "Build " + HexCard.family_word(str(option["family"]), "-")
			var args := {"hex": _hex, "family": option_family}
			var cost := Words.seasons(WorksView.seasons_of(game, Works.BUILD, _hex, option_family))
			_add_action(_actions, btn_text, Session.check("build", args), "build", args, KitButton.Kind.SECONDARY, cost)
		return
	_actions_heading.text = "Actions"
	var piece_family := int(piece["family_id"])
	var family_name := str(piece["family"])
	var level := int(piece["level"])
	var up := Session.check("upgrade", {"hex": _hex})
	var up_text := "Upgrade"
	if level < HexCard.top_level(family_name):
		up_text = "Upgrade to %s" % HexCard.level_name(family_name, level + 1)
	var up_cost := Words.seasons(WorksView.seasons_of(game, Works.UPGRADE, _hex, piece_family))
	_add_action(_actions, up_text, up, "upgrade", {"hex": _hex}, KitButton.Kind.SECONDARY, up_cost, &"game_upgrade")
	var down := Session.check("clear", {"hex": _hex})
	var down_cost := Words.seasons(WorksView.seasons_of(game, Works.CLEAR, _hex, piece_family))
	_add_action(_actions, "Clear", down, "clear", {"hex": _hex}, KitButton.Kind.DANGER, down_cost)


## One action button in `box`: enabled when the verdict is ok (it does the action through Session.act), else disabled
## with its reason under it. `cost` is the seasons text shown on the right of an enabled button (none when refused).
func _add_action(
	box: VBoxContainer,
	label_text: String,
	verdict: Dictionary,
	action_name: String,
	args: Dictionary,
	btn_kind: KitButton.Kind,
	cost: String = "",
	hotkey: StringName = &""
) -> void:
	var ok := bool(verdict["ok"])
	var reason_msg := str(verdict["reason"])
	var button := KitButton.new()
	button.kind = btn_kind
	button.text = label_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if hotkey != &"":
		button.hotkey_action = hotkey
	box.add_child(button)
	button.cost_text = cost if ok else ""
	button.set_verdict({"ok": ok, "reason": reason_msg})
	if ok:
		button.pressed.connect(func() -> void: Session.act(action_name, args))
	elif reason_msg != "":
		box.add_child(PanelKit.reason(reason_msg))


static func _pairs_of(rows: Array[Array]) -> Array[String]:
	var pairs: Array[String] = []
	for row: Array in rows:
		if row.size() >= 2:
			pairs.append(str(row[0]))
			pairs.append(str(row[1]))
	return pairs
