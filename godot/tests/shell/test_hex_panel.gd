## Studiolo inspected-hex side panel tests (docs/architecture/m1-build-spec.md section 11, T14;
## docs/architecture/ui-style-and-feedback-plan.md H1; m4-build-spec 6.4 for the rows, confirm and cancel).
extends GutTest

const PANEL := "res://shell/panels/hex_panel.tscn"
const SEARCH_LIMIT := 400

var _panel: HexPanel = null


func before_each() -> void:
	Bindings.ensure()
	Session.new_game(MapScene.MAP_ID, MapScene.START_SEED)
	_panel = (load(PANEL) as PackedScene).instantiate() as HexPanel
	_panel.theme = KitTheme.load_for(1.0)
	add_child_autofree(_panel)
	Events.hex_changed.connect(_on_hex_changed)


func after_each() -> void:
	if Events.hex_changed.is_connected(_on_hex_changed):
		Events.hex_changed.disconnect(_on_hex_changed)
	await get_tree().process_frame


func _on_hex_changed(_hex: Vector2i) -> void:
	_panel.refresh()


func _wild_land_with_options(limit: int) -> Array[Vector2i]:
	var game := Session.game
	var out: Array[Vector2i] = []
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if game.map.land[i] == 1 and Improve.piece_at(game, hex).is_empty() and not Improve.build_options(game, hex).is_empty():
			out.append(hex)
			if out.size() >= limit:
				break
	return out


## Ends seasons until the work on the hex has finished (a build, an upgrade or a clearing takes seasons since M3).
func _stand(hex: Vector2i) -> void:
	var n := 0
	while Session.game.state.work_at(hex) != null and n < 40:
		Session.end_season()
		n += 1
	await _settle()


## Waits for the panel's coalesced refresh (it runs at the end of the frame, after the signals of a press).
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _press(prefix: String) -> void:
	for button: Button in _panel.action_buttons():
		if not button.disabled and button.text.begins_with(prefix):
			button.pressed.emit()
			await _settle()
			return
	fail_test("no enabled button starts with '%s'" % prefix)


func _button(prefix: String) -> Button:
	for button: Button in _panel.action_buttons():
		if button.text.begins_with(prefix):
			return button
	return null


func _row_value(grid_path: String, key: String) -> String:
	var kids := (_panel.get_node(grid_path) as GridContainer).get_children()
	for at: int in range(0, kids.size() - 1, 2):
		if (kids[at] as Label).text == key:
			return (kids[at + 1] as Label).text
	return ""


## The reason lines under the rows (Reason-type labels inside the actions box, at any depth).
func _reason_lines() -> Array[String]:
	var out: Array[String] = []
	_collect_reasons(_panel.get_node("Body/ActionsBox/Actions"), out)
	return out


func _collect_reasons(node: Node, out: Array[String]) -> void:
	for child: Node in node.get_children():
		if child is Label and (child as Label).theme_type_variation == &"Reason":
			out.append((child as Label).text)
		_collect_reasons(child, out)


func _delta_chips(node: Node = null) -> Array[DeltaChip]:
	var out: Array[DeltaChip] = []
	var start: Node = _panel.get_node("Body/ActionsBox/Actions") if node == null else node
	for child: Node in start.get_children():
		if child is DeltaChip:
			out.append(child as DeltaChip)
		else:
			out.append_array(_delta_chips(child))
	return out


## Records the panel's works_requested signal: each entry is [what, args].
func _record_requests() -> Array:
	var log: Array = []
	_panel.works_requested.connect(func(what: StringName, args: Dictionary) -> void: log.append([what, args]))
	return log


func _set_mode(mode: String) -> void:
	var s := Settings.new("macOS", false)
	assert_true(s.set_value("game/confirm_works", mode), "the mode is a valid choice: " + mode)
	_panel.set_settings(s)


