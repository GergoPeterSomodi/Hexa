## LogFeed (docs/architecture/m3-build-spec.md 6.5 and section 9): the live lines equal a rebuild from the chronicle; unread
## counts the entries that make a line; filters; mark_read, clear and the no-game case.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const SAVONA := Vector2i(7, 12)
const WOODS := Vector2i(9, 11)

var _g: Game


func before_each() -> void:
	var defs := load(DEFS_PATH) as GameDefs
	_g = Game.new_scenario(load(MAP_PATH) as MapData, defs, defs.scenarios[defs.scenarios.size() - 1], 1480)
	assert_true(bool(_g.act("choose_country", {"tag": &"GEN"})["ok"]))


func _work(action: StringName, family: int, level_to: int, hex: Vector2i, seasons: int) -> Work:
	var w := Work.new()
	w.id = 1
	w.tag = &"GEN"
	w.hex = hex
	w.action = action
	w.family = family
	w.level_to = level_to
	w.started_turn = _g.turn
	w.seasons = seasons
	w.seasons_left = seasons
	return w


## Emits one notable event the way the rules do and returns the chronicle entry it made.
func _emit(kind: String, w: Work, extra: Dictionary = {}) -> Dictionary:
	var event := {"kind": kind, "tag": w.tag, "hex": w.hex, "work": w.to_dict()}
	event.merge(extra)
	_g.emit(event)
	return _g.chronicle.entries[_g.chronicle.entries.size() - 1]


func _lines_of(filter: StringName) -> int:
	var count := 0
	for season: Dictionary in LogLines.entries(_g, &"GEN", filter):
		count += (season["lines"] as Array).size()
	return count


func test_a_rebuild_reads_the_chronicle_and_is_read() -> void:
	_emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4))
	var feed := LogFeed.new()
	feed.rebuild(_g, &"GEN")
	assert_eq(feed.unread, 0, "a rebuild is all read")
	assert_eq(feed.entries(&"all"), LogLines.entries(_g, &"GEN", &"all"), "the feed's lines are the log's lines")
	assert_true(feed.has_game(), "the feed holds the game")
	assert_eq(feed.viewer(), &"GEN", "the viewer is the one given")


func test_live_lines_equal_a_rebuild_from_the_same_chronicle() -> void:
	var live := LogFeed.new()
	live.rebuild(_g, &"GEN")
	live.add(_emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4)))
	live.add(_emit("work_finished", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4)))
	live.add(_emit("work_cancelled", _work(Works.BUILD, ImproveRules.TIMBER, 1, WOODS, 4), {"why": "order", "reason": ""}))
	assert_eq(live.unread, 3, "three lines arrived")
	var fresh := LogFeed.new()
	fresh.rebuild(_g, &"GEN")
	for filter: StringName in [&"all", &"works", &"mine"]:
		assert_eq(live.entries(filter), fresh.entries(filter), "live equals rebuild under %s" % filter)
	assert_eq(live.entries(&"all").size(), 1, "one season so far")
	assert_eq((live.entries(&"all")[0]["lines"] as Array).size(), _lines_of(&"all"), "every line of the season is there, newest first")


func test_an_entry_that_makes_no_line_is_not_unread() -> void:
	var feed := LogFeed.new()
	feed.rebuild(_g, &"GEN")
	feed.add({"kind": "hex_changed", "turn": _g.turn, "hex": SAVONA})
	assert_eq(feed.unread, 0, "a hex change is not a log line")
	feed.add({})
	assert_eq(feed.unread, 0, "an empty entry is nothing")


func test_mark_read_clears_the_count() -> void:
	var feed := LogFeed.new()
	feed.rebuild(_g, &"GEN")
	feed.add(_emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4)))
	assert_eq(feed.unread, 1, "one unread")
	feed.mark_read()
	assert_eq(feed.unread, 0, "read")


func test_the_works_filter_keeps_only_works() -> void:
	_emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4))
	var feed := LogFeed.new()
	feed.rebuild(_g, &"GEN")
	var works := feed.entries(&"works")
	assert_false(works.is_empty(), "the works lines are there")
	for season: Dictionary in works:
		for line: Dictionary in season["lines"] as Array:
			assert_true((line["filters"] as Array).has(&"works"), "every works line is a works line")
	assert_true(feed.entries(&"nope").is_empty(), "an unknown filter has no seasons")


func test_clear_drops_the_game() -> void:
	var feed := LogFeed.new()
	feed.rebuild(_g, &"GEN")
	feed.add(_emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4)))
	feed.clear()
	assert_false(feed.has_game(), "no game")
	assert_eq(feed.unread, 0, "nothing unread")
	assert_true(feed.entries(&"all").is_empty(), "no lines without a game")
	feed.add(_emit("work_started", _work(Works.BUILD, ImproveRules.VINEYARD, 1, SAVONA, 4)))
	assert_eq(feed.unread, 0, "an entry with no game is not counted")


func test_a_feed_without_a_game_is_empty() -> void:
	var feed := LogFeed.new()
	assert_true(feed.entries(&"all").is_empty(), "no game, no lines")
	assert_eq(feed.unread, 0, "no game, nothing unread")
	assert_gt(_lines_of(&"all"), 0, "the game being tested has lines")
