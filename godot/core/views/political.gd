## The political reading of the map (the countries view): owners, the borders between them (with Python's two shades), the
## capitals and the point where each country's name goes. Pure functions over MapData's step-2 fields
## (godot/README.md "MapData fields").
class_name Political
extends RefCounted

## Python's MapView._owner_borders shades: the dark line is the colour tinted down by 35 percent, the light one tinted up.
const DARK := -0.35
const LIGHT := 0.35


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


## Python's tint: a colour pushed toward black (amount below 0) or toward white (above 0).
static func tint(colour: Color, amount: float) -> Color:
	if amount > 0.0:
		return Color(colour.r + (1.0 - colour.r) * amount, colour.g + (1.0 - colour.g) * amount,
				colour.b + (1.0 - colour.b) * amount, 1.0)
	return Color(colour.r * (1.0 + amount), colour.g * (1.0 + amount), colour.b * (1.0 + amount), 1.0)


## Each border edge once: land hexes whose owners differ, where at least one side has an owner. The colours are the
## shades of the owner's colour (the owned side; the first side when both are owned). Returns Array of
## {"a": Vector2i, "b": Vector2i, "dark": Color, "light": Color}.
static func border_items(map: MapData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pos: Vector2i in map.provinces.keys():
		var a := owner_of(map, pos)
		for n: Vector2i in HexGrid.neighbours(pos):
			if not map.provinces.has(n) or not HexGrid.lex_less(pos, n):
				continue
			var b := owner_of(map, n)
			if a == b or (a == "" and b == ""):
				continue
			var tag := a if a != "" else b
			var colour := map.countries[tag].colour if map.countries.has(tag) else Color(0.5, 0.5, 0.5)
			out.append({"a": pos, "b": n, "dark": tint(colour, DARK), "light": tint(colour, LIGHT)})
	return out


## The capital of each country, in geo.COUNTRIES order.
static func capitals(map: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for tag: String in map.country_order:
		if map.countries.has(tag):
			out.append(map.countries[tag].capital)
	return out


## Where each country's name goes: the middle of its largest land body (the owned hexes joined to each other), moved to
## the body hex nearest that middle, so that the name never sits in the sea or across another country.
## Returns an Array of {"name": String, "at": Vector2i, "area": int, "span": float}, in geo.COUNTRIES order, with area the
## number of hexes in the largest body and span the body's width in hexes. Countries with fewer than 3 hexes are left out.
static func name_points(map: MapData) -> Array[Dictionary]:
	var owned := owners(map)
	var seen: Dictionary = {}
	var by_tag: Dictionary = {}
	for start: Vector2i in owned.keys():
		if seen.has(start):
			continue
		var tag: String = owned[start]
		var body := _body(owned, start, seen)
		var best_body: Array = by_tag.get(tag, [])
		if body.size() > best_body.size():
			by_tag[tag] = body
	var out: Array[Dictionary] = []
	for tag: String in map.country_order:
		if not by_tag.has(tag):
			continue
		var body: Array = by_tag[tag]
		if body.size() < 3:
			continue
		var total := Vector2.ZERO
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for pos: Vector2i in body:
			var p := Vector2(pos.x, pos.y)
			total += p
			low = low.min(p)
			high = high.max(p)
		var mid := total / float(body.size())
		var best: Vector2i = body[0]
		var best_d := INF
		for pos: Vector2i in body:
			var d := Vector2(pos.x, pos.y).distance_squared_to(mid)
			if d < best_d:
				best_d = d
				best = pos
		var name := map.countries[tag].name if map.countries.has(tag) else tag
		out.append({"name": name, "at": best, "area": body.size(), "span": high.x - low.x + 1.0})
	return out


## The hexes of one owner joined to `start` through neighbours with the same owner. `seen` gets every hex of the body.
static func _body(owned: Dictionary, start: Vector2i, seen: Dictionary) -> Array[Vector2i]:
	var tag: String = owned[start]
	var body: Array[Vector2i] = []
	var stack: Array[Vector2i] = [start]
	seen[start] = true
	while not stack.is_empty():
		var pos: Vector2i = stack.pop_back()
		body.append(pos)
		for n: Vector2i in HexGrid.neighbours(pos):
			if owned.get(n, "") == tag and not seen.has(n):
				seen[n] = true
				stack.append(n)
	return body
