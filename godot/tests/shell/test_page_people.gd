## GUT tests for the People page of the Statesman's Study (docs/architecture/m5-build-spec.md 6.6, 4.11 (a)): the first-year
## game as Genoa (PeopleFixture.genoa) in Summer 1480: the head, the table's rows and sort, the countryside line, the food
## line, the two charts, Look there and Show on the map, the span, the state before a season, the digest unchanged by the
## page, the four pages of the nav and the fit at 1280 x 720 and 1024 x 600. A picture review (art director) is still due.
extends GutTest

const SCENE := "res://shell/screens/study/page_people.tscn"
const STUDY_SCENE := "res://shell/screens/study.tscn"
const GENOA := Vector2i(8, 13)
const SAVONA := Vector2i(6, 13)
const NO_DATA := "No data yet."

var _harness: UIHarness = null
var _root: Control = null
var _requests: Array[Array] = []


func before_each() -> void:
	Bindings.reset_defaults()
	_harness = UIHarness.new()
	_harness.mount(self)
	_root = Control.new()
	_root.theme = KitTheme.load_for(1.0)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_harness.viewport.add_child(_root)
	_requests = []


func after_each() -> void:
	if _harness != null:
		_harness.stack.clear()
	_root = null
	_harness = null
	Bindings.reset_defaults()


func _page(game: Game, root: Control = null) -> PagePeople:
	var page := (load(SCENE) as PackedScene).instantiate() as PagePeople
	page.milestone = "5"
	page.action_requested.connect(func(action: Array) -> void: _requests.append(action))
	(root if root != null else _root).add_child(page)
	page.refresh(game, &"open")
	return page


func _summer() -> Game:
	var g := PeopleFixture.genoa()
	Season.run(g)
	return g


func _table(page: PagePeople) -> StudyTable:
	return page.find_child("Table", true, false) as StudyTable


func _label(page: PagePeople, node: String) -> Label:
	return page.find_child(node, true, false) as Label


func _cells(table: StudyTable, row: int) -> Array:
	var item := table.tree().get_root().get_child(row)
	var out: Array = []
	for c: int in range(table.tree().columns):
		out.append(item.get_text(c))
	return out


func _button(page: PagePeople, node: String) -> KitButton:
	return page.find_child(node, true, false) as KitButton


func test_head_says_the_people_and_the_expected_change() -> void:
	var page := _page(_summer())
	assert_eq(_label(page, "Head").text,
		"83,285 people: 40,400 in towns, 42,885 in the countryside; room for 32,415 more.")
	var chip := page.find_child("Expected", true, false) as DeltaChip
	assert_eq(chip.text(), "Expected this season +589")


func test_the_table_lists_the_settlements_highest_first() -> void:
	var table := _table(_page(_summer()))
	assert_eq(table.total_count(), 2)
	assert_eq(table.sort_state()["id"], &"people")
	var genoa := _cells(table, 0)
	assert_eq(genoa[0], "Genoa (8, 13)")
	assert_eq(genoa[1], "walled town · port")
	assert_eq(genoa[2], "30,300")
	assert_eq(genoa[3], "45,000")
	assert_eq(genoa[4], "+300")
	assert_eq(genoa[5], "Room for 14,700 more; a city would give room for 100,000.")
	var savona := _cells(table, 1)
	assert_true(str(savona[0]).begins_with("Savona"), str(savona[0]))
	assert_eq(savona[2], "10,100")
	assert_eq(savona[4], "+100")


func test_the_headers_are_the_six_columns() -> void:
	var table := _table(_page(_summer()))
	var titles: Array = []
	for i: int in range(6):
		titles.append(table.column_header(i))
	assert_true(str(titles[0]).begins_with("Place"))
	assert_true(str(titles[5]).begins_with("Outlook"))
	assert_eq(titles.size(), 6)


