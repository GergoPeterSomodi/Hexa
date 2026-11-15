## The minimal hex panel of the map scene (the prototype's panel in containers): title, facts, and the Build / Upgrade /
## Clear buttons with a refused one's reason. T14 replaces it with shell/panels/hex_panel behind HexPanelContract.
class_name SimpleHexPanel
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

var _hex := NO_HEX
var _title: Label = null
var _facts: Label = null
var _actions: VBoxContainer = null


func _ready() -> void:
	custom_minimum_size = Vector2(300.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	box.add_child(_title)
	_facts = Label.new()
	_facts.add_theme_font_size_override("font_size", 13)
	box.add_child(_facts)
	_actions = VBoxContainer.new()
	_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_actions)
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
	var land := map.land[i] == 1
	var piece := Improve.piece_at(game, _hex)
	var place := Improve.place_of(map, _hex)
	var ground := COVER_WORDS[clampi(map.cover[i], 0, COVER_WORDS.size() - 1)]
	var title := str(place.get("name", ""))
	if title == "":
		title = "Sea" if not land else ground.capitalize()
	_title.text = title
	var lines: Array[String] = ["Hex %d, %d" % [_hex.x, _hex.y]]
	if piece.is_empty():
		lines.append("Wild land: nothing built" if land else "Open sea")
	else:
		lines.append("%s: %s" % [_family_word(str(piece["family"]), str(piece["extra"])),
			_level_word(str(piece["family"]), int(piece["level"]))])
		if int(piece["addon"]) > 0:
			lines.append("Harbour: %s (%s)" % [_level_word("harbour", int(piece["addon"])), str(piece["addon_mode"])])
		lines.append("Layout %d%s" % [int(piece["variant"]) + 1, ", mirrored" if bool(piece["mirror"]) else ""])
	if land:
		lines.append("")
		lines.append("Ground: %s" % ground)
		lines.append("Height: %d m" % map.height_m[i])
		lines.append("Winter: %s" % CLIMATE_WORDS[clampi(map.climate[i], 0, 2)])
		var facts := Improve.facts_of(map, _hex)
		var extras: Array[String] = []
		if bool(facts["coast"]):
			extras.append("coast")
		if bool(facts["river"]):
			extras.append("river")
		if bool(facts["road"]):
			extras.append("road")
		if bool(facts["pass"]):
			extras.append("pass")
		if not extras.is_empty():
			lines.append(", ".join(extras).capitalize())
	_facts.text = "\n".join(lines)
	_write_actions(piece, land)
	visible = true


## Build buttons for a wild hex; Upgrade and Clear for a built one. A refused button is disabled with its reason.
func _write_actions(piece: Dictionary, land: bool) -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	if not land:
		return
	if piece.is_empty():
		var options := Improve.build_options(Session.game, _hex)
		if options.is_empty():
			_add_note("Nothing can be built on this ground.")
			return
		_add_note("Build here:")
		for option: Dictionary in options:
			_add_action("Build " + _family_word(str(option["family"]), "-"), bool(option["ok"]), str(option["reason"]),
				"build", {"hex": _hex, "family": int(option["family_id"])})
		return
	var family_name := str(piece["family"])
	var level := int(piece["level"])
	var up := Session.check("upgrade", {"hex": _hex})
	var up_text := "Upgrade"
	if level < _top_level(family_name):
		up_text = "Upgrade to %s" % _level_name(family_name, level + 1)
	_add_action(up_text, bool(up["ok"]), str(up["reason"]), "upgrade", {"hex": _hex})
	var down := Session.check("clear", {"hex": _hex})
	_add_action("Clear", bool(down["ok"]), str(down["reason"]), "clear", {"hex": _hex})


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
	_add_note(reason, 11)


func _add_note(text: String, size: int = 13) -> void:
	var note := Label.new()
	note.text = text
	note.add_theme_font_size_override("font_size", size)
	note.add_theme_color_override("font_color", Color(0.62, 0.62, 0.62))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(280.0, 0.0)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actions.add_child(note)


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
