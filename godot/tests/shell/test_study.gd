## GUT tests for the Statesman's Study frame (docs/architecture/m4-build-spec.md 6.7). The pages are the test page
## tests/fixtures/study_page_sample.tscn, listed by configure(); StudyPages.LIST is empty in W11a.
extends GutTest

const SCENE := "res://shell/screens/study.tscn"
const SAMPLE := "res://tests/fixtures/study_page_sample.tscn"
const GENOA_HEX := Vector2i(7, 12)
const FRAME_INSET := Vector2(30.0, 30.0)
const COUNTING := "res://tests/fixtures/study_page_counting.tscn"

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


func _sample_entries(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(count):
		var id := &"sample" if i == 0 else StringName("sample%d" % (i + 1))
		out.append({"id": id, "title": "Sample %d" % (i + 1), "scene": SAMPLE, "since": "4"})
	return out


func _open(entries: Array[Dictionary]) -> Study:
	var study := (load(SCENE) as PackedScene).instantiate() as Study
	study.configure(entries)
	_harness.stack.push(study)
	return study


func _open_at(entries: Array[Dictionary], at: String) -> Study:
	var study := (load(SCENE) as PackedScene).instantiate() as Study
	study.configure(entries, at)
	_harness.stack.push(study)
	return study


func _ids(tabs: Array[Dictionary]) -> Array:
	var out: Array = []
	for tab: Dictionary in tabs:
		out.append(StringName(str(tab["id"])))
	return out


func test_study_is_an_opaque_screen_with_its_id() -> void:
	var study := _open(_sample_entries(1))
	assert_eq(study.kind, Screen.Kind.OPAQUE)
	assert_eq(study.screen_id, &"study")


func test_frame_has_ribbon_date_close_key_cap_and_nav() -> void:
	var study := _open(_sample_entries(1))
	assert_eq(study.ribbon().text, "The Statesman's Study")
	assert_eq(study.close_button().text, "Close")
	var cap := study.close_button().embedded_key_cap()
	assert_not_null(cap)
	assert_eq(cap.key_text, "I")
	assert_eq(study.nav().button_for(&"sample").text, "Sample 1")
	if Session.game == null:
		assert_eq(study.date_label().text, "")


func test_open_page_shows_that_page_and_the_nav_follows() -> void:
	var study := _open(_sample_entries(2))
	study.open_page(&"sample2")
	assert_eq(study.current_page_id(), &"sample2")
	assert_eq(study.nav().selected_id(), &"sample2")
	assert_true(study.page_scroll(&"sample2").visible)
	assert_false(study.page_scroll(&"sample").visible)


func test_empty_page_id_opens_the_last_page() -> void:
	var study := _open(_sample_entries(2))
	study.open_page(&"sample2")
	study.open_page(&"")
	assert_eq(study.current_page_id(), &"sample2")


func test_reopen_keeps_the_page_and_its_scroll() -> void:
	var study := _open(_sample_entries(2))
	study.open_page(&"sample")
	await _harness.wait_frames(self, 3)
	var scroll := study.page_scroll(&"sample")
	scroll.scroll_vertical = 200
	await _harness.wait_frames(self, 2)
	study.open_page(&"sample2")

	_harness.stack.remove(study)
	assert_true(is_instance_valid(study))
	assert_eq(_harness.stack.count(), 0)

	_harness.stack.push(study)
	await _harness.wait_frames(self, 3)
	assert_eq(study.current_page_id(), &"sample2")
	study.open_page(&"sample")
	assert_eq(study.page_scroll(&"sample"), scroll)
	assert_eq(scroll.scroll_vertical, 200)


func test_esc_closes_the_study_without_freeing_it() -> void:
	var study := _open(_sample_entries(1))
	assert_true(_harness.stack.back())
	assert_eq(_harness.stack.count(), 0)
	assert_true(is_instance_valid(study))
	_harness.stack.push(study)
	assert_eq(_harness.stack.count(), 1)


func test_i_key_closes_the_study() -> void:
	var study := _open(_sample_entries(1))
	_harness.send_key(KEY_I)
	assert_eq(_harness.stack.count(), 0)
	assert_true(is_instance_valid(study))
	study.free()


func test_close_button_closes_the_study() -> void:
	var study := _open(_sample_entries(1))
	study.close_button().pressed.emit()
	assert_eq(_harness.stack.count(), 0)
	assert_true(is_instance_valid(study))
	study.free()


func test_page_keys_hint_hidden_with_one_page_shown_with_two() -> void:
	var one := _open(_sample_entries(1))
	assert_false(one.hint().text.contains("[ ]: page"))
	assert_true(one.hint().text.contains("I: close"))
	assert_true(one.hint().text.contains("Enter: look there"))
	_harness.stack.clear()
	var two := _open(_sample_entries(2))
	assert_true(two.hint().text.contains("[ ]: page"))
	assert_true(two.hint_text().contains("[ ]: page"))


func test_page_look_request_is_forwarded_as_look_at() -> void:
	var study := _open(_sample_entries(1))
	study.current_page().request([&"look_at", GENOA_HEX])
	assert_eq(_requests.size(), 1)
	assert_eq(_requests[0][0], &"look_at")
	assert_eq((_requests[0][1] as Dictionary)["hex"], GENOA_HEX)
	assert_eq((_requests[0][1] as Dictionary)["select"], true)


func test_country_and_map_mode_actions_are_forwarded() -> void:
	var study := _open(_sample_entries(1))
	study.current_page().request([&"country", &"GEN"])
	assert_eq(_requests[0][0], &"country")
	assert_eq((_requests[0][1] as Dictionary)["tag"], &"GEN")
	study.current_page().request([&"map_mode", &"trade", GENOA_HEX])
	assert_eq(_requests[1][0], &"look_at")
	assert_eq(_requests[1][1], {"hex": GENOA_HEX, "select": false, "mode": &"trade"})
	study.current_page().request([&"map_mode", &"yields"])
	assert_eq(_requests[2][0], &"look_at")
	assert_eq(_requests[2][1], {"mode": &"yields"})


func test_frame_fits_1280_by_720_and_2560_by_1440() -> void:
	for view: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1440)]:
		_harness.viewport.size = view
		var study := _open(_sample_entries(2))
		await _harness.wait_frames(self, 2)
		var frame := study.get_node("Frame") as Control
		assert_eq(frame.size, Vector2(view) - FRAME_INSET)
		assert_true(frame.get_combined_minimum_size().x <= frame.size.x)
		assert_true(frame.get_combined_minimum_size().y <= frame.size.y)
		_harness.stack.clear()
		await _harness.wait_frames(self, 1)


