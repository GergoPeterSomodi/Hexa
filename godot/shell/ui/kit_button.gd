## Studiolo themed Button with semantic Kinds, Theme Kit icons, dynamic hotkey tooltip,
## cost suffix, action verdict refusal (lock + reason), and lazy hover/focus Glow
## (docs/architecture/ui-and-controls-spec.md section 3.5; ui-style-and-feedback-spec.md sections 4.3, 4.11, 5).
class_name KitButton
extends Button

enum Kind {
	SECONDARY,
	SMALL,
	PRIMARY,
	PRIMARY_LARGE,
	DANGER,
	TOGGLE,
	ICON,
	MENU,
	MENU_PRIMARY,
	MENU_DANGER,
	MEDALLION,
}

const GLOW_PATCH_MARGIN: int = 24

const _KIND_VARIATIONS: Dictionary[int, StringName] = {
	Kind.SECONDARY: &"",
	Kind.SMALL: &"ButtonSmall",
	Kind.PRIMARY: &"ButtonPrimary",
	Kind.PRIMARY_LARGE: &"ButtonPrimaryLarge",
	Kind.DANGER: &"ButtonDanger",
	Kind.TOGGLE: &"ButtonToggle",
	Kind.ICON: &"ButtonIcon",
	Kind.MENU: &"ButtonMenu",
	Kind.MENU_PRIMARY: &"ButtonMenuPrimary",
	Kind.MENU_DANGER: &"ButtonMenuDanger",
	Kind.MEDALLION: &"ButtonMedallion",
}

const _KIND_MIN_HEIGHTS: Dictionary[int, int] = {
	Kind.SECONDARY: Tokens.BUTTON_H,
	Kind.SMALL: Tokens.BUTTON_SM_H,
	Kind.PRIMARY: Tokens.BUTTON_H,
	Kind.PRIMARY_LARGE: Tokens.BUTTON_LG_H,
	Kind.DANGER: Tokens.BUTTON_H,
	Kind.TOGGLE: Tokens.BUTTON_H,
	Kind.ICON: Tokens.BUTTON_H,
	Kind.MENU: Tokens.BUTTON_MENU_H,
	Kind.MENU_PRIMARY: Tokens.BUTTON_MENU_H,
	Kind.MENU_DANGER: Tokens.BUTTON_MENU_H,
	Kind.MEDALLION: Tokens.MEDAL_SM,
}

@export var kind: Kind = Kind.SECONDARY:
	set(value):
		kind = value
		_apply_kind()

@export var icon_name: StringName = &"":
	set(value):
		icon_name = value
		_refresh_icon()

@export var cost_text: String = "":
	set(value):
		cost_text = value
		_refresh_cost_label()

@export var hotkey_action: StringName = &"":
	set(value):
		hotkey_action = value
		_refresh_tooltip()

@export var reduce_motion: bool = false

var _glow: NinePatchRect = null
var _glow_tween: Tween = null
var _cost_label: Label = null
var _hovered: bool = false
var _verdict_ok: bool = true
var _verdict_reason: String = ""
var _base_tooltip: String = ""
var _saved_custom_icon: Texture2D = null
var _showing_lock_icon: bool = false
var _auto_min_height: float = 0.0
var _auto_accessibility_desc: String = ""
var _internal_text_set: bool = false
var _internal_tooltip_set: bool = false


func _init() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	_apply_kind()


func _ready() -> void:
	_apply_kind()
	_refresh_icon()
	_refresh_cost_label()
	_refresh_tooltip()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_icon()
		if _glow != null and has_theme_icon(&"glow_soft", &"Kit"):
			_glow.texture = get_theme_icon(&"glow_soft", &"Kit")
	elif what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_FOCUS_ENTER:
		_refresh_tooltip()


func _set(property: StringName, value: Variant) -> bool:
	if property == &"text" and not _internal_text_set:
		var next_text := str(value)
		if _is_menu_kind():
			next_text = next_text.to_upper()
		_internal_text_set = true
		text = next_text
		_internal_text_set = false
		_sync_accessibility_desc()
		return true
	if property == &"tooltip_text" and not _internal_tooltip_set:
		_base_tooltip = str(value)
		_refresh_tooltip()
		return true
	return false


## Applies a rule-check verdict `{ok: bool, reason: String}` (missing `ok` defaults to `true`).
## Refused buttons disable interaction, show the Theme `lock` icon, and expose `reason` in tooltip and `reason_text()`.
func set_verdict(verdict: Dictionary) -> void:
	var ok := bool(verdict.get("ok", true))
	var reason := str(verdict.get("reason", ""))
	if not ok:
		if icon_name == &"" and not _showing_lock_icon and icon != null:
			_saved_custom_icon = icon
		_verdict_ok = false
		_verdict_reason = reason
		disabled = true
		_hovered = false
		_update_glow()
	else:
		_verdict_ok = true
		_verdict_reason = ""
		disabled = false
	_refresh_icon()
	_refresh_tooltip()
	_sync_accessibility_desc()


