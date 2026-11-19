## The country pick (docs/architecture/m2-build-spec.md section 7.5): an OVERLAY the App pushes when a game with
## countries starts with no player. The map stays live in Owner mode. The list is the keyboard path: Up and Down move
## (NavList), Enter shows that country (the App shows its panel and glides there) and Enter again on the same row plays
## it. A map click arrives through on_country_clicked. Esc: back() closes the dock's panel when one is open, otherwise
## asks the App for the pause menu; it always returns true, so Esc never pops the pick.
class_name CountryPick
extends Screen

const OUTSIDE_HEAD := "Outside powers"
const TITLE := "Choose your country"

@onready var _top: VBoxContainer = $Top
@onready var _ribbon: Ribbon = $Top/Ribbon
@onready var _left: PanelFrame = $Left

var _list: NavList = null
var _outside_box: VBoxContainer = null
var _rows: Dictionary[StringName, Button] = {}
var _row_order: Array[StringName] = []
var _shown_tag: StringName = &""
var _hover_tag: StringName = &""
var _dock_open: bool = false
var _retired: Array[Node] = []
var _ui_built: bool = false


func _ready() -> void:
	_ensure_ui()


func _exit_tree() -> void:
	_disconnect_chosen()
	PanelKit.free_retired(_retired)


func on_enter() -> void:
	_ensure_ui()
	_send_cover.call_deferred()  # the list and the banner settle a frame late
	_shown_tag = &""
	_dock_open = false
	_hover_tag = &""
	refresh_list()
	_connect_chosen()


func on_exit() -> void:
	_disconnect_chosen()
	if ctx != null:
		ctx.request(&"screen_cover", {"rects": []})


## Esc (ScreenStack and the App): closes the dock's panel when one is open, otherwise asks for the pause menu.
## Returns true in both cases, so the pick is never popped.
func back() -> bool:
	if _dock_open:
		_dock_open = false
		_shown_tag = &""
		if ctx != null:
			ctx.request(&"close_dock")
		return true
	if ctx != null:
		ctx.request(&"pause")
	return true


## Rebuilds the playable rows (largest first, ties by id) and the outside-powers lines from the game.
func refresh_list() -> void:
	_ensure_ui()
	_rows.clear()
	_row_order.clear()
	var playable: Array[Dictionary] = []
	var outside: Array[Dictionary] = []
	for card: Dictionary in _cards():
		if bool(card["playable"]):
			playable.append(card)
		else:
			outside.append(card)
	playable.sort_custom(_bigger_first)
	var items: Array = []
	for card: Dictionary in playable:
		var tag := StringName(str(card["tag"]))
		items.append({"id": tag, "text": str(card["name"]), "count": int(card["districts"])})
		_row_order.append(tag)
	_list.set_items(items)
	for tag: StringName in _row_order:
		var btn := _list.button_for(tag)
		_rows[tag] = btn
		btn.pressed.connect(_on_row_pressed.bind(tag))
	_fill_outside(outside)
	_set_default_focus()
	_paint_hover()


## Shows `tag` in the dock (the App glides there) and makes it the country that Enter acts on.
func show_country(tag: StringName) -> void:
	_ensure_ui()
	_shown_tag = tag
	_dock_open = true
	_list.select(tag)
	if ctx != null:
		ctx.request(&"country", {"tag": tag})


## The App routes MapScene.country_clicked here while picking. &"" (sea or unowned land) does nothing.
func on_country_clicked(tag: StringName) -> void:
	if tag == &"":
		return
	show_country(tag)


## The App routes MapScene.country_hovered here: the row of that country brightens. &"" clears it.
func on_country_hovered(tag: StringName) -> void:
	_hover_tag = tag
	_paint_hover()


## The App calls this when the dock's panel closes by any means (its close button, Esc, another panel).
func dock_closed() -> void:
	_dock_open = false
	_shown_tag = &""


## Chooses `tag` as the player's country. A refusal toasts its reason and changes nothing. A success ends the
## screen through Events.country_chosen.
func play(tag: StringName) -> bool:
	var verdict := Session.act("choose_country", {"tag": tag})
	if not bool(verdict.get("ok", false)):
		if ctx != null:
			ctx.toast(str(verdict.get("reason", "that country cannot be played")), &"bad")
		return false
	return true


