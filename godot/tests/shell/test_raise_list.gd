## The Raise tab of the hex panel (docs/architecture/m6-build-spec.md 6.8; L19, issue #209). A settlement of the player's shows
## the Works | Raise segment; the Raise tab lists one row per kind (Military.raise_options) with its cost text and verdict; a
## refused row shows its reason; a click raises one company through Session.act. The tab is absent on a foreign or an
## unowned hex and on the player's own wild land. Planted faults to catch: a click that does not reach Session.act, a row
## whose button ignores its verdict, a tab offered on foreign land.
extends GutTest

const PANEL := "res://shell/panels/hex_panel.tscn"
const TAG := ArmyFixture.TAG

var _g: Game
var _hex := Vector2i(-1, -1)
var _panel: HexPanel = null


func before_each() -> void:
	_g = ArmyFixture.game()
	_hex = ArmyFixture.find_town(_g)
	ArmyFixture.town(_g, _hex)
	ArmyFixture.rich(_g)
	Session.start_game(_g)
	_panel = (load(PANEL) as PackedScene).instantiate() as HexPanel
	_panel.theme = KitTheme.load_for(1.0)
	add_child_autofree(_panel)


func after_each() -> void:
	Session.end_game()
	await get_tree().process_frame


## Waits for the panel's coalesced refresh (it runs at the end of the frame).
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _raise_tab_on_town() -> void:
	_panel.show_hex(_hex)
	_panel.show_raise()
	await _settle()


func _foreign_land() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		var owner := Territory.owner_tag(_g, hex)
		if _g.map.is_land(hex) and owner != &"" and owner != TAG:
			return hex
	return ArmyFixture.NO_HEX


func _unowned_land() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.is_land(hex) and Territory.owner_tag(_g, hex) == &"":
			return hex
	return ArmyFixture.NO_HEX


func _own_wild_land() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.is_land(hex) and Territory.owner_tag(_g, hex) == TAG and int(_g.state.main_use[i]) != Economy.SETTLEMENTS:
			return hex
	return ArmyFixture.NO_HEX


func _tab_box() -> Control:
	return _panel.tabs().get_parent() as Control


func _raise_box() -> Control:
	return _panel.raise_list().get_parent() as Control


func _actions_box() -> Control:
	return _panel.get_node("Scroll/Body/ActionsBox") as Control


func test_offered_only_on_own_settlement() -> void:
	assert_true(RaiseList.offered(_g, TAG, _hex), "an own settlement offers the tab")
	assert_false(RaiseList.offered(_g, TAG, _own_wild_land()), "own wild land does not")
	assert_false(RaiseList.offered(_g, TAG, _foreign_land()), "foreign land does not")
	var unowned := _unowned_land()
	if unowned != ArmyFixture.NO_HEX:
		assert_false(RaiseList.offered(_g, TAG, unowned), "unowned land does not")


func test_tab_absent_on_foreign_unowned_and_wild_hexes() -> void:
	for hex: Vector2i in [_foreign_land(), _unowned_land(), _own_wild_land()]:
		if hex == ArmyFixture.NO_HEX:
			continue
		_panel.show_hex(hex)
		await _settle()
		assert_false(_tab_box().visible, "no segment on %s" % str(hex))
		assert_false(_raise_box().visible, "no raise list on %s" % str(hex))


func test_own_settlement_shows_the_segment_with_works_by_default() -> void:
	_panel.show_hex(_hex)
	await _settle()
	assert_true(_tab_box().visible, "the segment shows on an own settlement")
	assert_eq(_panel.tab_open(), &"works", "Works is the default tab")
	assert_eq(_panel.tabs().selected_id(), &"works")
	assert_false(_raise_box().visible, "no raise list under the Works tab")


func test_one_row_per_kind_with_its_cost_text_and_verdict() -> void:
	await _raise_tab_on_town()
	var options := Military.raise_options(_g, TAG, _hex)
	var rows := _panel.raise_list().raise_buttons()
	assert_eq(rows.size(), _g.defs.units.size(), "one row a kind")
	assert_eq(options.size(), rows.size())
	for i: int in rows.size():
		assert_eq(rows[i].text, "Raise", "the button says Raise")
		assert_eq(rows[i].cost_text, str(options[i]["cost_text"]), "the cost text of the kind")
		assert_eq(rows[i].disabled, not bool(options[i]["verdict"]["ok"]), "the button follows the verdict")
	assert_true(rows.size() > 0 and not rows[0].cost_text.is_empty())


