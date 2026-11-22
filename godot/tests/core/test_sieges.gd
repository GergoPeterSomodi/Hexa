## Sieges (docs/architecture/m7-build-spec.md 4.4, 4.5, 4.11, D18, 5.3): the terms of a siege, the seasons table's plain-ground
## cells (a watchtower, a castle and a fortress on plain ground), the meters and falls, the lift order (storm silent, peace,
## relief, left, outnumbered), the besieged hunger through the People door, the freed land (D18), regrowth, the walk-in, the
## retake and the loader. The plain-ground fortresses are made in a copy of the 1480 map (the shared map is never written):
## the relief of the chosen hex is set to 0. Every test makes its own game.
@warning_ignore_start("integer_division")
extends GutTest

var WATCH := Vector2i(-1, -1)
var CASTLE := Vector2i(-1, -1)
var KEEP := Vector2i(-1, -1)
var WATCH_OWNER := &""
var CASTLE_OWNER := &""
var KEEP_OWNER := &""


## A game with a plain watchtower (level 1), castle (2) and fortress (3) of the map, each held by its owner.
func _game() -> Game:
	var g := EconomyFixture.game()
	var plain := g.map.duplicate() as MapData
	WATCH = _lowest_fortress(g, 1)
	CASTLE = _lowest_fortress(g, 2)
	KEEP = _lowest_fortress(g, 3)
	for hex: Vector2i in [WATCH, CASTLE, KEEP]:
		if hex != Army.NO_HEX:
			plain.relief[plain.index_of(hex)] = 0
	g.map = plain
	Occupation.setup(g)
	WATCH_OWNER = Occupation.controller_tag(g, WATCH)
	CASTLE_OWNER = Occupation.controller_tag(g, CASTLE)
	KEEP_OWNER = Occupation.controller_tag(g, KEEP)
	return g


## The fortress of `level` that its owner holds on the lowest relief (the first in hex index order among ties); NO_HEX when none.
func _lowest_fortress(g: Game, level: int) -> Vector2i:
	var best := Army.NO_HEX
	var best_relief := 99
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if Occupation.fortress_level(g, hex) != level or Occupation.controller_tag(g, hex) == &"":
			continue
		var relief := int(g.map.relief[i])
		if relief < best_relief:
			best_relief = relief
			best = hex
	return best


## A country at war with `tag` through a live war, made by the fixture; its tag.
func _enemy_at_war(g: Game, tag: StringName) -> StringName:
	var enemy := WarFixture.neighbour_of(g, tag)
	assert_ne(enemy, &"", "the owner has a neighbour to fight")
	WarFixture.at_war(g, enemy, tag)
	return enemy


## Companies of pikemen (500 men each) of `tag` on `hex`.
func _pikemen(g: Game, tag: StringName, hex: Vector2i, companies: int) -> Army:
	return ArmyFixture.army(g, tag, hex, g.defs.units[0].id, companies)


## Runs sieges.season until the hex changes hands (or `cap` seasons pass); the seasons run, or -1.
func _seasons_to_fall(g: Game, hex: Vector2i, cap: int = 60) -> int:
	var owner := Occupation.controller_tag(g, hex)
	for k: int in range(1, cap + 1):
		Sieges.season(g)
		if Occupation.controller_tag(g, hex) != owner:
			return k
	return -1


