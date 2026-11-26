## The tile window's small drawn marks (issue 436 round 3): shapes the kit's icon atlases do not have, drawn in code from Tokens
## colours so they stay sharp at every UI scale and carry their meaning without colour (H4, M3, M4, M5, L4, M8):
##   EYE_SLASH  an eye struck through (fog: not seen now)          PLUS   a "+" badge (can build)
##   BANG       a "!" badge (short of ducats or goods)               STOP   an octagon with a bar (refused for the season)
##   HOUSE      a dark house silhouette (a free slot)                PIKE   a long pike across a figure tile (pikemen)
##   CROSSBOW   a crossbow's T and bow (crossbowmen)                 TICKS  one tick a season along a siege meter (`count`)
##   OPEN, SHUT a folding head's arrow, down or right
## A glyph takes no pointer: its owner carries the tooltip. Pure drawing.
class_name TileGlyph
extends Control

const EYE_SLASH := &"eye_slash"
const PLUS := &"plus"
const BANG := &"bang"
const STOP := &"stop"
const HOUSE := &"house"
const PIKE := &"pike"
const CROSSBOW := &"crossbow"
const TICKS := &"ticks"
const OPEN := &"open"
const SHUT := &"shut"
const KINDS: Array[StringName] = [EYE_SLASH, PLUS, BANG, STOP, HOUSE, PIKE, CROSSBOW, TICKS, OPEN, SHUT]
## The badge glyphs sit on a small dark disc with a rim in their colour.
const BADGES: Array[StringName] = [PLUS, BANG, STOP]

var kind: StringName = &""
## TICKS: how many seasons the meter spans (a tick between each two).
var count := 0


## A glyph of `kind` at `side` logical pixels (TICKS stretch with their owner instead).
static func make(glyph_kind: StringName, side: float = 14.0) -> TileGlyph:
	var g := TileGlyph.new()
	g.kind = glyph_kind
	g.name = StringName("Glyph_" + String(glyph_kind))
	g.custom_minimum_size = Vector2(side, side)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var c := r.get_center()
	var s := minf(size.x, size.y)
	match kind:
		EYE_SLASH:
			_eye(c, s)
		PLUS:
			_badge(c, s, Tokens.TILE_FREE)
			draw_line(c - Vector2(s * 0.26, 0.0), c + Vector2(s * 0.26, 0.0), Tokens.TEXT, maxf(2.0, s * 0.14), true)
			draw_line(c - Vector2(0.0, s * 0.26), c + Vector2(0.0, s * 0.26), Tokens.TEXT, maxf(2.0, s * 0.14), true)
		BANG:
			_badge(c, s, Tokens.BAD)
			draw_line(c - Vector2(0.0, s * 0.28), c + Vector2(0.0, s * 0.06), Tokens.TEXT, maxf(2.0, s * 0.14), true)
			draw_circle(c + Vector2(0.0, s * 0.24), maxf(1.2, s * 0.08), Tokens.TEXT)
		STOP:
			_octagon(c, s * 0.5, Tokens.BAD)
			draw_line(c - Vector2(s * 0.24, 0.0), c + Vector2(s * 0.24, 0.0), Tokens.TEXT, maxf(2.0, s * 0.16), true)
		HOUSE:
			var roof := PackedVector2Array([Vector2(s * 0.12, s * 0.5), Vector2(s * 0.5, s * 0.16), Vector2(s * 0.88, s * 0.5)])
			draw_colored_polygon(roof, Tokens.TILE_SEP)
			draw_rect(Rect2(s * 0.22, s * 0.5, s * 0.56, s * 0.36), Tokens.TILE_SEP)
		PIKE:
			draw_line(Vector2(size.x * 0.86, size.y * 0.04), Vector2(size.x * 0.2, size.y * 0.96), Tokens.INK, 3.0, true)
			draw_line(Vector2(size.x * 0.86, size.y * 0.04), Vector2(size.x * 0.2, size.y * 0.96), Tokens.BRASS_HI, 1.5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.92, 0.0), Vector2(size.x * 0.76, size.y * 0.1),
				Vector2(size.x * 0.9, size.y * 0.16)]), Tokens.PIC_STONE)
		CROSSBOW:
			var top := Vector2(size.x * 0.5, size.y * 0.12)
			var foot := Vector2(size.x * 0.5, size.y * 0.92)
			draw_line(top, foot, Tokens.INK, 3.0, true)
			draw_line(top, foot, Tokens.BRASS_HI, 1.5, true)
			var bow := PackedVector2Array()
			for k: int in 9:
				var a := PI * (0.1 + 0.8 * k / 8.0)
				bow.append(top + Vector2(-cos(a) * size.x * 0.42, sin(a) * size.y * 0.18 - size.y * 0.02))
			draw_polyline(bow, Tokens.INK, 3.0, true)
			draw_polyline(bow, Tokens.BRASS_HI, 1.5, true)
		TICKS:
			for k: int in range(1, maxi(count, 1)):
				var x := roundf(size.x * float(k) / float(count))
				draw_line(Vector2(x, 0.0), Vector2(x, size.y), Tokens.TILE_WOOD_LINE, 1.0)
		OPEN, SHUT:
			var tri := PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.15), c + Vector2(s * 0.3, -s * 0.15), c + Vector2(0.0, s * 0.22)]) \
				if kind == OPEN else PackedVector2Array([c + Vector2(-s * 0.15, -s * 0.3), c + Vector2(-s * 0.15, s * 0.3),
				c + Vector2(s * 0.22, 0.0)])
			draw_colored_polygon(tri, Tokens.MUTED)


## A dark disc with a rim in the glyph's colour (the corner badges of a building tile).
func _badge(c: Vector2, s: float, rim: Color) -> void:
	draw_circle(c, s * 0.5, Tokens.TILE_INSET)
	draw_circle(c, s * 0.5 - 0.75, rim, false, 1.5, true)
	draw_circle(c, s * 0.5 - 2.0, rim)


func _octagon(c: Vector2, radius: float, fill: Color) -> void:
	var pts := PackedVector2Array()
	for k: int in 8:
		var a := PI / 8.0 + k * PI / 4.0
		pts.append(c + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, Tokens.INK, 1.0, true)


## An almond eye with its pupil, struck through from the lower left to the upper right.
func _eye(c: Vector2, s: float) -> void:
	var w := s * 0.46
	var h := s * 0.26
	var lid := PackedVector2Array()
	for k: int in 17:
		var a := TAU * k / 16.0
		lid.append(c + Vector2(cos(a) * w, sin(a) * h))
	draw_polyline(lid, Tokens.TILE_CHIP_INK, 1.5, true)
	draw_circle(c, s * 0.12, Tokens.TILE_CHIP_INK)
	draw_line(c + Vector2(-w, h * 1.6), c + Vector2(w, -h * 1.6), Tokens.TILE_CHIP_DOT, 3.5, true)
	draw_line(c + Vector2(-w, h * 1.6), c + Vector2(w, -h * 1.6), Tokens.TILE_CHIP_INK, 1.5, true)
