## The battle dock (docs/architecture/m7-build-spec.md 6.5, 9; M7 B22). A battle is fought in CombatFixture inputs with a fixed
## luck stream and kept in the game (as test_battle_view does); the dock shows it through BattleView.of only. Planted faults:
## a witness sees no tag, no key and no army id in any label; an unseen battle opens nothing; the ends of the stepper are
## disabled; Esc is left to the stack; Left, Right, Home and End step the days; the footer fits the dock's width.
extends GutTest

const SAV := &"SAV"
const MLO := &"MLO"

var _g: Game = null
var _hex: Vector2i = Vector2i.ZERO
var _dock: BattleDock = null


func before_each() -> void:
	_g = ArmyFixture.game()
	_hex = ArmyFixture.find_town(_g)
	Session.start_game(_g)
	_dock = BattleDock.new()
	_dock.theme = KitTheme.load_for(1.0)
	_dock.custom_minimum_size = Vector2(BattleDock.WIDTH, 720.0)
	add_child_autofree(_dock)
	watch_signals(_dock)


func after_each() -> void:
	Session.end_game()
	await get_tree().process_frame


## A battle record fought between `attacker` and `defender` (two Savoy companies against one of pikemen and one of knights),
## kept in the game and witnessed by `witnesses`.
func _battle(attacker: StringName, defender: StringName, witnesses: PackedStringArray) -> BattleRecord:
	var war := CombatFixture.war()
	var fighters := [CombatFixture.pikemen(101, 0), CombatFixture.pikemen(102, 0), CombatFixture.pikemen(201, 1),
		CombatFixture.knights(202, 1)]
	var input := CombatFixture.input_of(war, fighters, 0, false, false)
	for f: Dictionary in fighters:
		for ud: UnitDef in _g.defs.units:
			if String(ud.branch) == str(f["branch"]):
				f["kind"] = ud.id
				break
		f["army"] = 1 if int(f["side"]) == 0 else 2
	input["attacker"] = String(attacker)
	input["defender"] = String(defender)
	var rng := Rng.new()
	rng.seed_with(1480)
	var before: int = rng.get_state()
	var out: Dictionary = Combat.fight(war, input, rng)
	var r := BattleRecord.new()
	r.id = _g.next_record_id
	_g.next_record_id += 1
	r.turn = _g.turn
	r.hex = _hex
	r.name = "Battle of Test, 1480"
	r.year = 1480
	r.attacker = attacker
	r.defender = defender
	r.input = input.duplicate(true)
	r.luck_before = before
	r.frames.assign(out["frames"])
	r.end = out["end"]
	r.witnesses = witnesses
	_g.battle_records.append(r)
	return r


