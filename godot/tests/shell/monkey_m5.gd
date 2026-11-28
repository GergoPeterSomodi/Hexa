## The M5 part of the UI monkey (test_ui_monkey.gd extends this, which extends MonkeyM45): the people's inputs (m5-build-spec.md
## sections 6 and 9). Key 5 (the Food mode and its legend), clicks on the People and Food chips (they open the People page) and
## their hover cards, the People page's rows, Look there and Show on the map (Food), and the console's `people c r N`. Invariants:
## the digest, the version, the Stats and the snapshot are unchanged by the page, the chips' cards and the Food mode (only
## `people c r N`, the dev actions, Begin, set_tax and a Space change them); the legend shows exactly in Yields or Food on the bare
## map with that mode's own title (MonkeyM4's per-step invariant); the People chip shows the player's people. Split out of the
## monkey to keep it under the lint's 1,200 lines.
class_name MonkeyM5
extends MonkeyM45

## An M5 action a seed must do runs from this step on when its counter is still 0 (after the M4.5 ones).
const FORCE_M5_STEP := 260
## The M5 counters a seed must raise above 0 (so its invariants cannot pass empty).
const M5_REQUIRED: Array[String] = [
	"m5_food_keys", "m5_chip_clicks", "m5_chip_cards", "m5_people_page", "m5_page_actions", "m5_console", "m5_checks",
]
## The M5 actions are on (a country game with the people).
var _m5: bool = false


## The next M5 action, by the dice.
func _m5_step(rng: Rng, vp: SubViewport, app: App) -> void:
	if not _m4_ready(app):
		return
	_m4_note("m5")
	match rng.randi_range(0, 8):
		0, 1:
			await _m5_food_key(rng, vp, app)
		2, 3:
			await _m5_chip(rng, vp, app, true)
		4:
			await _m5_chip(rng, vp, app, false)
		5, 6:
			await _m5_page(rng, vp, app)
		_:
			await _m5_console(rng, app)


## From FORCE_M5_STEP on, the first M5 action whose counter is still 0 (one a step, so a seed never passes empty).
func _m5_force(rng: Rng, vp: SubViewport, app: App) -> void:
	if not _m4_ready(app):
		return
	if int(_n["m5_food_keys"]) == 0:
		await _m5_food_key(rng, vp, app)
	elif int(_n["m5_chip_clicks"]) == 0:
		await _m5_chip(rng, vp, app, true)
	elif int(_n["m5_chip_cards"]) == 0:
		await _m5_chip(rng, vp, app, false)
	elif int(_n["m5_people_page"]) == 0 or int(_n["m5_page_actions"]) == 0:
		await _m5_page(rng, vp, app, true)
	elif int(_n["m5_console"]) == 0:
		await _m5_console(rng, app)


# ----- key 5 ----------------------------------------------------------------------------------------------------------------------


## Key 5 (Food: its legend shows with its own title), the pointer over some land, then a key of another mode (no legend).
func _m5_food_key(rng: Rng, vp: SubViewport, app: App) -> void:
	var before := _m45_snap()
	_send_chord(vp, KEY_5)
	_bump("m5_food_keys")
	await _wait_frames(3)
	if app.hud().is_hud_visible() and not app.hides_world():  # H hides the HUD
		assert_eq(app.map_scene().mode(), int(MapModes.Mode.FOOD), "%s: key 5 shows the Food mode" % _tag)
		assert_true(app.hud().mode_legend().visible, "%s: Food: the legend shows" % _tag)
		_bump("m5_checks")
	for _i: int in range(rng.randi_range(1, 3)):
		_m45_move(vp, Vector2(float(rng.randi_range(200, vp.size.x - 200)), float(rng.randi_range(120, vp.size.y - 120))))
		await _wait_frames(2)
	_m45_untouched(before, "key 5 and the pointer over the map")
	if rng.randi_range(0, 2) != 0:
		_send_chord(vp, [KEY_1, KEY_2, KEY_3, KEY_4][rng.randi_range(0, 3)] as Key)
		await _wait_frames(3)
	_m45_untouched(before, "a map mode key")


# ----- the chips ------------------------------------------------------------------------------------------------------------------


## A click on the People or Food chip opens the People page; or (`click` false) their hover cards are built from the chips.
func _m5_chip(rng: Rng, vp: SubViewport, app: App, click: bool) -> void:
	var chips := app.hud().chips()
	if not chips.is_visible_in_tree():
		return
	var candidates: Array[ResourceChip] = []
	for chip: ResourceChip in [chips.people_chip(), chips.food_chip()]:
		if chip.is_visible_in_tree():
			candidates.append(chip)
	if candidates.is_empty():
		return
	var chip := candidates[rng.randi_range(0, candidates.size() - 1)]
	var before := _m45_snap()
	if not click:
		var key := str(chip.call("_get_tooltip", Vector2.ZERO))
		assert_eq(key, ResourceChip.CARD_KEY, "%s: a People or Food chip asks for its card on hover" % _tag)
		var card := chip.call("_make_custom_tooltip", key) as HoverCard
		assert_not_null(card, "%s: the chip makes its hover card" % _tag)
		if card != null:
			app.add_child(card)
			await _wait_frames(2)
			assert_gt(card.rows_container().get_child_count(), 0, "%s: the chip's card has lines" % _tag)
			card.queue_free()
			await _wait_frames(1)
			_bump("m5_chip_cards")
		_m45_untouched(before, "a People or Food chip's hover card")
		return
	if _m4_press(vp, chip):
		_bump("m5_chip_clicks")
	await _wait_frames(3)
	var study := app.stack().top() as Study
	assert_not_null(study, "%s: a click on the People or Food chip opens the study" % _tag)
	if study != null:
		assert_eq(study.current_page_id(), &"people", "%s: the chip opens the People page" % _tag)
		assert_true(app.hides_world(), "%s: the study hides the world" % _tag)
	_m45_untouched(before, "a click on the People or Food chip")
	await _m4_close_study(rng, vp, app)