func _events(g: Game, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in g.events:
		if e.get("kind", "") == kind:
			out.append(e)
	return out


func _captures(g: Game) -> Array[Dictionary]:
	return _events(g, "district_captured")


## The reason of the last siege_lifted event in the game, or &"".
func _lift_why(g: Game) -> StringName:
	var lifts := _events(g, "siege_lifted")
	return lifts.back()["why"] if not lifts.is_empty() else &""


## The first land hex of `tag` with open ground (no fortress covers it) that is not a fortress, or NO_HEX.
func _open_hex_of(g: Game, tag: StringName) -> Vector2i:
	var id := Countries.by_tag(g, tag).id
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if g.map.land[i] == 1 and int(g.state.owner[i]) == id and Occupation.fortress_level(g, hex) == 0 \
				and Occupation.area_state(g, hex) == &"open":
			return hex
	return Army.NO_HEX


## The first walled town (a settlement of fortress level `level`) held by its owner, or NO_HEX.
func _settlement_fortress(g: Game, level: int) -> Vector2i:
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if int(g.state.main_use[i]) == People.SETTLEMENTS and Occupation.fortress_level(g, hex) == level \
				and Occupation.controller_tag(g, hex) != &"":
			return hex
	return Army.NO_HEX


func test_crowd_and_rate_follow_the_men_and_the_guns() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	var garrison := Occupation.garrison_full(g, WATCH)
	var t := Sieges.terms(g, WATCH, enemy, 1000, 0)
	assert_eq(int(t["crowd"]), 2, "1,000 men at a full garrison of %d is crowd 2 (under 4x)" % garrison)
	assert_eq(int(t["rate"]), 2, "crowd 2 with no guns moves 2 a season")
	assert_eq(int(Sieges.terms(g, WATCH, enemy, garrison + 100, 0)["crowd"]), 1, "under 2x the garrison is crowd 1")
	assert_eq(int(Sieges.terms(g, WATCH, enemy, garrison - 1, 0)["rate"]), 0, "under the garrison there is no siege")
	assert_eq(int(Sieges.terms(g, WATCH, enemy, 1000, 1)["rate"]), 3, "a gun adds to the crowd")
	assert_eq(int(t["need"]), 7, "a plain watchtower needs 4 + 3 = 7 (the table's need)")
	assert_eq(int(Sieges.terms(g, CASTLE, enemy, 800, 0)["need"]), 10, "a plain castle needs 4 + 6 = 10")
	assert_eq(int(Sieges.terms(g, KEEP, enemy, 1200, 0)["need"]), 13, "a plain fortress needs 4 + 9 = 13")
	assert_eq(int(t["stores"]), 2, "a watchtower's stores last 1 + level seasons")


## The seasons table, plain ground, full garrisons: each cell is a fall in the forecast's season, and the forecast is the
## table's number (4.5: 3 for 2 companies at a watchtower; 6 at a castle; 7 and 6 for 4 and 8 companies at a fortress; 4 for 6
## pikemen and 2 bombards with 2 guns).
func test_the_seasons_table_on_plain_ground() -> void:
	# [fortress level, companies of pikemen, the seasons the table gives]
	var cells := [[1, 2, 3], [2, 2, 6], [3, 4, 7], [3, 8, 6]]
	for cell: Array in cells:
		var g := _game()
		var hex := _lowest_fortress(g, int(cell[0]))
		var enemy := _enemy_at_war(g, Occupation.controller_tag(g, hex))
		_pikemen(g, enemy, hex, int(cell[1]))
		var men := Armies.men_of_country(g, enemy)
		var forecast := Sieges.forecast(g, hex, enemy, men, 0, 0, 0)
		assert_eq(forecast, int(cell[2]), "%d companies at a level %d fortress fall in %d seasons" % [int(cell[1]), int(cell[0]), int(cell[2])])
		assert_eq(_seasons_to_fall(g, hex), forecast, "and the siege falls in that season")
	var g := _game()
	var enemy := _enemy_at_war(g, KEEP_OWNER)
	_pikemen(g, enemy, KEEP, 6)
	ArmyFixture.army(g, enemy, KEEP, g.defs.units[3].id, 2)
	assert_eq(Armies.men_of_country(g, enemy), 3200, "six pikemen and two bombards are 3,200 men")
	assert_eq(Sieges.terms(g, KEEP, enemy)["guns"], 2, "two bombard batteries are 2 guns")
	assert_eq(Sieges.forecast(g, KEEP, enemy, 3200, 2, 0, 0), 4, "6 pikemen and 2 bombards fall in 4 seasons")
	assert_eq(_seasons_to_fall(g, KEEP), 4, "and the siege falls in the fourth season")


func test_forecast_is_the_season_the_fall_comes() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	_pikemen(g, enemy, WATCH, 2)
	assert_eq(Sieges.forecast(g, WATCH, enemy, 300, 0, 0, 0), -1, "too few men never take it")


func test_a_watchtower_falls_to_two_companies_and_books_the_garrison() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	var garrison := Occupation.garrison_of(g, WATCH)
	_pikemen(g, enemy, WATCH, 2)
	Sieges.season(g)
	assert_eq(Occupation.siege_at(g, WATCH).seasons, 1, "the arrival season counts")
	assert_eq(Occupation.controller_tag(g, WATCH), WATCH_OWNER, "still held after the first season")
	_seasons_to_fall(g, WATCH)
	assert_eq(Occupation.controller_tag(g, WATCH), enemy, "the besieger holds the watchtower")
	assert_null(Occupation.siege_at(g, WATCH), "a fallen siege is removed")
	var captures := _captures(g)
	assert_eq(captures.size(), 1, "one district captured")
	assert_eq(captures[0]["by"], &"siege")
	assert_eq(int(captures[0]["garrison_lost"]), garrison, "the garrison's men are booked lost")


func test_peace_lifts_the_siege_without_a_fall() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	_pikemen(g, enemy, WATCH, 2)
	Sieges.season(g)
	g.wars[g.wars.size() - 1].end_turn = g.turn
	Sieges.season(g)
	assert_null(Occupation.siege_at(g, WATCH), "a peace removes the siege")
	assert_eq(Occupation.controller_tag(g, WATCH), WATCH_OWNER, "nothing changes hands at peace")
	assert_eq(_lift_why(g), &"peace")


func test_an_army_that_leaves_lifts_the_siege() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	var army := _pikemen(g, enemy, WATCH, 2)
	Sieges.season(g)
	Armies.remove(g, army)
	Sieges.season(g)
	assert_null(Occupation.siege_at(g, WATCH), "no army of the besieger left: the siege lifts")
	assert_eq(_lift_why(g), &"left")


func test_a_lost_relief_battle_lifts_the_siege_before_anything_else() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	_pikemen(g, enemy, WATCH, 2)
	Sieges.season(g)
	var record := BattleRecord.new()
	record.turn = g.turn
	record.hex = WATCH
	record.attacker = WATCH_OWNER
	record.defender = enemy
	record.end = {"winner": 0, "loser": ""}
	g.battle_records.append(record)
	Sieges.season(g)
	assert_null(Occupation.siege_at(g, WATCH), "the besieger lost on the hex this season")
	assert_eq(_lift_why(g), &"relief", "the relief lift wins over the army still standing there")


func test_a_battle_the_besieger_won_stops_progress_but_not_the_clock() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	_pikemen(g, enemy, WATCH, 2)
	Sieges.season(g)
	var progress := Occupation.siege_at(g, WATCH).progress
	var record := BattleRecord.new()
	record.turn = g.turn
	record.hex = WATCH
	record.end = {"loser": String(WATCH_OWNER), "winner": String(enemy)}
	g.battle_records.append(record)
	Sieges.season(g)
	var s := Occupation.siege_at(g, WATCH)
	assert_not_null(s, "the siege goes on")
	assert_eq(s.progress, progress, "no progress in a season with a battle on the hex")
	assert_eq(s.seasons, 2, "the season still counts")


func test_a_storm_takes_the_hex_and_the_siege_goes_without_an_event() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	_pikemen(g, enemy, WATCH, 2)
	Sieges.season(g)
	Occupation.capture(g, WATCH, enemy, &"storm", {})
	Sieges.season(g)
	assert_null(Occupation.siege_at(g, WATCH), "a storm that took the hex removes the siege")
	assert_eq(_events(g, "siege_lifted").size(), 0, "a storm lifts silently")


func test_a_siege_with_too_few_men_is_outnumbered_the_next_season() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, KEEP_OWNER)
	var army := _pikemen(g, enemy, KEEP, 4)
	Sieges.season(g)
	assert_not_null(Occupation.siege_at(g, KEEP), "2,000 men start the siege of a garrisoned fortress")
	Armies.lose_men(g, army, 1500, &"battle")
	Sieges.season(g)
	assert_null(Occupation.siege_at(g, KEEP), "500 men are under the 1,200 garrison: the siege lifts")
	assert_eq(_lift_why(g), &"outnumbered")


