## The tile layers of the map view: which baked sprite each hex shows on each layer, as Python's map view draws the
## tile zoom (docs/design/art-inventory.md, "How Godot layers the pieces"). Pure: the shell turns each key into a cell
## of the TileSet. Layers: ground, coast (or a river mouth), river, road, decoration, town (or a harbour).
##
## Edge masks are bit e of hexgrid.neighbours order (0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE), the order of the atlas keys.
## Godot's TileMap neighbour order is never used: each key is chosen here by its mask.
##
## Data not in MapData yet (step 2 of the builder: roads, castles, owners) gives no cells here, so those layers stay
## empty until the builder fills the fields (godot/README.md "MapData fields"). Each such place is marked TODO-WIRE.
class_name TilePlan
extends RefCounted

const GROUND := "ground"
const COAST := "coast"
const RIVER := "river"
const ROAD := "road"
const DECO := "deco"
const TOWN := "town"
const LAYERS: PackedStringArray = ["ground", "coast", "river", "road", "deco", "town"]

var layers: Dictionary[String, Dictionary] = {}  # layer name -> Dictionary[Vector2i, String] (hex -> sprite key)
var missing: int = 0  # keys the plan wanted that the atlas does not hold (should stay 0)
var _atlas: AtlasIndex


## Builds every layer for the map. The atlas must be loaded (AtlasIndex.load_index).
static func build(map: MapData, atlas: AtlasIndex) -> TilePlan:
	var plan := TilePlan.new()
	plan._atlas = atlas
	for name: String in LAYERS:
		plan.layers[name] = {}
	var edges := _river_edges(map)
	plan._ground(map)
	var mouths: Dictionary[Vector2i, bool] = {}
	plan._rivers(map, edges, mouths)
	plan._coast(map, edges, mouths)
	plan._decoration(map, edges)
	plan._towns(map)
	plan._roads(map)
	return plan


## Number of cells of one layer.
func count(layer: String) -> int:
	var cells: Dictionary = layers.get(layer, {})
	return cells.size()


## The sprite key of a hex on a layer, or "" when the layer has no cell there.
func key_at(layer: String, pos: Vector2i) -> String:
	var cells: Dictionary = layers.get(layer, {})
	return cells.get(pos, "")


## Variant number of a hex: Python's MapView._variant (the same for every layer that picks by it).
static func variant(pos: Vector2i, count: int) -> int:
	return int((pos.x * 73856093) ^ (pos.y * 19349663)) % count


## Town level from the city size of the builder (its population in thousands, the Python CITIES table), as
## worldgen's settlement rule and overlay_desc's levels: 40 or more is a city (5), 60 or more a great city (6), else a
## market town (3). Walls (4) and villages (2) need the castle and the province population of step 2 (TODO-WIRE).
static func town_level(size: int) -> int:
	if size >= 40:
		return 6 if size >= 60 else 5
	return 3


## Bit of the edge from `from` to its neighbour `to` in hexgrid order, or 0 when they are not neighbours.
static func edge_bit(from: Vector2i, to: Vector2i) -> int:
	var i := 0
	for n: Vector2i in HexGrid.neighbours(from):
		if n == to:
			return 1 << i
		i += 1
	return 0


## Mask of the edges of a hex that touch ocean.
static func sea_mask(map: MapData, pos: Vector2i) -> int:
	var mask := 0
	var i := 0
	for n: Vector2i in HexGrid.neighbours(pos):
		if map.terrain.has(n) and map.terrain[n] == MapData.OCEAN:
			mask |= 1 << i
		i += 1
	return mask


## Mask of the river edges of every hex: each river joins its consecutive hexes.
static func _river_edges(map: MapData) -> Dictionary[Vector2i, int]:
	var edges: Dictionary[Vector2i, int] = {}
	for name: String in map.rivers.keys():
		var path: Array = map.rivers[name]
		for i in range(1, path.size()):
			var a: Vector2i = path[i - 1]
			var b: Vector2i = path[i]
			if HexGrid.distance(a, b) != 1:
				continue
			edges[a] = edges.get(a, 0) | edge_bit(a, b)
			edges[b] = edges.get(b, 0) | edge_bit(b, a)
	return edges


