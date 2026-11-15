## The map's lines (core/views/edge_lines.gd) and their drawer (shell/mapview/edge_line_layer.gd): smoothing, the
## chunk cut (docs/architecture/m1-build-spec.md section 6), and that the pieces of a cut line draw without a gap.
## The drawing is checked without a window: the layer's triangles are rasterised here into a mask of pixels.
extends GutTest

const WINDOW := 48  # px a side of the patch round each cut that is compared


func test_smooth_and_resample_keep_the_ends() -> void:
	var line := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)])
	var soft := EdgeLines.smooth(line, 3)
	assert_eq(soft[0], line[0])
	assert_eq(soft[soft.size() - 1], line[2])
	assert_gt(soft.size(), 10)
	var even := EdgeLines.resample(soft, 5.0)
	assert_eq(even[0], line[0])
	assert_almost_eq(even[even.size() - 1].distance_to(line[2]), 0.0, 5.0)
	for i: int in even.size() - 2:
		assert_almost_eq(even[i].distance_to(even[i + 1]), 5.0, 0.5)


func test_river_is_the_same_every_time_and_keeps_its_ends() -> void:
	var edge := PackedVector2Array([Vector2(0, 0), Vector2(52, 25), Vector2(52, 76), Vector2(104, 102), Vector2(156, 76)])
	var a := EdgeLines.river(edge, 3, 1.0)
	var b := EdgeLines.river(edge, 3, 1.0)
	assert_eq(a["points"], b["points"])
	var pts: PackedVector2Array = a["points"]
	assert_eq(pts[0], edge[0])
	assert_eq(float(a["width"]), 6.5)
	assert_eq(str(a["kind"]), "river")


func test_roads_join_steps_into_runs() -> void:
	var steps: Array[Array] = [
		[Vector2i(0, 0), Vector2i(1, 0), 3], [Vector2i(1, 0), Vector2i(2, 0), 3], [Vector2i(2, 0), Vector2i(3, 0), 3],
		[Vector2i(2, 0), Vector2i(2, 1), 1],
	]
	var lines := EdgeLines.roads(steps, MapTiles.cell_centre)
	var kinds: Array[String] = []
	for line: Dictionary in lines:
		kinds.append(str(line["kind"]))
	kinds.sort()
	# The junction at (2, 0) ends the runs: (0,0)-(1,0)-(2,0), (2,0)-(3,0) and the track.
	assert_eq(kinds, ["road", "road", "track"] as Array[String])
	for line: Dictionary in lines:
		var pts: PackedVector2Array = line["points"]
		assert_gt(pts.size(), 2)


func test_chunk_of_and_hex_of_point() -> void:
	assert_eq(EdgeLines.chunk_of(Vector2i(0, 0)), Vector2i(0, 0))
	assert_eq(EdgeLines.chunk_of(Vector2i(31, 31)), Vector2i(0, 0))
	assert_eq(EdgeLines.chunk_of(Vector2i(32, 31)), Vector2i(1, 0))
	assert_eq(EdgeLines.chunk_of(Vector2i(-1, 40)), Vector2i(-1, 1))
	for hex: Vector2i in [Vector2i(0, 0), Vector2i(7, 3), Vector2i(31, 32), Vector2i(40, 41)]:
		var middle := MapTiles.cell_centre(hex)
		assert_eq(EdgeLines.hex_of_point(middle), hex)
		assert_eq(EdgeLines.hex_of_point(middle + Vector2(20, 10)), hex)


## A smooth line that visits all four chunks round the corner where they meet.
func _fixture() -> Array[Dictionary]:
	var edge := PackedVector2Array([Vector2(3240, 2340), Vector2(3420, 2400), Vector2(3430, 2580), Vector2(3240, 2590)])
	var road: Array[Dictionary] = [EdgeLines.river(edge, 3, 0.5)]
	var shifted := PackedVector2Array()
	for p: Vector2 in road[0]["points"]:
		shifted.append(p + Vector2(-70, 20))
	var track := {"kind": "track", "points": shifted, "width": 1.3, "rank": 1}
	var out: Array[Dictionary] = [road[0], track]
	return out


func test_a_line_in_one_chunk_is_not_cut() -> void:
	var points := PackedVector2Array([Vector2(300, 300), Vector2(340, 330), Vector2(400, 330)])
	var pieces := EdgeLines.cut([{"kind": "road", "points": points, "width": 2.5, "rank": 2}] as Array[Dictionary])
	assert_eq(pieces.size(), 1)
	var piece: Dictionary = pieces[Vector2i(0, 0)][0]
	assert_eq(piece["points"], points)
	assert_false(piece.has("before"))
	assert_false(piece.has("after"))


