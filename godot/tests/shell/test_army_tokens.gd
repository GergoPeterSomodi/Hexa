## The army tokens of the map (docs/architecture/m6-build-spec.md 6.3; L16): one token a (hex, country) that ArmyView lists for the
## viewer (a foreign army out of sight has none), the badge text, the stand on the hex, the ring of the selection, the size
## below zoom 0.6 and the Kit pieces (plate, figure, state icon).
extends GutTest

var _game: Game = null
var _scene: MapScene = null


func before_each() -> void:
	_game = ArmyFixture.game()
	Session.start_game(_game)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()


func after_each() -> void:
	Session.end_game()


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


## An army of the player's on `hex`, made through the fixture; the game's version moves so the view reads it (as an action does).
func _army(hex: Vector2i, count: int, raised_turn: int = -1) -> Army:
	var a := ArmyFixture.army(_game, ArmyFixture.TAG, hex, 0, count, raised_turn)
	_game.version += 1
	return a


## Does ArmyView.tokens for `viewer` list a token of `tag` on `hex`?
func _listed(viewer: StringName, tag: StringName, hex: Vector2i) -> bool:
	for token: Dictionary in ArmyView.tokens(_game, viewer):
		if (token["hex"] as Vector2i) == hex and StringName(token["tag"]) == tag:
			return true
	return false


## A land hex of the other country (the first one), NO_HEX when none.
func _other_land_hex() -> Vector2i:
	var owner := Countries.by_tag(_game, ArmyFixture.other_tag(_game)).id
	for i: int in _game.map.hex_count():
		var hex := _game.map.hex_of(i)
		if _game.map.is_land(hex) and int(_game.state.owner[i]) == owner:
			return hex
	return ArmyFixture.NO_HEX


func test_an_own_army_has_a_token_on_its_hex_with_its_men() -> void:
	var hex := ArmyFixture.find_town(_game)
	assert_ne(hex, ArmyFixture.NO_HEX)
	var army := _army(hex, 2)
	_armies().sync()
	var token := _armies().tokens().token_at(hex, ArmyFixture.TAG)
	assert_not_null(token, "the army has a token")
	assert_eq(token.badge_text(), ArmyView.token_text(army.men(), true), "the badge reads the men as ArmyView gives them")
	assert_eq(token.badge_text(), "1.0k", "two companies of 500 men")
	assert_eq(token.position, _scene.view().centre_of(hex), "the token's foot stands on the hex's centre")
	assert_eq(_armies().tokens().token_count(), ArmyView.tokens(_game, ArmyFixture.TAG).size(), "one node a token")


func test_tokens_are_made_for_visible_armies_only() -> void:
	var hex := _other_land_hex()
	assert_ne(hex, ArmyFixture.NO_HEX)
	var other := ArmyFixture.other_tag(_game)
	ArmyFixture.army(_game, other, hex, 0, 300)
	_game.version += 1
	_armies().sync()
	var listed := _listed(ArmyFixture.TAG, other, hex)
	assert_eq(_armies().tokens().token_at(hex, other) != null, listed, "a token exists exactly when ArmyView lists one")
	assert_eq(_armies().tokens().token_count(), ArmyView.tokens(_game, ArmyFixture.TAG).size(), "the same count as the view")


func test_a_token_goes_when_its_army_is_gone() -> void:
	var hex := ArmyFixture.find_town(_game)
	var army := _army(hex, 100)
	_armies().sync()
	assert_not_null(_armies().tokens().token_at(hex, ArmyFixture.TAG))
	Armies.remove(_game, army)
	_game.version += 1
	_armies().sync()
	assert_null(_armies().tokens().token_at(hex, ArmyFixture.TAG), "a disbanded army has no token")


func test_the_ring_follows_the_selection() -> void:
	var hex := ArmyFixture.find_town(_game)
	var army := _army(hex, 100)
	_armies().sync()
	var token := _armies().tokens().token_at(hex, ArmyFixture.TAG)
	assert_false(token.ringed(), "no ring before a selection")
	assert_true(_armies().select_army(army.id))
	assert_true(token.ringed(), "the selected army's token rings")
	_armies().clear_army()
	assert_false(token.ringed(), "the ring goes with the selection")


func test_below_zoom_06_a_token_keeps_its_size() -> void:
	var hex := ArmyFixture.find_town(_game)
	_army(hex, 100)
	_armies().sync()
	var token := _armies().tokens().token_at(hex, ArmyFixture.TAG)
	_armies().tokens().set_zoom(0.3)
	assert_eq(token.scale, Vector2(2.0, 2.0), "scale is 0.6 / zoom below 0.6")
	_armies().tokens().set_zoom(0.6)
	assert_eq(token.scale, Vector2.ONE, "the art's size from 0.6 up")
	_armies().tokens().set_zoom(1.5)
	assert_eq(token.scale, Vector2.ONE)


func test_the_kit_pieces_are_drawn_and_the_state_icon_shows_a_muster() -> void:
	var hex := ArmyFixture.find_town(_game)
	_army(hex, 100)
	_armies().sync()
	var token := _armies().tokens().token_at(hex, ArmyFixture.TAG)
	assert_not_null(token.figure_texture(), "the kind's figure is a Kit icon")
	assert_false(token.state_shown(), "a holding army has no state icon")
	var raised := _army(hex, 50, _game.turn)
	_armies().sync()
	assert_true(_armies().tokens().token_at(hex, ArmyFixture.TAG).state_shown(), "a mustering army shows its state icon")
	Armies.remove(_game, raised)


func test_the_tokens_follow_the_colour_blind_palette_when_the_scene_changes_it() -> void:
	var hex := ArmyFixture.find_town(_game)
	_army(hex, 2)
	_armies().sync()
	var id := Countries.by_tag(_game, ArmyFixture.TAG).id
	_scene.set_colour_blind(true)
	await get_tree().process_frame
	assert_eq(_armies().tokens().token_at(hex, ArmyFixture.TAG).plate_colour(), MapModes.palette(_game, true)[id],
		"the plate takes the colour-blind colour")
	_scene.set_colour_blind(false)
	await get_tree().process_frame
	assert_eq(_armies().tokens().token_at(hex, ArmyFixture.TAG).plate_colour(), MapModes.palette(_game, false)[id],
		"and the standard one back")
