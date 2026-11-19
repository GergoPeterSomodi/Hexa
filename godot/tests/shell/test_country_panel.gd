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
