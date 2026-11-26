## The land facts, the lower part of the Town tab (town_tab.gd; until issue 436 the Land tab, whose ID, LABEL and ORDER it keeps
## for its own tests, but the file is no *_tab.gd so the registry does not list it; tile-window spec R18, R24). Sections: People and
## food; Made here a year (one row per good: loads, and at own land the value); Buildings (foreign and unowned land only);
## Ground and defence (the ground rows, the war rows, and the battle row when the battle was witnessed); Armies (the
## out-of-sight line on foreign land). Sea shows its rows only; the sandbox shows people, food and made goods. Show supply and
## Show the castle area are icon buttons on the window's picture since issue 436 round 3 (L3).
##
## Read-only: it reads the TileView dictionary (`land` and the header facts) and the views it is given, and it changes no
## game object. Its requests go out as app_requested: open_battle (record).
## The facts are one ledger (issue 436, the owner's mockup v4): under small-caps heads, a line per fact with its key at the left,
## an optional quiet note, its value at the right and a hairline under it (PanelTileLine). Round 3 (M8): each section folds under
## its head (a click on the head; the open state is kept in memory for the session, `folded`); a note that belongs to a row
## (the outlook under Room) sits in that row's box, at the label column, muted, before its hairline (M1).
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
const ROOM := "Room"
const FOOD := "Food"
const SIEGE_ROW := "Siege"
const FORTRESS_ROW := "Fortress"
const DASH := "-"
const NUMBER_WIDTH := 60.0
const HEAD := &"TileHead"
## The fort level's words (L3: the Fortress row names the walls, not a settlement word that clashes with the town's).
const FORT_WORDS: Array[String] = ["", "Palisade", "Town walls", "Castle walls", "Fortress walls", "Great walls"]
## A row's number variation (the views' Number tones) in the window's value size.
const VALUE_VARIATIONS := {&"Number": &"TileValue", &"NumberGood": &"TileValueGood", &"NumberBad": &"TileValueBad",
	&"NumberWarn": &"TileValueMuted", &"Hint": &"TileValueMuted", &"TableRow": &"TileValue"}
const ICON_PEOPLE := &"people"
const ICON_FOOD := &"food"
const ICON_ROOM := &"settlement"
const FOLD_TIP := "Click to fold this section away."
const UNFOLD_TIP := "Click to show this section."

## The sections folded away, by head (M8): kept for the session, so another tile opens with the same sections folded.
static var folded: Dictionary = {}

## The section the next rows go into (the body under the last head), or null before the first head.
var _into: VBoxContainer = null


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
		for pair: Variant in land.get("sea_rows", []) as Array:
			_pair(pair as Array)
		return
	_people(game, hex, case_id, land)
	_made(game, case_id, land)
	_buildings(case_id, land)
	_ground(game, land)
	_armies(land)
	_restyle(self)


## The fold heads of the sections shown (tests and tools), by head text.
func fold_heads() -> Dictionary:
	var out := {}
	for child: Node in get_children():
		if child.has_meta("head"):
			out[str(child.get_meta("head"))] = child
	return out


## Folds or opens a section by its head (the head's click does the same) and remembers it.
func set_folded(head: String, fold: bool) -> void:
	folded[head] = fold
	var button := fold_heads().get(head) as Button
	if button == null:
		return
	var body := button.get_meta("body") as Control
	body.visible = not fold
	button.tooltip_text = UNFOLD_TIP if fold else FOLD_TIP
	var glyph := button.get_node("Line/Arrow") as TileGlyph
	glyph.kind = TileGlyph.SHUT if fold else TileGlyph.OPEN
	glyph.queue_redraw()


# --- sections ------------------------------------------------------------------------------------------------------------


## People and food. Own land: the figure, last season's change, the room with the outlook under it. Other land: the figure
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


