## The parchment's geometry (docs/architecture/map-overview-build-spec.md R3, R5, D3, section 4): the wobble is a hash of
## each point's own position, so hexes that share a corner or an edge agree; every edge with land on a side comes once,
## with its two hexes and its kind. Each planted case (P) feeds a check the fault it is there for.
extends GutTest

## Row 14 of north Italy, counted by hand from the land of rows 13 and 14. Row 14 (even) is land at columns 0 to 7 and
## 12 to 18, sea at 8 to 11, 19 and 20; row 13 is land at columns 0 to 17, sea at 18 to 20. An even row's NE neighbour is
## (c, 13) and its NW neighbour (c - 1, 13).
## Land to land: E 7 + 6 = 13; NE 8 (c 0 to 7) + 6 (c 12 to 17) = 14; NW 7 (c 1 to 7) + 7 (c 12 to 18) = 14; so 41.
## Rim (land against the map's edge): column 0 has no W, NW or SW neighbour: 3. Column 20 is sea.
## Coast: E at (7|8), (11|12), (18|19) = 3; NE c 8 to 11 (sea under land) = 4 and c 18 (land under sea) = 1;
## NW c 8 to 11 = 4; so 12.
const HAND_ROW := 14
const HAND_LAND_PAIRS := 41
const HAND_RIM := 3
const HAND_COAST := 12


func _map() -> MapData:
	return EconomyFixture.map()


## The shared edges whose three points differ between the two hexes that hold them, under `outline` (hex -> 12 points),
## over every neighbour pair of the map. [pairs compared, pairs that differ].
func _seams(map: MapData, outline: Callable) -> Vector2i:
	var compared := 0
	var differ := 0
	for i: int in map.hex_count():
		var hex := map.hex_of(i)
		var mine: PackedVector2Array = outline.call(hex)
		for d: int in 3:
			var other := map.neighbour(hex, d)
			if not map.has(other):
				continue
			var theirs: PackedVector2Array = outline.call(other)
			var k := HexGrid.EDGE_CORNERS[d].x
			var back := HexGrid.EDGE_CORNERS[d + 3].x
			compared += 1
			# Their edge runs the other way: their first corner is my last.
			for p: int in 3:
				if mine[(2 * k + p) % 12] != theirs[(2 * back + 2 - p) % 12]:
					differ += 1
					break
	return Vector2i(compared, differ)


## The planted fault: the wobble hashes the hex (and the corner's number), not the corner's own position.
func _outline_hashed_by_hex(hex: Vector2i) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for k: int in 6:
		var move := Vector2(ParchmentShape.hash01(hex.x * 8 + k, hex.y), ParchmentShape.hash01(hex.y, hex.x * 8 + k))
		corners.append(BorderLines.hex_corners(hex)[k] + (move * 2.0 - Vector2.ONE) * ParchmentShape.CORNER_WOBBLE_PX)
	var out := PackedVector2Array()
	for k: int in 6:
		out.append(corners[k])
		out.append(ParchmentShape.middle(corners[k], corners[(k + 1) % 6]))
	return out


## The planted fault of a middle: right corners, a middle moved by a hash of the hex.
func _outline_middle_by_hex(hex: Vector2i) -> PackedVector2Array:
	var out := ParchmentShape.polygon(hex)
	for k: int in 6:
		out[2 * k + 1] += Vector2(ParchmentShape.hash01(hex.x, hex.y), 0.0) * ParchmentShape.MIDDLE_WOBBLE_PX
	return out


# ----- the hash and the points ---------------------------------------------------------------------------------------


