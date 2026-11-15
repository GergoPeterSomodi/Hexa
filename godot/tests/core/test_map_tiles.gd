## The tile-naming rules of the map view (core/views/map_tiles.gd).
extends GutTest


func test_ground_bands_follow_the_height() -> void:
	var hex := Vector2i(3, 4)
	assert_true(MapTiles.ground("farmland", 50.0, hex).begins_with("ground/farmland/0/"))
	assert_true(MapTiles.ground("grassland", 900.0, hex).begins_with("ground/grassland/3/"))
	assert_true(MapTiles.ground("grassland", 2000.0, hex).begins_with("ground/grassland/4/"))
	assert_true(MapTiles.ground("woods", 2000.0, hex).begins_with("ground/woods/3/"), "a wood is never half stone")
	assert_true(MapTiles.ground("rock", 2000.0, hex).begins_with("ground/rock/0/"))
	assert_eq(MapTiles.ground("", 0.0, hex), "")
	assert_eq(MapTiles.ground("woods", 300.0, hex), MapTiles.ground("woods", 300.0, hex), "the same hex, the same variant")


func test_sea_beside_land_is_shelf() -> void:
	assert_true(MapTiles.sea("deep", true, Vector2i(1, 1)).begins_with("sea/shelf/"))
	assert_true(MapTiles.sea("deep", false, Vector2i(1, 1)).begins_with("sea/deep/"))
	assert_true(MapTiles.sea("", false, Vector2i(1, 1)).begins_with("sea/shelf/"))


func test_coast_mask_and_name() -> void:
	var sea: Array[bool] = [false, false, false, false, true, true]
	var mask := MapTiles.coast_mask(sea)
	assert_eq(mask, 48)
	assert_eq(MapTiles.coast(0, Vector2i(2, 2), 1, false, false), "")
	assert_eq(MapTiles.coast(mask, Vector2i(4, 3), 1, false, false), "coast/beach/48/4")
	assert_eq(MapTiles.coast(mask, Vector2i(4, 3), 4, false, false), "coast/cliff/48/4")
	assert_eq(MapTiles.coast(mask, Vector2i(4, 3), 4, true, true), "coast/beach/48/4/bay", "a port: low shore, carved bay")
	assert_eq(MapTiles.coast(1, Vector2i(4, 3), 1, true, true), "coast/beach/1/4", "no bay unless the sea lies south")
	assert_eq(MapTiles.sea_side(mask), "S")
	assert_eq(MapTiles.sea_side(1), "E")
	assert_eq(MapTiles.sea_side(8), "W")
	assert_eq(MapTiles.sea_side(0), "")


func test_slope_tone_lit_shaded_and_flat() -> void:
	var flat := PackedFloat32Array([500.0, 500.0, 500.0, 500.0, 500.0, 500.0])
	assert_eq(MapTiles.slope_tone(500.0, flat), Vector2i(0, 0), "flat ground has no tone")
	# Ground that rises to the south-east faces the light from the upper left.
	var rises_se := PackedFloat32Array([1400.0, 500.0, 0.0, 0.0, 500.0, 1400.0])
	var lit := MapTiles.slope_tone(700.0, rises_se)
	assert_gt(lit.y, 0, "lit")
	assert_eq(lit.x, 0)
	var rises_nw := PackedFloat32Array([0.0, 500.0, 1400.0, 1400.0, 500.0, 0.0])
	var shaded := MapTiles.slope_tone(700.0, rises_nw)
	assert_gt(shaded.x, 0, "shaded")
	assert_eq(shaded.y, 0)
	assert_lte(shaded.x, MapTiles.SHADE_LEVELS)


func test_relief_forms() -> void:
	var hex := Vector2i(5, 5)
	assert_eq(MapTiles.relief(1, false, false, false, hex), "")
	assert_true(MapTiles.relief(6, true, false, false, hex).begins_with("relief/ridge_snow/full/"))
	assert_true(MapTiles.relief(5, true, true, false, hex).begins_with("relief/ridge_rock/back/"))
	assert_true(MapTiles.relief(5, true, false, true, hex).begins_with("relief/ridge_rock/pass/"))
	assert_eq(MapTiles.relief(4, false, true, false, hex), "", "a built hex loses its hills")


func test_trees_make_way() -> void:
	var hex := Vector2i(5, 5)
	assert_true(MapTiles.trees(0, "woods", 300.0, "woods", false, false, false, false, hex).begins_with("trees/broad/full/0/"))
	assert_true(MapTiles.trees(2, "woods", 900.0, "woods", true, false, false, false, hex).begins_with("trees/mixed/bank/2/"))
	assert_true(MapTiles.trees(2, "woods", 1500.0, "woods", false, true, false, false, hex).begins_with("trees/conifer/road/2/"))
	assert_true(MapTiles.trees(2, "woods", 300.0, "", false, false, false, false, hex).begins_with("trees/broad/bank/2/"), "the shore")
	assert_true(MapTiles.trees(1, "woods", 300.0, "woods", false, false, true, false, hex).begins_with("trees/broad/outer/1/"))
	assert_eq(MapTiles.trees(1, "woods", 300.0, "woods", true, false, true, false, hex), "")
	assert_true(MapTiles.trees(1, "woods", 300.0, "woods", false, false, false, true, hex).begins_with("trees/broad/thin/1/"))
	assert_true(MapTiles.trees(3, "grassland", 300.0, "woods", false, false, false, false, hex).begins_with("trees/broad/fringe/3/"))
	assert_eq(MapTiles.trees(3, "grassland", 300.0, "woods", false, true, false, false, hex), "")
	assert_eq(MapTiles.trees(3, "woods", 2500.0, "woods", false, false, false, false, hex), "", "above the tree line")


func test_piece_name() -> void:
	assert_eq(MapTiles.piece("wheat", 2, 1, true, "-", "back"), "piece/wheat/2/1/1/-/back")
	assert_eq(MapTiles.piece("mines", 1, 0, false, "", "ground"), "piece/mines/1/0/0/-/ground")
