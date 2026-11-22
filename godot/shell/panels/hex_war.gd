## The war block of the hex panel (docs/architecture/m7-build-spec.md 6.8; M7 B26): the war rows of HexCard ("Held by", "Fortress",
## "Castle area") as a ledger, and the siege of the hex (SiegeView: the meter, the rate and forecast, the stores and the relief) as
## its own block. Read-only: what the viewer may read is the views' fog. The Siege row of HexCard is not repeated here (the block
## says it). Storm now is not in this block: the army panel and the odds card carry it.
class_name HexWar
extends RefCounted

const HEADING := "War"
const SIEGE_HEADING := "Siege"
const SIEGE_ROW := "Siege"
const RELIEF_TEXT := "Relief: %s, %s away."


## Fills `box` with the war block of `hex` for `viewer` and returns whether it has anything to show (the box is shown then).
static func fill(box: VBoxContainer, game: Game, viewer: StringName, hex: Vector2i, retired: Array[Node]) -> bool:
	PanelKit.clear_children(box, retired)
	var rows := _rows(game, hex)
	var siege := SiegeView.at(game, viewer, hex)
	if rows.is_empty() and siege.is_empty():
		return false
	if not rows.is_empty():
		box.add_child(PanelKit.label(HEADING, &"SectionHead"))
		box.add_child(_ledger(rows))
	if not siege.is_empty():
		box.add_child(PanelKit.label(SIEGE_HEADING, &"SectionHead"))
		box.add_child(_siege_block(game, hex, siege))
	return true


## The war rows of the hex card without its Siege row.
static func _rows(game: Game, hex: Vector2i) -> Array:
	var out: Array = []
	for row: Variant in HexCard.war_rows(game, hex):
		if str((row as Array)[0]) != SIEGE_ROW:
			out.append(row)
	return out


## A key and value ledger: the key in Hint, the value in its tone's variation.
static func _ledger(rows: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for row: Variant in rows:
		var cells := row as Array
		grid.add_child(PanelKit.label(str(cells[0]), &"Hint"))
		var value := PanelKit.label(str(cells[2]), HexPanel.tone_variation(StringName(str(cells[1]))))
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)
	return grid


## The siege block: the meter (progress of need), "Pavia (10, 9) is besieged by X: 6 of 10.", and for the besieger and the
## defender (exact) the rate, the forecast and the stores; then the garrison and the relief the defender can send.
static func _siege_block(game: Game, hex: Vector2i, v: Dictionary) -> VBoxContainer:
	var out := VBoxContainer.new()
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var need := maxi(int(v.get("need", 1)), 1)
	var meter := ProgressBar.new()
	meter.show_percentage = false
	meter.max_value = float(need)
	meter.value = float(int(v.get("progress", 0)))
	meter.custom_minimum_size.y = 6.0
	out.add_child(meter)
	out.add_child(_text("%s is besieged by %s: %d of %d." % [Words.place(game, hex), str(v.get("besieger_name", "")),
		int(v.get("progress", 0)), need], &"TableRow"))
	if str(v.get("access", "")) == "exact":
		out.add_child(_text("+%d a season" % int(v.get("rate", 0)), &"Hint"))
		var falls := int(v.get("falls_in", -1))
		out.add_child(_text("Falls in about %s." % _seasons(falls) if falls >= 0 else "Will not fall at this rate.", &"Hint"))
		if bool(v.get("starving", false)):
			out.add_child(_text("The garrison is starving.", &"NumberBad"))
		else:
			out.add_child(_text("The garrison starves after %s." % _seasons(int(v.get("stores_left", 0))), &"Hint"))
	var garrison := str(v.get("garrison_text", ""))
	if garrison != "":
		out.add_child(_text(garrison.substr(0, 1).to_upper() + garrison.substr(1) + ".", &"Hint"))
	for relief: Variant in v.get("relief", []) as Array:
		var r := relief as Dictionary
		out.add_child(_text(RELIEF_TEXT % [str(r.get("men_text", "")), _seasons(int(r.get("seasons", 0)))], &"Hint"))
	return out


static func _text(text: String, variation: StringName) -> Label:
	var lbl := PanelKit.label(text, variation)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


static func _seasons(n: int) -> String:
	return "%d season%s" % [n, "" if n == 1 else "s"]
