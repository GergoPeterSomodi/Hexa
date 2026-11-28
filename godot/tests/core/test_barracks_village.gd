## A village barracks (docs/design/recruitment-queue.md decision 25 and the note under the table; task RQ4b): a country
## with no town and no barracks on the land it owns may build one in a village or hamlet, so that no country is shut out of
## raising. The rule, what counts against it, the tile and the cards, the fog, replay, save and load. France, which has no
## town on this map, loses the barracks of Fréjus by the developer's transfer and has its two other villages left.
extends GutTest

## No one may play France (its capital is off the map): its orders are given by its tag.
const FRA := &"FRA"
const MLO := &"MLO"
const SAV := &"SAV"
const GEN := &"GEN"
## France's seat, the village that starts with its barracks.
const FREJUS := Vector2i(1, 17)
## A French village where no winter halts a work.
const COAST := Vector2i(0, 16)
## A French village in the snow: a work there stops in winter.
const NORTH := Vector2i(1, 0)
const HAMLET := 1
const VILLAGE := 2
const TOWN := 3
const TOO_SMALL := "a barracks is built in a town or larger"
const READY_WORDS := "cost 150 · 10 timber · 10 stone"


## The 1480 game, calm, `player` chosen: France has Fréjus and its barracks.
func _game(player: StringName = MLO) -> Game:
	var g := EconomyFixture.game(player)
	g.events.clear()
	return g


## The same game with Fréjus given to Savoy: France has no town and no barracks.
func _shut_out(player: StringName = MLO) -> Game:
	var g := _game(player)
	g.dev_transfer([FREJUS] as Array[Vector2i], Countries.by_tag(g, SAV).id)
	g.events.clear()
	return g


func _id(g: Game, tag: StringName = FRA) -> int:
	return Countries.by_tag(g, tag).id


func _why(g: Game, hex: Vector2i, tag: StringName = FRA) -> String:
	return str(g.check("build_barracks", {"hex": hex, "tag": tag})["reason"])


## The check's words on the two villages left to France, COAST first.
func _both(g: Game) -> Array[String]:
	return [_why(g, COAST), _why(g, NORTH)] as Array[String]


func _begin(g: Game, hex: Vector2i) -> Dictionary:
	return g.act("build_barracks", {"hex": hex, "tag": FRA})


## A settlement's level written into the state (a test's state, outside the action log).
func _level(g: Game, hex: Vector2i, level: int) -> void:
	g.state.level[g.map.index_of(hex)] = level
	g.districts.clear()
	g.version += 1


func _occupy(g: Game, hex: Vector2i, by: StringName = SAV) -> void:
	WarFixture.at_war(g, by, Territory.owner_tag(g, hex))
	Occupation.capture(g, hex, by, &"walk", {})
	g.version += 1


## A work written into the state: what a former owner left, or one that is no barracks.
func _plant_work(g: Game, hex: Vector2i, tag: StringName, action: StringName) -> void:
	var work := Work.new()
	work.id = g.state.next_work_id
	g.state.next_work_id += 1
	work.tag = tag
	work.hex = hex
	work.action = action
	work.family = ImproveRules.SETTLEMENT
	work.level_to = TOWN if action == Works.UPGRADE else 0
	work.started_turn = g.turn
	work.seasons = 4
	work.seasons_left = 4
	g.state.works.append(work)
	g.version += 1


func _row(g: Game, hex: Vector2i, full: bool = false) -> Dictionary:
	var found: Array[Dictionary] = []
	for group: Dictionary in TileBuildings.of(g, FRA, hex, full).get("groups", []):
		for row: Dictionary in group["rows"]:
			if row.get("kind", &"") == BarracksView.KIND:
				found.append(row)
	assert_eq(found.size(), 1, "one barracks tile on %s" % hex)
	return found[0] if found.size() == 1 else {}


func _facts(row: Dictionary) -> Array:
	return [row.get("state"), row.get("state_text"), row.get("hammer")]


func _needs(g: Game, hex: Vector2i) -> Array:
	var out: Array = []
	for need: Dictionary in ImprovePreview.of(g, FRA, hex, BarracksView.option())["requirements"]:
		out.append([need["text"], need["ok"]])
	return out


# ----- allowed only then ------------------------------------------------------------------------------------------------


func test_at_the_start_every_country_has_a_town_or_a_barracks() -> void:
	var g := _game()
	var let_through: Array[StringName] = []
	for c: Country in g.countries:
		if Recruiting.lacks_town_and_barracks(g, c.id):
			let_through.append(c.tag)
	assert_eq(let_through, [] as Array[StringName])


