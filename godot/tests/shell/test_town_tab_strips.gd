## The building strips of the Town tab (issue 436): the cases of test_buildings_tab.gd unchanged, as a GUT inner class that tests
## the part (building_strips.gd, the old Buildings tab renamed so the registry no longer lists it). See test_town_tab.gd.
extends GutTest


## (from test_buildings_tab.gd)
class TestBuildingStrips:
	extends GutTest

	## The Buildings tab of the tile window (tile-window spec R19, R20, D8, D14; build plan TW11). The works cases of
	## test_hex_panel.gd (the rows, the confirm modes, the reasons, the card on hover, the begin without a listener moved to the App)
	## are here as the tab's own; the search, the filter, the gain fill (finish_now) and the summary are new.

	const TAB := "res://shell/panels/tile_tabs/building_strips.gd"
	const SEARCH_LIMIT := 400

	var _tab: TileTab = null
	var _log: Array = []


	func before_each() -> void:
		Bindings.ensure()
		Session.new_scenario("north_italy_1480", 1480)
		assert_true(bool(Session.act("choose_country", {"tag": "GEN"})["ok"]))
		_log = []


	func after_each() -> void:
		if _tab != null and is_instance_valid(_tab):
			_tab.queue_free()
		_tab = null
		await get_tree().process_frame


	func _buildable_for(tag: StringName) -> Dictionary:
		var game := Session.game
		for i: int in game.map.hex_count():
			var hex := game.map.hex_of(i)
			if game.map.land[i] != 1 or not Improve.piece_at(game, hex).is_empty():
				continue
			if tag != &"" and Territory.owner_tag(game, hex) != tag:
				continue
			for option: Dictionary in Improve.build_options(game, hex):
				var args := {"hex": hex, "family": int(option["family_id"])}
				if tag != &"":
					args["tag"] = tag
				if bool(Session.check("build", args)["ok"]):
					return args
		return {}


	func _tab_on(hex: Vector2i) -> TileTab:
		var script := load(TAB) as GDScript
		var tab := script.new() as TileTab
		add_child_autofree(tab)
		tab.works_requested.connect(func(request: Dictionary) -> void: _log.append(request))
		var view := TileView.of(Session.game, &"GEN", hex)
		tab.fill(Session.game, &"GEN", hex, view)
		_tab = tab
		return tab


	func _rows_of(tab: TileTab) -> Dictionary:
		return tab.call("row_nodes") as Dictionary


	func _set_mode(mode: String) -> Settings:
		var s := Settings.new("macOS", false)
		assert_true(s.set_value("game/confirm_works", mode), "the mode is a valid choice: " + mode)
		return s


	# --- the registry facts ---------------------------------------------------------------------------------------------------


	func test_the_tab_has_its_id_label_and_order_20() -> void:
		var script := load(TAB) as GDScript
		assert_eq(script.get_script_constant_map()["ID"], &"buildings")
		assert_eq(script.get_script_constant_map()["ORDER"], 20)
		assert_eq(script.get_script_constant_map()["LABEL"], "Buildings")


	func test_it_applies_on_land_and_not_on_sea_or_unexplored() -> void:
		var script := load(TAB) as GDScript
		assert_true(script.call("applies", {"case": "own"}))
		assert_true(script.call("applies", {"case": "foreign"}))
		assert_true(script.call("applies", {"case": "sandbox"}))
		assert_false(script.call("applies", {"case": "sea"}))
		assert_false(script.call("applies", {"case": "unexplored"}))


	func test_it_is_dimmed_with_the_home_reason_off_offered_land() -> void:
		var script := load(TAB) as GDScript
		assert_eq(script.call("dimmed", {"build": {"offered": true, "reason": ""}}), "", "live where offered")
		assert_eq(script.call("dimmed", {"build": {"offered": false, "reason": "Not your land: the Duchy of Milan holds it"}}),
				"Not your land: the Duchy of Milan holds it")


	# --- the rows and the gains -------------------------------------------------------------------------------------------------


	func test_an_own_hex_lists_its_rows_and_the_summary_fills_one_row_a_frame() -> void:
		var args := _buildable_for(&"GEN")
		assert_false(args.is_empty(), "Genoa has a buildable hex")
		var tab := _tab_on(args["hex"])
		assert_false(_rows_of(tab).is_empty(), "the rows are listed at once")
		assert_false(tab.call("is_done"), "the gains are not filled yet")
		assert_eq(tab.call("summary_text"), "Working out the year's gains")
		var before := int(tab.call("pending"))
		assert_gte(before, 1, "a row waits for its gain")
		await get_tree().process_frame
		assert_eq(int(tab.call("pending")), maxi(before - 1, 0), "one row a frame")
		tab.call("finish_now")
		assert_true(bool(tab.call("is_done")), "finish_now fills every row")
		assert_string_starts_with(str(tab.call("summary_text")), "Buildings here make ")


	func test_each_gain_equals_the_card_and_the_summary_is_the_sum_of_the_built_rows() -> void:
		var args := _buildable_for(&"GEN")
		var hex: Vector2i = args["hex"]
		var tab := _tab_on(hex)
		tab.call("finish_now")
		var full := TileBuildings.of(Session.game, &"GEN", hex, true)
		var make := 0
		var upkeep := 0
		for group: Dictionary in full["groups"]:
			for row: Dictionary in group["rows"]:
				var id := StringName(str(row["id"]))
				var node := _rows_of(tab).get(id) as BuildingRow
				if node == null:
					fail_test("no row node for %s" % id)
					continue
				var shown := node.gain_text()
				var want := "" if row["gain"] == null else Words.signed(int(row["gain"]))
				assert_eq(shown, want, "the gain of %s equals the card's" % id)
				if row["state"] == &"built":
					make += int(row["gain"] if row["gain"] != null else 0)
					upkeep += int(row["upkeep"] if row["upkeep"] != null else 0)
		assert_eq(full["summary"]["make"], make, "the full model's summary is the sum of its built gains")
		assert_eq(full["summary"]["upkeep"], upkeep)
		assert_true(str(tab.call("summary_text")).contains("make %s a year" % Words.signed(make)), "the summary line shows the sum")


	func test_the_filter_keeps_the_ready_rows_only_and_the_search_matches_names() -> void:
		var args := _buildable_for(&"GEN")
		var tab := _tab_on(args["hex"])
		tab.call("set_filter", &"ready")
		for id: StringName in tab.call("visible_ids"):
			assert_eq(str((tab.call("row_data", id) as Dictionary)["state"]), "ready", "only buildable rows pass Can build")
		tab.call("set_filter", &"all")
		tab.call("set_query", "zzz-no-such-building")
		assert_eq((tab.call("visible_ids") as Array).size(), 0, "a search that matches nothing hides every row")
		tab.call("set_query", "")
		assert_eq((tab.call("visible_ids") as Array).size(), _rows_of(tab).size(), "an empty search shows all rows")


	func test_the_built_filter_shows_only_standing_pieces() -> void:
		var args := _buildable_for(&"GEN")
		var hex: Vector2i = args["hex"]
		Session.act("build", args)
		for _n: int in 40:
			if Session.game.state.work_at(hex) == null:
				break
			Session.end_season()
		var tab := _tab_on(hex)
		tab.call("set_filter", &"built")
		for id: StringName in tab.call("visible_ids"):
			assert_eq(str((tab.call("row_data", id) as Dictionary)["state"]), "built")


	# --- the hammer and the works rule ------------------------------------------------------------------------------------------


	func test_confirm_off_asks_for_the_work_and_does_not_begin_it() -> void:
		var args := _buildable_for(&"GEN")
		var hex: Vector2i = args["hex"]
		var tab := _tab_on(hex)
		tab.set("settings", _set_mode("off"))
		tab.call("begin_option", {"action": Works.BUILD, "family": int(args["family"])}, true)
		assert_eq(_log[-1]["what"], &"begin_work", "off: the click asks for the work at once")
		assert_eq(_log[-1]["args"]["hex"], hex)
		assert_eq(_log[-1]["args"]["option"], {"action": Works.BUILD, "family": int(args["family"])})
		assert_null(Session.game.state.work_at(hex), "the tab did not begin it itself: the App does")


	func test_confirm_always_opens_the_card_for_every_row() -> void:
		var args := _buildable_for(&"GEN")
		var tab := _tab_on(args["hex"])
		tab.set("settings", _set_mode("always"))
		var node := _first_ready(tab)
		node.press_hammer()
		assert_eq(_log[-1]["what"], &"works_card", "always: a click asks for the card")
		var option := _log[-1]["args"]["option"] as Dictionary
		assert_eq(option.keys().size(), 2, "the option is action and family")


	func test_confirm_expensive_begins_a_cheap_row_and_cards_an_expensive_one() -> void:
		var args := _buildable_for(&"GEN")
		var tab := _tab_on(args["hex"])
		tab.set("settings", _set_mode("expensive"))
		tab.call("begin_option", {"action": Works.BUILD, "family": 1}, false)
		assert_eq(_log[-1]["what"], &"begin_work", "a cheap row begins the work")
		tab.call("begin_option", {"action": Works.BUILD, "family": 1}, true)
		assert_eq(_log[-1]["what"], &"works_card", "an expensive row asks for the card")


	func test_the_default_confirm_mode_is_expensive_without_settings() -> void:
		var args := _buildable_for(&"GEN")
		var tab := _tab_on(args["hex"])
		tab.call("begin_option", {"action": Works.BUILD, "family": 1}, false)
		assert_eq(_log[-1]["what"], &"begin_work", "no settings: a cheap row begins the work")


	func test_a_refused_row_has_a_disabled_hammer_and_no_request() -> void:
		var args := _buildable_for(&"GEN")
		var tab := _tab_on(args["hex"])
		var refused := ""
		for id: StringName in _rows_of(tab):
			var data := tab.call("row_data", id) as Dictionary
			if str(data["state"]) != "ready" and not (data["option"] as Dictionary).is_empty():
				refused = str(id)
				break
		if refused == "":
			pending("every row of this hex is buildable; nothing refused to check")
			return
		var node := _rows_of(tab)[StringName(refused)] as BuildingRow
		assert_true(node.hammer().disabled, "a refused hammer is disabled")
		node.press_hammer()
		assert_eq(_log.size(), 0, "a disabled hammer sends nothing")


	func test_under_way_every_hammer_is_greyed_with_the_busy_tip() -> void:
		var args := _buildable_for(&"GEN")
		var hex: Vector2i = args["hex"]
		assert_true(bool(Session.act("build", args)["ok"]), "the build is accepted")
		var tab := _tab_on(hex)
		var busy := false
		for id: StringName in _rows_of(tab):
			var node := _rows_of(tab)[id] as BuildingRow
			if node.hammer().visible:
				assert_true(node.hammer().disabled, "every hammer is greyed while a work is under way")
				busy = true
		assert_true(busy, "the other rows are still listed")


	func test_row_hover_emits_the_card_of_the_row() -> void:
		var args := _buildable_for(&"GEN")
		var hex: Vector2i = args["hex"]
		var tab := _tab_on(hex)
		var cards: Array = []
		tab.row_hovered.connect(func(card: Dictionary, _anchor: Rect2) -> void: cards.append(card))
		var node := _first_ready(tab)
		node.hovered.emit(node.data())
		assert_eq(cards.size(), 1, "the hover emits row_hovered once")
		var option := node.data()["option"] as Dictionary
		assert_eq(cards[0], BuildingCard.of(Session.game, &"GEN", hex, option), "the card is BuildingCard's")


	func test_a_foreign_hex_shows_the_reason_and_no_rows() -> void:
		var foreign := _foreign_hex()
		if foreign == Vector2i(-1, -1):
			pending("no foreign land on this map")
			return
		var tab := _tab_on(foreign)
		assert_eq(_rows_of(tab).size(), 0, "no rows on foreign land")


	func _first_ready(tab: TileTab) -> BuildingRow:
		for id: StringName in _rows_of(tab):
			var node := _rows_of(tab)[id] as BuildingRow
			if not node.hammer().disabled and node.hammer().visible:
				return node
		fail_test("no enabled hammer")
		return null


	func _foreign_hex() -> Vector2i:
		var game := Session.game
		for i: int in game.map.hex_count():
			var hex := game.map.hex_of(i)
			if game.map.land[i] == 1 and Territory.owner_tag(game, hex) not in [&"", &"GEN"]:
				return hex
		return Vector2i(-1, -1)


	# --- cases folded in from test_hex_panel.gd (TW16) --------------------------------------------------------------------------


	## The App's answer to the tab's begin_work request (WorksFlow.begin): the work of the row through Session.
	func _answer_as_the_app(tab: TileTab) -> void:
		tab.set("settings", _set_mode("off"))  # no card in the way: a hammer begins its work
		tab.works_requested.connect(func(request: Dictionary) -> void:
			if request["what"] != &"begin_work":
				return
			var option: Dictionary = request["args"]["option"]
			var args := {"hex": request["args"]["hex"]}
			if str(option["action"]) == String(Works.BUILD):
				args["family"] = int(option["family"])
			Session.act(str(option["action"]), args)
		)


	func _row_of_action(tab: TileTab, action: StringName) -> BuildingRow:
		for id: StringName in _rows_of(tab):
			var node := _rows_of(tab)[id] as BuildingRow
			var option: Dictionary = node.data().get("option", {})
			if not option.is_empty() and StringName(str(option["action"])) == action:
				return node
		return null


	func _stand(hex: Vector2i) -> void:
		var n := 0
		while Session.game.state.work_at(hex) != null and n < 40:
			Session.end_season()
			n += 1
		assert_null(Session.game.state.work_at(hex), "the work finished")


	## Was test_build_then_upgrade_then_clear_go_through_session: the hammers of the rows build, upgrade and clear one piece, each
	## through the App's begin_work answer and Session.act.
	func test_the_hammers_build_then_upgrade_then_clear_through_session() -> void:
		var args := _buildable_for(&"GEN")
		var hex: Vector2i = args["hex"]
		var tab := _tab_on(hex)
		_answer_as_the_app(tab)
		_first_ready(tab).press_hammer()
		assert_not_null(Session.game.state.work_at(hex), "the hammer began a work (Build only begins)")
		assert_true(Improve.piece_at(Session.game, hex).is_empty(), "nothing stands yet")
		_stand(hex)
		assert_false(Improve.piece_at(Session.game, hex).is_empty(), "the work put a piece on the hex")
		tab = _tab_on(hex)
		_answer_as_the_app(tab)
		var up := _row_of_action(tab, Works.UPGRADE)
		if up != null and not up.hammer().disabled:
			var level_before := Session.game.state.level[Session.game.map.index_of(hex)]
			up.press_hammer()
			_stand(hex)
			assert_eq(Session.game.state.level[Session.game.map.index_of(hex)], level_before + 1, "Upgrade raised the level by one")
			tab = _tab_on(hex)
			_answer_as_the_app(tab)
		var down := _row_of_action(tab, Works.CLEAR)
		assert_not_null(down, "a piece has a Clear row")
		assert_false(down.hammer().disabled, "Clear can be pressed here")
		down.press_hammer()
		_stand(hex)
		assert_true(Improve.piece_at(Session.game, hex).is_empty(), "Clear took the piece away")


	## Was test_confirm_expensive_opens_the_card_for_a_row_a_poor_treasury_makes_expensive: the verdict, the request name and the
	## confirm mode are asserted on a real row.
	func test_a_poor_treasury_makes_an_affordable_row_expensive_so_expensive_mode_asks_for_the_card() -> void:
		var args := _buildable_for(&"GEN")
		var hex: Vector2i = args["hex"]
		assert_true(Session.dev_money(&"GEN", -540), "70 ducats are left")
		var tab := _tab_on(hex)
		tab.set("settings", _set_mode("expensive"))
		var dear: BuildingRow = null
		for id: StringName in _rows_of(tab):
			var node := _rows_of(tab)[id] as BuildingRow
			if not node.hammer().disabled and bool(node.data().get("expensive", false)):
				dear = node
				break
		assert_not_null(dear, "an enabled expensive row at this hex")
		var option := dear.data()["option"] as Dictionary
		dear.press_hammer()
		assert_eq(_log.size(), 1, "one request for the expensive row")
		assert_eq(_log[-1]["what"], &"works_card", "an expensive row opens the card first")
		assert_eq(str((_log[-1]["args"]["option"] as Dictionary)["action"]), str(option["action"]), "the card of the row's own option")
		assert_null(Session.game.state.work_at(hex), "nothing begun by the click")
		assert_true(Session.dev_money(&"GEN", 540))
		tab = _tab_on(hex)
		tab.set("settings", _set_mode("expensive"))
		var cheap := _first_ready(tab)
		assert_false(bool(cheap.data().get("expensive", false)), "with 610 ducats the row is not expensive")
		cheap.press_hammer()
		assert_eq(_log[-1]["what"], &"begin_work", "and a click on it begins the work")


	## Was test_a_full_slot_gives_its_reason_on_the_build_buttons: a hex the slots refuse says so on its rows.
	func test_a_full_slot_gives_its_reason_on_the_rows() -> void:
		var slots := WorksView.slots(Session.game, &"GEN")
		var taken: Array[Vector2i] = []
		for n: int in int(slots["total"]):
			var args := _buildable_for(&"GEN")
			for hex: Vector2i in taken:
				if args.get("hex", Vector2i(-2, -2)) == hex:
					args = {}
			assert_false(args.is_empty(), "Genoa can start work %d" % (n + 1))
			assert_true(bool(Session.act("build", args)["ok"]), "work %d is accepted" % (n + 1))
			taken.append(args["hex"])
		var blocked := Vector2i(-1, -1)
		for i: int in Session.game.map.hex_count():
			var here := Session.game.map.hex_of(i)
			if Session.game.map.land[i] != 1 or taken.has(here) or not Improve.piece_at(Session.game, here).is_empty():
				continue
			if Territory.owner_tag(Session.game, here) != &"GEN":
				continue
			for option: Dictionary in Improve.build_options(Session.game, here):
				var check := Session.check("build", {"hex": here, "family": int(option["family_id"])})
				if str(check["reason"]).begins_with("no free work slot"):
					blocked = here
					break
			if blocked != Vector2i(-1, -1):
				break
		assert_ne(blocked, Vector2i(-1, -1), "a further build is refused by the slots")
		var tab := _tab_on(blocked)
		var found := 0
		for id: StringName in _rows_of(tab):
			var node := _rows_of(tab)[id] as BuildingRow
			if node.hammer() != null and node.hammer().disabled and str(node.data().get("reason", "")).contains("work slot"):
				found += 1
		assert_gt(found, 0, "a row shows the full slots' reason")
