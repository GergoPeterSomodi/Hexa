## The map as a stack of TileMapLayers on one hex grid (docs/architecture/godot-architecture.md section 3.2 and
## docs/architecture/m1-build-spec.md section 5). It holds no facts: it is told which tile name goes on which cell of
## which layer (core/views/map_cells.gd picks the names) and draws them.
##
## Bottom to top (LAYERS): ground cover (tiles ranked by their z, so one cover spills onto the next); relief shade
## (multiplied) and light (added); the sea; the coast; the pieces' flat ground and a harbour's; the hex grid; rivers
## and roads (EdgeLineLayer, one mesh a chunk); the shadows as one group; then the standing things, sorted by depth as
## one group: the relief, the six tree wedges, a piece's back and front band, a harbour, the three crossing layers;
## then the marks (OVERLAYS).
##
## Seasons: every layer but two shares the season's TileSet (TilesetBuilder), which has three climate slots a source; a
## cell is set with the slot of its hex's climate (set_climates), so a season swap writes no cell. Godot rebuilds a
## TileMapLayer when its TileSet changes (about 1 ms for 1,000 cells), so two things keep a swap from stopping the game:
## the grid and the marks have a TileSet of their own that is the same in every season (they never swap), and every
## other layer is cut into chunks of 128 x 64 cells (64 x 32 on a map that is bigger than one), one TileMapLayer a chunk and layer, made when the first cell
## lands in it. A swap (begin_season_swap, swap_step) then goes a chunk and a layer at a time, the chunks that are on
## the screen first, and takes only the time it is given a frame. `layer(name)` is the layer of the first chunk (the
## whole layer of a map of one chunk); `layers_of(name)` gives them all.
class_name TileMapView
extends Node2D

signal fill_finished
signal season_swapped

## Layer name -> [z index, kind]. Kinds: "" plain, "mul", "add", "shadow" (in the shadow group), "stand" (in the
## depth-sorted group).
const LAYERS: Dictionary[String, Array] = {
	"ground": [0, ""], "shade": [10, "mul"], "light": [11, "add"], "sea": [20, ""], "coast": [30, ""],
	"piece_ground": [40, ""], "addon_ground": [41, ""], "grid": [45, ""],
	"piece_shadow": [0, "shadow"], "addon_shadow": [0, "shadow"],
	"relief": [0, "stand"], "trees0": [0, "stand"], "trees1": [0, "stand"], "trees2": [0, "stand"],
	"trees3": [0, "stand"], "trees4": [0, "stand"], "trees5": [0, "stand"],
	"piece_back": [0, "stand"], "piece_front": [0, "stand"], "addon": [0, "stand"],
	"crossing0": [0, "stand"], "crossing1": [0, "stand"], "crossing2": [0, "stand"],
}
## Layers that MapCells does not fill: the selection and build marks (the tint and the fog arrive later).
const OVERLAYS: Dictionary[String, Array] = {"marks": [90, ""]}
## The layers that hold marks only: one TileSet for every season, one TileMapLayer for the whole map.
const WHOLE: Array[String] = ["grid", "marks"]
const LINES_Z := 50
const SHADOW_Z := 60
const STAND_Z := 70
const BORDERS_Z := 85
const SHADOW_ALPHA := 0.18
const SHADOW_SHADER := "res://shell/mapview/shadow_cover.gdshader"
const FILL_BLOCK := 16  # cells a side of one block of the sliced fill
const FILL_PER_FRAME := 4000  # hexes of one step by count (a test, a tool); a frame's fill is a time (FILL_MS)
const FILL_MS := 5.0  # milliseconds a frame the view's own fill takes (when the view is not driven by a scene)
const CHUNK := Vector2i(128, 64)  # cells a side of one chunk of layers (a multiple of FILL_BLOCK)
const CHUNK_BIG := Vector2i(64, 32)  # the chunk of a map that is more than one CHUNK: a swap goes in smaller steps
const NO_TILE := Vector3i(-1, -1, -1)
const ORDER := &"order"

