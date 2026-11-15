## The crossing tiles of the map (docs/architecture/m1-build-spec.md sections 3.3 and 6): the fords, bridges, ferries and
## pass marks that stand on an edge where a road meets water or a saddle. MapData.crossing says which (0 none, 1 ford,
## 2 bridge_wood, 3 bridge_stone, 4 ferry, 5 pass); this names the tile for each edge, `mark/<kind>/<d>` (baked by
## tools/worldmap/tileset_bake/mark_tiles.py), `d` the direction of the edge from the hex that holds the tile.
##
## An edge belongs to one hex (directions 0 E, 1 NE, 2 NW; MapData.edge_index), so that hex holds its tile. A hex can own
## up to three crossings, so the tiles go on three layers, `crossing0` to `crossing2`, one per owned direction; they are
## standing things (the same y-sorted group as the trees). Pure: no nodes, no files.
class_name Crossings
extends RefCounted

## MapData.crossing value -> kind (index 0 is "none").
const KINDS: Array[String] = ["", "ford", "bridge_wood", "bridge_stone", "ferry", "pass"]
## The directions a hex owns an edge in, and the layer of each (layer "crossing<d>").
const OWNED := 3
const LAYERS: Array[String] = ["crossing0", "crossing1", "crossing2"]


## The tile name of a crossing of `kind` (1 to 5) on the edge in direction `d` (0 to 5), "" for none or out of range.
static func tile_name(kind: int, d: int) -> String:
	if kind <= 0 or kind >= KINDS.size() or d < 0 or d > 5:
		return ""
	return "mark/%s/%d" % [KINDS[kind], d]


## {layer: tile name} for the three crossing layers of `hex`, "" where the edge has no crossing (so a layer can be cleared).
## Reads the three edges the hex owns (MapData.crossing).
static func of_hex(map: MapData, hex: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	for d: int in OWNED:
		var e := map.edge_index(hex, d)
		var kind := int(map.crossing[e]) if e >= 0 and e < map.crossing.size() else 0
		out[LAYERS[d]] = tile_name(kind, d)
	return out


## Every crossing of the map as [{hex, d, kind, tile}], in hex order: for a test or a whole-map fill.
static func all_of(map: MapData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in map.hex_count():
		var hex := map.hex_of(i)
		for d: int in OWNED:
			var kind := int(map.crossing[OWNED * i + d]) if OWNED * i + d < map.crossing.size() else 0
			if kind > 0:
				out.append({"hex": hex, "d": d, "kind": kind, "tile": tile_name(kind, d)})
	return out


## Every tile name a map can ask for (all kinds in all six directions): the names the bake must hold.
static func all_names() -> Array[String]:
	var out: Array[String] = []
	for kind: int in range(1, KINDS.size()):
		for d: int in 6:
			out.append(tile_name(kind, d))
	return out
