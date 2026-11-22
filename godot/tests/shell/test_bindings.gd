## Tests for Bindings (docs/architecture/ui-and-controls-spec.md section 4.1 and 9,
## docs/architecture/ui-style-and-feedback-spec.md section 9).
extends GutTest


func before_each() -> void:
	Bindings.reset_defaults()


func after_each() -> void:
	Bindings.reset_defaults()


func test_ensure_registers_every_default_action() -> void:
	Bindings.ensure()
	assert_gt(Bindings.DEFAULTS.size(), 50, "table covers M1 through M11 actions")
	for entry: Dictionary in Bindings.DEFAULTS:
		var action: StringName = entry["action"]
		assert_true(InputMap.has_action(action), "InputMap has %s" % action)
		var events := Bindings.events_for(action)
		var expected: Array = entry["events"]
		assert_eq(events.size(), expected.size(), "%s has all default events" % action)


func test_ensure_filters_by_milestone() -> void:
	for entry: Dictionary in Bindings.DEFAULTS:
		var action: StringName = entry["action"]
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	Bindings.ensure("1.5")
	assert_true(InputMap.has_action(&"cam_pan_left"))
	assert_true(InputMap.has_action(&"dev_new_seed"))
	assert_true(InputMap.has_action(&"app_fullscreen"))
	assert_false(InputMap.has_action(&"view_mode_1"))
	assert_false(InputMap.has_action(&"game_tech"))


func test_no_duplicate_default_event_within_group_and_active_milestone() -> void:
	var milestones: Array[String] = ["1", "1.5", "2", "3", "4", "4.5", "6", "7", "11", "12"]
	for m_str: String in milestones:
		var m := float(m_str)
		var by_group: Dictionary = {}
		for entry: Dictionary in Bindings.DEFAULTS:
			var start_m := float(str(entry["since"]))
			var end_m := float(str(entry.get("until", "999")))
			if m < start_m or m > end_m:
				continue
			var group := str(entry["group"])
			if not by_group.has(group):
				by_group[group] = {}
			var seen: Dictionary = by_group[group]
			var action: StringName = entry["action"]
			var ev_list: Array = entry["events"]
			for raw_ev: Variant in ev_list:
				var ev := Bindings.parse_event(str(raw_ev))
				assert_not_null(ev, "valid event %s on %s" % [str(raw_ev), action])
				var key := Bindings.serialize_event(ev)
				assert_false(seen.has(key),
					"duplicate event %s in group %s at M%s between %s and %s" % [
						key, group, m_str, str(seen.get(key, &"")), action])
				seen[key] = action


func test_round_trip_for_every_default_event() -> void:
	Bindings.ensure()
	for entry: Dictionary in Bindings.DEFAULTS:
		var action: StringName = entry["action"]
		var raw_events: Array = entry["events"]
		for raw_item: Variant in raw_events:
			var canonical := str(raw_item)
			var parsed := Bindings.parse_event(canonical)
			assert_not_null(parsed, "parse_event(%s) for %s" % [canonical, action])
			assert_eq(Bindings.serialize_event(parsed), canonical,
				"serialize_event(parse_event(%s)) round trip" % canonical)
			for platform: String in ["Windows", "macOS", "Linux"]:
				var display := Bindings.event_text(parsed, platform)
				assert_ne(display, "", "event_text non-empty for %s on %s" % [canonical, platform])
				var from_display := Bindings.parse_event(display)
				assert_not_null(from_display, "parse_event(event_text(%s, %s)) = %s" % [canonical, platform, display])
				assert_eq(Bindings.serialize_event(from_display), canonical,
					"event_text(%s, %s) -> %s round trips to %s" % [canonical, platform, display, canonical])
		var live_events := Bindings.events_for(action)
		for i: int in live_events.size():
			assert_eq(Bindings.serialize_event(live_events[i]), str(raw_events[i]),
				"live InputMap event %d of %s serializes back to default" % [i, action])


func test_physical_keys_and_autoremap_chords() -> void:
	Bindings.ensure()
	var pan_left := Bindings.events_for(&"cam_pan_left")
	assert_eq(pan_left.size(), 2)
	var first_key := pan_left[0] as InputEventKey
	assert_not_null(first_key)
	assert_eq(first_key.physical_keycode, KEY_A)
	assert_eq(first_key.keycode, KEY_NONE)

	var new_seed := Bindings.events_for(&"dev_new_seed")[0] as InputEventKey
	assert_not_null(new_seed)
	assert_true(new_seed.command_or_control_autoremap)
	assert_eq(Bindings.event_text(new_seed, "Windows"), "Ctrl+R")
	assert_eq(Bindings.event_text(new_seed, "macOS"), "Cmd+R")

	var fullscreen := Bindings.events_for(&"app_fullscreen")
	assert_eq(fullscreen.size(), 3)
	var mac_chord := fullscreen[2] as InputEventKey
	assert_false(mac_chord.command_or_control_autoremap)
	assert_true(mac_chord.ctrl_pressed)
	assert_true(mac_chord.meta_pressed)
	assert_eq(Bindings.event_text(mac_chord, "macOS"), "Ctrl+Cmd+F")
	assert_eq(Bindings.serialize_event(mac_chord), "Ctrl+Meta+F")


