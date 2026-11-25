## The war parts of the tile window and the hex menu (docs/architecture/m7-build-spec.md 6.8; M7 B26). The window's Land tab shows
## the hex card's war rows (without the Siege row) and, for a siege the viewer may read, the siege meter and its line. The menu's war items: "Open the Battle of ..." for a battle fought on the hex last season,
## "Show the siege of ..." on a besieged hex, "Show the castle area" on land a castle holds while a war of yours is on; each is a
## chosen(action) and carried out here where the menu can. Planted faults: a siege the viewer cannot read shows in the panel; a war
## row missing; a battle item with no record.
extends GutTest

const PANEL := "res://shell/panels/tile_window.tscn"
const MAP := "res://shell/map/map_scene.tscn"
const TAG := ArmyFixture.TAG

var _g: Game
var _panel: TileWindow = null
var _scene: MapScene = null
var _own := Vector2i(-1, -1)


func before_each() -> void:
	_g = ArmyFixture.game()
	_own = ArmyFixture.find_town(_g)
	ArmyFixture.town(_g, _own)
	ArmyFixture.rich(_g)
	Session.start_game(_g)
	_scene = (load(MAP) as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_panel = (load(PANEL) as PackedScene).instantiate() as TileWindow
	_panel.theme = KitTheme.load_for(1.0)
	add_child_autofree(_panel)
	_scene.set_panel(_panel)


func after_each() -> void:
	Session.end_game()
	await get_tree().process_frame


## The body of the Town tab, where the war rows and the siege meter are.
func _box() -> VBoxContainer:
	return _panel.get_node("%TabBody") as VBoxContainer


## Shows the hex on the Town tab (an own settlement opens on Buildings).
func _show(hex: Vector2i) -> void:
	_panel.show_hex(hex)
	assert_true(_panel.show_tab(&"town"), "the Town tab is live")


func _menu() -> HexMenu:
	for child: Node in (_scene.get_node("MapArmies") as MapArmies).get_children():
		if child is HexMenu:
			return child as HexMenu
	return null


## A fortress of an enemy at war with Genoa, garrisoned; {hex}. The test fails when the map has none.
func _enemy_fortress() -> Vector2i:
	var enemy := WarFixture.neighbour_of(_g, TAG)
	WarFixture.at_war(_g, enemy, TAG)
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if Occupation.fortress_level(_g, hex) > 0 and Occupation.garrison_of(_g, hex) > 0 \
				and Occupation.controller_tag(_g, hex) == enemy:
			return hex
	assert_true(false, "an enemy fortress with a garrison exists on the 1480 map")
	return ArmyFixture.NO_HEX


## A siege of hex by tag, as the sieges phase leaves it.
func _siege(hex: Vector2i, by: StringName, progress: int) -> void:
	var s := Siege.new()
	s.hex = hex
	s.besieger = by
	s.progress = progress
	s.seasons = 1
	s.name = "Siege of Test, 1480"
	s.started_turn = _g.turn
	_g.sieges.append(s)
	_g.version += 1


## A fortress we hold, besieged by a neighbour at war with us (the defender reads it exact). Returns the fortress's hex.
func _siege_of_own_town(progress: int) -> Vector2i:
	var fort := ArmyFixture.NO_HEX
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if Occupation.fortress_level(_g, hex) > 0 and Occupation.controller_tag(_g, hex) == TAG:
			fort = hex
			break
	assert_ne(fort, ArmyFixture.NO_HEX, "Genoa holds a fortress on the 1480 map")
	var enemy := WarFixture.neighbour_of(_g, TAG)
	WarFixture.at_war(_g, enemy, TAG)
	_siege(fort, enemy, progress)
	return fort


## A battle fought on hex last season (a record the battle views read as the newest): the record of BattleView's tests.
func _battle_on(hex: Vector2i) -> BattleRecord:
	var war := CombatFixture.war()
	var fighters := [CombatFixture.pikemen(101, 0), CombatFixture.pikemen(102, 0), CombatFixture.pikemen(201, 1),
		CombatFixture.knights(202, 1)]
	var input := CombatFixture.input_of(war, fighters, 0, false, false)
	for f: Dictionary in fighters:
		for ud: UnitDef in _g.defs.units:
			if String(ud.branch) == str(f["branch"]):
				f["kind"] = ud.id
				break
		f["army"] = 1 if int(f["side"]) == 0 else 2
	input["attacker"] = String(TAG)
	input["defender"] = String(ArmyFixture.other_tag(_g))
	var rng := Rng.new()
	rng.seed_with(1480)
	var before: int = rng.get_state()
	var out: Dictionary = Combat.fight(war, input, rng)
	var r := BattleRecord.new()
	r.id = _g.next_record_id
	_g.next_record_id += 1
	r.turn = _g.turn - 1
	r.hex = hex
	r.name = "Battle of Test, 1479"
	r.year = 1479
	r.attacker = TAG
	r.defender = ArmyFixture.other_tag(_g)
	r.input = input.duplicate(true)
	r.luck_before = before
	r.frames.assign(out["frames"])
	r.end = out["end"]
	r.witnesses = PackedStringArray([String(TAG)])
	_g.battle_records.append(r)
	_g.version += 1
	return r


func _labels_in(box: Node) -> Array[String]:
	var out: Array[String] = []
	for node: Node in box.find_children("*", "Label", true, false):
		out.append((node as Label).text)
	return out


func test_the_land_tab_shows_the_hex_cards_war_rows_without_the_siege_row() -> void:
	var fort := _enemy_fortress()
	_show(fort)
	assert_gt(_labels_in(_box()).size(), 0, "a fortress at war shows its war rows")
	var texts := _labels_in(_box())
	for row: Array in HexCard.war_rows(_g, fort):
		if str(row[0]) == "Siege":
			continue
		assert_true(texts.has(str(row[2])), "the row %s reads its card's words" % str(row[0]))


func test_a_siege_the_viewer_is_in_shows_its_meter_and_forecast() -> void:
	var site := _siege_of_own_town(3)
	_show(site)
	var meter: ProgressBar = null
	# The Town tab's building tiles have bars of their own (issue 436): the siege's is the one named SiegeMeter.
	for node: Node in _box().find_children("SiegeMeter", "ProgressBar", true, false):
		meter = node as ProgressBar
	assert_not_null(meter, "the siege has a meter")
	var v := SiegeView.at(_g, TAG, site)
	assert_eq(int(meter.max_value), int(v.need), "the meter's full mark is the siege's need")
	assert_eq(int(meter.value), mini(3, int(v.need)), "the meter is the siege's progress, up to the need")
	var texts := _labels_in(_box())
	assert_true(texts.any(func(t: String) -> bool: return t.contains("Besieged by")), "its line names the besieger")


func test_a_siege_the_viewer_cannot_read_shows_nothing() -> void:
	var fort := _enemy_fortress()
	var stranger := WarFixture.stranger_of(_g, TAG)
	if stranger == &"":
		pending("no country outside Genoa's borders on this map")
		return
	_siege(fort, stranger, 2)
	_show(fort)
	var texts := _labels_in(_box())
	assert_false(texts.has("Siege"), "a siege between two others is hidden from Genoa")


func test_the_menu_offers_the_battle_fought_on_the_hex() -> void:
	var record := _battle_on(_own)
	assert_true(_menu().open_for(_own, Vector2(10, 10)))
	var found := ""
	for entry: Dictionary in _menu().entries():
		if StringName(entry["action"][0]) == &"battle":
			found = str(entry["label"])
			assert_eq(int(entry["action"][1]), record.id, "the item names the record")
	assert_eq(found, "Open the " + record.name, "the battle's name in the item")


func test_the_menu_offers_the_siege_and_chooses_it() -> void:
	var site := _siege_of_own_town(2)
	assert_true(_menu().open_for(site, Vector2(10, 10)))
	var id := _menu().item_id_of(&"siege")
	assert_ne(id, -1, "a besieged hex offers its siege")
	watch_signals(_menu())
	_menu().id_pressed.emit(id)
	assert_signal_emitted_with_parameters(_menu(), "chosen", [[&"siege", site]])


func test_no_war_items_on_an_unbesieged_own_hex_without_a_war() -> void:
	assert_true(_menu().open_for(_own, Vector2(10, 10)))
	for entry: Dictionary in _menu().entries():
		assert_ne(StringName(entry["action"][0]), &"battle", "no battle here")
		assert_ne(StringName(entry["action"][0]), &"siege", "no siege here")
		assert_ne(StringName(entry["action"][0]), &"castle_area", "no castle area with no war of yours")


func test_the_war_rows_fit_the_window_width() -> void:
	var site := _siege_of_own_town(3)
	_panel.size = Vector2(Tokens.TILE_WINDOW_W, 720)  # the tile window's own width since issue 436 (mockup v4)
	_show(site)
	await get_tree().process_frame
	await get_tree().process_frame
	for node: Node in _box().find_children("*", "Label", true, false):
		var label := node as Label
		if label.visible:
			assert_lte(label.size.x, float(Tokens.TILE_WINDOW_W) + 0.5, "%s is no wider than the panel" % label.text)
	for node: Node in _box().find_children("*", "ProgressBar", true, false):
		assert_lte((node as Control).size.x, float(Tokens.TILE_WINDOW_W) + 0.5, "the meter fits the panel")


func test_the_war_rows_drop_an_occupier_that_is_cleared() -> void:
	var enemy := WarFixture.neighbour_of(_g, TAG)
	WarFixture.set_occupier(_g, _own, enemy)
	_g.version += 1
	_show(_own)
	assert_true(_labels_in(_box()).has("Held by"), "occupied land says who holds it")
	WarFixture.set_occupier(_g, _own, &"")
	_g.version += 1
	var hexes: Array[Vector2i] = [_own]
	Events.controllers_changed.emit(hexes)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(_labels_in(_box()).has("Held by"), "the cleared occupier is gone within a frame")


func test_a_lifted_siege_clears_the_siege_block() -> void:
	var site := _siege_of_own_town(3)
	_show(site)
	assert_eq(_box().find_children("SiegeMeter", "ProgressBar", true, false).size(), 1, "the siege meter is shown")
	_g.sieges.clear()
	_g.version += 1
	Events.siege_lifted.emit(site, TAG, &"lifted")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_box().find_children("SiegeMeter", "ProgressBar", true, false).size(), 0, "a lifted siege has no meter")


func test_a_freed_tile_window_leaves_no_war_listener() -> void:
	var before := Events.controllers_changed.get_connections().size()
	var panel := (load(PANEL) as PackedScene).instantiate() as TileWindow
	panel.theme = KitTheme.load_for(1.0)
	add_child(panel)
	assert_gt(Events.controllers_changed.get_connections().size(), before, "it listens while in the tree")
	remove_child(panel)
	assert_eq(Events.controllers_changed.get_connections().size(), before, "leaving the tree drops its listeners")
	panel.free()
