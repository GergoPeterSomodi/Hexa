## Ridges, passes and the hex under the mouse: plain marks drawn over the tiles (art inventory: redone in Godot).
class_name MapMarks
extends Node2D

const RIDGE_INK := Color(0.12, 0.09, 0.07, 0.9)
const PASS_MARK := Color(0.93, 0.78, 0.35, 0.95)
const HOVER_LINE := Color(1.0, 0.97, 0.75, 0.9)
const HALF_SIDE := 30.0  # half of a side of a hex at radius 60 (the side equals the radius)

var map: MapData
var hover: Vector2i = Vector2i(-1, -1)


func _draw() -> void:
	if map == null:
		return
	for key: Vector4i in map.ridge_edges.keys():
		var seg := _edge_segment(Vector2i(key.x, key.y), Vector2i(key.z, key.w), HALF_SIDE)
		draw_line(seg[0], seg[1], RIDGE_INK, 6.0, true)
	for key: Vector4i in map.pass_names.keys():
		var seg := _edge_segment(Vector2i(key.x, key.y), Vector2i(key.z, key.w), HALF_SIDE)
		draw_circle((seg[0] + seg[1]) * 0.5, 14.0, PASS_MARK)
	if map.has_hex(hover):
		var c := MapGeometry.centre(hover)
		var corners := PackedVector2Array()
		for k in 6:
			var a := deg_to_rad(30.0 + 60.0 * float(k))
			corners.append(c + Vector2(cos(a), sin(a)) * 60.0)
		corners.append(corners[0])
		draw_polyline(corners, HOVER_LINE, 5.0, true)


## The two ends of the side shared by two neighbouring hexes, `half` pixels either side of the middle of the side.
static func _edge_segment(a: Vector2i, b: Vector2i, half: float) -> PackedVector2Array:
	var ca := MapGeometry.centre(a)
	var cb := MapGeometry.centre(b)
	var mid := (ca + cb) * 0.5
	var dir := (cb - ca).normalized()
	var perp := Vector2(-dir.y, dir.x) * half
	return PackedVector2Array([mid - perp, mid + perp])