func test_hash01_is_a_fixed_integer_hash_in_the_unit_range() -> void:
	# Pinned: the same picture on every machine (R3). A change of the hash changes every coast.
	var pins: Array[int] = []
	for p: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-3, 7), Vector2i(991, 744)]:
		pins.append(int(ParchmentShape.hash01(p.x, p.y) * 4294967296.0))
	assert_eq(pins, [1921767510, 3768280001, 3519829607, 4223005241, 2396082674] as Array[int])
	var low := 1.0
	var high := 0.0
	var sum := 0.0
	var n := 0
	for x: int in range(-50, 50):
		for y: int in range(-50, 50):
			var v := ParchmentShape.hash01(x, y)
			low = minf(low, v)
			high = maxf(high, v)
			sum += v
			n += 1
	assert_gte(low, 0.0)
	assert_lt(high, 1.0)
	assert_almost_eq(sum / float(n), 0.5, 0.02, "even over the range")
	assert_ne(ParchmentShape.hash01(3, 4), ParchmentShape.hash01(4, 3), "x and y are not interchangeable")


func test_corners_stay_within_the_wobble_of_the_true_corner() -> void:
	var map := _map()
	var most := 0.0
	var outside := 0
	for i: int in map.hex_count():
		var hex := map.hex_of(i)
		var true_corners := BorderLines.hex_corners(hex)
		for k: int in 6:
			var moved := (ParchmentShape.corner(hex, k) - true_corners[k]).abs()
			most = maxf(most, maxf(moved.x, moved.y))
			if maxf(moved.x, moved.y) > ParchmentShape.CORNER_WOBBLE_PX + 0.001:
				outside += 1
	assert_eq(outside, 0, "no corner moves more than CORNER_WOBBLE_PX along an axis")
	assert_gt(most, 0.8 * ParchmentShape.CORNER_WOBBLE_PX, "and the corners do move")
	assert_eq(ParchmentShape.corner(Vector2i(4, 5), -1), ParchmentShape.corner(Vector2i(4, 5), 5), "k wraps")
	assert_eq(ParchmentShape.corner(Vector2i(4, 5), 6), ParchmentShape.corner(Vector2i(4, 5), 0), "k wraps")


func test_middle_is_the_same_both_ways_and_moves_only_along_the_normal() -> void:
	var map := _map()
	var most := 0.0
	var differ := 0
	var off_normal := 0
	for i: int in map.hex_count():
		var hex := map.hex_of(i)
		for k: int in 6:
			var a := ParchmentShape.corner(hex, k)
			var b := ParchmentShape.corner(hex, (k + 1) % 6)
			var m := ParchmentShape.middle(a, b)
			if m != ParchmentShape.middle(b, a):
				differ += 1
			var moved := m - (a + b) * 0.5
			most = maxf(most, moved.length())
			if absf(moved.dot((b - a).normalized())) > 0.01:
				off_normal += 1
	assert_eq(differ, 0, "middle(a, b) == middle(b, a)")
	assert_eq(off_normal, 0, "the middle moves along the edge's normal")
	assert_lte(most, ParchmentShape.MIDDLE_WOBBLE_PX + 0.001)
	assert_gt(most, 0.8 * ParchmentShape.MIDDLE_WOBBLE_PX)
	assert_eq(ParchmentShape.middle(Vector2(3.0, 4.0), Vector2(3.0, 4.0)), Vector2(3.0, 4.0), "no edge, no move")


func test_polygon_is_corner_then_middle() -> void:
	var hex := Vector2i(7, 9)
	var poly := ParchmentShape.polygon(hex)
	assert_eq(poly.size(), ParchmentShape.POLYGON_POINTS)
	for k: int in 6:
		assert_eq(poly[2 * k], ParchmentShape.corner(hex, k), "corner %d" % k)
		assert_eq(poly[2 * k + 1], ParchmentShape.middle(poly[2 * k], poly[(2 * k + 2) % 12]), "middle %d" % k)


func test_polygons_fan_from_the_cell_centre() -> void:
	var map := _map()
	var bad := 0
	for i: int in map.hex_count():
		var hex := map.hex_of(i)
		var centre := MapTiles.cell_centre(hex)
		var poly := ParchmentShape.polygon(hex)
		for p: int in poly.size():
			if (poly[p] - centre).cross(poly[(p + 1) % poly.size()] - centre) <= 0.0:
				bad += 1
	assert_eq(bad, 0, "every triangle of the fan from the centre turns clockwise on screen: no fold")


