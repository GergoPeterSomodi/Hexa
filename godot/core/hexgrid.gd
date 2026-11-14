## Hex grid maths for the pointy-top, odd-r offset layout, as in hexa/hexgrid.py (the frozen Python reference).
## Positions are Vector2i(col, row); odd rows sit half a hex to the right. Pure functions, no engine calls.
class_name HexGrid
extends RefCounted

const SQRT3 := 1.7320508075688772  # math.sqrt(3) in Python
const HEX_W := 60.0  # sprite width, flat side to flat side
const HEX_H := 70.0  # sprite height
const RADIUS := HEX_W / SQRT3  # centre to corner
const ROW_H := RADIUS * 1.5  # vertical distance between rows

const _EVEN_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const _ODD_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1),
]


## The six neighbours, in the Python order (east, north-east, north-west, west, south-west, south-east for even rows).
static func neighbours(pos: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dirs: Array[Vector2i] = _ODD_DIRS if (pos.y & 1) == 1 else _EVEN_DIRS
	for d: Vector2i in dirs:
		out.append(pos + d)
	return out


static func to_cube(pos: Vector2i) -> Vector3i:
	# (row - row & 1) is even, so >> 1 is the exact halving that Python's // gives.
	var q: int = pos.x - ((pos.y - (pos.y & 1)) >> 1)
	return Vector3i(q, pos.y, -q - pos.y)


static func distance(a: Vector2i, b: Vector2i) -> int:
	var ca := to_cube(a)
	var cb := to_cube(b)
	return maxi(maxi(absi(ca.x - cb.x), absi(ca.y - cb.y)), absi(ca.z - cb.z))


## Every hex within `radius` steps of pos, in the Python order (row by row, then column).
static func within(pos: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in range(pos.y - radius, pos.y + radius + 1):
		for c in range(pos.x - radius - 1, pos.x + radius + 2):
			if distance(pos, Vector2i(c, r)) <= radius:
				out.append(Vector2i(c, r))
	return out


static func hex_center(pos: Vector2i, origin: Vector2 = Vector2.ZERO) -> Vector2:
	var x := origin.x + float(pos.x) * HEX_W + float(pos.y & 1) * HEX_W / 2.0 + HEX_W / 2.0
	var y := origin.y + float(pos.y) * ROW_H + HEX_H / 2.0
	return Vector2(x, y)


static func pixel_to_hex(point: Vector2, origin: Vector2 = Vector2.ZERO) -> Vector2i:
	var x := point.x - origin.x - HEX_W / 2.0
	var y := point.y - origin.y - HEX_H / 2.0
	var q := (SQRT3 / 3.0 * x - y / 3.0) / RADIUS
	var r := (2.0 / 3.0 * y) / RADIUS
	var s := -q - r
	# Round the fractional cube coordinates to the nearest hex, as hexgrid.py does.
	var rq := round_half_even(q)
	var rr := round_half_even(r)
	var rs := round_half_even(s)
	var dq := absf(float(rq) - q)
	var dr := absf(float(rr) - r)
	var ds := absf(float(rs) - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	var col := rq + ((rr - (rr & 1)) >> 1)
	return Vector2i(col, rr)


## Python's round() of a float: halves go to the even integer. GDScript's round() goes away from zero, so
## every place that copies a Python round() uses this.
static func round_half_even(x: float) -> int:
	var f := floorf(x)
	var diff := x - f
	var n := int(f)
	if diff > 0.5:
		return n + 1
	if diff < 0.5:
		return n
	return n if n % 2 == 0 else n + 1


static func lex_less(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y


## The key of the edge between two neighbouring hexes: Vector4i(a, b) with a < b, so both orders give one key.
static func edge_key(a: Vector2i, b: Vector2i) -> Vector4i:
	if lex_less(b, a):
		return Vector4i(b.x, b.y, a.x, a.y)
	return Vector4i(a.x, a.y, b.x, b.y)


static func edge_ends(key: Vector4i) -> Array[Vector2i]:
	return [Vector2i(key.x, key.y), Vector2i(key.z, key.w)]


## Order of edge keys: by the first hex, then the second, the same as sorted(edge) in Python.
static func edge_less(a: Vector4i, b: Vector4i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.w < b.w
