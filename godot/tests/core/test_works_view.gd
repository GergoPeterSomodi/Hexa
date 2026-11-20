## WorksView (docs/architecture/m3-build-spec.md 4.3, 5.6, 9): labels, `at`, `ready_turn` across a winter, slots,
## `last_begun`, `seasons_of`, `of_country`.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const DEFS_PATH := "res://data/defs/game_defs.tres"
const ALPHA := Vector2i(0, 2)
const ALPHA_2 := Vector2i(0, 3)

var _next_id := 1


func _italy() -> Game:
	var defs := load(DEFS_PATH) as GameDefs
	var scenario: ScenarioDef = null
	for s: ScenarioDef in defs.scenarios:
		scenario = s
	return Game.new_scenario(load(MAP_PATH) as MapData, defs, scenario, 1480)


func _work(game: Game, action: StringName, family: int, level_to: int, hex: Vector2i, seasons: int,
		tag: StringName = &"GEN") -> Work:
	var w := Work.new()
	w.id = _next_id
	_next_id += 1
	w.tag = tag
	w.hex = hex
	w.action = action
	w.family = family
	w.level_to = level_to
	w.started_turn = game.turn
	w.seasons = seasons
	w.seasons_left = seasons
	game.state.works.append(w)
	return w


func _fixture() -> Game:
	var g := ScenarioFixture.game()
	for hex: Vector2i in [ALPHA, ALPHA_2]:
		g.improvement.clear(hex)
	g.act("choose_country", {"tag": &"AAA"})
	return g


func test_labels() -> void:
	var g := _italy()
	var build := _work(g, Works.BUILD, ImproveRules.VINEYARD, 1, Vector2i(7, 12), 4)
	assert_eq(WorksView.label(g, build), "vineyard, first stage")
	var town := _work(g, Works.UPGRADE, ImproveRules.SETTLEMENT, 5, Vector2i(8, 13), 8)
	assert_eq(WorksView.label(g, town), "walled town to city")
	var stage := _work(g, Works.UPGRADE, ImproveRules.VINEYARD, 2, Vector2i(3, 3), 8)
	assert_eq(WorksView.label(g, stage), "vineyard, first to second stage")
	var clear := _work(g, Works.CLEAR, ImproveRules.VINEYARD, 0, Vector2i(4, 4), 1)
	assert_eq(WorksView.label(g, clear), "clearing the vineyard")
	var castle := _work(g, Works.UPGRADE, ImproveRules.CASTLE, 3, Vector2i(5, 5), 16)
	assert_eq(WorksView.label(g, castle), "castle to fortress")


func test_line_adds_the_place() -> void:
	var g := _italy()
	var w := _work(g, Works.BUILD, ImproveRules.VINEYARD, 1, Vector2i(7, 12), 4)
	assert_eq(WorksView.line(g, w), "vineyard, first stage, near Savona (7, 12)")
	var town := _work(g, Works.UPGRADE, ImproveRules.SETTLEMENT, 5, Vector2i(8, 13), 8)
	assert_eq(WorksView.line(g, town), "walled town to city, Genoa (8, 13)")


func test_at_progress_and_ready() -> void:
	var g := _italy()
	assert_eq(WorksView.at(g, Vector2i(7, 12)), {}, "none without a work")
	var w := _work(g, Works.BUILD, ImproveRules.VINEYARD, 1, Vector2i(7, 12), 4)
	var info := WorksView.at(g, Vector2i(7, 12))
	assert_eq(info["label"], "vineyard, first stage")
	assert_eq(info["tag"], &"GEN")
	assert_eq(info["progress"], "1 of 4 seasons")
	assert_eq(info["ready"], "Spring 1481")
	assert_eq(info["ready_turn"], 5)
	assert_false(bool(info["halted"]))
	assert_eq(info["started_turn"], 1)
	w.seasons_left = 1
	g.turn = 4
	assert_eq(WorksView.at(g, Vector2i(7, 12))["progress"], "4 of 4 seasons")


