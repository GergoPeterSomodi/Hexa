## Ridges, passes, borders, the capitals' flags, the controller stripes and the hex under the mouse: plain marks drawn over
## the tiles (art inventory: redone in Godot). Borders show in the countries view only; the flags and the stripes in the
## countries view at the tile zoom (Python's _political_marks, which runs only in the political mode); the rest in both views.
class_name MapMarks
extends Node2D

const RIDGE_INK := Color(0.12, 0.09, 0.07, 0.9)
const PASS_MARK := Color(0.93, 0.78, 0.35, 0.95)
const BORDER_RADIUS := 60.0  # the radius the world is drawn at; the zoom is radius / 60
const FLAG_POLE := Color(60.0 / 255.0, 45.0 / 255.0, 35.0 / 255.0)  # Python's _flag
const FLAG_EDGE := Color(20.0 / 255.0, 20.0 / 255.0, 20.0 / 255.0)
const HOVER_LINE := Color(1.0, 0.97, 0.75, 0.9)
const HALF_SIDE := 30.0  # half of a side of a hex at radius 60 (the side equals the radius)

var map: MapData
var hover: Vector2i = Vector2i(-1, -1)
var borders: Array[Dictionary] = []  # the border edges with their shades (Political.border_items)
var flags: Array[Dictionary] = []  # the capitals' flags: {"pos", "colour"} (Political.capital_flags)
var controls: Array[Dictionary] = []  # the hexes held by another country: {"pos", "colour"} (Political.control_items)
var show_borders := false
var show_tile_marks := false  # the flags and the controller stripes (countries view, tile zoom)
## Border widths in world pixels for the zoom now: Python's widths in screen pixels (MapView._owner_borders: the dark
## line max(2, r // 8) wide, the light line half of it), divided by the zoom, so that they read the same at every zoom.
var _border_world := 6.0
var _inner_world := 2.5
var _px := 1.0  # one screen pixel in world pixels (1 / zoom)
var _flag_size := 8.0  # a flag's size in world pixels: Python's max(8, r // 3) screen pixels


## Sets the border widths and the flag size for a zoom (the radius of a hex on screen is 60 * zoom). Redraws only when
## they change.
func set_zoom(zoom: float) -> void:
	var radius_px := BORDER_RADIUS * zoom
	var dark_px := maxf(2.0, floorf(radius_px / 8.0))
	var light_px := maxf(1.0, floorf(dark_px / 2.0))
	var dark_world := dark_px / zoom
	var inner_world := light_px / zoom
	var flag_px := maxf(8.0, floorf(float(int(round(radius_px))) / 3.0))
	var px := 1.0 / zoom
	var flag_world := flag_px / zoom
	if dark_world != _border_world or inner_world != _inner_world or flag_world != _flag_size or px != _px:
		_border_world = dark_world
		_inner_world = inner_world
		_flag_size = flag_world
		_px = px
		queue_redraw()


func _draw() -> void:
	if map == null:
		return
	if show_borders:
		for item: Dictionary in borders:
			# Python's owner borders: a dark line and a light line inside it, widths in world pixels at radius 60.
			var edge := _edge_segment(item["a"], item["b"], HALF_SIDE)
			draw_line(edge[0], edge[1], item["dark"], _border_world, true)
			var inner := _edge_segment(item["a"], item["b"], HALF_SIDE - 4.0)
			draw_line(inner[0], inner[1], item["light"], _inner_world, true)
	if show_tile_marks:
		for item: Dictionary in controls:
			_control_stripes(MapGeometry.centre(item["pos"]), item["colour"])
	for key: Vector4i in map.ridge_edges.keys():
		var seg := _edge_segment(Vector2i(key.x, key.y), Vector2i(key.z, key.w), HALF_SIDE)
		draw_line(seg[0], seg[1], RIDGE_INK, 6.0, true)
	for key: Vector4i in map.pass_names.keys():
		var seg := _edge_segment(Vector2i(key.x, key.y), Vector2i(key.z, key.w), HALF_SIDE)
		draw_circle((seg[0] + seg[1]) * 0.5, 14.0, PASS_MARK)
	if show_tile_marks:
		for item: Dictionary in flags:
			var c := MapGeometry.centre(item["pos"])
			_flag(Vector2(c.x + BORDER_RADIUS * 0.35, c.y - BORDER_RADIUS * 0.85), item["colour"])
	if map.has_hex(hover):
		var c := MapGeometry.centre(hover)
		var corners := PackedVector2Array()
		for k in 6:
			var a := deg_to_rad(30.0 + 60.0 * float(k))
			corners.append(c + Vector2(cos(a), sin(a)) * 60.0)
		corners.append(corners[0])
		draw_polyline(corners, HOVER_LINE, 5.0, true)


## Python's controller stripes: three short slanted lines across a hex, in the colour of the country that holds it.
func _control_stripes(c: Vector2, colour: Color) -> void:
	var r := BORDER_RADIUS
	for k: float in [-0.4, 0.0, 0.4]:
		draw_line(Vector2(c.x - r * 0.5 + k * r, c.y + r * 0.45), Vector2(c.x + k * r + r * 0.1, c.y - r * 0.45),
				colour, 3.0 * _px, true)


## A flag on a pole, as Python's MapView._flag: the pole's foot at `at`, a pennant in the owner's colour, a dark edge.
func _flag(at: Vector2, colour: Color) -> void:
	var s := _flag_size
	draw_line(at, at + Vector2(0.0, s * 1.5), FLAG_POLE, 2.0 * _px)
	var pennant := PackedVector2Array([at + Vector2(_px, 0.0), at + Vector2(s, s / 3.0),
			at + Vector2(_px, 2.0 * s / 3.0)])
	draw_colored_polygon(pennant, colour)
	pennant.append(pennant[0])
	draw_polyline(pennant, FLAG_EDGE, _px, true)


## The two ends of the side shared by two neighbouring hexes, `half` pixels either side of the middle of the side.
static func _edge_segment(a: Vector2i, b: Vector2i, half: float) -> PackedVector2Array:
	var ca := MapGeometry.centre(a)
	var cb := MapGeometry.centre(b)
	var mid := (ca + cb) * 0.5
	var dir := (cb - ca).normalized()
	var perp := Vector2(-dir.y, dir.x) * half
	return PackedVector2Array([mid - perp, mid + perp])
