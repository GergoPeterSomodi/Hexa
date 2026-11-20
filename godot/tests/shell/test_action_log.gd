## ActionLog (docs/architecture/m3-build-spec.md 6.5 and section 9): collapsed and open; unread counts; filters; a line
## asks for its hex; the newest header asks for the report; Esc closes; the open state and filter kept in Settings.
extends GutTest

const ACTION_LOG_SCENE := "res://shell/hud/action_log.tscn"
const SAVONA := Vector2i(7, 12)
const WOODS := Vector2i(9, 11)

var _harness: UIHarness = null
var _root: Control = null
var _widget: ActionLog = null
var _prev_game: Game = null
var _prev_unsaved: int = 0


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the committed scenario starts")
	# The realistic order: the log is mounted in a scenario with no country yet, then the pick is made.
	_harness = UIHarness.new()
	_harness.mount(self)
	_root = VBoxContainer.new()
	_root.theme = KitTheme.load_for(1.0)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_harness.viewport.add_child(_root)
	_widget = (load(ACTION_LOG_SCENE) as PackedScene).instantiate() as ActionLog
	_root.add_child(_widget)
	assert_true(bool(Session.act("choose_country", {"tag": &"GEN"}).get("ok", false)), "Genoa is chosen")


func after_each() -> void:
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Bindings.reset_defaults()
	_widget = null
	_root = null
	_harness = null


func _game() -> Game:
	return Session.game


func _work(action: StringName, family: int, level_to: int, hex: Vector2i) -> Work:
	var w := Work.new()
	w.id = 1
	w.tag = &"GEN"
	w.hex = hex
	w.action = action
	w.family = family
	w.level_to = level_to
	w.started_turn = _game().turn
	w.seasons = 4
	w.seasons_left = 4
	return w


## Makes one work line the way the rules do (Game.emit appends it to the chronicle) and hands it to the bus as the
## session does after a drain.
func _log(kind: String = "work_started", hex: Vector2i = SAVONA) -> void:
	var w := _work(Works.BUILD, ImproveRules.VINEYARD, 1, hex)
	var event := {"kind": kind, "tag": w.tag, "hex": w.hex, "work": w.to_dict()}
	_game().emit(event)
	Events.chronicled.emit(_game().chronicle.entries[_game().chronicle.entries.size() - 1])


func _line_total(filter: StringName) -> int:
	var count := 0
	for season: Dictionary in LogLines.entries(_game(), &"GEN", filter):
		count += (season["lines"] as Array).size()
	return count


func test_starts_closed_as_a_bar() -> void:
	assert_false(_widget.is_open(), "closed at the start")
	assert_true(_widget._bar.visible, "the bar shows")
	assert_false(_widget._card.visible, "the card does not")
	assert_eq(_widget.season_titles().size(), 0, "a closed log lists no seasons")
	assert_eq(_widget.line_count(), 0, "a closed log has no line rows")


func test_a_new_line_counts_unread_while_closed() -> void:
	_widget.bind_settings(_harness.settings)
	var before := _widget.unread()
	_log()
	assert_eq(_widget.unread(), before + 1, "one new line is unread at once")
	await _harness.wait_frames(self, 2)
	assert_eq(_widget.badge_text(), "+%d new" % _widget.unread(), "the badge shows the count after the frame")
	assert_true(_widget.bar_text().begins_with("Begun"), "the bar shows the newest line")


func test_opening_marks_read_and_lists_the_seasons() -> void:
	_log()
	_log("work_finished")
	assert_gt(_widget.unread(), 0, "lines are unread before opening")
	_widget.open()
	assert_true(_widget.is_open(), "open")
	assert_eq(_widget.unread(), 0, "opening reads them all")
	assert_eq(_widget.badge_text(), "", "the badge is gone")
	assert_eq(_widget.season_titles(), ["Spring 1480"], "one season, the first spring")
	assert_eq(_widget.line_count(), _line_total(&"all"), "every line of the filter is a row")


