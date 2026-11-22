## GUT tests for the Military page of the Statesman's Study (docs/architecture/m6-build-spec.md 6.9, 9; L21): the player's
## armies from ArmyFixture (Genoa on seed 1480 with a town of its own), the head line, the table's rows, Look there and Show on
## the map, the two charts and their "No data yet." before a season, the foreign armies in sight (banded, no ids), the span in
## the settings, the digest unchanged by the page, the pages of the nav from milestone six, and the fit at 1280 x 720.
extends GutTest

const SCENE := "res://shell/screens/study/page_military.tscn"
const STUDY_SCENE := "res://shell/screens/study.tscn"
const NO_DATA := "No data yet."
const NO_ARMY_PREFIX := "You have no army."
const NO_SEEN := "No foreign army in sight."

var _harness: UIHarness = null
var _root: Control = null
var _requests: Array[Array] = []
var _g: Game = null


func before_each() -> void:
	Bindings.reset_defaults()
	_harness = UIHarness.new()
	_harness.mount(self)
	_root = Control.new()
	_root.theme = KitTheme.load_for(1.0)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_harness.viewport.add_child(_root)
	_requests = []
	_g = ArmyFixture.game()


func after_each() -> void:
	if _harness != null:
		_harness.stack.clear()
	_root = null
	_harness = null
	_g = null
	Bindings.reset_defaults()


func _page(game: Game, milestone: String = "6") -> PageMilitary:
	var page := (load(SCENE) as PackedScene).instantiate() as PageMilitary
	page.milestone = milestone
	page.action_requested.connect(func(action: Array) -> void: _requests.append(action))
	_root.add_child(page)
	page.refresh(game, &"open")
	return page


func _own(page: PageMilitary) -> StudyTable:
	return page.find_child("Table", true, false) as StudyTable


func _label(page: PageMilitary, node: String) -> Label:
	return page.find_child(node, true, false) as Label


func _cells(table: StudyTable, row: int) -> Array:
	var item := table.tree().get_root().get_child(row)
	var out: Array = []
	for c: int in range(table.tree().columns):
		out.append(item.get_text(c))
	return out


func _button(page: PageMilitary, node: String) -> KitButton:
	return page.find_child(node, true, false) as KitButton


func _town() -> Vector2i:
	return ArmyFixture.find_town(_g)


func test_no_army_says_where_to_raise_one() -> void:
	var page := _page(_g)
	assert_true(_label(page, "Head").text.begins_with(NO_ARMY_PREFIX), _label(page, "Head").text)
	assert_true(_label(page, "NoArmy").visible)
	assert_eq(_own(page).total_count(), 0)
	assert_true(_button(page, "Look").disabled)
	assert_true(_button(page, "ShowOnMap").disabled)


func test_head_says_men_armies_companies_and_upkeep() -> void:
	var army := ArmyFixture.army(_g, ArmyFixture.TAG, _town(), 0, 2)
	var page := _page(_g)
	var head := _label(page, "Head").text
	assert_true(head.begins_with("%s in 1 army, 2 companies; upkeep " % Words.men(army.men())), head)
	assert_true(head.ends_with(" of your income."), head)
	assert_false(_label(page, "NoArmy").visible)


func test_the_table_lists_the_armies_with_their_men_and_companies() -> void:
	var army := ArmyFixture.army(_g, ArmyFixture.TAG, _town(), 0, 2)
	var table := _own(_page(_g))
	assert_eq(table.total_count(), 1)
	var cells := _cells(table, 0)
	assert_eq(cells[0], army.name)
	assert_eq(cells[2], Words.number(army.men()))
	assert_eq(cells[3], "2")
	assert_eq(table.column_header(0), "Army")


func test_look_there_and_show_on_the_map_use_the_selected_row() -> void:
	ArmyFixture.army(_g, ArmyFixture.TAG, _town(), 0, 1)
	var page := _page(_g)
	assert_eq(page.selected_row()["hex"], _town(), "the first row is selected")
	_button(page, "Look").pressed.emit()
	assert_eq(_requests[0], [&"look_at", _town()])
	_button(page, "ShowOnMap").pressed.emit()
	assert_eq(_requests[1], [&"map_mode", &"supply", _town()])
	_own(page).row_activated.emit({"id": page.selected_row()["id"], "hex": _town()})
	assert_eq(_requests[2], [&"look_at", _town()])


