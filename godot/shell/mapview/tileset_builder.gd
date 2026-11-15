## Builds the map's TileSet from the indexes the Python tile bake wrote (tools/worldmap/tileset_bake): one atlas source
## per picture size, every tile with its origin, its sort point and its rank, so nobody sets a tile property by hand.
## The TileSet is a hex grid, stacked, offset axis horizontal: cell (column, row) is the rules' hex (column, row).
##
## A season's TileSet (docs/architecture/m1-build-spec.md section 3.4) has three CLIMATE SLOTS: for source `s` of the
## index it has the sources `3 s + 0` (snow), `3 s + 1` (frost), `3 s + 2` (mild). In spring, summer and autumn the three
## slots hold the same pictures; in winter the three winter sets. A cell uses the slot of its hex's climate, so a season
## change is `layer.tile_set = other` and touches no cell. The four TileSets are committed as
## assets/tiles/tiles_<season>.tres (tools/build_tileset.gd writes them; its --check mode fails when they differ).
class_name TilesetBuilder
extends RefCounted

const ROOT := "res://assets/tiles/"
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const CLIMATES := 3
## The bake set behind each climate slot (snow, frost, mild) of a season.
const SETS: Dictionary[String, Array] = {
	"spring": ["spring", "spring", "spring"],
	"summer": ["summer", "summer", "summer"],
	"autumn": ["autumn", "autumn", "autumn"],
	"winter": ["winter_snow", "winter_frost", "winter_mild"],
}
const ALL_SETS: Array[String] = ["spring", "summer", "autumn", "winter_snow", "winter_frost", "winter_mild"]

## Tile name -> Vector3i(source in the index, atlas column, atlas row), the same in every set. Shared, read only.
static var _season_names: Dictionary[String, Vector3i] = {}
## The TileSet of the marks alone and the index source it holds (see marks_set).
static var _marks_set: TileSet = null
static var _marks_source := -1
## The tile that tells which source holds the marks.
const MARK_TILE := "mark/grid"

## The TileSet, or null when the index is missing.
var tile_set: TileSet = null
## Tile name -> Vector3i(source in the index, atlas column, atlas row).
var names: Dictionary[String, Vector3i] = {}
## 3 for a season's TileSet (the view adds the hex's climate: source id = slots * source + climate), 1 for a single set.
var slots := 1
var season := ""
var error := ""


## One set's own folder (the folder with its last slash) as a TileSet of one slot per source: the trial's way.
static func build(folder: String) -> TilesetBuilder:
	var out := TilesetBuilder.new()
	var index := _read_index(folder, out)
	if index.is_empty():
		return out
	var tiles := _new_tile_set(index)
	var sources: Array = index["sources"]
	for s: int in sources.size():
		var source: Dictionary = sources[s]
		var texture := _texture(folder + str(source["file"]))
		if texture == null:
			out.error = "%s%s does not load" % [folder, str(source["file"])]
			continue
		_add_atlas(tiles, source, texture, tiles.get_source_count(), s, out.names)
	out.tile_set = tiles
	return out


## A season's TileSet with its three climate slots, built from the indexes and the imported pictures (what
## tools/build_tileset.gd saves). A picture that is the same file in several sets is loaded once.
static func assemble(season_name: String) -> TilesetBuilder:
	var out := TilesetBuilder.new()
	out.slots = CLIMATES
	out.season = season_name
	if not SETS.has(season_name):
		out.error = "%s is not a season" % season_name
		return out
	var set_names: Array = SETS[season_name]
	var indexes: Array[Dictionary] = []
	for slot: int in CLIMATES:
		var index := _read_index(ROOT + str(set_names[slot]) + "/", out)
		if index.is_empty():
			return out
		indexes.append(index)
	var tiles := _new_tile_set(indexes[0])
	var count := (indexes[0]["sources"] as Array).size()
	var textures: Dictionary[String, Texture2D] = {}  # md5 of the file -> its texture
	for s: int in count:
		for slot: int in CLIMATES:
			var sources: Array = indexes[slot]["sources"]
			var source: Dictionary = sources[s]
			var path := ROOT + str(set_names[slot]) + "/" + str(source["file"])
			var key := FileAccess.get_md5(path)
			if not textures.has(key):
				textures[key] = _texture(path)
			if textures[key] == null:
				out.error = "%s does not load" % path
				return out
			_add_atlas(tiles, source, textures[key], CLIMATES * s + slot, s, out.names if slot == 0 else {})
	out.tile_set = tiles
	return out


