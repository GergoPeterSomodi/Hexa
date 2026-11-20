## GUT tests for InkMarks: the cues, the five fills' geometry, dash lengths, spark points, bar length, and (where the
## renderer can read pixels back) a 96 x 32 picture of each helper
## (m4-5-build-spec.md 6.2 and section 8).
extends GutTest

const BOX := Rect2(0.0, 0.0, 40.0, 24.0)


class Sheet:
	extends Control
	var paint: Callable

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)


func test_cues_follow_the_chart_cues_by_ink() -> void:
	assert_eq(InkMarks.FILLS.size(), 5)
	assert_eq(InkMarks.dash_kind(0), "solid")
	assert_eq(InkMarks.dash_kind(1), "dash")
	assert_eq(InkMarks.dash_kind(4), "long_dash")
	assert_eq(InkMarks.marker_kind(2), "triangle")
	assert_eq(InkMarks.fill_kind(0), &"solid")
	assert_eq(InkMarks.fill_kind(3), &"back_hatch")
	assert_eq(InkMarks.fill_kind(4), &"cross_hatch")
	assert_eq(InkMarks.fill_kind(7), &"dots", "a cue wraps into the five")
	assert_eq(InkMarks.cue_of(-1), 4)


func test_dash_lengths_differ_per_cue() -> void:
	var lens := {}
	for cue: int in 5:
		lens[InkMarks.dash_length(InkMarks.dash_kind(cue))] = true
	assert_eq(InkMarks.dash_length("solid"), 0.0)
	assert_gte(lens.size(), 4, "dash, dotted and long dash have their own periods (dash_dot shares the 8 px unit)")
	assert_eq(InkMarks.dash_length("dotted"), 2.0)
	assert_eq(InkMarks.dash_length("long_dash"), 11.0)


func test_fills_each_have_their_own_pattern() -> void:
	assert_eq(InkMarks.hatch_segments(BOX, 0).size(), 0, "solid has no pattern lines")
	assert_eq(InkMarks.dot_points(BOX, 0).size(), 0)
	var fwd := InkMarks.hatch_segments(BOX, 1)
	var back := InkMarks.hatch_segments(BOX, 3)
	var cross := InkMarks.hatch_segments(BOX, 4)
	assert_gt(fwd.size(), 0)
	assert_gt(back.size(), 0)
	assert_eq(cross.size(), fwd.size() + back.size(), "cross hatch is both directions")
	assert_gt(InkMarks.dot_points(BOX, 2).size(), 0)
	assert_eq(InkMarks.hatch_segments(BOX, 2).size(), 0, "dots has no lines")
	assert_eq(InkMarks.dot_points(BOX, 1).size(), 0, "hatch has no dots")
	# slope: "/" rises to the right (end y above start y), "\" falls
	for i: int in range(0, fwd.size() - 1, 2):
		assert_true(fwd[i + 1].x >= fwd[i].x and fwd[i + 1].y <= fwd[i].y, "hatch runs /")
	for i: int in range(0, back.size() - 1, 2):
		assert_true(back[i + 1].x >= back[i].x and back[i + 1].y >= back[i].y, "back hatch runs \\")


func test_pattern_stays_inside_the_rect() -> void:
	var rect := Rect2(10.0, 6.0, 13.0, 9.0)
	for cue: int in 5:
		for p: Vector2 in InkMarks.hatch_segments(rect, cue):
			assert_true(rect.grow(0.001).has_point(p), "hatch point %s inside" % p)
		for p: Vector2 in InkMarks.dot_points(rect, cue):
			assert_true(rect.has_point(p), "dot %s inside" % p)
	assert_eq(InkMarks.hatch_segments(Rect2(0, 0, 0, 5), 1).size(), 0, "an empty rect gives nothing")


func test_spark_points_scale_to_the_rect() -> void:
	var rect := Rect2(4.0, 4.0, 80.0, 20.0)
	var pts := InkMarks.spark_points(rect, PackedInt32Array([0, 10, 5]))
	assert_eq(pts.size(), 3)
	assert_eq(pts[0], Vector2(4.0, 24.0), "the lowest value sits on the bottom")
	assert_eq(pts[1], Vector2(44.0, 4.0), "the highest on the top")
	assert_eq(pts[2], Vector2(84.0, 14.0))
	assert_eq(InkMarks.spark_points(rect, PackedInt32Array()).size(), 0)
	var one := InkMarks.spark_points(rect, PackedInt32Array([7]))
	assert_eq(one[0], Vector2(44.0, 14.0), "a single value sits at the centre")
	var flat := InkMarks.spark_points(rect, PackedInt32Array([3, 3]))
	assert_eq(flat[0].y, 14.0)


