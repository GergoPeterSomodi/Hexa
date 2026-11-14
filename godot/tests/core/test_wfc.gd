## The wave function collapse and its queue, on small grids: every cell collapses, no forbidden pair touches, the same
## seed gives the same map, and the queue pops in Python heapq order.
extends GutTest

const FORBIDDEN_PAIRS := [["mountains", "plains"], ["marsh", "mountains"], ["desert", "forest"]]


func _grid(width: int, height: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for r in height:
		for c in width:
			cells.append(Vector2i(c, r))
	return cells


func _prior_for(cells: Array[Vector2i]) -> Dictionary:
	var prior: Dictionary = {}
	for p: Vector2i in cells:
		if p.x < 3:
			prior[p] = {"plains": 1.0, "forest": 0.4, "mountains": 0.2}
		elif p.x < 6:
			prior[p] = {"plains": 0.5, "marsh": 0.3, "desert": 0.2, "mountains": 0.2}
		else:
			prior[p] = {"desert": 1.0, "forest": 0.3, "snow": 0.0}
	return prior


func _forbidden() -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	for pair: Array in FORBIDDEN_PAIRS:
		out.append(PackedStringArray(pair))
	return out


func _collapse(seed_value: int) -> Dictionary[Vector2i, String]:
	var cells := _grid(9, 7)
	var rng := Rng.new()
	rng.seed_with(seed_value)
	return Wfc.collapse(cells, _prior_for(cells), _forbidden(), 1.6, rng)


func test_every_cell_collapses_to_one_of_its_tiles() -> void:
	var out := _collapse(1480)
	assert_eq(out.size(), 63, "every cell has a tile")
	for p: Vector2i in out.keys():
		assert_true(["plains", "forest", "mountains", "marsh", "desert"].has(out[p]), "%s got %s" % [p, out[p]])


func test_no_forbidden_pair_touches() -> void:
	var out := _collapse(1480)
	for p: Vector2i in out.keys():
		for n: Vector2i in HexGrid.neighbours(p):
			if not out.has(n):
				continue
			for pair: Array in FORBIDDEN_PAIRS:
				var touching: bool = (out[p] == pair[0] and out[n] == pair[1]) or (out[p] == pair[1] and out[n] == pair[0])
				assert_false(touching, "%s %s next to %s %s" % [out[p], p, out[n], n])


func test_the_same_seed_gives_the_same_map() -> void:
	assert_eq(_collapse(7), _collapse(7), "a fixed seed is repeatable")


func test_a_different_seed_gives_another_map() -> void:
	assert_ne(_collapse(7), _collapse(8), "another seed draws another map")


func test_heap_pops_in_count_then_tie_order() -> void:
	var heap := MinHeap.new()
	heap.push(MinHeap.Entry.new(3, 0.5, Vector2i(1, 1)))
	heap.push(MinHeap.Entry.new(1, 0.9, Vector2i(2, 2)))
	heap.push(MinHeap.Entry.new(1, 0.2, Vector2i(3, 3)))
	heap.push(MinHeap.Entry.new(2, 0.1, Vector2i(4, 4)))
	var order: Array[Vector2i] = []
	while not heap.is_empty():
		order.append(heap.pop().pos)
	assert_eq(order, [Vector2i(3, 3), Vector2i(2, 2), Vector2i(4, 4), Vector2i(1, 1)], "smallest count, then tie")
