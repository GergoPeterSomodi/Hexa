## The busy pill (docs/architecture/m8-build-spec.md 6.1; M8 K15): a small card at the top centre of the map saying the game is
## busy and how far it is: "Countries are moving 3 / 12" while the AI makes its orders, "The season ends" for the phases, the
## replay's line while the moves play. The Kit's hourglass sits still beside the text (no animation: reduce motion needs no
## case). It takes neither the mouse nor the focus, and shows only what the flow tells it; the App shows and hides it.
class_name BusyPill
extends PanelContainer

const ICON_NAME := &"hourglass"
const SEASON_ENDS_TEXT := "The season ends"

@onready var _icon: TextureRect = $Row/Icon
@onready var _text: Label = $Row/Text


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_sync_icon()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_sync_icon()


## "Countries are moving 3 / 12" (Words.orders_progress); with no seat (total 0: the AI off, the sandbox) only "The season ends".
func show_orders(done: int, total: int) -> void:
	show_text(Words.orders_progress(done, total) if total > 0 else SEASON_ENDS_TEXT)


func show_text(text: String) -> void:
	_text.text = text
	visible = true


func hide_pill() -> void:
	visible = false


func text() -> String:
	return _text.text


func _sync_icon() -> void:
	if has_theme_icon(ICON_NAME, &"Kit"):
		_icon.texture = get_theme_icon(ICON_NAME, &"Kit")
	else:
		_icon.texture = null
