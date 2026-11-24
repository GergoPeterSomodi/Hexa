## The army tokens of the map (docs/architecture/m6-build-spec.md 6.3; L16; z 88, y-sorted among themselves): one ArmyToken a
## (hex, country) that ArmyView.tokens lists for the viewer, so a foreign army the viewer cannot see has no token. `refresh`
## adds, updates and frees the tokens to match; `set_selected` rings the token that holds the selected army. Reads the game
## through ArmyView and MapModes (the country's colour) only.
## The replay (L15) draws walking armies with show_poses: each walking army gets its own walker token that moves between two
## hexes, and the token that stands for it on the map is hidden while it walks. Walkers are drawn from the replay's poses only.
class_name ArmyTokens
extends Node2D

const LAYER_Z := 88

var _view: TileMapView = null
var _tokens: Dictionary = {}  # "x,y,tag" -> ArmyToken
## "x,y,tag" -> {token (ArmyView's dictionary), colour, walking (the walking army ids drawn now)}: what a token is redrawn from.
var _sources: Dictionary = {}
var _selected := -1
var _zoom := 1.0
var _game: Game = null
var _viewer := &""
var _colour_blind := false
## army id -> ArmyToken, the walkers of the replay (none outside it).
var _walkers: Dictionary = {}
var _poses_up := false


func _init() -> void:
	z_index = LAYER_Z
	y_sort_enabled = true


## Takes the tile view whose centres place the tokens.
func setup(view: TileMapView) -> void:
	_view = view


## Makes the tokens of `viewer` match ArmyView.tokens(game, viewer): new ones made, the rest updated, the others freed.
## `colour_blind` picks the palette the plates take (the map's accessibility/country_colours).
func refresh(game: Game, viewer: StringName, colour_blind: bool = false) -> void:
	_game = game
	_viewer = viewer
	_colour_blind = colour_blind
	var keep := {}
	var colours := _colours(game, colour_blind)
	if _view != null:
		for token: Dictionary in ArmyView.tokens(game, viewer):
			var key := _key(token)
			var node := _tokens.get(key) as ArmyToken
			if node == null:
				node = ArmyToken.new()
				add_child(node)
				_tokens[key] = node
			var colour := _colour_of(colours, game, StringName(token.tag))
			node.position = _view.centre_of(token.hex as Vector2i)
			node.show_token(token, colour)
			_sources[key] = {"token": token, "colour": colour, "walking": PackedInt32Array()}
			node.set_zoom(_zoom)
			node.set_ring(_selected >= 0 and node.armies.has(_selected))
			keep[key] = true
	for key: String in _tokens.keys():
		if not keep.has(key):
			var gone := _tokens[key] as ArmyToken
			remove_child(gone)
			gone.queue_free()
			_tokens.erase(key)
			_sources.erase(key)
	_apply_visibility()


## Rings the token of the army `army_id` (-1: no ring).
func set_selected(army_id: int) -> void:
	_selected = army_id
	for node: ArmyToken in tokens():
		node.set_ring(army_id >= 0 and node.armies.has(army_id))
	for id: Variant in _walkers.keys():
		(_walkers[id] as ArmyToken).set_ring(int(id) == army_id)


## The viewer's own token under the viewport point `screen`, the lower one on the map when several overlap (the one drawn
## on top); null for none. Only the shown static tokens are units: a walker is not, nor a token hidden while its army
## walks, and a foreign token never is (ArmyView lists only the armies the viewer sees, so an unseen one cannot be picked).
func own_token_at(screen: Vector2) -> ArmyToken:
	var best: ArmyToken = null
	if _viewer == &"":
		return null
	for node: ArmyToken in tokens():
		if not node.visible or node.tag != _viewer or not node.hit_screen(screen):
			continue
		if best == null or node.position.y > best.position.y:
			best = node
	return best


## The walker of army `army_id` while the replay draws it, or null.
func walker(army_id: int) -> ArmyToken:
	return _walkers.get(army_id) as ArmyToken


## Sizes every token for the camera's zoom (ArmyToken.set_zoom).
func set_zoom(zoom: float) -> void:
	_zoom = zoom
	for node: ArmyToken in tokens():
		node.set_zoom(zoom)
	for id: Variant in _walkers.keys():
		(_walkers[id] as ArmyToken).set_zoom(zoom)


