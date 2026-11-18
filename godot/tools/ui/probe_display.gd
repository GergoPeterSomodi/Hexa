## Display, HiDPI, window-mode, vsync, tooltip-delay, and low-processor probe
## (docs/architecture/ui-and-controls-spec.md sections 5.3, 6.2, 9; ui-and-controls-plan.md U8).
##
## Run windowed (interactive/CI):
##   godot --path godot -s res://tools/ui/probe_display.gd -- [--fullscreen] [--hidpi] [--low-proc] [--hold]
## Run headless: prints platform/DPI/Display metrics and exits 0 cleanly.
extends SceneTree

var _want_fullscreen := false
var _want_hidpi := false
var _want_low_proc := false
var _hold := false
var _passes := 0
var _fails := 0
var _skips := 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--fullscreen":
			_want_fullscreen = true
		elif arg == "--hidpi":
			_want_hidpi = true
		elif arg == "--low-proc":
			_want_low_proc = true
		elif arg == "--hold":
			_hold = true
	_run()


func _run() -> void:
	await process_frame
	var headless := DisplayServer.get_name() == "headless"
	print("probe_display: platform=%s driver=%s headless=%s" % [
		OS.get_name(), RenderingServer.get_current_rendering_driver_name(), str(headless)
	])

	_print_screen_metrics(headless)
	await _check_content_scale(headless)
	_check_min_size(headless)
	_check_vsync(headless)
	_check_tooltip_delay()
	_check_low_processor_mode()
	_check_hover_control_api()
	_check_close_request_setup()
	if _want_fullscreen:
		await _check_fullscreen_roundtrip(headless)

	print("probe_display: summary PASS=%d FAIL=%d SKIP=%d" % [_passes, _fails, _skips])
	if _hold and not headless:
		if not root.close_requested.is_connected(_on_close_requested):
			root.close_requested.connect(_on_close_requested)
		print("probe_display: --hold active; press Cmd+Q / close window to test close_requested")
		return
	quit(1 if _fails > 0 else 0)


func _on_close_requested() -> void:
	print("probe_display: received Window.close_requested (PASS)")
	quit(0)


func _print_screen_metrics(headless: bool) -> void:
	if headless:
		print("probe_display: screens=0 (headless dummy display)")
		return
	var count := DisplayServer.get_screen_count()
	print("probe_display: screen_count=%d primary=%d" % [count, DisplayServer.get_primary_screen()])
	for i: int in range(count):
		var sz := DisplayServer.screen_get_size(i)
		var usable := DisplayServer.screen_get_usable_rect(i)
		var scale := DisplayServer.screen_get_scale(i)
		var dpi := DisplayServer.screen_get_dpi(i)
		var auto_s := Display.auto_scale(OS.get_name(), scale, dpi)
		print("  screen[%d]: size=%s usable=%s scale=%.2f dpi=%d auto_scale=%.2f" % [
			i, str(sz), str(usable), scale, dpi, auto_s
		])


func _check_content_scale(headless: bool) -> void:
	var scale := 2.0 if _want_hidpi else 1.0
	if not headless and not _want_hidpi and DisplayServer.get_screen_count() > 0:
		var scr := clampi(root.current_screen, 0, DisplayServer.get_screen_count() - 1)
		scale = Display.auto_scale(OS.get_name(), DisplayServer.screen_get_scale(scr), DisplayServer.screen_get_dpi(scr))
	root.content_scale_factor = scale
	root.content_scale_size = root.size
	await process_frame
	var vis := root.get_visible_rect().size
	if headless:
		_record_skip("content_scale", "headless window size is %s (scale=%.2fx)" % [str(root.size), scale])
		return
	var expected_vis := Vector2(Display.logical_size(root.size, scale))
	if is_equal_approx(root.content_scale_factor, scale) and vis.x > 0.0 and vis.y > 0.0 and vis.distance_to(expected_vis) <= 2.0:
		_record_pass("content_scale", "factor=%.2f content_scale_size=%s visible_rect=%s" % [scale, str(root.content_scale_size), str(vis)])
	else:
		_record_fail("content_scale", "expected visible_rect~=%s, got %s for scale=%.2f" % [str(expected_vis), str(vis), scale])


