## The map's armies (docs/architecture/m6-build-spec.md 6.1 and 6.3; L16): the army tokens, the selection (a click, a second
## click on the same token, Tab), the order cursor (Alt+arrows, O and a right click), the route of the cursor or of the hex
## under the pointer, the stored route of a march in progress (thin), the reach of the selected army and R. A child of the
## map scene, made once the scene's layers exist, as MapPeople is. It reads the game through ArmyView and MovePreview and
## orders only through Session.act; it never changes the game.
class_name MapArmies
extends Node

signal army_selected(army_id: int)
signal army_cleared

const NO_HEX := Vector2i(-9999, -9999)
const REACH_TILE := "mark/white"
const CURSOR_TILE := "mark/target"
const REACH_LAYER := "reach"
const REACH_NEXT_LAYER := "reach_next"
## The order kind of a march (Army.ORDER_MARCH; the view's order.kind).
const MARCH_KIND := &"march"
## Supply states that feed an army (SupplyView.at's state); any other state is out of supply.
const INSIDE_STATES: Array[StringName] = [&"depot", &"in", &"winter_cut"]

var _scene: MapScene = null
var _view: TileMapView = null
var _tokens: ArmyTokens = null
var _route: PathMarks = null
var _stored: PathMarks = null
var _army := -1
var _cursor := NO_HEX
var _hover := NO_HEX
var _reach: Dictionary = {REACH_LAYER: [], REACH_NEXT_LAYER: []}
var _zoom := 1.0
var _colour_blind := false
var _dirty := false
var _links: Array[Array] = []


func _init() -> void:
	name = &"MapArmies"  # the map scene finds it as $MapArmies


func _ready() -> void:
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
	_view.layer(REACH_LAYER).modulate = Tokens.MAP_REACH
	_view.layer(REACH_NEXT_LAYER).modulate = Tokens.MAP_REACH_NEXT
	_colour_blind = _scene.overlay().is_colour_blind()
	var input := _scene.map_input()
	_link(input.next_army_requested, next_army)
	_link(input.continue_march_requested, continue_march)
	_link(input.cursor_moved, move_cursor)
	_link(input.command_key_requested, _on_command_key)
	_link(input.hover_changed, _on_hover)
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


func _mark_dirty(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null, _e: Variant = null) -> void:
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
	var colour_blind := _scene.overlay().is_colour_blind()
	if colour_blind != _colour_blind:
		_colour_blind = colour_blind
		_dirty = true
	if _dirty:
		sync()


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


## How many hexes the reach layer `layer` (REACH_LAYER or REACH_NEXT_LAYER) holds for the selected army.
func reach_count(layer: String) -> int:
	return (_reach[layer] as Array).size()


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
	_scene.select_hex(NO_HEX)
	_set_cursor(ArmyView.panel(game, Session.player_tag(), army_id)["hex"] as Vector2i)
	_hover = NO_HEX
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


## A left click on `hex` (not while picking). Your token there selects its first army, and each further click on it the
## next one. Shift, or a hex with none of your tokens, clears the army and returns false: the scene selects the hex.
func click(hex: Vector2i, shift: bool = false) -> bool:
	if shift or Session.game == null:
		clear_army()
		return false
	var token := _own_token(hex)
	if token.is_empty():
		clear_army()
		return false
	var ids := token["armies"] as PackedInt32Array
	select_army(ids[(ids.find(_army) + 1) % ids.size()])
	return true


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


## R: continue the halted march of the selected army; a refusal is said.
func continue_march() -> bool:
	if _army < 0:
		return _refuse("Select an army first.")
	var verdict := Session.act("continue_march", {"army": _army})
	if not bool(verdict.get("ok", false)):
		return _refuse(str(verdict.get("reason", "")))
	sync()
	return true


