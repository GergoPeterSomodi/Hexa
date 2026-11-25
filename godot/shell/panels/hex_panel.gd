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
## The works rows are BuildRows (the ActionsBox) and the job line is JobLine (the WorkBox), in shell/panels/tile_tabs/:
## this panel gives them the ask callable (_ask_app) and the retired list, and relays the rows' hover signals.
class_name HexPanel
extends HexPanelContract

## The Owner row's link was pressed: the owner's tag (the dock shows that country).
signal country_requested(tag: StringName)
## A request for the App (see the class comment): what, and its arguments.
signal works_requested(what: StringName, args: Dictionary)
## The pointer or the keyboard is on a row: the App shows the row's card and ghost. option is {action, family}.
signal row_hovered(hex: Vector2i, option: Dictionary)
signal row_unhovered
## A toast from the Raise tab (text, tone): the raise's words, or the refusal's reason.
signal toast_requested(text: String, tone: StringName)

## The segment of an own settlement (spec 6.8): Works (the rows) or Raise (the raise list).
const TAB_WORKS := &"works"
const TAB_RAISE := &"raise"

@onready var _cartouche: Cartouche = $Scroll/Body/Cartouche
@onready var _subtitle: Label = $Scroll/Body/Subtitle
@onready var _piece_box: VBoxContainer = $Scroll/Body/PieceBox
@onready var _piece_rows: GridContainer = $Scroll/Body/PieceBox/Rows
@onready var _ground_box: VBoxContainer = $Scroll/Body/GroundBox
@onready var _ground_rows: GridContainer = $Scroll/Body/GroundBox/Rows
@onready var _owner_row: HBoxContainer = $Scroll/Body/OwnerRow
@onready var _owner_value: HBoxContainer = $Scroll/Body/OwnerRow/Value
@onready var _war_box: VBoxContainer = $Scroll/Body/WarBox
@onready var _people_box: VBoxContainer = $Scroll/Body/PeopleBox
@onready var _people_value: Label = $Scroll/Body/PeopleBox/PeopleRow/Value
@onready var _people_room_row: HBoxContainer = $Scroll/Body/PeopleBox/RoomRow
@onready var _people_room_value: Label = $Scroll/Body/PeopleBox/RoomRow/Value
@onready var _people_outlook: Label = $Scroll/Body/PeopleBox/Outlook
@onready var _gives_row: HBoxContainer = $Scroll/Body/GivesRow
@onready var _gives_value: Label = $Scroll/Body/GivesRow/Value
@onready var _worth_row: HBoxContainer = $Scroll/Body/WorthRow
@onready var _worth_value: HBoxContainer = $Scroll/Body/WorthRow/Value
@onready var _rule: HSeparator = $Scroll/Body/Rule
@onready var _home_box: VBoxContainer = $Scroll/Body/HomeReason
@onready var _job: JobLine = $Scroll/Body/WorkBox
@onready var _build: BuildRows = $Scroll/Body/ActionsBox
@onready var _tab_box: VBoxContainer = $Scroll/Body/TabBox
@onready var _tabs: Segmented = $Scroll/Body/TabBox/Tabs
@onready var _raise_box: VBoxContainer = $Scroll/Body/RaiseBox
@onready var _raise: RaiseList = $Scroll/Body/RaiseBox/RaiseList

## The App's settings (game/confirm_works is read from them on each refresh); null reads the shipped default.
var settings: Settings = null:
	set(value):
		settings = value
		if _build != null:
			_build.settings = value

var _hex := NO_HEX:
	set(value):
		_hex = value
		if _build != null:
			_build.set_hex(value)
var _retired: Array[Node] = []
var _refresh_queued := false
var _fit_queued := false
var _tab: StringName = TAB_WORKS
var _raising := false

@onready var _scroll: ScrollContainer = $Scroll
@onready var _body: VBoxContainer = $Scroll/Body


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = float(Tokens.PANEL_W)
	visible = false
	_tabs.set_options([{"id": TAB_WORKS, "label": "Works"}, {"id": TAB_RAISE, "label": "Raise"}])
	_tabs.changed.connect(_on_tab_changed)
	_body.minimum_size_changed.connect(_fit_later)
	_raise.toast_requested.connect(_on_raise_toast)
	visibility_changed.connect(_fit_later)
	get_viewport().size_changed.connect(_fit_later)
	_build.settings = settings
	_build.set_hex(_hex)
	_build.retired = _retired
	_build.ask = _ask_app
	_build.row_hovered.connect(func(hex: Vector2i, option: Dictionary) -> void: row_hovered.emit(hex, option))
	_build.row_unhovered.connect(func() -> void: row_unhovered.emit())
	_job.retired = _retired
	_job.ask = _ask_app
	for pair: Array in _wiring():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		sig.connect(handler)