func test_a_walk_in_takes_open_land_held_by_a_country_at_war() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	var open_hex := _open_hex_of(g, WATCH_OWNER)
	assert_true(open_hex != Army.NO_HEX, "the map has open land of the owner")
	_pikemen(g, enemy, open_hex, 1)
	Sieges.season(g)
	assert_eq(Occupation.controller_tag(g, open_hex), enemy, "a company of 500 walks in")
	assert_eq(_captures(g).back()["by"], &"walk")


func test_own_land_occupied_by_an_enemy_is_retaken() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	Occupation.capture(g, WATCH, enemy, &"walk", {})
	_pikemen(g, WATCH_OWNER, WATCH, 1)
	Sieges.season(g)
	assert_eq(Occupation.controller_tag(g, WATCH), WATCH_OWNER, "the owner's 500 men retake the land")
	assert_eq(_captures(g).back()["by"], &"retaken")


func test_freed_land_goes_back_to_its_owner_after_six_seasons_without_support() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	Occupation.capture(g, WATCH, enemy, &"walk", {})
	for k: int in 5:
		Sieges.season(g)
	assert_eq(Occupation.controller_tag(g, WATCH), enemy, "five seasons unsupported: still held")
	Sieges.season(g)
	assert_eq(Occupation.controller_tag(g, WATCH), WATCH_OWNER, "the sixth season frees it")
	assert_eq(_captures(g).back()["by"], &"freed")


