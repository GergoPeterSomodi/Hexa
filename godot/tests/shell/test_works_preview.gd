## GUT tests for WorksPreview (docs/architecture/m4-build-spec.md 6.5, 6.12): the card of a real ImprovePreview, Begin's
## request, Enter and U, Esc, pin (two options on one scale), Shift holding the card, the treasury switch (remembered),
## the placement left of the hex panel at 1280 x 720 and 2560 x 1440, and the wheel.
extends GutTest

const WORKS_PREVIEW_SCENE := preload("res://shell/screens/works_preview.tscn")
const VINEYARD_HEX := Vector2i(7, 12)
const GENOA_HEX := Vector2i(8, 13)
const TREASURY_KEY := "game/gain_treasury_only"

var _harness: UIHarness = null
var _requests: Array = []


func before_each() -> void:
	_harness = UIHarness.new()
	_harness.mount(self)
	_harness.stack.theme = KitTheme.load_for(1.0)
	_harness.ctx.app_requested.connect(func(what: StringName, args: Dictionary) -> void: _requests.append([what, args]))
	Session.start_game(EconomyFixture.game(&"GEN", true))


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	Session.end_game()
	_harness = null
	_requests.clear()


func _vineyard() -> Dictionary:
	return {"action": Works.BUILD, "family": ImproveRules.VINEYARD}


func _open(hex: Vector2i = VINEYARD_HEX, option: Dictionary = {}) -> WorksPreview:
	var screen := WORKS_PREVIEW_SCENE.instantiate() as WorksPreview
	_harness.stack.push(screen)
	screen.show_option(hex, option if not option.is_empty() else _vineyard())
	return screen


func _begin_requests() -> int:
	var n := 0
	for entry: Array in _requests:
		if entry[0] == &"begin_work":
			n += 1
	return n


func _accepted_build() -> Array:
	var g := Session.game
	var id := Countries.by_tag(g, &"GEN").id
	for i: int in Territory.districts(g, id):
		var hex := g.map.hex_of(i)
		for row: Dictionary in ImprovePreview.options_of(g, &"GEN", hex):
			if row["action"] == Works.BUILD and bool(row["verdict"]["ok"]):
				return [hex, {"action": Works.BUILD, "family": row["family"]}]
	return []


func test_show_option_fills_the_card_from_the_real_preview() -> void:
	var screen := _open()
	await _harness.wait_frames(self, 2)
	var real := ImprovePreview.of(Session.game, &"GEN", VINEYARD_HEX, _vineyard())
	assert_eq(screen.preview(), real, "the screen holds the ImprovePreview dictionary")
	assert_eq(screen.card().title_label().text, "Vineyard, first stage")
	assert_eq(screen.card().brings_container().get_child_count(), 4)
	assert_false(screen.card().begin_button().disabled)
	assert_eq(screen.shown_hex(), VINEYARD_HEX)


func test_begin_requests_begin_work_with_hex_and_option_and_closes() -> void:
	var screen := _open()
	await _harness.wait_frames(self, 2)
	screen.card().begin_pressed.emit()
	assert_eq(_requests, [[&"begin_work", {"hex": VINEYARD_HEX, "option": _vineyard()}]])
	assert_eq(_harness.stack.count(), 0, "Begin closes the card")


func test_enter_begins_and_u_begins() -> void:
	_open()
	await _harness.wait_frames(self, 2)
	_harness.send_key(KEY_ENTER)
	await _harness.wait_frames(self, 2)
	assert_eq(_begin_requests(), 1, "Enter begins once")
	assert_eq(_harness.stack.count(), 0)

	_open()
	await _harness.wait_frames(self, 2)
	_harness.send_key(KEY_U)
	await _harness.wait_frames(self, 2)
	assert_eq(_begin_requests(), 2, "U begins once")
	assert_eq(_harness.stack.count(), 0)


func test_refused_option_cannot_begin() -> void:
	# Genoa's upgrade is refused for money in the plain north Italy game (610 of 1,000 ducats).
	Session.start_game(EconomyFixture.game(&"GEN"))
	var screen := _open(GENOA_HEX, {"action": Works.UPGRADE, "family": 0})
	await _harness.wait_frames(self, 2)
	assert_true(screen.card().begin_button().disabled, "Begin is off with the reason")
	_harness.send_key(KEY_ENTER)
	await _harness.wait_frames(self, 2)
	assert_eq(_begin_requests(), 0)
	assert_eq(_harness.stack.count(), 1, "the card stays open")