func _check_min_size(headless: bool) -> void:
	root.min_size = Display.MIN_SIZE
	if headless:
		_record_skip("min_size", "set Display.MIN_SIZE=%s (no OS window in headless)" % str(Display.MIN_SIZE))
		return
	if root.min_size == Display.MIN_SIZE:
		_record_pass("min_size", "Window.min_size=%s" % str(root.min_size))
	else:
		_record_fail("min_size", "expected %s, got %s" % [str(Display.MIN_SIZE), str(root.min_size)])


func _check_vsync(headless: bool) -> void:
	if headless:
		_record_skip("vsync_fallback", "no OS swapchain in headless")
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
	var readback := DisplayServer.window_get_vsync_mode()
	var valid := readback in [DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_ADAPTIVE]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	if valid:
		_record_pass("vsync_fallback", "ADAPTIVE readback=%d (fallback safe)" % readback)
	else:
		_record_fail("vsync_fallback", "unexpected vsync mode %d" % readback)


func _check_tooltip_delay() -> void:
	var prev: Variant = ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5)
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 0.2)
	var after := float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5))
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", prev)
	if is_equal_approx(after, 0.2):
		_record_pass("tooltip_delay_live", "gui/timers/tooltip_delay_sec updated to %.2f s" % after)
	else:
		_record_fail("tooltip_delay_live", "expected 0.2, got %.2f" % after)


func _check_low_processor_mode() -> void:
	var prev := OS.low_processor_usage_mode
	var target := true if _want_low_proc else bool(ProjectSettings.get_setting("application/run/low_processor_mode", true))
	OS.low_processor_usage_mode = target
	var actual := OS.low_processor_usage_mode
	OS.low_processor_usage_mode = prev
	if actual == target:
		_record_pass("low_processor_mode", "OS.low_processor_usage_mode=%s" % str(actual))
	else:
		_record_fail("low_processor_mode", "expected %s, got %s" % [str(target), str(actual)])


func _check_hover_control_api() -> void:
	var hovered := root.gui_get_hovered_control()
	_record_pass("gui_get_hovered_control", "callable (current=%s)" % str(hovered))


func _check_close_request_setup() -> void:
	var prev := auto_accept_quit
	auto_accept_quit = false
	var ok := not auto_accept_quit
	auto_accept_quit = prev
	if ok:
		_record_pass("wm_close_request", "auto_accept_quit=false armed cleanly")
	else:
		_record_fail("wm_close_request", "could not set auto_accept_quit=false")


func _check_fullscreen_roundtrip(headless: bool) -> void:
	if headless:
		_record_skip("fullscreen_roundtrip", "no OS window in headless")
		return
	var prev_mode := root.mode
	root.mode = Window.MODE_FULLSCREEN
	await process_frame
	var fs_mode := root.mode
	root.mode = prev_mode
	await process_frame
	if fs_mode == Window.MODE_FULLSCREEN or root.mode == prev_mode:
		_record_pass("fullscreen_roundtrip", "toggled fullscreen (%d) and restored (%d)" % [fs_mode, root.mode])
	else:
		_record_fail("fullscreen_roundtrip", "fullscreen=%d restored=%d" % [fs_mode, root.mode])


func _record_pass(fact: String, detail: String) -> void:
	_passes += 1
	print("  PASS [%s]: %s" % [fact, detail])


func _record_fail(fact: String, detail: String) -> void:
	_fails += 1
	printerr("  FAIL [%s]: %s" % [fact, detail])


func _record_skip(fact: String, detail: String) -> void:
	_skips += 1
	print("  SKIP [%s]: %s" % [fact, detail])
