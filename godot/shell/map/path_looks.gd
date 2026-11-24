## The three looks of the army's route on the map (owner ask, issue 434): A ribbon (a solid ink-edged line with an arrowhead on the
## last leg), B dashes (a dashed line with chevrons), C footprints (a dotted trail of footprints with an end flag). Each look draws the
## same curve (PathCurve) in the same colours: a leg that ends out of supply is in MAP_PATH_WARN, the rest in MAP_PATH. Line widths
## are in screen pixels: the callers pass `px`, the map units of one screen pixel (1 / zoom), so the line keeps its width at every zoom.
## Static drawing on any CanvasItem; no state, no game reads.
class_name PathLooks
extends RefCounted

const LINE_WIDTH := 4.0
const INK_WIDTH := 7.0
const THIN_WIDTH := 2.0
const ARROW_SIZE := 14.0
const DASH_ON := 14.0
const DASH_OFF := 8.0
const CHEVRON_EVERY := 56.0
const CHEVRON_ARM := 9.0
const FOOT_EVERY := 20.0
const FOOT_RADIUS := 3.2
const FOOT_OFFSET := 5.5
const DOT_RADIUS := 8.0
const FLAG_POLE := 26.0
const FLAG_WIDTH := 14.0
const FLAG_HEIGHT := 9.0
const RESAMPLE_EVERY := 2.0


## The route as one coloured line: each leg in its colour (`colours`, one per leg), round joints. `width` in screen pixels times px.
static func legs(c: CanvasItem, curve: Dictionary, colours: PackedColorArray, width: float) -> void:
	var s := curve["samples"] as PackedVector2Array
	var nodes := curve["nodes"] as PackedInt32Array
	for i: int in colours.size():
		c.draw_polyline(s.slice(nodes[i], nodes[i + 1] + 1), colours[i], width, true)
	for k: int in nodes.size():
		var colour := colours[mini(k, colours.size() - 1)]
		c.draw_circle(s[nodes[k]], width * 0.5, colour)


## A: the solid ribbon. An ink edge under the whole line, the coloured legs over it and an arrowhead at the middle of the last leg.
static func ribbon(c: CanvasItem, curve: Dictionary, colours: PackedColorArray, px: float) -> void:
	var s := curve["samples"] as PackedVector2Array
	var nodes := curve["nodes"] as PackedInt32Array
	c.draw_polyline(s, Tokens.MAP_PATH_INK, INK_WIDTH * px, true)
	for node: int in nodes:
		c.draw_circle(s[node], INK_WIDTH * px * 0.5, Tokens.MAP_PATH_INK)
	legs(c, curve, colours, LINE_WIDTH * px)
	var last := colours.size() - 1
	var mid := int(float(nodes[last] + nodes[last + 1]) * 0.5)
	_arrow(c, s[mid], s[mid + 1] - s[mid - 1], colours[last], px)


## B: dashes with chevrons. Each dash is an ink-edged coloured run; a chevron points the way every CHEVRON_EVERY screen pixels.
static func dashed(c: CanvasItem, curve: Dictionary, colours: PackedColorArray, px: float) -> void:
	var fine := PathCurve.resample(curve["samples"] as PackedVector2Array, curve["leg"] as PackedInt32Array, RESAMPLE_EVERY * px)
	var pts := fine["points"] as PackedVector2Array
	var legs_at := fine["leg"] as PackedInt32Array
	var runs := _dash_runs(pts, legs_at, DASH_ON * px, (DASH_ON + DASH_OFF) * px)
	for run: Dictionary in runs:
		c.draw_polyline(run["points"] as PackedVector2Array, Tokens.MAP_PATH_INK, INK_WIDTH * px, true)
	for run: Dictionary in runs:
		c.draw_polyline(run["points"] as PackedVector2Array, colours[run["leg"]], LINE_WIDTH * px, true)
	var acc := 0.0
	var step := CHEVRON_EVERY * px
	for k: int in range(pts.size() - 1):
		var next := acc + pts[k].distance_to(pts[k + 1])
		if floori(next / step) > floori(acc / step) and k + 1 < pts.size() - 1:
			_chevron(c, pts[k + 1], pts[k + 1] - pts[k], colours[legs_at[k + 1]], px)
		acc = next