func test_apply_overrides_and_reset_defaults() -> void:
	Bindings.ensure()
	var res := Bindings.apply_overrides({
		"view_grid": "K",
		"game_upgrade": ["Y", "Z"],
	})
	assert_true(bool(res["ok"]))
	var conflicts: Dictionary = res["conflicts"]
	assert_true(conflicts.is_empty())
	assert_eq(Bindings.key_caps_for(&"view_grid", "Windows"), ["K"] as Array[String])
	assert_eq(Bindings.key_caps_for(&"game_upgrade", "Windows"), ["Y", "Z"] as Array[String])

	Bindings.reset_defaults()
	assert_eq(Bindings.key_caps_for(&"view_grid", "Windows"), ["G"] as Array[String])
	assert_eq(Bindings.key_caps_for(&"game_upgrade", "Windows"), ["U"] as Array[String])


func test_apply_overrides_rejects_conflicts_and_invalid_inputs() -> void:
	Bindings.ensure()
	var res := Bindings.apply_overrides({
		"no_such_action": "K",
		"view_names": "NotAKeyNameAtAll",
		"view_grid": "H",  # clashes with view_hud in group "View"
		"cam_fit": "A",    # clashes with cam_pan_left in group "Camera"
	})
	assert_false(bool(res["ok"]))
	var conflicts: Dictionary = res["conflicts"]
	assert_eq(conflicts.get(&"no_such_action"), &"unknown_action")
	assert_eq(conflicts.get(&"view_names"), &"invalid_event")
	assert_eq(conflicts.get(&"view_grid"), &"view_hud")
	assert_eq(conflicts.get(&"cam_fit"), &"cam_pan_left")
	assert_eq(Bindings.key_caps_for(&"view_grid", "Windows"), ["G"] as Array[String])
	assert_eq(Bindings.key_caps_for(&"cam_fit", "Windows"), ["F", "Home"] as Array[String])


func test_parse_event_returns_null_on_invalid_strings() -> void:
	assert_null(Bindings.parse_event(""))
	assert_null(Bindings.parse_event("   "))
	assert_null(Bindings.parse_event("BogusMod+A"))
	assert_null(Bindings.parse_event("Ctrl+BogusKey"))
	assert_null(Bindings.parse_event("Ctrl+"))


func test_gestures_include_platform_lines_and_works_card_hold() -> void:
	for platform: String in ["macOS", "Windows", "Linux"]:
		var lines := Bindings.gestures_for(platform)
		assert_gt(lines.size(), 0)
		assert_true(lines.has("Shift: hold the works card"),
			"%s gestures include Shift: hold the works card" % platform)


func test_m2_actions_exist_and_season_keys_are_gone() -> void:
	Bindings.ensure()
	var wanted: Dictionary = {
		&"view_mode_1": "1", &"view_mode_2": "2", &"view_mode_3": "3", &"view_mode_4": "4",
		&"view_mode_5": "5", &"view_mode_6": "6",
		&"ui_find_place": "Ctrl+F", &"game_country": "C",
	}
	for action: StringName in wanted:
		assert_true(InputMap.has_action(action), "InputMap has %s" % action)
		var entry := _entry_of(action)
		assert_eq(str(entry["since"]), {&"view_mode_5": "5", &"view_mode_6": "6"}.get(action, "2"), "%s arrives with its milestone" % action)
		var ev := Bindings.parse_event(str(wanted[action]))
		assert_eq(Bindings.serialize_event(Bindings.parse_event(str((entry["events"] as Array)[0]))),
			Bindings.serialize_event(ev), "%s default key" % action)
	for i: int in range(1, 5):
		var season := StringName("view_season_%d" % i)
		assert_false(InputMap.has_action(season), "%s is gone from InputMap" % season)
		assert_true(_entry_of(season).is_empty(), "%s is gone from the table" % season)
	assert_false(InputMap.has_action(&"view_season_1"))


