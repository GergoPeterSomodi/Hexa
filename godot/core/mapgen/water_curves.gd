## The drawn curves of the water of the map prototype (WorldWater): a river or a ribbon lake as a polyline through its edge
## midpoints, the joins pinned into the curve they meet, the Chaikin smoothing every viewer draws with and the distance to a
## curve the join check uses. Split out of world_water.gd so that file stays under the size limit; the code is moved as it was
## (build is the old _build_drawn_lines and writes the curves into the water it is given).
class_name WaterCurves
extends RefCounted


## Chaikin corner cutting, a few rounds, for an open line. A point flagged in pins keeps its place (the ends, the river city
## crossings and the joins), so the curve passes through the points that are pinned. The viewer draws every curve with it.
static func smooth_line(points: PackedVector2Array, pins: Array[bool], rounds: int) -> PackedVector2Array:
	var pts := points
	var flags: Array[bool] = pins.duplicate()
	for r: int in rounds:
		var out := PackedVector2Array()
		var out_flags: Array[bool] = []
		var n := pts.size()
		if n < 3:
			break
		for i: int in n - 1:
			var a := pts[i]
			var b := pts[i + 1]
			if flags[i]:
				out.append(a)
				out_flags.append(true)
			else:
				out.append(a * 0.75 + b * 0.25)
				out_flags.append(false)
			if not flags[i + 1]:
				out.append(a * 0.25 + b * 0.75)
				out_flags.append(false)
		out.append(pts[n - 1])
		out_flags.append(true)
		pts = out
		flags = out_flags
	return pts