func test_accessibility_names() -> void:
	var study := _open(_sample_entries(2))
	assert_eq(study.close_button().accessibility_name, "Close")
	assert_eq(study.nav().button_for(&"sample").accessibility_name, "Sample 1")
	assert_false(study.hint().accessibility_name.is_empty())


func test_study_pages_shown_is_empty_before_economy() -> void:
	assert_true(StudyPages.shown("3").is_empty())
	assert_true(StudyPages.shown("not a number").is_empty())


func test_shown_tabs_follow_the_milestone() -> void:
	var at_four := _open_at(_sample_entries(1), "4")
	assert_eq(_ids(at_four.current_page().shown_tabs()), [&"alpha"])
	_harness.stack.clear()
	var at_45 := _open_at(_sample_entries(1), "4.5")
	assert_eq(_ids(at_45.current_page().shown_tabs()), [&"alpha", &"beta"])


func test_tab_strip_shows_only_from_two_shown_tabs() -> void:
	var at_four := _open_at(_sample_entries(1), "4")
	var strip := at_four.current_page().get_node("TabStrip") as Control
	assert_false(strip.visible)
	_assert_beta_not_selected(at_four)
	_harness.stack.clear()
	var at_45 := _open_at(_sample_entries(1), "4.5")
	assert_true((at_45.current_page().get_node("TabStrip") as Control).visible)


