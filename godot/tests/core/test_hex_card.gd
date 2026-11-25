## Tests for HexCard (core/views/hex_card.gd, docs/architecture/ui-and-controls-spec.md sections 3.5, 7 and 9):
## every land and sea hex of north Italy produces a complete card, specific hexes (sea, place, pass, rivers/roads/crossings)
## and build/upgrade/clear state changes are reflected in the card and its lines, and out-of-bounds or null inputs return {}.
extends GutTest

const MAP_PATH := "res://data/maps/north_italy.tres"
const START_SEED := 1480

var _map: MapData = null
var _game: Game = null


func before_all() -> void:
	_map = load(MAP_PATH) as MapData
	_game = Game.new_game(_map, START_SEED)


func test_out_of_bounds_or_null_returns_empty_card() -> void:
	assert_eq(HexCard.of(null, Vector2i(0, 0)), {})
	var empty_game := Game.new()
	assert_eq(HexCard.of(empty_game, Vector2i(0, 0)), {})
	assert_eq(HexCard.of(_game, Vector2i(-1, 0)), {})
	assert_eq(HexCard.of(_game, Vector2i(0, -1)), {})
	assert_eq(HexCard.of(_game, Vector2i(999, 999)), {})
	assert_eq(HexCard.of(_game, Vector2i(_map.cols, 0)), {})
	assert_eq(HexCard.of(_game, Vector2i(0, _map.rows)), {})


func test_every_hex_of_north_italy_gives_a_complete_card() -> void:
	assert_eq(_map.cols, 21)
	assert_eq(_map.rows, 19)
	assert_eq(_map.hex_count(), 399)
	var land_count := 0
	var sea_count := 0
	for i: int in _map.hex_count():
		var hex := _map.hex_of(i)
		var card := HexCard.of(_game, hex)
		assert_false(card.is_empty(), "hex %s card is not empty" % [hex])
		assert_eq(card["hex"], hex)
		assert_ne(str(card["title"]), "", "hex %s has a title" % [hex])
		assert_ne(str(card["subtitle"]), "", "hex %s has a subtitle" % [hex])
		assert_true(str(card["subtitle"]).begins_with("(%d, %d)" % [hex.x, hex.y]))
		assert_ne(str(card["cover"]), "", "hex %s has cover or depth" % [hex])
		assert_true(HexCard.RELIEF_WORDS.has(str(card["relief"])), "valid relief word for %s" % [hex])
		assert_true(HexCard.CLIMATE_WORDS.has(str(card["climate"])), "valid climate word for %s" % [hex])
		assert_ne(str(card["rivers"]), "")
		assert_ne(str(card["roads"]), "")
		assert_ne(str(card["crossings"]), "")
		var lines: Array = card["lines"]
		assert_gt(lines.size(), 0, "hex %s has hover lines" % [hex])
		for row: Variant in lines:
			assert_typeof(row, TYPE_ARRAY)
			var arr: Array = row
			assert_eq(arr.size(), 3, "each line is [text, tone, amount]")
		if bool(card["is_land"]):
			land_count += 1
			assert_true(HexCard.COVER_WORDS.has(str(card["cover"])))
		else:
			sea_count += 1
			assert_true(HexCard.DEPTH_WORDS.has(str(card["cover"])))
			assert_eq(int(card["height_m"]), 0)
			assert_eq(str(card["relief"]), "sea")
			assert_true((card["piece"] as Dictionary).is_empty())
	assert_gt(land_count, 0)
	assert_gt(sea_count, 0)
	assert_eq(land_count + sea_count, 399)


func test_sea_hex_card_has_depth_and_no_piece() -> void:
	var sea_hex := Vector2i(-1, -1)
	for i: int in _map.hex_count():
		if _map.land[i] == 0:
			sea_hex = _map.hex_of(i)
			break
	assert_ne(sea_hex, Vector2i(-1, -1))
	var card := HexCard.of(_game, sea_hex)
	assert_false(bool(card["is_land"]))
	assert_eq(str(card["title"]), "Sea (%d, %d)" % [sea_hex.x, sea_hex.y])
	assert_eq(str(card["subtitle"]), "(%d, %d) · Sea" % [sea_hex.x, sea_hex.y])
	assert_true(HexCard.DEPTH_WORDS.has(str(card["cover"])))
	assert_eq(int(card["height_m"]), 0)
	assert_eq(str(card["place"]), "")
	assert_eq(str(card["pass_name"]), "")
	assert_eq(card["piece"], {})


