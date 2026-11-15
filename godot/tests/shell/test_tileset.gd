## The tile bake and the TileSets built from it (docs/architecture/m1-build-spec.md sections 3.1 to 3.4): the six sets
## have the same tiles at the same places, the committed tiles_<season>.tres have three climate slots a source, and
## every tile's origin, sort point and rank equal the index.
extends GutTest

const ROOT := "res://assets/tiles/"


func _index(set_name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + set_name + "/index.json"))
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "%s index reads" % set_name)
	var index: Dictionary = parsed
	return index


## "source name|tile name" -> "column,row" for a whole index.
func _places(index: Dictionary) -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	var sources: Array = index["sources"]
	for entry: Variant in sources:
		var source: Dictionary = entry
		var tiles: Array = source["tiles"]
		for row: Variant in tiles:
			var tile: Dictionary = row
			var at: Array = tile["at"]
			out["%s|%s" % [source["name"], tile["name"]]] = "%d,%d" % [int(at[0]), int(at[1])]
	return out


func test_the_six_sets_have_the_same_tiles_at_the_same_places() -> void:
	var first := _index("summer")
	var want := _places(first)
	assert_gt(want.size(), 3000)
	for set_name: String in TilesetBuilder.ALL_SETS:
		var index := _index(set_name)
		assert_eq(index["cell"], first["cell"], set_name)
		var a: Array = first["sources"]
		var b: Array = index["sources"]
		assert_eq(b.size(), a.size(), "%s has the same sources" % set_name)
		for i: int in mini(a.size(), b.size()):
			var sa: Dictionary = a[i]
			var sb: Dictionary = b[i]
			for key: String in ["name", "file", "region", "separation"]:
				assert_eq(sb[key], sa[key], "%s source %d %s" % [set_name, i, key])
		var got := _places(index)
		assert_eq(got.size(), want.size(), "%s tile count" % set_name)
		var wrong := 0
		for key: String in want:
			if got.get(key, "") != want[key]:
				wrong += 1
		assert_eq(wrong, 0, "%s: tiles missing or at another place" % set_name)


func test_coast_is_two_sources_and_every_source_fits_the_picture() -> void:
	var index := _index("summer")
	var sources: Array = index["sources"]
	var names: Array[String] = []
	for entry: Variant in sources:
		var source: Dictionary = entry
		names.append(str(source["name"]))
		var region: Array = source["region"]
		var size: Array = source["size"]
		var tiles: Array = source["tiles"]
		var sep := int(source["separation"])
		var most := Vector2i.ZERO
		for row: Variant in tiles:
			var tile: Dictionary = row
			var at: Array = tile["at"]
			most = Vector2i(maxi(most.x, int(at[0])), maxi(most.y, int(at[1])))
		assert_lte((most.x + 1) * (int(region[0]) + sep), int(size[0]) + sep, "%s fits across" % source["name"])
		assert_lte((most.y + 1) * (int(region[1]) + sep), int(size[1]) + sep, "%s fits down" % source["name"])
	assert_eq(names, ["ground", "shade", "coast_0", "coast_1", "trees", "relief", "pieces_0", "pieces_1", "pieces_2", "marks"])