func test_disabled_rows_show_their_reason() -> void:
	Countries.by_tag(_g, TAG).treasury = 0
	await _raise_tab_on_town()
	var rows := _panel.raise_list().raise_buttons()
	assert_gt(rows.size(), 0)
	for row: KitButton in rows:
		assert_true(row.disabled, "no ducats: every row is refused")
		assert_true(row.reason_text().contains("not enough ducats"), "the verdict words: %s" % row.reason_text())
	var reasons := _panel.raise_list().reason_labels()
	assert_eq(reasons.size(), rows.size(), "each refused row shows its reason under it")
	assert_true(reasons[0].text.contains("not enough ducats"))


func test_cap_words_show_on_every_row_once_the_settlement_has_raised_its_cap() -> void:
	assert_true(Session.act("raise", {"hex": _hex, "kind": 0, "count": 2}).get("ok", false), "two companies raised")
	await _raise_tab_on_town()
	var cap := Military.raise_cap(_g, _hex)
	assert_eq(cap, 2, "a town raises 2 a season")
	for row: KitButton in _panel.raise_list().raise_buttons():
		assert_true(row.disabled)
		assert_true(row.reason_text().contains("has raised its 2 companies this season"), row.reason_text())


func test_head_line_reads_men_at_hand_and_companies() -> void:
	await _raise_tab_on_town()
	var head := _panel.raise_list().get_node("Head") as Label
	assert_true(head.text.begins_with("Men at hand: "), head.text)
	assert_true(head.text.contains("of %d companies raised this season" % Military.raise_cap(_g, _hex)), head.text)


func test_clicking_raise_goes_through_session_act_and_moves_the_treasury() -> void:
	await _raise_tab_on_town()
	var row := _panel.raise_list().raise_buttons()[0]
	assert_false(row.disabled, "the first kind is affordable here")
	var cost := int(Military.cost_of(_g, 0, 1)["ducats"])
	var before := Countries.by_tag(_g, TAG).treasury
	var acts := Session.unsaved_actions
	watch_signals(Events)
	row.pressed.emit()
	assert_eq(Session.unsaved_actions, acts + 1, "the click is one Session.act")
	assert_eq(Countries.by_tag(_g, TAG).treasury, before - cost, "the ducats are paid")
	assert_eq(Military.raised_here(_g, TAG, _hex), 1, "one company raised here")
	assert_signal_emitted(Events, "army_raised")


func test_raise_list_refuses_a_stale_click_with_the_words() -> void:
	await _raise_tab_on_town()
	var list := _panel.raise_list()
	Countries.by_tag(_g, TAG).treasury = 0
	list._on_raise_pressed(0)
	assert_eq(Military.raised_here(_g, TAG, _hex), 0, "a refused raise changes nothing")


func test_keyboard_reach_and_tab_order() -> void:
	await _raise_tab_on_town()
	var segment := _panel.tabs().button_for(&"raise")
	assert_not_null(segment)
	assert_eq(segment.focus_mode, Control.FOCUS_ALL, "the segment takes the keyboard")
	for row: KitButton in _panel.raise_list().raise_buttons():
		assert_eq(row.focus_mode, Control.FOCUS_ALL, "every Raise button takes the keyboard")
	var tab_box_index := _tab_box().get_index()
	var raise_box_index := _panel.raise_list().get_parent().get_index()
	assert_lt(tab_box_index, raise_box_index, "the segment comes before the raise rows in Tab order")
	assert_lt(_tab_box().get_index(), _actions_box().get_index(), "and before the works rows")


func test_raise_segment_hides_the_works_rows_and_back() -> void:
	_panel.show_hex(_hex)
	await _settle()
	_panel.tabs().select(&"raise", true)
	await _settle()
	assert_true(_raise_box().visible, "the raise list shows")
	assert_false(_actions_box().visible, "the works rows hide")
	_panel.tabs().select(&"works", true)
	await _settle()
	assert_false(_raise_box().visible)
	assert_true(_actions_box().visible, "the works rows come back")


func test_tab_goes_back_to_works_on_another_hex() -> void:
	await _raise_tab_on_town()
	var foreign := _foreign_land()
	_panel.show_hex(foreign)
	await _settle()
	assert_eq(_panel.tab_open(), &"works")
	assert_false(_raise_box().visible)
