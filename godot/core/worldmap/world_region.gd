## The hand-written skeleton of the map prototype region (godot/data/worldmap/region_alps_po.json): the window, the grid
## spec, the mountain ranges as spine lines, the named passes with their heights, the valleys, rivers, lakes, gorges,
## notable places and river cities. Points are Vector2(longitude, latitude) in degrees. Text in, data out (no files).
class_name WorldRegion
extends RefCounted

const SCHEMA := "hexa-godot/worldmap-region/1"

var name: String = ""
var lon_west: float = 0.0
var lon_east: float = 0.0
var lat_south: float = 0.0
var lat_north: float = 0.0
var hex_w_km: float = 0.0
var deg_km: float = 0.0
var ref_lat: float = 0.0
## The seed of the ground cover (step 4): the same seed gives the same cover on the same relief.
var cover_seed: int = 1480
## Each range: name (String), crest_level (int), line (PackedVector2Array of lon/lat).
var ranges: Array[Dictionary] = []
## Each pass: name, pos (Vector2 lon/lat), metres (int), range (String).
var passes: Array[Dictionary] = []
## Each valley: name, head (String), floor (PackedVector2Array), mouth (String).
var valleys: Array[Dictionary] = []
## Each river: name, class (int), line (PackedVector2Array), joins (String: the river it flows into, "" for a river that
## reaches the sea, a lake or the edge of the window on its own; only an authored join may join another river), leaves
## (String: the edge of the window it leaves by, "" when it does not leave; its last point is then on that edge's side).
var rivers: Array[Dictionary] = []
## Each lake: name, width (String), width_km (float), axis (PackedVector2Array).
var lakes: Array[Dictionary] = []
## Each gorge: name, pos (Vector2), river (String), range (String).
var gorges: Array[Dictionary] = []
## Each place: name, pos (Vector2 lon/lat), kind (String: city, town, hospice, castle, landmark, castle_town), source.
var places: Array[Dictionary] = []
## Each river city: name, river (String), form (String: straight or loop), bridge (String).
var river_cities: Array[Dictionary] = []
## The Venetian lagoon: a ring of lon/lat points; a hex whose centre lies inside it is lagoon sea (shallow water).
var lagoon: PackedVector2Array = PackedVector2Array()
## Each marsh zone: name (String), ring (PackedVector2Array of lon/lat). Lowland and plain hexes inside are marsh.
var marsh_zones: Array[Dictionary] = []


## The region of a file's text, or null when the text is not a region file of this schema.
static func from_text(text: String) -> WorldRegion:
	var raw: Variant = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = raw
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var out := WorldRegion.new()
	out.name = str(d["name"])
	var window: Dictionary = d["window"]
	out.lon_west = float(window["lon_west"])
	out.lon_east = float(window["lon_east"])
	out.lat_south = float(window["lat_south"])
	out.lat_north = float(window["lat_north"])
	var grid: Dictionary = d["grid"]
	out.hex_w_km = float(grid["hex_w_km"])
	out.deg_km = float(grid["deg_km"])
	out.ref_lat = float(grid["ref_lat"])
	out.cover_seed = int(d.get("cover_seed", 1480))
	for item: Variant in d["ranges"]:
		var r: Dictionary = item
		out.ranges.append({"name": str(r["name"]), "crest_level": int(r["crest_level"]), "line": _points(r["line"])})
	for item: Variant in d["passes"]:
		var p: Dictionary = item
		out.passes.append({"name": str(p["name"]), "pos": _point(p), "metres": int(p["metres"]),
			"range": str(p["range"])})
	for item: Variant in d["valleys"]:
		var v: Dictionary = item
		out.valleys.append({"name": str(v["name"]), "head": str(v["head"]), "floor": _points(v["floor"]),
			"mouth": str(v["mouth"])})
	for item: Variant in d["rivers"]:
		var rv: Dictionary = item
		out.rivers.append({"name": str(rv["name"]), "class": int(rv["class"]), "line": _points(rv["line"]),
			"joins": str(rv.get("joins", "")), "leaves": str(rv.get("leaves", ""))})
	for item: Variant in d["lakes"]:
		var lk: Dictionary = item
		out.lakes.append({"name": str(lk["name"]), "width": str(lk["width"]), "width_km": float(lk["width_km"]),
			"axis": _points(lk["axis"])})
	for item: Variant in d["gorges"]:
		var g: Dictionary = item
		out.gorges.append({"name": str(g["name"]), "pos": _point(g), "river": str(g["river"]),
			"range": str(g["range"])})
	for item: Variant in d["places"]:
		var pl: Dictionary = item
		out.places.append({"name": str(pl["name"]), "pos": _point(pl), "kind": str(pl["kind"]),
			"source": str(pl["source"])})
	if d.has("lagoon"):
		var lg: Dictionary = d["lagoon"]
		out.lagoon = _points(lg["ring"])
	for item: Variant in d.get("marsh_zones", []):
		var mz: Dictionary = item
		out.marsh_zones.append({"name": str(mz["name"]), "ring": _points(mz["ring"])})
	for item: Variant in d["river_cities"]:
		var rc: Dictionary = item
		out.river_cities.append({"name": str(rc["name"]), "river": str(rc["river"]), "form": str(rc["form"]),
			"bridge": str(rc["bridge"])})
	return out


## The place, pass, gorge or river city with this name, or an empty dictionary.
func find_place(place_name: String) -> Dictionary:
	for pl: Dictionary in places:
		if pl["name"] == place_name:
			return pl
	return {}


func find_pass(pass_name: String) -> Dictionary:
	for ps: Dictionary in passes:
		if ps["name"] == pass_name:
			return ps
	return {}


static func _point(d: Dictionary) -> Vector2:
	return Vector2(float(d["lon"]), float(d["lat"]))


static func _points(raw: Variant) -> PackedVector2Array:
	var out := PackedVector2Array()
	for pair: Variant in raw:
		var p: Array = pair
		out.append(Vector2(float(p[0]), float(p[1])))
	return out
