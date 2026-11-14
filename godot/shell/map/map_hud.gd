## The HUD over the map: the view button, the key hint and the tip under the mouse. It only shows what the map view
## reports; it changes nothing in the map.
class_name MapHud
extends CanvasLayer

const HINT := "Drag, WASD or arrows to pan    Wheel to zoom    1 terrain, 2 countries    Esc to quit"

var _view_button: Button
var _hint: Label
var _tip: Label
var _view: MapView


func bind(view: MapView) -> void:
	_view = view
	_view_button = get_node("Layout/ViewButton") as Button
	_hint = get_node("Layout/Hint") as Label
	_tip = get_node("Layout/HoverTip") as Label
	_view.view_changed.connect(_on_view_changed)
	_view.hover_changed.connect(_on_hover_changed)
	_view_button.pressed.connect(_on_button_pressed)
	_hint.text = HINT
	_on_view_changed(view.view_mode)


func _process(_delta: float) -> void:
	_tip.position = get_viewport().get_mouse_position() + Vector2(18.0, 18.0)


func _on_button_pressed() -> void:
	if _view.view_mode == MapView.VIEW_TERRAIN:
		_view.set_view(MapView.VIEW_COUNTRIES)
	else:
		_view.set_view(MapView.VIEW_TERRAIN)


func _on_view_changed(mode: String) -> void:
	_view_button.text = "Terrain view (1)" if mode == MapView.VIEW_COUNTRIES else "Countries view (2)"


func _on_hover_changed(text: String) -> void:
	_tip.text = text
	_tip.visible = text != ""
