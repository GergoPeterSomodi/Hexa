## Builds the TileSet of the map's tile layers from the baked atlases (godot/assets/baked): one atlas source per page,
## with the source id = the page number, and one tile per sprite cell. The tile is the hex grid tile (104 x 120,
## hexagon, stacked, horizontal offset axis); the texture region is the atlas cell (110 x 126), centred on the tile.
class_name MapTileSet
extends RefCounted

## The TileSet and the sources in page order (the page of a key is also its source id).
static func build(atlas: AtlasIndex) -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	tiles.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tiles.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tiles.tile_size = atlas.tile_size
	var sources: Array[TileSetAtlasSource] = []
	for page in atlas.page_names.size():
		var source := TileSetAtlasSource.new()
		source.texture = load(AtlasIndex.PAGE_DIR + atlas.page_names[page]) as Texture2D
		source.texture_region_size = atlas.cell_size
		tiles.add_source(source, page)
		sources.append(source)
	for key: String in atlas.keys():
		var source: TileSetAtlasSource = sources[atlas.page_of(key)]
		var cell := atlas.cell_of(key)
		if not source.has_tile(cell):
			source.create_tile(cell)
	return tiles