## Draws the replay's walkers (ReplayPlan.poses): each pose is {army, tag, from, to, t, shown}. A walker stands between `from`
## and `to` at fraction `t`, and is hidden for a step the viewer did not see. The token of a walking army is hidden while it
## walks. An empty list takes the walkers away and shows every token again.
func show_poses(poses: Array[Dictionary]) -> void:
	if poses.is_empty():
		_free_walkers()
		_poses_up = false
		_apply_visibility()
		return
	_poses_up = true
	var live := {}
	for pose: Dictionary in poses:
		var id := int(pose["army"])
		live[id] = true
		var node := _walkers.get(id) as ArmyToken
		if node == null:
			node = _make_walker(id, StringName(pose["tag"]))
			_walkers[id] = node
		if _view != null:
			node.position = _view.centre_of(pose["from"] as Vector2i).lerp(_view.centre_of(pose["to"] as Vector2i),
					float(pose["t"]))
		node.visible = bool(pose["shown"])
		node.set_ring(id == _selected)
	for id: Variant in _walkers.keys():
		if not live.has(id):
			_free_walker(int(id))
	_apply_visibility()


## The number of walkers on the map now (0 outside a replay).
func walker_count() -> int:
	return _walkers.size()


## The token of `tag` on `hex`, or null.
func token_at(hex: Vector2i, tag: StringName) -> ArmyToken:
	return _tokens.get(_key({"hex": hex, "tag": tag})) as ArmyToken


## Every token now (in no fixed order).
func tokens() -> Array[ArmyToken]:
	var out: Array[ArmyToken] = []
	for node: Variant in _tokens.values():
		out.append(node as ArmyToken)
	return out


func token_count() -> int:
	return _tokens.size()


static func _key(token: Dictionary) -> String:
	var hex := token.hex as Vector2i
	return "%d,%d,%s" % [hex.x, hex.y, String(token.tag)]


## The palette of the scenario's countries (MapModes.palette, colour-blind or not), or empty with no countries.
static func _colours(game: Game, colour_blind: bool) -> PackedColorArray:
	if game == null or not game.has_countries():
		return PackedColorArray()
	return MapModes.palette(game, colour_blind)


static func _colour_of(colours: PackedColorArray, game: Game, tag: StringName) -> Color:
	var c: Country = Countries.by_tag(game, tag) if game != null else null
	if c == null or c.id < 0 or c.id >= colours.size():
		return Color.WHITE
	return colours[c.id]


## A walker for army `id`: the token ArmyView lists for it (one army of it), else a plain one with no figure or badge.
func _make_walker(id: int, tag: StringName) -> ArmyToken:
	var dict := _token_dict_of(id)
	if dict.is_empty():
		dict = {"hex": Vector2i.ZERO, "tag": tag, "figure": &"", "text": ""}
	dict["armies"] = PackedInt32Array([id])
	dict["mustering"] = false
	dict["marching"] = true
	dict["waiting"] = false
	dict["hungry"] = false
	var colours := _colours(_game, _colour_blind)
	var node := ArmyToken.new()
	add_child(node)
	node.show_token(dict, _colour_of(colours, _game, tag))
	node.set_zoom(_zoom)
	return node


## The ArmyView token that holds army `id` for the viewer, or {} when the viewer cannot see it.
func _token_dict_of(id: int) -> Dictionary:
	if _game == null:
		return {}
	for token: Dictionary in ArmyView.tokens(_game, _viewer):
		if (token["armies"] as PackedInt32Array).has(id):
			var copy := token.duplicate()
			return copy
	return {}


func _free_walker(id: int) -> void:
	var node := _walkers.get(id) as ArmyToken
	_walkers.erase(id)
	if node != null:
		remove_child(node)
		node.queue_free()


func _free_walkers() -> void:
	for id: Variant in _walkers.keys():
		_free_walker(int(id))


## A token whose armies all walk is hidden (their walkers stand for them). One with some walking armies is drawn again
## with the standing ones only, so no army shows twice. It is redrawn only when the walking set changes.
func _apply_visibility() -> void:
	for key: String in _tokens.keys():
		var node := _tokens[key] as ArmyToken
		var source := _sources.get(key, {}) as Dictionary
		if source.is_empty():
			node.visible = true
			continue
		var all_armies := (source["token"] as Dictionary)["armies"] as PackedInt32Array
		var walking := _walking_in(all_armies)
		node.visible = walking.size() < all_armies.size()
		if walking == (source["walking"] as PackedInt32Array):
			continue
		source["walking"] = walking
		var dict := (source["token"] as Dictionary).duplicate()
		var rest := PackedInt32Array()
		for id: int in all_armies:
			if not walking.has(id):
				rest.append(id)
		dict["armies"] = rest
		node.show_token(dict, source["colour"] as Color)
		node.set_ring(_selected >= 0 and node.armies.has(_selected))  # the ring goes with the army that stays here


## The armies of `armies` that have a walker now (none outside a replay).
func _walking_in(armies: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not _poses_up:
		return out
	for id: int in armies:
		if _walkers.has(id):
			out.append(id)
	return out
