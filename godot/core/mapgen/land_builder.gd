## Land, lakes and sea, the forced points, the rivers and the cities: the first steps of build_map in
## hexa/campaign/systems/worldgen.py. Everything here is geometry; the terrain itself is map_builder.gd's wave function.
class_name LandBuilder
extends RefCounted


## Paints the grid: lake or ocean on every hex, then the land from the coastline polygons, with the forced land
## points (and the cities) added and the forced sea points taken away. Returns the land set (hex -> true).
static func paint(map: MapData, data: EuropeData, geo: Geo) -> Dictionary:
	var land: Dictionary = {}
	var lakes: Dictionary = {}
	var land_shapes := Geo.shapes_of(data.land_polygons)
	var sea_shapes := Geo.shapes_of(data.seas)
	var lake_shapes := Geo.shapes_of(data.lakes)
	for r in geo.rows:
		for c in geo.cols:
			var pos := Vector2i(c, r)
			var ll := geo.lonlat(pos)
			if Geo.hit(ll[0], ll[1], lake_shapes):
				lakes[pos] = true
			elif Geo.hit(ll[0], ll[1], land_shapes) and not Geo.hit(ll[0], ll[1], sea_shapes):
				land[pos] = true
	for r in geo.rows:
		for c in geo.cols:
			var pos := Vector2i(c, r)
			map.terrain[pos] = MapData.LAKE if lakes.has(pos) else MapData.OCEAN

	var forced := data.force_land.duplicate()
	forced.append_array(data.city_points)
	for k in Geo.point_count(forced):
		var pos := geo.hex_of(forced[2 * k], forced[2 * k + 1])
		if map.terrain.has(pos):
			land[pos] = true
			lakes.erase(pos)
	for pos: Vector2i in lakes.keys():
		land.erase(pos)
	for k in Geo.point_count(data.force_sea):
		land.erase(geo.hex_of(data.force_sea[2 * k], data.force_sea[2 * k + 1]))
	return land


## The hexes a (lon, lat) polyline passes through, in order, without loops (trace in worldgen.py).
static func trace(map: MapData, geo: Geo, line: PackedFloat64Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(Geo.point_count(line) - 1):
		var x0 := line[2 * i]
		var y0 := line[2 * i + 1]
		var x1 := line[2 * i + 2]
		var y1 := line[2 * i + 3]
		var steps := maxi(1, int(maxf(absf(x1 - x0), absf(y1 - y0)) / geo.col_deg * 4.0))
		for k in range(steps + 1):
			var t := float(k) / float(steps)
			var pos := geo.hex_of(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)
			if not map.terrain.has(pos) or (out.size() > 0 and out[out.size() - 1] == pos):
				continue
			if out.has(pos):
				out.resize(out.find(pos) + 1)  # del out[index + 1:]
				continue
			if out.size() > 0 and HexGrid.distance(out[out.size() - 1], pos) > 1:
				var between: Array[Vector2i] = []
				for n: Vector2i in HexGrid.neighbours(out[out.size() - 1]):
					if HexGrid.distance(n, pos) == 1:
						between.append(n)
				if not between.is_empty():
					out.append(_lex_min(between))
			out.append(pos)
	return out


## Traces each river onto the land it crosses; a river keeps its land hexes when there are three or more.
static func rivers(map: MapData, data: EuropeData, geo: Geo, land: Dictionary) -> void:
	for i in data.rivers.size():
		var name := data.river_names[i]
		var path: Array[Vector2i] = []
		for p: Vector2i in trace(map, geo, data.rivers[i]):
			if land.has(p):
				path.append(p)
		if path.size() >= 3:
			map.rivers[name] = path
			for pos: Vector2i in path:
				if not map.river_at.has(pos):
					map.river_at[pos] = name


## The cities that stand on land (their hexes are forced land, so they are).
static func cities(map: MapData, data: EuropeData, geo: Geo) -> void:
	for i in data.city_names.size():
		var pos := geo.hex_of(data.city_points[2 * i], data.city_points[2 * i + 1])
		if map.is_land(pos):
			map.city_names[pos] = data.city_names[i]
			map.city_sizes[pos] = data.city_sizes[i]


## Numbers each connected body of ocean (the seas), in row-major order of their first hex.
static func sea_bodies(map: MapData) -> void:
	var body := 0
	for pos: Vector2i in map.terrain.keys():
		if map.terrain[pos] != MapData.OCEAN or map.sea_body.has(pos):
			continue
		body += 1
		map.sea_body[pos] = body
		var queue: Array[Vector2i] = [pos]
		var head := 0
		while head < queue.size():
			var cur := queue[head]
			head += 1
			for n: Vector2i in HexGrid.neighbours(cur):
				if map.terrain.has(n) and map.terrain[n] == MapData.OCEAN and not map.sea_body.has(n):
					map.sea_body[n] = body
					queue.append(n)


static func _lex_min(hexes: Array[Vector2i]) -> Vector2i:
	var best := hexes[0]
	for h: Vector2i in hexes:
		if HexGrid.lex_less(h, best):
			best = h
	return best
