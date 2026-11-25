## The door scan of the tile window (tilewin-build-spec R8, 7.1): core/views/tile_*.gd, building_card.gd and company_card.gd never
## name the game's state (`game.state.`), the armies (`Armies.`), a garrison read (`Occupation.garrison_of`), the sight (`Sight.`),
## the autoloads (`Session`, `Events`) or the player (`game.player`). One exception: `game.armies` (the viewer-filtered army read) is
## allowed in ONE function only, TileView._armies_here, and that function must go through ArmyView.visible. P: one planted line of
## each kind in a temp script is caught, and a game.armies read outside the exception is caught.
extends GutTest

const VIEW_ROOT := "res://core/views"
const CARDS: Array[String] = ["building_card.gd", "company_card.gd"]
const ARMY_FILE := "tile_view.gd"
## The one function allowed to name game.armies, and the call it must make (the viewer's test, ArmyView.visible).
const ARMY_FUNCTION := "static func _armies_here("
const ARMY_CALL := "ArmyView.visible("
const ARMY_READ := "game.armies"
## One pattern per forbidden name of R8 (game.armies is handled apart, see the exception above).
const FORBIDDEN: Array[String] = ["game\\.state\\.", "\\bArmies\\.", "Occupation\\.garrison_of", "\\bSight\\.", "\\bSession\\b",
	"\\bEvents\\b", "game\\.player\\b"]


## The file names of the scan: the tile views and the two cards, as paths under res://core/views.
func _scanned() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(VIEW_ROOT)
	for name: String in dir.get_files():
		if name.begins_with("tile_") and name.ends_with(".gd"):
			out.append("%s/%s" % [VIEW_ROOT, name])
	for card: String in CARDS:
		out.append("%s/%s" % [VIEW_ROOT, card])
	out.sort()
	return out


## The text of `text` with the one allowed game.armies read removed from the exception's function (tile_view.gd only). Every
## other name in that function is still scanned: only the army read is excused, and only there.
func _without_exception(text: String, file: String) -> String:
	if file != ARMY_FILE:
		return text
	var start := text.find(ARMY_FUNCTION)
	if start < 0:
		return text
	var stop := text.find("\n\n\n", start)
	var span := text.substr(start, stop - start) if stop >= 0 else text.substr(start)
	var rest := text.substr(stop) if stop >= 0 else ""
	return text.substr(0, start) + span.replace(ARMY_READ, "") + rest


## The forbidden names a file's text names: one entry per pattern (and game.armies outside the exception).
func _problems(text: String, file: String) -> Array[String]:
	var out: Array[String] = []
	var body := _without_exception(text, file)
	for pattern: String in FORBIDDEN:
		if RegEx.create_from_string(pattern).search(body) != null:
			out.append("%s: %s" % [file, pattern])
	if body.contains(ARMY_READ):
		out.append("%s: %s" % [file, ARMY_READ])
	return out


## Writes `text` to a temp script under user://, reads it back and returns its problems (the file is removed after).
func _planted(text: String, name: String) -> Array[String]:
	var path := "user://%s" % name
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var read := FileAccess.get_file_as_string(path)
	DirAccess.open("user://").remove(name)
	return _problems(read, name)


func test_the_tile_views_and_cards_name_no_forbidden_read() -> void:
	var files := _scanned()
	assert_eq(files.size(), 5, "the scan reads the three tile views and the two cards")
	for path: String in files:
		assert_eq(_problems(FileAccess.get_file_as_string(path), path.get_file()), [] as Array[String], path)


func test_the_army_read_is_the_one_viewer_filtered_function() -> void:
	var text := FileAccess.get_file_as_string("%s/%s" % [VIEW_ROOT, ARMY_FILE])
	var start := text.find(ARMY_FUNCTION)
	assert_ne(start, -1, "TileView._armies_here exists")
	var stop := text.find("\n\n\n", start)
	var body := text.substr(start, stop - start if stop >= 0 else text.length() - start)
	assert_true(body.contains(ARMY_READ), "the one function reads game.armies")
	assert_true(body.contains(ARMY_CALL), "and filters it through ArmyView.visible (the viewer's test)")
	assert_eq(text.count(ARMY_READ), 1, "game.armies is read once in tile_view.gd")
	for card: String in CARDS:
		assert_false(FileAccess.get_file_as_string("%s/%s" % [VIEW_ROOT, card]).contains(ARMY_READ), card)


func test_p_each_forbidden_name_in_a_temp_script_is_caught() -> void:
	var plants := {
		"game.state.owner[0]": "game\\.state\\.",
		"var n := Armies.count(g)": "\\bArmies\\.",
		"var n := Occupation.garrison_of(g, h)": "Occupation\\.garrison_of",
		"var s := Sight.sees(g, t, h)": "\\bSight\\.",
		"var s := Session.game": "\\bSession\\b",
		"Events.emit(e)": "\\bEvents\\b",
		"var p := game.player": "game\\.player\\b",
	}
	var n := 0
	for line: String in plants:
		var problems := _planted("func f(game: Game) -> void:\n\t%s\n" % line, "planted_%d.gd" % n)
		n += 1
		assert_eq(problems.size(), 1, "P: `%s` is caught" % line)
		assert_true(problems.size() == 1 and problems[0].ends_with(plants[line]), "P: `%s` is caught by its own name" % line)


func test_p_a_game_armies_read_outside_the_exception_is_caught() -> void:
	var outside := "static func other(game: Game) -> Array:\n\treturn game.armies\n"
	assert_eq(_problems(outside, ARMY_FILE).size(), 1, "P: game.armies in another function of tile_view.gd")
	assert_eq(_problems(outside, "building_card.gd").size(), 1, "P: game.armies in a card")
	var inside := "static func _armies_here(game: Game) -> Array:\n\treturn game.armies\n\n\nstatic func x() -> int:\n\treturn 1\n"
	assert_eq(_problems(inside, ARMY_FILE), [] as Array[String], "the exception's own function is not reported")


func test_p_a_forbidden_name_inside_the_exception_is_still_caught() -> void:
	var inside := "static func _armies_here(game: Game) -> Array:\n\tvar s := game.state.owner\n\treturn game.armies\n\n\nstatic func x() -> int:\n\treturn 1\n"
	assert_gt(_problems(inside, ARMY_FILE).size(), 0, "P: game.state. in the exception function is reported")
