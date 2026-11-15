## The selected hex of the north Italy map: a gold outline with a light fill, drawn over everything on the map (the
## Python game's selection look). NorthItalyMap sets it when a hex is clicked and clears it with Esc.
class_name HexSelectLayer
extends Node2D

const RADIUS := 60.0
const EDGE := Color(1.0, 0.86, 0.35, 0.95)
const EDGE_DARK := Color(0.2, 0.14, 0.04, 0.55)
const FILL := Color(1.0, 0.92, 0.6, 0.16)

var _points := PackedVector2Array()


## Outline the hex with this centre (map pixels), squashed to the map's tilt.
func select(centre: Vector2, tilt: float) -> void:
	_points = PackedVector2Array()
	for k: int in 7:
		var a := deg_to_rad(-90.0 + 60.0 * float(k % 6))
		_points.append(centre + Vector2(RADIUS * cos(a), RADIUS * sin(a) * tilt))
	visible = true
	queue_redraw()


func clear() -> void:
	_points = PackedVector2Array()
	visible = false
	queue_redraw()


func _draw() -> void:
	if _points.size() < 7:
		return
	var fill := _points.slice(0, 6)
	draw_colored_polygon(fill, FILL)
	draw_polyline(_points, EDGE_DARK, 4.0, true)
	draw_polyline(_points, EDGE, 2.0, true)
