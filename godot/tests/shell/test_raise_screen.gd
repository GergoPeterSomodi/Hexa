## The Raise companies window (tile-window spec R27; TW14). Copied and adapted from test_raise_list.gd and test_army_tab.gd: one
## tall row a kind, the hammer enabled iff the raise check passes, the reason on a refused row, the cap words, the head line,
## a raise through Session.act with the old toasts, a stale click refused. New: search, the filter, Esc, refresh on the game
## version, the arms banner, a foreign or fogged hex showing nothing. Planted faults to catch: a hammer that does not reach
## Session.act, a hammer enabled where raise_check refuses, rows or a place name on a foreign hex, a filter that keeps a
## refused row, a window that does not follow a version change.
extends GutTest

const TAG := ArmyFixture.TAG

var _g: Game
var _hex := Vector2i(-1, -1)
var _harness: UIHarness = null


func before_each() -> void:
	Bindings.reset_defaults()
	_g = ArmyFixture.game()
	_hex = ArmyFixture.find_town(_g)
	ArmyFixture.town(_g, _hex)
	ArmyFixture.rich(_g)
	Session.start_game(_g)
	_harness = UIHarness.new()
	_harness.mount(self)
	_harness.stack.theme = KitTheme.load_for(1.0)


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	_harness = null
	Session.end_game()
	Bindings.reset_defaults()
	await get_tree().process_frame


func _open(hex: Vector2i) -> RaiseScreen:
	var screen := ScreenIds.make(&"raise_screen") as RaiseScreen
	assert_not_null(screen)
	_harness.stack.push(screen)
	screen.open_for(hex)
	await _harness.wait_frames(self, 2)
	return screen


func _foreign_land() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		var owner := Territory.owner_tag(_g, hex)
		if _g.map.is_land(hex) and owner != &"" and owner != TAG:
			return hex
	return ArmyFixture.NO_HEX


func _own_wild_land() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.is_land(hex) and Territory.owner_tag(_g, hex) == TAG and int(_g.state.main_use[i]) != Economy.SETTLEMENTS:
			return hex
	return ArmyFixture.NO_HEX


