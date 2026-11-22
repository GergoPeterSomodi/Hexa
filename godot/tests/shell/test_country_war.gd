## The War section of CountryPanel (docs/architecture/m7-build-spec.md section 6.7; issue #240). Genoa (GEN) is the player and
## Milan (MLO) its neighbour; France is an outside power that does not border Genoa. Every button's state and reason come
## from Session.check; a click goes through Session.act; a declaration and a peace ask first (a Confirm when a listener is
## connected, else the two-step). Planted faults: a refused declaration that still acts; a peace without its Confirm.
extends GutTest

const PANEL := "res://shell/panels/country_panel.tscn"
const SCENARIO := "north_italy_1480"
const MLO := &"MLO"
const FRA := &"FRA"

var _panel: CountryPanel = null


func before_each() -> void:
	assert_eq(Session.new_scenario(SCENARIO, 1480), "", "the 1480 scenario starts")
	_panel = (load(PANEL) as PackedScene).instantiate() as CountryPanel
	_panel.theme = KitTheme.load_for(1.0)
	add_child_autofree(_panel)
	watch_signals(_panel)
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"})["ok"]), "Genoa is the player")


func after_each() -> void:
	Session.end_game()
	await get_tree().process_frame


func _war() -> CountryWar:
	return _panel.war_section()


## A listener that keeps the Confirm in the tree, as the App does when it pushes it.
func _listen_and_keep(into: Array) -> void:
	_panel.confirm_requested.connect(func(screen: Screen) -> void:
		add_child_autofree(screen)
		into.append(screen))


func _the(tag: StringName) -> String:
	return Words.country_the(Session.game, tag)


func test_a_neighbour_at_peace_shows_an_enabled_declare_war() -> void:
	_panel.show_country(MLO, false)
	assert_eq(_war().state(), &"peace", "Milan is at peace with Genoa")
	assert_true(_war().visible, "the section is shown")
	var btn := _war().action_button("declare_war")
	assert_not_null(btn, "a Declare war button")
	assert_false(btn.disabled, "a neighbour at peace can be declared on")
	assert_eq(btn.kind, KitButton.Kind.DANGER, "a danger button")


func test_declare_war_asks_first_then_acts_and_toasts() -> void:
	_panel.show_country(MLO, false)
	var asked: Array = []
	_listen_and_keep(asked)
	watch_signals(Events)
	_war().action_button("declare_war").pressed.emit()
	assert_eq(asked.size(), 1, "the Confirm is asked")
	assert_signal_not_emitted(Events, "war_declared", "no war before the answer")
	(asked[0] as Confirm).call("_resolve", &"confirm")
	assert_signal_emitted(Events, "war_declared", "the accepted declaration goes through Session.act")
	assert_eq(_war().state(), &"war", "the section shows the war at once")
	assert_signal_emitted_with_parameters(_panel, "toast_requested", ["War with %s." % _the(MLO), &"plain"])


func test_declare_war_cancelled_changes_nothing() -> void:
	_panel.show_country(MLO, false)
	var asked: Array = []
	_listen_and_keep(asked)
	watch_signals(Events)
	_war().action_button("declare_war").pressed.emit()
	(asked[0] as Confirm).call("_resolve", &"cancel")
	assert_signal_not_emitted(Events, "war_declared", "Cancel is no war")
	assert_eq(_war().state(), &"peace")


func test_a_refused_declaration_is_disabled_with_its_reason() -> void:
	_panel.show_country(FRA, false)
	var btn := _war().action_button("declare_war")
	assert_not_null(btn)
	assert_true(btn.disabled, "France shares no border with Genoa")
	assert_string_contains(btn.reason_text(), "only neighbours go to war", "the check's reason on the button")
	assert_true(_war().reason_texts().has(btn.reason_text()), "and listed under the section")


func test_at_war_shows_the_three_peace_buttons_with_verdicts() -> void:
	assert_true(bool(Session.act("declare_war", {"target": MLO})["ok"]))
	_panel.show_country(MLO, false)
	assert_eq(_war().state(), &"war")
	assert_null(_war().action_button("declare_war"), "no declaration while at war")
	var take := _war().action_button("make_peace", &"take")
	var white := _war().action_button("make_peace", &"white")
	var yielded := _war().action_button("make_peace", &"yield")
	assert_not_null(take)
	assert_not_null(white)
	assert_not_null(yielded)
	assert_true(take.disabled, "Take what you hold needs a district held")
	assert_string_contains(take.reason_text(), "none of their districts")
	assert_true(white.disabled, "a white peace needs seasons of war first")
	assert_string_contains(white.reason_text(), "a white peace needs")


