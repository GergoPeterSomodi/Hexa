## Non-blocking Studiolo toast host stacking up to 3 swallow-tail banners with tone icons,
## optional KeyCap action hints, configurable TTL, and kind-based eviction
## (docs/architecture/ui-and-controls-spec.md section 3.5; ui-style-and-feedback-spec.md section 5).
class_name ToastHost
extends VBoxContainer

const TOAST_SCENE := preload("res://shell/ui/toast.tscn")
const MAX_TOASTS: int = 3
const DEFAULT_TTL_SEC: float = 3.5

const _TONE_ICONS: Dictionary[StringName, StringName] = {
	&"good": &"tick",
	&"bad": &"cross",
	&"warn": &"lock",
	&"info": &"info",
	&"plain": &"dash",
}

const _TONE_COLOR_TYPES: Dictionary[StringName, StringName] = {
	&"good": &"NumberGood",
	&"bad": &"NumberBad",
	&"warn": &"NumberWarn",
	&"info": &"SectionHead",
	&"plain": &"SectionHead",
}

@export var max_toasts: int = MAX_TOASTS
@export var ttl_sec: float = DEFAULT_TTL_SEC

var _entries: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	set("accessibility_live", 1)  # polite live region when supported by Godot


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		for entry: Dictionary in _entries:
			var node := entry["node"] as PanelContainer
			var tone := entry["tone"] as StringName
			if node != null and is_instance_valid(node):
				_apply_tone(node, tone)


func _process(delta: float) -> void:
	if _entries.is_empty():
		return
	var expired := false
	for entry: Dictionary in _entries:
		entry["elapsed"] = float(entry["elapsed"]) + delta
		if float(entry["elapsed"]) >= ttl_sec:
			expired = true
	if not expired:
		return
	var kept: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		if float(entry["elapsed"]) >= ttl_sec:
			_dispose_entry(entry)
		else:
			kept.append(entry)
	_entries = kept
	_sync_accessibility_name()


## Displays a toast banner with `text`, `tone` (`plain`, `good`, `bad`, `warn`, `info`),
## optional `key_action` KeyCap badge, and `kind` tag for `drop(kinds)`.
func toast(
	text: String,
	tone: StringName = &"plain",
	key_action: StringName = &"",
	kind: StringName = &""
) -> void:
	if text.is_empty():
		return
	var cap := maxi(1, max_toasts)
	while _entries.size() >= cap:
		var oldest := _entries[0]
		_entries.remove_at(0)
		_dispose_entry(oldest)

	var node := TOAST_SCENE.instantiate() as PanelContainer
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_lbl := node.get_node("HBox/Text") as Label
	text_lbl.text = text
	var key_cap := node.get_node("HBox/KeyCap") as KeyCap
	if key_action != &"":
		key_cap.action = key_action
		key_cap.visible = true
	else:
		key_cap.visible = false
	node.accessibility_name = text

	add_child(node)
	_apply_tone(node, tone)
	_entries.append({
		"node": node,
		"text": text,
		"tone": tone,
		"kind": kind,
		"elapsed": 0.0,
	})
	_sync_accessibility_name()


## Removes all active toasts whose `kind` matches any element in `kinds`.
func drop(kinds: Array) -> void:
	if kinds.is_empty() or _entries.is_empty():
		return
	var drop_set: Dictionary[StringName, bool] = {}
	for k: Variant in kinds:
		drop_set[StringName(str(k))] = true
	var kept: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		if drop_set.has(entry["kind"] as StringName):
			_dispose_entry(entry)
		else:
			kept.append(entry)
	_entries = kept
	_sync_accessibility_name()


## Returns the number of currently visible toasts.
func active_count() -> int:
	return _entries.size()


## Returns the visible toast messages in order from oldest to newest.
func messages() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in _entries:
		out.append(str(entry["text"]))
	return out


## Immediately removes and frees all active toasts.
func clear() -> void:
	for entry: Dictionary in _entries:
		_dispose_entry(entry)
	_entries.clear()
	_sync_accessibility_name()


func _apply_tone(node: PanelContainer, tone: StringName) -> void:
	var icon_rect := node.get_node("HBox/ToneIcon") as TextureRect
	var icon_key: StringName = _TONE_ICONS.get(tone, &"dash")
	if node.has_theme_icon(icon_key, &"Kit"):
		icon_rect.texture = node.get_theme_icon(icon_key, &"Kit")
	else:
		icon_rect.texture = null
	var color_type: StringName = _TONE_COLOR_TYPES.get(tone, &"SectionHead")
	if node.has_theme_color(&"font_color", color_type):
		icon_rect.self_modulate = node.get_theme_color(&"font_color", color_type)
	else:
		icon_rect.self_modulate = Color.WHITE


func _dispose_entry(entry: Dictionary) -> void:
	var node := entry.get("node", null) as Node
	if node != null and is_instance_valid(node):
		if node.get_parent() == self:
			remove_child(node)
		node.queue_free()


func _sync_accessibility_name() -> void:
	if _entries.is_empty():
		accessibility_name = ""
	else:
		accessibility_name = str(_entries[_entries.size() - 1]["text"])
