## The hex menu (docs/architecture/m6-build-spec.md 6.1 and 6.8; L19, issue #209). Opened by a right click, or O and Shift+F10,
## on an own hex while no army of yours is selected. Items: the hex's works (a refused one disabled), "Raise companies here..."
## on your settlement, "Select the Army of X", "Show supply (6)". Each choice is carried out here: the hex selected and its Raise
## tab opened, the army selected, the Supply mode, a work begun through the hex panel. Planted faults to catch: a menu opened on
## foreign land, a Raise item on wild land, an item that does nothing.
extends GutTest

const MAP := "res://shell/map/map_scene.tscn"
const PANEL := "res://shell/panels/hex_panel.tscn"
const TAG := ArmyFixture.TAG

var _g: Game
var _scene: MapScene = null
var _panel: HexPanel = null
var _hex := Vector2i(-1, -1)


func before_each() -> void:
	_g = ArmyFixture.game()
	_hex = ArmyFixture.find_town(_g)
	ArmyFixture.town(_g, _hex)
	ArmyFixture.rich(_g)
	Session.start_game(_g)
	_scene = (load(MAP) as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_panel = (load(PANEL) as PackedScene).instantiate() as HexPanel
	_panel.theme = KitTheme.load_for(1.0)
	add_child_autofree(_panel)
	_scene.set_panel(_panel)


func after_each() -> void:
	Session.end_game()
	await get_tree().process_frame


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


func _menu() -> HexMenu:
	for child: Node in _armies().get_children():
		if child is HexMenu:
			return child as HexMenu
	return null


func _label_of(kind: StringName) -> String:
	for entry: Dictionary in _menu().entries():
		if StringName(entry["action"][0]) == kind:
			return str(entry["label"])
	return ""


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


## An own wild hex with works to build and no work under way (the work items need one).
func _own_hex_with_options() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if _g.map.is_land(hex) and Territory.owner_tag(_g, hex) == TAG and _g.state.work_at(hex) == null \
				and Improve.piece_at(_g, hex).is_empty() and not ImprovePreview.options_of(_g, TAG, hex).is_empty():
			return hex
	return ArmyFixture.NO_HEX


func test_own_settlement_menu_has_the_raise_and_supply_items() -> void:
	assert_true(_menu().open_for(_hex, Vector2(10, 10)), "opens on an own hex")
	assert_true(_menu().visible)
	assert_eq(_label_of(&"raise_tab"), "Raise companies here...")
	assert_eq(_label_of(&"map_mode"), "Show supply (6)")
	var works := 0
	for entry: Dictionary in _menu().entries():
		if StringName(entry["action"][0]) == &"work":
			works += 1
	assert_eq(works, ImprovePreview.options_of(_g, TAG, _hex).size(), "one item a works option of the hex")


func test_foreign_hex_opens_nothing() -> void:
	assert_false(_menu().open_for(_foreign_land(), Vector2(10, 10)))
	assert_false(_menu().visible)
	assert_eq(_menu().entries().size(), 0)


func test_wild_own_land_has_no_raise_item() -> void:
	var wild := _own_wild_land()
	assert_true(_menu().open_for(wild, Vector2(10, 10)))
	assert_eq(_label_of(&"raise_tab"), "", "Raise companies is for settlements")
	assert_ne(_label_of(&"map_mode"), "", "the supply item is still there")


func test_army_items_name_each_army_of_yours_on_the_hex() -> void:
	var army := ArmyFixture.army(_g, TAG, _hex, 0, 2)
	_g.version += 1
	assert_true(_menu().open_for(_hex, Vector2(10, 10)))
	assert_eq(_label_of(&"select_army"), "Select %s" % army.name)


func test_refused_works_are_disabled() -> void:
	var hex := _own_hex_with_options()
	if hex == ArmyFixture.NO_HEX:
		pending("no own wild hex with works on this map")
		return
	Countries.by_tag(_g, TAG).treasury = 0
	assert_true(_menu().open_for(hex, Vector2(10, 10)))
	var works := 0
	for entry: Dictionary in _menu().entries():
		if StringName(entry["action"][0]) == &"work":
			works += 1
			assert_false(bool(entry["enabled"]), "no ducats: %s is disabled" % entry["label"])
	assert_gt(works, 0)


func test_raise_item_selects_the_hex_and_opens_the_raise_tab() -> void:
	assert_true(_menu().open_for(_hex, Vector2(10, 10)))
	var id := _menu().item_id_of(&"raise_tab")
	assert_ne(id, -1)
	_menu().id_pressed.emit(id)
	assert_eq(_scene.selected, _hex, "the hex is selected")
	assert_eq(_panel.tab_open(), &"raise", "the Raise tab opens")
	assert_true(_panel.raise_list().visible)


func test_select_army_item_selects_the_army() -> void:
	var army := ArmyFixture.army(_g, TAG, _hex, 0, 2)
	_g.version += 1
	assert_true(_menu().open_for(_hex, Vector2(10, 10)))
	_menu().id_pressed.emit(_menu().item_id_of(&"select_army"))
	assert_eq(_armies().selected_army(), army.id, "the army is selected")


func test_show_supply_switches_the_map_mode() -> void:
	assert_true(_menu().open_for(_hex, Vector2(10, 10)))
	_menu().id_pressed.emit(_menu().item_id_of(&"map_mode"))
	assert_eq(_scene.mode(), MapModes.Mode.SUPPLY, "the Supply mode is on")


func test_work_item_begins_the_work_through_the_hex_panel() -> void:
	var hex := _own_hex_with_options()
	if hex == ArmyFixture.NO_HEX:
		pending("no own wild hex with works on this map")
		return
	assert_true(_menu().open_for(hex, Vector2(10, 10)))
	var pick := -1
	for entry: Dictionary in _menu().entries():
		var action: Array = entry["action"]
		if StringName(action[0]) == &"work" and bool(entry["enabled"]) and not bool((action[2] as Dictionary)["expensive"]):
			pick = int(entry["id"])
			break
	if pick == -1:
		pending("no cheap enabled work on this hex")
		return
	_menu().id_pressed.emit(pick)
	assert_not_null(_g.state.work_at(hex), "the work is begun")


func test_right_click_on_own_hex_without_an_army_opens_the_menu() -> void:
	var px := _scene.view().centre_of(_hex)
	_scene.map_input().command_requested.emit(px)
	assert_true(_menu().visible, "the right click opens the hex menu")
	assert_eq(_scene.selected, MapScene.NO_HEX, "the hex selection clears as before")


func test_right_click_on_foreign_land_opens_nothing() -> void:
	_scene.map_input().command_requested.emit(_scene.view().centre_of(_foreign_land()))
	assert_false(_menu().visible)


func test_right_click_with_an_army_selected_orders_and_no_menu() -> void:
	var army := ArmyFixture.army(_g, TAG, _hex, 0, 1)
	_g.version += 1
	_armies().select_army(army.id)
	assert_true(_armies().command(_hex), "with an army selected the click is an order")
	assert_false(_menu().visible, "no menu over an order")


func test_key_o_with_no_army_opens_the_menu_at_the_selected_hex() -> void:
	_scene.select_hex(_hex)
	_scene.map_input().command_key_requested.emit()
	assert_true(_menu().visible, "O opens the menu at the selected hex")
	assert_ne(_label_of(&"raise_tab"), "")