func test_place_pass_and_edge_hexes() -> void:
	var milan_hex := Vector2i(-1, -1)
	var genoa_hex := Vector2i(-1, -1)
	for place: Dictionary in _map.places:
		var pname := str(place.get("name", ""))
		if pname == "Milan" or pname == "Milano":
			milan_hex = place["hex"] as Vector2i
		elif pname == "Genoa" or pname == "Genova":
			genoa_hex = place["hex"] as Vector2i
	assert_ne(milan_hex, Vector2i(-1, -1), "Milan is on the map")
	var milan := HexCard.of(_game, milan_hex)
	assert_true(bool(milan["is_land"]))
	assert_eq(str(milan["title"]), "Milan")
	assert_eq(str(milan["place"]), "Milan")
	assert_true(str(milan["subtitle"]).contains("capital"))
	assert_false((milan["piece"] as Dictionary).is_empty())

	assert_ne(genoa_hex, Vector2i(-1, -1), "Genoa is on the map")
	var genoa := HexCard.of(_game, genoa_hex)
	assert_eq(str(genoa["title"]), "Genoa")
	assert_true(str(genoa["subtitle"]).contains("port"))

	assert_gt(_map.passes.size(), 0, "north Italy has passes")
	var pass_hex := Vector2i(-1, -1)
	for i: int in _map.hex_count():
		if _map.pass_id[i] >= 0:
			pass_hex = _map.hex_of(i)
			break
	assert_ne(pass_hex, Vector2i(-1, -1))
	var pass_card := HexCard.of(_game, pass_hex)
	assert_ne(str(pass_card["pass_name"]), "")
	assert_true(str(pass_card["pass_name"]).contains("m)"))
	assert_true(str(pass_card["subtitle"]).contains("pass"))

	var with_river := 0
	var with_road := 0
	var with_crossing := 0
	for i: int in _map.hex_count():
		var card := HexCard.of(_game, _map.hex_of(i))
		if str(card["rivers"]) != "none":
			with_river += 1
		if str(card["roads"]) != "none":
			with_road += 1
		if str(card["crossings"]) != "none":
			with_crossing += 1
	assert_gt(with_river, 0, "some hexes report rivers with directions")
	assert_gt(with_road, 0, "some hexes report roads with directions")
	assert_gt(with_crossing, 0, "some hexes report crossings with directions")


func test_build_upgrade_and_clear_update_card_and_lines() -> void:
	var game := Game.new_game(_map, START_SEED, load("res://data/defs/game_defs.tres") as GameDefs)
	var target_hex := Vector2i(-1, -1)
	var target_family := -1
	for i: int in _map.hex_count():
		var hex := _map.hex_of(i)
		if not _map.is_land(hex) or not Improve.piece_at(game, hex).is_empty():
			continue
		for option: Dictionary in Improve.build_options(game, hex):
			if bool(option["ok"]):
				target_hex = hex
				target_family = int(option["family_id"])
				break
		if target_family >= 0:
			break
	assert_ne(target_hex, Vector2i(-1, -1), "found a buildable wild hex")

	var before := HexCard.of(game, target_hex)
	assert_eq(before["piece"], {})
	assert_false(_has_rule_line(before["lines"] as Array), "wild hex has no rule separator")

	var built := game.act("build", {"hex": target_hex, "family": target_family})
	assert_true(bool(built["ok"]))
	_until_stands(game, target_hex)
	var after_build := HexCard.of(game, target_hex)
	assert_false((after_build["piece"] as Dictionary).is_empty())
	assert_eq(int((after_build["piece"] as Dictionary)["level"]), 1)
	assert_true(_has_rule_line(after_build["lines"] as Array), "built hex has a rule separator before piece rows")

	var up_check := game.check("upgrade", {"hex": target_hex})
	if bool(up_check["ok"]):
		var upgraded := game.act("upgrade", {"hex": target_hex})
		assert_true(bool(upgraded["ok"]))
		_until_stands(game, target_hex)
		var after_upgrade := HexCard.of(game, target_hex)
		assert_eq(int((after_upgrade["piece"] as Dictionary)["level"]), 2)

	var cleared := game.act("clear", {"hex": target_hex})
	assert_true(bool(cleared["ok"]))
	_until_stands(game, target_hex)
	var after_clear := HexCard.of(game, target_hex)
	assert_eq(after_clear["piece"], {})
	assert_false(_has_rule_line(after_clear["lines"] as Array))


