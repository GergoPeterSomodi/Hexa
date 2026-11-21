## GUT tests for the Economy page of the Statesman's Study, "This season" (docs/architecture/m4-build-spec.md 6.7;
## study_econ.jpg): the closed ledger after Spring 1480 on EconomyFixture (Genoa), the season in play, the tax levels
## (a press asks set_tax, a hover shows the change), a row asks look_at, the treasury-only switch, the sandbox message,
## accessibility names and the fit at 1280 x 720 and 2560 x 1440.
extends GutTest

const SCENE := "res://shell/screens/study/page_economy.tscn"
const STUDY := "res://shell/screens/study.tscn"
const GEN := &"GEN"
const MINUS := "−"
const HIGH := 2
const NORMAL := 1

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


func _page(game: Game, treasury_only: bool = false) -> PageEconomy:
	var page := (load(SCENE) as PackedScene).instantiate() as PageEconomy
	page.treasury_only = treasury_only
	page.action_requested.connect(func(action: Array) -> void: _requests.append(action))
	_root.add_child(page)
	page.refresh(game, &"open")
	return page


func _chip_texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	for child: Node in node.get_children():
		if child is DeltaChip:
			out.append((child as DeltaChip).text())
		out.append_array(_chip_texts(child))
	return out


func _label_texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	for child: Node in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		out.append_array(_label_texts(child))
	return out


