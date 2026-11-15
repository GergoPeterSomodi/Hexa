## The map prototype's hex grid (docs/design/map/04-wfc-model.md section 3): pointy-top hexes, odd rows shifted half a
## hex to the right, about 28 km across. A hex is Vector2i(column, row). Positions in kilometres run from the north-west
## corner of the region window: x grows east, y grows south. The same formulas as tools/worldmap/extract_heights.py,
## which wrote the heights; the GUT test checks them against that script's numbers.
##
## Edges are numbered anticlockwise from east (0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE), as in 04 section 3. The edge a hex
## calls d is the edge its neighbour calls (d + 3) % 6.
class_name HexGrid
extends RefCounted

const SQRT3 := 1.7320508075688772
## Corners are numbered 0 at the top, then anticlockwise (corner k sits at angle -90 + 60 * k degrees, y down).
## EDGE_CORNERS[d] are the two corners that make the edge in direction d.
const EDGE_CORNERS: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(0, 1), Vector2i(5, 0), Vector2i(4, 5), Vector2i(3, 4), Vector2i(2, 3),
]
const _EVEN_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const _ODD_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1),
]

var hex_w_km: float  # centre to centre across a row
var hex_r_km: float  # centre to corner
var hex_h_km: float  # distance between rows
var deg_km: float  # kilometres per degree of latitude (and of longitude times cos(ref_lat))
var ref_lat: float
var lon_west: float
var lat_north: float
var _cos_ref: float


func _init(p_hex_w_km: float, p_deg_km: float, p_ref_lat: float, p_lon_west: float, p_lat_north: float) -> void:
	hex_w_km = p_hex_w_km
	hex_r_km = p_hex_w_km / SQRT3
	hex_h_km = 1.5 * hex_r_km
	deg_km = p_deg_km
	ref_lat = p_ref_lat
	lon_west = p_lon_west
	lat_north = p_lat_north
	_cos_ref = cos(deg_to_rad(p_ref_lat))


## Kilometres from the north-west corner of the window for a longitude and latitude.
func km_of(lon: float, lat: float) -> Vector2:
	return Vector2((lon - lon_west) * deg_km * _cos_ref, (lat_north - lat) * deg_km)


func lonlat_of(km: Vector2) -> Vector2:
	return Vector2(lon_west + km.x / (deg_km * _cos_ref), lat_north - km.y / deg_km)


## The centre of a hex, in kilometres.
func centre_km(hex: Vector2i) -> Vector2:
	return Vector2(
		hex_w_km * (float(hex.x) + 0.5) + float(hex.y & 1) * hex_w_km / 2.0,
		hex_r_km + hex_h_km * float(hex.y))


## The hex that holds a point in kilometres (axial rounding of the cube coordinates).
func hex_of_km(km: Vector2) -> Vector2i:
	var px := km.x - hex_w_km / 2.0
	var py := km.y - hex_r_km
	var q := (SQRT3 / 3.0 * px - py / 3.0) / hex_r_km
	var r := (2.0 / 3.0 * py) / hex_r_km
	var s := -q - r
	var rq: float = floorf(q + 0.5)
	var rr: float = floorf(r + 0.5)
	var rs: float = floorf(s + 0.5)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	var row := int(rr)
	# (row - row & 1) is even, so >> 1 is the exact halving (integer division would be an error here).
	var col := int(rq) + ((row - (row & 1)) >> 1)
	return Vector2i(col, row)


func hex_of(lon: float, lat: float) -> Vector2i:
	return hex_of_km(km_of(lon, lat))


## The six neighbours of a hex in edge order (0 E, 1 NE, 2 NW, 3 W, 4 SW, 5 SE).
func neighbours(hex: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dirs: Array[Vector2i] = _ODD_DIRS if (hex.y & 1) == 1 else _EVEN_DIRS
	for d: Vector2i in dirs:
		out.append(hex + d)
	return out


func neighbour(hex: Vector2i, direction: int) -> Vector2i:
	var dirs: Array[Vector2i] = _ODD_DIRS if (hex.y & 1) == 1 else _EVEN_DIRS
	return hex + dirs[direction]


## The edge direction from a to its neighbour b, or -1 when b is not next to a.
func direction_of(a: Vector2i, b: Vector2i) -> int:
	for d: int in 6:
		if neighbour(a, d) == b:
			return d
	return -1


## The key of the edge between two neighbouring hexes: both orders give one key (Vector4i with the smaller hex first).
static func edge_key(a: Vector2i, b: Vector2i) -> Vector4i:
	if b.x < a.x or (b.x == a.x and b.y < a.y):
		return Vector4i(b.x, b.y, a.x, a.y)
	return Vector4i(a.x, a.y, b.x, b.y)


static func edge_hexes(key: Vector4i) -> Array[Vector2i]:
	return [Vector2i(key.x, key.y), Vector2i(key.z, key.w)]


## The six corners of a hex in kilometres, in corner order.
func corners_km(hex: Vector2i) -> PackedVector2Array:
	var centre := centre_km(hex)
	var out := PackedVector2Array()
	for k: int in 6:
		var angle := deg_to_rad(-90.0 + 60.0 * float(k))
		out.append(centre + Vector2(hex_r_km * cos(angle), hex_r_km * sin(angle)))
	return out


## The two end points, in kilometres, of the edge between two neighbouring hexes.
func edge_segment_km(a: Vector2i, b: Vector2i) -> PackedVector2Array:
	var d := direction_of(a, b)
	if d < 0:
		return PackedVector2Array()
	var corners := corners_km(a)
	var pair := EDGE_CORNERS[d]
	return PackedVector2Array([corners[pair.x], corners[pair.y]])
