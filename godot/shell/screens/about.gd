## About & diagnostics modal screen and shared diagnostics builder for Options
## (docs/architecture/ui-and-controls-spec.md section 5.6;
## docs/architecture/ui-style-and-feedback-spec.md section 2).
class_name About
extends Screen

const BYTES_PER_MB := 1048576.0

@onready var _frame: ModalFrame = $Center/Frame

var _handles: Dictionary = {}
var _close_btn: KitButton = null
var _last_copied_text: String = ""
var _clipboard_writer: Callable = Callable()
var _ui_built: bool = false


func _ready() -> void:
	_ensure_ui()
	refresh_diagnostics()


func on_enter() -> void:
	_ensure_ui()
	_handles["context"] = ctx
	var reduce := _reduce_motion()
	var buttons: Array[KitButton] = [copy_button(), open_folder_button(), credits_button(), _close_btn]
	for btn: KitButton in buttons:
		if btn != null:
			btn.reduce_motion = reduce
	refresh_diagnostics()


func back() -> bool:
	return false


func frame() -> ModalFrame:
	_ensure_ui()
	return _frame


func copy_button() -> KitButton:
	_ensure_ui()
	return _handles.get("copy_btn", null) as KitButton


func open_folder_button() -> KitButton:
	_ensure_ui()
	return _handles.get("open_folder_btn", null) as KitButton


func credits_button() -> KitButton:
	_ensure_ui()
	return _handles.get("credits_btn", null) as KitButton


func close_button() -> KitButton:
	_ensure_ui()
	return _close_btn


func status_label() -> Label:
	_ensure_ui()
	return _handles.get("status_lbl", null) as Label


func last_copied_text() -> String:
	return _last_copied_text


func set_clipboard_writer(writer: Callable) -> void:
	_clipboard_writer = writer


## Returns the full multi-line diagnostics text matching spec section 5.6.
func diagnostics_text() -> String:
	var settings: Settings = ctx.settings if ctx != null else null
	return format_diagnostics(settings, get_window())


## Refreshes the displayed diagnostics grid and preview block.
func refresh_diagnostics() -> void:
	_ensure_ui()
	if _handles.is_empty():
		return
	var settings: Settings = ctx.settings if ctx != null else null
	refresh_about_handles(_handles, settings, get_window())


## Copies diagnostics_text() to the clipboard and updates status/toast feedback.
func copy_diagnostics() -> String:
	_ensure_ui()
	var settings: Settings = ctx.settings if ctx != null else null
	var text := format_diagnostics(settings, get_window())
	_last_copied_text = perform_copy_diagnostics(text, ctx, _handles, _clipboard_writer)
	return _last_copied_text


## Collects every diagnostic row required by spec section 5.6.
static func collect_diagnostics(settings: Settings = null, window: Window = null) -> Array[Dictionary]:
	var app_name := str(ProjectSettings.get_setting("application/config/name", "Hexa"))
	var app_ver := str(ProjectSettings.get_setting("application/config/version", "0.3.0"))
	var eng_info := Engine.get_version_info()
	var eng_str := "Godot %d.%d.%d.%s (%s)" % [
		int(eng_info.get("major", 4)),
		int(eng_info.get("minor", 7)),
		int(eng_info.get("patch", 2)),
		str(eng_info.get("status", "stable")),
		str(eng_info.get("build", "official")),
	]

	var sys_str := "%s %s · %s · locale %s" % [
		OS.get_name(),
		OS.get_version(),
		OS.get_processor_name(),
		OS.get_locale(),
	]

	var render_method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility"))
	var render_driver := RenderingServer.get_current_rendering_driver_name()
	var renderer_str := "%s (%s)" % [render_method, render_driver]

	var adapter_name := RenderingServer.get_video_adapter_name()
	var adapter_vendor := RenderingServer.get_video_adapter_vendor()
	var adapter_api := RenderingServer.get_video_adapter_api_version()
	var gpu_parts: Array[String] = []
	gpu_parts.append(adapter_name if not adapter_name.is_empty() else "unavailable")
	if not adapter_vendor.is_empty():
		gpu_parts.append(adapter_vendor)
	if not adapter_api.is_empty():
		gpu_parts.append(adapter_api)
	var gpu_str := " · ".join(gpu_parts)

	var screen_str := _format_screen_line(settings, window)
	var mem_str := _format_memory_line()
	var game_str := _format_game_line()

	return [
		{"key": "Hexa version", "value": "%s %s" % [app_name, app_ver]},
		{"key": "Engine", "value": eng_str},
		{"key": "System", "value": sys_str},
		{"key": "Renderer", "value": renderer_str},
		{"key": "Graphics card", "value": gpu_str},
		{"key": "Screen", "value": screen_str},
		{"key": "Memory", "value": mem_str},
		{"key": "Game", "value": game_str},
		{"key": "Folders", "value": OS.get_user_data_dir()},
		{"key": "Settings file", "value": Settings.PATH},
	]


