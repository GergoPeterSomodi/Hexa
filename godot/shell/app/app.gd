## Application root managing Settings, Theme, Display, Bindings, ShellContext, ScreenStack,
## AppInput, EscLadder, World (MapScene), Hud, close requests, focus FPS throttling, and CLI boot
## (docs/architecture/ui-and-controls-spec.md sections 3, 5, 6, 7; ui-style-and-feedback-spec.md section 4.8).
class_name App
extends Node

signal quit_performed
signal game_started
signal theme_reloaded(applied_theme: Theme)

const MAP_SCENE_PATH := "res://shell/map/map_scene.tscn"
const SAVE_DEBOUNCE_SEC := 1.0

@export var auto_boot: bool = true
@export var settings_path: String = Settings.PATH
@export var screenshot_dir: String = "user://screenshots"
@export var cli_args_override: PackedStringArray = PackedStringArray()
@export var pause_tree_when_modal: bool = true
@export var allow_tree_quit: bool = true
@export var skip_loading_frames: bool = false

@onready var _app_input: AppInput = $AppInput
@onready var _world: Node2D = $World
@onready var _hud: Hud = $Hud
@onready var _stack: ScreenStack = $Screens/Stack

var _settings: Settings = null
var _settings_override: Settings = null
var _ctx: ShellContext = null
var _map_scene: MapScene = null
var _current_theme: Theme = null
var _force_plain_ui: bool = false
var _last_ui_scale: float = 1.0
var _save_countdown: float = -1.0
var _syncing_window: bool = false
var _window_focused: bool = true
var _did_pause_tree: bool = false
var _starting_game: bool = false
var _routes: AppRoutes = null
var _booted: bool = false
var _lifecycle_gen: int = 0
var _quit_count: int = 0
var _last_screenshot: String = ""
var _signal_links: Array[Array] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if auto_boot:
		boot()


func _exit_tree() -> void:
	_lifecycle_gen += 1
	_disconnect_all()
	_disconnect_map_scene()
	_map_scene = null
	if _did_pause_tree and get_tree() != null:
		get_tree().paused = false
	_did_pause_tree = false


func _process(delta: float) -> void:
	if _save_countdown > 0.0:
		_save_countdown -= delta
		if _save_countdown <= 0.0:
			_save_countdown = -1.0
			_save_settings()


func _notification(what: int) -> void:
	if not _booted:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		handle_close_request()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_on_focus_out()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_on_focus_in()


## Injects Settings before boot (useful in tests to avoid touching user://settings.cfg).
func set_settings_override(p_settings: Settings) -> void:
	_settings_override = p_settings


## Boots the shell: Bindings, Settings, Display, Theme, signals, and CLI entry route.
func boot(p_cli_args: PackedStringArray = PackedStringArray(), p_settings: Settings = null) -> void:
	if _booted:
		return
	_booted = true
	if p_settings != null:
		_settings_override = p_settings
	Bindings.ensure()
	_init_settings()
	_apply_key_overrides()

	_ctx = ShellContext.new(_settings, _stack)
	_stack.setup(_ctx)
	_hud.setup(_ctx)
	_app_input.configure(_settings)
	_routes = AppRoutes.new(self)
	_connect_signals()

	var cli := _parse_cli_args(p_cli_args)
	_force_plain_ui = bool(cli["plain_ui"])

	if _is_root_window() and get_tree() != null:
		get_tree().auto_accept_quit = false

	_apply_display()
	_apply_theme()
	RenderingServer.set_default_clear_color(Tokens.BG)

	if bool(cli["new_game"]):
		_start_session(MapScene.MAP_ID, int(cli["seed"]), str(cli["scenario"]), StringName(str(cli["country"])))
	elif bool(cli["sandbox"]):
		_start_sandbox(MapScene.MAP_ID, int(cli["seed"]))
	else:
		_open_main_menu()


func is_starting() -> bool:
	return _starting_game


## Re-reads the screen stack's pause and hidden-world state (after the pick is pushed).
func refresh_stack_state() -> void:
	_on_stack_changed()


func context() -> ShellContext:
	return _ctx


func settings() -> Settings:
	return _settings


func stack() -> ScreenStack:
	return _stack


func hud() -> Hud:
	return _hud


func world_host() -> Node2D:
	return _world


func map_scene() -> MapScene:
	return _map_scene


func app_input() -> AppInput:
	return _app_input


func current_theme() -> Theme:
	return _current_theme


