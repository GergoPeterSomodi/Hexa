## The war part of the army panel (docs/architecture/m7-build-spec.md 6.8; M7 B26; ArmyWar in shell/panels/army_war.gd): the standing
## (Hold | Withdraw through set_standing), the morale and its refusal, the siege of a besieging army and its Storm button, the battle
## and the last battle with "Open the battle" (battle_requested with the record id). Every enabled state and reason equals the rules'
## check; a click goes through Session.act; the parts fit the dock width; the controls take the keyboard. Planted faults: a Storm
## button that is enabled against storm_check; a standing change that does not reach Session.act; an "Open the battle" with no record.
extends GutTest

const PANEL := "res://shell/panels/army_panel.tscn"
const TAG := ArmyFixture.TAG

var _g: Game
var _panel: ArmyPanel = null


func before_each() -> void:
	_g = ArmyFixture.game()
	Session.start_game(_g)
	_panel = (load(PANEL) as PackedScene).instantiate() as ArmyPanel
	_panel.theme = KitTheme.load_for(1.0)
	add_child_autofree(_panel)
	watch_signals(_panel)


func after_each() -> void:
	Session.end_game()
	await get_tree().process_frame


func _war() -> ArmyWar:
	for node: Node in _panel.body().find_children("*", "ArmyWar", true, false):
		return node as ArmyWar
	return null


## A fortress of an enemy at war with Genoa, garrisoned; Genoa's army of three companies on it, besieging it (the siege as the
## sieges phase leaves it). {army: Army, hex: Vector2i}; the test fails when the 1480 map has none.
func _siege_set_up() -> Dictionary:
	var enemy := WarFixture.neighbour_of(_g, TAG)
	WarFixture.at_war(_g, enemy, TAG)
	var fort := ArmyFixture.NO_HEX
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if Occupation.fortress_level(_g, hex) > 0 and Occupation.garrison_of(_g, hex) > 0 \
				and Occupation.controller_tag(_g, hex) == enemy:
			fort = hex
			break
	assert_ne(fort, ArmyFixture.NO_HEX, "an enemy fortress with a garrison exists on the 1480 map")
	var a := ArmyFixture.army(_g, TAG, fort, 0, 3)
	var s := Siege.new()
	s.hex = fort
	s.besieger = TAG
	s.progress = 3
	s.seasons = 1
	s.name = "Siege of Test, 1480"
	s.started_turn = _g.turn
	_g.sieges.append(s)
	_g.version += 1
	return {"army": a, "hex": fort}


func _show(a: Army) -> void:
	_panel.show_army(a.id)
	await get_tree().process_frame


