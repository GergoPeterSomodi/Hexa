## Building a barracks (docs/design/recruitment-queue.md sections 4.2 and 4.3; task RQ2): every row of the check, the work
## (paid, counted down, halted, cancelled, lost, blocked), the barracks through capture and cession, its upkeep in the
## season, the preview and the worth, replay, save and load. Questions 4 and 5 of section 13 as recommended: it stands
## through capture and passes with ceded land, and building one takes a work slot.
extends GutTest

const MLO := &"MLO"
const SAV := &"SAV"
## Pavia's like: a town or larger of Milan with no barracks is picked by _free_town.
const TOWN := 3

var _town := Army.NO_HEX


## The 1480 game, calm, Milan chosen, events cleared.
func _game() -> Game:
	var g := EconomyFixture.game(MLO)
	_town = _free_town(g, MLO)
	g.events.clear()
	return g


## The settlements of `tag` with no barracks whose level is `from` to `to`, hex index order.
func _settlements(g: Game, tag: StringName, from: int = TOWN, to: int = 5) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in Territory.districts(g, Countries.by_tag(g, tag).id):
		var level := int(g.state.level[i])
		if int(g.state.main_use[i]) == ImproveRules.SETTLEMENT and g.state.barracks[i] == 0 and level >= from and level <= to:
			out.append(g.map.hex_of(i))
	return out


## The settlements of _settlements where no winter halts a work (no snow climate).
func _open_towns(g: Game, tag: StringName) -> Array[Vector2i]:
	return _settlements(g, tag).filter(func(hex: Vector2i) -> bool: return g.map.climate[g.map.index_of(hex)] != 0)


func _free_town(g: Game, tag: StringName) -> Vector2i:
	var towns := _open_towns(g, tag)
	return towns[0] if not towns.is_empty() else Army.NO_HEX


## Ducats, timber and stone enough for several works.
func _supply(g: Game, tag: StringName = MLO) -> void:
	g.dev_money(tag, 5000)
	g.dev_goods(tag, g.defs.good_id(&"timber"), 100)
	g.dev_goods(tag, g.defs.good_id(&"stone"), 100)


func _args(hex: Vector2i, tag: StringName = MLO) -> Dictionary:
	return {"hex": hex, "tag": tag}


func _begin(g: Game, hex: Vector2i, tag: StringName = MLO) -> Dictionary:
	return g.act("build_barracks", _args(hex, tag))


func _why(g: Game, hex: Vector2i, tag: StringName = MLO) -> String:
	return str(g.check("build_barracks", _args(hex, tag))["reason"])


## [treasury, timber, stone] of a country.
func _purse(g: Game, tag: StringName = MLO) -> Array[int]:
	var c := Countries.by_tag(g, tag)
	return [c.treasury, c.stock[g.defs.good_id(&"timber")], c.stock[g.defs.good_id(&"stone")]] as Array[int]


func _kinds(g: Game) -> Array[String]:
	var out: Array[String] = []
	for event: Dictionary in g.events:
		out.append(str(event["kind"]))
	return out


## Runs whole seasons until no work stands on `hex`; the seasons run.
func _run_out(g: Game, hex: Vector2i, limit: int = 40) -> int:
	var n := 0
	while g.state.work_at(hex) != null and n < limit:
		Season.run(g)
		n += 1
	return n


func _siege(g: Game, hex: Vector2i, besieger: StringName) -> void:
	WarFixture.at_war(g, besieger, Territory.owner_tag(g, hex))
	var s := Siege.new()
	s.hex = hex
	s.besieger = besieger
	g.sieges.append(s)


func _upkeep_at(g: Game, hex: Vector2i) -> int:
	return int(Economy.district_output(g, StateView.of(g.state), hex, Calendar.season_of(g.turn))["upkeep"])


