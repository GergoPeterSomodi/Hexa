## Tests for Settings and ShellContext (docs/architecture/ui-and-controls-spec.md sections 3.2, 6, 9;
## docs/architecture/ui-style-and-feedback-spec.md section 9).
extends GutTest

var _temp_paths: Array[String] = []


func after_each() -> void:
	for p: String in _temp_paths:
		var global_p := ProjectSettings.globalize_path(p)
		if DirAccess.dir_exists_absolute(global_p):
			DirAccess.remove_absolute(global_p)
		elif FileAccess.file_exists(global_p):
			DirAccess.remove_absolute(global_p)
		var tmp_p := global_p + ".tmp"
		if DirAccess.dir_exists_absolute(tmp_p):
			DirAccess.remove_absolute(tmp_p)
		elif FileAccess.file_exists(tmp_p):
			DirAccess.remove_absolute(tmp_p)
	_temp_paths.clear()


func _tmp_file(suffix: String) -> String:
	var p := "/tmp/test_settings_%s_%d.cfg" % [suffix, Time.get_ticks_usec()]
	_temp_paths.append(p)
	return p


func test_round_trip_save_and_load() -> void:
	var path := _tmp_file("round_trip")
	var s := Settings.new("macOS", false)
	var changed_keys: Array[String] = []
	s.changed.connect(func(key: String, _val: Variant) -> void: changed_keys.append(key))

	assert_true(s.set_value("display/window_mode", "fullscreen"))
	assert_true(s.set_value("display/window_preset", "1920x1080"))
	assert_true(s.set_value("display/window_position", Vector2i(120, 80)))
	assert_true(s.set_value("display/window_size", Vector2i(1600, 900)))
	assert_true(s.set_value("display/maximized", true))
	assert_true(s.set_value("display/screen", 2))
	assert_true(s.set_value("display/vsync", "adaptive"))
	assert_true(s.set_value("display/fps_cap", 60))
	assert_true(s.set_value("display/background_fps", 5))
	assert_true(s.set_value("display/power_saving", false))
	assert_true(s.set_value("display/ui_scale", "150"))
	assert_true(s.set_value("graphics/relief_shading", false))
	assert_true(s.set_value("graphics/preload_next_season", false))
	assert_true(s.set_value("controls/pan_speed", 140))
	assert_true(s.set_value("controls/zoom_speed", 125))
	assert_true(s.set_value("controls/zoom_smoothing", false))
	assert_true(s.set_value("controls/zoom_anchor", "centre"))
	assert_true(s.set_value("controls/edge_pan", true))
	assert_true(s.set_value("controls/edge_pan_speed", 150))
	assert_true(s.set_value("map/grid", true))
	assert_true(s.set_value("map/grid_opacity", 65))
	assert_true(s.set_value("map/place_names", true))
	assert_true(s.set_value("accessibility/reduce_motion", true))
	assert_true(s.set_value("accessibility/tooltip_delay", "short"))
	assert_true(s.set_value("dev/developer_tools", false))
	assert_true(s.set_value("dev/ui_kit", "2x"))
	assert_true(s.set_value("dev/far_zoom", 0.35))
	assert_true(s.set_value("dev/slice_ms", 8))
	assert_true(s.set_value("state/help_seen", true))
	assert_true(s.set_value("game/season_report", "brief"))
	assert_true(s.set_value("game/confirm_works", "always"))
	assert_true(s.set_value("game/preview_on_map", false))
	assert_true(s.set_value("game/gain_treasury_only", true))
	assert_true(s.set_value("state/study_page", "rankings"))
	assert_true(s.set_value("state/study_span", 40))

	assert_gt(changed_keys.size(), 0, "changed signal emitted")
	assert_true(s.save_to(path), "saved to temp path")

	var loaded := Settings.load_from(path, "macOS", false)
	for key: String in Settings.SCHEMA.keys():
		if typeof(s.get_value(key)) == TYPE_FLOAT:
			assert_almost_eq(float(loaded.get_value(key)), float(s.get_value(key)), 0.0001, key)
		else:
			assert_eq(loaded.get_value(key), s.get_value(key), key)


func test_corrupt_file_falls_back_to_defaults() -> void:
	var path := _tmp_file("corrupt")
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(f)
	f.store_string("{{{not a valid config file\n[unclosed\nbroken_line_without_equals\n")
	f.close()

	var loaded := Settings.load_from(path, "macOS", false)
	for key: String in Settings.SCHEMA.keys():
		assert_eq(loaded.get_value(key), loaded.get_default(key), "default kept for " + key)


