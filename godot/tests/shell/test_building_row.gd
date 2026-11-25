## The compact row of the Buildings tab (tile-window spec R19, R34; build plan TW11): each state's look (built check, building
## bar, short and locked words, the hammer enabled iff the verdict is ok), the gain as one signed number, and the hover signal.
extends GutTest


func _data(state: String, extra: Dictionary = {}) -> Dictionary:
	var data := {
		"id": "clear:1", "group": "land", "name": "Vineyard, first stage", "icon": "vineyard", "state": state,
		"state_text": "cost 120", "tone": "plain", "progress": 0.0, "gain": null, "upkeep": null,
		"option": {"action": "build", "family": 1}, "hammer": true, "reason": "", "expensive": false, "gate": {},
	}
	data.merge(extra, true)
	return data


func _row(data: Dictionary) -> BuildingRow:
	var row := BuildingRow.new()
	row.setup(data)
	add_child_autofree(row)
	return row


func test_a_ready_row_has_an_enabled_hammer_and_no_check_or_bar() -> void:
	var row := _row(_data("ready"))
	assert_false(row.hammer().disabled, "the hammer is enabled when the verdict is ok")
	assert_true(row.hammer().visible)
	assert_false(row.shows_check())
	assert_false(row.shows_bar())
	assert_eq(row.name_text(), "Vineyard, first stage")


func test_a_built_row_has_a_check_and_no_hammer() -> void:
	var row := _row(_data("built", {"state_text": "working", "tone": "good", "option": {}, "hammer": false}))
	assert_true(row.shows_check(), "a built row shows the check")
	assert_false(row.hammer().visible, "a built row has no hammer")
	assert_eq(row.state_text(), "working")


func test_a_building_row_shows_its_progress_and_a_disabled_hammer() -> void:
	var row := _row(_data("building", {"state_text": "building · 2 of 4 seasons", "progress": 0.5, "option": {},
			"hammer": false}))
	assert_true(row.shows_bar())
	assert_almost_eq(row.bar_value(), 50.0, 0.001, "the bar is the progress in percent")
	assert_true(row.hammer().disabled)


func test_a_short_row_shows_its_shortfall_in_the_bad_tone() -> void:
	var row := _row(_data("short", {"state_text": "cost 300 · you have 204", "tone": "bad", "hammer": false,
			"reason": "not enough ducats"}))
	assert_eq(row.state_text(), "cost 300 · you have 204")
	assert_true(row.hammer().disabled, "a short row cannot be hammered")
	assert_eq(row.hammer().tooltip_text, "not enough ducats")


func test_a_locked_row_shows_a_lock_and_no_enabled_hammer() -> void:
	var row := _row(_data("locked", {"state_text": "opens in 1495", "tone": "muted", "hammer": false}))
	assert_true(row.shows_lock())
	assert_true(row.hammer().disabled)


func test_a_busy_row_says_a_work_is_under_way_on_its_hammer() -> void:
	var row := _row(_data("refused", {"tone": "bad", "hammer": false, "reason": "one job at a time: vineyard is under way"}))
	assert_true(row.hammer().disabled)
	assert_eq(row.hammer().tooltip_text, BuildingRow.BUSY_TIP)


func test_numbers_show_the_gain_as_one_signed_number_and_the_upkeep_on_the_state_line() -> void:
	var row := _row(_data("ready"))
	row.set_numbers(38, 8)
	assert_eq(row.gain_text(), "+38")
	assert_eq(row.state_text(), "cost 120 · upkeep 8")
	row.set_numbers(-6, null)
	assert_eq(row.gain_text(), Words.MINUS + "6", "a loss shows the true minus sign")
	assert_eq(row.state_text(), "cost 120 · upkeep 8", "a null upkeep leaves the line alone")


func test_a_built_row_gets_its_upkeep_after_its_numbers() -> void:
	var row := _row(_data("built", {"state_text": "working", "tone": "good", "option": {}, "hammer": false}))
	row.set_numbers(12, 3)
	assert_eq(row.state_text(), "working · upkeep 3")
	assert_eq(row.gain_text(), "+12")


func test_pressing_an_enabled_hammer_emits_its_data_and_a_disabled_one_does_not() -> void:
	var seen: Array = []
	var row := _row(_data("ready"))
	row.hammer_pressed.connect(func(data: Dictionary) -> void: seen.append(data))
	row.press_hammer()
	assert_eq(seen.size(), 1, "an enabled hammer emits once")
	assert_eq(seen[0]["option"], {"action": "build", "family": 1})
	var refused := _row(_data("refused", {"hammer": false}))
	refused.hammer_pressed.connect(func(data: Dictionary) -> void: seen.append(data))
	refused.press_hammer()
	assert_eq(seen.size(), 1, "a disabled hammer emits nothing")


func test_the_row_emits_hovered_and_unhovered() -> void:
	var row := _row(_data("ready"))
	var log: Array = []
	row.hovered.connect(func(_data_in: Dictionary) -> void: log.append("in"))
	row.unhovered.connect(func() -> void: log.append("out"))
	var entered: Signal = row.mouse_entered
	var left: Signal = row.mouse_exited
	entered.emit()
	left.emit()
	assert_eq(log, ["in", "out"])
