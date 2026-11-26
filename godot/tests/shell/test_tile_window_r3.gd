## The tile window's third polish round (issue 436; the designer's review H1 to H5, M1 to M9, L1 to L7 and the owner's decisions):
## the place line never hidden at any size and scale (H1), the queue at the foot of every tab of own land (H2), no text under
## 15 logical px and no head under 14 (H3), building states told apart by shape (H4), the hover card's width, title and place
## (H5), the header's skeleton at sea and in deep fog (M6), the folding facts remembered (M8), the height's UI scale (M9), the
## fade under the body (L1), the picture's icon buttons (L3), the dimmed tab's lock and the closed note in view (L6), and the
## emblem of the settlement type and the picture scaled to the width (the owner's decisions 2 and 5).
extends GutTest

const WINDOW := "res://shell/panels/tile_window.tscn"
const LAND := preload("res://shell/panels/tile_tabs/land_facts.gd")
## The variations that may be 14 px: the small-caps heads, the age badge and the numerals in a tile's corner plaque.
const HEADS: Array[StringName] = [&"TileHead", &"TileEra", &"TileLevel"]


func before_each() -> void:
	Bindings.ensure()
	var defs := Session.defs()
	var scenario: ScenarioDef = defs.scenarios[defs.scenarios.size() - 1]
	Session.new_scenario(scenario.id, MapScene.START_SEED, &"GEN")
	LAND.folded = {}


func after_each() -> void:
	LAND.folded = {}
	await get_tree().process_frame


func _hex_where(pred: Callable) -> Vector2i:
	var game := Session.game
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if bool(pred.call(TileView.of(game, Session.player_tag(), hex))):
			return hex
	return HexPanelContract.NO_HEX


func _case(name: String) -> Vector2i:
	return _hex_where(func(v: Dictionary) -> bool:
		var case_id := str(v.get("case", ""))
		match name:
			"settlement":
				return case_id == "own" and bool(v["army"]["raise_offered"])
			"wild":
				return case_id == "own" and (v["header"]["picture"] as Dictionary).is_empty()
		return case_id == name)


## A window in a viewport of `physical` pixels seen at `ui_scale`, right-docked under a 64 px bar.
func _window_at(physical: Vector2i, ui_scale: float) -> TileWindow:
	var logical := Vector2i(roundi(physical.x / ui_scale), roundi(physical.y / ui_scale))
	var sub := SubViewport.new()
	sub.size = physical
	if physical != logical:
		sub.size_2d_override = logical
		sub.size_2d_override_stretch = true
	add_child_autofree(sub)
	var win := (load(WINDOW) as PackedScene).instantiate() as TileWindow
	sub.add_child(win)
	win.theme = KitTheme.load_for(ui_scale)
	win.position = Vector2(float(logical.x - Tokens.TILE_WINDOW_W), 64.0)
	return win


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


# --- H1: the place and owner line --------------------------------------------------------------------------------------


func test_the_place_line_shows_at_every_size_and_scale() -> void:
	var runs: Array = [[Vector2i(1280, 720), 1.0], [Vector2i(1280, 720), 2.0], [Vector2i(1920, 1080), 1.0],
		[Vector2i(1920, 1080), 1.25], [Vector2i(1920, 1080), 1.5], [Vector2i(2560, 1440), 1.0], [Vector2i(2560, 1440), 2.0]]
	var hexes: Array[Vector2i] = [_case("settlement"), _case("foreign")]
	for run: Array in runs:
		var win := _window_at(run[0] as Vector2i, float(run[1]))
		for hex: Vector2i in hexes:
			win.show_hex(hex)
			await _frames(3)
			var place := win.get_node("%Place") as Button
			var where := "%s @%s on %s" % [str(run[0]), str(run[1]), str(hex)]
			assert_ne(place.text, "", where + ": the place line has its words")
			assert_true(place.is_visible_in_tree(), where + ": the place line is shown")
			assert_gt(place.size.x, 40.0, where + ": the place line has room (%d px)" % int(place.size.x))
			assert_true(win.get_global_rect().grow(0.5).encloses(place.get_global_rect()), where + ": inside the window")