## One season's committed TileSet against the indexes of its three sets.
func _check_season(season: String) -> void:
	var built := TilesetBuilder.load_season(season)
	assert_eq(built.error, "", season)
	assert_not_null(built.tile_set, season)
	if built.tile_set == null:
		return
	assert_eq(built.slots, 3)
	var tiles := built.tile_set
	assert_eq(tiles.tile_shape, TileSet.TILE_SHAPE_HEXAGON)
	assert_eq(tiles.tile_layout, TileSet.TILE_LAYOUT_STACKED)
	assert_eq(tiles.tile_offset_axis, TileSet.TILE_OFFSET_AXIS_HORIZONTAL)
	assert_eq(tiles.tile_size, Vector2i(104, 102))
	var set_names: Array = TilesetBuilder.SETS[season]
	var first := _index(str(set_names[0]))
	var count := (first["sources"] as Array).size()
	assert_eq(tiles.get_source_count(), 3 * count, "%s: three slots a source" % season)
	var bad := 0
	for slot: int in 3:
		var index := _index(str(set_names[slot]))
		var sources: Array = index["sources"]
		for s: int in count:
			var source: Dictionary = sources[s]
			var atlas := tiles.get_source(3 * s + slot) as TileSetAtlasSource
			assert_not_null(atlas, "%s source %d" % [season, 3 * s + slot])
			if atlas == null:
				continue
			assert_false(atlas.use_texture_padding, "a padded copy would be uncompressed")
			var region: Array = source["region"]
			var size := Vector2i(int(region[0]), int(region[1]))
			assert_eq(atlas.texture_region_size, size)
			assert_eq(atlas.get_tiles_count(), (source["tiles"] as Array).size(), "%s %s" % [season, source["name"]])
			var rows: Array = source["tiles"]
			for row: Variant in rows:
				var tile: Dictionary = row
				var at: Array = tile["at"]
				var anchor: Array = tile["anchor"]
				var coords := Vector2i(int(at[0]), int(at[1]))
				if not atlas.has_tile(coords):
					bad += 1
					continue
				var data := atlas.get_tile_data(coords, 0)
				var origin := Vector2i(int(anchor[0]) - int(size.x / 2.0), int(anchor[1]) - int(size.y / 2.0))
				if data.texture_origin != origin or data.y_sort_origin != int(tile["y_sort"]) or data.z_index != int(tile["z"]):
					bad += 1
	assert_eq(bad, 0, "%s: tiles whose origin, sort point or rank differ from the index" % season)
	# The name table: name -> (source in the index, column, row).
	var table: Dictionary[String, Vector3i] = {}
	var sources: Array = first["sources"]
	for s: int in sources.size():
		var source: Dictionary = sources[s]
		var rows: Array = source["tiles"]
		for row: Variant in rows:
			var tile: Dictionary = row
			var at: Array = tile["at"]
			table[str(tile["name"])] = Vector3i(s, int(at[0]), int(at[1]))
	assert_eq(built.names, table)


func test_spring_tileset() -> void:
	_check_season("spring")


func test_summer_tileset() -> void:
	_check_season("summer")


func test_autumn_tileset() -> void:
	_check_season("autumn")


func test_winter_tileset() -> void:
	_check_season("winter")


func test_the_slots_share_pictures_outside_winter_and_differ_in_winter() -> void:
	var summer := TilesetBuilder.load_season("summer").tile_set
	var ground_a := (summer.get_source(0) as TileSetAtlasSource).texture
	var ground_b := (summer.get_source(2) as TileSetAtlasSource).texture
	assert_same(ground_a, ground_b, "summer: one picture behind the three slots")
	var winter := TilesetBuilder.load_season("winter").tile_set
	var snow := (winter.get_source(0) as TileSetAtlasSource).texture
	var frost := (winter.get_source(1) as TileSetAtlasSource).texture
	var mild := (winter.get_source(2) as TileSetAtlasSource).texture
	assert_ne(snow.resource_path, frost.resource_path)
	assert_ne(frost.resource_path, mild.resource_path)
	# shade and marks are the same picture in all six sets: written once, loaded once.
	assert_same((winter.get_source(3) as TileSetAtlasSource).texture, (winter.get_source(4) as TileSetAtlasSource).texture)


func test_the_pictures_are_compressed_for_the_card() -> void:
	for set_name: String in TilesetBuilder.ALL_SETS:
		for file: String in ["ground", "coast_0", "pieces_0", "marks"]:
			var text := FileAccess.get_file_as_string("%s%s/%s.png.import" % [ROOT, set_name, file])
			assert_true(text.contains("compress/mode=2"), "%s/%s is VRAM compressed" % [set_name, file])
			assert_true(text.contains("compress/high_quality=true"), "%s/%s uses BPTC" % [set_name, file])


func test_a_missing_season_says_so() -> void:
	var built := TilesetBuilder.assemble("monsoon")
	assert_null(built.tile_set)
	assert_ne(built.error, "")


func test_a_requested_season_loads_the_same() -> void:
	TilesetBuilder.request_season("autumn")
	var built := TilesetBuilder.load_season("autumn")
	assert_eq(built.error, "")
	assert_not_null(built.tile_set)
	assert_eq(built.tile_set.get_source_count(), 30)
