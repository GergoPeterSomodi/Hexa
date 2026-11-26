## ArmyPanel and the Armies row of CountryPanel (docs/architecture/m6-build-spec.md 6.5, 6.10, 9; L18, issue #208).
## North Italy: Genoa (GEN) is the player, Savoy (SAV) the foreign country. The panel shows an army through ArmyView.panel;
## its buttons take their enabled state and reason from the checks (Session.check); a click goes through Session.act.
## A disband of several companies is one Session.act (the rules take all or none). Planted faults: an unseen foreign army
## shows no panel; a disband click that does not reach Session.act leaves the army; a half disband leaves a company.
extends GutTest

const PANEL := "res://shell/panels/army_panel.tscn"
const COUNTRY := "res://shell/panels/country_panel.tscn"
const SAV := &"SAV"
const HOLDS := "the army holds already"

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


func _unseen_land() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.land[i] == 1 and not Knowledge.sees(_g, ArmyFixture.TAG, hex):
			return hex
	return ArmyFixture.NO_HEX


## The verdict-carrying button of an action in the panel.
func _button(action: String) -> KitButton:
	return _panel.action_button(action)


func _treasury() -> int:
	return Countries.by_tag(_g, ArmyFixture.TAG).treasury


func _own_army(count: int = 2) -> Army:
	return ArmyFixture.army(_g, ArmyFixture.TAG, ArmyFixture.find_town(_g), 0, count)


## An army of the player's on the town, its companies raised this season (refunded in full) or before it (not).
func _army_raised(now: Array) -> Army:
	var hex := ArmyFixture.find_town(_g)
	var a := Armies.create(_g, ArmyFixture.TAG, hex, "Army of test")
	for raised_now: bool in now:
		Armies.add_units(_g, a, 0, 1, _g.turn if raised_now else _g.turn - 1, hex, 10, {})
	return a


## A listener that keeps the Confirm in the tree, as the App does when it pushes it.
func _listen_and_keep(into: Array) -> void:
	_panel.confirm_requested.connect(func(screen: Screen) -> void:
		add_child_autofree(screen)
		into.append(screen))


func test_hidden_until_an_army_is_shown() -> void:
	assert_false(_panel.visible, "hidden at the start")
	assert_eq(_panel.shown_army(), -1)
	assert_eq(_panel.mouse_filter, Control.MOUSE_FILTER_STOP, "a click on the panel never reaches the map")
	assert_eq(_panel.custom_minimum_size.x, float(Tokens.PANEL_W))


func test_own_army_shows_its_head_order_companies_and_buttons() -> void:
	var a := _own_army(2)
	_panel.show_army(a.id)
	assert_true(_panel.visible)
	assert_eq(_panel.shown_army(), a.id)
	assert_eq(_panel.cartouche().text, a.name, "the cartouche is the army's name")
	assert_not_null(_button("halt"), "Hold")
	assert_not_null(_button("continue_march"), "Continue march")
	assert_not_null(_button("split_army"), "Split off")
	assert_not_null(_button("disband"), "Disband")
	assert_null(_button("merge_armies"), "no Join row with no other army of yours here")


func test_hold_and_continue_follow_their_checks() -> void:
	var a := _own_army()
	_panel.show_army(a.id)
	assert_false(_button("halt").disabled, "a holding army can be told to hold: enabled")
	assert_true(_button("continue_march").disabled, "no march to continue")
	assert_eq(_button("continue_march").reason_text(), "no march to continue")
	assert_eq(_button("continue_march").reason_text(), str(Session.check("continue_march", {"army": a.id})["reason"]))

	Armies.set_order(_g, a, Army.ORDER_HOLD, ArmyFixture.NO_HEX, PackedInt32Array())
	_panel.refresh()
	assert_true(_button("halt").disabled, "already holding: disabled")
	assert_eq(_button("halt").reason_text(), HOLDS)