func test_the_countryside_line_and_the_food_line() -> void:
	var page := _page(_summer())
	assert_eq(_label(page, "Countryside").text,
		"The countryside: 12 places, 42,885 people of 50,700 room, ▲ +185 last season.")
	var food := _label(page, "FoodLine").text
	assert_true(food.begins_with("Food: "), food)
	assert_true(food.contains("Fed, "), food)
	assert_true(food.ends_with(" Lasts over 8 seasons."), food)


func test_the_two_charts_have_their_series_and_the_span() -> void:
	var game := PeopleFixture.genoa()
	PeopleFixture.play(game, 3)
	var page := _page(game)
	var food := page.find_child("FoodChart", true, false) as InkChart
	assert_eq(food.kind, InkChart.Kind.LINE)
	assert_true(food.legend)
	assert_eq(food.x_labels.size(), 3)
	assert_true(food.summary().contains("The towns' need"), food.summary())
	var growth := page.find_child("GrowthChart", true, false) as InkChart
	assert_eq(growth.kind, InkChart.Kind.STACKED_BAR)
	assert_true(growth.summary().contains("Starved"), growth.summary())
	assert_true(growth.summary().contains("Left"), growth.summary())
	var seg := page.find_child("Span", true, false) as Segmented
	assert_eq(seg.selected_id(), 12)
	seg.select(40, true)
	assert_eq(page.span, 40)
	assert_eq(food.x_labels.size(), 3)


func test_the_span_is_read_from_and_written_to_the_settings() -> void:
	var page := (load(SCENE) as PackedScene).instantiate() as PagePeople
	page.settings = _harness.settings
	_root.add_child(page)
	var game := _summer()
	page.refresh(game, &"open")
	(page.find_child("Span", true, false) as Segmented).select(40, true)
	assert_eq(int(_harness.settings.get_value("state/study_span")), 40)
	page.span = 12
	page.refresh(game, &"open")
	assert_eq(page.span, 40)


func test_look_there_and_show_on_the_map_use_the_selected_row() -> void:
	var page := _page(_summer())
	assert_eq(page.selected_row()["hex"], GENOA, "the first row is selected")
	_button(page, "Look").pressed.emit()
	assert_eq(_requests[0], [&"look_at", GENOA])
	_table(page).row_selected.emit({"id": page.selected_row()["id"], "hex": SAVONA})
	_button(page, "ShowOnMap").pressed.emit()
	assert_eq(_requests[1], [&"map_mode", &"food", SAVONA])
	_table(page).row_activated.emit({"id": 1, "hex": GENOA})
	assert_eq(_requests[2], [&"look_at", GENOA])


func test_before_a_season_has_ended() -> void:
	var page := _page(PeopleFixture.genoa())
	assert_true(_label(page, "Head").text.begins_with("82,700 people: "), _label(page, "Head").text)
	assert_eq(_label(page, "FoodLine").text, "No season has ended yet.")
	assert_eq(_cells(_table(page), 0)[4], "0")
	assert_true(_label(page, "Countryside").text.ends_with("room."), _label(page, "Countryside").text)
	for chart_name: String in ["FoodChart", "GrowthChart"]:
		assert_false((page.find_child(chart_name, true, false) as Control).visible)
	assert_eq(page.find_children("NoData", "Label", true, false).size(), 2)
	assert_eq(_label(page, "NoData").text, NO_DATA)
	assert_true(_label(page, "NoData").visible)


func test_no_game_or_no_player_is_the_empty_page() -> void:
	var page := _page(null)
	assert_eq(_table(page).total_count(), 0)
	assert_true(_button(page, "Look").disabled)
	_button(page, "Look").pressed.emit()
	assert_true(_requests.is_empty())
	page.refresh(EconomyFixture.game(), &"open")
	assert_eq(_table(page).total_count(), 0)


