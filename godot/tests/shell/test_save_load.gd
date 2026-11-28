## GUT tests for the Save and Load screen (docs/architecture/m3-build-spec.md sections 6.10 and 9): rows for every state,
## the Save and Load tabs, the three Confirms, Up, Down, Enter, Del and Esc, the name field, and the refresh on `saved`.
## Session points at a temporary folder for every test; the real user://saves is never touched.
extends GutTest

const SCENARIO := "north_italy_1480"
const TEMP_DIR := "user://test_saves_save_load"

var _harness: UIHarness = null
var _prev_game: Game = null
var _prev_unsaved: int = 0
var _prev_dir: String = ""
var _requests: Array[Dictionary] = []
var _toasts: Array[Dictionary] = []


func before_each() -> void:
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	_prev_dir = Session.save_dir
	Session.save_dir = TEMP_DIR
	Session.game = null
	Session.unsaved_actions = 0
	_wipe()
	_requests = []
	_toasts = []
	_harness = UIHarness.new()
	_harness.settings.set_value("accessibility/reduce_motion", true)
	_harness.mount(self)
	_harness.stack.theme = KitTheme.load_for(1.0)
	_harness.ctx.app_requested.connect(_on_request)
	_harness.ctx.toast_requested.connect(_on_toast)


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	_harness = null
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Session.save_dir = _prev_dir
	_wipe()
	DirAccess.remove_absolute(TEMP_DIR)


func _on_request(what: StringName, args: Dictionary) -> void:
	_requests.append({"what": what, "args": args})


func _on_toast(text: String, tone: StringName) -> void:
	_toasts.append({"text": text, "tone": tone})


func _wipe() -> void:
	if not DirAccess.dir_exists_absolute(TEMP_DIR):
		return
	for file: String in DirAccess.get_files_at(TEMP_DIR):
		DirAccess.remove_absolute(TEMP_DIR.path_join(file))


func _thumb() -> Image:
	return Image.create_empty(192, 108, false, Image.FORMAT_RGBA8)


func _open(tab: StringName = &"") -> SaveLoad:
	var screen := SaveLoad.make(tab)
	assert_not_null(screen, "save_load is registered")
	_harness.stack.push(screen)
	await _harness.wait_frames(self, 2)
	return screen


func _start_scenario_game() -> void:
	assert_eq(Session.new_scenario(SCENARIO, 5), "", "the scenario starts before the country pick")


func _save(slot: String, name: String = "") -> void:
	assert_eq(Session.save_game(slot, _thumb(), {}, name), "", "saved slot " + slot)


## Changes one value of a save's header line (JSON text, as the session tests do).
func _rewrite_header(slot: String, key: String, value: Variant) -> void:
	var path := Session.save_dir.path_join(slot + ".sav")
	var f := FileAccess.open(path, FileAccess.READ)
	var bytes := f.get_buffer(f.get_length())
	f.close()
	var end := bytes.find(10)
	var line := bytes.slice(0, end).get_string_from_utf8()
	var json := JSON.new()
	json.parse(line)
	var old: Variant = (json.data as Dictionary)[key]
	var shown := str(int(old)) if old is float else JSON.stringify(old)
	var from := "\"%s\":%s" % [key, shown]
	assert_true(line.contains(from), "the header has " + from)
	var out := (line.replace(from, "\"%s\":%s" % [key, JSON.stringify(value)]) + "\n").to_utf8_buffer()
	out.append_array(bytes.slice(end + 1))
	var w := FileAccess.open(path, FileAccess.WRITE)
	w.store_buffer(out)
	w.close()


func _write_garbage(slot: String) -> void:
	var f := FileAccess.open(Session.save_dir.path_join(slot + ".sav"), FileAccess.WRITE)
	f.store_string("this is not a save")
	f.close()


