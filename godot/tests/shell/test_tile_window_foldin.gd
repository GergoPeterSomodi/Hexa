## The tile window with the real tabs (tile-window spec R12, R33; TW16): the cases of the old hex panel tests that belong to the
## frame and not to a tab, folded in from test_hex_panel.gd, test_hex_panel_people.gd and test_hex_panel_fog.gd: the frame, the
## job line (own work with Cancel, another country's work without, a winter halt, the cancel request with its refund), the
## refresh on town_grew and district_declined, the listeners' disconnect on exit, the fit at 1024 x 600 and the window on the
## thin duel (an undiscovered hex shows no owner, a light-fog hex shows it).
extends GutTest

const WINDOW := "res://shell/panels/tile_window.tscn"

var _window: TileWindow = null


func before_each() -> void:
	Bindings.ensure()
	var defs := Session.defs()
	var scenario: ScenarioDef = defs.scenarios[defs.scenarios.size() - 1]
	Session.new_scenario(scenario.id, MapScene.START_SEED, &"GEN")
	_window = (load(WINDOW) as PackedScene).instantiate() as TileWindow
	_window.theme = KitTheme.load_for(1.0)
	add_child_autofree(_window)


func after_each() -> void:
	Session.end_game()
	await get_tree().process_frame


func _job() -> JobLine:
	return _window.get_node("Scroll/Body/WorkBox") as JobLine


func _title() -> Label:
	return _window.get_node("Scroll/Body/Header/Title") as Label


func _place() -> Button:
	return _window.get_node("Scroll/Body/Header/Meta/Place") as Button


# --- cases folded in from test_hex_panel.gd and test_hex_panel_people.gd (TW16): the frame, the job line, the refresh ------------


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


## The first land hex of `tag` where a build is allowed now, as {hex, family}; {} if none.
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


func _texts_of(node: Node, out: PackedStringArray) -> PackedStringArray:
	if node is Label or node is Button:
		out.append(str(node.get("text")))
	for child: Node in node.get_children():
		_texts_of(child, out)
	return out


func _cancel_button() -> Button:
	for button: Button in _window.action_buttons():
		if button.text.begins_with("Cancel the work"):
			return button
	return null


func _listens(sig: Signal, obj: Object) -> bool:
	for conn: Dictionary in sig.get_connections():
		if (conn["callable"] as Callable).get_object() == obj:
			return true
	return false


func test_the_frame_stops_the_mouse_takes_the_dock_width_and_hides_on_clear() -> void:
	assert_eq(_window.mouse_filter, Control.MOUSE_FILTER_STOP, "a click on the window never reaches the map")
	assert_eq(_window.custom_minimum_size.x, float(Tokens.PANEL_W), "width matches Tokens.PANEL_W")
	var args := _buildable_for(&"GEN", [])
	assert_false(args.is_empty(), "Genoa can build somewhere")
	var hex: Vector2i = args["hex"]
	_window.show_hex(hex)
	assert_true(_window.visible)
	assert_eq(_window.shown_hex(), hex)
	for button: Button in _window.action_buttons():
		assert_true(button is KitButton, "the hammers are Studiolo KitButtons")
		assert_eq(button.focus_mode, Control.FOCUS_ALL, "the rows take keyboard focus")
	_window.clear()
	assert_false(_window.visible, "clear hides it")
	assert_eq(_window.shown_hex(), HexPanelContract.NO_HEX)


func test_a_work_under_way_shows_its_line_and_its_cancel_button() -> void:
	var args := _buildable_for(&"GEN", [])
	assert_false(args.is_empty(), "Genoa can start a build")
	var hex: Vector2i = args["hex"]
	_window.show_hex(hex)
	assert_false(_job().visible, "no job line before a build")
	assert_true(bool(Session.act("build", args)["ok"]), "the build is accepted")
	await _settle()
	assert_true(_job().visible, "the build's work shows at once (work_started refreshes the window)")
	var at := WorksView.at(Session.game, hex, &"GEN")
	assert_eq((_job().get_node("Text") as Label).text, str(at["label"]))
	assert_eq((_job().get_node("Progress") as Label).text, "%s, ready %s" % [at["progress"], at["ready"]])
	var cancel := _cancel_button() as KitButton
	assert_not_null(cancel, "the player's own work has Cancel the work")
	assert_false(cancel.disabled, "cancel is allowed")
	cancel.pressed.emit()
	await _settle()
	assert_null(Session.game.state.work_at(hex), "with no listener the job line cancels the work itself")
	assert_false(_job().visible, "the line goes with the work")
	assert_null(_cancel_button(), "no Cancel once the work is gone")


