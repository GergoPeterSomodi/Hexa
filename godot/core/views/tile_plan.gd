## The tile layers of the map view: which baked sprite each hex shows on each layer, as Python's map view draws the
## tile zoom (docs/design/art-inventory.md, "How Godot layers the pieces"). Pure: the shell turns each key into a cell
## of the TileSet. Layers: ground, coast (or a river mouth), river, road (or a bridge), decoration, town (a town, its
## harbour or gates, or a castle).
##
## Edge masks are bit e of hexgrid.neighbours order (0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE), the order of the atlas keys.
## Godot's TileMap neighbour order is never used: each key is chosen here by its mask.
##
## Towns and castles come from the provinces' settlement and castle levels (Python's overlay_desc rule); a map without
## provinces (the small fixtures of the tests) falls back to the city sizes.
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
var _rivers: Dictionary[Vector2i, int] = {}  # hex -> river edge mask (before the sea is taken away)
var _roads: Dictionary[Vector2i, int] = {}  # hex -> road edge mask
var _harbours: Dictionary[Vector2i, bool] = {}  # coastal towns with a harbour piece (no coast of their own)
var _towns: Dictionary[Vector2i, bool] = {}  # hexes with a town piece or a castle


## Builds every layer for the map. The atlas must be loaded (AtlasIndex.load_index).
static func build(map: MapData, atlas: AtlasIndex) -> TilePlan:
	var plan := TilePlan.new()
	plan._atlas = atlas
	for name: String in LAYERS:
		plan.layers[name] = {}
	plan._rivers = _edge_masks(map.rivers)
	plan._roads = _edge_masks_of_paths(map.road_paths)
	var mouths: Dictionary[Vector2i, bool] = {}
	plan._ground(map)
	plan._rivers_layer(map, mouths)
	plan._towns_layer(map)
	plan._coast(map, mouths)
	plan._roads_layer(map)
	plan._decoration(map)
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


## Town level of a city size (its population in thousands, the Python CITIES table), for maps without provinces:
## 40 or more is a city (5), 60 or more a great city (6), else a market town (3).
static func town_level(size: int) -> int:
	if size >= 40:
		return 6 if size >= 60 else 5
	return 3


## Town level and castle level of a province, as Python's overlay_desc: a village (settlement 1) is level 2, a town
## (settlement 2) is 3, or 4 (walled) with a castle, a city (settlement 3) is 5, or 6 (great) at 60 or more people.
## A castle is drawn only where no town is, except that a village with a castle shows the castle.
## Returns Vector2i(town level, castle level), with 0 for none.
static func settlement_pieces(prov: Province) -> Vector2i:
	var s := prov.settlement
	var c := prov.castle
	if s > 0:
		var town := 0
		if s == 1:
			town = 2
		elif s == 2:
			town = 4 if c > 0 else 3
		else:
			town = 6 if prov.pop() >= 60.0 else 5
		if s == 1 and c > 0:
			return Vector2i(0, c)
		return Vector2i(town, 0)
	return Vector2i(0, c)


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


## Number of set bits of a mask.
static func bit_count(mask: int) -> int:
	var n := 0
	var m := mask
	while m != 0:
		n += m & 1
		m >>= 1
	return n


## Edge masks of a set of paths (each path joins its consecutive hexes).
static func _edge_masks_of_paths(paths: Array) -> Dictionary[Vector2i, int]:
	var edges: Dictionary[Vector2i, int] = {}
	for path: Array in paths:
		for i in range(1, path.size()):
			var a: Vector2i = path[i - 1]
			var b: Vector2i = path[i]
			if HexGrid.distance(a, b) != 1:
				continue
			edges[a] = edges.get(a, 0) | edge_bit(a, b)
			edges[b] = edges.get(b, 0) | edge_bit(b, a)
	return edges


## Edge masks of the rivers: the river names map to their hex paths.
static func _edge_masks(rivers: Dictionary) -> Dictionary[Vector2i, int]:
	var paths: Array = []
	for name: String in rivers.keys():
		paths.append(rivers[name])
	return _edge_masks_of_paths(paths)


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


func _rivers_layer(map: MapData, mouths: Dictionary[Vector2i, bool]) -> void:
	for pos: Vector2i in _rivers.keys():
		var sea := sea_mask(map, pos)
		var river: int = _rivers[pos] & ~sea
		if river == 0:
			continue
		var edge := _single_bit(river)
		if sea != 0 and edge >= 0:
			# A river mouth: its piece holds the river and the coast of the one edge the river comes in by.
			mouths[pos] = true
			_put(RIVER, pos, "mouth/%d/%d" % [edge, sea])
		else:
			_put(RIVER, pos, _family_key("river/%d" % river, variant(pos, 3)))


