## GUT tests for the History page of the Statesman's Study (docs/architecture/m4-5-build-spec.md 4.7 and 6.6; the mockup
## tests/fixtures/mockup/study_history.png): the timeline's marks on genoa_1483, the season line and its hover, focus({turn}),
## the filters by milestone, Older and Newest, a row moves the cursor, Go asks look_at, the keys on the timeline, the sandbox
## message, the digest and version, accessibility names and the fit at 1280 x 720 and 2560 x 1440.
extends GutTest

const SCENE := "res://shell/screens/study/page_history.tscn"
const GEN := &"GEN"
const ACTION_LOOK := &"look_at"
const GO_COLUMN := 3
const NO_DATA := "No data yet."
const NO_HEX := Vector2i(-1, -1)
const LAST_TURN := 12

var _harness: UIHarness = null
var _root: Control = null
var _prev_game: Game = null
var _requests: Array[Array] = []


func before_each() -> void:
	_prev_game = Session.game
	_harness = UIHarness.new()
	_harness.mount(self)
	_root = Control.new()
	_root.theme = KitTheme.load_for(1.0)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_harness.viewport.add_child(_root)
	_requests = []


func after_each() -> void:
	Session.game = _prev_game
	if _harness != null:
		_harness.stack.clear()
	_root = null
	_harness = null


func _page(game: Game) -> PageHistory:
	var page := (load(SCENE) as PackedScene).instantiate() as PageHistory
	page.action_requested.connect(func(action: Array) -> void: _requests.append(action))
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(page)
	page.refresh(game, &"open")
	return page


## The chronicle rows the page lists for `filter` up to `upto` (0 the newest), in the order the table shows them.
func _rows(game: Game, filter: StringName, upto: int) -> Array:
	return StudyHistory.chronicle(game, GEN, filter, upto)["rows"] as Array


## The Go button's item (its row has a hex), or null.
func _item_with_go(page: PageHistory) -> TreeItem:
	var root := page.table().tree().get_root()
	for item: TreeItem in root.get_children():
		if item.get_button_count(GO_COLUMN) > 0:
			return item
	return null


func test_is_the_history_page_with_its_scene_id() -> void:
	var page := _page(InsightsFixture.genoa_1483())
	assert_true(page is StudyPage)
	assert_eq(page.page_id, &"history")
	assert_eq(page.current_tab(), &"", "a page with no tabs")


func test_no_player_says_no_data() -> void:
	var page := _page(Game.new_game(EconomyFixture.map(), 1480))
	assert_eq(page.message_text(), NO_DATA)
	assert_false(page.body_visible())
	assert_eq(page.table().total_count(), 0)
	var nothing := _page(null)
	assert_eq(nothing.message_text(), NO_DATA)


func test_the_timeline_marks_the_players_seasons() -> void:
	var page := _page(InsightsFixture.genoa_1483())
	await _harness.wait_frames(self, 3)
	var marks := {}
	for slot: Dictionary in page.timeline().slots():
		var m := slot["drawn"] as Dictionary
		marks[int(m["turn"])] = str(m["kind"])
	assert_eq(marks.get(1), "begun", "Spring 1480: the timber camp begun")
	assert_eq(marks.get(4), "finished", "Winter 1480: the camp finished")
	assert_eq(marks.get(5), "short", "Spring 1481: a shortage")
	assert_eq(marks.get(8), "begun", "Winter 1481: the walled town begun")
	assert_eq(page.timeline().cursor(), LAST_TURN, "the cursor starts on the newest season")


func test_the_season_line_shows_the_cursor_season() -> void:
	var game := InsightsFixture.genoa_1483()
	var page := _page(game)
	assert_eq(page.season_head_text(), "Winter 1482")
	assert_eq(page.season_line_text(), str(StudyHistory.season(game, GEN, LAST_TURN)["text"]))
	page.focus({"turn": 8})
	assert_eq(page.season_head_text(), "Winter 1481")
	assert_eq(page.season_line_text(), str(StudyHistory.season(game, GEN, 8)["text"]))


func test_hovering_a_season_shows_it_and_leaving_restores_the_cursor() -> void:
	var page := _page(InsightsFixture.genoa_1483())
	page.timeline().season_hovered.emit(5)
	assert_eq(page.season_head_text(), "Spring 1481")
	page.timeline().season_hovered.emit(-1)
	assert_eq(page.season_head_text(), "Winter 1482")