## Plays seasons until the work on `hex` is done (a work takes up to 16 seasons, winters excepted).
func _until_stands(game: Game, hex: Vector2i) -> void:
	var guard := 0
	while game.state.work_at(hex) != null and guard < 40:
		Season.run(game)
		guard += 1
	assert_null(game.state.work_at(hex), "the work on %s stands" % hex)


func test_edge_and_crossing_summaries_on_fixture_map() -> void:
	var map := MapData.new()
	map.allocate(4, 4)
	var hex := Vector2i(1, 1)
	map.land[map.index_of(hex)] = 1
	map.cover[map.index_of(hex)] = 0
	map.river[map.edge_index(hex, 0)] = 2  # E
	map.river[map.edge_index(hex, 2)] = 1  # NW
	map.road[map.edge_index(hex, 0)] = 3   # E highway
	map.road[map.edge_index(hex, 4)] = 2   # SW road
	map.crossing[map.edge_index(hex, 0)] = 3  # E stone bridge
	assert_eq(HexCard.edge_summary(map, hex, "river"), "river (E, NW)")
	assert_eq(HexCard.edge_summary(map, hex, "road"), "highway (E), road (SW)")
	assert_eq(HexCard.crossing_summary(map, hex), "stone bridge (E)")
	assert_eq(HexCard.ground_rows(map, hex).size(), 5)
	assert_eq(HexCard.piece_rows({}).size(), 1)


func test_owner_line_in_scenario_and_map_only_games() -> void:
	# Map-only game has no Owner line.
	var sandbox_card := HexCard.of(_game, Vector2i(9, 9))
	assert_eq(str(sandbox_card["owner"]), "")
	assert_null(_find_line(sandbox_card["lines"] as Array, "Owner"), "map-only game omits Owner line")

	var game := ScenarioFixture.game()
	# Before player choice: owned land shows long name without ', yours'; unowned shows 'no one'; sea omits it.
	var alpha_before := HexCard.of(game, ScenarioFixture.ALPHA_CAPITAL)
	assert_eq(_find_line(alpha_before["lines"] as Array, "Owner"), ["Owner", &"plain", "Republic of Alpha"])
	var unowned_card := HexCard.of(game, ScenarioFixture.UNOWNED_HEXES[0])
	assert_eq(_find_line(unowned_card["lines"] as Array, "Owner"), ["Owner", &"plain", "no one"])
	var sea_card := HexCard.of(game, ScenarioFixture.SEA_HEX)
	assert_null(_find_line(sea_card["lines"] as Array, "Owner"), "sea hex omits Owner line")

	# After choosing AAA: AAA land gets ', yours'; BBB land does not.
	assert_true(bool(game.act("choose_country", {"tag": &"AAA"})["ok"]))
	var alpha_yours := HexCard.of(game, ScenarioFixture.ALPHA_CAPITAL)
	assert_eq(_find_line(alpha_yours["lines"] as Array, "Owner"), ["Owner", &"plain", "Republic of Alpha, yours"])
	# Fog build (R18, D18): AAA has not discovered Beta's capital, so its card says "Unexplored" and names no owner (P).
	var beta_card := HexCard.of(game, ScenarioFixture.BETA_CAPITAL)
	assert_eq(beta_card["title"], "Unexplored", "an undiscovered hex")
	assert_null(_find_line(beta_card["lines"] as Array, "Owner"), "an undiscovered hex has no Owner line")
	# Once AAA has discovered it (its explored bit set, as a walk would), the owner shows again.
	var bits := FogFixture.grown(game, &"AAA", 0)
	var idx := game.map.index_of(ScenarioFixture.BETA_CAPITAL)
	bits[idx >> 3] = bits[idx >> 3] | (1 << (idx & 7))
	Countries.by_tag(game, &"AAA").explored = bits
	game.sight.clear()
	Sight.refresh(game)
	game.version += 1
	beta_card = HexCard.of(game, ScenarioFixture.BETA_CAPITAL)
	assert_eq(_find_line(beta_card["lines"] as Array, "Owner"), ["Owner", &"plain", "Duchy of Beta"])
	var unowned_after := HexCard.of(game, ScenarioFixture.UNOWNED_HEXES[0])
	assert_eq(_find_line(unowned_after["lines"] as Array, "Owner"), ["Owner", &"plain", "no one"])
	var sea_after := HexCard.of(game, ScenarioFixture.SEA_HEX)
	assert_null(_find_line(sea_after["lines"] as Array, "Owner"))


