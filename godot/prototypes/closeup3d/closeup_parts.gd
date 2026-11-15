## Mesh builders for the 3D close-up test: every object is made here from triangles, with its colours in the vertices
## (no textures, no imported models). Sizes are in local units of about one house width; the scene scales the instances.
extends RefCounted

const WALL := Color(0.76, 0.72, 0.62)
const WALL_SHADE := Color(0.70, 0.65, 0.55)
const ROOF := Color(0.80, 0.26, 0.17)
const ROOF_DARK := Color(0.66, 0.20, 0.14)
const STONE := Color(0.64, 0.60, 0.53)
const STONE_DARK := Color(0.50, 0.47, 0.42)
const WOOD := Color(0.42, 0.28, 0.17)
const WOOD_DARK := Color(0.30, 0.20, 0.13)
const SAIL := Color(0.80, 0.77, 0.68)
const TRUNK := Color(0.36, 0.25, 0.16)


static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## A flat triangle that faces away from `inside` (Godot's front faces wind clockwise).
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3) -> void:
	var n := (c - a).cross(b - a)
	if n.dot(a - inside) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	n = n.normalized()
	for v: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(v)


static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, inside: Vector3) -> void:
	tri(st, a, b, c, col, inside)
	tri(st, a, c, d, col, inside)


## A triangle with its own normals and colours per corner (for the rounded shapes).
static func tri_smooth(st: SurfaceTool, p: Array[Vector3], n: Array[Vector3], c: Array[Color]) -> void:
	var order: Array[int] = [0, 1, 2]
	var face := (p[2] - p[0]).cross(p[1] - p[0])
	if face.dot(n[0] + n[1] + n[2]) < 0.0:
		order = [0, 2, 1]
	for k: int in order:
		st.set_normal(n[k])
		st.set_color(c[k])
		st.add_vertex(p[k])


## A box from lo to hi, placed by xf. The top can have its own colour.
static func box(st: SurfaceTool, xf: Transform3D, lo: Vector3, hi: Vector3, col: Color, top: Color = Color(0, 0, 0, 0)) -> void:
	var top_col := col if top.a == 0.0 else top
	var mid := xf * ((lo + hi) * 0.5)
	var p: Array[Vector3] = []
	for k in 8:
		p.append(xf * Vector3(hi.x if k & 1 else lo.x, hi.y if k & 2 else lo.y, hi.z if k & 4 else lo.z))
	quad(st, p[0], p[1], p[3], p[2], col, mid)
	quad(st, p[4], p[5], p[7], p[6], col, mid)
	quad(st, p[0], p[2], p[6], p[4], col, mid)
	quad(st, p[1], p[3], p[7], p[5], col, mid)
	quad(st, p[2], p[3], p[7], p[6], top_col, mid)
	quad(st, p[0], p[1], p[5], p[4], col, mid)


## A gable roof over the rectangle lo.x..hi.x by lo.z..hi.z at height y, ridge along x, with the gable ends in wall colour.
static func gable(st: SurfaceTool, xf: Transform3D, lo: Vector2, hi: Vector2, y: float, rise: float, roof: Color,
		roof_dark: Color, wall: Color) -> void:
	var zm := (lo.y + hi.y) * 0.5
	var a := xf * Vector3(lo.x, y, lo.y)
	var b := xf * Vector3(hi.x, y, lo.y)
	var c := xf * Vector3(hi.x, y, hi.y)
	var d := xf * Vector3(lo.x, y, hi.y)
	var r0 := xf * Vector3(lo.x, y + rise, zm)
	var r1 := xf * Vector3(hi.x, y + rise, zm)
	var mid := xf * Vector3((lo.x + hi.x) * 0.5, y, zm)
	quad(st, a, b, r1, r0, roof, mid)
	quad(st, d, c, r1, r0, roof_dark, mid)
	tri(st, a, d, r0, wall, mid)
	tri(st, b, c, r1, wall, mid)


## A pyramid on a square base.
static func pyramid(st: SurfaceTool, xf: Transform3D, centre: Vector3, half: float, rise: float, col: Color, dark: Color) -> void:
	var tip := xf * (centre + Vector3(0, rise, 0))
	var mid := xf * centre
	var corners: Array[Vector3] = []
	for k in 4:
		var sx := half if k == 1 or k == 2 else -half
		var sz := half if k >= 2 else -half
		corners.append(xf * (centre + Vector3(sx, 0, sz)))
	for k in 4:
		tri(st, corners[k], corners[(k + 1) % 4], tip, col if k % 2 == 0 else dark, mid)


