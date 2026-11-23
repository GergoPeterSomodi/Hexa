## Several raises by one country at one hex in one season are one notification card, "raised N companies at X" (the raise line of
## LogLines on the summed counts); another hex or another season is its own card. The entries have the shape Military.raise
## writes into the chronicle (kind, tag, hex, turn, count, men). Only raises the viewer was told of merge.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const WOODS := Vector2i(9, 11)
const OTHER := Vector2i(7, 12)

var _g: Game
var _prev_game: Game
var _notes: Notifications


func before_each() -> void:
	_prev_game = Session.game
	var defs := load(DEFS_PATH) as GameDefs
	_g = Game.new_scenario(load(MAP_PATH) as MapData, defs, defs.scenarios[defs.scenarios.size() - 1], 1480)
	assert_true(bool(_g.act("choose_country", {"tag": &"GEN"})["ok"]))
	Session.start_game(_g)
	_notes = Notifications.new()
	add_child_autofree(_notes)


func after_each() -> void:
	Session.game = _prev_game


func _raise(hex: Vector2i, turn: int, count: int = 1) -> Dictionary:
	return {"kind": "army_raised", "tag": "MLO", "hex": hex, "turn": turn, "count": count, "men": 500 * count, "army": -1}


func test_two_raises_at_one_hex_in_one_season_are_one_card_with_the_sum() -> void:
	_notes._on_chronicled(_raise(WOODS, _g.turn))
	_notes._on_chronicled(_raise(WOODS, _g.turn))
	assert_eq(_notes.card_count(), 1, "two raises at one hex in one season make one card")
	var text := str(_notes.cards()[0]["text"])
	assert_true(text.contains("2 companies"), "the card says the sum: '%s'" % text)


func test_a_raise_at_another_hex_or_season_is_its_own_card() -> void:
	_notes._on_chronicled(_raise(WOODS, _g.turn))
	_notes._on_chronicled(_raise(OTHER, _g.turn))
	_notes._on_chronicled(_raise(WOODS, _g.turn + 1))
	assert_eq(_notes.card_count(), 3, "another hex, another season: each its own card")


func test_the_merged_card_keeps_its_place_and_its_go() -> void:
	_notes._on_chronicled(_raise(OTHER, _g.turn))
	_notes._on_chronicled(_raise(WOODS, _g.turn))
	_notes._on_chronicled(_raise(WOODS, _g.turn))
	var cards := _notes.cards()
	assert_eq(cards.size(), 2, "the merged card and the other one")
	assert_eq(cards[0]["hex"], WOODS, "the merged card is the newest: it stays on top")
	assert_eq(cards[0]["hex"], WOODS, "Go looks at the merged card's hex")