func test_wrong_type_unknown_key_and_out_of_range_fall_back_to_defaults() -> void:
	var path := _tmp_file("invalid_vals")
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(f)
	f.store_string(
		"[display]\n"
		+ "window_mode = \"borderless_invalid\"\n"
		+ "fps_cap = \"sixty\"\n"
		+ "screen = 999\n"
		+ "window_size = Vector2i(320, 200)\n"
		+ "unknown_display_key = 123\n"
		+ "[controls]\n"
		+ "pan_speed = 10\n"
		+ "zoom_speed = 500\n"
		+ "invert_scroll = \"yes\"\n"
		+ "[dev]\n"
		+ "far_zoom = 5.0\n"
		+ "slice_ms = 1\n"
		+ "[mystery_section]\n"
		+ "foo = \"bar\"\n"
	)
	f.close()

	var loaded := Settings.load_from(path, "macOS", false)
	assert_eq(loaded.get_value("display/window_mode"), "windowed")
	assert_eq(loaded.get_value("display/fps_cap"), 0)
	assert_eq(loaded.get_value("display/screen"), 0)
	assert_eq(loaded.get_value("display/window_size"), Vector2i(1280, 720))
	assert_null(loaded.get_value("display/unknown_display_key"))
	assert_null(loaded.get_value("mystery_section/foo"))
	assert_eq(loaded.get_value("controls/pan_speed"), 100)
	assert_eq(loaded.get_value("controls/zoom_speed"), 100)
	assert_eq(loaded.get_value("controls/invert_scroll"), false)
	assert_almost_eq(float(loaded.get_value("dev/far_zoom")), 0.20, 0.0001)
	assert_eq(loaded.get_value("dev/slice_ms"), 5)

	assert_false(loaded.set_value("unknown/key", 1))
	assert_false(loaded.set_value("display/window_mode", 123))
	assert_false(loaded.set_value("display/window_mode", "not_a_mode"))
	assert_false(loaded.set_value("controls/pan_speed", 49))
	assert_false(loaded.set_value("controls/pan_speed", 201))
	assert_false(loaded.set_value("display/window_size", Vector2i(800, 600)))
	assert_false(loaded.set_value("dev/far_zoom", 0.01))
	assert_false(loaded.set_value("dev/far_zoom", 0.95))


func test_object_injection_is_rejected() -> void:
	var s := Settings.new("macOS", false)
	var dummy_obj := RefCounted.new()
	assert_false(s.set_value("display/window_mode", dummy_obj))
	assert_eq(s.get_value("display/window_mode"), "windowed")

	var path := _tmp_file("object_inject")
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(f)
	f.store_string(
		"[display]\n"
		+ "window_mode = Object(RefCounted)\n"
		+ "vsync = \"off\"\n"
	)
	f.close()

	var loaded := Settings.load_from(path, "macOS", false)
	assert_eq(loaded.get_value("display/window_mode"), "windowed")
	assert_eq(loaded.get_value("display/vsync"), "off")


func test_reset_page_restores_only_that_page() -> void:
	var s := Settings.new("macOS", false)
	assert_true(s.set_value("display/vsync", "off"))
	assert_true(s.set_value("display/fps_cap", 60))
	assert_true(s.set_value("map/grid", true))
	assert_true(s.set_value("map/grid_opacity", 40))

	s.reset_page("display")
	assert_eq(s.get_value("display/vsync"), "on")
	assert_eq(s.get_value("display/fps_cap"), 0)
	assert_eq(s.get_value("map/grid"), true, "map page untouched")
	assert_eq(s.get_value("map/grid_opacity"), 40, "map page untouched")


func test_controls_device_preset_updates_wheel_and_gesture_actions() -> void:
	var s := Settings.new("macOS", false)
	assert_eq(s.get_value("controls/device"), "both")
	assert_eq(s.get_value("controls/wheel_action"), "zoom")
	assert_eq(s.get_value("controls/gesture_action"), "pan")

	assert_true(s.set_value("controls/device", "mouse"))
	assert_eq(s.get_value("controls/wheel_action"), "zoom")
	assert_eq(s.get_value("controls/gesture_action"), "zoom")

	assert_true(s.set_value("controls/device", "trackpad"))
	assert_eq(s.get_value("controls/wheel_action"), "pan")
	assert_eq(s.get_value("controls/gesture_action"), "pan")

	assert_true(s.set_value("controls/device", "both"))
	assert_eq(s.get_value("controls/wheel_action"), "zoom")
	assert_eq(s.get_value("controls/gesture_action"), "pan")