## Returns the active refusal reason from `set_verdict()`, or empty string when allowed.
func reason_text() -> String:
	return _verdict_reason


## Rebuilds the hotkey-annotated tooltip from the current `Bindings` InputMap.
func refresh_hotkey() -> void:
	_refresh_tooltip()


func _is_menu_kind() -> bool:
	return kind == Kind.MENU or kind == Kind.MENU_PRIMARY or kind == Kind.MENU_DANGER


func _supports_glow() -> bool:
	return (
		kind == Kind.PRIMARY
		or kind == Kind.PRIMARY_LARGE
		or kind == Kind.MENU
		or kind == Kind.MENU_PRIMARY
		or kind == Kind.MENU_DANGER
		or kind == Kind.MEDALLION
	)


func _apply_kind() -> void:
	theme_type_variation = _KIND_VARIATIONS.get(kind, &"")
	if kind == Kind.TOGGLE:
		toggle_mode = true
	var min_h := float(maxi(_KIND_MIN_HEIGHTS.get(kind, Tokens.BUTTON_H), Tokens.TARGET_MIN))
	if is_equal_approx(custom_minimum_size.y, _auto_min_height) or custom_minimum_size.y < min_h:
		custom_minimum_size.y = min_h
	_auto_min_height = min_h
	if _is_menu_kind() and text != text.to_upper():
		_internal_text_set = true
		text = text.to_upper()
		_internal_text_set = false
	if _glow != null or (_supports_glow() and (_hovered or has_focus())):
		_update_glow()


func _refresh_icon() -> void:
	if not _verdict_ok:
		if has_theme_icon(&"lock", &"Kit"):
			icon = get_theme_icon(&"lock", &"Kit")
			_showing_lock_icon = true
		return
	_showing_lock_icon = false
	if icon_name != &"":
		icon = get_theme_icon(icon_name, &"Kit") if has_theme_icon(icon_name, &"Kit") else null
		_saved_custom_icon = null
	elif _saved_custom_icon != null:
		icon = _saved_custom_icon
		_saved_custom_icon = null
	else:
		icon = null


func _refresh_cost_label() -> void:
	if cost_text.is_empty():
		if _cost_label != null:
			_cost_label.text = ""
			_cost_label.visible = false
		_sync_accessibility_desc()
		return
	if _cost_label == null:
		_cost_label = Label.new()
		_cost_label.name = &"CostLabel"
		_cost_label.theme_type_variation = &"Hint"
		_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cost_label.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		_cost_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_cost_label.offset_right = -float(Tokens.S3)
		_cost_label.offset_left = -float(Tokens.S3)
		add_child(_cost_label)
	_cost_label.text = cost_text
	_cost_label.visible = true
	_sync_accessibility_desc()


func _refresh_tooltip() -> void:
	var final_tip := _base_tooltip
	if not _verdict_ok and not _verdict_reason.is_empty():
		final_tip = _verdict_reason
	elif hotkey_action != &"":
		var caps := Bindings.key_caps_for(hotkey_action)
		if not caps.is_empty():
			var hotkey_tag := "[%s]" % ", ".join(caps)
			final_tip = hotkey_tag if final_tip.is_empty() else "%s %s" % [final_tip, hotkey_tag]
	_internal_tooltip_set = true
	tooltip_text = final_tip
	_internal_tooltip_set = false


func _sync_accessibility_desc() -> void:
	var desired := ""
	if not _verdict_ok and not _verdict_reason.is_empty():
		desired = _verdict_reason
	elif not cost_text.is_empty():
		desired = cost_text
	if accessibility_description.is_empty() or accessibility_description == _auto_accessibility_desc:
		_auto_accessibility_desc = desired
		accessibility_description = desired


func _ensure_glow() -> NinePatchRect:
	if _glow == null:
		_glow = NinePatchRect.new()
		_glow.name = &"Glow"
		if has_theme_icon(&"glow_soft", &"Kit"):
			_glow.texture = get_theme_icon(&"glow_soft", &"Kit")
		_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_glow.patch_margin_left = GLOW_PATCH_MARGIN
		_glow.patch_margin_top = GLOW_PATCH_MARGIN
		_glow.patch_margin_right = GLOW_PATCH_MARGIN
		_glow.patch_margin_bottom = GLOW_PATCH_MARGIN
		_glow.modulate.a = 0.0
		add_child(_glow)
	return _glow


func _update_glow() -> void:
	var hot := (not disabled) and _supports_glow() and (_hovered or has_focus())
	if hot:
		_ensure_glow()
	if _glow == null:
		return
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = Motion.hover_glow(_glow, hot, reduce_motion)


func _on_mouse_entered() -> void:
	_hovered = true
	_update_glow()


func _on_mouse_exited() -> void:
	_hovered = false
	_update_glow()


func _on_focus_entered() -> void:
	_update_glow()


func _on_focus_exited() -> void:
	_update_glow()
