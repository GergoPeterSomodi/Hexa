## The tile window (tile-window spec R11 to R17, R32 its part, R33, R34; build plan TW9): the dock panel of one tile that
## replaced the old hex panel in the swap (TW16), behind the same HexPanelContract. Its parts, top to bottom: the postcard header (a
## SettlementPicture with the name, the place link, the size stars and the badges on a settlement or castle; a title bar
## elsewhere; no header on unexplored land but its title), the number strip (StripCells from TileView.strip), the job line
## (JobLine), the tab strip and the open tab's body. Only the open tab has children: the tabs are scripts of
## shell/panels/tile_tabs/ found by TileTabs, and a switch frees the old one (R17).
##
## Which tab opens (R16, D7): the last tab the player picked when it is live on the tile, else Buildings if live, else Land.
## A refresh where the open tab turns dimmed or gone falls back the same way, with no toast. A dimmed tab is drawn dimmed with
## its reason as tooltip; it is disabled, so it is not clickable and not reached by the keys (R14).
##
## The window reads the game through TileView and the tabs; it changes the game only through the tabs and Session.act. Its
## signals keep the names of the old panel's, so Hud and WarRequests connect to it. Tab workers implement begin_option
## (called by begin_option here) and may emit through the window's signals by way of the tab's own connections.
class_name TileWindow
extends HexPanelContract

## The Owner link was pressed: the owner's tag (the dock shows that country).
signal country_requested(tag: StringName)
## A request for the App (the job line's Cancel, the rows' works): what, and its arguments.
signal works_requested(what: StringName, args: Dictionary)
## An App request from a tab (see TileTab.app_requested): what, and its arguments.
signal app_requested(what: StringName, args: Dictionary)
## The pointer or the keyboard is on a row: the App shows the row's card and ghost.
## The row's card (a Dictionary) and the rect to anchor it to; the host shows the hover card.
signal row_hovered(card: Dictionary, anchor: Rect2)
signal row_unhovered
## A toast from a tab (text, tone).
signal toast_requested(text: String, tone: StringName)

const TAB_LAND := &"land"
const TAB_BUILDINGS := &"buildings"
const TAB_ARMY := &"army"
## The tab that opens when the last pick is not live: Buildings first, then Land (R16).
const FALLBACK_ORDER: Array[StringName] = [&"buildings", &"land"]
const DIMMED_ALPHA := 0.5

## Set by the host (the Study or RaiseScreen is up): true blocks the tab keys (R32). Unset means no screen is up.
var screens_up: Callable = Callable()
## The number of rebuilds so far (tests check one refresh per burst, R17).
var rebuilds := 0
## The App's settings (game/confirm_works is read from them by the Buildings tab's hammer); null reads the shipped default.
var settings: Settings = null:
	set(value):
		settings = value
		_give_settings(_open_node())

@onready var _scroll: ScrollContainer = $Scroll
@onready var _body: VBoxContainer = $Scroll/Body
@onready var _picture: SettlementPicture = $Scroll/Body/Header/Picture
@onready var _title: Label = $Scroll/Body/Header/Title
@onready var _subtitle: Label = $Scroll/Body/Header/Subtitle
@onready var _place: Button = $Scroll/Body/Header/Meta/Place
@onready var _stars: Label = $Scroll/Body/Header/Meta/Stars
@onready var _badges: HBoxContainer = $Scroll/Body/Header/Badges
@onready var _strip: StripCells = $Scroll/Body/Strip
@onready var _job: JobLine = $Scroll/Body/WorkBox
@onready var _tab_strip: HBoxContainer = $Scroll/Body/TabStrip
@onready var _tab_body: VBoxContainer = $Scroll/Body/TabBody

var _shown: Vector2i = NO_HEX
var _view: Dictionary = {}
var _tab_ids: Array[StringName] = []
var _dimmed: Dictionary = {}
var _open: StringName = &""
var _last_pick: StringName = &""
var _owner: StringName = &""
var _scripts_override: Array[GDScript] = []
var _group := ButtonGroup.new()
var _tab_buttons: Dictionary = {}
var _retired: Array[Node] = []
var _queued := false
var _fit_queued := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = float(Tokens.PANEL_W)
	visible = false
	_place.pressed.connect(_on_owner_pressed)
	_job.retired = _retired
	_job.ask = _ask_app
	_body.minimum_size_changed.connect(_fit_later)
	visibility_changed.connect(_fit_later)
	get_viewport().size_changed.connect(_fit_later)
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


