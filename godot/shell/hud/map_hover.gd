## Map hex hover card controller using HoverCard + HexCard, with tooltip delay, viewport/MapArea clamping,
## drag/UI suppression, and live refresh on Events.hex_changed
## (docs/architecture/ui-and-controls-spec.md section 7; ui-style-and-feedback-plan.md U14).
class_name MapHover
extends Control

const HOVER_CARD_SCENE := preload("res://shell/ui/hover_card.tscn")
const CURSOR_OFFSET := Vector2(18.0, 18.0)
## The group MapArmies calls for the order cursor (order_cursor_moved); the move card (6.7) is this node's child.
const GROUP := &"map_hover"
const MOVE_CARD_SCENE := preload("res://shell/hud/move_card.tscn")
## The odds card (6.4): the hover of a war target of the selected army, in place of the move card.
const ODDS_CARD_SCENE := preload("res://shell/hud/odds_card.tscn")

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
## The move card (6.7): while an army of yours is selected, the hover over another hex shows MovePreview.to's words in place of
## the hex card; the keyboard's order cursor (order_cursor_moved) stands in for the pointer.
var _move: MoveCard = null
var _odds: OddsCard = null
var _army := -1
var _keyboard := false
var _cursor_hex: Vector2i = MapInput.NO_HEX
var _cursor_screen := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(GROUP)
	_ensure_card()
	if not Events.hex_changed.is_connected(_on_hex_changed):
		Events.hex_changed.connect(_on_hex_changed)
	_bind(Events.army_selected, _on_army_selected)
	_bind(Events.army_cleared, _on_army_cleared)
	_bind(Events.army_changed, _on_army_event)
	_bind(Events.season_ended, _on_army_event)
	_bind(Events.game_ended, _on_army_cleared)


func _exit_tree() -> void:
	if Events.hex_changed.is_connected(_on_hex_changed):
		Events.hex_changed.disconnect(_on_hex_changed)
	_unbind(Events.army_selected, _on_army_selected)
	_unbind(Events.army_cleared, _on_army_cleared)
	_unbind(Events.army_changed, _on_army_event)
	_unbind(Events.season_ended, _on_army_event)
	_unbind(Events.game_ended, _on_army_cleared)
	_disconnect_settings()


func _process(delta: float) -> void:
	if _move_wanted():
		return
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
	_keyboard = false
	_track(hex)
	_refresh_move()


func set_pointer_position(pos: Vector2) -> void:
	_pointer_pos = pos
	if _shown:
		_position_card()
	_position_move()


func set_dragging(dragging: bool) -> void:
	_dragging = dragging
	if _dragging:
		_clear_card()
		_hide_move()


## The order cursor of an army of yours moved to `hex` (MapArmies, Alt+arrows); `screen` is the hex's centre on the screen.
## The move card follows it, and the pointer's hover takes over again at the next pointer move.
func order_cursor_moved(hex: Vector2i, screen: Vector2) -> void:
	_keyboard = true
	_cursor_hex = hex
	_cursor_screen = screen
	_refresh_move()


## The move card (6.7) of the hover, for the tests and the pictures; created on first use.
func move_card() -> MoveCard:
	_ensure_move()
	return _move


## The odds card (6.4) of the hover, for the tests and the pictures; created on first use.
func odds_card() -> OddsCard:
	_ensure_odds()
	return _odds


## True while a war mark on `hex` owns the hover (M7 B25): no army of yours is selected and the war layer has a card there.
func war_mark_at(hex: Vector2i) -> bool:
	if _army >= 0 or not is_inside_tree():
		return false
	var marks := get_tree().get_first_node_in_group(WarMarks.GROUP) as WarMarks
	return marks != null and not marks.card_at(hex).is_empty()


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
	if _move_wanted():
		return
	if war_mark_at(_hovered_hex):  # M7 B25: the war card owns a mark's hex
		_clear_card()
		return
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


## The hover's own tracking: the hex under the pointer, its delay and the hex card (the body the hover always had).
func _track(hex: Vector2i) -> void:
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


## The hex the move card is for: the order cursor after a keyboard move, else the hovered hex.
func _move_hex() -> Vector2i:
	return _cursor_hex if _keyboard else _hovered_hex


## Whether the move card replaces the hex card now: an army of yours is selected, the hex is on the map, not the army's own,
## and the hover is live (no drag, no UI under the pointer).
func _move_wanted() -> bool:
	var game := Session.game
	if _army < 0 or not hover_cards_enabled or _dragging or game == null or game.map == null:
		return false
	var hex := _move_hex()
	if hex == MapInput.NO_HEX or not game.map.has(hex) or _is_ui_hovered():
		return false
	var own := ArmyView.panel(game, Session.player_tag(), _army).get("hex", MapInput.NO_HEX) as Vector2i
	return hex != own


func _refresh_move() -> void:
	if not _move_wanted():
		_hide_move()
		return
	_ensure_move()
	_shown = false
	_elapsed = 0.0
	if _card != null:
		_card.clear()
	var tag := Session.player_tag()
	var preview := MovePreview.to(Session.game, tag, _army, _move_hex())
	var odds := OddsCard.odds_of(Session.game, tag, _army, _move_hex(), preview)
	if OddsCard.wants(preview, odds):
		_move.hide_card()
		_ensure_odds()
		_odds.show_odds(preview, odds)
	else:
		_hide_odds()
		_move.show_move(preview)
	_position_move()


func _hide_move() -> void:
	if _move != null:
		_move.hide_card()
	_hide_odds()


func _hide_odds() -> void:
	if _odds != null:
		_odds.hide_card()


func _ensure_odds() -> void:
	if _odds == null:
		_odds = ODDS_CARD_SCENE.instantiate() as OddsCard
		_odds.visible = false
		add_child(_odds)


func _ensure_move() -> void:
	if _move == null:
		_move = MOVE_CARD_SCENE.instantiate() as MoveCard
		_move.visible = false
		add_child(_move)


func _position_move() -> void:
	if _move != null and _move.is_open():
		_place_move_card(_move)
	if _odds != null and _odds.is_open():
		_place_move_card(_odds)


## Places a move or odds card at the pointer, or at the order cursor's hex centre after a keyboard move.
func _place_move_card(card: MoveCard) -> void:
	var anchor := _pointer_pos
	var to_local := get_global_transform_with_canvas().affine_inverse()
	if _keyboard:
		anchor = to_local * _cursor_screen
	elif is_inside_tree() and get_viewport() != null:
		anchor = to_local * get_viewport().get_mouse_position()  # the pointer is in viewport pixels, this node is not at 0,0
	card.place(anchor, _available_bounds())


func _on_army_selected(army_id: int) -> void:
	_army = army_id
	_keyboard = false
	_refresh_move()


func _on_army_cleared() -> void:
	_army = -1
	_keyboard = false
	_refresh_move()


func _on_army_event(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null, _e: Variant = null) -> void:
	_refresh_move()


func _bind(sig: Signal, fn: Callable) -> void:
	if not sig.is_connected(fn):
		sig.connect(fn)


func _unbind(sig: Signal, fn: Callable) -> void:
	if sig.is_connected(fn):
		sig.disconnect(fn)


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