func test_cut_pieces_share_their_end_points_and_lose_none() -> void:
	var line := _fixture()[0]
	var whole: PackedVector2Array = line["points"]
	var pieces := EdgeLines.cut([line] as Array[Dictionary])
	assert_eq(pieces.size(), 4, "the fixture visits the four chunks")
	var count := 0
	var shared := 0
	for chunk: Vector2i in pieces:
		for piece: Dictionary in pieces[chunk]:
			var pts: PackedVector2Array = piece["points"]
			assert_gte(pts.size(), 2)
			count += pts.size()
			assert_eq(EdgeLines.chunk_of_point(pts[0]), chunk, "a piece belongs to the chunk it starts in")
			if piece.has("before"):
				shared += 1
	# Every cut repeats one point.
	assert_eq(count, whole.size() + shared)


## The triangles of one layer as pixels of a window: a mask (1 where a triangle covers the middle of the pixel).
func _paint(mask: PackedByteArray, layer: EdgeLineLayer, origin: Vector2i) -> void:
	var v := layer.vertices()
	var idx := layer.indices()
	for t: int in int(idx.size() / 3.0):
		var a := v[idx[3 * t]] - Vector2(origin)
		var b := v[idx[3 * t + 1]] - Vector2(origin)
		var c := v[idx[3 * t + 2]] - Vector2(origin)
		var x0 := maxi(0, floori(minf(a.x, minf(b.x, c.x))))
		var x1 := mini(WINDOW - 1, ceili(maxf(a.x, maxf(b.x, c.x))))
		var y0 := maxi(0, floori(minf(a.y, minf(b.y, c.y))))
		var y1 := mini(WINDOW - 1, ceili(maxf(a.y, maxf(b.y, c.y))))
		for y: int in range(y0, y1 + 1):
			for x: int in range(x0, x1 + 1):
				if _inside(Vector2(x + 0.5, y + 0.5), a, b, c):
					mask[y * WINDOW + x] = 1


func _inside(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (p - b).cross(a - b)
	var d2 := (p - c).cross(b - c)
	var d3 := (p - a).cross(c - a)
	var negative := d1 < -0.0001 or d2 < -0.0001 or d3 < -0.0001
	var positive := d1 > 0.0001 or d2 > 0.0001 or d3 > 0.0001
	return not (negative and positive)


func _layer_of(lines: Array[Dictionary]) -> EdgeLineLayer:
	var layer := EdgeLineLayer.new()
	layer.set_lines(lines)
	return layer


## The pixels that a line's chunk layers cover in a window, and the same for the line drawn whole.
func _masks(origin: Vector2i, strip_leads: bool) -> Array[PackedByteArray]:
	var lines := _fixture()
	var whole := PackedByteArray()
	whole.resize(WINDOW * WINDOW)
	var layer := _layer_of(lines)
	_paint(whole, layer, origin)
	layer.free()
	var cut := PackedByteArray()
	cut.resize(WINDOW * WINDOW)
	var pieces := EdgeLines.cut(lines)
	for chunk: Vector2i in pieces:
		var list: Array[Dictionary] = []
		list.assign(pieces[chunk])
		if strip_leads:
			for piece: Dictionary in list:
				piece.erase("before")
				piece.erase("after")
		var node := _layer_of(list)
		assert_eq(node.surface_count(), 1, "one mesh a chunk")
		_paint(cut, node, origin)
		node.free()
	return [whole, cut]


func _joints() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var pieces := EdgeLines.cut([_fixture()[0]] as Array[Dictionary])
	for chunk: Vector2i in pieces:
		for piece: Dictionary in pieces[chunk]:
			if piece.has("before"):
				var at: Vector2 = piece["points"][0]
				out.append(Vector2i(at) - Vector2i(24, 24))
	return out


func _count_missing(joints: Array[Vector2i], strip_leads: bool) -> int:
	var missing := 0
	for origin: Vector2i in joints:
		var masks := _masks(origin, strip_leads)
		for i: int in WINDOW * WINDOW:
			if masks[0][i] == 1 and masks[1][i] == 0:
				missing += 1
	return missing


func test_a_cut_line_draws_without_a_gap() -> void:
	var joints := _joints()
	assert_eq(joints.size(), 3, "the fixture is cut three times")
	assert_eq(_count_missing(joints, false), 0, "every pixel of the whole line is drawn by some chunk")
	# The same cut without the neighbours' points leaves wedges at the bends: the check can fail.
	assert_gt(_count_missing(joints, true), 0, "the check sees a gap")


func test_cut_pieces_cover_no_more_than_the_whole() -> void:
	for origin: Vector2i in _joints():
		var masks := _masks(origin, false)
		var extra := 0
		for i: int in WINDOW * WINDOW:
			if masks[0][i] == 0 and masks[1][i] == 1:
				extra += 1
		assert_eq(extra, 0)


func test_each_chunk_is_one_mesh() -> void:
	var pieces := EdgeLines.cut(_fixture())
	for chunk: Vector2i in pieces:
		var list: Array[Dictionary] = []
		list.assign(pieces[chunk])
		var node := _layer_of(list)
		assert_eq(node.surface_count(), 1)
		assert_gt(node.indices().size(), 0)
		node.free()
	var empty := _layer_of([] as Array[Dictionary])
	assert_eq(empty.surface_count(), 0)
	empty.free()
