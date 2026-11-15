## Draws the lines of core/views/edge_lines.gd (rivers, streams, roads, tracks) for one chunk of the map as ONE mesh,
## built when the lines are set. A chunk that is off the screen is skipped by the engine, and a chunk on screen is one
## draw call, so the cost is what the camera sees.
##
## Measured in the M1 trial (docs/design/map/m1_trial/notes.md), on a made-up map of 120 x 60 hexes with a river
## every six rows: one node drawing every line with draw_polyline: 18 ms a frame; chunks with draw_polyline: 4 to 19
## ms; chunks with antialiased draw_multiline: 7 to 43 ms; a mesh per chunk: under 2 ms. Canvas draw commands are
## re-sent every frame; a mesh stays on the graphics card.
class_name EdgeLineLayer
extends Node2D

const RIVER := Color8(74, 146, 206)
const RIVER_EDGE := Color8(44, 92, 140)
const RIVER_LIGHT := Color8(128, 190, 232)
const ROAD := Color8(226, 206, 152)
const ROAD_EDGE := Color8(128, 100, 66)
const TRACK := Color8(196, 176, 126, 190)
const EDGE := 2.0  # px the dark edge is wider than the line
const SOFT := 0.5  # px added either side for the soft rim of the stroke texture

static var _rim: Texture2D = null

var _lines: Array[Dictionary] = []
var _mesh: ArrayMesh = null
var _vertices := PackedVector2Array()
var _colours := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()


func set_lines(lines: Array[Dictionary]) -> void:
	_lines = lines
	_build()
	queue_redraw()


func line_count() -> int:
	return _lines.size()


func _draw() -> void:
	if _mesh != null:
		draw_mesh(_mesh, _rim_texture())


## A strip one texel wide: clear at both ends, solid between, so a stroke's two rims are soft.
static func _rim_texture() -> Texture2D:
	if _rim == null:
		var image := Image.create(1, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		image.set_pixel(0, 0, Color(1, 1, 1, 0))
		image.set_pixel(0, 15, Color(1, 1, 1, 0))
		_rim = ImageTexture.create_from_image(image)
	return _rim


func _build() -> void:
	_vertices.clear()
	_colours.clear()
	_uvs.clear()
	_indices.clear()
	# Tracks, then water, then roads (a road crosses a river on its bridge or ford). Within a kind all dark edges
	# come before all fills, so two lines that meet run into each other. Triangles are drawn in this order.
	_pass("track", 0.0, TRACK)
	for kind: String in ["stream", "river", "road"]:
		_pass(kind, EDGE, ROAD_EDGE if kind == "road" else RIVER_EDGE)
		_pass(kind, 0.0, ROAD if kind == "road" else RIVER)
	for line: Dictionary in _lines:  # the light on a river's lit bank: short dashes
		var width := float(line["width"])
		if str(line["kind"]) != "river" or width <= 3.0:
			continue
		var points: PackedVector2Array = line["points"]
		var shift := Vector2(-width * 0.18, -width * 0.12)
		for i: int in range(0, points.size() - 1, 3):
			_stroke(PackedVector2Array([points[i] + shift, points[i].lerp(points[i + 1], 0.45) + shift]),
				maxf(1.0, width * 0.3), RIVER_LIGHT)
	_mesh = null
	if _indices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colours
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _pass(kind: String, wider: float, colour: Color) -> void:
	for line: Dictionary in _lines:
		if str(line["kind"]) == kind:
			_stroke(line["points"], float(line["width"]) + wider, colour)


## One thick line as a ribbon of triangles: two vertices a point, set square to the line's run there.
func _stroke(points: PackedVector2Array, width: float, colour: Color) -> void:
	var count := points.size()
	if count < 2:
		return
	var half := width / 2.0 + SOFT
	var first := _vertices.size()
	for i: int in count:
		var run := (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-run.y, run.x) * half
		_vertices.append(points[i] + side)
		_vertices.append(points[i] - side)
		_colours.append(colour)
		_colours.append(colour)
		_uvs.append(Vector2(0.5, 0.0))
		_uvs.append(Vector2(0.5, 1.0))
	for i: int in count - 1:
		var a := first + 2 * i
		_indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