# ----- the People page ------------------------------------------------------------------------------------------------------------


## The People page by its keys, then a click on a row of the towns table, the span, Look there or Show on the map (Food, with its
## legend). The page changes nothing.
func _m5_page(rng: Rng, vp: SubViewport, app: App, force: bool = false) -> void:
	var before := _m45_snap()
	var study := await _m45_goto(vp, app, &"people", 0)
	if study == null:
		return
	_bump("m5_people_page")
	await _wait_frames(2)
	var page := study.current_page() as PagePeople
	assert_not_null(page, "%s: the People page is up" % _tag)
	if page == null:
		await _m4_close_study(rng, vp, app)
		return
	var tables := _m45_tables(app)
	if not tables.is_empty():
		var table := tables[0]
		var root := table.tree().get_root()
		if root != null and root.get_child_count() > 0:
			var item := root.get_child(rng.randi_range(0, root.get_child_count() - 1))
			var at := table.tree().get_global_rect().position + table.tree().get_item_area_rect(item, 0).get_center()
			if table.tree().get_global_rect().has_point(at) and Rect2(Vector2.ZERO, Vector2(vp.size)).has_point(at):
				_send_click(vp, at, MOUSE_BUTTON_LEFT)
			else:
				table.select_id(int(table.sorted_ids()[0]))
			_bump("m5_page_actions")
			await _wait_frames(2)
	_m45_untouched(before, "a click on a row of the People page")
	var span := page.get_node_or_null("Top/Span") as Segmented
	if span != null and span.visible and rng.randi_range(0, 2) == 0 and not force:
		_m4_press(vp, span.button_for(&"40" if rng.randi_range(0, 1) == 0 else &"12"))
		await _wait_frames(2)
		_m45_untouched(before, "the span of the People page")
	if app.stack().top() is Study and (force or rng.randi_range(0, 1) == 0):
		var show := force or rng.randi_range(0, 1) == 0
		var button := page.find_child("ShowOnMap" if show else "Look", true, false) as BaseButton
		var scroll := _m4_scroll_of(button) if button != null else null
		if scroll != null:
			scroll.ensure_control_visible(button)
			await _wait_frames(1)
		if _m4_press(vp, button):
			_bump("m5_page_actions")
			await _wait_frames(3)
			if app.stack().has_screen(&"study"):  # the click missed (a clipped or covered button): the signal says the same
				button.pressed.emit()
				await _wait_frames(3)
			if show:
				assert_eq(app.map_scene().mode(), int(MapModes.Mode.FOOD), "%s: Show on the map leaves the map in Food" % _tag)
				if app.hud().is_hud_visible():  # H hides the HUD, the legend with it
					assert_true(app.hud().mode_legend().visible, "%s: and the Food legend shows" % _tag)
			assert_false(app.stack().has_screen(&"study"), "%s: the study closes" % _tag)
	_m45_untouched(before, "Look there or Show on the map")
	if _m45_study_of(app) != null:
		await _m4_close_study(rng, vp, app)


# ----- the console ------------------------------------------------------------------------------------------------------------------


## `people c r N` on one of the player's hexes through the console (a developer command: the digest may move). The answer is
## "Done" and the hex then holds N, or "Refused" and nothing moved; a malformed line only prints its usage and changes nothing.
func _m5_console(rng: Rng, app: App) -> void:
	var console := app.hud().debug_overlay().console()
	if console == null:
		return
	var game := Session.game
	var hex := _m4_pick_hex(rng, true)
	if hex == MapScene.NO_HEX:
		return
	var i := game.map.index_of(hex)
	var before := int(game.state.people[i])
	var digest := game.digest()
	var wanted := rng.randi_range(0, 3000)
	if rng.randi_range(0, 5) == 0:
		console.submit("people %d %d" % [hex.x, hex.y])
		assert_eq(game.digest(), digest, "%s: a malformed people line changes nothing" % _tag)
		_bump("m5_console")
		return
	console.submit("people %d %d %d" % [hex.x, hex.y, wanted])
	await _wait_frames(2)
	var answer := console.output_lines()[console.output_lines().size() - 1]
	_bump("m5_console")
	if answer.begins_with("Done"):
		_dev_changed = true
		assert_eq(int(game.state.people[i]), wanted, "%s: `people` leaves N people at the hex" % _tag)
	else:
		assert_eq(int(game.state.people[i]), before, "%s: a refused `people` changes nothing" % _tag)
		assert_eq(game.digest(), digest, "%s: a refused `people` leaves the digest" % _tag)
	_bump("m5_checks")


# ----- after every step ---------------------------------------------------------------------------------------------------------------


## The People chip shows the player's people and no hex holds a negative number.
func _m5_assert_invariants(app: App, tag: String) -> void:
	var game := Session.game
	if game == null or not game.has_countries() or game.player == &"" or app.is_starting() or app.map_scene() == null:
		return
	var negative := PackedStringArray()
	for i: int in game.state.people.size():
		if int(game.state.people[i]) < 0:
			negative.append(str(game.map.hex_of(i)))
	assert_eq(", ".join(negative), "", "%s: no hex holds a negative number of people" % tag)
	if _m3_calm(app) and app.hud().chips().is_visible_in_tree() and app.hud().chips().people_chip().is_visible_in_tree():
		var card := PeopleCards.people(game, game.player)
		if not card.is_empty():
			assert_eq(app.hud().chips().people_chip().value_label().text, Words.number(int(card["value"])),
				"%s: the People chip shows the people" % tag)
			_bump("m5_checks")