## A cone or a tapered post with flat sides: radius r0 at the base, r1 at the top.
static func taper(st: SurfaceTool, xf: Transform3D, base: Vector3, r0: float, r1: float, rise: float, sides: int,
		low: Color, high: Color) -> void:
	var mid := xf * (base + Vector3(0, rise * 0.4, 0))
	for k in sides:
		var a0 := TAU * float(k) / float(sides)
		var a1 := TAU * float(k + 1) / float(sides)
		var shade := 0.86 + 0.14 * float(k % 2)
		var b0 := xf * (base + Vector3(cos(a0) * r0, 0, sin(a0) * r0))
		var b1 := xf * (base + Vector3(cos(a1) * r0, 0, sin(a1) * r0))
		var t0 := xf * (base + Vector3(cos(a0) * r1, rise, sin(a0) * r1))
		var t1 := xf * (base + Vector3(cos(a1) * r1, rise, sin(a1) * r1))
		var n := (t0 - b0).cross(b1 - b0)
		if n.dot(b0 - mid) < 0.0:
			n = -n
		n = n.normalized()
		var lo_c := Color(low.r * shade, low.g * shade, low.b * shade)
		var hi_c := Color(high.r * shade, high.g * shade, high.b * shade)
		var flat_n: Array[Vector3] = [n, n, n]
		tri_smooth(st, [b0, b1, t1], flat_n, [lo_c, lo_c, hi_c])
		if r1 > 0.0:
			tri_smooth(st, [b0, t1, t0], flat_n, [lo_c, hi_c, hi_c])


## A rounded lump (a squashed sphere) with soft normals and a colour that lightens upward.
static func blob(st: SurfaceTool, xf: Transform3D, centre: Vector3, radius: Vector3, rings: int, sides: int, low: Color,
		high: Color, lumps: float = 0.0) -> void:
	var pts: Array = []
	var nrm: Array = []
	var cols: Array = []
	for r in rings + 1:
		var lat := PI * float(r) / float(rings)
		var row_p: Array[Vector3] = []
		var row_n: Array[Vector3] = []
		var row_c: Array[Color] = []
		for s in sides + 1:
			var lon := TAU * float(s % sides) / float(sides)
			var dir := Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon))
			var bump := 1.0 + lumps * sin(float((s % sides) * 3 + r * 2) * 1.7)
			row_p.append(xf * (centre + dir * radius * bump))
			row_n.append((xf.basis * (dir / radius)).normalized())
			row_c.append(low.lerp(high, clampf(dir.y * 0.6 + 0.5, 0.0, 1.0)))
		pts.append(row_p)
		nrm.append(row_n)
		cols.append(row_c)
	for r in rings:
		var p0: Array[Vector3] = pts[r]
		var p1: Array[Vector3] = pts[r + 1]
		var n0: Array[Vector3] = nrm[r]
		var n1: Array[Vector3] = nrm[r + 1]
		var c0: Array[Color] = cols[r]
		var c1: Array[Color] = cols[r + 1]
		for s in sides:
			if r > 0:
				tri_smooth(st, [p0[s], p0[s + 1], p1[s + 1]], [n0[s], n0[s + 1], n1[s + 1]], [c0[s], c0[s + 1], c1[s + 1]])
			if r < rings - 1:
				tri_smooth(st, [p0[s], p1[s + 1], p1[s]], [n0[s], n1[s + 1], n1[s]], [c0[s], c1[s + 1], c1[s]])


## A house: walls that reach below the ground (for slopes) and a red gable roof. One unit wide.
static func house_mesh() -> ArrayMesh:
	var st := begin()
	var xf := Transform3D.IDENTITY
	box(st, xf, Vector3(-0.5, -0.6, -0.34), Vector3(0.5, 0.52, 0.34), WALL)
	gable(st, xf, Vector2(-0.57, -0.42), Vector2(0.57, 0.42), 0.50, 0.42, ROOF, ROOF_DARK, WALL_SHADE)
	# A door and two windows, as dark marks on the long side that faces the viewer.
	box(st, xf, Vector3(-0.08, 0.0, 0.34), Vector3(0.08, 0.26, 0.355), WOOD)
	box(st, xf, Vector3(-0.36, 0.2, 0.34), Vector3(-0.22, 0.36, 0.355), WOOD_DARK)
	box(st, xf, Vector3(0.22, 0.2, 0.34), Vector3(0.36, 0.36, 0.355), WOOD_DARK)
	return st.commit()


