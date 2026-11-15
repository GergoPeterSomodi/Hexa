## The ground of the 3D close-up test: reads the derived height file (written outside the repository by
## tools/worldmap/closeup_3d/extract_area.py), projects it with the game's map grid (28 km pointy-top hexes, the same
## formulas as core/worldmap), and builds one regular height field in world units that every other part reads.
## World units are kilometres: x grows east, z grows south, y is up; the origin is Genoa at sea level.
extends RefCounted

const DEG_KM := 111.2
const REF_LAT := 45.25
const LON_WEST := 5.6
const LAT_NORTH := 47.3
const ORIGIN_LON := 8.93
const ORIGIN_LAT := 44.41

## The window of the test, in degrees.
const WEST := 7.9
const EAST := 9.9
const SOUTH := 43.8
const NORTH := 45.0

## Grid step of the height field and of the terrain mesh, in km.
const STEP := 0.5
## Land heights are multiplied by this, so the Apennines read at board-game scale. Sea depths get less.
const EXAGGERATION := 7.0
const SEA_EXAGGERATION := 0.55

var credit := ""
var cols := 0
var rows := 0
var lon0 := 0.0
var lat0 := 0.0
var d_lon := 0.0
var d_lat := 0.0
var metres := PackedFloat32Array()
## Stream lines in world x, z with the drained cell count in the third number.
var streams: Array[PackedVector3Array] = []

## The height field: nx by nz points, STEP apart, from (x0, z0).
var nx := 0
var nz := 0
var x0 := 0.0
var z0 := 0.0
var field := PackedFloat32Array()
## Distance to the shore in km for sea points (0 on land), for the foam and the depth tint.
var shore := PackedFloat32Array()
## 1 where trees and houses must keep off (roads, streams), per field point.
var keep_off := PackedByteArray()


