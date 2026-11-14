## The roads of the Europe 1480 map: each country's towns join the nearest town already on its network, and neighbouring
## capitals are joined on the same landmass. A port of build_roads in hexa/campaign/systems/worldgen.py (the frozen
## reference). Costs are kept in half steps (a road hex costs one half, other land its movement cost), so the search
## is exact in integers and the heap order is Python's heapq order on (cost, hex).
class_name RoadBuilder
extends RefCounted

const TOWN_REACH := 14  # scales: a country's towns join the network within this cost
const CAPITAL_REACH := 16  # scales: the cost limit between neighbouring capitals
const CAPITAL_NEAR := 9  # scales: capitals this close (in hexes) on one landmass are joined


static func build(map: MapData, data: EuropeData) -> void:
	var scale := data.scale
	for tag: String in map.country_order:
		var country: Country = map.countries[tag]
		var cap := country.capital
		var towns: Array[Vector2i] = []
		for prov: Province in map.provinces_of(tag):
			if prov.settlement >= 2 or prov.city:
				towns.append(prov.pos)
		# Nearest to the capital first; equal distances keep their province order (Python's stable sort).
		var keyed: Array[Vector3i] = []
		for i in towns.size():
			keyed.append(Vector3i(HexGrid.distance(towns[i], cap), i, 0))
		keyed.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return a.x < b.x or (a.x == b.x and a.y < b.y))
		var network: Dictionary = {cap: true}
		for item: Vector3i in keyed:
			var pos := towns[item.y]
			if network.has(pos):
				continue
			var path := _connect(map, data, pos, network, 2 * TOWN_REACH * scale, tag)
			if not path.is_empty():
				_add_road(map, path)
			network[pos] = true
	var capitals: Array[Vector2i] = []
	for tag: String in map.country_order:
		capitals.append(map.countries[tag].capital)
	for i in capitals.size():
		for j in range(i + 1, capitals.size()):
			var a := capitals[i]
			var b := capitals[j]
			if map.landmass[a] == map.landmass[b] and HexGrid.distance(a, b) <= CAPITAL_NEAR * scale:
				var goals: Dictionary = {b: true}
				var path := _connect(map, data, a, goals, 2 * CAPITAL_REACH * scale, "")
				if not path.is_empty():
					_add_road(map, path)


static func _add_road(map: MapData, path: Array[Vector2i]) -> void:
	map.road_paths.append(path)
	for pos: Vector2i in path:
		map.roads[pos] = true


## The cheapest way from start to the nearest goal hex (goals: a Dictionary used as a set), within the limit in half
## steps. owner "" lets the road cross any country's land; otherwise only land of that country. Empty when none.
static func _connect(map: MapData, data: EuropeData, start: Vector2i, goals: Dictionary, limit: int,
		owner: String) -> Array[Vector2i]:
	var best: Dictionary = {start: 0}
	var came_from: Dictionary = {}
	var heap := MinHeap.new()
	heap.push(MinHeap.Entry.new(0, 0.0, start))
	while not heap.is_empty():
		var top := heap.pop()
		var pos := top.pos
		var cost := top.count
		if cost > int(best[pos]):
			continue
		if goals.has(pos) and pos != start:
			var path: Array[Vector2i] = []
			var cur := pos
			path.append(cur)
			while came_from.has(cur):
				cur = came_from[cur]
				path.append(cur)
			path.reverse()
			return path
		for n: Vector2i in HexGrid.neighbours(pos):
			if not map.provinces.has(n):
				continue
			var prov: Province = map.provinces[n]
			if owner != "" and prov.owner != owner:
				continue
			if map.is_ridge_step(pos, n):
				continue
			var step := 1 if map.roads.has(n) else int(round(float(data.terrain_move[prov.terrain]) * 2.0))
			var next := cost + step
			var known: int = best.get(n, 1 << 30)
			if next <= limit and next < known:
				best[n] = next
				came_from[n] = pos
				heap.push(MinHeap.Entry.new(next, 0.0, n))
	return []
