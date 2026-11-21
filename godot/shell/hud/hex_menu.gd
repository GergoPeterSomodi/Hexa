## The hex menu (docs/architecture/m6-build-spec.md 6.1 and 6.8; L19, issue #209). A right click, or O and Shift+F10 at the
## cursor, on a hex of yours while no army of yours is selected opens it at the pointer (or the hex). Items: the hex's works
## (ImprovePreview.options_of; a refused one is disabled with its reason as the tooltip), "Raise companies here..." on your
## settlement, one "Select the Army of X" per army of yours on the hex, and "Show supply (6)". Keyboard: the PopupMenu's own
## focus (Up, Down, Enter, Esc). A choice is emitted as chosen(action) and then carried out here, so no App wiring is needed:
##   [&"work", hex, row]        the hex panel's row click (game/confirm_works: the card or the work)
##   [&"raise_tab", hex]        selects the hex and opens its Raise tab
##   [&"select_army", id]       selects the army (MapArmies.select_army)
##   [&"map_mode", &"supply"]   the Supply mode (MapScene.set_mode)
## Built and owned by MapArmies (its child, set up with setup()). It reads the game and changes it only through Session.
class_name HexMenu
extends PopupMenu

signal chosen(action: Array)

var _scene: MapScene = null
var _armies: MapArmies = null
## One entry a menu item id: {action: Array, enabled: bool}.
var _entries: Array[Dictionary] = []


func _init() -> void:
	hide_on_item_selection = true


## Gives the menu the map scene (selection, mode, the hex panel) and the map's armies (selection).
func setup(scene: MapScene, armies: Node) -> void:
	_scene = scene
	_armies = armies as MapArmies
	if not id_pressed.is_connected(_on_id_pressed):
		id_pressed.connect(_on_id_pressed)


## True when `hex` is land of `tag` in a game with countries: the only hexes the menu opens on.
static func own_hex(game: Game, tag: StringName, hex: Vector2i) -> bool:
	if tag == &"" or game == null or not game.has_countries() or not game.map.has(hex) or not game.map.is_land(hex):
		return false
	return Territory.owner_tag(game, hex) == tag


## Opens the menu for `hex` at screen position `at`. False (and nothing shown) when the hex is not one of yours.
func open_for(hex: Vector2i, at: Vector2) -> bool:
	var game := Session.game
	var tag := Session.player_tag()
	if not own_hex(game, tag, hex):
		return false
	clear()
	_entries.clear()
	var works := ImprovePreview.options_of(game, tag, hex)
	for row: Dictionary in works:
		_add_work(game, hex, row)
	_section()
	if RaiseList.offered(game, tag, hex):
		_add_item("Raise companies here...", [&"raise_tab", hex], true, "")
	_section()
	for army: Army in Armies.at(game, hex):
		if army.tag == tag:
			_add_item("Select %s" % army.name, [&"select_army", army.id], true, "")
	_section()
	_add_item("Show supply (6)", [&"map_mode", &"supply"], true, "")
	popup(Rect2i(Vector2i(at), Vector2i.ONE))
	return true


## One work row: "Build vineyard · 40 · 4 seasons", disabled with its reason when refused.
func _add_work(game: Game, hex: Vector2i, row: Dictionary) -> void:
	var verdict: Dictionary = row["verdict"]
	var ok := bool(verdict["ok"])
	var option := {"action": row["action"], "family": row["family"]}
	var label := str(row["label"])
	var cost := str(row["cost_text"])
	if cost != "":
		label += " · " + cost
	var reason := "" if ok else ImprovePreview.reason_words(game, hex, option, verdict)
	_add_item(label, [&"work", hex, row], ok, reason)


func _add_item(label: String, action: Array, enabled: bool, reason: String) -> void:
	var id := _entries.size()
	add_item(label, id)
	var index := item_count - 1
	set_item_disabled(index, not enabled)
	if reason != "":
		set_item_tooltip(index, reason)
	_entries.append({"action": action, "enabled": enabled})


## A separator between the groups of items, never two in a row and never first.
func _section() -> void:
	if item_count > 0 and not is_item_separator(item_count - 1):
		add_separator()


## The items as {id, label, enabled, action} in display order, for the tests and the keyboard path (separators left out).
func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index: int in item_count:
		if is_item_separator(index):
			continue
		var id := get_item_id(index)
		out.append({"id": id, "label": get_item_text(index), "enabled": not is_item_disabled(index), "action": _entries[id]["action"]})
	return out


## The item id of the first item whose action starts with `kind` (for example &"raise_tab"), or -1.
func item_id_of(kind: StringName) -> int:
	for id: int in _entries.size():
		var action: Array = _entries[id]["action"]
		if StringName(action[0]) == kind:
			return id
	return -1


func _on_id_pressed(id: int) -> void:
	if id < 0 or id >= _entries.size() or not bool(_entries[id]["enabled"]):
		return
	var action: Array = _entries[id]["action"]
	chosen.emit(action)
	_carry_out(action)


## Carries out a choice here (the rules are Session's; the panel and the map are the scene's).
func _carry_out(action: Array) -> void:
	var kind := StringName(action[0])
	if kind == &"work":
		_work(action[1], action[2] as Dictionary)
	elif kind == &"raise_tab":
		_scene.select_hex(action[1])
		var panel := _scene.panel() as HexPanel
		if panel != null:
			panel.show_raise()
	elif kind == &"select_army":
		_armies.select_army(int(action[1]))
	elif kind == &"map_mode":
		_scene.set_mode(MapModes.Mode.SUPPLY)


## The work of a row: the hex panel's row click when it is there (the confirm rule and the App's card); else the work itself.
func _work(hex: Vector2i, row: Dictionary) -> void:
	_scene.select_hex(hex)
	var option := {"action": row["action"], "family": row["family"]}
	var panel := _scene.panel() as HexPanel
	if panel != null and panel.shown_hex() == hex:
		panel.begin_option(option, bool(row["expensive"]))
		return
	var args := {"hex": hex}
	if str(row["action"]) == String(Works.BUILD):
		args["family"] = int(row["family"])
	Session.act(str(row["action"]), args)