func _assert_beta_not_selected(study: Study) -> void:
	var page := study.current_page()
	page.select_tab(&"beta")
	assert_eq(page.current_tab(), &"alpha", "a tab that is not shown yet is not selected")


func test_open_page_focus_selects_the_tab_and_times_the_open() -> void:
	var study := _open_at(_sample_entries(2), "4.5")
	study.open_page(&"sample")
	var seen: Array[StringName] = []
	study.current_page().tab_changed.connect(func(tab: StringName) -> void: seen.append(tab))
	study.open_page(&"sample", {"tab": "beta"})
	assert_eq(seen, [&"beta"])
	assert_eq(study.current_page().current_tab(), &"beta")
	assert_true(study.last_open_ms >= 0.0)
	assert_true(study.hint().text.contains("Ctrl+[ ]: tab"))


func test_focus_with_an_unknown_tab_changes_nothing() -> void:
	var study := _open_at(_sample_entries(1), "4.5")
	study.open_page(&"sample", {"tab": "nope"})
	assert_eq(study.current_page().current_tab(), &"alpha")


func test_step_tab_stops_at_the_first_and_last_tab() -> void:
	var study := _open_at(_sample_entries(1), "4.5")
	var page := study.current_page()
	assert_eq(page.current_tab(), &"alpha")
	page.step_tab(-1)
	assert_eq(page.current_tab(), &"alpha")
	page.step_tab(1)
	assert_eq(page.current_tab(), &"beta")
	page.step_tab(1)
	assert_eq(page.current_tab(), &"beta")


func test_the_tab_in_view_is_kept_for_the_life_of_the_page() -> void:
	var study := _open_at(_sample_entries(2), "4.5")
	study.open_page(&"sample")
	study.current_page().select_tab(&"beta")
	study.open_page(&"sample2")
	study.open_page(&"sample")
	assert_eq(study.current_page().current_tab(), &"beta")


func test_selected_tab_shows_its_body_and_hides_the_other() -> void:
	var study := _open_at(_sample_entries(1), "4.5")
	var page := study.current_page()
	page.select_tab(&"beta")
	await _harness.wait_frames(self, 40)
	assert_true((page.get_node("beta") as Control).visible)
	assert_false((page.get_node("alpha") as Control).visible)


func test_ctrl_brackets_step_the_tabs_and_plain_brackets_step_the_pages() -> void:
	var study := _open_at(_sample_entries(2), "4.5")
	study.open_page(&"sample")
	_harness.send_key(KEY_BRACKETRIGHT, true, true)
	assert_eq(study.current_page().current_tab(), &"beta")
	_harness.send_key(KEY_BRACKETLEFT, true, true)
	assert_eq(study.current_page().current_tab(), &"alpha")
	assert_eq(study.current_page_id(), &"sample")
	_harness.send_key(KEY_BRACKETRIGHT)
	assert_eq(study.current_page_id(), &"sample2")


func test_hint_shows_tab_keys_only_on_a_page_with_two_shown_tabs() -> void:
	var plain: Array[Dictionary] = [{"id": &"plain", "title": "Plain", "scene": COUNTING, "since": "4"}]
	var study := _open_at(plain, "4.5")
	assert_false(study.hint().text.contains("Ctrl+[ ]"))
	_harness.stack.clear()
	var tabbed := _open_at(_sample_entries(1), "4.5")
	assert_true(tabbed.hint().text.contains("Ctrl+[ ]: tab"))
	assert_true(tabbed.hint().text.contains("I: close"))
	assert_true(tabbed.hint().text.contains("Enter: look there"))


