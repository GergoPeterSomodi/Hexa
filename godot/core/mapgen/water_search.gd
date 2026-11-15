## Small pure helpers of the river router (WorldWater): the binary heap of [cost, item] pairs, the state key of a corner
## and the corner before it, a chain with its loops cut out, and a point's distance to a line. Split out of world_water.gd
## so that file stays under the size limit; the code is moved as it was.
class_name WaterSearch
extends RefCounted


static func distance_to_line(p: Vector2, line: PackedVector2Array) -> float:
	if line.size() == 1:
		return p.distance_to(line[0])
	var best := INF
	for i: int in line.size() - 1:
		var a := line[i]
		var ab := line[i + 1] - a
		var len2 := ab.length_squared()
		var t := 0.0 if len2 == 0.0 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		best = minf(best, (p - (a + ab * t)).length())
	return best


static func skey(c: Vector3i, prev: Vector3i) -> String:
	return "%d,%d,%d|%d,%d,%d" % [c.x, c.y, c.z, prev.x, prev.y, prev.z]


## The corner before a state, from its key.
static func pc_of_key(key: String) -> Vector3i:
	return state_prev(key)


## The previous corner of a state key (the second part of the key).
static func state_prev(key: String) -> Vector3i:
	var parts := key.split("|")
	var p := parts[1].split(",")
	if int(p[0]) == -1:
		return WorldWater.NO_CORNER
	return Vector3i(int(p[0]), int(p[1]), int(p[2]))


## The chain with its loops taken out: when a corner comes back, the chain is cut back to its first visit.
static func without_loops(chain: Array[Vector3i]) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var index: Dictionary[Vector3i, int] = {}
	for c: Vector3i in chain:
		if index.has(c):
			var j: int = index[c]
			for k: int in range(j + 1, out.size()):
				index.erase(out[k])
			out.resize(j + 1)
		else:
			index[c] = out.size()
			out.append(c)
	return out


static func heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if float(heap[parent][0]) <= float(item[0]):
			break
		heap[i] = heap[parent]
		i = parent
	heap[i] = item


static func heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	var i := 0
	var n := heap.size()
	while true:
		var l := 2 * i + 1
		var r := l + 1
		var m := i
		var mc := float(last[0])
		if l < n and float(heap[l][0]) < mc:
			m = l
			mc = float(heap[l][0])
		if r < n and float(heap[r][0]) < mc:
			m = r
		if m == i:
			break
		heap[i] = heap[m]
		i = m
	heap[i] = last
	return top