# --- H2: the queue ------------------------------------------------------------------------------------------------------


func test_the_queue_is_at_the_foot_of_every_tab_of_own_land() -> void:
	var win := _window_at(Vector2i(1280, 720), 1.0)
	var hex := _case("settlement")
	win.show_hex(hex)
	for id: StringName in win.live_tab_ids():
		win.show_tab(id)
		await _frames(2)
		var band := win.get_node("%WorkBand") as Control
		assert_true(band.is_visible_in_tree(), "the queue shows on the %s tab" % id)
		assert_eq((win.get_node("%QueueNote") as Label).text, TileWindow.QUEUE_IDLE, "idle: No work under way")
		assert_false((win.get_node("%QueueRow") as Control).visible, "no work row while idle")
		assert_lte(band.get_global_rect().end.y, win.get_global_rect().end.y + 0.5, "the queue lies inside the window")
	for name: String in ["foreign", "sea"]:
		var other := _case(name)
		if other == HexPanelContract.NO_HEX:
			continue
		win.show_hex(other)
		await _frames(2)
		if WorksView.at(Session.game, other, Session.player_tag()).is_empty():
			assert_false((win.get_node("%WorkBand") as Control).visible, "no queue on %s with no work" % name)


# --- H3: text sizes -----------------------------------------------------------------------------------------------------


func test_no_text_in_the_window_is_under_15_px_and_no_head_under_14() -> void:
	var win := _window_at(Vector2i(1280, 720), 1.0)
	var checked := 0
	for name: String in ["settlement", "wild", "foreign", "sea", "unexplored"]:
		var hex := _case(name)
		if hex == HexPanelContract.NO_HEX:
			continue
		win.show_hex(hex)
		var tabs := win.live_tab_ids()
		if tabs.is_empty():
			tabs.append(&"")
		for id: StringName in tabs:
			if id != &"":
				win.show_tab(id)
			var node := win.tab_node()
			if node != null and node.has_method("finish_now"):
				node.call("finish_now")
			await _frames(1)
			checked += _check_sizes(win, "%s %s" % [name, id])
	assert_gt(checked, 40, "the walk met the window's texts")


func _check_sizes(node: Node, where: String) -> int:
	var count := 0
	if node is Control and (node as Control).is_visible_in_tree():
		var text := ""
		if node is Label:
			text = (node as Label).text
		elif node is Button:
			text = (node as Button).text
		if text != "":
			var c := node as Control
			var px := c.get_theme_font_size(&"font_size")
			var floor_px := 14 if HEADS.has(c.theme_type_variation) else 15
			assert_gte(px, floor_px, "%s: '%s' (%s) is %d px" % [where, text, c.theme_type_variation, px])
			count += 1
	for child: Node in node.get_children():
		count += _check_sizes(child, where)
	return count


# --- H4: building states by shape ---------------------------------------------------------------------------------------


func _tile(state: String, extra: Dictionary = {}) -> BuildingRow:
	var data := {"id": "t:" + state, "group": "land", "name": "Vineyard", "icon": "vineyard", "state": state, "state_text": "",
		"tone": "plain", "progress": 0.5, "gain": null, "upkeep": null, "option": {"action": "build", "family": 1},
		"hammer": state == "ready", "reason": "", "expensive": false, "gate": {}, "level": 0}
	data.merge(extra, true)
	var row := BuildingRow.new()
	row.setup(data)
	row.theme = KitTheme.load_for(1.0)
	add_child_autofree(row)
	return row


