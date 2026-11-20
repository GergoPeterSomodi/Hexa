## GUT tests for Studiolo Options modal screen: schema/row parity, page switching,
## immediate edits, per-page defaults, staged display Apply + 10 s keep/revert, and keybindings
## (docs/architecture/ui-and-controls-spec.md sections 6.2-6.7, 9;
## docs/architecture/ui-style-and-feedback-spec.md section 2; plan U11).
extends GutTest

var _harness: UIHarness = null
var _old_max_fps: int = 0
var _old_low_proc: bool = false
var _old_tooltip_delay: float = 0.5


func before_each() -> void:
	_old_max_fps = Engine.max_fps
	_old_low_proc = OS.low_processor_usage_mode
	_old_tooltip_delay = float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5))
	Bindings.reset_defaults()
	_harness = UIHarness.new()
	_harness.settings.set_value("accessibility/reduce_motion", true)
	_harness.mount(self)
	_harness.stack.theme = KitTheme.load_for(1.0)


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	_harness = null
	Bindings.reset_defaults()
	Engine.max_fps = _old_max_fps
	OS.low_processor_usage_mode = _old_low_proc
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", _old_tooltip_delay)


func test_options_opens_with_studiolo_geometry_focus_and_bidirectional_schema_parity() -> void:
	var options := ScreenIds.make(&"options") as Options
	assert_not_null(options)
	_harness.stack.push(options)
	await _harness.wait_frames(self, 2)

	assert_eq(options.kind, Screen.Kind.MODAL)
	assert_eq(options.screen_id, &"options")
	assert_eq(options.frame().custom_minimum_size, Vector2(860.0, 580.0))
	assert_not_null(options.back_button().embedded_key_cap(), "Esc KeyCap is embedded inside BackButton")
	assert_eq(options.back_button().embedded_key_cap().label().text, "Esc")
	assert_eq(_harness.viewport.gui_get_focus_owner(), options.nav_list().button_for(&"display"))
	assert_true(options.apply_button().disabled, "Apply starts disabled with no staged changes")

	# Schema -> Row: every key up to milestone 3 with a non-empty page has a matching OptionRow
	var expected_1_5_keys: Dictionary[String, bool] = {}
	for key: String in Settings.SCHEMA.keys():
		var entry: Dictionary = Settings.SCHEMA[key]
		if float(str(entry.get("since", "1.5"))) <= 3.0 and not str(entry.get("page", "")).is_empty():
			expected_1_5_keys[key] = true
			var row := options.option_row(key)
			assert_not_null(row, "Options has OptionRow for M1.5 key %s" % key)
			if row != null:
				assert_eq(row.key(), key)

	# Row -> Schema: every OptionRow maps to a valid 1.5 Settings.SCHEMA key
	var rows := options.option_rows()
	assert_eq(rows.size(), expected_1_5_keys.size(), "OptionRow count matches M1.5 paged schema keys")
	for row: OptionRow in rows:
		var k := row.key()
		assert_true(Settings.SCHEMA.has(k), "Row key %s exists in Settings.SCHEMA" % k)
		assert_true(expected_1_5_keys.has(k), "Row key %s is an active M1.5 paged key" % k)


func test_page_switching_immediate_edits_and_defaults_for_this_page() -> void:
	var options := ScreenIds.make(&"options") as Options
	_harness.stack.push(options)
	await _harness.wait_frames(self, 2)

	# Switch pages via NavList
	options.nav_list().select(&"map", true)
	await _harness.wait_frames(self, 1)
	assert_eq(options.current_page(), &"map")
	assert_false(options.defaults_button().disabled)

	# Immediate edit through OptionRow updates Settings right away
	var grid_sw := options.option_row("map/grid").control() as KitSwitch
	assert_not_null(grid_sw)
	grid_sw.button_pressed = true
	assert_eq(_harness.settings.get_value("map/grid"), true)

	var opacity_sl := options.option_row("map/grid_opacity").control() as KitSlider
	assert_not_null(opacity_sl)
	opacity_sl.value = 55.0
	assert_eq(_harness.settings.get_value("map/grid_opacity"), 55)

	# Edit a Controls setting too
	options.nav_list().select(&"controls", true)
	await _harness.wait_frames(self, 1)
	assert_eq(options.current_page(), &"controls")
	var pan_sl := options.option_row("controls/pan_speed").control() as KitSlider
	pan_sl.value = 160.0
	assert_eq(_harness.settings.get_value("controls/pan_speed"), 160)

	# Switch back to Map and press Defaults for this page -> resets Map only
	options.nav_list().select(&"map", true)
	await _harness.wait_frames(self, 1)
	options.defaults_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.settings.get_value("map/grid"), false, "map/grid reset to default")
	assert_eq(_harness.settings.get_value("map/grid_opacity"), 100, "map/grid_opacity reset to default")
	assert_eq(_harness.settings.get_value("controls/pan_speed"), 160, "controls/pan_speed untouched")

	# About page disables Defaults for this page and renders Copy diagnostics
	options.nav_list().select(&"about", true)
	await _harness.wait_frames(self, 1)
	assert_eq(options.current_page(), &"about")
	assert_true(options.defaults_button().disabled)
	assert_not_null(options.about_copy_button())