## Formats all spec section 5.6 diagnostic rows as plain text for bug reports.
static func format_diagnostics(settings: Settings = null, window: Window = null) -> String:
	var lines := PackedStringArray()
	for row: Dictionary in collect_diagnostics(settings, window):
		lines.append("%s: %s" % [str(row["key"]), str(row["value"])])
	return "\n".join(lines)


## Populates a VBoxContainer with the About diagnostics table, action buttons, status line, and preview.
static func build_about_content(
	parent: VBoxContainer,
	settings: Settings,
	context: ShellContext,
	window: Window,
	on_copy: Callable = Callable()
) -> Dictionary:
	var grid := GridContainer.new()
	grid.name = &"DiagnosticsGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(grid)

	var value_labels: Array[Label] = []
	for row: Dictionary in collect_diagnostics(settings, window):
		var k_lbl := Label.new()
		k_lbl.theme_type_variation = &"Hint"
		k_lbl.text = str(row["key"])
		grid.add_child(k_lbl)

		var v_lbl := Label.new()
		v_lbl.theme_type_variation = &"TableRow"
		v_lbl.text = str(row["value"])
		v_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(v_lbl)
		value_labels.append(v_lbl)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sep)

	var reduce := bool(settings.get_value("accessibility/reduce_motion")) if settings != null else false
	var actions_row := HBoxContainer.new()
	actions_row.name = &"ActionsRow"
	actions_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(actions_row)

	var copy_btn := KitButton.new()
	copy_btn.name = &"CopyDiagnosticsButton"
	copy_btn.kind = KitButton.Kind.PRIMARY
	copy_btn.text = "Copy diagnostics"
	copy_btn.reduce_motion = reduce
	actions_row.add_child(copy_btn)

	var open_btn := KitButton.new()
	open_btn.name = &"OpenDataFolderButton"
	open_btn.kind = KitButton.Kind.SECONDARY
	open_btn.text = "Open data folder"
	open_btn.reduce_motion = reduce
	actions_row.add_child(open_btn)

	var credits_btn := KitButton.new()
	credits_btn.name = &"CreditsButton"
	credits_btn.kind = KitButton.Kind.SECONDARY
	credits_btn.text = "Credits"
	credits_btn.reduce_motion = reduce
	actions_row.add_child(credits_btn)

	var status_lbl := Label.new()
	status_lbl.name = &"StatusLabel"
	status_lbl.theme_type_variation = &"Hint"
	status_lbl.text = "Paste diagnostics into a bug report. It holds no personal data."
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(status_lbl)

	var preview_card := PanelContainer.new()
	preview_card.name = &"DiagnosticsCard"
	preview_card.theme_type_variation = &"PanelCard"
	preview_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(preview_card)

	var preview_rtl := RichTextLabel.new()
	preview_rtl.name = &"DiagnosticsPreview"
	preview_rtl.fit_content = true
	preview_rtl.scroll_active = false
	preview_rtl.selection_enabled = true
	preview_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_rtl.text = format_diagnostics(settings, window)
	preview_card.add_child(preview_rtl)

	var handles := {
		"grid": grid,
		"value_labels": value_labels,
		"copy_btn": copy_btn,
		"open_folder_btn": open_btn,
		"credits_btn": credits_btn,
		"status_lbl": status_lbl,
		"preview": preview_rtl,
		"context": context,
	}

	if on_copy.is_valid():
		copy_btn.pressed.connect(on_copy)
	else:
		copy_btn.pressed.connect(func() -> void:
			var txt := format_diagnostics(settings, window)
			var active_ctx := handles.get("context", null) as ShellContext
			perform_copy_diagnostics(txt, active_ctx, handles)
		)
	open_btn.pressed.connect(func() -> void:
		open_data_folder(status_lbl)
	)
	credits_btn.pressed.connect(func() -> void:
		var active_ctx := handles.get("context", null) as ShellContext
		push_credits_screen(active_ctx)
	)
	return handles


## Refreshes value labels and diagnostics preview inside `handles`.
static func refresh_about_handles(handles: Dictionary, settings: Settings, window: Window) -> void:
	var rows := collect_diagnostics(settings, window)
	var labels: Array = handles.get("value_labels", [])
	for i: int in mini(rows.size(), labels.size()):
		var lbl := labels[i] as Label
		if lbl != null:
			lbl.text = str(rows[i]["value"])
	var preview := handles.get("preview", null) as RichTextLabel
	if preview != null:
		preview.text = format_diagnostics(settings, window)


