## The Europe 1480 map as text (godot/data/maps/europe_1480.json): the map the builder makes, written once by
## tools/build_map.gd, committed, and loaded by every game (0.3.0 decision 1). Text only: the reads and writes of the
## file are in the shell (main.gd) and the tools, so that core/ stays free of files.
##
## Layout: one JSON object, one line per item. The terrain is one line per grid row (index = column in the row). A
## hex is [column, row]; a crest edge is [a, b, c, d] (HexGrid.edge_key). Dictionaries are written in their order, and
## from_text reads them back in the same order, so to_text(from_text(text)) gives the same text. A province is an array:
## [column, row, terrain, good, coastal, city, name, region, owner, controller, tribe, peasants, burghers, nobles, natives,
## works, settlement, castle, port] (an array, not an object: the start-up reads 14,000 of them).
class_name MapFile
extends RefCounted

const SCHEMA := "hexa-godot/map/1"
const PATH := "res://data/maps/europe_1480.json"  # the committed map file, read by the main scene
const NOTE := "Written by godot/tools/build_map.gd from the map seed and godot/data (see godot/README.md). Do not edit by hand."


## The file's text for a map. The same map gives the same text.
static func to_text(map: MapData) -> String:
	var parts := PackedStringArray()
	parts.append(_field("schema", JSON.stringify(SCHEMA)))
	parts.append(_field("note", JSON.stringify(NOTE)))
	parts.append(_field("cols", str(map.cols)))
	parts.append(_field("rows", str(map.rows)))
	parts.append(_field("map_seed", str(map.map_seed)))
	parts.append(_field("terrain", _terrain_text(map)))
	parts.append(_field("rivers", _list(_river_items(map))))
	parts.append(_field("river_at", _list(_hex_name_items(map.river_at))))
	parts.append(_field("sea_body", _list(_hex_value_items(map.sea_body))))
	parts.append(_field("city_names", _list(_hex_name_items(map.city_names))))
	parts.append(_field("city_sizes", _list(_hex_value_items(map.city_sizes))))
	parts.append(_field("ridge_edges", _list(_edge_items(map.ridge_edges.keys()))))
	parts.append(_field("pass_names", _list(_edge_name_items(map.pass_names))))
	parts.append(_field("pass_ids", _list(_edge_value_items(map.pass_ids))))
	parts.append(_field("pass_hexes", _list(_hex_name_items(map.pass_hexes))))
	parts.append(_field("landmass", _list(_hex_value_items(map.landmass))))
	parts.append(_field("provinces", _list(_province_items(map))))
	parts.append(_field("country_order", JSON.stringify(map.country_order)))
	parts.append(_field("countries", _list(_country_items(map))))
	parts.append(_field("roads", _list(_hex_items(map.roads.keys()))))
	parts.append(_field("road_paths", _list(_path_items(map))))
	parts.append(_field("units", _list(_unit_items(map))))
	return "{\n" + ",\n".join(parts) + "\n}\n"


## The map of a file's text, or null when the text is not a map file of this schema.
static func from_text(text: String) -> MapData:
	var raw: Variant = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = raw
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var map := MapData.new()
	map.cols = int(d["cols"])
	map.rows = int(d["rows"])
	map.map_seed = int(d["map_seed"])
	_read_terrain(map, d["terrain"])
	for item: Variant in d["rivers"]:
		var river: Dictionary = item
		var hexes: Array[Vector2i] = []
		for h: Variant in river["hexes"]:
			hexes.append(_hex(h))
		map.rivers[str(river["name"])] = hexes
	for item: Variant in d["river_at"]:
		map.river_at[_hex(item)] = str(item[2])
	for item: Variant in d["sea_body"]:
		map.sea_body[_hex(item)] = int(item[2])
	for item: Variant in d["city_names"]:
		map.city_names[_hex(item)] = str(item[2])
	for item: Variant in d["city_sizes"]:
		map.city_sizes[_hex(item)] = int(item[2])
	for item: Variant in d["ridge_edges"]:
		map.ridge_edges[_edge(item)] = true
	for item: Variant in d["pass_names"]:
		map.pass_names[_edge(item)] = str(item[4])
	for item: Variant in d["pass_ids"]:
		map.pass_ids[_edge(item)] = int(item[4])
	for item: Variant in d["pass_hexes"]:
		map.pass_hexes[_hex(item)] = str(item[2])
	for item: Variant in d["landmass"]:
		map.landmass[_hex(item)] = int(item[2])
	for item: Variant in d["provinces"]:
		var prov := _read_province(item)
		map.provinces[prov.pos] = prov
	for tag: Variant in d["country_order"]:
		map.country_order.append(str(tag))
	for item: Variant in d["countries"]:
		var country := _read_country(item)
		map.countries[country.tag] = country
	for item: Variant in d["roads"]:
		map.roads[_hex(item)] = true
	for item: Variant in d["road_paths"]:
		var path: Array[Vector2i] = []
		for h: Variant in item:
			path.append(_hex(h))
		map.road_paths.append(path)
	for item: Variant in d["units"]:
		map.units.append(_read_unit(item))
	return map


# ----- writing ----------------------------------------------------------------------------------------------------------

static func _field(key: String, value_text: String) -> String:
	return "\"%s\": %s" % [key, value_text]


## A JSON array with one item per line; each item is already text.
static func _list(items: PackedStringArray) -> String:
	if items.is_empty():
		return "[]"
	return "[\n" + ",\n".join(items) + "\n]"