func test_work_line_and_its_halted_form() -> void:
	var defs := load("res://data/defs/game_defs.tres") as GameDefs
	var game := Game.new_game(_map, START_SEED, defs)
	var hex := Vector2i(7, 12)
	var plain := HexCard.of(game, hex)
	assert_null(_find_line(plain["lines"] as Array, "Work"), "none without a work")
	game.state.works.append(_work(1, hex, ImproveRules.VINEYARD, 1, 4))
	var line: Variant = _find_line(HexCard.of(game, hex)["lines"] as Array, "Work")
	assert_eq(line, ["Work", &"warn", "vineyard, first stage: 1 of 4 seasons, ready Spring 1481"])
	var snow := Vector2i(9, 11)
	game.turn = 4
	game.state.works.append(_work(2, snow, ImproveRules.TIMBER, 1, 3))
	var halted: Variant = _find_line(HexCard.of(game, snow)["lines"] as Array, "Work")
	assert_eq(halted, ["Work", &"warn", "timber, first stage: stopped for the winter, ready Winter 1481"])


func _work(id: int, hex: Vector2i, family: int, level_to: int, left: int) -> Work:
	var w := Work.new()
	w.id = id
	w.hex = hex
	w.action = Works.BUILD
	w.family = family
	w.level_to = level_to
	w.started_turn = 1
	w.seasons = 4
	w.seasons_left = left
	return w


## M7 (6.8): occupied land reads "Held by the <occupier> since <season>", the season of the newest capture by that occupier.
func test_held_by_row_gives_the_capture_season() -> void:
	var g := ArmyFixture.game()
	var enemy := WarFixture.neighbour_of(g, ArmyFixture.TAG)
	var hex := ArmyFixture.find_town(g)
	WarFixture.set_occupier(g, hex, enemy)
	g.chronicle.add({"kind": "district_captured", "hex": hex, "tag": String(enemy), "turn": g.turn})
	var text := ""
	for row: Array in HexCard.war_rows_for(g, g.player, hex):
		if str(row[0]) == "Held by":
			text = str(row[2])
	assert_true(text.begins_with("the "), "the occupier's long name: %s" % text)
	assert_true(text.ends_with(" since " + Calendar.date_text(g.turn, g.start_year)), text)


func _find_line(lines: Array, label: String) -> Variant:
	for row: Variant in lines:
		var arr: Array = row
		if arr.size() >= 1 and str(arr[0]) == label:
			return arr
	return null


func _has_rule_line(lines: Array) -> bool:
	for row: Variant in lines:
		var arr: Array = row
		if arr.size() >= 2 and StringName(arr[1]) == &"rule":
			return true
	return false


func test_gives_line_of_the_genoa_vineyard() -> void:
	var game := EconomyFixture.game(&"GEN")
	var hex := EconomyFixture.VINEYARD_HEX
	var card := HexCard.of(game, hex)
	assert_eq(str(card["gives"]), "wine 24 in autumn · upkeep 2 a season")
	assert_eq(_find_line(card["lines"] as Array, "Gives"), ["Gives", &"plain", "wine 24 in autumn · upkeep 2 a season"])
	assert_eq(str(card["weather"]), "", "calm weather gives no Weather line")
	assert_null(_find_line(card["lines"] as Array, "Weather"))


