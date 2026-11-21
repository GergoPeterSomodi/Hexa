## The shared parts of the UI monkey (test_ui_monkey.gd extends this): the input helpers, the counters and the M4 actions and
## invariants. M4 (m4-build-spec.md section 9): I, L, [ and ], U, clicks on the chips, on the hex panel's rows (hover and
## click), on the works card (Begin, pin, Esc) and on the study's tax buttons; the world hidden exactly while the study is up,
## the digest unchanged by the study, a card, a row's hover or a chip's card, the treasury and the stores never negative,
## no error, no orphan growth. Split out of the monkey to keep it under the lint's 1,200 lines.
class_name MonkeyM4
extends GutTest

## An M4 action a seed must do runs from this step on when its counter is still 0.
const FORCE_M4_STEP := 150
## The M4 counters a seed must raise above 0 (so its invariants cannot pass empty).
const M4_REQUIRED: Array[String] = [
	"studies", "study_i", "study_l", "study_page_keys", "tax_clicks", "u_keys", "chip_clicks", "chip_cards", "row_hovers",
	"row_clicks", "card_begins", "card_pins", "card_escs", "orphan_cycles", "m4_checks", "study_tab_keys", "legend_checks",
]

## The monkey's counters (every action it does and every effect it sees).
var _n: Dictionary = {}
## The M4 actions are on (a country game).
var _m4: bool = false
## The seed and step in progress, for the checks' messages.
var _tag: String = ""
## The step in progress (0 based).
var _step_no: int = 0
## A developer command (`people c r N`, or the money a forced step gives) ran in the current step: the digest may have moved
## without an accepted action.
var _dev_changed: bool = false
## Late in a run (the last third of the steps) a required M4 counter still at 0 gets every step: the coverage steps go first.
const LATE_STEP := 400


