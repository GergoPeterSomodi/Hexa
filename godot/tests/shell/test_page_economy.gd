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