## The country's land upkeep as the season's phases read it (the profile) and as the hex by hex pass reads it.
func _land_upkeep(g: Game, tag: StringName) -> Array[int]:
	var c := Countries.by_tag(g, tag)
	var profile := SeasonProfile.of(g, SeasonProfile.table(g), c.id)
	# One district written over with its own values: a view with a change takes the hex by hex pass, not the profile.
	var i: int = Territory.districts(g, c.id)[0]
	var same := {i: Vector2i(int(g.state.main_use[i]), int(g.state.level[i]))}
	var plain := EconomySeason.made_of(g, StateView.of(g.state).with(same), tag, Calendar.season_of(g.turn), g.weather, c.tax)
	return [int(profile["upkeep"]), int(plain["upkeep"])] as Array[int]


# ----- the check ------------------------------------------------------------------------------------------------------


func test_a_town_of_your_own_may_have_one_and_the_check_changes_nothing() -> void:
	var g := _game()
	assert_ne(_town, Army.NO_HEX, "precondition: Milan has a town with no barracks")
	var before := g.digest()
	assert_eq(g.check("build_barracks", _args(_town)), {"ok": true, "reason": ""})
	assert_eq(g.digest(), before)
	var refused: Array[String] = []
	for level: int in [3, 4, 5]:
		g.state.level[g.map.index_of(_town)] = level
		if _why(g, _town) != "":
			refused.append("%d: %s" % [level, _why(g, _town)])
	assert_eq(refused, [] as Array[String], "a town, a walled town and a city")


func test_row_no_hex_and_no_data() -> void:
	var g := _game()
	assert_eq(g.check("build_barracks", {})["reason"], "no hex given")
	assert_eq(g.check("build_barracks", {"hex": "x", "tag": MLO})["reason"], "no hex given")
	g.defs.barracks = null
	assert_eq(_why(g, _town), "no barracks data: this game's definitions hold none")
	var bare := Game.new_game(g.map, 1)
	assert_eq(bare.check("build_barracks", {"hex": _town})["reason"], "no work data: this game has no definitions")


func test_row_your_land_comes_first() -> void:
	var g := _game()
	assert_eq(g.check("build_barracks", {"hex": _town})["reason"], "choose your country first")
	assert_string_starts_with(_why(g, _town, SAV), "not your land:")
	var theirs := _free_town(g, SAV)
	assert_string_starts_with(_why(g, theirs), "not your land:")


func test_row_a_work_under_way_comes_before_the_place() -> void:
	var g := _game()
	assert_true(bool(_begin(g, _town)["ok"]))
	var words := "a work is under way here: barracks, ready Spring 1481"
	assert_eq(_why(g, _town), words)
	assert_eq(g.check("upgrade", _args(_town))["reason"], words, "one work a hex: no upgrade while it is built")


func test_row_an_upgrade_under_way_refuses_a_barracks() -> void:
	var g := _game()
	_supply(g)
	var upgraded := Army.NO_HEX
	for hex: Vector2i in _settlements(g, MLO):
		if bool(g.act("upgrade", _args(hex))["ok"]):
			upgraded = hex
			break
	assert_ne(upgraded, Army.NO_HEX, "precondition: one of Milan's towns can be upgraded")
	if upgraded == Army.NO_HEX:
		return
	assert_string_starts_with(_why(g, upgraded), "a work is under way here:")


func test_row_war_occupied_and_besieged_but_not_a_passing_army() -> void:
	var g := _game()
	WarFixture.at_war(g, SAV, MLO)
	WarFixture.army_at(g, SAV, _town, 2)
	assert_eq(_why(g, _town), "", "an enemy army without a siege or occupation does not stop a work")
	var s := Siege.new()
	s.hex = _town
	s.besieger = SAV
	g.sieges.append(s)
	assert_eq(_why(g, _town), "under siege: no work can begin")
	g.sieges.clear()
	Occupation.capture(g, _town, SAV, &"walk", {})
	assert_eq(_why(g, _town), "held by the %s: no work can begin on occupied land" % Countries.def_of(g, SAV).long_name)
	assert_ne(_why(g, _town, SAV), "", "the occupier builds nothing there either")


