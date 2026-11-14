## The ridge edges and the mountain passes: a port of build_edges, join_pockets and pass_name_near in
## hexa/campaign/systems/worldgen.py, and the pass hexes of terrain.pass_tables. The named passes of the geography
## open the crest edge nearest to them; then one more pass is opened wherever the ridges would cut a landmass in two.
class_name Passes
extends RefCounted


class Gap:
	extends RefCounted
	var dist: float
	var key: Vector4i

	func _init(p_dist: float, p_key: Vector4i) -> void:
		dist = p_dist
		key = p_key


class Rank:
	extends RefCounted
	var score: int
	var pair: Vector2i

	func _init(p_score: int, p_pair: Vector2i) -> void:
		score = p_score
		pair = p_pair


## Fills map.ridge_edges, map.pass_names, map.pass_ids and map.pass_hexes from the terrain (the land set given).
static func build(map: MapData, data: EuropeData, geo: Geo, land: Dictionary) -> void:
	var crest := Ridges.crest_edges(geo, data, land)
	for k in data.pass_names.size():
		var pid := k + 1
		var px := Ridges.unit_x(geo, data.pass_points[2 * k])
		var py := Ridges.unit_y(geo, data.pass_points[2 * k + 1])
		var ranked: Array[Gap] = []
		for e: Vector4i in crest.keys():
			if not map.pass_names.has(e):
				ranked.append(_gap(px, py, e))
		ranked.sort_custom(_gap_less)
		if ranked.is_empty() or ranked[0].dist > 2.5:
			continue
		_open(map, ranked[0].key, data.pass_names[k], pid)
		if ranked.size() > 1 and ranked[1].dist <= 1.0:
			_open(map, ranked[1].key, data.pass_names[k], pid)
	_join_pockets(map, land, crest)
	for e: Vector4i in crest.keys():
		if not map.pass_names.has(e):
			map.ridge_edges[e] = true
	_pass_hexes(map)


static func _open(map: MapData, edge: Vector4i, name: String, pid: int) -> void:
	map.pass_names[edge] = name
	map.pass_ids[edge] = pid


static func _gap(px: float, py: float, edge: Vector4i) -> Gap:
	var ends := HexGrid.edge_ends(edge)
	var mx := (Ridges.centre_x(ends[0]) + Ridges.centre_x(ends[1])) / 2.0
	var my := (Ridges.centre_y(ends[0]) + Ridges.centre_y(ends[1])) / 2.0
	var sq := (px - mx) * (px - mx) + (py - my) * (py - my)
	return Gap.new(pow(sq, 0.5), edge)


static func _gap_less(a: Gap, b: Gap) -> bool:
	if a.dist != b.dist:
		return a.dist < b.dist
	return HexGrid.edge_less(a.key, b.key)


## Opens one more pass edge wherever the ridges (with their passes) would cut a landmass in two: the pieces are
## joined by the shortest chain of crest edges, one new pass per link, named after the nearest city.
static func _join_pockets(map: MapData, land: Dictionary, crest: Dictionary) -> void:
	var shut: Dictionary = {}
	for e: Vector4i in crest.keys():
		if not map.pass_names.has(e):
			shut[e] = true
	var flat := _label(land, shut)
	var shut_list: Array[Vector4i] = []
	for e: Vector4i in shut.keys():
		shut_list.append(e)
	shut_list.sort_custom(HexGrid.edge_less)
	var links: Dictionary = {}  # Vector2i pair of region ids -> Array of edges, in sorted order
	for e: Vector4i in shut_list:
		var ends := HexGrid.edge_ends(e)
		var fa: int = flat[ends[0]]
		var fb: int = flat[ends[1]]
		if fa != fb:
			var pair := Vector2i(mini(fa, fb), maxi(fa, fb))
			if not links.has(pair):
				links[pair] = []
			var edges: Array = links[pair]
			edges.append(e)
	var sizes: Dictionary = {}
	for region: int in flat.values():
		sizes[region] = int(sizes.get(region, 0)) + 1
	var number := 0
	for pid: int in map.pass_ids.values():
		number = maxi(number, pid)
	var ranks: Array[Rank] = []
	for pair: Vector2i in links.keys():
		var score := mini(int(sizes[pair.x]), int(sizes[pair.y]))
		ranks.append(Rank.new(score, pair))
	ranks.sort_custom(_rank_less)
	var parent: Dictionary = {}
	for rank: Rank in ranks:
		var i := rank.pair.x
		var j := rank.pair.y
		if _find(parent, i) == _find(parent, j):
			continue
		var chain: Array = links[rank.pair]
		var edge: Vector4i = chain[0]
		number += 1
		var taken: Dictionary = {}
		for name: String in map.pass_names.values():
			taken[name] = true
		var name := _pass_name_near(map, HexGrid.edge_ends(edge)[0], taken)
		_open(map, edge, name, number)
		parent[_find(parent, i)] = _find(parent, j)


## Region ids of the land, cut along the shut edges (the regions the passes must join).
static func _label(land: Dictionary, blocked: Dictionary) -> Dictionary:
	var ids: Dictionary = {}
	var count := 0
	var sorted_land: Array[Vector2i] = []
	for p: Vector2i in land.keys():
		sorted_land.append(p)
	sorted_land.sort_custom(HexGrid.lex_less)
	for p: Vector2i in sorted_land:
		if ids.has(p):
			continue
		count += 1
		ids[p] = count
		var queue: Array[Vector2i] = [p]
		var head := 0
		while head < queue.size():
			var cur := queue[head]
			head += 1
			for n: Vector2i in HexGrid.neighbours(cur):
				if land.has(n) and not ids.has(n) and not blocked.has(HexGrid.edge_key(cur, n)):
					ids[n] = count
					queue.append(n)
	return ids


static func _rank_less(a: Rank, b: Rank) -> bool:
	if a.score != b.score:
		return a.score > b.score
	return HexGrid.lex_less(a.pair, b.pair)


static func _find(parent: Dictionary, i: int) -> int:
	var root := i
	while parent.get(root, root) != root:
		root = parent[root]
	return root


## The nearest city's name, with II, III... added while the name is taken by another pass.
static func _pass_name_near(map: MapData, pos: Vector2i, taken: Dictionary) -> String:
	var base := "Mountain"
	var found := false
	var best_dist := 0
	var best_city := Vector2i.ZERO
	for c: Vector2i in map.city_names.keys():
		var d := HexGrid.distance(c, pos)
		if not found or d < best_dist or (d == best_dist and HexGrid.lex_less(c, best_city)):
			found = true
			best_dist = d
			best_city = c
	if found:
		base = map.city_names[best_city]
	var name := base
	var n := 1
	while taken.has(name):
		n += 1
		var roman := ""
		if n < 4:
			for i in n:
				roman += "I"
		elif n == 4:
			roman = "IV"
		else:
			roman = str(n)
		name = base + " " + roman
	return name


## The hexes at the ends of the pass edges, each with the first pass (in edge order) that ends there.
static func _pass_hexes(map: MapData) -> void:
	var edges: Array[Vector4i] = []
	for e: Vector4i in map.pass_names.keys():
		edges.append(e)
	edges.sort_custom(HexGrid.edge_less)
	for e: Vector4i in edges:
		for pos: Vector2i in HexGrid.edge_ends(e):
			if not map.pass_hexes.has(pos):
				map.pass_hexes[pos] = map.pass_names[e]