func test_m6_rows_exist_with_since_6_and_the_right_keys() -> void:
	var wanted: Dictionary = {
		&"game_next_unit": ["Tab"], &"game_continue_march": ["R"],
		&"map_cursor_left": ["Alt+Left"], &"map_cursor_right": ["Alt+Right"],
		&"map_cursor_up": ["Alt+Up"], &"map_cursor_down": ["Alt+Down"],
		&"map_command_key": ["O", "Shift+F10"], &"view_mode_6": ["6"],
	}
	for action: StringName in wanted:
		var entry := _entry_of(action)
		assert_false(entry.is_empty(), "%s has a row" % action)
		assert_eq(str(entry["since"]), "6", "%s arrives in M6" % action)
		assert_eq(Array(entry["events"]), wanted[action], "%s default keys" % action)
	assert_eq(str(_entry_of(&"map_command_key")["label"]), "Command at the cursor")
	assert_eq(str(_entry_of(&"map_command_key")["group"]), "Map")
	assert_eq(str(_entry_of(&"view_mode_6")["group"]), "View")
	assert_eq(str(_entry_of(&"map_command")["since"]), "1", "the right click row is older")
	Bindings.ensure("6")
	for action: StringName in wanted:
		assert_true(InputMap.has_action(action), "%s registers at milestone 6" % action)


func test_right_click_gesture_line_is_the_same_on_every_platform() -> void:
	var line := "Right click (two-finger click): order the selected army; with none, the hex menu"
	for platform: String in ["macOS", "Windows", "Linux", "default"]:
		assert_true(Bindings.gestures_for(platform).has(line), "%s has the new right-click line" % platform)
		for old: String in Bindings.gestures_for(platform):
			assert_false(old.ends_with("clear the selection"), "no stale line on %s" % platform)


func test_digit_keys_have_one_owner_at_every_milestone() -> void:
	for m_str: String in ["1", "1.5", "2", "3", "12"]:
		var owners: Array[StringName] = []
		for entry: Dictionary in Bindings.DEFAULTS:
			var m := float(m_str)
			if m < float(str(entry["since"])) or m > float(str(entry.get("until", "999"))):
				continue
			if str(entry["group"]) == "View" and (entry["events"] as Array).has("1"):
				owners.append(entry["action"])
		assert_lte(owners.size(), 1, "key 1 has at most one View action at M%s: %s" % [m_str, owners])


func _entry_of(action: StringName) -> Dictionary:
	for entry: Dictionary in Bindings.DEFAULTS:
		if entry["action"] == action:
			return entry
	return {}


func test_m3_actions_exist_with_the_spec_keys() -> void:
	var wanted := {&"game_undo_work": "Ctrl+Z", &"dev_console": "F2"}
	for action: StringName in wanted:
		assert_true(InputMap.has_action(action), "InputMap has %s" % action)
		var entry := _entry_of(action)
		assert_eq(str(entry["since"]), "3", "%s arrives in M3" % action)
		assert_eq(Bindings.serialize_event(Bindings.parse_event(str((entry["events"] as Array)[0]))),
			Bindings.serialize_event(Bindings.parse_event(str(wanted[action]))), "%s default key" % action)
	assert_eq(str(_entry_of(&"dev_console")["group"]), "Developer")


func test_m7_rows_have_the_spec_keys_and_groups() -> void:
	var storm := _entry_of(&"map_command_storm")
	assert_eq(str(storm["since"]), "7", "storm arrives in M7")
	assert_eq(str(storm["group"]), "Map")
	assert_eq(str(storm["label"]), "Storm at the cursor")
	assert_eq(storm["events"], ["Shift+O"], "storm default key")
	var battle := _entry_of(&"game_battle")
	assert_eq(str(battle["since"]), "7", "last battle arrives in M7")
	assert_eq(str(battle["group"]), "Game")
	assert_eq(str(battle["label"]), "Last battle")
	assert_eq(battle["events"], ["B"], "battle default key")
	assert_eq(_entry_of(&"map_command_key")["events"], ["O", "Shift+F10"], "the command key keeps plain O")
	Bindings.ensure("7")
	assert_true(InputMap.has_action(&"map_command_storm"))
	assert_true(InputMap.has_action(&"game_battle"))


func test_m7_shift_o_is_the_storm_and_plain_o_still_commands() -> void:
	Bindings.ensure("7")
	var shift_o := InputEventKey.new()
	shift_o.keycode = KEY_O
	shift_o.shift_pressed = true
	shift_o.pressed = true
	assert_true(shift_o.is_action_pressed(&"map_command_storm", false, true), "Shift+O storms")
	assert_false(shift_o.is_action_pressed(&"map_command_key", false, true), "Shift+O never also fires O")
	var plain := InputEventKey.new()
	plain.keycode = KEY_O
	plain.pressed = true
	assert_true(plain.is_action_pressed(&"map_command_key", false, true), "plain O still commands")
	assert_false(plain.is_action_pressed(&"map_command_storm", false, true), "plain O does not storm")


func test_m7_shift_right_click_gesture_line_is_on_every_platform() -> void:
	var line := "Shift+right click (Shift+two-finger click): storm a fortress with the selected army"
	for platform: String in ["macOS", "Windows", "Linux", "default"]:
		assert_true(Bindings.gestures_for(platform).has(line), "%s has the storm line" % platform)
