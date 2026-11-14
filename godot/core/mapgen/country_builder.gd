## The countries of the Europe 1480 map at the start: landmasses, capitals and seeds, the owner of every province, the
## names, the people, the towns, castles, works and ports. A port of build_countries in hexa/campaign/systems/worldgen.py
## (the frozen reference). The people factors and the settlement rules are the Python literals, kept as written.
class_name CountryBuilder
extends RefCounted

const DESERT_SEED_SCALES := 2  # a desert hex farther than this many scales from every seed stays unowned


## A territory seed: a point of a country (its capital first), on the land nearest to it.
class SeedPoint:
	extends RefCounted
	var tag: String
	var pos: Vector2i
	var mass: int
	var q: int
	var r: int
	var s: int

	func _init(p_tag: String, p_pos: Vector2i, p_mass: int) -> void:
		tag = p_tag
		pos = p_pos
		mass = p_mass
		q = p_pos.x - ((p_pos.y - (p_pos.y & 1)) >> 1)
		r = p_pos.y
		s = -q - r


static func build(map: MapData, data: EuropeData, geo: Geo, rng: Rng) -> void:
	_landmasses(map)
	var seeds := _countries(map, data, geo)
	_owners(map, data, seeds)
	_people(map, data, geo, rng)
	Naming.name_europe(map, data, geo)
	_settlements(map, data, rng)
	_ports(map)


## Numbers each landmass (connected land) in province order, as Python's landmass dict.
static func _landmasses(map: MapData) -> void:
	var comp := 0
	for pos: Vector2i in map.provinces.keys():
		if map.landmass.has(pos):
			continue
		comp += 1
		map.landmass[pos] = comp
		var queue: Array[Vector2i] = [pos]
		var head := 0
		while head < queue.size():
			var cur := queue[head]
			head += 1
			for n: Vector2i in HexGrid.neighbours(cur):
				if map.provinces.has(n) and not map.landmass.has(n):
					map.landmass[n] = comp
					queue.append(n)


## The countries (in geo.COUNTRIES order), their capitals, and the territory seeds of every country in order.
static func _countries(map: MapData, data: EuropeData, geo: Geo) -> Array[SeedPoint]:
	var seeds: Array[SeedPoint] = []
	for i in data.country_tags.size():
		var tag := data.country_tags[i]
		var points := data.country_seeds[i]
		var capital := _nearest_land(map, geo.hex_of(points[0], points[1]))
		var country := Country.new(tag, data.country_names[i], data.country_colours[i], capital)
		country.colonial_start = int(data.colonial_start.get(tag, 999))
		map.countries[tag] = country
		map.country_order.append(tag)
		for k in Geo.point_count(points):
			var pos := _nearest_land(map, geo.hex_of(points[2 * k], points[2 * k + 1]))
			seeds.append(SeedPoint.new(tag, pos, map.landmass[pos]))
	return seeds


## Every province goes to the nearest seed (a seed of its own landmass within the territory radius, one of another
## landmass only next door); a desert hex far from every seed stays unowned. Capitals always belong to their country.
static func _owners(map: MapData, data: EuropeData, seeds: Array[SeedPoint]) -> void:
	var reach := data.territory_radius
	for pos: Vector2i in map.provinces.keys():
		var prov: Province = map.provinces[pos]
		var q := pos.x - ((pos.y - (pos.y & 1)) >> 1)
		var r := pos.y
		var s := -q - r
		var best := -1
		var best_tag := ""
		var mass: int = map.landmass[pos]
		for seed: SeedPoint in seeds:
			var d := maxi(maxi(absi(q - seed.q), absi(r - seed.r)), absi(s - seed.s))
			var limit := reach if seed.mass == mass else 1
			if d <= limit and (best < 0 or d < best):
				best = d
				best_tag = seed.tag
		if best >= 0 and not (prov.terrain == "desert" and best > DESERT_SEED_SCALES * data.scale):
			prov.owner = best_tag
			prov.controller = best_tag
	for tag: String in map.country_order:
		var capital: Vector2i = map.countries[tag].capital
		var prov: Province = map.provinces[capital]
		prov.owner = tag
		prov.controller = tag


