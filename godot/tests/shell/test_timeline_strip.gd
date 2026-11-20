## GUT tests for TimelineStrip: a tick a season, year labels at 12, 40 and 680 seasons, marks merged when narrow, keys,
## signals, summary, the hover card and the redraw rules (docs/architecture/m4-5-build-spec.md sections 4.7, 6.2 and 9).
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


func _timeline(seasons: int, marks: Array = [], counts: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var counts_out := counts
	if counts_out.is_empty():
		counts_out = PackedInt32Array()
		for i: int in seasons:
			counts_out.append(0)
	return {"first_turn": 1, "last_turn": seasons, "start_year": 1480, "counts": counts_out, "marks": marks}


func _mark(turn: int, kind: String, tone: String = "plain") -> Dictionary:
	return {"turn": turn, "kind": kind, "tone": tone, "icon": "study", "text": kind, "hex": Vector2i(-1, -1), "more": 0}


func _strip(width: float, height: float = 96.0) -> TimelineStrip:
	var strip := TimelineStrip.new()
	strip.size = Vector2(width, height)
	_root.add_child(strip)
	return strip


func _key(keycode: Key, shift: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	ev.shift_pressed = shift
	return ev


func test_empty_timeline_is_quiet() -> void:
	var strip := _strip(600.0)
	strip.set_timeline({})
	assert_eq(strip.summary(), "No seasons yet")
	assert_eq(strip.accessibility_description, "No seasons yet")
	assert_eq(strip.cursor(), -1)
	assert_eq(strip.label_turns().size(), 0)
	assert_eq(strip._get_tooltip(Vector2(100.0, 40.0)), "")
	assert_null(strip._make_custom_tooltip(""))


func test_ticks_and_season_geometry() -> void:
	var strip := _strip(1280.0)
	var counts := PackedInt32Array([0, 1, 2, 3, 9, 4, 4, 4, 0, 0, 0, 0])
	strip.set_timeline(_timeline(12, [], counts))
	assert_eq(strip.tick_height(1), 4.0, "no witnessed line: the base 4 px")
	assert_eq(strip.tick_height(2), 7.0, "one line: 4 + 3")
	assert_eq(strip.tick_height(5), 28.0, "nine lines count as eight")
	var step := strip.season_x(2) - strip.season_x(1)
	assert_gt(step, 0.0)
	assert_almost_eq(strip.season_x(12) - strip.season_x(1), step * 11.0, 0.01, "seasons evenly spaced")
	assert_eq(strip.season_title(1), "Spring 1480")
	assert_eq(strip.season_title(2), "Summer 1480")
	assert_eq(strip.season_title(4), "Winter 1480")
	assert_eq(strip.season_title(5), "Spring 1481")


func test_labels_at_12_40_and_680_seasons() -> void:
	var strip := _strip(1280.0)
	strip.set_timeline(_timeline(12))
	assert_eq(strip.label_turns(), PackedInt32Array([1, 5, 9]), "12 seasons: every Spring")
	strip.set_timeline(_timeline(40))
	assert_eq(strip.label_turns().size(), 10, "40 seasons: every Spring still")
	strip.set_timeline(_timeline(680))
	var labels := strip.label_turns()
	# Four seasons are under 36 px here, so the first fitting step of 5, 10 or 50 years is used.
	assert_true(labels.size() == 34 or labels.size() == 17, "680 seasons at 1280: every 5th or 10th year")
	for turn: int in labels:
		assert_eq((turn - 1) % 4, 0, "labels sit on Springs")
		assert_eq((1480 + floori(float(turn - 1) / 4.0)) % 5, 0, "labels fall on multiples of 5 years")

	var wide := _strip(2560.0)
	wide.set_timeline(_timeline(680))
	assert_eq(wide.label_turns().size(), 34, "680 seasons at 2560: every 5th year fits")
	wide.set_timeline(_timeline(40))
	assert_eq(wide.label_turns().size(), 10, "40 seasons at 2560: every Spring")


func test_marks_merge_when_narrow() -> void:
	var strip := _strip(1280.0)
	var marks := [_mark(1, "begun"), _mark(2, "land", "good"), _mark(3, "short", "bad"), _mark(200, "tax")]
	strip.set_timeline(_timeline(680, marks))
	assert_eq(strip.slot_count(), 2, "turns 1 to 3 share a slot at 680 seasons; turn 200 stands alone")
	var slots := strip.slots()
	assert_eq(slots[0]["drawn"]["kind"], "land", "the slot draws its highest mark")
	assert_eq((slots[0]["marks"] as Array).size(), 3)

	strip.set_timeline(_timeline(12, [_mark(1, "begun"), _mark(2, "land")]))
	assert_eq(strip.slot_count(), 2, "12 seasons: wide enough, nothing merges")


func test_dense_marks_merge_by_anchor_not_chain() -> void:
	# 680 seasons at 720 px: about 1.03 px a season, so a slot holds about 12 px of seasons and a new one starts 12 px
	# from its first mark. A chain would give one slot; the anchor gives about 680 / 11.6 = 58.
	var strip := _strip(720.0)
	var marks: Array = []
	for t: int in range(1, 681):
		marks.append(_mark(t, "tax"))
	strip.set_timeline(_timeline(680, marks))
	var count := strip.slot_count()
	assert_gt(count, 50, "dense marks do not chain into one slot")
	assert_lt(count, 66, "about width / 12 slots")
	var total := 0
	for slot: Dictionary in strip.slots():
		total += (slot["marks"] as Array).size()
		assert_lt(float(slot["last_x"]) - float(slot["first_x"]), TimelineStrip.MERGE_PX, "a slot spans under 12 px")
	assert_eq(total, 680, "every mark sits in exactly one slot")

	# Sparse marks, 40 seasons apart (about 74 px at 1280): nothing merges, one slot each.
	var sparse_strip := _strip(1280.0)
	var sparse: Array = []
	for i: int in 10:
		sparse.append(_mark(1 + i * 40, "tax"))
	sparse_strip.set_timeline(_timeline(680, sparse))
	assert_eq(sparse_strip.slot_count(), 10, "sparse marks stay separate")


func test_slot_draws_its_highest_mark() -> void:
	var strip := _strip(720.0)
	var kinds := ["chosen", "begun", "tax", "short", "stopped", "finished", "land"]
	var marks: Array = []
	for i: int in kinds.size():
		marks.append(_mark(1 + i, kinds[i]))
	strip.set_timeline(_timeline(680, marks))
	for slot: Dictionary in strip.slots():
		var drawn_rank := TimelineStrip.MARK_PRIORITY.find(str(slot["drawn"]["kind"]))
		for m: Dictionary in slot["marks"] as Array:
			assert_true(TimelineStrip.MARK_PRIORITY.find(str(m["kind"])) >= drawn_rank,
				"the drawn mark outranks every mark in its slot")
	assert_eq(strip.slots()[0]["drawn"]["kind"], "land", "land outranks the rest of the first slot")


func test_keys_move_cursor_and_emit() -> void:
	var strip := _strip(600.0)
	strip.set_timeline(_timeline(12))
	watch_signals(strip)
	strip._gui_input(_key(KEY_RIGHT))
	assert_eq(strip.cursor(), 1, "Right from none starts at the first season")
	strip._gui_input(_key(KEY_RIGHT))
	assert_eq(strip.cursor(), 2)
	strip._gui_input(_key(KEY_RIGHT, true))
	assert_eq(strip.cursor(), 6, "Shift+Right is a year")
	strip._gui_input(_key(KEY_LEFT, true))
	assert_eq(strip.cursor(), 2, "Shift+Left is a year back")
	strip._gui_input(_key(KEY_END))
	assert_eq(strip.cursor(), 12)
	strip._gui_input(_key(KEY_RIGHT))
	assert_eq(strip.cursor(), 12, "clamped at the last season")
	strip._gui_input(_key(KEY_HOME))
	assert_eq(strip.cursor(), 1)
	assert_signal_emit_count(strip, "cursor_moved", 6, "only real moves emit")
	strip._gui_input(_key(KEY_ENTER))
	assert_signal_emitted_with_parameters(strip, "season_activated", [1])


func test_left_from_none_starts_at_the_last_season() -> void:
	var strip := _strip(600.0)
	strip.set_timeline(_timeline(12))
	strip._gui_input(_key(KEY_LEFT))
	assert_eq(strip.cursor(), 12)


func test_pointer_hover_and_click() -> void:
	var strip := _strip(1280.0)
	strip.set_timeline(_timeline(12))
	watch_signals(strip)
	var pos := Vector2(strip.season_x(5), 50.0)
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	strip._gui_input(motion)
	assert_signal_emitted_with_parameters(strip, "season_hovered", [5])
	assert_eq(strip._get_tooltip(pos), "turn:5")
	strip.notification(Control.NOTIFICATION_MOUSE_EXIT)
	assert_signal_emitted_with_parameters(strip, "season_hovered", [-1])
	var click := InputEventMouseButton.new()
	click.position = Vector2(strip.season_x(3), 50.0)
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	strip._gui_input(click)
	assert_eq(strip.cursor(), 3)
	assert_signal_emitted_with_parameters(strip, "season_activated", [3])


func test_summary_and_accessibility_description() -> void:
	var strip := _strip(1280.0)
	var marks := [_mark(4, "finished"), _mark(5, "short"), _mark(8, "begun")]
	strip.set_timeline(_timeline(12, marks))
	var expected := "1480 to 1482: 12 seasons; marks in Winter 1480 (finished), Spring 1481 (short), Winter 1481 (begun)."
	assert_eq(strip.summary(), expected)
	assert_eq(strip.accessibility_description, expected)
	strip.set_timeline(_timeline(12))
	assert_eq(strip.summary(), "1480 to 1482: 12 seasons; no marks.")


func test_hover_card_lists_the_slot() -> void:
	var strip := _strip(1280.0)
	var marks := [_mark(1, "begun"), _mark(2, "land", "good"), _mark(3, "short", "bad"), _mark(200, "tax")]
	strip.set_timeline(_timeline(680, marks))
	var tip := strip._make_custom_tooltip("turn:2")
	assert_true(tip is HoverCard, "a HoverCard")
	var card := tip as HoverCard
	assert_eq(card.get_node("VBox/Title").get("text"), "Summer 1480")
	assert_eq(card.rows_container().get_child_count(), 4, "the count line and the three merged marks")
	card.free()

	var lone := strip._make_custom_tooltip("turn:200") as HoverCard
	assert_eq(lone.rows_container().get_child_count(), 2, "the count line and one mark")
	lone.free()


func test_redraws_only_on_changes() -> void:
	var strip := _strip(600.0)
	strip.set_timeline(_timeline(12))
	await _harness.wait_frames(self, 2)
	var idle := strip.redraw_count()
	assert_gt(idle, 0, "the strip draws once")
	await _harness.wait_frames(self, 3)
	assert_eq(strip.redraw_count(), idle, "idle frames do not redraw")

	strip.set_cursor(4)
	await _harness.wait_frames(self, 1)
	var after_cursor := strip.redraw_count()
	assert_gt(after_cursor, idle, "set_cursor redraws")

	strip.set_cursor(4)
	await _harness.wait_frames(self, 2)
	assert_eq(strip.redraw_count(), after_cursor, "set_cursor to the same season does not redraw")

	strip.size = Vector2(700.0, 96.0)
	await _harness.wait_frames(self, 2)
	var after_resize := strip.redraw_count()
	assert_gt(after_resize, after_cursor, "resize redraws")

	strip._gui_input(_motion_at(strip.season_x(6)))
	await _harness.wait_frames(self, 1)
	assert_gt(strip.redraw_count(), after_resize, "a hover change redraws")

	var before_theme := strip.redraw_count()
	strip.notification(Control.NOTIFICATION_THEME_CHANGED)
	await _harness.wait_frames(self, 1)
	assert_gt(strip.redraw_count(), before_theme, "theme change redraws")


func test_full_history_at_1280_and_2560() -> void:
	# Marks every 3 seasons: at 1280 (5.6 px apart) a slot holds 3 marks, at 2560 (11.2 px apart) 2.
	var expected := {1280.0: 67, 2560.0: 100}
	for width: float in [1280.0, 2560.0]:
		var strip := _strip(width, 96.0)
		var counts := PackedInt32Array()
		for i: int in 680:
			counts.append(i % 9)
		var marks: Array = []
		for i: int in 200:
			marks.append(_mark(1 + i * 3, "tax"))
		strip.set_timeline(_timeline(680, marks, counts))
		strip.set_cursor(400)
		await _harness.wait_frames(self, 2)
		assert_gt(strip.redraw_count(), 0, "draws at %d px" % int(width))
		assert_eq(strip.slot_count(), expected[width], "anchored merge at %d px" % int(width))
		assert_eq(strip.custom_minimum_size.y, 96.0, "96 px high")
		assert_true(strip.summary().begins_with("1480 to 1649: 680 seasons"), "summary of 680 seasons")
		assert_eq(strip.cursor(), 400)


func _motion_at(px: float) -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(px, 50.0)
	return motion
