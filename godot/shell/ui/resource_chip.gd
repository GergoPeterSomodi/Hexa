## Studiolo top-bar resource chip (docs/architecture/m4-build-spec.md 6.3; ui-style-and-feedback-spec.md sections 5 and
## 4.11): a flat Button whose PanelSlot plate holds a 30 px Medallion with the resource's icon, the name (optional), the
## value through Words, and a DeltaChip. The hover card is built from a dictionary (HoverCard, no Game access).
class_name ResourceChip
extends Button

const HOVER_CARD_SCENE := preload("res://shell/ui/hover_card.tscn")
## The tooltip key that asks for the hover card (any non-empty text would do; the card is not text).
const CARD_KEY := "card"

## The medal's Kit icon (set by set_resource; settable on its own).
@export var icon_name: StringName = &"":
	set(value):
		icon_name = value
		if _refs_bound:
			_medal.icon_name = icon_name

@export var invert: bool = false:
	set(value):
		invert = value
		if _refs_bound:
			_delta.invert = invert

var resource_id: StringName = &""

var _resource_label: String = ""
var _value_text: String = ""
var _name_shown: bool = true
var _change_shown: bool = true
var _card: Dictionary = {}

var _plate: PanelContainer = null
var _medal: Medallion = null
var _name_label: Label = null
var _value_label: Label = null
var _delta: DeltaChip = null
var _refs_bound: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	_ensure_refs()
	_sync_name()
	_sync_change()
	_sync_min_size()
	_sync_accessibility()


## Names the chip: its id (for the bar's refresh), its icon from the Kit, and its label ("Ducats").
func set_resource(id: StringName, icon: StringName, label: String) -> void:
	_ensure_refs()
	resource_id = id
	icon_name = icon
	_resource_label = label
	_sync_name()
	_sync_accessibility()


## Shows the amount (through Words) and the change since the last closed season (a DeltaChip). `unit` names the change
## on the chip ("ducats" gives "+86 ducats"); `label` also renames the chip when not empty.
func set_value(value: int, change: int, unit: String = "", label: String = "") -> void:
	_ensure_refs()
	if not label.is_empty():
		_resource_label = label
		_sync_name()
	_value_text = Words.number(value)
	_value_label.text = _value_text
	_delta.set_delta(change, unit)
	_sync_accessibility()


## Sets the hover card from a dictionary (`{title, subtitle, lines}` as HoverCard.show_card takes it). An empty
## dictionary removes the card.
func set_card(card: Dictionary) -> void:
	_card = card.duplicate(true)


## Shows or hides the name (the top bar narrows by the name first). The medal and the value always show.
func set_name_shown(on: bool) -> void:
	_ensure_refs()
	_name_shown = on
	_sync_name()


## Shows or hides the change (the top bar narrows by the change after the name).
func set_change_shown(on: bool) -> void:
	_ensure_refs()
	_change_shown = on
	_sync_change()


## Returns the child Medal (a Medallion, not clickable: the chip takes the click).
func medallion() -> Medallion:
	_ensure_refs()
	return _medal


## Returns the child Name label.
func name_label() -> Label:
	_ensure_refs()
	return _name_label


## Returns the child Value label.
func value_label() -> Label:
	_ensure_refs()
	return _value_label


## Returns the child Change DeltaChip.
func delta_chip() -> DeltaChip:
	_ensure_refs()
	return _delta


## Returns the chip's hover card key when a card is set (Godot asks for it on hover).
func _get_tooltip(_at_position: Vector2) -> String:
	return CARD_KEY if not _card.is_empty() else ""


## Builds the HoverCard for the card dictionary; null when there is no card.
func _make_custom_tooltip(for_text: String) -> Object:
	if for_text != CARD_KEY or _card.is_empty():
		return null
	var card := HOVER_CARD_SCENE.instantiate() as HoverCard
	card.show_card(_card)
	return card


func _ensure_refs() -> void:
	if _refs_bound:
		return
	_plate = get_node("Plate") as PanelContainer
	_medal = get_node("Plate/HBox/Medal") as Medallion
	_name_label = get_node("Plate/HBox/Name") as Label
	_value_label = get_node("Plate/HBox/Value") as Label
	_delta = get_node("Plate/HBox/Change") as DeltaChip
	_medal.focus_mode = Control.FOCUS_NONE
	_medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delta.invert = invert
	_medal.icon_name = icon_name
	_plate.minimum_size_changed.connect(_sync_min_size)
	_refs_bound = true


func _sync_name() -> void:
	if not _refs_bound:
		return
	_name_label.text = _resource_label
	_name_label.visible = _name_shown and not _resource_label.is_empty()


func _sync_change() -> void:
	if not _refs_bound:
		return
	_delta.visible = _change_shown


## The Button takes the plate's size, so the top bar lays the chip out at its real size.
func _sync_min_size() -> void:
	if not _refs_bound:
		return
	custom_minimum_size = _plate.get_combined_minimum_size()


## "Ducats: 658, up 48"; the name is left out when empty.
func _sync_accessibility() -> void:
	if not _refs_bound:
		return
	var head := _value_text
	if not _resource_label.is_empty():
		head = "%s: %s" % [_resource_label, _value_text]
	var change := _delta.accessibility_name
	accessibility_name = head if change.is_empty() else "%s, %s" % [head, change]