func test_split_needs_a_ticked_company_and_a_company_left_behind() -> void:
	var a := _own_army(2)
	_panel.show_army(a.id)
	assert_true(_button("split_army").disabled)
	assert_eq(_button("split_army").reason_text(), "no companies given")
	assert_true(_panel.reason_texts().has("No companies given"), "the reason shows under the actions")

	_panel.set_ticked(a.units[0].id, true)
	assert_false(_button("split_army").disabled, "one of two ticked: enabled")
	_panel.set_ticked(a.units[1].id, true)
	assert_true(_button("split_army").disabled, "all ticked: the army would be left empty")
	assert_eq(_button("split_army").reason_text(), "a split must leave at least one company behind")


func test_split_goes_through_session_act() -> void:
	var a := _own_army(2)
	_panel.show_army(a.id)
	_panel.set_ticked(a.units[0].id, true)
	_button("split_army").pressed.emit()
	assert_eq(Armies.of_country(_g, ArmyFixture.TAG).size(), 2, "a new army on the hex holds the company")
	assert_eq(Armies.by_id(_g, a.id).units.size(), 1, "the shown army keeps the other company")


func test_disband_with_no_refund_asks_first_then_acts() -> void:
	var a := _own_army(2)
	var before := _g.armies.size()
	var asked: Array = []
	_listen_and_keep(asked)
	_panel.show_army(a.id)
	watch_signals(Events)
	_button("disband").pressed.emit()
	assert_eq(asked.size(), 1, "nothing refunded: a Confirm first")
	assert_signal_not_emitted(Events, "army_disbanded", "no disband before the answer")
	assert_eq(_g.armies.size(), before, "the army stands until accepted")

	var screen := asked[0] as Confirm
	screen.call("_resolve", &"confirm")
	assert_signal_emitted(Events, "army_disbanded", "P: the accepted disband reaches Session.act and the rules")
	assert_null(Armies.by_id(_g, a.id), "the whole army is gone")
	assert_false(_panel.visible, "the panel hides with its army")


func test_disband_with_a_refund_acts_at_once() -> void:
	var hex := ArmyFixture.find_town(_g)
	var a := Armies.create(_g, ArmyFixture.TAG, hex, "Army of test")
	Armies.add_units(_g, a, 0, 2, _g.turn, hex, 100, {})
	var asked: Array = []
	_listen_and_keep(asked)
	_panel.show_army(a.id)
	watch_signals(Events)
	_button("disband").pressed.emit()
	assert_eq(asked.size(), 0, "every company refunded in full: no question")
	assert_signal_emitted(Events, "army_disbanded", "the disband went through Session.act")


func test_disband_with_no_listener_arms_then_disbands_on_the_second_press() -> void:
	var a := _own_army(2)
	_panel.show_army(a.id)
	watch_signals(Events)
	_button("disband").pressed.emit()
	assert_not_null(Armies.by_id(_g, a.id), "the first press only arms the disband")
	assert_string_contains(_panel.notice_text(), "Press Disband again", "a visible notice says so")
	_button("disband").pressed.emit()
	assert_null(Armies.by_id(_g, a.id), "the second press on the same selection disbands")
	assert_signal_emitted(Events, "army_disbanded")


func test_a_changed_selection_disarms_the_disband() -> void:
	var a := _own_army(2)
	_panel.show_army(a.id)
	_button("disband").pressed.emit()
	_panel.set_ticked(a.units[0].id, true)
	assert_eq(_panel.notice_text(), "", "the notice goes with the selection")
	_button("disband").pressed.emit()
	assert_not_null(Armies.by_id(_g, a.id), "a new selection needs a new first press")
	assert_string_contains(_panel.notice_text(), "Press Disband again")


func test_a_listener_that_does_not_take_the_confirm_leaves_no_orphan() -> void:
	var a := _own_army(2)
	var seen: Array = []
	_panel.confirm_requested.connect(func(screen: Screen) -> void: seen.append(screen))
	_panel.show_army(a.id)
	_button("disband").pressed.emit()
	assert_eq(seen.size(), 1, "the Confirm was offered")
	assert_false(is_instance_valid(seen[0]), "the Confirm nobody took on is freed")
	assert_not_null(Armies.by_id(_g, a.id), "nothing disbanded")
	assert_string_contains(_panel.notice_text(), "Press Disband again", "and the panel falls back to the two-step")