## Builds the drawn curves. A river is a polyline through its steps (edge midpoints, river city centres) from its source to
## its mouth. A ribbon lake is a polyline through its steps. Then each join is pinned into the curve it meets: a tributary's
## end corner becomes a point of the main river's curve (inserted at that corner), and a river that starts or ends on a
## lake's chain becomes a point of the lake's curve. So the tributary's line ends exactly on the main line, and the river
## meets the lake shore exactly: the corner is a vertex of both curves, so both pass through it.
static func build(water: WorldWater) -> void:
	var r_pts: Array[Array] = []
	var r_pin: Array[Array] = []
	var r_cor: Array[Array] = []
	for i: int in water.rivers.size():
		var chain: Array[Vector3i] = water.rivers[i]["corners"]
		var steps: Array[Vector4i] = water.rivers[i]["steps"]
		var pts: Array[Vector2] = [water.corner_pos(chain[0])]
		var pin: Array[bool] = [true]
		var cor: Array[Vector3i] = [chain[0]]
		for j: int in steps.size():
			var e := steps[j]
			if e == WorldWater.NO_EDGE:
				pts.append(water.grid.centre_km(city_hex_of_link(chain[j], chain[j + 1])))
				pin.append(true)
			else:
				pts.append(water.edge_mid_km(e))
				pin.append(false)
			cor.append(WorldWater.NO_CORNER)
		pts.append(water.corner_pos(chain[chain.size() - 1]))
		pin.append(true)
		cor.append(chain[chain.size() - 1])
		r_pts.append(pts)
		r_pin.append(pin)
		r_cor.append(cor)
	var l_pts: Array[Array] = []
	var l_pin: Array[Array] = []
	var l_cor: Array[Array] = []
	for i: int in water.lakes.size():
		var steps: Array[Vector4i] = water.lakes[i]["steps"]
		var pts: Array[Vector2] = []
		var pin: Array[bool] = []
		var cor: Array[Vector3i] = []
		for e: Vector4i in steps:
			pts.append(water.edge_mid_km(e))
			pin.append(false)
			cor.append(WorldWater.NO_CORNER)
		if not pin.is_empty():
			pin[0] = true
			pin[pin.size() - 1] = true
		l_pts.append(pts)
		l_pin.append(pin)
		l_cor.append(cor)
	# The joins: each end corner of a river that is a corner of another curve (a river, or a ribbon lake's chain).
	var inserts: Array[Dictionary] = []
	water.join_anchors.clear()
	water.free_ends = 0
	for t: int in water.rivers.size():
		var chain: Array[Vector3i] = water.rivers[t]["corners"]
		for c: Vector3i in [chain[0], chain[chain.size() - 1]]:
			var host := host_of(water, c, t)
			if host.is_empty():
				water.free_ends += 1
				continue
			var kind := str(host["kind"])
			var idx := int(host["index"])
			var at := int(host["at"])
			water.join_anchors.append({"corner": c, "km": water.corner_pos(c), "tributary": t, "host_kind": kind, "host": idx})
			var host_size := (water.rivers[idx]["corners"] as Array).size() if kind == "river" else (water.lakes[idx]["corners"] as Array).size()
			# A river's own curve already starts and ends on its corners; a lake's curve starts on its first step's midpoint,
			# so a lake corner at either end is pinned too.
			if kind == "lake" or (at > 0 and at < host_size - 1):
				inserts.append({"kind": kind, "index": idx, "at": at, "corner": c})
	# Largest corner index first within a curve, so the earlier positions stay valid while inserting.
	inserts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a["kind"]) != str(b["kind"]):
			return str(a["kind"]) > str(b["kind"])
		if int(a["index"]) != int(b["index"]):
			return int(a["index"]) < int(b["index"])
		return int(a["at"]) > int(b["at"]))
	for ins: Dictionary in inserts:
		var idx := int(ins["index"])
		var at := int(ins["at"])
		var c: Vector3i = ins["corner"]
		var at_km := water.corner_pos(c)
		if str(ins["kind"]) == "river":
			# Entries are [source, step 0, ..., step N-1, mouth]: corner k sits between step k-1 and step k.
			(r_pts[idx] as Array).insert(at + 1, at_km)
			(r_pin[idx] as Array).insert(at + 1, true)
			(r_cor[idx] as Array).insert(at + 1, c)
		else:
			# Entries are the steps only: corner k sits before step k.
			(l_pts[idx] as Array).insert(at, at_km)
			(l_pin[idx] as Array).insert(at, true)
			(l_cor[idx] as Array).insert(at, c)
	water._river_curve.clear()
	water._river_pin.clear()
	water._lake_curve.clear()
	water._lake_pin.clear()
	for i: int in water.rivers.size():
		water._river_curve.append(PackedVector2Array(r_pts[i]))
		water._river_pin.append(r_pin[i])
	for i: int in water.lakes.size():
		water._lake_curve.append(PackedVector2Array(l_pts[i]))
		water._lake_pin.append(l_pin[i])


## The curve that a river end corner meets, other than river t itself: the river holding the corner (the highest class
## first), else a ribbon lake whose chain holds it. "at" is the corner's index in that chain (0 and the last index are the
## curve's own ends). Empty when no other curve holds the corner.
static func host_of(water: WorldWater, c: Vector3i, t: int) -> Dictionary:
	var best := {}
	var best_class := -1
	for r: int in water.rivers.size():
		if r == t:
			continue
		var chain: Array[Vector3i] = water.rivers[r]["corners"]
		var at := chain.find(c)
		if at >= 0 and int(water.rivers[r]["class"]) > best_class:
			best_class = int(water.rivers[r]["class"])
			best = {"kind": "river", "index": r, "at": at}
	if not best.is_empty():
		return best
	for k: int in water.lakes.size():
		var corners: Array[Vector3i] = water.lakes[k]["corners"]
		var at := corners.find(c)
		if at >= 0:
			return {"kind": "lake", "index": k, "at": at}
	return best


static func distance_to_curve(p: Vector2, curve: PackedVector2Array) -> float:
	var best := INF
	for i: int in curve.size():
		best = minf(best, p.distance_to(curve[i]))
	return best


static func city_hex_of_link(a: Vector3i, b: Vector3i) -> Vector2i:
	var hb := WorldWater.corner_hexes_of(b)
	for h: Vector2i in WorldWater.corner_hexes_of(a):
		if hb.has(h):
			return h
	return Vector2i.ZERO
