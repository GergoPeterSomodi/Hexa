## GUT tests for the Chancellor's report screen (docs/architecture/m3-build-spec.md 6.4 and 9;
## ui-style-and-feedback-spec.md 6.8). The screen is instantiated from its scene, fed by tests/fixtures/report_sample.gd.
extends GutTest

const SCENE := "res://shell/screens/season_report.tscn"
const GENOA_HEX := Vector2i(7, 12)

var _harness: UIHarness = null
var _requests: Array[Array] = []


func before_each() -> void:
	Bindings.reset_defaults()
	_harness = UIHarness.new()
	_harness.mount(self)
	_harness.stack.theme = KitTheme.load_for(1.0)
	_requests = []
	_harness.ctx.app_requested.connect(func(what: StringName, args: Dictionary) -> void: _requests.append([what, args]))


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	_harness = null
	Bindings.reset_defaults()


func _open(summary: Dictionary, reopened: bool = false) -> SeasonReport:
	var report := (load(SCENE) as PackedScene).instantiate() as SeasonReport
	report.show_summary(summary, reopened)
	_harness.stack.push(report)
	return report


func _section_ids(summary: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for section: Dictionary in summary["sections"]:
		out.append(StringName(str(section["id"])))
	return out


func _count_of(btn: Button) -> String:
	return (btn.get_node("Count") as Label).text


func _button_named(report: SeasonReport, text: String) -> Button:
	for btn: Button in report.link_buttons():
		if btn.text == text:
			return btn
	return null


func test_fixture_has_the_eleven_sections_in_order() -> void:
	var summary := ReportSample.genoa_spring()
	assert_eq(_section_ids(summary), ReportSample.SECTION_IDS)
	assert_eq(ReportSample.SECTION_IDS.size(), 11, "M7 adds the war section after armies")
	assert_false(bool(summary["quiet"]))
	assert_eq(summary["title"], "Spring 1480")
	assert_eq(summary["seal_letter"], "G")


func test_quiet_fixture_has_only_glance_and_the_link() -> void:
	var summary := ReportSample.quiet_season()
	assert_true(bool(summary["quiet"]))
	assert_eq(_section_ids(summary), [&"glance"])
	assert_eq(summary["lede"], "A quiet season.")


func test_every_section_of_the_fixture_is_drawn_with_its_count() -> void:
	var summary := ReportSample.genoa_spring()
	var report := _open(summary)
	await _harness.wait_frames(self, 2)

	for section: Dictionary in summary["sections"]:
		var id := StringName(str(section["id"]))
		assert_not_null(report.sheet().section_box(id), "section %s drawn" % id)
		var heading := report.sheet().section_box(id).get_parent().get_node("Heading") as Label
		assert_eq(heading.text, section["title"])
	var nav := report.sheet().nav()
	assert_eq(_count_of(nav.button_for(&"before")), "3")
	assert_eq(_count_of(nav.button_for(&"goods")), "6")
	assert_eq(_count_of(nav.button_for(&"works")), "1")
	assert_eq(_count_of(nav.button_for(&"orders")), "3")
	assert_false((nav.button_for(&"glance").get_node("Count") as Label).visible, "glance has no count")


func test_the_war_section_has_its_count_in_the_nav() -> void:
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	assert_eq(_count_of(report.sheet().nav().button_for(&"war")), "4", "the War count")


func test_glance_shows_up_to_five_boxed_chips() -> void:
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	var chips := report.sheet().section_box(&"glance").find_child("Chips", true, false) as HFlowContainer
	assert_not_null(chips)
	assert_eq(chips.get_child_count(), 5)
	var first := chips.get_child(0) as PanelContainer
	assert_eq(first.theme_type_variation, &"PanelSlot")
	assert_true(first.find_child("Delta", true, false) is DeltaChip, "a chip carries its DeltaChip")


func test_title_lede_seal_and_seal_press() -> void:
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	assert_eq(report.sheet().title, "Spring 1480")
	assert_eq(report.sheet().ribbon().text, "Spring 1480")
	assert_eq(report.sheet().lede, "The Chancellor's report to the Doge of Genoa. Summer 1480 begins.")
	assert_eq(report.sheet().seal_text(), "G")
	assert_eq(report.sheet().seal_tone, &"vermilion")


func test_quiet_season_uses_the_plain_seal_and_one_glance_line() -> void:
	var report := _open(ReportSample.quiet_season())
	await _harness.wait_frames(self, 2)
	assert_eq(report.sheet().seal_tone, &"plain")
	assert_eq(report.sheet().lede, "A quiet season.")
	assert_eq(report.sheet().nav().button_for(&"befell"), null, "a quiet report has no What befell")
	var link := _button_named(report, "2 works under way; nothing else of note.")
	assert_not_null(link, "the one glance line is a link to the capital")
	assert_true(link.name.begins_with("Link"))
	assert_eq(report.link_buttons().size(), 2, "the link and its Show Genoa action")


func test_link_closes_the_report_and_asks_for_a_glide_to_its_hex() -> void:
	var picked: Array[Array] = []
	var report := _open(ReportSample.genoa_spring())
	report.link_chosen.connect(func(hex: Vector2i, action: Array) -> void: picked.append([hex, action]))
	await _harness.wait_frames(self, 2)

	var link := _button_named(report, "Wine runs out in 4 seasons; the first vintage is Autumn 1481.")
	assert_not_null(link, "a line with a hex is a link button")
	link.pressed.emit()
	await _harness.wait_frames(self, 2)

	assert_eq(_harness.stack.count(), 0, "the link closes the report")
	assert_eq(picked.size(), 1)
	assert_eq(picked[0][0], Vector2i(7, 12))
	var look := _requests.filter(func(r: Array) -> bool: return r[0] == &"look_at")
	assert_eq(look.size(), 1)
	assert_eq(look[0][1], {"hex": Vector2i(7, 12), "select": true})
	assert_eq(_requests.filter(func(r: Array) -> bool: return r[0] == &"report_closed").size(), 1, "on_exit tells the App")


func test_action_button_closes_and_glides_to_its_hex() -> void:
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	var action: KitButton = null
	for btn: Button in report.link_buttons():
		if btn.name.begins_with("Action") and btn.text == "Show Genoa":
			action = btn as KitButton
	assert_not_null(action, "the before list has its action button")
	action.pressed.emit()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 0)
	var look := _requests.filter(func(r: Array) -> bool: return r[0] == &"look_at")
	assert_eq(look.size(), 1)
	assert_eq(look[0][1]["hex"], Vector2i(8, 13))