func test_with_no_town_and_no_barracks_a_village_may_have_one() -> void:
	var g := _shut_out()
	assert_eq([int(g.state.level[g.map.index_of(COAST)]), int(g.state.level[g.map.index_of(NORTH)])], [VILLAGE, VILLAGE],
		"precondition: two villages")
	assert_true(Recruiting.lacks_town_and_barracks(g, _id(g)))
	var before := g.digest()
	assert_eq(_both(g), ["", ""] as Array[String])
	assert_eq(g.digest(), before, "the check changes nothing")
	assert_true(bool(_begin(g, COAST)["ok"]))
	var work := g.state.work_at(COAST)
	assert_eq([work.action, work.seasons, work.paid, work.paid_goods], [Works.BARRACKS, 4, 150, {"timber": 10, "stone": 10}],
		"the same work at the same price")
	for n: int in 4:
		Season.run(g)
	assert_true(Recruiting.has_barracks(g, COAST))
	assert_eq(int(g.state.level[g.map.index_of(COAST)]), VILLAGE, "it stands on a village")


func test_a_hamlet_is_allowed_like_a_village() -> void:
	var g := _shut_out()
	_level(g, COAST, HAMLET)
	assert_eq(_why(g, COAST), "")
	assert_true(bool(_begin(g, COAST)["ok"]))


func test_the_other_rows_of_the_check_stay() -> void:
	var g := _shut_out()
	assert_string_starts_with(_why(g, COAST, SAV), "not your land:")
	assert_string_starts_with(_why(g, FREJUS), "not your land:")
	g.dev_money(FRA, 149 - Countries.by_tag(g, FRA).treasury)
	assert_eq(_why(g, COAST), "not enough ducats: 150 needed, 149 in the treasury")
	g.dev_money(FRA, 500)
	_plant_work(g, NORTH, FRA, Works.UPGRADE)
	assert_eq(_why(g, COAST), "no free work slot: 1 of 1 in use")
	assert_string_starts_with(_why(g, NORTH), "a work is under way here:")
	g.state.works.clear()
	var siege := Siege.new()
	siege.hex = COAST
	siege.besieger = SAV
	WarFixture.at_war(g, SAV, FRA)
	g.sieges.append(siege)
	g.version += 1
	assert_eq(_why(g, COAST), "under siege: no work can begin")
	g.sieges.clear()
	_occupy(g, COAST)
	assert_string_ends_with(_why(g, COAST), "no work can begin on occupied land")


# ----- refused with a town ----------------------------------------------------------------------------------------------


func test_a_town_of_any_size_closes_the_rule() -> void:
	var g := _shut_out()
	var got: Array = []
	for level: int in [TOWN, 4, 5]:
		_level(g, NORTH, level)
		got.append(_both(g))
	assert_eq(got, [[TOO_SMALL, ""], [TOO_SMALL, ""], [TOO_SMALL, ""]], "the town itself may have it; the village may not")
	_level(g, NORTH, VILLAGE)
	assert_eq(_why(g, COAST), "", "shrunk back: open again")


func test_an_occupied_town_still_counts() -> void:
	var g := _shut_out()
	_level(g, NORTH, TOWN)
	_occupy(g, NORTH)
	assert_eq(_why(g, COAST), TOO_SMALL)


func test_a_town_that_is_no_longer_owned_counts_no_more() -> void:
	var g := _shut_out()
	_level(g, NORTH, TOWN)
	assert_eq(_why(g, COAST), TOO_SMALL)
	g.dev_transfer([NORTH] as Array[Vector2i], _id(g, SAV))
	assert_eq(_why(g, COAST), "")


# ----- refused with a barracks, standing or being built -----------------------------------------------------------------


func test_a_standing_barracks_closes_the_rule() -> void:
	var g := _game()
	assert_eq(_both(g), [TOO_SMALL, TOO_SMALL] as Array[String], "Fréjus has one")
	var other := _shut_out()
	assert_true(other.dev_barracks(NORTH))
	assert_eq(_why(other, COAST), TOO_SMALL, "and so has a village that got one")


func test_an_occupied_barracks_still_counts() -> void:
	var g := _game()
	_occupy(g, FREJUS)
	assert_eq(_both(g), [TOO_SMALL, TOO_SMALL] as Array[String])


func test_a_barracks_being_built_closes_the_rule_even_with_a_free_slot() -> void:
	var g := _shut_out()
	g.defs.work_slots_base = 3
	g.dev_money(FRA, 1000)
	assert_true(bool(_begin(g, NORTH)["ok"]))
	assert_eq(AiKnow.slots_free(g, FRA), 2, "precondition: the slot is not what refuses")
	assert_eq(_why(g, COAST), TOO_SMALL)
	var before := g.digest()
	assert_false(bool(_begin(g, COAST)["ok"]), "two villages are never both begun")
	assert_eq(g.digest(), before)