func test_weather_line_follows_the_hexes_climate() -> void:
	var game := EconomyFixture.game(&"GEN")
	var hex := EconomyFixture.VINEYARD_HEX
	var climate := clampi(int(game.map.climate[game.map.index_of(hex)]), 0, 2)
	game.weather[climate] = 2
	assert_eq(str(HexCard.of(game, hex)["weather"]), "poor this season: crops −25 %")
	assert_eq(_find_line(HexCard.of(game, hex)["lines"] as Array, "Weather"),
		["Weather", &"plain", "poor this season: crops −25 %"])
	game.weather[climate] = 1
	assert_eq(str(HexCard.of(game, hex)["weather"]), "good this season: crops +20 %")
	# Another climate's weather does not reach this hex.
	game.weather[climate] = 0
	game.weather[(climate + 1) % 3] = 2
	assert_eq(str(HexCard.of(game, hex)["weather"]), "")


func test_wild_hex_gives_its_grain_over_the_year() -> void:
	var game := EconomyFixture.game(&"GEN", true)
	var gives := str(HexCard.of(game, EconomyFixture.VINEYARD_HEX)["gives"])
	assert_true(gives.begins_with("grain "), "wild land gives grain: " + gives)
	assert_true(gives.ends_with(" a year (wild)"), gives)


func test_no_gives_or_weather_without_countries_or_at_sea() -> void:
	assert_eq(str(HexCard.of(_game, Vector2i(9, 9))["gives"]), "")
	assert_eq(str(HexCard.of(_game, Vector2i(9, 9))["weather"]), "")
	var game := EconomyFixture.game(&"GEN")
	var sea := Vector2i(-1, -1)
	for i: int in EconomyFixture.map().hex_count():
		if EconomyFixture.map().land[i] == 0:
			sea = EconomyFixture.map().hex_of(i)
			break
	assert_ne(sea, Vector2i(-1, -1))
	assert_eq(str(HexCard.of(game, sea)["gives"]), "")
	assert_eq(str(HexCard.of(game, sea)["weather"]), "")


func test_worth_line_of_genoa_and_others() -> void:
	var game := EconomyFixture.game(&"GEN")
	var card := HexCard.of(game, InsightsFixture.GENOA_HEX)
	assert_eq(_find_line(card["lines"] as Array, "Worth"), ["Worth", &"good", "+232 a year (+60 this season)"])
	var vineyard := HexCard.of(game, EconomyFixture.VINEYARD_HEX)
	assert_eq(_find_line(vineyard["lines"] as Array, "Worth"), ["Worth", &"good", "+68 a year (+2 this season)"])


func test_worth_line_none_on_milan_sea_and_map_only() -> void:
	var game := EconomyFixture.game(&"GEN")
	var milan := Countries.by_tag(game, &"MLO")
	var checked := 0
	for i: int in game.map.hex_count():
		if game.map.land[i] != 0 and int(game.state.owner[i]) == milan.id:
			assert_null(_find_line(HexCard.of(game, game.map.hex_of(i))["lines"] as Array, "Worth"), "Milan hex %d" % i)
			checked += 1
			if checked >= 5:
				break
	assert_gt(checked, 0)
	for i: int in game.map.hex_count():
		if game.map.land[i] == 0:
			assert_null(_find_line(HexCard.of(game, game.map.hex_of(i))["lines"] as Array, "Worth"), "sea has no Worth")
			break
	assert_null(_find_line(HexCard.of(_game, Vector2i(9, 9))["lines"] as Array, "Worth"), "map-only game")
	var no_player := EconomyFixture.game()
	assert_null(_find_line(HexCard.of(no_player, InsightsFixture.GENOA_HEX)["lines"] as Array, "Worth"), "no chosen player")