## Cell writes (set_cell and erase_cell) so far: a season swap must not move it.
var cell_writes := 0

var _tiles: TilesetBuilder = null
var _names: Dictionary[String, Vector3i] = {}
var _slots := 1
var _half := false
var _cols := 0
var _chunk := CHUNK
var _climate := PackedByteArray()
var _layer_names: Array[String] = []  # every layer, in stacking order
var _layer_at: Dictionary[String, int] = {}
var _specs: Array[Array] = []  # per layer: [z index, kind]
var _whole: Array[TileMapLayer] = []  # per layer: the layer of a WHOLE name, else null
var _chunks: Dictionary[Vector2i, Array] = {}  # chunk -> per layer: its TileMapLayer or null
var _parents: Array[Node] = []  # per layer: the node its layers go under
var _materials: Array[Material] = []  # per layer: shared by its chunks
var _hidden: Dictionary[String, bool] = {}
var _marks_set: TileSet = null  # the TileSet of the WHOLE layers when a season's TileSet has climate slots
var _lines: Node2D = null
var _line_chunks: Dictionary[Vector2i, EdgeLineLayer] = {}
var _borders: Node2D = null
var _border_chunks: Dictionary[Vector2i, EdgeLineLayer] = {}
var _missing: Dictionary[String, bool] = {}
var _fill_provider := Callable()
var _fill_order := PackedInt32Array()  # the view layer of each name a packed provider writes (empty: it gives a Dictionary)
var _fill_names := PackedStringArray()
var _fill_here: Array = []  # the layers of the chunk the block being filled is in
var _fill_cols := 0
var _fill_rows := 0
var _fill_blocks: Array[Vector2i] = []
var _fill_block := 0
var _fill_at := 0
var _fill_total := 0
var _fill_done := 0
var _swap_to: TileSet = null
var _swap_scale := Vector2.ONE
var _swap_chunks: Array[Vector2i] = []
var _swap_focus := Rect2i()
var _swap_at := 0
var _swap_layer := 0
var _swap_focus_left := 0


## Makes the layers for a tileset (TilesetBuilder). Call once, before any set_tile.
func setup(tiles: TilesetBuilder) -> void:
	_tiles = tiles
	_names = tiles.names
	_slots = tiles.slots
	_half = tiles.half
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
	if tiles.slots == TilesetBuilder.CLIMATES:
		_marks_set = TilesetBuilder.marks_set()
	var specs := LAYERS.duplicate()
	specs.merge(OVERLAYS)
	for layer_name: String in specs:
		var spec: Array = specs[layer_name]
		_layer_at[layer_name] = _layer_names.size()
		_layer_names.append(layer_name)
		_specs.append(spec)
		var blend: Material = null
		var parent: Node = self
		match str(spec[1]):
			"mul", "add":
				var one := CanvasItemMaterial.new()
				one.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL if str(spec[1]) == "mul" else CanvasItemMaterial.BLEND_MODE_ADD
				blend = one
			"shadow":
				blend = shadow_material
				parent = shadows
			"stand":
				parent = standing
		_materials.append(blend)
		_parents.append(parent)
		_whole.append(null)
	_lines = Node2D.new()
	_lines.name = "Lines"
	_lines.z_index = LINES_Z
	_borders = Node2D.new()
	_borders.name = "Borders"
	_borders.z_index = BORDERS_Z
	add_child(_lines)
	add_child(shadows)
	add_child(standing)
	add_child(_borders)
	for k: int in _layer_names.size():
		if WHOLE.has(_layer_names[k]):
			_whole[k] = _new_layer(k, Vector2i.ZERO)
	_chunk_array(Vector2i.ZERO)  # the first chunk's layers exist at once: layer(name) is always there