func wants_pause() -> bool:
	return _stack != null and _stack.wants_pause()


func hides_world() -> bool:
	return _stack != null and _stack.hides_world()


func quit_count() -> int:
	return _quit_count


func last_screenshot_path() -> String:
	return _last_screenshot


## Handles OS close request (Cmd+Q / Alt+F4 / window close): confirms when unsaved_actions > 0.
func handle_close_request() -> void:
	if _settings != null and _is_root_window():
		_capture_window_geometry()
	if Session.unsaved_actions > 0:
		var top := _stack.top()
		if top != null and top.screen_id == &"confirm":
			return
		var confirm := Confirm.ask(
			"Quit to desktop?",
			["Quit to desktop? Unsaved changes are lost."],
			[
				{"id": &"confirm", "label": "Quit", "kind": "danger", "safe": false},
				{"id": &"cancel", "label": "Stay", "kind": "secondary", "safe": true},
			],
			{"danger": true, "on_result": _on_quit_confirm_result}
		)
		if confirm != null:
			_stack.push(confirm)
			return
	_perform_quit()


func _on_quit_confirm_result(accepted: bool) -> void:
	if accepted:
		_perform_quit()


func _init_settings() -> void:
	if _settings_override != null:
		_settings = _settings_override
	elif not settings_path.is_empty():
		_settings = Settings.load_from(settings_path)
	else:
		_settings = Settings.new()


func _apply_key_overrides() -> void:
	if _settings == null:
		return
	Bindings.apply_overrides(_settings.get_key_overrides())


func _parse_cli_args(explicit_args: PackedStringArray) -> Dictionary:
	var args := explicit_args
	if args.is_empty():
		args = cli_args_override if not cli_args_override.is_empty() else OS.get_cmdline_user_args()
	return AppCli.parse(args)


func _link(emitter: Object, sig: StringName, handler: Callable) -> void:
	if emitter == null:
		return
	if not emitter.is_connected(sig, handler):
		emitter.connect(sig, handler)
		_signal_links.append([emitter, sig, handler])


func _connect_signals() -> void:
	_link(_ctx, &"app_requested", _on_app_requested)
	_link(_settings, &"changed", _on_setting_changed)
	_link(_stack, &"changed", _on_stack_changed)

	_link(_app_input, &"back_requested", _on_back_requested)
	_link(_app_input, &"menu_requested", _on_menu_requested)
	_link(_app_input, &"help_toggled", _on_help_toggled)
	_link(_app_input, &"debug_toggled", _on_debug_toggled)
	_link(_app_input, &"fullscreen_toggled", _on_fullscreen_toggled)
	_link(_app_input, &"screenshot_requested", _on_screenshot_requested)

	_link(_hud, &"zoom_step_requested", _routes.on_hud_zoom_step)
	_link(_hud, &"zoom_set_requested", _routes.on_hud_zoom_set)
	_link(_hud, &"fit_requested", _routes.on_hud_fit)
	_link(_hud, &"season_preview_requested", _routes.on_hud_season_preview)
	_link(_hud, &"help_requested", _on_help_toggled)
	_link(_hud, &"menu_requested", _on_menu_requested)
	_link(_hud, &"new_seed_requested", _routes.on_hud_new_seed)
	_link(_hud, &"debug_layer_toggled", _routes.on_hud_debug_layer)
	_link(_hud, &"far_zoom_changed", _routes.on_hud_far_zoom)
	_link(_hud, &"slice_ms_changed", _routes.on_hud_slice_ms)
	_link(_hud, &"hud_visibility_changed", _sync_camera_free_rect.unbind(1))
	_link(_hud, &"cover_changed", _sync_screen_cover)
	_link(_hud, &"mode_requested", _routes.on_hud_mode_requested)
	_link(_hud, &"country_requested", _routes.show_country)
	_link(_hud, &"country_play_requested", _routes.on_hud_country_play)
	_link(_hud, &"country_look_at_requested", _routes.on_hud_country_look_at)
	_link(_hud, &"look_at_requested", _routes.on_hud_look_at)
	_link(_hud, &"jump_requested", _routes.on_hud_jump)
	if _hud.country_panel() != null:
		_link(_hud.country_panel(), &"closed", _routes.on_country_panel_closed)

	_link(Events, &"game_started", _on_events_game_started)
	_link(Events, &"country_chosen", _routes.on_country_chosen)
	_link(get_viewport(), &"size_changed", _sync_camera_free_rect)
	if _is_root_window():
		_link(get_window(), &"size_changed", _on_window_size_changed)