func test_staged_display_apply_and_ten_second_confirm_keep_revert_and_esc() -> void:
	var options := ScreenIds.make(&"options") as Options
	_harness.stack.push(options)
	await _harness.wait_frames(self, 2)

	var mode_opt := options.option_row("display/window_mode").control() as OptionButton
	var preset_opt := options.option_row("display/window_preset").control() as OptionButton
	var scale_opt := options.option_row("display/ui_scale").control() as OptionButton
	assert_not_null(mode_opt)
	assert_not_null(preset_opt)
	assert_not_null(scale_opt)
	assert_false(preset_opt.disabled, "window_preset enabled in windowed mode")

	# Stage fullscreen + 150% UI scale without committing to live Settings yet
	mode_opt.select(1)
	mode_opt.item_selected.emit(1)
	assert_true(preset_opt.disabled, "window_preset disabled while fullscreen staged")
	scale_opt.select(4)  # "150"
	scale_opt.item_selected.emit(4)

	assert_true(options.has_pending_display_changes())
	assert_false(options.apply_button().disabled, "Apply enabled when staged display changes exist")
	assert_eq(_harness.settings.get_value("display/window_mode"), "windowed", "live mode unchanged before Apply")
	assert_eq(_harness.settings.get_value("display/ui_scale"), "auto", "live ui_scale unchanged before Apply")

	# Click Apply -> commits, opens Confirm with 10s revert countdown, Esc reverts!
	options.apply_button().pressed.emit()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.settings.get_value("display/window_mode"), "fullscreen")
	assert_eq(_harness.settings.get_value("display/ui_scale"), "150")
	assert_eq(_harness.stack.count(), 2)

	var confirm := _harness.stack.top() as Confirm
	assert_not_null(confirm)
	assert_eq(confirm.sheet().seal_text(), "10")
	assert_eq(_harness.viewport.gui_get_focus_owner(), confirm.button_for(&"revert"), "Revert safe choice focused")

	# Esc picks safe choice (&"revert") and restores prior display settings
	assert_true(_harness.stack.back())
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 1)
	assert_eq(_harness.stack.top(), options)
	assert_eq(_harness.settings.get_value("display/window_mode"), "windowed", "Esc reverted window_mode")
	assert_eq(_harness.settings.get_value("display/ui_scale"), "auto", "Esc reverted ui_scale")
	assert_false(preset_opt.disabled, "window_preset re-enabled after revert")
	assert_false(options.has_pending_display_changes())

	# Stage UI scale 150%, Apply, and let 10 s timeout expire -> auto-reverts
	scale_opt.select(4)
	scale_opt.item_selected.emit(4)
	options.apply_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	var confirm2 := _harness.stack.top() as Confirm
	assert_not_null(confirm2)
	confirm2._process(10.1)
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 1)
	assert_eq(_harness.settings.get_value("display/ui_scale"), "auto", "10 s timeout reverted ui_scale")

	# Stage UI scale 125%, Apply, and click Keep -> persists new value
	scale_opt.select(3)  # "125"
	scale_opt.item_selected.emit(3)
	options.apply_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	var confirm3 := _harness.stack.top() as Confirm
	assert_not_null(confirm3)
	confirm3.button_for(&"keep").pressed.emit()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 1)
	assert_eq(_harness.settings.get_value("display/ui_scale"), "125", "Keep persisted new ui_scale")