func test_the_charts_have_their_series_and_wait_for_a_season() -> void:
	ArmyFixture.army(_g, ArmyFixture.TAG, _town(), 0, 1)
	var page := _page(_g)
	for chart_name: String in ["UpkeepChart", "LossesChart"]:
		assert_false((page.find_child(chart_name, true, false) as Control).visible, chart_name)
	assert_eq(page.find_children("NoData", "Label", true, false).size(), 2, "one 'No data yet.' under each chart")
	assert_eq(_label(page, "NoData").text, NO_DATA)
	Season.run(_g)
	page.refresh(_g, &"season_ended")
	var upkeep := page.find_child("UpkeepChart", true, false) as InkChart
	assert_true(upkeep.visible)
	assert_eq(upkeep.kind, InkChart.Kind.LINE_BARS)
	assert_true(upkeep.summary().contains("Army upkeep"), upkeep.summary())
	assert_true(upkeep.summary().contains("Left-over income"), upkeep.summary())
	var losses := page.find_child("LossesChart", true, false) as InkChart
	assert_eq(losses.kind, InkChart.Kind.STACKED_BAR)
	assert_true(losses.summary().contains("Men lost, a season"), losses.summary())
	assert_true(losses.summary().contains("1 point"), "one season of points: %s" % losses.summary())


func test_foreign_armies_in_sight_show_the_empty_line_without_any() -> void:
	var page := _page(_g)
	assert_true(_label(page, "NoSeen").visible)
	assert_eq(_label(page, "NoSeen").text, NO_SEEN)


## The first country other than the player's that the player knows (a neighbour or explored), or &"".
func _known_foreign() -> StringName:
	for c: Country in _g.countries:
		if c != null and c.tag != &"" and c.tag != ArmyFixture.TAG and Knowledge.knows(_g, ArmyFixture.TAG, c.tag):
			return c.tag
	return &""


## A foreign army on the player's own town (in sight): one row, its men banded, no army id and no orders in the text.
func test_a_foreign_army_in_sight_is_banded_and_has_no_id() -> void:
	var foreign := _known_foreign()
	assert_ne(foreign, &"", "a country Genoa knows")
	ArmyFixture.army(_g, foreign, _town(), 0, 3)
	var page := _page(_g)
	var tables := page.find_children("Table", "StudyTable", true, false)
	assert_eq(tables.size(), 2, "the own table and the foreign one")
	var seen := tables[1] as StudyTable
	assert_eq(seen.total_count(), 1)
	assert_false(_label(page, "NoSeen").visible)
	var cells := _cells(seen, 0)
	assert_true(str(cells[2]).begins_with("about "), "banded: %s" % str(cells[2]))
	for cell: Variant in cells:
		assert_false(str(cell).contains("#"), "no army id: %s" % str(cell))
	assert_true(seen.column_header(0).begins_with("Country"), seen.column_header(0))


func test_the_span_is_read_from_and_written_to_the_settings() -> void:
	var page := (load(SCENE) as PackedScene).instantiate() as PageMilitary
	page.settings = _harness.settings
	_root.add_child(page)
	page.refresh(_g, &"open")
	(page.find_child("Span", true, false) as Segmented).select(40, true)
	assert_eq(int(_harness.settings.get_value("state/study_span")), 40)
	assert_eq(page.span, 40)


func test_refresh_leaves_the_digest_and_the_version_alone() -> void:
	ArmyFixture.army(_g, ArmyFixture.TAG, _town(), 0, 1)
	var page := _page(_g)
	var digest := _g.digest()
	var version := _g.version
	page.refresh(_g, &"open")
	page.refresh(_g, &"season_ended")
	_button(page, "Look").pressed.emit()
	assert_eq(_g.digest(), digest)
	assert_eq(_g.version, version)


func test_no_player_is_the_empty_page() -> void:
	var page := _page(null)
	assert_eq(_own(page).total_count(), 0)
	assert_true(_button(page, "Look").disabled)
	_button(page, "Look").pressed.emit()
	assert_true(_requests.is_empty())


func test_five_pages_from_milestone_six_with_military_after_economy() -> void:
	var ids: Array = []
	for entry: Dictionary in StudyPages.shown("6"):
		ids.append(entry["id"])
	assert_eq(ids, [&"economy", &"military", &"people", &"rankings", &"history"])
	var five: Array = []
	for entry: Dictionary in StudyPages.shown("5"):
		five.append(entry["id"])
	assert_false(five.has(&"military"), "not before its milestone")


