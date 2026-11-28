## The map's armies (docs/architecture/m6-build-spec.md 6.1 and 6.3; L16): the army tokens, the selection (a click on your unit
## token, a second click on a stack, Tab), the order cursor (Alt+arrows, O and a right click), the route of the cursor or of the hex
## under the pointer, the stored route of a march in progress (thin), the reach of the selected army and R. A child of the
## map scene, made once the scene's layers exist, as MapPeople is. It reads the game through ArmyView and MovePreview and
## orders only through Session.act; it never changes the game. The orders of an army (march, halt, Continue and storm; the
## army panel's buttons come here too) go through its MoveOrders: a running live walk lands first, a risky move is asked about,
## the toast is MoveWords' and a battle the walk opened is told (moves-build-spec.md R48 to R53). Multi-leg marches (R58 to
## R62): Shift+right click and V order the selected army's path at once, a point added to its end or its final point taken off
## (MarchPath), a plain right click replaces the path, and while Shift is held the route and the move card show the extended
## path (MapHover.preview_changed).
class_name MapArmies
extends Node

signal army_selected(army_id: int)
signal army_cleared
## An order's toast (spec 6.10): the App shows it (GameRequests); a refusal is `refused` on the scene, as before.
signal said(text: String, tone: StringName)
## An order's walk fought a battle (R53): the App opens the dock on its record once the walk has played.
signal battle_opened(record: int)

## The group the armies' layer is found by: the army panel's orders and the map hover's points mark.
const GROUP := &"map_armies"

## The process priority of the layer: after every other node of the frame (the default is 0).
const SYNC_PRIORITY := 1000
const NO_HEX := Vector2i(-9999, -9999)
const REACH_TILE := "mark/white"
const CURSOR_TILE := "mark/target"
const REACH_LAYER := "reach"
const REACH_NEXT_LAYER := "reach_next"
## What only the next season reaches (the drawn map hatches it, ParchmentReach; the tiles never show it).
const REACH_AHEAD_LAYER := "reach_ahead"
## The order kind of a march (Army.ORDER_MARCH; the view's order.kind).
const MARCH_KIND := &"march"
## The tone of the toast of a hold and of the replay's line (spec 6.10); a walk's toast takes MoveWords' tone and a refusal is
## a warning (`refused`).
const TOAST_TONE := &"plain"
## Supply states that feed an army (SupplyView.at's state); any other state is out of supply.
const INSIDE_STATES: Array[StringName] = [&"depot", &"in", &"winter_cut"]

## The line an order gets while the movement replay runs (spec 6.4; the keys O and R and a halt are orders too).
const REPLAY_BLOCKED := "The moves are still playing: Space skips them."

## () -> bool, set by GameRequests: true while the movement replay runs, so no order is given (M6 6.4).
var orders_blocked: Callable = Callable()
var _orders := MoveOrders.new()
var _scene: MapScene = null
var _view: TileMapView = null
var _tokens: ArmyTokens = null
var _route: PathMarks = null
var _stored: PathMarks = null
var _look: StringName = PathMarks.LOOK_RIBBON
var _menu: HexMenu = null
var _army := -1
var _cursor := NO_HEX
var _hover := NO_HEX
var _reach: Dictionary = {REACH_LAYER: [], REACH_NEXT_LAYER: [], REACH_AHEAD_LAYER: []}
## MapModes.discovered_key of the hexes the reach was kept to when it was filled; [] when it was filled whole (the tiles).
var _reach_fog: Array = []
var _zoom := 1.0
var _colour_blind := false
var _dirty := false
## True after Alt+arrows moved the order cursor, until the pointer moves to a hex: V then reads the cursor (R62).
var _keyboard := false
## True while Shift is held over the map (MapInput.extend_changed): the previews are the extended path's.
var _extending := false
## The sight this sync last read: its revision and the player's explored revision (a change of sight with no army event re-syncs).
var _sight_key: Array = []
var _links: Array[Array] = []


func _init() -> void:
	name = &"MapArmies"  # the map scene finds it as $MapArmies
	# Last of the frame: the computer's season slices and the replay move armies and sight in other nodes' _process, and the
	# tokens must follow in the same frame (a token never stands on a hex the viewer cannot see, not even for a frame).
	process_priority = SYNC_PRIORITY