## The climate of every hex (MapData.climate: 0 snow, 1 frost, 2 mild; `cols` hexes a row). A cell takes the slot of
## its hex's climate when its tile is set, so set this before the cells (a cell already set keeps its slot).
func set_climates(cols: int, climate: PackedByteArray) -> void:
	_cols = cols
	_climate = climate


## Puts a tile on a cell of a layer; "" (or a name the tileset does not have) clears the cell. A cell that already
## shows the tile is not written again.
func set_tile(layer_name: String, cell: Vector2i, tile_name: String) -> void:
	var k := _layer_at[layer_name]
	var at := _names.get(tile_name, NO_TILE) as Vector3i if tile_name != "" else NO_TILE
	if at == NO_TILE or (_marks_set != null and _whole[k] != null and at.x != TilesetBuilder.marks_source()):
		if tile_name != "":
			_missing[tile_name] = true
		var there := _layer_of(k, cell, false)
		if there != null and there.get_cell_source_id(cell) != -1:
			there.erase_cell(cell)
			cell_writes += 1
		return
	var source := _source_of(at.x, cell, k)
	var layer := _layer_of(k, cell, true)
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


# ----- seasons ------------------------------------------------------------------------------------------------------


## Swaps the season at once: every layer gets the other TileSet. No cell is touched (the cells hold the same source ids
## and atlas places in every season). The view lets go of the previous builder: unless the caller holds it, its pictures
## are freed, so one season's pictures are in video memory. A big map is better swapped by begin_season_swap.
func set_season(tiles: TilesetBuilder) -> void:
	begin_season_swap(tiles)
	swap_step(INF)


## Starts a season swap that goes on in swap_step: the new TileSet goes to the layers a chunk at a time, the chunks that
## hold a hex of `focus` (a Rect2i of hexes, the part on the screen; empty for none) first, then the nearest. Cells
## written meanwhile land on the new TileSet at once; a chunk that has not been reached shows the old pictures.
func begin_season_swap(tiles: TilesetBuilder, focus: Rect2i = Rect2i()) -> void:
	_tiles = tiles
	_names = tiles.names
	_slots = tiles.slots
	_half = tiles.half
	_swap_to = tiles.tile_set
	_swap_scale = Vector2(2.0, 2.0) if _half else Vector2.ONE
	_swap_focus = focus
	_swap_chunks.clear()
	_swap_chunks.assign(_chunks.keys())
	var middle := Vector2(focus.get_center()) if focus.has_area() else Vector2.ZERO
	var rank := func(chunk: Vector2i) -> float:
		var inside := focus.has_area() and focus.intersects(_chunk_rect(chunk))
		return Vector2(_chunk_rect(chunk).get_center()).distance_to(middle) - (1.0e9 if inside else 0.0)
	_swap_chunks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return float(rank.call(a)) < float(rank.call(b)))
	_swap_at = 0
	_swap_layer = 0
	_swap_focus_left = 0
	for chunk: Vector2i in _swap_chunks:
		if focus.has_area() and focus.intersects(_chunk_rect(chunk)):
			_swap_focus_left += 1
	for k: int in _layer_names.size():
		if _whole[k] != null and _marks_set == null:  # (a single TileSet, the trial's: the grid goes with the rest)
			_whole[k].tile_set = _swap_to
			_whole[k].scale = _swap_scale
			_whole[k].update_internals()