func _texts(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if node is Label:
		out.append((node as Label).text)
	for child: Node in node.get_children():
		out.append_array(_texts(child))
	return out


func _record_toasts() -> Array:
	var toasts: Array = []
	_harness.ctx.toast_requested.connect(func(text: String, tone: StringName) -> void: toasts.append([text, tone]))
	return toasts


func test_registered_and_not_opaque() -> void:
	assert_true(ScreenIds.has(&"raise_screen"))
	var screen := await _open(_hex)
	assert_ne(screen.kind, Screen.Kind.OPAQUE)
	assert_eq(screen.frame().title, "Raise companies")
	assert_eq(screen.shown_hex(), _hex)


func test_one_tall_row_per_kind_with_the_hammer_following_the_verdict() -> void:
	var screen := await _open(_hex)
	var rows := screen.company_rows()
	var data: Array = TileArmy.of(_g, TAG, _hex)["raise"]["rows"]
	assert_eq(rows.size(), _g.defs.units.size(), "one row a kind")
	assert_eq(rows.size(), data.size())
	for i: int in rows.size():
		assert_eq(rows[i].layout, CompanyRow.TALL)
		assert_eq(rows[i].kind, int(data[i]["kind"]))
		var verdict := Military.raise_check(_g, {"hex": _hex, "kind": rows[i].kind, "count": 1, "tag": TAG})
		assert_eq(rows[i].hammer().disabled, not bool(verdict["ok"]), "the hammer follows the verdict")
	assert_false(rows[0].hammer().disabled, "the first kind is affordable here")


func test_disabled_rows_show_their_reason() -> void:
	Countries.by_tag(_g, TAG).treasury = 0
	var screen := await _open(_hex)
	var rows := screen.company_rows()
	assert_gt(rows.size(), 0)
	for row: CompanyRow in rows:
		assert_true(row.hammer().disabled, "no ducats: every row is refused")
		assert_true(row.hammer().tooltip_text.contains("not enough ducats"), row.hammer().tooltip_text)
		assert_eq(row.count_text(), CompanyRow.NO_COUNT)
	var reasons := 0
	for text: String in _texts(screen):
		if text.contains("not enough ducats"):
			reasons += 1
	assert_eq(reasons, rows.size(), "each refused row shows its reason")


func test_cap_words_show_on_every_row_once_the_settlement_has_raised_its_cap() -> void:
	assert_true(Session.act("raise", {"hex": _hex, "kind": 0, "count": 2}).get("ok", false), "two companies raised")
	var screen := await _open(_hex)
	assert_eq(Military.raise_cap(_g, _hex), 2, "a town raises 2 a season")
	for row: CompanyRow in screen.company_rows():
		assert_true(row.hammer().disabled)
		assert_true(row.hammer().tooltip_text.contains("has raised its 2 companies this season"), row.hammer().tooltip_text)


func test_head_line_reads_men_to_levy_and_companies() -> void:
	var screen := await _open(_hex)
	var head := screen.head_label().text
	assert_true(head.contains("Men to levy "), head)
	assert_true(head.contains("of %d raised this season" % Military.raise_cap(_g, _hex)), head)
	assert_true(head.contains(Military.hex_text(_g, _hex)), "the place is named")


func test_hammer_goes_through_session_act_and_moves_the_treasury() -> void:
	var screen := await _open(_hex)
	var toasts := _record_toasts()
	var row := screen.company_rows()[0]
	var cost := int(Military.cost_of(_g, 0, 1)["ducats"])
	var before := Countries.by_tag(_g, TAG).treasury
	var acts := Session.unsaved_actions
	watch_signals(Events)
	row.hammer().pressed.emit()
	assert_eq(Session.unsaved_actions, acts + 1, "the click is one Session.act")
	assert_eq(Countries.by_tag(_g, TAG).treasury, before - cost, "the ducats are paid")
	assert_eq(Military.raised_here(_g, TAG, _hex), 1, "one company raised here")
	assert_signal_emitted(Events, "army_raised")
	assert_eq(toasts.size(), 1)
	assert_eq(toasts[0][1], &"plain")
	assert_true(str(toasts[0][0]).begins_with("Raised 1 company of "), str(toasts[0][0]))


func test_a_stale_click_is_refused_with_the_words() -> void:
	var screen := await _open(_hex)
	var toasts := _record_toasts()
	Countries.by_tag(_g, TAG).treasury = 0
	screen.raise_company(0)
	assert_eq(Military.raised_here(_g, TAG, _hex), 0, "a refused raise changes nothing")
	assert_eq(toasts.size(), 1)
	assert_eq(toasts[0][1], &"warn")
	assert_true(str(toasts[0][0]).contains("not enough ducats"), str(toasts[0][0]))


func test_search_keeps_the_rows_whose_name_matches() -> void:
	var screen := await _open(_hex)
	var all := screen.company_rows().size()
	var name_0 := str(_g.defs.units[0].name)
	screen.set_query(name_0.to_upper())
	var shown := screen.company_rows()
	assert_gt(shown.size(), 0, "a match is case-blind")
	assert_lt(shown.size(), all + 1)
	for row: CompanyRow in shown:
		assert_true(str(_g.defs.units[row.kind].name).to_lower().contains(name_0.to_lower()))
	screen.set_query("zzqx")
	assert_eq(screen.company_rows().size(), 0)
	assert_true(screen.note_label().visible)
	assert_eq(screen.note_label().text, RaiseScreen.NO_MATCH_NOTE)
	screen.set_query("")
	assert_eq(screen.company_rows().size(), all)
	assert_false(screen.note_label().visible)


func test_typing_in_the_box_searches() -> void:
	var screen := await _open(_hex)
	var box := screen.search_box()
	box.text = "zzqx"
	box.text_changed.emit("zzqx")
	assert_eq(screen.company_rows().size(), 0)


func test_filter_can_raise_hides_refused_rows() -> void:
	var screen := await _open(_hex)
	var all := screen.company_rows()
	var ready := 0
	for row: CompanyRow in all:
		if not row.hammer().disabled:
			ready += 1
	screen.set_filter(RaiseScreen.FILTER_CAN)
	var shown := screen.company_rows()
	assert_eq(shown.size(), ready, "only the rows that can be raised")
	for row: CompanyRow in shown:
		assert_false(row.hammer().disabled)
	screen.set_filter(RaiseScreen.FILTER_ALL)
	assert_eq(screen.company_rows().size(), all.size())
	Countries.by_tag(_g, TAG).treasury = 0
	screen.set_filter(RaiseScreen.FILTER_CAN)
	screen.open_for(_hex)
	assert_eq(screen.company_rows().size(), 0, "nothing can be raised without ducats")


func test_esc_closes_the_window() -> void:
	var screen := await _open(_hex)
	assert_eq(_harness.stack.top(), screen)
	assert_true(_harness.stack.back())
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0)


