## GUT tests for Confirm vellum modal screen and its 10 s countdown variant
## (docs/architecture/ui-and-controls-spec.md section 5.3, 6.2, 9;
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


func test_confirm_vellum_layout_safe_focus_and_buttons() -> void:
	var results: Array[bool] = []
	var confirm := Confirm.make({
		"title": "Abandon campaign?",
		"body": "Unsaved progress will be lost.",
		"confirm_label": "Abandon",
		"cancel_label": "Stay",
		"danger": true,
		"on_result": func(accepted: bool) -> void: results.append(accepted),
	})
	assert_not_null(confirm)
	var signals_seen: Array[bool] = []
	confirm.confirmed.connect(func(accepted: bool) -> void: signals_seen.append(accepted))

	_harness.stack.push(confirm)
	await _harness.wait_frames(self, 2)

	assert_eq(confirm.kind, Screen.Kind.MODAL)
	assert_eq(confirm.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(confirm.sheet().theme_type_variation, &"PanelVellum")
	assert_eq(confirm.sheet().ribbon().label().text, "ABANDON CAMPAIGN?")
	assert_false(confirm.sheet().nav().visible)
	assert_eq(confirm.button_for(&"confirm").kind, KitButton.Kind.DANGER)
	assert_eq(_harness.viewport.gui_get_focus_owner(), confirm.button_for(&"cancel"), "safe choice holds initial focus")

	confirm.button_for(&"confirm").pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0, "Confirm auto-pops on button choice")
	assert_eq(results, [true])
	assert_eq(signals_seen, [true])


func test_confirm_esc_picks_safe_choice() -> void:
	var results: Array[bool] = []
	var confirm := Confirm.make({
		"title": "Keep these display settings?",
		"body": "The window mode changed.",
		"confirm_label": "Keep",
		"cancel_label": "Revert",
		"timeout_s": 10.0,
		"timeout_choice": &"cancel",
		"on_result": func(accepted: bool) -> void: results.append(accepted),
	})
	var signals_seen: Array[bool] = []
	confirm.confirmed.connect(func(accepted: bool) -> void: signals_seen.append(accepted))

	_harness.stack.push(confirm)
	await _harness.wait_frames(self, 1)
	assert_eq(confirm.sheet().seal_text(), "10")

	assert_true(_harness.stack.back(), "Esc handled by Confirm")
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0, "Esc closes Confirm")
	assert_eq(results, [false], "Esc picks safe/cancel choice")
	assert_eq(signals_seen, [false])


func test_confirm_countdown_displays_in_seal_and_auto_picks_timeout_choice() -> void:
	var results: Array[bool] = []
	var confirm := Confirm.make({
		"title": "Keep these display settings?",
		"body": "If you do nothing, the old settings come back.",
		"confirm_label": "Keep",
		"cancel_label": "Revert",
		"timeout_s": 10.0,
		"timeout_choice": &"cancel",
		"on_result": func(accepted: bool) -> void: results.append(accepted),
	})
	var signals_seen: Array[bool] = []
	confirm.confirmed.connect(func(accepted: bool) -> void: signals_seen.append(accepted))

	_harness.stack.push(confirm)
	await _harness.wait_frames(self, 1)
	assert_eq(confirm.sheet().seal_text(), "10")

	confirm._process(3.2)
	assert_eq(confirm.sheet().seal_text(), "7", "seal text counts down remaining whole seconds")
	assert_eq(_harness.stack.count(), 1, "still open before 10 s elapse")

	confirm._process(6.9)
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0, "Confirm pops after 10 s timeout")
	assert_eq(results, [false], "timeout_choice cancel resolves false")
	assert_eq(signals_seen, [false])


func test_confirm_countdown_can_timeout_to_confirm_and_supports_custom_choices() -> void:
	var chosen: Array[StringName] = []
	var results: Array[bool] = []
	var confirm := Confirm.make({
		"title": "Confirm action",
		"lines": ["Line one", "Line two"],
		"choices": [
			{"id": &"confirm", "label": "Proceed", "kind": "primary", "safe": false},
			{"id": &"cancel", "label": "Abort", "kind": "secondary", "safe": true},
		],
		"timeout_s": 4.0,
		"timeout_choice": &"confirm",
		"on_result": func(accepted: bool) -> void: results.append(accepted),
	})
	confirm.chose.connect(func(cid: StringName) -> void: chosen.append(cid))

	_harness.stack.push(confirm)
	await _harness.wait_frames(self, 1)
	assert_eq(confirm.sheet().seal_text(), "4")
	assert_eq(_harness.viewport.gui_get_focus_owner(), confirm.button_for(&"cancel"))

	confirm._process(4.1)
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0)
	assert_eq(chosen, [&"confirm"])
	assert_eq(results, [true])


func test_confirm_ask_derives_safe_choice_for_esc_and_stops_timer_on_pop() -> void:
	var chosen: Array[StringName] = []
	var confirm := Confirm.ask(
		"Keep display settings?",
		["Resolution changed."],
		[
			{"id": &"keep", "label": "Keep", "kind": "primary", "safe": false},
			{"id": &"revert", "label": "Revert", "kind": "secondary", "safe": true},
		],
		{"timeout_s": 10.0, "timeout_id": &"revert"}
	)
	confirm.chose.connect(func(cid: StringName) -> void: chosen.append(cid))

	_harness.stack.push(confirm)
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.viewport.gui_get_focus_owner(), confirm.button_for(&"revert"))
	assert_true(_harness.stack.back(), "Esc picks safe choice 'revert'")
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0)
	assert_eq(chosen, [&"revert"])

	# Popping a running countdown Confirm stops processing cleanly without firing timeout
	var chosen2: Array[StringName] = []
	var confirm2 := Confirm.ask(
		"Keep?",
		["Timer test"],
		[
			{"id": &"keep", "label": "Keep", "kind": "primary"},
			{"id": &"revert", "label": "Revert", "kind": "secondary", "safe": true},
		],
		{"timeout_s": 2.0, "timeout_id": &"revert"}
	)
	confirm2.chose.connect(func(cid: StringName) -> void: chosen2.append(cid))
	_harness.stack.push(confirm2)
	await _harness.wait_frames(self, 1)
	var popped := _harness.stack.pop()
	assert_eq(popped, confirm2)
	assert_false(confirm2.is_processing())
	confirm2._process(5.0)
	assert_eq(chosen2.size(), 0, "popped Confirm timer must not fire")
	confirm2.queue_free()
