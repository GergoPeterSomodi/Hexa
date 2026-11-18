## Deterministic multi-source Dijkstra territory growth from town and anchor seeds, plus neighbour-pair
## and connected-region queries (docs/architecture/m2-build-spec.md sections 4.3 and 5.1).
class_name ScenarioGrowth
extends RefCounted

const _HEX_BITS := 28
const _HEX_MASK := (1 << _HEX_BITS) - 1


## Grows hex ownership from `scenario.seeds` by integer travel cost up to `scenario.reach`, then applies
## `scenario.pins`. Sea hexes and unreached land hexes stay 0.
static func grow(map: MapData, scenario: ScenarioDef) -> PackedByteArray:
	if map == null:
		return PackedByteArray()
	var n := map.hex_count()
	var out := PackedByteArray()
	out.resize(n)
	out.fill(0)
	if scenario == null or n == 0:
		return out
	var reach := scenario.reach
	if reach < 0:
		_apply_pins(map, scenario, out)
		return out

	var seed_count := scenario.seeds.size()
	var seed_country := PackedByteArray()
	seed_country.resize(seed_count)
	var best_cost := PackedInt32Array()
	best_cost.resize(n)
	best_cost.fill(reach + 1)
	var best_seed := PackedInt32Array()
	best_seed.resize(n)
	best_seed.fill(seed_count)

	var buckets: Array[Array] = []
	buckets.resize(reach + 1)
	for c: int in reach + 1:
		buckets[c] = []

	for s_idx: int in seed_count:
		var seed_entry: Dictionary = scenario.seeds[s_idx]
		var hv: Variant = seed_entry.get("hex", ScenarioDef.NO_HEX)
		if not (hv is Vector2i):
			continue
		var idx := map.index_of(hv as Vector2i)
		if idx < 0 or map.land[idx] == 0:
			continue
		var cid := scenario.id_of(StringName(seed_entry.get("tag", &"")))
		if cid <= 0:
			continue
		var kind := StringName(seed_entry.get("kind", &""))
		if kind != &"town" and kind != &"anchor":
			continue
		var start_cost := 0 if kind == &"town" else scenario.anchor_start
		if start_cost < 0 or start_cost > reach:
			continue
		seed_country[s_idx] = cid
		if _better_entry(start_cost, s_idx, best_cost[idx], best_seed[idx]):
			best_cost[idx] = start_cost
			best_seed[idx] = s_idx
			(buckets[start_cost] as Array).append((s_idx << _HEX_BITS) | idx)

	_run_dijkstra(map, scenario, reach, buckets, seed_country, best_cost, best_seed, out)
	_apply_pins(map, scenario, out)
	return out


## Land-to-land step cost from `hex` in `direction` (0..5), or -1 if off-map or touching sea.
static func step(map: MapData, scenario: ScenarioDef, hex: Vector2i, direction: int) -> int:
	if map == null or scenario == null or direction < 0 or direction > 5:
		return -1
	var a_idx := map.index_of(hex)
	if a_idx < 0 or map.land[a_idx] == 0:
		return -1
	var b_idx := map.index_of(map.neighbour(hex, direction))
	if b_idx < 0 or map.land[b_idx] == 0:
		return -1
	var edge_idx := map.edge_index(hex, direction)
	if edge_idx < 0:
		return -1
	return _edge_step_cost(map, scenario, edge_idx)


## Sorted unique Vector2i(a, b) pairs (a < b) of non-zero country ids sharing a land-to-land edge.
static func neighbour_pairs(map: MapData, owner: PackedByteArray) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if map == null or owner.size() != map.hex_count():
		return out
	var cols := map.cols
	var rows := map.rows
	var grid := map.grid()
	var seen: Dictionary = {}
	for row: int in rows:
		for col: int in cols:
			var idx := row * cols + col
			if map.land[idx] == 0:
				continue
			var own_a := int(owner[idx])
			if own_a <= 0:
				continue
			var hex := Vector2i(col, row)
			for d: int in MapData.OWNED_EDGES:
				var nb := grid.neighbour(hex, d)
				if nb.x < 0 or nb.y < 0 or nb.x >= cols or nb.y >= rows:
					continue
				var nb_idx := nb.y * cols + nb.x
				if map.land[nb_idx] == 0:
					continue
				var own_b := int(owner[nb_idx])
				if own_b <= 0 or own_a == own_b:
					continue
				var pair := Vector2i(mini(own_a, own_b), maxi(own_a, own_b))
				seen[pair] = true
	for k: Variant in seen.keys():
		out.append(k as Vector2i)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y)
	return out


