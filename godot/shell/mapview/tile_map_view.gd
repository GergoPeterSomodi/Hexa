## The map as a stack of TileMapLayers on one hex grid (docs/architecture/godot-architecture.md section 3.2 and
## docs/architecture/m1-build-spec.md section 5). It holds no facts: it is told which tile name goes on which cell of
## which layer (core/views/map_cells.gd picks the names) and draws them.
##
## Bottom to top (LAYERS): ground cover (tiles ranked by their z, so one cover spills onto the next); relief shade
## (multiplied) and light (added); the sea; the coast; the pieces' flat ground and a harbour's; the hex grid; rivers
## and roads (EdgeLineLayer, one mesh a chunk); the shadows as one group; then the standing things, sorted by depth as
## one group: the relief, the six tree wedges, a piece's back and front band, a harbour; then the marks (OVERLAYS).
##
## Seasons: every layer shares the season's TileSet (TilesetBuilder), which has three climate slots a source; a cell
## is set with the slot of its hex's climate (set_climates), so set_season swaps the TileSet and writes no cell.
class_name TileMapView
extends Node2D

signal fill_finished

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
## Layers that MapCells does not fill: the selection and build marks (the tint and the fog arrive later).
const OVERLAYS: Dictionary[String, Array] = {"marks": [90, ""]}
const LINES_Z := 50
const SHADOW_Z := 60
const STAND_Z := 70
const SHADOW_ALPHA := 0.18
const SHADOW_SHADER := "res://shell/mapview/shadow_cover.gdshader"
const FILL_BLOCK := 16  # cells a side of one block of the sliced fill
const FILL_PER_FRAME := 4000  # hexes a frame (about 8 ms)

## Cell writes (set_cell and erase_cell) so far: a season swap must not move it.
var cell_writes := 0

var _tiles: TilesetBuilder = null
var _names: Dictionary[String, Vector3i] = {}
var _slots := 1
var _cols := 0
var _climate := PackedByteArray()
var _layers: Dictionary[String, TileMapLayer] = {}
var _lines: Node2D = null
var _line_chunks: Dictionary[Vector2i, EdgeLineLayer] = {}
var _missing: Dictionary[String, bool] = {}
var _fill_provider := Callable()
var _fill_cols := 0
var _fill_rows := 0
var _fill_blocks: Array[Vector2i] = []
var _fill_block := 0
var _fill_at := 0
var _fill_total := 0
var _fill_done := 0


## Makes the layers for a tileset (TilesetBuilder). Call once, before any set_tile.
func setup(tiles: TilesetBuilder) -> void:
	_tiles = tiles
	_names = tiles.names
	_slots = tiles.slots
	set_process(false)
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
	var specs := LAYERS.duplicate()
	specs.merge(OVERLAYS)
	for layer_name: String in specs:
		var spec: Array = specs[layer_name]
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


## The climate of every hex (MapData.climate: 0 snow, 1 frost, 2 mild; `cols` hexes a row). A cell takes the slot of
## its hex's climate when its tile is set, so set this before the cells (a cell already set keeps its slot).
func set_climates(cols: int, climate: PackedByteArray) -> void:
	_cols = cols
	_climate = climate


## Puts a tile on a cell of a layer; "" (or a name the tileset does not have) clears the cell. A cell that already
## shows the tile is not written again.
func set_tile(layer_name: String, cell: Vector2i, tile_name: String) -> void:
	var layer := _layers[layer_name]
	if tile_name == "" or not _names.has(tile_name):
		if tile_name != "":
			_missing[tile_name] = true
		if layer.get_cell_source_id(cell) != -1:
			layer.erase_cell(cell)
			cell_writes += 1
		return
	var at := _names[tile_name]
	var source := _source_of(at.x, cell)
	if layer.get_cell_source_id(cell) == source and layer.get_cell_atlas_coords(cell) == Vector2i(at.y, at.z):
		return
	layer.set_cell(cell, source, Vector2i(at.y, at.z))
	cell_writes += 1


## {layer name: {cell: tile name}}.
func set_cells(cells: Dictionary) -> void:
	for layer_name: String in cells:
		var one: Dictionary = cells[layer_name]
		for cell: Vector2i in one:
			set_tile(layer_name, cell, str(one[cell]))


## {layer name: tile name} for one hex (MapCells.of_hex). Only what differs is written.
func set_hex(hex: Vector2i, names: Dictionary) -> void:
	for layer_name: String in names:
		set_tile(layer_name, hex, str(names[layer_name]))