## A buildable hex of Genoa (the player's country in 1480), or Vector2i(-1, -1).
func _gen_buildable() -> Vector2i:
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the scenario starts")
	assert_true(bool(Session.act("choose_country", {"tag": "GEN"})["ok"]))
	var args := _buildable_for(&"GEN", [])
	if args.is_empty():
		return Vector2i(-1, -1)
	return args["hex"]


## The first row of `hex` that is enabled and whose expensive flag is `want_expensive`, as [row, button]; [] when none.
func _row_and_button(hex: Vector2i, want_expensive: bool) -> Array:
	var rows := ImprovePreview.options_of(Session.game, &"GEN", hex)
	var buttons := _panel.action_buttons()
	assert_eq(buttons.size(), rows.size(), "one button per row")
	for at: int in mini(rows.size(), buttons.size()):
		var row: Dictionary = rows[at]
		if bool((row["verdict"] as Dictionary)["ok"]) and bool(row["expensive"]) == want_expensive:
			return [row, buttons[at]]
	return []


func test_it_is_hidden_until_a_hex_is_shown_and_stops_the_mouse_with_studiolo_frame() -> void:
	assert_false(_panel.visible, "hidden at the start")
	assert_eq(_panel.shown_hex(), HexPanelContract.NO_HEX)
	assert_eq(_panel.mouse_filter, Control.MOUSE_FILTER_STOP, "a click on the panel never reaches the map")
	assert_eq(_panel.custom_minimum_size.x, float(Tokens.PANEL_W), "width matches Tokens.PANEL_W")
	assert_eq((_panel.get_node("Body/PieceBox/Heading") as Label).theme_type_variation, &"SectionHead")
	assert_eq((_panel.get_node("Body/GroundBox/Heading") as Label).theme_type_variation, &"SectionHead")
	assert_eq((_panel.get_node("Body/ActionsBox/Heading") as Label).theme_type_variation, &"SectionHead")

	var hex := _wild_land_with_options(1)[0]
	_panel.show_hex(hex)
	assert_true(_panel.visible)
	assert_eq(_panel.shown_hex(), hex)
	assert_eq(_panel.cartouche().theme_type_variation, &"PanelCartouche")
	assert_eq(_panel.cartouche().label().theme_type_variation, &"TitlePanel")
	for button: Button in _panel.action_buttons():
		assert_true(button is KitButton, "actions use Studiolo KitButton")
		assert_eq(button.focus_mode, Control.FOCUS_ALL, "the rows take keyboard focus")
	_panel.clear()
	assert_false(_panel.visible, "clear hides it")
	assert_eq(_panel.shown_hex(), HexPanelContract.NO_HEX)


func test_a_wild_hex_shows_its_ground_and_lists_its_builds() -> void:
	var hex := _wild_land_with_options(1)[0]
	_panel.show_hex(hex)
	assert_eq(_panel.subtitle_label().text, "Hex %d, %d" % [hex.x, hex.y])
	assert_eq(_row_value("Body/PieceBox/Rows", "Stands on it"), "nothing (wild land)")
	assert_ne(_row_value("Body/GroundBox/Rows", "Ground"), "", "the ground is written")
	assert_ne(_row_value("Body/GroundBox/Rows", "Height"), "", "the height is written")
	var piece_rows := (_panel.get_node("Body/PieceBox/Rows") as GridContainer).get_children()
	assert_eq((piece_rows[0] as Label).theme_type_variation, &"Hint", "ledger keys use Hint")
	assert_eq((piece_rows[1] as Label).theme_type_variation, &"TableRow", "ledger values use TableRow")
	assert_true((_panel.get_node("Body/GroundBox") as VBoxContainer).visible)
	assert_eq((_panel.get_node("Body/ActionsBox/Heading") as Label).text, "Build here")
	var enabled := 0
	for button: Button in _panel.action_buttons():
		assert_true(button.text.begins_with("Build "), "every button is a build: " + button.text)
		if not button.disabled:
			enabled += 1
	assert_gt(enabled, 0, "at least one build can be pressed")