func test_the_study_opens_the_page_and_brackets_step_to_it() -> void:
	var study := (load(STUDY_SCENE) as PackedScene).instantiate() as Study
	study.configure(StudyPages.shown("6"), "6")
	_harness.stack.push(study)
	study.open_page(&"military")
	assert_eq(study.current_page_id(), &"military")
	assert_true(study.current_page() is PageMilitary)
	assert_eq(study.nav().button_for(&"military").text, "Military")
	_harness.send_key(KEY_BRACKETRIGHT)
	assert_eq(study.current_page_id(), &"people", "[ steps to the next page")
	_harness.send_key(KEY_BRACKETLEFT)
	assert_eq(study.current_page_id(), &"military", "[ steps back")
	assert_eq((study.current_page() as PageMilitary).settings, _harness.ctx.settings)


func test_fits_at_1280_by_720() -> void:
	var harness := UIHarness.new(Vector2i(1280, 720))
	harness.mount(self)
	var root := Control.new()
	root.theme = KitTheme.load_for(1.0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	harness.viewport.add_child(root)
	ArmyFixture.army(_g, ArmyFixture.TAG, _town(), 0, 2)
	Season.run(_g)
	var host := Control.new()
	host.size = Vector2(1020.0, 720.0)
	root.add_child(host)
	var page := (load(SCENE) as PackedScene).instantiate() as PageMilitary
	page.milestone = "6"
	host.add_child(page)
	page.size = host.size
	page.refresh(_g, &"open")
	await harness.wait_frames(self, 2)
	assert_lte(page.get_combined_minimum_size().x, host.size.x, "no horizontal overflow")
	harness.dispose()


# ----- M7 (B27): the Wars and Battles tables ----------------------------------------------------------------------------


func _war_table(page: PageMilitary) -> StudyTable:
	return page.find_child("WarTable", true, false) as StudyTable


func _battle_table(page: PageMilitary) -> StudyTable:
	return page.find_child("BattleTable", true, false) as StudyTable


## A battle record fought by Genoa against `defender` (as test_battle_dock makes one), kept in the game.
func _battle(defender: StringName) -> BattleRecord:
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
	input["attacker"] = String(ArmyFixture.TAG)
	input["defender"] = String(defender)
	var rng := Rng.new()
	rng.seed_with(1480)
	var before: int = rng.get_state()
	var out: Dictionary = Combat.fight(war, input, rng)
	var r := BattleRecord.new()
	r.id = _g.next_record_id
	_g.next_record_id += 1
	r.turn = _g.turn
	r.hex = ArmyFixture.find_town(_g)
	r.name = "Battle of Test, 1480"
	r.year = 1480
	r.attacker = ArmyFixture.TAG
	r.defender = defender
	r.input = input.duplicate(true)
	r.luck_before = before
	r.frames.assign(out["frames"])
	r.end = out["end"]
	r.witnesses = PackedStringArray()
	_g.battle_records.append(r)
	return r


func test_a_war_row_asks_for_its_country_and_the_empty_state_clears() -> void:
	var enemy := ArmyFixture.other_tag(_g)
	var page := _page(_g)
	assert_true(_label(page, "NoWar").visible, "no war yet")
	WarFixture.at_war(_g, ArmyFixture.TAG, enemy)
	_g.version += 1
	page.refresh(_g, &"open")
	assert_false(_label(page, "NoWar").visible, "a war is listed")
	assert_eq(_war_table(page).total_count(), 1, "one war row")
	_war_table(page).row_activated.emit({"request": [&"country", enemy]})
	assert_eq(_requests.back(), [&"country", enemy], "Go asks for the enemy's country")


func test_a_battle_row_asks_for_its_record() -> void:
	var r := _battle(ArmyFixture.other_tag(_g))
	_g.version += 1
	var page := _page(_g)
	assert_false(_label(page, "NoBattle").visible, "a battle is listed")
	assert_eq(_battle_table(page).total_count(), 1, "one battle row")
	_battle_table(page).row_activated.emit({"request": [&"battle", r.id]})
	assert_eq(_requests.back(), [&"battle", r.id], "Open asks for the battle dock at the record")
