## Studiolo brass medallion button (64 px full or 30 px chip size) with optional 4-quarter
## season dial, rotating busy ring via Motion.spin_ring, and static reduce-motion indicator
## (docs/architecture/ui-style-and-feedback-spec.md sections 4.11 and 5).
class_name Medallion
extends KitButton

const DIAL_SEGMENTS: int = 12

@export var small: bool = false:
	set(value):
		small = value
		_apply_medallion_size()
		_sync_ring_texture()

@export var dial: int = -1:
	set(value):
		dial = value
		_sync_dial()

@export var busy: bool = false:
	set(value):
		if busy == value and _busy_initialized:
			return
		busy = value
		_busy_initialized = true
		_apply_busy(busy, reduce_motion)

var _busy_initialized: bool = false
var _spinning: bool = false
var _spin_tween: Tween = null

var _dial_node: Control = null
var _ring: Control = null
var _ring_icon: TextureRect = null
var _hand: TextureRect = null
var _busy_icon: TextureRect = null
var _busy_label: Label = null


## Rotation of the dial hand (it points up at rest) to the middle of lit quarter `quarter` (0 to 3).
static func hand_rotation(quarter: int) -> float:
	return deg_to_rad(45.0 + 90.0 * float(quarter))


func _init() -> void:
	super._init()
	kind = KitButton.Kind.MEDALLION
	_build_children()
	_apply_medallion_size()
	_sync_dial()


func _ready() -> void:
	super._ready()
	_apply_medallion_size()
	_sync_ring_texture()
	_sync_dial()
	_sync_busy_icon_texture()
	if busy:
		_apply_busy(true, reduce_motion)


func _exit_tree() -> void:
	_stop_spin_tween()


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_THEME_CHANGED:
		_sync_ring_texture()
		_sync_busy_icon_texture()
		_sync_hand()
		if _ring != null:
			_ring.queue_redraw()
		if _dial_node != null:
			_dial_node.queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		if _ring != null:
			_ring.pivot_offset = size * 0.5
			_ring.queue_redraw()
		if _hand != null:
			_hand.pivot_offset = size * 0.5
		if _dial_node != null:
			_dial_node.queue_redraw()


## The busy hourglass texture (reduce motion), or null when the theme has none.
func busy_icon_node() -> TextureRect:
	return _busy_icon


## The dial's hand (a child of Dial, shown on a lit quarter).
func hand_node() -> TextureRect:
	return _hand


## Sets busy state, spinning the ring unless `p_reduce_motion` is true (which shows a static indicator).
func set_busy(on: bool, p_reduce_motion: bool = false) -> void:
	busy = on
	_busy_initialized = true
	_apply_busy(on, p_reduce_motion)


## Returns true when the busy ring spin animation is currently active.
func is_spinning() -> bool:
	return _spinning


## Returns the rotating ring Control node.
func ring_node() -> Control:
	return _ring


func _build_children() -> void:
	_dial_node = Control.new()
	_dial_node.name = &"Dial"
	_dial_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dial_node.show_behind_parent = true
	_dial_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dial_node.draw.connect(_on_dial_draw)
	add_child(_dial_node)

	_hand = TextureRect.new()
	_hand.name = &"Hand"
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hand.visible = false
	_dial_node.add_child(_hand)

	_ring = Control.new()
	_ring.name = &"Ring"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.show_behind_parent = true
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.draw.connect(_on_ring_draw)
	add_child(_ring)

	_ring_icon = TextureRect.new()
	_ring_icon.name = &"RingTexture"
	_ring_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_icon.show_behind_parent = true
	_ring_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ring_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ring_icon.visible = false
	_ring.add_child(_ring_icon)

	_busy_icon = TextureRect.new()
	_busy_icon.name = &"BusyIcon"
	_busy_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_busy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_busy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_busy_icon.visible = false
	add_child(_busy_icon)

	# Text fallback for a theme without the hourglass icon (the hourglass is the indicator).
	_busy_label = Label.new()
	_busy_label.name = &"BusyIndicator"
	_busy_label.text = "wait"
	_busy_label.theme_type_variation = &"Label"
	_busy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_busy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_busy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_busy_label.visible = false
	add_child(_busy_label)


func _apply_medallion_size() -> void:
	var dim := float(Tokens.MEDAL_SM if small else Tokens.MEDAL)
	custom_minimum_size = Vector2(dim, dim)
	if _ring != null:
		_ring.pivot_offset = Vector2(dim * 0.5, dim * 0.5)
		_ring.queue_redraw()
	if _dial_node != null:
		_dial_node.queue_redraw()