func test_row_the_place_a_settlement_none_there_a_town_or_larger() -> void:
	var g := _game()
	var wild := Army.NO_HEX
	for i: int in Territory.districts(g, Countries.by_tag(g, MLO).id):
		if int(g.state.main_use[i]) != ImproveRules.SETTLEMENT:
			wild = g.map.hex_of(i)
			break
	assert_eq(_why(g, wild), "no settlement here: a barracks is built in one")
	assert_eq(_why(g, Countries.by_tag(g, MLO).capital), "a barracks stands here already")
	var i := g.map.index_of(_town)
	var got: Array[String] = []
	for level: int in [1, 2]:
		g.state.level[i] = level
		got.append(_why(g, _town))
	assert_eq(got, ["a barracks is built in a town or larger", "a barracks is built in a town or larger"] as Array[String],
		"a hamlet and a village")
	var swiss := EconomyFixture.game(&"SWI")
	assert_eq(_why(swiss, Vector2i(5, 0), &"SWI"), "a barracks stands here already",
		"Bern, a village, has one: that comes before the level")


func test_row_a_free_work_slot() -> void:
	var g := _game()
	_supply(g)
	assert_eq(Works.slots(g, MLO), 3)
	var towns := _settlements(g, MLO)
	for n: int in 3:
		assert_true(bool(_begin(g, towns[n])["ok"]))
	assert_eq(Works.in_use(g, MLO), 3, "a barracks takes a work slot")
	assert_eq(_why(g, towns[3]), "no free work slot: 3 of 3 in use")


func test_row_ducats_then_goods() -> void:
	var g := _game()
	var timber := g.defs.good_id(&"timber")
	var stone := g.defs.good_id(&"stone")
	g.dev_money(MLO, 149 - _purse(g)[0])
	g.dev_goods(MLO, timber, -1000)
	assert_eq(_why(g, _town), "not enough ducats: 150 needed, 149 in the treasury")
	g.dev_money(MLO, 1)
	assert_eq(_why(g, _town), Stores.short_of(g, MLO, {"timber": 10, "stone": 10}))
	assert_string_contains(_why(g, _town), "timber")
	g.dev_goods(MLO, timber, 10)
	g.dev_goods(MLO, stone, 9 - _purse(g)[2])
	assert_string_contains(_why(g, _town), "stone")
	var before := g.digest()
	assert_false(bool(_begin(g, _town)["ok"]))
	assert_eq(g.digest(), before, "a refusal changes nothing")
	g.dev_goods(MLO, stone, 1)
	assert_true(bool(_begin(g, _town)["ok"]), "exactly the price is enough")
	assert_eq(_purse(g), [0, 0, 0] as Array[int])


# ----- the work -------------------------------------------------------------------------------------------------------


func test_beginning_pays_and_puts_nothing() -> void:
	var g := _game()
	var purse := _purse(g)
	var use := g.state.main_use.duplicate()
	var level := g.state.level.duplicate()
	assert_true(bool(_begin(g, _town)["ok"]))
	var w := g.state.work_at(_town)
	assert_eq([w.tag, w.action, w.family, w.level_to], [MLO, &"barracks", ImproveRules.SETTLEMENT, 0])
	assert_eq([w.started_turn, w.seasons, w.seasons_left, w.paid], [1, 4, 4, 150])
	assert_eq(w.paid_goods, {"timber": 10, "stone": 10})
	assert_eq(_purse(g), [purse[0] - 150, purse[1] - 10, purse[2] - 10] as Array[int])
	assert_eq(_kinds(g), ["work_started"])
	assert_false(Recruiting.has_barracks(g, _town))
	assert_eq([g.state.main_use, g.state.level], [use, level])
	assert_eq(g.action_log.back(), {"turn": 1, "action": "build_barracks", "args": Chronicle.plain(_args(_town))})
	assert_eq(WorksView.label(g, w), "barracks")
	assert_eq(LogLines.noun_of(w), "a barracks")