func _ready() -> void:
	add_to_group(GROUP)
	_scene = get_parent() as MapScene
	_view = _scene.view()
	_tokens = ArmyTokens.new()
	_tokens.setup(_view)
	add_child(_tokens)
	_route = PathMarks.new()
	_route.setup(_view)
	add_child(_route)
	_stored = PathMarks.new()
	_stored.setup(_view)
	add_child(_stored)
	_set_look_all()
	_menu = HexMenu.new()  # the hex menu (L19): no army of yours selected, a right click or O on an own hex
	add_child(_menu)
	_menu.setup(_scene, self)
	_view.layer(REACH_LAYER).modulate = Tokens.MAP_REACH
	_view.layer(REACH_NEXT_LAYER).modulate = Tokens.MAP_REACH_NEXT
	_colour_blind = _scene.overlay().is_colour_blind()
	var input := _scene.map_input()
	_link(input.next_army_requested, next_army)
	_link(input.continue_march_requested, continue_march)
	_link(input.cursor_moved, move_cursor)
	_link(input.command_key_requested, _on_command_key)
	_link(input.hover_changed, _on_hover)
	_link(_scene.camera_rig().view_changed, _on_view_moved)
	_link(input.unit_requested, _on_unit_requested)
	input.unit_at_func = _own_unit_at
	_link(input.waypoint_requested, _on_waypoint_clicked)
	_link(input.waypoint_key_requested, _on_waypoint_key)
	_link(input.extend_changed, _on_extend_changed)
	input.waypoint_ready = _has_army
	_link(Events.game_started, _on_game_started)
	_link(Events.game_ended, _on_game_ended)
	_link(_scene.selection_changed, _on_selection_changed)
	for sig: Signal in [Events.army_raised, Events.army_disbanded, Events.army_changed, Events.unit_moved,
			Events.march_halted, Events.army_starved, Events.unit_lost, Events.season_ended]:
		_link(sig, _mark_dirty)
	sync()


func _exit_tree() -> void:
	for pair: Array in _links:
		var sig := pair[0] as Signal
		var fn := pair[1] as Callable
		if sig.is_connected(fn):
			sig.disconnect(fn)
	_links.clear()


func _link(sig: Signal, fn: Callable) -> void:
	sig.connect(fn)
	_links.append([sig, fn])


func _mark_dirty(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null, _e: Variant = null,
		_f: Variant = null) -> void:
	_dirty = true


func _on_game_started() -> void:
	clear_army()
	_mark_dirty()


## The game ended (Session.game is null now): the selection goes; the sync empties the tokens.
func _on_game_ended() -> void:
	clear_army()
	_mark_dirty()


func _process(_delta: float) -> void:
	if _scene == null:
		return
	var z := _scene.zoom()
	if not is_equal_approx(z, _zoom):
		_zoom = z
		_tokens.set_zoom(z)
		_route.set_zoom(z)
		_stored.set_zoom(z)
	var colour_blind := _scene.overlay().is_colour_blind()
	if colour_blind != _colour_blind:
		_colour_blind = colour_blind
		_dirty = true
	if _sight_moved():
		_dirty = true
	if _dirty:
		sync()
	elif _army >= 0 and Session.game != null and not _mine(Session.game, _army):
		# An army that died or merged away without an event of its own (a battle or a merge in the computer's turn): the selection
		# goes on this frame, not at the next event.
		clear_army()


## True when the player's sight moved since the last sync: the sight's revision (its army part and land) or the player's explored
## revision. A district taken, a fog change or a foreign army that left sight moves it with no army event of its own, so its
## token must go (a token never stands on a hex the viewer cannot see).
func _sight_moved() -> bool:
	var game := Session.game
	if game == null or not game.has_countries():
		return false
	var c := Countries.by_tag(game, Session.player_tag())
	var key: Array = [game.sight.revision(), game.sight.explored_revision(c.id) if c != null else -1]
	if key == _sight_key:
		return false
	_sight_key = key
	return true


