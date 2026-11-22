## The task flag (docs/architecture/m3-build-spec.md 6.7, 9): the count and its words, the list, a row's action, hidden at 0,
## with the option off and while covered, closed by a press elsewhere.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const WOODS := Vector2i(9, 11)
const SAVONA := Vector2i(7, 12)

var _g: Game
var _prev_game: Game
var _flag: TaskFlag


func before_each() -> void:
	_prev_game = Session.game
	var defs := load(DEFS_PATH).duplicate() as GameDefs  # rich: money and stores no season moves, so the M4 reminders stay quiet
	defs.weather_odds = PackedInt32Array([100, 0, 0])
	defs.start_treasury_base = 1000000
	defs.reserve_seasons = 10000
	_g = Game.new_scenario(load(MAP_PATH) as MapData, defs, defs.scenarios[defs.scenarios.size() - 1], 1480)
	assert_true(bool(_g.act("choose_country", {"tag": &"GEN"})["ok"]))
	_g.improvement.clear(SAVONA)
	Session.start_game(_g)
	_flag = (load("res://shell/hud/task_flag.tscn") as PackedScene).instantiate() as TaskFlag
	add_child_autofree(_flag)


func after_each() -> void:
	Session.game = _prev_game


func _build(hex: Vector2i, family: int) -> bool:
	return bool(_g.act("build", {"hex": hex, "family": family, "tag": &"GEN"})["ok"])


func test_the_count_and_its_words() -> void:
	assert_eq(_flag.line_count(), 1, "a free work slot is one thing to do")
	assert_eq(_flag._number.text, "1")
	assert_eq(_flag._noun.text, " thing to do")
	assert_true(_flag.visible)
	assert_true(_build(SAVONA, ImproveRules.VINEYARD))
	_flag.refresh()
	assert_eq(_flag._number.text, "1", "one slot left: still one")
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	_flag.refresh()
	assert_eq(_flag.line_count(), 0, "both slots in use: nothing to do")
	assert_false(_flag.visible, "hidden at 0")


func test_two_things_read_in_the_plural() -> void:
	_g.turn = 3  # Autumn: a work in the snow stops until spring
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	_flag.refresh()
	assert_eq(_flag.line_count(), 2)
	assert_eq(_flag._number.text, "2")
	assert_eq(_flag._noun.text, " things to do")


func test_hidden_with_the_option_off() -> void:
	var settings := Settings.new()
	settings.set_value("game/task_flag", false)
	_flag.settings = settings
	_flag.refresh()
	assert_false(_flag.visible, "the option is off: no card")
	assert_eq(_flag.line_count(), 0)
	settings.set_value("game/task_flag", true)
	_flag.refresh()
	assert_true(_flag.visible, "the option is on again")


func test_the_option_changed_through_settings_refreshes_the_card() -> void:
	var settings := Settings.new()
	_flag.settings = settings
	assert_true(_flag.visible, "on: the one free slot shows")
	settings.set_value("game/task_flag", false)
	assert_false(_flag.visible, "off through Settings.changed: hidden at once, no event needed")
	settings.set_value("game/task_flag", true)
	assert_true(_flag.visible, "on again through Settings.changed: shown at once")


func test_other_settings_do_not_refresh_or_hide() -> void:
	var settings := Settings.new()
	_flag.settings = settings
	settings.set_value("game/autosave", "off")
	assert_true(_flag.visible, "an unrelated key leaves the card alone")


func test_replacing_the_settings_moves_the_link() -> void:
	var first := Settings.new()
	var second := Settings.new()
	_flag.settings = first
	_flag.settings = second
	first.set_value("game/task_flag", false)
	assert_true(_flag.visible, "the old settings no longer drive the card")
	second.set_value("game/task_flag", false)
	assert_false(_flag.visible, "the new settings do")


func test_leaving_the_tree_drops_the_settings_link() -> void:
	var settings := Settings.new()
	_flag.settings = settings
	assert_true(settings.changed.is_connected(_flag._on_setting_changed))
	var host := _flag.get_parent()
	host.remove_child(_flag)
	assert_false(settings.changed.is_connected(_flag._on_setting_changed), "no link after exit")
	host.add_child(_flag)
	assert_true(settings.changed.is_connected(_flag._on_setting_changed), "relinked on re-entry")


func test_hidden_without_a_game() -> void:
	Session.game = null
	_flag.refresh()
	assert_false(_flag.visible)


func test_the_list_opens_with_one_row_per_line() -> void:
	_g.turn = 3
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	_flag.refresh()
	_flag.open_list()
	assert_true(_flag.is_list_open())
	assert_eq(_flag._rows.get_child_count(), 2, "the snow line and the free slot")
	var first := _flag._rows.get_child(0) as Button
	assert_eq(first.tooltip_text, "Go to (9, 11)", "the worst line first: its action's label")


func test_a_row_looks_at_its_hex_and_closes_the_list() -> void:
	var watched: Array[Vector2i] = []
	_flag.go_requested.connect(func(hex: Vector2i) -> void: watched.append(hex))
	_flag.open_list()
	assert_true(_flag.choose_row(0))
	assert_eq(watched, [Countries.by_tag(_g, &"GEN").capital], "the free slot's line goes to the capital")
	assert_false(_flag.is_list_open(), "the list closes on a row")


func test_a_row_without_a_hex_does_nothing_but_close() -> void:
	var watched: Array[Vector2i] = []
	_flag.go_requested.connect(func(hex: Vector2i) -> void: watched.append(hex))
	_flag.open_list()
	_flag._lines[0]["hex"] = WorksView.NO_HEX
	assert_false(_flag.choose_row(0))
	assert_eq(watched, [] as Array[Vector2i])
	assert_false(_flag.is_list_open())
	assert_false(_flag.choose_row(7), "no such row")