func test_a_garrison_regrows_from_its_own_people() -> void:
	var g := _game()
	ArmyFixture.people_at(g, KEEP, 20000)
	# regrow_all visits the hexes that hold men, so an empty fortress is set to one man first (see the report).
	Occupation.set_garrison(g, KEEP, 1)
	var flow := People.FLOWS.find(&"garrisoned")
	var owner := Countries.by_tag(g, KEEP_OWNER)
	var before := owner.people_flows[flow] if owner.people_flows.size() > flow else 0
	Sieges.season(g)
	assert_eq(Occupation.garrison_of(g, KEEP), 1 + 300, "a regrowth of 100 a level (3 levels) comes from the people")
	assert_eq(owner.people_flows[flow] - before, -300, "the men are taken from the people, booked garrisoned on the owner")


func test_besieged_settlement_starves_through_the_people_door_once_stores_are_out() -> void:
	var g := _game()
	# The fixture's defs are still people (no hunger): this game's copy takes the committed hunger back.
	g.defs.hunger_bp = 400
	var hex := _settlement_fortress(g, 2)
	assert_true(hex != Army.NO_HEX, "the map has a held walled town")
	var owner := Countries.by_tag(g, Occupation.controller_tag(g, hex))
	var enemy := _enemy_at_war(g, owner.tag)
	ArmyFixture.people_at(g, hex, 20000)
	var level := Occupation.fortress_level(g, hex)
	# Two companies (1,000 men) at a garrison of 800: crowd 1, so the stores run out before the town can fall.
	_pikemen(g, enemy, hex, 2)
	var i := g.map.index_of(hex)
	var flow := People.FLOWS.find(&"starved")
	var flow_before: int = owner.people_flows[flow] if owner.people_flows.size() > flow else 0
	var people_before: int = g.state.people[i]
	for k: int in 1 + level + 1:
		Sieges.season(g)
	assert_not_null(Occupation.siege_at(g, hex), "the siege stands past its stores")
	var lost := people_before - g.state.people[i]
	assert_gt(lost, 0, "a starving town loses people")
	assert_eq(owner.people_flows[flow] - flow_before, -lost, "every person lost is booked starved on the owner")
	assert_gte(g.state.people[i], g.defs.town_floor, "the loss stops at the town floor")


