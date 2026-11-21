## CountryPanel tests (docs/architecture/m2-build-spec.md sections 7.4 and 10).
extends GutTest

const PANEL := "res://shell/panels/country_panel.tscn"
const SCENARIO := "north_italy_1480"
const GENOA_FOCUS := Vector2i(8, 13)
const FRANCE_REASON := "France cannot be played here: its capital, Paris, is off this map"

var _panel: CountryPanel = null


func before_each() -> void:
	assert_eq(Session.new_scenario(SCENARIO, 1480), "", "the 1480 scenario starts")
	_panel = (load(PANEL) as PackedScene).instantiate() as CountryPanel
	_panel.theme = KitTheme.load_for(1.0)
	add_child_autofree(_panel)
	watch_signals(_panel)


func after_each() -> void:
	Session.end_game()
	await get_tree().process_frame


func _value_of(key: String) -> String:
	var rows := _panel.ledger_texts()
	for at: int in range(0, rows.size() - 1, 2):
		if rows[at] == key:
			return rows[at + 1]
	return "<missing " + key + ">"


func test_hidden_until_shown_and_framed_as_a_panel() -> void:
	assert_false(_panel.visible, "hidden at the start")
	assert_eq(_panel.shown_tag(), &"")
	assert_eq(_panel.mouse_filter, Control.MOUSE_FILTER_STOP, "a click on the panel never reaches the map")
	assert_eq(_panel.custom_minimum_size.x, float(Tokens.PANEL_W), "width matches Tokens.PANEL_W")
	assert_eq(_panel.cartouche().label().theme_type_variation, &"TitlePanel")


func test_genoa_outside_the_pick_shows_the_ledger_and_links() -> void:
	_panel.show_country(&"GEN", false)
	assert_true(_panel.visible)
	assert_eq(_panel.shown_tag(), &"GEN")
	assert_eq(_panel.cartouche().text, "Genoa", "the cartouche is the short name")
	assert_eq(_panel.long_name_text(), "Republic of Genoa")
	assert_eq(_panel.relation_text(), "", "no player yet: no relation line")
	assert_false(_panel.play_button().visible, "no Play as outside the pick")
	assert_eq(_panel.tip_text(), "", "no tip outside the pick")

	assert_eq(_value_of("Capital"), "Genoa")
	assert_eq(_value_of("Districts"), "14")
	assert_eq(_value_of("Towns"), "2, 1 of them a city")
	assert_true(_value_of("Passes").contains("Cadibona"))
	assert_true(_value_of("Passes").contains("Giovi"))
	var land := CountryCard.of(Session.game, &"GEN")["land"] as Array
	var top := land[0] as Dictionary
	assert_true(_value_of("Land").begins_with("%s %d" % [str(top["cover"]), int(top["count"])]), "the largest cover leads")

	var nbs := _panel.neighbour_buttons()
	assert_eq(nbs.size(), 2)
	assert_eq(nbs[0].text, "Savoy")
	assert_eq(nbs[1].text, "Milan")

	_panel.capital_button().pressed.emit()
	assert_signal_emitted_with_parameters(_panel, "look_at_requested", [GENOA_FOCUS])
	nbs[1].pressed.emit()
	assert_signal_emitted_with_parameters(_panel, "country_requested", [&"MLO"])
	_panel.show_button().pressed.emit()
	assert_signal_emitted_with_parameters(_panel, "look_at_requested", [GENOA_FOCUS], 1)


func test_milan_has_twenty_towns_and_the_relation_follows_the_player() -> void:
	_panel.show_country(&"MLO", false)
	assert_eq(_value_of("Towns"), "20, 2 of them cities")
	assert_eq(_value_of("Districts"), "52")
	assert_eq(_panel.relation_text(), "", "no player: no relation")

	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"})["ok"]))
	_panel.show_country(&"MLO", false)
	assert_eq(_panel.relation_text(), "neighbour", "Milan borders Genoa")
	_panel.show_country(&"GEN", false)
	assert_eq(_panel.relation_text(), "your country")


func test_france_is_an_outside_power_and_its_play_button_shows_the_reason() -> void:
	_panel.show_country(&"FRA", true)
	assert_eq(_panel.relation_text(), "outside power")
	assert_eq(_value_of("Capital"), "Paris, off this map")
	assert_null(_panel.capital_button(), "no capital link off the map")
	assert_false(_panel.show_button().disabled, "the footer shows France's land on the map")
	assert_true(_panel.play_button().visible)
	assert_true(_panel.play_button().disabled, "France cannot be played")
	assert_eq(_panel.play_button().text, "Play as France")
	assert_eq(_panel.play_reason_text(), FRANCE_REASON)
	assert_eq(_panel.play_button().reason_text(), FRANCE_REASON)


