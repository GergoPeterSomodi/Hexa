## Throw-away benchmark for docs/design/map/04-wfc-model.md. Not game code.
## Times the heavy steps of the proposed pipeline in GDScript on the real grid (203 x 150) with packed arrays.
## Run: godot --headless --script bench.gd -- <path to godot/data> [scale]   (scale 2 = hexes half as wide)
extends SceneTree

var cols := 0
var rows := 0
var n := 0
var land := PackedByteArray()
var near := PackedInt32Array()  # 6 per cell, -1 off the map
var height := PackedFloat32Array()
var relief := PackedByteArray()
var heap := PackedInt64Array()
var scale := 1


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var data_dir: String = args[0]
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data_dir + "/maps/europe_1480.json"))
	var shapes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data_dir + "/geography/terrain_shapes.json"))
	var proj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data_dir + "/geography/projection.json"))
	if args.size() > 1:
		scale = int(args[1])
	var mem0 := OS.get_static_memory_usage()
	cols = int(map["cols"]) * scale
	rows = int(map["rows"]) * scale
	n = cols * rows
	land.resize(n)
	var terrain: Array = map["terrain"]
	var land_count := 0
	for r in rows:
		var row: Array = terrain[r / scale]
		for c in cols:
			var t: String = row[c / scale]
			var is_land := t != "ocean" and t != "lake" and t != "sea" and t != "coast"
			land[r * cols + c] = 1 if is_land else 0
			if is_land:
				land_count += 1
	print("grid %d x %d = %d hexes, %d land" % [cols, rows, n, land_count])
	var t0 := Time.get_ticks_usec()
	_neighbours()
	var t1 := Time.get_ticks_usec()
	_relief(shapes, proj)
	var t2 := Time.get_ticks_usec()
	var flow := _flood()
	var t3 := Time.get_ticks_usec()
	var stats := _wfc(1480)
	var t4 := Time.get_ticks_usec()
	var searches := _roads(400 * scale * scale, false)
	var t5 := Time.get_ticks_usec()
	_roads(400 * scale * scale, true)
	var t5b := Time.get_ticks_usec()
	var bad := _sockets(flow)
	var t6 := Time.get_ticks_usec()
	print("neighbour table      %7.1f ms" % [(t1 - t0) / 1000.0])
	print("relief from lines    %7.1f ms" % [(t2 - t1) / 1000.0])
	print("drainage (flood+sum) %7.1f ms" % [(t3 - t2) / 1000.0])
	print("cover WFC            %7.1f ms   %s" % [(t4 - t3) / 1000.0, str(stats)])
	print("roads (%d searches)  %7.1f ms" % [searches, (t5 - t4) / 1000.0])
	print("  same searches, stopping at the nearest town (1 hex in 40): %7.1f ms" % [(t5b - t5) / 1000.0])
	print("sockets + checks     %7.1f ms   mismatches %d" % [(t6 - t5b) / 1000.0, bad])
	print("total (full searches)        %7.1f ms" % [(t6 - t0 - (t5b - t5)) / 1000.0])
	print("total (searches that stop)    %7.1f ms" % [(t6 - t0 - (t5 - t4)) / 1000.0])
	print("memory held by the arrays: %.1f MB (peak %.1f MB for the whole process)" % [(OS.get_static_memory_usage() - mem0) / 1048576.0, OS.get_static_memory_peak_usage() / 1048576.0])
	var again := _wfc(1480)
	print("same seed, same result: %s" % [str(again["digest"] == stats["digest"])])
	var other := _wfc(7)
	print("another seed differs:   %s" % [str(other["digest"] != stats["digest"])])
	quit()


func _neighbours() -> void:
	near.resize(n * 6)
	var even := [1, 0, 0, -1, -1, -1, -1, 0, -1, 1, 0, 1]
	var odd := [1, 0, 1, -1, 0, -1, -1, 0, 0, 1, 1, 1]
	for r in rows:
		var d: Array = odd if (r & 1) == 1 else even
		for c in cols:
			var i := r * cols + c
			for e in 6:
				var cc: int = c + d[2 * e]
				var rr: int = r + d[2 * e + 1]
				near[i * 6 + e] = rr * cols + cc if (cc >= 0 and cc < cols and rr >= 0 and rr < rows) else -1


