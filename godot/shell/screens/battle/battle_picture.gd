## The face-off picture of the battle dock (docs/architecture/m7-build-spec.md 6.5; M7 B22): the attacker's figure on the left
## and the defender's on the right, facing each other, with the battle badge between them and the caption under (the ground,
## the lanes and the day). Kit pieces only; the terrain tile of the season is not drawn yet (see the dock's report note).
class_name BattlePicture
extends VBoxContainer

const FIGURE_PX: float = 40.0
const BADGE_PX: float = 40.0

var _left: TextureRect = null
var _badge: TextureRect = null
var _right: TextureRect = null
var _caption: Label = null


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left = _figure(false)
	row.add_child(_left)
	_badge = TextureRect.new()
	_badge.custom_minimum_size = Vector2(BADGE_PX, BADGE_PX)
	_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_badge)
	_right = _figure(true)
	row.add_child(_right)
	add_child(row)
	_caption = PanelKit.label("", &"Hint")
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_caption)


func _ready() -> void:
	_badge.texture = _kit(&"badge_battle")


## Sets the two figures (kit icon names, "" for none) and the caption under the picture.
func set_picture(attacker_figure: StringName, defender_figure: StringName, caption: String) -> void:
	_left.texture = _kit(attacker_figure)
	_right.texture = _kit(defender_figure)
	_caption.text = caption
	_caption.visible = caption != ""


## The caption text (empty when none).
func caption() -> String:
	return _caption.text


## The kit textures shown on the left and the right (null when none).
func figures() -> Array[Texture2D]:
	return [_left.texture, _right.texture]


func _figure(flip: bool) -> TextureRect:
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(FIGURE_PX, FIGURE_PX)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.flip_h = flip
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex


func _kit(name: StringName) -> Texture2D:
	if name == &"":
		return null
	return get_theme_icon(name, &"Kit") if has_theme_icon(name, &"Kit") else null