func test_each_building_state_has_its_own_shape_without_colour() -> void:
	var tiles := {
		"built": _tile("built", {"option": {}, "hammer": false, "level": 4}),
		"building": _tile("building", {"option": {}}),
		"ready": _tile("ready"),
		"short": _tile("short", {"state_text": "cost 300 · you have 204"}),
		"locked": _tile("locked", {"gate": {"year": 1495}, "state_text": "opens in 1495"}),
		"free": _tile("free", {"option": {}}),
	}
	await _frames(1)
	var shapes := {}
	for state: String in tiles:
		var marks: Dictionary = (tiles[state] as BuildingRow).marks()
		marks.erase("rim")  # the colour: what is left must still tell the states apart (H4)
		var key := var_to_str(marks)
		assert_false(shapes.has(key), "%s looks like %s without its colour: %s" % [state, str(shapes.get(key, "")), key])
		shapes[key] = state
	assert_eq((tiles["built"] as BuildingRow).marks()["corner"], &"level", "built: the level in its corner plaque")
	assert_eq((tiles["built"] as BuildingRow).level_text(), "IV")
	assert_eq((tiles["ready"] as BuildingRow).marks()["corner"], &"plus", "can build: the + badge")
	assert_true(bool((tiles["ready"] as BuildingRow).marks()["dimmed"]), "can build: the icon dimmed")
	assert_eq((tiles["building"] as BuildingRow).marks()["corner"], &"hourglass", "building: the hourglass")
	assert_true(bool((tiles["building"] as BuildingRow).marks()["bar"]), "building: the progress bar")
	assert_eq((tiles["short"] as BuildingRow).marks()["corner"], &"bang", "short: the ! badge")
	assert_eq((tiles["locked"] as BuildingRow).marks()["icon"], &"lock", "locked: the padlock")
	assert_eq((tiles["locked"] as BuildingRow).marks()["number"], "1495", "locked: the year that opens it")
	assert_eq((tiles["free"] as BuildingRow).marks()["icon"], &"house", "free: the house silhouette")
	assert_eq((tiles["built"] as BuildingRow).custom_minimum_size, Vector2(40, 40), "the owner's 40 px tiles")


func test_a_hovered_tile_is_lit() -> void:
	var row := _tile("ready")
	assert_false(row.lit())
	row.mouse_entered.emit()
	assert_true(row.lit(), "the hovered tile has its bright rim")
	row.mouse_exited.emit()
	assert_false(row.lit())


# --- H5: the hover card -------------------------------------------------------------------------------------------------


func test_the_hover_card_is_320_wide_titled_by_its_action_and_placed_beside_the_tile() -> void:
	var game := Session.game
	var hex := _case("settlement")
	var option := {}
	for row: Dictionary in ImprovePreview.options_of(game, &"GEN", hex):
		if StringName(str(row["action"])) == Works.UPGRADE:
			option = {"action": row["action"], "family": row["family"]}
	if option.is_empty():
		pending("no upgrade offered at the town")
		return
	var sub := SubViewport.new()
	sub.size = Vector2i(1280, 720)
	add_child_autofree(sub)
	var card := TileHoverCard.new()
	card.theme = KitTheme.load_for(1.0)
	sub.add_child(card)
	card.show_card(RowCard.hover_of(BuildingCard.of(game, &"GEN", hex, option)))
	await _frames(2)
	card.reset_size()
	assert_eq(card.size.x, TileHoverCard.WIDTH, "320 logical px wide, the long payback wraps")
	assert_true(card.title_text().begins_with("Upgrade to "), "the title is the action: " + card.title_text())
	var tile := Rect2(1100, 400, 40, 40)
	var spot := RowCard.place(tile, card.size, Vector2(1280, 720), 680.0)
	assert_almost_eq(spot.x + card.size.x, tile.position.x - float(Tokens.S2), 0.5, "its right edge 8 px left of the tile")
	assert_lte(spot.y + card.size.y, 680.0 - float(Tokens.S2) + 0.5, "above the key-hint bar")
	var lines := BuildingCard.of(game, &"GEN", hex, option)["sections"] as Array
	for section: Variant in lines:
		for line: Variant in (section as Dictionary)["lines"]:
			assert_false(str((line as Array)[0]).contains("a season") and str((line as Array)[2]).contains("ducat"),
				"money is a year: %s" % str(line))


