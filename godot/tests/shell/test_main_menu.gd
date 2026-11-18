## GUT tests for MainMenu, Sandbox, and Credits screens
## (docs/architecture/ui-and-controls-spec.md section 5.1, 5.7, 9;
## docs/architecture/ui-style-and-feedback-plan.md U12).
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


func test_main_menu_loads_and_drops_menu_art_and_ignores_esc() -> void:
	_harness.settings.set_value("accessibility/reduce_motion", true)
	var menu := ScreenIds.make(&"main_menu") as MainMenu
	assert_not_null(menu)
	assert_null(menu.background_rect().texture, "menu_bg is not preloaded before enter")
	assert_null(menu.shade_rect().texture, "menu_shade is not preloaded before enter")

	_harness.stack.push(menu)
	await _harness.wait_frames(self, 2)

	assert_eq(menu.kind, Screen.Kind.OPAQUE)
	assert_true(_harness.stack.hides_world())
	assert_not_null(menu.background_rect().texture, "menu_bg loaded lazily on enter")
	assert_not_null(menu.shade_rect().texture, "menu_shade loaded lazily on enter")
	assert_eq(_harness.viewport.gui_get_focus_owner(), menu.sandbox_button(), "Map sandbox focused when dev tools on")

	assert_true(_harness.stack.back(), "Esc does nothing on MainMenu")
	assert_eq(_harness.stack.count(), 1)

	var popped := _harness.stack.pop()
	assert_eq(popped, menu)
	assert_null(menu.background_rect().texture, "menu_bg dropped on exit")
	assert_null(menu.shade_rect().texture, "menu_shade dropped on exit")
	menu.queue_free()


func test_main_menu_hides_sandbox_when_developer_tools_off_and_quits_directly() -> void:
	_harness.settings.set_value("dev/developer_tools", false)
	var menu := ScreenIds.make(&"main_menu") as MainMenu
	_harness.stack.push(menu)
	await _harness.wait_frames(self, 2)

	assert_false(menu.sandbox_button().visible, "Sandbox button hidden when dev/developer_tools is false")
	assert_eq(_harness.viewport.gui_get_focus_owner(), menu.options_button(), "Options takes focus when Sandbox hidden")

	_harness.settings.set_value("dev/developer_tools", true)
	assert_true(menu.sandbox_button().visible, "Sandbox button reappears when dev/developer_tools enabled")

	var requests: Array[StringName] = []
	_harness.ctx.app_requested.connect(func(what: StringName, _args: Dictionary) -> void: requests.append(what))
	menu.quit_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 1, "MainMenu Quit does not push Confirm")
	assert_eq(requests, [&"quit"])


func test_sandbox_starts_with_typed_and_random_seed_and_validates_input() -> void:
	var requests: Array[Dictionary] = []
	_harness.ctx.app_requested.connect(
		func(what: StringName, args: Dictionary) -> void: requests.append({"what": what, "args": args})
	)

	var menu := ScreenIds.make(&"main_menu") as MainMenu
	_harness.stack.push(menu)
	await _harness.wait_frames(self, 1)

	menu.sandbox_button().pressed.emit()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 2)
	var sandbox := _harness.stack.top() as Sandbox
	assert_not_null(sandbox)
	assert_eq(_harness.viewport.gui_get_focus_owner(), sandbox.start_button())

	# Invalid seed rejected
	sandbox.seed_input().text = "not_a_number"
	sandbox.start_button().pressed.emit()
	assert_eq(requests.size(), 0, "non-numeric seed does not emit start_sandbox")

	# Typed seed accepted
	sandbox.seed_input().text = "4242"
	sandbox.start_button().pressed.emit()
	assert_eq(requests.size(), 1)
	assert_eq(requests[0]["what"], &"start_sandbox")
	assert_eq((requests[0]["args"] as Dictionary)["seed"], 4242)

	# Random seed produces a valid positive integer
	sandbox.random_button().pressed.emit()
	var rolled := sandbox.current_seed()
	assert_gte(rolled, Sandbox.RANDOM_SEED_MIN)
	assert_lte(rolled, Sandbox.RANDOM_SEED_MAX)
	sandbox.start_button().pressed.emit()
	assert_eq(requests.size(), 2)
	assert_eq((requests[1]["args"] as Dictionary)["seed"], rolled)

	# Esc closes Sandbox back to MainMenu
	assert_true(_harness.stack.back())
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 1)
	assert_eq(_harness.stack.top(), menu)


func test_credits_displays_credits_md_on_vellum_and_closes() -> void:
	var menu := ScreenIds.make(&"main_menu") as MainMenu
	_harness.stack.push(menu)
	await _harness.wait_frames(self, 1)

	menu.credits_button().pressed.emit()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 2)
	var credits := _harness.stack.top() as Credits
	assert_not_null(credits)
	assert_eq(credits.sheet().theme_type_variation, &"PanelVellum")
	assert_eq(credits.sheet().ribbon().label().text, "CREDITS")
	assert_true(credits.credits_text().contains("Godot Engine"))
	assert_true(credits.credits_text().contains("Cinzel"))
	assert_true(credits.credits_text().contains("Alegreya"))
	assert_eq(_harness.viewport.gui_get_focus_owner(), credits.close_button())

	credits.close_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 1)
	assert_eq(_harness.stack.top(), menu)
