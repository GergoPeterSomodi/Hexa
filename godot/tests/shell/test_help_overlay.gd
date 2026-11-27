## GUT tests for HelpOverlay screen
## (docs/architecture/ui-and-controls-spec.md section 4.6, 9;
## docs/architecture/ui-style-and-feedback-plan.md U13).
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


func test_help_overlay_is_non_pausing_three_columns_and_lists_every_default_action() -> void:
	var behind_hits: Array[int] = [0]
	var behind_btn := Button.new()
	behind_btn.position = Vector2(20.0, 20.0)
	behind_btn.size = Vector2(100.0, 40.0)
	behind_btn.pressed.connect(func() -> void: behind_hits[0] += 1)
	_harness.viewport.add_child(behind_btn)
	_harness.viewport.move_child(behind_btn, 0)

	var help := ScreenIds.make(&"help") as HelpOverlay
	assert_not_null(help)
	_harness.stack.push(help)
	await _harness.wait_frames(self, 2)

	assert_eq(help.kind, Screen.Kind.OVERLAY)
	assert_false(_harness.stack.wants_pause(), "HelpOverlay does not pause")
	assert_false(_harness.stack.hides_world(), "HelpOverlay does not hide world")
	assert_eq(help.column_count(), 3, "HelpOverlay displays three columns")
	assert_eq(help.frame().ribbon().label().text, "CONTROLS")
	assert_eq(_harness.viewport.gui_get_focus_owner(), help.close_button())

	# Click outside modal frame reaches underlying control
	_harness.send_click(Vector2(50.0, 40.0))
	await _harness.wait_frames(self, 1)
	assert_eq(behind_hits[0], 1, "OVERLAY passes clicks outside ModalFrame to underlying controls")

	# Every action in Bindings.DEFAULTS is rendered with matching KeyCap(s)
	var plat := OS.get_name()
	for entry: Dictionary in Bindings.DEFAULTS:
		var action: StringName = entry["action"]
		var caps := help.key_caps_for_action(action)
		var expected := Bindings.key_caps_for(action, plat)
		assert_eq(caps.size(), expected.size(), "KeyCap count matches for %s" % String(action))
		for i: int in mini(caps.size(), expected.size()):
			assert_eq(caps[i].label().text, expected[i], "KeyCap %d text for %s" % [i, String(action)])


## moves in the month (R54): the help overlay says moves are final, and so do the key hints while an army is selected.
func test_help_and_key_hints_say_army_moves_are_final() -> void:
	var words := "Army moves are final: an army walks when you give the order."
	var help := ScreenIds.make(&"help") as HelpOverlay
	_harness.stack.push(help)
	await _harness.wait_frames(self, 2)
	assert_eq(help.moves_note(), words)
	var hints := KeyHints.new()
	add_child_autofree(hints)
	assert_eq(hints.note_text(), "", "no line with no army")
	var actions := hints.hint_actions()
	Events.army_selected.emit(1)
	assert_eq(hints.note_text(), words)
	assert_eq(hints.hint_actions(), actions, "the key caps stay")
	assert_eq(hints.get_child(0), hints.note_label(), "the line leads, so the room never cuts it first")
	hints.set_context(true)
	assert_eq(hints.note_text(), words, "kept when the context changes")
	Events.army_cleared.emit()
	assert_eq(hints.note_text(), "")


func test_help_overlay_shows_platform_gestures_and_updates_live_on_rebind() -> void:
	var help := ScreenIds.make(&"help") as HelpOverlay
	help.platform_override = "macOS"
	_harness.stack.push(help)
	await _harness.wait_frames(self, 2)

	assert_eq(help.gesture_lines(), Bindings.gestures_for("macOS"), "macOS gesture lines displayed")
	assert_eq(help.key_caps_for_action(&"dev_new_seed")[0].label().text, "Cmd+R")

	help.refresh_bindings("Windows")
	assert_eq(help.gesture_lines(), Bindings.gestures_for("Windows"), "Windows gesture lines displayed")
	assert_eq(help.key_caps_for_action(&"dev_new_seed")[0].label().text, "Ctrl+R")

	# Live rebind via Bindings + settings change signal
	var res := Bindings.apply_overrides({"view_grid": "K"})
	assert_true(bool(res["ok"]))
	_harness.settings.set_key_override("view_grid", "K")
	await _harness.wait_frames(self, 1)
	assert_eq(help.key_caps_for_action(&"view_grid")[0].label().text, "K", "HelpOverlay updates live on rebinding")


func test_help_overlay_state_help_seen_opens_once_and_closes_cleanly() -> void:
	assert_false(bool(_harness.settings.get_value("state/help_seen")))
	assert_true(HelpOverlay.should_auto_open(_harness.settings))

	var first := HelpOverlay.open_if_unseen(_harness.ctx)
	assert_not_null(first, "opens automatically when state/help_seen is false")
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 1)
	assert_true(bool(_harness.settings.get_value("state/help_seen")), "marks state/help_seen true on enter")
	assert_false(HelpOverlay.should_auto_open(_harness.settings))

	assert_null(HelpOverlay.open_if_unseen(_harness.ctx), "does not re-open once help_seen is true")
	assert_eq(_harness.stack.count(), 1)

	assert_true(_harness.stack.back(), "Esc closes HelpOverlay")
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0)
	assert_eq(_harness.settings.changed.get_connections().size(), 0, "no leaked settings.changed connections on exit")