func shown_tag() -> StringName:
	return _shown_tag


func dock_open() -> bool:
	return _dock_open


func hover_tag() -> StringName:
	return _hover_tag


func row_tags() -> Array[StringName]:
	return _row_order.duplicate()


func row_button(tag: StringName) -> Button:
	return _rows.get(tag, null) as Button


func outside_lines() -> Array[String]:
	var out: Array[String] = []
	if _outside_box == null:
		return out
	for child: Node in _outside_box.get_children():
		var lbl := child as Label
		if lbl != null and lbl.theme_type_variation == &"Hint":
			out.append(lbl.text)
	return out


## Tells the HUD what the list and the banner cover: country names keep clear, the key hints start right of the list.
func _send_cover() -> void:
	if ctx != null and is_inside_tree() and visible:
		ctx.request(&"screen_cover", {"rects": [Hud.screen_rect(_left), Hud.screen_rect(_top)]})


func _ensure_ui() -> void:
	if _ui_built or _left == null:
		return
	_ui_built = true
	_ribbon.text = TITLE
	_ribbon.custom_minimum_size.x = _ribbon.single_line_width()  # one line: the default width wraps the title
	_top.offset_top = float(Tokens.BAR_H + Tokens.S2)
	_left.custom_minimum_size.x = float(Tokens.PANEL_W)
	_left.offset_left = float(Tokens.S4)
	_left.offset_right = float(Tokens.S4 + Tokens.PANEL_W)
	_left.offset_top = float(Tokens.BAR_H + Tokens.S2)
	_left.offset_bottom = -float(Tokens.S4)
	_left.resized.connect(_send_cover)
	_top.resized.connect(_send_cover)
	_left.cartouche_title = "Countries"
	_left.show_close = false
	var body := _left.body()
	_list = NavList.new()
	_list.name = &"CountryList"
	body.add_child(_list)
	_outside_box = VBoxContainer.new()
	_outside_box.name = &"OutsideBox"
	body.add_child(_outside_box)


func _cards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var game := Session.game
	if game == null or not game.has_countries():
		return out
	for country: Country in game.countries:
		var card := CountryCard.of(game, country.tag)
		if card.is_empty():
			continue
		card["sort_id"] = country.id
		out.append(card)
	return out


static func _bigger_first(a: Dictionary, b: Dictionary) -> bool:
	var da := int(a["districts"])
	var db := int(b["districts"])
	if da != db:
		return da > db
	return int(a["sort_id"]) < int(b["sort_id"])


func _fill_outside(outside: Array[Dictionary]) -> void:
	PanelKit.clear_children(_outside_box, _retired)
	if outside.is_empty():
		return
	_outside_box.add_child(PanelKit.label(OUTSIDE_HEAD, &"SectionHead"))
	for card: Dictionary in outside:
		var line := PanelKit.label(_outside_line(card), &"Hint")
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_outside_box.add_child(line)


func _outside_line(card: Dictionary) -> String:
	var capital: Dictionary = card["capital"]
	if bool(capital["off_map"]):
		return "%s: %s is off this map" % [str(card["name"]), str(capital["name"])]
	return str(card["play_reason"])


func _set_default_focus() -> void:
	if _row_order.is_empty():
		return
	default_focus = get_path_to(_rows[_row_order[0]])


func _paint_hover() -> void:
	for tag: StringName in _row_order:
		var btn := _rows[tag]
		btn.self_modulate = Tokens.GOLD if tag == _hover_tag else Color.WHITE


func _on_row_pressed(tag: StringName) -> void:
	if tag == _shown_tag:
		play(tag)
	else:
		show_country(tag)


func _on_country_chosen(_tag: StringName) -> void:
	finished.emit(&"chosen")


func _connect_chosen() -> void:
	if not Events.country_chosen.is_connected(_on_country_chosen):
		Events.country_chosen.connect(_on_country_chosen)


func _disconnect_chosen() -> void:
	if Events.country_chosen.is_connected(_on_country_chosen):
		Events.country_chosen.disconnect(_on_country_chosen)
