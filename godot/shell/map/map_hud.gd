## The HUD over the map: the view button, the key hint and the tip under the mouse. It only shows what the map view
## reports; it changes nothing in the map. The tip sits by the mouse on a dark panel, and turns to the other side of the
## mouse when it would leave the window.
class_name MapHud
extends CanvasLayer

const HINT := "Drag, WASD or arrows to pan    Wheel to zoom    1 terrain, 2 countries    Esc to quit"
const TIP_OFFSET := Vector2(18.0, 18.0)
const TIP_PANEL := Color(0.05, 0.05, 0.07, 0.92)

@onready var _view_button: Button = $Layout/ViewButton
@onready var _hint: Label = $Layout/Hint
@onready var _tip: Label = $Layout/HoverTip
var _view: MapView


func bind(view: MapView) -> void:
	_view = view
	_view.view_changed.connect(_on_view_changed)
	_view.hover_changed.connect(_on_hover_changed)
	_view_button.pressed.connect(_on_button_pressed)
	_hint.text = HINT
	var panel := StyleBoxFlat.new()
	panel.bg_color = TIP_PANEL
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(8.0)
	_tip.add_theme_stylebox_override("normal", panel)
	_on_view_changed(view.view_mode)


func _process(_delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var view := get_viewport().get_visible_rect().size
	var size := _tip.get_combined_minimum_size()
	var at := mouse + TIP_OFFSET
	if at.x + size.x > view.x:
		at.x = mouse.x - TIP_OFFSET.x - size.x
	if at.y + size.y > view.y:
		at.y = mouse.y - TIP_OFFSET.y - size.y
	_tip.position = at


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