## Brings the tokens, the reach and the route up to the game as it is now (an army event, a season, a new game).
func sync() -> void:
	_dirty = false
	var game := Session.game
	_tokens.refresh(game, Session.player_tag(), _colour_blind)
	if game != null:
		_scene.overlay().sync_sight(game)  # the sight texture follows an army that moved or appeared (cheap at the same version)
	if _army < 0:
		return
	if not _mine(game, _army):
		clear_army()
		return
	_fill_reach()
	_show_route()


## The army tokens (ArmyTokens) of the map, for the scene's tests and tools.
func tokens() -> ArmyTokens:
	return _tokens


## The route of the cursor (PathMarks) and the stored route of a march in progress, for the tests and the pictures.
func route_marks() -> PathMarks:
	return _route


func stored_marks() -> PathMarks:
	return _stored


## Fills the reach again when what it is kept to moved: the drawn map came or went, or, while it shows, the viewer or
## what the viewer has discovered changed. The scene calls it each time it decides what shows (MapSceneParchment); a
## discovery that moves with no view change also comes through sync().
func follow_drawn_map() -> void:
	if _army >= 0 and _reach_fog_now() != _reach_fog:
		_fill_reach()


## How many hexes the reach layer `layer` (one of the three REACH_*) holds for the selected army.
func reach_count(layer: String) -> int:
	return (_reach[layer] as Array).size()


## The hex menu (HexMenu) of the armies' layer: the App listens to its `chosen` for the war items (M7 6.8).
func hex_menu() -> HexMenu:
	return _menu


## The selected army's id, -1 for none.
func selected_army() -> int:
	return _army


## The order cursor's hex with an army selected, else the scene's selected hex (NO_HEX for none).
func cursor_hex() -> Vector2i:
	return _cursor if _army >= 0 else _scene.selected


## Selects one army of yours: its token rings, its reach fills, the order cursor stands on its hex and the route follows.
## False, with nothing changed, for an army that is not yours.
func select_army(army_id: int) -> bool:
	var game := Session.game
	if not _mine(game, army_id):
		return false
	_army = army_id
	_keyboard = false
	_scene.select_hex(NO_HEX)
	_set_cursor(ArmyView.panel(game, Session.player_tag(), army_id)["hex"] as Vector2i)
	_hover = _scene.map_input().hover_from_pointer()  # V and the route read the hex under the pointer at once (issue 479)
	_tokens.set_selected(army_id)
	_fill_reach()
	_show_route()
	army_selected.emit(army_id)
	Events.army_selected.emit(army_id)
	return true


## Clears the army selection: the ring, the reach, the routes and the order cursor go. The scene's hex selection stays.
func clear_army() -> void:
	if _army < 0:
		return
	_set_cursor(NO_HEX)
	_release()


## The army lets go: its ring, reach and routes go, and the two signals say so. The cursor's mark is the caller's.
func _release() -> void:
	_army = -1
	_keyboard = false
	_clear_reach()
	_route.clear_route()
	_stored.clear_route()
	_tokens.set_selected(-1)
	army_cleared.emit()
	Events.army_cleared.emit()


## The scene selected a hex while an army was selected (a search, a bookmark, a click the army did not take): the army lets go,
## and the cursor's mark goes unless the new selection's ring now sits on it (the two share the marks layer).
func _on_selection_changed(hex: Vector2i) -> void:
	if hex == NO_HEX or _army < 0:
		return
	if _cursor != hex and _cursor != NO_HEX:
		_view.set_tile("marks", _cursor, "")
	_cursor = NO_HEX
	_release()


## A left click on one of your unit tokens (MapInput.unit_requested; a hex click is the scene's, and the hex is not picked
## here). The token's first army is selected, and each further click on the stack takes the next army of it.
func _on_unit_requested(screen: Vector2) -> void:
	var token := _tokens.own_token_at(screen)
	if token == null or token.armies.is_empty():
		return
	var ids := token.armies
	select_army(ids[(ids.find(_army) + 1) % ids.size()])


## MapInput's hit test: true while one of your unit tokens stands under the viewport point `screen`.
func _own_unit_at(screen: Vector2) -> bool:
	return _tokens.own_token_at(screen) != null


