## The hover of a token's points mark (docs/architecture/moves-build-spec.md R51; MV9's mark, MV10's hover): the pointer on the
## mark of one of your army tokens shows "8 of 12 move points left this season" in the hover card, after the tooltip delay, in
## place of the hex card and the move card; off the mark the hex's own hover comes back; a foreign token has none; the hover
## cards switched off show nothing. Planted faults: a mark with no hover; the words kept after the pointer leaves; words on a
## foreign token.
extends GutTest

var _game: Game = null
var _scene: MapScene = null
var _hover: MapHover = null
var _pointer := Vector2(-9999.0, -9999.0)


func before_each() -> void:
	_game = ArmyFixture.game()
	Session.start_game(_game)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_hover = MapHover.new()
	add_child_autofree(_hover)
	_hover.hover_delay_sec = 0.2
	_pointer = Vector2(-9999.0, -9999.0)
	_hover.pointer_func = func() -> Vector2: return _pointer


func after_each() -> void:
	Session.end_game()


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


## An army of `tag` on `hex` with `points` points left, and its token.
func _army(tag: StringName, hex: Vector2i, points: int) -> ArmyToken:
	var a := ArmyFixture.army(_game, tag, hex, 0, 2)
	ArmyFixture.spent(_game, a, points)
	_game.version += 1
	Sight.refresh(_game)
	_armies().sync()
	return _armies().tokens().token_at(hex, tag)


func _on_mark(token: ArmyToken) -> Vector2:
	return token.get_global_transform_with_canvas() * ArmyToken.POINTS_BAR.get_center()


## The pointer moves to `at` over `hex`, and time passes.
func _point(hex: Vector2i, at: Vector2, seconds: float) -> void:
	_pointer = at
	_hover.on_hover_changed(hex, at)
	_hover._process(seconds)


func _title() -> String:
	if not _hover.is_card_visible():
		return ""
	return (_hover.card().get_node("VBox/Title") as Label).text


func test_the_mark_of_your_token_has_a_hover_after_the_delay() -> void:
	var hex := ArmyFixture.find_town(_game)
	var token := _army(ArmyFixture.TAG, hex, 8)
	var full := int(ArmyView.tokens(_game, ArmyFixture.TAG)[0]["points_full"])
	var words := "8 of %d move points left this season" % full
	assert_eq(_armies().tokens().points_tip_at(_on_mark(token)), words, "the mark answers under the pointer")
	_point(hex, _on_mark(token), 0.05)
	assert_eq(_title(), "", "not before the tooltip delay")
	_hover._process(0.25)
	assert_eq(_title(), words, "P: the mark has no hover")


func test_off_the_mark_the_hex_hover_comes_back() -> void:
	var hex := ArmyFixture.find_town(_game)
	var token := _army(ArmyFixture.TAG, hex, 8)
	_point(hex, _on_mark(token), 0.3)
	assert_ne(_title(), "")
	_pointer = Vector2(-9999.0, -9999.0)
	_hover._process(0.05)
	assert_false(_title().contains("move points"), "P: the words stayed after the pointer left")
	_hover._process(0.3)
	assert_eq(_title(), str(HexCard.of(_game, hex)["title"]), "the hex card again")


func test_the_mark_takes_the_move_cards_place_while_an_army_is_selected() -> void:
	var hex := ArmyFixture.find_town(_game)
	var token := _army(ArmyFixture.TAG, hex, 8)
	var mover := ArmyFixture.army(_game, ArmyFixture.TAG, _game.map.neighbour(hex, 0), 0, 1)
	_game.version += 1
	_armies().sync()
	token = _armies().tokens().token_at(hex, ArmyFixture.TAG)
	assert_true(_armies().select_army(mover.id))
	_point(hex, token.get_global_transform_with_canvas() * Vector2(0.0, -4000.0), 0.3)
	assert_true(_hover.move_card().is_open(), "off the mark: the move card of the hex")
	_point(hex, _on_mark(token), 0.3)
	assert_false(_hover.move_card().is_open(), "on the mark the move card gives way")
	assert_string_contains(_title(), "move points left this season")
	_pointer = Vector2(-9999.0, -9999.0)
	_hover._process(0.05)
	assert_true(_hover.move_card().is_open(), "and comes back")


func test_a_foreign_token_and_switched_off_cards_show_nothing() -> void:
	var hex := ArmyFixture.find_town(_game)
	var other := _army(ArmyFixture.other_tag(_game), hex, 8)
	assert_not_null(other, "the foreign army is in sight")
	_point(hex, _on_mark(other), 0.3)
	assert_false(_title().contains("move points"), "P: a foreign army shows its points")
	var near := _game.map.neighbour(hex, 0)
	var mine := _army(ArmyFixture.TAG, near, 8)
	_hover.hover_cards_enabled = false
	_point(near, _on_mark(mine), 0.3)
	assert_eq(_title(), "", "no card with the hover cards off")
	_hover.hover_cards_enabled = true
	_hover.set_dragging(true)
	_point(near, _on_mark(mine), 0.3)
	assert_eq(_title(), "", "none while the map is dragged")
	_hover.set_dragging(false)
	_point(MapInput.NO_HEX, _on_mark(mine), 0.3)
	assert_eq(_title(), "", "none off the map")