## Does up to `budget_ms` of the swap (a layer of a chunk is never split, so a step can pass its budget by one);
## true while more is to do. season_swapped is emitted when the last layer has it.
func swap_step(budget_ms: float) -> bool:
	if _swap_to == null:
		return false
	var until := Time.get_ticks_usec() + int(minf(budget_ms, 1.0e9) * 1000.0)
	while _swap_at < _swap_chunks.size():
		var chunk := _swap_chunks[_swap_at]
		var layers: Array = _chunks[chunk] if _chunks.has(chunk) else []
		while _swap_layer < layers.size():
			var layer := layers[_swap_layer] as TileMapLayer
			_swap_layer += 1
			if layer != null and (layer.tile_set != _swap_to or layer.scale != _swap_scale):
				layer.tile_set = _swap_to
				layer.scale = _swap_scale
				layer.update_internals()  # the rebuild happens here, inside the slice, not at the end of the frame
				if Time.get_ticks_usec() >= until:
					return _finish_swap_step()
		if _swap_focus.has_area() and _swap_focus.intersects(_chunk_rect(chunk)):
			_swap_focus_left -= 1
		_swap_at += 1
		_swap_layer = 0
		if Time.get_ticks_usec() >= until:
			break
	return _finish_swap_step()


func _finish_swap_step() -> bool:
	if _swap_at >= _swap_chunks.size():
		_swap_to = null
		season_swapped.emit()
		return false
	return true


func is_swapping() -> bool:
	return _swap_to != null


## Whether the chunks of the swap's focus all have the new TileSet (true when there was no focus).
func swap_focus_done() -> bool:
	return _swap_to == null or _swap_focus_left <= 0


func season() -> String:
	return "" if _tiles == null else _tiles.season


# ----- layers and chunks --------------------------------------------------------------------------------------------


## The source id for a tile in a cell: the season's slot of the hex's climate (the marks have the slot 0 only).
func _source_of(source_in_index: int, cell: Vector2i, layer: int) -> int:
	if _slots == 1:
		return source_in_index
	if _whole[layer] != null:
		return _slots * source_in_index
	return _slots * source_in_index + _climate_at(cell)


func _climate_at(cell: Vector2i) -> int:
	if cell.x >= 0 and cell.x < _cols:
		var i := cell.y * _cols + cell.x
		if i >= 0 and i < _climate.size():
			return _climate[i]
	return 0


func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / float(_chunk.x)), floori(float(cell.y) / float(_chunk.y)))


## The cells of a chunk.
func _chunk_rect(chunk: Vector2i) -> Rect2i:
	return Rect2i(chunk * _chunk, _chunk)


## The per-layer array of a chunk (null where a layer has no cell there yet), made when asked.
func _chunk_array(chunk: Vector2i) -> Array:
	if _chunks.has(chunk):
		return _chunks[chunk]
	var arr: Array = []
	arr.resize(_layer_names.size())
	_chunks[chunk] = arr
	if chunk == Vector2i.ZERO:
		for k: int in _layer_names.size():
			if _whole[k] == null:
				arr[k] = _new_layer(k, chunk)
	return arr


## The layer `k` that holds `cell`; null when it has none and `make` is false.
func _layer_of(k: int, cell: Vector2i, make: bool) -> TileMapLayer:
	if _whole[k] != null:
		return _whole[k]
	var chunk := chunk_of(cell)
	if not make and not _chunks.has(chunk):
		return null
	var arr := _chunk_array(chunk)
	var layer := arr[k] as TileMapLayer
	if layer == null and make:
		layer = _new_layer(k, chunk)
		arr[k] = layer
	return layer