func test_the_close_button_closes_the_window() -> void:
	var screen := await _open(_hex)
	screen.frame().closed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0)


func test_it_refreshes_when_the_game_version_changes() -> void:
	var screen := await _open(_hex)
	var before := screen.company_rows()[0].count_text()
	assert_ne(before, CompanyRow.NO_COUNT)
	var version := _g.version
	assert_true(Session.act("raise", {"hex": _hex, "kind": 0, "count": 2}).get("ok", false), "raised from outside")
	assert_ne(_g.version, version, "the act moved the version")
	await _harness.wait_frames(self, 2)
	assert_true(screen.head_label().text.contains("2 of 2 raised"), screen.head_label().text)
	for row: CompanyRow in screen.company_rows():
		assert_true(row.hammer().disabled, "the cap is reached: the window followed")


func test_the_arms_banner_shows_only_when_the_model_gives_arms() -> void:
	var screen := await _open(_hex)
	assert_false(screen.banner_label().visible, "no arms before M9.5")
	var raise: Dictionary = TileArmy.of(_g, TAG, _hex)["raise"]
	raise["arms"] = {"in_stores": "6", "premium_text": "buying costs 3 more"}
	screen.show_raise(raise)
	assert_true(screen.banner_label().visible)
	assert_eq(screen.banner_label().text, "Arms in stores 6 · buying costs 3 more")
	raise["arms"] = {}
	screen.show_raise(raise)
	assert_false(screen.banner_label().visible)


func test_a_foreign_hex_shows_nothing() -> void:
	var foreign := _foreign_land()
	assert_ne(foreign, ArmyFixture.NO_HEX)
	var screen := await _open(foreign)
	assert_eq(screen.company_rows().size(), 0, "no rows on foreign land")
	assert_eq(screen.head_label().text, "", "no place or men on foreign land")
	assert_false(screen.head_label().visible)
	assert_false(screen.banner_label().visible)
	assert_eq(screen.note_label().text, RaiseScreen.NOTHING_NOTE)
	assert_false(screen.search_box().editable)
	var name_of_place := Military.hex_text(_g, foreign)
	for text: String in _texts(screen):
		assert_false(name_of_place != "" and text.contains(name_of_place), "the place is not named: %s" % text)


func test_own_wild_land_shows_nothing() -> void:
	var wild := _own_wild_land()
	if wild == ArmyFixture.NO_HEX:
		pending("no own wild land on this map")
		return
	var screen := await _open(wild)
	assert_eq(screen.company_rows().size(), 0)
	assert_eq(screen.head_label().text, "")


func test_a_fogged_hex_shows_nothing() -> void:
	var fogged := Vector2i(-1, -1)
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.is_land(hex) and not Knowledge.sees(_g, TAG, hex) and Territory.owner_tag(_g, hex) != TAG:
			fogged = hex
			break
	if fogged == Vector2i(-1, -1):
		pending("no fogged land on this map")
		return
	var screen := await _open(fogged)
	assert_eq(screen.company_rows().size(), 0)
	assert_eq(screen.head_label().text, "")
	assert_false(screen.banner_label().visible)