## The town (or castle) of each hex. Sets _towns and _harbours for the other layers.
func _towns_layer(map: MapData) -> void:
	if map.provinces.is_empty():
		for pos: Vector2i in map.city_names.keys():
			if map.is_land(pos):
				_town_at(map, pos, Vector2i(town_level(map.city_sizes.get(pos, 1)), 0))
		return
	for pos: Vector2i in map.provinces.keys():
		var prov: Province = map.provinces[pos]
		var pieces := settlement_pieces(prov)
		if pieces.x > 0 or pieces.y > 0:
			_town_at(map, pos, pieces)


## A town: the harbour on the coast; else the gates where roads meet it; else the plain town. A castle (no town) is its
## own piece.
func _town_at(map: MapData, pos: Vector2i, pieces: Vector2i) -> void:
	var level := pieces.x
	if level > 0:
		var sea := sea_mask(map, pos)
		var harbour := "harbour/%d/%d" % [level, sea]
		if sea != 0 and _atlas.has(harbour):
			_harbours[pos] = true
			_put(TOWN, pos, harbour)
		else:
			var road: int = _roads.get(pos, 0) & ~sea
			var gates := "town/%d/gates/%d" % [level, road]
			if road != 0 and _atlas.has(gates):
				_put(TOWN, pos, gates)
			else:
				_put(TOWN, pos, _family_key("town/%d" % level, variant(pos, 3)))
		_towns[pos] = true
	elif pieces.y > 0:
		_put(TOWN, pos, _family_key("castle/%d" % pieces.y, variant(pos, 3)))
		_towns[pos] = true


func _coast(map: MapData, mouths: Dictionary[Vector2i, bool]) -> void:
	for pos: Vector2i in map.land_hexes():
		var sea := sea_mask(map, pos)
		if sea == 0 or mouths.has(pos) or _harbours.has(pos):
			continue
		_put(COAST, pos, _family_key("coast/%d" % sea, variant(pos, 3)))


## Roads and bridges: a road piece by its edge mask on every road hex, except where a town holds the street. A road
## over a river, with two edges of each, is a bridge where the key exists.
func _roads_layer(map: MapData) -> void:
	for pos: Vector2i in map.roads.keys():
		if _towns.has(pos):
			continue
		var sea := sea_mask(map, pos)
		var road: int = _roads.get(pos, 0) & ~sea
		if road == 0:
			continue
		var river: int = _rivers.get(pos, 0) & ~sea
		if bit_count(road) == 2 and bit_count(river) == 2:
			var bridge := "bridge/%d/%d" % [road, river]
			if _atlas.has(bridge):
				_put(ROAD, pos, bridge)
				continue
		_put(ROAD, pos, "road/dirt/%d" % road)


## Trees, rocks, fields and hamlets, by Python's decorations_for: only on open land of plains, steppe or savanna that
## has no building, no river, coast or road. Fields and hamlets need an owner (a hamlet also more than 10 people).
func _decoration(map: MapData) -> void:
	for pos: Vector2i in map.land_hexes():
		var kind: String = map.terrain[pos]
		if kind != "plains" and kind != "steppe" and kind != "savanna":
			continue
		if map.city_names.has(pos) or _rivers.has(pos) or _roads.has(pos) or sea_mask(map, pos) != 0:
			continue
		var prov: Province = map.provinces.get(pos) as Province
		if prov != null and (prov.settlement > 0 or prov.castle > 0 or prov.works > 0):
			continue
		var h := int((pos.x * 73856093) ^ (pos.y * 19349663)) & 0xFFFF
		var owned := prov != null and prov.owner != ""
		var kind_name := ""
		if h % 6 == 0:
			kind_name = "trees"
		elif h % 9 == 1:
			kind_name = "rocks"
		elif owned and h % 7 == 2:
			kind_name = "fields"
		elif owned and prov.pop() > 10.0 and h % 11 == 3:
			kind_name = "hamlet"
		if kind_name != "":
			_put(DECO, pos, "deco/%s/%d" % [kind_name, h % 4])


static func _single_bit(mask: int) -> int:
	for i in 6:
		if mask == 1 << i:
			return i
	return -1