## Tab: the next army of the player in ArmyView.needing_orders (the ones with no order first), selected and glided to.
func next_army() -> bool:
	var game := Session.game
	var tag := Session.player_tag()
	var ids := ArmyView.needing_orders(game, tag) if game != null else PackedInt32Array()
	if ids.is_empty():
		return _refuse("You have no army.")
	select_army(ids[(ids.find(_army) + 1) % ids.size()])
	_scene.glide_to_hex(_cursor)
	return true


## An army chosen from a report line, a task flag row or a notification's Go: selected, and the view glides to it (6.10).
## False, with nothing changed, for an army that is not yours.
func show_army(army_id: int) -> bool:
	if not select_army(army_id):
		return false
	_scene.glide_to_hex(_cursor)
	return true


## What the orders ask and skip (the App sets its settings and callables).
func orders() -> MoveOrders:
	return _orders


## The armies' layer of the map in `node`'s tree, or null (a panel or a card with no map).
static func in_tree(node: Node) -> MapArmies:
	return node.get_tree().get_first_node_in_group(GROUP) as MapArmies if node.is_inside_tree() else null


## R: continue the halted march of the selected army; a refusal is said.
func continue_march() -> bool:
	if _replay_blocks():
		return false
	if _army < 0:
		return _refuse("Select an army first.")
	return continue_army(_army)


## Continue (R, the army panel's button) for an army of yours: asked first when risky. False when refused (the refusal is said);
## true when the order was given or its question is up.
func continue_army(army_id: int) -> bool:
	if _replay_blocks():
		return false
	_orders.skip_live()
	var verdict := Session.check("continue_march", {"army": army_id})
	if not bool(verdict.get("ok", false)):
		return _refuse(str(verdict.get("reason", "")))
	var game := Session.game
	_orders.run(_name_of(game, army_id), MoveOrders.continue_risks(game, Session.player_tag(), army_id),
			_give_continue.bind(game, army_id))
	return true


## A command at `hex` (a right click, or O at the cursor) with an army of yours selected: a march to it, which replaces any
## path (asked first when risky), or a halt when it is the army's own hex (R60). False with no army selected (the scene then
## deselects, and the hex menu comes later).
func command(hex: Vector2i) -> bool:
	if _replay_blocks():
		return true
	if _army < 0:
		_menu.open_for(hex, get_viewport().get_mouse_position())
		return false
	var game := Session.game
	if not _mine(game, _army):
		clear_army()
		return false
	if game.map == null or not game.map.has(hex):
		return true
	_orders.skip_live()
	if hex == (ArmyView.panel(game, Session.player_tag(), _army)["hex"] as Vector2i):
		_halt(game, hex)
	else:
		_order_march(game, hex)
	return true


## Shift+right click or V at `hex` with an army of yours selected (R58): with a path under way, a march through it on to `hex`,
## or, on its final point, without that point (the only one: a halt); with none, as command(hex). Asked first when risky.
## False when nothing is ordered here: no army, off the map, the replay.
func extend_path(hex: Vector2i) -> bool:
	if _replay_blocks():
		return false
	var game := Session.game
	if _army < 0 or not _mine(game, _army):
		return _refuse("Select an army first.")
	if game.map == null or not game.map.has(hex):
		return false
	var a := Armies.by_id(game, _army)
	var step := MarchPath.next(game, a, hex)
	if step.is_empty():
		return command(hex)
	_orders.skip_live()
	if bool(step["halt"]):
		_halt(game, a.hex)
	else:
		_order_march(game, step["goal"] as Vector2i, step["via"] as Array[Vector2i])
	return true


## The picture of the order a click at `hex` would give the selected army now: with Shift held and a path under way, the
## path's (MarchPath.preview); else the plain march's.
func order_preview(hex: Vector2i) -> Dictionary:
	var tag := Session.player_tag()
	if _extending:
		var path := MarchPath.preview(Session.game, tag, _army, hex)
		if not path.is_empty():
			return path
	return MovePreview.to(Session.game, tag, _army, hex)


