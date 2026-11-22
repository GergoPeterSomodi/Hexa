## The war marks and the castle-area layer of the map (docs/architecture/m7-build-spec.md 6.3; M7 B25): marks equal the views'
## battle sites and sieges (a hidden battle has no mark), the click requests the battle dock, the gate for the area tint and the
## lines (setting x selection x war), the lines' count against AreaLines, the replay's badges, the refresh on events, the zoom's
## screen size, and the listeners let go when the layer is freed. Every game is WarFixture.game() (copied definitions).
extends GutTest

const FOE := &"SAV"
const FAR := &"MLO"

var _g: Game = null
var _scene: MapScene = null
var _wars: MapWars = null
var _marks: WarMarks = null
var _settings: Settings = null


func before_each() -> void:
	_g = WarFixture.game()
	Session.start_game(_g)
	_settings = Settings.new()
	_scene = (load("res://shell/map/map_scene.tscn") as PackedScene).instantiate() as MapScene
	_scene.preload_next_season = false
	add_child_autofree(_scene)
	_scene.finish_loading()
	_wars = _scene.get_node("MapWars") as MapWars
	_marks = _scene.get_node("WarMarks") as WarMarks
	_wars.configure(_settings)


func after_each() -> void:
	Session.end_game()


## A kept battle record between two countries, fought in the turn before this one, its hex and witnesses given.
func _battle(attacker: StringName, defender: StringName, hex: Vector2i, witnesses: PackedStringArray) -> BattleRecord:
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
	input["attacker"] = String(attacker)
	input["defender"] = String(defender)
	var r := CombatFixture.record_of(war, input, 1480)
	r.id = _g.next_record_id
	_g.next_record_id += 1
	r.turn = _g.turn - 1
	r.hex = hex
	r.attacker = attacker
	r.defender = defender
	r.witnesses = witnesses
	_g.battle_records.append(r)
	_g.version += 1
	return r


func _siege(hex: Vector2i, by: StringName, progress: int, seasons: int) -> void:
	var s := Siege.new()
	s.hex = hex
	s.besieger = by
	s.progress = progress
	s.seasons = seasons
	s.name = "Siege of Test, 1480"
	s.started_turn = _g.turn
	_g.sieges.append(s)
	_g.version += 1


func _own_fortress() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if Occupation.fortress_level(_g, hex) > 0 and Occupation.controller_tag(_g, hex) == ArmyFixture.TAG:
			return hex
	return ArmyFixture.NO_HEX


## An army of the player's on a town, made through the fixture; the version moves as an action does.
func _own_army() -> int:
	var hex := ArmyFixture.find_town(_g)
	var id := ArmyFixture.army(_g, ArmyFixture.TAG, hex, 0, 2).id
	_g.version += 1
	return id


func _seen_battle() -> BattleRecord:
	var hex := ArmyFixture.find_town(_g)
	return _battle(ArmyFixture.TAG, FOE, hex, PackedStringArray([String(ArmyFixture.TAG), String(FOE)]))


# --- marks equal the views ---------------------------------------------------------------------------------------------


func test_marks_equal_the_views_battle_sites_and_sieges() -> void:
	var r := _seen_battle()
	var fortress := _own_fortress()
	assert_ne(fortress, ArmyFixture.NO_HEX, "the player holds a fortress on the 1480 map")
	var enemy := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	WarFixture.at_war(_g, enemy, ArmyFixture.TAG)
	_siege(fortress, enemy, 2, 1)
	_marks.refresh(_g, ArmyFixture.TAG)
	var sites := BattleView.sites(_g, ArmyFixture.TAG)
	var dials := SiegeView.all(_g, ArmyFixture.TAG)
	assert_gt(sites.size(), 0, "the battle is a badge for its witness")
	assert_eq(_marks.mark_count(), sites.size() + dials.size(), "one mark for each site and each dial")
	var mark := _marks.battle_mark(r.id)
	assert_not_null(mark, "the battle's mark exists")
	assert_eq(mark.hex, r.hex)
	assert_eq(mark.tone, sites[0]["tone"], "the ring takes the site's tone")
	assert_eq(_marks.siege_mark(fortress).dial_done, 2, "the dial shows the siege's progress")
	assert_eq(_marks.siege_mark(fortress).need, int(SiegeView.at(_g, ArmyFixture.TAG, fortress)["need"]))


