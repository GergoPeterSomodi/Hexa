## Terrain names and colours (godot/data/terrain.json), and the colours of the far maps: one colour per grid hex, in
## row-major order (index = row * cols + col). Pure data and functions, no engine calls.
class_name TerrainStyle
extends RefCounted

const PATH := "res://data/terrain.json"

var names: Dictionary[String, String] = {}
var colours: Dictionary[String, Color] = {}


static func load_default() -> TerrainStyle:
	var style := TerrainStyle.new()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	for item: Dictionary in raw["terrain"]:
		var key: String = item["key"]
		var rgb: Array = item["color"]
		style.names[key] = String(item["name"])
		style.colours[key] = Color(float(rgb[0]) / 255.0, float(rgb[1]) / 255.0, float(rgb[2]) / 255.0)
	return style


## Owner of each hex (a country tag) when the builder has them, else an empty dictionary.
## TODO-WIRE: MapData field `owner_of` (Dictionary[Vector2i, String]) from step 2 of the builder.
static func owners(map: MapData) -> Dictionary:
	var raw: Variant = map.get(&"owner_of")
	if raw is Dictionary:
		return raw
	return {}


## Colour of each country tag: the field `country_colours` (Dictionary[String, Color]) when the builder has it, else a
## colour made from the tag, so that owners still show when the colours are missing.
## TODO-WIRE: MapData field `country_colours` from step 2 of the builder.
static func country_colour(map: MapData, tag: String) -> Color:
	var raw: Variant = map.get(&"country_colours")
	if raw is Dictionary:
		var table: Dictionary = raw
		if table.has(tag):
			return table[tag]
	return Color.from_hsv(float(absi(tag.hash()) % 360) / 360.0, 0.55, 0.85)


## The colour of every hex for the far map. `countries` true: the owner's colour where there is one, else the terrain
## colour. `countries` false: the terrain colour everywhere. Land and sea and lakes all have a terrain colour.
func far_colours(map: MapData, countries: bool) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(map.cols * map.rows)
	var owned := owners(map) if countries else {}
	for r in map.rows:
		for c in map.cols:
			var pos := Vector2i(c, r)
			var colour := terrain_colour(map, pos)
			if owned.has(pos):
				colour = country_colour(map, owned[pos])
			out[r * map.cols + c] = colour
	return out


## The owner colour of each hex for the countries overlay on the tile zoom: transparent where nobody owns the hex.
func overlay_colours(map: MapData) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(map.cols * map.rows)
	var owned := owners(map)
	for r in map.rows:
		for c in map.cols:
			var pos := Vector2i(c, r)
			var colour := Color(0, 0, 0, 0)
			if owned.has(pos):
				colour = country_colour(map, owned[pos])
				colour.a = 0.45
			out[r * map.cols + c] = colour
	return out


func terrain_colour(map: MapData, pos: Vector2i) -> Color:
	if not map.terrain.has(pos):
		return Color(0.05, 0.05, 0.08)
	var kind: String = map.terrain[pos]
	return colours.get(kind, Color(1, 0, 1))


func terrain_name(kind: String) -> String:
	return names.get(kind, kind)
