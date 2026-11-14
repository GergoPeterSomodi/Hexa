## Province names on the Europe 1480 map: the historical region of every land hex, the real place of the hex when
## one exists (placenames.json, GeoNames, CC BY 4.0), and otherwise a description of the land ("Lorraine (forest)").
## A port of assign_regions, region_of, label_groups and name_europe in hexa/campaign/naming.py (the frozen reference).
## Random worlds are not built in 0.3.0, so their naming (make_unique) is not ported.
class_name Naming
extends RefCounted


## A regional anchor: a historical region, or a geography city that names one.
class Anchor:
	extends RefCounted
	var name: String
	var lon: float
	var lat: float
	var tag: String  # the country that held the region ("" when none)
	var mass: int  # the landmass it stands on, -1 when none

	func _init(p_name: String, p_lon: float, p_lat: float, p_tag: String, p_mass: int) -> void:
		name = p_name
		lon = p_lon
		lat = p_lat
		tag = p_tag
		mass = p_mass


## Sets every land province's region (in province order; nothing depends on hashing). A city's hex takes the
## region of its city.
static func assign_regions(map: MapData, data: EuropeData, geo: Geo) -> void:
	var grid := _grid(_anchors(map, data, geo), data.anchor_cell)
	for pos: Vector2i in map.provinces.keys():
		var prov: Province = map.provinces[pos]
		var ll := geo.lonlat(pos)
		prov.region = region_of(grid, data, ll[0], ll[1], prov.owner, map.landmass[pos])
	for pos: Vector2i in map.city_names.keys():
		var city: String = map.city_names[pos]
		if map.provinces.has(pos) and data.city_region.has(city):
			var prov: Province = map.provinces[pos]
			prov.region = str(data.city_region[city])


## Names the land provinces of the Europe map: real places first (the biggest place of a hex that is still free),
## then descriptions of what is left, grouped by region. Cities keep their names; nothing repeats.
static func name_europe(map: MapData, data: EuropeData, geo: Geo) -> void:
	assign_regions(map, data, geo)
	var used: Dictionary = {}
	for prov: Province in map.provinces.values():
		if prov.name != "" and not is_wild(prov.name):
			used[prov.name] = true
	var cities: Dictionary = {}
	for pos: Vector2i in map.city_names.keys():
		cities[map.city_names[pos]] = true
	var todo: Dictionary = {}
	for pos: Vector2i in map.provinces.keys():
		var prov: Province = map.provinces[pos]
		if not prov.city and is_wild(prov.name):
			todo[pos] = true
	var by_hex: Dictionary = {}
	var order: Array[Vector2i] = []
	for i in data.place_names.size():
		var pos := geo.hex_of(data.place_points[2 * i], data.place_points[2 * i + 1])
		if not by_hex.has(pos):
			by_hex[pos] = []
			order.append(pos)
		var hex_names: Array = by_hex[pos]
		hex_names.append(data.place_names[i])
	for pos: Vector2i in order:
		if not todo.has(pos):
			continue
		var hex_names: Array = by_hex[pos]
		for raw: String in hex_names:
			var name: String = data.exonyms.get(raw, raw)
			if data.name_skip.has(raw) or used.has(name) or cities.has(name):
				continue
			var prov: Province = map.provinces[pos]
			prov.name = name
			used[name] = true
			todo.erase(pos)
			break
	var groups: Dictionary = {}
	for pos: Vector2i in todo.keys():
		var prov: Province = map.provinces[pos]
		var region := prov.region
		if region == "":
			region = "Wilderness"
		if not groups.has(region):
			groups[region] = []
		var members: Array = groups[region]
		members.append(pos)
	var labels := label_groups(groups, used, map, geo, data)
	for pos: Vector2i in labels.keys():
		var prov: Province = map.provinces[pos]
		prov.name = str(labels[pos])


## The name of the region a point belongs to: the nearest anchor, the owner's anchors counted as closer and the
## anchors on another landmass as farther. "" when no anchor is near.
static func region_of(grid: Dictionary, data: EuropeData, lon: float, lat: float, owner: String, mass: int) -> String:
	var cell := data.anchor_cell
	var kx := maxf(0.2, cos(deg_to_rad(lat)))
	var cx := floori(lon / cell)
	var cy := floori(lat / cell)
	var have := false
	var best := ""
	var best_d := 0.0
	for ring in range(0, 40):
		if have and (ring - 1) * cell * kx * data.own_weight >= sqrt(best_d):
			break
		for gx in range(cx - ring, cx + ring + 1):
			for gy in range(cy - ring, cy + ring + 1):
				if maxi(absi(gx - cx), absi(gy - cy)) != ring:
					continue
				var bucket: Array = grid.get(Vector2i(gx, gy), [])
				for anchor: Anchor in bucket:
					var dx := (lon - anchor.lon) * kx
					var dy := lat - anchor.lat
					var d := dx * dx + dy * dy
					if anchor.mass != mass:
						d *= data.sea_penalty
					if owner != "" and anchor.tag == owner:
						d *= data.own_weight * data.own_weight
					if not have or d < best_d or (d == best_d and anchor.name < best):
						have = true
						best = anchor.name
						best_d = d
	return best


