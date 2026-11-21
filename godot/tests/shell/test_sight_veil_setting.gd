## The map/sight_veil setting (docs/architecture/m6-build-spec.md 6.1 and 6.6): MapScene.configure applies it to the mode
## overlay's veil, live, and the minimap rebinds when the veil changes (its key carries the veil), so the minimap's veil never
## goes stale. Planted fault: a setting change that the scene ignores, or a minimap key without the veil, fails here.
extends GutTest

var _scene: MapScene = null
var _minimap: Minimap = null
var _settings: Settings = null


func before_each() -> void:
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_settings = Settings.new("macOS", false)
	_scene.configure(_settings)
	_minimap = (load("res://shell/hud/minimap.tscn") as PackedScene).instantiate() as Minimap
	add_child_autofree(_minimap)
	_minimap.bind_map_scene(_scene)


func after_each() -> void:
	Session.end_game()


func test_the_setting_applies_to_the_overlay_on_configure_and_on_change() -> void:
	assert_true(bool(_settings.get_value("map/sight_veil")), "the veil is on by default")
	assert_true(_scene.overlay().is_sight_veil_on(), "configure applies the setting")
	_settings.set_value("map/sight_veil", false)
	assert_false(_scene.overlay().is_sight_veil_on(), "a change reaches the overlay at once")
	_settings.set_value("map/sight_veil", true)
	assert_true(_scene.overlay().is_sight_veil_on(), "and back")


func test_the_minimap_rebinds_when_the_veil_changes() -> void:
	await wait_process_frames(2)
	var before := _minimap._overlay_key
	assert_true(before.ends_with("true"), "the key carries the veil on")
	_settings.set_value("map/sight_veil", false)
	await wait_process_frames(2)
	assert_ne(_minimap._overlay_key, before, "the minimap rebinds")
	assert_true(_minimap._overlay_key.ends_with("false"), "with the veil off in its key")
