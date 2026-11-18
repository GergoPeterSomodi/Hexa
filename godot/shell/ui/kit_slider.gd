## Studiolo slider pairing an expanding HSlider with a tabular Number Label
## (docs/architecture/ui-and-controls-spec.md section 3.5; ui-style-and-feedback-spec.md section 5).
class_name KitSlider
extends HBoxContainer

signal value_changed(new_value: float)
signal value_committed(new_value: float)

var min_value: float:
	get:
		return _slider.min_value
	set(v):
		_slider.min_value = v
		_update_label()

var max_value: float:
	get:
		return _slider.max_value
	set(v):
		_slider.max_value = v
		_update_label()

var step: float:
	get:
		return _slider.step
	set(v):
		_slider.step = v

var value: float:
	get:
		return _slider.value
	set(v):
		_slider.value = v
		_update_label()

@export var suffix: String = "":
	set(v):
		suffix = v
		_update_label()

@export var format_int: bool = true:
	set(v):
		format_int = v
		_update_label()

var disabled: bool = false:
	get:
		return not _slider.editable
	set(v):
		_slider.editable = not v
		_value_label.theme_type_variation = &"Reason" if v else &"Number"

var _slider: HSlider = null
var _value_label: Label = null


func _init() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, float(Tokens.TARGET_MIN))

	_slider = HSlider.new()
	_slider.name = &"Slider"
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.custom_minimum_size.y = float(Tokens.TARGET_MIN)
	_slider.value_changed.connect(_on_slider_value_changed)
	_slider.drag_ended.connect(_on_slider_drag_ended)
	add_child(_slider)

	_value_label = Label.new()
	_value_label.name = &"ValueLabel"
	_value_label.theme_type_variation = &"Number"
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.custom_minimum_size.x = 48.0
	add_child(_value_label)

	_update_label()


## Sets slider bounds (`min_v`, `max_v`, `step_v`) and refreshes the displayed value label.
func set_bounds(min_v: float, max_v: float, step_v: float = 1.0) -> void:
	_slider.min_value = min_v
	_slider.max_value = max_v
	_slider.step = step_v
	_update_label()


## Sets the slider value, emitting `value_changed` only when `emit` is true.
func set_slider_value(v: float, emit: bool = false) -> void:
	_slider.set_value_no_signal(v)
	_update_label()
	if emit:
		value_changed.emit(_slider.value)


## Returns the inner `HSlider` control.
func slider() -> HSlider:
	return _slider


## Returns the inner tabular `Label` displaying the formatted value.
func value_label() -> Label:
	return _value_label


func _update_label() -> void:
	if _value_label == null or _slider == null:
		return
	var num_text := str(roundi(_slider.value)) if format_int else String.num(_slider.value, 2)
	_value_label.text = num_text + suffix


func _on_slider_value_changed(new_value: float) -> void:
	_update_label()
	value_changed.emit(new_value)


func _on_slider_drag_ended(_changed: bool) -> void:
	value_committed.emit(_slider.value)
