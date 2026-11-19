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


## Returns true if `id` is registered in PATHS.
static func has(id: StringName) -> bool:
	return PATHS.has(id)


## Returns the scene resource path for `id`, or "" if unknown.
static func path_of(id: StringName) -> String:
	return str(PATHS.get(id, ""))


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
	var packed := ResourceLoader.load(path) as PackedScene
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