func test_a_sea_hex_shows_no_actions() -> void:
	var game := Session.game
	var sea := Vector2i(-1, -1)
	for i: int in game.map.hex_count():
		if game.map.land[i] == 0:
			sea = game.map.hex_of(i)
			break
	assert_ne(sea, Vector2i(-1, -1), "the map has a sea hex")
	_panel.show_hex(sea)
	assert_true(_panel.visible)
	assert_eq(_panel.cartouche().text, "Sea")
	assert_eq(_panel.cartouche().label().text, "SEA")
	assert_false((_panel.get_node("Body/ActionsBox") as VBoxContainer).visible)
	assert_true(_panel.action_buttons().is_empty())
	assert_false((_panel.get_node("Body/GivesRow") as HBoxContainer).visible, "a sea hex gives nothing")


func test_a_refused_button_is_disabled_and_shows_its_reason() -> void:
	var game := Session.game
	var place_hex := Vector2i(-1, -1)
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		var piece := Improve.piece_at(game, hex)
		if not piece.is_empty() and int(piece["family_id"]) == ImproveRules.SETTLEMENT and game.improvement.is_fixed(hex):
			place_hex = hex
			break
	assert_ne(place_hex, Vector2i(-1, -1), "a place of the map stands on a settlement")
	_panel.show_hex(place_hex)
	var clear_button := _button("Clear") as KitButton
	assert_not_null(clear_button, "a built hex has Clear")
	assert_eq(clear_button.kind, KitButton.Kind.DANGER)
	assert_true(clear_button.disabled, "a place is never pulled down, so Clear is refused")
	var verdict := Session.check("clear", {"hex": place_hex})
	var piece_family := int(Improve.piece_at(game, place_hex)["family_id"])
	var words := ImprovePreview.reason_words(game, place_hex, {"action": Works.CLEAR, "family": piece_family}, verdict)
	assert_ne(words, "", "the rules give a reason")
	assert_eq(clear_button.tooltip_text, words, "the reason is the tooltip")
	assert_eq(clear_button.reason_text(), words, "KitButton tracks verdict reason")
	assert_eq(clear_button.icon, clear_button.get_theme_icon(&"lock", &"Kit"), "refused KitButton shows lock icon")
	assert_true(_reason_lines().has(words), "the reason is a line under the actions")


func test_build_then_upgrade_then_clear_go_through_session() -> void:
	var done := false
	for hex: Vector2i in _wild_land_with_options(SEARCH_LIMIT):
		_panel.show_hex(hex)
		var is_wild := Improve.piece_at(Session.game, hex).is_empty()
		if not is_wild or not _has_enabled("Build"):
			continue
		await _press("Build")
		assert_true(Improve.piece_at(Session.game, hex).is_empty(), "Build only begins a work")
		assert_not_null(Session.game.state.work_at(hex), "the work is under way")
		await _stand(hex)
		assert_false(Improve.piece_at(Session.game, hex).is_empty(), "the work put a piece on the hex")
		assert_eq(_row_value("Body/PieceBox/Rows", "Level"), "level 1, " + _level_word_for(hex), "the panel shows level 1")
		if not _has_enabled("Upgrade"):
			await _press("Clear")
			await _stand(hex)
			assert_true(Improve.piece_at(Session.game, hex).is_empty(), "Clear took it away again")
			continue
		var level_before := Session.game.state.level[Session.game.map.index_of(hex)]
		await _press("Upgrade")
		await _stand(hex)
		assert_eq(Session.game.state.level[Session.game.map.index_of(hex)], level_before + 1, "Upgrade raised the level by one")
		assert_eq(_panel.shown_hex(), hex, "the panel still shows the hex")
		await _press("Clear")
		await _stand(hex)
		assert_true(Improve.piece_at(Session.game, hex).is_empty(), "Clear took the piece away")
		assert_false((_panel.get_node("Body/ActionsBox/Actions") as VBoxContainer).get_children().is_empty(), "the build list is back")
		done = true
		break
	assert_true(done, "a wild hex could be built, upgraded and cleared")


