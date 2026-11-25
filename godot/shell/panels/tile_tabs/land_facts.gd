## The land facts, the lower part of the Town tab (town_tab.gd; until issue 436 the Land tab, whose ID, LABEL and ORDER it keeps
## for its own tests, but the file is no *_tab.gd so the registry does not list it; tile-window spec R18, R24). Sections: People and
## food; Made here a year (one row per good: loads, and at own land the value); Buildings (foreign and unowned land only);
## Ground and defence (the ground rows, the war rows, the siege meter, and the battle row when the battle was witnessed);
## Armies (the out-of-sight line on foreign land); the buttons Show supply and Show the castle area. Sea shows its rows
## only; the sandbox shows people, food and made goods.
##
## Read-only: it reads the TileView dictionary (`land` and the header facts) and the views it is given, and it changes no
## game object. Its requests go out as app_requested: open_battle (record), map_mode (supply) and castle_area (hex).
## The facts are one ledger (issue 436, the owner's mockup v4): under small-caps heads, a line per fact with its key at the left,
## an optional quiet note, its value at the right and a hairline under it (PanelTileLine).
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
const NUMBER_WIDTH := 60.0
const HEAD := &"TileHead"
## A row's number variation (the views' Number tones) in the window's value size.
const VALUE_VARIATIONS := {&"Number": &"TileValue", &"NumberGood": &"TileValueGood", &"NumberBad": &"TileValueBad",
	&"NumberWarn": &"TileValueMuted", &"Hint": &"TileValueMuted", &"TableRow": &"TileValue"}
const ICON_PEOPLE := &"people"
const ICON_FOOD := &"food"
const ICON_ROOM := &"settlement"


## Shown for every land case and the sea; never for an undiscovered hex (the view has no case there).
static func applies(view: Dictionary) -> bool:
	var case_id := str(view.get("case", ""))
	return case_id != "" and case_id != "unexplored"


## Fills the tab for the hex from its TileView dictionary; the tab is rebuilt on each refresh.
func fill(game: Game, viewer: StringName, hex: Vector2i, view: Dictionary) -> void:
	var case_id := str(view.get("case", ""))
	var land: Dictionary = view.get("land", {})
	add_theme_constant_override(&"separation", 0)
	if case_id == "sea":
		_section(HEAD_SEA)
		var sea := _ledger()
		for pair: Variant in land.get("sea_rows", []) as Array:
			_pair(sea, pair as Array)
		return
	_people(game, hex, case_id, land)
	_made(game, case_id, land)
	_buildings(case_id, land)
	_ground(land)
	_armies(land)
	_buttons(hex, land)
	_restyle(self)


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
			_row("People", "", text, &"Number", null, ICON_PEOPLE)
	if not food.is_empty():
		var made := int(food.get("made", 0))
		var eaten := int(food.get("eaten", 0))
		var net := made - eaten
		_row(FOOD, "makes %s, eats %s" % [Words.number(made), Words.number(eaten)], _signed(net),
			&"NumberGood" if net >= 0 else &"NumberBad", null, ICON_FOOD)


## Own people: the figure with last season's change under it, the room, and the outlook as a line in its tone.
func _own_people(game: Game, hex: Vector2i, people: Dictionary) -> void:
	var change := int(people.get("change", 0))
	var small := ""
	if change != 0:
		small = "%s %s last season" % ["up" if change > 0 else "down", Words.number(absi(change))]
	_row("People", small, Words.number(int(people.get("people", 0))), &"Number", null, ICON_PEOPLE)
	_row(ROOM, "", Words.number(int(people.get("room", 0))), &"Number", null, ICON_ROOM)
	var outlook := PeopleView.outlook(game, hex)
	if not outlook.is_empty():
		add_child(_wrapped(str(outlook.get("text", "")), _tone_variation(StringName(str(outlook.get("tone", ""))))))


## Made here a year: one row per good, its loads; own land adds the value at the good's price (a plus sign, good tone).
func _made(game: Game, case_id: String, land: Dictionary) -> void:
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
		var icon := _good_icon(game, int(entry.get("good", -1)))
		if value == null or case_id != "own":
			_row(title, "", "%d loads" % loads, &"TileValue", null, icon)
		else:
			_row(title, "%d loads" % loads, "+" + Words.number(int(value)), &"NumberGood", null, icon)


## The Kit icon of a good ("good_grain"...), or &"" when the good is unknown.
static func _good_icon(game: Game, good: int) -> StringName:
	if game == null or good < 0 or good >= game.defs.goods.size():
		return &""
	return StringName("good_" + String(game.defs.good(good).key))


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
		var name := str(entry.get("name", ""))
		_row(name.capitalize(), "", str(entry.get("state_text", "")), &"Hint", null,
			StringName(BuildingRow.FAMILY_ICONS.get(name.to_lower(), &"")))


