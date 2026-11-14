## The baked atlas index (godot/assets/baked/index.json): the counts, the cells and the families the map view relies on.
extends GutTest

var _atlas: AtlasIndex


func before_all() -> void:
	_atlas = AtlasIndex.load_index()


func test_index_loads_the_bake() -> void:
	assert_eq(_atlas.sprite_count(), 1859, "sprites")
	assert_eq(_atlas.page_names.size(), 12, "atlas pages")
	assert_eq(_atlas.tile_size, Vector2i(104, 120), "grid tile")
	assert_eq(_atlas.cell_size, Vector2i(110, 126), "atlas cell (sprite plus 2 px border)")
	assert_eq(_atlas.extrude, 2, "extrude")


func test_every_sprite_sits_on_a_cell_inside_its_page() -> void:
	var seen: Dictionary = {}
	for key: String in _atlas.keys():
		var page := _atlas.page_of(key)
		var cell := _atlas.cell_of(key)
		assert_true(page >= 0 and page < _atlas.page_names.size(), "page of %s" % [key])
		var size := _atlas.page_sizes[page]
		assert_true((cell.x + 1) * _atlas.cell_size.x <= size.x, "cell x of %s inside the page" % [key])
		assert_true((cell.y + 1) * _atlas.cell_size.y <= size.y, "cell y of %s inside the page" % [key])
		var slot := "%d:%d:%d" % [page, cell.x, cell.y]
		assert_false(seen.has(slot), "cell %s used twice (%s)" % [slot, key])
		seen[slot] = true


func test_known_keys_and_families() -> void:
	assert_true(_atlas.has("terrain/plains/0"), "plains")
	assert_true(_atlas.has("sea/sea/2"), "sea")
	assert_true(_atlas.has("coast/24/1"), "coast mask 24 (west and south-west sea)")
	assert_false(_atlas.has("terrain/nowhere/0"), "unknown key")
	assert_eq(_atlas.variants("terrain/plains").size(), 2, "plains variants")
	assert_eq(_atlas.variants("sea/sea").size(), 3, "sea variants")
	assert_eq(_atlas.variants("deco/trees").size(), 4, "tree seeds")
	assert_eq(_atlas.variants("no/such").size(), 0, "missing family is empty")


func test_unknown_key_has_no_cell() -> void:
	assert_eq(_atlas.page_of("no/such/key"), -1, "page")
	assert_eq(_atlas.cell_of("no/such/key"), Vector2i(-1, -1), "cell")