func test_toggle_and_escape() -> void:
	_widget.toggle()
	assert_true(_widget.is_open(), "toggle opens")
	assert_true(_widget.escape(), "Esc closes an open log")
	assert_false(_widget.is_open(), "closed")
	assert_false(_widget.escape(), "Esc on a closed log is left to the ladder")
	_widget.toggle()
	_widget.toggle()
	assert_false(_widget.is_open(), "toggle twice closes")


func test_the_toggle_button_opens() -> void:
	_widget._toggle.pressed.emit()
	assert_true(_widget.is_open(), "the Log button opens the card")
	_widget._close.pressed.emit()
	assert_false(_widget.is_open(), "the Close button closes it")


func test_the_filters_show_only_their_lines() -> void:
	_log()
	_widget.open()
	_widget.set_filter(&"works")
	assert_eq(_widget.filter(), &"works", "the works filter is set")
	assert_eq(_widget.line_count(), _line_total(&"works"), "the works rows")
	_widget.set_filter(&"mine")
	assert_eq(_widget.line_count(), _line_total(&"mine"), "the mine rows")
	_widget.set_filter(&"war")
	assert_eq(_widget.filter(), &"mine", "a filter after the milestone is ignored")


func test_the_newest_header_asks_for_the_report() -> void:
	_log()
	_widget.open()
	var head := _widget.report_button()
	assert_not_null(head, "the newest season header is a button")
	watch_signals(_widget)
	head.pressed.emit()
	assert_signal_emitted(_widget, "report_requested", "the header asks for the report")


func test_an_older_header_is_text_not_a_button() -> void:
	_log()
	_game().turn = Calendar.FIRST_TURN + 4
	_log("work_finished")
	_widget.open()
	assert_eq(_widget.season_titles().size(), 2, "two seasons")
	var buttons := 0
	for child: Node in _widget._seasons.get_children():
		if child is Button:
			buttons += 1
	assert_eq(buttons, 1, "only the newest header is a button")


func test_a_line_with_a_hex_asks_to_glide_there() -> void:
	_log("work_started", SAVONA)
	_widget.open()
	await _harness.wait_frames(self, 2)
	watch_signals(_widget)
	var target: Control = null
	for child: Node in _widget._seasons.get_children():
		var row := child as HBoxContainer
		if row == null:
			continue
		var sentence := row.get_child(1) as Label
		if sentence.tooltip_text == ActionLog.ACTIVATE_TIP:
			target = sentence
	assert_not_null(target, "a line with a hex has a clickable sentence")
	_widget._on_line_input(_press(), SAVONA)
	assert_signal_emitted_with_parameters(_widget, "line_activated", [SAVONA], 0)


func test_a_clickable_line_passes_the_wheel_to_the_card() -> void:
	_widget.open()
	var clickable := 0
	for child: Node in _widget._seasons.get_children():
		var row := child as HBoxContainer
		if row == null:
			continue
		var sentence := row.get_child(1) as Label
		if sentence.tooltip_text == ActionLog.ACTIVATE_TIP:
			clickable += 1
			assert_eq(sentence.mouse_filter, Control.MOUSE_FILTER_PASS, "the wheel still reaches the scroll")
	assert_gt(clickable, 0, "the rule line of the pick has a hex and is clickable")


func test_the_bar_shows_a_placeholder_when_there_is_no_game() -> void:
	_widget.bind_settings(_harness.settings)
	Session.game = null
	_widget._on_game_ended()
	assert_eq(_widget.bar_text(), ActionLog.EMPTY_TEXT, "no game, no line")
	assert_eq(_widget.badge_text(), "", "no badge")
	assert_eq(_widget.unread(), 0, "nothing unread")


func test_the_open_state_and_filter_are_kept_in_settings() -> void:
	var s := Settings.new("macOS", true)
	_widget.bind_settings(s)
	assert_eq(_widget.filter(), &"all", "the default filter")
	_widget.set_filter(&"works")
	assert_eq(str(s.get_value("state/log_filter")), "works", "the filter is saved")
	_widget.open()
	assert_true(bool(s.get_value("state/log_open")), "the open state is saved")
	_widget.close()
	assert_false(bool(s.get_value("state/log_open")), "and the close")


