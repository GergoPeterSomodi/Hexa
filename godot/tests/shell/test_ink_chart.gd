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
	assert_true(sum.contains("Genoa from "), "summary has a sentence a series")
	assert_true(sum.contains("lowest ") and sum.contains("highest "))


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


func test_summary_reads_as_the_spec_sentence() -> void:
	var chart := InkChart.new()
	chart.caption = "Treasury"
	chart.x_labels = PackedStringArray(["Spring 1480", "Summer 1480", "Autumn 1480", "Winter 1480"])
	chart.set_series([{"name": "Treasury", "values": PackedInt32Array([696, 900, 800, 1068]), "ink": 0}])
	assert_eq(chart.summary(), "Treasury, 4 points: from 696 (Spring 1480) to 1,068 (Winter 1480); lowest 696 (Spring 1480), highest 1,068 (Winter 1480).")
	chart.set_series([
		{"name": "In", "values": PackedInt32Array([5]), "ink": 0},
		{"name": "Out", "values": PackedInt32Array([-1200]), "ink": 1},
	])
	assert_true(chart.summary().contains("1 point:"))
	assert_true(chart.summary().contains("Out -1,200"))
	chart.free()


func test_accessibility_follows_caption_and_summary() -> void:
	var chart := InkChart.new()
	chart.caption = "Money in and out"
	chart.set_series([{"name": "In", "values": PackedInt32Array([1, 2]), "ink": 0}])
	assert_eq(chart.accessibility_name, "Money in and out")
	assert_eq(chart.accessibility_description, chart.summary())
	chart.free()


func test_set_cursor_clamps_draws_and_emits_nothing() -> void:
	var chart := InkChart.new()
	chart.size = Vector2(320.0, 160.0)
	chart.set_series([{"name": "A", "values": PackedInt32Array([1, 2, 3]), "ink": 0}])
	_root.add_child(chart)
	var heard: Array[int] = []
	chart.point_hovered.connect(func(i: int) -> void: heard.append(i))
	assert_eq(chart.cursor(), -1)
	chart.set_cursor(2)
	assert_eq(chart.cursor(), 2)
	chart.set_cursor(9)
	assert_eq(chart.cursor(), 2, "past the end clamps to the last point")
	chart.set_cursor(-5)
	assert_eq(chart.cursor(), -1)
	assert_eq(heard.size(), 0, "set_cursor is silent")
	await _harness.wait_frames(self, 2)
	var base := chart.redraw_count()
	chart.set_cursor(1)
	await _harness.wait_frames(self, 2)
	assert_gt(chart.redraw_count(), base, "a moved cursor redraws")
	var again := chart.redraw_count()
	chart.set_cursor(1)
	await _harness.wait_frames(self, 2)
	assert_eq(chart.redraw_count(), again, "the same cursor does not")


func test_pointer_leaving_emits_minus_one() -> void:
	var chart := InkChart.new()
	chart.size = Vector2(320.0, 160.0)
	chart.set_series([{"name": "A", "values": PackedInt32Array([1, 2, 3]), "ink": 0}])
	_root.add_child(chart)
	var heard: Array[int] = []
	chart.point_hovered.connect(func(i: int) -> void: heard.append(i))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(chart.size.x - 14.0, 40.0)
	chart._gui_input(motion)
	assert_eq(chart.cursor(), 2)
	chart.notification(Control.NOTIFICATION_MOUSE_EXIT)
	assert_eq(heard, [2, -1])
	assert_eq(chart.cursor(), -1, "a pointer cursor goes with the pointer")
	chart.set_cursor(1)
	chart._gui_input(motion)
	chart.notification(Control.NOTIFICATION_MOUSE_EXIT)
	assert_eq(chart.cursor(), -1)


func test_a_click_sets_the_cursor_and_activates() -> void:
	var chart := InkChart.new()
	chart.size = Vector2(320.0, 160.0)
	chart.set_series([{"name": "A", "values": PackedInt32Array([1, 2, 3]), "ink": 0}])
	_root.add_child(chart)
	var activated: Array[int] = []
	chart.point_activated.connect(func(i: int) -> void: activated.append(i))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(PAD_LEFT_TEST, 40.0)
	chart._gui_input(click)
	assert_eq(activated, [0])
	assert_eq(chart.cursor(), 0)


const PAD_LEFT_TEST := 41.0


func test_legend_takes_a_row_from_the_plot() -> void:
	var chart := InkChart.new()
	chart.size = Vector2(320.0, 160.0)
	chart.set_series([{"name": "A", "values": PackedInt32Array([1, 2, 3]), "ink": 0}])
	var plain := chart._plot_rect()
	chart.legend = true
	var with_legend := chart._plot_rect()
	assert_eq(with_legend.size.y, plain.size.y - InkChart.LEGEND_H)
	assert_eq(with_legend.position, plain.position)
	chart.kind = InkChart.Kind.SPARK
	chart.legend = false
	chart.free()


func test_stacked_bar_roles_net_and_hover_card() -> void:
	var chart := InkChart.new()
	chart.kind = InkChart.Kind.STACKED_BAR
	chart.caption = "Money in and out"
	chart.size = Vector2(320.0, 180.0)
	chart.legend = true
	chart.x_labels = PackedStringArray(["Spring", "Summer"])
	chart.set_series([
		{"name": "Taxes", "values": PackedInt32Array([30, 40]), "ink": 0, "role": "in"},
		{"name": "Trade", "values": PackedInt32Array([10, 5]), "ink": 1, "role": "in"},
		{"name": "Upkeep", "values": PackedInt32Array([20, 60]), "ink": 2, "role": "out"},
	])
	_root.add_child(chart)
	await _harness.wait_frames(self, 2)
	var bounds := chart._compute_bounds(2)
	assert_eq(bounds.x, -60.0, "an out series is stacked down from zero")
	assert_eq(bounds.y, 45.0)
	assert_eq(chart._stack_net(0), 20)
	assert_eq(chart._stack_net(1), -15)
	var card := chart._make_custom_tooltip("point:1") as HoverCard
	assert_eq(card.rows_container().get_child_count(), 4, "a line a series and Net")
	card.free()
	chart.set_cursor(1)
	await _harness.wait_frames(self, 2)
	assert_eq(chart._ring_points(chart._plot_rect(), 1, -60.0, 45.0, 2).size(), 1, "one ring on the stack's top")