## Saves every state into slots and an autosave: 1 ok (pre-pick), quick ok named, 2 newer, 3 older, 4 other map,
## 5 other build, 6 broken; autosave 1 ok; 7 and 8 stay empty.
func _seed_every_state() -> void:
	_start_scenario_game()
	Session.autosave_game(null, {})
	_save("quick", "Before the war")
	_save("1")
	_save("2")
	_rewrite_header("2", "format", SaveFile.FORMAT + 1)
	_save("3")
	_rewrite_header("3", "format", 0)
	_save("4")
	_rewrite_header("4", "map_id", "elsewhere")
	_save("5")
	_rewrite_header("5", "scenario_id", "nope")
	_save("6")
	_write_garbage("6")


func _top() -> Node:
	return _harness.stack.top()


func _press_confirm(confirm: Confirm) -> void:
	confirm.button_for(&"confirm").pressed.emit()


func _press_cancel(confirm: Confirm) -> void:
	confirm.button_for(&"cancel").pressed.emit()


func test_save_dir_is_the_temporary_folder_never_the_real_saves() -> void:
	assert_eq(Session.save_dir, TEMP_DIR)
	assert_ne(Session.save_dir, SaveFile.DIR, "P: the real user://saves is never used by these tests")


func test_without_a_game_the_screen_opens_on_load_and_hides_the_tabs() -> void:
	var screen := await _open()
	assert_eq(screen.tab(), &"load")
	assert_false(screen.segmented().visible, "no Save tab without a game")
	assert_eq(screen.frame().ribbon_title, "Load game")
	assert_eq(screen.row_count(), 12, "three autosaves, quicksave and eight slots")
	assert_eq(screen.row_slots()[0], "auto1")
	assert_eq(screen.title_label("1").text, "Empty slot")
	assert_true(screen.action_button("1").disabled, "an empty row cannot load")


func test_save_tab_cannot_open_without_a_game() -> void:
	var screen := await _open(&"save")
	assert_eq(screen.tab(), &"load", "P: Save with no game falls back to Load")


func test_with_a_game_the_save_tab_lists_quicksave_and_slots_and_suggests_a_name() -> void:
	_start_scenario_game()
	var screen := await _open()
	assert_eq(screen.tab(), &"save")
	assert_true(screen.segmented().visible)
	assert_eq(screen.row_slots(), ["quick", "1", "2", "3", "4", "5", "6", "7", "8"])
	assert_eq(screen.name_text(), SaveRows.default_name("", Session.game.date_text()),
		"the default name is the date before the country pick")


func test_every_state_has_its_row_on_the_load_tab() -> void:
	_seed_every_state()
	var screen := await _open(&"load")
	assert_true(screen.title_label("quick").text.begins_with("Choose your country · "), "a pre-pick quicksave says so")
	assert_eq(screen.state_label("2").text, "Made by a newer Hexa")
	assert_eq(screen.state_label("3").text, "Made by an older test build")
	assert_eq(screen.state_label("4").text, "Made for another map")
	assert_eq(screen.state_label("5").text, "Made by another build")
	assert_eq(screen.state_label("6").text, "Cannot be read")
	assert_eq(screen.title_label("2").text, "Slot 2", "a greyed row names its slot")
	for slot: String in ["2", "3", "4", "5", "6"]:
		assert_true(screen.action_button(slot).disabled, slot + " is greyed")
		assert_true(screen.delete_button(slot).visible, slot + " can be deleted")
	assert_false(screen.action_button("quick").disabled, "a good save loads")
	assert_eq(screen.title_label("auto1").text.substr(0, 11), "Autosave · ")
	assert_true(screen.title_label("1").text.begins_with("Choose your country · "), "before the pick the row says so")


func test_the_newest_autosave_is_the_first_row_and_enter_loads_that_slot() -> void:
	_start_scenario_game()
	Session.autosave_game(null, {})
	Session.autosave_game(null, {})
	_rewrite_header("auto1", "saved_unix", 1000)
	var screen := await _open(&"load")
	assert_eq(screen.row_slots()[0], "auto2", "auto2 was saved last, so it is listed first")
	screen.set_index(0)
	_harness.send_key(KEY_ENTER)
	assert_eq(_requests.size(), 1)
	assert_eq(_requests[0]["args"]["slot"], "auto2", "the row's own slot is what loads")