## A TileMapLayer for a layer of the table in a chunk, in the place its stacking order gives it under its parent (equal
## depths are drawn in tree order, so the layers keep the order of the table, and a layer's chunks follow each other).
func _new_layer(k: int, chunk: Vector2i) -> TileMapLayer:
	var layer := TileMapLayer.new()
	var layer_name := _layer_names[k]
	var spec := _specs[k]
	layer.name = layer_name.to_pascal_case() if chunk == Vector2i.ZERO else "%s_%d_%d" % [layer_name.to_pascal_case(), chunk.x, chunk.y]
	var uses_marks := _marks_set != null and WHOLE.has(layer_name)
	layer.tile_set = _marks_set if uses_marks else _tiles.tile_set
	layer.scale = Vector2(2.0, 2.0) if (_half and not uses_marks) else Vector2.ONE
	layer.z_index = int(spec[0])
	layer.material = _materials[k]
	layer.y_sort_enabled = str(spec[1]) == "stand"
	layer.visible = not _hidden.get(layer_name, false)
	var key := k * 1000000 + chunk.y * 1000 + chunk.x
	layer.set_meta(ORDER, key)
	var parent := _parents[k]
	parent.add_child(layer)
	# Binary search for the first child that comes after the key (the children with an order come first).
	var low := 0
	var high := parent.get_child_count() - 1  # (the new layer is the last)
	while low < high:
		var middle := int((low + high) / 2.0)
		var other := parent.get_child(middle)
		if other.has_meta(ORDER) and int(other.get_meta(ORDER)) <= key:
			low = middle + 1
		else:
			high = middle
	parent.move_child(layer, low)
	return layer


## Empties every layer and the lines.
func clear() -> void:
	for k: int in _layer_names.size():
		if _whole[k] != null:
			_whole[k].clear()
	for chunk: Vector2i in _chunks.keys():
		var arr: Array = _chunks[chunk]
		for k: int in arr.size():
			var layer := arr[k] as TileMapLayer
			if layer == null:
				continue
			if chunk == Vector2i.ZERO:
				layer.clear()
			else:
				layer.queue_free()
		if chunk != Vector2i.ZERO:
			_chunks.erase(chunk)
	_clear_edge_chunks(_lines, _line_chunks)
	_clear_edge_chunks(_borders, _border_chunks)


# ----- the sliced fill ----------------------------------------------------------------------------------------------


## Starts the sliced fill of a map of cols x rows hexes. `provider` gives the tiles of a hex: either
## `provider.call(hex)` -> {layer: tile name}, or, when `order` (the layer names of a packed list, MapCells.LAYERS) is
## given, `provider.call(hex, names)` that writes the names into `names` (a PackedStringArray in that order; "" for no
## tile), which builds no dictionary a hex. The view is cleared first. Blocks of FILL_BLOCK x FILL_BLOCK hexes go
## nearest `near` first; fill_finished is emitted at the end. Driven by the view's own _process (FILL_MS a frame), by
## fill_for (a time a call, what the map scene does) or by fill_step (a count of hexes, tests).
func begin_fill(cols: int, rows: int, provider: Callable, near: Vector2i, order: Array[String] = []) -> void:
	clear()
	_chunk = CHUNK if cols <= CHUNK.x and rows <= CHUNK.y else CHUNK_BIG  # (a map of one chunk keeps one layer a name)
	_fill_provider = provider
	_fill_order = PackedInt32Array()
	for layer_name: String in order:
		_fill_order.append(_layer_at[layer_name])
	_fill_names = PackedStringArray()
	_fill_names.resize(order.size())
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
	_fill_here = []
	set_process(true)


func is_filling() -> bool:
	return _fill_block < _fill_blocks.size()


## 0 to 1.
func fill_progress() -> float:
	return 1.0 if _fill_total == 0 else float(_fill_done) / float(_fill_total)


## Fills for up to `budget_ms` (a few hexes at a time, so it stops soon after the time is up); true while more is to do.
func fill_for(budget_ms: float) -> bool:
	var until := Time.get_ticks_usec() + int(budget_ms * 1000.0)
	while is_filling() and Time.get_ticks_usec() < until:
		fill_step(24)
	return is_filling()