func test_platform_defaults_and_reduce_motion_first_run() -> void:
	var missing := _tmp_file("nonexistent")
	var mac := Settings.load_from(missing, "macOS", true)
	var win := Settings.load_from(missing, "Windows", false)

	assert_eq(mac.platform, "macOS")
	assert_eq(win.platform, "Windows")
	assert_eq(mac.choices_for("display/window_mode"), ["windowed", "fullscreen"])
	assert_eq(win.choices_for("display/window_mode"), ["windowed", "fullscreen", "exclusive"])
	assert_false(mac.set_value("display/window_mode", "exclusive"), "exclusive rejected on macOS")
	assert_true(win.set_value("display/window_mode", "exclusive"), "exclusive allowed on Windows")
	assert_eq(mac.get_value("accessibility/reduce_motion"), true, "follows system reduce_motion on first run")
	assert_eq(win.get_value("accessibility/reduce_motion"), false)

	var saved_path := _tmp_file("saved_reduce_motion")
	assert_true(mac.set_value("accessibility/reduce_motion", false))
	assert_true(mac.save_to(saved_path))
	var reloaded := Settings.load_from(saved_path, "macOS", true)
	assert_eq(reloaded.get_value("accessibility/reduce_motion"), false, "saved choice overrides first-run default")


func test_atomic_write_preserves_previous_valid_file_on_failure() -> void:
	var path := _tmp_file("atomic")
	var first := Settings.new("macOS", false)
	assert_true(first.set_value("display/fps_cap", 30))
	assert_true(first.save_to(path))

	var global_tmp := ProjectSettings.globalize_path(path + ".tmp")
	assert_eq(DirAccess.make_dir_absolute(global_tmp), OK, "occupy .tmp path with a directory so write fails")

	var second := Settings.new("macOS", false)
	assert_true(second.set_value("display/fps_cap", 120))
	assert_false(second.save_to(path), "save_to fails when .tmp cannot be written")

	var check := Settings.load_from(path, "macOS", false)
	assert_eq(check.get_value("display/fps_cap"), 30, "previous valid file is preserved")


func test_key_overrides_round_trip() -> void:
	var path := _tmp_file("keys")
	var s := Settings.new("macOS", false)
	s.set_key_override("view_grid", "Key:H")
	s.set_key_override("cam_fit", "Key:Home")
	assert_eq(s.get_key_overrides(), {"view_grid": "Key:H", "cam_fit": "Key:Home"})
	assert_true(s.save_to(path))

	var loaded := Settings.load_from(path, "macOS", false)
	assert_eq(loaded.get_key_overrides(), {"view_grid": "Key:H", "cam_fit": "Key:Home"})

	loaded.set_key_override("view_grid", "")
	assert_false(loaded.get_key_overrides().has("view_grid"))


func test_every_m1_5_schema_key_with_page_is_valid() -> void:
	var s := Settings.new("Windows", false)
	var count_1_5 := 0
	for key: String in Settings.SCHEMA.keys():
		var entry: Dictionary = Settings.SCHEMA[key]
		assert_true(entry.has("type"), key + " has type")
		assert_true(entry.has("default"), key + " has default")
		assert_true(entry.has("page"), key + " has page")
		assert_true(entry.has("since"), key + " has since")
		assert_true(entry.has("label"), key + " has label")
		assert_true(entry.has("applies"), key + " has applies")
		assert_true(Settings.is_valid_value(key, entry["default"]), key + " default is valid")
		if str(entry["since"]) == "1.5" and not str(entry["page"]).is_empty():
			count_1_5 += 1
			assert_eq(s.get_value(key), entry["default"], key + " starts at default")
	assert_gt(count_1_5, 15, "all M1.5 page rows are present")


func test_shell_context_signals_and_convenience_methods() -> void:
	var s := Settings.new("macOS", false)
	var dummy_stack := Control.new()
	add_child_autofree(dummy_stack)
	var ctx := ShellContext.new(s, dummy_stack)
	assert_eq(ctx.settings, s)
	assert_eq(ctx.stack, dummy_stack)

	var toasts: Array[Dictionary] = []
	var requests: Array[Dictionary] = []
	ctx.toast_requested.connect(func(t: String, tone: StringName) -> void:
		toasts.append({"text": t, "tone": tone})
	)
	ctx.app_requested.connect(func(what: StringName, args: Dictionary) -> void:
		requests.append({"what": what, "args": args})
	)

	ctx.toast("Saved")
	ctx.toast("Cannot build", &"bad")
	ctx.request(&"new_sandbox", {"seed": 42})

	assert_eq(toasts.size(), 2)
	assert_eq(toasts[0], {"text": "Saved", "tone": &"plain"})
	assert_eq(toasts[1], {"text": "Cannot build", "tone": &"bad"})
	assert_eq(requests.size(), 1)
	assert_eq(requests[0], {"what": &"new_sandbox", "args": {"seed": 42}})
