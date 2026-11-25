## The Army tab of the tile window (tile-window spec R14, R21, R22, R26, R27; TW12). Copied and adapted from test_raise_list.gd
## (the old Raise tab of the hex panel): one row a kind, the hammer enabled iff the raise check passes, the reason on a refused
## row, the cap words, the head line, the hammer through Session.act with the old toasts. New: the armies here (own arrow
## only), a foreign army in sight read-only, Show all, the hover card, the dimmed reasons, the tab's place in the registry.
## Planted faults to catch: a hammer enabled where raise_check refuses, a click that does not reach Session.act, an arrow on a
## foreign army, a raise offered on foreign land.
extends GutTest

const TAB := preload("res://shell/panels/tile_tabs/army_tab.gd")
const TAG := ArmyFixture.TAG

var _g: Game
var _hex := Vector2i(-1, -1)


func before_each() -> void:
	_g = ArmyFixture.game()
	_hex = ArmyFixture.find_town(_g)
	ArmyFixture.town(_g, _hex)
	ArmyFixture.rich(_g)
	Session.start_game(_g)


func after_each() -> void:
	Session.end_game()
	await get_tree().process_frame


## A tab for `hex`, built the way the window builds it: in the tree, filled once.
func _tab(hex: Vector2i) -> ArmyTab:
	var tab := ArmyTab.new()
	tab.theme = KitTheme.load_for(1.0)
	add_child_autofree(tab)
	tab.fill(_g, TAG, hex, TileView.of(_g, TAG, hex))
	return tab


func _foreign_land() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		var owner := Territory.owner_tag(_g, hex)
		if _g.map.is_land(hex) and owner != &"" and owner != TAG:
			return hex
	return ArmyFixture.NO_HEX


## A foreign hex of land the player sees now (Sight.refresh first, as the vision phase does).
func _seen_foreign_hex() -> Vector2i:
	Sight.refresh(_g)
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		var owner := Territory.owner_tag(_g, hex)
		if _g.map.is_land(hex) and owner != &"" and owner != TAG and Knowledge.sees(_g, TAG, hex):
			return hex
	return ArmyFixture.NO_HEX


