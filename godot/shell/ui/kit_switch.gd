## Studiolo themed CheckButton switch with minimum hit target enforcement and automatic
## accessible name fallback from `text`
## (docs/architecture/ui-and-controls-spec.md section 3.5; ui-style-and-feedback-spec.md section 5).
class_name KitSwitch
extends CheckButton

var _auto_accessibility_name: String = ""


func _init() -> void:
	theme_type_variation = &"KitSwitch"
	custom_minimum_size.y = maxf(custom_minimum_size.y, float(Tokens.TARGET_MIN))


func _ready() -> void:
	_sync_accessibility_name()


func _set(property: StringName, value: Variant) -> bool:
	if property == &"text":
		text = str(value)
		_sync_accessibility_name()
		return true
	return false


func _sync_accessibility_name() -> void:
	if text.is_empty():
		if accessibility_name == _auto_accessibility_name:
			_auto_accessibility_name = ""
			accessibility_name = ""
		return
	if accessibility_name.is_empty() or accessibility_name == _auto_accessibility_name:
		_auto_accessibility_name = text
		accessibility_name = text