## Ground and defence: the ground rows, the war rows (holder, fortress, garrison, castle area; the Siege row is the Town tab's
## siege block), then the battle row when the battle was witnessed. Fog is the views' (the war rows are already read for the
## viewer).
func _ground(land: Dictionary) -> void:
	_section(HEAD_GROUND)
	var ledger := _ledger()
	for pair: Variant in land.get("ground_rows", []) as Array:
		_pair(ledger, pair as Array)
	for row: Variant in land.get("war_rows", []) as Array:
		var cells := row as Array
		if str(cells[0]) == SIEGE_ROW:
			continue
		_line(ledger, str(cells[0]), str(cells[2]), _tone_variation(StringName(str(cells[1]))))
	# The siege meter is the Town tab's siege block, at its top (the owner's decision, issue 436).
	var battle: Dictionary = land.get("battle", {})
	if not battle.is_empty():
		var button := _button(BATTLE_BUTTON)
		var record := int(battle.get("record", -1))
		button.pressed.connect(func() -> void: app_requested.emit(&"open_battle", {"record": record}))
		_row(str(battle.get("name", "")), BATTLE_SMALL, "", &"Hint", button)


## Armies: on foreign and unowned land out of sight, the line that no armies are shown (a quiet boxed note, as mockup v4's).
## Armies in sight are the Army tab's.
func _armies(land: Dictionary) -> void:
	if not bool(land.get("armies_hidden", false)):
		return
	_section(HEAD_ARMIES)
	var box := PanelContainer.new()
	box.theme_type_variation = &"PanelTileNote"
	box.add_child(_wrapped(OUT_OF_SIGHT, &"TileText"))
	add_child(box)


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


# --- rows and labels ----------------------------------------------------------------------------------------------------


## A key and value pair of the views' rows (ground and sea rows) as one line of the ledger.
func _pair(ledger: VBoxContainer, pair: Array) -> void:
	if pair.size() < 2:
		return
	_line(ledger, str(pair[0]), str(pair[1]), &"TileValue")


## A ledger: its lines are added to the tab itself (mockup v4: the facts as a short list of key and value lines).
func _ledger() -> VBoxContainer:
	return self


## One ledger line: the key at the left, the value at the right, a hairline under it.
func _line(ledger: VBoxContainer, key: String, value: String, variation: StringName) -> void:
	_row(key, "", value, variation, null, &"", ledger)


## One ledger line (mockup v4's Land tab): the key, an optional quiet small text after it, a right-aligned value in its
## variation (the window's value size), and an optional control at the end; a hairline under it. `icon` is kept for the
## callers' sake and not drawn (the ledger has no icons).
func _row(title: String, small: String, number: String, number_variation: StringName, control: Control = null,
		_icon: StringName = &"", into: Container = null) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"PanelTileLine"
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", Tokens.S2)
	card.add_child(line)
	var key := _wrapped(title, &"TileKey")
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(key)
	if small != "":
		var quiet := PanelKit.label(small, &"Hint")
		quiet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(quiet)
	if number != "":
		# A short value keeps one line; a long one (a fortress and its garrison) shares the line with the key and wraps.
		var variation: StringName = VALUE_VARIATIONS.get(number_variation, number_variation)
		var value := _wrapped(number, variation) if number.length() > 24 else PanelKit.label(number, variation)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size.x = NUMBER_WIDTH
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL if number.length() > 24 else Control.SIZE_FILL
		value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(value)
	if control != null:
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(control)
	(into if into != null else self as Container).add_child(card)


func _section(text: String) -> void:
	var head := PanelKit.label(text, HEAD)
	head.uppercase = true
	if get_child_count() > 0:
		head.custom_minimum_size.y = 28.0  # the gap above a group: the head sits at the foot of its taller box
		head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(head)


## The tab's small buttons in the window's flat style (a KitButton sets its kind's variation when it enters the tree).
static func _restyle(node: Node) -> void:
	for child: Node in node.get_children():
		if child is KitButton:
			(child as KitButton).theme_type_variation = &"ButtonTileSmall"
		_restyle(child)


func _button(text: String) -> KitButton:
	var button := KitButton.new()
	button.kind = KitButton.Kind.SMALL
	button.text = text
	return button


static func _wrapped(text: String, variation: StringName) -> Label:
	var label := PanelKit.label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func _signed(n: int) -> String:
	return ("+" if n >= 0 else "-") + Words.number(absi(n))


## The theme variation of a tone: good, bad or warn; any other tone reads as the window's body text (15 px, mockup v4).
static func _tone_variation(tone: StringName) -> StringName:
	match tone:
		&"good":
			return &"NumberGood"
		&"bad":
			return &"NumberBad"
		&"warn":
			return &"NumberWarn"
	return &"TileText"