## A command at `hex` (a right click, or O at the cursor) with an army of yours selected: a march to it, or a halt when it is
## the army's own hex. False with no army selected (the scene then deselects, and the hex menu comes later).
func command(hex: Vector2i) -> bool:
	if _army < 0:
		return false
	var game := Session.game
	if not _mine(game, _army):
		clear_army()
		return false
	if game.map == null or not game.map.has(hex):
		return true
	var here := ArmyView.panel(game, Session.player_tag(), _army)["hex"] as Vector2i
	var verdict: Dictionary
	if hex == here:
		verdict = Session.act("halt", {"army": _army})
	else:
		verdict = Session.act("march", {"army": _army, "goal": hex})
	if bool(verdict.get("ok", false)):
		_set_cursor(hex)
		sync()
	else:
		_refuse(str(verdict.get("reason", "")))
	return true


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
	_hover = NO_HEX
	_set_cursor(next)
	_scene.glide_to_hex(next)
	_show_route()


func _on_command_key() -> void:
	if _army >= 0:
		command(_cursor)


func _on_hover(hex: Vector2i) -> void:
	_hover = hex
	if _army >= 0:
		_show_route()


## The hex when it is on the map, else `fallback` (the clamp of the cursor at the map's edge).
static func _inside(game: Game, hex: Vector2i, fallback: Vector2i) -> Vector2i:
	return hex if game.map.has(hex) else fallback


func _mine(game: Game, army_id: int) -> bool:
	if game == null:
		return false
	return bool(ArmyView.panel(game, Session.player_tag(), army_id).get("mine", false))


## The token of the player's armies on `hex` (ArmyView.tokens' dictionary), {} when there is none.
func _own_token(hex: Vector2i) -> Dictionary:
	for token: Dictionary in ArmyView.tokens(Session.game, Session.player_tag()):
		if bool(token["mine"]) and (token["hex"] as Vector2i) == hex:
			return token
	return {}


func _set_cursor(hex: Vector2i) -> void:
	if _cursor != NO_HEX:
		_view.set_tile("marks", _cursor, "")
	_cursor = hex
	if hex != NO_HEX:
		_view.set_tile("marks", hex, CURSOR_TILE)


## The route to the hex under the pointer (the order cursor when the pointer is off the map), and the stored route of a
## march in progress, thin, when its goal is another hex.
func _show_route() -> void:
	var game := Session.game
	if _army < 0 or not _mine(game, _army):
		_route.clear_route()
		_stored.clear_route()
		return
	var tag := Session.player_tag()
	var target := _hover if _hover != NO_HEX else _cursor
	_route.show_route(_with_beyond(MovePreview.to(game, tag, _army, target)))
	_stored.clear_route()
	var order := ArmyView.panel(game, tag, _army)["order"] as Dictionary
	if StringName(order["kind"]) == MARCH_KIND and (order["goal"] as Vector2i) != target:
		_stored.show_route(_with_beyond(MovePreview.stored(game, tag, _army)), true)


## The preview with `beyond` added: one byte a hex, 1 where the hex is out of supply for the player (SupplyView.at).
func _with_beyond(preview: Dictionary) -> Dictionary:
	var out := preview.duplicate()
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
	_paint(REACH_LAYER, reach["season"] as PackedInt32Array)
	_paint(REACH_NEXT_LAYER, reach["next"] as PackedInt32Array)


func _paint(layer: String, indices: PackedInt32Array) -> void:
	var cells := _reach[layer] as Array
	for i: int in indices:
		var hex := Session.game.map.hex_of(i)
		_view.set_tile(layer, hex, REACH_TILE)
		cells.append(hex)


func _clear_reach() -> void:
	for layer: String in [REACH_LAYER, REACH_NEXT_LAYER]:
		var cells := _reach[layer] as Array
		for hex: Vector2i in cells:
			_view.set_tile(layer, hex, "")
		cells.clear()


## Says a refusal on the scene's `refused` signal (the App's toast) and returns false.
func _refuse(reason: String) -> bool:
	_scene.refused.emit(reason)
	return false