func test_white_peace_after_the_seasons_confirms_then_starts_a_truce() -> void:
	assert_true(bool(Session.act("declare_war", {"target": MLO})["ok"]))
	Session.game.wars[0].start_turn -= 4
	_panel.show_country(MLO, false)
	var white := _war().action_button("make_peace", &"white")
	assert_false(white.disabled, "four seasons of war: a white peace is allowed")
	var asked: Array = []
	_listen_and_keep(asked)
	watch_signals(Events)
	white.pressed.emit()
	assert_eq(asked.size(), 1, "the peace is asked first")
	assert_signal_not_emitted(Events, "peace_made", "no peace before the answer")
	(asked[0] as Confirm).call("_resolve", &"confirm")
	assert_signal_emitted(Events, "peace_made", "the accepted peace goes through Session.act")
	assert_eq(_war().state(), &"truce", "after the peace the section shows the truce")
	assert_signal_emitted_with_parameters(_panel, "toast_requested",
		["Peace with %s: everything returns to its owner." % _the(MLO), &"plain"])


func test_in_a_truce_declare_war_is_off_with_the_truce_reason() -> void:
	assert_true(bool(Session.act("declare_war", {"target": MLO})["ok"]))
	Session.game.wars[0].start_turn -= 4
	assert_true(bool(Session.act("make_peace", {"target": MLO, "terms": "white"})["ok"]))
	_panel.show_country(MLO, false)
	assert_eq(_war().state(), &"truce")
	var lines := ""
	for child: Node in _war().find_children("*", "Label", true, false):
		lines += (child as Label).text + "\n"
	assert_string_contains(lines, "Truce until", "the truce line")
	var btn := _war().action_button("declare_war")
	assert_true(btn.disabled, "no declaration in a truce")
	assert_string_contains(btn.reason_text(), "truce", "the truce is the reason")


func test_your_own_card_lists_wars_and_truces_with_links_and_no_buttons() -> void:
	assert_true(bool(Session.act("declare_war", {"target": MLO})["ok"]))
	_panel.show_country(&"GEN", false)
	assert_eq(_war().state(), &"self")
	assert_null(_war().action_button("declare_war"), "no declaration on your own card")
	assert_null(_war().action_button("make_peace", &"take"), "no peace buttons on your own card")
	var links := _war().find_children("*", "KitButton", true, false)
	assert_eq(links.size(), 1, "one link per war")
	(links[0] as KitButton).pressed.emit()
	assert_signal_emitted_with_parameters(_panel, "country_requested", [MLO])


func test_without_a_listener_the_first_press_arms_and_the_second_declares() -> void:
	_panel.show_country(MLO, false)
	_war().action_button("declare_war").pressed.emit()
	assert_eq(_war().state(), &"peace", "the first press only arms the declaration")
	assert_string_contains(_war().notice_text(), "Press Declare war again", "a visible notice says so")
	_war().action_button("declare_war").pressed.emit()
	assert_eq(_war().state(), &"war", "the second press declares")


func test_a_listener_that_does_not_take_the_confirm_falls_back_to_two_steps() -> void:
	var seen: Array = []
	_panel.confirm_requested.connect(func(screen: Screen) -> void: seen.append(screen))
	_panel.show_country(MLO, false)
	_war().action_button("declare_war").pressed.emit()
	assert_eq(seen.size(), 1, "the Confirm was offered")
	assert_false(is_instance_valid(seen[0]), "the Confirm nobody took on is freed")
	assert_eq(_war().state(), &"peace", "nothing declared")
	assert_string_contains(_war().notice_text(), "Press Declare war again")


func test_a_declaration_made_elsewhere_refreshes_the_section() -> void:
	_panel.show_country(MLO, false)
	assert_eq(_war().state(), &"peace")
	assert_true(bool(Session.act("declare_war", {"target": MLO})["ok"]))
	assert_eq(_war().state(), &"war", "war_declared refreshes the section")


func test_the_buttons_take_keyboard_focus_in_order() -> void:
	assert_true(bool(Session.act("declare_war", {"target": MLO})["ok"]))
	Session.game.wars[0].start_turn -= 4
	_panel.show_country(MLO, false)
	var keys: Array[String] = []
	for child: Node in _war().find_children("*", "KitButton", true, false):
		assert_eq((child as Control).focus_mode, Control.FOCUS_ALL, "every war button takes focus")
		keys.append(str(child.get_meta(&"key")))
	assert_eq(keys, ["make_peace:take", "make_peace:white", "make_peace:yield"], "take, white, yield in order")


func test_no_state_hides_the_section() -> void:
	_war().fill(MLO, {"state": &"none"}, false)
	assert_false(_war().visible, "no player: no section")
