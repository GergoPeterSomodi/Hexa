## Studiolo bottom-right zoom card with zoom out, 100% reset/readout, zoom in, and fit buttons
## (docs/architecture/ui-and-controls-spec.md section 7; ui-style-and-feedback-plan.md U14).
class_name ZoomControl
extends PanelContainer

signal zoom_step_requested(notches: float)
signal zoom_set_requested(zoom: float)
signal fit_requested

@onready var _zoom_out_btn: KitButton = $HBox/ZoomOutButton
@onready var _readout_btn: KitButton = $HBox/ReadoutButton
@onready var _zoom_in_btn: KitButton = $HBox/ZoomInButton
@onready var _fit_btn: KitButton = $HBox/FitButton

var _zoom: float = 1.0
var _min_zoom: float = 0.0
var _max_zoom: float = ZoomModel.ZOOM_MAX


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_configure_button(_zoom_out_btn, &"cam_zoom_out")
	_configure_button(_readout_btn, &"")
	_configure_button(_zoom_in_btn, &"cam_zoom_in")
	_configure_button(_fit_btn, &"cam_fit")

	_zoom_out_btn.pressed.connect(func() -> void: zoom_step_requested.emit(-CameraRig.KEY_ZOOM_NOTCHES))
	_readout_btn.pressed.connect(func() -> void: zoom_set_requested.emit(1.0))
	_zoom_in_btn.pressed.connect(func() -> void: zoom_step_requested.emit(CameraRig.KEY_ZOOM_NOTCHES))
	_fit_btn.pressed.connect(func() -> void: fit_requested.emit())
	set_zoom(_zoom, _min_zoom, _max_zoom)


## Updates the displayed zoom readout and min/max button enabled states.
func set_zoom(zoom: float, min_zoom: float = 0.0, max_zoom: float = ZoomModel.ZOOM_MAX) -> void:
	_zoom = zoom
	_min_zoom = min_zoom
	_max_zoom = max_zoom
	if not is_node_ready():
		return
	_readout_btn.text = "%d%%" % roundi(zoom * 100.0)
	_zoom_out_btn.disabled = min_zoom > 0.0 and zoom <= min_zoom + 0.001
	_zoom_in_btn.disabled = zoom >= max_zoom - 0.001


func zoom_value() -> float:
	return _zoom


func zoom_out_button() -> KitButton:
	return _zoom_out_btn


func readout_button() -> KitButton:
	return _readout_btn


func zoom_in_button() -> KitButton:
	return _zoom_in_btn


func fit_button() -> KitButton:
	return _fit_btn


func refresh_hotkeys() -> void:
	if not is_node_ready():
		return
	_zoom_out_btn.refresh_hotkey()
	_zoom_in_btn.refresh_hotkey()
	_fit_btn.refresh_hotkey()


func _configure_button(btn: KitButton, action: StringName) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	if action != &"":
		btn.hotkey_action = action