## Own people: the figure with last season's change, the room, and the outlook as a note of the Room row in its tone.
func _own_people(game: Game, hex: Vector2i, people: Dictionary) -> void:
	var change := int(people.get("change", 0))
	var small := ""
	if change != 0:
		small = "%s %s last season" % ["up" if change > 0 else "down", Words.number(absi(change))]
	_row("People", small, Words.number(int(people.get("people", 0))), &"Number")
	var outlook := PeopleView.outlook(game, hex)
	var note: Label = null
	if not outlook.is_empty():
		note = _wrapped(str(outlook.get("text", "")), _tone_variation(StringName(str(outlook.get("tone", "")))))
	_row(ROOM, "", Words.number(int(people.get("room", 0))), &"Number", null, note)


## Made here a year: one row per good, its loads; own land adds the value at the good's price (a plus sign, good tone).
func _made(_game: Game, case_id: String, land: Dictionary) -> void:
	_section(HEAD_MADE)
	var made: Array = land.get("made", [])
	if made.is_empty():
		var none := PanelContainer.new()
		none.theme_type_variation = &"PanelTileLine"
		none.add_child(_wrapped(MADE_NONE, &"TileHint"))
		_into.add_child(none)
		return
	for row: Variant in made:
		var entry := row as Dictionary
		var loads := Words.number(int(entry.get("loads", 0)))
		var value: Variant = entry.get("value")
		var title := str(entry.get("name", "")).capitalize()
		if value == null or case_id != "own":
			_row(title, "", "%s loads" % loads, &"TileValue")
		else:
			_row(title, "%s loads" % loads, "+" + Words.number(int(value)), &"NumberGood")


## Buildings on foreign and unowned land: each built piece (working) and the work under way (its progress). Own land and
## the sandbox have the strips instead, so this section is not shown there.
func _buildings(case_id: String, land: Dictionary) -> void:
	if case_id != "foreign" and case_id != "unowned":
		return
	var rows: Array = land.get("buildings", [])
	if rows.is_empty():
		return
	_section(HEAD_BUILDINGS)
	for row: Variant in rows:
		var entry := row as Dictionary
		_row(str(entry.get("name", "")).capitalize(), "", str(entry.get("state_text", "")), &"Hint")


## Ground and defence: the ground rows, the war rows (holder, fortress in its walls' words, castle area; the Siege row is the
## Town tab's siege block), then the battle row when the battle was witnessed. Fog is the views' (the war rows are already read
## for the viewer).
func _ground(game: Game, land: Dictionary) -> void:
	_section(HEAD_GROUND)
	for pair: Variant in land.get("ground_rows", []) as Array:
		_pair(pair as Array)
	for row: Variant in land.get("war_rows", []) as Array:
		var cells := row as Array
		if str(cells[0]) == SIEGE_ROW:
			continue
		var value := str(cells[2])
		if str(cells[0]) == FORTRESS_ROW:
			var per := game.defs.war.garrison_per_level if game != null and game.defs != null and game.defs.war != null else 0
			value = fortress_words(value, per)
		_row(str(cells[0]), "", value, _value_tone(StringName(str(cells[1]))))
	var battle: Dictionary = land.get("battle", {})
	if not battle.is_empty():
		var button := _button(BATTLE_BUTTON)
		var record := int(battle.get("record", -1))
		button.pressed.connect(func() -> void: app_requested.emit(&"open_battle", {"record": record}))
		_row(str(battle.get("name", "")), BATTLE_SMALL, "", &"Hint", button)


## The Fortress row's words (L3, L2): "Walled town · garrison 800 of 800" becomes "Town walls, garrison 800 of 800": the walls by
## the fort level (the full garrison over the men a level holds, `per`), numbers with thousands separators. A text it cannot read is
## kept as it is.
static func fortress_words(text: String, per: int) -> String:
	var found := RegEx.create_from_string("garrison (\\d+) of (\\d+)").search(text)
	if found == null:
		return text
	var men := int(found.get_string(1))
	var full := int(found.get_string(2))
	var level := clampi(roundi(float(full) / float(per)), 1, FORT_WORDS.size() - 1) if full > 0 and per > 0 else 1
	return "%s, garrison %s of %s" % [FORT_WORDS[level], Words.number(men), Words.number(full)]


