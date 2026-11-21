## The army tokens of the map (docs/architecture/m6-build-spec.md 6.3; L16; z 88, y-sorted among themselves): one ArmyToken a
## (hex, country) that ArmyView.tokens lists for the viewer, so a foreign army the viewer cannot see has no token. `refresh`
## adds, updates and frees the tokens to match; `set_selected` rings the token that holds the selected army. Reads the game
## through ArmyView and MapModes (the country's colour) only.
class_name ArmyTokens
extends Node2D

const LAYER_Z := 88

var _view: TileMapView = null
var _tokens: Dictionary = {}  # "x,y,tag" -> ArmyToken
var _selected := -1
var _zoom := 1.0


func _init() -> void:
	z_index = LAYER_Z
	y_sort_enabled = true


## Takes the tile view whose centres place the tokens.
func setup(view: TileMapView) -> void:
	_view = view


## Makes the tokens of `viewer` match ArmyView.tokens(game, viewer): new ones made, the rest updated, the others freed.
## `colour_blind` picks the palette the plates take (the map's accessibility/country_colours).
func refresh(game: Game, viewer: StringName, colour_blind: bool = false) -> void:
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
			node.position = _view.centre_of(token.hex as Vector2i)
			node.show_token(token, _colour_of(colours, game, StringName(token.tag)))
			node.set_zoom(_zoom)
			node.set_ring(_selected >= 0 and node.armies.has(_selected))
			keep[key] = true
	for key: String in _tokens.keys():
		if not keep.has(key):
			var gone := _tokens[key] as ArmyToken
			remove_child(gone)
			gone.queue_free()
			_tokens.erase(key)


## Rings the token of the army `army_id` (-1: no ring).
func set_selected(army_id: int) -> void:
	_selected = army_id
	for node: ArmyToken in tokens():
		node.set_ring(army_id >= 0 and node.armies.has(army_id))


## Sizes every token for the camera's zoom (ArmyToken.set_zoom).
func set_zoom(zoom: float) -> void:
	_zoom = zoom
	for node: ArmyToken in tokens():
		node.set_zoom(zoom)


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