func _disconnect_all() -> void:
	for i: int in range(_signal_links.size() - 1, -1, -1):
		var pair: Array = _signal_links[i]
		var emitter := pair[0] as Object
		var sig := pair[1] as StringName
		var handler := pair[2] as Callable
		if emitter != null and is_instance_valid(emitter) and emitter.is_connected(sig, handler):
			emitter.disconnect(sig, handler)
	_signal_links.clear()


func _open_main_menu() -> void:
	_stack.clear()
	_teardown_world()
	if _hud != null:
		_hud.close_popovers()
		_hud.set_debug_open(false)
		_hud.hex_panel().clear()
		_hud.set_hud_visible(true)
	RenderingServer.set_default_clear_color(Tokens.BG)
	var menu := ScreenIds.make(&"main_menu")
	if menu != null:
		_stack.push(menu)
	_on_stack_changed()


func _start_sandbox(map_id_val: String, seed_val: int) -> void:
	_start_session(map_id_val, seed_val)


## Starts a game: the map sandbox when `scenario_id` is empty, otherwise that scenario (with the country `player` when
## given, so no pick). A scenario the rules refuse toasts its first problem and goes back to the main menu.
func _start_session(map_id_val: String, seed_val: int, scenario_id: String = "", player: StringName = &"") -> void:
	if _starting_game:
		return
	_starting_game = true
	var gen := _lifecycle_gen

	var loading := ScreenIds.make(&"loading") as Loading
	if loading != null:
		if scenario_id.is_empty():
			loading.set_status("Building the map", "Preparing %s (seed %d)..." % [_map_title(map_id_val), seed_val])
		else:
			loading.set_status("Drawing the map", "Preparing %s (seed %d)..." % [_routes.scenario_title(scenario_id), seed_val])
		loading.set_progress(0.1)
		_stack.push(loading)

	if not skip_loading_frames and is_inside_tree() and get_tree() != null:
		await get_tree().process_frame
		if not is_inside_tree() or _lifecycle_gen != gen:
			_starting_game = false
			return
		await get_tree().process_frame
		if not is_inside_tree() or _lifecycle_gen != gen:
			_starting_game = false
			return

	_teardown_world()
	if scenario_id.is_empty():
		Session.new_game(map_id_val, seed_val)
	else:
		var problem := Session.new_scenario(scenario_id, seed_val, player)
		if problem != "":
			_starting_game = false
			_open_main_menu()
			_ctx.toast(problem, &"bad")
			return
		map_id_val = Session.defs().scenario(scenario_id).map_id
	_mount_map_scene(map_id_val, seed_val)

	if loading != null and is_instance_valid(loading) and _map_scene != null and _map_scene.is_loading():
		loading.set_progress_source(_map_scene.fill_progress)
		while _map_scene != null and is_instance_valid(_map_scene) and _map_scene.is_loading():
			if not is_inside_tree() or _lifecycle_gen != gen or get_tree() == null:
				_starting_game = false
				return
			await get_tree().process_frame

	if not is_inside_tree() or _lifecycle_gen != gen:
		_starting_game = false
		return

	_stack.clear()
	_starting_game = false
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)
	if _hud != null:
		_hud.set_hud_visible(true)
		_hud.bind_map_scene(_map_scene)
	_sync_camera_free_rect()
	_sync_screen_cover()
	if _map_scene != null:
		_map_scene.fit()
	_on_stack_changed()
	if _map_scene != null and _map_scene.picking():
		_routes.begin_pick()
	else:
		if _map_scene != null and Session.player_tag() != &"":
			_routes.announce_rule(true)
		HelpOverlay.open_if_unseen(_ctx)
	game_started.emit()


