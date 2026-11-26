## Tests for Display pure helpers and headless-safe Display.apply
## (docs/architecture/ui-and-controls-spec.md sections 6.2 and 9).
extends GutTest


func test_auto_scale_on_macos_and_windows() -> void:
	assert_almost_eq(Display.auto_scale("macOS", 2.0, 144), 2.0, 0.001, "Retina Mac -> 2.0")
	assert_almost_eq(Display.auto_scale("macOS", 1.0, 72), 1.0, 0.001, "Standard Mac -> 1.0")
	assert_almost_eq(Display.auto_scale("macOS", 1.5, 110), 1.5, 0.001, "1.5x Mac -> 1.5")

	assert_almost_eq(Display.auto_scale("Windows", 1.0, 96), 1.0, 0.001, "Windows 96 dpi -> 1.0")
	assert_almost_eq(Display.auto_scale("Windows", 1.0, 120), 1.25, 0.001, "Windows 120 dpi -> 1.25")
	assert_almost_eq(Display.auto_scale("Windows", 1.0, 144), 1.5, 0.001, "Windows 144 dpi -> 1.5")
	assert_almost_eq(Display.auto_scale("Windows", 1.0, 192), 2.0, 0.001, "Windows 192 dpi -> 2.0")
	assert_almost_eq(Display.auto_scale("Windows", 1.0, 300), 2.0, 0.001, "Clamped at 2.0")
	assert_almost_eq(Display.auto_scale("Windows", 1.0, 48), 0.75, 0.001, "Clamped at 0.75")


func test_resolve_ui_scale() -> void:
	assert_almost_eq(Display.resolve_ui_scale("auto", "macOS", 2.0, 144), 2.0, 0.001)
	assert_almost_eq(Display.resolve_ui_scale("auto", "Windows", 1.0, 120), 1.25, 0.001)
	assert_almost_eq(Display.resolve_ui_scale("75", "macOS", 2.0, 144), 0.75, 0.001)
	assert_almost_eq(Display.resolve_ui_scale("100", "macOS", 2.0, 144), 1.0, 0.001)
	assert_almost_eq(Display.resolve_ui_scale("125", "macOS", 2.0, 144), 1.25, 0.001)
	assert_almost_eq(Display.resolve_ui_scale("150", "macOS", 2.0, 144), 1.5, 0.001)
	assert_almost_eq(Display.resolve_ui_scale("175", "macOS", 2.0, 144), 1.75, 0.001)
	assert_almost_eq(Display.resolve_ui_scale("200", "macOS", 1.0, 96), 2.0, 0.001)


func test_presets_for_usable_rect() -> void:
	assert_eq(
		Display.presets_for(Vector2i(1366, 768)),
		["custom", "1280x720"] as Array[String]
	)
	assert_eq(
		Display.presets_for(Vector2i(1920, 1080)),
		["custom", "1280x720", "1600x900", "1920x1080"] as Array[String]
	)
	assert_eq(
		Display.presets_for(Vector2i(3840, 2160)),
		["custom", "1280x720", "1600x900", "1920x1080", "2560x1440"] as Array[String]
	)
	assert_eq(
		Display.presets_for(Vector2i(1024, 600)),
		["custom"] as Array[String]
	)