## The signals that change what the window shows; each one queues one refresh for the end of the frame (R17).
func _wiring() -> Array:
	return [
		[Events.hex_changed, _on_event],
		[Events.owners_changed, _on_event],
		[Events.country_chosen, _on_event],
		[Events.work_started, _on_event],
		[Events.work_finished, _on_event],
		[Events.work_cancelled, _on_event],
		[Events.town_grew, _on_town_grew],
		[Events.district_declined, _on_district_declined],
		[Events.season_ended, _on_event],
		[Events.army_raised, _on_event],
		[Events.army_disbanded, _on_event],
		[Events.tax_set, _on_event],
		[Events.goods_short, _on_event],
		[Events.controllers_changed, _on_event],
		[Events.district_captured, _on_event],
		[Events.siege_started, _on_event],
		[Events.siege_progress, _on_event],
		[Events.siege_lifted, _on_event],
		[Events.battle_ended, _on_event],
		[Events.war_declared, _on_event],
		[Events.peace_made, _on_event],
	]


func _on_event(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null, _e: Variant = null) -> void:
	if _shown == NO_HEX or _queued:
		return
	_queued = true
	_flush.call_deferred()


## A town grew or a district declined: the window refreshes when it shows that hex (the old panel's rule).
func _on_town_grew(_tag: StringName, hex: Vector2i, _level: int) -> void:
	if hex == _shown:
		_on_event()


func _on_district_declined(_tag: StringName, hex: Vector2i, _level: int, _why: StringName) -> void:
	if hex == _shown:
		_on_event()


func _flush() -> void:
	if not _queued:
		return
	_queued = false
	if _shown != NO_HEX:
		_rebuild()


## Runs a queued refresh now (tests and tools; the frame does it otherwise).
func flush_pending() -> void:
	_flush()


# --- the HexPanelContract -----------------------------------------------------------------------------------------------


## Shows the window for the hex: the header, the strip, the job line and the tabs, with the tab R16 picks open.
func show_hex(hex: Vector2i) -> void:
	_shown = hex
	_open = &""
	visible = true
	_rebuild()


## Hides the window; nothing is shown afterwards.
func clear() -> void:
	_shown = NO_HEX
	_view = {}
	_tab_ids = []
	_dimmed = {}
	_open = &""
	_tab_buttons = {}
	if _tab_body != null:  # a window not yet in the tree (the map scene clears its panel when it is set) has no nodes to clear
		PanelKit.clear_children(_tab_body, _retired)
		PanelKit.clear_children(_tab_strip, _retired)
	visible = false


func shown_hex() -> Vector2i:
	return _shown


## Reads the game again for the shown hex (the header, strip, job line and tabs; the open tab refills).
func refresh() -> void:
	if _shown == NO_HEX:
		return
	_rebuild()


# --- the tabs -----------------------------------------------------------------------------------------------------------


## The tab ids that show for the hex, in ORDER (dimmed ones included).
func tab_ids() -> Array[StringName]:
	return _tab_ids.duplicate()


## The shown tabs that are live (not dimmed) for the hex, in ORDER.
func live_tab_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _tab_ids:
		if not _dimmed.has(id):
			out.append(id)
	return out


## The open tab's id, or &"" when none is open.
func tab_open() -> StringName:
	return _open


## Opens a live tab and remembers it as the player's pick (R16). A dimmed or absent tab does nothing and returns false.
func show_tab(id: StringName) -> bool:
	if not live_tab_ids().has(id):
		return false
	_last_pick = id
	_open = id
	_open_tab()
	return true


## Steps to the next (step 1) or previous (step -1) live tab, wrapping. Dimmed tabs are skipped.
func next_tab(step: int) -> void:
	var live := live_tab_ids()
	if live.is_empty():
		return
	var at := live.find(_open)
	var target: StringName
	if at < 0:
		target = live[0] if step > 0 else live[live.size() - 1]
	else:
		target = live[posmod(at + step, live.size())]
	show_tab(target)


## Offers a build row's option to the open tab (the Buildings tab implements begin_option). False when no tab takes it.
func begin_option(option: Dictionary, expensive: bool) -> bool:
	var tab := _open_node()
	if tab == null or not tab.has_method("begin_option"):
		return false
	tab.call("begin_option", option, expensive)
	return true


## Gives the window the App's settings (the open tab reads game/confirm_works from them).
func set_settings(p_settings: Settings) -> void:
	settings = p_settings


