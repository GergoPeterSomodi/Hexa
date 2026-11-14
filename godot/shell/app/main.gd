## The main scene: opens the window, shows "Building Europe..." while the map builder runs, then the map view and its HUD.
## Esc quits. The game itself arrives with the later releases; the map builder runs here, not in core/.
extends Control

const WINDOW_TITLE := "Hexa"
const MAP_VIEW := preload("res://shell/map/map_view.tscn")
const MAP_HUD := preload("res://shell/map/map_hud.tscn")
const BACKGROUND := Color(0.04, 0.05, 0.07)

var _centre: CenterContainer
var _status: Label

var _view: MapView
var _hud: MapHud


func _ready() -> void:
	get_window().title = WINDOW_TITLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centre = get_node("Centre") as CenterContainer
	_status = get_node("Centre/Status") as Label
	RenderingServer.set_default_clear_color(BACKGROUND)
	_status.text = "Building Europe..."
	# Let the first frame draw the message before the builder takes its second.
	await get_tree().process_frame
	_build_map()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_tree().quit()


func _build_map() -> void:
	var data := EuropeData.load_europe()
	var map := MapBuilder.build_europe(data)
	var atlas := AtlasIndex.load_index()
	_view = MAP_VIEW.instantiate() as MapView
	add_child(_view)
	move_child(_view, 0)
	_view.setup(map, atlas)
	_hud = MAP_HUD.instantiate() as MapHud
	add_child(_hud)
	_hud.bind(_view)
	_centre.visible = false