func _buttons(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	for child: Node in node.get_children():
		if child is Button:
			out.append(child as Button)
		out.append_array(_buttons(child))
	return out


func _segmented(page: PageEconomy) -> Segmented:
	return page.find_child("TaxLevels", true, false) as Segmented


func _hint(page: PageEconomy) -> String:
	return (page.find_child("TaxHint", true, false) as Label).text


func test_is_the_economy_page_shown_from_four() -> void:
	var page := _page(EconomyFixture.game(GEN))
	assert_true(page is StudyPage)
	assert_true(page is PageEconomy)
	var ids: Array = []
	for entry: Dictionary in StudyPages.shown("4"):
		ids.append(entry["id"])
	assert_true(ids.has(&"economy"))
	assert_false(StudyPages.shown("3").any(func(e: Dictionary) -> bool: return e["id"] == &"economy"))


func test_before_the_first_season_shows_expected_and_tax_only() -> void:
	var game := EconomyFixture.game(GEN)
	var page := _page(game)
	var texts := _label_texts(page)
	assert_true(texts.has(PageEconomy.NO_SEASON))
	assert_false(texts.has(PageEconomy.HEAD_IN))
	assert_false(texts.has(PageEconomy.EARNS))
	assert_false((page.find_child("Right", true, false) as Control).visible)
	assert_true(texts.has(PageEconomy.EXPECTED))
	var seg := _segmented(page)
	assert_not_null(seg)
	assert_eq(seg.button_for(0).text, "Low")
	assert_eq(seg.button_for(NORMAL).text, "Normal")
	assert_eq(seg.button_for(HIGH).text, "High")
	assert_eq(seg.selected_id(), NORMAL)
	assert_eq(_hint(page), "Normal: as now")
	var expected := StudyEconomy.this_season(game, GEN)["expected"] as Dictionary
	assert_true(_chip_texts(page).has(Words.signed(int(expected["realm"]))))


func test_after_spring_shows_the_ledger_and_the_chart() -> void:
	var game := EconomyFixture.game(GEN)
	assert_true(bool(Season.run(game)["ok"]))
	var page := _page(game)
	var chips := _chip_texts(page)
	assert_true(chips.has("+102"), "money in total")
	assert_true(chips.has(MINUS + "16"), "money out total")
	assert_true(chips.has("+86"), "left over")
	assert_true(chips.has("+65"), "taxes on people")
	assert_true((page.find_child("Right", true, false) as Control).visible)
	var chart := page.find_child("Chart", true, false) as InkChart
	assert_ne(chart.summary(), "No data yet")
	assert_false(_label_texts(page).has(PageEconomy.NO_SEASON))


func test_pressing_a_tax_level_asks_set_tax() -> void:
	var page := _page(EconomyFixture.game(GEN))
	_segmented(page).button_for(HIGH).button_pressed = true
	assert_eq(_requests.size(), 1)
	assert_eq(_requests[0][0], &"set_tax")
	assert_eq(_requests[0][1], HIGH)


func test_hovering_a_level_shows_its_expected_change_and_leaving_restores_it() -> void:
	var game := EconomyFixture.game(GEN)
	var page := _page(game, true)
	var options := (StudyEconomy.this_season(game, GEN)["tax"] as Dictionary)["options"] as Array
	var high := options[HIGH] as Dictionary
	var expected_note := "High: %s a season" % Words.signed_ducats(int(high["change"]))
	_segmented(page).button_for(HIGH).mouse_entered.emit()
	assert_eq(_hint(page), expected_note)
	_segmented(page).button_for(HIGH).mouse_exited.emit()
	assert_eq(_hint(page), "Normal: as now")


func test_a_row_with_a_hex_asks_look_at() -> void:
	var game := EconomyFixture.game(GEN)
	assert_true(bool(Season.run(game)["ok"]))
	var page := _page(game)
	var link: Button = null
	for btn: Button in _buttons(page):
		if btn.accessibility_name.begins_with("Look at"):
			link = btn
			break
	assert_not_null(link, "a ledger or list row with a hex")
	link.pressed.emit()
	assert_eq(_requests.size(), 1)
	assert_eq(_requests[0][0], &"look_at")
	assert_true(_requests[0][1] is Vector2i)


func test_treasury_only_switch_picks_the_measure() -> void:
	var game := EconomyFixture.game(GEN)
	var expected := StudyEconomy.this_season(game, GEN)["expected"] as Dictionary
	var page_net := _page(game, true)
	assert_true(_chip_texts(page_net).has(Words.signed(int(expected["net"]))))
	var page_realm := _page(game, false)
	assert_true(_chip_texts(page_realm).has(Words.signed(int(expected["realm"]))))


func test_sandbox_has_no_treasury() -> void:
	var game := Game.new_game(EconomyFixture.map(), 1480)
	var page := _page(game)
	assert_true(_label_texts(page).has(PageEconomy.NO_TREASURY))
	assert_false((page.find_child("Columns", true, false) as Control).visible)


func test_controls_have_accessibility_names() -> void:
	var game := EconomyFixture.game(GEN)
	assert_true(bool(Season.run(game)["ok"]))
	var page := _page(game)
	assert_eq(_segmented(page).accessibility_name, "Tax level")
	assert_eq((page.find_child("Chart", true, false) as InkChart).accessibility_name, PageEconomy.CHART_CAPTION)
	for btn: Button in _buttons(page):
		assert_false(btn.accessibility_name.is_empty() and btn.text.is_empty())


func test_the_study_opens_the_economy_page() -> void:
	Session.game = EconomyFixture.game(GEN)
	var study := (load(STUDY) as PackedScene).instantiate() as Study
	study.configure(StudyPages.shown("4"))
	_harness.stack.push(study)
	study.open_page(&"economy")
	assert_eq(study.current_page_id(), &"economy")
	assert_true(study.current_page() is PageEconomy)
	assert_eq(study.current_page().page_id, &"economy")
	_harness.stack.remove(study)
	study.free()


func test_fits_at_1280_by_720_and_2560_by_1440() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1440)]:
		var harness := UIHarness.new(size)
		harness.mount(self)
		var root := Control.new()
		root.theme = KitTheme.load_for(1.0)
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		harness.viewport.add_child(root)
		var game := EconomyFixture.game(GEN)
		assert_true(bool(Season.run(game)["ok"]))
		var page := (load(SCENE) as PackedScene).instantiate() as PageEconomy
		root.add_child(page)
		page.refresh(game, &"open")
		await harness.wait_frames(self, 2)
		assert_lte(page.get_combined_minimum_size().x, float(size.x) - 60.0, "no horizontal overflow at %s" % str(size))
		harness.dispose()