## Swaps the season: every layer gets the other TileSet. No cell is touched (the cells hold the same source ids and
## atlas places in every season). The view lets go of the previous builder: unless the caller holds it, its pictures
## are freed, so one season's pictures are in video memory.
func set_season(tiles: TilesetBuilder) -> void:
	_tiles = tiles
	_names = tiles.names
	_slots = tiles.slots
	for layer_name: String in _layers:
		_layers[layer_name].tile_set = tiles.tile_set


func season() -> String:
	return "" if _tiles == null else _tiles.season


func _source_of(source_in_index: int, cell: Vector2i) -> int:
	if _slots == 1:
		return source_in_index
	var climate := 0
	if cell.x >= 0 and cell.x < _cols:
		var i := cell.y * _cols + cell.x
		if i >= 0 and i < _climate.size():
			climate = _climate[i]
	return _slots * source_in_index + climate


## Empties every layer and the lines.
func clear() -> void:
	for layer_name: String in _layers:
		_layers[layer_name].clear()
	for chunk: Vector2i in _line_chunks:
		_line_chunks[chunk].queue_free()
	_line_chunks.clear()


## Starts the sliced fill of a map of cols x rows hexes: `provider.call(hex)` gives {layer: tile name} (MapCells.of_hex
## in a lambda). The view is cleared first. Blocks of FILL_BLOCK x FILL_BLOCK hexes go nearest `near` first,
## FILL_PER_FRAME hexes a frame; fill_finished is emitted at the end. fill_step() does a slice by hand (tests).
func begin_fill(cols: int, rows: int, provider: Callable, near: Vector2i) -> void:
	clear()
	_fill_provider = provider
	_fill_cols = cols
	_fill_rows = rows
	_fill_blocks.clear()
	var across := ceili(float(cols) / FILL_BLOCK)
	for by: int in ceili(float(rows) / FILL_BLOCK):
		for bx: int in across:
			_fill_blocks.append(Vector2i(bx, by))
	var target := Vector2(near) / float(FILL_BLOCK) - Vector2(0.5, 0.5)
	_fill_blocks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(target) < Vector2(b).distance_squared_to(target))
	_fill_block = 0
	_fill_at = 0
	_fill_total = cols * rows
	_fill_done = 0
	set_process(true)


func is_filling() -> bool:
	return _fill_block < _fill_blocks.size()


## 0 to 1.
func fill_progress() -> float:
	return 1.0 if _fill_total == 0 else float(_fill_done) / float(_fill_total)


## Fills up to `budget` hexes; true while more is to do.
func fill_step(budget: int) -> bool:
	var left := budget
	while left > 0 and _fill_block < _fill_blocks.size():
		var block := _fill_blocks[_fill_block]
		var column := block.x * FILL_BLOCK + _fill_at % FILL_BLOCK
		@warning_ignore("integer_division")
		var row := block.y * FILL_BLOCK + _fill_at / FILL_BLOCK  # a row inside the block: whole numbers are meant
		_fill_at += 1
		if _fill_at >= FILL_BLOCK * FILL_BLOCK:
			_fill_at = 0
			_fill_block += 1
		if column >= _fill_cols or row >= _fill_rows:
			continue
		left -= 1
		_fill_done += 1
		var hex := Vector2i(column, row)
		var names: Dictionary = _fill_provider.call(hex)
		for layer_name: String in names:
			var tile_name := str(names[layer_name])
			if tile_name != "":
				set_tile(layer_name, hex, tile_name)
	if _fill_block >= _fill_blocks.size():
		set_process(false)
		fill_finished.emit()
		return false
	return true


func _process(_delta: float) -> void:
	fill_step(FILL_PER_FRAME)


## Rivers, streams and roads of one chunk (EdgeLines.for_chunk): one mesh node for the chunk, replaced when the
## chunk's lines change; no lines frees it.
func set_chunk_lines(chunk: Vector2i, lines: Array[Dictionary]) -> void:
	if _line_chunks.has(chunk):
		_line_chunks[chunk].queue_free()
		_line_chunks.erase(chunk)
	if lines.is_empty():
		return
	var node := EdgeLineLayer.new()
	node.name = "Lines_%d_%d" % [chunk.x, chunk.y]
	_lines.add_child(node)
	node.set_lines(lines)
	_line_chunks[chunk] = node


## The chunks that have a line node.
func line_chunks() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_line_chunks.keys())
	return out


## All the lines of the map at once (the trial's way): cut at the chunk borders, one node a chunk.
func set_lines(lines: Array[Dictionary]) -> void:
	for chunk: Vector2i in _line_chunks:
		_line_chunks[chunk].queue_free()
	_line_chunks.clear()
	var cut := EdgeLines.cut(lines)
	for chunk: Vector2i in cut:
		var list: Array[Dictionary] = []
		list.assign(cut[chunk])
		set_chunk_lines(chunk, list)


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
