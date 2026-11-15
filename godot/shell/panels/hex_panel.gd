## The hex panel of the map scene (docs/architecture/m1-build-spec.md section 11, T14; the contract is HexPanelContract).
## It shows the selected hex's place or ground, what stands on it and at which level, its ground, the build list of a wild
## hex, and Upgrade and Clear of a built one. It reads the game and changes it only through Session.act. A refused button is
## disabled: its reason is the tooltip and a grey line under it. Built from the scene's containers and the Theme
## (shell/ui/theme.tres); the words are the minimal panel's (shell/map/simple_hex_panel.gd).
class_name HexPanel
extends HexPanelContract

## The words for a level, per family (docs/design/map/pieces/GUIDE.md section 8); other families use STAGE_WORDS.
const LEVEL_WORDS := {
	"settlements": ["", "hamlet", "village", "town", "walled town", "city"],
	"castles": ["", "watchtower", "castle", "fortress"],
	"harbour": ["", "fishing jetty", "quay", "port"],
}
const STAGE_WORDS: Array[String] = ["wild", "first stage", "second stage", "third stage"]
const COVER_WORDS: Array[String] = ["farmland", "grassland", "woods", "marsh", "rock", "snow", "tundra", "sand"]
const CLIMATE_WORDS: Array[String] = ["snow", "frost", "mild"]
const EDGES: Array[String] = ["coast", "river", "road", "pass"]

@onready var _title: Label = $Body/Title
@onready var _subtitle: Label = $Body/Subtitle
@onready var _piece_box: VBoxContainer = $Body/PieceBox
@onready var _piece_rows: GridContainer = $Body/PieceBox/Rows
@onready var _ground_box: VBoxContainer = $Body/GroundBox
@onready var _ground_rows: GridContainer = $Body/GroundBox/Rows
@onready var _actions_box: VBoxContainer = $Body/ActionsBox
@onready var _actions_heading: Label = $Body/ActionsBox/Heading
@onready var _actions: VBoxContainer = $Body/ActionsBox/Actions

var _hex := NO_HEX


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func show_hex(hex: Vector2i) -> void:
	_hex = hex
	refresh()


func clear() -> void:
	_hex = NO_HEX
	visible = false


func shown_hex() -> Vector2i:
	return _hex


func refresh() -> void:
	var game := Session.game
	if _hex == NO_HEX or game == null or not game.map.has(_hex):
		visible = false
		return
	var map := game.map
	var i := map.index_of(_hex)
	if map.land[i] == 0:
		_title.text = "Sea"
		_subtitle.text = "Hex %d, %d, open sea" % [_hex.x, _hex.y]
		_piece_box.visible = false
		_ground_box.visible = false
		_actions_box.visible = false
		visible = true
		return
	var piece := Improve.piece_at(game, _hex)
	var place := Improve.place_of(map, _hex)
	var ground := COVER_WORDS[clampi(map.cover[i], 0, COVER_WORDS.size() - 1)]
	var place_name := str(place.get("name", ""))
	_title.text = place_name if place_name != "" else ground.capitalize()
	_subtitle.text = "Hex %d, %d" % [_hex.x, _hex.y]
	_refresh_piece(piece)
	_refresh_ground(game, ground)
	_write_actions(piece)
	visible = true


## What stands on the hex and its level, or that nothing does.
func _refresh_piece(piece: Dictionary) -> void:
	_piece_box.visible = true
	var pairs: Array[String] = []
	if piece.is_empty():
		_add_pair(pairs, "Stands on it", "nothing (wild land)")
	else:
		var family := str(piece["family"])
		_add_pair(pairs, "Piece", _family_word(family, str(piece["extra"])))
		_add_pair(pairs, "Level", _level_word(family, int(piece["level"])))
		if int(piece["addon"]) > 0:
			_add_pair(pairs, "Harbour", "%s (%s)" % [_level_word("harbour", int(piece["addon"])), str(piece["addon_mode"])])
		_add_pair(pairs, "Layout", "%d%s" % [int(piece["variant"]) + 1, ", mirrored" if bool(piece["mirror"]) else ""])
	PanelKit.fill_rows(_piece_rows, pairs)


