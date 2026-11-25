## The tile window (tile-window spec R11 to R17, R32 its part, R33, R34; build plan TW9): the dock panel of one tile that
## replaced the old hex panel in the swap (TW16), behind the same HexPanelContract. Its parts, top to bottom, as the owner's mockup
## v4 draws them: the title bar (the size stars, the name, the close button), the sub line (the ground and hex, the owner's place
## link, the food), the chips (StripCells: an icon and a number per TileView.strip cell), the wide picture (SettlementPicture: the
## settlement, or the bare land or sea; badge icons at its foot; the fog's word on an unexplored hex), the tab strip, the open
## tab's body, and the queue at the foot (JobLine: the work under way, Cancel on your own). Only the open tab has children: the
## tabs are scripts of shell/panels/tile_tabs/ found by TileTabs, and a switch frees the old one (R17). On the Town tab, the
## reasons of the dimmed tabs are written under the facts (mockup v4, tab 5).
##
## One size for every tile and tab (issue 436): Tokens.TILE_WINDOW_W wide and, at most, Tokens.TILE_WINDOW_H tall (440 x 640 at
## 1280 x 720); a shorter viewport shrinks it to the room below its top (R33), the same for every tile and tab, so the window never
## jumps when another tile or tab is picked. The header, the tab strip and the queue are pinned; only the tab body scrolls. The
## frame is the kit's gold panel_frame; the parts are TileStyle's flat boxes and the Tile* type variations. The parts are found by
## their unique names (%Title, %Strip, %TabBody...).
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

const TAB_TOWN := &"town"
const TAB_ARMY := &"army"
## The tab that opens when the last pick is not live (R16): the Town tab (Land and Buildings in one since issue 436); the old
## ids stay in the list for windows given other tabs (the tests' stubs): Buildings first, then Land.
const FALLBACK_ORDER: Array[StringName] = [&"town", &"buildings", &"land"]
## The size stars beside the name: the point radius and the gap, in logical pixels (the fonts have no star glyph).
const STAR_R := 7.0
const STAR_GAP := 3.0
## The tab strip's height and the tab body's inner margins (left, top, right, bottom), in logical pixels.
const TAB_H := 36.0
const BODY_PAD: Array[int] = [8, 8, 8, 6]
## The badge icons at the foot of the picture: their side and the inset from the picture's corner, in logical pixels.
const BADGE_ICON := Vector2(18, 18)
const BADGE_INSET := 6
## The Kit icon of a badge, by the start of its words; and of the harbour badge.
const BADGE_ICONS := {"Occupied": &"castle", "Besieged": &"walls", "Battle": &"army", "Enemy army": &"army",
	"Foreign army": &"army"}
const HARBOUR_ICON := &"port_dues"
## The close button's cross: half its arm in logical pixels and its stroke; drawn as two lines about the button's centre, so it
## sits exactly in the middle of the circle whatever the font (no glyph, no icon).
const CLOSE_ARM := 4.5
const CLOSE_STROKE := 2.0
## The note under the Town tab's facts when other tabs are dimmed (mockup v4, tab 5), at sea, and on a never discovered hex.
const CLOSED_NOTE := "%s closed here"
const SEA_NOTE: Array[String] = ["Nothing to build or raise at sea", "Ports and ships arrive later."]
const FOG_NOTE: Array[String] = ["Never discovered",
	"Nothing is shown here until one of your armies or lands sees it. Explore by marching to the edge of the map."]

## Set by the host (the Study or RaiseScreen is up): true blocks the tab keys (R32). Unset means no screen is up.
var screens_up: Callable = Callable()
## The number of rebuilds so far (tests check one refresh per burst, R17).
var rebuilds := 0
## The App's settings (game/confirm_works is read from them by the Town tab's hammer); null reads the shipped default.
var settings: Settings = null:
	set(value):
		settings = value
		_give_settings(_open_node())

