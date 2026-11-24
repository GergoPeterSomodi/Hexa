## GUT tests for the top bar's resource chips (docs/architecture/m4-build-spec.md 6.3): the Ducats and Stores values and
## hover cards from EconomyCards (Genoa, seed 1480: 610 ducats, +86 expected), the refreshes on the bus, the click that
## asks for the study, the hiding in the sandbox, in the country pick and after the game ends, and the narrowing.
extends GutTest

const CHIPS_SCENE := "res://shell/hud/chips.tscn"
const GEN := &"GEN"
const SCENARIO := "north_italy_1480"

var _harness: UIHarness = null
var _root: Control = null
var _chips: Chips = null
var _prev_game: Game = null
var _prev_unsaved: int = 0
var _old_save_dir: String = ""
var _old_lock_path: String = ""


func before_each() -> void:
	_old_save_dir = Session.save_dir
	_old_lock_path = RunLock.path
	Session.save_dir = "user://test_chips_saves"
	RunLock.path = "user://test_chips_running.lock"
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	_harness = UIHarness.new()
	_harness.mount(self)
	_root = VBoxContainer.new()
	_root.theme = KitTheme.load_for(1.0)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_harness.viewport.add_child(_root)
	_chips = (load(CHIPS_SCENE) as PackedScene).instantiate() as Chips
	_root.add_child(_chips)


func after_each() -> void:
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Session.save_dir = _old_save_dir
	RunLock.path = _old_lock_path
	_chips = null
	_root = null
	_harness = null


## Genoa as the player in the committed scenario at seed 1480 (the start the owner playtested).
func _genoa() -> void:
	assert_eq(Session.new_scenario(SCENARIO, 1480, GEN), "", "the committed scenario starts with Genoa chosen")
	_chips.refresh()


## The amounts of a card's rows by their text, lower-cased (the Stores card: good name to stock).
func _amounts(card: Dictionary) -> Dictionary:
	var out := {}
	for row: Variant in card["lines"] as Array:
		var r := row as Array
		if r.size() >= 3:
			out[str(r[0]).to_lower()] = str(r[2])
	return out


## The amount text of the row with this text ("" when there is no such row).
func _amount_of(card: Dictionary, text: String) -> String:
	for row: Variant in card["lines"] as Array:
		var r := row as Array
		if r.size() >= 3 and str(r[0]) == text:
			return str(r[2])
	return ""


func test_hidden_in_the_sandbox() -> void:
	Session.new_game(MapScene.MAP_ID, 1480)
	_chips.refresh()
	assert_false(_chips.visible, "a map sandbox has no countries: no chips")


func test_hidden_in_the_country_pick() -> void:
	assert_eq(Session.new_scenario(SCENARIO, 1480), "", "the scenario starts with no player")
	assert_eq(Session.player_tag(), &"", "the pick is open")
	_chips.refresh()
	assert_false(_chips.visible, "no country chosen: no chips")


func test_hidden_after_the_game_ends() -> void:
	_genoa()
	assert_true(_chips.visible, "precondition: the chips show")
	Session.end_game()
	assert_false(_chips.visible, "no game, no chips")


func test_ducats_chip_shows_the_treasury_and_the_expected_card() -> void:
	_genoa()
	assert_true(_chips.visible, "the chips show for Genoa")
	assert_eq(_chips.ducats_chip().value_label().text, "610", "Ducats 610")
	assert_eq(_chips.ducats_chip().name_label().text, "Ducats")
	var card := _chips.ducats_card()
	assert_eq(card["title"], "Ducats")
	assert_eq(_amount_of(card, "Expected this season"), "▲ +86", "Expected this season +86")
	var lines := card["lines"] as Array
	assert_eq((lines[0] as Array)[0], "No season has ended yet.", "no season has ended yet")
	assert_eq(str((lines[-1] as Array)[0]), "L: the Economy page", "the hint is the last row")


func test_stores_chip_shows_the_worth_and_the_stock_card() -> void:
	_genoa()
	var stores := EconomyCards.stores(Session.game, GEN)
	assert_eq(_chips.stores_chip().value_label().text, Words.number(int(stores["value"])), "value at price")
	assert_eq(_chips.stores_chip().name_label().text, "Stores")
	var amounts := _amounts(_chips.stores_card())
	var expected := {"grain": "16", "olive oil": "4", "wine": "4", "salt": "4", "horses": "10", "timber": "40", "stone": "40", "iron": "20", "copper": "5"}
	assert_eq(amounts, expected, "the Stores card lists the nine goods in store (M6: horses and copper join)")
	assert_eq(str((_chips.stores_card()["lines"] as Array)[-1][0]), "The reserve keeps four seasons of the towns' needs; the rest is sold.",
		"the Stores hint")


