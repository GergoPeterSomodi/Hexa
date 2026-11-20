## GUT tests for what the App wires into the Statesman's Study (docs/architecture/m4-build-spec.md 6.7 and 6.12): the bus
## signals it listens to while it is on the stack, the measure switch read before each refresh, the tax levels done through
## Session, the last page kept in a setting, and a page with no player to tax.
extends GutTest

const SCENE := "res://shell/screens/study.tscn"
const GEN := &"GEN"

var _harness: UIHarness = null
var _prev_game: Game = null
var _toasts: Array[Array] = []


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_harness = UIHarness.new()
	_harness.mount(self)
	_harness.stack.theme = KitTheme.load_for(1.0)
	_toasts = []
	_harness.ctx.toast_requested.connect(func(text: String, tone: StringName) -> void: _toasts.append([text, tone]))
	Session.start_game(EconomyFixture.game(GEN))


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	_harness = null
	Session.game = _prev_game
	Bindings.reset_defaults()


func _open() -> Study:
	var study := (load(SCENE) as PackedScene).instantiate() as Study
	study.configure(StudyPages.shown("4"))
	_harness.stack.push(study)
	return study


func _tax(study: Study) -> Segmented:
	return study.find_child("TaxLevels", true, false) as Segmented


func test_the_study_listens_to_the_five_signals_only_while_it_is_on_the_stack() -> void:
	var study := _open()
	var pairs: Array = [
		[Events.season_ended, study._on_season_ended], [Events.tax_set, study._on_tax_set], [Events.work_started, study._on_work_event],
		[Events.work_finished, study._on_work_event], [Events.work_cancelled, study._on_work_cancelled],
	]
	for pair: Array in pairs:
		assert_true((pair[0] as Signal).is_connected(pair[1] as Callable), "linked while up")
	_harness.stack.remove(study)
	for pair: Array in pairs:
		assert_false((pair[0] as Signal).is_connected(pair[1] as Callable), "unlinked when it leaves")
	_harness.stack.push(study)
	assert_true(Events.tax_set.is_connected(study._on_tax_set), "and linked again when it returns")
	_harness.stack.remove(study)
	study.free()


func test_a_tax_change_a_work_and_a_season_refresh_the_page_in_view() -> void:
	var study := _open()
	assert_eq(_tax(study).selected_id(), 1, "Normal at the start")
	assert_true(bool(Session.act("set_tax", {"level": 2})["ok"]))
	assert_eq(_tax(study).selected_id(), 2, "tax_set refreshed the page")
	assert_true(bool(Session.end_season()["ok"]))
	assert_false(_texts(study).has(PageEconomy.NO_SEASON), "season_ended refreshed it: a season has ended")
	assert_eq(study.date_label().text, "Summer 1480", "and the date")
	_harness.stack.remove(study)
	assert_true(bool(Session.act("set_tax", {"level": 0})["ok"]))
	assert_eq(_tax(study).selected_id(), 2, "a study off the stack is not refreshed")
	study.free()


func _buildable() -> Dictionary:
	var game := Session.game
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if game.map.land[i] == 0 or not Improve.piece_at(game, hex).is_empty():
			continue
		for option: Dictionary in Improve.build_options(game, hex):
			if bool(option["ok"]) and bool(Session.check("build", {"hex": hex, "family": int(option["family_id"])})["ok"]):
				return {"hex": hex, "family": int(option["family_id"])}
	return {}


func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	for child: Node in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		out.append_array(_texts(child))
	return out


func test_every_signal_refreshes_the_page_in_view_with_its_reason() -> void:
	var study := (load(SCENE) as PackedScene).instantiate() as Study
	study.configure([{"id": &"counting", "title": "Counting", "scene": "res://tests/fixtures/study_page_counting.tscn", "since": "4"}] as Array[Dictionary])
	_harness.stack.push(study)
	var reasons: Array = study.current_page().get("reasons")  # the page's own list: it fills as the signals come
	assert_eq(reasons, [&"open"], "the push shows the page")
	var hex := _buildable()
	assert_true(bool(Session.act("build", {"hex": hex["hex"], "family": hex["family"]})["ok"]))
	assert_eq(reasons.back(), &"work", "work_started")
	assert_true(bool(Session.act("cancel_work", {"hex": hex["hex"]})["ok"]))
	assert_eq(reasons.back(), &"work", "work_cancelled")
	assert_eq(reasons.size(), 3)
	Events.work_finished.emit(GEN, hex["hex"], {})
	assert_eq(reasons.size(), 4, "work_finished")
	assert_true(bool(Session.act("set_tax", {"level": 2})["ok"]))
	assert_eq(reasons.back(), &"tax_set")
	assert_true(bool(Session.end_season()["ok"]))
	assert_eq(reasons.back(), &"season_ended")
	var seen: int = reasons.size()
	_harness.stack.remove(study)
	Session.act("set_tax", {"level": 0})
	assert_eq(reasons.size(), seen, "a study off the stack is left alone")
	study.free()


func test_the_measure_switch_is_read_before_each_refresh() -> void:
	var study := _open()
	var page := study.current_page() as PageEconomy
	assert_false(page.treasury_only)
	_harness.settings.set_value("game/gain_treasury_only", true)
	study.open_page(&"economy")
	assert_true(page.treasury_only, "open_page reads game/gain_treasury_only")
	_harness.settings.set_value("game/gain_treasury_only", false)
	Session.act("set_tax", {"level": 2})
	assert_false(page.treasury_only, "so does a refresh from the bus")


func test_a_set_tax_action_goes_through_session_and_the_page_follows() -> void:
	var study := _open()
	study.current_page().request([&"set_tax", 2])
	assert_eq(Countries.by_tag(Session.game, GEN).tax, 2, "Session.act set it")
	assert_eq(_tax(study).selected_id(), 2)
	assert_true(_toasts.is_empty(), "the toast of a set tax is the App's (tax_set), not the study's")
	study.current_page().request([&"set_tax", 2])
	assert_eq(Countries.by_tag(Session.game, GEN).tax, 2, "the same level again changes nothing")
	assert_eq(_toasts.size(), 1)
	assert_eq(_toasts[0], ["Taxes are already High.", &"bad"], "the rule's own words as a toast")
	study.current_page().request([&"set_tax", 9])
	assert_eq(_toasts[1][0], "No such tax level.")
	Session.end_game()
	study.current_page().request([&"set_tax", 1])
	assert_eq(_toasts[2][0], "No game.", "with no game")


func test_the_last_page_is_kept_in_state_study_page() -> void:
	var study := _open()
	assert_eq(str(_harness.settings.get_value("state/study_page")), "economy")
	study.open_page(&"economy")
	assert_eq(str(_harness.settings.get_value("state/study_page")), "economy")


func test_a_game_with_no_player_shows_no_tax_row() -> void:
	Session.start_game(EconomyFixture.game())
	var study := _open()
	assert_null(study.find_child("TaxRow", true, false), "no country to tax: no row")
	assert_null(_tax(study))
	Session.start_game(EconomyFixture.game(GEN))
	study.open_page(&"economy")
	assert_not_null(_tax(study), "a player: the row is there")
