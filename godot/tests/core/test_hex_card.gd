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
	var beta_card := HexCard.of(game, ScenarioFixture.BETA_CAPITAL)
	assert_eq(_find_line(beta_card["lines"] as Array, "Owner"), ["Owner", &"plain", "Duchy of Beta"])
	var unowned_after := HexCard.of(game, ScenarioFixture.UNOWNED_HEXES[0])
	assert_eq(_find_line(unowned_after["lines"] as Array, "Owner"), ["Owner", &"plain", "no one"])
	var sea_after := HexCard.of(game, ScenarioFixture.SEA_HEX)
	assert_null(_find_line(sea_after["lines"] as Array, "Owner"))


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
