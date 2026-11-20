## Map mode colours, height ramp, palette packing, and pixel-to-hex lookup
## (docs/architecture/m2-build-spec.md sections 4.6 and 5.7).
## Pure core/views/ code: no nodes, no engine calls; mirrors mode_overlay.gdshader.
class_name MapModes
extends RefCounted

enum Mode { TERRAIN, OWNER, RELIEF }  # keys 1, 2, 3

const TINT_ALPHA := 0.14
const OWNER_ALPHA := 0.55
const RELIEF_ALPHA := 0.65
const HOT_ALPHA := 0.20
const HOT_LIGHTEN := 0.15
const PALETTE_SIZE := 256
const HEIGHT_STEP_M := 16
const HEIGHT_STEP_SHIFT := 4  # HEIGHT_STEP_M is 1 << 4
const RELIEF_STOPS: Array[Array] = [
	[0, Color("#4f8a4a")],
	[150, Color("#79a557")],
	[400, Color("#b7b56a")],
	[800, Color("#c49a5c")],
	[1300, Color("#a2744c")],
	[1900, Color("#8e7f74")],
	[2500, Color("#c9c7c4")],
	[3200, Color("#f4f5f8")],
]

const DEFAULT_UNOWNED := Color("#d8ccb0")
## The works card's tint (Tokens.GOOD and Tokens.BAD, whose values these are: a view does not read the shell).
const DELTA_GOOD := Color("#7fc98a")
const DELTA_BAD := Color("#f0806a")
const DELTA_ALPHA := 0.35

static var _cached_ramp := PackedColorArray()


## The card's tint of a change in ducats a year: DELTA_GOOD at a gain, DELTA_BAD at a loss, alpha 0.35; no tint (clear)
## for no change.
static func delta_colour(delta: int) -> Color:
	if delta == 0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var base := DELTA_GOOD if delta > 0 else DELTA_BAD
	return Color(base.r, base.g, base.b, DELTA_ALPHA)


## The cell under a map pixel, matching TileMapLayer.local_to_map and mode_overlay.gdshader.
static func hex_at_px(px: Vector2) -> Vector2i:
	var half_w := float(MapTiles.CELL.x) * 0.5
	var half_h := float(MapTiles.CELL.y) * 0.5
	var ux := px.x - half_w
	var uy := px.y - half_h
	var r := uy / MapTiles.ROW
	var q := ux / float(MapTiles.CELL.x) - 0.5 * r
	var s := -q - r
	var rq := floorf(q + 0.5)
	var rr := floorf(r + 0.5)
	var rs := floorf(s + 0.5)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	var row := int(rr)
	var col := int(rq) + ((row - (row & 1)) >> 1)
	return Vector2i(col, row)


## Encodes each hex's elevation as 1 byte (0 = sea, 1..255 = 1 + clampi(height_m / 16, 0, 254)).
static func height_bytes(map: MapData) -> PackedByteArray:
	if map == null:
		return PackedByteArray()
	var n := map.hex_count()
	var out := PackedByteArray()
	out.resize(n)  # zero: sea
	var land := map.land
	var heights := map.height_m
	for i: int in n:  # (a shift floors a negative height as floori does)
		if land[i] != 0:
			out[i] = 1 + clampi(heights[i] >> HEIGHT_STEP_SHIFT, 0, 254)
	return out


## 256-entry colour ramp indexed by height byte (0 = transparent sea, 1..255 = elevation stops).
static func relief_ramp() -> PackedColorArray:
	return _ramp().duplicate()


## Packs a 256-entry palette: index 0 is unowned, index id (1..255) is colours[id - 1].
static func palette_from(colours: PackedColorArray, unowned: Color) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(PALETTE_SIZE)
	out.fill(Color(0.0, 0.0, 0.0, 0.0))
	out[0] = unowned
	var count := mini(colours.size(), PALETTE_SIZE - 1)
	for i: int in count:
		out[i + 1] = colours[i]
	return out


