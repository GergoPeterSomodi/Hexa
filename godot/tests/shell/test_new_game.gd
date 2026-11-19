## GUT tests for the New game modal (docs/architecture/m2-build-spec.md sections 7.7 and 10).
extends GutTest

var _harness: UIHarness = null


func before_each() -> void:
	Bindings.reset_defaults()
	_harness = UIHarness.new()
	_harness.mount(self)


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	_harness = null
	Bindings.reset_defaults()


func _open() -> NewGame:
	_harness.stack.theme = KitTheme.load_for(1.0)
	var screen := ScreenIds.make(&"new_game") as NewGame
	assert_not_null(screen)
	_harness.stack.push(screen)
	await _harness.wait_frames(self, 2)
	return screen


func _record_requests() -> Array:
	var requests: Array = []
	_harness.ctx.app_requested.connect(func(what: StringName, args: Dictionary) -> void: requests.append([what, args]))
	return requests


func test_opens_as_a_modal_with_begin_focused_and_the_scenario_listed() -> void:
	var screen := await _open()
	assert_eq(screen.kind, Screen.Kind.MODAL)
	assert_true(_harness.stack.wants_pause())
	assert_eq(screen.frame().ribbon().label().text, "NEW GAME")
	assert_true(screen.scenario_ids().has("north_italy_1480"))
	assert_eq(screen.selected_scenario(), "north_italy_1480")
	assert_false(screen.blurb_label().text.is_empty(), "the scenario's blurb shows")
	assert_eq(_harness.viewport.gui_get_focus_owner(), screen.begin_button(), "Begin holds initial focus")
	assert_between(screen.current_seed(), 1, 999999, "the seed is filled with a random one")
	assert_false(screen.more_box().visible, "the seed row is folded under More")


func test_begin_sends_new_game_with_the_scenario_and_the_typed_seed() -> void:
	var screen := await _open()
	var requests := _record_requests()
	screen.seed_input().text = "1480"
	screen.begin_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(requests.size(), 1)
	assert_eq(requests[0][0], &"new_game")
	assert_eq(requests[0][1], {"scenario": "north_italy_1480", "seed": 1480})
	assert_eq(_harness.stack.count(), 0, "Begin ends the screen")


func test_enter_on_begin_starts_the_game() -> void:
	await _open()
	var requests := _record_requests()
	_harness.send_key(KEY_ENTER, true)
	_harness.send_key(KEY_ENTER, false)
	await _harness.wait_frames(self, 1)
	assert_eq(requests.size(), 1, "Enter on the focused Begin sends new_game")
	assert_eq(requests[0][0], &"new_game")


func test_a_bad_seed_is_refused_in_place() -> void:
	var screen := await _open()
	var requests := _record_requests()
	screen.seed_input().text = "12a"
	screen.begin_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(requests.size(), 0, "nothing is sent")
	assert_eq(_harness.stack.count(), 1, "the screen stays")
	assert_true(screen.reason_label().visible)
	assert_eq(NewGame.parse_seed("-4"), -1)
	assert_eq(NewGame.parse_seed(""), -1)
	assert_eq(NewGame.parse_seed("1234567890"), -1, "more than nine digits is refused")
	assert_eq(NewGame.parse_seed(" 42 "), 42)


func test_random_puts_a_seed_in_range_in_the_field() -> void:
	var screen := await _open()
	var rolled := screen.roll_random_seed()
	assert_between(rolled, 1, 999999)
	assert_eq(screen.current_seed(), rolled)
	screen.random_button().pressed.emit()
	assert_between(screen.current_seed(), 1, 999999)


func test_more_shows_the_seed_row() -> void:
	var screen := await _open()
	screen.more_button().button_pressed = true
	assert_true(screen.more_box().visible)
	screen.more_button().button_pressed = false
	assert_false(screen.more_box().visible)


func test_esc_goes_back_and_back_closes_without_a_request() -> void:
	await _open()
	var requests := _record_requests()
	assert_true(_harness.stack.back(), "Esc pops the screen")
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0)
	assert_eq(requests.size(), 0)

	var screen := await _open()
	screen.back_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0)
	assert_eq(requests.size(), 0)