@onready var _frame: VBoxContainer = %Frame
@onready var _scroll: ScrollContainer = %Scroll
@onready var _picture: SettlementPicture = %Picture
@onready var _title: Label = %Title
@onready var _close: Button = %Close
@onready var _food: Label = %Food
@onready var _subtitle: Label = %Subtitle
@onready var _place: Button = %Place
@onready var _stars: Control = %Stars
@onready var _badges: HBoxContainer = %Badges
@onready var _badge_band: PanelContainer = %BadgeBand
@onready var _body_pad: MarginContainer = %BodyPad
@onready var _fog_box: PanelContainer = %FogBox
@onready var _strip_band: PanelContainer = %StripBand
@onready var _strip: StripCells = %Strip
@onready var _work_band: PanelContainer = %WorkBand
@onready var _job: JobLine = %WorkBox
@onready var _tab_strip: HBoxContainer = %TabStrip
@onready var _fog: Label = %Fog
@onready var _tab_body: VBoxContainer = %TabBody

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
var _star_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(float(Tokens.TILE_WINDOW_W), float(Tokens.TILE_WINDOW_H))
	visible = false
	_place.pressed.connect(_on_owner_pressed)
	_job.retired = _retired
	_job.ask = _ask_app
	for box: BoxContainer in [_frame, %Header as BoxContainer, _tab_strip]:
		box.add_theme_constant_override(&"separation", 0)
	(%JobRow as BoxContainer).add_theme_constant_override(&"separation", Tokens.S2)
	(%Queue as BoxContainer).add_theme_constant_override(&"separation", 2)
	_badges.add_theme_constant_override(&"separation", Tokens.S1 + 1)
	var names: Array[StringName] = [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]
	for i: int in names.size():
		_body_pad.add_theme_constant_override(names[i], BODY_PAD[i])
		(_badge_band.get_parent() as MarginContainer).add_theme_constant_override(names[i], BADGE_INSET)
	_stars.draw.connect(_draw_stars)
	_close.pressed.connect(_on_close_pressed)
	_close.draw.connect(_draw_close)
	_close.accessibility_name = "Close the tile window"
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
	if _tab_body != null:
		_scroll.scroll_vertical = 0  # a window not yet in the tree (the map scene clears its panel when it is set) has no nodes to clear
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


## Offers a build row's option to the open tab (the Town tab implements begin_option). False when no tab takes it.
func begin_option(option: Dictionary, expensive: bool) -> bool:
	var tab := _open_node()
	if tab == null or not tab.has_method("begin_option"):
		return false
	tab.call("begin_option", option, expensive)
	return true


## Gives the window the App's settings (the open tab reads game/confirm_works from them).
func set_settings(p_settings: Settings) -> void:
	settings = p_settings


## The buttons of the work and the rows, in display order: Cancel the work first, then the open Town tab's hammers (the
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


## The building tiles of the open Town tab, in display order (empty on any other tab).
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
	_strip_band.visible = _strip.visible
	if unexplored:
		_job.visible = false
	else:
		_job.refresh(game, _shown, Session.player_tag())
	_work_band.visible = _job.visible
	var queue_row := %QueueRow as Control
	queue_row.mouse_filter = Control.MOUSE_FILTER_PASS
	queue_row.tooltip_text = "The work under way here: %s, %s.
One work at a time on a tile." % [
		(_job.get_node("Text") as Label).text, (_job.get_node("Progress") as Label).text] if _job.visible else ""
	_fog_box.visible = unexplored
	_fog.text = _title.text if unexplored else ""
	_picture.visible = not unexplored
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
		button.theme_type_variation = &"ButtonTileTab"
		button.toggle_mode = true
		button.button_group = _group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = TAB_H
		button.clip_text = true
		button.focus_mode = Control.FOCUS_ALL
		# A disabled button keeps its tooltip only when it still takes the pointer (mouse_filter STOP).
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		var reason := str(_dimmed.get(id, ""))
		button.disabled = reason != ""
		button.tooltip_text = reason
		button.pressed.connect(_on_tab_pressed.bind(id))
		_tab_strip.add_child(button)
		_tab_buttons[id] = button
	_sync_buttons()


func _open_tab() -> void:
	PanelKit.clear_children(_tab_body, _retired)
	_scroll.scroll_vertical = 0
	var script := _script_of(_open)
	if script != null and _shown != NO_HEX:
		var tab := script.new() as TileTab
		_give_settings(tab)
		_tab_body.add_child(tab)
		_wire_tab(tab)
		tab.fill(Session.game, Session.player_tag(), _shown, _view)
		if _open == TAB_TOWN:
			_closed_note(tab)
	elif _shown != NO_HEX and StringName(str(_view.get("case", ""))) == &"unexplored":
		_tab_body.add_child(_note(FOG_NOTE[0], [FOG_NOTE[1]]))
	_sync_buttons()


