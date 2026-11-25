## Helpers shared by the M4 App tests (tests/shell/test_app_flow.gd and test_app_flow_m4.gd): rows of the tile window, toasts,
## the chips' texts and the keys of a SubViewport. Pure statics: the tests own the nodes and the waiting.
class_name AppFlowHelpers
extends RefCounted


## The tile window's button named `prefix`: "Cancel the work" is the job line's, any other prefix names a Buildings row ("Build
## woodland") and gives its hammer. Null when there is none.
static func row_button(app: App, prefix: String) -> Button:
	var window := app.hud().tile_window()
	for button: Button in window.action_buttons():
		if button.text.begins_with(prefix):
			return button
	var row := row_of(app, prefix)
	return row.hammer() if row != null else null


## The Buildings row whose name starts with `prefix` ("" is the first row), or null.
static func row_of(app: App, prefix: String) -> BuildingRow:
	for row: BuildingRow in app.hud().tile_window().building_rows():
		if row.name_text().begins_with(prefix):
			return row
	return null


## The pointer enters the row of `button` (its hammer or the row itself) on `hex`: the row's hover card shows, and the works
## card of its option opens as the old panel's hover did (WorksFlow.show_card, no focus taken).
static func hover_card(app: App, hex: Vector2i, button: Control) -> void:
	var row := _row_above(button)
	if row == null:
		button.mouse_entered.emit()
		return
	row.mouse_entered.emit()
	var option: Dictionary = row.data().get("option", {})
	if not option.is_empty():
		app.requests().works.show_card(hex, {"action": option["action"], "family": option["family"]}, false)


## The pointer leaves the row of `button`.
static func hover_out(button: Control) -> void:
	var row := _row_above(button)
	(row if row != null else button).mouse_exited.emit()


static func _row_above(node: Node) -> BuildingRow:
	var at := node
	while at != null and not (at is BuildingRow):
		at = at.get_parent()
	return at as BuildingRow


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