func _key(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	_dock._input(ev)


## Every Label, KitButton text, tooltip and accessibility name under the dock, as one array of strings.
func _all_words() -> PackedStringArray:
	var out := PackedStringArray()
	for node: Node in _dock.find_children("*", "", true, false):
		if node is Label:
			out.append((node as Label).text)
		if node is KitButton:
			out.append((node as KitButton).text)
		if node is Control:
			out.append((node as Control).tooltip_text)
			out.append((node as Control).accessibility_name)
	return out


func _button_text(text: String) -> KitButton:
	for node: Node in _dock.find_children("*", "KitButton", true, false):
		if (node as KitButton).text == text:
			return node as KitButton
	return null


func test_hidden_until_a_battle_the_viewer_sees_is_shown() -> void:
	assert_false(_dock.visible, "hidden at the start")
	assert_eq(_dock.shown_record(), BattleDock.NO_RECORD)
	var r := _battle(SAV, MLO, PackedStringArray())
	r.turn = _g.turn - 1
	assert_false(_dock.show_record(r.id), "P: an unseen foreign battle opens nothing")
	assert_false(_dock.visible)


func test_exact_viewer_sees_every_part_of_the_battle() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	assert_true(_dock.show_record(r.id), "the attacker sees the battle")
	assert_true(_dock.visible)
	assert_eq(_dock.shown_record(), r.id)
	assert_eq(_dock.day_count(), r.frames.size(), "the stepper counts the battle's days")
	assert_eq(_dock.shown_day(), r.frames.size(), "the last day is shown first")
	assert_eq(_dock.cartouche_text(), "Battle of Test, 1480", "the title is the battle's name")
	assert_eq(_dock.find_children("*", "BattlePicture", true, false).size(), 1, "the face-off picture")
	assert_eq(_dock.find_children("*", "DieFace", true, false).size(), 2, "a die a side")
	assert_eq(_dock.find_children("*", "TugBar", true, false).size(), 1, "the front-line tug bar")
	assert_true(_dock.find_children("*", "RegimentTile", true, false).size() >= 6, "three lanes a side at least")
	assert_true(_dock.result_text().contains("won in") or _dock.result_text().contains("draw"), "the result line")


func test_witness_sees_no_tag_no_key_and_no_id_in_any_label() -> void:
	var r := _battle(SAV, MLO, PackedStringArray([String(ArmyFixture.TAG)]))
	assert_true(_dock.show_record(r.id), "a witness sees the battle")
	for word: String in _all_words():
		assert_false(word.contains("SAV") or word.contains("MLO"), "P: no country tag in '%s'" % word)
		assert_false(word.to_lower().contains(" key") or word.to_lower().contains("army id"), "P: no id word in '%s'" % word)


func test_witness_stance_is_hidden_and_arms_only_for_a_known_side() -> void:
	var r := _battle(SAV, MLO, PackedStringArray([String(ArmyFixture.TAG)]))
	_dock.show_record(r.id)
	for word: String in _all_words():
		assert_false(word.begins_with("Fought on"), "P: a witness sees no stance")
	var arms := _dock.find_children("*", "CountryArms", true, false).size()
	assert_true(arms <= 2, "at most one arms a side")


func test_day_stepping_clamps_and_disables_the_ends() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	var days := r.frames.size()
	assert_gte(days, 2, "the battle lasts two days or more")
	_dock.show_record(r.id, 1)
	assert_eq(_dock.shown_day(), 1)
	assert_true(_button_text("<").disabled, "no day before the first")
	assert_false(_button_text(">").disabled, "a day after the first")
	_dock.step_day(1)
	assert_eq(_dock.shown_day(), 2)
	_dock.go_to_day(days)
	assert_true(_button_text(">").disabled, "no day after the last")
	assert_true(_button_text("End").disabled, "skip to the end does nothing at the end")
	_dock.step_day(1)
	assert_eq(_dock.shown_day(), days, "a step past the last day stays on it")
	_dock.step_day(-1)
	assert_eq(_dock.shown_day(), days - 1)


func test_keys_step_jump_and_play_belong_to_the_dock() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	var days := r.frames.size()
	_dock.show_record(r.id, 1)
	_key(KEY_RIGHT)
	assert_eq(_dock.shown_day(), 2, "Right steps forward")
	_key(KEY_LEFT)
	assert_eq(_dock.shown_day(), 1, "Left steps back")
	_key(KEY_END)
	assert_eq(_dock.shown_day(), days, "End goes to the last day")
	_key(KEY_HOME)
	assert_eq(_dock.shown_day(), 1, "Home goes to the first day")
	_key(KEY_LEFT)
	assert_eq(_dock.shown_day(), 1, "Left at the first day stays")


func test_play_runs_the_days_and_stops_at_the_last_one() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	var days := r.frames.size()
	_dock.show_record(r.id, 1)
	_dock.play()
	assert_true(_dock.is_playing(), "Play starts the clock")
	assert_true(_button_text("Play").disabled, "Play is off while it runs")
	for i: int in days:
		_dock._on_tick()
	assert_false(_dock.is_playing(), "the play stops at the last day")
	assert_eq(_dock.shown_day(), days)
	assert_false(_button_text("Play").disabled, "Play comes back at the end")


func test_stepping_by_hand_stops_a_running_play() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	_dock.show_record(r.id, 1)
	_dock.play()
	_dock.step_day(1)
	assert_false(_dock.is_playing(), "a hand step stops the play")


func test_escape_is_left_to_the_stack_and_the_close_button_finishes() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	_dock.show_record(r.id)
	assert_false(_dock.back(), "Esc is the stack's: back() does not consume it")
	_dock._frame.closed.emit()
	assert_signal_emitted_with_parameters(_dock, "finished", [&"close"])


func test_look_at_button_asks_for_the_battle_hex() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	_dock.show_record(r.id)
	_button_text("Show the place").pressed.emit()
	assert_signal_emitted_with_parameters(_dock, "look_at_requested", [_hex])


## Pushes a key press and its release through the viewport, as the engine does (push_input reaches _input, the GUI and the
## focused button).
func _press(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		get_viewport().push_input(ev)


## Gives the focus to a footer button and checks that it has it.
func _focus(text: String) -> KitButton:
	var btn := _button_text(text)
	assert_not_null(btn, "the button '%s' exists" % text)
	btn.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), btn, "'%s' has the focus" % text)
	return btn


