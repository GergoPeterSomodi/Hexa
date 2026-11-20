## Helpers shared by the M4 App tests (tests/shell/test_app_flow.gd and test_app_flow_m4.gd): rows of the hex panel, toasts,
## the chips' texts and the keys of a SubViewport. Pure statics: the tests own the nodes and the waiting.
class_name AppFlowHelpers
extends RefCounted


## The hex panel's row button whose text starts with `prefix`, or null.
static func row_button(app: App, prefix: String) -> Button:
	for button: Button in app.hud().hex_panel().action_buttons():
		if button.text.begins_with(prefix):
			return button
	return null


static func toasts(app: App) -> Array[String]:
	return app.hud().toast_host().messages()


static func has_toast(app: App, part: String) -> bool:
	return toasts(app).any(func(m: String) -> bool: return m.contains(part))


## The Ducats chip's value as the bar shows it ("610").
static func ducats_shown(app: App) -> String:
	return app.hud().chips().ducats_chip().value_label().text


## The lines of a hover card ({title, lines}) as "text tone amount" strings.
static func card_lines(card: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for line: Variant in card["lines"]:
		out.append(" ".join(PackedStringArray((line as Array).map(func(part: Variant) -> String: return str(part)))))
	return out


## The text of every Label and Button under `node`.
static func labels_under(node: Node) -> Array[String]:
	var out: Array[String] = []
	for child: Node in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		elif child is Button:
			out.append((child as Button).text)
		out.append_array(labels_under(child))
	return out


## The platform's undo chord (Ctrl or Cmd with Z), pressed and released.
static func undo_key(vp: SubViewport) -> void:
	for pressed: bool in [true, false]:
		var ev := Bindings.events_for(&"game_undo_work")[0].duplicate() as InputEventKey
		ev.pressed = pressed
		vp.push_input(ev)