func test_esc_closes_the_card() -> void:
	_open()
	await _harness.wait_frames(self, 2)
	_harness.send_key(KEY_ESCAPE)
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 0, "Esc closes")
	assert_eq(_begin_requests(), 0, "Esc does not begin")


func test_back_closes_the_card() -> void:
	var screen := _open()
	assert_true(screen.back())
	assert_eq(_harness.stack.count(), 0)


func test_pin_keeps_the_card_and_the_next_option_opens_beside_it() -> void:
	var screen := _open()
	await _harness.wait_frames(self, 2)
	screen.pin(true)
	assert_true(screen.pinned())
	assert_true(screen.card().pin_button().button_pressed)
	var other := _accepted_build()
	assert_eq(other.size(), 2, "another accepted build to compare with")
	screen.show_option(other[0], other[1])
	assert_true(screen.card().compare_container().visible, "two options side by side")
	var charts: Array[InkChart] = []
	for col_name: String in ["ColA", "ColB"]:
		for child: Node in (screen.card().compare_container().get_node(col_name) as Control).get_children():
			if child is InkChart:
				charts.append(child as InkChart)
	assert_eq(charts.size(), 2)
	assert_eq(charts[0].y_ticks, charts[1].y_ticks, "one scale for both")
	screen.pin(false)
	assert_false(screen.pinned())
	assert_true(screen.card().body_visible(), "unpinned: one card again")


func test_hold_keeps_the_card_while_the_pointer_is_away() -> void:
	var screen := _open()
	await _harness.wait_frames(self, 2)
	_harness.send_key(KEY_SHIFT, true, false, true)
	await _harness.wait_frames(self, 1)
	assert_true(screen.held(), "Shift holds")
	screen.leave()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 1, "the card stays while Shift is held")
	_harness.send_key(KEY_SHIFT, false)
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 0, "released after the pointer left: the card closes")


func test_leaving_without_shift_closes_the_card() -> void:
	_open()
	await _harness.wait_frames(self, 2)
	var screen := _harness.stack.top() as WorksPreview
	screen.leave()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 0)


func test_treasury_switch_rereads_the_gains_and_is_remembered() -> void:
	var screen := _open()
	await _harness.wait_frames(self, 2)
	screen.card().treasury_only_switch().set_pressed(true)
	assert_true(screen.treasury())
	assert_true(bool(_harness.settings.get_value(TREASURY_KEY)), "remembered in game/gain_treasury_only")
	assert_eq((screen.card().season_strip().cell(2).get_node("VBox/Gain") as DeltaChip).text(), "+14", "the treasury measure")
	_harness.stack.clear()
	var again := _open()
	assert_true(again.card().treasury_only, "a new card starts with the remembered switch")


func _overflows(screen: WorksPreview, vp: Vector2) -> bool:
	var r := screen.card_rect()
	return r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > vp.x or r.end.y > vp.y


func test_card_opens_left_of_the_hex_panel_at_1280_x_720() -> void:
	var screen := _open()
	await _harness.wait_frames(self, 2)
	var vp := Vector2(1280, 720)
	var panel := Rect2(vp.x - Tokens.PANEL_W, Tokens.BAR_H + Tokens.S2, Tokens.PANEL_W, 400.0)
	screen.set_beside(panel)
	await _harness.wait_frames(self, 2)
	var r := screen.card_rect()
	assert_true(r.end.x <= panel.position.x, "left of the panel")
	assert_eq(r.position.y, panel.position.y, "top at the panel's top")
	assert_false(_overflows(screen, vp), "no overflow")
	assert_gte(r.size.x, float(WorksPreview.CARD_W))


func test_card_opens_left_of_the_hex_panel_at_2560_x_1440() -> void:
	var big := UIHarness.new(Vector2i(2560, 1440))
	big.mount(self)
	big.stack.theme = KitTheme.load_for(1.0)
	Session.start_game(EconomyFixture.game(&"GEN", true))
	var screen := WORKS_PREVIEW_SCENE.instantiate() as WorksPreview
	big.stack.push(screen)
	screen.show_option(VINEYARD_HEX, _vineyard())
	await big.wait_frames(self, 2)
	var vp := Vector2(2560, 1440)
	assert_false(_overflows(screen, vp), "no overflow by default placement")
	var panel := Rect2(vp.x - Tokens.PANEL_W, Tokens.BAR_H + Tokens.S2, Tokens.PANEL_W, 600.0)
	screen.set_beside(panel)
	await big.wait_frames(self, 2)
	assert_true(screen.card_rect().end.x <= panel.position.x, "left of the panel at 2560 x 1440")
	assert_false(_overflows(screen, vp), "no overflow at 2560 x 1440")
	big.stack.clear()


