## The smooth route line (issue 434): PathCurve passes through every hex centre, bends without kinks and keeps its nodes; PathLooks
## and PathMarks keep the look setting and the route's start on the army's own hex.
extends GutTest

## A route that turns sharply at every hex (a zig-zag over hex centres, 60 degrees a corner).
const ZIGZAG := [Vector2(0, 0), Vector2(100, 0), Vector2(150, 87), Vector2(100, 173), Vector2(200, 173), Vector2(250, 260)]


func _points(list: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in list:
		out.append(p)
	return out


func test_the_curve_passes_through_every_centre() -> void:
	var pts := _points(ZIGZAG)
	var curve := PathCurve.build(pts)
	var s := curve["samples"] as PackedVector2Array
	var nodes := curve["nodes"] as PackedInt32Array
	assert_eq(nodes.size(), pts.size(), "one node a point")
	for i: int in pts.size():
		assert_eq(s[nodes[i]], pts[i], "node %d is the centre" % i)
	assert_eq(s.size(), (pts.size() - 1) * PathCurve.STEPS + 1, "STEPS samples a leg and the last point")


func test_the_curve_has_no_kinks() -> void:
	var curve := PathCurve.build(_points(ZIGZAG))
	var s := curve["samples"] as PackedVector2Array
	var worst := 0.0
	for k: int in range(1, s.size() - 1):
		var a := (s[k] - s[k - 1]).normalized()
		var b := (s[k + 1] - s[k]).normalized()
		worst = maxf(worst, rad_to_deg(absf(a.angle_to(b))))
	# A 60 degree corner in the straight route is spread over the samples of two legs: no single step turns sharply.
	assert_lt(worst, 35.0, "the largest turn between two samples is %.1f degrees (the corners themselves are 60)" % worst)


func test_a_leg_is_the_samples_between_its_nodes() -> void:
	var curve := PathCurve.build(_points(ZIGZAG))
	var leg := curve["leg"] as PackedInt32Array
	var nodes := curve["nodes"] as PackedInt32Array
	for k: int in leg.size():
		var expected := mini(int(float(k) / PathCurve.STEPS), ZIGZAG.size() - 2)
		assert_eq(leg[k], expected, "sample %d lies on leg %d" % [k, expected])
	assert_eq(nodes[1], PathCurve.STEPS, "the second point is the tenth sample")


func test_two_points_make_a_straight_line() -> void:
	var curve := PathCurve.build(_points([Vector2(0, 0), Vector2(120, 40)]))
	var s := curve["samples"] as PackedVector2Array
	for k: int in s.size():
		var u := float(k) / (s.size() - 1)
		assert_true(s[k].distance_to(Vector2(0, 0).lerp(Vector2(120, 40), u)) < 0.01, "sample %d is on the straight line" % k)


func test_fewer_than_two_points_make_no_curve() -> void:
	assert_true((PathCurve.build(_points([Vector2(3, 3)]))["samples"] as PackedVector2Array).is_empty())
	assert_true((PathCurve.build(PackedVector2Array())["samples"] as PackedVector2Array).is_empty())


func test_a_repeated_point_does_not_break_the_curve() -> void:
	var curve := PathCurve.build(_points([Vector2(0, 0), Vector2(0, 0), Vector2(100, 0)]))
	for p: Vector2 in curve["samples"] as PackedVector2Array:
		assert_false(is_nan(p.x) or is_nan(p.y), "no NaN")


func test_resample_spaces_points_evenly_and_keeps_the_ends() -> void:
	var curve := PathCurve.build(_points(ZIGZAG))
	var fine := PathCurve.resample(curve["samples"] as PackedVector2Array, curve["leg"] as PackedInt32Array, 10.0)
	var pts := fine["points"] as PackedVector2Array
	assert_eq(pts[0], (curve["samples"] as PackedVector2Array)[0], "starts on the first centre")
	assert_eq(pts[pts.size() - 1], ZIGZAG[ZIGZAG.size() - 1], "ends on the last centre")
	# Steps are measured along the sampled chords, so a step that straddles a sample corner is a little shorter than the spacing.
	for k: int in range(1, pts.size() - 2):
		var step := pts[k].distance_to(pts[k + 1])
		assert_between(step, 8.5, 10.05, "step %d is about the spacing (%.2f)" % [k, step])


func test_the_look_setting_takes_the_three_looks_and_ignores_others() -> void:
	var marks := PathMarks.new()
	add_child_autofree(marks)
	assert_eq(marks.look(), PathMarks.LOOK_RIBBON, "the ribbon by default")
	marks.set_look(&"dashed")
	assert_eq(marks.look(), PathMarks.LOOK_DASHES)
	marks.set_look(&"footprints")
	assert_eq(marks.look(), PathMarks.LOOK_FOOTPRINTS)
	marks.set_look(&"zigzag")
	assert_eq(marks.look(), PathMarks.LOOK_FOOTPRINTS, "an unknown look is ignored")
	assert_eq(PathMarks.LOOKS.size(), 3, "three looks to compare")