func test_shared_corners_and_middles_are_equal_from_both_hexes() -> void:
	var seams := _seams(_map(), ParchmentShape.polygon)
	assert_gt(seams.x, 1000, "the shared edges of north Italy are compared")
	assert_eq(seams.y, 0, "no gap and no sliver: both hexes give the same three points")


func test_p_a_wobble_hashed_by_the_hex_opens_the_seams() -> void:
	var seams := _seams(_map(), _outline_hashed_by_hex)
	assert_gt(seams.y * 2, seams.x, "P: corners hashed by the hex differ across the shared edges")
	var middles := _seams(_map(), _outline_middle_by_hex)
	assert_gt(middles.y * 2, middles.x, "P: a middle hashed by the hex differs too")


# ----- the edges -----------------------------------------------------------------------------------------------------


## [land pairs, rim edges, coast edges] of an edges() result.
func _kinds(edges: Dictionary) -> Array[int]:
	var out: Array[int] = [0, 0, 0]
	var b: PackedInt32Array = edges["b"]
	var kind: PackedByteArray = edges["kind"]
	for e: int in kind.size():
		if kind[e] == ParchmentShape.Edge.COAST:
			out[2] += 1
		elif b[e] < 0:
			out[1] += 1
		else:
			out[0] += 1
	return out


func test_edges_of_one_row_match_the_hand_count() -> void:
	var edges := ParchmentShape.edges(_map(), Vector2i(HAND_ROW, HAND_ROW + 1))
	assert_eq(_kinds(edges), [HAND_LAND_PAIRS, HAND_RIM, HAND_COAST] as Array[int], "[land pairs, rim, coast]")
	assert_eq((edges["a"] as PackedInt32Array).size(), HAND_LAND_PAIRS + HAND_RIM + HAND_COAST)
	assert_eq((edges["b"] as PackedInt32Array).size(), HAND_LAND_PAIRS + HAND_RIM + HAND_COAST)
	assert_eq((edges["points"] as PackedVector2Array).size(),
		ParchmentShape.EDGE_POINTS * (HAND_LAND_PAIRS + HAND_RIM + HAND_COAST))


func test_every_edge_with_land_comes_once_with_its_hexes_kind_and_points() -> void:
	var map := _map()
	var edges := ParchmentShape.edges(map, Vector2i(0, map.rows))
	var points: PackedVector2Array = edges["points"]
	var a: PackedInt32Array = edges["a"]
	var b: PackedInt32Array = edges["b"]
	var kind: PackedByteArray = edges["kind"]
	# The edges the map should give: a key a pair, and a key a rim side.
	var wanted: Dictionary = {}
	for i: int in map.hex_count():
		var hex := map.hex_of(i)
		for d: int in 6:
			var j := map.index_of(map.neighbour(hex, d))
			if j < 0:
				if map.land[i] == 1:
					wanted[Vector3i(i, -1, d)] = true
			elif map.land[i] == 1 or map.land[j] == 1:
				wanted[Vector3i(mini(i, j), maxi(i, j), 0)] = true
	var twice_or_extra := 0
	var wrong_sides := 0
	var wrong_points := 0
	for e: int in a.size():
		var i := a[e]
		var hex := map.hex_of(i)
		var poly := ParchmentShape.polygon(hex)
		var at := poly.find(points[3 * e])
		if at < 0 or at % 2 != 0 or poly[(at + 1) % 12] != points[3 * e + 1] or poly[(at + 2) % 12] != points[3 * e + 2]:
			wrong_points += 1
			continue
		var d := -1
		for side: int in 6:
			if HexGrid.EDGE_CORNERS[side].x * 2 == at:
				d = side
		if map.index_of(map.neighbour(hex, d)) != b[e]:
			wrong_points += 1
		# `a` lies right of the course on screen.
		if (points[3 * e + 2] - points[3 * e]).cross(MapTiles.cell_centre(hex) - points[3 * e]) <= 0.0:
			wrong_points += 1
		var land_b := b[e] >= 0 and map.land[b[e]] == 1
		var coast := b[e] >= 0 and not land_b
		if map.land[i] != 1 or (kind[e] == ParchmentShape.Edge.COAST) != coast:
			wrong_sides += 1
		var key := Vector3i(i, -1, d) if b[e] < 0 else Vector3i(mini(i, b[e]), maxi(i, b[e]), 0)
		if not wanted.erase(key):
			twice_or_extra += 1
	assert_eq(wrong_points, 0, "three points of polygon(a) on the side toward b, a on the right")
	assert_eq(wrong_sides, 0, "a is land; COAST exactly when b is a sea hex")
	assert_eq(twice_or_extra, 0, "no edge twice, none with sea on both sides")
	assert_eq(wanted.size(), 0, "no edge missing")