func _put(layer: String, pos: Vector2i, key: String) -> void:
	if key == "":
		return
	if not _atlas.has(key):
		missing += 1
		return
	var cells: Dictionary = layers[layer]
	cells[pos] = key


## The key of one member of a family ("terrain/plains" with index 1 gives terrain/plains/1), or "".
func _family_key(family: String, index: int) -> String:
	var keys := _atlas.variants(family)
	if keys.is_empty():
		return ""
	return keys[index % keys.size()]


func _ground(map: MapData) -> void:
	for pos: Vector2i in map.terrain.keys():
		var kind: String = map.terrain[pos]
		var key := ""
		if kind == MapData.OCEAN:
			key = _family_key("sea/sea", variant(pos, 3))
		elif kind == MapData.LAKE:
			# Owner's default (decision 1): a lake is the drawn sea tile, not the Kenney lake tile.
			key = _family_key("sea/sea", variant(pos, 3))
		else:
			key = _family_key("terrain/" + kind, pos.x * 5 + pos.y * 11)
		_put(GROUND, pos, key)


func _rivers(map: MapData, edges: Dictionary[Vector2i, int], mouths: Dictionary[Vector2i, bool]) -> void:
	for pos: Vector2i in edges.keys():
		var river: int = edges[pos] & ~sea_mask(map, pos)
		if river == 0:
			continue
		var sea := sea_mask(map, pos)
		if sea != 0 and _single_bit(river) >= 0:
			# A river mouth: its piece holds the river and the coast of the one edge the river comes in by.
			mouths[pos] = true
			_put(RIVER, pos, "mouth/%d/%d" % [_single_bit(river), sea])
		else:
			_put(RIVER, pos, _family_key("river/%d" % river, variant(pos, 3)))


func _coast(map: MapData, edges: Dictionary[Vector2i, int], mouths: Dictionary[Vector2i, bool]) -> void:
	for pos: Vector2i in map.land_hexes():
		var sea := sea_mask(map, pos)
		if sea == 0 or mouths.has(pos) or _harbour_key(map, pos) != "":
			continue
		_put(COAST, pos, _family_key("coast/%d" % sea, variant(pos, 3)))


func _decoration(map: MapData, edges: Dictionary[Vector2i, int]) -> void:
	for pos: Vector2i in map.land_hexes():
		var kind: String = map.terrain[pos]
		if kind != "plains" and kind != "steppe" and kind != "savanna":
			continue
		if map.city_names.has(pos) or edges.has(pos) or sea_mask(map, pos) != 0:
			continue
		# Python's decorations_for: the same hash of the position, trees and rocks on undeveloped open land.
		var h := int((pos.x * 73856093) ^ (pos.y * 19349663)) & 0xFFFF
		var kind_name := ""
		if h % 6 == 0:
			kind_name = "trees"
		elif h % 9 == 1:
			kind_name = "rocks"
		if kind_name != "":
			_put(DECO, pos, "deco/%s/%d" % [kind_name, h % 4])


## The harbour piece of a coastal town (it holds the coast too, so the town has no coast cell), or "".
func _harbour_key(map: MapData, pos: Vector2i) -> String:
	if not map.city_names.has(pos) or not map.is_land(pos):
		return ""
	var sea := sea_mask(map, pos)
	if sea == 0:
		return ""
	var level := town_level(map.city_sizes.get(pos, 1))
	var key := "harbour/%d/%d" % [level, sea]
	return key if _atlas.has(key) else ""


func _towns(map: MapData) -> void:
	for pos: Vector2i in map.city_names.keys():
		if not map.is_land(pos):
			continue
		var harbour := _harbour_key(map, pos)
		if harbour != "":
			_put(TOWN, pos, harbour)
		else:
			var level := town_level(map.city_sizes.get(pos, 1))
			_put(TOWN, pos, _family_key("town/%d" % level, variant(pos, 3)))
	# TODO-WIRE: castles (castle/<level>/<v>) need the castle levels of step 2; the castle hexes are not in MapData yet.


func _roads(_map: MapData) -> void:
	# TODO-WIRE: roads (road/dirt/<mask>, road/paved/<mask>, bridge/<road>/<river>) need the road edges of step 2.
	# The road layer stays empty until then.
	pass


static func _single_bit(mask: int) -> int:
	for i in 6:
		if mask == 1 << i:
			return i
	return -1