func test_the_loader_round_trips_and_refuses_a_bad_row() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	_pikemen(g, enemy, WATCH, 2)
	Sieges.season(g)
	var saved := Sieges.to_dict(g)
	var other := _game()
	WarFixture.at_war(other, enemy, WATCH_OWNER)  # the loader needs the war the siege is fought in
	assert_eq(Sieges.from_dict(saved, other), "", "a saved siege loads")
	assert_eq(Sieges.digest(other), Sieges.digest(g), "the digest survives the round trip")
	var bad := saved.duplicate(true)
	(bad["sieges"][0] as Dictionary)["besieger"] = "NOPE"
	assert_ne(Sieges.from_dict(bad, _game()), "", "a besieger that is no country is refused")


func test_the_digest_moves_with_a_siege() -> void:
	var g := _game()
	var before := Sieges.digest(g)
	_pikemen(g, _enemy_at_war(g, WATCH_OWNER), WATCH, 2)
	Sieges.season(g)
	assert_ne(Sieges.digest(g), before, "a running siege changes the digest")


func test_a_peace_between_the_besieger_and_the_owner_ends_their_siege() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	_pikemen(g, enemy, WATCH, 2)
	Sieges.season(g)
	assert_not_null(Occupation.siege_at(g, WATCH), "the siege runs before the peace")
	Sieges.end_between(g, enemy, WATCH_OWNER)
	assert_null(Occupation.siege_at(g, WATCH), "the peace ends the siege between the two")
	assert_eq(_lift_why(g), &"peace", "lifted by peace")
	assert_eq(Occupation.controller_tag(g, WATCH), WATCH_OWNER, "the peace does not move the hex")


func test_a_peace_between_others_leaves_the_siege_alone() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	_pikemen(g, enemy, WATCH, 2)
	Sieges.season(g)
	var stranger := WarFixture.stranger_of(g, WATCH_OWNER)
	Sieges.end_between(g, enemy, stranger)
	assert_not_null(Occupation.siege_at(g, WATCH), "a siege between other countries is untouched")
	assert_eq(_events(g, "siege_lifted").size(), 0, "no lift event for it")


## M7 review: a walled town's siege starves on the season after its stores run out (seasons > 1 + level), not on the season they run out.
func test_a_walled_town_starves_only_past_its_stores() -> void:
	var g := _game()
	var hex := _settlement_fortress(g, 2)
	assert_true(hex != Army.NO_HEX, "the map has a held walled town (fortress level 2)")
	var owner := Countries.by_tag(g, Occupation.controller_tag(g, hex))
	var enemy := _enemy_at_war(g, owner.tag)
	g.defs.hunger_bp = 400
	ArmyFixture.people_at(g, hex, 20000)
	_pikemen(g, enemy, hex, 2)
	var i := g.map.index_of(hex)
	var people_at_start: int = g.state.people[i]
	for k: int in 3:
		Sieges.season(g)
	assert_false(Sieges.starving(g, hex), "season 3 of a level 2 town: its stores (3 seasons) are not yet past")
	assert_eq(int(g.state.people[i]), people_at_start, "no hunger loss in season 3")
	Sieges.season(g)
	assert_true(Sieges.starving(g, hex), "season 4: past the stores, the town starves")
	assert_lt(int(g.state.people[i]), people_at_start, "and loses people in season 4")