func test_window_rect_keeps_valid_saved_position_and_centres_off_screen() -> void:
	var screens: Array[Rect2i] = [
		Rect2i(Vector2i(0, 0), Vector2i(1920, 1080)),
		Rect2i(Vector2i(1920, 0), Vector2i(2560, 1440)),
	]

	var first_run := Display.window_rect(Vector2i(-1, -1), Vector2i(1280, 720), screens, 0)
	assert_eq(first_run.size, Vector2i(1280, 720))
	assert_eq(first_run.position, Vector2i(320, 180), "first run centred on primary screen")

	var kept := Display.window_rect(Vector2i(2100, 120), Vector2i(1600, 900), screens, 0)
	assert_eq(kept.position, Vector2i(2100, 120), "valid position on second screen is kept")
	assert_eq(kept.size, Vector2i(1600, 900))

	var off_screen := Display.window_rect(Vector2i(-2000, 5000), Vector2i(1280, 720), screens, 0)
	assert_eq(off_screen.position, Vector2i(320, 180), "off-screen position moved to primary screen centre")
	assert_eq(off_screen.size, Vector2i(1280, 720))

	var too_small := Display.window_rect(Vector2i(100, 100), Vector2i(640, 400), screens, 0)
	assert_eq(too_small.size, Display.MIN_SIZE, "clamped up to MIN_SIZE")

	var too_large := Display.window_rect(Vector2i(50, 50), Vector2i(4000, 3000), screens, 0)
	assert_eq(too_large.size, Vector2i(1920, 1080), "clamped down to screen size")

	var retina_screens: Array[Rect2i] = [Rect2i(Vector2i(0, 0), Vector2i(3024, 1898))]
	var retina_min := Display.window_rect(Vector2i(-1, -1), Vector2i(1280, 720), retina_screens, 0, Vector2i(2048, 1200))
	assert_eq(retina_min.size, Vector2i(2048, 1200), "clamps up to scaled Retina min_size_px")


func test_logical_size_and_tooltip_delay() -> void:
	assert_eq(Display.logical_size(Vector2i(2560, 1440), 2.0), Vector2i(1280, 720))
	assert_eq(Display.logical_size(Vector2i(1920, 1080), 1.5), Vector2i(1280, 720))
	assert_eq(Display.logical_size(Vector2i(1280, 720), 1.0), Vector2i(1280, 720))

	assert_almost_eq(Display.tooltip_delay_seconds("short"), 0.2, 0.001)
	assert_almost_eq(Display.tooltip_delay_seconds("normal"), 0.5, 0.001)
	assert_almost_eq(Display.tooltip_delay_seconds("long"), 1.0, 0.001)


## Issue 461: "auto" is the screen's own scale only, so a large window on a 96 dpi screen draws the UI at 1.0.
func test_auto_is_the_default_and_ignores_the_window_size() -> void:
	var s := Settings.new("Windows", false)
	assert_eq(str(s.get_value("display/ui_scale")), "auto", "auto is the default")
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]:
		var win := Window.new()
		win.size = size
		add_child_autofree(win)
		Display.apply(win, s)
		assert_almost_eq(win.content_scale_factor, 1.0, 0.001, "auto at %s" % size)
	assert_almost_eq(Display.resolve_ui_scale("auto", "Windows", 1.0, 96), 1.0, 0.001)


func test_a_saved_percentage_still_applies() -> void:
	var path := "user://test_display_ui_scale.cfg"
	var saved := Settings.new("Windows", false)
	assert_true(saved.set_value("display/ui_scale", "150"))
	assert_true(saved.save_to(path))
	var loaded := Settings.load_from(path)
	assert_eq(str(loaded.get_value("display/ui_scale")), "150")
	var win := Window.new()
	win.size = Vector2i(2560, 1440)
	add_child_autofree(win)
	Display.apply(win, loaded)
	assert_almost_eq(win.content_scale_factor, 1.5, 0.001)
	DirAccess.remove_absolute(path)


func test_headless_safe_apply() -> void:
	var old_fps := Engine.max_fps
	var old_low_proc := OS.low_processor_usage_mode
	var old_delay := float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5))

	var s := Settings.new("macOS", false)
	assert_true(s.set_value("display/fps_cap", 60))
	assert_true(s.set_value("display/power_saving", false))
	assert_true(s.set_value("display/ui_scale", "125"))
	assert_true(s.set_value("accessibility/tooltip_delay", "short"))

	var win := Window.new()
	win.size = Vector2i(1600, 1000)
	add_child_autofree(win)

	Display.apply(win, s)
	assert_eq(Engine.max_fps, 60)
	assert_eq(OS.low_processor_usage_mode, false)
	assert_almost_eq(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")), 0.2, 0.001)
	assert_eq(win.min_size, Display.MIN_SIZE)
	assert_almost_eq(win.content_scale_factor, 1.25, 0.001)
	assert_eq(win.content_scale_size, Vector2i(1600, 1000))

	Engine.max_fps = old_fps
	OS.low_processor_usage_mode = old_low_proc
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", old_delay)