func test_ready_turn_across_a_winter() -> void:
	var g := _italy()
	var frost := _work(g, Works.BUILD, ImproveRules.VINEYARD, 1, Vector2i(7, 12), 4)
	assert_eq(WorksView.ready_turn(g, frost), 5, "frost climate: no halt, Spring 1481")
	g.turn = 2
	var snow := _work(g, Works.BUILD, ImproveRules.TIMBER, 1, Vector2i(9, 11), 4)
	assert_eq(WorksView.ready_turn(g, snow), 7, "Autumn 1481, not Summer 1481: Winter 1480 halts it")
	var town := _work(g, Works.UPGRADE, ImproveRules.SETTLEMENT, 5, Vector2i(8, 13), 8)
	g.turn = 1
	town.started_turn = 1
	assert_eq(WorksView.ready_turn(g, town), 9, "mild climate: Spring 1482")


func test_halted_in_the_current_winter() -> void:
	var g := _italy()
	g.turn = 4
	var snow := _work(g, Works.BUILD, ImproveRules.TIMBER, 1, Vector2i(9, 11), 4)
	snow.seasons_left = 3
	var info := WorksView.at(g, Vector2i(9, 11))
	assert_true(bool(info["halted"]), "P: Winter on a snow hex")
	assert_eq(info["ready"], "Winter 1481", "waits out Winter 1480, then 3 seasons")
	var frost := _work(g, Works.BUILD, ImproveRules.VINEYARD, 1, Vector2i(7, 12), 4)
	assert_false(bool(WorksView.at(g, frost.hex)["halted"]), "frost is not halted")


func test_slots_of_country_and_last_begun() -> void:
	var g := _fixture()
	assert_eq(WorksView.slots(g, &"AAA"), {"used": 0, "total": Works.slots(g, &"AAA")})
	assert_eq(WorksView.last_begun(g, &"AAA"), WorksView.NO_HEX)
	assert_true(bool(g.act("build", {"hex": ALPHA, "family": ImproveRules.WHEAT, "tag": &"AAA"})["ok"]))
	assert_eq(WorksView.last_begun(g, &"AAA"), ALPHA)
	assert_eq(WorksView.slots(g, &"AAA")["used"], 1)
	var total := int(WorksView.slots(g, &"AAA")["total"])
	if total < 0 or total > 1:
		assert_true(bool(g.act("build", {"hex": ALPHA_2, "family": ImproveRules.WHEAT, "tag": &"AAA"})["ok"]))
		assert_eq(WorksView.last_begun(g, &"AAA"), ALPHA_2, "the newest")
		assert_eq(WorksView.of_country(g, &"AAA").size(), 2)
	assert_eq(WorksView.of_country(g, &"BBB").size(), 0)
	Season.run(g)
	assert_eq(WorksView.last_begun(g, &"AAA"), WorksView.NO_HEX, "none begun this turn")


func test_slots_without_countries_have_no_limit() -> void:
	var g := Game.new_game(ImproveFixture.block(5, 5, {}), 1, load(DEFS_PATH) as GameDefs)
	assert_eq(WorksView.slots(g, &"")["total"], -1)


func test_seasons_of() -> void:
	var g := _fixture()
	assert_eq(WorksView.seasons_of(g, Works.BUILD, ALPHA, ImproveRules.WHEAT), 4)
	assert_eq(Words.seasons(WorksView.seasons_of(g, Works.BUILD, ALPHA, ImproveRules.WHEAT)), "4 seasons")
	g.improvement.build_on(ALPHA, ImproveRules.WHEAT)
	assert_eq(WorksView.seasons_of(g, Works.UPGRADE, ALPHA), 8, "to level 2")
	assert_eq(WorksView.seasons_of(g, Works.CLEAR, ALPHA), 1)
	g.improvement.upgrade(ALPHA)
	assert_eq(WorksView.seasons_of(g, Works.UPGRADE, ALPHA), 16, "to level 3")
