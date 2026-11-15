## Which tile every layer of the map view shows on a hex, from the facts of the map (docs/architecture/m1-build-spec.md
## sections 3.3 and 5). The one place that decides a tile: it reads MapData (what is fixed) and MapState (what the
## player built), asks the rules of MapTiles for each name, and returns them by layer. No nodes, no files, no luck.
## Before M1 this logic lived in the trial scene (shell/mapview/trial/tile_trial.gd).
class_name MapCells
extends RefCounted

## The layers of TileMapView (shell/mapview/tile_map_view.gd) that a hex has a tile on. A test pins the two lists.
const LAYERS: Array[String] = [
	"grid", "ground", "shade", "light", "sea", "coast", "relief",
	"trees0", "trees1", "trees2", "trees3", "trees4", "trees5",
	"piece_ground", "piece_shadow", "piece_back", "piece_front", "addon_ground", "addon_shadow", "addon",
]
## The grid line tile (in the marks source of every set).
const GRID_TILE := "mark/grid"
const PIECE_PARTS: Array[String] = ["ground", "shadow", "back", "front"]
const ADDON_PARTS: Array[String] = ["ground", "shadow", "front"]  # a harbour's standing things are one tile


## Where a layer is in LAYERS (the order `fill_hex` writes its names in).
const AT_GRID := 0
const AT_GROUND := 1
const AT_SHADE := 2
const AT_LIGHT := 3
const AT_SEA := 4
const AT_COAST := 5
const AT_RELIEF := 6
const AT_TREES := 7  # six layers, one a wedge
const AT_PIECE := 13  # four layers: ground, shadow, back, front (PIECE_PARTS)
const AT_ADDON_GROUND := 17
const AT_ADDON_SHADOW := 18
const AT_ADDON := 19  # a harbour's standing things are one tile (its "front")


## {layer name: tile name} for every layer of LAYERS; "" means no tile on that layer (so a changed hex can be
## compared layer by layer with what is shown, and what is gone is cleared).
static func of_hex(map: MapData, state: MapState, hex: Vector2i) -> Dictionary:
	var names := PackedStringArray()
	names.resize(LAYERS.size())
	fill_hex(map, state, hex, names)
	var out: Dictionary = {}
	for k: int in LAYERS.size():
		out[LAYERS[k]] = names[k]
	return out


