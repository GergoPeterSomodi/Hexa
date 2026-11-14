## The map view on the real Europe: the tile layers' cells, the zoom levels that switch the far maps, and the views.
## A TileMapLayer's own mapping is checked against the geometry the view uses.
extends GutTest

const MapViewScene := preload("res://shell/map/map_view.tscn")

var _atlas: AtlasIndex
var _map: MapData
var _view: MapView


func before_all() -> void:
	_atlas = AtlasIndex.load_index()
	_map = MapBuilder.build_europe(EuropeData.load_europe())


func before_each() -> void:
	_view = MapViewScene.instantiate() as MapView
	add_child_autofree(_view)
	_view.setup(_map, _atlas)


func test_tile_layer_mapping_matches_the_geometry() -> void:
	# A real TileMapLayer with the view's TileSet: its own cell centres, mapped by the view's scale and offset,
	# must land on MapGeometry.centre.
	var layer := TileMapLayer.new()
	layer.tile_set = MapTileSet.build(_atlas)
	add_child_autofree(layer)
	layer.scale = MapGeometry.tile_layer_scale()
	layer.position = MapGeometry.tile_layer_offset()
	for pos: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(7, 4), Vector2i(150, 99), Vector2i(202, 149)]:
		var local := layer.map_to_local(pos)
		var on_screen := layer.position + Vector2(local.x * layer.scale.x, local.y)
		assert_true(on_screen.distance_to(MapGeometry.centre(pos)) <= 0.05,
				"TileMapLayer centre of %s: %s vs %s" % [pos, on_screen, MapGeometry.centre(pos)])


func test_layers_have_the_planned_cells() -> void:
	var counts := _view.layer_cells()
	assert_eq(counts[TilePlan.GROUND], 14411 + 15956 + 83, "ground: every hex (land, ocean, lake)")
	assert_eq(counts[TilePlan.COAST], _coast_cells(), "coast cells")
	assert_gt(counts[TilePlan.TOWN], 0, "towns and castles from the provinces")
	assert_gt(counts[TilePlan.ROAD], 0, "roads from the builder")
	assert_eq(_view.plan.missing, 0, "every planned key exists in the atlas")


func test_far_zoom_shows_the_far_maps_and_tile_zoom_shows_tiles() -> void:
	_view.frame(MapGeometry.map_size(_map.cols, _map.rows) * 0.5, MapView.ZOOM_MIN)
	assert_true(_view.is_far(), "far at the minimum zoom")
	# The tiles stay visible under the opaque far maps (hiding them cost a 25 to 56 ms frame at each zoom band).
	assert_true(_shown("Tiles"), "tiles kept under the far maps")
	assert_true(_shown("FarTerrain"), "far terrain shown far")
	_view.frame(MapGeometry.centre(Vector2i(100, 75)), MapView.TILE_ZOOM + 0.01)
	assert_false(_view.is_far(), "tiles from the first tile zoom")
	assert_true(_shown("Tiles"), "tiles shown")
	assert_false(_shown("FarTerrain"), "far terrain hidden at tile zoom")


func test_views_switch_the_far_and_the_overlay() -> void:
	_view.frame(MapGeometry.map_size(_map.cols, _map.rows) * 0.5, MapView.ZOOM_MIN)
	_view.set_view(MapView.VIEW_COUNTRIES)
	assert_true(_shown("FarCountries"), "countries far map")
	assert_false(_shown("FarTerrain"), "no terrain far map in countries view")
	_view.frame(MapGeometry.centre(Vector2i(100, 75)), 0.4)
	assert_true(_shown("CountriesOverlay"), "overlay at tile zoom in countries view")
	assert_true((_view.get_node("Tiles/deco") as CanvasItem).visible, "decorations in countries view")
	_view.set_view(MapView.VIEW_TERRAIN)
	assert_false(_shown("CountriesOverlay"), "no overlay in terrain view")
	assert_false((_view.get_node("Tiles/deco") as CanvasItem).visible, "no decorations in terrain view")


func test_zoom_is_clamped_to_the_python_range() -> void:
	_view.frame(Vector2.ZERO, 5.0)
	assert_almost_eq(_view.zoom(), MapView.ZOOM_MAX, 0.0001, "clamped to the closest zoom")
	_view.frame(Vector2.ZERO, 0.0001)
	assert_almost_eq(_view.zoom(), MapView.ZOOM_MIN, 0.0001, "clamped to the far zoom")


func test_hex_under_the_screen_centre_is_on_the_map() -> void:
	_view.frame(MapGeometry.centre(Vector2i(50, 60)), 0.4)
	var screen_centre := _view.get_viewport().get_visible_rect().size * 0.5
	assert_eq(_view.hex_at_screen(screen_centre), Vector2i(50, 60), "the hex under the camera centre")


func _shown(node_name: String) -> bool:
	var item := _view.get_node(node_name) as CanvasItem
	return item.visible


## Coastal land hexes that have a coast cell: not a river mouth (its piece holds the coast), not a harbour town.
func _coast_cells() -> int:
	var count := 0
	for pos: Vector2i in _map.land_hexes():
		if TilePlan.sea_mask(_map, pos) == 0:
			continue
		if _view.plan.key_at(TilePlan.RIVER, pos).begins_with("mouth/"):
			continue
		if _view.plan.key_at(TilePlan.TOWN, pos).begins_with("harbour/"):
			continue
		count += 1
	return count