func test_marks_draw_on_every_kind() -> void:
	var chart := InkChart.new()
	chart.size = Vector2(360.0, 180.0)
	chart.x_labels = PackedStringArray(["a", "b", "c", "d"])
	_root.add_child(chart)
	for k: InkChart.Kind in [InkChart.Kind.LINE, InkChart.Kind.LINE_BARS, InkChart.Kind.PAIRED_BARS, InkChart.Kind.STACKED_BAR, InkChart.Kind.SPARK]:
		chart.kind = k
		chart.set_series([
			{"name": "A", "values": PackedInt32Array([3, 5, 2, 8]), "ink": 0, "role": "line"},
			{"name": "B", "values": PackedInt32Array([1, 2, 3, 4]), "ink": 1, "role": "bar"},
		])
		chart.set_marks([
			{"index": 1, "text": "Harvest", "short": "Harv", "tone": &"good"},
			{"index": 3, "text": "Plague", "tone": &"bad"},
			{"index": 9, "text": "Off the end"},
		])
		var before := chart.redraw_count()
		await _harness.wait_frames(self, 2)
		assert_gt(chart.redraw_count(), before, "kind %d drew with marks" % k)


func test_each_fill_cue_is_told_apart_by_pattern_not_ink() -> void:
	var seen := {}
	var rect := Rect2(0, 0, 24, 16)
	for cue: int in 5:
		var hatch := InkMarks.hatch_segments(rect, cue)
		var slope := 0
		if hatch.size() >= 2:
			slope = signi(roundi(hatch[1].y - hatch[0].y))
		var key := "%d:%d:%d:%d" % [hatch.size(), InkMarks.dot_points(rect, cue).size(), slope, 1 if cue == 0 else 0]
		assert_false(seen.has(key), "cue %d has a pattern of its own" % cue)
		seen[key] = true


func test_swatch_ink_on_leather_is_the_series_ink_and_not_the_ground() -> void:
	var chart := InkChart.new()
	chart.ground = InkChart.Ground.SLOT
	_root.add_child(chart)
	for cue: int in 5:
		var key := StringName("ink_%d" % cue)
		var series_ink: Color = chart._chart_color(key)
		var swatch_ink := InkChart.colour_of(chart, key, InkChart.Ground.SLOT)
		assert_eq(swatch_ink, series_ink, "ink %d: legend and swatch use the series ink on leather" % cue)
		assert_ne(swatch_ink, Tokens.BG, "ink %d differs from the ground" % cue)
	assert_ne(InkChart.colour_of(chart, &"ink_0", InkChart.Ground.SLOT), InkChart.colour_of(chart, &"ink_0", InkChart.Ground.VELLUM))


func test_a_key_cursor_survives_the_pointer_leaving() -> void:
	var chart := InkChart.new()
	chart.size = Vector2(320.0, 160.0)
	chart.set_series([{"name": "A", "values": PackedInt32Array([1, 2, 3, 4, 5]), "ink": 0}])
	_root.add_child(chart)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(60.0, 40.0)
	chart._gui_input(motion)
	chart._handle_key(KEY_END, 5)
	assert_eq(chart.cursor(), 4)
	chart.notification(Control.NOTIFICATION_MOUSE_EXIT)
	assert_eq(chart.cursor(), 4, "the keyboard cursor stays")


func test_a_key_that_moves_nothing_does_not_redraw() -> void:
	var chart := InkChart.new()
	chart.size = Vector2(320.0, 160.0)
	chart.set_series([{"name": "A", "values": PackedInt32Array([1, 2, 3]), "ink": 0}])
	_root.add_child(chart)
	var heard: Array[int] = []
	chart.point_hovered.connect(func(i: int) -> void: heard.append(i))
	chart._handle_key(KEY_END, 3)
	await _harness.wait_frames(self, 2)
	var base := chart.redraw_count()
	chart._handle_key(KEY_END, 3)
	chart._handle_key(KEY_RIGHT, 3)
	await _harness.wait_frames(self, 2)
	assert_eq(chart.redraw_count(), base, "End at the end and Right at the end change nothing")
	assert_eq(heard, [2], "and say nothing")


func test_a_legend_that_cannot_hold_every_series_says_how_many_are_left_out() -> void:
	var chart := InkChart.new()
	chart.size = Vector2(240.0, 160.0)
	chart.legend = true
	chart.caption = "Wealth"
	_root.add_child(chart)
	var many: Array = []
	for i: int in 6:
		many.append({"name": "Country number %d" % i, "values": PackedInt32Array([1, 2]), "ink": i})
	chart.set_series(many)
	var font := chart._chart_font()
	var fit := chart._legend_fit(font, chart._chart_font_size())
	assert_gte(fit, 1)
	assert_lt(fit, 6, "six long names do not fit 240 px")
	assert_true(chart.summary().contains("The legend shows %d series; %d more not shown." % [fit, 6 - fit]))
	chart.size = Vector2(1600.0, 160.0)
	assert_eq(chart._legend_fit(font, chart._chart_font_size()), 6, "wide enough shows them all")
	assert_false(chart.summary().contains("more not shown"))
	await _harness.wait_frames(self, 2)