func test_key_rebinding_conflict_esc_cancel_and_reset() -> void:
	var options := ScreenIds.make(&"options") as Options
	_harness.stack.push(options)
	await _harness.wait_frames(self, 2)

	options.select_page(&"controls")
	await _harness.wait_frames(self, 1)

	# Every Bindings.DEFAULTS action is represented
	for entry: Dictionary in Bindings.DEFAULTS:
		var action: StringName = entry["action"]
		assert_gt(options.key_caps_for_action(action).size(), 0, "KeyCaps rendered for %s" % String(action))

	# Begin capture on view_grid, then cancel with Esc -> stays G and Options remains open
	options.rebind_button_for(&"view_grid").pressed.emit()
	assert_eq(options.capturing_action(), &"view_grid")
	assert_true(options.key_caps_for_action(&"view_grid")[0].waiting)

	_harness.send_key(KEY_ESCAPE)
	await _harness.wait_frames(self, 1)
	assert_eq(options.capturing_action(), &"")
	assert_eq(_harness.stack.count(), 1, "Esc during key capture does not pop Options")
	assert_eq(options.key_caps_for_action(&"view_grid")[0].label().text, "G")

	# Attempt conflicting key H (clashes with view_hud in View group) -> refused
	options.rebind_button_for(&"view_grid").pressed.emit()
	_harness.send_key(KEY_H)
	await _harness.wait_frames(self, 1)
	assert_eq(options.capturing_action(), &"")
	assert_true(options.keys_hint_label().text.contains("conflicts"))
	assert_eq(options.key_caps_for_action(&"view_grid")[0].label().text, "G")

	# Valid rebind to K -> succeeds and writes key override
	options.rebind_button_for(&"view_grid").pressed.emit()
	_harness.send_key(KEY_K)
	await _harness.wait_frames(self, 1)
	assert_eq(options.key_caps_for_action(&"view_grid")[0].label().text, "K")
	assert_eq(_harness.settings.get_key_overrides().get("view_grid"), "K")

	# Rebinding another action in the same group to K clashes with view_grid's custom binding
	options.rebind_button_for(&"view_names").pressed.emit()
	_harness.send_key(KEY_K)
	await _harness.wait_frames(self, 1)
	assert_true(options.keys_hint_label().text.contains("conflicts"))
	assert_eq(options.key_caps_for_action(&"view_names")[0].label().text, "N")
	assert_eq(options.key_caps_for_action(&"view_grid")[0].label().text, "K", "previous rebind preserved after clash")

	# Rebinding a second action to B preserves both custom overrides in InputMap and Settings
	options.rebind_button_for(&"view_names").pressed.emit()
	_harness.send_key(KEY_B)
	await _harness.wait_frames(self, 1)
	assert_eq(options.key_caps_for_action(&"view_names")[0].label().text, "B")
	assert_eq(options.key_caps_for_action(&"view_grid")[0].label().text, "K", "first rebind still active after second rebind")
	assert_eq(_harness.settings.get_key_overrides().get("view_grid"), "K")
	assert_eq(_harness.settings.get_key_overrides().get("view_names"), "B")
	assert_eq(Bindings.key_caps_for(&"view_grid", _harness.settings.platform)[0], "K")
	assert_eq(Bindings.key_caps_for(&"view_names", _harness.settings.platform)[0], "B")

	# Reset keys restores default G / N and clears overrides
	options.reset_keys_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(options.key_caps_for_action(&"view_grid")[0].label().text, "G")
	assert_eq(options.key_caps_for_action(&"view_names")[0].label().text, "N")
	assert_true(_harness.settings.get_key_overrides().is_empty())


func test_back_button_discards_unapplied_staging_and_closes() -> void:
	var options := ScreenIds.make(&"options") as Options
	_harness.stack.push(options)
	await _harness.wait_frames(self, 2)

	var mode_opt := options.option_row("display/window_mode").control() as OptionButton
	mode_opt.select(1)
	mode_opt.item_selected.emit(1)
	assert_true(options.has_pending_display_changes())

	options.back_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.stack.count(), 0)
	assert_eq(_harness.settings.get_value("display/window_mode"), "windowed")


