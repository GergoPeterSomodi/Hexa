## Opaque Studiolo loading screen displaying a progress bar on the KitTheme progress channel,
## status message, optional hint, and optional cancel action
## (docs/architecture/ui-and-controls-spec.md section 3.2, 5.1, 7;
## docs/architecture/ui-style-and-feedback-spec.md section 2, 4.7).
class_name Loading
extends Screen

signal cancelled

@onready var _title_label: Label = $Backdrop/Center/Card/VBox/Title
@onready var _progress_bar: ProgressBar = $Backdrop/Center/Card/VBox/ProgressBar
@onready var _status_label: Label = $Backdrop/Center/Card/VBox/Status
@onready var _hint_label: Label = $Backdrop/Center/Card/VBox/Hint
@onready var _actions_box: HBoxContainer = $Backdrop/Center/Card/VBox/Actions
@onready var _cancel_btn: KitButton = $Backdrop/Center/Card/VBox/Actions/CancelButton

var _title_text: String = "Building the map"
var _status_text: String = "Preparing..."
var _hint_text: String = ""
var _progress_fraction: float = 0.0
var _cancelable: bool = false
var _on_cancel: Callable = Callable()
var _progress_source: Callable = Callable()
var _ui_ready: bool = false


func _ready() -> void:
	_ui_ready = true
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_apply_state()
	set_process(_progress_source.is_valid())


func _process(_delta: float) -> void:
	if not _progress_source.is_valid():
		set_process(false)
		return
	var frac := clampf(float(_progress_source.call()), 0.0, 1.0)
	set_progress(frac, "Drawing the map %d %%" % roundi(frac * 100.0))


func on_enter() -> void:
	_apply_state()


func on_exit() -> void:
	set_process(false)


## Loading screen ignores Esc unless cancelable is explicitly active and handled by Cancel.
func back() -> bool:
	return true


## Updates the modal title and status message.
func set_status(title_text_val: String, message_text: String = "") -> void:
	_title_text = title_text_val
	if not message_text.is_empty():
		_status_text = message_text
	_apply_state()


## Updates the progress fraction in [0.0, 1.0] and optionally the status message.
func set_progress(fraction: float, message_text: String = "") -> void:
	_progress_fraction = clampf(fraction, 0.0, 1.0)
	if not message_text.is_empty():
		_status_text = message_text
	_apply_state()


## Sets an optional secondary hint below the status message (empty hides it).
func set_hint(hint: String) -> void:
	_hint_text = hint
	_apply_state()


## Enables or disables an optional Cancel button with callback `on_cancel`.
func set_cancelable(enabled: bool, on_cancel: Callable = Callable()) -> void:
	_cancelable = enabled
	_on_cancel = on_cancel
	_apply_state()


## Binds a callable `() -> float` returning [0.0, 1.0] polled during `_process`.
func set_progress_source(source: Callable) -> void:
	_progress_source = source
	if _ui_ready:
		set_process(_progress_source.is_valid())


func progress_value() -> float:
	return _progress_fraction


func title_text() -> String:
	return _title_text


func status_text() -> String:
	return _status_text


func progress_bar() -> ProgressBar:
	return _progress_bar


func cancel_button() -> KitButton:
	return _cancel_btn


func _apply_state() -> void:
	if not _ui_ready:
		return
	_title_label.text = _title_text.to_upper()
	_progress_bar.value = _progress_fraction * 100.0
	_status_label.text = _status_text
	_hint_label.text = _hint_text
	_hint_label.visible = not _hint_text.is_empty()
	_actions_box.visible = _cancelable
	_cancel_btn.reduce_motion = _reduce_motion()
	if _cancelable:
		default_focus = get_path_to(_cancel_btn)
	else:
		default_focus = NodePath()


func _on_cancel_pressed() -> void:
	if not _cancelable:
		return
	cancelled.emit()
	if _on_cancel.is_valid():
		_on_cancel.call()
	finished.emit(&"cancel")


func _reduce_motion() -> bool:
	if ctx != null and ctx.settings != null:
		return bool(ctx.settings.get_value("accessibility/reduce_motion"))
	return false
