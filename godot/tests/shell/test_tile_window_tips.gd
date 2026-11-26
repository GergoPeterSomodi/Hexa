## The owner's rule for the tile window (issue 436): the look is icon first (chips, plaques, tiles, badges, stars, cards), so
## every icon and number explains itself on hover. This walks the window on each case this map has (own settlement, own land
## with no settlement, foreign land, sea, an undiscovered hex) and each of its live tabs, with the real tabs, and asserts that
## every such control has a tooltip, or (a building tile, a company row) a hover card through its hovered signal.
extends GutTest

const WINDOW := "res://shell/panels/tile_window.tscn"
## The panel variations that carry an icon or a number and so must explain themselves.
const ICON_PANELS: Array[StringName] = [&"PanelTileChip", &"PanelTilePlaque", &"PanelTileRound", &"PanelTileRoundBad",
	&"PanelTileUnit", &"PanelTileQueueRow", &"PanelTileSiege"]


func before_each() -> void:
	Bindings.ensure()
	var defs := Session.defs()
	var scenario: ScenarioDef = defs.scenarios[defs.scenarios.size() - 1]
	Session.new_scenario(scenario.id, MapScene.START_SEED, &"GEN")


func after_each() -> void:
	await get_tree().process_frame


func _hex_where(pred: Callable) -> Vector2i:
	var game := Session.game
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if bool(pred.call(TileView.of(game, Session.player_tag(), hex))):
			return hex
	return HexPanelContract.NO_HEX


func _cases() -> Array[Vector2i]:
	var preds: Array[Callable] = [
		func(v: Dictionary) -> bool: return str(v.get("case", "")) == "own" and not (v["header"]["picture"] as Dictionary).is_empty(),
		func(v: Dictionary) -> bool: return str(v.get("case", "")) == "own" and (v["header"]["picture"] as Dictionary).is_empty(),
		func(v: Dictionary) -> bool: return str(v.get("case", "")) == "foreign",
		func(v: Dictionary) -> bool: return str(v.get("case", "")) == "sea",
		func(v: Dictionary) -> bool: return str(v.get("case", "")) == "unexplored",
	]
	var out: Array[Vector2i] = []
	for pred: Callable in preds:
		var hex := _hex_where(pred)
		if hex != HexPanelContract.NO_HEX:
			out.append(hex)
	return out


func test_every_icon_and_number_explains_itself_on_hover() -> void:
	var sub := SubViewport.new()
	sub.size = Vector2i(1280, 720)
	add_child_autofree(sub)
	var win := (load(WINDOW) as PackedScene).instantiate() as TileWindow
	sub.add_child(win)
	win.theme = KitTheme.load_for(1.0)
	win.position = Vector2(840.0, 64.0)
	var checked := 0
	for hex: Vector2i in _cases():
		win.show_hex(hex)
		var tabs: Array[StringName] = win.tab_ids()
		if tabs.is_empty():
			tabs.append(&"")
		for id: StringName in tabs:
			if id != &"" and win.live_tab_ids().has(id):
				win.show_tab(id)
			var node := win.tab_node()
			if node != null and node.has_method("finish_now"):
				node.call("finish_now")
			await get_tree().process_frame
			checked += _walk(win, "%s %s" % [hex, id])
	assert_gt(checked, 20, "the walk met the window's icons and numbers")


## The tooltip the pointer meets on `c`, as the viewport finds it: its own, else (while the pointer passes through, the
## control not stopping it) the nearest ancestor's.
static func _tip_of(c: Control) -> String:
	var at: Node = c
	while at is Control:
		var control := at as Control
		if control.tooltip_text != "" or control.mouse_filter == Control.MOUSE_FILTER_STOP:
			return control.tooltip_text
		at = at.get_parent()
	return ""


## Checks every visible icon or number control under `node`; returns how many it checked.
func _walk(node: Node, where: String) -> int:
	var count := 0
	if node is Control and (node as Control).is_visible_in_tree():
		var c := node as Control
		var what := "%s: %s %s" % [where, c.get_class(), c.theme_type_variation]
		if node is BuildingRow:
			assert_ne(c.tooltip_text, "", what + " has its words as tooltip")
			assert_gt((node as BuildingRow).hovered.get_connections().size(), 0, what + " shows its hover card")
			count += 1
		elif node is CompanyRow:
			assert_gt((node as CompanyRow).hovered.get_connections().size(), 0, what + " shows its company card")
			count += 1
		elif c is PanelContainer and ICON_PANELS.has(c.theme_type_variation):
			# A part the pointer passes through (a plaque's round icon) is explained by the control under it.
			assert_ne(_tip_of(c), "", what + " has a tooltip (%s)" % c.get_path())
			count += 1
		elif c is Button and ((c as Button).text == "" or (c as Button).disabled):
			assert_ne(c.tooltip_text, "", what + " (an icon or a greyed button) has a tooltip")
			count += 1
		elif node is SettlementEmblem:
			# Issue 436 round 3: the settlement type's emblem replaced the stars; it names the type on hover.
			assert_ne(c.tooltip_text, "", what + " (the emblem) names the type")
			count += 1
		elif c.name == &"Stars" or c.name == &"Food" or c.name == &"HexCell" or c.name == &"QueueNote":
			assert_ne(c.tooltip_text, "", what + " has a tooltip")
			count += 1
	for child: Node in node.get_children():
		count += _walk(child, where)
	return count