func test_space_enter_and_esc_close_the_report() -> void:
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	_harness.send_key(KEY_SPACE)
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 0, "Space closes")

	report = _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	_harness.send_key(KEY_ENTER)
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 0, "Enter closes")

	report = _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	assert_true(_harness.stack.back(), "Esc handled by the stack")
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 0, "Esc closes")


func test_begin_is_focused_and_says_the_season_that_begins() -> void:
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	assert_eq(report.begin_button().text, "BEGIN SUMMER", "KitButton sets its own caps")
	assert_eq(report.begin_button().kind, KitButton.Kind.MENU_PRIMARY)
	assert_eq(_harness.viewport.gui_get_focus_owner(), report.begin_button(), "the primary button holds focus")
	report.begin_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0)


func test_reopened_report_says_back_to_the_map() -> void:
	var report := _open(ReportSample.genoa_spring(), true)
	await _harness.wait_frames(self, 2)
	assert_eq(report.begin_button().text, "BACK TO THE MAP")


func test_segmented_writes_the_season_report_setting() -> void:
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	assert_eq(report.segmented().selected_id(), "full")
	report.segmented().button_for("brief").button_pressed = true
	assert_eq(_harness.settings.get_value("game/season_report"), "brief")
	report.segmented().button_for("off").button_pressed = true
	assert_eq(_harness.settings.get_value("game/season_report"), "off")


func test_glance_chips_hold_no_buttons() -> void:
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	var glance := report.sheet().section_box(&"glance")
	assert_eq(glance.find_children("*", "Button", true, false).size(), 0, "chips are labels, not links")


func test_glance_chip_value_and_label_use_the_light_ink() -> void:
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	var chip := report.sheet().section_box(&"glance").find_child("Chips", true, false).get_child(0) as PanelContainer
	assert_not_null(chip)
	var texts := chip.find_children("*", "Label", true, false)
	assert_true(texts.size() >= 2, "a label and a value")
	for i: int in 2:  # the label, then the value, in tree order (a DeltaChip's own text comes after)
		var lbl := texts[i] as Label
		assert_eq(lbl.get_theme_color(&"font_color"), Tokens.TEXT, "%s is light on the dark chip" % lbl.text)


func test_sheet_clears_the_top_bar_and_keeps_the_footer_at_1280_x_720() -> void:
	await _assert_layout(Vector2i(1280, 720))


func test_sheet_clears_the_top_bar_and_keeps_the_footer_at_1600_x_900() -> void:
	await _assert_layout(Vector2i(1600, 900))