func test_the_numbers_follow_the_bus() -> void:
	_genoa()
	var c := Countries.by_tag(Session.game, GEN)
	var emits: Array[Callable] = [
		func() -> void: Events.game_started.emit(),
		func() -> void: Events.country_chosen.emit(GEN),
		func() -> void: Events.season_ended.emit(1),
		func() -> void: Events.tax_set.emit(GEN, 1),
		func() -> void: Events.work_started.emit(GEN, Vector2i.ZERO, {}),
		func() -> void: Events.work_finished.emit(GEN, Vector2i.ZERO, {}),
		func() -> void: Events.work_cancelled.emit(GEN, Vector2i.ZERO, {}, &"order"),
	]
	for emit: Callable in emits:
		c.treasury += 1
		emit.call()
		await get_tree().process_frame  # work_finished refreshes the chips at the next idle frame (issue 441)
		assert_eq(_chips.ducats_chip().value_label().text, Words.number(c.treasury), "the Ducats chip follows the treasury")


func test_dev_money_and_goods_show_after_a_refresh() -> void:
	# Session.dev_money and dev_goods emit no event: the caller refreshes the chips.
	_genoa()
	assert_true(Session.dev_money(GEN, 50), "dev money goes through")
	_chips.refresh()
	assert_eq(_chips.ducats_chip().value_label().text, "660", "the Ducats chip after dev money")
	var before := _chips.stores_chip().value_label().text
	assert_true(Session.dev_goods(GEN, 0, 10), "dev goods go through")
	_chips.refresh()
	assert_ne(_chips.stores_chip().value_label().text, before, "the Stores chip after dev goods")


func test_a_click_on_either_chip_asks_for_the_study() -> void:
	_genoa()
	var asked: Array[StringName] = []
	_chips.study_requested.connect(func(tab: StringName) -> void: asked.append(tab))
	_chips.ducats_chip().pressed.emit()
	assert_eq(asked, [&"this_season"] as Array[StringName], "the Ducats chip asks for This season")
	_chips.stores_chip().pressed.emit()
	assert_eq(asked, [&"this_season", &"goods"] as Array[StringName], "the Stores chip asks for Goods")


func test_narrowing_hides_the_stores_name_and_the_changes() -> void:
	_genoa()
	_chips.set_narrow(true)
	assert_true(_chips.is_narrow(), "narrow")
	assert_false(_chips.stores_chip().name_label().visible, "the Stores name hides")
	assert_true(_chips.ducats_chip().name_label().visible, "the Ducats name stays")
	assert_false(_chips.ducats_chip().delta_chip().visible, "the Ducats change hides")
	assert_false(_chips.stores_chip().delta_chip().visible, "the Stores change hides")
	assert_true(_chips.ducats_chip().value_label().visible, "the values stay")
	_chips.set_narrow(false)
	assert_true(_chips.stores_chip().name_label().visible, "the Stores name returns")
	assert_true(_chips.ducats_chip().delta_chip().visible, "the Ducats change returns")
	assert_true(_chips.stores_chip().delta_chip().visible, "the Stores change returns")


func test_refresh_hotkeys_is_a_no_op() -> void:
	_genoa()
	_chips.refresh_hotkeys()
	assert_true(_chips.visible, "still shown")
	assert_eq(_chips.ducats_chip().value_label().text, "610", "the values are unchanged")


func test_accessibility_names_come_from_the_chips() -> void:
	_genoa()
	assert_true(_chips.ducats_chip().accessibility_name.begins_with("Ducats: 610"), "Ducats name: %s" % _chips.ducats_chip().accessibility_name)
	assert_true(_chips.stores_chip().accessibility_name.begins_with("Stores: "), "Stores name: %s" % _chips.stores_chip().accessibility_name)


func test_a_reparented_widget_still_follows_the_bus() -> void:
	# A top-bar relayout removes the widget and adds it back: the bus links must survive.
	_genoa()
	_root.remove_child(_chips)
	_root.add_child(_chips)
	var c := Countries.by_tag(Session.game, GEN)
	c.treasury += 100
	Events.tax_set.emit(GEN, 2)
	assert_eq(_chips.ducats_chip().value_label().text, Words.number(c.treasury), "tax_set after a reparent refreshes")


## The texts of a card's rows (the first cell of each row).
func _row_texts(card: Dictionary) -> Array:
	var out: Array = []
	for row: Variant in card["lines"] as Array:
		out.append(str((row as Array)[0]))
	return out


