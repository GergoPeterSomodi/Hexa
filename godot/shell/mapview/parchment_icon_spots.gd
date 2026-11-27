## Where the goods icons of the parchment may lie (docs/architecture/map-overview-build-spec.md R7, R10; used by
## ParchmentLabels): the districts of a good near the screen, and the spots an icon takes in its hex. An icon's box holds
## its disc and, just under it, the pips' row.
class_name ParchmentIconSpots
extends RefCounted

## The disc's radius as a share of the hex's width on screen (a disc a little over half the hex), never under the least
## nor over the most; the spots tried, as shares of the hex's width.
const HEX_SHARE := 0.28
const MIN_RADIUS_PX := 6.0
## The Kit icon's side as a share of the disc's radius. The goods icons are ICON_TEXTURE_PX textures, never drawn above
## ICON_MAX_SCALE times that (they blur), so the disc stops growing at MAX_RADIUS_PX.
const GLYPH_SHARE := 1.4
const ICON_TEXTURE_PX := 24.0
const ICON_MAX_SCALE := 2.0
const MAX_RADIUS_PX := ICON_MAX_SCALE * ICON_TEXTURE_PX / GLYPH_SHARE
const SPOTS: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.0, -0.18), Vector2(0.0, 0.14), Vector2(-0.18, 0.0),
	Vector2(0.18, 0.0)]


static func radius(hex_px: float) -> float:
	return clampf(HEX_SHARE * hex_px, MIN_RADIUS_PX, MAX_RADIUS_PX)


## The side the Kit icon is drawn at in a disc of radius `r`.
static func glyph_side(r: float) -> float:
	return GLYPH_SHARE * r


## The districts that make the good `good` on hexes that may show in `area` (map px), row by row, each
## [column, row, stage]; `goods` is ParchmentView.goods_bytes. They are searched a row's visible stretch at a time, so a
## change of good reads nothing but the screen.
static func districts(map: MapData, goods: PackedByteArray, good: int, area: Rect2) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var first := maxi(0, floori((area.position.y - 51.0) / MapTiles.ROW))
	var last := mini(map.rows - 1, ceili((area.end.y - 51.0) / MapTiles.ROW))
	var left := maxi(0, floori(area.position.x / MapTiles.CELL.x) - 1)
	var right := mini(map.cols - 1, ceili(area.end.x / MapTiles.CELL.x))
	if left > right:
		return out
	var want := good + 1
	var stride := ParchmentView.GOODS_STRIDE
	for row: int in range(first, last + 1):
		var from := row * map.cols + left
		var line := goods.slice(from * stride, (row * map.cols + right + 1) * stride)
		var found := line.find(want)
		while found >= 0:
			if found % stride == 0:
				@warning_ignore("integer_division")
				var col := left + found / stride
				out.append(Vector3i(col, row, int(line[found + 1])))
			found = line.find(want, found + 1)
	return out


## The boxes an icon may take in the hex of screen middle `middle`, first choice first; on a hex with a town's dot of
## radius `dot` (below 0: none) over it, beside it or under it.
static func boxes(middle: Vector2, hex_px: float, dot: float) -> Array[Rect2]:
	var r := radius(hex_px)
	var under := ParchmentLabels.PIP_GAP_PX + 2.0 * ParchmentLabels.pip_radius(r)  # the pips' row under the disc
	var level := -under * 0.5  # the disc and its pips sit evenly about the spot
	var spots: Array[Vector2] = []
	if dot >= 0.0:
		var away := r + dot + 2.0
		spots = [Vector2(0.0, -away - under), Vector2(-away, level), Vector2(away, level), Vector2(0.0, away)]
	else:
		for share: Vector2 in SPOTS:
			spots.append(share * hex_px + Vector2(0.0, level))
	var out: Array[Rect2] = []
	for spot: Vector2 in spots:
		out.append(Rect2(middle + spot - Vector2(r, r), Vector2(r * 2.0, r * 2.0 + under)))
	return out
