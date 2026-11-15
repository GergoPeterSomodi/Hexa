## Pins the map's tile grid to the rules' hex grid (docs/architecture/godot-architecture.md section 3.1): a TileSet
## with hexagon tiles, stacked layout and a horizontal offset axis puts cell (column, row) where core's odd-r grid
## puts hex (column, row), finds the same hex under a point, and has the same six neighbours.
extends GutTest

const CELL := Vector2i(104, 102)

var _layer: TileMapLayer = null
var _grid: HexGrid = null


func before_all() -> void:
	var tiles := TileSet.new()
	tiles.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	tiles.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tiles.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tiles.tile_size = CELL
	_layer = TileMapLayer.new()
	_layer.tile_set = tiles
	add_child(_layer)
	# The rules' grid with a hex 104 units wide: its rows are 90.07 units apart, the tile grid's 76.5 px (the tilt).
	_grid = HexGrid.new(float(CELL.x), 1.0, 0.0, 0.0, 0.0)


func after_all() -> void:
	_layer.free()


func _to_grid(px: Vector2) -> Vector2:
	return Vector2(px.x, px.y * _grid.hex_h_km / MapTiles.ROW)


func test_cell_centres_are_the_odd_r_centres() -> void:
	var worst := 0.0
	for row: int in range(-6, 60):
		for column: int in range(-6, 60):
			var hex := Vector2i(column, row)
			var godot := _layer.map_to_local(hex)
			worst = maxf(worst, godot.distance_to(MapTiles.cell_centre(hex)))
			worst = maxf(worst, _to_grid(godot).distance_to(_grid.centre_km(hex)))
	assert_lt(worst, 0.001, "TileMapLayer.map_to_local, MapTiles.cell_centre and HexGrid.centre_km agree")


func test_odd_rows_are_shifted_right() -> void:
	assert_almost_eq(_layer.map_to_local(Vector2i(0, 1)).x - _layer.map_to_local(Vector2i(0, 0)).x, 52.0, 0.001)
	assert_almost_eq(_layer.map_to_local(Vector2i(0, 2)).x, _layer.map_to_local(Vector2i(0, 0)).x, 0.001)


func test_the_hex_under_a_point_is_the_same() -> void:
	var rng := Rng.new()
	rng.seed_with(1480)
	var differ := 0
	for n: int in 20000:
		var px := Vector2(rng.randf() * 5000.0 - 400.0, rng.randf() * 4000.0 - 400.0)
		if _layer.local_to_map(px) != _grid.hex_of_km(_to_grid(px)):
			differ += 1
	assert_eq(differ, 0, "local_to_map and HexGrid.hex_of_km name the same hex for 20000 points")


func test_neighbours_are_the_same_six() -> void:
	for hex: Vector2i in [Vector2i(4, 4), Vector2i(4, 5), Vector2i(0, 0), Vector2i(-3, -3), Vector2i(-3, -2)]:
		var godot := _layer.get_surrounding_cells(hex)
		var ours := _grid.neighbours(hex)
		assert_eq(godot.size(), 6)
		for n: Vector2i in ours:
			assert_true(godot.has(n), "%s is a neighbour of %s for Godot too" % [n, hex])


func test_lattice_variant_repeats_every_three_cells_and_two_rows() -> void:
	for hex: Vector2i in [Vector2i(0, 0), Vector2i(5, 7), Vector2i(-4, 3)]:
		assert_eq(MapTiles.lattice_variant(hex), MapTiles.lattice_variant(hex + Vector2i(3, 0)))
		assert_eq(MapTiles.lattice_variant(hex), MapTiles.lattice_variant(hex + Vector2i(0, 2)))
		assert_between(MapTiles.lattice_variant(hex), 0, 5)
