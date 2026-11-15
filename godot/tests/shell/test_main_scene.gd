## The project's main scene opens: it is the map scene (north Italy on tiles), and the window is titled Hexa.
extends GutTest


func test_main_scene_is_the_map_scene() -> void:
	var path := str(ProjectSettings.get_setting("application/run/main_scene"))
	assert_eq(path, "res://shell/map/map_scene.tscn", "the main scene")
	var scene := load(path) as PackedScene
	assert_not_null(scene, "the main scene loads")
	var main := scene.instantiate()
	add_child_autofree(main)
	assert_true(main is MapScene, "the main scene is the map")
	assert_eq(str(ProjectSettings.get_setting("application/config/name")), "Hexa", "the window title")
