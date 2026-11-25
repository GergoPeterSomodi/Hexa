## The hex menu (tile window spec R31; m6-build-spec 6.1 and 6.8; L19, issue #209). Opened by a right click, or O and Shift+F10,
## on an own hex while no army of yours is selected. Items: "Tile details...", "Build here...", "Raise companies..." on your
## settlement, "Select <army>", "Show supply (6)", the war items, "Cancel <work>". Each choice is carried out here: the hex
## selected and the window's tab opened, the army selected, the Supply mode, the work cancelled. Planted faults to catch: a menu
## opened on foreign land, a Raise item on wild land, an item that does nothing, works rows still inline.
extends GutTest

const MAP := "res://shell/map/map_scene.tscn"
const PANEL := "res://shell/panels/tile_window.tscn"
const TAG := ArmyFixture.TAG

var _g: Game
var _scene: MapScene = null
var _panel: TileWindow = null
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
	_panel = (load(PANEL) as PackedScene).instantiate() as TileWindow
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


func test_own_settlement_menu_has_the_r31_items_and_no_inline_works() -> void:
	assert_true(_menu().open_for(_hex, Vector2(10, 10)), "opens on an own hex")
	assert_true(_menu().visible)
	assert_eq(_label_of(&"details"), "Tile details...")
	assert_eq(_label_of(&"raise_tab"), "Raise companies...")
	assert_eq(_label_of(&"map_mode"), "Show supply (6)")
	for entry: Dictionary in _menu().entries():
		assert_ne(StringName(entry["action"][0]), &"work", "no inline works rows: %s" % entry["label"])
	if not ImprovePreview.options_of(_g, TAG, _hex).is_empty():
		assert_eq(_label_of(&"build_tab"), "Build here...")


func test_the_title_is_the_place_name() -> void:
	assert_true(_menu().open_for(_hex, Vector2(10, 10)))
	assert_true(_menu().is_item_separator(0), "the first row is the title")
	assert_eq(_menu().get_item_text(0), Words.place(_g, _hex))


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


func test_build_here_is_offered_only_where_building_is() -> void:
	var hex := _own_hex_with_options()
	if hex == ArmyFixture.NO_HEX:
		pending("no own wild hex with works on this map")
		return
	assert_true(_menu().open_for(hex, Vector2(10, 10)))
	assert_ne(_label_of(&"build_tab"), "", "an own hex with options offers Build here")
	assert_eq(_label_of(&"details"), "Tile details...")


func test_raise_item_selects_the_hex_and_opens_the_army_tab() -> void:
	assert_true(_menu().open_for(_hex, Vector2(10, 10)))
	var id := _menu().item_id_of(&"raise_tab")
	assert_ne(id, -1)
	_menu().id_pressed.emit(id)
	assert_eq(_scene.selected, _hex, "the hex is selected")
	assert_eq(_panel.tab_open(), &"army", "the Army tab opens")
	assert_not_null(_panel.tab_node() as ArmyTab, "and its body is the Army tab")


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


func test_tile_details_selects_the_hex_and_opens_the_land_tab() -> void:
	assert_true(_menu().open_for(_hex, Vector2(10, 10)))
	_panel.show_hex(_hex)
	_panel.show_tab(&"army")
	_menu().id_pressed.emit(_menu().item_id_of(&"details"))
	assert_eq(_scene.selected, _hex, "the hex is selected")
	assert_eq(_panel.tab_open(), &"town", "the Town tab opens")


func test_build_here_selects_the_hex_and_opens_the_buildings_tab() -> void:
	var hex := _own_hex_with_options()
	if hex == ArmyFixture.NO_HEX:
		pending("no own wild hex with works on this map")
		return
	assert_true(_menu().open_for(hex, Vector2(10, 10)))
	_menu().id_pressed.emit(_menu().item_id_of(&"build_tab"))
	assert_eq(_scene.selected, hex)
	assert_eq(_panel.tab_open(), &"town", "the Town tab opens")


func test_cancel_item_cancels_the_work_under_way() -> void:
	var hex := _own_hex_with_options()
	if hex == ArmyFixture.NO_HEX:
		pending("no own wild hex with works on this map")
		return
	assert_true(_menu().open_for(hex, Vector2(10, 10)))
	assert_eq(_label_of(&"cancel_work"), "", "no work, no Cancel item")
	var pick := -1
	for row: Dictionary in ImprovePreview.options_of(_g, TAG, hex):
		if bool((row["verdict"] as Dictionary)["ok"]):
			var verdict := Session.act(str(row["action"]), {"hex": hex, "family": int(row["family"])})
			if bool(verdict["ok"]):
				pick = 1
				break
	if pick == -1:
		pending("no work could be begun on this hex")
		return
	assert_not_null(_g.state.work_at(hex))
	assert_true(_menu().open_for(hex, Vector2(10, 10)))
	assert_true(_label_of(&"cancel_work").begins_with("Cancel "), "the work has a Cancel item")
	_menu().id_pressed.emit(_menu().item_id_of(&"cancel_work"))
	assert_null(_g.state.work_at(hex), "the item cancels the work")


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
