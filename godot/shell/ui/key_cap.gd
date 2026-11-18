## Bone key-cap badge reading an action's primary key binding from `Bindings` / InputMap
## (docs/architecture/ui-and-controls-spec.md section 3.5; ui-style-and-feedback-spec.md section 4.7).
class_name KeyCap
extends PanelContainer

const MIN_CAP_WIDTH: float = 32.0
const MIN_CAP_HEIGHT: float = 28.0

@export var action: StringName = &"":
	set(value):
		action = value
		refresh_from_input_map()

var key_text: String = "":
	set(value):
		key_text = value
		_apply_display()

var waiting: bool = false:
	set(value):
		waiting = value
		_apply_display()

var _label: Label = null


func _init() -> void:
	theme_type_variation = &"KeyCapPanel"
	custom_minimum_size = Vector2(MIN_CAP_WIDTH, maxf(MIN_CAP_HEIGHT, float(Tokens.TARGET_MIN)))

	_label = Label.new()
	_label.name = &"Label"
	_label.theme_type_variation = &"KeyCap"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_apply_display()


func _ready() -> void:
	if action != &"":
		refresh_from_input_map()
	else:
		_apply_display()


## Reads `Bindings.key_caps_for(action, platform)` and updates the displayed primary key cap.
func refresh_from_input_map(platform: String = OS.get_name()) -> void:
	if action == &"":
		key_text = ""
		return
	var caps := Bindings.key_caps_for(action, platform)
	key_text = caps[0] if not caps.is_empty() else ""


## Returns the inner `Label` displaying the key text.
func label() -> Label:
	return _label


func _apply_display() -> void:
	theme_type_variation = &"KeyCapPanelWait" if waiting else &"KeyCapPanel"
	if _label == null:
		return
	var shown := "..." if waiting else (key_text if not key_text.is_empty() else "—")
	_label.text = shown
	accessibility_name = shown if action == &"" else "%s: %s" % [String(action), shown]