func test_refresh_leaves_the_digest_and_the_version_alone() -> void:
	var game := _summer()
	var page := _page(game)
	var digest := game.digest()
	var version := game.version
	page.refresh(game, &"open")
	page.refresh(game, &"season_ended")
	(page.find_child("Span", true, false) as Segmented).select(40, true)
	_button(page, "Look").pressed.emit()
	assert_eq(game.digest(), digest)
	assert_eq(game.version, version)


func test_the_selection_survives_a_season_and_a_refresh() -> void:
	var game := PeopleFixture.genoa()
	Season.run(game)
	var page := _page(game)
	_table(page).row_selected.emit({"id": game.map.index_of(SAVONA), "hex": SAVONA})
	Season.run(game)
	page.refresh(game, &"season_ended")
	assert_eq(page.selected_row()["hex"], SAVONA)


func test_four_pages_in_the_nav_from_milestone_five() -> void:
	var ids: Array = []
	for entry: Dictionary in StudyPages.shown("5"):
		ids.append(entry["id"])
	assert_eq(ids, [&"economy", &"people", &"rankings", &"history"])
	var four: Array = []
	for entry: Dictionary in StudyPages.shown("4.5"):
		four.append(entry["id"])
	assert_eq(four, [&"economy", &"rankings", &"history"])


func test_the_study_opens_the_page_and_survives_rapid_switching() -> void:
	var study := (load(STUDY_SCENE) as PackedScene).instantiate() as Study
	study.configure(StudyPages.shown("5"), "5")
	_harness.stack.push(study)
	var ids: Array = [&"people", &"economy", &"people", &"rankings", &"history", &"people", &"economy", &"people"]
	for id: StringName in ids:
		study.open_page(id)
		assert_eq(study.current_page_id(), id)
	assert_true(study.current_page() is PagePeople)
	assert_eq((study.current_page() as PagePeople).settings, _harness.ctx.settings)
	for _i: int in 6:
		study.open_page(&"")
		study.back()
		_harness.stack.push(study)
	await _harness.wait_frames(self, 2)
	assert_eq(study.nav().button_for(&"people").text, "People")
	assert_gte(study.page_host().size.x, 984.0, "the Study's page area at 1280 holds both charts")


func test_fits_at_1280_by_720_and_1024_by_600() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 600)]:
		var harness := UIHarness.new(size)
		harness.mount(self)
		var root := Control.new()
		root.theme = KitTheme.load_for(1.0)
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		harness.viewport.add_child(root)
		# The Study frame and its nav leave this width to a page.
		var host := Control.new()
		host.custom_minimum_size = Vector2(float(size.x) - 260.0, 0.0)
		host.size = Vector2(float(size.x) - 260.0, float(size.y))
		root.add_child(host)
		var page := _page(_summer(), host)
		page.size = host.size
		await harness.wait_frames(self, 2)
		assert_lte(page.get_combined_minimum_size().x, host.size.x, "no horizontal overflow at %s" % str(size))
		var towns := page.find_child("Towns", true, false) as Control
		var food := page.find_child("Food", true, false) as Control
		assert_true(towns.is_visible_in_tree() and food.is_visible_in_tree())
		assert_gt(food.position.y, towns.position.y, "Food sits under the table, which has the page's full width at %s" % str(size))
		assert_gte(towns.size.x, host.size.x - 40.0, "the table takes the page's width at %s" % str(size))
		var inset_a := page.find_child("FoodInset", true, false) as Control
		var inset_b := page.find_child("GrowthInset", true, false) as Control
		if size.x >= 1280:
			assert_eq(inset_a.position.y, inset_b.position.y, "the two charts sit side by side at 1280")
			assert_gt(inset_b.position.x, inset_a.position.x)
		else:
			assert_gt(inset_b.position.y, inset_a.position.y, "the charts stack at 1024")
		assert_lt((page.find_child("Top", true, false) as Control).size.y, 80.0, "the head stays a line or two at %s" % str(size))
		harness.dispose()
