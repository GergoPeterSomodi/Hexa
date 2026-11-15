## Rivers, streams and roads as plain lines for the map view (docs/architecture/m1-build-spec.md, section 6): the
## data says which edges carry what; this turns it into smooth point lists in map px. No nodes, no luck: the same
## data gives the same lines.
##
## A line is a Dictionary: {kind ("river", "stream", "road", "track"), points (PackedVector2Array, map px), width (px),
## rank (the river's class or the road's quality)}.
class_name EdgeLines
extends RefCounted

const RIVER_WIDTH: Array[float] = [0.0, 3.4, 4.6, 6.5]  # by class 1 to 3 (the style frame's)
const STREAM_WIDTH := 2.0
const ROAD_WIDTH: Array[float] = [0.0, 1.3, 2.5, 3.4]  # by quality 1 to 3; quality 1 is a track
const ROAD_SWING := 2.2  # px a road wanders either side of its straight run
const RIVER_STEP := 4.4  # px between a river's points after smoothing
const MEANDER := 2.4  # px a river swings either side of its edge


## Corner cutting (Chaikin): each round replaces every corner by two points a quarter along its sides.
static func smooth(points: PackedVector2Array, rounds: int) -> PackedVector2Array:
	var pts := points
	for _i: int in rounds:
		if pts.size() < 3:
			break
		var out := PackedVector2Array([pts[0]])
		for i: int in pts.size() - 1:
			out.append(pts[i].lerp(pts[i + 1], 0.25))
			out.append(pts[i].lerp(pts[i + 1], 0.75))
		out.append(pts[pts.size() - 1])
		pts = out
	return pts


## The same line with a point every `step` px (the two ends kept).
static func resample(points: PackedVector2Array, step: float) -> PackedVector2Array:
	if points.size() < 2:
		return points
	var out := PackedVector2Array([points[0]])
	var carried := 0.0
	for i: int in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var d := a.distance_to(b)
		if d <= 0.0:
			continue
		var t := step - carried
		while t <= d:
			out.append(a.lerp(b, t / d))
			t += step
		carried = fmod(carried + d, step)
	if out[out.size() - 1].distance_to(points[points.size() - 1]) > step * 0.3:
		out.append(points[points.size() - 1])
	return out


## A river: its edge line smoothed, with a slow meander that is the same every time for the same `phase`.
static func river(edge_points: PackedVector2Array, river_class: int, phase: float) -> Dictionary:
	var pts := resample(smooth(edge_points, 3), RIVER_STEP)
	var out := PackedVector2Array()
	for i: int in pts.size():
		if i == 0 or i == pts.size() - 1:
			out.append(pts[i])
			continue
		var along := (pts[i + 1] - pts[i - 1]).normalized()
		var side := Vector2(-along.y, along.x)
		var swing := sin(float(i) * 0.55 + phase) * 0.54 + sin(float(i) * 0.21 + phase * 2.0) * 0.46
		out.append(pts[i] + side * swing * MEANDER)
	return {"kind": "river", "points": out, "width": RIVER_WIDTH[clampi(river_class, 1, 3)], "rank": river_class}


## A stream on one edge: from corner to corner, bowed a little.
static func stream(corner_a: Vector2, corner_b: Vector2) -> Dictionary:
	var mid := (corner_a + corner_b) / 2.0 + Vector2(4.0, 0.0)
	var pts := resample(smooth(PackedVector2Array([corner_a, mid, corner_b]), 3), RIVER_STEP)
	return {"kind": "stream", "points": pts, "width": STREAM_WIDTH, "rank": 0}


## Roads: `steps` are the road's hex-to-hex steps as [from, to, quality] (each edge once), `centres` gives the middle
## of a hex in map px. Steps are joined into runs of one quality between junctions, drawn through the middles of the
## hexes and smoothed, so a road bends through a hex instead of turning on a point.
static func roads(steps: Array[Array], centres: Callable) -> Array[Dictionary]:
	var links: Dictionary[Vector2i, Array] = {}
	for n: int in steps.size():
		var step: Array = steps[n]
		for end: int in 2:
			var hex: Vector2i = step[end]
			if not links.has(hex):
				links[hex] = []
			links[hex].append(n)
	var used := PackedByteArray()
	used.resize(steps.size())
	var out: Array[Dictionary] = []
	for n: int in steps.size():
		if used[n] == 1:
			continue
		var first: Array = steps[n]
		var quality: int = first[2]
		used[n] = 1
		var chain: Array[Vector2i] = [first[0], first[1]]
		for side: int in 2:
			while true:
				var tip: Vector2i = chain[chain.size() - 1] if side == 0 else chain[0]
				var next := _only_way_on(tip, links[tip], steps, used, quality)
				if next < 0:
					break
				used[next] = 1
				var step: Array = steps[next]
				var other: Vector2i = step[1] if step[0] == tip else step[0]
				if side == 0:
					chain.append(other)
				else:
					chain.insert(0, other)
		var pts := PackedVector2Array()
		for hex: Vector2i in chain:
			var at: Vector2 = centres.call(hex)
			pts.append(at)
		var line := resample(smooth(pts, 3), 3.0)
		var phase := float(posmod(chain[0].x * 7 + chain[0].y * 13, 17))
		for i: int in range(1, line.size() - 1):
			var along := (line[i + 1] - line[i - 1]).normalized()
			var ease := minf(1.0, float(mini(i, line.size() - 1 - i)) / 8.0)  # the two ends stay on their hexes
			line[i] += Vector2(-along.y, along.x) * sin(float(i) * 0.19 + phase) * ROAD_SWING * ease
		out.append({"kind": "road" if quality >= 2 else "track", "points": line,
			"width": ROAD_WIDTH[clampi(quality, 1, 3)], "rank": quality})
	return out


## The one unused step of the same quality that goes on from a hex, or -1 at a junction, an end or a change of
## quality (a run stops there).
static func _only_way_on(_hex: Vector2i, here: Array, steps: Array[Array], used: PackedByteArray, quality: int) -> int:
	if here.size() != 2:
		return -1
	for entry: Variant in here:
		var n: int = entry
		var step: Array = steps[n]
		var q: int = step[2]
		if used[n] == 0 and q == quality:
			return n
	return -1