func test_focus_puts_the_cursor_on_a_season_and_lists_from_it() -> void:
	var game := InsightsFixture.genoa_1483()
	var page := _page(game)
	page.focus({"turn": 5})
	assert_eq(page.cursor_turn(), 5)
	assert_eq(page.timeline().cursor(), 5)
	assert_eq(page.list_upto(), 5)
	assert_eq(page.season_head_text(), "Spring 1481")
	assert_eq(page.table().total_count(), _rows(game, &"all", 5).size(), "the list shows the seasons up to turn 5")


func test_the_filters_are_the_milestones_and_each_one_lists_its_lines() -> void:
	var game := InsightsFixture.genoa_1483()
	var page := _page(game)
	assert_eq(page.filter_ids(), [&"all", &"money", &"works", &"mine"], "4.5 has no War")
	page.filters_control().button_for(&"works").button_pressed = true
	assert_eq(page.filter_id(), &"works")
	var works := _rows(game, &"works", 0)
	assert_eq(page.table().total_count(), works.size())
	var total := int(StudyHistory.chronicle(game, GEN, &"works", 0)["total"])
	assert_eq(page.count_text(), "Showing %s of %s" % [InkMarks.grouped(works.size()), InkMarks.grouped(total)])
	page.filters_control().button_for(&"mine").button_pressed = true
	assert_eq(page.table().total_count(), _rows(game, &"mine", 0).size())
	page.refresh(game, &"season_ended")
	assert_eq(page.filter_id(), &"mine", "the filter is kept by a refresh")


## The forty-season game with 160 more witnessed lines (copies of its first witnessed line, four a season), so that its
## chronicle has more than one page of 120 rows (the forty seasons alone give 54 lines).
func _long_game() -> Game:
	var game := InsightsFixture.forty_seasons()
	var first_seen := (StudyHistory.index(game, GEN)["entries"] as PackedInt32Array)[0]
	var base: Dictionary = game.chronicle.entries[first_seen]
	for turn: int in range(1, 41):
		for _n: int in 4:
			var copy := base.duplicate(true)
			copy["turn"] = turn
			game.chronicle.entries.append(copy)
	return game


func test_older_and_newest_page_by_whole_seasons() -> void:
	var game := _long_game()
	var page := _page(game)
	var first := StudyHistory.chronicle(game, GEN, &"all", 0)
	var older := int(first["older_turn"])
	assert_gt(older, 0, "the forty-season game has more than one page")
	assert_true(page.newest_button().disabled, "the newest page is shown")
	assert_false(page.older_button().disabled)
	page.older_button().pressed.emit()
	assert_eq(page.list_upto(), older)
	assert_eq(page.table().total_count(), _rows(game, &"all", older).size(), "Older starts at that season")
	page.newest_button().pressed.emit()
	assert_eq(page.list_upto(), 0)
	assert_eq(page.table().total_count(), (first["rows"] as Array).size())
	assert_true(page.newest_button().disabled)


func test_a_row_moves_the_cursor_and_keeps_the_list() -> void:
	var game := InsightsFixture.genoa_1483()
	var page := _page(game)
	var rows := _rows(game, &"all", 0)
	var k := rows.size() - 1
	var target := int((rows[k] as Dictionary)["turn"])
	assert_lt(target, LAST_TURN, "the oldest line is an older season")
	var tree := page.table().tree()
	tree.set_selected(tree.get_root().get_child(k), 0)
	assert_eq(page.cursor_turn(), target, "selecting a row moves the cursor")
	assert_eq(page.timeline().cursor(), target)
	assert_eq(page.table().total_count(), rows.size(), "the list is not refilled")


func test_go_asks_look_at_for_a_row_with_a_hex() -> void:
	var game := InsightsFixture.genoa_1483()
	var page := _page(game)
	var rows := _rows(game, &"all", 0)
	var k := -1
	for i: int in rows.size():
		if (rows[i] as Dictionary)["hex"] != NO_HEX:
			k = i
			break
	assert_gte(k, 0, "a line with a hex")
	var tree := page.table().tree()
	var item: TreeItem = tree.get_root().get_child(k)
	assert_eq(item.get_button_count(GO_COLUMN), 1, "a Go button on a row with a hex")
	tree.button_clicked.emit(item, GO_COLUMN, 0, MOUSE_BUTTON_LEFT)
	assert_eq(_requests.size(), 1)
	assert_eq(_requests[0][0], ACTION_LOOK)
	assert_eq(_requests[0][1], (rows[k] as Dictionary)["hex"])