func test_a_halted_barracks_work_still_counts() -> void:
	var g := _shut_out()
	g.defs.work_slots_base = 3
	assert_true(bool(_begin(g, NORTH)["ok"]))
	while not Calendar.is_winter(g.turn):
		g.turn += 1
	g.version += 1
	assert_true(Works.halted(g, g.state.work_at(NORTH), g.turn), "precondition: stopped by the snow")
	assert_eq(_why(g, COAST), TOO_SMALL, "in a snow winter")
	var siege := Siege.new()
	siege.hex = NORTH
	siege.besieger = SAV
	WarFixture.at_war(g, SAV, FRA)
	g.sieges.append(siege)
	g.version += 1
	assert_eq(_why(g, COAST), TOO_SMALL, "under siege")
	g.sieges.clear()
	_occupy(g, NORTH)
	assert_eq(_why(g, COAST), TOO_SMALL, "on occupied land")


func test_cancelling_the_work_opens_the_rule_again() -> void:
	var g := _shut_out()
	assert_true(bool(_begin(g, NORTH)["ok"]))
	assert_eq(_why(g, COAST), TOO_SMALL)
	assert_true(bool(g.act("cancel_work", {"hex": NORTH, "tag": FRA})["ok"]))
	assert_eq(_both(g), ["", ""] as Array[String])


func test_a_work_that_is_no_barracks_does_not_count() -> void:
	var g := _shut_out()
	g.defs.work_slots_base = 3
	_plant_work(g, NORTH, FRA, Works.UPGRADE)
	assert_eq(_why(g, COAST), "", "a village on its way to a town is no town yet")


func test_a_barracks_work_on_lost_land_or_left_by_a_former_owner_does_not_count() -> void:
	var g := _shut_out()
	g.defs.work_slots_base = 3  # the lost work still holds a slot until the works step
	assert_true(bool(_begin(g, NORTH)["ok"]))
	g.dev_transfer([NORTH] as Array[Vector2i], _id(g, SAV))
	assert_not_null(g.state.work_at(NORTH), "precondition: not yet dropped by the works step")
	assert_eq(_why(g, COAST), "", "France's work is not on France's land")
	var other := _shut_out()
	other.defs.work_slots_base = 3
	_plant_work(other, NORTH, SAV, Works.BARRACKS)
	assert_eq(_why(other, COAST), "", "Savoy's work on French land will be lost: nothing is being built")


func test_a_game_without_countries_keeps_the_town_rule() -> void:
	var g := Game.new_game(EconomyFixture.map(), 7, EconomyFixture.defs())
	g.state.barracks.fill(0)
	assert_false(Recruiting.lacks_town_and_barracks(g, 0))
	assert_eq(str(g.check("build_barracks", {"hex": COAST})["reason"]), TOO_SMALL)


# ----- the tile and the cards -------------------------------------------------------------------------------------------


func test_the_tile_offers_it_where_the_rule_lets_it_through() -> void:
	var g := _shut_out()
	assert_eq(_facts(_row(g, COAST)), [&"ready", READY_WORDS, true])
	assert_eq(_facts(_row(g, COAST, true)), [&"ready", READY_WORDS + " · upkeep 4", true])
	g.dev_money(FRA, 120 - Countries.by_tag(g, FRA).treasury)
	assert_eq(_facts(_row(g, COAST)), [&"short", "cost 150 · you have 120", false])


func test_the_tile_needs_a_town_while_there_is_a_town_or_a_barracks() -> void:
	var g := _game()
	assert_eq(_facts(_row(g, COAST)), [&"locked", "needs a town", false], "Fréjus has a barracks")
	var other := _shut_out()
	assert_eq(_row(other, COAST)["state"], &"ready")
	assert_true(bool(_begin(other, NORTH)["ok"]))
	var locked := _row(other, COAST)
	assert_eq(_facts(locked), [&"locked", "needs a town", false], "one is being built: not the slot's words")
	assert_eq(locked["reason"], "A barracks is built in a town or larger.")
	assert_eq(_facts(_row(other, NORTH))[0], &"building")
	assert_true(bool(other.act("cancel_work", {"hex": NORTH, "tag": FRA})["ok"]))
	assert_eq(_row(other, COAST)["state"], &"ready", "cancelled: on offer again")
	_level(other, NORTH, TOWN)
	assert_eq(_facts(_row(other, COAST)), [&"locked", "needs a town", false], "it has a town")


