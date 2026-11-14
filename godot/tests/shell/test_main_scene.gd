## Sample GUT test: the main scene opens and its window is titled Hexa.
extends GutTest

const MainScene := preload("res://shell/app/main.tscn")


func test_main_scene_opens_titled_hexa() -> void:
	var main := MainScene.instantiate()
	add_child_autofree(main)
	assert_eq(get_window().title, "Hexa", "the window title")
