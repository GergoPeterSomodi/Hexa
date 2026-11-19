## GUT tests for the country pick (docs/architecture/m2-build-spec.md sections 7.5 and 10).
extends GutTest

var _harness: UIHarness = null
var _prev_game: Game = null
var _prev_unsaved: int = 0


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the committed scenario starts")
	_harness = UIHarness.new()
	_harness.mount(self)


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	_harness = null
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Bindings.reset_defaults()


func _open() -> CountryPick:
	_harness.stack.theme = KitTheme.load_for(1.0)
	var pick := ScreenIds.make(&"country_pick") as CountryPick
	assert_not_null(pick)
	_harness.stack.push(pick)
	await _harness.wait_frames(self, 2)
	return pick


func _record_requests() -> Array:
	var requests: Array = []
	_harness.ctx.app_requested.connect(func(what: StringName, args: Dictionary) -> void: requests.append([what, args]))
	return requests


func _tap(keycode: Key) -> void:
	_harness.send_key(keycode, true)
	_harness.send_key(keycode, false)


func test_list_is_the_playable_countries_largest_first_and_france_is_outside() -> void:
	var pick := await _open()
	var tags := pick.row_tags()
	assert_true(tags.has(&"GEN"))
	assert_false(tags.has(&"FRA"), "an outside power is not in the list")
	for i: int in range(1, tags.size()):
		var before := CountryCard.of(Session.game, tags[i - 1])["districts"] as int
		var after := CountryCard.of(Session.game, tags[i])["districts"] as int
		assert_true(before >= after, "largest first")
	assert_true(pick.outside_lines().has("France: Paris is off this map"))


func test_pick_is_an_overlay_with_focus_on_the_first_row() -> void:
	var pick := await _open()
	assert_eq(pick.kind, Screen.Kind.OVERLAY)
	assert_false(_harness.stack.wants_pause(), "the map is not paused")
	assert_eq(_harness.viewport.gui_get_focus_owner(), pick.row_button(pick.row_tags()[0]))


func test_down_arrow_moves_the_focus_to_the_next_row() -> void:
	var pick := await _open()
	var tags := pick.row_tags()
	_tap(KEY_DOWN)
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.viewport.gui_get_focus_owner(), pick.row_button(tags[1]))


func test_enter_shows_the_country_then_enter_again_chooses_it() -> void:
	var pick := await _open()
	var requests := _record_requests()
	pick.row_button(&"GEN").grab_focus()
	_tap(KEY_ENTER)
	await _harness.wait_frames(self, 1)
	assert_eq(requests.size(), 1)
	assert_eq(requests[0], [&"country", {"tag": &"GEN"}])
	assert_eq(pick.shown_tag(), &"GEN")
	assert_true(pick.dock_open())
	assert_eq(_harness.stack.count(), 1, "showing does not end the pick")

	_tap(KEY_ENTER)
	await _harness.wait_frames(self, 1)
	assert_eq(Session.player_tag(), &"GEN", "the second Enter plays the country")
	assert_eq(_harness.stack.count(), 0, "the pick ends on country_chosen")


func test_play_as_refuses_an_outside_power_with_a_toast_and_changes_nothing() -> void:
	await _open()
	var pick := _harness.stack.top() as CountryPick
	var tones: Array = []
	_harness.ctx.toast_requested.connect(func(text: String, tone: StringName) -> void: tones.append(tone))
	assert_false(pick.play(&"FRA"))
	assert_eq(tones, [&"bad"])
	assert_eq(Session.player_tag(), &"", "no player is chosen")
	assert_eq(_harness.stack.count(), 1)


func test_a_map_click_shows_the_clicked_country() -> void:
	var pick := await _open()
	var requests := _record_requests()
	pick.on_country_clicked(&"MLO")
	assert_eq(requests, [[&"country", {"tag": &"MLO"}]])
	assert_eq(pick.shown_tag(), &"MLO")
	pick.on_country_clicked(&"")
	assert_eq(requests.size(), 1, "sea or unowned land does nothing")


func test_hover_brightens_its_row_and_clears() -> void:
	var pick := await _open()
	pick.on_country_hovered(&"GEN")
	assert_eq(pick.row_button(&"GEN").self_modulate, Tokens.GOLD)
	pick.on_country_hovered(&"")
	assert_eq(pick.row_button(&"GEN").self_modulate, Color.WHITE)


func test_esc_closes_the_dock_first_then_asks_for_pause_and_never_pops() -> void:
	var pick := await _open()
	var requests := _record_requests()
	pick.show_country(&"GEN")
	assert_true(_harness.stack.back(), "Esc is consumed")
	assert_eq(requests[1], [&"close_dock", {}])
	assert_eq(_harness.stack.count(), 1, "the pick is not popped")
	assert_false(pick.dock_open())

	assert_true(_harness.stack.back(), "Esc with no dock is consumed too")
	assert_eq(requests[2], [&"pause", {}])
	assert_eq(_harness.stack.count(), 1, "back() never pops the pick")
	assert_true(pick.back())
	assert_eq(_harness.stack.count(), 1)