## Under the Town tab's facts, inside the tab: which tabs are dimmed here and why (their tooltips' reasons, once each; mockup
## v4, tab 5); at sea, that nothing is built or raised there.
func _closed_note(tab: TileTab) -> void:
	if StringName(str(_view.get("case", ""))) == &"sea":
		tab.add_child(_note(SEA_NOTE[0], [SEA_NOTE[1]]))
		return
	var names: Array[String] = []
	var reasons: Array[String] = []
	for id: StringName in _tab_ids:
		var reason := str(_dimmed.get(id, ""))
		if reason == "":
			continue
		names.append(_label_of(id))
		if not reasons.has(reason):
			reasons.append(reason)
	if names.is_empty():
		return
	var verb := " is" if names.size() == 1 else " are"
	tab.add_child(_note(CLOSED_NOTE % (" and ".join(names) + verb), reasons))


## A quiet boxed note (mockup v4): its title in the name's type, then its lines in the small text.
func _note(title: String, lines: Array[String]) -> PanelContainer:
	var note := PanelContainer.new()
	note.name = &"ClosedNote"
	note.theme_type_variation = &"PanelTileNote"
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 2)
	note.add_child(column)
	column.add_child(PanelKit.label(title, &"TileName"))
	for text: String in lines:
		var line := PanelKit.label(text, &"Hint")
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(line)
	return note


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
	if _tab_body == null or _tab_body.get_child_count() == 0:
		return null
	var first := _tab_body.get_child(0)
	return first if first is TileTab else null


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
	_subtitle.tooltip_text = _subtitle.text
	var owner: Dictionary = head.get("owner", {})
	_owner = StringName(str(owner.get("tag", "")))
	var place := str(head.get("place", ""))
	_place.text = place
	_place.tooltip_text = place
	_place.visible = place != ""
	_place.disabled = _owner == &""
	_show_food()
	_star_count = int(head.get("stars", 0))
	_stars.custom_minimum_size = Vector2(_star_count * (2.0 * STAR_R + STAR_GAP), 2.0 * STAR_R)
	_stars.visible = _star_count > 0
	_stars.mouse_filter = Control.MOUSE_FILTER_PASS
	_stars.tooltip_text = "Size %d of 5: %s" % [_star_count, place.get_slice(" · ", 0).to_lower()] if _star_count > 0 else ""
	_stars.queue_redraw()
	var picture: Dictionary = head.get("picture", {})
	_show_badges(head.get("badges", []), int(picture.get("harbour", 0)) > 0)
	var colour := _colour_of(game, StringName(str(picture.get("owner_tag", owner.get("tag", "")))))
	var snow := int(picture.get("climate", -1)) == HexCard.CLIMATE_WORDS.find("snow")
	if not picture.is_empty():
		_picture.show_picture(StringName(str(picture.get("kind", "hamlet"))), int(picture.get("level", 1)),
				int(picture.get("harbour", 0)), snow, colour)
	else:
		# No settlement: the bare land, or the sea (mockup v4: the picture is there on every tile).
		var sea := StringName(str(_view.get("case", ""))) == &"sea"
		_picture.show_picture(SettlementPicture.SEA if sea else SettlementPicture.LAND, 1, 0, snow, colour)


## The sub line's food: the strip's food cell ("Food +11"), in its tone; hidden where the strip has none.
func _show_food() -> void:
	_food.visible = false
	for raw: Variant in _view.get("strip", []):
		var cell := raw as Dictionary
		if str(cell.get("key", "")) == "food":
			_food.text = "Food %s" % str(cell.get("value", ""))
			_food.mouse_filter = Control.MOUSE_FILTER_PASS
			_food.tooltip_text = "Food a year here: %s (what is made less what is eaten)." % str(cell.get("value", ""))
			_food.theme_type_variation = _badge_variation(StringName(str(cell.get("tone", "plain"))))
			_food.visible = true


