## Static drawing helpers shared by InkChart and StudyTable: lines with a dash cue, markers, five fills (solid, hatch,
## dots, back hatch, cross hatch), sparks, bars and legend swatches. Colours are passed in by the caller from the Theme;
## the cue is an ink index (0 to 4, as Tokens.CHART_CUES), so a series is told apart by ink AND pattern, never by colour
## alone (m4-5-build-spec.md 6.2). The geometry helpers are pure so tests can check them without a renderer.
class_name InkMarks
extends RefCounted

const FILLS: Array[StringName] = [&"solid", &"hatch", &"dots", &"back_hatch", &"cross_hatch"]
const HATCH_GAP: float = 4.0
const DOT_GAP: float = 4.0
const FILL_WASH: float = 0.18
const SPARK_DOT: float = 2.5


## The cue (ink index) wrapped into the five of Tokens.CHART_CUES.
static func cue_of(cue: int) -> int:
	return posmod(cue, FILLS.size())


## The dash name of a cue: solid, dash, dotted, dash_dot or long_dash.
static func dash_kind(cue: int) -> String:
	return str((Tokens.CHART_CUES[cue_of(cue)] as Dictionary)["dash"])


## The marker name of a cue: dot, square, triangle, diamond or cross.
static func marker_kind(cue: int) -> String:
	return str((Tokens.CHART_CUES[cue_of(cue)] as Dictionary)["marker"])


## The fill name of a cue (FILLS).
static func fill_kind(cue: int) -> StringName:
	return FILLS[cue_of(cue)]


## The length of one dash in px for a dash name (0 for solid).
static func dash_length(kind: String) -> float:
	match kind:
		"dotted":
			return 2.0
		"long_dash":
			return 11.0
		"dash_dot":
			return 8.0
		"dash":
			return 6.0
	return 0.0


## A polyline in `colour` with the dash of `cue`, `width` px wide (M4's drawing, moved here unchanged).
static func line(canvas: CanvasItem, points: PackedVector2Array, colour: Color, cue: int, width: float = 2.0) -> void:
	if points.size() < 2:
		return
	var dash_len := dash_length(dash_kind(cue))
	if dash_len <= 0.0:
		canvas.draw_polyline(points, colour, width, true)
		return
	for i: int in range(points.size() - 1):
		canvas.draw_dashed_line(points[i], points[i + 1], colour, width, dash_len, true, true)


## A marker of `cue`, `size` px across, centred on `at`.
static func marker(canvas: CanvasItem, at: Vector2, colour: Color, cue: int, size: float = 5.0) -> void:
	var r := size * 0.5
	match marker_kind(cue):
		"square":
			canvas.draw_rect(Rect2(at - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), colour)
		"triangle":
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(0.0, -r * 1.15),
				at + Vector2(r, r * 0.9),
				at + Vector2(-r, r * 0.9),
			]), colour)
		"diamond":
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(0.0, -r * 1.15),
				at + Vector2(r * 1.15, 0.0),
				at + Vector2(0.0, r * 1.15),
				at + Vector2(-r * 1.15, 0.0),
			]), colour)
		"cross":
			canvas.draw_line(at + Vector2(-r, -r), at + Vector2(r, r), colour, 1.6, true)
			canvas.draw_line(at + Vector2(-r, r), at + Vector2(r, -r), colour, 1.6, true)
		_:
			canvas.draw_circle(at, r, colour)


## A small triangle for a chart mark: pointing down from above a good point (`above` true) or up from below a bad one.
static func mark_triangle(canvas: CanvasItem, at: Vector2, colour: Color, above: bool, size: float = 6.0) -> void:
	var h := size * 0.5
	var dir := 1.0 if above else -1.0
	canvas.draw_colored_polygon(PackedVector2Array([
		at + Vector2(0.0, h * dir),
		at + Vector2(-h, -h * dir),
		at + Vector2(h, -h * dir),
	]), colour)