## Copies `text` to system clipboard when supported and reports status + toast.
static func perform_copy_diagnostics(
	text: String,
	context: ShellContext,
	handles: Dictionary,
	clipboard_writer: Callable = Callable()
) -> String:
	if clipboard_writer.is_valid():
		clipboard_writer.call(text)
	elif DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(text)
	var status_lbl := handles.get("status_lbl", null) as Label
	if status_lbl != null:
		status_lbl.theme_type_variation = &"NumberGood"
		status_lbl.text = "Diagnostics copied to clipboard."
	if context != null:
		context.toast("Diagnostics copied", &"good")
	return text


## Opens `OS.get_user_data_dir()` in the system file browser when not headless.
static func open_data_folder(status_lbl: Label = null) -> void:
	var data_dir := OS.get_user_data_dir()
	if DisplayServer.get_name() != "headless":
		OS.shell_open(data_dir)
	if status_lbl != null:
		status_lbl.theme_type_variation = &"Hint"
		status_lbl.text = "Data folder: %s" % data_dir


## Pushes the Credits modal onto `context.stack`.
static func push_credits_screen(context: ShellContext) -> void:
	if context == null or context.stack == null or not context.stack.has_method(&"push"):
		return
	var credits := ScreenIds.make(&"credits")
	if credits != null:
		context.stack.call(&"push", credits)


static func _format_screen_line(settings: Settings, window: Window) -> String:
	var platform := settings.platform if settings != null else OS.get_name()
	var ui_setting := str(settings.get_value("display/ui_scale")) if settings != null else "auto"
	var scr_size := Display.DEFAULT_SIZE
	var scr_scale := 1.0
	var scr_dpi := 96
	if DisplayServer.get_name() != "headless" and DisplayServer.get_screen_count() > 0:
		var scr := window.current_screen if window != null else DisplayServer.get_primary_screen()
		scr = clampi(scr, 0, DisplayServer.get_screen_count() - 1)
		scr_size = DisplayServer.screen_get_size(scr)
		scr_scale = DisplayServer.screen_get_scale(scr)
		scr_dpi = DisplayServer.screen_get_dpi(scr)
	var win_size := window.size if window != null else Display.DEFAULT_SIZE
	var resolved_scale := Display.resolve_ui_scale(ui_setting, platform, scr_scale, scr_dpi)
	return "%dx%d @%.2fx (%d dpi) · window %dx%d · UI scale %s (%.2fx)" % [
		scr_size.x,
		scr_size.y,
		scr_scale,
		scr_dpi,
		win_size.x,
		win_size.y,
		ui_setting,
		resolved_scale,
	]


static func _format_memory_line() -> String:
	var static_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / BYTES_PER_MB
	var video_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / BYTES_PER_MB
	var tex_mb := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / BYTES_PER_MB
	return "static %.1f MB · video %.1f MB · textures %.1f MB" % [static_mb, video_mb, tex_mb]


static func _format_game_line() -> String:
	var g := Session.game
	if g == null:
		return "No active game"
	var map_id := g.map.id if g.map != null else "unknown"
	var short_digest := g.digest().substr(0, 8) if (g.map != null and g.state != null) else "none"
	var season_val: Variant = g.get(&"season")
	var season_str := str(season_val) if season_val != null else "sandbox"
	return "map %s · digest %s · seed %d · season %s" % [
		map_id,
		short_digest,
		g.seed_value,
		season_str,
	]


func _ensure_ui() -> void:
	if _ui_built:
		return
	if _frame == null:
		_frame = get_node_or_null("Center/Frame") as ModalFrame
	if _frame == null:
		return
	_ui_built = true
	_frame.closed.connect(_on_close_pressed)

	var settings: Settings = ctx.settings if ctx != null else null
	_handles = build_about_content(_frame.body(), settings, ctx, get_window(), copy_diagnostics)

	var foot := _frame.footer()
	_close_btn = KitButton.new()
	_close_btn.name = &"CloseButton"
	_close_btn.kind = KitButton.Kind.PRIMARY
	_close_btn.text = "Close"
	_close_btn.hotkey_action = &"app_back"
	_close_btn.pressed.connect(_on_close_pressed)
	foot.add_child(_close_btn)
	default_focus = get_path_to(_close_btn)


func _on_close_pressed() -> void:
	finished.emit(&"close")


func _reduce_motion() -> bool:
	if ctx != null and ctx.settings != null:
		return bool(ctx.settings.get_value("accessibility/reduce_motion"))
	return false