func test_up_and_down_move_the_selection_and_stop_at_both_ends() -> void:
	_start_scenario_game()
	var screen := await _open()
	_harness.send_key(KEY_DOWN)
	_harness.send_key(KEY_DOWN)
	assert_eq(screen.index(), 2)
	for i: int in 5:
		_harness.send_key(KEY_UP)
	assert_eq(screen.index(), 0, "Up stops at the first row")
	for i: int in 20:
		_harness.send_key(KEY_DOWN)
	assert_eq(screen.index(), 8, "Down stops at the last row")


func test_enter_on_an_empty_save_row_saves_at_once_with_the_name() -> void:
	_start_scenario_game()
	var screen := await _open()
	screen.set_index(3)
	_harness.send_key(KEY_ENTER)
	assert_eq(_requests.size(), 1, "no Confirm for an empty slot")
	assert_eq(_requests[0]["what"], &"save")
	assert_eq(_requests[0]["args"]["slot"], "3")
	assert_eq(_requests[0]["args"]["name"], screen.name_text())
	assert_true(_top() == screen, "the screen is still up")


func test_saving_over_a_used_slot_asks_first_and_saves_on_confirm() -> void:
	_start_scenario_game()
	_save("1")
	var screen := await _open()
	screen.set_index(1)
	_harness.send_key(KEY_ENTER)
	assert_eq(_requests.size(), 0, "nothing is saved before the Confirm")
	var confirm := _top() as Confirm
	assert_not_null(confirm, "a Confirm is on top")
	assert_eq(confirm.sheet().title, "Save over Slot 1?")
	_press_confirm(confirm)
	assert_eq(_requests.size(), 1)
	assert_eq(_requests[0]["args"]["slot"], "1")


func test_cancelling_the_save_over_sends_nothing() -> void:
	_start_scenario_game()
	_save("1")
	var screen := await _open()
	screen.set_index(1)
	_harness.send_key(KEY_ENTER)
	_press_cancel(_top() as Confirm)
	assert_eq(_requests.size(), 0)
	assert_true(_top() == screen, "back on the screen")


func test_the_saved_signal_refreshes_the_rows_and_a_problem_toasts() -> void:
	_start_scenario_game()
	var screen := await _open()
	assert_eq(screen.title_label("4").text, "Empty slot")
	Session.save_game("4", _thumb(), {}, "Fresh")
	_harness.ctx.saved.emit("4", "")
	assert_ne(screen.title_label("4").text, "Empty slot", "the row shows the new save")
	_harness.ctx.saved.emit("5", "no space left on the disk")
	assert_eq(_toasts.size(), 1)
	assert_eq(_toasts[0]["text"], "no space left on the disk")
	assert_eq(_toasts[0]["tone"], &"bad")


func test_loading_over_unsaved_actions_asks_and_loads_on_confirm() -> void:
	_start_scenario_game()
	_save("1")
	Session.unsaved_actions = 2
	var screen := await _open(&"load")
	screen.set_index(screen.row_slots().find("1"))
	_harness.send_key(KEY_ENTER)
	assert_eq(_requests.size(), 0, "nothing is loaded before the Confirm")
	var confirm := _top() as Confirm
	assert_eq(confirm.sheet().title, "Load Slot 1?")
	assert_eq(confirm.sheet().lede, "", "the body carries the warning")
	_press_confirm(confirm)
	assert_eq(_requests.size(), 1)
	assert_eq(_requests[0]["what"], &"load")
	assert_eq(_requests[0]["args"]["slot"], "1")


func test_loading_with_no_unsaved_actions_loads_at_once() -> void:
	_start_scenario_game()
	_save("1")
	Session.unsaved_actions = 0
	var screen := await _open(&"load")
	screen.set_index(screen.row_slots().find("1"))
	_harness.send_key(KEY_ENTER)
	assert_eq(_requests.size(), 1, "no Confirm when nothing is unsaved")
	assert_eq(_requests[0]["what"], &"load")