## The hatch lines of a fill cue inside `rect`, as pairs of points (a start and an end each), clipped to the rect:
## `hatch` runs "/" , `back_hatch` runs "\", `cross_hatch` both; other cues give none.
static func hatch_segments(rect: Rect2, cue: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var kind := fill_kind(cue)
	if kind == &"hatch" or kind == &"cross_hatch":
		_diagonals(out, rect, false)
	if kind == &"back_hatch" or kind == &"cross_hatch":
		_diagonals(out, rect, true)
	return out


static func _diagonals(out: PackedVector2Array, rect: Rect2, back: bool) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var w := rect.size.x
	var h := rect.size.y
	# a line of "/" is x + y = c measured from the rect's top left (it goes up and to the right); "\" is x - y = c
	var lo := 0.0 if not back else -h
	var hi := w + h if not back else w
	var c := lo + HATCH_GAP * 0.5
	while c < hi:
		var p0 := Vector2.ZERO
		var p1 := Vector2.ZERO
		if not back:
			# x + y = c: from the bottom-left side to the top-right side
			var x0 := clampf(c - h, 0.0, w)
			var x1 := clampf(c, 0.0, w)
			p0 = Vector2(x0, c - x0)
			p1 = Vector2(x1, c - x1)
		else:
			# x - y = c: from the top-left side to the bottom-right side
			var xa := clampf(c, 0.0, w)
			var xb := clampf(c + h, 0.0, w)
			p0 = Vector2(xa, xa - c)
			p1 = Vector2(xb, xb - c)
		if p0.distance_to(p1) > 0.5:
			out.append(rect.position + p0)
			out.append(rect.position + p1)
		c += HATCH_GAP
	return


## The dots of the `dots` fill inside `rect` (staggered every other row); other cues give none.
static func dot_points(rect: Rect2, cue: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if fill_kind(cue) != &"dots" or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return out
	var row := 0
	var y := DOT_GAP * 0.5
	while y < rect.size.y:
		var x := DOT_GAP * 0.5 + (DOT_GAP * 0.5 if row % 2 == 1 else 0.0)
		while x < rect.size.x:
			out.append(rect.position + Vector2(x, y))
			x += DOT_GAP
		y += DOT_GAP * 0.5 + 0.5
		row += 1
	return out


## A rect filled by `cue`: solid in `colour`; the others a pale wash of `colour` with the pattern over it; then `outline`
## (1 px, skipped when its alpha is 0). The hatch in madder is the loss stripe.
static func fill_rect(canvas: CanvasItem, rect: Rect2, colour: Color, cue: int, outline: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if fill_kind(cue) == &"solid":
		canvas.draw_rect(rect, colour)
	else:
		var wash := colour
		wash.a = FILL_WASH
		canvas.draw_rect(rect, wash)
		var lines := hatch_segments(rect, cue)
		for i: int in range(0, lines.size() - 1, 2):
			canvas.draw_line(lines[i], lines[i + 1], colour, 1.0)
		for p: Vector2 in dot_points(rect, cue):
			canvas.draw_rect(Rect2(p - Vector2(0.75, 0.75), Vector2(1.5, 1.5)), colour)
	if outline.a > 0.0:
		canvas.draw_rect(rect.grow(-0.5), outline, false, 1.0)


## The points of a spark's line inside `rect`: x spread over the width, the values scaled to the height (a flat run sits
## in the middle; one value sits at the centre).
static func spark_points(rect: Rect2, values: PackedInt32Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := values.size()
	if n == 0:
		return pts
	var lo := values[0]
	var hi := values[0]
	for v: int in values:
		lo = mini(lo, v)
		hi = maxi(hi, v)
	for i: int in n:
		var x := rect.position.x + rect.size.x * 0.5 if n == 1 else rect.position.x + rect.size.x * float(i) / float(n - 1)
		var t := 0.5 if hi == lo else float(values[i] - lo) / float(hi - lo)
		pts.append(Vector2(x, rect.end.y - t * rect.size.y))
	return pts


## A spark line: the values as a 1.8 px line in `colour`, the last point a dot.
static func spark(canvas: CanvasItem, rect: Rect2, values: PackedInt32Array, colour: Color) -> void:
	var pts := spark_points(rect, values)
	if pts.is_empty():
		return
	if pts.size() >= 2:
		canvas.draw_polyline(pts, colour, 1.8, true)
	canvas.draw_circle(pts[pts.size() - 1], SPARK_DOT, colour)


## The width in px of a bar's filled part: `permille` (clamped 0 to 1000) of the rect's width.
static func bar_length(rect: Rect2, permille: int) -> float:
	return rect.size.x * float(clampi(permille, 0, 1000)) / 1000.0


## A bar: `track` over the whole rect, `colour` over `permille` thousandths of its width from the left.
static func bar(canvas: CanvasItem, rect: Rect2, permille: int, colour: Color, track: Color) -> void:
	canvas.draw_rect(rect, track)
	var len := bar_length(rect, permille)
	if len > 0.0:
		canvas.draw_rect(Rect2(rect.position, Vector2(len, rect.size.y)), colour)


## A legend swatch: the fill of `cue` when `as_fill`, else a short line with the cue's dash and marker.
static func swatch(canvas: CanvasItem, rect: Rect2, colour: Color, cue: int, as_fill: bool) -> void:
	if as_fill:
		fill_rect(canvas, rect, colour, cue, colour)
		return
	var mid := rect.position.y + rect.size.y * 0.5
	var pts := PackedVector2Array([Vector2(rect.position.x, mid), Vector2(rect.end.x, mid)])
	line(canvas, pts, colour, cue, 2.0)
	marker(canvas, Vector2(rect.position.x + rect.size.x * 0.5, mid), colour, cue, minf(5.0, rect.size.y))


## A whole number with thousands commas: 1068 gives "1,068".
static func grouped(v: int) -> String:
	var digits := str(absi(v))
	var out := ""
	for i: int in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if v < 0 else "") + out


## How many legend entries fit in a row from `start` to `limit`: an entry is `lead` px of swatch plus its name's width
## (from `widths`) plus `gap`; when not all fit, the "+N more" marker of width `more_w` must fit too. At least one.
static func legend_fit(widths: PackedFloat32Array, start: float, limit: float, lead: float, gap: float, more_w: float) -> int:
	for reserve: float in [0.0, more_w]:
		var x := start
		var fit := 0
		for w: float in widths:
			var end := x + lead + w
			var room := limit - (reserve if (reserve > 0.0 or fit + 1 < widths.size()) else 0.0)
			if end > room and fit > 0:
				break
			x = end + gap
			fit += 1
		if fit >= widths.size() or reserve > 0.0:
			return maxi(1, fit) if widths.size() > 0 else 0
	return 0