## Fills up to `budget` hexes; true while more is to do.
func fill_step(budget: int) -> bool:
	var left := budget
	while left > 0 and _fill_block < _fill_blocks.size():
		var block := _fill_blocks[_fill_block]
		if _fill_at == 0:
			_fill_here = _chunk_array(chunk_of(block * FILL_BLOCK))
		var column := block.x * FILL_BLOCK + _fill_at % FILL_BLOCK
		@warning_ignore("integer_division")
		var row := block.y * FILL_BLOCK + _fill_at / FILL_BLOCK  # a row inside the block: whole numbers are meant
		_fill_at += 1
		var block_done := _fill_at >= FILL_BLOCK * FILL_BLOCK
		if column < _fill_cols and row < _fill_rows:
			left -= 1
			_fill_done += 1
			_fill_hex(Vector2i(column, row))
		if block_done:
			_fill_at = 0
			_fill_block += 1
			_flush(_fill_here)
	if _fill_block >= _fill_blocks.size():
		set_process(false)
		_flush(_fill_here)
		fill_finished.emit()
		return false
	return true


func _fill_hex(hex: Vector2i) -> void:
	if _fill_order.is_empty():
		var names: Dictionary = _fill_provider.call(hex)
		for layer_name: String in names:
			var tile_name := str(names[layer_name])
			if tile_name != "":
				set_tile(layer_name, hex, tile_name)
		return
	_fill_provider.call(hex, _fill_names)
	var climate := _climate_at(hex)
	for n: int in _fill_order.size():
		var tile_name := _fill_names[n]
		if tile_name == "":
			continue
		var at := _names.get(tile_name, NO_TILE) as Vector3i
		var k := _fill_order[n]
		if at == NO_TILE or (_marks_set != null and _whole[k] != null and at.x != TilesetBuilder.marks_source()):
			_missing[tile_name] = true
			continue
		var layer := _whole[k]
		if layer == null:
			layer = _fill_here[k] as TileMapLayer
			if layer == null:
				layer = _new_layer(k, chunk_of(hex))
				_fill_here[k] = layer
		var source := at.x if _slots == 1 else _slots * at.x + (0 if _whole[k] != null else climate)
		layer.set_cell(hex, source, Vector2i(at.y, at.z))
		cell_writes += 1


## Builds what the cells just written need (the engine would do it at the end of the frame), so the time is taken
## inside the slice it belongs to.
func _flush(layers: Array) -> void:
	for layer: Variant in layers:
		if layer != null:
			(layer as TileMapLayer).update_internals()
	for k: int in _whole.size():
		if _whole[k] != null:
			_whole[k].update_internals()


func _process(_delta: float) -> void:
	fill_for(FILL_MS)


# ----- lines --------------------------------------------------------------------------------------------------------


## Rivers, streams and roads of one chunk (EdgeLines.for_chunk): one mesh node for the chunk, replaced when the
## chunk's lines change; no lines frees it.
func set_chunk_lines(chunk: Vector2i, lines: Array[Dictionary]) -> void:
	_set_chunk_edge_layer(_lines, _line_chunks, "Lines", chunk, lines)


## The chunks that have a line node.
func line_chunks() -> Array[Vector2i]:
	return _edge_chunk_keys(_line_chunks)


## All the lines of the map at once (the trial's way): cut at the chunk borders, one node a chunk.
func set_lines(lines: Array[Dictionary]) -> void:
	_clear_edge_chunks(_lines, _line_chunks)
	var cut := EdgeLines.cut(lines)
	for chunk: Vector2i in cut:
		var list: Array[Dictionary] = []
		list.assign(cut[chunk])
		set_chunk_lines(chunk, list)


# ----- borders ------------------------------------------------------------------------------------------------------


## Country borders and inner tinted bands of one chunk (BorderLines.for_chunk): one mesh node for the chunk,
## replaced when the chunk's borders change; [] frees it.
func set_chunk_borders(chunk: Vector2i, lines: Array[Dictionary]) -> void:
	_set_chunk_edge_layer(_borders, _border_chunks, "Borders", chunk, lines)


## The chunks that have a border node.
func border_chunks() -> Array[Vector2i]:
	return _edge_chunk_keys(_border_chunks)


