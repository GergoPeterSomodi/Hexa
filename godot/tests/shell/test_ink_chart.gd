## GUT tests for InkChart: 0, 1, and 40 points across all 5 chart kinds, VELLUM/SLOT grounds,
## zero idle redraws, summary(), keyboard cursor, and HoverCard tooltips
## (docs/architecture/ui-style-and-feedback-spec.md sections 5 and 11).
extends GutTest

var _harness: UIHarness = null
var _root: Control = null


func before_each() -> void:
	_harness = UIHarness.new()
	_harness.mount(self)
	_root = Control.new()
	_root.theme = KitTheme.load_for(1.0)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_harness.viewport.add_child(_root)


func after_each() -> void:
	_root = null
	_harness = null


func _make_40_values(offset: int) -> PackedInt32Array:
	var arr := PackedInt32Array()
	for i: int in 40:
		arr.append(offset + ((i * 17) % 53) - 20)
	return arr


func test_zero_points_shows_no_data_yet_and_summary() -> void:
	var chart := InkChart.new()
	chart.caption = "Treasury"
	chart.size = Vector2(360.0, 180.0)
	_root.add_child(chart)

	assert_eq(chart.summary(), "Treasury: No data yet")
	assert_eq(chart.cursor_index(), -1)
	assert_eq(chart._get_tooltip(Vector2(50.0, 50.0)), "")
	assert_null(chart._make_custom_tooltip(""))

	await _harness.wait_frames(self, 2)
	assert_gt(chart.redraw_count(), 0, "empty chart draws once")


func test_one_and_forty_points_across_all_kinds_and_grounds() -> void:
	var chart := InkChart.new()
	chart.size = Vector2(420.0, 200.0)
	_root.add_child(chart)

	var kinds: Array[InkChart.Kind] = [
		InkChart.Kind.LINE,
		InkChart.Kind.LINE_BARS,
		InkChart.Kind.PAIRED_BARS,
		InkChart.Kind.STACKED_BAR,
		InkChart.Kind.SPARK,
	]

	for g: InkChart.Ground in [InkChart.Ground.VELLUM, InkChart.Ground.SLOT]:
		chart.ground = g
		for k: InkChart.Kind in kinds:
			chart.kind = k
			chart.x_labels = PackedStringArray(["Sp 80"])
			chart.set_series([
				{"name": "Genoa", "values": PackedInt32Array([42]), "ink": 0, "role": "line"},
				{"name": "Change", "values": PackedInt32Array([-5]), "ink": 1, "role": "bar"},
			])
			await _harness.wait_frames(self, 1)

			var labels_40 := PackedStringArray()
			for i: int in 40:
				labels_40.append("S%d" % (i + 1))
			chart.x_labels = labels_40
			chart.set_series([
				{"name": "Genoa", "values": _make_40_values(100), "ink": 0, "role": "line"},
				{"name": "Delta", "values": _make_40_values(0), "ink": 2, "role": "bar"},
				{"name": "Milan", "values": _make_40_values(80), "ink": 1},
			])
			chart.set_marks([{"index": 12, "text": "Winter 1480", "tone": &"bad"}])
			await _harness.wait_frames(self, 1)

	assert_gt(chart.redraw_count(), 10)
	var sum := chart.summary()
	assert_true(sum.contains("40 points"), "summary includes point count")
	assert_true(sum.contains("Genoa: min "), "summary includes series stats")


