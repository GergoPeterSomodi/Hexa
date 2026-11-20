## GUT tests for the Statesman's Study frame (docs/architecture/m4-build-spec.md 6.7). The pages are the test page
## tests/fixtures/study_page_sample.tscn, listed by configure(); StudyPages.LIST is empty in W11a.
extends GutTest

const SCENE := "res://shell/screens/study.tscn"
const SAMPLE := "res://tests/fixtures/study_page_sample.tscn"
const GENOA_HEX := Vector2i(7, 12)
const FRAME_INSET := Vector2(30.0, 30.0)

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
	assert_false(one.hint().text.contains("[ ]"))
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


func test_other_page_actions_are_not_forwarded() -> void:
	var study := _open(_sample_entries(1))
	study.current_page().request([&"map_mode", &"trade"])
	assert_eq(_requests.size(), 0)


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
