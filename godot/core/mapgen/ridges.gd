## The crest edges of the mountain lines: every edge between two neighbouring land hexes that a ridge polyline cuts an
## odd number of times. A port of crest_edges and cross in hexa/campaign/systems/worldgen.py. Hex-grid units: a hex
## centre is 1 apart along a row and 0.866 between rows (unit_x, unit_y, centre_x, centre_y).
class_name Ridges
extends RefCounted

const ROW_STEP := 0.8660254
const SHIFT_X := 1.3e-6  # keeps a vertex off an exact crossing, deterministically
const SHIFT_Y := 2.1e-6


## The x of a (lon) in hex-grid units.
static func unit_x(geo: Geo, lon: float) -> float:
	return (lon - geo.lon0) / geo.col_deg


## The y of a (lat) in hex-grid units.
static func unit_y(geo: Geo, lat: float) -> float:
	return (geo.y_top - Geo.merc(lat)) / geo.col_deg


static func centre_x(pos: Vector2i) -> float:
	return float(pos.x) + 0.5 * float(pos.y & 1) + 0.5


static func centre_y(pos: Vector2i) -> float:
	return (float(pos.y) + 0.5) * ROW_STEP


## Every edge (Vector4i keys) between two land hexes that a mountain line crosses an odd number of times.
## land: the land set (hex -> true). Returns the set of edge keys (edge -> true).
static func crest_edges(geo: Geo, data: EuropeData, land: Dictionary) -> Dictionary:
	var found: Dictionary = {}
	for line: PackedFloat64Array in data.mountains:
		var crossings: Dictionary = {}
		var n := Geo.point_count(line)
		for i in range(n - 1):
			var x0 := unit_x(geo, line[2 * i]) + SHIFT_X
			var y0 := unit_y(geo, line[2 * i + 1]) + SHIFT_Y
			var x1 := unit_x(geo, line[2 * i + 2]) + SHIFT_X
			var y1 := unit_y(geo, line[2 * i + 3]) + SHIFT_Y
			var steps := maxi(1, int(maxf(absf(x1 - x0), absf(y1 - y0)) / 0.4) + 1)
			var near: Dictionary = {}
			for k in range(steps + 1):
				var t := float(k) / float(steps)
				var x := x0 + (x1 - x0) * t
				var y := y0 + (y1 - y0) * t
				var pos := geo.hex_of(geo.lon0 + x * geo.col_deg, Geo.inv_merc(geo.y_top - y * geo.col_deg))
				for h: Vector2i in HexGrid.within(pos, 1):
					near[h] = true
			for a: Vector2i in near.keys():
				if not land.has(a):
					continue
				var ax := centre_x(a)
				var ay := centre_y(a)
				for b: Vector2i in HexGrid.neighbours(a):
					if not land.has(b) or HexGrid.lex_less(b, a):
						continue
					if cross(x0, y0, x1, y1, ax, ay, centre_x(b), centre_y(b)):
						var key := HexGrid.edge_key(a, b)
						crossings[key] = int(crossings.get(key, 0)) + 1
		# A ridge that bends round an edge crosses it twice and does not separate its two hexes.
		for key: Vector4i in crossings.keys():
			if int(crossings[key]) % 2 == 1:
				found[key] = true
	return found


## Whether the segments (x0, y0)-(x1, y1) and (ax, ay)-(bx, by) cross.
static func cross(x0: float, y0: float, x1: float, y1: float, ax: float, ay: float, bx: float, by: float) -> bool:
	var d1x := x1 - x0
	var d1y := y1 - y0
	var d2x := bx - ax
	var d2y := by - ay
	var den := d1x * d2y - d1y * d2x
	if absf(den) < 1e-12:
		return false
	var t := ((ax - x0) * d2y - (ay - y0) * d2x) / den
	var u := ((ax - x0) * d1y - (ay - y0) * d1x) / den
	return 0.0 <= t and t <= 1.0 and 0.0 <= u and u <= 1.0