## The buttons of the work and the rows, in display order: Cancel the work first, then the open Buildings tab's hammers (the
## tests and the keyboard path; a built or locked row has none).
func action_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child: Node in _job.actions_box().get_children():
		if child is KitButton:
			out.append(child as Button)
	for row: BuildingRow in building_rows():
		if row.hammer() != null:
			out.append(row.hammer())
	return out


## The compact rows of the open Buildings tab, in display order (empty on any other tab).
func building_rows() -> Array[BuildingRow]:
	var out: Array[BuildingRow] = []
	var tab := _open_node()
	if tab == null or not tab.has_method("row_nodes"):
		return out
	var nodes: Dictionary = tab.call("row_nodes")
	for id: Variant in nodes:
		var row := nodes[id] as BuildingRow
		if row != null and is_instance_valid(row):
			out.append(row)
	return out


## Replaces the tab registry with these scripts (tests and the monkey); an empty list restores TileTabs.all().
func use_tabs(scripts: Array[GDScript]) -> void:
	_scripts_override = scripts.duplicate()
	if _shown != NO_HEX:
		_rebuild()


## Handles the tab keys (R32): Ctrl+] and Ctrl+[ step through the live tabs; Left and Right do when the strip has focus.
## Nothing is handled while the window shows no hex or while a screen is up. True when the key was used.
func handle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo or _shown == NO_HEX or not is_visible_in_tree():
		return false
	if screens_up.is_valid() and bool(screens_up.call()):
		return false
	if key.ctrl_pressed and key.keycode == KEY_BRACKETRIGHT:
		next_tab(1)
		return true
	if key.ctrl_pressed and key.keycode == KEY_BRACKETLEFT:
		next_tab(-1)
		return true
	if (key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT) and _strip_has_focus():
		next_tab(1 if key.keycode == KEY_RIGHT else -1)
		return true
	return false


func _unhandled_key_input(event: InputEvent) -> void:
	if handle_key(event):
		get_viewport().set_input_as_handled()


func _strip_has_focus() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus != null and _tab_strip.is_ancestor_of(focus)


# --- building ----------------------------------------------------------------------------------------------------------


func _scripts() -> Array[GDScript]:
	if not _scripts_override.is_empty():
		return _scripts_override
	return TileTabs.all()


func _rebuild() -> void:
	rebuilds += 1
	var game := Session.game
	_view = TileView.of(game, Session.player_tag(), _shown)
	if _view.is_empty():
		clear()
		return
	var unexplored := StringName(str(_view.get("case", ""))) == &"unexplored"
	_show_header(game)
	_strip.show_cells(_view.get("strip", []) if not unexplored else [])
	if unexplored:
		_job.visible = false
	else:
		_job.refresh(game, _shown, Session.player_tag())
	var scripts := _scripts()
	_tab_ids = []
	_dimmed = {}
	if not unexplored:
		_tab_ids = TileTabs.shown_in(scripts, _view)
		_dimmed = TileTabs.dimmed_in(scripts, _view)
	var live := live_tab_ids()
	if not live.has(_open):
		_open = _fallback(live)
	_build_tab_strip()
	_open_tab()


## R16: the last pick when live, else Buildings, else Land; the first live tab when none of those is.
func _fallback(live: Array[StringName]) -> StringName:
	if live.has(_last_pick):
		return _last_pick
	for id: StringName in FALLBACK_ORDER:
		if live.has(id):
			return id
	return live[0] if not live.is_empty() else &""


func _build_tab_strip() -> void:
	PanelKit.clear_children(_tab_strip, _retired)
	_tab_buttons = {}
	_tab_strip.visible = _tab_ids.size() > 1
	for id: StringName in _tab_ids:
		var button := Button.new()
		button.text = _label_of(id)
		button.set_meta("tab_id", id)
		button.theme_type_variation = &"ButtonTabCompact"
		button.toggle_mode = true
		button.button_group = _group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = float(maxi(Tokens.BUTTON_H, Tokens.TARGET_MIN))
		button.focus_mode = Control.FOCUS_ALL
		# A disabled button keeps its tooltip only when it still takes the pointer (mouse_filter STOP).
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		var reason := str(_dimmed.get(id, ""))
		button.disabled = reason != ""
		button.tooltip_text = reason
		button.modulate.a = DIMMED_ALPHA if reason != "" else 1.0
		button.pressed.connect(_on_tab_pressed.bind(id))
		_tab_strip.add_child(button)
		_tab_buttons[id] = button
	_sync_buttons()


func _open_tab() -> void:
	PanelKit.clear_children(_tab_body, _retired)
	var script := _script_of(_open)
	if script != null and _shown != NO_HEX:
		var tab := script.new() as TileTab
		_give_settings(tab)
		_tab_body.add_child(tab)
		_wire_tab(tab)
		tab.fill(Session.game, Session.player_tag(), _shown, _view)
	_sync_buttons()