## Builds every border chunk of `map` from `owner` and `palette`.
func set_borders(map: MapData, owner: PackedByteArray, palette: PackedColorArray) -> void:
	_clear_edge_chunks(_borders, _border_chunks)
	if map == null:
		return
	var chunks_x := ceili(float(map.cols) / float(EdgeLines.CHUNK))
	var chunks_y := ceili(float(map.rows) / float(EdgeLines.CHUNK))
	for cy: int in chunks_y:
		for cx: int in chunks_x:
			var chunk := Vector2i(cx, cy)
			set_chunk_borders(chunk, BorderLines.for_chunk(map, owner, chunk, palette))


## Rebuilds only the border chunks touched by ownership changes on `hexes`.
func rebuild_borders(map: MapData, owner: PackedByteArray, palette: PackedColorArray, hexes: Array[Vector2i]) -> void:
	if map == null:
		return
	for chunk: Vector2i in BorderLines.chunks_touched(map, hexes):
		set_chunk_borders(chunk, BorderLines.for_chunk(map, owner, chunk, palette))


## Shows or hides the Borders node without rebuilding its chunk meshes.
func set_borders_visible(value: bool) -> void:
	if _borders != null:
		_borders.visible = value


func _set_chunk_edge_layer(parent: Node2D, store: Dictionary[Vector2i, EdgeLineLayer], prefix: String,
		chunk: Vector2i, lines: Array[Dictionary]) -> void:
	if store.has(chunk):
		var old := store[chunk]
		if parent != null and old.get_parent() == parent:
			parent.remove_child(old)
		old.queue_free()
		store.erase(chunk)
	if lines.is_empty():
		return
	var node := EdgeLineLayer.new()
	node.name = "%s_%d_%d" % [prefix, chunk.x, chunk.y]
	parent.add_child(node)
	node.set_lines(lines)
	store[chunk] = node


func _clear_edge_chunks(parent: Node2D, store: Dictionary[Vector2i, EdgeLineLayer]) -> void:
	for chunk: Vector2i in store:
		var old := store[chunk]
		if parent != null and old.get_parent() == parent:
			parent.remove_child(old)
		old.queue_free()
	store.clear()


func _edge_chunk_keys(store: Dictionary[Vector2i, EdgeLineLayer]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(store.keys())
	return out


# ----- asking -------------------------------------------------------------------------------------------------------


func set_layer_visible(layer_name: String, value: bool) -> void:
	_hidden[layer_name] = not value
	for layer: TileMapLayer in layers_of(layer_name):
		layer.visible = value


## The layer of a name: the first chunk's (all of it for the grid, the marks and any map of one chunk).
func layer(layer_name: String) -> TileMapLayer:
	var k := _layer_at[layer_name]
	if _whole[k] != null:
		return _whole[k]
	return _chunks[Vector2i.ZERO][k] as TileMapLayer


## Every TileMapLayer of a name, one a chunk that has a cell of it.
func layers_of(layer_name: String) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	var k := _layer_at[layer_name]
	if _whole[k] != null:
		out.append(_whole[k])
		return out
	for chunk: Vector2i in _chunks:
		var one := (_chunks[chunk] as Array)[k] as TileMapLayer
		if one != null:
			out.append(one)
	return out


## The hex under a point of the map (the view's own coordinates).
func hex_at(map_px: Vector2) -> Vector2i:
	var ground := layer("ground")
	return ground.local_to_map(map_px / ground.scale)


func centre_of(hex: Vector2i) -> Vector2:
	var ground := layer("ground")
	return ground.map_to_local(hex) * ground.scale


func is_half() -> bool:
	return _half


## The tile names that were asked for and are not in the tileset (a bake that is behind the rules).
func missing_names() -> Array[String]:
	var out: Array[String] = []
	out.assign(_missing.keys())
	out.sort()
	return out


func cell_count() -> int:
	var total := 0
	for layer_name: String in _layer_names:
		for one: TileMapLayer in layers_of(layer_name):
			total += one.get_used_cells().size()
	return total
