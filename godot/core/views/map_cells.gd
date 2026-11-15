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


## {layer name: tile name} for every layer of LAYERS; "" means no tile on that layer (so a changed hex can be
## compared layer by layer with what is shown, and what is gone is cleared).
static func of_hex(map: MapData, state: MapState, hex: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	for layer_name: String in LAYERS:
		out[layer_name] = ""
	var i := map.index_of(hex)
	if i < 0:
		return out
	out["grid"] = GRID_TILE
	if map.land[i] == 0:
		var beside := false
		for d: int in 6:
			beside = beside or map.is_land(map.neighbour(hex, d))
		out["sea"] = MapTiles.sea_of(map.depth[i], beside, hex)
		return out
	var height := float(map.height_m[i])
	var cover := MapTiles.cover_name(map.cover[i])
	var relief_level := int(map.relief[i])
	var sea_near: Array[bool] = []
	var heights := PackedFloat32Array()
	var covers: Array[String] = []
	var river_mask := 0
	var road_mask := 0  # roads of quality 2 and up: the trees do not make way for a track
	var crest := false
	for d: int in 6:
		var n := map.neighbour(hex, d)
		var j := map.index_of(n)
		var land := j >= 0 and map.land[j] == 1
		sea_near.append(j >= 0 and map.land[j] == 0)
		heights.append(float(map.height_m[j]) if land else height)
		covers.append(MapTiles.cover_name(map.cover[j]) if land else "")
		var e := map.edge_index(hex, d)
		if e >= 0:
			if map.river[e] > 0:
				river_mask |= 1 << d
			if map.road[e] >= 2:
				road_mask |= 1 << d
			crest = crest or map.crest[e] == 1
	var piece := piece_of(map, state, hex)
	var built := not piece.is_empty()
	var mask := MapTiles.coast_mask(sea_near)
	var place := _place_of(map, i)
	var port := bool(place.get("port", false))
	var carved := built and str(piece["addon_mode"]) == "carved" and MapTiles.bay_fits(mask)
	out["ground"] = MapTiles.ground_of(map.cover[i], height, hex)
	var tone := MapTiles.slope_tone(height, heights)
	out["shade"] = "shade/%d" % tone.x if tone.x > 0 else ""
	out["light"] = "light/%d" % tone.y if tone.y > 0 else ""
	out["coast"] = MapTiles.coast(mask, hex, relief_level, port, carved)
	var relief := MapTiles.relief(relief_level, crest, built, road_mask != 0, hex)
	out["relief"] = relief
	for d: int in 6:
		out["trees%d" % d] = MapTiles.trees(d, cover, height, covers[d], (river_mask >> d) & 1 == 1,
			(road_mask >> d) & 1 == 1, built, relief != "", hex)
	if not built:
		return out
	var family := str(piece["family"])
	var extra := str(piece["extra"])
	if family == "harbour" or family == "salt":
		extra = MapTiles.sea_side(mask)
	for part: String in PIECE_PARTS:
		out["piece_" + part] = MapTiles.piece(family, int(piece["level"]), int(piece["variant"]), bool(piece["mirror"]),
			extra, part)
	if int(piece["addon"]) > 0 and mask != 0:
		var side := "carved" if carved else MapTiles.sea_side(mask)
		for part: String in ADDON_PARTS:
			var layer_name := "addon" if part == "front" else "addon_" + part
			out[layer_name] = MapTiles.piece("harbour_addon", int(piece["addon"]), int(piece["variant"]),
				bool(piece["mirror"]), side, part)
	return out


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
