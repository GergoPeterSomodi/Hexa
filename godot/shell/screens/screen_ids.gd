## Registry mapping screen IDs to scene paths so screens open one another without load cycles
## (docs/architecture/ui-and-controls-spec.md section 3.2; ui-style-and-feedback-spec.md section 6.8, 7.4, 8).
class_name ScreenIds
extends RefCounted

const PATHS: Dictionary[StringName, String] = {
	&"main_menu": "res://shell/screens/main_menu.tscn",
	&"sandbox": "res://shell/screens/sandbox.tscn",
	&"pause_menu": "res://shell/screens/pause_menu.tscn",
	&"options": "res://shell/screens/options.tscn",
	&"confirm": "res://shell/screens/confirm.tscn",
	&"loading": "res://shell/screens/loading.tscn",
	&"help": "res://shell/screens/help_overlay.tscn",
	&"credits": "res://shell/screens/credits.tscn",
	&"about": "res://shell/screens/about.tscn",
	&"new_game": "res://shell/screens/new_game.tscn",
	&"country_pick": "res://shell/screens/country_pick.tscn",
	&"find_place": "res://shell/screens/find_place.tscn",
	&"save_load": "res://shell/screens/save_load.tscn",
	&"season_report": "res://shell/screens/season_report.tscn",
	&"works_preview": "res://shell/screens/works_preview.tscn",
	&"study": "res://shell/screens/study.tscn",
	&"tech": "res://shell/screens/tech.tscn",
	&"idea_pick": "res://shell/screens/idea_pick.tscn",
	&"peace": "res://shell/screens/peace.tscn",
}

## The screens a player opens from the menus: warm() loads them on a thread while the main menu is up.
const WARM_IDS: Array[StringName] = [
	&"options", &"pause_menu", &"help", &"credits", &"about", &"new_game", &"country_pick", &"save_load",
	&"season_report", &"confirm", &"sandbox", &"find_place", &"works_preview", &"study",
]

## Scenes already loaded, kept so a second open does not read the file again (a PackedScene is small).
static var _scenes: Dictionary[StringName, PackedScene] = {}
## Ids with a threaded load asked for and not yet taken.
static var _warming: Dictionary[StringName, bool] = {}


## Returns true if `id` is registered in PATHS.
static func has(id: StringName) -> bool:
	return PATHS.has(id)


## Returns the scene resource path for `id`, or "" if unknown.
static func path_of(id: StringName) -> String:
	return str(PATHS.get(id, ""))


## Starts loading the scenes of WARM_IDS on a thread (nothing blocks; make() takes the result). Safe to call again.
static func warm() -> void:
	for id: StringName in WARM_IDS:
		if _scenes.has(id) or _warming.has(id) or not PATHS.has(id):
			continue
		var path: String = PATHS[id]
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK:
			_warming[id] = true


## The PackedScene of `id` (a finished threaded load, the cache, or a load now); null when it cannot be had.
static func scene_of(id: StringName) -> PackedScene:
	if _scenes.has(id):
		return _scenes[id]
	var path: String = PATHS[id]
	var packed: PackedScene = null
	if _warming.has(id):
		_warming.erase(id)
		packed = ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null:
		packed = ResourceLoader.load(path) as PackedScene
	if packed != null:
		_scenes[id] = packed
	return packed


## Instantiates the Screen scene for `id`. Fails loudly via push_error and returns null
## if `id` is unknown, the .tscn is missing on disk, or the scene root is not a Screen.
static func make(id: StringName) -> Screen:
	if not PATHS.has(id):
		push_error("ScreenIds.make: unknown screen id '%s'" % String(id))
		return null
	var path: String = PATHS[id]
	if not ResourceLoader.exists(path):
		push_error("ScreenIds.make: missing scene for screen '%s' at %s" % [String(id), path])
		return null
	var packed := scene_of(id)
	if packed == null:
		push_error("ScreenIds.make: failed to load PackedScene for '%s' at %s" % [String(id), path])
		return null
	var instance := packed.instantiate()
	if not (instance is Screen):
		if instance != null:
			instance.queue_free()
		push_error("ScreenIds.make: root of %s is not a Screen" % path)
		return null
	var screen := instance as Screen
	if screen.screen_id == &"":
		screen.screen_id = id
	return screen