func test_enter_presses_the_focused_next_button_and_does_not_play() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	assert_gte(r.frames.size(), 3, "the battle lasts three days or more")
	_dock.show_record(r.id, 2)
	await get_tree().process_frame
	_focus(">")
	_press(KEY_ENTER)
	assert_eq(_dock.shown_day(), 3, "Enter on Next steps one day")
	assert_false(_dock.is_playing(), "Enter on Next does not start Play")


func test_enter_presses_the_focused_previous_button() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	_dock.show_record(r.id, 2)
	await get_tree().process_frame
	_focus("<")
	_press(KEY_ENTER)
	assert_eq(_dock.shown_day(), 1, "Enter on Previous steps back")
	assert_false(_dock.is_playing())


func test_enter_presses_the_focused_end_button() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	_dock.show_record(r.id, 2)
	await get_tree().process_frame
	_focus("End")
	_press(KEY_ENTER)
	assert_eq(_dock.shown_day(), r.frames.size(), "Enter on End skips to the last day")
	assert_false(_dock.is_playing(), "Enter on End does not start Play")


func test_enter_presses_the_focused_look_at_button() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	_dock.show_record(r.id, 1)
	await get_tree().process_frame
	_focus("Show the place")
	_press(KEY_ENTER)
	assert_signal_emitted_with_parameters(_dock, "look_at_requested", [_hex], 0)
	assert_false(_dock.is_playing(), "Enter on another button does not play")


func test_enter_plays_when_play_or_nothing_has_the_focus() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	_dock.show_record(r.id, 1)
	await get_tree().process_frame
	_focus("Play")
	_press(KEY_ENTER)
	assert_true(_dock.is_playing(), "Enter on Play plays")
	_dock.stop()
	get_viewport().gui_release_focus()
	_press(KEY_ENTER)
	assert_true(_dock.is_playing(), "Enter with no focus plays")
	_dock.stop()


## A battle no longer kept: a chronicle entry with no record, witnessed by the player.
func _gone_id() -> int:
	var id := 9999
	_g.chronicle.entries.append({"kind": "battle_ended", "record": id, "tag": ArmyFixture.TAG,
		"attacker": ArmyFixture.TAG, "defender": SAV, "winner": ArmyFixture.TAG, "how": "broke", "cause": "centre",
		"days": 2, "hex": _hex, "name": "Battle of Gone, 1480", "year": 1480,
		"killed": {String(ArmyFixture.TAG): 40, String(SAV): 60}, "wounded": {String(ArmyFixture.TAG): 30, String(SAV): 20}})
	return id


func test_show_record_before_the_dock_is_in_the_tree_does_not_crash() -> void:
	var dock := (load("res://shell/screens/battle_dock.tscn") as PackedScene).instantiate() as BattleDock
	autofree(dock)
	assert_false(dock.show_record(BattleDock.NO_RECORD), "no record: nothing is shown, and nothing crashes")
	var unseen := _battle(SAV, MLO, PackedStringArray())
	unseen.turn = _g.turn - 1
	assert_false(dock.show_record(unseen.id), "an unseen record: nothing is shown, and nothing crashes")
	assert_true(dock.show_record(_gone_id()), "a gone record shows its totals before the tree")
	assert_eq(dock.shown_record(), 9999)
	assert_false(dock.show_record(12345), "an unknown record is refused before the tree too")


func test_footer_and_title_fit_the_dock_width() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	_dock.show_record(r.id)
	_dock.size = Vector2(BattleDock.WIDTH, 720.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gte(BattleDock.WIDTH, float(Tokens.PANEL_W), "the dock is at least a panel wide")
	assert_lte(_dock._frame.footer().get_combined_minimum_size().x, BattleDock.WIDTH, "the stepper fits")
	for node: Node in _dock.find_children("*", "KitButton", true, false):
		var btn := node as KitButton
		assert_gt(btn.size.x, 0.0, "%s is laid out" % btn.text)
