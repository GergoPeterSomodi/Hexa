## The smooth line of an army's route (owner ask, issue 434): a centripetal Catmull-Rom curve through the hex centres of the route,
## so the line bends through every centre without kinks or loops. Pure: no nodes and no drawing (PathLooks draws it). The
## route's first point is the army's own hex, so the curve starts on the tile the units stand on.
class_name PathCurve
extends RefCounted

## The knot spacing exponent: 0.5 is the centripetal form, which keeps a sharp hex corner from looping.
const ALPHA := 0.5
## The smallest knot distance (a repeated point must not divide by zero).
const EPS := 0.001
## Samples per leg between two centres.
const STEPS := 16


## The curve through `points` (the route's centres, the army's own hex first): {samples (PackedVector2Array), leg (PackedInt32Array,
## the leg each sample lies on: leg i runs from point i to point i + 1), nodes (PackedInt32Array, the sample index of each point)}.
## Fewer than two points gives an empty curve. Every point is a sample exactly (nodes[i] is points[i]).
static func build(points: PackedVector2Array) -> Dictionary:
	var samples := PackedVector2Array()
	var leg := PackedInt32Array()
	var nodes := PackedInt32Array()
	var n := points.size()
	if n < 2:
		return {"samples": samples, "leg": leg, "nodes": nodes}
	for i: int in range(n - 1):
		var p1 := points[i]
		var p2 := points[i + 1]
		# The ends continue straight: the point beyond an end is the reflection of its neighbour.
		var p0 := points[i - 1] if i > 0 else p1 * 2.0 - p2
		var p3 := points[i + 2] if i + 2 < n else p2 * 2.0 - p1
		nodes.append(samples.size())
		for k: int in STEPS:
			samples.append(_segment(p0, p1, p2, p3, float(k) / STEPS))
			leg.append(i)
	samples.append(points[n - 1])
	leg.append(n - 2)
	nodes.append(samples.size() - 1)
	return {"samples": samples, "leg": leg, "nodes": nodes}


## The point at `u` (0 to 1) of the centripetal segment from p1 to p2, with p0 and p3 as its neighbours.
static func _segment(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, u: float) -> Vector2:
	var t0 := 0.0
	var t1 := t0 + _knot(p0, p1)
	var t2 := t1 + _knot(p1, p2)
	var t3 := t2 + _knot(p2, p3)
	var t := t1 + (t2 - t1) * u
	var a1 := _mix(p0, p1, t0, t1, t)
	var a2 := _mix(p1, p2, t1, t2, t)
	var a3 := _mix(p2, p3, t2, t3, t)
	var b1 := _mix(a1, a2, t0, t2, t)
	var b2 := _mix(a2, a3, t1, t3, t)
	return _mix(b1, b2, t1, t2, t)


static func _knot(a: Vector2, b: Vector2) -> float:
	return pow(maxf(a.distance_to(b), EPS), ALPHA)


## The weighted mean of a and b for the knots ta and tb: a at ta, b at tb, linear between.
static func _mix(a: Vector2, b: Vector2, ta: float, tb: float, t: float) -> Vector2:
	var d := tb - ta
	return a * ((tb - t) / d) + b * ((t - ta) / d)


## The samples at a fixed arc spacing (`spacing` in the map's units) along the curve, each with the leg it lies on. Returns
## {points (PackedVector2Array), leg (PackedInt32Array)}; the first and last samples are the curve's ends.
static func resample(samples: PackedVector2Array, leg: PackedInt32Array, spacing: float) -> Dictionary:
	var pts := PackedVector2Array()
	var legs := PackedInt32Array()
	if samples.size() < 2 or spacing <= 0.0:
		return {"points": samples, "leg": leg}
	pts.append(samples[0])
	legs.append(leg[0])
	var carry := 0.0  # the distance from the last point emitted to the start of the next segment
	for j: int in range(samples.size() - 1):
		var a := samples[j]
		var b := samples[j + 1]
		var seg := a.distance_to(b)
		if seg <= 0.0:
			continue
		var at := spacing - carry  # where in this segment the next point falls
		while at <= seg:
			pts.append(a.lerp(b, at / seg))
			legs.append(leg[j])
			at += spacing
		carry = seg - (at - spacing)
	pts.append(samples[samples.size() - 1])
	legs.append(leg[leg.size() - 1])
	return {"points": pts, "leg": legs}
