## The political reading of the map (the countries view): owners, the borders between them, the capitals and the point
## where each country's name goes. Pure functions over MapData's step-2 fields (godot/README.md "MapData fields").
class_name Political
extends RefCounted


## The owner (country tag) of every land hex that has one. Unowned hexes are absent.
static func owners(map: MapData) -> Dictionary:
	var out: Dictionary[Vector2i, String] = {}
	for pos: Vector2i in map.provinces.keys():
		var prov: Province = map.provinces[pos]
		if prov.owner != "":
			out[pos] = prov.owner
	return out


## The owner of one land hex, "" when none or not land.
static func owner_of(map: MapData, pos: Vector2i) -> String:
	var prov: Province = map.province(pos)
	return prov.owner if prov != null else ""


## Each border edge once (HexGrid.edge_key): land hexes whose owners differ, where at least one side has an owner.
static func border_edges(map: MapData) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	for pos: Vector2i in map.provinces.keys():
		var a := owner_of(map, pos)
		for n: Vector2i in HexGrid.neighbours(pos):
			if not map.provinces.has(n) or not HexGrid.lex_less(pos, n):
				continue
			var b := owner_of(map, n)
			if a != b and (a != "" or b != ""):
				out.append(HexGrid.edge_key(pos, n))
	return out


## The capital of each country, in geo.COUNTRIES order.
static func capitals(map: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for tag: String in map.country_order:
		if map.countries.has(tag):
			out.append(map.countries[tag].capital)
	return out


## Where each country's name is written: the owned hex nearest to the middle of its provinces, with its name.
## Returns an Array of {"name": String, "at": Vector2i}, in geo.COUNTRIES order; countries without land are left out.
static func name_points(map: MapData) -> Array[Dictionary]:
	var sums: Dictionary = {}
	var counts: Dictionary = {}
	var members: Dictionary = {}
	for pos: Vector2i in map.provinces.keys():
		var tag := owner_of(map, pos)
		if tag == "":
			continue
		var sum: Vector2 = sums.get(tag, Vector2.ZERO)
		sums[tag] = sum + Vector2(pos.x, pos.y)
		counts[tag] = int(counts.get(tag, 0)) + 1
		var list: Array = members.get(tag, [])
		list.append(pos)
		members[tag] = list
	var out: Array[Dictionary] = []
	for tag: String in map.country_order:
		if not members.has(tag):
			continue
		var mid: Vector2 = sums[tag] / float(counts[tag])
		var best := Vector2i.ZERO
		var best_d := INF
		for pos: Vector2i in members[tag]:
			var d := Vector2(pos.x, pos.y).distance_squared_to(mid)
			if d < best_d:
				best_d = d
				best = pos
		var name := map.countries[tag].name if map.countries.has(tag) else tag
		out.append({"name": name, "at": best})
	return out
