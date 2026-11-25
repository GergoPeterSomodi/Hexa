## The job line of the hex panel (spec R10), moved out of the old hex panel in TW2 with its words and Cancel rule unchanged:
## the work under way on the hex (its label, its progress and ready season, "stopped for the winter" while halted) and
## Cancel the work for the player's own work only; another country's work has no button. This script is the WorkBox
## node of the hex panel: Heading, Text, Progress and Actions children. The panel gives it ask (see BuildRows.ask) and
## retired (the panel's freed-later nodes).
##   &"cancel_work" {hex, tag, refund, refund_goods}   the Cancel button; with no listener the job line cancels it itself.
class_name JobLine
extends VBoxContainer

## Asks the App for a works request: ask.call(what: StringName, args: Dictionary) -> bool (true: a listener took it).
var ask: Callable = Callable()
## The panel's retired-node list, shared with the panel.
var retired: Array[Node] = []

@onready var _text_label: Label = $Text
@onready var _progress_label: Label = $Progress
@onready var _actions: VBoxContainer = $Actions


## The box the Cancel button sits in (the panel collects its buttons for the tests and the keyboard path).
func actions_box() -> VBoxContainer:
	return _actions


func clear_actions() -> void:
	PanelKit.clear_children(_actions, retired)


## The Work section (spec 6.8): the work under way on the hex, its progress and ready season ("stopped for the winter"
## while halted), and Cancel the work for the player's own work only; another country's work has no button.
## `viewer` is who the work is shown to (the window passes the player's tag); empty means game.player, as the old panel did.
func refresh(game: Game, hex: Vector2i, viewer: StringName = &"") -> void:
	PanelKit.clear_children(_actions, retired)
	var who: StringName = viewer if viewer != &"" else game.player
	var at := WorksView.at(game, hex, who)
	visible = not at.is_empty()
	if at.is_empty():
		return
	_text_label.text = str(at["label"])
	var when := "stopped for the winter" if bool(at["halted"]) else str(at["progress"])
	_progress_label.text = "%s, ready %s" % [when, str(at["ready"])]
	var tag: StringName = at["tag"]
	var work := game.state.work_at(hex)
	if tag != Session.player_tag() or work == null:
		return
	var verdict := Session.check("cancel_work", {"hex": hex, "tag": tag})
	var args := {"hex": hex, "tag": tag, "refund": Works.refund(game, work), "refund_goods": Works.refund_goods(game, work)}
	var button := BuildRows.new_button("Cancel the work", KitButton.Kind.SECONDARY)
	_actions.add_child(button)
	button.set_verdict(verdict)
	if bool(verdict["ok"]):
		button.pressed.connect(_on_cancel_pressed.bind(args))


func _on_cancel_pressed(args: Dictionary) -> void:
	if bool(ask.call(&"cancel_work", args)):
		return
	Session.act("cancel_work", {"hex": args["hex"], "tag": args["tag"]})