func test_the_mine_filter_follows_the_pick_when_mounted_first() -> void:
	# before_each mounts the log before the pick: the viewer must change to Genoa when it is chosen.
	assert_eq(_widget.feed.viewer(), &"GEN", "the feed follows the country chosen after mounting")
	_widget.set_filter(&"mine")
	_widget.open()
	assert_gt(_line_total(&"mine"), 0, "Genoa's own lines exist")
	assert_eq(_widget.line_count(), _line_total(&"mine"), "the mine filter shows them")


func test_a_burst_of_events_causes_one_rebuild() -> void:
	_widget.close()
	var unread_before := _widget.unread()
	var refreshes := _widget.refresh_count()
	for i: int in 50:
		_log()
	assert_eq(_widget.unread(), unread_before + 50, "unread is exact at once")
	assert_eq(_widget.refresh_count(), refreshes, "no rebuild runs inside the burst")
	await _harness.wait_frames(self, 2)
	assert_eq(_widget.refresh_count(), refreshes + 1, "one refresh after the burst")

	_widget.open()
	var opened := _widget.refresh_count()
	for i: int in 50:
		_log("work_finished")
	assert_eq(_widget.unread(), 0, "an open card reads each line as it arrives")
	await _harness.wait_frames(self, 2)
	assert_eq(_widget.refresh_count(), opened + 1, "the open card rebuilds once for the burst")
	assert_eq(_widget.line_count(), _line_total(&"all"), "and its rows are the log's lines")


func test_the_open_card_is_at_most_340_wide_and_the_bar_stays_400() -> void:
	# The UIHarness viewport is 1280 x 720, the size the picture check uses.
	assert_eq(_harness.viewport.size, Vector2i(1280, 720), "the test viewport is 1280 x 720")
	_log()
	_widget.open()
	await _harness.wait_frames(self, 3)
	assert_eq(_widget._card.custom_minimum_size.x, 340.0, "the card asks for 340 px")
	assert_lte(_widget._card.size.x, 340.5, "the open card is at most 340 px wide")
	assert_gt(_widget._card.size.x, 300.0, "and it fills that width, not a sliver")
	var sentence := _first_sentence()
	assert_not_null(sentence, "a line is on the card")
	assert_eq(sentence.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "the line text wraps inside the card")
	_widget.close()
	await _harness.wait_frames(self, 3)
	assert_eq(_widget._bar.custom_minimum_size.x, 400.0, "the closed bar keeps its 400 px")
	assert_gte(_widget._bar.size.x, 400.0 - 0.5, "and is never drawn narrower than 400 px")


func test_the_open_card_ends_above_the_key_hints_at_1280_720() -> void:
	# The card starts at y 368 at 1280 x 720; its bottom must stay above the hints row (720 - 44).
	_widget.open()
	var top := 368.0
	assert_lte(top + float(ActionLog.CARD_H), 720.0 - float(ActionLog.HINTS_CLEARANCE), "the default card clears the hints")
	_widget.fit_height(100.0)
	assert_eq(_widget._card.custom_minimum_size.y, 100.0, "fit_height caps the card")
	await _harness.wait_frames(self, 3)
	assert_lte(_widget._card.size.y, 100.5, "the card is no taller than the space given")
	_widget.fit_height(9999.0)
	assert_eq(_widget._card.custom_minimum_size.y, float(ActionLog.CARD_H), "never taller than 268")
	_widget.fit_height(-5.0)
	assert_eq(_widget._card.custom_minimum_size.y, 0.0, "a negative space gives no height")


func _first_sentence() -> Label:
	for child: Node in _widget._seasons.get_children():
		var row := child as HBoxContainer
		if row != null and row.get_child_count() == 2:
			return row.get_child(1) as Label
	return null


func _press() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev
