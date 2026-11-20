## GUT tests for MainMenu, Sandbox, and Credits screens
## (docs/architecture/ui-and-controls-spec.md section 5.1, 5.7, 9;
## docs/architecture/ui-style-and-feedback-plan.md U12).
extends GutTest

const SAVE_DIR := "user://test_saves_menu"

var _harness: UIHarness = null
var _prev_dir: String = ""
var _prev_game: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_prev_dir = Session.save_dir
	Session.save_dir = SAVE_DIR
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_clear_saves()
	_harness = UIHarness.new()
	_harness.mount(self)
	_harness.stack.theme = KitTheme.load_for(1.0)


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	_harness = null
	Bindings.reset_defaults()
	_clear_saves()
	Session.save_dir = _prev_dir
	Session.game = _prev_game


func _clear_saves() -> void:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	for file: String in dir.get_files():
		dir.remove(file)


func _make_save() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"}).get("ok", false)))
	assert_eq(Session.save_game("1"), "")


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
	assert_eq(_harness.viewport.gui_get_focus_owner(), menu.new_game_button(), "New game is focused first")
	assert_eq(menu.new_game_button().kind, KitButton.Kind.MENU_PRIMARY, "New game is the primary button")
	assert_eq(menu.sandbox_button().kind, KitButton.Kind.MENU, "Map sandbox is a secondary button")

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
	assert_eq(_harness.viewport.gui_get_focus_owner(), menu.new_game_button(), "New game keeps focus when Sandbox hidden")
	assert_true(menu.new_game_button().visible, "New game is always shown")

	_harness.settings.set_value("dev/developer_tools", true)
	assert_true(menu.sandbox_button().visible, "Sandbox button reappears when dev/developer_tools enabled")

	var requests: Array[StringName] = []
	_harness.ctx.app_requested.connect(func(what: StringName, _args: Dictionary) -> void: requests.append(what))
	menu.quit_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 1, "MainMenu Quit does not push Confirm")
	assert_eq(requests, [&"quit"])


func test_new_game_is_first_and_opens_the_new_game_screen() -> void:
	var menu := ScreenIds.make(&"main_menu") as MainMenu
	_harness.stack.push(menu)
	await _harness.wait_frames(self, 1)

	var first_visible: Control = null
	for child: Node in menu.new_game_button().get_parent().get_children():
		if child is Control and (child as Control).visible:
			first_visible = child as Control
			break
	assert_eq(first_visible, menu.new_game_button(), "New game is the first visible button without a save")
	assert_eq(menu.new_game_button().text.to_lower(), "new game")
	menu.new_game_button().pressed.emit()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 2)
	assert_true(_harness.stack.top() is NewGame)
	assert_true(_harness.stack.back(), "Esc closes New game")
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.top(), menu)


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


func test_continue_is_first_and_focused_with_a_save_and_names_the_save() -> void:
	_make_save()
	var menu := ScreenIds.make(&"main_menu") as MainMenu
	_harness.stack.push(menu)
	await _harness.wait_frames(self, 2)

	assert_true(menu.continue_button().visible)
	assert_true(menu.continue_hint().visible)
	assert_true(menu.load_button().visible, "Load game shows with a save")
	assert_eq(menu.continue_button().get_parent().get_child(0), menu.continue_button(), "Continue is first")
	assert_eq(_harness.viewport.gui_get_focus_owner(), menu.continue_button(), "Continue is focused")
	assert_eq(menu.continue_button().kind, KitButton.Kind.MENU_PRIMARY, "Continue is the primary button")
	assert_eq(menu.new_game_button().kind, KitButton.Kind.MENU, "New game is secondary with a save")
	assert_eq(menu.continue_hint().text, "Republic of Genoa · Spring 1480")


func test_no_save_hides_continue_and_load_game() -> void:
	var menu := ScreenIds.make(&"main_menu") as MainMenu
	_harness.stack.push(menu)
	await _harness.wait_frames(self, 1)

	assert_false(menu.continue_button().visible, "Continue hidden without a save")
	assert_false(menu.continue_hint().visible)
	assert_false(menu.load_button().visible, "Load game hidden without a save")
	assert_eq(_harness.viewport.gui_get_focus_owner(), menu.new_game_button(), "New game is focused without a save")


func test_continue_asks_the_app_to_load_the_newest_save() -> void:
	_make_save()
	var menu := ScreenIds.make(&"main_menu") as MainMenu
	_harness.stack.push(menu)
	await _harness.wait_frames(self, 1)

	var requests: Array[Dictionary] = []
	_harness.ctx.app_requested.connect(
		func(what: StringName, args: Dictionary) -> void: requests.append({"what": what, "args": args})
	)
	menu.continue_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(requests.size(), 1)
	assert_eq(requests[0]["what"], &"load")
	assert_eq((requests[0]["args"] as Dictionary)["slot"], "1")


func test_load_game_opens_the_save_and_load_screen_on_its_load_tab() -> void:
	_make_save()
	var menu := ScreenIds.make(&"main_menu") as MainMenu
	_harness.stack.push(menu)
	await _harness.wait_frames(self, 1)
	menu.load_button().pressed.emit()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 2)
	assert_eq(_harness.stack.top().screen_id, &"save_load")
	assert_eq((_harness.stack.top() as SaveLoad).tab(), SaveLoad.TAB_LOAD, "opens on the Load tab")