# --- M6, the owner's decisions 2 and 5: the header's skeleton, the emblem, the picture --------------------------------------


func test_deep_fog_shows_one_muted_chip_and_terra_incognita() -> void:
	var hex := _case("unexplored")
	if hex == HexPanelContract.NO_HEX:
		var g := Session.game
		FogFixture.thin(g, &"GEN", 0)
		g.version += 1
		hex = _case("unexplored")
	var win := _window_at(Vector2i(1280, 720), 1.0)
	win.show_hex(hex)
	await _frames(1)
	assert_eq((win.get_node("%Strip") as StripCells).values(), PackedStringArray(["Unexplored"]), "one Unexplored chip")
	var picture := win.get_node("%Picture") as SettlementPicture
	assert_true(picture.is_visible_in_tree(), "the picture keeps its place")
	assert_eq(picture.current_recipe()[0]["part"], &"parchment", "terra incognita, not the word twice")


func test_the_emblem_names_the_settlement_type_and_each_type_has_its_charge() -> void:
	var win := _window_at(Vector2i(1280, 720), 1.0)
	win.show_hex(_case("settlement"))
	await _frames(1)
	var emblem := win.header().emblem()
	assert_true(emblem.is_visible_in_tree(), "the emblem shows on a settlement")
	var view := TileView.of(Session.game, &"GEN", win.shown_hex())
	var kind := StringName(str(view["header"]["picture"]["kind"]))
	assert_true(emblem.tooltip_text.begins_with(SettlementEmblem.name_of(kind, int(view["header"]["picture"]["level"]))),
		"its tooltip names the type: " + emblem.tooltip_text)
	var charges := {}
	for case: Array in [[&"hamlet", 1], [&"village", 2], [&"town", 3], [&"walled_town", 4], [&"city", 5], [&"castle", 1],
			[&"castle", 2], [&"castle", 3]]:
		charges[SettlementEmblem.charge_of(case[0], case[1])] = true
	assert_eq(charges.size(), 8, "eight types, eight charges")
	win.show_hex(_case("wild"))
	await _frames(1)
	assert_false(emblem.visible, "no emblem without a settlement")


func test_the_picture_shows_the_whole_scene_by_the_window_width() -> void:
	var k := SettlementPicture.scene_scale(Vector2(434, 150))
	assert_almost_eq(k.x, 434.0 / 296.0, 0.001, "scaled by the width (about 1.5 times)")
	assert_lte(SettlementPicture.LOGICAL_SIZE.y * k.y, 150.0, "the whole scene fits the height; the sky fills above")
	for shape: Dictionary in SettlementPicture.recipe(&"town", 1, 3, false, Tokens.LAPIS):
		if shape["part"] == &"sail":
			assert_eq(shape["shape"], &"rect", "a square sail, not the play-button triangle (L5)")


# --- M8: folding facts --------------------------------------------------------------------------------------------------


func test_a_folded_section_stays_folded_on_the_next_tile() -> void:
	var win := _window_at(Vector2i(1280, 720), 1.0)
	win.show_hex(_case("settlement"))
	win.show_tab(&"town")
	await _frames(1)
	var facts := (win.tab_node() as Object).call("facts") as Node
	var heads: Dictionary = facts.call("fold_heads")
	assert_true(heads.has(LAND.HEAD_MADE), "the Made here head folds")
	(heads[LAND.HEAD_MADE] as Button).pressed.emit()
	assert_false(((heads[LAND.HEAD_MADE] as Button).get_meta("body") as Control).visible, "folded")
	win.show_hex(_case("wild"))
	await _frames(1)
	facts = (win.tab_node() as Object).call("facts") as Node
	heads = facts.call("fold_heads")
	assert_false(((heads[LAND.HEAD_MADE] as Button).get_meta("body") as Control).visible, "still folded on another tile")
	assert_true(((heads[LAND.HEAD_GROUND] as Button).get_meta("body") as Control).visible, "the others stay open")