func test_worth_line_wild_land_and_a_loss() -> void:
	var wild := EconomyFixture.game(&"GEN", true)
	var line: Variant = _find_line(HexCard.of(wild, EconomyFixture.VINEYARD_HEX)["lines"] as Array, "Worth")
	assert_not_null(line, "wild land of yours has a Worth line")
	assert_true(str((line as Array)[2]).contains(" a year ("), str(line))
	var row := HexCard.worth_row(wild, EconomyFixture.VINEYARD_HEX)
	var worth := EconomyPreview.worth_seasons(wild, &"GEN", 4)
	var values: PackedInt32Array = worth["worth"]
	var h := (worth["hexes"] as PackedInt32Array).find(wild.map.index_of(EconomyFixture.VINEYARD_HEX))
	var year := 0
	for k: int in 4:
		year += values[h * 4 + k]
	assert_eq(row[1], &"good" if year > 0 else (&"bad" if year < 0 else &"plain"))
	assert_eq(row[2], "%s a year (%s this season)" % [Words.signed(year), Words.signed(values[h * 4])])


func test_people_and_food_lines_of_genoa() -> void:
	var game := PeopleFixture.genoa()
	var genoa := HexCard.of(game, Vector2i(8, 13))
	var people: Variant = _find_line(genoa["lines"] as Array, "People")
	assert_not_null(people)
	assert_eq((people as Array)[2], "30,000 · room 45,000")
	var food: Variant = _find_line(genoa["lines"] as Array, "Food")
	assert_not_null(food, "Genoa makes fish and eats")
	var year := MapModes.food_year(game, &"GEN", Vector2i(8, 13))
	assert_eq((food as Array)[2], "made %d, eaten %d a year" % [year.x, year.y])
	assert_eq(year, Vector2i(22, 12))
	for row: Variant in genoa["lines"] as Array:
		assert_eq((row as Array).size(), 3)
	Season.run(game)
	assert_eq((_find_line(HexCard.of(game, Vector2i(8, 13))["lines"] as Array, "People") as Array)[2],
		"30,300 · room 45,000 · ▲ +300")


## Fog build (R18): a discovered foreign hex's people line is exact, not banded (the whole of north Italy is discovered).
func test_people_line_of_a_discovered_foreign_hex_is_exact_and_no_food() -> void:
	var game := PeopleFixture.genoa()
	var milan := Countries.by_tag(game, &"MLO")
	var france := Countries.by_tag(game, &"FRA")
	var seen_milan := false
	var seen_france := false
	for i: int in game.map.hex_count():
		if game.map.land[i] == 0:
			continue
		var lines := HexCard.of(game, game.map.hex_of(i))["lines"] as Array
		if int(game.state.owner[i]) == milan.id and not seen_milan and game.state.people[i] > 0:
			seen_milan = true
			var row: Variant = _find_line(lines, "People")
			if row != null:
				assert_eq(str((row as Array)[2]), Words.number(int(game.state.people[i])), "known: exact")
			assert_null(_find_line(lines, "Food"), "no food line on foreign land")
		if int(game.state.owner[i]) == france.id and not seen_france:
			seen_france = true
			var france_row: Variant = _find_line(lines, "People")
			if france_row != null:
				assert_eq(str((france_row as Array)[2]), Words.number(int(game.state.people[i])), "France: discovered, exact")
	assert_true(seen_milan and seen_france)


func test_no_people_line_at_sea_or_in_a_map_only_game() -> void:
	var game := PeopleFixture.genoa()
	for i: int in game.map.hex_count():
		if game.map.land[i] == 0:
			assert_null(_find_line(HexCard.of(game, game.map.hex_of(i))["lines"] as Array, "People"))
			break
	assert_null(_find_line(HexCard.of(_game, Vector2i(9, 9))["lines"] as Array, "People"))


## Fog build (R18, D18): an undiscovered hex's card is the title "Unexplored" and nothing else; a named place is not told (P).
func test_an_undiscovered_hex_reads_unexplored_and_nothing_else() -> void:
	var game := PeopleFixture.genoa()
	FogFixture.thin(game, &"GEN", 0)
	var deep := 0
	var placed := 0
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if Knowledge.discovered(game, &"GEN", hex):
			continue
		deep += 1
		var card := HexCard.of(game, hex)
		assert_eq(card["title"], "Unexplored", "the title")
		assert_eq((card["lines"] as Array).size(), 0, "nothing else is shown")
		assert_eq(str(card["owner"]), "", "no owner")
		assert_eq(str(card["place"]), "", "no place name")
		var place_name := str(Improve.place_of(game.map, hex).get("name", ""))
		if place_name != "":
			placed += 1
			assert_ne(card["title"], place_name, "P: a place name is not shown")
	assert_gt(deep, 0, "the thin fixture leaves hexes undiscovered")
	assert_gt(placed, 0, "an undiscovered hex with a place name exists")


