## The far zoom's one picture: a few pixels a hex, built from the map's facts (docs/architecture/m1-build-spec.md,
## section 7). No nodes, no files: it returns RGBA8 bytes that the shell puts in one texture.
## `map` and `state` are read by field name, so a MapData and a MapState work, and so does a plain Dictionary with
## the same keys (until T1 lands the tests use that): map = {cols, rows, land, height_m, cover, depth, climate},
## state = {main_use}; every array is indexed row * cols + col.
## Covers by number are the tile names' order: farmland, grassland, woods, marsh, rock, snow, tundra, sand; depth
## 0 shelf, 1 sea, 2 deep; climate 0 snow, 1 frost, 2 mild.
class_name FarPicture
extends RefCounted

const PX := Vector2i(4, 3)  # picture px a hex; odd rows are shifted 2 px
const SHIFT := 2
## Base colours of the ground tiles (tools/worldmap/tileset_bake/flat_tiles.py), by cover number.
const COVER_COLOURS: Array[Color] = [
	Color8(178, 198, 98), Color8(146, 186, 86), Color8(112, 164, 78), Color8(128, 162, 98),
	Color8(170, 156, 130), Color8(172, 160, 138), Color8(150, 160, 112), Color8(234, 216, 162),
]
const GREEN_COVERS := 4  # covers 0 to 3 go paler with height
const WOODS := 2
const HIGH_TINT := Color8(190, 206, 128)
const ALPINE := Color8(172, 160, 138)
const SEA_COLOURS: Array[Color] = [Color8(84, 155, 201), Color8(71, 143, 192), Color8(60, 127, 183)]  # shelf, sea, deep
const SNOW := Color8(244, 246, 250)
const BUILT_WARM := Color8(214, 168, 96)  # a built hex is a little warmer
const ROOF := Color8(190, 70, 52)  # a settlement's dot
const SETTLEMENT := 1  # ImproveRules family ids
const CASTLE := 2
const _EVEN_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const _ODD_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1),
]


static func size_of(map: Variant) -> Vector2i:
	return Vector2i(PX.x * int(map.cols) + SHIFT, PX.y * int(map.rows) + 1)


## The picture pixels of a hex: its 4 x 3 block.
static func rect_of(hex: Vector2i) -> Rect2i:
	return Rect2i(PX.x * hex.x + SHIFT * (hex.y & 1), PX.y * hex.y, PX.x, PX.y)


## RGBA8, row by row. Pixels no hex covers (the margins) are transparent.
static func pixels(map: Variant, state: Variant) -> PackedByteArray:
	var size := size_of(map)
	var out := PackedByteArray()
	out.resize(size.x * size.y * 4)
	for r: int in int(map.rows):
		for c: int in int(map.cols):
			write_hex(out, map, state, Vector2i(c, r))
	return out


## Rewrites one hex's 12 pixels in a buffer made by pixels() (what a hex_changed does).
static func write_hex(buffer: PackedByteArray, map: Variant, state: Variant, hex: Vector2i) -> void:
	var width := size_of(map).x
	var rect := rect_of(hex)
	var base := colour_of(map, state, hex)
	var dot := _has_dot(state, int(map.cols), hex)
	for dy: int in PX.y:
		for dx: int in PX.x:
			var col := ROOF if dot and dy == 1 and (dx == 1 or dx == 2) else base
			var at := ((rect.position.y + dy) * width + rect.position.x + dx) * 4
			buffer[at] = col.r8
			buffer[at + 1] = col.g8
			buffer[at + 2] = col.b8
			buffer[at + 3] = 255


static func colour_of(map: Variant, state: Variant, hex: Vector2i) -> Color:
	var i := hex.y * int(map.cols) + hex.x
	if int(map.land[i]) == 0:
		var depth := 0 if _beside_land(map, hex) else int(map.depth[i])
		return SEA_COLOURS[clampi(depth, 0, 2)]
	var cover := clampi(int(map.cover[i]), 0, COVER_COLOURS.size() - 1)
	var height := float(map.height_m[i])
	var col := COVER_COLOURS[cover]
	if cover < GREEN_COVERS:
		col = col.lerp(HIGH_TINT, 0.1 * float(clampi(roundi(_smoothstep(100.0, 850.0, height) * 3.0), 0, 3)))
		if height > 1700.0 and cover != WOODS:
			col = col.lerp(ALPINE, 0.55)
	var climate := int(map.climate[i])
	if climate == 0:
		col = col.lerp(SNOW, 0.45)
	elif climate == 1:
		col = col.lerp(SNOW, 0.15)
	var tone := MapTiles.slope_tone(height, _neighbour_heights(map, hex, height))
	col = col.darkened(0.03 * float(tone.x))
	col = col.lerp(Color.WHITE, 0.03 * float(tone.y))
	if int(state.main_use[i]) != 0:
		col = col.lerp(BUILT_WARM, 0.22)
	return col


static func _has_dot(state: Variant, cols: int, hex: Vector2i) -> bool:
	var use := int(state.main_use[hex.y * cols + hex.x])
	return use == SETTLEMENT or use == CASTLE


static func _smoothstep(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _neighbour_of(hex: Vector2i, direction: int) -> Vector2i:
	var dirs: Array[Vector2i] = _ODD_DIRS if (hex.y & 1) == 1 else _EVEN_DIRS
	return hex + dirs[direction]


static func _on_map(map: Variant, hex: Vector2i) -> bool:
	return hex.x >= 0 and hex.y >= 0 and hex.x < int(map.cols) and hex.y < int(map.rows)


## A sea hex with land next to it shows the shelf (the tiles do the same).
static func _beside_land(map: Variant, hex: Vector2i) -> bool:
	for d: int in 6:
		var n := _neighbour_of(hex, d)
		if _on_map(map, n) and int(map.land[n.y * int(map.cols) + n.x]) == 1:
			return true
	return false


## The six neighbours' heights; a sea or missing neighbour counts as the hex's own (the shore is no slope).
static func _neighbour_heights(map: Variant, hex: Vector2i, own: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(6)
	for d: int in 6:
		var n := _neighbour_of(hex, d)
		var at := n.y * int(map.cols) + n.x
		out[d] = float(map.height_m[at]) if _on_map(map, n) and int(map.land[at]) == 1 else own
	return out