# --- L1, L3, L6 ---------------------------------------------------------------------------------------------------------


func test_the_fade_shows_while_more_lies_below() -> void:
	var win := _window_at(Vector2i(1280, 720), 1.0)
	win.show_hex(_case("settlement"))
	win.show_tab(&"town")
	await _frames(3)
	var scroll := win.get_node("%Scroll") as ScrollContainer
	if scroll.get_v_scroll_bar().max_value <= scroll.size.y:
		pending("the Town tab fits without scrolling here")
		return
	assert_true(win.fade_shown(), "the fade lies under the last visible row")
	scroll.scroll_vertical = 100000
	await _frames(2)
	assert_false(win.fade_shown(), "no fade at the foot")


func test_picture_icon_buttons_ask_and_show_only_when_the_view_says() -> void:
	var win := _window_at(Vector2i(1280, 720), 1.0)
	var seen: Array = []
	win.app_requested.connect(func(what: StringName, args: Dictionary) -> void: seen.append([what, args]))
	var hex := _hex_where(func(v: Dictionary) -> bool: return bool((v.get("land", {}) as Dictionary).get("supply", false)))
	if hex == HexPanelContract.NO_HEX:
		pending("no hex with supply")
		return
	win.show_hex(hex)
	var supply := win.header().icon_button(&"SupplyButton")
	assert_not_null(supply, "Show supply is an icon button on the picture")
	assert_ne(supply.tooltip_text, "", "with its words as tooltip")
	supply.pressed.emit()
	assert_eq(seen[0][0], &"map_mode", "it asks for the supply mode")
	var castle_hex := _hex_where(func(v: Dictionary) -> bool:
		return bool((v.get("land", {}) as Dictionary).get("castle_area", false)))
	if castle_hex != HexPanelContract.NO_HEX:
		win.show_hex(castle_hex)
		win.header().icon_button(&"CastleButton").pressed.emit()
		assert_eq(seen[seen.size() - 1][0], &"castle_area", "Show the castle area asks for it")
		assert_eq((seen[seen.size() - 1][1] as Dictionary)["hex"], castle_hex, "for the shown hex")
	var none := _hex_where(func(v: Dictionary) -> bool:
		var land: Dictionary = v.get("land", {})
		return str(v.get("case", "")) != "unexplored" and not bool(land.get("supply", false)) and not bool(land.get("castle_area", false)))
	if none != HexPanelContract.NO_HEX:
		win.show_hex(none)
		assert_null(win.header().icon_button(&"SupplyButton"), "no supply button without supply")
		assert_null(win.header().icon_button(&"CastleButton"), "no castle button without a castle")


func test_a_dimmed_tab_shows_a_lock_and_the_closed_note_is_in_view_on_foreign_land() -> void:
	var hex := _case("foreign")
	if hex == HexPanelContract.NO_HEX:
		pending("no foreign land")
		return
	var win := _window_at(Vector2i(1280, 720), 1.0)
	win.show_hex(hex)
	await _frames(3)
	var army: Button = null
	for child: Node in (win.get_node("%TabStrip") as Node).get_children():
		if child.get_meta("tab_id", &"") == &"army":
			army = child as Button
	if army == null or not army.disabled:
		pending("the Army tab is live on this foreign hex")
		return
	assert_not_null(army.icon, "the dimmed tab shows a lock (L6)")
	var note := win.closed_note()
	assert_not_null(note, "the closed note is drawn")
	assert_true(note.is_visible_in_tree(), "and shown")
	var scroll := win.get_node("%Scroll") as ScrollContainer
	assert_true(scroll.get_global_rect().grow(0.5).encloses(note.get_global_rect()), "seen without scrolling")
