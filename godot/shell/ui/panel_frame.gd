## Studiolo side-panel frame with optional Cartouche or Title header, subtitle, close button,
## expanding ScrollContainer body, and sticky footer (docs/architecture/ui-and-controls-spec.md section 3.5;
## ui-style-and-feedback-spec.md section 5).
class_name PanelFrame
extends PanelContainer

signal closed

@export var cartouche_title: String = "":
	set(value):
		cartouche_title = value
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

@onready var _head: HBoxContainer = $VBox/Head
@onready var _title_box: VBoxContainer = $VBox/Head/TitleBox
@onready var _cartouche: Cartouche = $VBox/Head/TitleBox/Cartouche
@onready var _title_label: Label = $VBox/Head/TitleBox/Title
@onready var _subtitle_label: Label = $VBox/Head/TitleBox/Subtitle
@onready var _close_button: KitButton = $VBox/Head/CloseButton
@onready var _body_scroll: ScrollContainer = $VBox/BodyScroll
@onready var _body: VBoxContainer = $VBox/BodyScroll/Body
@onready var _foot: HBoxContainer = $VBox/Foot


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_close_button.pressed.connect(_on_close_pressed)
	_foot.child_order_changed.connect(_sync_footer_visibility)
	_sync_header()
	_sync_footer_visibility()


## Returns the scrollable body VBoxContainer where panel content is added.
func body() -> VBoxContainer:
	return _body


## Returns the sticky footer HBoxContainer.
func footer() -> HBoxContainer:
	return _foot


## Returns the ScrollContainer wrapping `body()`.
func body_scroll() -> ScrollContainer:
	return _body_scroll


## Returns the header Cartouche node.
func cartouche() -> Cartouche:
	return _cartouche


## Returns the header close KitButton.
func close_button() -> KitButton:
	return _close_button


func _sync_header() -> void:
	if not is_node_ready():
		return
	var has_cartouche := not cartouche_title.is_empty()
	var has_plain_title := not has_cartouche and not title.is_empty()
	_cartouche.text = cartouche_title
	_cartouche.visible = has_cartouche

	_title_label.text = title.to_upper() if has_plain_title else ""
	_title_label.visible = has_plain_title

	_subtitle_label.text = subtitle
	_subtitle_label.visible = not subtitle.is_empty()

	_title_box.visible = has_cartouche or has_plain_title or _subtitle_label.visible
	_close_button.visible = show_close
	_head.visible = _title_box.visible or _close_button.visible


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
