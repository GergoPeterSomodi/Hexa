## Pure unit tests for BorderLines (docs/architecture/m2-build-spec.md sections 4.6, 5.7, and 10).
extends GutTest


func _make_map(cols: int, rows: int, sea_rows: Array[int] = []) -> MapData:
	var map := MapData.new()
	map.id = "border_fixture"
	map.allocate(cols, rows)
	for r: int in rows:
		var is_sea := sea_rows.has(r)
		for c: int in cols:
			var i := r * cols + c
			map.land[i] = 0 if is_sea else 1
			map.cover[i] = MapData.COVER_SEA if is_sea else 0
	return map


func _palette() -> PackedColorArray:
	return PackedColorArray([
		Color("#d8ccb0"),
		Color("#be3c6e"),
		Color("#3460b2"),
		Color("#1ea08c"),
	])


func _count_differing_land_edges(map: MapData, owner: PackedByteArray) -> int:
	var count := 0
	for r: int in map.rows:
		for c: int in map.cols:
			var hex := Vector2i(c, r)
			var i := map.index_of(hex)
			if map.land[i] == 0:
				continue
			for d: int in MapData.OWNED_EDGES:
				var j := map.index_of(map.neighbour(hex, d))
				if j >= 0 and map.land[j] == 1 and owner[i] != owner[j]:
					count += 1
	return count


func _edge_key(p0: Vector2, p1: Vector2) -> String:
	var a := Vector2i(roundi(p0.x * 10.0), roundi(p0.y * 10.0))
	var b := Vector2i(roundi(p1.x * 10.0), roundi(p1.y * 10.0))
	if b.x < a.x or (b.x == a.x and b.y < a.y):
		var tmp := a
		a = b
		b = tmp
	return "%d,%d-%d,%d" % [a.x, a.y, b.x, b.y]


func test_empty_and_uniform_owners_produce_no_borders() -> void:
	var map := _make_map(6, 6)
	var palette := _palette()
	var owner := PackedByteArray()
	owner.resize(map.hex_count())
	assert_eq(BorderLines.for_chunk(map, owner, Vector2i.ZERO, palette), [] as Array[Dictionary])
	owner.fill(1)
	assert_eq(BorderLines.for_chunk(map, owner, Vector2i.ZERO, palette), [] as Array[Dictionary])
	assert_eq(BorderLines.for_chunk(null, owner, Vector2i.ZERO, palette), [] as Array[Dictionary])
	var bad_size := PackedByteArray([1, 2])
	assert_eq(BorderLines.for_chunk(map, bad_size, Vector2i.ZERO, palette), [] as Array[Dictionary])


func test_differing_land_edges_bands_and_coast_rules() -> void:
	var map := _make_map(5, 4, [3])  # row 3 is sea
	var palette := _palette()
	var owner := PackedByteArray()
	owner.resize(map.hex_count())
	for r: int in 3:
		for c: int in 5:
			var i := r * 5 + c
			if c <= 1:
				owner[i] = 1
			elif c <= 3:
				owner[i] = 2
			else:
				owner[i] = 0  # col 4 is unowned land

	var items := BorderLines.for_chunk(map, owner, Vector2i.ZERO, palette)
	var borders: Array[Dictionary] = []
	var bands: Array[Dictionary] = []
	for item: Dictionary in items:
		match str(item["kind"]):
			"border":
				borders.append(item)
			"border_band":
				bands.append(item)
			_:
				fail_test("unexpected border item kind: %s" % item["kind"])

	var expected_edges := _count_differing_land_edges(map, owner)
	assert_gt(expected_edges, 0)
	assert_eq(borders.size(), expected_edges, "one ink border per differing land edge, none on coast or equal owners")

	for b: Dictionary in borders:
		assert_eq((b["points"] as PackedVector2Array).size(), 2)
		assert_almost_eq(float(b["width"]), BorderLines.INK_WIDTH, 0.001)
		assert_eq(b["colour"], BorderLines.INK)

	# Between country 1 and 2: 2 bands per edge; between country 2 and unowned (col 3 vs 4): 1 band per edge.
	var expected_bands := 0
	for r: int in 3:
		for c: int in 5:
			var hex := Vector2i(c, r)
			var i := map.index_of(hex)
			for d: int in MapData.OWNED_EDGES:
				var j := map.index_of(map.neighbour(hex, d))
				if j >= 0 and map.land[j] == 1 and owner[i] != owner[j]:
					if owner[i] > 0:
						expected_bands += 1
					if owner[j] > 0:
						expected_bands += 1
	assert_eq(bands.size(), expected_bands, "two bands per country-country edge, one beside unowned land")

	for band: Dictionary in bands:
		var poly: PackedVector2Array = band["polygon"]
		var cols: PackedColorArray = band["colours"]
		assert_eq(poly.size(), 4)
		assert_eq(cols.size(), 4)
		assert_almost_eq(cols[0].a, BorderLines.BAND_ALPHA, 0.001)
		assert_almost_eq(cols[1].a, BorderLines.BAND_ALPHA, 0.001)
		assert_almost_eq(cols[2].a, 0.0, 0.001)
		assert_almost_eq(cols[3].a, 0.0, 0.001)
		assert_eq(Color(cols[0], 1.0), Color(cols[2], 1.0))


