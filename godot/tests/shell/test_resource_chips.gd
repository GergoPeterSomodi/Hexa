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
	var expected := {"grain": "16", "olive oil": "4", "wine": "4", "salt": "4", "timber": "40", "stone": "40", "iron": "20"}
	assert_eq(amounts, expected, "the Stores card lists the seven goods in store")
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
