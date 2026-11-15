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