func _reason_text_of(box: VBoxContainer) -> String:
	for child: Node in box.get_children():
		if child is Label:
			return (child as Label).text
	return ""


func _find_hex_owned(tag: StringName, same: bool) -> Vector2i:
	var game := Session.game
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		var holder := Territory.owner_tag(game, hex)
		if game.map.land[i] == 1 and holder != &"" and (holder == tag) == same:
			return hex
	return Vector2i(-1, -1)


func test_owner_row_is_hidden_and_the_home_rule_is_silent_in_a_map_only_game() -> void:
	var hex := _wild_land_with_options(1)[0]
	_panel.show_hex(hex)
	assert_false((_panel.get_node("Body/OwnerRow") as HBoxContainer).visible, "no owner without countries")
	assert_false((_panel.get_node("Body/HomeReason") as VBoxContainer).visible, "a map-only game has no home rule")
	assert_true((_panel.get_node("Body/ActionsBox") as VBoxContainer).visible, "the works show")
	assert_false((_panel.get_node("Body/WorthRow") as HBoxContainer).visible, "no worth without countries")


func test_owner_link_opens_the_country_and_the_home_reason_explains_refusals() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the scenario starts")
	var own_hex := _find_hex_owned(&"GEN", true)
	var other_hex := _find_hex_owned(&"GEN", false)
	assert_ne(own_hex, Vector2i(-1, -1), "Genoa holds land")
	assert_ne(other_hex, Vector2i(-1, -1), "someone else holds land")
	var asked: Array[StringName] = []
	_panel.country_requested.connect(func(tag: StringName) -> void: asked.append(tag))

	_panel.show_hex(own_hex)
	var owner_row := _panel.get_node("Body/OwnerRow") as HBoxContainer
	assert_true(owner_row.visible, "the Owner row shows on owned land")
	var link := (_panel.get_node("Body/OwnerRow/Value") as HBoxContainer).get_child(0) as KitButton
	assert_not_null(link, "the owner is a link")
	assert_eq(link.text, HexCard.owner_of(Session.game, own_hex), "the link names the owner")
	link.pressed.emit()
	assert_eq(asked, [&"GEN"], "the link asks for the owner's country")

	var reason := _panel.get_node("Body/HomeReason") as VBoxContainer
	var actions := _panel.get_node("Body/ActionsBox") as VBoxContainer
	assert_true(reason.visible, "no player: one reason line")
	assert_true(_reason_text_of(reason).contains("choose your country"), "the reason says to choose a country")
	assert_false(actions.visible, "no works before a country is chosen")

	assert_true(bool(Session.act("choose_country", {"tag": "GEN"})["ok"]))
	_panel.show_hex(own_hex)
	assert_false(reason.visible, "own land: no reason line")
	assert_true(actions.visible, "own land: the works show")

	_panel.show_hex(other_hex)
	assert_true(reason.visible, "another's land: the reason shows")
	assert_true(_reason_text_of(reason).begins_with("not your land"), "the refusal names the holder")
	assert_false(actions.visible, "another's land: no works")
	assert_false((_panel.get_node("Body/WorthRow") as HBoxContainer).visible, "another's land: no worth row")


## The first wild land hex (not in `skip`) where a build is allowed now, as the build's args {hex, family} (with the
## tag when given); empty when none.
func _buildable_for(tag: StringName, skip: Array[Vector2i]) -> Dictionary:
	var game := Session.game
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if game.map.land[i] != 1 or skip.has(hex) or not Improve.piece_at(game, hex).is_empty():
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