## M7 review: a draw is no relief; a battle the besieger lost (the int winner) is.
func test_a_drawn_battle_is_no_relief_and_a_lost_one_is() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	_pikemen(g, enemy, WATCH, 2)
	Sieges.season(g)
	var draw := BattleRecord.new()
	draw.turn = g.turn
	draw.hex = WATCH
	draw.attacker = WATCH_OWNER
	draw.defender = enemy
	draw.end = {"winner": -1, "loser": ""}
	g.battle_records.append(draw)
	Sieges.season(g)
	assert_not_null(Occupation.siege_at(g, WATCH), "a draw lifts nothing")
	var lost := BattleRecord.new()
	lost.turn = g.turn
	lost.hex = WATCH
	lost.attacker = WATCH_OWNER
	lost.defender = enemy
	lost.end = {"winner": 0, "loser": ""}
	g.battle_records.append(lost)
	Sieges.season(g)
	assert_null(Occupation.siege_at(g, WATCH), "the defender lost (winner 0): the relief lifts the siege")
	assert_eq(_lift_why(g), &"relief")


## M7 review: a country at war with the holder but not with the owner walks into nothing (defence in depth, 4.4).
func test_a_walk_in_needs_war_with_the_owner_too() -> void:
	var g := EconomyFixture.game(&"SAV", false, true, 1480, true)
	Occupation.setup(g)
	var sav := Countries.by_tag(g, &"SAV")
	var holder := WarFixture.neighbour_of(g, &"SAV")
	var walker: StringName = &""
	for x: Country in g.countries:
		if x.tag != &"SAV" and x.tag != holder:
			walker = x.tag
			break
	WarFixture.at_war(g, &"SAV", holder)
	WarFixture.at_war(g, holder, walker)
	var hex := Army.NO_HEX
	for i: int in g.map.hex_count():
		var h := g.map.hex_of(i)
		if g.map.land[i] == 1 and int(g.state.owner[i]) == sav.id and Occupation.fortress_level(g, h) == 0:
			hex = h
			break
	assert_true(hex != Army.NO_HEX, "SAV has a plain hex")
	Occupation.capture(g, hex, holder, &"walk", {})
	Occupation.flush(g)
	Sieges._act(g, hex, walker, 500, Occupation.standing(g))
	assert_eq(Occupation.controller_tag(g, hex), holder, "the walker is not at war with the owner: no walk-in")
	WarFixture.at_war(g, walker, &"SAV")
	Sieges._act(g, hex, walker, 500, Occupation.standing(g))
	assert_eq(Occupation.controller_tag(g, hex), walker, "at war with both: the walk-in takes the hex")


## M7 review: the loader refuses forged rows: caps, the owner as besieger, a besieger with no war, duplicates and name caps.
func test_the_loader_refuses_each_forged_case() -> void:
	var g := _game()
	var enemy := _enemy_at_war(g, WATCH_OWNER)
	_pikemen(g, enemy, WATCH, 2)
	Sieges.season(g)
	var good := Sieges.to_dict(g)
	var row: Dictionary = (good["sieges"] as Array)[0]
	var f_progress := good.duplicate(true)
	((f_progress["sieges"] as Array)[0] as Dictionary)["progress"] = 100000
	var other := _game()
	WarFixture.at_war(other, enemy, WATCH_OWNER)
	assert_ne(Sieges.from_dict(f_progress, other), "", "a progress past its cap is refused")
	var f_seasons := good.duplicate(true)
	((f_seasons["sieges"] as Array)[0] as Dictionary)["seasons"] = 100000
	var other_s := _game()
	WarFixture.at_war(other_s, enemy, WATCH_OWNER)
	assert_ne(Sieges.from_dict(f_seasons, other_s), "", "a season count past its cap is refused")
	var f_owner := good.duplicate(true)
	((f_owner["sieges"] as Array)[0] as Dictionary)["besieger"] = String(WATCH_OWNER)
	var other_o := _game()
	assert_ne(Sieges.from_dict(f_owner, other_o), "", "the owner as besieger is refused")
	assert_ne(Sieges.from_dict(good.duplicate(true), _game()), "", "a besieger with no war with the owner is refused")
	var f_dup := good.duplicate(true)
	(f_dup["sieges"] as Array).append(row.duplicate(true))
	var other_d := _game()
	WarFixture.at_war(other_d, enemy, WATCH_OWNER)
	assert_ne(Sieges.from_dict(f_dup, other_d), "", "two sieges on one hex are refused")
	var f_names := good.duplicate(true)
	(f_names["siege_names"] as Dictionary)["Pavia"] = 9223372036854775807
	var other_n := _game()
	WarFixture.at_war(other_n, enemy, WATCH_OWNER)
	assert_ne(Sieges.from_dict(f_names, other_n), "", "a name count past its cap is refused")
	var f_many := good.duplicate(true)
	var table := {}
	for k: int in Sieges.MAX_NAME_ENTRIES + 1:
		table["p%d" % k] = 1
	f_many["siege_names"] = table
	var other_m := _game()
	WarFixture.at_war(other_m, enemy, WATCH_OWNER)
	assert_ne(Sieges.from_dict(f_many, other_m), "", "more place names than the cap are refused")