## Every label text under a node, depth first.
func _texts(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if node is Label:
		out.append((node as Label).text)
	for child: Node in node.get_children():
		out.append_array(_texts(child))
	return out


func _has_text(node: Node, prefix: String) -> bool:
	for text: String in _texts(node):
		if text.begins_with(prefix):
			return true
	return false


func test_registry_constants_and_place() -> void:
	assert_eq(TAB.ID, &"army")
	assert_eq(TAB.ORDER, 30)
	assert_eq(TAB.LABEL, "Army")


func test_applies_on_land_but_not_sea_unexplored_or_sandbox() -> void:
	assert_true(TAB.applies({"case": &"own"}), "own land")
	assert_true(TAB.applies({"case": &"foreign"}), "foreign land")
	assert_true(TAB.applies({"case": &"unowned"}), "unowned land")
	assert_false(TAB.applies({"case": &"sea"}), "sea")
	assert_false(TAB.applies({"case": &"unexplored"}), "unexplored")
	assert_false(TAB.applies({"case": &"sandbox"}), "the sandbox")


func test_dimmed_gives_the_model_reason_and_live_on_a_settlement() -> void:
	assert_eq(TAB.dimmed(TileView.of(_g, TAG, _hex)), "", "an own town is live")
	var foreign := _foreign_land()
	if foreign == ArmyFixture.NO_HEX:
		pending("no foreign land on this map")
		return
	var reason := TAB.dimmed(TileView.of(_g, TAG, foreign))
	assert_true(reason == "No armies here" or reason == "Out of sight: no armies are shown", "foreign: %s" % reason)


func test_one_row_per_kind_and_the_hammer_follows_the_check() -> void:
	var tab := _tab(_hex)
	var rows: Array[CompanyRow] = tab.company_rows()
	assert_eq(rows.size(), _g.defs.units.size(), "one row a kind")
	for row: CompanyRow in rows:
		var verdict := Military.raise_check(_g, {"hex": _hex, "kind": row.kind, "count": 1, "tag": TAG})
		assert_eq(row.hammer().disabled, not bool(verdict["ok"]), "the hammer of kind %d follows raise_check" % row.kind)


func test_disabled_rows_show_their_reason() -> void:
	Countries.by_tag(_g, TAG).treasury = 0
	var tab := _tab(_hex)
	var rows: Array[CompanyRow] = tab.company_rows()
	assert_gt(rows.size(), 0)
	for row: CompanyRow in rows:
		assert_true(row.hammer().disabled, "no ducats: every hammer is off")
		assert_true(row.hammer().tooltip_text.contains("not enough ducats"), row.hammer().tooltip_text)
	var reasons := 0
	for text: String in _texts(tab):
		if text.contains("not enough ducats"):
			reasons += 1
	assert_eq(reasons, rows.size(), "each refused row shows its reason")


func test_cap_words_show_on_every_row_once_the_settlement_has_raised_its_cap() -> void:
	assert_true(Session.act("raise", {"hex": _hex, "kind": 0, "count": 2}).get("ok", false), "two companies raised")
	var tab := _tab(_hex)
	assert_eq(Military.raise_cap(_g, _hex), 2, "a town raises 2 a season")
	for row: CompanyRow in tab.company_rows():
		assert_true(row.hammer().disabled)
		assert_true(row.hammer().tooltip_text.contains("has raised its 2 companies this season"), row.hammer().tooltip_text)


func test_head_line_reads_men_to_levy_and_companies() -> void:
	var tab := _tab(_hex)
	assert_true(_has_text(tab, "Men to levy "), "the head line")
	assert_true(_has_text(tab, "Raise a company here"), "the raise heading")


func test_arms_banner_is_absent_until_the_model_has_arms() -> void:
	var tab := _tab(_hex)
	assert_false(_has_text(tab, "Arms in stores"), "no arms data, no banner")


func test_clicking_the_hammer_goes_through_session_act_and_moves_the_treasury() -> void:
	var tab := _tab(_hex)
	var row: CompanyRow = tab.company_rows()[0]
	assert_false(row.hammer().disabled, "the first kind is affordable here")
	var cost := int(Military.cost_of(_g, row.kind, 1)["ducats"])
	var before := Countries.by_tag(_g, TAG).treasury
	var acts := Session.unsaved_actions
	var toasts: Array = []
	tab.toast_requested.connect(func(text: String, tone: StringName) -> void: toasts.append([text, tone]))
	watch_signals(Events)
	row.hammer().pressed.emit()
	assert_eq(Session.unsaved_actions, acts + 1, "the click is one Session.act")
	assert_eq(Countries.by_tag(_g, TAG).treasury, before - cost, "the ducats are paid")
	assert_eq(Military.raised_here(_g, TAG, _hex), 1, "one company raised here")
	assert_signal_emitted(Events, "army_raised")
	assert_eq(toasts.size(), 1)
	assert_true(str(toasts[0][0]).begins_with("Raised 1 company of "), "the old raise words")
	assert_eq(toasts[0][1], &"plain")


func test_a_refused_raise_changes_nothing_and_says_why() -> void:
	var tab := _tab(_hex)
	Countries.by_tag(_g, TAG).treasury = 0
	var toasts: Array = []
	tab.toast_requested.connect(func(text: String, tone: StringName) -> void: toasts.append([text, tone]))
	tab.raise_company(0)
	assert_eq(Military.raised_here(_g, TAG, _hex), 0, "a refused raise changes nothing")
	assert_eq(toasts.size(), 1)
	assert_eq(toasts[0][1], &"warn", "the refusal is a warn toast")


func test_show_all_asks_the_app_for_the_raise_screen() -> void:
	var tab := _tab(_hex)
	var asks: Array = []
	tab.app_requested.connect(func(what: StringName, args: Dictionary) -> void: asks.append([what, args]))
	assert_not_null(tab.show_all_button())
	tab.show_all_button().pressed.emit()
	assert_eq(asks.size(), 1)
	assert_eq(asks[0][0], &"raise_screen")
	assert_eq(asks[0][1], {"hex": _hex})


func test_hover_on_a_row_gives_the_company_card_and_leaving_clears_it() -> void:
	var tab := _tab(_hex)
	var row: CompanyRow = tab.company_rows()[0]
	var cards: Array = []
	var cleared := [0]
	tab.row_hovered.connect(func(card: Dictionary, _anchor: Rect2) -> void: cards.append(card))
	tab.row_unhovered.connect(func() -> void: cleared[0] += 1)
	row.hovered.emit(row.kind)
	assert_eq(cards.size(), 1, "one card")
	assert_eq(cards[0], CompanyCard.of(_g, TAG, _hex, row.kind), "the card is CompanyCard.of")
	row.unhovered.emit()
	assert_eq(cleared[0], 1, "leaving clears the card")


func test_own_army_has_an_open_arrow_that_selects_it() -> void:
	var army := ArmyFixture.army(_g, TAG, _hex, 0, 1)
	var tab := _tab(_hex)
	var opens := tab.open_buttons()
	assert_eq(opens.size(), 1, "one arrow for the one own army")
	var asks: Array = []
	tab.app_requested.connect(func(what: StringName, args: Dictionary) -> void: asks.append([what, args]))
	opens[0].pressed.emit()
	assert_eq(asks.size(), 1)
	assert_eq(asks[0][0], &"select_army")
	assert_eq(int(asks[0][1]["army"]), army.id)


func test_a_foreign_army_in_sight_is_read_only_and_named_by_its_country() -> void:
	var seen := _seen_foreign_hex()
	if seen == ArmyFixture.NO_HEX:
		pending("no foreign land in the player's sight on this map")
		return
	var foreign := ArmyFixture.other_tag(_g)
	ArmyFixture.army(_g, foreign, seen, 0, 2)
	Sight.refresh(_g)
	var view := TileView.of(_g, TAG, seen)
	assert_true(TAB.applies(view), "live on a foreign tile with an army in sight")
	assert_eq(TAB.dimmed(view), "", "not dimmed")
	var tab := _tab(seen)
	assert_true(_has_text(tab, "An army of "), "named by the country")
	var shown: String = str(TileArmy.of(_g, TAG, seen)["armies"][0]["men_text"])
	assert_true(_has_text(tab, str(shown)), "the men exact: %s" % shown)
	assert_eq(tab.open_buttons().size(), 0, "no arrow on a foreign army")
	assert_eq(tab.company_rows().size(), 0, "no raise rows on foreign land")
	assert_null(tab.show_all_button(), "no Show all on foreign land")


func test_tall_form_shows_one_line_a_part_and_the_count() -> void:
	var rows: Array = TileArmy.of(_g, TAG, _hex)["raise"]["rows"]
	var tall := CompanyRow.make(rows[0], CompanyRow.TALL)
	add_child_autofree(tall)
	var part: Dictionary = rows[0]["parts"][0]
	assert_true(_texts(tall).has("%d %s" % [int(part["amount"]), str(part["name"])]), "the ducats line")
	var n := int(rows[0]["can_raise"])
	assert_eq(tall.count_text(), "can raise %d" % n if n > 0 else "-", "the count")
	assert_eq(tall.hammer().disabled, str(rows[0]["state"]) != "ready", "the hammer follows the state")
