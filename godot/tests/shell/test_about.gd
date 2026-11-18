## GUT tests for About diagnostics modal screen
## (docs/architecture/ui-and-controls-spec.md sections 5.6 and 9;
## docs/architecture/ui-style-and-feedback-plan.md U11).
extends GutTest

var _harness: UIHarness = null
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_harness = UIHarness.new()
	_harness.mount(self)
	_harness.stack.theme = KitTheme.load_for(1.0)


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	_harness = null
	Session.game = _prev_game
	Bindings.reset_defaults()


func test_about_opens_with_focus_and_all_spec_diagnostics_lines() -> void:
	var map := load("res://data/maps/north_italy.tres") as MapData
	Session.game = Game.new_game(map, 1480)

	var about := ScreenIds.make(&"about") as About
	assert_not_null(about)
	_harness.stack.push(about)
	await _harness.wait_frames(self, 2)

	assert_eq(about.kind, Screen.Kind.MODAL)
	assert_eq(about.screen_id, &"about")
	assert_true(_harness.stack.wants_pause())
	assert_eq(_harness.viewport.gui_get_focus_owner(), about.close_button(), "Close holds initial focus")

	var text := about.diagnostics_text()
	var expected_app := str(ProjectSettings.get_setting("application/config/name", "Hexa"))
	var expected_ver := str(ProjectSettings.get_setting("application/config/version", "0.3.0"))
	assert_true(text.contains("Hexa version: %s %s" % [expected_app, expected_ver]))
	assert_true(text.contains("Engine: Godot "))
	assert_true(text.contains("System: %s" % OS.get_name()))
	assert_true(text.contains("locale %s" % OS.get_locale()))
	assert_true(text.contains("Renderer: "))
	assert_true(text.contains(RenderingServer.get_current_rendering_driver_name()))
	assert_true(text.contains("Graphics card: "))
	var adapter := RenderingServer.get_video_adapter_name()
	if not adapter.is_empty():
		assert_true(text.contains(adapter))
	assert_true(text.contains("Screen: "))
	assert_true(text.contains("UI scale "))
	assert_true(text.contains("Memory: "))
	assert_true(text.contains("Game: map north_italy"))
	assert_true(text.contains("seed 1480"))
	assert_true(text.contains("Folders: %s" % OS.get_user_data_dir()))
	assert_true(text.contains("Settings file: %s" % Settings.PATH))


func test_about_copy_diagnostics_updates_clipboard_status_and_toast() -> void:
	var about := ScreenIds.make(&"about") as About
	assert_not_null(about)
	_harness.stack.push(about)
	await _harness.wait_frames(self, 2)

	var copied_calls: Array[String] = []
	about.set_clipboard_writer(func(t: String) -> void: copied_calls.append(t))

	var toasts: Array[Dictionary] = []
	_harness.ctx.toast_requested.connect(func(msg: String, tone: StringName) -> void:
		toasts.append({"text": msg, "tone": tone})
	)

	about.copy_button().pressed.emit()
	await _harness.wait_frames(self, 1)

	assert_eq(copied_calls.size(), 1)
	assert_eq(copied_calls[0], about.last_copied_text())
	assert_true(copied_calls[0].contains("Hexa version:"))
	assert_true(copied_calls[0].contains("Graphics card:"))
	assert_true(copied_calls[0].contains("Screen:"))
	assert_true(copied_calls[0].contains("Memory:"))
	assert_true(copied_calls[0].contains("Folders:"))
	assert_eq(about.status_label().text, "Diagnostics copied to clipboard.")
	assert_eq(toasts.size(), 1)
	assert_eq(toasts[0]["tone"], &"good")


func test_about_opens_credits_and_esc_closes_cleanly() -> void:
	Session.game = null
	var about := ScreenIds.make(&"about") as About
	_harness.stack.push(about)
	await _harness.wait_frames(self, 2)
	assert_true(about.diagnostics_text().contains("Game: No active game"))

	about.credits_button().pressed.emit()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 2)
	assert_eq(_harness.stack.top().screen_id, &"credits")

	assert_true(_harness.stack.back(), "Esc closes Credits first")
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 1)
	assert_eq(_harness.stack.top(), about)

	assert_true(_harness.stack.back(), "Esc closes About")
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0)
