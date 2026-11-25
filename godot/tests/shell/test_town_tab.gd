## The Town tab of the tile window (issue 436: Land and Buildings merged into one tab, as EU5's Infrastructure tab) and its
## land facts. The cases of test_land_tab.gd are here unchanged, as a GUT inner class that tests the part (land_facts.gd, the old
## Land tab renamed so the registry no longer lists it); TestTownTab tests the tab that stacks the parts. The building strips'
## cases (the old test_buildings_tab.gd) are in test_town_tab_strips.gd (one file would pass the 800-line limit).
extends GutTest


## (from test_land_tab.gd)
class TestLandFacts:
	extends GutTest

	## The Land tab of the tile window (tile-window spec R18, R24): the people and food figures (own, known country, unowned,
	## sandbox), the made rows, the out-of-sight line, the battle row's request, the two buttons, the sea rows, and the write scan.
	## Cases copied and adapted from test_hex_panel_people.gd, test_hex_panel_fog.gd and the details half of test_hex_panel.gd.

	const LAND := preload("res://shell/panels/tile_tabs/land_facts.gd")
	const TAB_PATH := "res://shell/panels/tile_tabs/land_facts.gd"

	var _tab: TileTab = null
	var _requests: Array = []


	func before_each() -> void:
		Bindings.ensure()
		Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
		_requests = []


	func after_each() -> void:
		Session.end_game()


	## A fresh tab filled for the hex and the viewer from the view dictionary.
	func _fill(game: Game, viewer: StringName, hex: Vector2i, view: Dictionary) -> void:
		_tab = LAND.new() as TileTab
		_tab.theme = KitTheme.load_for(1.0)
		add_child_autofree(_tab)
		_tab.app_requested.connect(func(what: StringName, args: Dictionary) -> void: _requests.append([what, args]))
		_tab.fill(game, viewer, hex, view)


	func _texts(node: Node, out: PackedStringArray) -> void:
		if node is Label or node is Button:
			out.append(str(node.get("text")))
		for child: Node in node.get_children():
			_texts(child, out)


	func _all_texts() -> PackedStringArray:
		var out := PackedStringArray()
		_texts(_tab, out)
		return out


	func _has_text(text: String) -> bool:
		return _all_texts().has(text)


	func _buttons() -> Array[Button]:
		var out: Array[Button] = []
		_collect_buttons(_tab, out)
		return out


	func _collect_buttons(node: Node, out: Array[Button]) -> void:
		if node is Button:
			out.append(node as Button)
		for child: Node in node.get_children():
			_collect_buttons(child, out)


	func _button(text: String) -> Button:
		for button: Button in _buttons():
			if button.text == text:
				return button
		return null


	## Genoa's first town (settlement) or countryside hex; Vector2i(-1, -1) if none.
	func _hex_of_country(tag: StringName, settlement: bool) -> Vector2i:
		var game := Session.game
		var c := Countries.by_tag(game, tag)
		for i: int in Territory.districts(game, c.id):
			if (int(game.state.main_use[i]) == People.SETTLEMENTS) == settlement:
				return game.map.hex_of(i)
		return Vector2i(-1, -1)


	func _gen_start() -> void:
		assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the scenario starts")
		assert_true(bool(Session.act("choose_country", {"tag": "GEN"})["ok"]))


	func _view(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary:
		return TileView.of(game, viewer, hex)


	## A hand-made view for the parts of the tab that read the view's facts only.
	func _fake_view(case_id: String, land: Dictionary) -> Dictionary:
		return {"case": case_id, "hex": Vector2i(1, 1), "sight": "sight", "land": land}


	func _land_base() -> Dictionary:
		return {"people": {"shown": false}, "food": {}, "made": [], "buildings": [], "ground_rows": [], "war": false,
			"war_rows": [], "battle": {}, "armies_hidden": false, "supply": false, "castle_area": false, "sea_rows": []}


	func test_applies_to_every_land_case_and_the_sea_but_not_unexplored() -> void:
		for case_id: String in ["own", "foreign", "unowned", "sandbox", "sea"]:
			assert_true(LAND.applies({"case": case_id}), "the Land tab shows on " + case_id)
		assert_false(LAND.applies({"case": "unexplored"}), "no Land tab on an undiscovered hex")
		assert_false(LAND.applies({}), "no Land tab without a view")


	func test_id_label_and_order_are_the_specs() -> void:
		assert_eq(LAND.ID, &"land")
		assert_eq(LAND.LABEL, "Land")
		assert_eq(LAND.ORDER, 10)
		assert_eq(LAND.dimmed({"case": "own"}), "", "the Land tab is never dimmed")


	func test_own_settlement_shows_people_change_room_and_outlook() -> void:
		_gen_start()
		var hex := _hex_of_country(&"GEN", true)
		assert_ne(hex, Vector2i(-1, -1), "Genoa has a town")
		var game := Session.game
		var seen := PeopleView.at(game, &"GEN", hex)
		_fill(game, &"GEN", hex, _view(game, &"GEN", hex))
		assert_true(_has_text(LAND.HEAD_PEOPLE), "the People and food heading")
		assert_true(_has_text(Words.number(int(seen["people"]))), "the figure: " + str(seen["people"]))
		assert_true(_has_text("Room"), "the Room row on your land")
		assert_true(_has_text(Words.number(int(seen["room"]))), "the room figure")
		var outlook := PeopleView.outlook(game, hex)
		assert_false(outlook.is_empty(), "your town has an outlook")
		assert_true(_has_text(str(outlook["text"])), "the outlook text is the view's")


	func test_a_known_countrys_land_shows_an_exact_figure_and_no_room_or_outlook() -> void:
		_gen_start()
		var game := Session.game
		var hex := Vector2i(-1, -1)
		for i: int in Territory.districts(game, Countries.by_tag(game, &"MLO").id):
			var cand := game.map.hex_of(i)
			var text := str(PeopleView.at(game, &"GEN", cand).get("text", ""))
			if text != "" and text != "none":
				hex = cand
				break
		assert_ne(hex, Vector2i(-1, -1), "Milan has land with people")
		_fill(game, &"GEN", hex, _view(game, &"GEN", hex))
		var seen := PeopleView.at(game, &"GEN", hex)
		assert_true(_has_text(str(seen["text"])), "the exact figure: " + str(seen["text"]))
		assert_false(str(seen["text"]).begins_with("about "), "exact, not banded")
		assert_false(_has_text("Room"), "no Room row for a known country")
		var outlook := PeopleView.outlook(game, hex)
		if not outlook.is_empty():
			assert_false(_has_text(str(outlook["text"])), "no outlook line for a known country")


	func test_unowned_land_in_a_map_only_game_shows_the_number_alone() -> void:
		var game := Session.game
		var hex := Vector2i(-1, -1)
		for i: int in game.map.hex_count():
			if game.map.land[i] == 1 and game.state.people[i] > 0:
				hex = game.map.hex_of(i)
				break
		assert_ne(hex, Vector2i(-1, -1), "a map-only game has land with people")
		_fill(game, &"", hex, _view(game, &"", hex))
		var seen := PeopleView.at(game, &"", hex)
		assert_true(_has_text(str(seen["text"])), "the number alone")
		assert_false(_has_text("Room"), "no Room row on unowned land")
		var outlook := PeopleView.outlook(game, hex)
		if not outlook.is_empty():
			assert_false(_has_text(str(outlook["text"])), "no outlook line on unowned land")


	func test_an_undiscovered_hex_has_no_land_tab_and_its_panel_names_nothing() -> void:
		_gen_start()
		var game := Session.game
		var hex := Vector2i(-1, -1)
		for i: int in game.map.hex_count():
			if game.map.land[i] == 1 and not Knowledge.discovered(game, &"GEN", game.map.hex_of(i)):
				hex = game.map.hex_of(i)
				break
		if hex == Vector2i(-1, -1):
			pass_test("every land hex is discovered on this map")
			return
		var view := _view(game, &"GEN", hex)
		assert_false(LAND.applies(view), "the Land tab does not apply on an undiscovered hex")


	func test_made_rows_show_loads_and_value_on_own_land_and_a_dash_elsewhere() -> void:
		var made := [{"good": 0, "name": "GRAIN", "loads": 14, "value": 42}]
		var land := _land_base()
		land["made"] = made
		_fill(Session.game, &"GEN", Vector2i(1, 1), _fake_view("own", land))
		assert_true(_has_text("Grain"), "the good's name")
		assert_true(_has_text("14 loads"), "the loads")
		assert_true(_has_text("+42"), "the value at the price on own land")
		_fill(Session.game, &"GEN", Vector2i(1, 1), _fake_view("foreign", land))
		assert_false(_has_text("+42"), "no value on foreign land")
		# Mockup v4 (issue 436): elsewhere the loads stand in the value's place ("Wool  10 loads"), no dash.
		assert_true(_has_text("14 loads"), "the loads as the value")


	func test_out_of_sight_line_only_on_foreign_land_out_of_sight() -> void:
		var land := _land_base()
		land["armies_hidden"] = true
		_fill(Session.game, &"GEN", Vector2i(1, 1), _fake_view("foreign", land))
		assert_true(_has_text(LAND.OUT_OF_SIGHT), "the out-of-sight line")
		land["armies_hidden"] = false
		_fill(Session.game, &"GEN", Vector2i(1, 1), _fake_view("foreign", land))
		assert_false(_has_text(LAND.OUT_OF_SIGHT), "no line when armies are in sight")


	func test_the_battle_row_asks_open_battle_with_its_record() -> void:
		var land := _land_base()
		land["battle"] = {"record": 4, "name": "Battle of Pavia, Spring 1481"}
		_fill(Session.game, &"GEN", Vector2i(1, 1), _fake_view("foreign", land))
		assert_true(_has_text("Battle of Pavia, Spring 1481"), "the battle's name")
		var button := _button(LAND.BATTLE_BUTTON)
		assert_not_null(button, "an Open the battle button")
		button.pressed.emit()
		assert_eq(_requests.size(), 1, "one request")
		assert_eq(_requests[0][0], &"open_battle", "the request is open_battle")
		assert_eq((_requests[0][1] as Dictionary)["record"], 4, "with the record")


	func test_supply_and_castle_buttons_only_ask_and_show_when_the_view_says() -> void:
		var land := _land_base()
		land["supply"] = true
		land["castle_area"] = true
		_fill(Session.game, &"GEN", Vector2i(1, 1), _fake_view("own", land))
		_button(LAND.SUPPLY_BUTTON).pressed.emit()
		_button(LAND.CASTLE_BUTTON).pressed.emit()
		assert_eq(_requests[0][0], &"map_mode", "the supply request")
		assert_eq(_requests[1][0], &"castle_area", "the castle request")
		_fill(Session.game, &"GEN", Vector2i(1, 1), _fake_view("own", _land_base()))
		assert_null(_button(LAND.SUPPLY_BUTTON), "no supply button without supply")
		assert_null(_button(LAND.CASTLE_BUTTON), "no castle button without a castle")


	func test_sea_shows_its_rows_and_no_people_section() -> void:
		var land := _land_base()
		land["sea_rows"] = [["Winter", "mild"], ["Coasts", "north"]]
		_fill(Session.game, &"GEN", Vector2i(1, 1), _fake_view("sea", land))
		assert_true(_has_text("Winter"), "the Winter row")
		assert_true(_has_text("north"), "the coast row's value")
		assert_false(_has_text(LAND.HEAD_PEOPLE), "no People section at sea")


	func test_sandbox_shows_food_made_and_eaten() -> void:
		var land := _land_base()
		land["food"] = {"made": 5, "eaten": 3}
		land["people"] = {"shown": true, "text": "2,000", "people": 2000, "change": 0, "room": 0}
		_fill(Session.game, &"", Vector2i(1, 1), _fake_view("sandbox", land))
		assert_true(_has_text("+2"), "the net food")
		assert_true(_has_text("makes 5, eats 3"), "the food line")
		assert_true(_has_text("2,000"), "the people figure")


	func test_foreign_land_has_no_write_controls() -> void:
		var land := _land_base()
		land["people"] = {"shown": true, "text": "about 9,800", "people": 9800, "change": 0, "room": 0}
		land["buildings"] = [{"name": "Weaver", "state_text": "working"}]
		land["war_rows"] = [["Held by", "plain", "Duchy of Milan"]]
		_fill(Session.game, &"MLO", Vector2i(1, 1), _fake_view("foreign", land))
		assert_true(_has_text("Weaver"), "the foreign building shows")
		assert_true(_has_text("Duchy of Milan"), "the holder shows")
		for button: Button in _buttons():
			assert_false(button.text.begins_with("Build") or button.text.begins_with("Raise"), "no build or raise: " + button.text)
		assert_null(_button(LAND.BATTLE_BUTTON), "no battle button without a battle")


	func test_a_light_fog_hex_shows_exact_land_and_no_armies() -> void:
		var game := FogFixture.duel_thin()
		game.player = AiFixture.MILAN
		Session.start_game(game)
		var hex := Vector2i(-1, -1)
		for i: int in game.map.hex_count():
			var cand := game.map.hex_of(i)
			var owner := Territory.owner_tag(game, cand)
			if game.map.is_land(cand) and Knowledge.discovered(game, game.player, cand) \
					and not Knowledge.sees(game, game.player, cand) and owner != &"" and owner != game.player:
				hex = cand
				break
		assert_ne(hex, Vector2i(-1, -1), "the thin duel has a light-fog hex with an owner")
		_fill(game, game.player, hex, _view(game, game.player, hex))
		assert_true(_has_text(LAND.OUT_OF_SIGHT), "the out-of-sight line in light fog")
		assert_true(_has_text(LAND.HEAD_PEOPLE), "the People section shows in light fog (the figure is exact)")


	func test_the_tab_writes_nothing_to_the_game() -> void:
		var text := FileAccess.get_file_as_string(TAB_PATH)
		assert_ne(text, "", "the tab file reads")
		var forbidden := ["Session.", "Events.", "game.state", "game.player", ".act(", ".tag =", "Armies.", "Occupation.",
			"Sight.", "Color(", "Color.", "game.map.land[", "Engine."]
		for token: String in forbidden:
			assert_false(text.contains(token), "the Land tab never uses: " + token)
		assert_false(text.contains("Session"), "the Land tab reads no session")


	# --- cases folded in from test_hex_panel_people.gd (TW16): the outlook in its tone -----------------------------------------


	## The Land tab's outlook line (the label that starts with `start`), or null.
	func _outlook_label(start: String) -> Label:
		var found: Label = null
		for node: Node in _tab.find_children("*", "Label", true, false):
			if (node as Label).text.begins_with(start):
				found = node as Label
		return found


	func test_each_outlook_tone_has_its_theme_variation() -> void:
		assert_eq(LAND._tone_variation(&"good"), &"NumberGood")
		assert_eq(LAND._tone_variation(&"bad"), &"NumberBad")
		assert_eq(LAND._tone_variation(&"warn"), &"NumberWarn")
		assert_eq(LAND._tone_variation(&"plain"), &"TileText", "plain is the window's 15 px body text (issue 436, mockup v4)")


	func test_the_outlook_line_is_in_the_views_tone() -> void:
		_gen_start()
		var hex := _hex_of_country(&"GEN", true)
		var game := Session.game
		var outlook := PeopleView.outlook(game, hex)
		assert_false(outlook.is_empty(), "your town has an outlook")
		_fill(game, &"GEN", hex, _view(game, &"GEN", hex))
		var line := _outlook_label(str(outlook["text"]))
		assert_not_null(line, "the outlook line shows")
		assert_eq(line.theme_type_variation, LAND._tone_variation(StringName(str(outlook["tone"]))), "in its tone")


	func test_a_hungry_town_gives_a_bad_outlook() -> void:
		_gen_start()
		var hex := _hex_of_country(&"GEN", true)
		Countries.by_tag(Session.game, &"GEN").food_fed = 0
		_fill(Session.game, &"GEN", hex, _view(Session.game, &"GEN", hex))
		var line := _outlook_label("Hungry")
		assert_not_null(line, "the hunger line shows")
		assert_eq(line.theme_type_variation, &"NumberBad", "hunger is bad")


	func test_a_countryside_over_its_room_is_crowded_and_warn() -> void:
		_gen_start()
		var hex := _hex_of_country(&"GEN", false)
		assert_ne(hex, Vector2i(-1, -1), "Genoa has countryside")
		var room := int(PeopleView.at(Session.game, &"GEN", hex)["room"])
		assert_true(Session.dev_people(hex, room + 500), "the people go over the room")
		_fill(Session.game, &"GEN", hex, _view(Session.game, &"GEN", hex))
		var line := _outlook_label("Crowded")
		assert_not_null(line, "the crowding line shows")
		assert_eq(line.theme_type_variation, &"NumberWarn", "crowding is a warning")


	func test_a_countryside_with_room_left_is_plain() -> void:
		_gen_start()
		var hex := _hex_of_country(&"GEN", false)
		assert_true(Session.dev_people(hex, 0), "an empty countryside hex")
		_fill(Session.game, &"GEN", hex, _view(Session.game, &"GEN", hex))
		var line := _outlook_label("Room for")
		assert_not_null(line, "the room line shows")
		assert_eq(line.theme_type_variation, &"TileText", "room left is plain (the window's body text)")


	func test_a_town_that_can_grow_gives_a_good_outlook() -> void:
		_gen_start()
		var game := Session.game
		var c := Countries.by_tag(game, &"GEN")
		var hex := Vector2i(-1, -1)
		var said := PackedStringArray()
		for i: int in Territory.districts(game, c.id):
			if int(game.state.main_use[i]) != People.SETTLEMENTS:
				continue
			# Genoa's towns start at or above the top growing level: a hamlet (level 1) is set up for the test.
			game.state.level[i] = 1
			var here := game.map.hex_of(i)
			Session.dev_people(here, int(PeopleView.at(game, &"GEN", here)["room"]))
			var o := PeopleView.outlook(game, here)
			said.append("%s/%s" % [str(o.get("tone", "")), str(o.get("text", ""))])
			if str(o.get("tone", "")) == "good":
				hex = here
				break
		assert_ne(hex, Vector2i(-1, -1), "a Genoese town can grow into the next level; said: " + " | ".join(said))
		_fill(game, &"GEN", hex, _view(game, &"GEN", hex))
		var line := _outlook_label(str(PeopleView.outlook(game, hex)["text"]))
		assert_not_null(line)
		assert_eq(line.theme_type_variation, &"NumberGood", "growth is good")


## The Town tab itself (issue 436, the owner's decision of 2026-11-25): Land and Buildings in one tab. Its registry facts, when
## it shows, never dimmed, the strips on top where building is offered and the facts under them, the facts alone on foreign land,
## and the strips' accessors answered through the tab (the window, the App and the keys use them).
class TestTownTab:
	extends GutTest

	const TOWN := "res://shell/panels/tile_tabs/town_tab.gd"

	var _tab: TownTab = null

	func before_each() -> void:
		Bindings.ensure()
		Session.new_scenario("north_italy_1480", 1480)
		assert_true(bool(Session.act("choose_country", {"tag": "GEN"})["ok"]))

	func after_each() -> void:
		if _tab != null and is_instance_valid(_tab):
			_tab.queue_free()
		_tab = null
		await get_tree().process_frame

	func _hex_where(pred: Callable) -> Vector2i:
		var game := Session.game
		for i: int in game.map.hex_count():
			var hex := game.map.hex_of(i)
			if bool(pred.call(TileView.of(game, &"GEN", hex))):
				return hex
		return HexPanelContract.NO_HEX

	func _town_on(hex: Vector2i) -> TownTab:
		_tab = (load(TOWN) as GDScript).new() as TownTab
		_tab.theme = KitTheme.load_for(1.0)
		add_child_autofree(_tab)
		_tab.fill(Session.game, &"GEN", hex, TileView.of(Session.game, &"GEN", hex))
		return _tab

	func test_the_tab_is_town_with_order_10_and_the_registry_lists_it() -> void:
		var script := load(TOWN) as GDScript
		assert_eq(script.get_script_constant_map()["ID"], &"town")
		assert_eq(script.get_script_constant_map()["LABEL"], "Town")
		assert_eq(script.get_script_constant_map()["ORDER"], 10)
		var ids: Array[StringName] = []
		for tab: GDScript in TileTabs.all():
			ids.append(TileTabs.id_of(tab))
		assert_true(ids.has(&"town"), "the registry lists the Town tab")
		assert_false(ids.has(&"land") or ids.has(&"buildings"), "Land and Buildings are no tabs of their own any more")
		assert_eq(TileTabs.check(TileTabs.all()).size(), 0, "the registry's tabs pass its check")

	func test_it_shows_on_land_and_sea_never_unexplored_and_is_never_dimmed() -> void:
		for case_id: String in ["own", "foreign", "unowned", "sandbox", "sea"]:
			assert_true(TownTab.applies({"case": case_id}), "shown on %s" % case_id)
			assert_eq(TownTab.dimmed({"case": case_id, "build": {"offered": false, "reason": "Not your land"}}), "",
					"never dimmed on %s" % case_id)
		assert_false(TownTab.applies({"case": "unexplored"}), "not on an undiscovered hex")

	func test_own_land_has_the_strips_on_top_and_the_facts_under_them() -> void:
		var hex := _hex_where(func(v: Dictionary) -> bool: return str(v.get("case", "")) == "own" and TownTab.buildable(v))
		assert_ne(hex, HexPanelContract.NO_HEX, "Genoa has land to build on")
		var tab := _town_on(hex)
		assert_not_null(tab.strips(), "the strips show where building is offered")
		assert_not_null(tab.facts(), "the facts show under them")
		assert_lt(tab.strips().get_index(), tab.facts().get_index(), "strips first, then the facts")
		assert_false(tab.row_nodes().is_empty(), "the tab answers the strips' tiles")
		tab.finish_now()
		assert_true(tab.is_done(), "finish_now fills the strips' gains through the tab")
		assert_string_starts_with(tab.summary_text(), "Buildings here make ")

	func test_foreign_land_has_the_facts_alone() -> void:
		var hex := _hex_where(func(v: Dictionary) -> bool: return str(v.get("case", "")) == "foreign")
		if hex == HexPanelContract.NO_HEX:
			pending("no foreign land in sight of Genoa")
			return
		var tab := _town_on(hex)
		assert_null(tab.strips(), "no strips where nothing can be built")
		assert_not_null(tab.facts(), "the exact facts")
		assert_true(tab.row_nodes().is_empty(), "no tiles")
		assert_true(tab.is_done(), "nothing to fill")

	func test_the_parts_requests_reach_the_tab() -> void:
		var hex := _hex_where(func(v: Dictionary) -> bool: return str(v.get("case", "")) == "own" and TownTab.buildable(v))
		var tab := _town_on(hex)
		var seen: Array = []
		tab.app_requested.connect(func(what: StringName, _args: Dictionary) -> void: seen.append(what))
		tab.works_requested.connect(func(request: Dictionary) -> void: seen.append(request["what"]))
		tab.facts().app_requested.emit(&"map_mode", {"mode": &"supply"})
		tab.strips().works_requested.emit({"what": &"begin_work", "args": {}})
		assert_eq(seen, [&"map_mode", &"begin_work"], "each part's request comes out of the Town tab once")