func test_bar_length_is_a_clamped_permille_of_the_width() -> void:
	var rect := Rect2(0.0, 0.0, 50.0, 6.0)
	assert_eq(InkMarks.bar_length(rect, 0), 0.0)
	assert_eq(InkMarks.bar_length(rect, 500), 25.0)
	assert_eq(InkMarks.bar_length(rect, 1000), 50.0)
	assert_eq(InkMarks.bar_length(rect, 1500), 50.0)
	assert_eq(InkMarks.bar_length(rect, -20), 0.0)


func test_every_helper_draws_without_error() -> void:
	var sheet := Sheet.new()
	sheet.size = Vector2(96.0, 32.0)
	sheet.paint = func(c: CanvasItem) -> void:
		var col := Tokens.VELLUM_INK
		var none := Tokens.VELLUM_INK
		none.a = 0.0
		for cue: int in 5:
			var x := float(cue) * 18.0
			InkMarks.fill_rect(c, Rect2(x, 0.0, 16.0, 10.0), col, cue, col)
			InkMarks.fill_rect(c, Rect2(x, 12.0, 16.0, 6.0), col, cue, none)
			InkMarks.marker(c, Vector2(x + 8.0, 24.0), col, cue)
			InkMarks.swatch(c, Rect2(x, 26.0, 16.0, 6.0), col, cue, cue % 2 == 0)
		InkMarks.line(c, PackedVector2Array([Vector2(0, 5), Vector2(90, 5)]), col, 3, 2.0)
		InkMarks.line(c, PackedVector2Array([Vector2(0, 5)]), col, 3)
		InkMarks.spark(c, Rect2(0, 0, 40, 10), PackedInt32Array([1, 3, 2]), col)
		InkMarks.spark(c, Rect2(0, 0, 40, 10), PackedInt32Array(), col)
		InkMarks.bar(c, Rect2(0, 0, 40, 4), 300, col, none)
		InkMarks.mark_triangle(c, Vector2(5, 5), col, true)
		InkMarks.mark_triangle(c, Vector2(5, 5), col, false)
	var vp := SubViewport.new()
	vp.size = Vector2i(96, 32)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autoqfree(vp)
	vp.add_child(sheet)
	await wait_process_frames(2)
	assert_true(sheet.is_inside_tree())


func test_pixels_of_a_solid_fill_and_a_hatch_when_the_renderer_can_read_them() -> void:
	var col := Tokens.VELLUM_INK
	var sheet := Sheet.new()
	sheet.size = Vector2(96.0, 32.0)
	sheet.paint = func(c: CanvasItem) -> void:
		InkMarks.fill_rect(c, Rect2(0, 0, 20, 20), col, 0, col)
		InkMarks.fill_rect(c, Rect2(30, 0, 20, 20), col, 1, col)
		InkMarks.bar(c, Rect2(0, 24, 40, 6), 500, col, Tokens.VELLUM_MUTED)
	var vp := SubViewport.new()
	vp.size = Vector2i(96, 32)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autoqfree(vp)
	vp.add_child(sheet)
	await wait_process_frames(3)
	if DisplayServer.get_name() == "headless":
		pending("the headless renderer cannot read pixels back; the contact sheet tool covers this windowed")
		return
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		pending("the headless renderer cannot read pixels back; the contact sheet tool covers this windowed")
		return
	assert_eq(img.get_pixel(10, 10).a, 1.0, "a solid fill is opaque ink")
	var inked := 0
	for x: int in range(31, 49):
		for y: int in range(1, 19):
			if img.get_pixel(x, y).a > 0.6:
				inked += 1
	assert_gt(inked, 10, "a hatch has ink lines")
	assert_lt(inked, 18 * 18, "and gaps between them")
	assert_gt(img.get_pixel(10, 27).a, 0.9, "the bar's filled half")


func test_grouped_and_legend_fit() -> void:
	assert_eq(InkMarks.grouped(1068), "1,068")
	assert_eq(InkMarks.grouped(-1200), "-1,200")
	assert_eq(InkMarks.grouped(7), "7")
	var w := PackedFloat32Array([40.0, 40.0, 40.0, 40.0])
	assert_eq(InkMarks.legend_fit(w, 0.0, 1000.0, 20.0, 12.0, 30.0), 4, "all fit")
	var some := InkMarks.legend_fit(w, 0.0, 150.0, 20.0, 12.0, 30.0)
	assert_gte(some, 1)
	assert_lt(some, 4)
	assert_eq(InkMarks.legend_fit(w, 0.0, 10.0, 20.0, 12.0, 30.0), 1, "at least one")
	assert_eq(InkMarks.legend_fit(PackedFloat32Array(), 0.0, 10.0, 20.0, 12.0, 30.0), 0)