## The body scrolls inside the panel: the panel is as tall as its content but never taller than the window below its top
## edge, so a long list of rows can never push the HUD column past the window.
func _fit_later() -> void:
	if not _fit_queued:
		_fit_queued = true
		_fit.call_deferred()


func _fit() -> void:
	_fit_queued = false
	if not is_inside_tree():
		return
	var top := global_position.y if visible else float(Tokens.BAR_H)
	var room := maxf(0.0, get_viewport_rect().size.y - top - float(Tokens.S2))
	var chrome := get_combined_minimum_size().y - _scroll.get_combined_minimum_size().y
	var want := minf(_body.get_combined_minimum_size().y, maxf(0.0, room - chrome))
	if not is_equal_approx(_scroll.custom_minimum_size.y, want):
		_scroll.custom_minimum_size.y = want


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
		[Events.town_grew, _on_town_grew],
		[Events.district_declined, _on_district_declined],
		[Events.army_raised, _on_stock_changed],
		[Events.army_disbanded, _on_stock_changed],
		[Events.tax_set, _on_stock_changed],
		[Events.goods_short, _on_stock_changed],
		[Events.controllers_changed, _on_war_changed],
		[Events.district_captured, _on_war_changed],
		[Events.siege_started, _on_war_changed],
		[Events.siege_progress, _on_war_changed],
		[Events.siege_lifted, _on_war_changed],
		[Events.battle_ended, _on_war_changed],
		[Events.war_declared, _on_war_changed],
		[Events.peace_made, _on_war_changed],
	]


func show_hex(hex: Vector2i) -> void:
	if hex != _hex:
		_tab = TAB_WORKS
	_hex = hex
	refresh()


## Opens the Raise tab of the shown hex (the hex menu's Raise item). Only an own settlement offers the tab.
func show_raise() -> void:
	_tab = TAB_RAISE
	refresh()


func clear() -> void:
	_hex = NO_HEX
	visible = false


func shown_hex() -> Vector2i:
	return _hex


## The segment (Works | Raise) and the raise list, for the tests and the keyboard path.
func tabs() -> Segmented:
	return _tabs


func raise_list() -> RaiseList:
	return _raise


## The open tab: TAB_WORKS or TAB_RAISE.
func tab_open() -> StringName:
	return _tab


## Gives the panel the App's settings, read for game/confirm_works on each refresh.
func set_settings(p_settings: Settings) -> void:
	settings = p_settings


## Returns the KitButtons of the work and action rows in display order: Cancel the work first, then the rows
## (Build, or Upgrade and Clear). The (i) buttons are plain Buttons and are not listed.
func action_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for box: VBoxContainer in [_job.actions_box(), _build.rows()]:
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
	if game.has_countries() and not Knowledge.discovered(game, game.player, _hex):
		_show_unexplored()
		return
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
	_war_box.visible = HexWar.fill(_war_box, game, Session.player_tag(), _hex, _retired)
	_refresh_people(game)
	_refresh_gives(game)
	_refresh_worth(game)
	_rule.visible = true
	var home := Territory.at_home_check(game, Session.player_tag(), _hex)
	_refresh_home(home)
	_job.refresh(game, _hex)
	_refresh_tabs(game)
	if bool(home["ok"]):
		_write_actions(game, piece)
	else:
		_build.clear_rows()
		_build.visible = false
	visible = true


## An undiscovered hex (fog D18, as HexCard): the header says Unexplored and no row of the panel shows (no owner, place, ground, people).
func _show_unexplored() -> void:
	_show_sea()
	_cartouche.text = "Unexplored"
	_subtitle.text = "Hex %d, %d" % [_hex.x, _hex.y]


## A sea hex: the cartouche says so and no row of the panel shows.
func _show_sea() -> void:
	_cartouche.text = "Sea"
	_subtitle.text = "Hex %d, %d, open sea" % [_hex.x, _hex.y]
	_piece_box.visible = false
	_ground_box.visible = false
	_owner_row.visible = false
	_war_box.visible = false
	_people_box.visible = false
	_gives_row.visible = false
	_worth_row.visible = false
	_rule.visible = false
	_home_box.visible = false
	_job.visible = false
	_build.visible = false
	_tab_box.visible = false
	_raise_box.visible = false
	_job.clear_actions()
	_build.clear_rows()
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


