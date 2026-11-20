## The work marks (docs/architecture/m3-build-spec.md 6.9): one per work, "done/total", FAINT while halted, z 87, drawn from
## zoom 0.45, redrawn on the work signals and season_ended; the kit's hourglass is there to draw.
extends GutTest

var _marks: WorkMarks = null


func before_each() -> void:
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	_marks = WorkMarks.new()
	add_child_autofree(_marks)
	_marks.setup(Session.game)


## A wild land hex with a build option the rules allow, and that option's family id.
func _buildable() -> Dictionary:
	var game := Session.game
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if game.map.land[i] == 0 or not Improve.piece_at(game, hex).is_empty():
			continue
		for option: Dictionary in Improve.build_options(game, hex):
			if bool(option["ok"]):
				return {"hex": hex, "family": int(option["family_id"])}
	return {}


func test_the_layer_and_the_constants() -> void:
	assert_eq(_marks.z_index, 87)
	assert_eq(WorkMarks.MIN_ZOOM, 0.45)
	assert_gte(WorkMarks.ICON_SIZE, 20.0)
	assert_gte(WorkMarks.FONT_SIZE, 13)


func test_the_kit_has_the_hourglass() -> void:
	var theme := load(KitTheme.THEME_PATH) as Theme
	assert_true(theme.has_icon(&"hourglass", &"Kit"))
	assert_not_null(_marks._kit_icon(&"hourglass"))


func test_the_hourglass_is_found_when_the_windows_theme_has_no_kit() -> void:
	var window := get_window()
	var before := window.theme
	window.theme = Theme.new()
	assert_not_null(_marks._kit_icon(&"hourglass"), "taken from the project or the Studiolo theme")
	window.theme = before


func test_a_mark_follows_a_work_from_start_to_finish() -> void:
	assert_eq(_marks.mark_count(), 0)
	var found := _buildable()
	var hex := found["hex"] as Vector2i
	assert_true(Session.act("build", {"hex": hex, "family": int(found["family"])})["ok"])
	assert_eq(_marks.mark_count(), 1, "redrawn on work_started")
	var work := Session.game.state.work_at(hex)
	var mark := _marks.mark_at(hex)
	assert_eq(mark["text"], "1/%d" % work.seasons)
	var first_total := work.seasons
	var n := 0
	while Session.game.state.work_at(hex) != null and n < 40:
		assert_true(bool(Session.end_season()["ok"]))
		n += 1
		var live := Session.game.state.work_at(hex)
		if live != null:
			assert_eq(_marks.mark_at(hex)["text"], "%d/%d" % [first_total - live.seasons_left + 1, first_total], "season %d" % n)
	assert_eq(_marks.mark_count(), 0, "gone on work_finished")


func test_a_cancelled_work_loses_its_mark() -> void:
	var found := _buildable()
	var hex := found["hex"] as Vector2i
	assert_true(Session.act("build", {"hex": hex, "family": int(found["family"])})["ok"])
	assert_eq(_marks.mark_count(), 1)
	var verdict := Session.act("cancel_work", {"hex": hex})
	assert_true(bool(verdict["ok"]), str(verdict))
	assert_eq(_marks.mark_count(), 0, "redrawn on work_cancelled")


func test_a_halted_work_is_marked_halted() -> void:
	var found := _buildable()
	var hex := found["hex"] as Vector2i
	assert_true(Session.act("build", {"hex": hex, "family": int(found["family"])})["ok"])
	assert_false(bool(_marks.mark_at(hex)["halted"]), "spring: not halted")
	var game := Session.game
	var snowy := game.map.climate[game.map.index_of(hex)] == 0
	game.turn = 4  # winter
	_marks.refresh()
	assert_eq(bool(_marks.mark_at(hex)["halted"]), snowy and game.defs.works_halt_in_snow_winter, "halted by the winter rule")
	# The halt rule itself, seen through the mark.
	var work := game.state.work_at(hex)
	assert_eq(bool(_marks.mark_at(hex)["halted"]), Works.halted(game, work, game.turn))


func test_marks_are_drawn_from_zoom_045_up() -> void:
	_marks.set_zoom(0.3)
	assert_false(_marks.shown())
	_marks.set_zoom(0.45)
	assert_true(_marks.shown())
	_marks.set_zoom(2.0)
	assert_true(_marks.shown())


func test_setup_with_no_game_draws_nothing() -> void:
	_marks.setup(null)
	assert_eq(_marks.mark_count(), 0)
