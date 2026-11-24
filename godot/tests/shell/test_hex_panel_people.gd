## Studiolo hex panel: the People section tests (spec 6.3): yours, known, unknown, unowned; the outlook in its tone; the
## refresh on town_grew and district_declined; the disconnect on exit; the fit at 1024 x 600. Split from test_hex_panel.gd
## to keep that file under the size limit; the setup and helpers below are the same as there.
extends GutTest

const PANEL := "res://shell/panels/hex_panel.tscn"

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


## Waits for the panel's coalesced refresh (it runs at the end of the frame, after the signals of a press).
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


## A buildable hex of Genoa (the player's country in 1480), or Vector2i(-1, -1).
func _gen_buildable() -> Vector2i:
	assert_eq(Session.new_scenario("north_italy_1480", 1480), "", "the scenario starts")
	assert_true(bool(Session.act("choose_country", {"tag": "GEN"})["ok"]))
	var args := _buildable_for(&"GEN", [])
	if args.is_empty():
		return Vector2i(-1, -1)
	return args["hex"]


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


## The People section (spec 6.3): yours, known, unknown, unowned; the outlook in its tone; the refresh on town_grew and
## district_declined; the disconnect on exit; the fit at 1024 x 600.
func _people_box() -> VBoxContainer:
	return _panel.get_node("Scroll/Body/PeopleBox") as VBoxContainer


func _people_value() -> String:
	return (_panel.get_node("Scroll/Body/PeopleBox/PeopleRow/Value") as Label).text


func _room_row() -> HBoxContainer:
	return _panel.get_node("Scroll/Body/PeopleBox/RoomRow") as HBoxContainer


func _outlook() -> Label:
	return _panel.get_node("Scroll/Body/PeopleBox/Outlook") as Label


## The first land hex of `tag` that is (settlement) or is not a settlement; Vector2i(-1, -1) if none.
func _hex_of_country(tag: StringName, settlement: bool) -> Vector2i:
	var game := Session.game
	var c := Countries.by_tag(game, tag)
	for i: int in Territory.districts(game, c.id):
		if (int(game.state.main_use[i]) == People.SETTLEMENTS) == settlement:
			return game.map.hex_of(i)
	return Vector2i(-1, -1)


func _listens(sig: Signal, obj: Object) -> bool:
	for conn: Dictionary in sig.get_connections():
		if (conn["callable"] as Callable).get_object() == obj:
			return true
	return false


func test_yours_shows_the_people_room_and_outlook_in_its_tone() -> void:
	_gen_buildable()
	var hex := _hex_of_country(&"GEN", true)
	assert_ne(hex, Vector2i(-1, -1), "Genoa has a town")
	_panel.show_hex(hex)
	var seen := PeopleView.at(Session.game, &"GEN", hex)
	assert_true(_people_box().visible, "the People section shows on your land")
	var expected := Words.number(int(seen["people"]))
	var change := int(seen["change"])
	if change != 0:
		expected += " (%s %s last season)" % ["up" if change > 0 else "down", Words.number(absi(change))]
	assert_eq(_people_value(), expected, "the People row: the figure and last season's change")
	assert_true(_room_row().visible, "the Room row shows on your land")
	assert_eq((_room_row().get_node("Value") as Label).text, Words.number(int(seen["room"])), "the Room row")
	var outlook := PeopleView.outlook(Session.game, hex)
	assert_false(outlook.is_empty(), "your town has an outlook")
	assert_true(_outlook().visible)
	assert_eq(_outlook().text, str(outlook["text"]), "the outlook text is the view's")
	assert_eq(_outlook().theme_type_variation, HexPanel.tone_variation(StringName(str(outlook["tone"]))), "in its tone")


func test_each_outlook_tone_has_its_theme_variation() -> void:
	assert_eq(HexPanel.tone_variation(&"good"), &"NumberGood")
	assert_eq(HexPanel.tone_variation(&"bad"), &"NumberBad")
	assert_eq(HexPanel.tone_variation(&"warn"), &"NumberWarn")
	assert_eq(HexPanel.tone_variation(&"plain"), &"TableRow")


func test_a_hungry_town_gives_a_bad_outlook() -> void:
	_gen_buildable()
	var hex := _hex_of_country(&"GEN", true)
	Countries.by_tag(Session.game, &"GEN").food_fed = 0
	_panel.show_hex(hex)
	assert_eq(_outlook().theme_type_variation, &"NumberBad", "hunger is bad")
	assert_true(_outlook().text.begins_with("Hungry"), "the hunger line: " + _outlook().text)


func test_a_countryside_over_its_room_is_crowded_and_warn() -> void:
	_gen_buildable()
	var hex := _hex_of_country(&"GEN", false)
	assert_ne(hex, Vector2i(-1, -1), "Genoa has countryside")
	var room := int(PeopleView.at(Session.game, &"GEN", hex)["room"])
	assert_true(Session.dev_people(hex, room + 500), "the people go over the room")
	_panel.show_hex(hex)
	assert_eq(_outlook().theme_type_variation, &"NumberWarn", "crowding is a warning")
	assert_true(_outlook().text.begins_with("Crowded"), "the crowding line: " + _outlook().text)


func test_a_countryside_with_room_left_is_plain() -> void:
	_gen_buildable()
	var hex := _hex_of_country(&"GEN", false)
	assert_true(Session.dev_people(hex, 0), "an empty countryside hex")
	_panel.show_hex(hex)
	assert_eq(_outlook().theme_type_variation, &"TableRow", "room left is plain")
	assert_true(_outlook().text.begins_with("Room for"), "the room line: " + _outlook().text)