static func _terrain_text(map: MapData) -> String:
	var rows := PackedStringArray()
	for r: int in map.rows:
		var kinds: Array[String] = []
		for c: int in map.cols:
			kinds.append(str(map.terrain.get(Vector2i(c, r), "")))
		rows.append(JSON.stringify(kinds))
	return _list(rows)


static func _river_items(map: MapData) -> PackedStringArray:
	var out := PackedStringArray()
	for name: String in map.rivers.keys():
		var hexes: Array = []
		for h: Vector2i in map.rivers[name]:
			hexes.append(_pair(h))
		out.append(JSON.stringify({"name": name, "hexes": hexes}))
	return out


## [column, row, name] for a hex-keyed dictionary of names.
static func _hex_name_items(dict: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	for key: Vector2i in (dict as Dictionary).keys():
		out.append(JSON.stringify([key.x, key.y, (dict as Dictionary)[key]]))
	return out


## [column, row, value] for a hex-keyed dictionary of numbers.
static func _hex_value_items(dict: Variant) -> PackedStringArray:
	return _hex_name_items(dict)


## [a, b, c, d, name] for an edge-keyed dictionary of names.
static func _edge_name_items(dict: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for key: Vector4i in dict.keys():
		out.append(JSON.stringify([key.x, key.y, key.z, key.w, dict[key]]))
	return out


## [a, b, c, d, value] for an edge-keyed dictionary of numbers.
static func _edge_value_items(dict: Dictionary) -> PackedStringArray:
	return _edge_name_items(dict)


static func _edge_items(keys: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for key: Vector4i in keys:
		out.append(JSON.stringify([key.x, key.y, key.z, key.w]))
	return out


static func _hex_items(keys: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for key: Vector2i in keys:
		out.append(JSON.stringify(_pair(key)))
	return out


static func _path_items(map: MapData) -> PackedStringArray:
	var out := PackedStringArray()
	for path: Array in map.road_paths:
		var hexes: Array = []
		for h: Vector2i in path:
			hexes.append(_pair(h))
		out.append(JSON.stringify(hexes))
	return out


static func _province_items(map: MapData) -> PackedStringArray:
	var out := PackedStringArray()
	for prov: Province in map.provinces.values():
		out.append(JSON.stringify([prov.pos.x, prov.pos.y, prov.terrain, prov.good, prov.coastal, prov.city, prov.name,
				prov.region, prov.owner, prov.controller, prov.tribe, prov.peasants, prov.burghers, prov.nobles,
				prov.natives, prov.works, prov.settlement, prov.castle, prov.port]))
	return out


static func _country_items(map: MapData) -> PackedStringArray:
	var out := PackedStringArray()
	for tag: String in map.countries.keys():
		var country: Country = map.countries[tag]
		out.append(JSON.stringify({
			"tag": country.tag,
			"name": country.name,
			"colour": [country.colour.r, country.colour.g, country.colour.b, country.colour.a],
			"capital": _pair(country.capital),
			"colonial_start": country.colonial_start,
		}))
	return out


static func _unit_items(map: MapData) -> PackedStringArray:
	var out := PackedStringArray()
	for unit: Unit in map.units:
		out.append(JSON.stringify({
			"id": unit.id,
			"kind": unit.kind,
			"owner": unit.owner,
			"pos": _pair(unit.pos),
			"hp": unit.hp,
			"moves": unit.moves,
		}))
	return out


static func _pair(pos: Vector2i) -> Array:
	return [pos.x, pos.y]


# ----- reading ----------------------------------------------------------------------------------------------------------

static func _hex(raw: Variant) -> Vector2i:
	var a: Array = raw
	return Vector2i(int(a[0]), int(a[1]))


static func _edge(raw: Variant) -> Vector4i:
	var a: Array = raw
	return Vector4i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))


static func _read_terrain(map: MapData, raw: Variant) -> void:
	var rows: Array = raw
	for r: int in rows.size():
		var kinds: Array = rows[r]
		for c: int in kinds.size():
			map.terrain[Vector2i(c, r)] = str(kinds[c])


static func _read_province(raw: Variant) -> Province:
	var a: Array = raw
	var prov := Province.new(Vector2i(int(a[0]), int(a[1])), str(a[2]), bool(a[4]), bool(a[5]))
	prov.good = str(a[3])
	prov.name = str(a[6])
	prov.region = str(a[7])
	prov.owner = str(a[8])
	prov.controller = str(a[9])
	prov.tribe = str(a[10])
	prov.peasants = float(a[11])
	prov.burghers = float(a[12])
	prov.nobles = float(a[13])
	prov.natives = float(a[14])
	prov.works = int(a[15])
	prov.settlement = int(a[16])
	prov.castle = int(a[17])
	prov.port = bool(a[18])
	return prov


static func _read_country(raw: Variant) -> Country:
	var d: Dictionary = raw
	var rgba: Array = d["colour"]
	var colour := Color(float(rgba[0]), float(rgba[1]), float(rgba[2]), float(rgba[3]))
	var country := Country.new(str(d["tag"]), str(d["name"]), colour, _hex(d["capital"]))
	country.colonial_start = int(d["colonial_start"])
	return country


static func _read_unit(raw: Variant) -> Unit:
	var d: Dictionary = raw
	return Unit.new(int(d["id"]), str(d["kind"]), str(d["owner"]), _hex(d["pos"]), int(d["hp"]),
			float(d["moves"]))