func test_graphics_page_texture_quality_presets_and_page_defaults() -> void:
	var options := ScreenIds.make(&"options") as Options
	_harness.stack.push(options)
	await _harness.wait_frames(self, 2)

	options.select_page(&"graphics")
	await _harness.wait_frames(self, 1)
	var preset_row := options.option_row("graphics/preset")
	var quality_row := options.option_row("graphics/texture_quality")
	var relief_row := options.option_row("graphics/relief_shading")
	assert_not_null(preset_row)
	assert_not_null(quality_row)
	assert_not_null(relief_row)

	var preset_opt := preset_row.control() as OptionButton
	var quality_opt := quality_row.control() as OptionButton
	var relief_sw := relief_row.control() as KitSwitch
	assert_not_null(preset_opt)
	assert_not_null(quality_opt)
	assert_not_null(relief_sw)

	# Select "low" (index 0) -> half textures, relief off, preload off, fps_cap 60
	preset_opt.select(0)
	preset_opt.item_selected.emit(0)
	assert_eq(_harness.settings.get_value("graphics/preset"), "low")
	assert_eq(_harness.settings.get_value("graphics/texture_quality"), "half")
	assert_eq(_harness.settings.get_value("graphics/relief_shading"), false)
	assert_eq(_harness.settings.get_value("graphics/preload_next_season"), false)
	assert_eq(_harness.settings.get_value("display/fps_cap"), 60)
	assert_eq(quality_opt.selected, 1, "Texture quality row synced to Half")
	assert_false(relief_sw.button_pressed, "Relief shading switch synced off")

	# Flip relief shading back on -> preset row updates to Custom (index 3)
	relief_sw.button_pressed = true
	assert_eq(_harness.settings.get_value("graphics/preset"), "custom")
	assert_eq(preset_opt.selected, 3)

	# Defaults for this page resets graphics rows without clobbering Display/Advanced
	options.defaults_button().pressed.emit()
	await _harness.wait_frames(self, 1)
	assert_eq(_harness.settings.get_value("graphics/texture_quality"), _harness.settings.get_default("graphics/texture_quality"))
	assert_eq(_harness.settings.get_value("graphics/relief_shading"), true)
	assert_eq(_harness.settings.get_value("display/fps_cap"), 60, "Display fps_cap preserved")
	assert_eq(_harness.settings.get_value("graphics/preload_next_season"), false, "Advanced preload preserved")


func test_game_page_shows_the_three_milestone_three_rows() -> void:
	var options := ScreenIds.make(&"options") as Options
	_harness.stack.push(options)
	await _harness.wait_frames(self, 2)

	options.nav_list().select(&"game", true)
	await _harness.wait_frames(self, 1)
	assert_eq(options.current_page(), &"game")
	var keys: Array[String] = []
	for row: OptionRow in options.page_rows(&"game"):
		keys.append(row.key())
	keys.sort()
	assert_eq(keys, ["game/autosave", "game/season_report", "game/task_flag"])
	assert_not_null(options.option_row("graphics/season_change"), "Season change on Graphics")
	assert_not_null(options.option_row("dev/save_json"), "Write saves as JSON too on Advanced")
	assert_null(options.option_row("game/confirm_works"), "milestone 4 rows stay hidden")


## Pages are built when first needed: only Display at the start, the rest on a page switch or an accessor, and the rows are
## the same as when everything was built at once.
func test_pages_build_lazily_and_every_accessor_still_reaches_its_rows() -> void:
	var options := ScreenIds.make(&"options") as Options
	_harness.stack.push(options)
	await _harness.wait_frames(self, 2)
	var rows_of_display := options.page_rows(&"display").size()
	assert_gt(rows_of_display, 0, "Display is built at once")
	assert_eq(options.get_node("Center/Frame").find_child("AccessibilityPage", true, false).find_child("Rows", true, false).get_child_count(), 0, "Accessibility waits")
	assert_eq(options.get_node("Center/Frame").find_child("ControlsPage", true, false).find_child("Rows", true, false).get_child_count(), 0, "Controls waits")

	# An accessor builds the page it needs.
	assert_not_null(options.option_row("accessibility/reduce_motion"))
	assert_not_null(options.rebind_button_for(&"app_back"))
	assert_not_null(options.about_copy_button())
	# A page switch builds its page too.
	options.select_page(&"map")
	assert_gt(options.page_rows(&"map").size(), 0)
	# Every schema row with a page at or under the milestone has exactly one row once all are asked for.
	var expected := 0
	for key: String in Settings.SCHEMA.keys():
		var entry: Dictionary = Settings.SCHEMA[key]
		if not str(entry.get("page", "")).is_empty() and float(str(entry.get("since", "1.5"))) <= Options.TARGET_MILESTONE:
			expected += 1
	assert_eq(options.option_rows().size(), expected, "lazy pages give the same rows as the old build")