## C: footprints every FOOT_EVERY screen pixels, alternating sides, and a flag at the goal. The start (under the army) and the goal
## (under the flag) get none.
static func footprints(c: CanvasItem, curve: Dictionary, colours: PackedColorArray, px: float) -> void:
	var fine := PathCurve.resample(curve["samples"] as PackedVector2Array, curve["leg"] as PackedInt32Array, FOOT_EVERY * px)
	var pts := fine["points"] as PackedVector2Array
	var legs_at := fine["leg"] as PackedInt32Array
	for k: int in range(1, pts.size() - 1):
		var dir := (pts[k + 1] - pts[k - 1]).normalized()
		var side := 1.0 if k % 2 == 0 else -1.0
		var at := pts[k] + dir.orthogonal() * side * FOOT_OFFSET * px
		var colour := colours[legs_at[k]]
		c.draw_circle(at, (FOOT_RADIUS + 1.2) * px, Tokens.MAP_PATH_INK)
		c.draw_circle(at, FOOT_RADIUS * px, colour)
	var s := curve["samples"] as PackedVector2Array
	_flag(c, s[s.size() - 1], colours[colours.size() - 1], px)


## The dashes of a resampled line: runs of points that are on, each with its leg (a run breaks where the leg changes).
static func _dash_runs(pts: PackedVector2Array, legs_at: PackedInt32Array, on: float, period: float) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	var cur := PackedVector2Array()
	var cur_leg := -1
	var acc := 0.0
	for k: int in range(pts.size() - 1):
		var is_on := fposmod(acc, period) < on
		if is_on and cur_leg != legs_at[k]:
			_close_run(runs, cur, cur_leg)
			cur = PackedVector2Array()
			cur_leg = legs_at[k]
		if is_on:
			if cur.is_empty():
				cur.append(pts[k])
			cur.append(pts[k + 1])
		else:
			_close_run(runs, cur, cur_leg)
			cur = PackedVector2Array()
			cur_leg = -1
		acc += pts[k].distance_to(pts[k + 1])
	_close_run(runs, cur, cur_leg)
	return runs


static func _close_run(runs: Array[Dictionary], run: PackedVector2Array, leg: int) -> void:
	if run.size() >= 2:
		runs.append({"points": run, "leg": leg})


## An arrowhead at `at`, pointing along `dir`, in `colour` with an ink edge.
static func _arrow(c: CanvasItem, at: Vector2, dir: Vector2, colour: Color, px: float) -> void:
	var fwd := dir.normalized()
	var side := fwd.orthogonal()
	var size := ARROW_SIZE * px
	var poly := PackedVector2Array([at + fwd * size * 0.6, at - fwd * size * 0.4 + side * size * 0.5,
		at - fwd * size * 0.4 - side * size * 0.5])
	c.draw_colored_polygon(poly, colour)
	c.draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[0]]), Tokens.MAP_PATH_INK, 1.5 * px, true)


## A chevron ">" with its tip at `at`, pointing along `dir`.
static func _chevron(c: CanvasItem, at: Vector2, dir: Vector2, colour: Color, px: float) -> void:
	var back := -dir.normalized() * CHEVRON_ARM * px
	var arm_a := at + back.rotated(0.6)
	var arm_b := at + back.rotated(-0.6)
	var line := PackedVector2Array([arm_a, at, arm_b])
	c.draw_polyline(line, Tokens.MAP_PATH_INK, 5.0 * px, true)
	c.draw_polyline(line, colour, 2.5 * px, true)


## The end flag: a pole up from `at` and a pennant of `colour` with an ink edge.
static func _flag(c: CanvasItem, at: Vector2, colour: Color, px: float) -> void:
	var top := at + Vector2(0.0, -FLAG_POLE * px)
	c.draw_line(at, top, Tokens.MAP_PATH_INK, 3.0 * px, true)
	var pennant := PackedVector2Array([top, top + Vector2(FLAG_WIDTH * px, FLAG_HEIGHT * 0.5 * px),
		top + Vector2(0.0, FLAG_HEIGHT * px)])
	c.draw_colored_polygon(pennant, colour)
	c.draw_polyline(PackedVector2Array([pennant[0], pennant[1], pennant[2], pennant[0]]), Tokens.MAP_PATH_INK, 1.5 * px, true)


## A stop as a dot (look A): an ink ring and a coloured disc, `size` in map units.
static func dot(c: CanvasItem, at: Vector2, size: float, colour: Color) -> void:
	c.draw_circle(at, size * 1.25, Tokens.MAP_PATH_INK)
	c.draw_circle(at, size, colour)
