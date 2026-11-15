## Checks, on the real renderer, the Godot behaviour the map standard relies on (docs/architecture/godot-architecture.md
## section 11): tall tiles on SEVERAL TileMapLayers inside one y-sorted group are drawn in order of their depth
## (the cell's y plus the tile's y_sort_origin), whatever the order of the layers in the tree.
## Windowed (nothing is drawn headless):  godot --path godot -s res://tools/mapview/probe_ysort.gd
## Prints one line per case and exits 0 when all pass, 1 otherwise.
extends SceneTree

const CELL := Vector2i(104, 102)
const TALL := Vector2i(104, 204)  # a tile twice the cell's height, standing on the cell's lower edge
const RED := Color(1, 0, 0)
const GREEN := Color(0, 1, 0)
const BLUE := Color(0, 0, 1)

var _layers: Array[TileMapLayer] = []
var _frames := 0


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	RenderingServer.set_default_clear_color(Color.BLACK)
	# One atlas: columns red, green, blue; row 0 sorts at the cell's middle, row 1 sorts 30 px lower (in front),
	# row 2 sorts 30 px higher (behind).
	var image := Image.create(TALL.x * 3, TALL.y * 3, false, Image.FORMAT_RGBA8)
	var colours: Array[Color] = [RED, GREEN, BLUE]
	for column: int in 3:
		for row: int in 3:
			image.fill_rect(Rect2i(column * TALL.x + 20, row * TALL.y, TALL.x - 40, TALL.y), colours[column])
	var tiles := TileSet.new()
	tiles.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	tiles.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tiles.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tiles.tile_size = CELL
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = TALL
	tiles.add_source(atlas, 0)
	for column: int in 3:
		for row: int in 3:
			atlas.create_tile(Vector2i(column, row))
			var data := atlas.get_tile_data(Vector2i(column, row), 0)
			data.texture_origin = Vector2i(0, 51)  # the picture's foot on the cell's lower corner
			data.y_sort_origin = [0, 30, -30][row]
	var group := Node2D.new()
	group.y_sort_enabled = true
	root.add_child(group)
	for n: int in 3:
		var layer := TileMapLayer.new()
		layer.tile_set = tiles
		layer.y_sort_enabled = true
		group.add_child(layer)
		_layers.append(layer)
	# Case A: red (first layer) one row LOWER than green (second layer): red is in front although its layer is first.
	_layers[0].set_cell(Vector2i(1, 3), 0, Vector2i(0, 0))
	_layers[1].set_cell(Vector2i(1, 2), 0, Vector2i(1, 0))
	# Case B: the other way round: green (second layer) lower than blue (third layer).
	_layers[1].set_cell(Vector2i(4, 3), 0, Vector2i(1, 0))
	_layers[2].set_cell(Vector2i(4, 2), 0, Vector2i(2, 0))
	# Case C: three tiles on ONE cell: red sorts in front (+30), blue behind (-30), green in the middle.
	_layers[0].set_cell(Vector2i(7, 3), 0, Vector2i(0, 1))
	_layers[1].set_cell(Vector2i(7, 3), 0, Vector2i(1, 0))
	_layers[2].set_cell(Vector2i(7, 3), 0, Vector2i(2, 2))
	# Case D: a tile's own sort point beats the row: blue on the upper row sorts +30... but the row below is 76.5 px
	# lower, so red there still wins (rows never swap while sort points stay within half a row).
	_layers[2].set_cell(Vector2i(9, 2), 0, Vector2i(2, 1))
	_layers[0].set_cell(Vector2i(9, 3), 0, Vector2i(0, 2))


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 6:
		return false
	var image := root.get_texture().get_image()
	var layer := _layers[0]
	var failed := 0
	# Where two tiles overlap: a little above the foot of the upper tile (inside the lower tile's tall picture too).
	failed += _check(image, "A  lower row in front, its layer first in the tree", _overlap(layer, Vector2i(1, 2), Vector2i(1, 3)), RED)
	failed += _check(image, "B  lower row in front, its layer second", _overlap(layer, Vector2i(4, 2), Vector2i(4, 3)), GREEN)
	failed += _check(image, "C  one cell, three layers: the tile with the lowest sort point in front",
		layer.map_to_local(Vector2i(7, 3)), RED)
	failed += _check(image, "D  the row still wins over a tile's own sort point", _overlap(layer, Vector2i(9, 2), Vector2i(9, 3)), RED)
	print("probe_ysort: %s" % ("ALL PASS" if failed == 0 else "%d FAILED" % failed))
	quit(0 if failed == 0 else 1)
	return true


func _overlap(layer: TileMapLayer, upper: Vector2i, lower: Vector2i) -> Vector2:
	var a := layer.map_to_local(upper)
	var b := layer.map_to_local(lower)
	return Vector2((a.x + b.x) / 2.0, a.y)  # inside both pictures: the columns overlap by half a cell


func _check(image: Image, what: String, at: Vector2, want: Color) -> int:
	var got := image.get_pixel(int(at.x), int(at.y))
	var ok := got.is_equal_approx(want)
	print("probe_ysort: %s  %s  (pixel %s is %s)" % ["PASS" if ok else "FAIL", what, at, got])
	return 0 if ok else 1
