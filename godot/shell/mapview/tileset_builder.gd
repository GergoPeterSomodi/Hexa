## Builds the map's TileSet from the index the Python tile bake wrote (tools/worldmap/tileset_bake): one atlas source
## per picture size, every tile with its origin, its sort point and its rank, so nobody sets a tile property by hand.
## The TileSet is a hex grid, stacked, offset axis horizontal: cell (column, row) is the rules' hex (column, row).
class_name TilesetBuilder
extends RefCounted

## The TileSet, or null when the index is missing.
var tile_set: TileSet = null
## Tile name -> Vector3i(source id, atlas column, atlas row).
var names: Dictionary[String, Vector3i] = {}
var error := ""


## Reads <folder>index.json (the folder with its last slash) and its atlases.
static func build(folder: String) -> TilesetBuilder:
	var out := TilesetBuilder.new()
	var path := folder + "index.json"
	if not FileAccess.file_exists(path):
		out.error = "%s is not there" % path
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		out.error = "%s does not read" % path
		return out
	var index: Dictionary = parsed
	var cell: Array = index["cell"]
	var tiles := TileSet.new()
	tiles.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	tiles.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tiles.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tiles.tile_size = Vector2i(int(cell[0]), int(cell[1]))
	var sources: Array = index["sources"]
	for entry: Variant in sources:
		var source: Dictionary = entry
		var texture := _texture(folder + str(source["file"]))
		if texture == null:
			out.error = "%s%s does not load" % [folder, str(source["file"])]
			continue
		var region: Array = source["region"]
		var size := Vector2i(int(region[0]), int(region[1]))
		var atlas := TileSetAtlasSource.new()
		atlas.texture = texture
		atlas.separation = Vector2i(int(source["separation"]), int(source["separation"]))
		atlas.texture_region_size = size
		var id := tiles.add_source(atlas)
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
			out.names[str(tile["name"])] = Vector3i(id, coords.x, coords.y)
	out.tile_set = tiles
	return out


## The imported texture, or the PNG read as it is when the project was not imported since the bake.
static func _texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null:
			return ImageTexture.create_from_image(image)
	return null