func _send_chord(vp: SubViewport, key: Key, ctrl: bool = false, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.ctrl_pressed = ctrl
		ev.shift_pressed = shift
		ev.pressed = pressed
		vp.push_input(ev)


func _send_click(vp: SubViewport, pos: Vector2, button: MouseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)

	var press := InputEventMouseButton.new()
	press.button_index = button
	press.position = pos
	press.global_position = pos
	press.pressed = true
	vp.push_input(press)

	var release := InputEventMouseButton.new()
	release.button_index = button
	release.position = pos
	release.global_position = pos
	release.pressed = false
	vp.push_input(release)


func _wait_frames(frames: int = 1) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame


func _collect_clickable_buttons(root_node: Node) -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	var queue: Array[Node] = [root_node]
	while not queue.is_empty():
		var cur := queue.pop_front() as Node
		if cur is CanvasItem and not (cur as CanvasItem).visible:
			continue
		if cur is BaseButton:
			var btn := cur as BaseButton
			if btn.is_visible_in_tree() and not btn.disabled:
				var bname := String(btn.name)
				if bname != "QuitButton" and not bname.contains("Quit") and not bname.contains("OpenDataFolder"):
					out.append(btn)
		for child: Node in cur.get_children():
			queue.append(child)
	return out


func _bump(key: String) -> void:
	_n[key] = int(_n[key]) + 1


func _m3_calm(app: App) -> bool:
	return Session.game != null and Session.player_tag() != &"" and app.stack().count() == 0 \
		and not app.is_starting() and app.requests().flow.state() == SeasonFlow.State.IDLE


# ----- M4: the study, the chips, the hex panel's rows and the works card ----------------------------------------------------
# Invariants (m4-build-spec.md section 9): the world is hidden exactly while the study is up (an opaque screen); the digest
# is unchanged by opening the study, a card, hovering a row or a chip's hover card (only Begin, set_tax and the dev actions
# change it); the treasury and the stocks are never negative, and a refused action leaves them as they were; the card's marks
# go with the card; no error (GUT fails a test on an engine error) and no orphan growth.


## Names the M4 action in progress in the messages of its checks.
func _m4_note(what: String) -> void:
	_tag = "%s (%s)" % [_tag.get_slice(" (", 0), what]


## What an action may change, taken before it: the game, its digest and version, the player's treasury and stocks.
func _m4_snapshot() -> Dictionary:
	var game := Session.game
	var country := Countries.by_tag(game, game.player)
	return {
		"game": game,
		"digest": game.digest(),
		"version": game.version,
		"treasury": country.treasury if country != null else 0,
		"stock": country.stock.duplicate() if country != null else PackedInt32Array(),
	}


## `what` is not an action: the digest, the version, the treasury and the stocks are as `before` took them.
func _m4_assert_untouched(before: Dictionary, what: String) -> void:
	if Session.game == null or Session.game != before["game"]:
		return
	var now := _m4_snapshot()
	assert_eq(now["digest"], before["digest"], "%s: %s leaves the game digest" % [_tag, what])
	assert_eq(now["version"], before["version"], "%s: %s is not an action" % [_tag, what])
	assert_eq(now["treasury"], before["treasury"], "%s: %s leaves the treasury" % [_tag, what])
	assert_eq(now["stock"], before["stock"], "%s: %s leaves the stores" % [_tag, what])


## A land hex of the map (the player's own when `own`); MapScene.NO_HEX when none turns up.
func _m4_pick_hex(rng: Rng, own: bool) -> Vector2i:
	var game := Session.game
	var count := game.map.hex_count()
	for _try: int in 300:
		var i := rng.randi_range(0, count - 1)
		if game.map.land[i] == 0:
			continue
		var hex := game.map.hex_of(i)
		if own and Territory.owner_tag(game, hex) != game.player:
			continue
		return hex
	return MapScene.NO_HEX


## A left click on the middle of `btn` when it shows in the window, else its pressed signal. False when nothing was done.
func _m4_press(vp: SubViewport, btn: BaseButton) -> bool:
	if btn == null or not is_instance_valid(btn) or not btn.is_visible_in_tree() or btn.disabled:
		return false
	var rect := btn.get_global_rect()
	if rect.has_area() and Rect2(Vector2.ZERO, Vector2(vp.size)).has_point(rect.get_center()):
		_send_click(vp, rect.get_center(), MOUSE_BUTTON_LEFT)
	else:
		btn.pressed.emit()
	return true


## Whether a click on a hex panel row is a real mouse click. Off while the bug of
## test_a_mouse_click_on_a_row_keeps_its_card stands: the click opens the card, Begin takes the focus, the row's focus_exited
## reads as the pointer leaving and the card closes at once, its ghost left on the map. The row's pressed signal (the path of
## test_app_flow_m4) is what the monkey sends until the fix; then set this true.
const ROW_CLICKS_BY_MOUSE := true


func _m4_press_row(vp: SubViewport, row: Button) -> bool:
	if ROW_CLICKS_BY_MOUSE:
		return _m4_press(vp, row)
	if row == null or not row.is_visible_in_tree() or row.disabled:
		return false
	row.pressed.emit()
	return true


func _m4_card(app: App) -> WorksPreview:
	return app.stack().top() as WorksPreview


## Esc until no card is left; its marks must be off the map with it.
func _m4_close_cards(vp: SubViewport, app: App) -> void:
	var guard := 0
	while app.stack().has_screen(&"works_preview") and guard < 4:
		_send_chord(vp, KEY_ESCAPE)
		_bump("card_escs")
		await _wait_frames(2)
		guard += 1
	assert_false(app.stack().has_screen(&"works_preview"), "%s: Esc closes the works card" % _tag)
	if app.map_scene() != null:
		assert_false(app.map_scene().preview_marks().shown(), "%s: the card's marks went with it" % _tag)


## Esc or I closes the study; a click inside it may have closed it already.
func _m4_close_study(rng: Rng, vp: SubViewport, app: App) -> void:
	if not app.stack().has_screen(&"study"):
		return
	_send_chord(vp, KEY_I if rng.randi_range(0, 1) == 0 else KEY_ESCAPE)
	await _wait_frames(2)
	assert_false(app.stack().has_screen(&"study"), "%s: I or Esc closes the study" % _tag)
	if app.stack().has_screen(&"study"):
		_send_chord(vp, KEY_ESCAPE)
		await _wait_frames(2)


## Calm, and no text box holding the keys (the console's line takes I, L and U as letters): lets the console go first.
func _m4_ready(app: App) -> bool:
	if not _m3_calm(app) or app.map_scene() == null:
		return false
	if app.get_viewport().gui_get_focus_owner() is LineEdit:
		app.hud().release_console_focus()
		var owner := app.get_viewport().gui_get_focus_owner()
		if owner is LineEdit:
			owner.release_focus()
	return not (app.get_viewport().gui_get_focus_owner() is LineEdit)


## The next M4 action, by the dice.
func _m4_step(rng: Rng, vp: SubViewport, app: App) -> void:
	if not _m4_ready(app):
		return
	match rng.randi_range(0, 11):
		0, 1:
			await _m4_study_open(rng, vp, app, KEY_I if rng.randi_range(0, 1) == 0 else KEY_L)
		2:
			await _m4_u_key(rng, vp, app)
		3, 4:
			await _m4_row_hover(rng, vp, app, rng.randi_range(0, 2))
		5, 6:
			await _m4_row_click(rng, vp, app)
		7:
			await _m4_chip(rng, vp, app, rng.randi_range(0, 1))
		8, 9:
			await _m4_tax(rng, vp, app)
		10:
			await _m4_card_cycle(rng, vp, app)
		_:
			await _m4_study_open(rng, vp, app, KEY_L, true)


## Whether a required M4 counter is still 0 late in the run: the M4.5 and M5 actions then wait (the coverage steps go first).
func _m4_coverage_due() -> bool:
	if not _m4 or _step_no < LATE_STEP:
		return false
	for key: String in M4_REQUIRED:
		if int(_n.get(key, 0)) == 0:
			return true
	return false


## The player's treasury is topped up (a developer gift, so a Begin on a card can be pressed and not refused for ducats); the
## step's digest check excuses it.
func _m4_fund(app: App) -> void:
	var game := Session.game
	if game != null and game.player != &"" and Session.dev_money(game.player, 5000):
		_dev_changed = true
		app.hud().refresh_economy()  # as the console does: the chip and the panels read the money again


## From FORCE_M4_STEP on, the first M4 action whose counter is still 0 (one a step, so the seed never passes empty). Begin and
## the pin need a card that Begin can be pressed on: the treasury is topped up first, and the counters retry every step.
func _m4_force(rng: Rng, vp: SubViewport, app: App) -> void:
	if not _m4_ready(app):
		return
	if int(_n["card_begins"]) == 0 or int(_n["card_pins"]) == 0:
		_m4_fund(app)
	if int(_n["study_i"]) == 0:
		await _m4_study_open(rng, vp, app, KEY_I)
	elif int(_n["study_l"]) == 0:
		await _m4_study_open(rng, vp, app, KEY_L)
	elif int(_n["tax_clicks"]) == 0:
		await _m4_tax(rng, vp, app)
	elif int(_n["u_keys"]) == 0:
		await _m4_u_key(rng, vp, app)
	elif int(_n["chip_clicks"]) == 0:
		await _m4_chip(rng, vp, app, 1)
	elif int(_n["chip_cards"]) == 0:
		await _m4_chip(rng, vp, app, 0)
	elif int(_n["row_hovers"]) == 0:
		await _m4_row_hover(rng, vp, app, 0)
	elif int(_n["row_clicks"]) == 0:
		await _m4_row_click(rng, vp, app)
	elif int(_n["card_begins"]) == 0:
		await _m4_row_hover(rng, vp, app, 1, 0)
	elif int(_n["card_pins"]) == 0:
		await _m4_row_hover(rng, vp, app, 2, 1)
	elif int(_n["card_escs"]) == 0:
		await _m4_row_hover(rng, vp, app, 1, 2)
	elif int(_n["orphan_cycles"]) == 0:
		await _m4_card_cycle(rng, vp, app)


## I or L: the study opens, the world hides, nothing changes; [ and ] (one page: nothing); maybe a click inside; I or Esc closes.
func _m4_study_open(rng: Rng, vp: SubViewport, app: App, key: Key, click: bool = false) -> void:
	_m4_note("study")
	var before := _m4_snapshot()
	_send_chord(vp, key)
	_bump("study_i" if key == KEY_I else "study_l")
	await _wait_frames(3)
	var study := app.stack().top() as Study
	assert_not_null(study, "%s: %s opens the study" % [_tag, OS.get_keycode_string(key)])
	if study == null:
		return
	_bump("studies")
	if key == KEY_L:
		assert_eq(study.current_page_id(), &"economy", "%s: L opens the Economy page" % _tag)
	assert_true(app.hides_world(), "%s: the study hides the world" % _tag)
	assert_false(app.world_host().visible, "%s: the world is hidden while the study is up" % _tag)
	_m4_assert_untouched(before, "opening the study")
	for _i: int in range(rng.randi_range(1, 2)):
		_send_chord(vp, KEY_BRACKETRIGHT if rng.randi_range(0, 1) == 0 else KEY_BRACKETLEFT)
		_bump("study_page_keys")
		await _wait_frames(1)
		assert_true(app.stack().top() is Study, "%s: the page keys keep the study" % _tag)
	_m4_assert_untouched(before, "[ and ] in the study")
	for _i: int in range(rng.randi_range(1, 2)):  # Ctrl+[ and Ctrl+]: the page's tabs (nothing on a page without tabs)
		_send_chord(vp, KEY_BRACKETRIGHT if rng.randi_range(0, 1) == 0 else KEY_BRACKETLEFT, true)
		_bump("study_tab_keys")
		await _wait_frames(1)
		assert_true(app.stack().top() is Study, "%s: the tab keys keep the study" % _tag)
	_m4_assert_untouched(before, "Ctrl+[ and Ctrl+] in the study")
	if click or rng.randi_range(0, 3) == 0:
		await _m4_study_click(rng, vp, app)
	await _m4_close_study(rng, vp, app)
	assert_true(app.world_host().visible, "%s: the world is back when the study closes" % _tag)
	assert_false(app.hides_world(), "%s: nothing hides the world after the study" % _tag)


func _m4_scroll_of(node: Node) -> ScrollContainer:
	var cur := node.get_parent()
	while cur != null:
		if cur is ScrollContainer:
			return cur as ScrollContainer
		cur = cur.get_parent()
	return null


func _m4_in_tax_row(node: Node) -> bool:
	var cur := node
	while cur != null:
		if cur.name == &"TaxLevels":
			return true
		cur = cur.get_parent()
	return false


## A click on a button of the open study: only the tax buttons may change the game.
func _m4_study_click(rng: Rng, vp: SubViewport, app: App) -> void:
	_m4_note("study click")
	var study := app.stack().top() as Study
	if study == null:
		return
	var buttons := _collect_clickable_buttons(study)
	if buttons.is_empty():
		return
	var btn := buttons[rng.randi_range(0, buttons.size() - 1)]
	var is_tax := _m4_in_tax_row(btn)
	var before := _m4_snapshot()
	if _m4_press(vp, btn):
		_bump("study_clicks")
		if is_tax:
			_bump("tax_clicks")
	await _wait_frames(3)
	if not is_tax:
		_m4_assert_untouched(before, "a click in the study")


## The study's tax buttons: a level set changes the game by set_tax alone; the same level or a refusal changes nothing.
func _m4_tax(rng: Rng, vp: SubViewport, app: App) -> void:
	_m4_note("tax")
	_send_chord(vp, KEY_L)
	_bump("study_l")
	await _wait_frames(3)
	var study := app.stack().top() as Study
	if study == null:
		return
	_bump("studies")
	var seg := study.find_child("TaxLevels", true, false) as Segmented
	if seg != null:
		var level := rng.randi_range(0, 2)
		var country := Countries.by_tag(Session.game, Session.game.player)
		var old := country.tax
		var before := _m4_snapshot()
		var btn := seg.button_for(level)
		var scroll := _m4_scroll_of(seg)
		if scroll != null:  # the page scrolls: bring the row into the window as a player would
			scroll.ensure_control_visible(btn)
			await _wait_frames(2)
		var rect := btn.get_global_rect()
		if rect.has_area() and Rect2(Vector2.ZERO, Vector2(vp.size)).has_point(rect.get_center()):
			_send_click(vp, rect.get_center(), MOUSE_BUTTON_LEFT)
		else:
			seg.select(level, true)  # still out of the window: the same change through the control
		_bump("tax_clicks")
		await _wait_frames(3)
		country = Countries.by_tag(Session.game, Session.game.player)
		if level == old:
			_m4_assert_untouched(before, "choosing the tax level already set")
		else:  # set_tax refuses only the level already set: a click on another level must change the tax, by one action
			assert_eq(country.tax, level, "%s: a click on the tax level %d sets it (it was %d)" % [_tag, level, old])
			assert_ne(Session.game.digest(), before["digest"], "%s: a changed tax changes the game" % _tag)
			assert_gt(Session.game.version, int(before["version"]), "%s: a changed tax is an action" % _tag)
			_bump("tax_changes")
	await _m4_close_study(rng, vp, app)


## U on a hex: the card opens (the game untouched) or a cheap work begins at once (the only change U may make).
func _m4_u_key(rng: Rng, vp: SubViewport, app: App) -> void:
	_m4_note("U")
	var hex := _m4_pick_hex(rng, rng.randi_range(0, 3) != 0)
	if hex == MapScene.NO_HEX:
		return
	app.map_scene().select_hex(hex)
	await _wait_frames(2)
	var before := _m4_snapshot()
	var begun := int(_n["works_begun"])
	_send_chord(vp, KEY_U)
	_bump("u_keys")
	await _wait_frames(3)
	var card := _m4_card(app)
	if card != null:
		_bump("u_cards")
		_m4_assert_untouched(before, "U opening the works card")
		await _m4_card_actions(rng, vp, app, card)
	elif Session.game.digest() != before["digest"]:
		assert_gt(int(_n["works_begun"]), begun, "%s: U changed the game without a work begun" % _tag)
		assert_lte(_m4_snapshot()["treasury"], before["treasury"], "%s: a work begun does not add ducats" % _tag)
	await _m4_close_cards(vp, app)


## What a player does on an open card: Begin (a click or Enter), pin, Esc. `act` picks one (-1: by the dice).
func _m4_card_actions(rng: Rng, vp: SubViewport, app: App, card: WorksPreview, act: int = -1) -> void:
	if act < 0:
		act = rng.randi_range(0, 3)
	var before := _m4_snapshot()
	var begun := int(_n["works_begun"])
	match act:
		0, 3:
			var begin_btn := card.card().begin_button()
			var pressed := false
			if act == 0:
				pressed = _m4_press(vp, begin_btn)
			elif begin_btn.is_visible_in_tree() and not begin_btn.disabled:
				_send_chord(vp, KEY_ENTER)
				pressed = true
			if pressed:
				_bump("card_begins")
			await _wait_frames(3)
			if int(_n["works_begun"]) == begun:
				_m4_assert_untouched(before, "a refused Begin")
			else:
				assert_lte(_m4_snapshot()["treasury"], before["treasury"], "%s: Begin does not add ducats" % _tag)
		1:
			var pin_btn := card.card().pin_button()
			if pin_btn.is_visible_in_tree():
				pin_btn.button_pressed = not pin_btn.button_pressed
				_bump("card_pins")
				await _wait_frames(2)
				assert_eq(card.pinned(), pin_btn.button_pressed, "%s: the pin button pins the card" % _tag)
				_m4_assert_untouched(before, "pinning the card")
		_:
			pass  # Esc is sent by the cleanup below
	await _m4_close_cards(vp, app)


## A row of the hex panel: the pointer enters (the card and the marks come, the game stays), maybe the card is pinned or held
## and handled, the pointer leaves. `mode` 0 hover and leave, 1 hold (Shift) then act, 2 pin then act; `act` as in
## _m4_card_actions.
func _m4_row_hover(rng: Rng, vp: SubViewport, app: App, mode: int, act: int = -1) -> void:
	_m4_note("row hover")
	var hex := _m4_pick_hex(rng, rng.randi_range(0, 3) != 0)
	if hex == MapScene.NO_HEX:
		return
	app.map_scene().select_hex(hex)
	await _wait_frames(2)
	var rows := app.hud().hex_panel().action_buttons()
	if rows.is_empty():
		return
	var before := _m4_snapshot()
	var begun := int(_n["works_begun"])
	var row := rows[rng.randi_range(0, rows.size() - 1)]
	var refused := row.disabled
	row.mouse_entered.emit()
	await _wait_frames(2)
	var card := _m4_card(app)
	if card != null:
		_bump("row_hovers")
		if refused:
			_bump("row_refused_hovers")
		assert_false(card.preview().is_empty(), "%s: the hovered row gives the card a preview" % _tag)
	_m4_assert_untouched(before, "hovering a row")
	if card != null and mode == 1:
		card.hold(true)
		row.mouse_exited.emit()
		await _wait_frames(2)
		assert_true(app.stack().has_screen(&"works_preview"), "%s: Shift holds the card while the pointer leaves" % _tag)
		_m4_assert_untouched(before, "the pointer leaving a held card")
		await _m4_card_actions(rng, vp, app, card, act)
		if is_instance_valid(card):
			card.hold(false)
	elif card != null and mode == 2:
		card.card().pin_button().button_pressed = true
		_bump("card_pins")
		await _wait_frames(2)
		assert_true(card.pinned(), "%s: the card is pinned" % _tag)
		# A second row beside the pinned card: two columns, the game untouched.
		var second := rows[rng.randi_range(0, rows.size() - 1)]
		second.mouse_entered.emit()
		await _wait_frames(2)
		_m4_assert_untouched(before, "a second row beside a pinned card")
		second.mouse_exited.emit()
		row.mouse_exited.emit()
		await _wait_frames(2)
		assert_true(app.stack().has_screen(&"works_preview"), "%s: a pinned card stays when the pointer leaves" % _tag)
		_m4_assert_untouched(before, "the pointer leaving a pinned card")
		if act == 1 or act == 2:
			card = _m4_card(app)
			if card != null:
				await _m4_card_actions(rng, vp, app, card, act)
	else:
		row.mouse_exited.emit()
		await _wait_frames(2)
		if card != null:
			assert_false(app.stack().has_screen(&"works_preview"), "%s: the card goes when the pointer leaves" % _tag)
		_m4_assert_untouched(before, "the pointer leaving a row")
	await _m4_close_cards(vp, app)
	if int(_n["works_begun"]) == begun:  # Begin on the card is the one thing that may change the game
		_m4_assert_untouched(before, "a row's hover, pin and Esc")


## A click on an enabled row: the card (Always, or an expensive work) or the work at once; only a begun, cancelled or cleared
## work changes the game, and a refusal leaves the treasury and the stores.
func _m4_row_click(rng: Rng, vp: SubViewport, app: App) -> void:
	_m4_note("row click")
	var hex := _m4_pick_hex(rng, rng.randi_range(0, 3) != 0)
	if hex == MapScene.NO_HEX:
		return
	app.map_scene().select_hex(hex)
	await _wait_frames(2)
	var rows: Array[Button] = []
	for button: Button in app.hud().hex_panel().action_buttons():
		if not button.disabled and button.is_visible_in_tree():
			rows.append(button)
	if rows.is_empty():
		return
	var row := rows[rng.randi_range(0, rows.size() - 1)]
	var before := _m4_snapshot()
	var unsaved := Session.unsaved_actions
	if rng.randi_range(0, 2) == 0:
		var modes: Array[String] = ["off", "always", "expensive"]
		app.settings().set_value("game/confirm_works", modes[rng.randi_range(0, 2)])
	if _m4_press_row(vp, row):
		_bump("row_clicks")
	await _wait_frames(3)
	var card := _m4_card(app)
	if card != null:
		await _m4_card_actions(rng, vp, app, card)
	elif Session.game.digest() != before["digest"]:
		assert_gt(Session.unsaved_actions, unsaved, "%s: a row changed the game without an accepted action" % _tag)
	await _m4_close_cards(vp, app)


## The chips: a click opens the study on Economy; the hover card is built from the chip and leaves the game alone.
func _m4_chip(rng: Rng, vp: SubViewport, app: App, mode: int) -> void:
	_m4_note("chip")
	var chips := app.hud().chips()
	if not chips.is_visible_in_tree():
		return
	var chip := chips.ducats_chip()
	if chips.stores_chip().is_visible_in_tree() and rng.randi_range(0, 1) == 0:
		chip = chips.stores_chip()
	var before := _m4_snapshot()
	if mode == 0:
		var key := str(chip.call("_get_tooltip", Vector2.ZERO))
		assert_eq(key, ResourceChip.CARD_KEY, "%s: a chip with a card asks for it on hover" % _tag)
		var card := chip.call("_make_custom_tooltip", key) as HoverCard
		assert_not_null(card, "%s: the chip makes its hover card" % _tag)
		if card != null:
			app.add_child(card)
			await _wait_frames(2)
			assert_gt(card.rows_container().get_child_count(), 0, "%s: the chip's card has lines" % _tag)
			card.queue_free()
			await _wait_frames(1)
			_bump("chip_cards")
		_m4_assert_untouched(before, "a chip's hover card")
		return
	if _m4_press(vp, chip):
		_bump("chip_clicks")
	await _wait_frames(3)
	var study := app.stack().top() as Study
	assert_not_null(study, "%s: a click on a chip opens the study" % _tag)
	if study != null:
		assert_eq(study.current_page_id(), &"economy", "%s: the chip opens Economy" % _tag)
		assert_true(app.hides_world(), "%s: the study hides the world" % _tag)
	_m4_assert_untouched(before, "a click on a chip")
	await _m4_close_study(rng, vp, app)


## The card opened and left again: no node is left behind (a warm cycle first, then three).
func _m4_card_cycle(rng: Rng, vp: SubViewport, app: App) -> void:
	_m4_note("card cycle")
	var hex := _m4_pick_hex(rng, true)
	if hex == MapScene.NO_HEX:
		return
	app.map_scene().select_hex(hex)
	await _wait_frames(3)
	if app.hud().hex_panel().action_buttons().is_empty():
		return
	var before := _m4_snapshot()
	var orphans := -1
	for round_no: int in 4:
		var rows := app.hud().hex_panel().action_buttons()
		if rows.is_empty():
			return
		var row := rows[0]
		row.mouse_entered.emit()
		await _wait_frames(2)
		row.mouse_exited.emit()
		await _wait_frames(2)
		await _m4_close_cards(vp, app)
		if round_no == 0:
			orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	await _wait_frames(3)
	var after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	assert_lte(after, orphans, "%s: three cards opened and closed leave no orphan node" % _tag)
	_m4_assert_untouched(before, "opening and closing cards")
	_bump("orphan_cycles")


## After every step: the world is hidden exactly while the study is up; the treasury and the stores are not negative; the
## marks are off the map when no card is up; the Ducats chip shows the treasury.
func _m4_assert_invariants(app: App, tag: String) -> void:
	if app.stack().has_screen(&"study"):
		assert_true(app.hides_world(), "%s: the study is up: the world is hidden" % tag)
		assert_false(app.world_host().visible, "%s: the study is up: the map is not drawn" % tag)
		assert_false(app.hud().visible, "%s: the study is up: the HUD is hidden" % tag)
		assert_true(app.wants_pause(), "%s: the study is up: the world is paused" % tag)
	elif app.stack().count() == 0 and not app.is_starting():
		assert_false(app.hides_world(), "%s: no study: the world shows" % tag)
		assert_true(app.world_host().visible, "%s: no study: the map is drawn" % tag)
	var game := Session.game
	if game == null or not game.has_countries():
		return
	for country: Country in game.countries:
		assert_gte(country.treasury, 0, "%s: the treasury of %s is never negative" % [tag, str(country.tag)])
		for good: int in country.stock.size():
			assert_gte(country.stock[good], 0, "%s: the stock %d of %s is never negative" % [tag, good, str(country.tag)])
	if game.player == &"" or app.map_scene() == null or app.is_starting():
		return
	if not app.stack().has_screen(&"works_preview"):
		assert_false(app.map_scene().preview_marks().shown(), "%s: no card, no marks on the map" % tag)
	if _m3_calm(app) and app.hud().chips().is_visible_in_tree():
		var player := Countries.by_tag(game, game.player)
		assert_eq(app.hud().chips().ducats_chip().value_label().text, Words.number(player.treasury),
			"%s: the Ducats chip shows the treasury" % tag)
	_bump("m4_checks")
	var legend := app.hud().mode_legend()
	var mode := app.map_scene().mode()
	var has_legend := mode == int(MapModes.Mode.YIELDS) or mode == int(MapModes.Mode.FOOD)
	var expect := has_legend and not app.hides_world() and app.hud().is_hud_visible()
	assert_eq(legend.visible, expect, "%s: the legend shows exactly in Yields or Food on the bare map" % tag)
	if expect:
		assert_eq(legend.mode(), mode, "%s: the legend is the legend of the mode on the map" % tag)
		var labels := legend.find_children("*", "Label", true, false)
		if not labels.is_empty():
			assert_eq((labels[0] as Label).text, MapModes.legend_title(mode), "%s: the legend's title is the mode's own" % tag)
	_bump("legend_checks")