## Armies: on foreign and unowned land out of sight, the line that no armies are shown (a quiet boxed note, as mockup v4's).
## Armies in sight are the Army tab's.
func _armies(land: Dictionary) -> void:
	if not bool(land.get("armies_hidden", false)):
		return
	_section(HEAD_ARMIES)
	var box := PanelContainer.new()
	box.theme_type_variation = &"PanelTileNote"
	box.add_child(_wrapped(OUT_OF_SIGHT, &"TileText"))
	_into.add_child(box)


# --- rows and labels ----------------------------------------------------------------------------------------------------


## A key and value pair of the views' rows (ground and sea rows) as one line of the ledger.
func _pair(pair: Array) -> void:
	if pair.size() < 2:
		return
	_row(str(pair[0]), "", str(pair[1]), &"TileValue")


## One ledger line (mockup v4's Land tab): the key, an optional quiet small text after it, a right-aligned value in its
## variation (the window's value size), an optional control at the end, and an optional note under them at the label column
## (M1); a hairline under the whole.
func _row(title: String, small: String, number: String, number_variation: StringName, control: Control = null,
		note: Label = null) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"PanelTileLine"
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", Tokens.S2)
	card.add_child(column)
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", Tokens.S2)
	column.add_child(line)
	var key := _wrapped(title, &"TileKey")
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(key)
	if small != "":
		var quiet := PanelKit.label(small, &"TileHint")
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
	if note != null:
		column.add_child(note)
	(_into if _into != null else self as Container).add_child(card)


## A section: its head (a flat button with the small-caps words and a fold arrow; M8) and the body its rows go into. A head
## after another section has room above it.
func _section(text: String) -> void:
	var head := Button.new()
	head.theme_type_variation = &"ButtonTileFold"
	head.set_meta("head", text)
	head.focus_mode = Control.FOCUS_ALL
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.accessibility_name = text
	head.custom_minimum_size.y = 34.0 if get_child_count() > 0 else 24.0
	var line := HBoxContainer.new()
	line.name = &"Line"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", Tokens.S1)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.alignment = BoxContainer.ALIGNMENT_BEGIN
	var arrow := TileGlyph.make(TileGlyph.OPEN, 12.0)
	arrow.name = &"Arrow"
	arrow.size_flags_vertical = Control.SIZE_SHRINK_END
	var label := PanelKit.label(text, HEAD)
	label.uppercase = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	line.add_child(label)
	line.add_child(arrow)
	head.add_child(line)
	add_child(head)
	_into = VBoxContainer.new()
	_into.add_theme_constant_override(&"separation", 0)
	add_child(_into)
	head.set_meta("body", _into)
	head.pressed.connect(func() -> void: set_folded(text, not bool(folded.get(text, false))))
	set_folded(text, bool(folded.get(text, false)))


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


## A ledger value's variation by its tone (the war rows): good and bad in their colours, warn muted, plain the value's type.
static func _value_tone(tone: StringName) -> StringName:
	match tone:
		&"good":
			return &"NumberGood"
		&"bad":
			return &"NumberBad"
		&"warn":
			return &"NumberWarn"
	return &"TileValue"


## The theme variation of a note's tone: good, bad or warn in their colours (the window's 15 px secondary size); any other tone reads as
## the window's muted secondary text (M1: a note is quiet unless its tone says otherwise).
static func _tone_variation(tone: StringName) -> StringName:
	match tone:
		&"good":
			return &"TileHintGood"
		&"bad":
			return &"TileHintBad"
		&"warn":
			return &"TileHintWarn"
	return &"TileHint"
