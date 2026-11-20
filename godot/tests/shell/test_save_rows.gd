## GUT tests for SaveRows, the pure rows of the Save and Load screen (docs/architecture/m3-build-spec.md sections 4.10,
## 6.10 and 9): a row for every state, the tabs, the words, the clock and play-time text, and the default name.
extends GutTest

const NOW := 1700000000


func _header(overrides: Dictionary = {}) -> Dictionary:
	var header := {
		"hexa": "save", "format": 1, "build": "0.3.0", "slot": "1", "name": "",
		"map_id": "north_italy", "map_digest": "d", "scenario_id": "north_italy_1480", "scenario_digest": "s",
		"tag": "GEN", "country": "Republic of Genoa", "turn": 9, "date": "Spring 1482",
		"saved_unix": 1700000000, "play_seconds": 125, "digest": "g",
	}
	for key: String in overrides:
		header[key] = overrides[key]
	return header


func _row(slot: String, state: StringName, header: Dictionary = {}, thumb: String = "") -> Dictionary:
	return {"slot": slot, "state": state, "header": header, "thumbnail": thumb}


func _every_state() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append(_row("auto1", &"ok", _header({"slot": "auto1", "country": "Republic of Genoa", "saved_unix": 100})))
	list.append(_row("auto2", &"empty"))
	list.append(_row("auto3", &"ok", _header({"slot": "auto3", "saved_unix": 300})))
	list.append(_row("quick", &"ok", _header({"slot": "quick", "name": "Before the war"}), "/x/quick.png"))
	list.append(_row("1", &"ok", _header({"slot": "1", "country": ""})))
	list.append(_row("2", &"newer", _header({"slot": "2", "format": 9})))
	list.append(_row("3", &"older", _header({"slot": "3", "format": 0})))
	list.append(_row("4", &"other_map", _header({"slot": "4", "map_id": "elsewhere"})))
	list.append(_row("5", &"other_build", _header({"slot": "5"})))
	list.append(_row("6", &"broken"))
	list.append(_row("7", &"empty"))
	list.append(_row("8", &"empty"))
	return list


func _by_slot(rows: Array[Dictionary], slot: String) -> Dictionary:
	for row: Dictionary in rows:
		if str(row["slot"]) == slot:
			return row
	return {}


func test_load_tab_lists_autosaves_quick_then_slots_in_order() -> void:
	var rows := SaveRows.of(_every_state(), SaveRows.LOAD_TAB, NOW)
	var slots: Array[String] = []
	for row: Dictionary in rows:
		slots.append(str(row["slot"]))
	assert_eq(slots, ["auto3", "auto1", "auto2", "quick", "1", "2", "3", "4", "5", "6", "7", "8"],
		"autosaves newest first, the empty one last, then the fixed order")


func test_autosaves_sort_newest_first_with_ties_in_list_order_and_empties_last() -> void:
	var list: Array[Dictionary] = []
	list.append(_row("auto1", &"ok", _header({"slot": "auto1", "saved_unix": 100})))
	list.append(_row("auto2", &"ok", _header({"slot": "auto2", "saved_unix": 300})))
	list.append(_row("auto3", &"ok", _header({"slot": "auto3", "saved_unix": 300})))
	var slots: Array[String] = []
	for row: Dictionary in SaveRows.of(list, SaveRows.LOAD_TAB, NOW):
		slots.append(str(row["slot"]))
	assert_eq(slots.slice(0, 3), ["auto2", "auto3", "auto1"], "a tie keeps list order")
	list = []
	list.append(_row("auto1", &"empty"))
	list.append(_row("auto2", &"ok", _header({"slot": "auto2", "saved_unix": 100})))
	list.append(_row("auto3", &"ok", _header({"slot": "auto3", "saved_unix": 200})))
	slots = []
	for row: Dictionary in SaveRows.of(list, SaveRows.LOAD_TAB, NOW):
		slots.append(str(row["slot"]))
	assert_eq(slots.slice(0, 3), ["auto3", "auto2", "auto1"], "P: an empty autosave never sorts first")


func test_save_tab_lists_quicksave_and_eight_slots_only() -> void:
	var rows := SaveRows.of(_every_state(), SaveRows.SAVE_TAB, NOW)
	var slots: Array[String] = []
	for row: Dictionary in rows:
		slots.append(str(row["slot"]))
	assert_eq(slots, ["quick", "1", "2", "3", "4", "5", "6", "7", "8"], "no autosaves on the save tab")


func test_ok_row_title_summary_detail_and_name() -> void:
	var row := _by_slot(SaveRows.of(_every_state(), SaveRows.LOAD_TAB, NOW), "quick")
	assert_eq(row["label"], "Quicksave")
	assert_eq(row["name"], "Before the war", "the save's name shows above the title")
	assert_eq(row["title"], "Republic of Genoa · Spring 1482")
	assert_eq(row["summary"], "Republic of Genoa, Spring 1482", "the overwrite Confirm's line")
	assert_eq(row["state_text"], "")
	assert_true(bool(row["can_act"]))
	assert_true(bool(row["can_delete"]))
	assert_eq(row["thumbnail"], "/x/quick.png")
	var detail := str(row["detail"])
	assert_true(detail.begins_with("North Italy · saved "), "map name first: " + detail)
	assert_true(detail.ends_with(" · played 2 min · Hexa 0.3.0"), "play time and build last: " + detail)


