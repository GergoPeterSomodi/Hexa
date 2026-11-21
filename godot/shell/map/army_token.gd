## One army token on the map (docs/architecture/m6-build-spec.md 6.3; L16): the country's plate in its colour, the figure of
## its main kind, the strength badge, a small state icon and the selection ring, all from the L14 Kit pieces. Its origin is
## the foot of the token, the centre of its hex; the parts stand above it. It shows what ArmyView.tokens says and changes
## nothing in the game. Built in code (no scene file): the parts are plain Sprite2D and Label children.
class_name ArmyToken
extends Node2D

## How far the token stands above its hex's centre (map pixels).
const LIFT := -20.0
const BADGE_OFFSET := Vector2(0.0, 6.0)
const BADGE_SIZE := Vector2(36.0, 18.0)
const STATE_OFFSET := Vector2(17.0, -40.0)
const FONT_SIZE := 12
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
	_ring = _sprite(&"army_plate_ring", Vector2(0.0, LIFT))
	_plate = _sprite(&"army_plate", Vector2(0.0, LIFT))
	_figure = _sprite(FIGURE_FALLBACK, Vector2(0.0, LIFT - 8.0))
	_badge = _sprite(&"army_badge", BADGE_OFFSET)
	_state = _sprite(&"march", STATE_OFFSET)
	_text = Label.new()
	_text.position = BADGE_OFFSET - BADGE_SIZE * 0.5
	_text.size = BADGE_SIZE
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.add_theme_font_size_override(&"font_size", FONT_SIZE)
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
	_figure.texture = ArmyToken.kit_icon(figure if figure != &"" else FIGURE_FALLBACK, self)
	_text.text = str(token.text)
	_state.texture = ArmyToken.kit_icon(_state_icon(token), self)
	_state.visible = _state.texture != null
	_text.add_theme_color_override(&"font_color", Tokens.INK)


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


func _sprite(icon_name: StringName, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = ArmyToken.kit_icon(icon_name, self)
	sprite.position = at
	add_child(sprite)
	return sprite