func test_lucca_in_the_pick_shows_the_tip_and_plays_as_lucca() -> void:
	_panel.show_country(&"LUC", true)
	var tip := str(CountryCard.of(Session.game, &"LUC")["tip"])
	assert_ne(tip, "")
	assert_eq(_panel.tip_text(), tip)
	assert_eq(_panel.play_button().text, "Play as Lucca")
	assert_false(_panel.play_button().disabled)
	_panel.play_button().pressed.emit()
	assert_signal_emitted_with_parameters(_panel, "play_requested", [&"LUC"])


func test_genoa_in_the_pick_is_refused_once_another_country_is_chosen() -> void:
	_panel.show_country(&"GEN", true)
	assert_false(_panel.play_button().disabled)
	_panel.play_button().pressed.emit()
	assert_signal_emitted_with_parameters(_panel, "play_requested", [&"GEN"])

	assert_true(bool(Session.act("choose_country", {"tag": &"LUC"})["ok"]))
	_panel.show_country(&"GEN", true)
	assert_true(_panel.play_button().disabled, "a country is chosen already")
	assert_ne(_panel.play_reason_text(), "", "the reason is shown")


func test_close_hides_it_and_forgets_the_country() -> void:
	_panel.show_country(&"GEN", false)
	_panel.close_button().pressed.emit()
	assert_false(_panel.visible)
	assert_eq(_panel.shown_tag(), &"")


func test_p_an_unknown_tag_or_no_game_hides_the_panel() -> void:
	_panel.show_country(&"ZZZ", true)
	assert_false(_panel.visible, "no such country: hidden")
	_panel.show_country(&"GEN", false)
	assert_true(_panel.visible)
	Session.end_game()
	_panel.refresh()
	assert_false(_panel.visible, "no game: hidden")

func test_yours_shows_the_exact_treasury_change_and_tax() -> void:
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"})["ok"]))
	var gen := Countries.by_tag(Session.game, &"GEN")
	_panel.show_country(&"GEN", false)
	assert_true(_panel.treasury_visible())
	assert_eq(_panel.treasury_text(), "Treasury " + Words.number(gen.treasury), "the exact treasury")
	assert_true(_panel.change_text().begins_with("Last season"), "last season's change is shown")
	assert_eq(_panel.tax_text(), "Taxes " + Words.tax_name(gen.tax), "the tax name")
	assert_eq(_panel.expected_text(), "Expected this season +%d" % int(EconomyPreview.expected(Session.game, &"GEN")["net"]), "your card carries the expected net")
	assert_true(_panel.study_button().visible, "the study button is yours")
	assert_false(_panel.study_button().disabled)


func test_a_known_foreign_country_is_banded_with_no_change_tax_or_study() -> void:
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"})["ok"]))
	var mlo := Countries.by_tag(Session.game, &"MLO")
	_panel.show_country(&"MLO", false)
	assert_true(_panel.treasury_visible(), "Milan borders Genoa: known")
	assert_eq(_panel.treasury_text(), "Treasury " + Knowledge.band_text(mlo.treasury, ""), "the banded figure")
	if Knowledge.band(mlo.treasury) != mlo.treasury:
		assert_false(_panel.treasury_text().contains(Words.number(mlo.treasury)), "no exact figure anywhere")
	assert_eq(_panel.change_text(), "", "no change for a foreign country")
	assert_eq(_panel.tax_text(), "", "no tax for a foreign country")
	assert_false(_panel.study_button().visible, "the study is yours only")


func test_an_unknown_country_shows_no_treasury_section() -> void:
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"})["ok"]))
	_panel.show_country(&"FRA", false)
	assert_false(_panel.treasury_visible(), "France does not border Genoa")
	assert_eq(_panel.treasury_text(), "")
	assert_false(_panel.study_button().visible)


func test_with_no_player_every_country_is_banded() -> void:
	_panel.show_country(&"GEN", false)
	assert_true(_panel.treasury_visible())
	assert_eq(_panel.change_text(), "", "no change without a player")
	assert_false(_panel.study_button().visible)


func test_the_expected_line_follows_the_card_and_a_banded_card_never_shows_change() -> void:
	var yours := {"shown": true, "value": 658, "banded": false, "change": 48, "expected": 95, "tax": "Normal"}
	_panel._fill_treasury({"treasury": yours})
	assert_eq(_panel.change_text(), "Last season +48")
	assert_eq(_panel.expected_text(), "Expected this season +95")
	yours["expected"] = null
	_panel._fill_treasury({"treasury": yours})
	assert_eq(_panel.expected_text(), "", "a null expected hides the line")
	# planted fault: a banded card that carries change, tax and expected must show none of them
	var banded := {"shown": true, "value": 1900, "banded": true, "change": 50, "expected": 95, "tax": "Normal"}
	_panel._fill_treasury({"treasury": banded})
	assert_eq(_panel.treasury_text(), "Treasury about 1,900")
	assert_eq(_panel.change_text(), "")
	assert_eq(_panel.expected_text(), "")
	assert_eq(_panel.tax_text(), "")