## TW1: the viewer's fog decides the war rows (war_rows_for); a viewer that has discovered nothing gets none on an occupied hex.
func test_war_rows_for_reads_the_viewer_not_the_player() -> void:
	var g := ArmyFixture.game()
	var hex := ArmyFixture.find_town(g)
	WarFixture.set_occupier(g, hex, WarFixture.neighbour_of(g, ArmyFixture.TAG))
	assert_false(HexCard.war_rows(g, hex).is_empty(), "the player sees the occupation")
	assert_true(HexCard.war_rows_for(g, &"NOBODY", hex).is_empty(), "a viewer with no discovery gets no rows")

## Fog build (R19, D6): a light-fog fortress shows its garrison exact, never rounded or "a garrison".
func test_a_light_fog_fortress_shows_its_garrison_exact() -> void:
	var game := PeopleFixture.genoa()
	FogFixture.thin(game, &"GEN", 2)
	var light := 0
	for i: int in game.map.hex_count():
		var hex := game.map.hex_of(i)
		if Occupation.fortress_level(game, hex) <= 0 or not Knowledge.discovered(game, &"GEN", hex) \
				or Knowledge.sees(game, &"GEN", hex):
			continue
		light += 1
		var text := ""
		for row: Array in HexCard.war_rows_for(game, game.player, hex):
			if str(row[0]) == "Fortress":
				text = str(row[2])
		var expect := "garrison %d of %d" % [Occupation.garrison_of(game, hex), Occupation.garrison_full(game, hex)]
		assert_true(text.ends_with(expect), "exact: " + text)
		assert_false(text.contains("about") or text.contains("a garrison"), "no rounding: " + text)
	assert_gt(light, 0, "a light-fog fortress on the thin fixture")


## Fog build (R21): a light-fog siege reads "Besieged" with the progress and the need, and names no besieger; the holder
## and the besieger see it exact.
func test_a_light_fog_siege_reads_besieged_and_names_no_besieger() -> void:
	var g := ArmyFixture.game()
	var hex := ArmyFixture.find_town(g)
	var holder := Occupation.controller_tag(g, hex)
	var besieger := WarFixture.neighbour_of(g, holder)
	assert_ne(besieger, &"", "a neighbour of the holder exists")
	WarFixture.at_war(g, besieger, holder)
	var s := Siege.new()
	s.hex = hex
	s.besieger = besieger
	s.name = "Siege of Test, 1480"
	g.sieges.append(s)
	for c: Country in g.countries:
		if c != null and c.tag != &"":
			FogFixture.thin(g, c.tag, 0)
	var viewer := &""
	for c: Country in g.countries:
		if c != null and c.tag != &"" and c.tag != holder and c.tag != besieger:
			viewer = c.tag
			break
	assert_ne(viewer, &"", "a third country exists")
	var bits := FogFixture.grown(g, viewer, 0)
	var idx := g.map.index_of(hex)
	bits[idx >> 3] = bits[idx >> 3] | (1 << (idx & 7))
	Countries.by_tag(g, viewer).explored = bits
	g.sight.clear()
	Sight.refresh(g)
	g.version += 1
	assert_true(Knowledge.discovered(g, viewer, hex), "precondition: the viewer has discovered the hex")
	assert_false(Knowledge.sees(g, viewer, hex), "precondition: and does not see it")
	g.player = viewer
	var siege_text := _siege_row(g, hex)
	assert_eq(siege_text, "Siege of Test, 1480: Besieged, %d of %d" % [s.progress, Occupation.siege_need(g, hex)])
	assert_false(siege_text.contains(String(besieger)), "P: no besieger named")
	g.player = holder
	assert_true(_siege_row(g, hex).contains("besieged by"), "the holder sees it exact")


func _siege_row(g: Game, hex: Vector2i) -> String:
	for row: Array in HexCard.war_rows_for(g, g.player, hex):
		if str(row[0]) == "Siege":
			return str(row[2])
	return ""
