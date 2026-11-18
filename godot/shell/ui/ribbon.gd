## Crimson velvet ribbon banner for modal and vellum-sheet titles
## (docs/architecture/ui-style-and-feedback-spec.md sections 4.3, 4.5, 4.7 and 5).
class_name Ribbon
extends PanelContainer

const MIN_WIDTH: float = 230.0
const MAX_LINES: int = 2

@export var text: String = "":
	set(value):
		text = value
		_apply_text()

var _label: Label = null


func _init() -> void:
	theme_type_variation = &"PanelRibbon"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = MIN_WIDTH

	_label = Label.new()
	_label.name = &"Label"
	_label.theme_type_variation = &"TitleRibbon"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.max_lines_visible = MAX_LINES
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_apply_text()


## Returns the inner Label displaying the upper-cased Cinzel ribbon title.
func label() -> Label:
	return _label


func _apply_text() -> void:
	if _label == null:
		return
	_label.text = text.to_upper()
	accessibility_name = text