## A square town tower with a wider top and a red cap.
static func tower_mesh() -> ArrayMesh:
	var st := begin()
	var xf := Transform3D.IDENTITY
	box(st, xf, Vector3(-0.27, -0.6, -0.27), Vector3(0.27, 1.75, 0.27), STONE)
	box(st, xf, Vector3(-0.35, 1.75, -0.35), Vector3(0.35, 2.0, 0.35), WALL_SHADE, STONE_DARK)
	pyramid(st, xf, Vector3(0, 2.0, 0), 0.30, 0.5, ROOF, ROOF_DARK)
	box(st, xf, Vector3(-0.07, 1.2, 0.27), Vector3(0.07, 1.45, 0.285), WOOD_DARK)
	return st.commit()


## A church: a nave, a dome on a drum, and a bell tower.
static func church_mesh() -> ArrayMesh:
	var st := begin()
	var xf := Transform3D.IDENTITY
	box(st, xf, Vector3(-0.9, -0.6, -0.5), Vector3(0.9, 0.85, 0.5), WALL)
	gable(st, xf, Vector2(-0.97, -0.58), Vector2(0.97, 0.58), 0.83, 0.5, ROOF, ROOF_DARK, WALL_SHADE)
	taper(st, xf, Vector3(0.35, 1.0, 0), 0.42, 0.42, 0.45, 8, WALL_SHADE, WALL)
	blob(st, xf, Vector3(0.35, 1.45, 0), Vector3(0.46, 0.5, 0.46), 5, 8, Color(0.52, 0.60, 0.66), Color(0.80, 0.86, 0.90))
	box(st, xf, Vector3(-1.25, -0.6, -0.2), Vector3(-0.85, 2.3, 0.2), STONE)
	pyramid(st, xf, Vector3(-1.05, 2.3, 0), 0.26, 0.6, ROOF, ROOF_DARK)
	box(st, xf, Vector3(-0.12, 0.0, 0.5), Vector3(0.12, 0.4, 0.515), WOOD)
	return st.commit()


## The Lanterna: two square towers one on the other, each with a gallery, on a rock. The light is a separate mesh.
static func lighthouse_mesh() -> ArrayMesh:
	var st := begin()
	var xf := Transform3D.IDENTITY
	taper(st, xf, Vector3(0, -0.5, 0), 0.85, 0.55, 0.8, 7, STONE_DARK, STONE)
	box(st, xf, Vector3(-0.27, 0.3, -0.27), Vector3(0.27, 2.0, 0.27), WALL)
	box(st, xf, Vector3(-0.37, 2.0, -0.37), Vector3(0.37, 2.14, 0.37), STONE, STONE_DARK)
	box(st, xf, Vector3(-0.19, 2.14, -0.19), Vector3(0.19, 3.3, 0.19), WALL)
	box(st, xf, Vector3(-0.28, 3.3, -0.28), Vector3(0.28, 3.4, 0.28), STONE, STONE_DARK)
	pyramid(st, xf, Vector3(0, 3.72, 0), 0.17, 0.26, ROOF_DARK, ROOF_DARK)
	return st.commit()


static func lighthouse_light_mesh() -> ArrayMesh:
	var st := begin()
	box(st, Transform3D.IDENTITY, Vector3(-0.13, 3.4, -0.13), Vector3(0.13, 3.72, 0.13), Color(1.0, 0.86, 0.35))
	return st.commit()