func test_the_people_chip_shows_the_people_and_its_card() -> void:
	_genoa()
	var data := PeopleCards.people(Session.game, GEN)
	assert_false(data.is_empty(), "Genoa has people")
	assert_true(_chips.people_chip().is_visible_in_tree(), "the People chip shows for Genoa")
	assert_eq(_chips.people_chip().value_label().text, Words.number(int(data["value"])), "the People value")
	assert_eq(_chips.people_chip().name_label().text, "People", "the People name")
	assert_eq(_chips.people_card()["title"], "People", "the People card title")
	assert_eq(_amount_of(_chips.people_card(), "Towns"), Words.number(int(PeopleView.totals(Session.game, GEN)["towns"])),
		"the card's Towns amount")
	var lines := _chips.people_card()["lines"] as Array
	assert_eq(str((lines[-1] as Array)[0]), PeopleCards.HINT, "the People hint is the last row")
	assert_eq(str((lines[-2] as Array)[0]), "", "a rule above the hint")


func test_the_people_change_shows_only_once_a_season_has_closed() -> void:
	_genoa()
	assert_false(_chips.people_chip().delta_chip().visible, "no season yet: no change on the chip")
	assert_false(_chips.food_chip().delta_chip().visible, "no season yet: no change on the Food chip")
	assert_true("No season has ended yet." in _row_texts(_chips.people_card()), "the card says no season has ended")
	var turn := Session.game.turn
	Session.end_season()
	assert_eq(Session.game.turn, turn + 1, "a season ends")
	assert_true(_chips.people_chip().delta_chip().visible, "after a season the People change shows")
	assert_false("No season has ended yet." in _row_texts(_chips.people_card()), "the card has its flows now")


func test_the_food_chip_shows_the_grain_and_fish_in_store() -> void:
	_genoa()
	var g := Session.game
	var c := Countries.by_tag(g, GEN)
	var grain := g.defs.good_id(&"grain")
	var fish := g.defs.good_id(&"fish")
	var expected := c.stock[grain] + (c.stock[fish] if fish >= 0 else 0)
	assert_true(_chips.food_chip().is_visible_in_tree(), "the Food chip shows for Genoa")
	assert_eq(_chips.food_chip().value_label().text, Words.number(expected), "the Food value is grain and fish in store")
	assert_eq(_chips.food_chip().name_label().text, "Food", "the Food name")
	assert_eq(_chips.food_card()["title"], "Food", "the Food card title")
	var lines := _chips.food_card()["lines"] as Array
	assert_eq(str((lines[-1] as Array)[0]), PeopleCards.HINT, "the Food hint is the last row")


func test_a_bad_food_card_puts_its_first_line_in_the_bad_tone() -> void:
	var data := {"title": "Food", "tone": &"bad", "hint": "h", "lines": [["Made 1", &"plain", ""], ["Eaten 2", &"plain", ""]]}
	var card := Chips._card_of(data)
	assert_eq((card["lines"] as Array)[0][1], &"bad", "the first line is bad when the towns went hungry")
	assert_eq((card["lines"] as Array)[1][1], &"plain", "the other lines keep their tone")
	var fine := Chips._card_of({"title": "Food", "tone": &"plain", "hint": "h", "lines": [["Made 1", &"plain", ""]]})
	assert_eq((fine["lines"] as Array)[0][1], &"plain", "a fed country keeps the tone")


func test_a_click_on_people_or_food_asks_for_the_people_page() -> void:
	_genoa()
	var pages: Array[StringName] = []
	var tabs: Array[StringName] = []
	_chips.page_requested.connect(func(page: StringName) -> void: pages.append(page))
	_chips.study_requested.connect(func(tab: StringName) -> void: tabs.append(tab))
	_chips.people_chip().pressed.emit()
	_chips.food_chip().pressed.emit()
	assert_eq(pages, [&"people", &"people"] as Array[StringName], "both chips ask for the People page")
	assert_eq(tabs.size(), 0, "the Economy tabs are not asked for")


func test_people_and_food_are_hidden_in_the_sandbox_and_the_pick() -> void:
	Session.new_game(MapScene.MAP_ID, 1480)
	_chips.refresh()
	assert_false(_chips.people_chip().is_visible_in_tree(), "the sandbox: no People chip")
	assert_false(_chips.food_chip().is_visible_in_tree(), "the sandbox: no Food chip")
	assert_eq(Session.new_scenario(SCENARIO, 1480), "", "the scenario starts")
	_chips.refresh()
	assert_false(_chips.people_chip().is_visible_in_tree(), "the pick: no People chip")
	assert_false(_chips.food_chip().is_visible_in_tree(), "the pick: no Food chip")


func test_people_and_food_hide_after_the_game_ends() -> void:
	_genoa()
	Session.end_game()
	assert_false(_chips.people_chip().is_visible_in_tree(), "no game: no People chip")
	assert_false(_chips.food_chip().is_visible_in_tree(), "no game: no Food chip")


