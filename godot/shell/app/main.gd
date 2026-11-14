## The main scene: opens the window, shows "Building Europe..." with a progress bar while the map builder runs, then the
## map view and its HUD. Esc quits. The game itself arrives with the later releases; the map builder runs here, not in
## core/.
extends Control

const WINDOW_TITLE := "Hexa"
const MAP_VIEW := preload("res://shell/map/map_view.tscn")
const MAP_HUD := preload("res://shell/map/map_hud.tscn")
const BACKGROUND := Color(0.04, 0.05, 0.07)

@onready var _centre: CenterContainer = $Centre
@onready var _status: Label = $Centre/Box/Status
@onready var _bar: ProgressBar = $Centre/Box/Bar

var _view: MapView
var _hud: MapHud


func _ready() -> void:
	get_window().title = WINDOW_TITLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	RenderingServer.set_default_clear_color(BACKGROUND)
	_stage("Building Europe...", 0.0)
	# Let the first frame draw the screen before the builder takes its turn.
	await get_tree().process_frame
	_build_map()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_tree().quit()


## Shows a stage of the build. The builder itself is one call (the bar does not move while it runs): the bar moves
## between the stages, each one a frame, so the screen is drawn at every step.
func _stage(text: String, fraction: float) -> void:
	_status.text = text
	_bar.value = fraction


func _build_map() -> void:
	_stage("Reading the geography...", 0.05)
	await get_tree().process_frame
	var data := EuropeData.load_europe()
	_stage("Building the land, rivers, terrain, countries, roads and towns...", 0.15)
	await get_tree().process_frame
	var map := MapBuilder.build_europe(data)
	_stage("Setting up the map...", 0.9)
	await get_tree().process_frame
	var atlas := AtlasIndex.load_index()
	_view = MAP_VIEW.instantiate() as MapView
	add_child(_view)
	move_child(_view, 0)
	_view.setup(map, atlas)
	_hud = MAP_HUD.instantiate() as MapHud
	add_child(_hud)
	_hud.bind(_view)
	_bar.value = 1.0
	_centre.visible = false
