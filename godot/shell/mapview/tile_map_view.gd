## The map as a stack of TileMapLayers on one hex grid (docs/architecture/godot-architecture.md section 3.2 and
## docs/architecture/m1-build-spec.md section 4). It holds no facts: it is told which tile name goes on which cell of
## which layer (core/views/map_tiles.gd picks the names) and draws them.
##
## Bottom to top (LAYERS): ground cover (tiles ranked by their z, so one cover spills onto the next); relief shade
## (multiplied) and light (added); the sea; the coast; the pieces' flat ground and a harbour's; the hex grid; rivers
## and roads (EdgeLineLayer); the shadows as one group; then the standing things, sorted by depth as one group: the
## relief, the six tree wedges, a piece's back and front band, a harbour.
class_name TileMapView
extends Node2D

## Layer name -> [z index, kind]. Kinds: "" plain, "mul", "add", "shadow" (in the shadow group), "stand" (in the
## depth-sorted group).
const LAYERS: Dictionary[String, Array] = {
	"ground": [0, ""], "shade": [10, "mul"], "light": [11, "add"], "sea": [20, ""], "coast": [30, ""],
	"piece_ground": [40, ""], "addon_ground": [41, ""], "grid": [45, ""],
	"piece_shadow": [0, "shadow"], "addon_shadow": [0, "shadow"],
	"relief": [0, "stand"], "trees0": [0, "stand"], "trees1": [0, "stand"], "trees2": [0, "stand"],
	"trees3": [0, "stand"], "trees4": [0, "stand"], "trees5": [0, "stand"],
	"piece_back": [0, "stand"], "piece_front": [0, "stand"], "addon": [0, "stand"],
}
const LINES_Z := 50
const LINE_CHUNK := 32  # cells a side
const LINE_PIECE := 24  # points in one piece of a line
const SHADOW_Z := 60
const STAND_Z := 70
const SHADOW_ALPHA := 0.18
const SHADOW_SHADER := "res://shell/mapview/shadow_cover.gdshader"

var _names: Dictionary[String, Vector3i] = {}
var _layers: Dictionary[String, TileMapLayer] = {}
var _lines: Node2D = null
var _line_chunks: Dictionary[Vector2i, EdgeLineLayer] = {}
var _missing: Dictionary[String, bool] = {}


## Makes the layers for a tileset (TilesetBuilder). Call once, before any set_tile.
func setup(tiles: TilesetBuilder) -> void:
	_names = tiles.names
	var shadows := CanvasGroup.new()
	shadows.name = "Shadows"
	shadows.z_index = SHADOW_Z
	shadows.self_modulate = Color(1.0, 1.0, 1.0, SHADOW_ALPHA)
	var standing := Node2D.new()
	standing.name = "Standing"
	standing.z_index = STAND_Z
	standing.y_sort_enabled = true
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = load(SHADOW_SHADER) as Shader
	for layer_name: String in LAYERS:
		var spec: Array = LAYERS[layer_name]
		var kind := str(spec[1])
		var layer := TileMapLayer.new()
		layer.name = layer_name.to_pascal_case()
		layer.tile_set = tiles.tile_set
		layer.z_index = int(spec[0])
		match kind:
			"mul", "add":
				var blend := CanvasItemMaterial.new()
				blend.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL if kind == "mul" else CanvasItemMaterial.BLEND_MODE_ADD
				layer.material = blend
				add_child(layer)
			"shadow":
				layer.material = shadow_material
				shadows.add_child(layer)
			"stand":
				layer.y_sort_enabled = true
				standing.add_child(layer)
			_:
				add_child(layer)
		_layers[layer_name] = layer
	_lines = Node2D.new()
	_lines.name = "Lines"
	_lines.z_index = LINES_Z
	add_child(_lines)
	add_child(shadows)
	add_child(standing)


## Puts a tile on a cell of a layer; "" (or a name the tileset does not have) clears the cell.
func set_tile(layer_name: String, cell: Vector2i, tile_name: String) -> void:
	var layer := _layers[layer_name]
	if tile_name == "" or not _names.has(tile_name):
		if tile_name != "":
			_missing[tile_name] = true
		layer.erase_cell(cell)
		return
	var at := _names[tile_name]
	layer.set_cell(cell, at.x, Vector2i(at.y, at.z))


## Rivers, streams and roads (core/views/edge_lines.gd). The lines are cut into short pieces and each piece goes to
## the chunk it starts in: one drawn node per chunk of LINE_CHUNK cells, so only the chunks on screen are drawn.
func set_lines(lines: Array[Dictionary]) -> void:
	for chunk: Vector2i in _line_chunks:
		_line_chunks[chunk].queue_free()
	_line_chunks.clear()
	var buckets: Dictionary[Vector2i, Array] = {}
	for line: Dictionary in lines:
		var points: PackedVector2Array = line["points"]
		var start := 0
		while start < points.size() - 1:
			var end := mini(start + LINE_PIECE, points.size() - 1)
			var piece := line.duplicate()
			piece["points"] = points.slice(start, end + 1)
			var chunk := Vector2i((hex_at(points[start]) / float(LINE_CHUNK)).floor())
			if not buckets.has(chunk):
				buckets[chunk] = []
			buckets[chunk].append(piece)
			start = end
	for chunk: Vector2i in buckets:
		var node := EdgeLineLayer.new()
		node.name = "Lines_%d_%d" % [chunk.x, chunk.y]
		_lines.add_child(node)
		var list: Array[Dictionary] = []
		list.assign(buckets[chunk])
		node.set_lines(list)
		_line_chunks[chunk] = node


func set_layer_visible(layer_name: String, value: bool) -> void:
	_layers[layer_name].visible = value


func layer(layer_name: String) -> TileMapLayer:
	return _layers[layer_name]


## The hex under a point of the map (the view's own coordinates).
func hex_at(map_px: Vector2) -> Vector2i:
	return _layers["ground"].local_to_map(map_px)


func centre_of(hex: Vector2i) -> Vector2:
	return _layers["ground"].map_to_local(hex)


## The tile names that were asked for and are not in the tileset (a bake that is behind the rules).
func missing_names() -> Array[String]:
	var out: Array[String] = []
	out.assign(_missing.keys())
	out.sort()
	return out


func cell_count() -> int:
	var total := 0
	for layer_name: String in _layers:
		total += _layers[layer_name].get_used_cells().size()
	return total