func test_a_work_under_way_shows_its_section_and_its_cancel_button() -> void:
	var args := _buildable_for(&"", [])
	assert_false(args.is_empty(), "a map-only game can start a build")
	var hex: Vector2i = args["hex"]
	_panel.show_hex(hex)
	var work_box := _panel.get_node("Body/WorkBox") as VBoxContainer
	assert_false(work_box.visible, "no work section before a build")
	await _press("Build")
	assert_true(work_box.visible, "the build's work shows at once (work_started refreshes the panel)")
	var at := WorksView.at(Session.game, hex)
	assert_eq((_panel.get_node("Body/WorkBox/Heading") as Label).text, "Work under way")
	assert_eq((_panel.get_node("Body/WorkBox/Text") as Label).text, str(at["label"]))
	assert_eq((_panel.get_node("Body/WorkBox/Progress") as Label).text, "%s, ready %s" % [at["progress"], at["ready"]])
	assert_false((_panel.get_node("Body/ActionsBox") as VBoxContainer).visible, "the rows are hidden while the work runs")
	var cancel := _button("Cancel the work") as KitButton
	assert_not_null(cancel, "the player's own work has Cancel the work")
	assert_false(cancel.disabled, "cancel is allowed")
	await _press("Cancel the work")
	assert_null(Session.game.state.work_at(hex), "Cancel ended the work")
	assert_false(work_box.visible, "the section goes with the work")
	assert_null(_button("Cancel the work"), "no Cancel once the work is gone")


func test_another_countrys_work_shows_with_no_cancel_button() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the scenario starts")
	assert_true(bool(Session.act("choose_country", {"tag": "GEN"})["ok"]))
	var args := _buildable_for(&"LUC", [])
	assert_false(args.is_empty(), "Lucca can start a work")
	assert_true(bool(Session.act("build", args)["ok"]), "Lucca's build is accepted")
	_panel.show_hex(args["hex"])
	assert_true((_panel.get_node("Body/WorkBox") as VBoxContainer).visible, "the work shows")
	assert_null(_button("Cancel the work"), "no Cancel on another country's work")


func test_a_work_halted_in_a_snow_winter_says_stopped_for_the_winter() -> void:
	var game := Session.game
	var hex := Vector2i(-1, -1)
	var args := {}
	for i: int in game.map.hex_count():
		var here := game.map.hex_of(i)
		if game.map.land[i] != 1 or int(game.map.climate[i]) != 0 or not Improve.piece_at(game, here).is_empty():
			continue
		for option: Dictionary in Improve.build_options(game, here):
			var family := int(option["family_id"])
			var candidate := {"hex": here, "family": family}
			if bool(Session.check("build", candidate)["ok"]) and WorksView.seasons_of(game, Works.BUILD, here, family) >= 3:
				hex = here
				args = candidate
				break
		if hex != Vector2i(-1, -1):
			break
	assert_ne(hex, Vector2i(-1, -1), "a snow hex can take a build of three seasons or more")
	assert_true(bool(Session.act("build", args)["ok"]), "the build is accepted")
	_panel.show_hex(hex)
	var n := 0
	while Session.game.state.work_at(hex) != null and n < 40 and not bool(WorksView.at(Session.game, hex).get("halted", false)):
		Session.end_season()
		n += 1
	await _settle()
	assert_true(bool(WorksView.at(Session.game, hex).get("halted", false)), "the snow work halts in winter")
	assert_true((_panel.get_node("Body/WorkBox/Progress") as Label).text.begins_with("stopped for the winter, ready "),
		"the panel says it stopped for the winter (season_ended refreshes it)")


func test_build_buttons_say_their_seasons() -> void:
	var args := _buildable_for(&"", [])
	var hex: Vector2i = args["hex"]
	_panel.show_hex(hex)
	var options := Improve.build_options(Session.game, hex)
	var buttons := _panel.action_buttons()
	assert_eq(buttons.size(), options.size(), "one build button per option")
	for at: int in mini(buttons.size(), options.size()):
		var kit := buttons[at] as KitButton
		var family := int(options[at]["family_id"])
		var expected := Words.seasons(WorksView.seasons_of(Session.game, Works.BUILD, hex, family))
		assert_eq(kit.cost_text, expected, "build %s says its seasons (refused or not)" % options[at]["family"])