# --- forecast_for (M8 K13, D49) --------------------------------------------------------------------------------------------


func test_forecast_for_equals_forecast_with_the_real_garrison() -> void:
	# [fortress level, companies]: the cells of the seasons table, and a count too small to take it.
	for cell: Array in [[1, 2], [2, 2], [3, 4], [3, 8], [1, 1]]:
		var g := _game()
		var hex := _lowest_fortress(g, int(cell[0]))
		var enemy := _enemy_at_war(g, Occupation.controller_tag(g, hex))
		_pikemen(g, enemy, hex, int(cell[1]))
		var men := Armies.men_of_country(g, enemy)
		var real := Sieges.forecast(g, hex, enemy, men, 0, 0, 0)
		var given := Sieges.forecast_for(g, hex, Occupation.garrison_of(g, hex), men, 0, 0, 0)
		assert_eq(given, real, "level %d, %d companies: the garrison given is the real one" % [int(cell[0]), int(cell[1])])
		var mid := Sieges.forecast(g, hex, enemy, men, 1, 1, 1)
		assert_eq(Sieges.forecast_for(g, hex, Occupation.garrison_of(g, hex), men, 1, 1, 1), mid, "with a gun and progress too")


func test_forecast_for_differs_with_another_garrison() -> void:
	var g := _game()
	var full := Occupation.garrison_full(g, WATCH)
	var base := Sieges.forecast_for(g, WATCH, full, 1000, 0, 0, 0)
	assert_gt(base, 0, "1,000 men take a full watchtower")
	assert_eq(Sieges.forecast_for(g, WATCH, full * 3, 1000, 0, 0, 0), -1, "a garrison three times as big is too many for them")
	assert_ne(Sieges.forecast_for(g, WATCH, full / 4, 1000, 0, 0, 0), base, "a small garrison falls on another schedule")


func test_planted_forecast_for_never_reads_the_real_garrison() -> void:
	var g := _game()
	var full := Occupation.garrison_full(g, WATCH)
	var with_full := Sieges.forecast_for(g, WATCH, full, 1000, 0, 0, 0)
	var seen_terms := Sieges.terms(g, WATCH, &"", 1000, 0, full)
	Occupation.set_garrison(g, WATCH, 100)
	assert_eq(Sieges.forecast_for(g, WATCH, full, 1000, 0, 0, 0), with_full, "P: a lowered real garrison does not move the estimate")
	var after := Sieges.terms(g, WATCH, &"", 1000, 0, full)
	assert_eq(int(after["need"]), int(seen_terms["need"]), "P: nor the need of a siege worked out from a given garrison")
	assert_eq(int(after["rate"]), int(seen_terms["rate"]))
	assert_ne(Sieges.forecast(g, WATCH, &"", 1000, 0, 0, 0), with_full, "the plain forecast does read the real one")