func _relief(shapes: Dictionary, proj: Dictionary) -> void:
	height.resize(n)
	relief.resize(n)
	var lon0: float = proj["lon0"]
	var col_deg: float = float(proj["col_deg"]) / scale
	var y_top: float = proj["y_top"]
	var lines: Array = shapes["mountains"]
	var segs := PackedFloat32Array()  # ax, ay, bx, by, top per segment
	for m: Dictionary in lines:
		var pts: Array = m["line"]
		for k in range(pts.size() - 1):
			segs.append_array([pts[k][0], pts[k][1], pts[k + 1][0], pts[k + 1][1], m["height"]])
	var reach := 0.9
	for r in rows:
		var lat := rad_to_deg(2.0 * atan(exp(deg_to_rad(y_top - (r + 0.5) * col_deg * 0.8660254))) - PI / 2.0)
		for c in cols:
			var i := r * cols + c
			if land[i] == 0:
				height[i] = -1.0
				continue
			var lon := lon0 + (c + 0.5 * (r & 1) + 0.5) * col_deg
			var h := 0.0
			var s := 0
			while s < segs.size():
				var ax := segs[s]
				var ay := segs[s + 1]
				var bx := segs[s + 2]
				var by := segs[s + 3]
				if not (minf(ax, bx) - reach > lon or maxf(ax, bx) + reach < lon or minf(ay, by) - reach > lat or maxf(ay, by) + reach < lat):
					var dx := bx - ax
					var dy := by - ay
					var len2 := dx * dx + dy * dy
					var t := clampf(((lon - ax) * dx + (lat - ay) * dy) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
					var ex := lon - ax - t * dx
					var ey := lat - ay - t * dy
					h = maxf(h, segs[s + 4] * (1.0 - sqrt(ex * ex + ey * ey) / reach))
				s += 5
			h += 0.1 * (_hash(c, r, 7) - 0.5)
			height[i] = maxf(h, 0.0)
			relief[i] = 0 if h < 0.18 else (1 if h < 0.42 else (2 if h < 0.72 else 3))


static func _hash(a: int, b: int, c: int) -> float:
	var h := 2166136261
	for v: int in [a, b, c]:
		h = ((h ^ (v & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
		h = h ^ (h >> 13)
		h = (h * 0x5bd1e995) & 0xFFFFFFFF
		h = h ^ (h >> 15)
	return float(h) / 4294967296.0


# --- a binary min-heap of 64-bit keys (priority in the high bits, the cell in the low 20) -------------------
func _push(key: int) -> void:
	heap.append(key)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if heap[p] <= key:
			break
		heap[i] = heap[p]
		i = p
	heap[i] = key


func _pop() -> int:
	var top := heap[0]
	var last := heap[heap.size() - 1]
	heap.resize(heap.size() - 1)
	var size := heap.size()
	if size > 0:
		var i := 0
		while true:
			var l := 2 * i + 1
			if l >= size:
				break
			var r := l + 1
			var c := r if (r < size and heap[r] < heap[l]) else l
			if heap[c] >= last:
				break
			heap[i] = heap[c]
			i = c
		heap[i] = last
	return top


## Priority flood from the coast: every land hex gets the neighbour its water runs to; then the flow is summed.
func _flood() -> PackedInt32Array:
	var down := PackedInt32Array()
	down.resize(n)
	down.fill(-2)
	var level := PackedInt32Array()
	level.resize(n)
	var order := PackedInt32Array()
	heap.clear()
	for i in n:
		if land[i] == 0:
			continue
		level[i] = int(height[i] * 1000000.0)
		for e in 6:
			var m := near[i * 6 + e]
			if m < 0 or land[m] == 0:
				down[i] = -1
				_push((level[i] << 20) | i)
				break
	while not heap.is_empty():
		var key := _pop()
		var i := key & 0xFFFFF
		var lvl := key >> 20
		order.append(i)
		for e in 6:
			var m := near[i * 6 + e]
			if m >= 0 and land[m] == 1 and down[m] == -2:
				down[m] = i
				level[m] = maxi(level[m], lvl + 1)
				_push((level[m] << 20) | m)
	var acc := PackedInt32Array()
	acc.resize(n)
	acc.fill(1)
	for k in range(order.size() - 1, -1, -1):
		var i := order[k]
		if down[i] >= 0:
			acc[down[i]] += acc[i]
	var streams := 0
	for i in n:
		if land[i] == 1 and acc[i] >= 12:
			streams += 1
	print("  drainage: %d land hexes ordered, %d hexes carry a stream (flow >= 12)" % [order.size(), streams])
	return down


## Ground cover: 14 tiles, domains as bit masks, least options first, an undo log and one-step backtracking.
func _wfc(run_seed: int) -> Dictionary:
	var tiles := 14
	var compat := PackedInt32Array()
	compat.resize(tiles)
	for a in tiles:
		var mask := 0
		for b in tiles:
			if absi(a - b) < 5:
				mask |= 1 << b
		compat[a] = mask
	var domain := PackedInt32Array()
	domain.resize(n)
	var prior := PackedFloat32Array()
	prior.resize(n * tiles)
	var result := PackedByteArray()
	result.resize(n)
	result.fill(255)
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var cells := 0
	for i in n:
		if land[i] == 0:
			continue
		cells += 1
		var base := int(relief[i]) * 3
		var mask := 0
		for k in 5:
			var t := base + k
			mask |= 1 << t
			prior[i * tiles + t] = 0.2 + _hash(i, t, run_seed)
		domain[i] = mask
	var support := {}
	var trail_cell := PackedInt32Array()
	var trail_mask := PackedInt32Array()
	var queue := PackedInt32Array()
	heap.clear()
	for i in n:
		if land[i] == 1:
			_push((_bits(domain[i]) << 44) | (int(_hash(i, 1, run_seed) * 16777215.0) << 20) | i)
			queue.append(i)
	var wipeouts := 0
	var retries := 0
	var relaxed := 0
	var from_input := 0
	var pass_no := 0
	var pending := -1
	var banned := 0
	while true:
		# propagate everything in the queue; a wipe-out undoes the pending choice
		var failed := false
		while not queue.is_empty():
			var p := queue[queue.size() - 1]
			queue.resize(queue.size() - 1)
			var dm := domain[p]
			var allow: int
			if support.has(dm):
				allow = support[dm]
			else:
				allow = 0
				for t in tiles:
					if (dm >> t) & 1 == 1:
						allow |= compat[t]
				support[dm] = allow
			for e in 6:
				var m := near[p * 6 + e]
				if m < 0 or land[m] == 0 or result[m] != 255:
					continue
				var before := domain[m]
				var nd := before & allow
				if nd == before:
					continue
				if nd == 0:
					wipeouts += 1
					if pending >= 0:
						failed = true
						break
					relaxed += 1
					continue
				trail_cell.append(m)
				trail_mask.append(before)
				domain[m] = nd
				queue.append(m)
				_push((_bits(nd) << 44) | (int(_hash(m, pass_no, run_seed) * 16777215.0) << 20) | m)
			if failed:
				break
		var p2 := -1
		if failed:
			queue.clear()
			while trail_cell[trail_cell.size() - 1] != -1:
				domain[trail_cell[trail_cell.size() - 1]] = trail_mask[trail_mask.size() - 1]
				trail_cell.resize(trail_cell.size() - 1)
				trail_mask.resize(trail_mask.size() - 1)
			trail_cell.resize(trail_cell.size() - 1)
			var old := trail_mask[trail_mask.size() - 1]
			trail_mask.resize(trail_mask.size() - 1)
			banned |= 1 << result[pending]
			result[pending] = 255
			domain[pending] = old
			p2 = pending
			retries += 1
		else:
			pending = -1
			banned = 0
			trail_cell.clear()
			trail_mask.clear()
			while not heap.is_empty():
				var key := _pop()
				var i := key & 0xFFFFF
				if result[i] == 255 and (key >> 44) == _bits(domain[i]):
					p2 = i
					break
			if p2 < 0:
				break
		if pass_no == 0 and not failed:
			from_input = relaxed
		# choose a tile for p2: prior times (1 + affinity * same neighbours)
		var options := domain[p2] & ~banned
		if options == 0:
			options = domain[p2]
			relaxed += 1
			pending = -1
		else:
			pending = p2
		var total := 0.0
		var weights := PackedFloat32Array()
		weights.resize(tiles)
		for t in tiles:
			if (options >> t) & 1 == 1:
				var same := 0
				for e in 6:
					var m := near[p2 * 6 + e]
					if m >= 0 and result[m] == t:
						same += 1
				weights[t] = prior[p2 * tiles + t] * (1.0 + 1.6 * same)
				total += weights[t]
		var x := rng.randf() * total
		var pick := 0
		for t in tiles:
			if (options >> t) & 1 == 1:
				pick = t
				x -= weights[t]
				if x < 0.0:
					break
		if pending >= 0:
			trail_cell.append(-1)
			trail_mask.append(domain[p2])
		result[p2] = pick
		domain[p2] = 1 << pick
		pass_no += 1
		queue.append(p2)
	var bad := 0
	var digest := 0
	for i in n:
		if land[i] == 0:
			continue
		digest = (digest * 1000003 + result[i]) & 0xFFFFFFFFFFFF
		for e in 3:
			var m := near[i * 6 + e]
			if m >= 0 and land[m] == 1 and (compat[result[i]] >> result[m]) & 1 == 0:
				bad += 1
	return {"cells": cells, "wipeouts": wipeouts, "retries": retries, "relaxed": relaxed, "relaxed_before_first_choice": from_input, "bad_pairs": bad, "digest": digest}


static func _bits(x: int) -> int:
	var count := 0
	while x != 0:
		x &= x - 1
		count += 1
	return count


## Cheapest-path searches with a cost limit (as the road builder does), on packed arrays.
func _roads(count: int, stop_at_town: bool) -> int:
	var best := PackedInt32Array()
	best.resize(n)
	var stamp := PackedInt32Array()
	stamp.resize(n)
	var done := 0
	var step := maxi(1, n / (count * 2))
	var i := 0
	var visited := 0
	while done < count and i < n:
		if land[i] == 1:
			done += 1
			heap.clear()
			_push(i)
			best[i] = 0
			stamp[i] = done
			while not heap.is_empty():
				var key := _pop()
				var p := key & 0xFFFFF
				var cost := key >> 20
				if cost > best[p]:
					continue
				visited += 1
				if stop_at_town and p != i and (p * 7919) % 40 == 0:
					break
				for e in 6:
					var m := near[p * 6 + e]
					if m < 0 or land[m] == 0:
						continue
					var nc := cost + 2 + 3 * int(relief[m])
					if nc <= 60 * scale and (stamp[m] != done or nc < best[m]):
						stamp[m] = done
						best[m] = nc
						_push((nc << 20) | m)
		i += step
	print("  roads: %d hexes settled in all" % [visited])
	return done


## One packed record per edge (3 owned edges per hex), then every hex reads its six and they are checked.
func _sockets(down: PackedInt32Array) -> int:
	var sock := PackedInt32Array()
	sock.resize(n * 3)
	for i in n:
		for e in 3:
			var m := near[i * 6 + e]
			if m < 0:
				continue
			var s := 0
			if land[i] == 0 and land[m] == 0:
				s = 1
			elif land[i] != land[m]:
				s = 2
			else:
				var d := absi(int(relief[i]) - int(relief[m]))
				s = (3 + mini(d, 2)) | ((1 << 4) if (down[i] == m or down[m] == i) else 0)
			sock[i * 3 + e] = s
	var bad := 0
	var masks := {}
	for i in n:
		if land[i] == 0:
			continue
		var water := 0
		for e in 6:
			var m := near[i * 6 + e]
			if m < 0:
				continue
			var s := sock[i * 3 + e] if e < 3 else sock[m * 3 + e - 3]
			if (s >> 4) & 1 == 1:
				water |= 1 << e
			if (s & 15) == 0:
				bad += 1
		masks[water] = true
	print("  sockets: %d distinct water masks of 64" % [masks.size()])
	return bad
