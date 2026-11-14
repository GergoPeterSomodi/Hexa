## The main scene: opens the window. The game itself arrives with the map (0.3.0 later steps).
extends Control

const WINDOW_TITLE := "Hexa"


func _ready() -> void:
	get_window().title = WINDOW_TITLE