## The sheet starts under the bar's real bottom edge (76 px), its ribbon and seal overhang stay on screen below it, and
## the footer (the setting, Begin) is inside the window.
func _assert_layout(view: Vector2i) -> void:
	_harness.viewport.size = view
	_harness.ctx.top_bar_bottom_func = func() -> float: return 76.0
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 3)
	var sheet_rect := report.sheet().get_global_rect()
	assert_true(sheet_rect.position.y >= 76.0 + 60.0 - 0.5, "the sheet starts below the bar and its overhang")
	assert_true(report.sheet().ribbon().get_global_rect().position.y >= 76.0, "the ribbon clears the bar")
	assert_true(report.sheet().seal_node().get_global_rect().position.y >= 76.0, "the seal clears the bar")
	var window := Rect2(Vector2.ZERO, Vector2(view))
	assert_true(window.encloses(sheet_rect), "the sheet fits the window")
	assert_true(report.sheet().footer().visible, "the footer shows")
	assert_true(window.encloses(report.begin_button().get_global_rect()), "Begin is on screen")
	assert_true(window.encloses(report.segmented().get_global_rect()), "the setting is on screen")
	_harness.ctx.top_bar_bottom_func = Callable()
	_harness.viewport.size = Vector2i(1280, 720)


func _requested(what: StringName) -> Array:
	return _requests.filter(func(r: Array) -> bool: return r[0] == what)


func test_open_the_study_closes_the_report_and_asks_for_the_economy_page() -> void:
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	var btn := report.find_child("StudyButton", true, false) as KitButton
	assert_not_null(btn, "the footer has Open the study")
	assert_eq(btn.text, "Open the study")
	assert_eq(btn.embedded_key_cap().key_text, "I", "with a key cap of I")
	btn.pressed.emit()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 0, "the report closes")
	assert_eq(_requested(&"study").size(), 1)
	assert_eq(_requested(&"study")[0][1], {"page": &"economy"})
	assert_eq(_requested(&"look_at").size(), 0, "no glide")
	assert_eq(_requested(&"report_closed").size(), 1, "the App is told the report is closed")


func test_the_i_key_opens_the_study_from_the_report() -> void:
	var prev := Session.game
	Session.new_scenario("north_italy_1480", 1480, &"GEN")  # a game with a treasury: the button (and its key) show
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	assert_not_null(report)
	_harness.send_key(KEY_I)
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 0)
	assert_eq(_requested(&"study").size(), 1)
	Session.game = prev


func test_a_line_with_the_study_action_opens_the_study() -> void:
	var summary := ReportSample.genoa_spring()
	for section: Dictionary in summary["sections"]:
		if section["id"] == &"before":
			(section["lines"] as Array).append({
				"text": "The treasury will fall by 12 ducats this season.", "tone": "warn", "action": [&"study", &"economy"],
				"action_label": "Open the study", "severity": 1,
			})
	var report := _open(summary)
	await _harness.wait_frames(self, 2)
	var action: KitButton = null
	for btn: Button in report.link_buttons():
		if btn.name.begins_with("Action") and btn.text == "Open the study":
			action = btn as KitButton
	assert_not_null(action, "the line has its action button")
	action.pressed.emit()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 0)
	assert_eq(_requested(&"study").size(), 1, "the study, not a glide")
	assert_eq(_requested(&"study")[0][1], {"page": &"economy"})
	assert_eq(_requested(&"look_at").size(), 0)


## M5 spec 6.8 and 6.10: the hunger line of Reminders (its action opens People) and the report's People links.
func test_the_hunger_line_opens_the_people_page_and_a_people_link_glides() -> void:
	var summary := ReportSample.genoa_spring()
	for section: Dictionary in summary["sections"]:
		if section["id"] == &"before":
			(section["lines"] as Array).append({
				"text": "Your towns went hungry: 8 of 9 food. They lose people each season until they are fed.", "tone": "bad",
				"action": Reminders.PEOPLE_ACTION.duplicate(), "action_label": "Open People", "severity": 2,
			})
	var report := _open(summary)
	await _harness.wait_frames(self, 2)
	var action: KitButton = null
	for btn: Button in report.link_buttons():
		if btn.name.begins_with("Action") and btn.text == "Open People":
			action = btn as KitButton
	assert_not_null(action, "the hunger line has its Open People button")
	action.pressed.emit()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 0, "the report closes")
	assert_eq(_requested(&"study").size(), 1)
	assert_eq(_requested(&"study")[0][1], {"page": &"people"}, "the People page, not Economy")
	assert_eq(_requested(&"look_at").size(), 0)


func test_open_the_study_hides_in_a_game_without_countries() -> void:
	var prev := Session.game
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	assert_false((report.find_child("StudyButton", true, false) as Button).visible, "the sandbox has no treasury")
	_harness.stack.clear()
	Session.game = prev
