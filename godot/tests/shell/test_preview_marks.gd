## The map marks of a card (docs/architecture/m4-build-spec.md 6.6): a ghost, a tint and labels that come and go with
## show_preview and clear_marks, no cell written on the real layers, off with game/preview_on_map, no input.
extends GutTest

var _scene: MapScene = null
var _marks: PreviewMarks = null


func before_each() -> void:
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_marks = _scene.preview_marks()


## The card of the first wild land hex with a build the rules allow.
func _card() -> Dictionary:
	var game := Session.game
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if game.map.land[i] == 0 or not Improve.piece_at(game, hex).is_empty():
			continue
		for option: Dictionary in Improve.build_options(game, hex):
			if bool(option["ok"]):
				var card := ImprovePreview.of(game, &"GEN", hex, {"action": "build", "family": int(option["family_id"])})
				if not (card["ghost"] as Dictionary).is_empty():
					return card
	return {}


## A card made by hand: a ghost on a land hex of the map and marks with and without a label.
func _made() -> Dictionary:
	var card := _card()
	var hex := (card["ghost"] as Dictionary)["hex"] as Vector2i
	card["map_marks"] = {
		hex: {"delta": 16, "label": "+16 timber"},
		hex + Vector2i(1, 0): {"delta": -4, "label": "-4 grain"},
		hex + Vector2i(0, 1): {"delta": 0, "label": ""},
	}
	return card


func test_nothing_is_there_until_a_card_is_shown() -> void:
	assert_eq(_marks.z_index, 82)
	assert_false(_marks.shown())
	assert_eq(_marks.get_child_count(), 0, "no nodes")
	assert_false(_marks.is_processing())
	assert_eq(_marks.ghost_layers().size(), 0)


func test_a_card_shows_a_ghost_a_tint_and_labels() -> void:
	var card := _made()
	assert_false(card.is_empty(), "a card to show")
	_scene.show_preview(card)
	assert_true(_marks.shown())
	assert_gt(_marks.ghost_layers().size(), 0, "the ghost has layers")
	var ghost := _marks.get_child(0) as CanvasGroup
	assert_eq(ghost.z_index, 75)
	assert_almost_eq(ghost.self_modulate.a, 0.55, 0.001)
	for layer: TileMapLayer in _marks.ghost_layers():
		assert_eq(layer.tile_set, _scene.view().tileset(), "the season's TileSet")
		assert_eq(layer.get_used_cells().size(), 1)
	assert_eq(_marks.tinted().size(), 2, "the no-change hex is not tinted")
	assert_eq((_marks.tinted()[0]["colour"] as Color), MapModes.delta_colour(16))
	assert_eq((_marks.tinted()[1]["colour"] as Color), MapModes.delta_colour(-4))
	assert_eq(_marks.labels().size(), 2)
	assert_eq(_marks.labels()[0]["text"], "+16 timber")


func test_clear_marks_takes_everything_off() -> void:
	_scene.show_preview(_made())
	_scene.clear_marks()
	assert_false(_marks.shown())
	assert_eq(_marks.get_child_count(), 0)
	assert_eq(_marks.tinted().size(), 0)
	assert_eq(_marks.labels().size(), 0)
	await get_tree().process_frame
	assert_eq(_marks.get_child_count(), 0)


func test_a_second_card_replaces_the_first() -> void:
	var card := _made()
	_scene.show_preview(card)
	_scene.show_preview(card)
	await get_tree().process_frame
	assert_eq(_marks.get_child_count(), 1, "one ghost")
	assert_eq(_marks.tinted().size(), 2)


func test_no_cell_is_written_on_the_real_layers() -> void:
	var writes := _scene.view().cell_writes
	var cells := 0
	for layer_name: String in TileMapView.LAYERS:
		cells += _scene.view().layer(layer_name).get_used_cells().size()
	_scene.show_preview(_made())
	_scene.clear_marks()
	_scene.show_preview(_made())
	var after := 0
	for layer_name: String in TileMapView.LAYERS:
		after += _scene.view().layer(layer_name).get_used_cells().size()
	assert_eq(_scene.view().cell_writes, writes)
	assert_eq(after, cells)


func test_a_card_with_no_ghost_still_marks() -> void:
	var card := _made()
	card["ghost"] = {}
	_scene.show_preview(card)
	assert_eq(_marks.ghost_layers().size(), 0)
	assert_eq(_marks.get_child_count(), 0)
	assert_eq(_marks.labels().size(), 2)


func test_at_most_seven_labels_the_biggest_first() -> void:
	var marks: Dictionary = {}
	for k: int in 10:
		marks[Vector2i(k, 0)] = {"delta": k + 1, "label": "+%d wine" % (k + 1)}
	_scene.show_preview({"map_marks": marks, "ghost": {}})
	assert_eq(_marks.labels().size(), PreviewMarks.MAX_LABELS)
	assert_eq(_marks.labels()[0]["text"], "+10 wine")


func test_the_setting_turns_the_marks_off() -> void:
	_marks.set_enabled(false)
	_scene.show_preview(_made())
	assert_false(_marks.shown())
	_marks.set_enabled(true)
	_scene.show_preview(_made())
	assert_true(_marks.shown())
	_marks.set_enabled(false)
	assert_false(_marks.shown(), "turning it off clears what is shown")


func test_the_setting_in_the_scene_reaches_the_marks() -> void:
	var settings := Settings.new()
	_scene.configure(settings)
	assert_true(settings.set_value("game/preview_on_map", false))
	_scene.show_preview(_made())
	assert_false(_marks.shown())
	assert_true(settings.set_value("game/preview_on_map", true))
	_scene.show_preview(_made())
	assert_true(_marks.shown())


func test_the_ghost_follows_the_season() -> void:
	_scene.show_preview(_made())
	var before := _scene.view().tileset()
	_scene.set_season("winter")
	_scene.finish_swap()
	assert_ne(_scene.view().tileset(), before)
	for layer: TileMapLayer in _marks.ghost_layers():
		assert_eq(layer.tile_set, _scene.view().tileset())


func test_the_marks_follow_the_camera_and_never_take_input() -> void:
	_scene.show_preview(_made())
	assert_true(_marks.get_parent() == _scene, "in map space: it moves and zooms with the camera")
	_marks.set_zoom(0.5)
	_marks.set_zoom(0.5)
	assert_false(_marks.is_processing())
	assert_false(_marks.is_processing_input())
	assert_false(_marks.is_processing_unhandled_input())


func test_a_new_game_clears_the_marks() -> void:
	_scene.show_preview(_made())
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	assert_false(_marks.shown())


func test_the_ghost_takes_the_scale_of_a_quality_change() -> void:
	_scene.show_preview(_made())
	var settings := Settings.new("Windows", false)
	assert_true(settings.set_value("graphics/preload_next_season", false))
	assert_true(settings.set_value("graphics/texture_quality", "half"))
	_scene.configure(settings)
	_scene.finish_swap()
	assert_true(_scene.view().is_half())
	assert_gt(_marks.ghost_layers().size(), 0)
	for layer: TileMapLayer in _marks.ghost_layers():
		assert_eq(layer.scale, _scene.view().layer("ground").scale)
		assert_eq(layer.tile_set, _scene.view().tileset())
	_scene.show_preview(_made())
	for layer: TileMapLayer in _marks.ghost_layers():
		assert_eq(layer.scale, Vector2(2.0, 2.0), "a new ghost starts at the half scale")