## The ground of a land hex: its cover, height, winter climate and the edges it has.
func _refresh_ground(game: Game, ground: String) -> void:
	_ground_box.visible = true
	var map := game.map
	var i := map.index_of(_hex)
	var facts := Improve.facts_of(map, _hex)
	var pairs: Array[String] = []
	_add_pair(pairs, "Ground", ground)
	_add_pair(pairs, "Height", "%d m" % map.height_m[i])
	_add_pair(pairs, "Winter", CLIMATE_WORDS[clampi(map.climate[i], 0, CLIMATE_WORDS.size() - 1)])
	var edges: Array[String] = []
	for edge: String in EDGES:
		if bool(facts[edge]):
			edges.append(edge)
	if not edges.is_empty():
		_add_pair(pairs, "Edges", ", ".join(PackedStringArray(edges)))
	PanelKit.fill_rows(_ground_rows, pairs)


## Build buttons for a wild hex; Upgrade and Clear for a built one. A refused button is disabled with its reason.
func _write_actions(piece: Dictionary) -> void:
	PanelKit.clear_children(_actions)
	_actions_box.visible = true
	if piece.is_empty():
		_actions_heading.text = "Build here"
		var options := Improve.build_options(Session.game, _hex)
		if options.is_empty():
			_actions.add_child(PanelKit.reason("Nothing can be built on this ground."))
			return
		for option: Dictionary in options:
			_add_action("Build " + _family_word(str(option["family"]), "-"), bool(option["ok"]), str(option["reason"]),
				"build", {"hex": _hex, "family": int(option["family_id"])})
		return
	_actions_heading.text = "Actions"
	var family_name := str(piece["family"])
	var level := int(piece["level"])
	var up := Session.check("upgrade", {"hex": _hex})
	var up_text := "Upgrade"
	if level < _top_level(family_name):
		up_text = "Upgrade to %s" % _level_name(family_name, level + 1)
	_add_action(up_text, bool(up["ok"]), str(up["reason"]), "upgrade", {"hex": _hex})
	var down := Session.check("clear", {"hex": _hex})
	_add_action("Clear", bool(down["ok"]), str(down["reason"]), "clear", {"hex": _hex})


## One action button: pressed, it asks Session; refused, it is disabled, with the reason as tooltip and a grey line.
func _add_action(text: String, ok: bool, reason: String, action: String, args: Dictionary) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE  # a key (U, R, 1 to 4) never presses a button that was clicked
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_actions.add_child(button)
	if ok:
		button.pressed.connect(func() -> void: Session.act(action, args))
		return
	button.disabled = true
	button.tooltip_text = reason
	if reason != "":
		_actions.add_child(PanelKit.reason(reason))


static func _add_pair(pairs: Array[String], key: String, value: String) -> void:
	pairs.append(key)
	pairs.append(value)


static func _top_level(family_name: String) -> int:
	var id := ImproveRules.NAMES.find(family_name)
	return ImproveRules.TOP_LEVEL[id] if id >= 0 else 0


static func _level_name(family_name: String, level: int) -> String:
	var word := ""
	if LEVEL_WORDS.has(family_name):
		var words: Array = LEVEL_WORDS[family_name]
		if level < words.size():
			word = str(words[level])
	elif level < STAGE_WORDS.size():
		word = STAGE_WORDS[level]
	return "%s (level %d)" % [word, level] if word != "" else "level %d" % level


static func _family_word(family: String, extra: String) -> String:
	var word := family.replace("_", " ").capitalize()
	if extra != "-" and extra != "":
		word += " (" + extra + ")"
	return word


static func _level_word(family: String, level: int) -> String:
	if LEVEL_WORDS.has(family):
		var words: Array = LEVEL_WORDS[family]
		if level >= 0 and level < words.size():
			return "level %d, %s" % [level, str(words[level])]
	if level >= 0 and level < STAGE_WORDS.size():
		return "level %d, %s" % [level, STAGE_WORDS[level]]
	return "level %d" % level
