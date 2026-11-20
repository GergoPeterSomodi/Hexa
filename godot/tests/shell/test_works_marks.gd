## The real card on the real map (docs/architecture/m4-build-spec.md 6.6 and 4.15 c): ImprovePreview's own dictionary for the
## vineyard at (7, 12) is drawn by PreviewMarks in a MapScene with no hand-made marks: the ghost's layers, the tint and the
## "+12 wine" label come with the card and are gone after clear_marks, and no cell is written on the view's own layers.
extends GutTest

const HEX := Vector2i(7, 12)
const VINEYARD := ImproveRules.VINEYARD

var _scene: MapScene = null
var _prev_game: Game = null
var _game: Game = null


func before_each() -> void:
	_prev_game = Session.game
	_game = EconomyFixture.game(&"GEN", true)  # (7, 12) is wild in the fixture: the card builds a first vineyard there
	Session.start_game(_game)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()


func after_each() -> void:
	Session.game = _prev_game


func _card() -> Dictionary:
	return ImprovePreview.of(_game, &"GEN", HEX, {"action": Works.BUILD, "family": VINEYARD})


func test_the_real_vineyard_card_shows_a_ghost_a_tint_and_its_label_and_clears() -> void:
	var card := _card()
	assert_eq((card["ghost"] as Dictionary)["hex"], HEX, "the card's ghost stands on the hex")
	var marks := _scene.preview_marks()
	assert_false(marks.shown())
	var writes := _scene.view().cell_writes
	_scene.show_preview(card)
	assert_true(marks.shown())
	assert_gt(marks.ghost_layers().size(), 0, "the ghost has tile layers")
	for layer: TileMapLayer in marks.ghost_layers():
		assert_ne(layer.get_cell_source_id(HEX), -1, "%s has the vineyard's tile on its hex" % layer.name)
	var tinted := marks.tinted().filter(func(t: Dictionary) -> bool: return t["hex"] == HEX)
	assert_eq(tinted.size(), 1, "the hex is tinted")
	assert_eq(tinted[0]["colour"], MapModes.delta_colour(22), "in the colour of its gain")
	var labels := marks.labels().filter(func(l: Dictionary) -> bool: return l["hex"] == HEX)
	assert_eq(labels.size(), 1)
	assert_eq(labels[0]["text"], "+12 wine")
	assert_eq(_scene.view().cell_writes, writes, "no cell of the real layers was written")
	_scene.clear_marks()
	assert_false(marks.shown(), "gone")
	assert_eq(marks.ghost_layers().size(), 0)
	assert_eq(marks.tinted().size(), 0)
	assert_eq(marks.labels().size(), 0)


func test_a_second_card_replaces_the_first_and_the_setting_turns_the_marks_off() -> void:
	var marks := _scene.preview_marks()
	_scene.show_preview(_card())
	var first := marks.ghost_layers().size()
	assert_gt(first, 0)
	_scene.show_preview(_card())
	assert_eq(marks.ghost_layers().size(), first, "a second card takes the first one's place: the layers are not doubled")
	assert_eq(marks.get_child_count(), 1, "one ghost")
	var settings := Settings.new()
	settings.set_value("game/preview_on_map", false)
	_scene.configure(settings)
	_scene.show_preview(_card())
	assert_false(marks.shown(), "Preview on the map off: no ghost, no tint, no labels")
