## Ridges, passes, borders, capitals and the hex under the mouse: plain marks drawn over the tiles (art inventory:
## redone in Godot). Borders show in the countries view only; the rest in both views.
class_name MapMarks
extends Node2D

const RIDGE_INK := Color(0.12, 0.09, 0.07, 0.9)
const PASS_MARK := Color(0.93, 0.78, 0.35, 0.95)
const BORDER_WIDTH := 6.0
const CAPITAL_FILL := Color(0.98, 0.84, 0.3, 1.0)
const CAPITAL_EDGE := Color(0.12, 0.09, 0.05, 1.0)
const HOVER_LINE := Color(1.0, 0.97, 0.75, 0.9)
const HALF_SIDE := 30.0  # half of a side of a hex at radius 60 (the side equals the radius)

var map: MapData
var hover: Vector2i = Vector2i(-1, -1)
var borders: Array[Dictionary] = []  # the border edges with their shades (Political.border_items)
var capitals: Array[Vector2i] = []  # the capitals (Political.capitals)
var show_borders := false


func _draw() -> void:
	if map == null:
		return
	if show_borders:
		for item: Dictionary in borders:
			# Python's owner borders: a dark line and a light line inside it, widths in world pixels at radius 60.
			var edge := _edge_segment(item["a"], item["b"], HALF_SIDE)
			draw_line(edge[0], edge[1], item["dark"], BORDER_WIDTH, true)
			var inner := _edge_segment(item["a"], item["b"], HALF_SIDE - 4.0)
			draw_line(inner[0], inner[1], item["light"], BORDER_WIDTH * 0.42, true)
	for key: Vector4i in map.ridge_edges.keys():
		var seg := _edge_segment(Vector2i(key.x, key.y), Vector2i(key.z, key.w), HALF_SIDE)
		draw_line(seg[0], seg[1], RIDGE_INK, 6.0, true)
	for key: Vector4i in map.pass_names.keys():
		var seg := _edge_segment(Vector2i(key.x, key.y), Vector2i(key.z, key.w), HALF_SIDE)
		draw_circle((seg[0] + seg[1]) * 0.5, 14.0, PASS_MARK)
	for pos: Vector2i in capitals:
		_capital_mark(MapGeometry.centre(pos))
	if map.has_hex(hover):
		var c := MapGeometry.centre(hover)
		var corners := PackedVector2Array()
		for k in 6:
			var a := deg_to_rad(30.0 + 60.0 * float(k))
			corners.append(c + Vector2(cos(a), sin(a)) * 60.0)
		corners.append(corners[0])
		draw_polyline(corners, HOVER_LINE, 5.0, true)


## A capital: a gold diamond with a dark rim, the size of a town's piece.
func _capital_mark(c: Vector2) -> void:
	var r := 18.0
	var diamond := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(diamond, CAPITAL_FILL)
	diamond.append(diamond[0])
	draw_polyline(diamond, CAPITAL_EDGE, 3.0, true)


## The two ends of the side shared by two neighbouring hexes, `half` pixels either side of the middle of the side.
static func _edge_segment(a: Vector2i, b: Vector2i, half: float) -> PackedVector2Array:
	var ca := MapGeometry.centre(a)
	var cb := MapGeometry.centre(b)
	var mid := (ca + cb) * 0.5
	var dir := (cb - ca).normalized()
	var perp := Vector2(-dir.y, dir.x) * half
	return PackedVector2Array([mid - perp, mid + perp])