func test_another_countrys_work_shows_with_no_cancel_button() -> void:
	var args := _buildable_for(&"LUC", [])
	assert_false(args.is_empty(), "Lucca can start a work")
	assert_true(bool(Session.act("build", args)["ok"]), "Lucca's build is accepted")
	_window.show_hex(args["hex"])
	assert_true(_job().visible, "the work shows")
	assert_null(_cancel_button(), "no Cancel on another country's work")


func test_a_work_halted_in_a_snow_winter_says_stopped_for_the_winter() -> void:
	var game := Session.game
	var hex := Vector2i(-1, -1)
	var args := {}
	for i: int in game.map.hex_count():
		var here := game.map.hex_of(i)
		if game.map.land[i] != 1 or int(game.map.climate[i]) != 0 or not Improve.piece_at(game, here).is_empty():
			continue
		if Territory.owner_tag(game, here) != &"GEN":
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
	if hex == Vector2i(-1, -1):
		pending("no snow hex of Genoa can take a build of three seasons or more")
		return
	assert_true(bool(Session.act("build", args)["ok"]), "the build is accepted")
	_window.show_hex(hex)
	var n := 0
	while Session.game.state.work_at(hex) != null and n < 40 and not bool(WorksView.at(Session.game, hex, &"GEN").get("halted", false)):
		Session.end_season()
		n += 1
	await _settle()
	assert_true(bool(WorksView.at(Session.game, hex, &"GEN").get("halted", false)), "the snow work halts in winter")
	assert_true((_job().get_node("Progress") as Label).text.begins_with("stopped for the winter, ready "),
		"the window says it stopped for the winter (season_ended refreshes it)")


func test_cancel_asks_the_app_for_the_cancel_with_its_refund() -> void:
	var args := _buildable_for(&"GEN", [])
	assert_false(args.is_empty(), "Genoa can start a build")
	assert_true(bool(Session.act("build", args)["ok"]), "the build is accepted")
	var hex: Vector2i = args["hex"]
	var expected := Works.refund(Session.game, Session.game.state.work_at(hex))
	_window.show_hex(hex)
	var log: Array = []
	_window.works_requested.connect(func(what: StringName, request: Dictionary) -> void: log.append([what, request]))
	var cancel := _cancel_button()
	assert_not_null(cancel, "Cancel the work is there")
	cancel.pressed.emit()
	await _settle()
	assert_eq(log.size(), 1, "the cancel is one request")
	assert_eq(log[0][0], &"cancel_work", "the request is cancel_work")
	assert_eq(int(log[0][1]["refund"]), expected, "the request carries the refund")
	assert_eq(log[0][1]["hex"], hex, "and its hex")
	assert_not_null(Session.game.state.work_at(hex), "the App cancels it, not the window")


func test_a_town_grew_or_declined_refreshes_the_people_value() -> void:
	var game := Session.game
	var town := Vector2i(-1, -1)
	var other := Vector2i(-1, -1)
	for i: int in Territory.districts(game, Countries.by_tag(game, &"GEN").id):
		var settlement := int(game.state.main_use[i]) == People.SETTLEMENTS
		if settlement and town == Vector2i(-1, -1):
			town = game.map.hex_of(i)
		elif not settlement and other == Vector2i(-1, -1):
			other = game.map.hex_of(i)
	assert_ne(town, Vector2i(-1, -1), "Genoa has a town")
	_window.show_hex(town)
	assert_true(_window.show_tab(&"land"), "the Land tab is live on own land")
	var before := int(PeopleView.at(game, &"GEN", town)["people"])
	assert_true(Session.dev_people(town, before + 1000), "the town gains 1,000 (no signal)")
	assert_false(_texts_of(_window.tab_node(), PackedStringArray()).has(Words.number(before + 1000)), "no refresh without the signal")
	Events.town_grew.emit(&"GEN", town, 2)
	await _settle()
	assert_true(_texts_of(_window.tab_node(), PackedStringArray()).has(Words.number(before + 1000)), "town_grew refreshes it")
	assert_true(Session.dev_people(town, before + 2000))
	Events.district_declined.emit(&"GEN", town, 1, &"hunger")
	await _settle()
	assert_true(_texts_of(_window.tab_node(), PackedStringArray()).has(Words.number(before + 2000)), "district_declined refreshes it")
	if other != Vector2i(-1, -1):
		assert_true(Session.dev_people(town, before + 3000))
		Events.town_grew.emit(&"GEN", other, 2)
		await _settle()
		assert_false(_texts_of(_window.tab_node(), PackedStringArray()).has(Words.number(before + 3000)),
			"another hex's signal does not change this one")


