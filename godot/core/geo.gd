## The Mercator projection of Europe 1480 and the polygon maths of hexa/campaign/geo.py (the frozen reference).
## The constants are read from godot/data/geography/projection.json (exact doubles, never recomputed).
##
## Geography is kept in float64: a point is two floats, and a polyline or polygon is a PackedFloat64Array of
## interleaved x, y pairs (lon, lat). Godot's Vector2 is single precision, so it is not used for geography.
class_name Geo
extends RefCounted

## A polygon with its bounding box [min x, min y, max x, max y], so the point tests skip the far ones.
class Shape:
	extends RefCounted
	var box: PackedFloat64Array
	var poly: PackedFloat64Array

	func _init(points: PackedFloat64Array) -> void:
		poly = points
		box = Geo.bbox(points)


var lon0: float
var col_deg: float
var row_deg: float
var y_top: float
var cols: int
var rows: int


func _init(p_lon0: float, p_col_deg: float, p_row_deg: float, p_y_top: float, p_cols: int, p_rows: int) -> void:
	lon0 = p_lon0
	col_deg = p_col_deg
	row_deg = p_row_deg
	y_top = p_y_top
	cols = p_cols
	rows = p_rows


static func merc(lat: float) -> float:
	return log(tan(PI / 4.0 + lat * (PI / 180.0) / 2.0)) * (180.0 / PI)


static func inv_merc(y: float) -> float:
	return (2.0 * atan(exp(y * (PI / 180.0))) - PI / 2.0) * (180.0 / PI)


## [lon, lat] of the centre of a hex.
func lonlat(pos: Vector2i) -> PackedFloat64Array:
	var lon := lon0 + (float(pos.x) + 0.5 * float(pos.y & 1) + 0.5) * col_deg
	var lat := inv_merc(y_top - (float(pos.y) + 0.5) * row_deg)
	return PackedFloat64Array([lon, lat])


## The hex that holds (lon, lat), with the rounding of geo.hex_of.
func hex_of(lon: float, lat: float) -> Vector2i:
	var row := HexGrid.round_half_even((y_top - merc(lat)) / row_deg - 0.5)
	var col := HexGrid.round_half_even((lon - lon0) / col_deg - 0.5 - 0.5 * float(row & 1))
	return Vector2i(col, row)


static func point_count(path: PackedFloat64Array) -> int:
	return path.size() >> 1


## Even-odd test of (x, y) against a polygon of interleaved points.
static func inside(x: float, y: float, poly: PackedFloat64Array) -> bool:
	var n := poly.size() >> 1
	var hit := false
	var j := n - 1
	for i in n:
		var xi := poly[2 * i]
		var yi := poly[2 * i + 1]
		var xj := poly[2 * j]
		var yj := poly[2 * j + 1]
		if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
			hit = not hit
		j = i
	return hit


## [min x, min y, max x, max y] of a polygon.
static func bbox(poly: PackedFloat64Array) -> PackedFloat64Array:
	var n := poly.size() >> 1
	var lo_x := poly[0]
	var lo_y := poly[1]
	var hi_x := poly[0]
	var hi_y := poly[1]
	for i in n:
		lo_x = minf(lo_x, poly[2 * i])
		lo_y = minf(lo_y, poly[2 * i + 1])
		hi_x = maxf(hi_x, poly[2 * i])
		hi_y = maxf(hi_y, poly[2 * i + 1])
	return PackedFloat64Array([lo_x, lo_y, hi_x, hi_y])


static func shapes_of(polys: Array[PackedFloat64Array]) -> Array[Shape]:
	var out: Array[Shape] = []
	for poly: PackedFloat64Array in polys:
		out.append(Shape.new(poly))
	return out


## True when (x, y) lies inside one of the shapes (bounding box first, then the polygon test).
static func hit(x: float, y: float, shapes: Array[Shape]) -> bool:
	for s: Shape in shapes:
		var b := s.box
		if b[0] <= x and x <= b[2] and b[1] <= y and y <= b[3] and inside(x, y, s.poly):
			return true
	return false


## Distance in degrees (longitude scaled by the latitude's cosine) from the point p to the segment a-b.
static func seg_distance(p_lon: float, p_lat: float, a_lon: float, a_lat: float, b_lon: float,
		b_lat: float) -> float:
	var k := cos(p_lat * (PI / 180.0))
	var px := p_lon * k
	var py := p_lat
	var ax := a_lon * k
	var ay := a_lat
	var dx := b_lon * k - ax
	var dy := b_lat - ay
	var t := 0.0
	if not (dx == 0.0 and dy == 0.0):
		t = clampf(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy), 0.0, 1.0)
	var ex := px - ax - t * dx
	var ey := py - ay - t * dy
	return sqrt(ex * ex + ey * ey)
