## GUT tests for the top bar date and End season (docs/architecture/m3-build-spec.md 6.2 and section 9):
## the year and quarter follow the turn; the End season verdict and its reason during the pick; a click emits; busy.
extends GutTest

const DATE_END_SCENE := "res://shell/hud/date_end.tscn"

var _harness: UIHarness = null
var _root: Control = null
var _widget: DateEnd = null
var _prev_game: Game = null
var _prev_unsaved: int = 0


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the committed scenario starts")
	_harness = UIHarness.new()
	_harness.mount(self)
	_root = VBoxContainer.new()
	_root.theme = KitTheme.load_for(1.0)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_harness.viewport.add_child(_root)
	_widget = (load(DATE_END_SCENE) as PackedScene).instantiate() as DateEnd
	_root.add_child(_widget)


func after_each() -> void:
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Bindings.reset_defaults()
	_widget = null
	_root = null
	_harness = null


func _choose_player() -> void:
	var verdict := Session.act("choose_country", {"tag": &"GEN"})
	assert_true(bool(verdict.get("ok", false)), "Genoa is chosen for the test")


func test_the_year_and_quarter_follow_the_turn() -> void:
	Session.game.turn = 1
	_widget.refresh()
	var medal := _widget.date_button()
	assert_eq(medal.text, "Spring 1480", "the first turn is Spring of the start year")
	assert_eq(_widget.season(), Calendar.SPRING, "the first turn is Spring")
	assert_eq(medal.tooltip_text, "Spring 1480. J: the last report", "tooltip names the season and the report key")

	Session.game.turn = 6
	_widget.refresh()
	assert_eq(medal.text, "Summer 1481", "turn 6 is Summer 1481")
	assert_eq(_widget.season(), Calendar.SUMMER, "turn 6 is Summer")
	assert_true(medal.tooltip_text.begins_with("Summer 1481"), "tooltip follows the turn")

	Session.game.turn = 8
	_widget.set_date(Calendar.year_of(8, Session.game.start_year), Calendar.season_of(8))
	assert_eq(_widget.season(), Calendar.WINTER, "turn 8 is Winter")


func test_the_pick_refuses_the_end_with_its_reason() -> void:
	assert_eq(Session.game.player, &"", "the pick is open")
	_widget.refresh()
	var end := _widget.end_button()
	assert_true(end.disabled, "End season is off during the pick")
	assert_eq(end.reason_text(), "choose your country first", "the verdict's reason")
	assert_eq(end.tooltip_text, "choose your country first", "the reason is the tooltip")
	assert_true(_widget.verdict_label().visible, "the reason line shows")
	assert_eq(_widget.verdict_text(), "choose your country first", "the reason line text")


func test_a_chosen_country_enables_the_end() -> void:
	_choose_player()
	_widget.refresh()
	var end := _widget.end_button()
	assert_false(end.disabled, "End season is on once a country is chosen")
	assert_eq(end.reason_text(), "", "no reason")
	assert_false(_widget.verdict_label().visible, "no reason line")
	assert_eq(_widget.verdict_text(), "", "no verdict text")


func test_no_game_shows_no_date_and_refuses_the_end() -> void:
	Session.game = null
	_widget.refresh()
	assert_eq(_widget.date_button().text, "", "no year")
	assert_eq(_widget.season(), -1, "no quarter")
	assert_eq(_widget.date_button().tooltip_text, "No game", "tooltip")
	assert_true(_widget.end_button().disabled, "no game, no end")


func test_a_click_on_the_date_asks_for_the_report() -> void:
	var asked := [0]
	_widget.report_requested.connect(func() -> void: asked[0] += 1)
	_widget.date_button().pressed.emit()
	assert_eq(asked[0], 1, "one report request")


func test_a_click_on_the_end_season_asks_to_end() -> void:
	_choose_player()
	_widget.refresh()
	var asked := [0]
	_widget.end_season_requested.connect(func() -> void: asked[0] += 1)
	_widget.end_button().pressed.emit()
	assert_eq(asked[0], 1, "one end request")


func test_the_end_button_has_the_plate_and_the_space_key_cap() -> void:
	var end := _widget.end_button()
	assert_eq(end.theme_type_variation, &"ButtonEndSeason", "the End turn plate variation")
	assert_eq(end.hotkey_action, &"game_end_season", "the end key")
	assert_true(end.show_key_cap, "a key cap shows")
	assert_eq(end.embedded_key_cap().action, &"game_end_season", "the cap reads the binding")


func test_busy_adds_an_ellipsis_to_the_date() -> void:
	var date := _widget.date_button()
	var plain := date.text
	_widget.set_busy(true)
	assert_true(_widget.is_busy(), "busy")
	assert_eq(date.text, plain + DateEnd.BUSY_TAIL, "the date shows an ellipsis")
	_widget.set_busy(false)
	assert_false(_widget.is_busy(), "idle")
	assert_eq(date.text, plain, "the ellipsis goes")


func test_a_reparented_widget_still_follows_the_bus() -> void:
	# A top-bar relayout removes the widget and adds it back: the bus links must survive.
	_root.remove_child(_widget)
	_root.add_child(_widget)
	Session.game.turn = 6
	Events.game_started.emit()
	assert_eq(_widget.date_button().text, "Summer 1481", "game_started after a reparent updates the date")
	assert_eq(_widget.season(), Calendar.SUMMER, "and the quarter")

	_choose_player()
	Events.country_chosen.emit(&"GEN")
	assert_false(_widget.end_button().disabled, "country_chosen after a reparent enables End season")
	assert_false(_widget.verdict_label().visible, "and clears the reason line")

	Session.game.turn = 8
	Events.season_ended.emit(7)
	assert_eq(_widget.season(), Calendar.WINTER, "season_ended after a reparent updates the quarter")


func test_game_ended_shows_no_game_and_refuses_the_end() -> void:
	_choose_player()
	_widget.refresh()
	assert_false(_widget.end_button().disabled, "precondition: End season is on")
	Events.game_ended.emit()
	assert_eq(_widget.date_button().text, "", "game_ended clears the year")
	assert_eq(_widget.season(), -1, "and the quarter")
	assert_true(_widget.end_button().disabled, "game_ended turns End season off")
	assert_eq(_widget.end_button().tooltip_text, "no game", "with the no-game reason")
	assert_false(_widget.verdict_label().visible, "no reason line for a game that has ended")


func test_bus_links_are_dropped_when_the_widget_leaves_the_tree() -> void:
	_root.remove_child(_widget)
	assert_false(Events.game_started.is_connected(_widget._on_game_started), "no game_started link out of the tree")
	assert_false(Events.game_ended.is_connected(_widget._on_game_ended), "no game_ended link out of the tree")
	_root.add_child(_widget)
	assert_true(Events.game_started.is_connected(_widget._on_game_started), "linked again on re-entry")
	assert_true(Events.game_ended.is_connected(_widget._on_game_ended), "game_ended linked again")