func test_leaving_the_tree_disconnects_the_window_signals() -> void:
	var extra := (load(WINDOW) as PackedScene).instantiate() as TileWindow
	extra.theme = KitTheme.load_for(1.0)
	add_child(extra)
	for sig: Signal in [Events.town_grew, Events.district_declined, Events.controllers_changed, Events.army_raised]:
		assert_true(_listens(sig, extra), "listens while in the tree: " + sig.get_name())
	remove_child(extra)
	for sig: Signal in [Events.town_grew, Events.district_declined, Events.controllers_changed, Events.army_raised]:
		assert_false(_listens(sig, extra), "no listener after exit: " + sig.get_name())
	extra.free()


func test_a_tall_window_stays_inside_1024_by_600() -> void:
	var args := _buildable_for(&"GEN", [])
	var hex: Vector2i = args["hex"]
	var host := SubViewport.new()
	host.size = Vector2i(1024, 600)
	add_child_autofree(host)
	var window := (load(WINDOW) as PackedScene).instantiate() as TileWindow
	window.theme = KitTheme.load_for(1.0)
	host.add_child(window)
	await _settle()
	window.show_hex(hex)
	await _settle()
	assert_true(window.visible)
	assert_lte(window.get_global_rect().end.y, 600.5, "the window ends inside a 1024 x 600 viewport")


# --- cases folded in from test_hex_panel_fog.gd (TW16): the window on the thin duel -----------------------------------------


## Milan's view of the thin duel (the player is Milan); the first land hex whose owner is another country and that is
## undiscovered (light false) or in light fog (light true); NO_HEX when none.
func _duel_hex(game: Game, light: bool) -> Vector2i:
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		var owner := Territory.owner_tag(game, hex)
		if not game.map.is_land(hex) or owner == &"" or owner == game.player:
			continue
		var found := Knowledge.discovered(game, game.player, hex)
		if light and found and not Knowledge.sees(game, game.player, hex):
			return hex
		if not light and not found:
			return hex
	return HexPanelContract.NO_HEX


func _visible_texts(node: Node, out: PackedStringArray) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label or node is RichTextLabel or node is Button:
		out.append(str(node.get("text")))
	for child: Node in node.get_children():
		_visible_texts(child, out)


func test_an_undiscovered_hex_says_unexplored_and_shows_no_owner() -> void:
	var game := FogFixture.duel_thin()
	game.player = AiFixture.MILAN
	Session.start_game(game)
	var hex := _duel_hex(game, false)
	assert_ne(hex, HexPanelContract.NO_HEX, "the thin duel has an undiscovered hex with an owner")
	_window.show_hex(hex)
	assert_eq(_title().text, "Unexplored", "the window's header says Unexplored")
	assert_false(_place().is_visible_in_tree(), "no owner link on an undiscovered hex")
	var cdef := Countries.def_of(game, Territory.owner_tag(game, hex))
	var owner_name := cdef.long_name if cdef != null and cdef.long_name != "" else String(Territory.owner_tag(game, hex))
	var texts := PackedStringArray()
	_visible_texts(_window, texts)
	for text: String in texts:
		assert_false(text.contains(owner_name), "no visible text names the owner of an undiscovered hex: '%s'" % text)
	Session.end_game()


func test_a_light_fog_hex_still_shows_its_owner() -> void:
	var game := FogFixture.duel_thin()
	game.player = AiFixture.MILAN
	Session.start_game(game)
	var hex := _duel_hex(game, true)
	assert_ne(hex, HexPanelContract.NO_HEX, "the thin duel has a light-fog hex with an owner")
	_window.show_hex(hex)
	assert_ne(_title().text, "Unexplored", "a discovered hex is not Unexplored")
	assert_true(_place().is_visible_in_tree(), "the owner link shows on a light-fog hex (R18)")
	Session.end_game()