func test_the_whole_page_with_its_tax_control_fits_1280_by_720() -> void:
	var harness := UIHarness.new(Vector2i(1280, 720))
	harness.mount(self)
	var root := Control.new()
	root.theme = KitTheme.load_for(1.0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	harness.viewport.add_child(root)
	var game := EconomyFixture.game(GEN)
	assert_true(bool(Season.run(game)["ok"]))
	var page := (load(SCENE) as PackedScene).instantiate() as PageEconomy
	root.add_child(page)
	page.refresh(game, &"open")
	await harness.wait_frames(self, 3)
	# The Study frame leaves about 520 px under its ribbon for a page.
	assert_lte(page.get_combined_minimum_size().y, 520.0, "the ledger and the Tax control need no scrolling")
	assert_not_null(page.find_child("TaxLevels", true, false))
	harness.dispose()


# ----- M4.5 tabs (docs/architecture/m4-5-build-spec.md 4.3 to 4.5, 6.4, 4.10): Districts, Goods and History -----------------

const TABS_AT := "4.5"
const NO_DATA := "No data yet."


func _tabbed(game: Game, tab: StringName = &"") -> PageEconomy:
	var page := (load(SCENE) as PackedScene).instantiate() as PageEconomy
	page.milestone = TABS_AT
	page.action_requested.connect(func(action: Array) -> void: _requests.append(action))
	_root.add_child(page)
	page.refresh(game, &"open")
	if tab != &"":
		page.select_tab(tab)
	return page


func _tab(page: PageEconomy, id: StringName) -> Control:
	return page.get_node(NodePath(String(id))) as Control


func test_the_tabs_are_this_season_districts_goods_history_from_four_point_five() -> void:
	var page := _tabbed(EconomyFixture.game(GEN))
	var ids: Array = []
	for entry: Dictionary in page.shown_tabs():
		ids.append(entry["id"])
	assert_eq(ids, [&"this_season", &"districts", &"goods", &"history"])
	assert_eq(page.current_tab(), &"this_season")
	var old := _page(EconomyFixture.game(GEN))
	old.milestone = "4"  # the shell now defaults to 4.5
	assert_eq(old.shown_tabs().size(), 1, "at milestone 4 only This season shows")


func test_districts_at_turn_one_has_the_five_places_in_the_worked_order() -> void:
	var game := EconomyFixture.game(GEN)
	var page := _tabbed(game, &"districts")
	var tab := _tab(page, &"districts") as EconomyDistrictsTab
	var table := tab.table()
	assert_eq(table.total_count(), 5)
	assert_eq(table.sort_state()["id"], &"year")
	var by_id: Dictionary = {}
	for r: Dictionary in (StudyEconomy.districts(game, GEN)["rows"] as Array):
		by_id[int(r["id"])] = int(r["year"])
	var years: Array[int] = []
	for id: Variant in table.sorted_ids():
		years.append(int(by_id[int(id)]))
	assert_eq(years, [232, 105, 68, 38, 33])
	assert_true(table.row_name(int(table.sorted_ids()[0])).begins_with("Genoa (8, 13)"))
	assert_true(_label_texts(tab).any(func(t: String) -> bool: return t.begins_with("Wild land: 9 places")))
	assert_true(_chip_texts(tab).has("+533 a year"))
	assert_true(_chip_texts(tab).has("+57 a year"))
	assert_eq(table.accessibility_name, "Districts")


func test_districts_look_there_and_show_on_the_map_send_their_actions() -> void:
	var game := EconomyFixture.game(GEN)
	var page := _tabbed(game, &"districts")
	var tab := _tab(page, &"districts") as EconomyDistrictsTab
	var first := int(tab.table().sorted_ids()[0])
	var hex := game.map.hex_of(first)
	tab.look_button().pressed.emit()
	assert_eq(_requests, [[&"look_at", hex]] as Array[Array])
	_requests = []
	tab.show_button().pressed.emit()
	assert_eq(_requests, [[&"map_mode", &"yields", hex]] as Array[Array])
	_requests = []
	tab.table().row_activated.emit(tab.table().selected_row())
	assert_eq(_requests, [[&"look_at", hex]] as Array[Array])
	var second := int(tab.table().sorted_ids()[1])
	page.focus({"tab": &"districts", "hex": game.map.hex_of(second)})
	assert_eq(int(tab.table().selected_row()["id"]), second)
	_requests = []
	tab.show_button().pressed.emit()
	assert_eq(_requests[0][2], game.map.hex_of(second))


func test_goods_at_turn_one_and_turn_five_for_salt() -> void:
	var game := EconomyFixture.game(GEN)
	var page := _tabbed(game, &"goods")
	var tab := _tab(page, &"goods") as EconomyGoodsTab
	var rows := StudyEconomy.goods(game, GEN, 12)["rows"] as Array
	var salt := rows.filter(func(r: Dictionary) -> bool: return str(r["name"]) == "Salt")[0] as Dictionary
	assert_eq(str(salt["lasts_text"]), "in 5 seasons")
	assert_eq(int(tab.table().sorted_ids()[0]), int(rows[0]["id"]), "soonest to run out first")
	var seasons := InsightsFixture.genoa_first_year()
	var page5 := _tabbed(seasons, &"goods")
	var tab5 := _tab(page5, &"goods") as EconomyGoodsTab
	var first := int(tab5.table().sorted_ids()[0])
	assert_eq(tab5.table().row_name(first).get_slice(",", 0), "Salt")
	assert_true(tab5.table().row_name(first).contains("none left"))
	assert_eq(tab5.note_label().text, "Your towns need 1 salt a season; none of your land makes it.")
	assert_eq(tab5.chart().accessibility_name, "Salt: made and in store, the last 4 seasons")
	page5.focus({"tab": &"goods", "good": "wine"})
	assert_true(tab5.chart().caption.begins_with("Wine"))
	assert_eq(_requests.size(), 0, "Goods sends nothing")


func test_history_after_the_first_year_shows_the_worked_season() -> void:
	var game := InsightsFixture.genoa_first_year()
	var page := _tabbed(game, &"history")
	var tab := _tab(page, &"history") as EconomyHistoryTab
	assert_eq(tab.cursor(), 3, "the cursor starts on the newest season")
	assert_eq(tab.ledger_sum, 134)
	tab.chart().point_activated.emit(0)
	assert_eq(tab.shown_season(), 0)
	var texts := _label_texts(tab.ledger())
	assert_true(texts.has("Spring 1480"))
	assert_true(texts.has("Treasury 610 → 696"))
	assert_eq(tab.ledger_sum, 86)
	var chips := _chip_texts(tab.ledger())
	for want: String in ["+65", "+7", "+30", MINUS + "12", MINUS + "4", "+86"]:
		assert_true(chips.has(want), want)
	assert_true(tab.year_chart().summary().contains("1,068"))
	assert_false((tab.find_child("YearNote", true, false) as Label).visible)


func test_history_has_no_year_before_the_first_winter_and_no_seasons_at_turn_one() -> void:
	var game := EconomyFixture.game(GEN)
	var tab := _tab(_tabbed(game, &"history"), &"history") as EconomyHistoryTab
	assert_eq(tab.cursor(), -1)
	assert_true(_label_texts(tab.ledger()).has("No season has ended yet."))
	assert_true((tab.find_child("YearNote", true, false) as Label).visible)


func test_history_keys_move_the_cursor_and_every_ledger_adds_up() -> void:
	var game := InsightsFixture.genoa_first_year()
	var page := _tabbed(game, &"history")
	var tab := _tab(page, &"history") as EconomyHistoryTab
	var chart := tab.chart()
	chart.grab_focus()
	var left := InputEventKey.new()
	left.keycode = KEY_LEFT
	left.pressed = true
	chart.call(&"_gui_input", left)
	assert_eq(tab.cursor(), 2)
	assert_eq(tab.shown_season(), 2)
	assert_true(_label_texts(tab.ledger()).has("Autumn 1480"))
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	chart.call(&"_gui_input", right)
	assert_eq(tab.cursor(), 3)
	var data := StudyEconomy.history(game, GEN, 12)["seasons"] as Array
	for i: int in data.size():
		chart.point_activated.emit(i)
		assert_eq(tab.ledger_sum, int((data[i] as Dictionary)["change"]), "season %d adds up" % i)


func test_history_of_forty_seasons_adds_up_at_both_spans() -> void:
	var game := InsightsFixture.forty_seasons()
	var page := _tabbed(game, &"history")
	var tab := _tab(page, &"history") as EconomyHistoryTab
	assert_eq((StudyEconomy.history(game, GEN, 12)["seasons"] as Array).size(), 12)
	tab.span_control().button_for(40).button_pressed = true
	var seasons := StudyEconomy.history(game, GEN, 40)["seasons"] as Array
	assert_eq(seasons.size(), 40)
	assert_eq(tab.span, 40)
	for i: int in seasons.size():
		tab.chart().point_activated.emit(i)
		assert_eq(tab.ledger_sum, int((seasons[i] as Dictionary)["change"]), "season %d adds up" % i)


func test_the_span_writes_the_setting_and_both_tabs_follow() -> void:
	Session.game = InsightsFixture.genoa_first_year()
	var study := (load(STUDY) as PackedScene).instantiate() as Study
	study.configure(StudyPages.shown("4"), TABS_AT)
	_harness.stack.push(study)
	study.open_page(&"economy", {"tab": &"goods"})
	var page := study.current_page() as PageEconomy
	assert_eq(page.current_tab(), &"goods")
	var goods := _tab(page, &"goods") as EconomyGoodsTab
	var history := _tab(page, &"history") as EconomyHistoryTab
	goods.span_control().button_for(40).button_pressed = true
	assert_eq(int(_harness.settings.get_value("state/study_span")), 40)
	assert_eq(goods.span, 40)
	assert_eq(history.span, 40)
	assert_eq(history.span_control().selected_id(), 40)
	page.select_tab(&"history")
	history.span_control().button_for(12).button_pressed = true
	assert_eq(int(_harness.settings.get_value("state/study_span")), 12)
	assert_eq(goods.span_control().selected_id(), 12)
	_harness.stack.remove(study)
	study.free()


func test_tab_actions_go_up_through_the_page() -> void:
	Session.game = EconomyFixture.game(GEN)
	var study := (load(STUDY) as PackedScene).instantiate() as Study
	study.configure(StudyPages.shown("4"), TABS_AT)
	_harness.stack.push(study)
	study.open_page(&"economy", {"tab": &"districts"})
	var page := study.current_page() as PageEconomy
	var tab := _tab(page, &"districts") as EconomyDistrictsTab
	page.action_requested.connect(func(action: Array) -> void: _requests.append(action))
	tab.show_button().pressed.emit()
	assert_eq(_requests[0][0], &"map_mode")
	assert_eq(_requests[0][1], &"yields")
	_harness.stack.remove(study)
	study.free()


func test_no_player_shows_no_data_on_each_tab() -> void:
	var game := Game.new_game(EconomyFixture.map(), 1480)
	var page := _tabbed(game)
	for id: StringName in [&"districts", &"goods", &"history"]:
		page.select_tab(id)
		var tab := _tab(page, id)
		assert_true(_label_texts(tab).has(NO_DATA), String(id))
		assert_false((tab.find_child("Content", true, false) as Control).visible)


func test_each_tab_refresh_leaves_the_digest_and_version() -> void:
	var game := InsightsFixture.genoa_first_year()
	var digest := game.digest()
	var version := game.version
	var page := _tabbed(game)
	for id: StringName in [&"districts", &"goods", &"history"]:
		page.select_tab(id)
		page.refresh(game, &"season_ended")
	assert_eq(game.digest(), digest)
	assert_eq(game.version, version)


func test_the_tab_controls_have_accessibility_names() -> void:
	var game := InsightsFixture.genoa_first_year()
	var page := _tabbed(game)
	for id: StringName in [&"districts", &"goods", &"history"]:
		page.select_tab(id)
		for btn: Button in _buttons(_tab(page, id)):
			assert_false(btn.accessibility_name.is_empty() and btn.text.is_empty())
	assert_eq((_tab(page, &"goods") as EconomyGoodsTab).span_control().accessibility_name, "Span in seasons")
	assert_eq((_tab(page, &"history") as EconomyHistoryTab).chart().accessibility_name, EconomyHistoryTab.CHART_CAPTION)


func test_the_tabs_fit_at_1280_by_720_and_2560_by_1440() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1440)]:
		var harness := UIHarness.new(size)
		harness.mount(self)
		var root := Control.new()
		root.theme = KitTheme.load_for(1.0)
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		harness.viewport.add_child(root)
		var game := InsightsFixture.genoa_first_year()
		var page := (load(SCENE) as PackedScene).instantiate() as PageEconomy
		page.milestone = TABS_AT
		root.add_child(page)
		page.refresh(game, &"open")
		for id: StringName in [&"districts", &"goods", &"history"]:
			page.select_tab(id)
			await harness.wait_frames(self, 2)
			assert_lte(page.get_combined_minimum_size().x, float(size.x) - 60.0, "%s fits %s" % [String(id), str(size)])
		harness.dispose()


func test_the_cursor_keeps_its_season_when_the_span_changes() -> void:
	var game := InsightsFixture.forty_seasons()
	var page := _tabbed(game, &"history")
	var tab := _tab(page, &"history") as EconomyHistoryTab
	assert_eq(tab.cursor(), 11, "on the newest of 12")
	tab.span_control().button_for(40).button_pressed = true
	assert_eq(tab.cursor(), 39, "still the newest season")
	var seasons := StudyEconomy.history(game, GEN, 40)["seasons"] as Array
	tab.chart().point_activated.emit(30)
	var turn := int((seasons[30] as Dictionary)["turn"])
	tab.refresh(game, GEN)
	assert_eq(int(((StudyEconomy.history(game, GEN, 40)["seasons"] as Array)[tab.cursor()] as Dictionary)["turn"]), turn)
	tab.span_control().button_for(12).button_pressed = true
	assert_eq(tab.cursor(), 2, "turn 31 is found again by turn in the last 12")


func test_a_key_move_sticks_while_the_pointer_rests_on_the_chart() -> void:
	var game := InsightsFixture.forty_seasons()
	var tab := _tab(_tabbed(game, &"history"), &"history") as EconomyHistoryTab
	tab.chart().point_activated.emit(8)
	tab.chart().call(&"_key_cursor", 5)
	assert_eq(tab.cursor(), 5)
	tab.chart().point_hovered.emit(2)
	assert_eq(tab.shown_season(), 2, "a hover only shows")
	assert_eq(tab.cursor(), 5)
	tab.chart().point_hovered.emit(-1)
	assert_eq(tab.shown_season(), 5)


