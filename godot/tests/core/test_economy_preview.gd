## EconomyPreview (docs/architecture/m4-build-spec.md 4.17, 5.6, 9): `with(game, tag, {}, 8)` equals eight played seasons for
## every country of the 1480 scenario (calm weather), works under way stand from their ready turns, a tax change, `expected`,
## `worth_by_hex`, both measures, and a preview never changes the game.
extends GutTest

@warning_ignore_start("integer_division")

const VINEYARD := ImproveRules.VINEYARD
const WINE := 3


func _lines_of(lines: Array) -> Dictionary:
	var out := {}
	for line: Dictionary in lines:
		if Treasury.SPENDING.has(line["why"]) or line["why"] == &"dev":
			continue  # the player's choices and the console, not the season's income
		var key := "%s|%d,%d" % [line["why"], (line["hex"] as Vector2i).x, (line["hex"] as Vector2i).y]
		out[key] = int(line["amount"])
	return out


func _flow(c: Country, why: StringName, sign_of: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for g: int in c.stock.size():
		out.append(Stores.flow(c, g, why, true) * sign_of)
	return out


## Plays `count` seasons and checks every country's preview (made before the game moves) against what happened.
func _check_against_play(g: Game, count: int, label: String) -> void:
	var previews := {}
	for c: Country in g.countries:
		previews[c.tag] = EconomyPreview.with(g, c.tag, {}, count)
	for k: int in count:
		assert_true(bool(Season.run(g)["ok"]))
		for c: Country in g.countries:
			var p: Dictionary = (previews[c.tag]["seasons"] as Array)[k]
			var where := "%s %s season %d" % [label, String(c.tag), k + 1]
			assert_eq(int(p["turn"]), g.turn - 1, where + " turn")
			assert_eq(_flow(c, &"made", 1), p["made"], where + " made")
			assert_eq(_flow(c, &"used", -1), p["used"], where + " used")
			assert_eq(_flow(c, &"sold", -1), p["sold"], where + " sold")
			assert_eq(c.stock, p["stock"], where + " stock")
			assert_eq(_lines_of(c.ledger_closed["lines"] as Array), _lines_of(p["lines"] as Array), where + " money lines")
			var closed: Array[Dictionary] = []
			closed.assign(c.ledger_closed["lines"] as Array)
			assert_eq(Treasury.left_over(closed), int(p["net"]), where + " net")


func test_eight_seasons_equal_play_for_every_country() -> void:
	var g := EconomyFixture.game(&"GEN")
	assert_gt(g.countries.size(), 10)
	_check_against_play(g, 8, "plain")


func test_eight_seasons_with_works_under_way_and_a_tax() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var begun := 0
	for c: Country in g.countries:
		g.dev_money(c.tag, 5000)
		for n: int in 6:
			var districts := Territory.districts(g, c.id)
			if districts.is_empty():
				break
			var hex := g.map.hex_of(districts[rng.randi_range(0, districts.size() - 1)])
			for row: Dictionary in ImprovePreview.options_of(g, c.tag, hex):
				if bool(row["verdict"]["ok"]):
					g.act(String(row["action"]), {"hex": hex, "family": row["family"], "tag": c.tag})
					begun += 1
					break
		if c.tag == &"GEN":
			g.act("set_tax", {"level": 2, "tag": c.tag})
	assert_gt(begun, 5, "works were begun")
	assert_gt(g.state.works.size(), 3)
	_check_against_play(g, 8, "works")


func test_a_work_stands_from_its_ready_turn() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var verdict := g.act("build", {"hex": EconomyFixture.VINEYARD_HEX, "family": VINEYARD, "tag": &"GEN"})
	assert_true(bool(verdict["ok"]))
	var seasons: Array = EconomyPreview.with(g, &"GEN", {}, 8)["seasons"]
	assert_eq((seasons[2]["made"] as PackedInt32Array)[WINE], 0, "autumn 1480: the vineyard is not there yet")
	assert_eq((seasons[6]["made"] as PackedInt32Array)[WINE], 12, "autumn 1481: the first vintage")
	var upkeep_before: int = _lines_of(seasons[3]["lines"] as Array)["upkeep_districts|-1,-1"]
	var upkeep_after: int = _lines_of(seasons[4]["lines"] as Array)["upkeep_districts|-1,-1"]
	assert_eq(upkeep_after - upkeep_before, -1, "upkeep from Spring 1481")


func test_a_change_stands_from_the_first_season_and_both_measures_come() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var i := g.map.index_of(EconomyFixture.VINEYARD_HEX)
	var base := EconomyPreview.with(g, &"GEN", {}, 4)
	var after := EconomyPreview.with(g, &"GEN", {"hexes": {i: Vector2i(VINEYARD, 1)}}, 4)
	assert_eq(int(after["year"]["realm"]) - int(base["year"]["realm"]), 22)
	assert_eq(int(after["year"]["net"]) - int(base["year"]["net"]), 10)
	assert_eq(int(base["year"]["realm"]), 511)
	for k: int in 4:
		assert_true((after["seasons"][k] as Dictionary).has("net"))
		assert_true((after["seasons"][k] as Dictionary).has("realm"))


func test_a_tax_change_equals_the_real_one() -> void:
	var g := EconomyFixture.game(&"GEN")
	var preview := EconomyPreview.with(g, &"GEN", {"tax": 2}, 4)
	var real := EconomyFixture.game(&"GEN")
	assert_true(bool(real.act("set_tax", {"level": 2, "tag": &"GEN"})["ok"]))
	var c := Countries.by_tag(real, &"GEN")
	for k: int in 4:
		Season.run(real)
		assert_eq(_lines_of(c.ledger_closed["lines"] as Array), _lines_of((preview["seasons"][k] as Dictionary)["lines"] as Array), "season %d" % k)
	assert_ne(int(EconomyPreview.with(g, &"GEN", {}, 4)["year"]["net"]), int(preview["year"]["net"]))
	assert_eq(Countries.by_tag(g, &"GEN").tax, 1, "the game's tax stays")


func test_expected_is_the_first_season() -> void:
	var g := EconomyFixture.game(&"GEN")
	var first := EconomyPreview.expected(g, &"GEN")
	assert_eq(first, (EconomyPreview.with(g, &"GEN", {}, 1)["seasons"] as Array)[0])
	assert_eq(int(first["net"]), 86)
	assert_eq(EconomyPreview.expected(g, &"NOPE"), {})
	assert_eq((EconomyPreview.with(g, &"NOPE", {}, 4)["seasons"] as Array).size(), 0)


func test_a_preview_never_changes_the_game() -> void:
	var g := EconomyFixture.game(&"GEN", true)
	var digest := g.digest()
	var version := g.version
	var turn := g.turn
	var i := g.map.index_of(EconomyFixture.VINEYARD_HEX)
	EconomyPreview.with(g, &"GEN", {"hexes": {i: Vector2i(VINEYARD, 1)}, "tax": 0, "detail": true}, 8)
	EconomyPreview.worth_by_hex(g, &"GEN")
	assert_eq(g.digest(), digest)
	assert_eq(g.version, version)
	assert_eq(g.turn, turn)
	assert_eq(Countries.by_tag(g, &"GEN").stock[WINE], 4)


func test_a_map_only_game_has_nothing() -> void:
	var d := EconomyFixture.defs()
	var g := Game.new_game(EconomyFixture.map(), 5, d)
	assert_eq((EconomyPreview.with(g, &"GEN", {}, 4)["seasons"] as Array).size(), 0)


func test_the_baseline_is_cached_by_version() -> void:
	var g := EconomyFixture.game(&"GEN")
	var a := EconomyPreview.baseline(g, &"GEN", 4, 1)
	assert_true(is_same(a, EconomyPreview.baseline(g, &"GEN", 4, 1)), "the same array")
	g.version += 1
	assert_false(is_same(a, EconomyPreview.baseline(g, &"GEN", 4, 1)), "a new version makes it again")


func test_worth_by_hex_follows_4_17() -> void:
	var g := EconomyFixture.game(&"GEN")
	var rows := EconomyPreview.worth_by_hex(g, &"GEN")
	assert_true(is_same(rows, EconomyPreview.worth_by_hex(g, &"GEN")), "cached")
	var genoa := {}
	for row: Dictionary in rows:
		if row["hex"] == Vector2i(8, 13):
			genoa = row
	assert_false(genoa.is_empty())
	# fish 6 at 1.0, dues 30, people 30,000 x 1,000 x 1,000 / 1,000 x 1,000 / 10^9 = 30, less upkeep 2 and walls 4.
	var fish_price := g.defs.goods[Economy.FISH].price_milli
	assert_eq(int(genoa["worth"]), 6 * fish_price / 1000 + 30 + 30 - 6)
	assert_eq(int(genoa["upkeep"]), 6)
	assert_eq(genoa["label"], "Genoa (8, 13)")
	var total := 0
	for row: Dictionary in rows:
		total += int(row["worth"])
	assert_gt(total, 0)