func test_a_town_that_can_grow_gives_a_good_outlook() -> void:
	_gen_buildable()
	var found := false
	var game := Session.game
	var c := Countries.by_tag(game, &"GEN")
	var said := PackedStringArray()
	for i: int in Territory.districts(game, c.id):
		if int(game.state.main_use[i]) != People.SETTLEMENTS:
			continue
		# Genoa's towns start at or above the top growing level: a hamlet (level 1) is set up for the test.
		game.state.level[i] = 1
		var hex := game.map.hex_of(i)
		Session.dev_people(hex, int(PeopleView.at(game, &"GEN", hex)["room"]))
		var o := PeopleView.outlook(game, hex)
		said.append("%s/%s" % [str(o.get("tone", "")), str(o.get("text", ""))])
		if str(o.get("tone", "")) == "good":
			found = true
			_panel.show_hex(hex)
			break
	assert_true(found, "a Genoese town can grow into the next level; said: " + " | ".join(said))
	assert_eq(_outlook().theme_type_variation, &"NumberGood", "growth is good")


func test_an_undiscovered_hex_shows_no_people_section() -> void:
	_gen_buildable()
	var game := Session.game
	FogFixture.thin(game, &"GEN", 0)
	var hex := Vector2i(-1, -1)
	for i: int in game.map.hex_count():
		if game.map.land[i] == 1 and not Knowledge.discovered(game, &"GEN", game.map.hex_of(i)):
			hex = game.map.hex_of(i)
			break
	assert_ne(hex, Vector2i(-1, -1), "an undiscovered land hex on the thin fixture")
	_panel.show_hex(hex)
	assert_true(_panel.visible, "the panel shows the hex")
	assert_false(_people_box().visible, "no People section for an undiscovered hex")


func test_a_discovered_countrys_land_shows_an_exact_figure_and_no_room() -> void:
	_gen_buildable()
	var hex := Vector2i(-1, -1)
	var milan := Countries.by_tag(Session.game, &"MLO")
	for i: int in Territory.districts(Session.game, milan.id):
		var cand := Session.game.map.hex_of(i)
		var text := str(PeopleView.at(Session.game, &"GEN", cand).get("text", ""))
		if text != "" and text != "none":
			hex = cand
			break
	assert_ne(hex, Vector2i(-1, -1), "Milan has land with people")
	_panel.show_hex(hex)
	var seen := PeopleView.at(Session.game, &"GEN", hex)
	assert_true(_people_box().visible, "Milan borders Genoa: known")
	assert_eq(_people_value(), str(seen["text"]), "the exact figure")
	assert_false(_people_value().begins_with("about "), "exact, not banded: " + _people_value())
	assert_false(_room_row().visible, "no Room row for a known country")
	assert_false(_outlook().visible, "no outlook for a known country")


func test_unowned_land_in_a_map_only_game_shows_the_number_alone() -> void:
	var hex := _wild_land_with_options(1)[0]
	_panel.show_hex(hex)
	var seen := PeopleView.at(Session.game, &"", hex)
	assert_eq(_people_box().visible, bool(seen["shown"]), "the section follows the view")
	assert_eq(_people_value(), str(seen["text"]), "the number alone")
	assert_false(_room_row().visible, "no Room row on unowned land")
	assert_false(_outlook().visible, "no outlook on unowned land")


func test_a_town_grew_or_declined_refreshes_the_people_value() -> void:
	_gen_buildable()
	var hex := _hex_of_country(&"GEN", true)
	_panel.show_hex(hex)
	var before := int(PeopleView.at(Session.game, &"GEN", hex)["people"])
	assert_true(Session.dev_people(hex, before + 1000), "the town gains 1,000 (no signal)")
	assert_true(_people_value().begins_with(Words.number(before)), "no refresh without the signal")
	Events.town_grew.emit(&"GEN", hex, 2)
	await _settle()
	assert_true(_people_value().begins_with(Words.number(before + 1000)), "town_grew refreshes it")
	assert_true(Session.dev_people(hex, before + 2000))
	Events.district_declined.emit(&"GEN", hex, 1, &"hunger")
	await _settle()
	assert_true(_people_value().begins_with(Words.number(before + 2000)), "district_declined refreshes it")
	var other := _hex_of_country(&"GEN", false)
	Events.town_grew.emit(&"GEN", other, 2)
	await _settle()
	assert_true(_people_value().begins_with(Words.number(before + 2000)), "another hex's signal does not change this one")


func test_leaving_the_tree_disconnects_the_people_signals() -> void:
	var extra := (load(PANEL) as PackedScene).instantiate() as HexPanel
	extra.theme = KitTheme.load_for(1.0)
	add_child(extra)
	assert_true(_listens(Events.town_grew, extra), "listens to town_grew while in the tree")
	assert_true(_listens(Events.district_declined, extra), "listens to district_declined while in the tree")
	remove_child(extra)
	assert_false(_listens(Events.town_grew, extra), "no town_grew listener after exit")
	assert_false(_listens(Events.district_declined, extra), "no district_declined listener after exit")
	extra.free()


func test_a_people_section_on_a_tall_hex_stays_inside_1024_by_600() -> void:
	var hex := _gen_buildable()
	# A window of 1024 x 600 hosts the panel (the root window's size is not changed by a test; a SubViewport is).
	var window := SubViewport.new()
	window.size = Vector2i(1024, 600)
	add_child_autofree(window)
	var panel := (load(PANEL) as PackedScene).instantiate() as HexPanel
	panel.theme = KitTheme.load_for(1.0)
	window.add_child(panel)
	await _settle()
	panel.show_hex(hex)
	await _settle()
	assert_true(panel.visible)
	assert_lte(panel.get_global_rect().end.y, 600.5, "the panel ends inside a 1024 x 600 window")