func test_a_dead_player_shows_no_data_on_each_tab() -> void:
	var game := EconomyFixture.game(GEN)
	Countries.by_tag(game, GEN).alive = false
	var page := _tabbed(game)
	for id: StringName in [&"districts", &"goods", &"history"]:
		page.select_tab(id)
		assert_true(_label_texts(_tab(page, id)).has(NO_DATA), String(id))


func _table_text_width(table: StudyTable, column: int, text: String) -> float:
	var grid := table.tree()
	return grid.get_theme_font(&"font", &"StudyTree").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, grid.get_theme_font_size(&"font_size", &"StudyTree")).x


func test_districts_place_and_what_are_not_truncated_at_1280_and_2560() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1440)]:
		var harness := UIHarness.new(size)
		harness.mount(self)
		var root := Control.new()
		root.theme = KitTheme.load_for(1.0)
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		harness.viewport.add_child(root)
		var game := EconomyFixture.game(GEN)
		var page := (load(SCENE) as PackedScene).instantiate() as PageEconomy
		page.milestone = TABS_AT
		root.add_child(page)
		page.refresh(game, &"open")
		page.select_tab(&"districts")
		# 1280 x 720: the Study frame holds a page about 1000 px wide.
		page.size = Vector2(minf(float(size.x) - 280.0, 1000.0 * float(size.x) / 1280.0), float(size.y))
		await harness.wait_frames(self, 4)
		var table := (_tab(page, &"districts") as EconomyDistrictsTab).table()
		var grid := table.tree()
		var item := grid.get_root().get_first_child()
		var checked := 0
		while item != null:
			for c: int in [0, 1]:
				var need := _table_text_width(table, c, item.get_text(c))
				assert_gte(float(grid.get_column_width(c)), need, "%s: column %d holds '%s' at %s" % [table.section_title, c, item.get_text(c), str(size)])
				assert_ne(item.get_tooltip_text(c), "", "the full text is the tooltip")
				checked += 1
			item = item.get_next()
		assert_eq(checked, 10, "five rows, two columns")
		harness.dispose()


