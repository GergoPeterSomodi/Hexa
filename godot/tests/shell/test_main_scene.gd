## The project's main scene opens: it is the App root (booting to the main menu), and the window is titled Hexa.
extends GutTest


func test_main_scene_is_the_app_root() -> void:
	var path := str(ProjectSettings.get_setting("application/run/main_scene"))
	assert_eq(path, "res://shell/app/app.tscn", "the main scene")
	var scene := load(path) as PackedScene
	assert_not_null(scene, "the main scene loads")
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child_autofree(vp)
	var main := scene.instantiate() as App
	assert_not_null(main, "the main scene is the App root")
	main.settings_path = ""
	main.allow_tree_quit = false
	vp.add_child(main)
	assert_not_null(main.stack().top(), "App pushes initial screen")
	assert_eq(main.stack().top().screen_id, &"main_menu", "App boots to main_menu")
	assert_eq(str(ProjectSettings.get_setting("application/config/name")), "Hexa", "the window title")