## An army of yours storms the fortress at `hex` (Ctrl+right click, Shift+O, the panel's Storm), asked first when risky. False
## when refused (the refusal is said) or there is no such army or hex; true when the order was given or its question is up.
func storm(army_id: int, hex: Vector2i) -> bool:
	if _replay_blocks():
		return false
	var game := Session.game
	if game == null or game.map == null or not game.map.has(hex) or not _mine(game, army_id):
		return false
	_orders.skip_live()
	var verdict := Session.check("storm", {"army": army_id, "goal": hex})
	if not bool(verdict.get("ok", false)):
		return _refuse(str(verdict.get("reason", "")))
	_orders.run(_name_of(game, army_id), MoveOrders.storm_risks(game, Session.player_tag(), army_id, hex),
			_give_storm.bind(game, army_id, hex))
	return true


## Halts the selected army on its own hex: "The Army of Turin holds at Vercelli (6, 9)."
func _halt(game: Game, hex: Vector2i) -> void:
	var words := "The %s holds at %s." % [_name_of(game, _army), Words.place(game, hex)]
	var verdict := Session.act("halt", {"army": _army})
	if not bool(verdict.get("ok", false)):
		_refuse(str(verdict.get("reason", "")))
		return
	_set_cursor(hex)
	sync()
	_say(words, TOAST_TONE)


## Orders the selected army's march to `hex` through the path points `via` (none: a plain march), asked first when risky (the
## question names the whole path).
func _order_march(game: Game, hex: Vector2i, via: Array[Vector2i] = []) -> void:
	_orders.run(_name_of(game, _army), MoveOrders.march_risks(game, Session.player_tag(), _army, hex, via),
			_give_march.bind(game, _army, hex, via), MoveOrders.path_line(game, via, hex))


## Gives the march (at once, or after "Move"): the army walks in the act. A refused one changes nothing (R60).
func _give_march(game: Game, army_id: int, hex: Vector2i, via: Array[Vector2i]) -> void:
	if not _still(game, army_id):
		return
	var army_name := _name_of(game, army_id)
	var args := {"army": army_id, "goal": hex}
	if not via.is_empty():
		args["via"] = via.duplicate()
	var verdict := Session.act("march", args)
	if not bool(verdict.get("ok", false)):
		_refuse(_said_reason(army_id, hex, via, verdict))
		return
	if army_id == _army:
		_set_cursor(hex)
		_keyboard = false
	var walk := verdict.get("walk", {}) as Dictionary
	_walked(MoveOrders.words(game, Session.player_tag(), army_id, army_name, walk), walk)


func _give_continue(game: Game, army_id: int) -> void:
	if not _still(game, army_id):
		return
	var army_name := _name_of(game, army_id)
	var verdict := Session.act("continue_march", {"army": army_id})
	if not bool(verdict.get("ok", false)):
		_refuse(str(verdict.get("reason", "")))
		return
	var walk := verdict.get("walk", {}) as Dictionary
	_walked(MoveOrders.words(game, Session.player_tag(), army_id, army_name, walk), walk)


func _give_storm(game: Game, army_id: int, hex: Vector2i) -> void:
	if not _still(game, army_id):
		return
	var tag := Session.player_tag()
	var army_name := _name_of(game, army_id)
	var odds := OddsView.of(game, tag, army_id, hex, true)  # the word as it reads before the walk
	var word := str(odds.get("word", ""))
	if word.is_empty():
		word = str(odds.get("storm_word", ""))
	var verdict := Session.act("storm", {"army": army_id, "goal": hex})
	if not bool(verdict.get("ok", false)):
		_refuse(str(verdict.get("reason", "")))
		return
	var walk := verdict.get("walk", {}) as Dictionary
	_walked(MoveOrders.storm_words(game, tag, army_id, army_name, walk, hex, word), walk)


## After an order's walk: the layer follows the game, the toast is said and a battle fought is told.
func _walked(words: Dictionary, walk: Dictionary) -> void:
	sync()
	if str(words.get("text", "")) != "":
		_say(str(words["text"]), StringName(words.get("tone", TOAST_TONE)))
	if int(walk.get("battle", -1)) >= 0:
		battle_opened.emit(int(walk["battle"]))


## Whether an order asked about in `game` may still be given: the same game, the army still the player's.
func _still(game: Game, army_id: int) -> bool:
	return Session.game == game and _mine(game, army_id)


func _name_of(game: Game, army_id: int) -> String:
	return str(ArmyView.panel(game, Session.player_tag(), army_id).get("name", "The army"))