func load_file(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return "cannot read the height file: " + path
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return "the height file is not a JSON object: " + path
	var data: Dictionary = parsed
	credit = str(data.get("credit", ""))
	cols = int(data["cols"])
	rows = int(data["rows"])
	lon0 = float(data["lon0"])
	lat0 = float(data["lat0"])
	d_lon = float(data["d_lon"])
	d_lat = float(data["d_lat"])
	metres.resize(cols * rows)
	var z_rows: Array = data["z"]
	for r in rows:
		var row: Array = z_rows[r]
		for c in cols:
			metres[r * cols + c] = float(row[c])
	var raw_streams: Array = data.get("streams", [])
	for raw: Array in raw_streams:
		var line := PackedVector3Array()
		for p: Array in raw:
			var w := world_of(float(p[0]), float(p[1]))
			line.append(Vector3(w.x, w.y, float(p[2])))
		streams.append(line)
	return ""


## Game grid kilometres of a place (the formulas of the map prototype's grid).
static func km_of(lon: float, lat: float) -> Vector2:
	return Vector2((lon - LON_WEST) * DEG_KM * cos(deg_to_rad(REF_LAT)), (LAT_NORTH - lat) * DEG_KM)


static func origin_km() -> Vector2:
	return km_of(ORIGIN_LON, ORIGIN_LAT)


## World x and z of a place.
static func world_of(lon: float, lat: float) -> Vector2:
	return km_of(lon, lat) - origin_km()


static func lonlat_of(x: float, z: float) -> Vector2:
	var km := Vector2(x, z) + origin_km()
	return Vector2(LON_WEST + km.x / (DEG_KM * cos(deg_to_rad(REF_LAT))), LAT_NORTH - km.y / DEG_KM)


func _cell(r: int, c: int) -> float:
	return metres[clampi(r, 0, rows - 1) * cols + clampi(c, 0, cols - 1)]


static func _cubic(a: float, b: float, c: float, d: float, t: float) -> float:
	return b + 0.5 * t * (c - a + t * (2.0 * a - 5.0 * b + 4.0 * c - d + t * (3.0 * (b - c) + d - a)))


## Height in metres at a place, by Catmull-Rom interpolation of the 60 arc-second cells.
func metres_at(lon: float, lat: float) -> float:
	var fc := (lon - lon0) / d_lon
	var fr := (lat0 - lat) / d_lat
	var c := floori(fc)
	var r := floori(fr)
	var tc := fc - float(c)
	var tr := fr - float(r)
	var line := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for k in 4:
		var rr := r - 1 + k
		line[k] = _cubic(_cell(rr, c - 1), _cell(rr, c), _cell(rr, c + 1), _cell(rr, c + 2), tc)
	return _cubic(line[0], line[1], line[2], line[3], tr)


## Builds the height field: exaggerated land, a shallower sea bed, a little detail on the slopes, and the stream beds.
func build_field() -> void:
	var nw := world_of(WEST, NORTH)
	var se := world_of(EAST, SOUTH)
	x0 = nw.x
	z0 = nw.y
	nx = int(floor((se.x - nw.x) / STEP)) + 1
	nz = int(floor((se.y - nw.y) / STEP)) + 1
	field.resize(nx * nz)
	var detail := FastNoiseLite.new()
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail.seed = 1480
	detail.frequency = 0.16
	detail.fractal_octaves = 3
	for j in nz:
		for i in nx:
			var x := x0 + float(i) * STEP
			var z := z0 + float(j) * STEP
			var ll := lonlat_of(x, z)
			var m := metres_at(ll.x, ll.y)
			var y := 0.0
			if m >= 0.0:
				# Ridged detail that grows with height: the 60 arc-second cells are smooth, hills want a little bite.
				var ridged := 1.0 - absf(detail.get_noise_2d(x, z))
				m += (ridged - 0.6) * 90.0 * smoothstep(60.0, 600.0, m)
				y = maxf(m, 0.5) * 0.001 * EXAGGERATION
			else:
				y = m * 0.001 * SEA_EXAGGERATION - 0.02
			field[j * nx + i] = y
	_carve_streams()
	_measure_shore()
	keep_off.resize(nx * nz)
	keep_off.fill(0)


func _carve_streams() -> void:
	var carve := PackedFloat32Array()
	carve.resize(nx * nz)
	carve.fill(0.0)
	for line in streams:
		var path := densify(line, 0.25)
		for p in path:
			var depth := 0.10 + 0.03 * minf(sqrt(p.z) / 20.0, 2.0)
			var radius := 1.1 + 0.3 * minf(sqrt(p.z) / 20.0, 2.0)
			var i0 := int(floor((p.x - radius - x0) / STEP))
			var j0 := int(floor((p.y - radius - z0) / STEP))
			var span := int(ceil(2.0 * radius / STEP)) + 1
			for j in range(maxi(j0, 0), mini(j0 + span + 1, nz)):
				for i in range(maxi(i0, 0), mini(i0 + span + 1, nx)):
					var d := Vector2(x0 + float(i) * STEP - p.x, z0 + float(j) * STEP - p.y).length()
					var v := depth * (1.0 - smoothstep(0.15, radius, d))
					if v > carve[j * nx + i]:
						carve[j * nx + i] = v
	for k in nx * nz:
		if field[k] > 0.0:
			field[k] = maxf(field[k] - carve[k], 0.012)


## Shore distance for the sea points: the first ring is measured inside the cell (where the bed crosses sea level), the rest
## by two chamfer passes.
func _measure_shore() -> void:
	shore.resize(nx * nz)
	var far := 1.0e6
	for j in nz:
		for i in nx:
			var k := j * nx + i
			if field[k] >= 0.0:
				shore[k] = 0.0
				continue
			var best := far
			for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ii := i + n.x
				var jj := j + n.y
				if ii < 0 or jj < 0 or ii >= nx or jj >= nz:
					continue
				var other := field[jj * nx + ii]
				if other >= 0.0:
					best = minf(best, STEP * (-field[k]) / (other - field[k]))
			shore[k] = best
	var diag := STEP * 1.41421
	for j in nz:
		for i in nx:
			var k := j * nx + i
			if shore[k] == 0.0:
				continue
			if i > 0:
				shore[k] = minf(shore[k], shore[k - 1] + STEP)
			if j > 0:
				shore[k] = minf(shore[k], shore[k - nx] + STEP)
				if i > 0:
					shore[k] = minf(shore[k], shore[k - nx - 1] + diag)
				if i < nx - 1:
					shore[k] = minf(shore[k], shore[k - nx + 1] + diag)
	for j in range(nz - 1, -1, -1):
		for i in range(nx - 1, -1, -1):
			var k := j * nx + i
			if shore[k] == 0.0:
				continue
			if i < nx - 1:
				shore[k] = minf(shore[k], shore[k + 1] + STEP)
			if j < nz - 1:
				shore[k] = minf(shore[k], shore[k + nx] + STEP)
				if i < nx - 1:
					shore[k] = minf(shore[k], shore[k + nx + 1] + diag)
				if i > 0:
					shore[k] = minf(shore[k], shore[k + nx - 1] + diag)


## Lowers the hills inside the circle of a town toward a cap above its centre, so the houses stand on a shelf.
func level_town(centre: Vector2, radius: float, cap: float) -> void:
	var limit := height_at(centre.x, centre.y) + cap
	var i0 := int(floor((centre.x - radius - x0) / STEP))
	var j0 := int(floor((centre.y - radius - z0) / STEP))
	var span := int(ceil(2.0 * radius / STEP)) + 1
	for j in range(maxi(j0, 0), mini(j0 + span + 1, nz)):
		for i in range(maxi(i0, 0), mini(i0 + span + 1, nx)):
			var k := j * nx + i
			if field[k] <= limit:
				continue
			var d := Vector2(x0 + float(i) * STEP - centre.x, z0 + float(j) * STEP - centre.y).length()
			var w := 1.0 - smoothstep(radius * 0.45, radius, d)
			field[k] = lerpf(field[k], limit + (field[k] - limit) * 0.25, w)


func width() -> float:
	return float(nx - 1) * STEP


func depth() -> float:
	return float(nz - 1) * STEP


func inside(x: float, z: float) -> bool:
	return x >= x0 and z >= z0 and x <= x0 + width() and z <= z0 + depth()


## World height at a point of the field (bilinear, like the mesh).
func height_at(x: float, z: float) -> float:
	var fi := clampf((x - x0) / STEP, 0.0, float(nx - 1) - 0.001)
	var fj := clampf((z - z0) / STEP, 0.0, float(nz - 1) - 0.001)
	var i := int(fi)
	var j := int(fj)
	var ti := fi - float(i)
	var tj := fj - float(j)
	var k := j * nx + i
	var a := lerpf(field[k], field[k + 1], ti)
	var b := lerpf(field[k + nx], field[k + nx + 1], ti)
	return lerpf(a, b, tj)


## Surface normal of the field at a point.
func normal_at(x: float, z: float) -> Vector3:
	var e := STEP
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


## Real height in metres of a land point of the field (the exaggeration taken out).
func real_metres(x: float, z: float) -> float:
	return height_at(x, z) / EXAGGERATION * 1000.0


## Marks the field points within radius of the path as closed to trees and houses.
func mark_keep_off(path: PackedVector2Array, radius: float) -> void:
	for p in path:
		var i0 := int(floor((p.x - radius - x0) / STEP))
		var j0 := int(floor((p.y - radius - z0) / STEP))
		var span := int(ceil(2.0 * radius / STEP)) + 1
		for j in range(maxi(j0, 0), mini(j0 + span + 1, nz)):
			for i in range(maxi(i0, 0), mini(i0 + span + 1, nx)):
				if Vector2(x0 + float(i) * STEP - p.x, z0 + float(j) * STEP - p.y).length() <= radius:
					keep_off[j * nx + i] = 1


func is_keep_off(x: float, z: float) -> bool:
	var i := clampi(int(round((x - x0) / STEP)), 0, nx - 1)
	var j := clampi(int(round((z - z0) / STEP)), 0, nz - 1)
	return keep_off[j * nx + i] == 1


## Points along a line every `spacing` km. The third number of the input (when used) is carried along.
static func densify(line: PackedVector3Array, spacing: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in line.size() - 1:
		var a := line[k]
		var b := line[k + 1]
		var steps := maxi(1, int(ceil(Vector2(b.x - a.x, b.y - a.y).length() / spacing)))
		for s in steps:
			out.append(a.lerp(b, float(s) / float(steps)))
	if line.size() > 0:
		out.append(line[line.size() - 1])
	return out


## Corner cutting (Chaikin), which keeps the ends: turns the stepped stream lines into curves.
static func smooth(line: PackedVector3Array, rounds: int) -> PackedVector3Array:
	var cur := line
	for _n in rounds:
		if cur.size() < 3:
			break
		var out := PackedVector3Array()
		out.append(cur[0])
		for k in cur.size() - 1:
			out.append(cur[k].lerp(cur[k + 1], 0.25))
			out.append(cur[k].lerp(cur[k + 1], 0.75))
		out.append(cur[cur.size() - 1])
		cur = out
	return cur


## A Catmull-Rom curve through the points, sampled every `spacing` km.
static func curve_through(points: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	for k in n - 1:
		var p0 := points[maxi(k - 1, 0)]
		var p1 := points[k]
		var p2 := points[k + 1]
		var p3 := points[mini(k + 2, n - 1)]
		var steps := maxi(1, int(ceil(p1.distance_to(p2) / spacing)))
		for s in steps:
			var t := float(s) / float(steps)
			out.append(Vector2(_cubic(p0.x, p1.x, p2.x, p3.x, t), _cubic(p0.y, p1.y, p2.y, p3.y, t)))
	if n > 0:
		out.append(points[n - 1])
	return out
