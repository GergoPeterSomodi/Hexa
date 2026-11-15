## The per-hex heights of the map prototype region (godot/data/worldmap/heights_alps_po.json, written by
## tools/worldmap/extract_heights.py from NOAA ETOPO 2022). Text in, data out: the file is read in the shell and the
## tools, so core/ stays free of files. A hex is Vector2i(column, row); a sea hex has land = false and no height.
class_name WorldHeights
extends RefCounted

const SCHEMA := "hexa-godot/worldmap-heights/1"

var height_stat: String = ""  # which statistic of the file is the height (inner_max: the highest ground within 0.4 hex)
var hex_w_km: float = 0.0
var deg_km: float = 0.0
var ref_lat: float = 0.0
var lon_west: float = 0.0
var lat_north: float = 0.0
var lon_east: float = 0.0
var lat_south: float = 0.0
var land: Dictionary[Vector2i, bool] = {}
var height_m: Dictionary[Vector2i, float] = {}  # land hexes only
var depth_m: Dictionary[Vector2i, float] = {}  # sea hexes only (negative metres: the mean of the ETOPO sea cells)
var stats: Dictionary[Vector2i, Dictionary] = {}  # every statistic the file holds, per hex
var anchors: Array[Dictionary] = []  # named places, passes and gorges: kind, name, c, r, z (and metres for passes)


## The heights of a file's text, or null when the text is not a heights file of this schema.
static func from_text(text: String) -> WorldHeights:
	var raw: Variant = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = raw
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var out := WorldHeights.new()
	out.height_stat = str(d["height_stat"])
	var grid: Dictionary = d["grid"]
	out.hex_w_km = float(grid["hex_w_km"])
	out.deg_km = float(grid["deg_km"])
	out.ref_lat = float(grid["ref_lat"])
	var window: Dictionary = d["window"]
	out.lon_west = float(window["lon_west"])
	out.lon_east = float(window["lon_east"])
	out.lat_south = float(window["lat_south"])
	out.lat_north = float(window["lat_north"])
	for item: Variant in d["hexes"]:
		var h: Dictionary = item
		var hex := Vector2i(int(h["c"]), int(h["r"]))
		var is_land: bool = h["land"]
		out.land[hex] = is_land
		if is_land:
			out.height_m[hex] = float(h["height_m"])
		elif h.has("depth_m"):
			out.depth_m[hex] = float(h["depth_m"])
		out.stats[hex] = h
	for item: Variant in d["anchors"]:
		var anchor: Dictionary = item
		out.anchors.append(anchor)
	return out


func has_hex(hex: Vector2i) -> bool:
	return land.has(hex)


func is_land(hex: Vector2i) -> bool:
	return bool(land.get(hex, false))
