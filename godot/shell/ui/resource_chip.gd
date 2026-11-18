## Studiolo top-bar resource chip: PanelSlot holding a 30 px Medallion, optional resource name,
## tabular value, and inline DeltaChip (docs/architecture/ui-style-and-feedback-spec.md section 5).
class_name ResourceChip
extends PanelContainer

signal pressed

@export var icon_name: StringName = &"":
	set(value):
		icon_name = value
		if _refs_bound:
			_medallion.icon_name = icon_name

@export var resource_name: String = "":
	set(value):
		resource_name = value
		_sync_name()

@export var invert: bool = false:
	set(value):
		invert = value
		if _refs_bound:
			_delta.invert = invert

@export var hud_mode: bool = false:
	set(value):
		hud_mode = value
		_sync_focus_mode()

var _medallion: Medallion = null
var _name_label: Label = null
var _value_label: Label = null
var _delta: DeltaChip = null
var _refs_bound: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_refs()
	_medallion.icon_name = icon_name
	_delta.invert = invert
	_sync_name()
	_sync_focus_mode()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


## Updates the displayed resource amount, change delta, optional unit, and optional resource name.
func set_value(amount: int, change: int, unit: String = "", p_resource_name: String = "") -> void:
	_ensure_refs()
	if not p_resource_name.is_empty():
		resource_name = p_resource_name
	_value_label.text = str(amount)
	_delta.set_delta(change, unit)
	_sync_accessibility(amount)


## Returns the child Medallion button.
func medallion() -> Medallion:
	_ensure_refs()
	return _medallion


## Returns the child NameLabel.
func name_label() -> Label:
	_ensure_refs()
	return _name_label


## Returns the child ValueLabel.
func value_label() -> Label:
	_ensure_refs()
	return _value_label


## Returns the child DeltaChip.
func delta_chip() -> DeltaChip:
	_ensure_refs()
	return _delta


func _ensure_refs() -> void:
	if _refs_bound:
		return
	_medallion = get_node("HBox/Medallion") as Medallion
	_name_label = get_node("HBox/NameLabel") as Label
	_value_label = get_node("HBox/ValueLabel") as Label
	_delta = get_node("HBox/DeltaChip") as DeltaChip
	_medallion.pressed.connect(_on_medallion_pressed)
	_refs_bound = true


func _sync_name() -> void:
	if not _refs_bound:
		return
	_name_label.text = resource_name
	_name_label.visible = not resource_name.is_empty()
	_medallion.accessibility_name = resource_name
	if not resource_name.is_empty() and accessibility_name.is_empty():
		accessibility_name = resource_name


func _sync_focus_mode() -> void:
	if not _refs_bound:
		return
	_medallion.focus_mode = Control.FOCUS_NONE if hud_mode else Control.FOCUS_ALL


func _sync_accessibility(amount: int) -> void:
	var parts: PackedStringArray = []
	if not resource_name.is_empty():
		parts.append(resource_name)
	parts.append(str(amount))
	if not _delta.accessibility_name.is_empty():
		parts.append(_delta.accessibility_name)
	accessibility_name = ", ".join(parts)


func _on_medallion_pressed() -> void:
	pressed.emit()
