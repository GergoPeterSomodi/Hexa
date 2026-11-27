## Table-driven tests for EscLadder (docs/architecture/ui-and-controls-spec.md section 3.3 and 9).
extends GutTest


func test_esc_ladder_screen_cases() -> void:
	var cases: Array[Dictionary] = [
		{
			"name": "loading screen ignores Esc even with everything else open",
			"state": {"top_screen_id": &"loading", "has_screen": true, "hud_list_open": true, "has_selection": true, "dock_open": true},
			"expected": &"none",
		},
		{
			"name": "main menu ignores Esc",
			"state": {"top_screen_id": &"main_menu", "has_screen": true, "hud_list_open": false, "has_selection": false, "dock_open": false},
			"expected": &"none",
		},
		{
			"name": "pause menu pops via stack_back",
			"state": {"top_screen_id": &"pause_menu", "has_screen": true, "hud_list_open": true, "has_selection": true, "dock_open": true},
			"expected": &"stack_back",
		},
		{
			"name": "options modal uses stack_back",
			"state": {"top_screen_id": &"options", "has_screen": true, "hud_list_open": false, "has_selection": false, "dock_open": false},
			"expected": &"stack_back",
		},
		{
			"name": "help overlay uses stack_back before clearing map selection",
			"state": {"top_screen_id": &"help_overlay", "has_screen": true, "hud_list_open": false, "has_selection": true, "dock_open": true},
			"expected": &"stack_back",
		},
	]
	for c: Dictionary in cases:
		var state: Dictionary = c["state"]
		var expected: StringName = c["expected"]
		assert_eq(EscLadder.decide(state), expected, str(c["name"]))


## M6 (L24): a selected army (its panel in the dock) is the first thing the clear step takes, before the hex.
func test_a_selected_army_clears_before_the_hex() -> void:
	assert_eq(EscLadder.decide({"has_army": true, "dock_open": true}), EscLadder.CLEAR_SELECTION, "the army panel clears")
	assert_eq(EscLadder.decide({"has_army": true}), EscLadder.CLEAR_SELECTION, "an army alone clears")
	assert_eq(EscLadder.decide({"has_army": false, "has_selection": false}), EscLadder.OPEN_PAUSE_MENU, "no army: the pause menu")
	assert_eq(EscLadder.decide({"hud_list_open": true, "has_army": true}), EscLadder.CLOSE_HUD_LIST, "a HUD list closes first")
	assert_eq(EscLadder.decide({"top_screen_id": &"help_overlay", "has_screen": true, "has_army": true}), EscLadder.STACK_BACK, "a screen first")


## moves in the month (R61, D34): staged stops clear in one step before the army; a screen and a HUD list still come first.
func test_staged_stops_clear_before_the_army() -> void:
	var state := {"has_stops": true, "has_army": true, "has_selection": true, "dock_open": true}
	assert_eq(EscLadder.decide(state), EscLadder.CLEAR_STOPS, "P: Esc that leaves stops staged and drops the army")
	assert_eq(EscLadder.decide({"has_stops": false, "has_army": true}), EscLadder.CLEAR_SELECTION, "then the army")
	assert_eq(EscLadder.decide({"has_stops": true, "hud_list_open": true}), EscLadder.CLOSE_HUD_LIST, "a HUD list first")
	assert_eq(EscLadder.decide({"has_stops": true, "has_screen": true, "top_screen_id": &"confirm"}), EscLadder.STACK_BACK,
		"a screen first")


func test_esc_ladder_hud_and_map_cases() -> void:
	var cases: Array[Dictionary] = [
		{
			"name": "open HUD list closes before selection or dock",
			"state": {"top_screen_id": &"", "has_screen": false, "hud_list_open": true, "has_selection": true, "dock_open": true},
			"expected": &"close_hud_list",
		},
		{
			"name": "selected hex clears selection",
			"state": {"top_screen_id": &"", "has_screen": false, "hud_list_open": false, "has_selection": true, "dock_open": false},
			"expected": &"clear_selection",
		},
		{
			"name": "open dock panel clears selection and closes dock",
			"state": {"top_screen_id": &"", "has_screen": false, "hud_list_open": false, "has_selection": false, "dock_open": true},
			"expected": &"clear_selection",
		},
		{
			"name": "idle map opens pause menu",
			"state": {"top_screen_id": &"", "has_screen": false, "hud_list_open": false, "has_selection": false, "dock_open": false},
			"expected": &"open_pause_menu",
		},
		{
			"name": "empty dictionary defaults to open_pause_menu",
			"state": {},
			"expected": &"open_pause_menu",
		},
	]
	for c: Dictionary in cases:
		var state: Dictionary = c["state"]
		var expected: StringName = c["expected"]
		assert_eq(EscLadder.decide(state), expected, str(c["name"]))