func test_band_polygons_lie_inside_their_owned_hex() -> void:
	var map := _make_map(4, 3)
	var palette := _palette()
	var owner := PackedByteArray()
	owner.resize(map.hex_count())
	owner[map.index_of(Vector2i(1, 1))] = 1
	owner[map.index_of(Vector2i(2, 1))] = 2

	var items := BorderLines.for_chunk(map, owner, Vector2i.ZERO, palette)
	var checked := 0
	for item: Dictionary in items:
		if str(item["kind"]) != "border_band":
			continue
		checked += 1
		var poly: PackedVector2Array = item["polygon"]
		var edge_col: Color = (item["colours"] as PackedColorArray)[0]
		var target_owner := 1 if is_equal_approx(edge_col.r, palette[1].r) else 2
		var inner_mid := (poly[2] + poly[3]) * 0.5
		var owner_hex := EdgeLines.hex_of_point(inner_mid)
		assert_eq(owner[map.index_of(owner_hex)], target_owner, "inner band sits inside the hex of its owner")
		var corners := BorderLines.hex_corners(owner_hex)
		assert_true(Geometry2D.is_point_in_polygon(poly[2], corners), "inner vertex 2 is inside its hex")
		assert_true(Geometry2D.is_point_in_polygon(poly[3], corners), "inner vertex 3 is inside its hex")
		assert_almost_eq(poly[0].distance_to(poly[3]), BorderLines.BAND_DEPTH, 0.01)
		assert_almost_eq(poly[1].distance_to(poly[2]), BorderLines.BAND_DEPTH, 0.01)
	assert_gt(checked, 0)


func test_every_edge_appears_once_across_chunk_seams() -> void:
	var map := _make_map(40, 40, [39])
	var palette := _palette()
	var owner := PackedByteArray()
	owner.resize(map.hex_count())
	for r: int in 39:
		for c: int in 40:
			var i := r * 40 + c
			if r <= 31:
				owner[i] = 1 if c <= 31 else 2
			else:
				owner[i] = 1 if (c + r) % 2 == 0 else 3

	var seen_edges: Dictionary[String, bool] = {}
	var total_borders := 0
	for cy: int in 2:
		for cx: int in 2:
			for item: Dictionary in BorderLines.for_chunk(map, owner, Vector2i(cx, cy), palette):
				if str(item["kind"]) != "border":
					continue
				total_borders += 1
				var pts: PackedVector2Array = item["points"]
				var key := _edge_key(pts[0], pts[1])
				assert_false(seen_edges.has(key), "edge %s must not be emitted twice across chunk seams" % key)
				seen_edges[key] = true

	assert_eq(total_borders, _count_differing_land_edges(map, owner))


func test_chunks_touched_includes_self_and_neighbour_chunks() -> void:
	var map := _make_map(70, 70)
	assert_eq(BorderLines.chunks_touched(map, [Vector2i(10, 10)]), [Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(BorderLines.chunks_touched(map, [Vector2i(0, 0)]), [Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(
		BorderLines.chunks_touched(map, [Vector2i(31, 10)]),
		[Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i]
	)
	assert_eq(
		BorderLines.chunks_touched(map, [Vector2i(32, 32)]),
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i]
	)
	assert_eq(BorderLines.chunks_touched(map, [Vector2i(-1, -1)]), [] as Array[Vector2i])
	assert_eq(
		BorderLines.chunks_touched(map, [Vector2i(10, 10), Vector2i(12, 12)]),
		[Vector2i(0, 0)] as Array[Vector2i]
	)