func _needed_width(btn: KitButton) -> float:
	var font := btn.get_theme_font(&"font")
	var font_size := btn.get_theme_font_size(&"font_size")
	var need := font.get_string_size(btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if btn.icon != null:
		need += float(btn.icon.get_width()) + float(btn.get_theme_constant(&"h_separation"))
	var cap := btn.embedded_key_cap()
	if cap != null and cap.visible:
		need += cap.get_combined_minimum_size().x
	var style := btn.get_theme_stylebox(&"normal")
	if style != null:
		need += style.get_minimum_size().x
	return need


func test_a_besieging_army_shows_its_siege_and_a_storm_button() -> void:
	var set_up := _siege_set_up()
	await _show(set_up.army)
	var war := _war()
	assert_not_null(war, "the army panel carries the war part")
	assert_not_null(war.storm_button(), "a besieging army has a Storm button")
	var texts: Array[String] = []
	for node: Node in war.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	assert_true(texts.any(func(t: String) -> bool: return t.begins_with("Besieging ")), "the siege line: Besieging ...")


func test_the_storm_button_is_enabled_exactly_when_storm_check_allows() -> void:
	var set_up := _siege_set_up()
	await _show(set_up.army)
	var btn := _war().storm_button()
	var verdict := Session.check("storm", {"army": set_up.army.id, "goal": set_up.hex})
	assert_eq(btn.disabled, not bool(verdict["ok"]), "the button's state is the check's")
	if not bool(verdict["ok"]):
		assert_eq(btn.reason_text(), str(verdict["reason"]), "a refused button carries the check's reason")


func test_a_storm_click_goes_through_session_act() -> void:
	var set_up := _siege_set_up()
	await _show(set_up.army)
	var btn := _war().storm_button()
	var verdict := Session.check("storm", {"army": set_up.army.id, "goal": set_up.hex})
	btn.pressed.emit()
	var army := Armies.by_id(_g, set_up.army.id)
	if bool(verdict["ok"]):
		assert_eq(army.order, Army.ORDER_STORM, "the storm is ordered through the rules")
	else:
		assert_ne(army.order, Army.ORDER_STORM, "a refused storm changes nothing")
		assert_eq(_war().reason_text(), str(verdict["reason"]).substr(0, 1).to_upper() + str(verdict["reason"]).substr(1) + ".",
			"and its reason shows")


func test_the_standing_segments_match_the_checks() -> void:
	var set_up := _siege_set_up()
	await _show(set_up.army)
	var seg := _war().standing_segment()
	var now := _war().standing_id()
	for id: String in ["hold", "withdraw"]:
		if id == now:
			continue
		var verdict := Session.check("set_standing", {"army": set_up.army.id, "standing": id})
		assert_eq(not seg.button_for(id).disabled, bool(verdict["ok"]), "%s is enabled as the check says" % id)


func test_a_standing_change_goes_through_session_act() -> void:
	var set_up := _siege_set_up()
	await _show(set_up.army)
	var verdict := Session.check("set_standing", {"army": set_up.army.id, "standing": "withdraw"})
	assert_true(bool(verdict["ok"]), "Withdraw is allowed for a fresh army")
	_war().standing_segment().select("withdraw", true)
	assert_eq(Armies.by_id(_g, set_up.army.id).standing, Army.STANDING_WITHDRAW, "the army now withdraws, set by the rules")


func test_a_shaken_army_says_so_in_reason() -> void:
	var set_up := _siege_set_up()
	for u: Unit in set_up.army.units:
		u.morale = 200
	_g.version += 1
	await _show(set_up.army)
	var said := false
	for node: Node in _war().find_children("*", "Label", true, false):
		if (node as Label).visible and (node as Label).text.begins_with("Too shaken to attack"):
			said = true
	assert_true(said, "the morale refusal is a Reason line of the war part")


func test_the_battle_button_carries_the_record_id() -> void:
	var war := ArmyWar.new()
	add_child_autofree(war)
	watch_signals(war)
	war.fill(_g, _data({"battle": {"name": "Battle of Test, 1480", "hex": Vector2i(1, 1)},
		"last_battle": {"record": 7, "name": "Battle of Test, 1480", "result": "won"}}))
	var buttons := war.open_buttons()
	assert_eq(buttons.size(), 1, "one Open the battle button")
	assert_false(buttons[0].disabled, "a battle with its record opens")
	buttons[0].pressed.emit()
	assert_signal_emitted_with_parameters(war, "battle_requested", [7])


func test_a_battle_with_no_record_yet_cannot_open() -> void:
	var war := ArmyWar.new()
	add_child_autofree(war)
	war.fill(_g, _data({"battle": {"name": "Battle of Test, 1480", "hex": Vector2i(1, 1)},
		"last_battle": {"record": 7, "name": "Battle of Other, 1479", "result": "lost"}}))
	var buttons := war.open_buttons()
	assert_true(buttons[0].disabled, "no record for this battle: the button is off")
	assert_eq(buttons[0].reason_text(), ArmyWar.NO_RECORD_REASON)


func test_the_last_battle_links_to_its_record() -> void:
	var war := ArmyWar.new()
	add_child_autofree(war)
	watch_signals(war)
	war.fill(_g, _data({"last_battle": {"record": 4, "name": "Battle of Test, 1480", "result": "won"}}))
	assert_eq(war.open_buttons().size(), 1, "the last battle has its link")
	war.open_buttons()[0].pressed.emit()
	assert_signal_emitted_with_parameters(war, "battle_requested", [4])


func test_company_words_are_the_morale_rank_and_experience() -> void:
	assert_eq(ArmyWar.company_words({"morale_word": "Steady", "rank_name": "Veteran", "xp": 40}), "Steady · Veteran · 40 xp")
	assert_eq(ArmyWar.company_words({"xp": 0}), "0 xp", "a company with no rank name shows its experience alone")


func test_the_war_part_fits_the_dock_width() -> void:
	var set_up := _siege_set_up()
	_panel.size = Vector2(Tokens.PANEL_W, 720)
	await _show(set_up.army)
	await get_tree().process_frame
	await get_tree().process_frame
	var war := _war()
	for node: Node in war.find_children("*", "KitButton", true, false):
		var btn := node as KitButton
		assert_gt(btn.size.x, 40.0, "%s is laid out" % btn.text)
		assert_lte(_needed_width(btn), btn.size.x + 0.5, "%s fits its text, icon and key cap" % btn.text)
	for node: Node in war.find_children("*", "Label", true, false):
		var label := node as Label
		if label.visible:
			assert_lte(label.size.x, float(Tokens.PANEL_W) + 0.5, "%s is no wider than the dock" % label.text)


func test_the_war_controls_take_the_keyboard_and_no_focus_on_show() -> void:
	var set_up := _siege_set_up()
	await _show(set_up.army)
	assert_eq(_war().storm_button().focus_mode, Control.FOCUS_ALL, "Storm is reached by Tab")
	assert_eq(_war().standing_segment().button_for("withdraw").focus_mode, Control.FOCUS_ALL, "Withdraw is reached by Tab")
	assert_null(get_viewport().gui_get_focus_owner(), "showing the panel takes no focus")


## The data ArmyWar.fill reads: the fields ArmyView.panel gives an own army, with the given battle parts.
func _data(parts: Dictionary) -> Dictionary:
	var data := {"id": 1, "standing": "hold", "morale": 1000, "morale_text": "Morale 100 %", "morale_word": "Steady",
		"too_shaken": false, "battle": {}, "siege": {}, "storm_verdict": {}, "storm_word": "", "last_battle": {}}
	data.merge(parts, true)
	return data


func test_a_lifted_siege_removes_the_storm_and_the_siege_line() -> void:
	var set_up := _siege_set_up()
	await _show(set_up.army)
	assert_not_null(_war().storm_button(), "a besieging army has Storm")
	_g.sieges.clear()
	_g.version += 1
	Events.siege_lifted.emit(set_up.hex, TAG, &"lifted")
	await get_tree().process_frame
	assert_null(_war().storm_button(), "the lifted siege takes Storm away")
	var besieging := false
	for node: Node in _war().find_children("*", "Label", true, false):
		if (node as Label).text.begins_with("Besieging "):
			besieging = true
	assert_false(besieging, "and its siege line")


func test_a_siege_progress_signal_updates_the_siege_line() -> void:
	var set_up := _siege_set_up()
	await _show(set_up.army)
	var s: Siege = _g.sieges[0]
	s.progress = 5
	_g.version += 1
	Events.siege_progress.emit(set_up.hex, TAG, 5, s.progress)
	await get_tree().process_frame
	var shown := false
	for node: Node in _war().find_children("*", "Label", true, false):
		if (node as Label).text.begins_with("Besieging ") and (node as Label).text.ends_with("5 of %d" % Occupation.siege_need(_g, set_up.hex)):
			shown = true
	assert_true(shown, "the siege line reads the new progress")


func test_a_freed_army_panel_leaves_no_war_listener() -> void:
	var before := Events.siege_progress.get_connections().size()
	var panel := (load(PANEL) as PackedScene).instantiate() as ArmyPanel
	panel.theme = KitTheme.load_for(1.0)
	add_child(panel)
	assert_gt(Events.siege_progress.get_connections().size(), before, "it listens while in the tree")
	remove_child(panel)
	assert_eq(Events.siege_progress.get_connections().size(), before, "leaving the tree drops its listeners")
	panel.free()
