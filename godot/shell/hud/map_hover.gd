## Map hex hover card controller using HoverCard + HexCard, with tooltip delay, viewport/MapArea clamping,
## drag/UI suppression, and live refresh on Events.hex_changed
## (docs/architecture/ui-and-controls-spec.md section 7; ui-style-and-feedback-plan.md U14).
class_name MapHover
extends Control

const HOVER_CARD_SCENE := preload("res://shell/ui/hover_card.tscn")
const CURSOR_OFFSET := Vector2(18.0, 18.0)

const DELAY_BY_CHOICE: Dictionary[String, float] = {
	"short": 0.2,
	"normal": 0.5,
	"long": 1.0,
}

@export var hover_delay_sec: float = 0.5
@export var hover_cards_enabled: bool = true:
	set(value):
		hover_cards_enabled = value
		if not hover_cards_enabled:
			_clear_card()

var _card: HoverCard = null
var _hovered_hex: Vector2i = MapInput.NO_HEX
var _pointer_pos: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _shown: bool = false
var _dragging: bool = false
var _settings: Settings = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_card()
	if not Events.hex_changed.is_connected(_on_hex_changed):
		Events.hex_changed.connect(_on_hex_changed)


func _exit_tree() -> void:
	if Events.hex_changed.is_connected(_on_hex_changed):
		Events.hex_changed.disconnect(_on_hex_changed)
	_disconnect_settings()


func _process(delta: float) -> void:
	if _hovered_hex == MapInput.NO_HEX or not hover_cards_enabled or _dragging:
		return
	if _is_ui_hovered():
		_clear_card()
		return
	if _shown:
		_position_card()
		return
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= hover_delay_sec:
		_show_current()


## Pure clamping helper keeping `card_size` inside `bounds` near `pointer`.
static func clamp_card_position(pointer: Vector2, card_size: Vector2, bounds: Rect2) -> Vector2:
	var pad := float(Tokens.S2)
	var x := pointer.x + CURSOR_OFFSET.x
	if x + card_size.x > bounds.end.x - pad:
		x = pointer.x - card_size.x - float(Tokens.S3)
	var max_x := maxf(bounds.position.x + pad, bounds.end.x - card_size.x - pad)
	x = clampf(x, bounds.position.x + pad, max_x)

	var y := pointer.y + CURSOR_OFFSET.y
	if y + card_size.y > bounds.end.y - pad:
		y = pointer.y - card_size.y - float(Tokens.S3)
	var max_y := maxf(bounds.position.y + pad, bounds.end.y - card_size.y - pad)
	y = clampf(y, bounds.position.y + pad, max_y)
	return Vector2(x, y)


func configure(settings: Settings) -> void:
	if settings == _settings:
		if settings != null:
			_apply_settings(settings)
		return
	_disconnect_settings()
	_settings = settings
	if _settings == null:
		return
	_settings.changed.connect(_on_setting_changed)
	_apply_settings(_settings)


func on_hover_changed(hex: Vector2i, pointer_pos: Variant = null) -> void:
	_ensure_card()
	if pointer_pos is Vector2:
		_pointer_pos = pointer_pos as Vector2
	if hex == MapInput.NO_HEX or not hover_cards_enabled or _dragging:
		_clear_card()
		return
	if Session.game == null or Session.game.map == null or not Session.game.map.has(hex):
		_clear_card()
		return
	if hex != _hovered_hex:
		_hovered_hex = hex
		_elapsed = 0.0
		_shown = false
		_card.clear()
		if hover_delay_sec <= 0.0 and not _is_ui_hovered():
			_show_current()
	elif _shown:
		_position_card()


func set_pointer_position(pos: Vector2) -> void:
	_pointer_pos = pos
	if _shown:
		_position_card()


func set_dragging(dragging: bool) -> void:
	_dragging = dragging
	if _dragging:
		_clear_card()


func card() -> HoverCard:
	_ensure_card()
	return _card


func hovered_hex() -> Vector2i:
	return _hovered_hex


func is_card_visible() -> bool:
	return _card != null and _card.visible


func _ensure_card() -> void:
	if _card == null:
		_card = HOVER_CARD_SCENE.instantiate() as HoverCard
		_card.visible = false
		_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_card)


func _show_current() -> void:
	if _hovered_hex == MapInput.NO_HEX or Session.game == null:
		_clear_card()
		return
	var model := HexCard.of(Session.game, _hovered_hex)
	if model.is_empty():
		_clear_card()
		return
	_ensure_card()
	_card.show_card(model)
	_shown = true
	_position_card()


func _clear_card() -> void:
	_hovered_hex = MapInput.NO_HEX
	_elapsed = 0.0
	_shown = false
	if _card != null:
		_card.clear()


func _position_card() -> void:
	if _card == null or not _card.visible:
		return
	var bounds := _available_bounds()
	var csize := _card.get_combined_minimum_size()
	if _card.size.x > csize.x or _card.size.y > csize.y:
		csize = Vector2(maxf(_card.size.x, csize.x), maxf(_card.size.y, csize.y))
	_card.position = clamp_card_position(_pointer_pos, csize, bounds)


func _available_bounds() -> Rect2:
	if size.x > 0.0 and size.y > 0.0:
		return Rect2(Vector2.ZERO, size)
	if is_inside_tree():
		var vp := get_viewport()
		if vp != null:
			var vr := vp.get_visible_rect()
			if vr.size.x > 0.0 and vr.size.y > 0.0:
				return Rect2(Vector2.ZERO, vr.size)
	return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


func _is_ui_hovered() -> bool:
	if not is_inside_tree():
		return false
	var vp := get_viewport()
	return vp != null and vp.gui_get_hovered_control() != null


func _on_hex_changed(hex: Vector2i) -> void:
	if _shown and hex == _hovered_hex:
		_show_current()


func _apply_settings(settings: Settings) -> void:
	var delay_key := str(settings.get_value("accessibility/tooltip_delay"))
	hover_delay_sec = float(DELAY_BY_CHOICE.get(delay_key, 0.5))
	if Settings.SCHEMA.has("ui/hover_cards"):
		hover_cards_enabled = bool(settings.get_value("ui/hover_cards"))


func _on_setting_changed(key: String, _value: Variant) -> void:
	if _settings != null and (key == "accessibility/tooltip_delay" or key == "ui/hover_cards"):
		_apply_settings(_settings)


func _disconnect_settings() -> void:
	if _settings != null and _settings.changed.is_connected(_on_setting_changed):
		_settings.changed.disconnect(_on_setting_changed)
	_settings = null