func test_upgrade_and_clear_buttons_say_their_seasons() -> void:
	var args := _buildable_for(&"", [])
	var hex: Vector2i = args["hex"]
	assert_true(bool(Session.act("build", args)["ok"]), "the build is accepted")
	await _stand(hex)
	var piece := Improve.piece_at(Session.game, hex)
	assert_false(piece.is_empty(), "the build is standing")
	var family := int(piece["family_id"])
	_panel.show_hex(hex)
	var up := _button("Upgrade") as KitButton
	var down := _button("Clear") as KitButton
	assert_not_null(up, "a piece has Upgrade")
	assert_not_null(down, "a piece has Clear")
	var up_seasons := Words.seasons(WorksView.seasons_of(Session.game, Works.UPGRADE, hex, family))
	var down_seasons := Words.seasons(WorksView.seasons_of(Session.game, Works.CLEAR, hex, family))
	assert_eq(up.cost_text, up_seasons, "Upgrade says its seasons")
	assert_eq(down.cost_text, down_seasons, "Clear says its seasons")


func test_a_full_slot_gives_its_reason_on_the_build_buttons() -> void:
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the scenario starts")
	assert_true(bool(Session.act("choose_country", {"tag": "GEN"})["ok"]))
	var slots := WorksView.slots(Session.game, &"GEN")
	assert_eq(int(slots["total"]), 2, "Genoa has two work slots in 1480")
	var taken: Array[Vector2i] = []
	for n: int in int(slots["total"]):
		var args := _buildable_for(&"GEN", taken)
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
			var args := {"hex": here, "family": int(option["family_id"])}
			if str(Session.check("build", args)["reason"]).begins_with("no free work slot"):
				blocked = here
				break
		if blocked != Vector2i(-1, -1):
			break
	assert_ne(blocked, Vector2i(-1, -1), "a third build is refused by the slots")
	_panel.show_hex(blocked)
	var full := "No free work slot: 2 of 2 in use."
	var found := 0
	for button: Button in _panel.action_buttons():
		var kit := button as KitButton
		if kit.disabled and kit.reason_text() == full:
			found += 1
			assert_eq(kit.tooltip_text, full, "the reason is the tooltip")
	assert_gt(found, 0, "a build button shows the full slot's reason")
	assert_true(_reason_lines().has(full), "the reason is a line under the buttons")


func test_rows_show_their_label_cost_text_and_at_most_three_chips() -> void:
	var hex := _gen_buildable()
	assert_ne(hex, Vector2i(-1, -1), "Genoa can build somewhere")
	_panel.show_hex(hex)
	var rows := ImprovePreview.options_of(Session.game, &"GEN", hex)
	var buttons := _panel.action_buttons()
	assert_eq(buttons.size(), rows.size(), "one KitButton per row")
	for at: int in rows.size():
		var row: Dictionary = rows[at]
		var kit := buttons[at] as KitButton
		assert_eq(kit.text, str(row["label"]), "the row's label")
		assert_eq(kit.cost_text, str(row["cost_text"]), "the row's cost text, e.g. '40 · 4 seasons'")
		assert_true(kit.cost_text.ends_with("seasons") or kit.cost_text.ends_with("season"), "the cost ends in seasons")
	var chips := _delta_chips()
	var expected := 0
	for row: Dictionary in rows:
		expected += mini((row["chips"] as Array).size(), 3)
	assert_eq(chips.size(), expected, "each row shows up to three DeltaChips from its chips")


func test_a_refused_row_has_no_click_and_its_reason_is_words() -> void:
	var hex := _gen_buildable()
	_panel.show_hex(hex)
	var rows := ImprovePreview.options_of(Session.game, &"GEN", hex)
	var buttons := _panel.action_buttons()
	for at: int in rows.size():
		var verdict: Dictionary = rows[at]["verdict"]
		if not bool(verdict["ok"]):
			assert_true(buttons[at].disabled, "a refused row is disabled")
			var words := ImprovePreview.reason_words(Session.game, hex, {"action": rows[at]["action"], "family": rows[at]["family"]}, verdict)
			assert_true(_reason_lines().has(words), "the refused row's reason is a line: " + words)


