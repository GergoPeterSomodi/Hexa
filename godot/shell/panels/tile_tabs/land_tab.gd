## The Land tab of the tile window (tile-window spec R18, R24; the approved Land mockup). Sections in order: People and
## food; Made here a year (one row per good: loads, and at own land the value); Buildings (foreign and unowned land only);
## Ground and defence (the ground rows, the war rows, the siege meter, and the battle row when the battle was witnessed);
## Armies (the out-of-sight line on foreign land); the buttons Show supply and Show the castle area. Sea shows its rows
## only; the sandbox shows people, food and made goods.
##
## Read-only: it reads the TileView dictionary (`land` and the header facts) and the views it is given, and it changes no
## game object. Its requests go out as app_requested: open_battle (record), map_mode (supply) and castle_area (hex).
## Rows are compact: an icon box, the name with a small line, and a right-aligned number, all in Studiolo theme types.
extends TileTab

const ID := &"land"
const LABEL := "Land"
const ORDER := 10

const HEAD_PEOPLE := "People and food"
const HEAD_MADE := "Made here a year"
const HEAD_BUILDINGS := "Buildings"
const HEAD_GROUND := "Ground and defence"
const HEAD_ARMIES := "Armies"
const HEAD_SEA := "Sea"
const MADE_NONE := "Nothing is made here."
const OUT_OF_SIGHT := "Out of sight: no armies are shown"
const BATTLE_BUTTON := "Open the battle"
const BATTLE_SMALL := "Battle witnessed here"
const SUPPLY_BUTTON := "Show supply"
const CASTLE_BUTTON := "Show the castle area"
const ROOM := "Room"
const FOOD := "Food"
const SIEGE_ROW := "Siege"
const DASH := "-"
const ICON_SIZE := Vector2(26, 26)
const NUMBER_WIDTH := 64.0


## Shown for every land case and the sea; never for an undiscovered hex (the view has no case there).
static func applies(view: Dictionary) -> bool:
	var case_id := str(view.get("case", ""))
	return case_id != "" and case_id != "unexplored"


## Fills the tab for the hex from its TileView dictionary; the tab is rebuilt on each refresh.
func fill(game: Game, viewer: StringName, hex: Vector2i, view: Dictionary) -> void:
	var case_id := str(view.get("case", ""))
	var land: Dictionary = view.get("land", {})
	if case_id == "sea":
		_section(HEAD_SEA)
		for pair: Variant in land.get("sea_rows", []) as Array:
			_pair(pair as Array)
		return
	_people(game, hex, case_id, land)
	_made(case_id, land)
	_buildings(case_id, land)
	_ground(game, viewer, hex, land)
	_armies(land)
	_buttons(hex, land)


# --- sections ------------------------------------------------------------------------------------------------------------


## People and food. Own land: the figure, last season's change, the room and the outlook in its tone. Other land: the figure
## as the view reads it (exact, banded or the number alone). Food is made and eaten a year on own land and the sandbox.
func _people(game: Game, hex: Vector2i, case_id: String, land: Dictionary) -> void:
	var people: Dictionary = land.get("people", {})
	var food: Dictionary = land.get("food", {})
	var shown := bool(people.get("shown", false))
	if not shown and food.is_empty():
		return
	_section(HEAD_PEOPLE)
	if shown:
		var text := str(people.get("text", ""))
		if case_id == "own" and text != "none":
			_own_people(game, hex, people)
		else:
			_row("People", "", text, &"Number")
	if not food.is_empty():
		var made := int(food.get("made", 0))
		var eaten := int(food.get("eaten", 0))
		var net := made - eaten
		_row(FOOD, "makes %s, eats %s" % [Words.number(made), Words.number(eaten)], _signed(net),
			&"NumberGood" if net >= 0 else &"NumberBad")


## Own people: the figure with last season's change under it, the room, and the outlook as a line in its tone.
func _own_people(game: Game, hex: Vector2i, people: Dictionary) -> void:
	var change := int(people.get("change", 0))
	var small := ""
	if change != 0:
		small = "%s %s last season" % ["up" if change > 0 else "down", Words.number(absi(change))]
	_row("People", small, Words.number(int(people.get("people", 0))), &"Number")
	_row(ROOM, "", Words.number(int(people.get("room", 0))), &"Number")
	var outlook := PeopleView.outlook(game, hex)
	if not outlook.is_empty():
		add_child(_wrapped(str(outlook.get("text", "")), _tone_variation(StringName(str(outlook.get("tone", ""))))))


## Made here a year: one row per good, its loads; own land adds the value at the good's price (a plus sign, good tone).
func _made(case_id: String, land: Dictionary) -> void:
	_section(HEAD_MADE)
	var made: Array = land.get("made", [])
	if made.is_empty():
		add_child(_wrapped(MADE_NONE, &"Hint"))
		return
	for row: Variant in made:
		var entry := row as Dictionary
		var loads := int(entry.get("loads", 0))
		var value: Variant = entry.get("value")
		var title := str(entry.get("name", "")).capitalize()
		if value == null or case_id != "own":
			_row(title, "%d loads" % loads, DASH, &"Hint")
		else:
			_row(title, "%d loads" % loads, "+" + Words.number(int(value)), &"NumberGood")