func test_a_hidden_battle_has_no_mark() -> void:
	var hex := ArmyFixture.find_town(_g)
	var hidden := _battle(FAR, FOE, hex, PackedStringArray())
	_marks.refresh(_g, ArmyFixture.TAG)
	for site: Dictionary in BattleView.sites(_g, ArmyFixture.TAG):
		assert_ne(int(site["record"]), hidden.id, "the views hide it from the player")
	assert_null(_marks.battle_mark(hidden.id), "P: a battle the viewer cannot see has no badge")


func test_a_mark_is_removed_when_its_view_goes() -> void:
	var r := _seen_battle()
	_marks.refresh(_g, ArmyFixture.TAG)
	assert_not_null(_marks.battle_mark(r.id))
	_g.battle_records.erase(r)
	_g.version += 1
	_marks.refresh(_g, ArmyFixture.TAG)
	assert_null(_marks.battle_mark(r.id), "a record that is gone takes its badge")


func test_clicking_a_battle_badge_asks_for_the_dock() -> void:
	var r := _seen_battle()
	_marks.refresh(_g, ArmyFixture.TAG)
	var asked: Array[int] = []
	var listen := func(record: int) -> void: asked.append(record)
	Events.battle_mark_clicked.connect(listen)
	var hex := r.hex
	_scene.map_input().select_requested.emit(_scene.view().centre_of(hex))
	Events.battle_mark_clicked.disconnect(listen)
	assert_eq(asked, [r.id], "a click on the badge names the record once")


func test_the_hover_card_is_the_battle_card_and_hides_off_a_mark() -> void:
	var r := _seen_battle()
	_marks.refresh(_g, ArmyFixture.TAG)
	var card := _marks.card_at(r.hex)
	assert_eq(card["hint"], WarCards.HINT_SITE, "the card is WarCards.site")
	assert_true(_wars_card_visible(r.hex), "the hover shows it")
	_scene.map_input().hover_changed.emit(MapInput.NO_HEX)
	assert_false(_wars_card().visible, "and hides when the pointer leaves")


func _wars_card() -> HoverCard:
	return (_wars.get_node("WarCards") as CanvasLayer).get_child(0) as HoverCard


func _wars_card_visible(hex: Vector2i) -> bool:
	_scene.map_input().hover_changed.emit(hex)
	return _wars_card().visible


# --- the replay's badges --------------------------------------------------------------------------------------------------


func test_replay_badges_show_only_what_the_viewer_sees() -> void:
	var hex := ArmyFixture.find_town(_g)
	var marks: Array[Dictionary] = [{"hex": hex, "shown": true}, {"hex": Vector2i(1, 1), "shown": false}]
	_marks.set_replay(marks)
	assert_eq(_marks.mark_count(), 1, "a battle the viewer cannot see is no badge in the replay")
	assert_eq(_marks.mark_at(hex).kind, WarMark.KIND_REPLAY)
	_marks.set_replay([] as Array[Dictionary])
	assert_eq(_marks.mark_count(), 0, "the replay's end takes them away")


# --- the gate ------------------------------------------------------------------------------------------------------------


func test_gate_truth_table_setting_by_selection_by_war() -> void:
	var army := _own_army()
	_armies_sync()
	var foe := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	for setting: bool in [false, true]:
		for selected: bool in [false, true]:
			for at_war: bool in [false, true]:
				_settings.set_value("map/castle_areas", setting)
				_set_war(foe, at_war)
				if selected:
					_armies().select_army(army)
				else:
					_armies().clear_army()
				var expected := setting and selected and at_war
				assert_eq(_wars.area_gate(), expected, "gate setting %s selected %s war %s" % [setting, selected, at_war])
				assert_eq(_scene.overlay().is_areas_on(), expected, "the tint follows the gate")
				assert_eq(_wars.areas_on(), expected)
	_set_war(foe, false)
	_armies().clear_army()