## Fragment colour for one (owner_id, height_byte) pair; matches mode_overlay.gdshader.
static func colour_of(mode: int, owner_id: int, height_byte: int, palette: PackedColorArray,
		tint_on: bool, hot_id: int) -> Color:
	if height_byte <= 0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var base := Color(0.0, 0.0, 0.0, 0.0)
	var alpha := 0.0
	match mode:
		Mode.TERRAIN:
			if not tint_on or owner_id <= 0 or owner_id >= palette.size():
				return Color(0.0, 0.0, 0.0, 0.0)
			base = palette[owner_id]
			alpha = TINT_ALPHA
		Mode.OWNER:
			if owner_id < 0 or owner_id >= palette.size():
				return Color(0.0, 0.0, 0.0, 0.0)
			base = palette[owner_id]
			alpha = OWNER_ALPHA
		Mode.RELIEF:
			var ramp := _ramp()
			base = ramp[clampi(height_byte, 0, PALETTE_SIZE - 1)]
			alpha = RELIEF_ALPHA
		_:
			return Color(0.0, 0.0, 0.0, 0.0)
	if hot_id > 0 and owner_id == hot_id:
		base = base.lerp(Color.WHITE, HOT_LIGHTEN)
		alpha += HOT_ALPHA
	return Color(base.r, base.g, base.b, alpha)


## Available map modes for `game`: `[TERRAIN, OWNER, RELIEF]`, omitting `OWNER` in a map-only game.
static func modes(game: Game) -> Array[int]:
	if game != null and game.has_countries():
		return [Mode.TERRAIN, Mode.OWNER, Mode.RELIEF]
	return [Mode.TERRAIN, Mode.RELIEF]


## 256-entry palette for `game` using standard country colours or colour-blind safe colours.
static func palette(game: Game, colour_blind: bool) -> PackedColorArray:
	if game == null or game.defs == null:
		return palette_from(PackedColorArray(), DEFAULT_UNOWNED)
	if not game.has_countries() or game.scenario == null:
		return palette_from(PackedColorArray(), game.defs.unowned_colour)
	return palette_from(game.scenario.colours(game.defs, colour_blind), game.defs.unowned_colour)


## Overlay colour for `hex` in `game`, matching `colour_of` and `mode_overlay.gdshader`.
static func colour_at(game: Game, mode: int, hex: Vector2i, pal: PackedColorArray,
		tint_on: bool, hot_id: int) -> Color:
	if game == null or game.map == null or not game.map.has(hex):
		return Color(0.0, 0.0, 0.0, 0.0)
	var idx := game.map.index_of(hex)
	var height_byte := _height_byte_at(game.map, idx)
	var oid := Territory.owner_id(game, hex)
	return colour_of(mode, oid, height_byte, pal, tint_on, hot_id)


static func _height_byte_at(map: MapData, idx: int) -> int:
	if map.land[idx] == 0:
		return 0
	return 1 + clampi(floori(float(map.height_m[idx]) / float(HEIGHT_STEP_M)), 0, 254)


static func _ramp() -> PackedColorArray:
	if _cached_ramp.size() == PALETTE_SIZE:
		return _cached_ramp
	_cached_ramp.resize(PALETTE_SIZE)
	_cached_ramp[0] = Color(0.0, 0.0, 0.0, 0.0)
	for b: int in range(1, PALETTE_SIZE):
		_cached_ramp[b] = _colour_at_metres((b - 1) * HEIGHT_STEP_M)
	return _cached_ramp


static func _colour_at_metres(metres: int) -> Color:
	var last_idx := RELIEF_STOPS.size() - 1
	if metres <= int(RELIEF_STOPS[0][0]):
		return RELIEF_STOPS[0][1] as Color
	for i: int in range(1, RELIEF_STOPS.size()):
		var hi_m := int(RELIEF_STOPS[i][0])
		if metres <= hi_m:
			var lo_m := int(RELIEF_STOPS[i - 1][0])
			var lo_c := RELIEF_STOPS[i - 1][1] as Color
			var hi_c := RELIEF_STOPS[i][1] as Color
			var t := float(metres - lo_m) / float(hi_m - lo_m)
			return lo_c.lerp(hi_c, t)
	return RELIEF_STOPS[last_idx][1] as Color