func _mount_map_scene(map_id_val: String, seed_val: int) -> void:
	var packed := ResourceLoader.load(MAP_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("App: failed to load %s" % MAP_SCENE_PATH)
		return
	var scene := packed.instantiate() as MapScene
	if scene == null:
		push_error("App: %s root is not MapScene" % MAP_SCENE_PATH)
		return
	scene.map_id = map_id_val
	scene.start_seed = seed_val
	if _settings != null:
		scene.preload_next_season = bool(_settings.get_value("graphics/preload_next_season"))
		scene.texture_quality = str(_settings.get_value("graphics/texture_quality"))
	_world.add_child(scene)
	_map_scene = scene
	scene.configure(_settings)
	scene.set_panel(_hud.hex_panel())
	_hud.bind_map_scene(scene)
	_connect_map_scene(scene)


func _connect_map_scene(scene: MapScene) -> void:
	_routes.bind_scene(scene)


func _disconnect_map_scene() -> void:
	if _routes != null:
		_routes.unbind_scene(_map_scene)


func _teardown_world() -> void:
	_disconnect_map_scene()
	_map_scene = null
	if _hud != null:
		_hud.bind_map_scene(null)
	if _world == null:
		return
	for child: Node in _world.get_children():
		_world.remove_child(child)
		child.queue_free()


func _on_app_requested(what: StringName, args: Dictionary) -> void:
	match what:
		&"new_game":
			if args.has("scenario"):
				_start_session(
					MapScene.MAP_ID, int(args.get("seed", Sandbox.DEFAULT_SEED)), str(args["scenario"]),
					StringName(str(args.get("country", &"")))
				)
			else:
				_start_sandbox(str(args.get("map_id", MapScene.MAP_ID)), int(args.get("seed", Sandbox.DEFAULT_SEED)))
		&"start_sandbox":
			var map_id_val := str(args.get("map_id", MapScene.MAP_ID))
			var seed_val := int(args.get("seed", Sandbox.DEFAULT_SEED))
			_start_sandbox(map_id_val, seed_val)
		&"country":
			_routes.show_country(StringName(str(args.get("tag", &""))))
		&"close_dock":
			if _hud != null:
				_hud.close_dock()
		&"left_inset":
			if _hud != null:
				_hud.set_left_inset(float(args.get("px", 0.0)))
		&"pause":
			_open_pause_menu()
		&"main_menu", &"end_game":
			Session.end_game()
			_open_main_menu()
		&"quit":
			_perform_quit()
		&"open_screen":
			var id := StringName(str(args.get("id", &"")))
			if id != &"":
				var screen := ScreenIds.make(id)
				if screen != null:
					_stack.push(screen)
		&"toggle_debug":
			_on_debug_toggled()
		&"toast":
			_ctx.toast(str(args.get("text", "")), StringName(str(args.get("tone", &"plain"))))
		&"screenshot":
			_on_screenshot_requested()
		&"apply_display":
			_handle_display_applied()
		&"reload_theme":
			_apply_theme()
		&"look_at":
			_handle_look_at(args)


func _handle_look_at(args: Dictionary) -> void:
	if _map_scene == null or _map_scene.camera_rig() == null:
		return
	if args.has("map_px") and args["map_px"] is Vector2:
		_map_scene.camera_rig().look_at(args["map_px"] as Vector2)
	elif args.has("hex") and args["hex"] is Vector2i and _map_scene.view() != null:
		var hex := args["hex"] as Vector2i
		_map_scene.glide_to_hex(hex, _routes.glide_zoom())
		if bool(args.get("select", false)):
			_map_scene.select_hex(hex)


func _handle_display_applied() -> void:
	var old_scale := _last_ui_scale
	_apply_display()
	_apply_theme()
	if not is_equal_approx(old_scale, _last_ui_scale) and _map_scene != null and _map_scene.camera_rig() != null:
		_map_scene.camera_rig().apply_ui_scale_change(old_scale, _last_ui_scale)
	_sync_camera_free_rect()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if _settings == null:
		return
	if not settings_path.is_empty():
		_save_countdown = SAVE_DEBOUNCE_SEC
	if key in ["display/ui_scale", "accessibility/high_contrast", "dev/ui_kit"]:
		_handle_display_applied()
	elif key in ["display/fps_cap", "display/power_saving", "accessibility/tooltip_delay", "display/vsync"]:
		_apply_display()
	elif key == "dev/developer_tools" and not bool(_settings.get_value("dev/developer_tools")):
		if _hud != null:
			_hud.set_debug_open(false)
	elif key.begins_with("keys/"):
		_apply_key_overrides()
		if _hud != null:
			_hud.refresh_bindings(_settings.platform)


func _on_stack_changed() -> void:
	var paused := wants_pause()
	var hidden := hides_world()
	if pause_tree_when_modal and _is_root_window() and get_tree() != null:
		get_tree().paused = paused
		_did_pause_tree = paused
	if _world != null:
		_world.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_PAUSABLE
		_world.visible = not hidden
	if _hud != null:
		_hud.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_PAUSABLE
		_hud.visible = not hidden
		if hidden:
			_hud.close_popovers()
	if _map_scene != null and is_instance_valid(_map_scene):
		_map_scene.set_input_enabled(not paused)


func _on_back_requested() -> void:
	if _hud != null and _hud.has_open_popover():
		_hud.close_popovers()
		return
	var top := _stack.top()
	var top_id := top.screen_id if top != null else &""
	var state := {
		"top_screen_id": top_id,
		"has_screen": top != null,
		"hud_list_open": false,
		"has_selection": _map_scene != null and _map_scene.selected != MapScene.NO_HEX,
		"dock_open": _hud != null and _hud.is_dock_open(),
	}
	match EscLadder.decide(state):
		EscLadder.NONE:
			return
		EscLadder.STACK_BACK:
			_stack.back()
		EscLadder.CLOSE_HUD_LIST:
			if _hud != null:
				_hud.close_popovers()
		EscLadder.CLEAR_SELECTION:
			if _hud != null and _hud.country_panel() != null and _hud.country_panel().visible:
				_hud.close_dock()
			elif _map_scene != null:
				_map_scene.select_hex(MapScene.NO_HEX)
			elif _hud != null:
				_hud.hex_panel().clear()
		EscLadder.OPEN_PAUSE_MENU:
			_open_pause_menu()


func _on_menu_requested() -> void:
	if hides_world():
		return
	var top := _stack.top()
	if top != null:
		if top.screen_id == &"pause_menu":
			_stack.back()
		return
	_open_pause_menu()


func _on_help_toggled() -> void:
	if hides_world():
		return
	var top := _stack.top()
	if top != null and top.screen_id == &"help":
		_stack.back()
		return
	if top != null and top.screen_id == &"loading":
		return
	var help := ScreenIds.make(&"help")
	if help != null:
		_stack.push(help)


func _on_debug_toggled() -> void:
	if _settings != null and not bool(_settings.get_value("dev/developer_tools")):
		return
	if hides_world() or _map_scene == null or _hud == null:
		return
	_hud.toggle_debug()


func _on_fullscreen_toggled() -> void:
	if _settings == null:
		return
	var cur := str(_settings.get_value("display/window_mode"))
	var next := "windowed" if cur != "windowed" else "fullscreen"
	_settings.set_value("display/window_mode", next)
	_apply_display()


func _on_screenshot_requested() -> void:
	var vp := get_viewport()
	if vp == null or DisplayServer.get_name() == "headless":
		return
	var tex := vp.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.is_empty():
		return
	var global_dir := ProjectSettings.globalize_path(screenshot_dir)
	if DirAccess.make_dir_recursive_absolute(global_dir) != OK:
		_ctx.toast("Could not create screenshot folder", &"bad")
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var filename := "hexa_%s.png" % stamp
	var full_path := screenshot_dir.path_join(filename)
	if img.save_png(full_path) == OK:
		_last_screenshot = full_path
		_ctx.toast("Saved screenshot: %s" % filename, &"good")
	else:
		_ctx.toast("Could not save screenshot", &"bad")


func _on_events_game_started() -> void:
	if _hud != null and _map_scene != null and Session.game != null and not Session.game.has_countries():
		_hud.set_map_info(_map_title(_map_scene.map_id), Session.game.seed_value)
		_hud.set_season(_map_scene.season)


func _open_pause_menu() -> void:
	if _map_scene == null:
		return
	var top := _stack.top()
	if top != null and top.screen_id == &"pause_menu":
		return
	var pause := ScreenIds.make(&"pause_menu")
	if pause != null:
		_stack.push(pause)


func _on_window_size_changed() -> void:
	if _syncing_window or _settings == null or not _is_root_window():
		return
	var win := get_window()
	if win == null:
		return
	var old_scale := _last_ui_scale
	var scale := _resolved_ui_scale(win)
	win.content_scale_factor = scale
	win.content_scale_size = win.size
	if not is_equal_approx(old_scale, scale):
		_apply_theme()
		if _map_scene != null and _map_scene.camera_rig() != null:
			_map_scene.camera_rig().apply_ui_scale_change(old_scale, _last_ui_scale)
		_sync_camera_free_rect()
	if DisplayServer.get_name() != "headless":
		_capture_window_geometry()


func _capture_window_geometry() -> void:
	var win := get_window()
	if win == null or _settings == null or DisplayServer.get_name() == "headless":
		return
	match win.mode:
		Window.MODE_FULLSCREEN:
			_settings.set_value("display/window_mode", "fullscreen")
		Window.MODE_EXCLUSIVE_FULLSCREEN:
			_settings.set_value("display/window_mode", "exclusive")
		Window.MODE_MAXIMIZED:
			_settings.set_value("display/window_mode", "windowed")
			_settings.set_value("display/maximized", true)
		_:
			_settings.set_value("display/window_mode", "windowed")
			_settings.set_value("display/maximized", false)
			if win.size.x >= Display.MIN_SIZE.x and win.size.y >= Display.MIN_SIZE.y:
				_settings.set_value("display/window_size", win.size)
			_settings.set_value("display/window_position", win.position)


func _apply_display() -> void:
	if _settings == null:
		return
	_syncing_window = true
	var target_win: Window = get_window() if _is_root_window() else null
	Display.apply(target_win, _settings)
	_syncing_window = false
	if not _window_focused:
		_on_focus_out()


func _apply_theme() -> void:
	if _settings == null:
		return
	var win := get_window() if _is_root_window() else null
	var scale := _resolved_ui_scale(win)
	_last_ui_scale = scale
	var kit_mode := &"plain" if _force_plain_ui else StringName(str(_settings.get_value("dev/ui_kit")))
	var high_contrast := bool(_settings.get_value("accessibility/high_contrast"))
	var loaded := KitTheme.load_for(scale, kit_mode, high_contrast)
	_current_theme = loaded
	if _hud != null and _hud.root() != null:
		_hud.root().theme = loaded
	if _stack != null:
		_stack.theme = loaded
	if _is_root_window() and win != null:
		win.theme = loaded
	theme_reloaded.emit(loaded)


func _resolved_ui_scale(win: Window) -> float:
	if _settings == null:
		return 1.0
	var scr_scale := 1.0
	var scr_dpi := 96
	if DisplayServer.get_name() != "headless" and DisplayServer.get_screen_count() > 0:
		var scr := clampi(win.current_screen if win != null else DisplayServer.get_primary_screen(), 0, DisplayServer.get_screen_count() - 1)
		scr_scale = DisplayServer.screen_get_scale(scr)
		scr_dpi = DisplayServer.screen_get_dpi(scr)
	return Display.resolve_ui_scale(str(_settings.get_value("display/ui_scale")), _settings.platform, scr_scale, scr_dpi)


func _sync_camera_free_rect() -> void:
	if _map_scene == null or not is_instance_valid(_map_scene):
		return
	var rig := _map_scene.camera_rig()
	if rig == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var vp_size := vp.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var top_h := float(Tokens.BAR_H) if (_hud != null and _hud.is_hud_visible()) else 0.0
	rig.set_free_rect(Rect2(0.0, top_h, vp_size.x, maxf(1.0, vp_size.y - top_h)))


## Country names keep clear of what the HUD covers.
func _sync_screen_cover() -> void:
	if _map_scene != null and is_instance_valid(_map_scene) and _hud != null:
		_map_scene.set_screen_cover(_hud.cover_rects())


func _on_focus_out() -> void:
	_window_focused = false
	if _settings == null:
		return
	var bg_fps := int(_settings.get_value("display/background_fps"))
	if bg_fps > 0:
		var fg_fps := int(_settings.get_value("display/fps_cap"))
		Engine.max_fps = mini(bg_fps, fg_fps) if fg_fps > 0 else bg_fps


func _on_focus_in() -> void:
	_window_focused = true
	if _settings == null:
		return
	Engine.max_fps = int(_settings.get_value("display/fps_cap"))


func _save_settings() -> void:
	if _settings == null or settings_path.is_empty():
		return
	if not _settings.save_to(settings_path) and _ctx != null:
		_ctx.toast("Option changed, but it could not be saved", &"warn")


func _perform_quit() -> void:
	_save_countdown = -1.0
	_save_settings()
	_quit_count += 1
	quit_performed.emit()
	if allow_tree_quit and _is_root_window() and is_inside_tree() and get_tree() != null:
		get_tree().quit()


func _is_root_window() -> bool:
	if not is_inside_tree():
		return false
	var tree := get_tree()
	return tree != null and get_viewport() == tree.root


func _map_title(id: String) -> String:
	return "North Italy" if id == MapScene.MAP_ID else id.capitalize()