func test_it_stands_after_four_seasons() -> void:
	var g := _game()
	_begin(g, _town)
	for n: int in 3:
		Season.run(g)
	assert_eq(g.state.work_at(_town).seasons_left, 1)
	assert_false(Recruiting.has_barracks(g, _town))
	var level := int(g.state.level[g.map.index_of(_town)])
	g.events.clear()
	Season.run(g)
	assert_null(g.state.work_at(_town))
	assert_true(Recruiting.has_barracks(g, _town))
	assert_eq(int(g.state.level[g.map.index_of(_town)]), level, "no level changes while it is built")
	var finished: Array[Dictionary] = []
	var changed := false
	for event: Dictionary in g.events:
		if event["kind"] == "work_finished" and event["hex"] == _town:
			finished.append(event)
		changed = changed or (event["kind"] == "hex_changed" and event.get("hex") == _town)
	assert_eq(finished.size(), 1)
	assert_true(changed, "a finished barracks says the hex changed")
	assert_eq(_why(g, _town), "a barracks stands here already")
	var line := LogLines.line_of(g, g.chronicle.entries[_entry_of(g, "work_finished", _town)], MLO)
	assert_eq(line["text"], "Barracks finished %s." % Words.at(g, (Work.from_dict(finished[0]["work"] as Dictionary)).hex))
	assert_string_starts_with(str(line["text"]), "Barracks finished at ")
	var report := JSON.stringify(SeasonSummary.of(g, MLO, g.turn - 1))
	assert_string_contains(report, "Upkeep 1 a season.", "the report names the barracks' own upkeep")


## The index of the newest chronicle entry of a kind on a hex; -1 when none.
func _entry_of(g: Game, kind: String, hex: Vector2i) -> int:
	for n: int in range(g.chronicle.entries.size() - 1, -1, -1):
		var entry: Dictionary = g.chronicle.entries[n]
		if str(entry.get("kind", "")) == kind and Work.from_dict(entry.get("work", {}) as Dictionary).hex == hex:
			return n
	return -1


func test_a_siege_an_occupation_and_a_snow_winter_halt_it() -> void:
	var g := _game()
	_begin(g, _town)
	var w := g.state.work_at(_town)
	_siege(g, _town, SAV)
	Works.season(g)
	assert_eq([w.seasons_left, Works.ready_words(g, w)], [4, "halted by war"], "a siege")
	g.sieges.clear()
	Occupation.capture(g, _town, SAV, &"walk", {})
	Works.season(g)
	assert_eq(w.seasons_left, 4, "occupied")
	Occupation.release(g, [_town] as Array[Vector2i])
	g.war_cache.forget_control()
	Works.season(g)
	assert_eq(w.seasons_left, 3, "released: it goes on")
	var snow := Army.NO_HEX
	for c: Country in g.countries:
		for hex: Vector2i in _settlements(g, c.tag):
			if snow == Army.NO_HEX and int(g.map.climate[g.map.index_of(hex)]) == 0:
				snow = hex
	assert_ne(snow, Army.NO_HEX, "precondition: a town in the snow")
	if snow == Army.NO_HEX:
		return
	assert_true(bool(_begin(g, snow, Territory.owner_tag(g, snow))["ok"]))
	var cold := g.state.work_at(snow)
	while not Calendar.is_winter(g.turn):
		g.turn += 1
	Works.season(g)
	assert_eq(cold.seasons_left, 4, "a snow winter")
	g.turn += 1
	Works.season(g)
	assert_eq(cold.seasons_left, 3)


func test_a_cancel_gives_everything_back_in_its_first_season_only() -> void:
	var g := _game()
	var purse := _purse(g)
	_begin(g, _town)
	assert_true(bool(g.act("cancel_work", _args(_town))["ok"]))
	assert_eq(_purse(g), purse)
	assert_null(g.state.work_at(_town))
	_begin(g, _town)
	Season.run(g)
	purse = _purse(g)
	assert_true(bool(g.act("cancel_work", _args(_town))["ok"]))
	assert_eq(_purse(g), purse, "nothing back after the first season")
	assert_false(Recruiting.has_barracks(g, _town))


func test_a_work_on_ceded_land_is_lost_with_nothing_back() -> void:
	var g := _game()
	_begin(g, _town)
	Season.run(g)
	assert_eq(g.dev_transfer([_town] as Array[Vector2i], Countries.by_tag(g, SAV).id), 1)
	var purse := _purse(g)
	g.events.clear()
	Works.season(g)
	assert_null(g.state.work_at(_town))
	assert_false(Recruiting.has_barracks(g, _town))
	assert_eq(_purse(g), purse)
	var lost: Array = []
	for event: Dictionary in g.events:
		if event["kind"] == "work_cancelled" and event["hex"] == _town:
			lost.append([event["tag"], event["why"], event["refund"]])
	assert_eq(lost, [[MLO, &"lost", 0]])


