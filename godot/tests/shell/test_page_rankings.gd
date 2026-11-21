## GUT tests for the Rankings page of the Statesman's Study (docs/architecture/m4-5-build-spec.md 4.6, 4.10, 6.5): Genoa
## on seed 1480 after Spring 1480 (the turn-2 lists: land Savoy about 58, Milan about 52, Genoa 14; income Milan about +260,
## Savoy about +240, Genoa +86; 10 countries unknown; "You are 3rd of 3."), your row, banded foreign values, a row's Go or
## Enter asking for the country, the chart captions, the refresh leaving the digest and version alone, the page with no
## player, before a season, the milestone, and the fit at 1280 x 720 and 2560 x 1440.
extends GutTest

const SCENE := "res://shell/screens/study/page_rankings.tscn"
const GEN := &"GEN"
const NO_DATA := "No data yet."
const NO_SEASON := "No season has ended yet."
const LAND := "land"
const INCOME := "income"

var _harness: UIHarness = null
var _root: Control = null
var _requests: Array[Array] = []


func before_each() -> void:
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


func _page(game: Game, milestone: String = "4.5") -> PageRankings:
	var page := (load(SCENE) as PackedScene).instantiate() as PageRankings
	page.milestone = milestone
	page.action_requested.connect(func(action: Array) -> void: _requests.append(action))
	_root.add_child(page)
	page.refresh(game, &"open")
	return page


func _column(page: PageRankings, measure: String) -> Control:
	return page.find_child(measure, true, false) as Control


func _table(page: PageRankings, measure: String) -> StudyTable:
	return _column(page, measure).find_child("Table", false, false) as StudyTable


## The rows of a table as [rank, country, value, ...] texts, in display order.
func _row_texts(table: StudyTable) -> Array:
	var out: Array = []
	var root := table.tree().get_root()
	for i: int in range(table.shown_count()):
		var item := root.get_child(i)
		out.append([item.get_text(0), item.get_text(1), item.get_text(2)])
	return out


func _labels(node: Node) -> Array[String]:
	var out: Array[String] = []
	for child: Node in node.get_children():
		if child is Label and (child as Label).visible:
			out.append((child as Label).text)
		out.append_array(_labels(child))
	return out


func _played_one_season() -> Game:
	var game := EconomyFixture.game(GEN)
	assert_true(bool(Season.run(game)["ok"]))
	return game


func test_the_lists_show_the_turn_two_numbers() -> void:
	var page := _page(_played_one_season())
	var land := _row_texts(_table(page, LAND))
	assert_eq(land.size(), 3)
	assert_eq(land[0], ["1", "Savoy", "about 58"])
	assert_eq(land[1], ["2", "Milan", "about 52"])
	assert_eq(land[2], ["3", "Genoa (you)", "14"])
	var income := _row_texts(_table(page, INCOME))
	assert_eq(income.size(), 3)
	assert_eq(income[0], ["1", "Milan", "about +260"])
	assert_eq(income[1], ["2", "Savoy", "about +240"])
	assert_eq(income[2], ["3", "Genoa (you)", "+86"])


func test_you_are_third_of_three_under_both_lists() -> void:
	var page := _page(_played_one_season())
	assert_true(_labels(_column(page, LAND)).has("You are 3rd of 3."))
	assert_true(_labels(_column(page, INCOME)).has("You are 3rd of 3."))


func test_the_head_line_counts_the_countries_and_the_unknown_ones() -> void:
	var page := _page(_played_one_season())
	var head := page.find_child("Head", true, false) as Label
	assert_true(head.visible)
	assert_true(head.text.begins_with("The 3 countries you know, you among them."), head.text)
	assert_true(head.text.contains("10 countries unknown."), head.text)
	assert_true(head.text.contains("Their numbers are rounded."), head.text)


func test_foreign_values_are_banded_and_yours_is_exact() -> void:
	var page := _page(_played_one_season())
	for measure: String in [LAND, INCOME]:
		for row: Array in _row_texts(_table(page, measure)):
			var text := str(row[2])
			if str(row[1]).begins_with("Genoa"):
				assert_false(text.begins_with("about"), "your value is exact: %s" % text)
			else:
				assert_true(text.begins_with("about "), "a foreign value is banded: %s" % text)


func test_your_row_is_marked_and_the_list_is_sorted_by_rank() -> void:
	var table := _table(_page(_played_one_season()), LAND)
	assert_eq(table.sort_state()["id"], &"rank")
	var rows := table.tree().get_root()
	var mine := 0
	for i: int in range(table.shown_count()):
		if rows.get_child(i).get_text(1).ends_with("(you)"):
			mine += 1
	assert_eq(mine, 1)


func test_a_row_activation_asks_for_the_country() -> void:
	var game := _played_one_season()
	var page := _page(game)
	var first := StudyRankings.of(game, GEN, 12)["measures"][0]["rows"][0] as Dictionary
	_table(page, LAND).row_activated.emit(first)
	assert_eq(_requests.size(), 1)
	assert_eq(_requests[0][0], &"country")
	assert_eq(_requests[0][1], first["tag"])


func test_enter_or_double_click_on_a_row_asks_for_the_country() -> void:
	var page := _page(_played_one_season())
	var table := _table(page, INCOME)
	table.select_id(int(table.sorted_ids()[0]))
	table.tree().item_activated.emit()
	assert_eq(_requests.size(), 1)
	assert_eq(_requests[0][0], &"country")
	assert_true(_requests[0][1] is StringName)