func test_pre_pick_scenario_says_choose_your_country_with_the_date() -> void:
	var row := _by_slot(SaveRows.of(_every_state(), SaveRows.LOAD_TAB, NOW), "1")
	assert_eq(row["title"], "Choose your country · Spring 1482")
	assert_eq(row["summary"], "Choose your country, Spring 1482")


func test_autosave_title_and_empty_rows() -> void:
	var rows := SaveRows.of(_every_state(), SaveRows.LOAD_TAB, NOW)
	assert_eq(_by_slot(rows, "auto1")["title"], "Autosave · Spring 1482")
	assert_eq(_by_slot(rows, "auto2")["title"], "Empty slot")
	assert_false(bool(_by_slot(rows, "auto2")["can_act"]), "an empty load row cannot load")
	assert_false(bool(_by_slot(rows, "auto2")["can_delete"]))
	var save_row := _by_slot(SaveRows.of(_every_state(), SaveRows.SAVE_TAB, NOW), "7")
	assert_true(bool(save_row["can_act"]), "an empty slot takes a save")
	assert_eq(save_row["title"], "Empty slot")


func test_every_greyed_state_has_its_words_and_cannot_load() -> void:
	var rows := SaveRows.of(_every_state(), SaveRows.LOAD_TAB, NOW)
	assert_eq(_by_slot(rows, "2")["state_text"], "Made by a newer Hexa")
	assert_eq(_by_slot(rows, "3")["state_text"], "Made by an older test build")
	assert_eq(_by_slot(rows, "4")["state_text"], "Made for another map")
	assert_eq(_by_slot(rows, "5")["state_text"], "Made by another build")
	assert_eq(_by_slot(rows, "6")["state_text"], "Cannot be read")
	for slot: String in ["2", "3", "4", "5", "6"]:
		var row := _by_slot(rows, slot)
		assert_false(bool(row["can_act"]), slot + " cannot load")
		assert_true(bool(row["can_delete"]), slot + " can be deleted")
		assert_eq(row["title"], "Slot " + slot, "a greyed row names its slot")


func test_greyed_save_rows_may_be_saved_over_on_the_save_tab() -> void:
	var rows := SaveRows.of(_every_state(), SaveRows.SAVE_TAB, NOW)
	assert_true(bool(_by_slot(rows, "2")["can_act"]), "saving over a newer save asks first; the screen confirms")
	assert_eq(_by_slot(rows, "2")["state_text"], "Made by a newer Hexa")


func test_unknown_state_reads_as_unreadable() -> void:
	var rows := SaveRows.of([_row("1", &"mystery")], SaveRows.LOAD_TAB, NOW)
	assert_eq(_by_slot(rows, "1")["state_text"], "Cannot be read", "P: an unknown state is not loadable text")
	assert_false(bool(_by_slot(rows, "1")["can_act"]))


func test_label_and_play_and_date_text() -> void:
	assert_eq(SaveRows.label_of("quick"), "Quicksave")
	assert_eq(SaveRows.label_of("3"), "Slot 3")
	assert_eq(SaveRows.label_of("auto2"), "Autosave 2")
	assert_eq(SaveRows.play_text(125), "2 min", "under an hour: minutes only")
	assert_eq(SaveRows.play_text(2 * 3600 + 5 * 60), "2 h 05 min")
	assert_eq(SaveRows.play_text(-4), "0 min", "P: negative seconds read as none")
	assert_eq(SaveRows.date_text(0, 0), "1 Jan 1970, 00:00")
	assert_eq(SaveRows.date_text(0, 3600), "1 Jan 1970, 01:00", "P: a positive offset moves the clock forward")
	assert_eq(SaveRows.date_text(0, -3600), "31 Dec 1969, 23:00", "P: a negative offset moves it back")


func test_default_name_is_country_and_date_or_the_date_alone() -> void:
	assert_eq(SaveRows.default_name("Republic of Genoa", "Spring 1482"), "Republic of Genoa, Spring 1482")
	assert_eq(SaveRows.default_name("", "Spring 1480"), "Spring 1480", "before the country pick")
	assert_eq(SaveRows.default_name("Sandbox", "Winter 1480"), "Sandbox, Winter 1480")


func test_zone_offset_is_a_whole_number_of_minutes() -> void:
	var offset := SaveRows.zone_offset_seconds()
	assert_eq(offset % 60, 0, "a whole number of minutes")
	assert_true(absi(offset) <= 14 * 3600, "no zone is further than 14 hours from UTC")