## A round-hulled trading ship with two square sails, about 1.7 units long, bow toward +x, waterline at y = 0.
static func ship_mesh() -> ArrayMesh:
	var st := begin()
	var xf := Transform3D.IDENTITY
	var deck: Array[Vector3] = [Vector3(-0.85, 0.34, -0.2), Vector3(-0.2, 0.26, -0.29), Vector3(0.5, 0.28, -0.22),
		Vector3(0.95, 0.4, 0.0), Vector3(0.5, 0.28, 0.22), Vector3(-0.2, 0.26, 0.29), Vector3(-0.85, 0.34, 0.2)]
	var keel: Array[Vector3] = []
	for p in deck:
		keel.append(Vector3(p.x * 0.8, -0.12, p.z * 0.55))
	var mid := Vector3(0, 0.1, 0)
	for k in deck.size():
		var k2 := (k + 1) % deck.size()
		quad(st, keel[k], keel[k2], deck[k2], deck[k], WOOD if k % 2 == 0 else WOOD_DARK, mid)
	for k in range(1, deck.size() - 1):
		tri(st, deck[0], deck[k], deck[k + 1], Color(0.62, 0.47, 0.30), Vector3(0, -1, 0))
	box(st, xf, Vector3(-0.85, 0.3, -0.19), Vector3(-0.45, 0.5, 0.19), WOOD, Color(0.62, 0.47, 0.30))
	box(st, xf, Vector3(-0.02, 0.26, -0.025), Vector3(0.03, 1.5, 0.025), WOOD_DARK)
	box(st, xf, Vector3(0.48, 0.28, -0.02), Vector3(0.52, 1.05, 0.02), WOOD_DARK)
	box(st, xf, Vector3(0.03, 0.62, -0.42), Vector3(0.07, 1.32, 0.42), SAIL)
	box(st, xf, Vector3(0.52, 0.5, -0.28), Vector3(0.55, 0.95, 0.28), SAIL)
	box(st, xf, Vector3(-0.2, 1.38, -0.01), Vector3(0.0, 1.5, 0.01), ROOF)
	return st.commit()


## A round broadleaf tree, about 1.6 units tall. White in the instance colour keeps these greens.
static func round_tree_mesh() -> ArrayMesh:
	var st := begin()
	var xf := Transform3D.IDENTITY
	taper(st, xf, Vector3(0, -0.2, 0), 0.09, 0.07, 0.8, 5, TRUNK, TRUNK)
	blob(st, xf, Vector3(0, 1.0, 0), Vector3(0.6, 0.62, 0.6), 5, 8, Color(0.17, 0.42, 0.15), Color(0.44, 0.70, 0.25), 0.06)
	return st.commit()


## A conifer of three stacked cones, about 2 units tall.
static func conifer_mesh() -> ArrayMesh:
	var st := begin()
	var xf := Transform3D.IDENTITY
	taper(st, xf, Vector3(0, -0.2, 0), 0.08, 0.06, 0.6, 5, TRUNK, TRUNK)
	taper(st, xf, Vector3(0, 0.3, 0), 0.52, 0.0, 0.85, 7, Color(0.15, 0.40, 0.26), Color(0.24, 0.54, 0.34))
	taper(st, xf, Vector3(0, 0.8, 0), 0.42, 0.0, 0.75, 7, Color(0.16, 0.43, 0.28), Color(0.27, 0.58, 0.36))
	taper(st, xf, Vector3(0, 1.3, 0), 0.30, 0.0, 0.7, 7, Color(0.18, 0.46, 0.30), Color(0.31, 0.63, 0.39))
	return st.commit()


## A cairn for a pass: three stones.
static func cairn_mesh() -> ArrayMesh:
	var st := begin()
	var xf := Transform3D.IDENTITY
	blob(st, xf, Vector3(0, 0.2, 0), Vector3(0.42, 0.3, 0.42), 3, 6, STONE_DARK, STONE)
	blob(st, xf, Vector3(0.03, 0.62, 0), Vector3(0.3, 0.24, 0.3), 3, 6, STONE_DARK, STONE)
	blob(st, xf, Vector3(0, 0.96, 0.02), Vector3(0.2, 0.18, 0.2), 3, 6, STONE_DARK, STONE)
	return st.commit()


## A band laid along a path on the ground. `heights` gives y for the centre and the two edges of every point (3 per
## point: left, centre, right), so the caller decides whether the band follows the ground across or lies level.
static func ribbon(path: PackedVector2Array, half_widths: PackedFloat32Array, heights: PackedFloat32Array, mid: Color,
		edge: Color) -> ArrayMesh:
	var st := begin()
	var n := path.size()
	for k in n:
		var a := path[maxi(k - 1, 0)]
		var b := path[mini(k + 1, n - 1)]
		var along := (b - a).normalized()
		var side := Vector2(-along.y, along.x) * half_widths[k]
		for s in 3:
			var p := path[k] + side * float(s - 1)
			st.set_normal(Vector3.UP)
			st.set_color(mid if s == 1 else edge)
			st.add_vertex(Vector3(p.x, heights[k * 3 + s], p.y))
	for k in n - 1:
		for s in 2:
			var i0 := k * 3 + s
			var i1 := i0 + 3
			st.add_index(i0)
			st.add_index(i1 + 1)
			st.add_index(i0 + 1)
			st.add_index(i0)
			st.add_index(i1)
			st.add_index(i1 + 1)
	return st.commit()