## The badges as round icons at the foot of the picture, each with its words as tooltip (a bad one rimmed in red); a port
## shows the harbour's icon first.
func _show_badges(badges: Array, harbour: bool) -> void:
	PanelKit.clear_children(_badges, _retired)
	var items: Array[Dictionary] = []
	if harbour:
		items.append({"text": "A port", "tone": "plain", "icon": HARBOUR_ICON})
	for raw: Variant in badges:
		var badge := (raw as Dictionary).duplicate()
		badge["icon"] = _badge_icon(str(badge.get("text", "")))
		items.append(badge)
	_badge_band.visible = not items.is_empty()
	for badge: Dictionary in items:
		var disc := PanelContainer.new()
		var tone := StringName(str(badge.get("tone", "plain")))
		disc.theme_type_variation = &"PanelTileRoundBad" if tone == &"bad" else &"PanelTileRound"
		disc.tooltip_text = str(badge.get("text", ""))
		disc.mouse_filter = Control.MOUSE_FILTER_STOP
		disc.set_meta("text", disc.tooltip_text)
		var icon := TextureRect.new()
		icon.custom_minimum_size = BADGE_ICON
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_name := StringName(str(badge["icon"]))
		if has_theme_icon(icon_name, &"Kit"):
			icon.texture = get_theme_icon(icon_name, &"Kit")
		disc.add_child(icon)
		_badges.add_child(disc)


## The words of the badges shown (tests read them, in order).
func badge_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for child: Node in _badges.get_children():
		out.append(str(child.get_meta("text", "")))
	return out


static func _badge_icon(text: String) -> StringName:
	for start: String in BADGE_ICONS:
		if text.begins_with(start):
			return BADGE_ICONS[start]
	return &"warning"


## A tone's small text: bad and warn in their colours, good in green, plain in the table text.
static func _badge_variation(tone: StringName) -> StringName:
	match tone:
		&"bad":
			return &"HintBad"
		&"warn":
			return &"HintWarn"
		&"good":
			return &"HintGood"
	return &"TileSub"


## The size stars, drawn (the fonts have no star glyph): five-pointed, filled in GOLD with an INK rim.
func _draw_stars() -> void:
	var gold := _stars.get_theme_color(&"font_color", &"SectionHead")
	for n: int in _star_count:
		var centre := Vector2(STAR_R + n * (2.0 * STAR_R + STAR_GAP), STAR_R)
		var points := PackedVector2Array()
		for k: int in 10:
			var r := STAR_R if k % 2 == 0 else STAR_R * 0.45
			var a := -PI / 2.0 + k * PI / 5.0
			points.append(centre + Vector2(cos(a), sin(a)) * r)
		_stars.draw_colored_polygon(points, gold)
		points.append(points[0])
		_stars.draw_polyline(points, Tokens.INK, 1.0, true)


func _draw_close() -> void:
	var colour := _close.get_theme_color(&"font_hover_color" if _close.is_hovered() else &"font_color")
	var rect := close_glyph_rect()
	_close.draw_line(rect.position, rect.end, colour, CLOSE_STROKE, true)
	_close.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), colour, CLOSE_STROKE, true)


## The close cross's box in the button's own coordinates: centred on the button (tests check it).
func close_glyph_rect() -> Rect2:
	var centre := _close.size * 0.5
	return Rect2(centre - Vector2(CLOSE_ARM, CLOSE_ARM), Vector2(CLOSE_ARM, CLOSE_ARM) * 2.0)


## The close button (tests).
func close_button() -> Button:
	return _close


## The close button: the App clears the selection (the map's hex, so the window and the map agree); with no App, the window
## clears itself.
func _on_close_pressed() -> void:
	if app_requested.get_connections().is_empty():
		clear()
		return
	app_requested.emit(&"close_tile", {})


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


## The window is one size (TILE_WINDOW_W x TILE_WINDOW_H) and the tab body scrolls inside it; only a viewport too short for that
## height shrinks it to the room below its top edge less S2 (R33).
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
	var want := minf(float(Tokens.TILE_WINDOW_H), room)
	if not is_equal_approx(custom_minimum_size.y, want):
		custom_minimum_size.y = want
		size.y = want