func test_a_refunded_company_alone_disbands_without_a_question() -> void:
	var a := _army_raised([true, false])
	var asked: Array = []
	_listen_and_keep(asked)
	_panel.show_army(a.id)
	_panel.set_ticked(a.units[0].id, true)
	var ducats := _treasury()
	_button("disband").pressed.emit()
	assert_eq(asked.size(), 0, "the ticked company is refunded in full: no question")
	assert_eq(Armies.by_id(_g, a.id).units.size(), 1, "that company went; the other stays")
	assert_eq(_treasury(), ducats + 10, "its refund came back")


func test_a_set_with_one_company_not_refunded_asks_about_the_whole_set() -> void:
	var a := _army_raised([true, false])
	var asked: Array = []
	_listen_and_keep(asked)
	_panel.show_army(a.id)
	_panel.set_ticked(a.units[0].id, true)
	_panel.set_ticked(a.units[1].id, true)
	_button("disband").pressed.emit()
	assert_eq(asked.size(), 1, "one company is refunded only in part: the set is asked about")
	assert_eq(Armies.by_id(_g, a.id).units.size(), 2, "nothing is disbanded before the answer")


func test_two_companies_with_room_for_one_are_refused_whole_from_the_panel() -> void:
	var hex := ArmyFixture.find_town(_g)
	var a := Armies.create(_g, ArmyFixture.TAG, hex, "Army of test")
	Armies.add_units(_g, a, 0, 2, _g.turn, hex, 10, {})
	ArmyFixture.people_at(_g, hex, People.PEOPLE_MAX - a.units[0].men)
	_panel.show_army(a.id)
	_panel.set_ticked(a.units[0].id, true)
	_panel.set_ticked(a.units[1].id, true)
	assert_true(_button("disband").disabled, "the set's combined verdict refuses")
	assert_string_contains(_button("disband").reason_text(), "no room for")
	_button("disband").pressed.emit()
	assert_eq(Armies.by_id(_g, a.id).units.size(), 2, "never half a disband: both companies stay")
	assert_string_contains(_panel.notice_text(), "no room for", "the refusal shows")


func test_disband_refused_by_its_check_shows_the_reason() -> void:
	var a := _own_army(2)
	_panel.show_army(a.id)
	var far := _unseen_land()
	Armies.set_hex(_g, a, far, a.hex)
	_panel.refresh()
	assert_true(_button("disband").disabled, "disband only in your own land")
	assert_string_contains(_button("disband").reason_text(), "disband only in your own land")


## R23: a seen foreign army shows, whether or not its country is known; no action buttons.
func test_a_seen_foreign_army_is_shown_with_no_buttons() -> void:
	var hex := ArmyFixture.find_town(_g)
	var a := ArmyFixture.army(_g, SAV, hex, 0, 2)
	_panel.show_army(a.id)
	assert_true(_panel.visible, "a seen foreign army shows")
	assert_eq(_panel.cartouche().text, "Savoy", "the country's name")
	assert_eq(_panel.body().find_children("*", "KitButton", true, false).filter(
		func(n: Node) -> bool: return (n as KitButton).has_meta(&"action")).size(), 0, "no action buttons")
	assert_eq(_panel.join_segment(), null)


func test_an_unseen_foreign_army_shows_no_panel() -> void:
	var far := ArmyFixture.army(_g, SAV, _unseen_land(), 0, 1)
	_panel.show_army(far.id)
	assert_false(_panel.visible, "P: an unseen foreign army is not shown")
	assert_eq(_panel.shown_army(), -1)


func test_join_lists_the_other_armies_of_yours_on_the_hex() -> void:
	var hex := ArmyFixture.find_town(_g)
	var a := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 2)
	var b := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 1)
	_panel.show_army(a.id)
	assert_not_null(_panel.join_segment(), "one other army here: a Join row")
	assert_not_null(_button("merge_armies"))
	assert_false(_button("merge_armies").disabled)
	assert_eq(_panel.join_segment().selected_id(), b.id)
	_button("merge_armies").pressed.emit()
	assert_null(Armies.by_id(_g, a.id), "the joined army is gone")
	assert_eq(_panel.shown_army(), b.id, "the panel follows the army that remains")