func test_the_order_of_the_chips_is_ducats_people_food_stores() -> void:
	var names: Array[String] = []
	for child: Node in _chips.get_children():
		names.append(child.name)
	assert_eq(names, ["Ducats", "People", "Food", "Army", "Stores"] as Array[String], "the chips' order (M6: Army between Food and Stores)")


## M6 (L21): the Army chip shows the men under arms of the player's country, its change and its card (MilitaryCards.army).
func test_the_army_chip_shows_the_men_and_its_card() -> void:
	_genoa()
	var army := _chips.army_chip()
	assert_true(army.visible, "a player: the Army chip shows")
	assert_eq(army.value_label().text, "0", "no army yet: no men")
	assert_eq(_chips.army_card()["title"], "Men under arms")
	var game := Session.game
	ArmyFixture.army(game, GEN, ArmyFixture.find_town(game), 0, 2)
	_chips.refresh()
	assert_eq(army.value_label().text, Words.number(Armies.men_of_country(game, GEN)))
	var lines := _chips.army_card()["lines"] as Array
	assert_eq(str((lines[0] as Array)[0]), "1 army, 2 companies", "the first line counts the armies and companies")
	assert_eq(str((lines[lines.size() - 1] as Array)[0]), "Click: the Military page", "the hint is the last row")


## A raise through Session.act reaches the Army and Ducats chips on the bus (army_raised), with no refresh() by the test.
func test_a_raise_through_the_door_updates_the_army_and_ducats_chips() -> void:
	_genoa()
	var army := _chips.army_chip()
	var ducats := _chips.ducats_chip()
	var game := Session.game
	var hex := ArmyFixture.find_town(game)
	ArmyFixture.town(game, hex)
	ArmyFixture.rich(game)
	_chips.refresh()
	assert_eq(army.value_label().text, "0", "no men before the raise")
	var kinds := Military.raise_options(game, GEN, hex)
	assert_false(kinds.is_empty(), "a raise is on offer")
	var verdict := Session.act("raise", {"hex": hex, "kind": int(kinds[0]["kind"]), "count": 1})
	assert_true(bool(verdict.get("ok", false)), str(verdict))
	var men := Armies.men_of_country(game, GEN)
	assert_gt(men, 0)
	assert_eq(army.value_label().text, Words.number(men), "the Army chip follows the raise on the bus")
	assert_eq(ducats.value_label().text, Words.number(Countries.by_tag(game, GEN).treasury), "the Ducats chip follows the raise's cost")


func test_a_click_on_the_army_chip_asks_for_the_military_page() -> void:
	_genoa()
	var pages: Array[StringName] = []
	_chips.page_requested.connect(func(page: StringName) -> void: pages.append(page))
	_chips.army_chip().pressed.emit()
	assert_eq(pages, [&"military"] as Array[StringName], "the Army chip asks for the Military page")


func test_the_army_chip_never_shows_a_name_and_narrows_its_change() -> void:
	_genoa()
	assert_false(_chips.army_chip().name_label().visible, "no Army name at any width")
	assert_true(_chips.army_chip().delta_chip().visible, "the Army change shows")
	_chips.set_narrow(true)
	assert_false(_chips.army_chip().name_label().visible, "still no name when narrow")
	assert_false(_chips.army_chip().delta_chip().visible, "the Army change hides when narrow")
	assert_true(_chips.army_chip().value_label().visible, "the Army value stays")
	_chips.set_narrow(false)
	assert_true(_chips.army_chip().delta_chip().visible, "the Army change returns")
	Session.new_game(MapScene.MAP_ID, 1480)
	_chips.refresh()
	assert_false(_chips.wanted(&"army"), "the sandbox has no Army chip")


func test_narrowing_hides_food_then_the_people_name_and_keeps_the_values() -> void:
	_genoa()
	_chips.set_narrow(true)
	assert_false(_chips.food_chip().name_label().visible, "the Food name hides")
	assert_false(_chips.people_chip().name_label().visible, "the People name hides")
	assert_true(_chips.people_chip().value_label().visible, "the People value stays")
	assert_true(_chips.food_chip().value_label().visible, "the Food value stays")
	_chips.set_narrow(false)
	assert_true(_chips.people_chip().name_label().visible, "the People name returns")
	assert_true(_chips.food_chip().name_label().visible, "the Food name returns")


func test_the_people_and_food_follow_the_bus() -> void:
	_genoa()
	var food_before := _chips.food_chip().value_label().text
	Events.season_ended.emit(1)
	assert_eq(_chips.food_chip().value_label().text, food_before, "a refresh on season_ended keeps the Food value")
	assert_eq(_chips.people_chip().value_label().text, Words.number(int(PeopleCards.people(Session.game, GEN)["value"])),
		"the People chip reads the card after the bus")