func test_confirm_off_asks_for_the_work_and_does_not_begin_it() -> void:
	var hex := _gen_buildable()
	_set_mode("off")
	_panel.show_hex(hex)
	var log := _record_requests()
	var pair := _row_and_button(hex, false)
	assert_false(pair.is_empty(), "an enabled row that is not expensive")
	(pair[1] as Button).pressed.emit()
	await _settle()
	assert_eq(log.size(), 1, "one request")
	assert_eq(log[0][0], &"begin_work", "off: the click asks for the work")
	assert_eq(str((log[0][1] as Dictionary)["option"]["action"]), str((pair[0] as Dictionary)["action"]), "the request names the row")
	assert_eq(log[0][1]["hex"], hex, "the request names the hex")
	assert_null(Session.game.state.work_at(hex), "the panel did not begin it itself: the App does")


func test_confirm_always_opens_the_card_for_every_row() -> void:
	var hex := _gen_buildable()
	_set_mode("always")
	_panel.show_hex(hex)
	var log := _record_requests()
	var pair := _row_and_button(hex, false)
	assert_false(pair.is_empty(), "an enabled row")
	(pair[1] as Button).pressed.emit()
	await _settle()
	assert_eq(log.size(), 1, "one request")
	assert_eq(log[0][0], &"works_card", "always: the click opens the card")
	assert_null(Session.game.state.work_at(hex), "no work begun")


func test_confirm_expensive_opens_the_card_only_for_expensive_rows() -> void:
	var hex := _gen_buildable()
	_set_mode("expensive")
	_panel.show_hex(hex)
	var log := _record_requests()
	var cheap := _row_and_button(hex, false)
	if cheap.is_empty():
		pending("no enabled row that is not expensive at this hex")
	else:
		(cheap[1] as Button).pressed.emit()
		await _settle()
		assert_eq(log[-1][0], &"begin_work", "a cheap row begins the work")
	var dear := _row_and_button(hex, true)
	if dear.is_empty():
		pending("no enabled expensive row at this hex")
	else:
		var before := log.size()
		(dear[1] as Button).pressed.emit()
		await _settle()
		assert_eq(log.size(), before + 1, "one request for the expensive row")
		assert_eq(log[-1][0], &"works_card", "an expensive row opens the card first")


func test_the_default_confirm_mode_is_expensive() -> void:
	var hex := _gen_buildable()
	_panel.show_hex(hex)
	var log := _record_requests()
	var cheap := _row_and_button(hex, false)
	assert_false(cheap.is_empty(), "an enabled row that is not expensive")
	(cheap[1] as Button).pressed.emit()
	await _settle()
	assert_eq(log[-1][0], &"begin_work", "no settings: a cheap row begins the work")


func test_row_hover_emits_row_hovered_and_leaving_emits_row_unhovered() -> void:
	var hex := _gen_buildable()
	_panel.show_hex(hex)
	var hovered: Array = []
	var left := [0]
	_panel.row_hovered.connect(func(h: Vector2i, option: Dictionary) -> void: hovered.append([h, option]))
	_panel.row_unhovered.connect(func() -> void: left[0] += 1)
	var rows := ImprovePreview.options_of(Session.game, &"GEN", hex)
	var buttons := _panel.action_buttons()
	assert_gt(buttons.size(), 0, "the hex has rows")
	buttons[0].mouse_entered.emit()
	assert_eq(hovered.size(), 1, "hovering a row emits once")
	assert_eq(hovered[0][0], hex, "the hex of the row")
	assert_eq(str((hovered[0][1] as Dictionary)["action"]), str(rows[0]["action"]), "the row's action")
	assert_eq(int((hovered[0][1] as Dictionary)["family"]), int(rows[0]["family"]), "the row's family")
	buttons[0].mouse_exited.emit()
	assert_eq(left[0], 1, "leaving emits row_unhovered")