func test_a_town_that_shrank_keeps_its_work_and_its_barracks() -> void:
	var g := _game()
	_begin(g, _town)
	var i := g.map.index_of(_town)
	g.state.level[i] = 2
	g.districts.clear()
	_run_out(g, _town)
	assert_true(Recruiting.has_barracks(g, _town), "the work goes on in a village")
	g.state.level[i] = 1
	g.districts.clear()
	Season.run(g)
	assert_true(Recruiting.has_barracks(g, _town), "and it stays in a hamlet")


func test_a_barracks_put_meanwhile_blocks_the_work() -> void:
	var g := _game()
	_begin(g, _town)
	Season.run(g)
	assert_true(g.dev_barracks(_town))
	assert_true(_kinds(g).has("hex_changed"), "the developer's barracks says the hex changed too")
	g.events.clear()
	var purse := _purse(g)
	for n: int in 3:
		Works.season(g)
	assert_null(g.state.work_at(_town))
	assert_eq(_purse(g), purse, "a blocked work gives nothing back")
	var blocked: Array = []
	for event: Dictionary in g.events:
		if event["kind"] == "work_cancelled":
			blocked.append([event["why"], event["reason"]])
	assert_eq(blocked, [[&"blocked", "a barracks stands here already"]])


func test_a_map_only_game_builds_one_free() -> void:
	var defs := EconomyFixture.defs()
	var g := Game.new_game(EconomyFixture.map(), 7, defs)
	var town := Army.NO_HEX
	for i: int in g.map.hex_count():
		if town == Army.NO_HEX and int(g.state.main_use[i]) == ImproveRules.SETTLEMENT and int(g.state.level[i]) >= TOWN:
			town = g.map.hex_of(i)
	assert_true(bool(g.act("build_barracks", {"hex": town})["ok"]))
	assert_eq([g.state.works[0].paid, g.state.works[0].paid_goods], [0, {}])
	_run_out(g, town)
	assert_true(Recruiting.has_barracks(g, town))


func test_the_pair_rules_do_not_read_a_barracks_work() -> void:
	var g := _game()
	_begin(g, _town)
	var near := ImproveRules.neighbour(_town, 0)
	var clashes: Array[String] = []
	for family: int in range(1, ImproveRules.FAMILIES):
		for level: int in [1, 2, 3]:
			var why := Works.pending_conflict(g, near, family, level)
			if why != "":
				clashes.append(why)
	assert_eq(clashes, [] as Array[String])
	assert_eq(ImproveCardParts.pending(g, near, ImproveRules.SETTLEMENT, 3), {})


# ----- capture and cession --------------------------------------------------------------------------------------------


func test_a_barracks_stands_through_capture_and_release() -> void:
	var g := _game()
	var capital := Countries.by_tag(g, MLO).capital
	var town_upkeep := _upkeep_at(g, capital)
	Occupation.capture(g, capital, SAV, &"walk", {})
	assert_true(Recruiting.has_barracks(g, capital), "taken by force: it stands")
	Season.run(g)
	assert_true(Recruiting.has_barracks(g, capital))
	Occupation.release(g, [capital] as Array[Vector2i])
	g.war_cache.forget_control()
	assert_true(Recruiting.has_barracks(g, capital))
	assert_eq(_upkeep_at(g, capital), town_upkeep)


func test_a_barracks_passes_with_land_ceded_in_a_peace() -> void:
	var g := _game()
	g.dev_money(MLO, 1000)
	_begin(g, _town)
	_run_out(g, _town)
	var war := WarFixture.at_war(g, SAV, MLO)
	Occupation.capture(g, _town, SAV, &"walk", {})
	assert_true(Wars.ceded(g, war, &"yield", MLO).has(_town), "precondition: the peace moves the town")
	var peace := g.act("make_peace", {"target": SAV, "terms": &"yield", "tag": MLO})
	assert_true(bool(peace["ok"]), str(peace["reason"]))
	assert_eq(Territory.owner_tag(g, _town), SAV)
	assert_true(Recruiting.has_barracks(g, _town), "ceded: the winner has it")
	assert_eq(_why(g, _town, SAV), "a barracks stands here already")


