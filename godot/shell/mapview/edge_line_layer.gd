## Draws the lines of core/views/edge_lines.gd (rivers, streams, roads, tracks) for one chunk of the map as ONE mesh,
## built when the lines are set. A chunk that is off the screen is skipped by the engine, and a chunk on screen is one
## draw call, so the cost is what the camera sees.
##
## Measured in the M1 trial (docs/design/map/m1_trial/notes.md), on a made-up map of 120 x 60 hexes with a river
## every six rows: one node drawing every line with draw_polyline: 18 ms a frame; chunks with draw_polyline: 4 to 19
## ms; chunks with antialiased draw_multiline: 7 to 43 ms; a mesh per chunk: under 2 ms. Canvas draw commands are
## re-sent every frame; a mesh stays on the graphics card.
@tool
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


## The mesh is one surface (or none when there is nothing to draw).
func surface_count() -> int:
	return 0 if _mesh == null else _mesh.get_surface_count()


## The mesh's triangles, for tests that draw them without a window.
func vertices() -> PackedVector2Array:
	return _vertices


func colours() -> PackedColorArray:
	return _colours


func indices() -> PackedInt32Array:
	return _indices


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
		if str(line.get("kind", "")) != "river":
			continue
		var width := float(line["width"])
		if width <= 3.0:
			continue
		var points: PackedVector2Array = line["points"]
		var shift := Vector2(-width * 0.18, -width * 0.12)
		for i: int in range(0, points.size() - 1, 3):
			_stroke(PackedVector2Array([points[i] + shift, points[i].lerp(points[i + 1], 0.45) + shift]),
				maxf(1.0, width * 0.3), RIVER_LIGHT)
	for line: Dictionary in _lines:
		if str(line.get("kind", "")) == "border_band":
			_polygon(line["polygon"] as PackedVector2Array, line["colours"] as PackedColorArray)
	for line: Dictionary in _lines:
		if str(line.get("kind", "")) == "border":
			var width := float(line.get("width", BorderLines.INK_WIDTH))
			var colour: Color = line["colour"] if line.has("colour") else BorderLines.INK
			_stroke(line["points"] as PackedVector2Array, width, colour, line.get("before"), line.get("after"))
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
		if str(line.get("kind", "")) == kind:
			_stroke(line["points"], float(line["width"]) + wider, colour, line.get("before"), line.get("after"))


## One filled convex polygon with per-vertex colours (border_band), sampling the solid middle of _rim_texture().
func _polygon(polygon: PackedVector2Array, colours: PackedColorArray) -> void:
	var count := polygon.size()
	if count < 3 or colours.size() != count:
		return
	var first := _vertices.size()
	_vertices.resize(first + count)
	_colours.resize(first + count)
	_uvs.resize(first + count)
	for i: int in count:
		_vertices[first + i] = polygon[i]
		_colours[first + i] = colours[i]
		_uvs[first + i] = Vector2(0.5, 0.5)
	var written := _indices.size()
	_indices.resize(written + 3 * (count - 2))
	for i: int in range(1, count - 1):
		_indices[written] = first
		_indices[written + 1] = first + i
		_indices[written + 2] = first + i + 1
		written += 3


## One thick line as a ribbon of triangles: two vertices a point, set square to the line's run there.
## `before` and `after` (a Vector2 or null) are the points of the line just outside this piece: they only turn the
## stroke at the ends, so two pieces of one line that share an end point set it square the same way and meet exactly.
func _stroke(points: PackedVector2Array, width: float, colour: Color, before: Variant = null, after: Variant = null) -> void:
	var count := points.size()
	if count < 2:
		return
	var half := width / 2.0 + SOFT
	var first := _vertices.size()
	_vertices.resize(first + 2 * count)
	_colours.resize(first + 2 * count)
	_uvs.resize(first + 2 * count)
	var at := first
	for i: int in count:
		var behind: Vector2 = points[i - 1] if i > 0 else (before if before != null else points[0])
		var ahead: Vector2 = points[i + 1] if i < count - 1 else (after if after != null else points[count - 1])
		var run := (ahead - behind).normalized()
		var side := Vector2(-run.y, run.x) * half
		_vertices[at] = points[i] + side
		_vertices[at + 1] = points[i] - side
		_colours[at] = colour
		_colours[at + 1] = colour
		_uvs[at] = Vector2(0.5, 0.0)
		_uvs[at + 1] = Vector2(0.5, 1.0)
		at += 2
	var written := _indices.size()
	_indices.resize(written + 6 * (count - 1))
	for i: int in count - 1:
		var a := first + 2 * i
		_indices[written] = a
		_indices[written + 1] = a + 1
		_indices[written + 2] = a + 2
		_indices[written + 3] = a + 1
		_indices[written + 4] = a + 3
		_indices[written + 5] = a + 2
		written += 6