func test_goods_shows_seven_whole_rows_above_the_chart_at_1280_by_720() -> void:
	var harness := UIHarness.new(Vector2i(1280, 720))
	harness.mount(self)
	var root := Control.new()
	root.theme = KitTheme.load_for(1.0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	harness.viewport.add_child(root)
	var game := InsightsFixture.genoa_first_year()
	var page := (load(SCENE) as PackedScene).instantiate() as PageEconomy
	page.milestone = TABS_AT
	root.add_child(page)
	page.refresh(game, &"open")
	page.select_tab(&"goods")
	await harness.wait_frames(self, 4)
	var tab := _tab(page, &"goods") as EconomyGoodsTab
	var grid := tab.table().tree()
	assert_gte(tab.table().total_count(), 7, "the fixture has seven goods or more")
	var item := grid.get_root().get_first_child()
	for i: int in 7:
		var area := grid.get_item_area_rect(item, 0)
		assert_lte(area.end.y, grid.size.y + 0.5, "row %d is whole inside the table" % (i + 1))
		item = item.get_next()
	assert_gte(tab.table().get_global_rect().end.y, 0.0)
	assert_lte(tab.table().get_global_rect().end.y, tab.chart().get_global_rect().position.y, "the table ends above the chart")
	harness.dispose()


func _tables_in(node: Node, out: Array[StudyTable]) -> void:
	if node is StudyTable and (node as Control).is_visible_in_tree():
		out.append(node as StudyTable)
	for child: Node in node.get_children():
		_tables_in(child, out)


## Every shown StudyTable of `page` in the real Study frame: each cell's text and each heading fit their column, and the
## columns together fill at least 90 % of the table's width.
func _check_tables(page: Control, label: String) -> int:
	var tables: Array[StudyTable] = []
	_tables_in(page, tables)
	for table: StudyTable in tables:
		var grid := table.tree()
		var font := grid.get_theme_font(&"font", &"StudyTree")
		var size := grid.get_theme_font_size(&"font_size", &"StudyTree")
		var total := 0.0
		for c: int in grid.columns:
			var width := float(grid.get_column_width(c))
			total += width
			var title := grid.get_column_title(c)
			var head_font := grid.get_theme_font(&"title_button_font", &"StudyTree")
			var head_size := grid.get_theme_font_size(&"title_button_font_size", &"StudyTree")
			assert_gte(width, head_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, head_size).x, "%s: heading '%s' fits" % [label, title])
			var item := grid.get_root().get_first_child()
			while item != null and item.get_metadata(0) != null and int(item.get_metadata(0)) >= 0:
				var text := item.get_text(c)
				assert_gte(width, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, "%s: '%s' fits column %d" % [label, text, c])
				item = item.get_next()
		assert_gte(total, grid.size.x * 0.9, "%s: the columns fill the table (%.0f of %.0f)" % [label, total, grid.size.x])
	return tables.size()


func test_every_study_table_fits_its_columns_and_fills_the_page_at_1280_and_2560() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1440)]:
		var harness := UIHarness.new(size)
		harness.mount(self)
		Session.game = InsightsFixture.genoa_first_year()
		var study := (load(STUDY) as PackedScene).instantiate() as Study
		study.configure(StudyPages.shown("4.5"))
		harness.stack.push(study)
		var seen := 0
		study.open_page(&"economy")
		var economy := study.current_page() as PageEconomy
		for tab: StringName in [&"districts", &"goods"]:
			economy.select_tab(tab)
			await harness.wait_frames(self, 4)
			seen += _check_tables(economy, "%s %s" % [String(tab), str(size)])
		for id: StringName in [&"rankings", &"history"]:
			study.open_page(id)
			await harness.wait_frames(self, 4)
			seen += _check_tables(study.current_page(), "%s %s" % [String(id), str(size)])
		assert_gte(seen, 4, "four tables checked at %s" % str(size))
		harness.stack.remove(study)
		study.free()
		harness.dispose()