func test_the_new_owner_pays_for_a_transferred_barracks() -> void:
	var g := _game()
	_begin(g, _town)
	_run_out(g, _town)
	var mine := _land_upkeep(g, MLO)
	var theirs := _land_upkeep(g, SAV)
	var cost := _upkeep_at(g, _town)
	g.dev_transfer([_town] as Array[Vector2i], Countries.by_tag(g, SAV).id)
	assert_eq(_land_upkeep(g, MLO), [mine[0] - cost, mine[1] - cost] as Array[int])
	assert_eq(_land_upkeep(g, SAV), [theirs[0] + cost, theirs[1] + cost] as Array[int])
	assert_true(Recruiting.has_barracks(g, _town))


func test_the_season_report_lists_the_order() -> void:
	var g := _game()
	_begin(g, _town)
	var turn := g.turn
	Season.run(g)
	var said: Array[String] = []
	for section: Dictionary in SeasonSummary.of(g, MLO, turn)["sections"]:
		if section["id"] == &"orders":
			for line: Dictionary in section["lines"]:
				said.append(str(line["text"]))
	var found := said.filter(func(t: String) -> bool: return t.begins_with("Ordered to build: barracks "))
	assert_eq(found.size(), 1, "the order is named: %s" % str(said))


# ----- upkeep ---------------------------------------------------------------------------------------------------------


func test_a_barracks_adds_one_ducat_to_the_settlements_upkeep() -> void:
	var g := _game()
	var before := _upkeep_at(g, _town)
	var land := _land_upkeep(g, MLO)
	assert_eq(land[0], land[1])
	var cached := int(g.districts.base_of(g, g.map.index_of(_town))["upkeep"])
	assert_eq(cached, before)
	assert_true(g.dev_barracks(_town))
	assert_eq(_upkeep_at(g, _town), before + 1)
	assert_eq(int(g.districts.base_of(g, g.map.index_of(_town))["upkeep"]), before + 1, "the district cache reads it anew")
	assert_eq(_land_upkeep(g, MLO), [land[0] + 1, land[1] + 1] as Array[int], "and the season's profile")


func test_the_thirteen_start_barracks_cost_thirteen_ducats_a_season() -> void:
	var with := EconomyFixture.game(MLO)
	var without := EconomyFixture.game(MLO)
	without.state.barracks.fill(0)
	without.districts.clear()
	var got: Array = []
	var want: Array = []
	for c: Country in with.countries:
		got.append([c.tag, _land_upkeep(with, c.tag)[0] - _land_upkeep(without, c.tag)[0]])
		want.append([c.tag, 1])
	assert_eq(got, want, "one barracks a country, 1 ducat each")
	Season.run(with)
	Season.run(without)
	var paid: Array = []
	for c: Country in with.countries:
		paid.append([c.tag, without.countries[c.id - 1].treasury - c.treasury])
	assert_eq(paid, want, "the season takes it with the districts' upkeep")


func test_occupied_and_besieged_land_pays_no_barracks_upkeep() -> void:
	var g := _game()
	var capital := Countries.by_tag(g, MLO).capital
	for war_kind: String in ["occupied", "besieged"]:
		var with := _game()
		var without := _game()
		without.state.barracks[without.map.index_of(capital)] = 0
		without.districts.clear()
		for game: Game in [with, without]:
			if war_kind == "occupied":
				Occupation.capture(game, capital, SAV, &"walk", {})
			else:
				_siege(game, capital, SAV)
		assert_eq([_land_upkeep(with, MLO), _land_upkeep(with, SAV)], [_land_upkeep(without, MLO), _land_upkeep(without, SAV)],
			"%s: neither side pays for it" % war_kind)
	assert_true(Recruiting.has_barracks(g, capital))


# ----- the preview ----------------------------------------------------------------------------------------------------