func test_wheel_scrolls_the_card_when_it_is_taller_than_the_window() -> void:
	var screen := _open(GENOA_HEX, {"action": Works.UPGRADE, "family": 0})
	await _harness.wait_frames(self, 2)
	var scroll := screen.scroll()
	var bar := scroll.get_v_scroll_bar()
	assert_gt(bar.max_value, float(scroll.size.y), "the card is taller than its scroll area")
	var at := scroll.get_global_rect().get_center()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.position = at
	wheel.global_position = at
	wheel.pressed = true
	_harness.push_input(wheel)
	await _harness.wait_frames(self, 3)
	assert_gt(scroll.scroll_vertical, 0, "the wheel scrolls the card")


class KeySpy extends Node:
	var count: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.pressed and not key.is_echo() and key.keycode == KEY_U:
			count += 1


func test_u_is_swallowed_while_begin_is_disabled() -> void:
	var spy := KeySpy.new()
	_harness.viewport.add_child(spy)
	_harness.viewport.move_child(spy, 0)
	_harness.send_key(KEY_U)
	await _harness.wait_frames(self, 1)
	assert_eq(spy.count, 1, "control: with no card open, U reaches the rest of the tree")
	Session.start_game(EconomyFixture.game(&"GEN"))
	var screen := _open(GENOA_HEX, {"action": Works.UPGRADE, "family": 0})
	await _harness.wait_frames(self, 2)
	assert_true(screen.card().begin_button().disabled, "Begin is off for the refused option")
	_harness.send_key(KEY_U)
	await _harness.wait_frames(self, 2)
	assert_eq(spy.count, 1, "U is swallowed by the refused card")
	assert_eq(_begin_requests(), 0)
	assert_eq(_harness.stack.count(), 1, "the card stays open")


func test_an_explicit_open_takes_the_focus_on_begin() -> void:
	var screen := WORKS_PREVIEW_SCENE.instantiate() as WorksPreview
	_harness.stack.push(screen)
	screen.show_option(VINEYARD_HEX, _vineyard(), true)
	await _harness.wait_frames(self, 2)
	assert_true(screen.card().begin_button().has_focus(), "the info button or U focuses Begin")


func test_focused_hex_panel_row_keeps_the_card_open() -> void:
	var hex: Vector2i = _accepted_build()[0]
	var panel := (load("res://shell/panels/hex_panel.tscn") as PackedScene).instantiate() as HexPanel
	panel.theme = KitTheme.load_for(1.0)
	_harness.viewport.add_child(panel)
	panel.show_hex(hex)
	var screen := WORKS_PREVIEW_SCENE.instantiate() as WorksPreview
	_harness.stack.push(screen)
	panel.row_hovered.connect(func(h: Vector2i, option: Dictionary) -> void: screen.show_option(h, option))
	panel.row_unhovered.connect(func() -> void:
		if is_instance_valid(screen):
			screen.leave()
	)
	var buttons := panel.action_buttons()
	assert_gt(buttons.size(), 0, "the hex has rows")
	buttons[0].grab_focus()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 1, "the card stays while the row has focus")
	assert_true(buttons[0].has_focus(), "the row keeps its focus")
	assert_false(screen.card().begin_button().has_focus(), "the hover did not move the focus to Begin")
	panel.free()


func test_shift_held_before_the_card_opens_keeps_it_when_the_pointer_leaves() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_SHIFT
	key.physical_keycode = KEY_SHIFT
	key.pressed = true
	Input.parse_input_event(key)
	await _harness.wait_frames(self, 1)
	var screen := _open()
	await _harness.wait_frames(self, 1)
	screen.leave()
	await _harness.wait_frames(self, 1)
	var kept := _harness.stack.count() == 1
	key.pressed = false
	Input.parse_input_event(key)
	await _harness.wait_frames(self, 1)
	assert_true(kept, "Shift already down keeps the card when the pointer leaves")
	screen.hold(false)
	assert_eq(_harness.stack.count(), 0, "released after the pointer left: closes")