func test_refresh_follows_the_bus() -> void:
	var a := _own_army(2)
	_panel.show_army(a.id)
	Armies.set_order(_g, a, Army.ORDER_HOLD, ArmyFixture.NO_HEX, PackedInt32Array())
	Events.army_changed.emit(ArmyFixture.TAG, a.id)
	assert_true(_button("halt").disabled, "an army_changed event refreshes the verdicts")


## CountryPanel's Under arms row: yours exact with the count, a known country exact too (D7), an unknown one no row.
func test_country_panel_under_arms_row() -> void:
	var country := (load(COUNTRY) as PackedScene).instantiate() as CountryPanel
	country.theme = KitTheme.load_for(1.0)
	add_child_autofree(country)
	var mine := _own_army(2)
	country.show_country(ArmyFixture.TAG, false)
	var rows := country.ledger_texts()
	var at := rows.find("Under arms")
	assert_gt(at, -1, "the row is there for the player")
	assert_eq(rows[at + 1], "%s in 1 army" % Words.men(mine.men()), "yours exact with the count")
	assert_eq(rows.find("People") + 2, at, "the row follows People")

	var sav_hex := ArmyFixture.find_town(_g)
	ArmyFixture.army(_g, SAV, sav_hex, 0, 2)
	country.show_country(SAV, false)
	var sav_rows := country.ledger_texts()
	var sav_at := sav_rows.find("Under arms")
	if Knowledge.knows(_g, ArmyFixture.TAG, SAV):
		assert_true(sav_rows[sav_at + 1].begins_with(Words.men(Knowledge.men_of(_g, ArmyFixture.TAG, SAV))), "D7: a known country's men exact")
	else:
		assert_eq(sav_at, -1, "an unknown country has no row")


## The picture of L18's review: tick boxes as tall as the row, a company row of about 50 px, and "Continue march" cut by its
## key cap. Laid out at the dock width, every check box is compact, every company row is under 64 px, and each action
## button's text, icon and key cap fit inside it.
func test_rows_and_buttons_fit_at_the_dock_width() -> void:
	var a := _own_army(3)
	_panel.size = Vector2(Tokens.PANEL_W, 720)
	_panel.show_army(a.id)
	await get_tree().process_frame
	await get_tree().process_frame
	var boxes := 0
	for node: Node in _panel.body().find_children("*", "CheckBox", true, false):
		var box := node as CheckBox
		boxes += 1
		assert_lte(box.size.y, 26.0, "a compact check box, not one as tall as its row")
		var row := box.get_parent() as Control
		assert_lte(row.size.y, 64.0, "a company row is about 50 px: under 64")
	assert_eq(boxes, 3, "one check box a company")

	var checked := 0
	for node: Node in _panel.body().find_children("*", "KitButton", true, false):
		var btn := node as KitButton
		if not btn.has_meta(&"action"):
			continue
		checked += 1
		assert_gt(btn.size.x, 40.0, "%s is laid out" % btn.text)
		assert_lte(_needed_width(btn), btn.size.x + 0.5, "%s fits its button: text, icon and key cap" % btn.text)
	assert_gte(checked, 4, "Hold, Continue, Split off and Disband are checked")


## The width a button's content needs: its text, its icon and its embedded key cap, plus the normal style's margins.
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


## The points row (R51): its text is ArmyView.panel's points text, and it follows the army's points.
func test_the_points_row_is_the_views_text() -> void:
	var a := _own_army(2)
	a.points = 5
	_g.version += 1
	_panel.show_army(a.id)
	var want := str(ArmyView.panel(_g, ArmyFixture.TAG, a.id)["points"]["text"])
	assert_true(want.begins_with("5 of "), "the view says 5 left: %s" % want)
	var row := _panel.find_child("PointsRow", true, false) as Label
	assert_not_null(row, "the panel has a points row")
	assert_eq(row.text, want)
	assert_ne(row.tooltip_text, "", "the row has a hover text")