## Says an order's words on the scene's `said` signal (the App's toast).
func _say(text: String, tone: StringName) -> void:
	said.emit(text, tone)


## The words of a refused march: MovePreview's, the same as the move card's (spec 6.7), else the action's own reason.
func _said_reason(army_id: int, hex: Vector2i, via: Array[Vector2i], verdict: Dictionary) -> String:
	var reason := str(verdict.get("reason", ""))
	var game := Session.game
	var tag := Session.player_tag()
	if via.is_empty() and hex == (ArmyView.panel(game, tag, army_id)["hex"] as Vector2i):
		return reason
	var shown := MovePreview.to(game, tag, army_id, hex) if via.is_empty() else MovePreview.via(game, tag, army_id, via, hex)
	var preview := shown["verdict"] as Dictionary
	return reason if bool(preview.get("ok", false)) else str(preview.get("reason", reason))


## Alt+arrows: with no army selected the selected hex moves (from the camera's hex when none); with one, the order cursor
## moves and the route follows. Either stops at the edge of the map, and the camera follows.
func move_cursor(direction: int) -> void:
	var game := Session.game
	if game == null or game.map == null:
		return
	if _army < 0:
		var base: Vector2i = _scene.selected if _scene.selected != NO_HEX else _view.hex_at(_scene.camera().position)
		var target := _inside(game, MapInput.cursor_step(base, direction), base)
		_scene.select_hex(target)
		_scene.glide_to_hex(target)
		return
	var next := _inside(game, MapInput.cursor_step(_cursor, direction), _cursor)
	_scene.map_input().yield_hover()  # the glide to the cursor must not hand the hover back to a resting pointer
	_hover = NO_HEX
	_keyboard = true
	_set_cursor(next)
	_scene.glide_to_hex(next)
	_show_route()
	_announce_cursor(next)


## True while the replay runs: the order is not given and the replay's line is said (orders_blocked, spec 6.4).
func _replay_blocks() -> bool:
	if not (orders_blocked.is_valid() and bool(orders_blocked.call())):
		return false
	_say(REPLAY_BLOCKED, TOAST_TONE)
	return true


func _on_command_key() -> void:
	if _army >= 0:
		command(_cursor)
	elif _scene.selected != NO_HEX:
		_menu.open_for(_scene.selected, _view.get_global_transform_with_canvas() * _view.centre_of(_scene.selected))


## The camera moved: the hover is the hex under the resting pointer (issue 480).
func _on_view_moved(_zoom_now: float, _visible_rect: Rect2) -> void:
	_scene.map_input().refresh_hover()


func _on_hover(hex: Vector2i) -> void:
	_hover = hex
	if hex != NO_HEX:
		_keyboard = false
	if _army >= 0:
		_show_route()


func _has_army() -> bool:
	return _army >= 0


func _on_waypoint_clicked(map_px: Vector2) -> void:
	extend_path(_view.hex_at(map_px))


## V: at the order cursor after Alt+arrows, else the hovered hex, else the cursor (R62).
func _on_waypoint_key() -> void:
	extend_path(_hover if _hover != NO_HEX and not _keyboard else cursor_hex())


## Shift went down or came up: the route is drawn again and the move card told (R59).
func _on_extend_changed(on: bool) -> void:
	_extending = on
	if _army < 0:
		return
	_show_route()
	if is_inside_tree():
		get_tree().call_group(MapHover.GROUP, "preview_changed")


## The hex when it is on the map, else `fallback` (the clamp of the cursor at the map's edge).
static func _inside(game: Game, hex: Vector2i, fallback: Vector2i) -> Vector2i:
	return hex if game.map.has(hex) else fallback


func _mine(game: Game, army_id: int) -> bool:
	if game == null:
		return false
	return bool(ArmyView.panel(game, Session.player_tag(), army_id).get("mine", false))


func _set_cursor(hex: Vector2i) -> void:
	if _cursor != NO_HEX:
		_view.set_tile("marks", _cursor, "")
	_cursor = hex
	if hex != NO_HEX:
		_view.set_tile("marks", hex, CURSOR_TILE)


