## Where the map view puts each hex in world pixels, and the size of the baked grid tile.
## World pixels are the hexgrid geometry at the bake's hex radius 60, which is sqrt(3) times the 1x sprite size of
## core/hexgrid.gd: centre(pos) equals HexGrid.hex_center(pos) * SQRT3 for every hex (a test checks it).
## The tile layers use the baked tile (104 x 120, the atlas index's tile_size); their scale and offset map that tile
## grid onto the exact hexgrid geometry (see tile_layer_scale and tile_layer_offset). Pure functions, no engine calls.
class_name MapGeometry
extends RefCounted

const SQRT3 := 1.7320508075688772  # math.sqrt(3); the same value as HexGrid.SQRT3
const TILE_W := 104  # the baked grid tile, whole pixels (godot/assets/baked/index.json tile_size)
const TILE_H := 120
const ROW_STEP := 90.0  # the row step at radius 60: 1.5 x 60


## World width of one hex (flat side to flat side) at radius 60: sqrt(3) x 60.
static func hex_width() -> float:
	return HexGrid.HEX_W * SQRT3


## The centre of a hex in world pixels.
static func centre(pos: Vector2i) -> Vector2:
	return HexGrid.hex_center(pos) * SQRT3


## The hex that holds a world point (the nearest hex centre).
static func pixel_to_hex(point: Vector2) -> Vector2i:
	return HexGrid.pixel_to_hex(point / SQRT3)


## Size of the whole map in world pixels, from the top-left corner (0, 0) to the far corner of the last hex.
static func map_size(cols: int, rows: int) -> Vector2:
	return Vector2(float(cols) * hex_width() + hex_width() * 0.5, float(rows) * ROW_STEP + float(TILE_H) * 0.5)


## Scale of a TileMapLayer whose tiles are TILE_W wide: exact world width of a hex over the whole-pixel tile width.
static func tile_layer_scale() -> Vector2:
	return Vector2(hex_width() / float(TILE_W), 1.0)


## Position of a TileMapLayer: the tile centre sits TILE_H / 2 below the row top, the hexgrid centre sits
## HEX_H / 2 x sqrt(3) below it; the difference is the offset.
static func tile_layer_offset() -> Vector2:
	return Vector2(0.0, HexGrid.HEX_H * 0.5 * SQRT3 - float(TILE_H) * 0.5)