func test_the_charts_have_two_series_a_legend_and_the_caption() -> void:
	var game := InsightsFixture.genoa_first_year()
	var page := _page(game)
	var chart := _column(page, LAND).find_child("Chart", true, false) as InkChart
	assert_eq(chart.kind, InkChart.Kind.LINE)
	assert_true(chart.legend)
	assert_eq(chart.x_labels.size(), 4)
	var caption := "Your land, the last 4 seasons"
	assert_eq(chart.caption, caption)
	assert_true(chart.summary().contains(caption), chart.summary())
	assert_true(_labels(_column(page, LAND)).has(caption))
	assert_true(chart.summary().contains("You"), chart.summary())


func test_refresh_leaves_the_digest_and_the_version_alone() -> void:
	var game := _played_one_season()
	var page := _page(game)
	var digest := game.digest()
	var version := game.version
	page.refresh(game, &"open")
	page.refresh(game, &"season_ended")
	assert_eq(game.digest(), digest)
	assert_eq(game.version, version)


func test_no_player_shows_no_data_and_no_lists() -> void:
	var page := _page(EconomyFixture.game())
	assert_true(_labels(page).has(NO_DATA))
	assert_false((page.find_child("Lists", true, false) as Control).visible)


func test_before_the_first_season_shows_no_season_yet() -> void:
	var page := _page(EconomyFixture.game(GEN))
	assert_true(_labels(page).has(NO_SEASON))
	assert_false((page.find_child("Lists", true, false) as Control).visible)


## M6 (L21): the fourth measure, Men under arms, is a list of its own from milestone six, and is hidden before it.
func test_the_fourth_measure_men_under_arms_shows_from_milestone_six() -> void:
	var page := _page(_played_one_season(), "6")
	var army := _column(page, "army")
	assert_true(army.visible, "the army list shows at milestone 6")
	assert_eq(_table(page, "army").section_title, "Men under arms")
	var rows := _row_texts(_table(page, "army"))
	assert_eq(rows.size(), 3, "the three countries you know")
	var mine := rows.filter(func(r: Array) -> bool: return str(r[1]).ends_with("(you)"))
	assert_eq(mine.size(), 1, "your row is in the army list")
	var chart := army.find_child("Chart", true, false) as InkChart
	assert_true(chart.caption.begins_with("Your army"), chart.caption)
	assert_true(_column(page, "people").visible, "the earlier measures stay")
	var before := _page(_played_one_season(), "5")
	var hidden := _column(before, "army")
	assert_true(hidden == null or not hidden.visible, "the army list is not shown before milestone 6")


func test_lists_are_hidden_before_the_milestone_of_the_measures() -> void:
	var page := _page(_played_one_season(), "4")
	var land := _column(page, LAND)
	assert_true(land == null or not land.visible)
	var income := _column(page, INCOME)
	assert_true(income == null or not income.visible)


func test_span_choice_changes_the_span() -> void:
	var page := _page(_played_one_season())
	var seg := page.find_child("Span", true, false) as Segmented
	assert_eq(seg.selected_id(), 12)
	seg.select(40, true)
	assert_eq(page.span, 40)
	assert_eq(seg.button_for(12).text, "12 seasons")


func test_accessibility_names_are_set() -> void:
	var page := _page(_played_one_season())
	var seg := page.find_child("Span", true, false) as Segmented
	assert_false(seg.accessibility_name.is_empty())
	assert_eq(_table(page, LAND).section_title, "Land, districts")
	assert_eq(_table(page, INCOME).section_title, "Income, a season")
	assert_false((_column(page, LAND).find_child("Chart", true, false) as InkChart).accessibility_description.is_empty())


func test_the_third_measure_wraps_to_a_second_row_and_fits_1280_and_1024() -> void:
	for size: Vector2i in [Vector2i(2560, 1440), Vector2i(1280, 720), Vector2i(1024, 600)]:
		var harness := UIHarness.new(size)
		harness.mount(self)
		var root := Control.new()
		root.theme = KitTheme.load_for(1.0)
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		harness.viewport.add_child(root)
		# The Study frame and its nav leave this width to a page (the minimum window is checked as the top bar does).
		var width := float(size.x) - 260.0
		var host := Control.new()
		host.size = Vector2(width, float(size.y))
		root.add_child(host)
		var game := InsightsFixture.genoa_first_year()
		var page := (load(SCENE) as PackedScene).instantiate() as PageRankings
		page.milestone = "5"
		host.add_child(page)
		page.size = host.size
		page.refresh(game, &"open")
		await harness.wait_frames(self, 2)
		assert_lte(page.get_combined_minimum_size().x, width, "no horizontal overflow at %s" % str(size))
		var land := _column(page, LAND)
		var income := _column(page, INCOME)
		var people := _column(page, "people")
		assert_true(land.is_visible_in_tree() and income.is_visible_in_tree() and people.is_visible_in_tree())
		var mine := _row_texts(_table(page, "people")).filter(func(r: Array) -> bool: return str(r[1]).ends_with("(you)"))
		assert_eq(mine.size(), 1, "your row is in the People list")
		assert_false(str(mine[0][2]).begins_with("about"), "your people are exact")
		for col: Control in [land, income, people]:
			assert_lte(col.position.x + col.size.x, width + 1.0, "no column past the page at %s" % str(size))
		if size.x >= 2560:
			assert_eq(people.position.y, land.position.y, "all three on one row at 2560")
		elif size.x == 1280:
			assert_eq(income.position.y, land.position.y, "land and income share the first row")
			assert_gt(people.position.y, land.position.y, "People is on the second row at 1280")
		else:
			assert_gt(people.position.y, income.position.y, "one column a row at 1024")
		harness.dispose()
