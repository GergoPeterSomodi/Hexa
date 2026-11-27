## The Navy tab of the tile window (tile-window spec R23, D5; TW13; named Ships until the owner's 540 banner design of 2026-11-26;
## its id stays &"ships"). It shows only on the player's own port settlements (TileView's own_port: the own case and Improve.is_port).
## On top, the one real part: an empty bordered box, "No ships in port" and a line in the game's words saying shipyards come with
## the age of sail (issue 436 round 3, the owner's decision 3). Under it the placeholders of the navy to come (TileBoxes, the
## "soon" tag, muted example values, "Example only: not in the game yet" on hover): "Build a ship" with the Cog, the Galley and the
## Carrack, each with a greyed Build button; then the boxes Harbour and Fleets nearby, Crews and Routes, Shipyard and Naval log.
## The harbour's level is the real one (the view's picture); the rest are examples. The window's fit hides the last pair first and
## the ship cards last; the empty box never hides. Never dimmed (D5); it changes nothing in the game.
class_name ShipsTab
extends TileTab

const ID := &"ships"
const LABEL := "Navy"
const ORDER := 40

const HEADING := "No ships in port."
const NOTE := "Shipyards come with the age of sail."
const BUILD_HEAD := "Build a ship"
const BUILD := "Build"
## The ship cards: name, the line under it.
const SHIPS: Array = [["Cog", "Trade ship, 40 loads"], ["Galley", "War ship, calm seas"], ["Carrack", "Ocean ship"]]
const SHIP_ICON := &"port_dues"
const HARBOUR_WORDS: Array[String] = ["none", "jetty", "harbour", "great harbour"]
const FLEETS_ROWS: Array = [["Your fleets", "none"], ["Foreign sails", "2 seen"]]
const CREWS_ROWS: Array = [["Sailors", "0"], ["Captains", "0"], ["Upkeep", "0 a year"]]
const ROUTES_ROWS: Array = [["To the next port", "3 hexes"], ["Piracy", "low"], ["Winds", "mild"]]
const YARD_ROWS: Array = [["Slips", "0"], ["Timber", "2 in store"], ["Hemp", "1 in store"]]
const LOG_ROWS: Array = [["Last season", "none"], ["A year ago", "none"], ["Two years ago", "none"]]

var _retired: Array[Node] = []


static func applies(view: Dictionary) -> bool:
	return bool(view.get("own_port", false))


static func dimmed(_view: Dictionary) -> String:
	return ""


## Fills the tab for the hex: the empty box, then (on your own port) the placeholders.
func fill(_game: Game, _viewer: StringName, _hex: Vector2i, view: Dictionary) -> void:
	PanelKit.clear_children(self, _retired)
	add_theme_constant_override(&"separation", TileBoxes.GAP)
	var box := PanelContainer.new()
	box.name = &"EmptyBox"
	box.theme_type_variation = &"PanelSlot"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var column := VBoxContainer.new()
	column.name = &"Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(column)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.custom_minimum_size.y = 64.0
	var heading := PanelKit.label(HEADING, &"TileName")
	heading.name = &"Heading"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var note := PanelKit.label(NOTE, &"TileHint")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.name = &"Note"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	if applies(view) and TileBoxes.allowed(view):
		_placeholders(view)


func _placeholders(view: Dictionary) -> void:
	var ships := VBoxContainer.new()
	ships.name = &"Shipyard"
	ships.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ships.add_theme_constant_override(&"separation", Tokens.S1)
	ships.add_child(TileBoxes.head(BUILD_HEAD, true))
	for spec: Array in SHIPS:
		ships.add_child(_ship_card(str(spec[0]), str(spec[1])))
	add_child(TileBoxes.rank(ships, TileBoxes.RANK_SHIPS))
	var level := clampi(int(((view.get("header", {}) as Dictionary).get("picture", {}) as Dictionary).get("harbour", 0)), 0,
		HARBOUR_WORDS.size() - 1)
	var harbour := TileBoxes.box("Harbour", [["Level", HARBOUR_WORDS[level], false], ["Sea", "calm", true]], true)
	add_child(TileBoxes.pair(harbour, TileBoxes.box("Fleets nearby", FLEETS_ROWS, true), TileBoxes.RANK_PAIR_MID))
	add_child(TileBoxes.pair(TileBoxes.box("Crews", CREWS_ROWS, true), TileBoxes.box("Routes", ROUTES_ROWS, true),
		TileBoxes.RANK_PAIR_HIGH))
	add_child(TileBoxes.pair(TileBoxes.box("Shipyard", YARD_ROWS, true), TileBoxes.box("Naval log", LOG_ROWS, true),
		TileBoxes.RANK_PAIR_TOP))


## One ship card as the Army tab's army card: the ship on a wooden icon tile, its name and line, and a greyed Build button.
func _ship_card(title: String, line_text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = StringName("Ship" + title)
	card.theme_type_variation = &"PanelTileUnit"
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.tooltip_text = "%s: %s\n%s" % [title, line_text, SoonTag.EXAMPLE_TIP]
	card.set_meta(&"example", true)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", Tokens.S2 + 2)
	card.add_child(line)
	line.add_child(icon_tile(self, SHIP_ICON))
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override(&"separation", 0)
	text.add_child(PanelKit.label(title, &"TileName"))
	text.add_child(PanelKit.label(line_text, &"TileValueMuted"))
	line.add_child(text)
	var build := Button.new()
	build.name = &"Build"
	build.text = BUILD
	build.theme_type_variation = &"ButtonTileAct"
	build.disabled = true
	build.mouse_filter = Control.MOUSE_FILTER_STOP
	build.tooltip_text = SoonTag.EXAMPLE_TIP
	build.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(build)
	return card


func _exit_tree() -> void:
	PanelKit.free_retired(_retired)