func _armies() -> MapArmies:
	return _scene.get_node("MapArmies") as MapArmies


func _armies_sync() -> void:
	_armies().sync()


## The player at war with `foe` (on) or at peace (off): one live war at a time.
func _set_war(foe: StringName, on: bool) -> void:
	_g.wars.clear()
	if on:
		WarFixture.at_war(_g, ArmyFixture.TAG, foe)
	_g.version += 1


func test_the_area_lines_count_equals_area_lines() -> void:
	var army := _own_army()
	var foe := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	WarFixture.at_war(_g, ArmyFixture.TAG, foe)
	_g.version += 1
	_settings.set_value("map/castle_areas", true)
	_armies().select_army(army)
	_wars.finish_areas()
	var expected := 0
	for cy: int in ceili(float(_g.map.rows) / float(EdgeLines.CHUNK)):
		for cx: int in ceili(float(_g.map.cols) / float(EdgeLines.CHUNK)):
			expected += AreaLines.for_chunk(_g, ArmyFixture.TAG, Vector2i(cx, cy)).size()
	var drawn := 0
	for chunk: Vector2i in _scene.view().area_chunks():
		drawn += (_scene.view().get_node("Areas").get_node_or_null("Areas_%d_%d" % [chunk.x, chunk.y]) as EdgeLineLayer).line_count()
	assert_gt(expected, 0, "a war with a neighbour of a standing fortress draws lines")
	assert_eq(drawn, expected, "every line of AreaLines is drawn once")


func test_the_lines_go_when_the_gate_goes() -> void:
	var army := _own_army()
	var foe := WarFixture.neighbour_of(_g, ArmyFixture.TAG)
	WarFixture.at_war(_g, ArmyFixture.TAG, foe)
	_g.version += 1
	_settings.set_value("map/castle_areas", true)
	_armies().select_army(army)
	_wars.finish_areas()
	assert_gt(_scene.view().area_chunks().size(), 0)
	_settings.set_value("map/castle_areas", false)
	assert_eq(_scene.view().area_chunks().size(), 0, "the setting off frees the lines")
	assert_false(_scene.overlay().is_areas_on())


# --- the events, the zoom and the layer's life ----------------------------------------------------------------------------


func test_a_battle_event_refreshes_the_marks() -> void:
	assert_eq(_marks.mark_count(), 0, "no battle yet")
	var r := _seen_battle()
	Events.battle_ended.emit(r.hex, r.id, FOE)
	assert_not_null(_marks.battle_mark(r.id), "battle_ended puts the badge up")


func test_marks_keep_their_screen_size_below_zoom_point_six() -> void:
	var r := _seen_battle()
	_marks.refresh(_g, ArmyFixture.TAG)
	_marks.set_zoom(0.3)
	assert_almost_eq(_marks.battle_mark(r.id).scale.x, 2.0, 0.001, "twice the size at a third of the zoom")
	_marks.set_zoom(1.0)
	assert_almost_eq(_marks.battle_mark(r.id).scale.x, 1.0, 0.001)


func test_the_layer_is_under_the_selection_and_over_the_lines() -> void:
	assert_eq(_marks.z_index, 89, "WarMarks sits at z 89")
	assert_eq((_scene.view().get_node("Areas") as Node2D).z_index, 82, "the castle areas sit at z 82")


func test_freeing_the_layer_lets_go_of_its_listeners() -> void:
	var before := Events.battle_ended.get_connections().size()
	_scene.remove_child(_wars)
	_wars.free()
	assert_lt(Events.battle_ended.get_connections().size(), before, "the war layer no longer listens to the battle")


