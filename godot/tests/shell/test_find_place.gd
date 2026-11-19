## GUT tests for the place search (docs/architecture/m2-build-spec.md sections 7.9 and 10).
extends GutTest

var _harness: UIHarness = null
var _prev_game: Game = null
var _prev_unsaved: int = 0


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "")
	_harness = UIHarness.new()
	_harness.mount(self)


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	_harness = null
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Bindings.reset_defaults()


func _open() -> FindPlace:
	_harness.stack.theme = KitTheme.load_for(1.0)
	var screen := ScreenIds.make(&"find_place") as FindPlace
	assert_not_null(screen)
	_harness.stack.push(screen)
	await _harness.wait_frames(self, 2)
	return screen


func _record_requests() -> Array:
	var requests: Array = []
	_harness.ctx.app_requested.connect(func(what: StringName, args: Dictionary) -> void: requests.append([what, args]))
	return requests


func _tap(keycode: Key) -> void:
	_harness.send_key(keycode, true)
	_harness.send_key(keycode, false)


func test_opens_as_an_overlay_with_the_field_focused() -> void:
	var screen := await _open()
	assert_eq(screen.kind, Screen.Kind.OVERLAY)
	assert_eq(_harness.viewport.gui_get_focus_owner(), screen.query())
	assert_false(_harness.stack.wants_pause())


func test_ver_gives_verona_and_vercelli_first_by_prefix() -> void:
	var screen := await _open()
	screen.set_query("ver")
	var names: Array[String] = []
	for hit: Dictionary in screen.results():
		names.append(str(hit["name"]))
	assert_true(names.size() >= 2)
	assert_true(names[0].to_lower().begins_with("ver"))
	assert_true(names[1].to_lower().begins_with("ver"))
	assert_true(names.has("Verona") and names.has("Vercelli"))


func test_mil_gives_the_country_milan_first() -> void:
	var screen := await _open()
	screen.set_query("mil")
	var first := screen.results()[0]
	assert_eq(first["kind"], &"country")
	assert_eq(first["name"], "Milan")


func test_at_most_eight_results_and_a_note_when_nothing_matches() -> void:
	var screen := await _open()
	screen.set_query("a")
	assert_true(screen.results().size() <= PlaceSearch.LIMIT)
	assert_eq(screen.row_buttons().size(), screen.results().size())
	screen.set_query("zzqx")
	assert_eq(screen.results().size(), 0)
	assert_true(screen.note_label().visible)


func test_arrows_then_enter_on_a_place_sends_look_at_with_select() -> void:
	var screen := await _open()
	var requests := _record_requests()
	screen.set_query("ver")
	_tap(KEY_DOWN)
	assert_eq(screen.cursor(), 1, "Down moves the highlight")
	var hex: Vector2i = screen.results()[1]["hex"]
	_tap(KEY_ENTER)
	await _harness.wait_frames(self, 1)
	assert_eq(requests, [[&"look_at", {"hex": hex, "select": true}]])
	assert_eq(_harness.stack.count(), 0, "the screen ends after a choice")


func test_enter_on_a_country_sends_country() -> void:
	var screen := await _open()
	var requests := _record_requests()
	screen.set_query("mil")
	_tap(KEY_ENTER)
	await _harness.wait_frames(self, 1)
	assert_eq(requests, [[&"country", {"tag": &"MLO"}]])


func test_clicking_a_row_chooses_it() -> void:
	var screen := await _open()
	var requests := _record_requests()
	screen.set_query("mil")
	screen.row_buttons()[0].pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(requests.size(), 1)
	assert_eq(requests[0][0], &"country")


func test_ctrl_f_closes_and_esc_pops() -> void:
	await _open()
	_harness.send_key(KEY_F, true, true)
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0, "Ctrl+F closes the search")

	await _open()
	assert_true(_harness.stack.back(), "Esc pops it")
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0)