func _sync_ring_texture() -> void:
	if _ring_icon == null:
		return
	var icon_key := &"medallion_30" if small else &"medallion_64"
	if has_theme_icon(icon_key, &"Kit"):
		_ring_icon.texture = get_theme_icon(icon_key, &"Kit")
		_ring_icon.visible = true
	else:
		_ring_icon.texture = null
		_ring_icon.visible = false
	if _ring != null:
		_ring.queue_redraw()


func _sync_busy_icon_texture() -> void:
	if _busy_icon == null:
		return
	if has_theme_icon(&"hourglass", &"Kit"):
		_busy_icon.texture = get_theme_icon(&"hourglass", &"Kit")
	else:
		_busy_icon.texture = null


func _sync_dial() -> void:
	if _dial_node != null:
		_dial_node.queue_redraw()
	_sync_hand()


func _sync_hand() -> void:
	if _hand == null:
		return
	var lit := dial >= 0 and dial <= 3
	var has_hand := lit and has_theme_icon(&"dial_hand", &"Kit")
	if has_hand:
		_hand.texture = get_theme_icon(&"dial_hand", &"Kit")
	_hand.visible = has_hand
	_hand.pivot_offset = size * 0.5
	_hand.rotation = hand_rotation(dial) if lit else 0.0


func _apply_busy(on: bool, p_reduce_motion: bool) -> void:
	_stop_spin_tween()
	if _ring != null:
		_ring.rotation = 0.0
	if not on:
		_spinning = false
		if _busy_icon != null:
			_busy_icon.visible = false
		if _busy_label != null:
			_busy_label.visible = false
		return

	if p_reduce_motion:
		_spinning = false
		_sync_busy_icon_texture()
		var has_hg := _busy_icon != null and _busy_icon.texture != null
		if _busy_icon != null:
			_busy_icon.visible = has_hg
		if _busy_label != null:
			_busy_label.visible = not has_hg
	else:
		if _busy_icon != null:
			_busy_icon.visible = false
		if _busy_label != null:
			_busy_label.visible = false
		if _ring != null:
			_spin_tween = Motion.spin_ring(_ring, false)
			_spinning = true


func _stop_spin_tween() -> void:
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()
	_spin_tween = null
	_spinning = false


func _on_dial_draw() -> void:
	if _dial_node == null:
		return
	var center := _dial_node.size * 0.5
	var radius := minf(center.x, center.y) - 3.0
	if radius <= 2.0:
		return
	if dial < 0 or dial > 3:
		_dial_node.draw_circle(center, radius, Tokens.SLOT)
		return

	var inner_r := radius - 1.0
	var face := _face_texture()
	if face != null:
		# The baked face (lapis, quarter lines, hub); the lit quarter is tinted over it.
		_dial_node.draw_texture_rect(face, Rect2(Vector2.ZERO, _dial_node.size), false)
		var tint := Tokens.GOLD
		tint.a = 0.6
		_draw_quarter(center, inner_r, dial, tint)
		return

	_dial_node.draw_circle(center, radius, Tokens.LAPIS)
	for q: int in 4:
		_draw_quarter(center, inner_r, q, Tokens.GOLD if q == dial else Tokens.LAPIS)
	_dial_node.draw_line(center + Vector2(-inner_r, 0.0), center + Vector2(inner_r, 0.0), Tokens.BRASS_LO, 1.5, true)
	_dial_node.draw_line(center + Vector2(0.0, -inner_r), center + Vector2(0.0, inner_r), Tokens.BRASS_LO, 1.5, true)


func _face_texture() -> Texture2D:
	if has_theme_icon(&"dial_quarters", &"Kit"):
		return get_theme_icon(&"dial_quarters", &"Kit")
	return null


func _draw_quarter(center: Vector2, inner_r: float, q: int, color: Color) -> void:
	var start_angle := -PI * 0.5 + float(q) * (PI * 0.5)
	var end_angle := start_angle + PI * 0.5
	var pts := PackedVector2Array([center])
	for step: int in range(DIAL_SEGMENTS + 1):
		var t := float(step) / float(DIAL_SEGMENTS)
		var ang := lerpf(start_angle, end_angle, t)
		pts.append(center + Vector2(cos(ang), sin(ang)) * inner_r)
	_dial_node.draw_colored_polygon(pts, color)


func _on_ring_draw() -> void:
	if _ring == null or (_ring_icon != null and _ring_icon.visible):
		return
	var center := _ring.size * 0.5
	var radius := minf(center.x, center.y) - 2.0
	if radius <= 2.0:
		return
	var ring_w := 2.0 if small else 3.5
	_ring.draw_arc(center, radius, 0.0, TAU, 36, Tokens.BRASS, ring_w, true)
	_ring.draw_arc(center, radius + ring_w * 0.5, 0.0, TAU, 36, Tokens.INK, 1.0, true)
	var stud_pos := center + Vector2(0.0, -radius)
	_ring.draw_circle(stud_pos, 1.8 if small else 2.5, Tokens.BRASS_HI)