## Forwards a tab's requests to the window's signals; open_tab_requested asks for the tab (show_tab decides).
func _wire_tab(tab: TileTab) -> void:
	tab.row_hovered.connect(func(card: Dictionary, anchor: Rect2) -> void: row_hovered.emit(card, anchor))
	tab.row_unhovered.connect(func() -> void: row_unhovered.emit())
	tab.works_requested.connect(_forward_works)
	tab.toast_requested.connect(func(text: String, tone: StringName) -> void: toast_requested.emit(text, tone))
	tab.app_requested.connect(func(what: StringName, args: Dictionary) -> void: app_requested.emit(what, args))
	tab.open_tab_requested.connect(func(id: StringName) -> void: show_tab(id))


func _give_settings(tab: Node) -> void:
	if tab != null and "settings" in tab:
		tab.set("settings", settings)


func _forward_works(request: Dictionary) -> void:
	var args: Dictionary = request.get("args", {})
	works_requested.emit(StringName(str(request.get("what", ""))), args)


## The open tab's node, or null when none is open (tests and tools read the tab's own accessors through it).
func tab_node() -> Node:
	return _open_node()


func _open_node() -> Node:
	if _tab_body == null:
		return null
	return _tab_body.get_child(0) if _tab_body.get_child_count() > 0 else null


func _sync_buttons() -> void:
	for id: Variant in _tab_buttons:
		var button := _tab_buttons[id] as Button
		if button != null:
			button.set_pressed_no_signal(StringName(str(id)) == _open)


func _script_of(id: StringName) -> GDScript:
	if id == &"":
		return null
	for script: GDScript in _scripts():
		if TileTabs.id_of(script) == id:
			return script
	return null


func _label_of(id: StringName) -> String:
	var script := _script_of(id)
	if script == null:
		return str(id)
	return str(script.get_script_constant_map().get("LABEL", str(id)))


func _on_tab_pressed(id: StringName) -> void:
	show_tab(id)


# --- the header ---------------------------------------------------------------------------------------------------------


func _show_header(game: Game) -> void:
	var head: Dictionary = _view.get("header", {})
	_title.text = str(head.get("title", ""))
	_subtitle.text = str(head.get("subtitle", ""))
	var owner: Dictionary = head.get("owner", {})
	_owner = StringName(str(owner.get("tag", "")))
	var place := str(head.get("place", ""))
	_place.text = place
	_place.visible = place != ""
	_place.disabled = _owner == &""
	var stars := int(head.get("stars", 0))
	_stars.text = "*".repeat(stars)
	_stars.visible = stars > 0
	_show_badges(head.get("badges", []))
	var picture: Dictionary = head.get("picture", {})
	_picture.visible = not picture.is_empty()
	if not picture.is_empty():
		var colour := _colour_of(game, StringName(str(picture.get("owner_tag", ""))))
		var snow := int(picture.get("climate", -1)) == HexCard.CLIMATE_WORDS.find("snow")
		_picture.show_picture(StringName(str(picture.get("kind", "hamlet"))), int(picture.get("level", 1)),
				int(picture.get("harbour", 0)), snow, colour)


func _show_badges(badges: Array) -> void:
	PanelKit.clear_children(_badges, _retired)
	for raw: Variant in badges:
		var badge := raw as Dictionary
		var tone := StringName(str(badge.get("tone", "plain")))
		_badges.add_child(PanelKit.label(str(badge.get("text", "")), _badge_variation(tone)))


static func _badge_variation(tone: StringName) -> StringName:
	match tone:
		&"bad":
			return &"Reason"
		&"warn":
			return &"Hint"
	return &"LabelInk"


func _colour_of(game: Game, tag: StringName) -> Color:
	var cdef: CountryDef = Countries.def_of(game, tag) if tag != &"" else null
	if cdef == null:
		return Tokens.MUTED
	return cdef.colour


func _on_owner_pressed() -> void:
	if _owner != &"":
		country_requested.emit(_owner)


## The App's works requests: true when a listener took the request, else false and the job line acts itself.
func _ask_app(what: StringName, args: Dictionary) -> bool:
	if works_requested.get_connections().is_empty():
		return false
	works_requested.emit(what, args)
	return true


# --- fit ---------------------------------------------------------------------------------------------------------------


## The body scrolls inside the window: the window is as tall as its content but never taller than the viewport below its
## top edge less S2 (R33).
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