## Buildings on foreign and unowned land: each built piece (working) and the work under way (its progress). Own land and
## the sandbox have the Buildings tab instead, so this section is not shown there.
func _buildings(case_id: String, land: Dictionary) -> void:
	if case_id != "foreign" and case_id != "unowned":
		return
	var rows: Array = land.get("buildings", [])
	if rows.is_empty():
		return
	_section(HEAD_BUILDINGS)
	for row: Variant in rows:
		var entry := row as Dictionary
		_row(str(entry.get("name", "")), str(entry.get("state_text", "")), DASH, &"Hint")


## Ground and defence: the ground rows, the war rows (holder, fortress, garrison, castle area; the Siege row is the meter),
## the siege meter, then the battle row when the battle was witnessed. Fog is the views' (the war rows and the siege are
## already read for the viewer).
func _ground(game: Game, viewer: StringName, hex: Vector2i, land: Dictionary) -> void:
	_section(HEAD_GROUND)
	for pair: Variant in land.get("ground_rows", []) as Array:
		_pair(pair as Array)
	for row: Variant in land.get("war_rows", []) as Array:
		var cells := row as Array
		if str(cells[0]) == SIEGE_ROW:
			continue
		_row(str(cells[0]), "", str(cells[2]), _tone_variation(StringName(str(cells[1]))))
	var siege := SiegeView.at(game, viewer, hex)
	if not siege.is_empty():
		_siege(siege)
	var battle: Dictionary = land.get("battle", {})
	if not battle.is_empty():
		var button := _button(BATTLE_BUTTON)
		var record := int(battle.get("record", -1))
		button.pressed.connect(func() -> void: app_requested.emit(&"open_battle", {"record": record}))
		_row(str(battle.get("name", "")), BATTLE_SMALL, "", &"Hint", button)


## Armies: on foreign and unowned land out of sight, the line that no armies are shown. Armies in sight are the Army tab's.
func _armies(land: Dictionary) -> void:
	if not bool(land.get("armies_hidden", false)):
		return
	_section(HEAD_ARMIES)
	add_child(_wrapped(OUT_OF_SIGHT, &"Hint"))


## The two buttons: Show supply on land with supply, Show the castle area on land a castle holds. Requests only.
func _buttons(hex: Vector2i, land: Dictionary) -> void:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	if bool(land.get("supply", false)):
		var supply := _button(SUPPLY_BUTTON)
		supply.pressed.connect(func() -> void: app_requested.emit(&"map_mode", {"mode": &"supply"}))
		box.add_child(supply)
	if bool(land.get("castle_area", false)):
		var castle := _button(CASTLE_BUTTON)
		castle.pressed.connect(func() -> void: app_requested.emit(&"castle_area", {"hex": hex}))
		box.add_child(castle)
	if box.get_child_count() > 0:
		add_child(box)
	else:
		box.free()


## A siege meter (progress of need) and its sentence; a besieger is named only where the view names one.
func _siege(siege: Dictionary) -> void:
	var need := maxi(int(siege.get("need", 1)), 1)
	var progress := int(siege.get("progress", 0))
	var meter := ProgressBar.new()
	meter.show_percentage = false
	meter.max_value = float(need)
	meter.value = float(progress)
	meter.custom_minimum_size.y = 6.0
	add_child(meter)
	var besieger := str(siege.get("besieger_name", ""))
	var by := " by " + besieger if besieger != "" else ""
	add_child(_wrapped("Besieged%s: %d of %d." % [by, progress, need], &"TableRow"))


# --- rows and labels ----------------------------------------------------------------------------------------------------


## A key and value pair of the views' rows (ground and sea rows): the key is the name, the value the number.
func _pair(pair: Array) -> void:
	if pair.size() < 2:
		return
	_row(str(pair[0]), "", str(pair[1]), &"TableRow")


## One compact row: an icon box (the name's first letter, until the goods art lands), the name with an optional small
## line, a right-aligned number in its variation, and an optional control at the end.
func _row(title: String, small: String, number: String, number_variation: StringName, control: Control = null) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"PanelCard"
	var line := HBoxContainer.new()
	card.add_child(line)
	var box := PanelContainer.new()
	box.theme_type_variation = &"PanelSlot"
	box.custom_minimum_size = ICON_SIZE
	var glyph := PanelKit.label(title.substr(0, 1).to_upper(), &"SectionHead")
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(glyph)
	line.add_child(box)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(_wrapped(title, &"TableRow"))
	if small != "":
		text.add_child(_wrapped(small, &"Hint"))
	line.add_child(text)
	if number != "":
		var value := PanelKit.label(number, number_variation)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size.x = NUMBER_WIDTH
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(value)
	if control != null:
		line.add_child(control)
	add_child(card)


func _section(text: String) -> void:
	add_child(PanelKit.label(text, &"SectionHead"))


func _button(text: String) -> KitButton:
	var button := KitButton.new()
	button.text = text
	return button


static func _wrapped(text: String, variation: StringName) -> Label:
	var label := PanelKit.label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func _signed(n: int) -> String:
	return ("+" if n >= 0 else "-") + Words.number(absi(n))


## The theme variation of a tone: good, bad or warn; any other tone reads as table text.
static func _tone_variation(tone: StringName) -> StringName:
	match tone:
		&"good":
			return &"NumberGood"
		&"bad":
			return &"NumberBad"
		&"warn":
			return &"NumberWarn"
	return &"TableRow"
