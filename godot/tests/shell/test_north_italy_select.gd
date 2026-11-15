## Selecting a hex on the north Italy map: every hex centre finds its own hex, a point outside the map finds none, and
## selecting shows the panel while clearing hides it. Skipped when the baked art is missing.
extends GutTest

var _map: NorthItalyMap = null


func before_all() -> void:
	var scene: PackedScene = load("res://shell/worldmap/north_italy_map.tscn")
	_map = scene.instantiate() as NorthItalyMap
	add_child(_map)


func after_all() -> void:
	_map.queue_free()


func test_every_centre_finds_its_hex() -> void:
	if not _map.is_loaded():
		pending("the north Italy bake is missing")
		return
	var checked := 0
	for hex: Vector2i in _map.improve.hexes:
		assert_eq(_map.hex_at(_map.centre_of(hex)), hex, "centre of %s" % hex)
		checked += 1
	assert_gt(checked, 50, "the map has its land hexes")


func test_a_point_off_the_map_finds_nothing() -> void:
	if not _map.is_loaded():
		pending("the north Italy bake is missing")
		return
	assert_eq(_map.hex_at(Vector2(-5000.0, -5000.0)), NorthItalyMap.NO_HEX)


func test_select_and_clear() -> void:
	if not _map.is_loaded():
		pending("the north Italy bake is missing")
		return
	var hex: Vector2i = _map.improve.hexes[0]
	_map.select_hex(hex)
	assert_eq(_map.selected, hex)
	_map.select_hex(NorthItalyMap.NO_HEX)
	assert_eq(_map.selected, NorthItalyMap.NO_HEX)


# ----- build, upgrade and clear from the panel ----------------------------------------------------------------------


func before_each() -> void:
	if _map.is_loaded():
		_map.select_hex(NorthItalyMap.NO_HEX)
		_map.with_villages = true
		_map.reroll(NorthItalyMap.START_SEED)


## A wild hex that offers wheat.
func _wild_wheat_hex() -> Vector2i:
	for hex: Vector2i in _map.improve.hexes:
		if _map.improve.family_at(hex) != ImproveRules.NONE:
			continue
		for o: Dictionary in _map.improve.build_options(hex):
			if int(o["family_id"]) == ImproveRules.WHEAT and bool(o["ok"]):
				return hex
	return NorthItalyMap.NO_HEX


func _button(text_start: String) -> Button:
	for b: Button in _map.action_buttons():
		if b.text.begins_with(text_start):
			return b
	return null


func test_the_panel_takes_the_mouse_and_a_wild_hex_lists_its_builds() -> void:
	if not _map.is_loaded():
		pending("the north Italy bake is missing")
		return
	var hex := _wild_wheat_hex()
	assert_ne(hex, NorthItalyMap.NO_HEX)
	_map.select_hex(hex)
	var panel := _map.get_node("Hud/InfoMargin/InfoPanel") as Control
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_STOP, "a click on the panel does not reach the map")
	var wheat := _button("Build Wheat")
	assert_not_null(wheat, "a wild hex offers wheat")
	assert_eq(wheat.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_false(wheat.disabled)
	assert_null(_button("Upgrade"), "nothing to upgrade on a wild hex")


func test_build_then_upgrade_changes_the_piece_and_keeps_the_selection() -> void:
	if not _map.is_loaded():
		pending("the north Italy bake is missing")
		return
	var hex := _wild_wheat_hex()
	_map.select_hex(hex)
	var pieces_before := int(_map.stats["pieces"])
	_button("Build Wheat").pressed.emit()
	assert_eq(_map.improve.family_at(hex), ImproveRules.WHEAT)
	assert_eq(_map.selected, hex, "the selection stays")
	assert_eq(int(_map.stats["pieces"]), pieces_before + 1, "the map is drawn again")
	assert_eq(_map.change_count(), 1)
	var up := _button("Upgrade")
	assert_not_null(up, "a built hex offers the next level")
	assert_not_null(_button("Clear"))
	assert_eq(_map.improve.upgrade_check(hex)["ok"], not up.disabled)
	if not up.disabled:
		_map.upgrade_selected()
		assert_eq(_map.improve.level_at(hex), 2)
	else:
		assert_ne(up.tooltip_text, "", "a refused upgrade says why")
	_map.clear_selected()
	assert_eq(_map.improve.family_at(hex), ImproveRules.NONE)
	assert_eq(_map.selected, hex)
	assert_null(_button("Upgrade"))
	assert_not_null(_button("Build Wheat"), "wild again: the list is back")


func test_a_refused_button_is_disabled_with_the_reason() -> void:
	if not _map.is_loaded():
		pending("the north Italy bake is missing")
		return
	var town := NorthItalyMap.NO_HEX
	for hex: Vector2i in _map.improve.hexes:
		if _map.improve.is_fixed(hex) and _map.improve.family_at(hex) == ImproveRules.SETTLEMENT:
			town = hex
			break
	_map.select_hex(town)
	var clear_button := _button("Clear")
	assert_not_null(clear_button)
	assert_true(clear_button.disabled, "a place of the map is never pulled down")
	assert_ne(clear_button.tooltip_text, "")
	var before := _map.change_count()
	_map.clear_selected()
	assert_eq(_map.change_count(), before, "a refused change is not kept")


func test_changes_survive_a_season_and_v_and_r_drops_them() -> void:
	if not _map.is_loaded():
		pending("the north Italy bake is missing")
		return
	var hex := _wild_wheat_hex()
	_map.select_hex(hex)
	_map.build_selected(ImproveRules.WHEAT)
	_map.set_season("winter")
	assert_eq(_map.improve.family_at(hex), ImproveRules.WHEAT, "a new season keeps it")
	_map.set_season("summer")
	_map.set_villages(false)
	assert_eq(_map.change_count() == 1, _map.improve.family_at(hex) == ImproveRules.WHEAT, "V played the change again")
	_map.set_villages(true)
	_map.reroll(NorthItalyMap.START_SEED + 1)
	assert_eq(_map.change_count(), 0, "a new seed starts a new map")