func test_slices_of_rows_give_the_whole_map_in_order() -> void:
	var map := _map()
	var slices: Array[Vector2i] = [Vector2i(-5, 1), Vector2i(1, 8), Vector2i(8, 8), Vector2i(8, 99)]
	var whole_rows := Vector2i(0, map.rows)
	for make: Callable in [ParchmentShape.edges, ParchmentShape.mountains]:
		var whole: Dictionary = make.call(map, whole_rows)
		for key: String in whole:
			var joined: Array = []
			for rows: Vector2i in slices:
				joined.append_array(Array((make.call(map, rows) as Dictionary)[key]))
			assert_gt(joined.size(), 0, key)
			assert_true(joined == Array(whole[key]), "%s: the slices give %s in order" % [make.get_method(), key])
	assert_eq((ParchmentShape.edges(null, Vector2i(0, 1))["a"] as PackedInt32Array).size(), 0, "no map, nothing")


# ----- the mountain marks --------------------------------------------------------------------------------------------


func test_mountain_marks_stand_above_the_two_heights() -> void:
	var map := MapData.new()
	map.allocate(6, 1)
	var heights: Array[int] = [1400, 1401, 2400, 2401, 3000, 100]
	for c: int in 6:
		map.land[c] = 0 if c == 4 else 1
		map.height_m[c] = heights[c]
	var marks := ParchmentShape.mountains(map, Vector2i(0, 1))
	assert_eq(marks["hex"], PackedInt32Array([1, 2, 3]), "above 1,400 m, land only")
	assert_eq(marks["big"], PackedByteArray([0, 0, 1]), "above 2,400 m the larger mark")
	var points: PackedVector2Array = marks["points"]
	assert_eq(points.size(), 3 * ParchmentShape.MOUNTAIN_POINTS)
	var small := points[4].x - points[0].x
	var large := points[14].x - points[10].x
	assert_almost_eq(large, small * ParchmentShape.MOUNTAIN_BIG_SCALE, 0.001)
	for m: int in 3:
		var centre := MapTiles.cell_centre(map.hex_of((marks["hex"] as PackedInt32Array)[m]))
		for p: int in ParchmentShape.MOUNTAIN_POINTS:
			var off := (points[m * ParchmentShape.MOUNTAIN_POINTS + p] - centre).abs()
			assert_true(off.x <= 40.0 and off.y <= 40.0, "the mark stays inside its hex")


func test_mountain_marks_of_north_italy() -> void:
	var map := _map()
	var marks := ParchmentShape.mountains(map, Vector2i(0, map.rows))
	var high := 0
	var higher := 0
	for i: int in map.hex_count():
		if map.land[i] == 1 and map.height_m[i] > ParchmentShape.MOUNTAIN_M:
			high += 1
			if map.height_m[i] > ParchmentShape.MOUNTAIN_BIG_M:
				higher += 1
	assert_gt(higher, 0, "north Italy has high Alps")
	assert_eq((marks["hex"] as PackedInt32Array).size(), high)
	assert_eq((marks["big"] as PackedByteArray).count(1), higher)