## The People section (spec 6.3): on land, PeopleView.at's figures. Yours: "People 30,300 (up 300 last season)" and "Room
## 45,000", then the outlook in its tone; a known country's land: "People about 30,000"; unknown: no section; unowned land
## and the sandbox: the number alone (no outlook).
func _refresh_people(game: Game) -> void:
	var seen := PeopleView.at(game, Session.player_tag(), _hex)
	_people_box.visible = bool(seen.get("shown", false))
	_people_room_row.visible = false
	_people_outlook.visible = false
	if not _people_box.visible:
		return
	var player := Session.player_tag()
	var yours := player != &"" and Territory.owner_tag(game, _hex) == player
	if not yours or str(seen["text"]) == "none":
		_people_value.text = str(seen["text"])
		return
	var change := int(seen["change"])
	var people_text := Words.number(int(seen["people"]))
	if change != 0:
		people_text += " (%s %s last season)" % ["up" if change > 0 else "down", Words.number(absi(change))]
	_people_value.text = people_text
	_people_room_value.text = Words.number(int(seen["room"]))
	_people_room_row.visible = true
	var outlook := PeopleView.outlook(game, _hex)
	if not outlook.is_empty():
		_people_outlook.text = str(outlook["text"])
		_people_outlook.theme_type_variation = tone_variation(StringName(str(outlook["tone"])))
		_people_outlook.visible = true


## The theme variation of an outlook's tone (spec 6.3): good, bad, warn; plain reads as table text.
static func tone_variation(tone: StringName) -> StringName:
	match tone:
		&"good":
			return &"NumberGood"
		&"bad":
			return &"NumberBad"
		&"warn":
			return &"NumberWarn"
	return &"TableRow"


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


## The Works | Raise segment (spec 6.8): an own settlement shows it; the Raise tab shows the raise list in place of the
## works rows. Anywhere else the tab goes back to Works and both hide.
func _refresh_tabs(game: Game) -> void:
	var own := RaiseList.offered(game, Session.player_tag(), _hex)
	if not own:
		_tab = TAB_WORKS
	_tab_box.visible = own
	_tabs.select(_tab)
	_raising = own and _tab == TAB_RAISE
	_raise_box.visible = _raising
	if _raising:
		_raise.show_hex(_hex)


func _on_tab_changed(id: Variant) -> void:
	_tab = StringName(str(id))
	refresh()


func _on_stock_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null, _e: Variant = null) -> void:
	_request_refresh()


## A war signal (occupation, siege, battle, war or peace): the War block re-reads the game. Any arity is accepted, the signals
## carry different arguments.
func _on_war_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null, _e: Variant = null) -> void:
	_request_refresh()


func _on_raise_toast(text: String, tone: StringName) -> void:
	toast_requested.emit(text, tone)


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


## A town grew or a district declined: the panel refreshes when it shows that hex (spec 6.3).
func _on_town_grew(_tag: StringName, hex: Vector2i, _level: int) -> void:
	if hex == _hex:
		_request_refresh()


func _on_district_declined(_tag: StringName, hex: Vector2i, _level: int, _why: StringName) -> void:
	if hex == _hex:
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


## The rows of the hex (spec 6.4), written by BuildRows. A work under way on the hex hides the rows (the job line shows it).
func _write_actions(game: Game, piece: Dictionary) -> void:
	_build.clear_rows()
	_build.visible = game.state.work_at(_hex) == null and not _raising
	if _build.visible:
		_build.write(game, piece)


## The click of a menu item on a row (the hex menu): the same rule as the row's button, game/confirm_works included.
func begin_option(option: Dictionary, expensive: bool) -> void:
	_build.begin_option(option, expensive)


## The App's works requests (see the class comment): true when a listener took the request, so the App acts; false when
## none listens, and the row or the job line acts itself (the M3 path for begin_work and cancel_work).
func _ask_app(what: StringName, args: Dictionary) -> bool:
	if not _has_listener():
		return false
	works_requested.emit(what, args)
	return true


func _has_listener() -> bool:
	return works_requested.get_connections().size() > 0


static func _pairs_of(rows: Array[Array]) -> Array[String]:
	var pairs: Array[String] = []
	for row: Array in rows:
		if row.size() >= 2:
			pairs.append(str(row[0]))
			pairs.append(str(row[1]))
	return pairs
