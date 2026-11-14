## The baked art atlases (godot/assets/baked/index.json): which page and which cell holds each sprite key, such as
## "terrain/plains/1" or "coast/9/0" (the key is the Python call's family, see docs/design/art-inventory.md).
## Pure data: it reads the JSON and answers lookups. The shell builds the TileSet from it.
class_name AtlasIndex
extends RefCounted

const INDEX_PATH := "res://assets/baked/index.json"
const PAGE_DIR := "res://assets/baked/"

var page_names: PackedStringArray = PackedStringArray()  # atlas page file names, sorted; the page number is the index
var page_sizes: Array[Vector2i] = []  # pixel size of each page
var tile_size: Vector2i = Vector2i.ZERO  # the grid tile (104 x 120)
var cell_size: Vector2i = Vector2i.ZERO  # one atlas cell: the sprite plus its 2 px extruded border (110 x 126)
var extrude: int = 0
var _cell: Dictionary[String, Vector3i] = {}  # key -> (page, cell x, cell y)
var _keys: PackedStringArray = PackedStringArray()  # every key, sorted
var _families: Dictionary[String, PackedStringArray] = {}  # "terrain/plains" -> its keys, sorted


static func load_index(path: String = INDEX_PATH) -> AtlasIndex:
	var index := AtlasIndex.new()
	index._read(path)
	return index


func _read(path: String) -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary:
		return
	var data: Dictionary = raw
	var tile: Array = data["tile_size"]
	tile_size = Vector2i(int(tile[0]), int(tile[1]))
	var cell: Array = data["cell"]
	cell_size = Vector2i(int(cell[0]), int(cell[1]))
	extrude = int(data["extrude"])
	var atlases: Dictionary = data["atlases"]
	page_names = PackedStringArray(atlases.keys())
	page_names.sort()
	for name: String in page_names:
		var entry: Dictionary = atlases[name]
		var size: Array = entry["size"]
		page_sizes.append(Vector2i(int(size[0]), int(size[1])))
	var sprites: Dictionary = data["sprites"]
	for key: String in sprites.keys():
		var sprite: Dictionary = sprites[key]
		var page := page_names.find(String(sprite["atlas"]))
		var rect: Array = sprite["rect"]
		# The rect is the sprite inside its cell: the cell starts `extrude` pixels above and left of it.
		var cx := int(float(int(rect[0]) - extrude) / float(cell_size.x))
		var cy := int(float(int(rect[1]) - extrude) / float(cell_size.y))
		_cell[key] = Vector3i(page, cx, cy)
		_keys.append(key)
	_keys.sort()
	for key: String in _keys:
		var slash := key.rfind("/")
		var family := key.substr(0, slash)
		var members: PackedStringArray = _families.get(family, PackedStringArray())
		members.append(key)
		_families[family] = members


func has(key: String) -> bool:
	return _cell.has(key)


func sprite_count() -> int:
	return _keys.size()


func keys() -> PackedStringArray:
	return _keys


## Page number (index into page_names) of a key, or -1.
func page_of(key: String) -> int:
	if not _cell.has(key):
		return -1
	return _cell[key].x


## Cell of a key inside its page (cell x, cell y), or Vector2i(-1, -1).
func cell_of(key: String) -> Vector2i:
	if not _cell.has(key):
		return Vector2i(-1, -1)
	var c := _cell[key]
	return Vector2i(c.y, c.z)


## The keys of one family ("terrain/plains" gives terrain/plains/0, /1, ...), sorted; empty when there are none.
func variants(family: String) -> PackedStringArray:
	if not _families.has(family):
		return PackedStringArray()
	return _families[family]
