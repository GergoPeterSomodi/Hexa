## Country map-label placements per connected region (docs/architecture/m2-build-spec.md section 5.7).
## Pure core/views/ code: no nodes, no engine calls.
class_name CountryNames
extends RefCounted

const MIN_REGION_HEXES := 3


## Label placements for every country in `game`, in country id order then region order.
static func places(game: Game) -> Array[Dictionary]:
	if game == null or not game.has_countries():
		return []
	var ids := PackedInt32Array()
	ids.resize(game.countries.size())
	for i: int in game.countries.size():
		ids[i] = i + 1
	return places_of(game, ids)


## Label placements for the country `ids`, skipping regions smaller than `MIN_REGION_HEXES`.
## Ordered by ascending country id, then ascending region order.
static func places_of(game: Game, ids: PackedInt32Array) -> Array[Dictionary]:
	if game == null or not game.has_countries() or game.map == null or game.state == null:
		return []
	var wanted := _unique_sorted_ids(ids, game.countries.size())
	var out: Array[Dictionary] = []
	for cid: int in wanted:
		var country := Countries.by_id(game, cid)
		if country == null:
			continue
		var cdef := Countries.def_of(game, country.tag)
		var short_name := cdef.name if cdef != null and not cdef.name.is_empty() else String(country.tag)
		var regs := ScenarioGrowth.regions(game.map, game.state.owner, cid)
		for reg: PackedInt32Array in regs:
			if reg.size() < MIN_REGION_HEXES:
				continue
			out.append(_region_entry(game.map, cid, country.tag, short_name, reg))
	return out


## Hex inside `region` farthest in step distance from its boundary; ties break by lowest hex index.
static func region_label_hex(map: MapData, region: PackedInt32Array) -> Vector2i:
	if map == null or region.is_empty():
		return ScenarioDef.NO_HEX
	var dist: Dictionary[int, int] = {}
	for idx: int in region:
		dist[idx] = -1
	var grid := map.grid()
	var queue: Array[int] = []
	for idx: int in region:
		var hex := map.hex_of(idx)
		for d: int in 6:
			var nb_idx := map.index_of(grid.neighbour(hex, d))
			if nb_idx < 0 or not dist.has(nb_idx):
				dist[idx] = 0
				queue.append(idx)
				break
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		var cur_d := dist[cur]
		var cur_hex := map.hex_of(cur)
		for d: int in 6:
			var nb_idx := map.index_of(grid.neighbour(cur_hex, d))
			if nb_idx >= 0 and dist.get(nb_idx, 0) == -1:
				dist[nb_idx] = cur_d + 1
				queue.append(nb_idx)
	var best_idx := region[0]
	var best_dist := dist[best_idx]
	for idx: int in region:
		var d_val := dist[idx]
		if d_val > best_dist or (d_val == best_dist and idx < best_idx):
			best_dist = d_val
			best_idx = idx
	return map.hex_of(best_idx)


static func _region_entry(map: MapData, cid: int, tag: StringName, text: String,
		region: PackedInt32Array) -> Dictionary:
	var min_col := map.cols
	var max_col := -1
	for idx: int in region:
		var col := map.hex_of(idx).x
		min_col = mini(min_col, col)
		max_col = maxi(max_col, col)
	var label_hex := region_label_hex(map, region)
	return {
		"id": cid,
		"tag": tag,
		"text": text,
		"at": MapTiles.cell_centre(label_hex),
		"span_px": float(max_col - min_col + 1) * float(MapTiles.CELL.x),
		"hexes": region.size(),
	}


static func _unique_sorted_ids(ids: PackedInt32Array, max_id: int) -> Array[int]:
	var seen: Dictionary[int, bool] = {}
	for cid: int in ids:
		if cid >= 1 and cid <= max_id:
			seen[cid] = true
	var out: Array[int] = []
	for cid: int in seen.keys():
		out.append(cid)
	out.sort()
	return out