## The route to the hex under the pointer (the order cursor when the pointer is off the map), with Shift held the extended
## path's with a pin on each point, and the stored route of a march in progress, thin, when its goal is another hex or it has
## path points left (R68).
func _show_route() -> void:
	var game := Session.game
	if _army < 0 or not _mine(game, _army):
		_route.clear_route()
		_stored.clear_route()
		return
	var tag := Session.player_tag()
	var panel := ArmyView.panel(game, tag, _army)
	var here := panel["hex"] as Vector2i
	var target := _hover if _hover != NO_HEX else _cursor
	_route.show_route(_with_beyond(order_preview(target), here))
	_stored.clear_route()
	var order := panel["order"] as Dictionary
	if StringName(order["kind"]) == MARCH_KIND:
		var stored := MovePreview.stored(game, tag, _army)
		if (order["goal"] as Vector2i) != target or not (stored["via"] as Array).is_empty():
			_stored.show_route(_with_beyond(stored, here), true)


## The setting map/path_look: the look of the cursor's route and of the stored route (PathMarks.set_look). Kept until the marks exist.
func set_path_look(look: String) -> void:
	_look = StringName(look)
	_set_look_all()


func _set_look_all() -> void:
	if _route != null:
		_route.set_look(_look)
		_stored.set_look(_look)


## The preview with `beyond` added: one byte a hex, 1 where the hex is out of supply for the player (SupplyView.at), and `from`,
## the army's own hex, where the route starts.
func _with_beyond(preview: Dictionary, from: Vector2i) -> Dictionary:
	var out := preview.duplicate()
	out["from"] = from
	var beyond := PackedByteArray()
	for item: Variant in preview.get("hexes", []) as Array:
		var supply := SupplyView.at(Session.game, Session.player_tag(), item as Vector2i)
		var inside := bool(supply["shown"]) and INSIDE_STATES.has(StringName(supply["state"]))
		beyond.append(0 if inside else 1)
	out["beyond"] = beyond
	return out


func _fill_reach() -> void:
	_clear_reach()
	var reach := MovePreview.reach(Session.game, Session.player_tag(), _army)
	_reach_fog = _reach_fog_now()
	var season := _on_known(reach["season"] as PackedInt32Array)
	var next := _on_known(reach["next"] as PackedInt32Array)
	_paint(REACH_LAYER, season)
	_paint(REACH_NEXT_LAYER, next)
	var ahead := PackedInt32Array()
	for i: int in next:
		if not season.has(i):
			ahead.append(i)
	_paint(REACH_AHEAD_LAYER, ahead)


## What the reach is to be kept to now: while the drawn map shows, the viewer's discovered hexes (by their key); else [].
func _reach_fog_now() -> Array:
	var game := Session.game
	if game == null or game.map == null or not _scene.parchment().visible:
		return []
	return MapModes.discovered_key(game, Session.player_tag())


## `indices` as the reach may show them: on the drawn map none on a hex the viewer has not discovered (its unexplored paper
## would show the coast of unknown land, map-overview-build-spec.md R12, R15); on the tiles all of them.
func _on_known(indices: PackedInt32Array) -> PackedInt32Array:
	if _reach_fog.is_empty():
		return indices
	var seen := MapModes.discovered_bytes(Session.game, Session.player_tag())
	var out := PackedInt32Array()
	for i: int in indices:
		if seen[i] == 1:
			out.append(i)
	return out


func _paint(layer: String, indices: PackedInt32Array) -> void:
	var cells := _reach[layer] as Array
	for i: int in indices:
		var hex := Session.game.map.hex_of(i)
		_view.set_tile(layer, hex, REACH_TILE)
		cells.append(hex)


func _clear_reach() -> void:
	for layer: String in _reach:
		var cells := _reach[layer] as Array
		for hex: Vector2i in cells:
			_view.set_tile(layer, hex, "")
		cells.clear()


## The order cursor moved (Alt+arrows): the move card of the pointer's hover card (MapHover) follows it to the hex's centre.
func _announce_cursor(hex: Vector2i) -> void:
	var screen := _view.get_global_transform_with_canvas() * _view.centre_of(hex)
	get_tree().call_group(MapHover.GROUP, "order_cursor_moved", hex, screen)


## Says a refusal on the scene's `refused` signal (the App's toast) and returns false.
func _refuse(reason: String) -> bool:
	_scene.refused.emit(reason)
	return false