## The same names in the order of LAYERS, written into `out` (a PackedStringArray of LAYERS.size(); every slot is set).
## The fill of a whole map calls this for every hex, so it asks the map arrays what it needs and builds no dictionary.
static func fill_hex(map: MapData, state: MapState, hex: Vector2i, out: PackedStringArray) -> void:
	out.fill("")
	var cols := map.cols
	var rows := map.rows
	if hex.x < 0 or hex.y < 0 or hex.x >= cols or hex.y >= rows:
		return
	var i := hex.y * cols + hex.x
	out[AT_GRID] = GRID_TILE
	var grid := map.grid()
	if map.land[i] == 0:
		var beside := false
		for d: int in 6:
			var n := grid.neighbour(hex, d)
			if n.x >= 0 and n.y >= 0 and n.x < cols and n.y < rows and map.land[n.y * cols + n.x] == 1:
				beside = true
				break
		out[AT_SEA] = MapTiles.sea_of(map.depth[i], beside, hex)
		return
	var height := float(map.height_m[i])
	var cover := MapTiles.cover_name(map.cover[i])
	var relief_level := int(map.relief[i])
	var heights := PackedFloat32Array()
	heights.resize(6)
	var covers := PackedStringArray()
	covers.resize(6)
	var mask := 0  # MapTiles.coast_mask: bit d is set when the neighbour in direction d is sea
	var level_ground := true  # no neighbour is higher or lower: no slope to shade
	var river_mask := 0
	var road_mask := 0  # roads of quality 2 and up: the trees do not make way for a track
	var crest := false
	for d: int in 6:
		var n := grid.neighbour(hex, d)
		var j := n.y * cols + n.x if n.x >= 0 and n.y >= 0 and n.x < cols and n.y < rows else -1
		var land := j >= 0 and map.land[j] == 1
		if j >= 0 and not land:
			mask |= 1 << d
		var beside_height := float(map.height_m[j]) if land else height
		heights[d] = beside_height
		level_ground = level_ground and beside_height == height
		covers[d] = MapTiles.cover_name(map.cover[j]) if land else ""
		var e := 3 * i + d if d < 3 else (3 * j + d - 3 if j >= 0 else -1)  # MapData.edge_index
		if e >= 0:
			if map.river[e] > 0:
				river_mask |= 1 << d
			if map.road[e] >= 2:
				road_mask |= 1 << d
			crest = crest or map.crest[e] == 1
	var built := false
	var piece: Dictionary = {}
	var family_number := int(state.main_use[i]) if i < state.main_use.size() else ImproveRules.NONE
	if family_number > ImproveRules.NONE and family_number < ImproveRules.FAMILIES:
		piece = piece_of(map, state, hex)
		built = not piece.is_empty()
	var port := false
	if mask != 0 and map.place_id[i] >= 0 and map.place_id[i] < map.places.size():
		port = bool(map.places[map.place_id[i]].get("port", false))
	var carved := built and str(piece["addon_mode"]) == "carved" and MapTiles.bay_fits(mask)
	out[AT_GROUND] = MapTiles.ground_of(map.cover[i], height, hex)
	if not level_ground:  # (a flat hex has no tone: slope_tone gives 0, 0)
		var tone := MapTiles.slope_tone(height, heights)
		if tone.x > 0:
			out[AT_SHADE] = "shade/%d" % tone.x
		if tone.y > 0:
			out[AT_LIGHT] = "light/%d" % tone.y
	out[AT_COAST] = MapTiles.coast(mask, hex, relief_level, port, carved)
	var relief := MapTiles.relief(relief_level, crest, built, road_mask != 0, hex)
	out[AT_RELIEF] = relief
	if height <= 1800.0:  # (above it MapTiles.trees gives no tree on any wedge)
		for d: int in 6:
			out[AT_TREES + d] = MapTiles.trees(d, cover, height, covers[d], (river_mask >> d) & 1 == 1,
				(road_mask >> d) & 1 == 1, built, relief != "", hex)
	if not built:
		return
	var family := str(piece["family"])
	var extra := str(piece["extra"])
	if family == "harbour" or family == "salt":
		extra = MapTiles.sea_side(mask)
	for k: int in PIECE_PARTS.size():
		out[AT_PIECE + k] = MapTiles.piece(family, int(piece["level"]), int(piece["variant"]), bool(piece["mirror"]),
			extra, PIECE_PARTS[k])
	if int(piece["addon"]) > 0 and mask != 0:
		var side := "carved" if carved else MapTiles.sea_side(mask)
		for k: int in ADDON_PARTS.size():
			out[AT_ADDON_GROUND + k] = MapTiles.piece("harbour_addon", int(piece["addon"]), int(piece["variant"]),
				bool(piece["mirror"]), side, ADDON_PARTS[k])


## The hexes whose tiles can change when `hex` changes: the hex and its six neighbours (the ones on the map).
static func touched_by(map: MapData, hex: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if map.has(hex):
		out.append(hex)
	for d: int in 6:
		var n := map.neighbour(hex, d)
		if map.has(n):
			out.append(n)
	return out


## What stands on a hex ({} for a wild hex): the facts of Improve.piece_of, the one place that decides them.
static func piece_of(map: MapData, state: MapState, hex: Vector2i) -> Dictionary:
	return Improve.piece_of(map, state, hex)


## The place on a hex (a MapData.places entry), or {}.
static func _place_of(map: MapData, index: int) -> Dictionary:
	return Improve.place_of(map, map.hex_of(index))