func test_open_the_study_requests_the_study() -> void:
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"})["ok"]))
	_panel.show_country(&"GEN", false)
	_panel.study_button().pressed.emit()
	assert_signal_emitted(_panel, "study_requested")


func test_the_treasury_refreshes_when_a_season_ends() -> void:
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"})["ok"]))
	_panel.show_country(&"GEN", false)
	Countries.by_tag(Session.game, &"GEN").treasury = 999
	Events.season_ended.emit(1)
	assert_eq(_panel.treasury_text(), "Treasury 999")


## The People row (spec 6.4): after Towns; yours exact with last season's change; a known country banded; an unknown
## country has no row; the row refreshes on town_grew and district_declined; the bus is left on exit.
func _listens(sig: Signal, obj: Object) -> bool:
	for conn: Dictionary in sig.get_connections():
		if (conn["callable"] as Callable).get_object() == obj:
			return true
	return false


func _first_settlement(tag: StringName) -> Vector2i:
	var game := Session.game
	var c := Countries.by_tag(game, tag)
	for i: int in Territory.districts(game, c.id):
		if int(game.state.main_use[i]) == ImproveRules.SETTLEMENT:
			return game.map.hex_of(i)
	return Vector2i(-1, -1)


func test_yours_shows_the_people_row_after_towns() -> void:
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"})["ok"]))
	_panel.show_country(&"GEN", false)
	var rows := _panel.ledger_texts()
	assert_eq(rows[4], "Towns", "the row order: Towns")
	assert_eq(rows[6], "People", "People comes right after Towns")
	var sums := PeopleView.totals(Session.game, &"GEN")
	var expected := Words.number(int(sums["people"]))
	var change := int(sums["change"])
	if change != 0:
		expected += " (%s %s last season)" % [PeopleView.UP if change > 0 else PeopleView.DOWN, Words.signed(change)]
	assert_eq(_value_of("People"), expected, "the exact figure with last season's change")


func test_a_known_foreign_country_shows_a_banded_people_row() -> void:
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"})["ok"]))
	_panel.show_country(&"MLO", false)
	var card := CountryCard.of(Session.game, &"MLO")
	var people := int(PeopleView.totals(Session.game, &"MLO")["people"])
	assert_eq(_value_of("People"), Knowledge.band_text(int(card["people"]["value"]), ""), "a banded figure")
	if Knowledge.band(people) != people:
		assert_false(_value_of("People").contains(Words.number(people)), "no exact figure")
	assert_false(_value_of("People").contains("last season"), "no change for a foreign country")


func test_an_unknown_country_has_no_people_row() -> void:
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"})["ok"]))
	_panel.show_country(&"FRA", false)
	assert_true(_panel.visible, "France still has a card")
	assert_eq(_panel.ledger_texts().find("People"), -1, "no People row for an unknown country")


func test_the_people_row_refreshes_on_town_grew_and_district_declined() -> void:
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"})["ok"]))
	_panel.show_country(&"GEN", false)
	var hex := _first_settlement(&"GEN")
	assert_ne(hex, Vector2i(-1, -1), "Genoa has a town")
	var before := int(PeopleView.at(Session.game, &"GEN", hex)["people"])
	assert_true(Session.dev_people(hex, before + 1000), "the town gains 1,000")
	Events.town_grew.emit(&"GEN", hex, 2)
	var total := int(PeopleView.totals(Session.game, &"GEN")["people"])
	assert_true(_value_of("People").begins_with(Words.number(total)), "town_grew refreshes the row")
	assert_true(Session.dev_people(hex, before + 2000))
	Events.district_declined.emit(&"GEN", hex, 1, &"hunger")
	total = int(PeopleView.totals(Session.game, &"GEN")["people"])
	assert_true(_value_of("People").begins_with(Words.number(total)), "district_declined refreshes the row")


func test_leaving_the_tree_disconnects_the_people_signals() -> void:
	var extra := (load(PANEL) as PackedScene).instantiate() as CountryPanel
	extra.theme = KitTheme.load_for(1.0)
	add_child(extra)
	assert_true(_listens(Events.town_grew, extra), "listens to town_grew while in the tree")
	assert_true(_listens(Events.district_declined, extra), "listens to district_declined while in the tree")
	remove_child(extra)
	assert_false(_listens(Events.town_grew, extra), "no town_grew listener after exit")
	assert_false(_listens(Events.district_declined, extra), "no district_declined listener after exit")
	extra.free()