func test_the_works_card_says_why_a_village_will_do() -> void:
	var g := _shut_out()
	var card := ImprovePreview.of(g, FRA, COAST, BarracksView.option())
	assert_eq(card["verdict"], {"ok": true, "reason": ""})
	assert_eq(_needs(g, COAST)[0], ["any settlement: you have no town and no barracks", true])
	assert_eq(BuildingCard.of(g, FRA, COAST, BarracksView.option())["verdict"]["text"], "You can build this: click the tile.")
	g.dev_money(FRA, -Countries.by_tag(g, FRA).treasury)
	assert_eq(_needs(g, COAST)[0], ["any settlement: you have no town and no barracks", true], "short of money all the same")
	_level(g, NORTH, TOWN)
	assert_eq(_needs(g, NORTH)[0], ["a town or larger", true], "a town reads as before")
	var refused := BuildingCard.of(g, FRA, COAST, BarracksView.option())
	assert_eq(refused["verdict"]["text"], "A barracks is built in a town or larger.")


# ----- fog: nothing new about another country ---------------------------------------------------------------------------


## What `viewer` is told about the French village COAST.
func _told(g: Game, viewer: StringName) -> Array:
	var args := {"hex": COAST, "tag": viewer}
	return [TileView.of(g, viewer, COAST).duplicate(true), TileBuildings.of(g, viewer, COAST, true).duplicate(true),
		BuildingCard.of(g, viewer, COAST, BarracksView.option()), ImprovePreview.of(g, viewer, COAST,
		BarracksView.option()).duplicate(true), HexCard.of(g, COAST).duplicate(true), g.check("build_barracks", args)]


## Two games that differ only in whether France is let through (a barracks work far from the viewer's hex): every other
## country reads the village the same, an occupier standing on it too.
func test_another_country_is_told_nothing_of_the_owners_barracks() -> void:
	for viewer: StringName in [GEN, SAV]:
		var open := _shut_out(viewer)
		var closed := _shut_out(viewer)
		_plant_work(closed, NORTH, FRA, Works.BARRACKS)
		assert_ne(_why(open, COAST), _why(closed, COAST), "precondition: France itself reads two answers")
		for g: Game in [open, closed]:
			if viewer == SAV:
				_occupy(g, COAST)
		assert_eq(_told(closed, viewer), _told(open, viewer), "%s reads the same" % viewer)
		assert_eq(_told(open, viewer)[1], {}, "no tiles on land it does not own")


# ----- replay, save and load --------------------------------------------------------------------------------------------


func test_replay_builds_the_same_village_barracks() -> void:
	var g := _shut_out()
	assert_true(bool(_begin(g, NORTH)["ok"]))
	assert_true(bool(g.act("cancel_work", {"hex": NORTH, "tag": FRA})["ok"]))
	assert_true(bool(_begin(g, COAST)["ok"]))
	assert_false(bool(_begin(g, NORTH)["ok"]))
	for n: int in 5:
		Season.run(g)
	var again := Replay.run(g.map, g.defs, g.scenario.id, g.seed_value, g.action_log)
	assert_not_null(again)
	assert_true(Recruiting.has_barracks(again, COAST))
	assert_false(Recruiting.has_barracks(again, NORTH))
	assert_eq(again.digest(), g.digest())


func test_a_saved_game_keeps_the_rule_and_the_village_barracks() -> void:
	var g := _shut_out()
	var open := _loaded(g)
	assert_eq(_both(open), ["", ""] as Array[String], "loaded before the work: still let through")
	assert_true(bool(_begin(g, COAST)["ok"]))
	Season.run(g)
	var back := _loaded(g)
	assert_eq(_why(back, NORTH), TOO_SMALL, "loaded with the work under way: closed")
	for n: int in 3:
		Season.run(g)
		Season.run(back)
	assert_true(Recruiting.has_barracks(back, COAST))
	assert_eq(back.digest(), g.digest())
	var built := _loaded(back)
	assert_true(Recruiting.has_barracks(built, COAST), "a barracks on a village loads")
	assert_eq(_why(built, NORTH), TOO_SMALL)


## The game saved and loaded; the same digest.
func _loaded(g: Game) -> Game:
	var bytes := var_to_bytes(Snapshot.of(g))
	var result := Snapshot.restore(bytes_to_var(bytes) as Dictionary, g.map, g.defs)
	assert_eq(result["problem"], "")
	var back := result["game"] as Game
	assert_eq(back.digest(), g.digest())
	return back
