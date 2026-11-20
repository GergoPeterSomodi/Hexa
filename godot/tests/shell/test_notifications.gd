## Notification cards (docs/architecture/m3-build-spec.md 6.6, 9): four at most, newest on top, dropped after two seasons,
## Go looks and dismisses, Close dismisses, hidden while covered, fed by chronicled player lines, cleared by a new game.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const WOODS := Vector2i(9, 11)
const SAVONA := Vector2i(7, 12)

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


func _line(text: String, hex: Vector2i = WOODS, notify: bool = true) -> Dictionary:
	return {"text": text, "tone": "good", "hex": hex, "notify": notify, "turn": _g.turn, "filters": [&"all"]}


func _work_entry(tag: StringName = &"GEN") -> Dictionary:
	assert_true(bool(_g.act("build", {"hex": WOODS, "family": ImproveRules.TIMBER, "tag": &"GEN"})["ok"]))
	var work: Work = _g.state.works[_g.state.works.size() - 1]
	return {"kind": "work_finished", "tag": str(tag), "hex": WOODS, "work": work.to_dict(), "turn": _g.turn}


func test_four_cards_at_most_newest_on_top() -> void:
	for i: int in 5:
		_notes.add_line(_line("card %d" % i))
	assert_eq(_notes.card_count(), 4, "the fifth drops the oldest")
	var texts: Array[String] = []
	for card: Dictionary in _notes.cards():
		texts.append(str(card["text"]))
	assert_eq(texts, ["card 4", "card 3", "card 2", "card 1"], "newest first; card 0 gone")
	assert_eq(_notes.get_child_count(), 4, "one node a card")


func test_only_notify_lines_make_cards() -> void:
	assert_eq(_notes.add_line(_line("quiet", WOODS, false)), -1)
	assert_eq(_notes.add_line({}), -1)
	assert_eq(_notes.card_count(), 0)
	assert_false(_notes.visible, "no cards: nothing shows")


func test_dropped_after_two_seasons() -> void:
	_notes.add_line(_line("kept"))
	Events.season_ended.emit(_g.turn)
	assert_eq(_notes.card_count(), 1, "the season it came in does not count")
	assert_eq(int(_notes.cards()[0]["seasons"]), 0)
	Events.season_ended.emit(_g.turn + 1)
	assert_eq(_notes.card_count(), 1, "the first season after it came: it stays")
	assert_eq(int(_notes.cards()[0]["seasons"]), 1)
	Events.season_ended.emit(_g.turn + 2)
	assert_eq(_notes.card_count(), 0, "the second season after it came: dropped")
	assert_eq(_notes.get_child_count(), 0, "its node is freed")


func test_a_card_born_at_a_season_end_lives_two_later_seasons() -> void:
	# Born during the works phase of the season that is ending: that season_ended is the one it came in.
	Events.season_ended.emit(_g.turn - 1)
	_notes.add_line(_line("late"))
	Events.season_ended.emit(_g.turn)
	assert_eq(_notes.card_count(), 1, "the ending season is not counted")
	Events.season_ended.emit(_g.turn + 1)
	assert_eq(_notes.card_count(), 1, "one later season")
	Events.season_ended.emit(_g.turn + 2)
	assert_eq(_notes.card_count(), 0, "two later seasons")


func test_older_cards_count_on_each_season_end() -> void:
	_notes.add_line(_line("first"))
	Events.season_ended.emit(_g.turn)
	_notes.add_line(_line("second"))
	Events.season_ended.emit(_g.turn + 1)
	var seasons := {}
	for card: Dictionary in _notes.cards():
		seasons[str(card["text"])] = int(card["seasons"])
	assert_eq(seasons, {"first": 1, "second": 0}, "the older card counts this end, the newer one starts")


func test_go_looks_and_dismisses() -> void:
	var watched: Array[Vector2i] = []
	_notes.go_requested.connect(func(hex: Vector2i) -> void: watched.append(hex))
	var id := _notes.add_line(_line("go", SAVONA))
	assert_true(_notes.go(id))
	assert_eq(watched, [SAVONA], "Go asks to look at the card's hex")
	assert_eq(_notes.card_count(), 0, "and the card goes")
	assert_false(_notes.go(id), "a second Go finds nothing")


func test_close_dismisses_without_looking() -> void:
	var watched: Array[Vector2i] = []
	_notes.go_requested.connect(func(hex: Vector2i) -> void: watched.append(hex))
	var id := _notes.add_line(_line("close"))
	assert_true(_notes.dismiss(id))
	assert_eq(watched, [] as Array[Vector2i])
	assert_false(_notes.dismiss(id))


func test_go_without_a_hex_is_quiet() -> void:
	var watched: Array[Vector2i] = []
	_notes.go_requested.connect(func(hex: Vector2i) -> void: watched.append(hex))
	var id := _notes.add_line(_line("no hex", WorksView.NO_HEX))
	assert_true(_notes.go(id))
	assert_eq(watched, [] as Array[Vector2i], "no hex, no look")


func test_hidden_while_covered_and_waiting() -> void:
	_notes.set_covered(true)
	_notes.add_line(_line("waits"))
	assert_false(_notes.visible, "a screen hides the world")
	assert_eq(_notes.card_count(), 1, "the card waits")
	_notes.set_covered(false)
	assert_true(_notes.visible)


func test_a_chronicled_player_work_makes_a_card() -> void:
	Events.chronicled.emit(_work_entry(&"GEN"))
	assert_eq(_notes.card_count(), 1, "the player's finished work notifies")
	var text := str(_notes.cards()[0]["text"])
	assert_true(text.begins_with("Finished: "), "the player's own sentence: %s" % text)
	assert_true(text.ends_with("(9, 11)."), "the place is named")
	assert_eq(_notes.cards()[0]["hex"], WOODS)


func test_another_countrys_work_makes_no_card() -> void:
	var entry := _work_entry(&"BBB")
	Events.chronicled.emit(entry)
	assert_eq(_notes.card_count(), 0, "a stranger's finished work is not for the player")


func test_a_new_game_clears_the_cards() -> void:
	_notes.add_line(_line("old"))
	Events.game_started.emit()
	assert_eq(_notes.card_count(), 0)


func test_the_planted_fault_no_card_without_a_player() -> void:
	Session.start_game(Game.new_game(_g.map, 1, _g.defs))  # a map-only game: no player tag
	Events.chronicled.emit(_work_entry(&"GEN"))
	assert_eq(_notes.card_count(), 0, "without a viewer there are no notifications")
