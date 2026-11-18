## GUT tests for PauseMenu screen
## (docs/architecture/ui-and-controls-spec.md section 5.2, 9;
## docs/architecture/ui-style-and-feedback-plan.md U10).
extends GutTest


class FakeUnsavedContext:
	extends ShellContext

	var unsaved: bool = false

	func _init(p_settings: Settings, p_stack: Control, p_unsaved: bool) -> void:
		super(p_settings, p_stack)
		unsaved = p_unsaved

	func has_unsaved_actions() -> bool:
		return unsaved


var _harness: UIHarness = null
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_harness = UIHarness.new()
	_harness.mount(self)


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	_harness = null
	Session.game = _prev_game
	Bindings.reset_defaults()


func _apply_theme() -> void:
	_harness.stack.theme = KitTheme.load_for(1.0)


func test_pause_menu_opens_paused_with_studiolo_buttons_and_default_focus() -> void:
	_apply_theme()
	var map := load("res://data/maps/north_italy.tres") as MapData
	Session.game = Game.new_game(map, 1480)

	var pause := ScreenIds.make(&"pause_menu") as PauseMenu
	assert_not_null(pause)
	_harness.stack.push(pause)
	await _harness.wait_frames(self, 2)

	assert_eq(pause.kind, Screen.Kind.MODAL)
	assert_true(_harness.stack.wants_pause())
	assert_false(_harness.stack.hides_world())
	assert_eq(pause.frame().ribbon().label().text, "PAUSED")
	assert_true(pause.subtitle_label().text.contains("1480"))
	assert_eq(pause.resume_button().kind, KitButton.Kind.MENU_PRIMARY)
	assert_eq(pause.quit_button().kind, KitButton.Kind.MENU_DANGER)
	assert_eq(pause.options_button().kind, KitButton.Kind.MENU)
	assert_eq(pause.help_button().kind, KitButton.Kind.MENU)
	assert_eq(pause.main_menu_button().kind, KitButton.Kind.MENU)
	assert_eq(_harness.viewport.gui_get_focus_owner(), pause.resume_button(), "Resume holds initial focus")


func test_resume_and_esc_close_pause_menu_and_help_opens_help_overlay() -> void:
	_apply_theme()
	var pause := ScreenIds.make(&"pause_menu") as PauseMenu
	_harness.stack.push(pause)
	await _harness.wait_frames(self, 1)

	pause.help_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 2)
	assert_eq(_harness.stack.top().screen_id, &"help")

	assert_true(_harness.stack.back(), "Esc closes HelpOverlay first")
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 1)
	assert_eq(_harness.stack.top(), pause)

	pause.resume_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0, "Resume closes PauseMenu")

	var pause2 := ScreenIds.make(&"pause_menu") as PauseMenu
	_harness.stack.push(pause2)
	await _harness.wait_frames(self, 1)
	assert_true(_harness.stack.back(), "Esc closes PauseMenu")
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0)


func test_main_menu_and_quit_emit_directly_without_unsaved_actions() -> void:
	_apply_theme()
	var fake_ctx := FakeUnsavedContext.new(_harness.settings, _harness.stack, false)
	_harness.stack.setup(fake_ctx)

	var requests: Array[StringName] = []
	fake_ctx.app_requested.connect(func(what: StringName, _args: Dictionary) -> void: requests.append(what))

	var pause := ScreenIds.make(&"pause_menu") as PauseMenu
	_harness.stack.push(pause)
	await _harness.wait_frames(self, 1)

	pause.main_menu_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 1, "no Confirm pushed when unsaved == 0")
	assert_eq(requests, [&"main_menu"])

	pause.quit_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 1, "no Confirm pushed for Quit when unsaved == 0")
	assert_eq(requests, [&"main_menu", &"quit"])


func test_main_menu_and_quit_require_confirm_when_unsaved_actions_exist() -> void:
	_apply_theme()
	var fake_ctx := FakeUnsavedContext.new(_harness.settings, _harness.stack, true)
	_harness.stack.setup(fake_ctx)

	var requests: Array[StringName] = []
	fake_ctx.app_requested.connect(func(what: StringName, _args: Dictionary) -> void: requests.append(what))

	var pause := ScreenIds.make(&"pause_menu") as PauseMenu
	_harness.stack.push(pause)
	await _harness.wait_frames(self, 1)

	pause.main_menu_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 2, "Confirm pushed when unsaved > 0")
	assert_eq(requests.size(), 0, "main_menu not emitted before confirmation")

	var confirm := _harness.stack.top() as Confirm
	assert_not_null(confirm)
	# Cancel via Esc
	assert_true(_harness.stack.back())
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 1)
	assert_eq(requests.size(), 0, "cancelling Confirm does not emit main_menu")

	# Now accept Main menu
	pause.main_menu_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	confirm = _harness.stack.top() as Confirm
	assert_not_null(confirm)
	confirm.button_for(&"confirm").pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(requests, [&"main_menu"])

	# And Quit with Confirm accepted
	pause.quit_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	confirm = _harness.stack.top() as Confirm
	assert_not_null(confirm)
	assert_eq(confirm.button_for(&"confirm").kind, KitButton.Kind.DANGER)
	confirm.button_for(&"confirm").pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(requests, [&"main_menu", &"quit"])