func test_the_info_button_opens_the_card_and_is_not_a_row() -> void:
	var hex := _gen_buildable()
	_panel.show_hex(hex)
	var log := _record_requests()
	var info: Button = null
	for node: Node in _panel.find_children("*", "Button", true, false):
		if node is Button and not (node is KitButton) and (node as Button).tooltip_text == "Show the card":
			info = node as Button
			break
	assert_not_null(info, "each row has an (i) button")
	info.pressed.emit()
	assert_eq(log[-1][0], &"works_card", "(i) asks for the card")
	assert_null(Session.game.state.work_at(hex), "(i) begins nothing")


func test_cancel_asks_for_the_cancel_with_its_refund() -> void:
	var hex := _gen_buildable()
	var args := _buildable_for(&"GEN", [])
	assert_false(args.is_empty(), "Genoa can start a build")
	assert_true(bool(Session.act("build", args)["ok"]), "the build is accepted")
	var work_hex: Vector2i = args["hex"]
	assert_ne(hex, Vector2i(-1, -1), "Genoa can build somewhere")
	var work := Session.game.state.work_at(work_hex)
	assert_not_null(work, "the work is under way")
	var expected := Works.refund(Session.game, work)
	_panel.show_hex(work_hex)
	var log := _record_requests()
	await _press("Cancel the work")
	assert_eq(log.size(), 1, "the cancel is one request")
	assert_eq(log[0][0], &"cancel_work", "the request is cancel_work")
	assert_eq(int(log[0][1]["refund"]), expected, "the request carries the refund")
	assert_eq(log[0][1]["hex"], work_hex, "and its hex")
	assert_not_null(Session.game.state.work_at(work_hex), "the App cancels it, not the panel")


func test_gives_and_worth_rows_show_the_hex_card_and_the_worth() -> void:
	var hex := _gen_buildable()
	assert_ne(hex, Vector2i(-1, -1), "Genoa can build somewhere")
	var worth_rows := EconomyPreview.worth_by_hex(Session.game, &"GEN")
	assert_false(worth_rows.is_empty(), "Genoa's land has a worth this season")
	var row: Dictionary = worth_rows[0]
	var worth_hex: Vector2i = row["hex"]
	_panel.show_hex(worth_hex)
	var gives_row := _panel.get_node("Body/GivesRow") as HBoxContainer
	var gives := str(HexCard.of(Session.game, worth_hex).get("gives", ""))
	assert_eq(gives_row.visible, gives != "", "the Gives row shows when the hex card has a Gives line")
	assert_eq((_panel.get_node("Body/GivesRow/Value") as Label).text, gives, "the Gives text is the hex card's")
	var worth_row := _panel.get_node("Body/WorthRow") as HBoxContainer
	assert_true(worth_row.visible, "the Worth row shows for a held hex")
	var chips := (_panel.get_node("Body/WorthRow/Value") as HBoxContainer).get_children()
	assert_eq(chips.size(), 1, "one DeltaChip")
	var chip := chips[0] as DeltaChip
	assert_not_null(chip, "the worth is a DeltaChip")
	assert_true(chip.text().contains(str(absi(int(row["worth"])))), "the chip shows the worth: " + chip.text())
	assert_eq((_panel.get_node("Body/WorthRow/Key") as Label).text, "Worth, this season")


func test_a_row_click_with_no_listener_begins_the_work_itself() -> void:
	var hex := _gen_buildable()
	_set_mode("off")
	_panel.show_hex(hex)
	var pair := _row_and_button(hex, false)
	assert_false(pair.is_empty(), "an enabled row")
	(pair[1] as Button).pressed.emit()
	await _settle()
	assert_not_null(Session.game.state.work_at(hex), "without a listener the M3 path begins the work")


func _has_enabled(prefix: String) -> bool:
	for button: Button in _panel.action_buttons():
		if not button.disabled and button.text.begins_with(prefix):
			return true
	return false


func _level_word_for(hex: Vector2i) -> String:
	var piece := Improve.piece_at(Session.game, hex)
	var family := str(piece["family"])
	if family == "settlements":
		return "hamlet"
	if family == "castles":
		return "watchtower"
	return "first stage"