class FakeReplay extends MoveReplay:
	var on := false
	var hexes: Array[Vector2i] = []

	func active() -> bool:
		return on

	func battle_hexes() -> Array[Vector2i]:
		return hexes

	func marks() -> Array[Dictionary]:
		return []


# --- review fixes (B25): fog, the newest record, one card per hex, the replay's hold -------------------------------------


func test_a_lifted_siege_flashes_only_where_the_viewer_sees() -> void:
	var unseen := ArmyFixture.NO_HEX
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if not Knowledge.sees(_g, ArmyFixture.TAG, hex):
			unseen = hex
			break
	assert_ne(unseen, ArmyFixture.NO_HEX, "the map has a hex the player does not see")
	var before := _marks.get_child_count()
	_wars._on_siege_lifted(unseen, FOE, &"lifted")
	assert_eq(_marks.get_child_count(), before, "P: no flash on a hex the viewer cannot see")
	_wars._on_siege_lifted(unseen, ArmyFixture.TAG, &"lifted")
	assert_eq(_marks.get_child_count(), before + 1, "the viewer's own lifted siege flashes anywhere")
	var seen := ArmyFixture.find_town(_g)
	assert_true(Knowledge.sees(_g, ArmyFixture.TAG, seen), "the town is seen")
	_wars._on_siege_lifted(seen, FOE, &"lifted")
	assert_eq(_marks.get_child_count(), before + 2, "a seen hex flashes")


func test_men_lost_takes_the_newest_record_where_the_viewer_has_a_side() -> void:
	var hex := ArmyFixture.find_town(_g)
	var witnesses := PackedStringArray([String(ArmyFixture.TAG), String(FOE)])
	var old := _battle(ArmyFixture.TAG, FOE, hex, witnesses)
	old.turn = _g.turn - 1
	old.end["killed"] = PackedInt32Array([200, 0])
	old.end["wounded_total"] = PackedInt32Array([33, 0])
	var now := _battle(ArmyFixture.TAG, FOE, hex, witnesses)
	now.turn = _g.turn
	now.end["killed"] = PackedInt32Array([100, 0])
	now.end["wounded_total"] = PackedInt32Array([22, 0])
	var foreign := _battle(FAR, FOE, hex, PackedStringArray())
	foreign.turn = _g.turn
	_g.version += 1
	assert_eq(MapWars.men_lost(_g, ArmyFixture.TAG, hex), 122, "the newest record this season: 100 killed, 22 wounded")
	_g.battle_records.erase(now)
	_g.version += 1
	assert_eq(MapWars.men_lost(_g, ArmyFixture.TAG, hex), 233, "without it, last season's record counts")


func test_one_card_per_hex_the_war_card_at_a_mark_and_the_move_card_with_an_army() -> void:
	var r := _seen_battle()
	_marks.refresh(_g, ArmyFixture.TAG)
	var hover := MapHover.new()
	add_child_autofree(hover)
	hover.on_hover_changed(r.hex)
	hover._show_current()
	assert_false(hover.is_card_visible(), "the war card owns a mark's hex: no plain hex card there")
	assert_true(_wars_card_visible(r.hex), "the war card shows on the mark")
	_armies().select_army(_own_army())
	assert_false(hover.war_mark_at(r.hex), "with an army selected the war card yields")
	assert_false(_wars_card_visible(r.hex), "and MapWars hides its card: the move card owns the hover")


func test_a_battle_badge_waits_for_the_running_replay() -> void:
	var r := _seen_battle()
	var fake := FakeReplay.new()
	add_child_autofree(fake)
	_wars._on_war_event()
	assert_not_null(_marks.battle_mark(r.id), "no replay: the badge is up")
	fake.on = true
	fake.hexes = [r.hex] as Array[Vector2i]
	_wars._process(0.0)
	assert_null(_marks.battle_mark(r.id), "P: a running replay holds the site badge, no spoiler")
	fake.on = false
	fake.hexes = [] as Array[Vector2i]
	_wars._process(0.0)
	assert_not_null(_marks.battle_mark(r.id), "the badge comes up when the replay ends")