## Connected land components owned by `id`, each sorted ascending and ordered by its first hex index.
static func regions(map: MapData, owner: PackedByteArray, id: int) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	if map == null or id <= 0 or owner.size() != map.hex_count():
		return out
	var n := map.hex_count()
	var cols := map.cols
	var rows := map.rows
	var grid := map.grid()
	var visited := PackedByteArray()
	visited.resize(n)
	for start: int in n:
		if visited[start] != 0 or map.land[start] == 0 or int(owner[start]) != id:
			continue
		var comp := PackedInt32Array()
		var queue: Array[int] = [start]
		visited[start] = 1
		var head := 0
		while head < queue.size():
			var cur := queue[head]
			head += 1
			comp.append(cur)
			var row := floori(float(cur) / float(cols))
			var hex := Vector2i(cur - row * cols, row)
			for d: int in 6:
				var nb := grid.neighbour(hex, d)
				if nb.x < 0 or nb.y < 0 or nb.x >= cols or nb.y >= rows:
					continue
				var nb_idx := nb.y * cols + nb.x
				if visited[nb_idx] != 0 or map.land[nb_idx] == 0 or int(owner[nb_idx]) != id:
					continue
				visited[nb_idx] = 1
				queue.append(nb_idx)
		comp.sort()
		out.append(comp)
	return out


static func _run_dijkstra(map: MapData, scenario: ScenarioDef, reach: int, buckets: Array[Array],
		seed_country: PackedByteArray, best_cost: PackedInt32Array, best_seed: PackedInt32Array,
		out: PackedByteArray) -> void:
	var cols := map.cols
	var rows := map.rows
	var land := map.land
	var grid := map.grid()
	for cost: int in reach + 1:
		var bucket: Array = buckets[cost]
		if bucket.is_empty():
			continue
		bucket.sort()
		var k := 0
		while k < bucket.size():
			var entry: int = int(bucket[k])
			k += 1
			var s_idx := entry >> _HEX_BITS
			var idx := entry & _HEX_MASK
			if out[idx] != 0:
				continue
			out[idx] = seed_country[s_idx]
			var row := floori(float(idx) / float(cols))
			var hex := Vector2i(idx - row * cols, row)
			for d: int in 6:
				var nb := grid.neighbour(hex, d)
				if nb.x < 0 or nb.y < 0 or nb.x >= cols or nb.y >= rows:
					continue
				var nb_idx := nb.y * cols + nb.x
				if land[nb_idx] == 0 or out[nb_idx] != 0:
					continue
				var edge_idx := (MapData.OWNED_EDGES * idx + d) if d < MapData.OWNED_EDGES else (
					MapData.OWNED_EDGES * nb_idx + d - MapData.OWNED_EDGES)
				var step_c := _edge_step_cost(map, scenario, edge_idx)
				if step_c < 0:
					continue
				var next_cost := cost + step_c
				if next_cost > reach:
					continue
				if _better_entry(next_cost, s_idx, best_cost[nb_idx], best_seed[nb_idx]):
					best_cost[nb_idx] = next_cost
					best_seed[nb_idx] = s_idx
					(buckets[next_cost] as Array).append((s_idx << _HEX_BITS) | nb_idx)
					if next_cost == cost:
						var tail := bucket.slice(k)
						tail.sort()
						bucket.resize(k)
						bucket.append_array(tail)


static func _apply_pins(map: MapData, scenario: ScenarioDef, out: PackedByteArray) -> void:
	for pin: Dictionary in scenario.pins:
		var hv: Variant = pin.get("hex", ScenarioDef.NO_HEX)
		if not (hv is Vector2i):
			continue
		var idx := map.index_of(hv as Vector2i)
		if idx < 0 or map.land[idx] == 0:
			continue
		out[idx] = scenario.id_of(StringName(pin.get("tag", &"")))


static func _edge_step_cost(map: MapData, scenario: ScenarioDef, edge_idx: int) -> int:
	var cost := scenario.step_cost
	if map.crest[edge_idx] == 1 and map.pass_edge[edge_idx] == 0:
		cost += scenario.crest_cost
	var rv := int(map.river[edge_idx])
	if rv >= 1 and rv <= 3:
		cost += scenario.river_cost
	return cost


static func _better_entry(cost: int, seed_idx: int, prev_cost: int, prev_seed: int) -> bool:
	return cost < prev_cost or (cost == prev_cost and seed_idx < prev_seed)