func test_a_press_elsewhere_closes_the_list() -> void:
	_flag.open_list()
	var away := InputEventMouseButton.new()
	away.button_index = MOUSE_BUTTON_LEFT
	away.pressed = true
	away.global_position = Vector2(-5000, -5000)
	_flag._input(away)
	assert_false(_flag.is_list_open(), "a press outside closes it")


func test_a_press_inside_the_card_keeps_the_list() -> void:
	_flag.open_list()
	var inside := InputEventMouseButton.new()
	inside.button_index = MOUSE_BUTTON_LEFT
	inside.pressed = true
	inside.global_position = _flag.get_global_rect().get_center()
	_flag._input(inside)
	assert_true(_flag.is_list_open(), "the card itself is not 'elsewhere'")


func test_covered_hides_and_closes() -> void:
	_flag.open_list()
	_flag.set_covered(true)
	assert_false(_flag.visible)
	assert_false(_flag.is_list_open(), "a screen up closes the list")
	_flag.open_list()
	assert_false(_flag.is_list_open(), "and it does not open under a screen")
	_flag.set_covered(false)
	assert_true(_flag.visible)


func test_a_click_on_the_card_toggles_the_list() -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	_flag._gui_input(press)
	assert_true(_flag.is_list_open())
	_flag._gui_input(press)
	assert_false(_flag.is_list_open())


func test_a_season_end_refreshes_the_count() -> void:
	assert_eq(_flag._number.text, "1")
	assert_true(_build(SAVONA, ImproveRules.VINEYARD))
	assert_true(_build(WOODS, ImproveRules.TIMBER))
	Events.season_ended.emit(_g.turn)
	assert_false(_flag.visible, "the signal refreshed the flag")


# ----- M4: a line whose action is [&"study", page] (docs/architecture/m4-build-spec.md 6.9) ------------------------------


func _study_line() -> Dictionary:
	return {
		"kind": &"treasury_falling", "severity": 1, "hint": "", "hex": WorksView.NO_HEX, "text": "The treasury will fall by 12 ducats this season.",
		"action": Reminders.STUDY_ACTION.duplicate(), "action_label": "Open the study",
	}


func test_a_study_row_asks_for_the_page_and_closes_the_list() -> void:
	var asked: Array[StringName] = []
	var watched: Array[Vector2i] = []
	_flag.study_requested.connect(func(page: StringName) -> void: asked.append(page))
	_flag.go_requested.connect(func(hex: Vector2i) -> void: watched.append(hex))
	_flag.open_list()
	_flag._lines = [_study_line()]
	_flag._rebuild_rows()
	assert_true(_flag.choose_row(0), "a study line is a row that does something")
	assert_eq(asked, [&"economy"])
	assert_eq(watched, [] as Array[Vector2i], "no glide")
	assert_false(_flag.is_list_open(), "the list closes")


func test_a_study_row_is_enabled_and_a_row_with_neither_is_not() -> void:
	_flag._lines = [_study_line(), {"kind": &"x", "severity": 0, "hint": "", "hex": WorksView.NO_HEX, "text": "Nothing to go to.", "action": [], "action_label": ""}]
	_flag._rebuild_rows()
	assert_false((_flag._rows.get_child(0) as Button).disabled, "the study row can be pressed")
	assert_true((_flag._rows.get_child(1) as Button).disabled, "a row with no hex and no study action is off")
	assert_false(_flag.choose_row(1), "and does nothing")


func test_the_real_hunger_line_opens_the_people_page() -> void:
	var c := Countries.by_tag(_g, &"GEN")
	c.food_need = 9
	c.food_fed = 999
	var line := Reminders.hunger(_g, &"GEN")
	assert_eq(line["action"], [&"study", &"people"])
	_flag._lines = [line]
	var asked: Array[StringName] = []
	_flag.study_requested.connect(func(page: StringName) -> void: asked.append(page))
	assert_true(_flag.choose_row(0))
	assert_eq(asked, [&"people"], "the flag asks for the People page")


func test_the_real_money_lines_carry_the_study_action() -> void:
	# The treasury lines of Reminders open the study: a line built by the rules, not by hand.
	var line := Reminders.treasury_empty(_g, &"GEN")
	assert_true(line.is_empty(), "a rich treasury has no such line")
	assert_true(_g.dev_money(&"GEN", -(Countries.by_tag(_g, &"GEN").treasury + 5)), "the console's way into debt")
	line = Reminders.treasury_empty(_g, &"GEN")
	assert_eq(line["action"], [&"study", &"economy"])
	_flag._lines = [line]
	var asked: Array[StringName] = []
	_flag.study_requested.connect(func(page: StringName) -> void: asked.append(page))
	assert_true(_flag.choose_row(0))
	assert_eq(asked, [&"economy"])


## M7 (B27): a war timer row opens the enemy's country panel (the App's country request), and a war event rereads the flag.
func test_a_war_timer_row_asks_for_the_enemy_country() -> void:
	var g := Session.game
	var enemy := ArmyFixture.other_tag(g)
	WarFixture.at_war(g, ArmyFixture.TAG, enemy)
	g.turn += g.defs.war.war_timer_warning
	g.version += 1
	var asked: Array[StringName] = []
	_flag.country_requested.connect(func(tag: StringName) -> void: asked.append(tag))
	_flag.refresh()
	var index := -1
	for i: int in _flag.line_count():
		if _flag.lines()[i]["kind"] == &"war_timer":
			index = i
	assert_true(index >= 0, "the timer reminder is on the flag")
	assert_true(_flag.choose_row(index), "the row is chosen")
	assert_eq(asked, [enemy], "the enemy's country is asked for")
