## Pointed walnut cartouche header plate for side panels and cards
## (docs/architecture/ui-style-and-feedback-spec.md sections 4.3, 4.5, 4.7 and 5).
class_name Cartouche
extends PanelContainer

@export var text: String = "":
	set(value):
		text = value
		_apply_text()

var _label: Label = null


func _init() -> void:
	theme_type_variation = &"PanelCartouche"
	mouse_filter = Control.MOUSE_FILTER_PASS

	_label = Label.new()
	_label.name = &"Label"
	_label.theme_type_variation = &"TitlePanel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.max_lines_visible = 1
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_apply_text()


## Returns the inner Label displaying the upper-cased Cinzel panel title.
func label() -> Label:
	return _label


func _apply_text() -> void:
	if _label == null:
		return
	_label.text = text.to_upper()
	tooltip_text = text
	accessibility_name = text