func test_redraws_only_on_setters_resize_and_theme_change() -> void:
	var chart := InkChart.new()
	chart.size = Vector2(360.0, 180.0)
	chart.set_series([{"name": "Income", "values": PackedInt32Array([10, 20, 15, 30]), "ink": 0}])
	_root.add_child(chart)

	await _harness.wait_frames(self, 2)
	var baseline := chart.redraw_count()
	assert_gt(baseline, 0)

	# Idle frames must not trigger redraws
	await _harness.wait_frames(self, 5)
	assert_eq(chart.redraw_count(), baseline, "idle frames do not redraw InkChart")

	# Setter triggers redraw
	chart.set_series([{"name": "Income", "values": PackedInt32Array([12, 24, 18, 36]), "ink": 0}])
	await _harness.wait_frames(self, 2)
	var after_setter := chart.redraw_count()
	assert_gt(after_setter, baseline, "set_series triggers redraw")

	await _harness.wait_frames(self, 4)
	assert_eq(chart.redraw_count(), after_setter, "idle frames after setter stay constant")

	# Resize triggers redraw
	chart.size = Vector2(440.0, 220.0)
	await _harness.wait_frames(self, 2)
	var after_resize := chart.redraw_count()
	assert_gt(after_resize, after_setter, "resize triggers redraw")

	# Theme change triggers redraw
	chart.theme = KitTheme.load_for(1.0, &"plain")
	await _harness.wait_frames(self, 2)
	assert_gt(chart.redraw_count(), after_resize, "theme change triggers redraw")


func test_keyboard_cursor_activation_and_hover_card_tooltip() -> void:
	var chart := InkChart.new()
	chart.caption = "Treasury"
	chart.size = Vector2(320.0, 160.0)
	chart.x_labels = PackedStringArray(["Sp 80", "Su 80", "Au 80", "Wi 80"])
	chart.set_series([
		{"name": "Treasury", "values": PackedInt32Array([100, 120, 110, 145]), "ink": 0},
	])
	chart.set_marks([{"index": 2, "text": "Harvest", "tone": &"good"}])
	_root.add_child(chart)

	var hovered: Array[int] = []
	var activated: Array[int] = []
	chart.point_hovered.connect(func(i: int) -> void: hovered.append(i))
	chart.point_activated.connect(func(i: int) -> void: activated.append(i))

	await _harness.wait_frames(self, 2)
	chart.grab_focus()
	assert_true(chart.has_focus())

	_harness.send_key(KEY_RIGHT)
	await _harness.wait_frames(self, 1)
	assert_eq(chart.cursor_index(), 0)
	_harness.send_key(KEY_RIGHT)
	_harness.send_key(KEY_RIGHT)
	await _harness.wait_frames(self, 1)
	assert_eq(chart.cursor_index(), 2)
	_harness.send_key(KEY_LEFT)
	await _harness.wait_frames(self, 1)
	assert_eq(chart.cursor_index(), 1)
	_harness.send_key(KEY_END)
	await _harness.wait_frames(self, 1)
	assert_eq(chart.cursor_index(), 3)
	_harness.send_key(KEY_HOME)
	await _harness.wait_frames(self, 1)
	assert_eq(chart.cursor_index(), 0)

	_harness.send_key(KEY_RIGHT)
	_harness.send_key(KEY_RIGHT)
	_harness.send_key(KEY_ENTER)
	await _harness.wait_frames(self, 1)
	assert_eq(activated, [2], "Enter emits point_activated for cursor index")
	assert_gt(hovered.size(), 0)

	var tip := chart._make_custom_tooltip("point:2")
	assert_true(tip is HoverCard, "_make_custom_tooltip returns a HoverCard")
	var card := tip as HoverCard
	assert_eq((card.get_node("VBox/Title") as Label).text, "Au 80")
	assert_eq(card.rows_container().get_child_count(), 2, "tooltip includes series row and mark row")
	card.free()


func test_paired_bars_draw_the_before_series_hollow_and_the_after_solid() -> void:
	var chart := InkChart.new()
	chart.kind = InkChart.Kind.PAIRED_BARS
	chart.set_series([
		{"name": "Before", "values": PackedInt32Array([1, 2]), "ink": 0},
		{"name": "After", "values": PackedInt32Array([2, 3]), "ink": 3},
	])
	assert_true(chart.is_hollow(0), "the before series (ink 0) is hollow")
	assert_false(chart.is_hollow(1), "the after series (ink 3) is solid")
	chart.kind = InkChart.Kind.LINE_BARS
	assert_false(chart.is_hollow(0), "only paired bars are hollow")
	chart.free()
