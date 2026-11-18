## Studiolo modal frame wrapping a PanelModal PanelContainer and an overhanging Ribbon Control
## so Motion.enter and the overhanging ribbon never fight parent containers
## (docs/architecture/ui-style-and-feedback-spec.md sections 4.11 and 5).
class_name ModalFrame
extends Control

signal closed

@export var ribbon_title: String = "":
	set(value):
		ribbon_title = value
		_sync_header()

@export var title: String = "":
	set(value):
		title = value
		_sync_header()

@export var subtitle: String = "":
	set(value):
		subtitle = value
		_sync_header()

@export var show_close: bool = true:
	set(value):
		show_close = value
		_sync_header()

@onready var _panel: PanelContainer = $Panel
@onready var _head: HBoxContainer = $Panel/VBox/Head
@onready var _title_box: VBoxContainer = $Panel/VBox/Head/TitleBox
@onready var _title_label: Label = $Panel/VBox/Head/TitleBox/Title
@onready var _subtitle_label: Label = $Panel/VBox/Head/TitleBox/Subtitle
@onready var _close_button: KitButton = $Panel/VBox/Head/CloseButton
@onready var _body_scroll: ScrollContainer = $Panel/VBox/BodyScroll
@onready var _body: VBoxContainer = $Panel/VBox/BodyScroll/Body
@onready var _foot: HBoxContainer = $Panel/VBox/Foot
@onready var _ribbon: Ribbon = $Overhang/Ribbon


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.minimum_size_changed.connect(update_minimum_size)
	_close_button.pressed.connect(_on_close_pressed)
	_foot.child_order_changed.connect(_sync_footer_visibility)
	_sync_header()
	_sync_footer_visibility()
	update_minimum_size()


func _get_minimum_size() -> Vector2:
	if _panel != null:
		return _panel.get_combined_minimum_size()
	return Vector2.ZERO


## Returns the scrollable body VBoxContainer where modal content is added.
func body() -> VBoxContainer:
	return _body


## Returns the sticky footer HBoxContainer.
func footer() -> HBoxContainer:
	return _foot


## Returns the ScrollContainer wrapping `body()`.
func body_scroll() -> ScrollContainer:
	return _body_scroll


## Returns the inner PanelModal PanelContainer.
func panel() -> PanelContainer:
	return _panel


## Returns the overhanging Ribbon banner.
func ribbon() -> Ribbon:
	return _ribbon


## Returns the header close KitButton.
func close_button() -> KitButton:
	return _close_button


func _sync_header() -> void:
	if not is_node_ready():
		return
	var has_ribbon := not ribbon_title.is_empty()
	_ribbon.text = ribbon_title
	_ribbon.visible = has_ribbon

	var has_title := not title.is_empty()
	_title_label.text = title.to_upper() if has_title else ""
	_title_label.visible = has_title

	_subtitle_label.text = subtitle
	_subtitle_label.visible = not subtitle.is_empty()

	var has_title_content := has_title or _subtitle_label.visible
	_close_button.visible = show_close
	_head.visible = has_title_content or _close_button.visible
	_title_box.visible = _head.visible


func _sync_footer_visibility() -> void:
	if not is_node_ready():
		return
	var remaining := 0
	for child: Node in _foot.get_children():
		if not child.is_queued_for_deletion():
			remaining += 1
	_foot.visible = remaining > 0


func _on_close_pressed() -> void:
	closed.emit()