## A season's TileSet from its committed file. Loading it loads that season's pictures (and no other season's):
## drop the builder (and the view's reference) to unload them.
static func load_season(season_name: String) -> TilesetBuilder:
	var out := TilesetBuilder.new()
	out.slots = CLIMATES
	out.season = season_name
	var path := tres_path(season_name)
	if not ResourceLoader.exists(path):
		out.error = "%s is not there (tools/build_tileset.gd writes it)" % path
		return out
	# A request_season that is under way (or done) is taken over: that also lets the loader let go of it.
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		out.tile_set = ResourceLoader.load_threaded_get(path) as TileSet
	else:
		out.tile_set = load(path) as TileSet
	if _season_names.is_empty():
		var reader := TilesetBuilder.new()
		var index := _read_index(ROOT + "summer/", reader)
		var table: Dictionary[String, Vector3i] = {}
		var sources: Array = index.get("sources", [])
		for s: int in sources.size():
			var source: Dictionary = sources[s]
			var tiles: Array = source["tiles"]
			for row: Variant in tiles:
				var tile: Dictionary = row
				var at: Array = tile["at"]
				table[str(tile["name"])] = Vector3i(s, int(at[0]), int(at[1]))
		_season_names = table
		out.error = reader.error
	out.names = _season_names
	return out


## A TileSet of the marks source alone (the grid line, the selection ring), the same picture in every season, with the
## source at the id a season's TileSet gives its slot 0 (CLIMATES * source). The layers that hold only marks use it, so
## a season swap never rebuilds them (the grid layer has a cell on every hex). Null when the index is missing.
static func marks_set() -> TileSet:
	if _marks_set != null:
		return _marks_set
	var reader := TilesetBuilder.new()
	var folder := ROOT + "summer/"
	var index := _read_index(folder, reader)
	if index.is_empty():
		return null
	var sources: Array = index["sources"]
	for s: int in sources.size():
		var source: Dictionary = sources[s]
		var holds := false
		var rows: Array = source["tiles"]
		for row: Variant in rows:
			var tile: Dictionary = row
			holds = holds or str(tile["name"]) == MARK_TILE
		if not holds:
			continue
		var texture := _texture(folder + str(source["file"]))
		if texture == null:
			return null
		var tiles := _new_tile_set(index)
		_add_atlas(tiles, source, texture, CLIMATES * s, s, {})
		_marks_set = tiles
		_marks_source = s
		return tiles
	return null


## The index source that holds the marks (-1 before marks_set found it).
static func marks_source() -> int:
	return _marks_source


## Starts loading a season's TileSet and pictures on another thread (the swap then does not wait for the disk:
## load_season finds the resource ready). Ask a moment before the swap, e.g. when the season is about to change.
static func request_season(season_name: String) -> void:
	var path := tres_path(season_name)
	if ResourceLoader.exists(path):
		ResourceLoader.load_threaded_request(path)


## Whether a season's TileSet has been loaded (by request_season) and waits to be taken by load_season.
static func is_loaded(season_name: String) -> bool:
	return ResourceLoader.load_threaded_get_status(tres_path(season_name)) == ResourceLoader.THREAD_LOAD_LOADED


static func tres_path(season_name: String) -> String:
	return ROOT + "tiles_%s.tres" % season_name


## The index of a folder, or {} (and out.error says why).
static func _read_index(folder: String, out: TilesetBuilder) -> Dictionary:
	var path := folder + "index.json"
	if not FileAccess.file_exists(path):
		out.error = "%s is not there" % path
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		out.error = "%s does not read" % path
		return {}
	var index: Dictionary = parsed
	return index


static func _new_tile_set(index: Dictionary) -> TileSet:
	var cell: Array = index["cell"]
	var tiles := TileSet.new()
	tiles.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	tiles.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tiles.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tiles.tile_size = Vector2i(int(cell[0]), int(cell[1]))
	return tiles


## One atlas source of the index: every tile with its origin, sort point and rank. `table` (when not empty-literal
## {}) gets name -> (source in the index, column, row).
static func _add_atlas(tiles: TileSet, source: Dictionary, texture: Texture2D, id: int, source_in_index: int,
		table: Dictionary) -> void:
	var region: Array = source["region"]
	var size := Vector2i(int(region[0]), int(region[1]))
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.separation = Vector2i(int(source["separation"]), int(source["separation"]))
	atlas.texture_region_size = size
	# The engine would make an uncompressed padded copy of every atlas (3 x 290 MB a season); the bake leaves 2 px between tiles.
	atlas.use_texture_padding = false
	tiles.add_source(atlas, id)
	var rows: Array = source["tiles"]
	for row: Variant in rows:
		var tile: Dictionary = row
		var at: Array = tile["at"]
		var anchor: Array = tile["anchor"]
		var coords := Vector2i(int(at[0]), int(at[1]))
		atlas.create_tile(coords)
		var data := atlas.get_tile_data(coords, 0)
		# The picture is drawn with its middle on the cell's middle, moved back by texture_origin: this puts the
		# picture's anchor pixel on the middle of the cell.
		data.texture_origin = Vector2i(int(anchor[0]) - int(size.x / 2.0), int(anchor[1]) - int(size.y / 2.0))
		data.y_sort_origin = int(tile["y_sort"])
		data.z_index = int(tile["z"])
		table[str(tile["name"])] = Vector3i(source_in_index, coords.x, coords.y)


## The imported texture, or the PNG read as it is when the project was not imported since the bake.
static func _texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null:
			return ImageTexture.create_from_image(image)
	return null
