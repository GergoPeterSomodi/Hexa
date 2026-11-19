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


## The width that shows the title on one line, padding included (MIN_WIDTH at least; needs the theme, so call it
## once the ribbon is in the tree).
func single_line_width() -> float:
	if _label == null or _label.text.is_empty():
		return MIN_WIDTH
	var font := _label.get_theme_font(&"font")
	var font_size := _label.get_theme_font_size(&"font_size")
	if font == null or font_size <= 0:
		return MIN_WIDTH
	var sb := get_theme_stylebox(&"panel")
	var pad_x := 80.0
	if sb != null:
		pad_x = maxf(72.0, sb.content_margin_left + sb.content_margin_right + 12.0)
	var text_w := font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return maxf(MIN_WIDTH, text_w + pad_x)


## Computes and applies centered overhanging offsets so the ribbon expands to fit 1 line when possible.
func fit_overhang(max_w: float = 520.0, top_y: float = -22.0, center_x_offset: float = 0.0) -> void:
	var upper_bound := maxf(MIN_WIDTH, max_w)
	var single_w := single_line_width()
	var target_w := clampf(single_w, MIN_WIDTH, upper_bound)
	var needs_two_lines := single_w > target_w + 1.0
	var target_h := 56.0 if needs_two_lines else 40.0
	custom_minimum_size = Vector2(target_w, target_h)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = center_x_offset - target_w * 0.5
	offset_right = center_x_offset + target_w * 0.5
	offset_top = top_y
	offset_bottom = top_y + target_h


func _apply_text() -> void:
	if _label == null:
		return
	_label.text = text.to_upper()
	accessibility_name = text
