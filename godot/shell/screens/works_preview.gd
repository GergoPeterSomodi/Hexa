## The works card screen (docs/architecture/m4-build-spec.md 6.5): the card of one work option, opened left of the hex panel
## over a live map. An OVERLAY: the map stays live and nothing pauses. show_option(hex, option) reads ImprovePreview.of for the
## player's country. Begin asks the App for the work (ctx.request(&"begin_work", {hex, option})) and closes the card; Enter
## and U begin too; Esc and Close close it. Pin keeps the card, and the next option opens beside it on one chart scale.
## Shift holds the card while the pointer is away (leave()). The treasury switch re-reads the gains and is remembered in
## game/gain_treasury_only. The card scrolls with the wheel when it is taller than the window.
class_name WorksPreview
extends Screen

const CARD_W: int = 556
## Room for the scroll bar beside the card.
const SCROLL_ROOM: int = Tokens.S3
const CARD_GAP: int = Tokens.S3
const BOTTOM_MARGIN: int = Tokens.S4
const BEGIN_REQUEST := &"begin_work"
const LOOK_REQUEST := &"look_at"
const BEGIN_ACTION := &"game_upgrade"
const TREASURY_KEY := "game/gain_treasury_only"

@onready var _scroll: ScrollContainer = $Scroll
@onready var _card: PreviewCard = $Scroll/Card

var _hex: Vector2i = Vector2i.ZERO
var _option: Dictionary = {}
var _preview: Dictionary = {}
var _pinned: Dictionary = {}
var _held: bool = false
var _pointer_left: bool = false
var _treasury: bool = false
var _beside: Rect2 = Rect2()
var _has_beside: bool = false
var _done: bool = false


func _init() -> void:
	kind = Screen.Kind.OVERLAY
	screen_id = &"works_preview"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.begin_pressed.connect(_begin)
	_card.closed.connect(_close)
	_card.pin_toggled.connect(pin)
	_card.treasury_only_toggled.connect(_on_treasury_toggled)
	_card.look_at_requested.connect(_on_look_at)
	resized.connect(_layout)
	_layout()


func on_enter() -> void:
	_done = false
	_treasury = _setting_treasury()
	_card.treasury_only = _treasury
	_layout()


## Esc closes the card (ScreenStack routes Esc here).
func back() -> bool:
	_close()
	return true


## Shows the card of `option` ({action, family}) on `hex` for the player's country. While a card is pinned, the option opens
## beside it.
## `focus` (the info button, the keyboard, U) puts the focus on Begin. A hover (`focus` false) never takes the focus, so the
## hex panel's row keeps it under the card.
func show_option(hex: Vector2i, option: Dictionary, focus: bool = false) -> void:
	_hex = hex
	_option = option.duplicate()
	_pointer_left = false
	_done = false
	if Session.game == null:
		_preview = {}
		_card.visible = false
		return
	_preview = ImprovePreview.of(Session.game, Session.player_tag(), hex, _option)
	_render(focus)


## Keeps the shown card (on) or lets it go (off). The next option shown while a card is pinned opens beside it on one scale.
func pin(on: bool) -> void:
	if on and not _preview.is_empty():
		_pinned = _preview
	else:
		_pinned = {}
	_render()


## Shift held (true) keeps the card while the pointer is away. Released (false) after the pointer left, the card closes.
func hold(on: bool) -> void:
	_held = on
	if not on and _pointer_left and _pinned.is_empty():
		_close()


## The pointer left the row that opened the card: the card closes unless Shift holds it or it is pinned.
func leave() -> void:
	_pointer_left = true
	if not _shift_down() and _pinned.is_empty():
		_close()


## Shift is held: from the key events this screen saw, or the keyboard state now (it may be down before the card opens).
func _shift_down() -> bool:
	return _held or Input.is_key_pressed(KEY_SHIFT)


## Places the card beside the hex panel's screen rect (the App passes it when it opens the card). Without it, the card sits
## left of the right-hand dock.
func set_beside(rect: Rect2) -> void:
	_beside = rect
	_has_beside = true
	_layout()


func card() -> PreviewCard:
	return _card


func scroll() -> ScrollContainer:
	return _scroll


## The card's rect in this screen's coordinates (what the window shows of it).
func card_rect() -> Rect2:
	return Rect2(_scroll.position, _scroll.size)


func preview() -> Dictionary:
	return _preview


func shown_hex() -> Vector2i:
	return _hex


func shown_option() -> Dictionary:
	return _option


func pinned() -> bool:
	return not _pinned.is_empty()


func held() -> bool:
	return _held


func treasury() -> bool:
	return _treasury


func _render(focus: bool = false) -> void:
	if _preview.is_empty():
		return
	_card.treasury_only = _treasury
	if _pinned.is_empty() or _pinned == _preview:
		_card.set_pinned(not _pinned.is_empty())
		_card.show_preview(_preview)
	else:
		_card.set_pinned(true)
		_card.show_compare(_pinned, _preview)
	_card.visible = true
	if focus and is_inside_tree():
		_card.focus_begin()


func _begin() -> void:
	if _preview.is_empty() or _card.begin_button().disabled:
		return
	if ctx != null:
		ctx.request(BEGIN_REQUEST, {"hex": _hex, "option": _option})
	_close()


func _close() -> void:
	if _done:
		return
	_done = true
	finished.emit(&"closed")


func _on_treasury_toggled(on: bool) -> void:
	_treasury = on
	if ctx != null and ctx.settings != null:
		ctx.settings.set_value(TREASURY_KEY, on)
	_render()


func _on_look_at(hex: Vector2i) -> void:
	if ctx != null:
		ctx.request(LOOK_REQUEST, {"hex": hex, "select": true})


func _setting_treasury() -> bool:
	if ctx != null and ctx.settings != null:
		return bool(ctx.settings.get_value(TREASURY_KEY))
	return false


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.is_echo():
		return
	if key.keycode == KEY_SHIFT:
		hold(key.pressed)
		return
	if not key.pressed:
		return
	var begins := key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER
	if not begins and InputMap.has_action(BEGIN_ACTION) and event.is_action_pressed(BEGIN_ACTION, false, true):
		begins = true
	if not begins or _preview.is_empty():
		return
	# A shown card takes the key even when Begin is off: U must not reach the map's upgrade shortcut.
	accept_event()
	if not _card.begin_button().disabled:
		_begin()


## The card opens left of the hex panel, its top at the panel's top (never under the top bar), and its height fits the
## window less a margin; the scroll container takes the rest.
func _layout() -> void:
	if not is_node_ready():
		return
	var vp := get_viewport_rect().size
	var top := maxf(ctx.top_inset() if ctx != null else float(Tokens.BAR_H + Tokens.S2), 0.0)
	var right := float(CARD_GAP) + (vp.x - float(Tokens.PANEL_W))
	if _has_beside:
		top = maxf(top, _beside.position.y)
		right = _beside.position.x - float(CARD_GAP)
	var width := float(CARD_W + SCROLL_ROOM)
	var left := maxf(right - width, float(Tokens.S2))
	_scroll.position = Vector2(left, top)
	_scroll.size = Vector2(width, maxf(0.0, vp.y - top - float(BOTTOM_MARGIN)))