## Names the hexes of each group "<base> (<what it is like>)": the description first, then with the direction from the
## middle of the group, then with inner or outer, and only then with a number. groups: {base: [pos]}. Returns
## {pos: name}; every name is added to taken (a Dictionary used as a set).
static func label_groups(groups: Dictionary, taken: Dictionary, map: MapData, geo: Geo, data: EuropeData) -> Dictionary:
	var out: Dictionary = {}
	var bases: Array = groups.keys()
	bases.sort()
	for base: String in bases:
		var members: Array[Vector2i] = []
		for pos: Vector2i in groups[base]:
			members.append(pos)
		members.sort_custom(HexGrid.lex_less)
		var lls: Dictionary = {}
		var mx := 0.0
		var my := 0.0
		for pos: Vector2i in members:
			var ll := geo.lonlat(pos)
			lls[pos] = ll
			mx += ll[0]
			my += ll[1]
		mx /= float(members.size())
		my /= float(members.size())
		var dist: Dictionary = {}
		var dists: Array[float] = []
		var kx := cos(deg_to_rad(my))
		for pos: Vector2i in members:
			var ll: PackedFloat64Array = lls[pos]
			var dx := (ll[0] - mx) * kx
			var dy := ll[1] - my
			var d := sqrt(dx * dx + dy * dy)
			dist[pos] = d
			dists.append(d)
		dists.sort()
		var far: float = dists[members.size() >> 1]
		for pos: Vector2i in members:
			var prov: Province = map.provinces[pos]
			var river: String = map.river_at.get(pos, "")
			var words := _descriptions(prov, river, data)
			var ll: PackedFloat64Array = lls[pos]
			var way := compass(ll[0] - mx, ll[1] - my, data)
			var ring := "outer" if float(dist[pos]) > far else "inner"
			var turn := posmod(pos.x * 7 + pos.y * 13, 4)
			# Every word is a variant, starting at a different one per hex.
			var ordered: Array[String] = []
			if words.size() > 1:
				for i in range(turn, words.size()):
					ordered.append(words[i])
				for i in range(0, mini(turn, words.size())):
					ordered.append(words[i])
			else:
				ordered = words
			var tries: Array[String] = []
			for w: String in ordered:
				tries.append("%s (%s)" % [base, w])
			for w: String in ordered:
				tries.append("%s (%s %s)" % [base, way, w])
			for w: String in ordered:
				tries.append("%s (%s %s %s)" % [base, ring, way, w])
			var name := ""
			for t: String in tries:
				if not taken.has(t):
					name = t
					break
			var n := 2
			while name == "":
				var cand := "%s (%s %s %s %d)" % [base, ring, way, ordered[0], n]
				if not taken.has(cand):
					name = cand
				n += 1
			taken[name] = true
			out[pos] = name
	return out


## The eight compass words of the direction (dx, dy): the angle rounded to the nearest eighth turn, as Python's round.
static func compass(dx: float, dy: float, data: EuropeData) -> String:
	var step := HexGrid.round_half_even(atan2(dy, dx) / (PI / 4.0))
	return data.compass[posmod(step, 8)]


## Whether a name is one of the old scheme's placeholders (or empty) that the real-place naming replaces.
static func is_wild(name: String) -> bool:
	return name == "" or name.begins_with("near ") or name.contains(" lands") or name.ends_with("countryside")


## What a hex is like, most telling first (a river's name comes with its valley).
static func _descriptions(prov: Province, river: String, data: EuropeData) -> Array[String]:
	var words: Array[String] = []
	if river != "":
		for w: String in data.river_words:
			words.append(river + " " + w)
	if prov.coastal:
		for w: String in data.coast_words:
			words.append(w)
	if data.land_words.has(prov.terrain):
		for w: String in data.land_words[prov.terrain]:
			words.append(w)
	else:
		words.append(prov.terrain)
	return words


static func _anchors(map: MapData, data: EuropeData, geo: Geo) -> Array[Anchor]:
	var tags: Dictionary = {}
	for i in data.region_names.size():
		var rname := data.region_names[i]
		if not tags.has(rname):
			tags[rname] = data.region_tags[i]
	# [name, lon, lat, tag]: the regions, then the geography cities that name a region.
	var found: Array[Array] = []
	for i in data.region_names.size():
		found.append([data.region_names[i], data.region_points[2 * i], data.region_points[2 * i + 1],
				data.region_tags[i]])
	for i in data.city_names.size():
		var city := data.city_names[i]
		if not data.city_region.has(city):
			continue
		var region := str(data.city_region[city])
		if region == "":
			continue
		found.append([region, data.city_points[2 * i], data.city_points[2 * i + 1], str(tags.get(region, ""))])
	var out: Array[Anchor] = []
	for item: Array in found:
		var lon: float = item[1]
		var lat: float = item[2]
		var pos := geo.hex_of(lon, lat)
		var mass: int = map.landmass.get(pos, -1)
		if mass == -1:
			var near := HexGrid.within(pos, 2)
			near.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				var ka := a != pos
				var kb := b != pos
				if ka != kb:
					return kb
				return HexGrid.lex_less(a, b))
			for p: Vector2i in near:
				if map.landmass.has(p):
					mass = map.landmass[p]
					break
		out.append(Anchor.new(str(item[0]), lon, lat, str(item[3]), mass))
	return out


static func _grid(anchors: Array[Anchor], cell: float) -> Dictionary:
	var grid: Dictionary = {}
	for anchor: Anchor in anchors:
		var key := Vector2i(floori(anchor.lon / cell), floori(anchor.lat / cell))
		if not grid.has(key):
			grid[key] = []
		(grid[key] as Array).append(anchor)
	return grid
