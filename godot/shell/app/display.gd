## Window, screen, UI-scale and frame-rate helpers (docs/architecture/ui-and-controls-spec.md section 6.2).
## The pure calculations take explicit platform and screen parameters so they can be tested headless
## without touching DisplayServer; apply() guards DisplayServer calls when running headless.
class_name Display
extends RefCounted

const MIN_SIZE := Vector2i(1024, 600)
const DEFAULT_SIZE := Vector2i(1280, 720)
const PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]


static func auto_scale(platform: String, screen_scale: float, screen_dpi: int) -> float:
	if platform == "macOS":
		var raw_mac: float = screen_scale if screen_scale > 0.0 else 1.0
		return clampf(roundf(raw_mac * 4.0) / 4.0, 0.75, 2.0)
	var dpi: int = screen_dpi if screen_dpi > 0 else 96
	var raw_dpi: float = float(dpi) / 96.0
	return clampf(roundf(raw_dpi * 4.0) / 4.0, 0.75, 2.0)


static func resolve_ui_scale(
	ui_scale_setting: String,
	platform: String,
	screen_scale: float,
	screen_dpi: int
) -> float:
	if ui_scale_setting == "auto" or not ui_scale_setting.is_valid_int():
		return auto_scale(platform, screen_scale, screen_dpi)
	var pct := float(ui_scale_setting.to_int()) / 100.0
	return clampf(pct, 0.75, 2.0)


static func presets_for(usable_rect_points: Vector2i) -> Array[String]:
	var result: Array[String] = ["custom"]
	for preset: Vector2i in PRESETS:
		if preset.x <= usable_rect_points.x and preset.y <= usable_rect_points.y:
			result.append("%dx%d" % [preset.x, preset.y])
	return result


static func parse_preset(preset: String) -> Vector2i:
	var parts := preset.split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i.ZERO
	return Vector2i(parts[0].to_int(), parts[1].to_int())


static func window_rect(
	saved_pos: Vector2i,
	saved_size: Vector2i,
	screen_rects: Array[Rect2i],
	primary_screen: int = 0
) -> Rect2i:
	if screen_rects.is_empty():
		var fallback_size := Vector2i(
			maxi(saved_size.x, MIN_SIZE.x),
			maxi(saved_size.y, MIN_SIZE.y)
		)
		var fallback_pos := saved_pos if saved_pos != Vector2i(-1, -1) else Vector2i.ZERO
		return Rect2i(fallback_pos, fallback_size)

	var primary_idx: int = clampi(primary_screen, 0, screen_rects.size() - 1)
	var target_screen: Rect2i = screen_rects[primary_idx]
	var keep_pos := false

	if saved_pos != Vector2i(-1, -1):
		for rect: Rect2i in screen_rects:
			if rect.has_point(saved_pos):
				target_screen = rect
				keep_pos = true
				break

	var max_w: int = maxi(MIN_SIZE.x, target_screen.size.x)
	var max_h: int = maxi(MIN_SIZE.y, target_screen.size.y)
	var clamped_size := Vector2i(
		clampi(saved_size.x, MIN_SIZE.x, max_w),
		clampi(saved_size.y, MIN_SIZE.y, max_h)
	)

	if keep_pos:
		return Rect2i(saved_pos, clamped_size)

	var offset_x := int(floorf(float(target_screen.size.x - clamped_size.x) * 0.5))
	var offset_y := int(floorf(float(target_screen.size.y - clamped_size.y) * 0.5))
	var centred_pos := target_screen.position + Vector2i(offset_x, offset_y)
	return Rect2i(centred_pos, clamped_size)


static func logical_size(window_px: Vector2i, ui_scale: float) -> Vector2i:
	var safe_scale: float = maxf(ui_scale, 0.01)
	return Vector2i(
		roundi(float(window_px.x) / safe_scale),
		roundi(float(window_px.y) / safe_scale)
	)


static func tooltip_delay_seconds(choice: String) -> float:
	match choice:
		"short":
			return 0.2
		"long":
			return 1.0
		_:
			return 0.5


static func apply(window: Window, settings: Settings) -> void:
	if settings == null:
		return
	Engine.max_fps = int(settings.get_value("display/fps_cap"))
	OS.low_processor_usage_mode = bool(settings.get_value("display/power_saving"))
	var delay := tooltip_delay_seconds(str(settings.get_value("accessibility/tooltip_delay")))
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", delay)

	if window == null:
		return
	window.min_size = MIN_SIZE

	var is_headless := DisplayServer.get_name() == "headless"
	var screen_scale := 1.0
	var screen_dpi := 96

	if not is_headless:
		_apply_window_and_screen(window, settings)
		var scr: int = window.current_screen
		screen_scale = DisplayServer.screen_get_scale(scr)
		screen_dpi = DisplayServer.screen_get_dpi(scr)

	var scale := resolve_ui_scale(
		str(settings.get_value("display/ui_scale")),
		settings.platform,
		screen_scale,
		screen_dpi
	)
	window.content_scale_factor = scale
	window.content_scale_size = logical_size(window.size, scale)


static func _apply_window_and_screen(window: Window, settings: Settings) -> void:
	var screen_count: int = DisplayServer.get_screen_count()
	var screen_choice: int = int(settings.get_value("display/screen"))
	if screen_choice > 0 and screen_choice <= screen_count:
		window.current_screen = screen_choice - 1

	var vsync_choice := str(settings.get_value("display/vsync"))
	match vsync_choice:
		"off":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		"adaptive":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
		_:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)

	var mode_choice := str(settings.get_value("display/window_mode"))
	if mode_choice == "fullscreen":
		window.mode = Window.MODE_FULLSCREEN
		return
	if mode_choice == "exclusive":
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		return
	if bool(settings.get_value("display/maximized")):
		window.mode = Window.MODE_MAXIMIZED
		return

	window.mode = Window.MODE_WINDOWED
	var desired_size: Vector2i = settings.get_value("display/window_size") as Vector2i
	var preset_str := str(settings.get_value("display/window_preset"))
	if preset_str != "custom":
		var parsed := parse_preset(preset_str)
		if parsed != Vector2i.ZERO:
			desired_size = parsed

	var screen_rects: Array[Rect2i] = []
	for i: int in range(screen_count):
		screen_rects.append(DisplayServer.screen_get_usable_rect(i))
	var primary := DisplayServer.get_primary_screen()
	if screen_choice > 0 and screen_choice <= screen_count:
		primary = screen_choice - 1
	var saved_pos: Vector2i = settings.get_value("display/window_position") as Vector2i
	var rect := window_rect(saved_pos, desired_size, screen_rects, primary)
	window.size = rect.size
	window.position = rect.position
