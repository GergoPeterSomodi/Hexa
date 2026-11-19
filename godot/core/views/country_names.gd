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
	var cols := map.cols
	# The region's box, with a rim of one slot all round so that no neighbour is ever outside it, as a grid of
	# distances (not a dictionary): -2 outside the region, -1 not reached yet.
	var min_col := cols
	var max_col := -1
	var min_row := map.rows
	var max_row := -1
	for idx: int in region:
		@warning_ignore("integer_division")
		var row := idx / cols
		min_col = mini(min_col, idx - row * cols)
		max_col = maxi(max_col, idx - row * cols)
		min_row = mini(min_row, row)
		max_row = maxi(max_row, row)
	var w := max_col - min_col + 3
	var home := w + 1 - min_row * w - min_col  # box slot = home + row * w + col
	var dist := PackedInt32Array()
	dist.resize(w * (max_row - min_row + 3))
	dist.fill(-2)
	for idx: int in region:
		@warning_ignore("integer_division")
		var row := idx / cols
		dist[home + row * w + idx - row * cols] = -1
	# The six neighbours as slot steps, for an even and an odd row of the map (HexGrid's).
	var step_even := PackedInt32Array([1, -w, -w - 1, -1, w - 1, w])
	var step_odd := PackedInt32Array([1, 1 - w, -w, -1, w, w + 1])
	var queue := PackedInt32Array()  # slots
	for idx: int in region:
		@warning_ignore("integer_division")
		var row := idx / cols
		var slot := home + row * w + idx - row * cols
		for step: int in (step_odd if (row & 1) == 1 else step_even):
			if dist[slot + step] == -2:  # next to something that is not the region: on its boundary
				dist[slot] = 0
				queue.append(slot)
				break
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		var next_d := dist[cur] + 1
		@warning_ignore("integer_division")
		var box_row := cur / w
		var odd := ((box_row + min_row - 1) & 1) == 1
		for step: int in (step_odd if odd else step_even):
			var nb := cur + step
			if dist[nb] == -1:
				dist[nb] = next_d
				queue.append(nb)
	var best_idx := region[0]
	var best_dist := -2
	for idx: int in region:
		@warning_ignore("integer_division")
		var row := idx / cols
		var d_val := dist[home + row * w + idx - row * cols]
		if d_val > best_dist or (d_val == best_dist and idx < best_idx):
			best_dist = d_val
			best_idx = idx
	return map.hex_of(best_idx)


static func _region_entry(map: MapData, cid: int, tag: StringName, text: String,
		region: PackedInt32Array) -> Dictionary:
	var min_col := map.cols
	var max_col := -1
	for idx: int in region:
		var col := idx % map.cols
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
