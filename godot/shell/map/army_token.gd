## One army token on the map (docs/architecture/m6-build-spec.md 6.3; L16): the country's plate in its colour, the figure of
## its main kind, the strength badge, a small state icon and the selection ring, all from the L14 Kit pieces. Its origin is
## the foot of the token, the centre of its hex; the plate stands above the hex centre, so the town icon on the centre stays
## in view. Sizes are on-map sizes at zoom 1 (a hex is 104 px wide): each Kit piece is scaled to its size here, whatever
## the texture's pixel size. It shows what ArmyView.tokens says and changes nothing in the game. Built in code (no scene
## file): the parts are plain Sprite2D and Label children.
class_name ArmyToken
extends Node2D

## On-map sizes at zoom 1 (px): the plate (about 38 % of a hex's width, so it reads at a glance), its selection ring, the
## figure inside it, the strength badge under it, the state icon at its top right corner.
const PLATE_SIZE := Vector2(40.0, 34.0)
const RING_SIZE := Vector2(52.0, 45.0)
const FIGURE_SIZE := Vector2(26.0, 26.0)
const BADGE_SIZE := Vector2(46.0, 22.0)
const STATE_SIZE := Vector2(16.0, 16.0)
## The plate's centre above the hex centre (px): the plate's bottom edge stays above the town icon on the centre.
const LIFT := -34.0
const BADGE_OFFSET := Vector2(0.0, -11.0)
const STATE_OFFSET := Vector2(18.0, -47.0)
## The strength text: 14 px in the light Studiolo text colour on the dark badge slot, with a 3 px dark ink outline.
const TEXT_INK := Tokens.TEXT
const FONT_SIZE := 14
const OUTLINE_SIZE := 3
const FIGURE_FALLBACK := &"fig_infantry"
## The state icon of a token's flag (ArmyView's keys): mustering, marching, waiting in winter, hungry.
const STATE_ICONS: Dictionary[StringName, StringName] = {
	&"mustering": &"muster", &"marching": &"march", &"waiting": &"wait_snow", &"hungry": &"supply_out",
}

## The Kit icons of the window's theme, else the project's, else the Studiolo theme from disk (the first that has the icon).
static var _studiolo: Theme = null

## The army ids on the token (empty for a foreign token) and its hex and country: set by show_token.
var armies := PackedInt32Array()
var hex := Vector2i.ZERO
var tag := &""

var _plate: Sprite2D = null
var _figure: Sprite2D = null
var _badge: Sprite2D = null
var _text: Label = null
var _state: Sprite2D = null
var _ring: Sprite2D = null


func _init() -> void:
	_ring = _sprite(&"army_plate_ring", Vector2(0.0, LIFT), RING_SIZE)
	_plate = _sprite(&"army_plate", Vector2(0.0, LIFT), PLATE_SIZE)
	_figure = _sprite(FIGURE_FALLBACK, Vector2(0.0, LIFT - 1.0), FIGURE_SIZE)
	_badge = _sprite(&"army_badge", BADGE_OFFSET, BADGE_SIZE)
	_state = _sprite(&"march", STATE_OFFSET, STATE_SIZE)
	_text = Label.new()
	_text.position = BADGE_OFFSET - BADGE_SIZE * 0.5
	_text.size = BADGE_SIZE
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.add_theme_font_size_override(&"font_size", FONT_SIZE)
	_text.add_theme_constant_override(&"outline_size", OUTLINE_SIZE)
	_text.add_theme_color_override(&"font_color", TEXT_INK)
	_text.add_theme_color_override(&"font_outline_color", Tokens.INK)
	add_child(_text)
	_ring.visible = false
	_state.visible = false


## Sets the token's picture from ArmyView.tokens' dictionary and the country's colour.
func show_token(token: Dictionary, colour: Color) -> void:
	hex = token.hex as Vector2i
	tag = StringName(token.tag)
	armies = token.armies as PackedInt32Array
	_plate.modulate = colour
	var figure := StringName(token.figure)
	_set_icon(_figure, figure if figure != &"" else FIGURE_FALLBACK, FIGURE_SIZE)
	_text.text = str(token.text)
	_set_icon(_state, _state_icon(token), STATE_SIZE)
	_state.visible = _state.texture != null


