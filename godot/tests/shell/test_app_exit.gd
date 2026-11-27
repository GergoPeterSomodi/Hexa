## GUT tests for what the App leaves behind when it goes (issue 478): the request helpers are freed (no RefCounted cycle),
## and no threaded load stays running or untaken. Either one makes the engine report errors or leaks as it quits, which
## fails the CI step that opens the main scene headless.
extends GutTest

const APP_SCENE := preload("res://shell/app/app.tscn")

var _prev_game: Game = null
var _prev_unsaved: int = 0
var _old_max_fps: int = 0
var _old_low_proc: bool = false
var _old_tooltip_delay: float = 0.5


func before_each() -> void:
	Bindings.reset_defaults()
	_prev_game = Session.game
	_prev_unsaved = Session.unsaved_actions
	_old_max_fps = Engine.max_fps
	_old_low_proc = OS.low_processor_usage_mode
	_old_tooltip_delay = float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5))


func after_each() -> void:
	Session.game = _prev_game
	Session.unsaved_actions = _prev_unsaved
	Bindings.reset_defaults()
	Engine.max_fps = _old_max_fps
	OS.low_processor_usage_mode = _old_low_proc
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", _old_tooltip_delay)
	RenderingServer.set_default_clear_color(MapScene.SEA_COLOUR)


func _spawn_app(cli_args: PackedStringArray = PackedStringArray()) -> App:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child_autofree(vp)
	var app := APP_SCENE.instantiate() as App
	app.settings_path = ""
	app.allow_tree_quit = false
	app.pause_tree_when_modal = false
	app.skip_loading_frames = true
	app.cli_args_override = cli_args
	var settings := Settings.new("macOS", true)
	settings.set_value("state/help_seen", true)
	settings.set_value("graphics/preload_next_season", false)
	app.set_settings_override(settings)
	vp.add_child(app)
	return app


## Weak references to the App's request helpers, by class name; no strong one outlives this call.
func _helpers(app: App) -> Dictionary:
	var requests := app.requests()
	return {
		"GameRequests": weakref(requests),
		"WarRequests": weakref(requests.war),
		"WorksFlow": weakref(requests.works),
		"AiTurnUI": weakref(requests.ai_turn),
		"DecisionQueue": weakref(requests.decisions),
		"Bookmarks": weakref(requests.bookmarks),
	}


func _assert_all_freed(helpers: Dictionary) -> void:
	for helper: String in helpers:
		assert_null((helpers[helper] as WeakRef).get_ref(), "%s is freed with its App" % helper)


## The paths among `paths` with a threaded load asked for and not yet taken.
func _untaken(paths: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for path: String in paths:
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			out.append(path)
	return out


func test_a_freed_app_releases_its_request_helpers() -> void:
	var app := _spawn_app()
	var helpers := _helpers(app)
	app.free()
	await wait_process_frames(2)
	_assert_all_freed(helpers)


func test_a_freed_app_releases_its_request_helpers_after_a_game() -> void:
	var app := _spawn_app(PackedStringArray(["--new-game", "--country=VEN", "--seed=1480"]))
	var waited := 0
	while app.is_starting() and waited < 600:
		await wait_process_frames(1)
		waited += 1
	assert_not_null(app.map_scene(), "the game is on the screen")
	var helpers := _helpers(app)
	app.free()
	await wait_process_frames(2)
	_assert_all_freed(helpers)


func test_a_freed_app_takes_the_scenes_warmed_by_the_main_menu() -> void:
	ScreenIds._scenes.clear()  # warm() skips what an earlier test loaded
	var paths: Array[String] = []
	for id: StringName in ScreenIds.WARM_IDS:
		paths.append(ScreenIds.path_of(id))
	var app := _spawn_app()
	assert_gt(_untaken(paths).size(), 0, "the main menu asked for threaded loads")
	app.free()
	assert_eq(_untaken(paths), [] as Array[String])
	await wait_process_frames(2)  # what the App queued for freeing goes


func test_a_freed_app_takes_the_menu_pictures_still_loading() -> void:
	var paths: Array[String] = [MainMenu.MENU_BG_PATH, MainMenu.MENU_SHADE_PATH]
	var app := _spawn_app()
	assert_gt(_untaken(paths).size(), 0, "the main menu asked for its pictures")
	app.free()
	assert_eq(_untaken(paths), [] as Array[String])
	await wait_process_frames(2)  # what the App queued for freeing goes


func test_a_freed_app_takes_the_seasons_asked_for_ahead() -> void:
	var paths: Array[String] = [TilesetBuilder.tres_path("winter"), TilesetBuilder.tres_path("spring", true)]
	var app := _spawn_app()
	TilesetBuilder.request_season("winter")
	TilesetBuilder.request_season("winter")  # asked twice: each request needs its own take
	TilesetBuilder.request_season("spring", true)
	assert_eq(_untaken(paths), paths, "both seasons are asked for")
	app.free()
	assert_eq(_untaken(paths), [] as Array[String])
	await wait_process_frames(2)  # what the App queued for freeing goes