## Names the cities, gives every unowned hex its native people, and sets the people of every hex. The random draws
## are the density of each hex (a factor 0.75 to 1.25).
static func _people(map: MapData, data: EuropeData, geo: Geo, rng: Rng) -> void:
	for pos: Vector2i in map.provinces.keys():
		var prov: Province = map.provinces[pos]
		var ll := geo.lonlat(pos)
		var lon := ll[0]
		var lat := ll[1]
		if map.city_names.has(pos):
			prov.name = map.city_names[pos]
		if prov.owner == "":
			prov.tribe = _nearest_tribe(data, lon, lat)
		var density: float = float(data.terrain_density[prov.terrain]) * (0.75 + 0.5 * rng.randf())
		var size: int = map.city_sizes.get(pos, 0)
		if prov.owner != "":
			var factor := 1.0
			if (lon > -5.0 and lon < 17.0 and lat > 40.0 and lat < 46.0) or \
					(lon > 2.0 and lon < 7.0 and lat > 50.0 and lat < 53.0):
				factor = 1.35
			elif lon > 30.0 and lat > 50.0:
				factor = 0.45
			elif lat > 58.0:
				factor = 0.4
			elif lat < 37.5 and lon < 28.0:
				factor = 0.7
			if data.fertile_river.size() > 0 and _line_distance(lon, lat, data.fertile_river) < 1.0:
				factor = 2.2
			elif map.river_at.has(pos):
				factor *= 1.3
			prov.peasants = density * factor * 0.94
			prov.burghers = density * factor * 0.03
			prov.nobles = density * factor * 0.03
			if map.city_names.has(pos):
				prov.peasants += float(size) * 0.4
				prov.burghers += float(size) * 0.55
				prov.nobles += float(size) * 0.05
		else:
			var factor := 0.35 if lon < -30.0 else (0.6 if lat < 17.0 else 0.5)
			if prov.tribe == "Mexica":
				factor = 1.6
			elif prov.tribe in ["Maya", "Muisca", "Benin", "Akan", "Yoruba", "Hausa"]:
				factor = 0.9
			prov.natives = density * factor
			if map.city_names.has(pos):
				prov.natives += float(size) * 0.5


## Villages, towns, cities, castles and works of the owned provinces, as the starting buildings of the Python builder.
static func _settlements(map: MapData, data: EuropeData, rng: Rng) -> void:
	for pos: Vector2i in map.provinces.keys():
		var prov: Province = map.provinces[pos]
		if prov.owner == "":
			continue
		var country: Country = map.countries[prov.owner]
		var capital := country.capital == pos
		var size: int = map.city_sizes.get(pos, 0)
		if prov.city:
			prov.settlement = 3 if size >= 40 else 2
		elif prov.pop() >= float(data.settlement_pop) * 2.5:
			prov.settlement = 1
		if capital:
			prov.settlement = maxi(prov.settlement, 2)
			prov.castle = 3 if size >= 100 else 2
		elif prov.settlement >= 2 and rng.randf() < 0.3:
			prov.castle = 1
		if prov.coastal and (capital or (prov.city and size >= 25)):
			prov.port = true
		if prov.good != "" and data.works_goods.has(prov.good) and rng.randf() < 0.25:
			prov.works = 2 if (prov.pop() > 20.0 and rng.randf() < 0.4) else 1


## Every coastal country without a port gets one in its coastal province with the most people.
static func _ports(map: MapData) -> void:
	for tag: String in map.country_order:
		var has_port := false
		var best: Province = null
		for prov: Province in map.provinces_of(tag):
			if prov.port:
				has_port = true
			if prov.coastal and (best == null or prov.pop() > best.pop()
					or (prov.pop() == best.pop() and HexGrid.lex_less(best.pos, prov.pos))):
				best = prov
		if best != null and not has_port:
			best.port = true


## The nearest land hex of the province set: the hex itself when it is land, else the nearest by (distance, hex).
static func _nearest_land(map: MapData, pos: Vector2i) -> Vector2i:
	if map.provinces.has(pos):
		return pos
	var best := Vector2i.ZERO
	var best_d := -1
	for p: Vector2i in map.provinces.keys():
		var d := HexGrid.distance(p, pos)
		if best_d < 0 or d < best_d or (d == best_d and HexGrid.lex_less(p, best)):
			best = p
			best_d = d
	return best


static func _nearest_tribe(data: EuropeData, lon: float, lat: float) -> String:
	var best := -1
	var best_d := 0.0
	for i in data.tribe_names.size():
		var dx := data.tribe_points[2 * i] - lon
		var dy := data.tribe_points[2 * i + 1] - lat
		var d := dx * dx + dy * dy
		if best < 0 or d < best_d:
			best = i
			best_d = d
	return data.tribe_names[best]


## Python geo.line_distance: the least distance in degrees from (lon, lat) to a polyline.
static func _line_distance(lon: float, lat: float, line: PackedFloat64Array) -> float:
	var best := INF
	for i in Geo.point_count(line) - 1:
		best = minf(best, Geo.seg_distance(lon, lat, line[2 * i], line[2 * i + 1], line[2 * i + 2], line[2 * i + 3]))
	return best