## The state icon's name for the token's first flag that is set, &"" for none.
static func state_name(token: Dictionary) -> StringName:
	for flag: StringName in [&"mustering", &"marching", &"waiting", &"hungry"]:
		if bool(token.get(flag, false)):
			return flag
	return &""


func _state_icon(token: Dictionary) -> StringName:
	var flag := state_name(token)
	return STATE_ICONS.get(flag, &"") as StringName


## Shows or hides the selection ring.
func set_ring(on: bool) -> void:
	_ring.visible = on


## The plate's colour (the country's, in the palette in use: tests and the colour-blind check).
func plate_colour() -> Color:
	return _plate.modulate


## The plate's size on the map at zoom 1, in px (PLATE_SIZE: tests and the pictures' check).
func plate_size() -> Vector2:
	return _plate.texture.get_size() * _plate.scale if _plate.texture != null else Vector2.ZERO


## The strength text's colour (TEXT_INK) and the badge's fill under its middle (tests: the contrast of the number).
func badge_text_colour() -> Color:
	return _text.get_theme_color(&"font_color")


func badge_fill() -> Color:
	if _badge.texture == null:
		return Color.BLACK
	var img := _badge.texture.get_image()
	return img.get_pixel(img.get_width() >> 1, img.get_height() >> 1)


## The label's size in px (the badge's size: the text is centred in it).
func badge_label_size() -> Vector2:
	return _text.size


## The strength text's font size in px (FONT_SIZE).
func badge_font_size() -> int:
	return _text.get_theme_font_size(&"font_size")


## Whether the selection ring is up (tests and the cursor's check).
func ringed() -> bool:
	return _ring.visible


## The badge's text (the men as ArmyView.token_text gives them).
func badge_text() -> String:
	return _text.text


## The figure's texture (the kind's Kit figure), null when the token has none.
func figure_texture() -> Texture2D:
	return _figure.texture


## Whether the state icon is up (a muster, a march, a winter wait or a hungry army).
func state_shown() -> bool:
	return _state.visible


## The token's size on the screen: the art at scale 1 above zoom 0.6, and at 0.6 / zoom below it (so it keeps its size).
func set_zoom(zoom: float) -> void:
	var s := 1.0 if zoom <= 0.0 else maxf(1.0, 0.6 / zoom)
	scale = Vector2(s, s)


## The Kit icon named `icon_name`, from the window's theme when it has one, else the project's, else the Studiolo theme.
static func kit_icon(icon_name: StringName, from: Node = null) -> Texture2D:
	var themes: Array[Theme] = []
	if from != null and from.is_inside_tree() and from.get_window() != null and from.get_window().theme != null:
		themes.append(from.get_window().theme)
	if ThemeDB.get_project_theme() != null:
		themes.append(ThemeDB.get_project_theme())
	if _studiolo == null and ResourceLoader.exists(KitTheme.THEME_PATH):
		_studiolo = load(KitTheme.THEME_PATH) as Theme
	if _studiolo != null:
		themes.append(_studiolo)
	for theme: Theme in themes:
		if theme.has_icon(icon_name, &"Kit"):
			return theme.get_icon(icon_name, &"Kit")
	return null


func _sprite(icon_name: StringName, at: Vector2, size: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.position = at
	add_child(sprite)
	_set_icon(sprite, icon_name, size)
	return sprite


## Gives `sprite` the Kit icon `icon_name` drawn at `size` px: the scale is the size over the texture's own size.
func _set_icon(sprite: Sprite2D, icon_name: StringName, size: Vector2) -> void:
	sprite.texture = ArmyToken.kit_icon(icon_name, self)
	if sprite.texture != null and sprite.texture.get_size() != Vector2.ZERO:
		sprite.scale = size / sprite.texture.get_size()