func test_a_row_without_a_hex_has_no_go_button() -> void:
	var game := InsightsFixture.genoa_1483()
	var page := _page(game)
	var rows := _rows(game, &"all", 0)
	var root := page.table().tree().get_root()
	for i: int in rows.size():
		var hex: Vector2i = (rows[i] as Dictionary)["hex"]
		var expected := 1 if hex != NO_HEX else 0
		assert_eq((root.get_child(i) as TreeItem).get_button_count(GO_COLUMN), expected, "row %d" % i)
	var item: TreeItem = _item_with_go(page)
	assert_not_null(item)


func test_the_keys_on_the_timeline_move_the_cursor() -> void:
	var page := _page(InsightsFixture.genoa_1483())
	await _harness.wait_frames(self, 2)
	page.timeline().grab_focus()
	_harness.send_key(KEY_LEFT)
	assert_eq(page.cursor_turn(), 11)
	assert_eq(page.season_head_text(), "Autumn 1482")
	_harness.send_key(KEY_LEFT, true, false, true)
	assert_eq(page.cursor_turn(), 7, "Shift+Left goes a year back")
	_harness.send_key(KEY_RIGHT, true, false, true)
	assert_eq(page.cursor_turn(), 11, "Shift+Right goes a year on")
	_harness.send_key(KEY_ENTER)
	assert_eq(page.list_upto(), 11, "Enter shows the list from the cursor back")


func test_a_click_on_the_timeline_shows_the_list_from_that_season() -> void:
	var game := InsightsFixture.genoa_1483()
	var page := _page(game)
	page.timeline().season_activated.emit(6)
	assert_eq(page.cursor_turn(), 6)
	assert_eq(page.list_upto(), 6)
	assert_eq(page.table().total_count(), _rows(game, &"all", 6).size())
	page.timeline().season_activated.emit(LAST_TURN)
	assert_eq(page.list_upto(), 0, "the newest season shows the newest list")


func test_the_page_leaves_the_digest_and_the_version_unchanged() -> void:
	var game := InsightsFixture.genoa_1483()
	var digest := game.digest()
	var version := game.version
	var page := _page(game)
	page.focus({"turn": 5})
	page.filters_control().button_for(&"works").button_pressed = true
	page.timeline().season_hovered.emit(3)
	page.timeline().season_activated.emit(4)
	page.timeline().cursor_moved.emit(2)
	page.older_button().pressed.emit()
	page.newest_button().pressed.emit()
	page.refresh(game, &"season_ended")
	assert_eq(game.digest(), digest)
	assert_eq(game.version, version)


func test_controls_have_accessibility_names() -> void:
	var page := _page(InsightsFixture.genoa_1483())
	assert_eq(page.filters_control().accessibility_name, "Lines to show")
	assert_eq(page.older_button().accessibility_name, "Show older lines")
	assert_eq(page.newest_button().accessibility_name, "Show the newest lines")
	assert_eq(page.table().accessibility_name, "History")
	assert_false(page.timeline().accessibility_name.is_empty())
	for btn: Button in _buttons(page):
		assert_false(btn.accessibility_name.is_empty() and btn.text.is_empty())


func _buttons(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	for child: Node in node.get_children():
		if child is Button:
			out.append(child as Button)
		out.append_array(_buttons(child))
	return out


func test_fits_at_1280_by_720_and_2560_by_1440() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1440)]:
		var harness := UIHarness.new(size)
		harness.mount(self)
		var root := Control.new()
		root.theme = KitTheme.load_for(1.0)
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		harness.viewport.add_child(root)
		var page := (load(SCENE) as PackedScene).instantiate() as PageHistory
		root.add_child(page)
		page.refresh(InsightsFixture.genoa_1483(), &"open")
		await harness.wait_frames(self, 2)
		assert_lte(page.get_combined_minimum_size().x, float(size.x) - 60.0, "no horizontal overflow at %s" % str(size))
		harness.dispose()


func test_the_page_does_no_per_frame_work() -> void:
	var page := _page(InsightsFixture.genoa_1483())
	var names: Array = []
	for m: Dictionary in (page.get_script() as Script).get_script_method_list():
		names.append(str(m["name"]))
	assert_false(names.has("_process"), "no _process: a row's Go button comes from its cell, not a frame sync")
	assert_false(page.is_processing(), "the page does not process every frame")
