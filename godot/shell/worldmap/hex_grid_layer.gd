## The faint hex grid of the north Italy map (the style frame's hexgrid: thin dark lines at low alpha), drawn over the
## ground, the rivers and the roads and under every standing thing. Each hex is outlined once from its centre in map
## pixels: pointy top, radius 60 px, squashed to the map's tilt. Key G in NorthItalyMap turns it on and off.
class_name HexGridLayer
extends Node2D

const RADIUS := 60.0
const LINE := Color(0.12, 0.16, 0.12, 0.22)
const WIDTH := 1.0

var _outlines: Array[PackedVector2Array] = []


## The hex centres in map pixels and the map's vertical squash (0.85).
func set_hexes(centres: Array[Vector2], tilt: float) -> void:
	_outlines.clear()
	for centre: Vector2 in centres:
		var points := PackedVector2Array()
		for k: int in 7:
			var a := deg_to_rad(-90.0 + 60.0 * float(k % 6))
			points.append(centre + Vector2(RADIUS * cos(a), RADIUS * sin(a) * tilt))
		_outlines.append(points)
	queue_redraw()


func _draw() -> void:
	for points: PackedVector2Array in _outlines:
		draw_polyline(points, LINE, WIDTH, true)