func test_the_preview_pays_a_barracks_from_the_season_it_stands() -> void:
	var g := _game()
	var base := _upkeep_line(EconomyPreview.expected(g, MLO))
	g.dev_money(MLO, 1000)
	assert_true(bool(_begin(g, _town)["ok"]))
	var ahead: Array = EconomyPreview.with(g, MLO, {}, 7)["seasons"]
	var worth := EconomyWorth.worth_seasons(g, MLO, 7)
	var h := (worth["hexes"] as PackedInt32Array).find(g.map.index_of(_town))
	var lines: Array[int] = []
	var hex_cost: Array[int] = []
	for k: int in 7:
		lines.append(_upkeep_line(ahead[k] as Dictionary) - base)
		hex_cost.append((worth["upkeep"] as PackedInt32Array)[h * 7 + k] - _upkeep_at(g, _town))
	assert_eq(lines, [0, 0, 0, 0, -1, -1, -1] as Array[int], "four seasons of work, then the upkeep")
	assert_eq(hex_cost, [0, 0, 0, 0, 1, 1, 1] as Array[int], "the hex's worth says the same")
	var played: Array = []
	var said: Array = []
	for k: int in 7:
		var c := Countries.by_tag(g, MLO)
		var money := c.treasury
		Season.run(g)
		played.append([c.treasury - money, c.stock.duplicate()])
		said.append([int((ahead[k] as Dictionary)["net"]), (ahead[k] as Dictionary)["stock"]])
	assert_eq(played, said, "the preview is the seven seasons")
	assert_true(Recruiting.has_barracks(g, _town))


## The upkeep_districts line of a previewed season (negative), 0 when it has none.
func _upkeep_line(entry: Dictionary) -> int:
	for line: Dictionary in entry.get("lines", []):
		if line["why"] == &"upkeep_districts":
			return int(line["amount"])
	return 0


# ----- replay, save and load ------------------------------------------------------------------------------------------


func test_replay_builds_the_same_barracks() -> void:
	var g := _game()
	_supply(g)
	var towns := _open_towns(g, MLO)
	_begin(g, towns[0])
	_begin(g, towns[1])
	g.act("cancel_work", _args(towns[1]))
	for n: int in 5:
		Season.run(g)
	var again := Replay.run(g.map, g.defs, g.scenario.id, g.seed_value, g.action_log)
	assert_not_null(again)
	assert_true(Recruiting.has_barracks(again, towns[0]))
	assert_false(Recruiting.has_barracks(again, towns[1]))
	assert_eq(again.digest(), g.digest())


func test_a_barracks_work_is_saved_loaded_and_goes_on() -> void:
	var g := _game()
	_begin(g, _town)
	Season.run(g)
	var bytes := var_to_bytes(Snapshot.of(g))
	var r := Snapshot.restore(bytes_to_var(bytes) as Dictionary, g.map, g.defs)
	assert_eq(r["problem"], "")
	var back := r["game"] as Game
	assert_eq(back.digest(), g.digest())
	assert_eq(back.state.to_dict(), g.state.to_dict())
	assert_eq(back.state.work_at(_town).action, &"barracks")
	for n: int in 3:
		Season.run(g)
		Season.run(back)
	assert_true(Recruiting.has_barracks(back, _town))
	assert_eq(back.digest(), g.digest())


func test_p_a_barracks_work_off_a_settlement_is_refused() -> void:
	var g := _game()
	_begin(g, _town)
	var wild := Vector2i.ZERO
	for i: int in g.map.hex_count():
		if g.map.land[i] != 0 and int(g.state.main_use[i]) != ImproveRules.SETTLEMENT:
			wild = g.map.hex_of(i)
			break
	var body := bytes_to_var(var_to_bytes(Snapshot.of(g))) as Dictionary
	assert_eq(Snapshot.restore(body.duplicate(true), g.map, g.defs)["problem"], "", "the sound body loads")
	var works := (body["map_state"] as Dictionary)["works"] as Array
	(works[0] as Dictionary)["hex"] = [wild.x, wild.y]
	var r := Snapshot.restore(body, g.map, g.defs)
	assert_null(r["game"])
	assert_eq(r["problem"], Snapshot.PROBLEM_UNREADABLE)