func _three_tab_page() -> StudyPage:
	var page := StudyPage.new()
	var entries: Array[Dictionary] = [
		{"id": &"a", "title": "A", "since": "4"},
		{"id": &"b", "title": "B", "since": "4"},
		{"id": &"c", "title": "C", "since": "4"},
	]
	page.tabs = entries
	add_child_autofree(page)
	return page


## The tab in view is shown whole, and the others are not shown.
func _settled(page: StudyPage, tab: StringName) -> void:
	assert_eq(page.current_tab(), tab)
	var body := page.get_node(String(tab)) as Control
	assert_true(body.visible, "%s in view is visible" % String(tab))
	assert_eq(body.modulate.a, 1.0, "%s in view is opaque" % String(tab))
	for other: Node in page.get_children():
		if other.name != String(tab) and other is Control and other.name != "TabStrip" and other.name != "Heading":
			assert_false((other as Control).visible, "%s is not in view" % other.name)


func test_rapid_a_b_a_in_one_frame_leaves_a_visible() -> void:
	var study := _open_at(_sample_entries(1), "4.5")
	var page := study.current_page()
	page.select_tab(&"beta")
	page.select_tab(&"alpha")
	await _harness.wait_frames(self, 40)
	_settled(page, &"alpha")


func test_rapid_a_b_a_across_a_tenth_of_a_second_leaves_a_visible() -> void:
	var study := _open_at(_sample_entries(1), "4.5")
	var page := study.current_page()
	page.select_tab(&"beta")
	await get_tree().create_timer(0.1).timeout
	page.select_tab(&"alpha")
	await _harness.wait_frames(self, 40)
	_settled(page, &"alpha")


func test_a_b_c_a_in_one_frame_leaves_a_visible() -> void:
	var page := _three_tab_page()
	page.select_tab(&"b")
	page.select_tab(&"c")
	page.select_tab(&"a")
	await _harness.wait_frames(self, 40)
	_settled(page, &"a")


func test_a_b_c_a_across_a_tenth_of_a_second_leaves_a_visible() -> void:
	var page := _three_tab_page()
	page.select_tab(&"b")
	await get_tree().create_timer(0.1).timeout
	page.select_tab(&"c")
	await get_tree().create_timer(0.1).timeout
	page.select_tab(&"a")
	await _harness.wait_frames(self, 40)
	_settled(page, &"a")


func test_step_tab_back_and_forth_in_one_frame_leaves_the_tab_visible() -> void:
	var study := _open_at(_sample_entries(1), "4.5")
	var page := study.current_page()
	page.step_tab(1)
	page.step_tab(-1)
	page.step_tab(1)
	await _harness.wait_frames(self, 40)
	_settled(page, &"beta")


func test_reduce_motion_rapid_switches_end_on_the_tab_in_view() -> void:
	var study := _open_at(_sample_entries(1), "4.5")
	var page := study.current_page()
	page.reduce_motion = true
	page.select_tab(&"beta")
	page.select_tab(&"alpha")
	page.select_tab(&"beta")
	_settled(page, &"beta")
	await _harness.wait_frames(self, 10)
	_settled(page, &"beta")


func test_study_closed_mid_fade_reopens_on_a_settled_tab() -> void:
	var study := _open_at(_sample_entries(1), "4.5")
	var page := study.current_page()
	page.select_tab(&"beta")
	_harness.stack.remove(study)
	_harness.stack.push(study)
	await _harness.wait_frames(self, 40)
	_settled(study.current_page(), &"beta")


func test_study_closed_mid_fade_and_a_new_switch_leaves_a_visible() -> void:
	var study := _open_at(_sample_entries(1), "4.5")
	study.current_page().select_tab(&"beta")
	_harness.stack.remove(study)
	_harness.stack.push(study)
	study.current_page().select_tab(&"alpha")
	await _harness.wait_frames(self, 40)
	_settled(study.current_page(), &"alpha")
