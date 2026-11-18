## GUT tests for Loading screen
## (docs/architecture/ui-and-controls-spec.md section 3.2, 7, 9;
## docs/architecture/ui-style-and-feedback-plan.md U10).
extends GutTest

var _harness: UIHarness = null


func before_each() -> void:
	Bindings.reset_defaults()
	_harness = UIHarness.new()
	_harness.mount(self)
	_harness.stack.theme = KitTheme.load_for(1.0)


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	_harness = null
	Bindings.reset_defaults()


func test_loading_hides_world_blocks_input_and_ignores_esc() -> void:
	var behind_hits: Array[int] = [0]
	var behind_btn := Button.new()
	behind_btn.position = Vector2(540.0, 320.0)
	behind_btn.size = Vector2(180.0, 60.0)
	behind_btn.pressed.connect(func() -> void: behind_hits[0] += 1)
	_harness.viewport.add_child(behind_btn)
	_harness.viewport.move_child(behind_btn, 0)

	var loading := ScreenIds.make(&"loading") as Loading
	assert_not_null(loading)
	_harness.stack.push(loading)
	await _harness.wait_frames(self, 2)

	assert_eq(loading.kind, Screen.Kind.OPAQUE)
	assert_true(_harness.stack.hides_world())
	assert_true(_harness.stack.wants_pause())

	_harness.send_click(Vector2(600.0, 350.0))
	await _harness.wait_frames(self, 1)
	assert_eq(behind_hits[0], 0, "Loading blocks pointer input from reaching underlying controls")

	assert_true(_harness.stack.back(), "Loading consumes Esc")
	assert_eq(_harness.stack.count(), 1, "Esc does not pop Loading")


func test_loading_progress_status_hint_and_optional_cancel() -> void:
	var loading := ScreenIds.make(&"loading") as Loading
	_harness.stack.push(loading)
	await _harness.wait_frames(self, 1)

	loading.set_status("Building the map", "Drawing the map 0 %")
	loading.set_progress(0.63, "Drawing the map 63 %")
	assert_eq(loading.title_text(), "Building the map")
	assert_eq(loading.status_text(), "Drawing the map 63 %")
	assert_almost_eq(loading.progress_value(), 0.63, 0.001)
	assert_almost_eq(loading.progress_bar().value, 63.0, 0.01)

	loading.set_progress(1.5)
	assert_almost_eq(loading.progress_value(), 1.0, 0.001)
	loading.set_progress(-0.2)
	assert_almost_eq(loading.progress_value(), 0.0, 0.001)

	loading.set_hint("Placing rivers and passes")
	assert_false(loading.cancel_button().is_visible_in_tree())

	var source_frac: Array[float] = [0.42]
	loading.set_progress_source(func() -> float: return source_frac[0])
	loading._process(0.016)
	assert_almost_eq(loading.progress_value(), 0.42, 0.001)
	assert_eq(loading.status_text(), "Drawing the map 42 %")

	var cancel_calls: Array[int] = [0]
	var cancel_signals: Array[int] = [0]
	loading.cancelled.connect(func() -> void: cancel_signals[0] += 1)
	loading.set_cancelable(true, func() -> void: cancel_calls[0] += 1)
	assert_true(loading.cancel_button().is_visible_in_tree())

	loading.cancel_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(cancel_calls[0], 1)
	assert_eq(cancel_signals[0], 1)
	assert_eq(_harness.stack.count(), 0, "cancel closes Loading")