func test_a_greyed_row_cannot_load_and_says_why() -> void:
	_seed_every_state()
	var screen := await _open(&"load")
	screen.set_index(screen.row_slots().find("2"))
	_harness.send_key(KEY_ENTER)
	assert_eq(_requests.size(), 0)
	assert_eq(_toasts.size(), 1)
	assert_eq(_toasts[0]["text"], "Made by a newer Hexa")


func test_delete_asks_and_removes_the_save_only_on_confirm() -> void:
	_start_scenario_game()
	_save("1")
	var screen := await _open()
	screen.set_index(1)
	_harness.send_key(KEY_DELETE)
	var confirm := _top() as Confirm
	assert_eq(confirm.sheet().title, "Delete Slot 1?")
	_press_cancel(confirm)
	assert_true(FileAccess.file_exists(TEMP_DIR.path_join("1.sav")), "cancel keeps the save")
	_harness.send_key(KEY_DELETE)
	_press_confirm(_top() as Confirm)
	assert_false(FileAccess.file_exists(TEMP_DIR.path_join("1.sav")), "confirm deletes it")
	assert_eq(screen.title_label("1").text, "Empty slot")


func test_delete_on_an_empty_row_does_nothing() -> void:
	_start_scenario_game()
	var screen := await _open()
	screen.set_index(screen.row_slots().find("7"))
	_harness.send_key(KEY_DELETE)
	assert_true(_top() == screen, "no Confirm for an empty row")


func test_the_name_field_keeps_the_keys_but_down() -> void:
	_start_scenario_game()
	_save("1")
	var screen := await _open()
	screen.name_edit().grab_focus()
	await _harness.wait_frames(self, 1)
	_harness.send_key(KEY_DELETE)
	_harness.send_key(KEY_ENTER)
	assert_true(_top() == screen, "no Confirm and no save while the name has focus")
	assert_eq(_requests.size(), 0)
	assert_true(FileAccess.file_exists(TEMP_DIR.path_join("1.sav")), "Del did not delete")
	_harness.send_key(KEY_DOWN)
	assert_eq(screen.index(), 1, "Down leaves the field for the rows")


func test_a_typed_name_is_the_name_of_the_save() -> void:
	_start_scenario_game()
	var screen := await _open()
	screen.set_name_text("  Before Florence  ")
	assert_eq(screen.name_text(), "Before Florence")
	screen.set_index(0)
	_harness.send_key(KEY_ENTER)
	assert_eq(_requests[0]["args"]["name"], "Before Florence")
	screen.set_name_text("   ")
	assert_eq(screen.name_text(), screen.default_name(), "a blank name takes the default")


func test_switching_tabs_changes_the_ribbon_and_the_rows() -> void:
	_start_scenario_game()
	var screen := await _open()
	assert_eq(screen.frame().ribbon_title, "Save game")
	screen.segmented().select(&"load", true)
	assert_eq(screen.tab(), &"load")
	assert_eq(screen.frame().ribbon_title, "Load game")
	assert_eq(screen.row_count(), 12)


func test_the_thumbnails_load_two_rows_a_frame() -> void:
	_start_scenario_game()
	_save("quick")
	_save("1")
	_save("2")
	var screen := await _open(&"load")
	screen.refresh()
	assert_eq(screen.pending_thumbnails(), 3)
	assert_eq(screen.step_thumbnails(), 2, "two rows this frame")
	assert_eq(screen.step_thumbnails(), 1)
	assert_eq(screen.step_thumbnails(), 0)
	assert_not_null(screen.thumb_rect("quick").texture)
	assert_true(screen.thumb_rect("quick").visible)


func test_escape_closes_the_screen() -> void:
	_start_scenario_game()
	await _open()
	assert_true(_harness.stack.back(), "Esc is taken by the stack")
	assert_eq(_harness.stack.count(), 0, "the screen is popped")


func test_the_make_helper_sets_the_opening_tab() -> void:
	var screen := SaveLoad.make(&"load")
	assert_eq(screen.start_tab, &"load")
	screen.free()
