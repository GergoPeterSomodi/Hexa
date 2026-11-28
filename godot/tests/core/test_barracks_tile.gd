## The barracks in the tile window (docs/design/recruitment-queue.md sections 6 and 8; task RQ3): every state of its tile,
## the upkeep counted once beside the settlement's row, its hover card and works card, the foreign land facts only in sight,
## and the words of its log lines and report.
extends GutTest

const MLO := &"MLO"
const SAV := &"SAV"
const GEN := &"GEN"
const MILAN := Vector2i(9, 9)
const READY_WORDS := "cost 150 · 10 timber · 10 stone"


## The 1480 game, calm, Milan chosen, events cleared.
func _game() -> Game:
	var g := EconomyFixture.game(MLO)
	g.events.clear()
	return g


## The first settlement of `tag` with no barracks whose level is `from` to `to`, in a climate where no winter halts a work.
func _settlement(g: Game, from: int = 3, to: int = 5, tag: StringName = MLO) -> Vector2i:
	for i: int in Territory.districts(g, Countries.by_tag(g, tag).id):
		var level := int(g.state.level[i])
		if int(g.state.main_use[i]) == ImproveRules.SETTLEMENT and g.state.barracks[i] == 0 and level >= from and level <= to \
				and g.map.climate[i] != 0:
			return g.map.hex_of(i)
	return Army.NO_HEX


func _supply(g: Game, tag: StringName = MLO) -> void:
	g.dev_money(tag, 5000)
	g.dev_goods(tag, g.defs.good_id(&"timber"), 100)
	g.dev_goods(tag, g.defs.good_id(&"stone"), 100)


func _rows(g: Game, hex: Vector2i, full: bool = false, tag: StringName = MLO) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for group: Dictionary in TileBuildings.of(g, tag, hex, full).get("groups", []):
		for row: Dictionary in group["rows"]:
			out.append(row)
	return out


## The barracks rows of a tile (never more than one).
func _barracks(g: Game, hex: Vector2i, full: bool = false, tag: StringName = MLO) -> Array[Dictionary]:
	return _rows(g, hex, full, tag).filter(func(row: Dictionary) -> bool: return row.get("kind", &"") == BarracksView.KIND)


## The one barracks row ({} and a failure when there is not exactly one).
func _row(g: Game, hex: Vector2i, full: bool = false, tag: StringName = MLO) -> Dictionary:
	var found := _barracks(g, hex, full, tag)
	assert_eq(found.size(), 1, "one barracks tile on %s" % hex)
	return found[0] if found.size() == 1 else {}


## [state, state_text, tone, hammer] of a row.
func _facts(row: Dictionary) -> Array:
	return [row.get("state"), row.get("state_text"), row.get("tone"), row.get("hammer")]


func _texts(card: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for section: Dictionary in card.get("sections", []):
		if str(section["head"]) != "":
			out.append(str(section["head"]))
		for line: Array in section["lines"]:
			out.append(str(line[0]) if line.size() < 3 else "%s: %s" % [line[0], line[2]])
	return out


func _verdict(card: Dictionary) -> Array:
	var verdict: Dictionary = card.get("verdict", {})
	return [verdict.get("ok"), verdict.get("text"), verdict.get("tone")]


# ----- the tile's states ------------------------------------------------------------------------------------------------


func test_a_town_with_none_offers_it_in_the_settlements_strip_after_the_built_piece() -> void:
	var g := _game()
	var town := _settlement(g)
	assert_ne(town, Army.NO_HEX, "precondition: Milan has a town with no barracks")
	var rows := _rows(g, town)
	assert_eq([rows[0]["id"], rows[1]["id"]], ["built:%d" % ImproveRules.SETTLEMENT, "barracks:0"])
	var row := _row(g, town)
	assert_eq([row["name"], row["group"], row["icon"], row["level"]], ["Barracks", &"settlement", "barracks", 0])
	assert_eq(row["option"], {"action": Works.BARRACKS, "family": 0})
	assert_eq(_facts(row), [&"ready", READY_WORDS, &"plain", true])
	assert_eq([row["gain"], row["upkeep"], row["build_seasons"]], [null, null, 4])
	assert_eq(row["cost"], {"ducats": 150, "goods": {"timber": 10, "stone": 10}})
	var full := _row(g, town, true)
	assert_eq(_facts(full), [&"ready", READY_WORDS + " · upkeep 4", &"plain", true], "upkeep a year, as every row")
	assert_eq([full["gain"], full["upkeep"], full["payback"]], [null, 4, {}], "no gain and no payback")


func test_short_of_ducats_and_of_goods() -> void:
	var g := _game()
	var town := _settlement(g)
	g.dev_money(MLO, -Countries.by_tag(g, MLO).treasury + 120)
	assert_eq(_facts(_row(g, town)), [&"short", "cost 150 · you have 120", &"bad", false])
	_supply(g)
	var stone := g.defs.good_id(&"stone")
	g.dev_goods(MLO, stone, -Countries.by_tag(g, MLO).stock[stone] + 3)
	assert_eq(_facts(_row(g, town)), [&"short", "Not enough stone: 10 needed, 3 in store.", &"bad", false])


func test_a_village_is_locked_and_says_it_needs_a_town() -> void:
	var g := _game()
	var village := _settlement(g, 1, 2)
	assert_ne(village, Army.NO_HEX, "precondition: Milan has a village")
	var row := _row(g, village)
	assert_eq(_facts(row), [&"locked", "needs a town", &"muted", false])
	assert_eq(row["reason"], "A barracks is built in a town or larger.")
	assert_eq(_facts(_row(g, village, true)), [&"locked", "needs a town", &"muted", false], "the full rows too")


func test_war_the_slots_and_another_work_refuse_it_with_their_words() -> void:
	var g := _game()
	_supply(g)
	var town := _settlement(g)
	var siege := Siege.new()
	siege.hex = town
	siege.besieger = SAV
	WarFixture.at_war(g, SAV, MLO)
	g.sieges.append(siege)
	g.version += 1
	assert_eq(_facts(_row(g, town)), [&"refused", "Under siege: no work can begin.", &"bad", false])
	g.sieges.clear()
	Occupation.capture(g, town, SAV, &"walk", {})
	g.version += 1
	var held := _row(g, town)
	assert_eq([held["state"], held["hammer"]], [&"refused", false])
	assert_string_starts_with(str(held["state_text"]), "Held by the ")
	var slots := _game()
	_supply(slots)
	var total := Works.slots(slots, MLO)
	for i: int in Territory.districts(slots, Countries.by_tag(slots, MLO).id):
		var hex := slots.map.hex_of(i)
		if Works.in_use(slots, MLO) >= total:
			break
		if hex != town and _settlement(slots) == town:
			for option: Dictionary in Improve.build_options(slots, hex):
				slots.act("build", {"hex": hex, "family": int(option["family_id"]), "tag": MLO})
				break
	assert_eq(Works.in_use(slots, MLO), total, "precondition: every slot is taken")
	assert_eq(_facts(_row(slots, town)), [&"refused", "No free work slot: %d of %d in use." % [total, total], &"bad", false])


func test_one_job_at_a_time_while_another_work_is_under_way() -> void:
	var g := _game()
	_supply(g)
	var upgraded := Army.NO_HEX
	for i: int in Territory.districts(g, Countries.by_tag(g, MLO).id):
		if int(g.state.main_use[i]) == ImproveRules.SETTLEMENT and g.state.barracks[i] == 0 \
				and bool(g.act("upgrade", {"hex": g.map.hex_of(i), "tag": MLO})["ok"]):
			upgraded = g.map.hex_of(i)
			break
	assert_ne(upgraded, Army.NO_HEX, "precondition: one of Milan's settlements can be upgraded")
	var row := _row(g, upgraded)
	var why := "one job at a time: %s is under way" % WorksView.label(g, g.state.work_at(upgraded))
	assert_eq(_facts(row), [&"refused", why, &"bad", false])


func test_under_way_it_is_the_barracks_tile_with_its_seasons() -> void:
	var g := _game()
	var town := _settlement(g)
	assert_true(bool(g.act("build_barracks", {"hex": town, "tag": MLO})["ok"]))
	var row := _row(g, town, true)
	assert_eq([row["id"], row["name"], row["group"], row["icon"], row["level"]], ["work", "Barracks", &"settlement", "barracks", 0])
	assert_eq(_facts(row), [&"building", "building · 1 of 4 seasons", &"plain", false])
	assert_eq(row["progress"], 0.25)
	assert_eq([row["gain"], row["upkeep"], row["option"]], [null, null, {}])
	var busy := _rows(g, town).filter(func(r: Dictionary) -> bool: return r["state"] == &"refused")
	assert_gt(busy.size(), 0, "the other rows stay listed")
	assert_eq(busy[0]["state_text"], "one job at a time: barracks is under way")
	var job: Dictionary = TileView.of(g, MLO, town)["job"]
	assert_eq([job["label"], job["progress"], job["cancel"]], ["barracks", "1 of 4 seasons", true])
	assert_true(bool(g.act("cancel_work", {"hex": town, "tag": MLO})["ok"]))
	assert_eq(_row(g, town)["state"], &"ready", "cancelled: on offer again")


func test_standing_it_works_on_a_town_and_on_a_village() -> void:
	var g := _game()
	var row := _row(g, MILAN)
	assert_eq([row["id"], row["name"], row["option"], row["level"]], ["built:barracks", "Barracks", {}, 0])
	assert_eq(_facts(row), [&"built", "working", &"good", false])
	assert_eq(row["upkeep"], null)
	var full := _row(g, MILAN, true)
	assert_eq([full["state_text"], full["upkeep"], full["gain"]], ["working · upkeep 4", 4, null])
	var village := _settlement(g, 1, 2)
	assert_true(Recruiting.put(g, village))
	g.version += 1
	assert_eq(_facts(_row(g, village)), [&"built", "working", &"good", false])


func test_no_tile_off_a_settlement_on_foreign_land_or_without_its_numbers() -> void:
	var g := _game()
	var wild := Army.NO_HEX
	for i: int in Territory.districts(g, Countries.by_tag(g, MLO).id):
		if int(g.state.main_use[i]) != ImproveRules.SETTLEMENT:
			wild = g.map.hex_of(i)
			break
	assert_eq(_barracks(g, wild).size(), 0, "no settlement there")
	var theirs := _settlement(g, 3, 5, SAV)
	assert_eq(TileBuildings.of(g, MLO, theirs), {}, "foreign land has no tiles")
	assert_eq(BuildingCard.of(g, MLO, theirs, BarracksView.option()), {}, "and no card")
	var town := _settlement(g)
	g.defs.barracks = null
	g.version += 1
	assert_eq(_barracks(g, town).size(), 0, "definitions with no barracks")
	assert_eq(BuildingCard.of(g, MLO, town, BarracksView.option()), {})


# ----- counted once -----------------------------------------------------------------------------------------------------


## A settlement that is no place of the map can be cleared, so its built row has figures: they must be its own.
func test_a_settlements_row_and_card_leave_the_barracks_upkeep_to_its_tile() -> void:
	var g := _game()
	var hex := Army.NO_HEX
	for i: int in Territory.districts(g, Countries.by_tag(g, MLO).id):
		if int(g.state.main_use[i]) == ImproveRules.NONE:
			hex = g.map.hex_of(i)
			break
	var at := g.map.index_of(hex)
	g.state.main_use[at] = ImproveRules.SETTLEMENT
	g.state.level[at] = 3
	g.districts.clear()
	g.version += 1
	var id := "built:%d" % ImproveRules.SETTLEMENT
	var before := TileBuildings.of(g, MLO, hex, true)
	var alone: Dictionary = _rows(g, hex, true)[0]
	var card_alone := BuildingCard.of(g, MLO, hex, {})
	assert_eq(alone["id"], id)
	assert_ne(alone["upkeep"], null, "precondition: this settlement's row has figures")
	assert_ne(alone["gain"], null)
	assert_true(Recruiting.put(g, hex))
	g.districts.clear()
	g.version += 1
	var beside: Dictionary = _rows(g, hex, true)[0]
	assert_eq([beside["state_text"], beside["upkeep"], beside["gain"]], [alone["state_text"], alone["upkeep"], alone["gain"]])
	var raw := ImprovePreview.of(g, MLO, hex, {"action": Works.CLEAR, "family": ImproveRules.SETTLEMENT})
	assert_eq(-int((raw["lands"] as Dictionary)["upkeep"]), int(alone["upkeep"]) + 4, "the hex itself costs both")
	assert_eq(BuildingCard.of(g, MLO, hex, {}), card_alone, "the settlement's hover card is its own too")
	var after := TileBuildings.of(g, MLO, hex, true)
	assert_eq(after["summary"]["upkeep"], int(before["summary"]["upkeep"]) + 4, "the summary counts the barracks once")
	assert_eq(after["summary"]["make"], before["summary"]["make"], "it makes nothing")
	assert_eq(ImprovePreview.of(g, MLO, hex, {"action": Works.CLEAR, "family": ImproveRules.SETTLEMENT}), raw,
		"the cached card is not written")


# ----- the cards ------------------------------------------------------------------------------------------------------


func test_the_hover_card_of_an_offer_has_the_price_the_upkeep_and_no_gain() -> void:
	var g := _game()
	var town := _settlement(g)
	var card := BuildingCard.of(g, MLO, town, BarracksView.option())
	assert_eq([card["heading"], card["kind"]], ["Build: Barracks", "Barracks"])
	assert_eq(card["title"], "Barracks in %s" % ImproveCardParts.named(g, town))
	assert_eq(_texts(card), [BarracksView.ABOUT, "Each year it would", "Upkeep a year: −4 ducats", "To build",
		"Ducats: 150 ducats", "Timber: 10 timber", "Stone: 10 stone", "Building time: 4 seasons"] as Array[String])
	assert_eq(_verdict(card), [true, "You can build this: click the tile.", &"good"])
	assert_eq(BarracksView.ABOUT, "Companies are raised here: up to 5 queued, one ready a season.")
	g.dev_money(MLO, -Countries.by_tag(g, MLO).treasury + 100)
	assert_eq(_verdict(BuildingCard.of(g, MLO, town, BarracksView.option())),
		[false, "You cannot afford this yet: 50 more ducats.", &"bad"])
	var village := _settlement(g, 1, 2)
	var locked := BuildingCard.of(g, MLO, village, BarracksView.option())
	assert_eq(_verdict(locked), [false, "A barracks is built in a town or larger.", &"bad"])
	assert_true(_texts(locked).has("Ducats: 150 ducats"), "a refused card keeps its cost")


func test_the_hover_card_of_a_standing_and_of_a_building_one() -> void:
	var g := _game()
	var standing := BuildingCard.of(g, MLO, MILAN, BarracksView.option())
	assert_eq([standing["heading"], standing["title"]], ["Barracks", "Barracks in Milan"])
	assert_eq(_texts(standing), [BarracksView.ABOUT, "Upkeep a year: −4 ducats"] as Array[String])
	assert_eq(_verdict(standing), [true, "It stands here.", &"good"])
	var town := _settlement(g)
	g.act("build_barracks", {"hex": town, "tag": MLO})
	var card := BuildingCard.of(g, MLO, town, BarracksView.option())
	assert_eq(card["heading"], "Barracks")
	assert_eq(_verdict(card), [true, "Being built: 1 of 4 seasons, ready Spring 1481.", &"plain"])
	assert_false(_texts(card).has("To build"))
	Occupation.capture(g, town, SAV, &"walk", {})
	g.version += 1
	assert_eq(_verdict(BuildingCard.of(g, MLO, town, BarracksView.option()))[1], "Being built: halted by war.")


func test_the_works_card_has_the_price_the_needs_and_no_gain() -> void:
	var g := _game()
	var town := _settlement(g)
	var card := ImprovePreview.of(g, MLO, town, BarracksView.option())
	assert_eq([card["verdict"], card["blocked_by"]], [{"ok": true, "reason": ""}, &""])
	assert_eq(card["title"], "%s, barracks" % str(Improve.place_of(g.map, town).get("name", "")))
	assert_eq((card["cost"] as Dictionary)["text"], "150 ducats · 10 timber · 10 stone · 4 seasons · ready Spring 1481")
	var needs: Array[String] = []
	for need: Dictionary in card["requirements"]:
		needs.append("%s %s" % [need["text"], need["ok"]])
	var c := Countries.by_tag(g, MLO)
	assert_eq(needs, ["a town or larger true", "a free work slot: 0 of %d in use true" % Works.slots(g, MLO),
		"150 of %s ducats true" % Words.number(c.treasury), "10 of %d timber true" % c.stock[g.defs.good_id(&"timber")],
		"10 of %d stone true" % c.stock[g.defs.good_id(&"stone")]] as Array[String])
	assert_eq(card["lands"], {"upkeep": 4})
	assert_eq([card["year"], card["by_season"], card["chips"], card["payback"], card["brings"], card["map_marks"], card["ghost"]],
		[{}, [], [], {}, [], {}, {}])
	assert_eq(card["next_stages"][0]["text"], BarracksView.ABOUT)
	assert_eq(card["expensive"], 150 * 1000 > c.treasury * g.defs.expensive_permille)
	g.dev_money(MLO, -c.treasury + 200)
	assert_true(bool(ImprovePreview.of(g, MLO, town, BarracksView.option())["expensive"]), "dear for this treasury")
	var refused := ImprovePreview.of(g, MLO, _settlement(g, 1, 2), BarracksView.option())
	assert_eq([refused["blocked_by"], refused["reason_words"]], [&"rule", "A barracks is built in a town or larger."])
	assert_eq(Works.game_action(Works.BARRACKS), "build_barracks")
	assert_eq(Works.game_action(Works.UPGRADE), "upgrade")


# ----- foreign land: only in sight ------------------------------------------------------------------------------------


## [a land hex of Savoy or Milan that Genoa sees, one it has discovered and does not see], both with a settlement.
func _foreign_pair(g: Game) -> Array[Vector2i]:
	var seen := Army.NO_HEX
	var light := Army.NO_HEX
	for i: int in g.map.hex_count():
		var hex := g.map.hex_of(i)
		if int(g.state.main_use[i]) != ImproveRules.SETTLEMENT or Territory.owner_tag(g, hex) in [&"", GEN] \
				or not Knowledge.discovered(g, GEN, hex):
			continue
		if Knowledge.sees(g, GEN, hex) and seen == Army.NO_HEX:
			seen = hex
		elif not Knowledge.sees(g, GEN, hex) and light == Army.NO_HEX:
			light = hex
	return [seen, light] as Array[Vector2i]


func _stand(g: Game, hex: Vector2i, on: bool) -> void:
	g.state.barracks[g.map.index_of(hex)] = 1 if on else 0
	g.version += 1


func _building_names(view: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in (view["land"] as Dictionary)["buildings"]:
		out.append("%s: %s" % [row["name"], row["state_text"]])
	return out


func _buildings_cell(view: Dictionary) -> String:
	for cell: Dictionary in view["strip"]:
		if cell["key"] == "buildings":
			return str(cell["value"])
	return ""


func test_a_foreign_barracks_is_among_the_land_facts_only_in_sight() -> void:
	var g := EconomyFixture.game(GEN)
	var pair := _foreign_pair(g)
	assert_ne(pair[0], Army.NO_HEX, "precondition: a foreign settlement in sight")
	assert_ne(pair[1], Army.NO_HEX, "precondition: a foreign settlement out of sight")
	_stand(g, pair[0], false)
	_stand(g, pair[1], false)
	var seen_without := TileView.of(g, GEN, pair[0]).duplicate(true)
	var light_without := TileView.of(g, GEN, pair[1]).duplicate(true)
	var card_without := HexCard.of(g, pair[1]).duplicate(true)
	_stand(g, pair[0], true)
	_stand(g, pair[1], true)
	var seen := TileView.of(g, GEN, pair[0])
	assert_eq(_building_names(seen), _building_names(seen_without) + (["Barracks: working"] as Array[String]))
	assert_eq([_buildings_cell(seen_without), _buildings_cell(seen)], ["1", "2"])
	assert_eq(TileView.of(g, GEN, pair[1]), light_without, "out of sight the tile reads as one without a barracks")
	assert_eq(HexCard.of(g, pair[1]), card_without)


func test_a_foreign_barracks_work_is_told_only_in_sight_and_another_work_as_before() -> void:
	var g := EconomyFixture.game(GEN)
	var pair := _foreign_pair(g)
	_stand(g, pair[0], false)
	_stand(g, pair[1], false)
	var light_without := TileView.of(g, GEN, pair[1]).duplicate(true)
	var works: Array[Work] = []
	for hex: Vector2i in pair:
		var work := Work.new()
		work.id = g.state.next_work_id
		g.state.next_work_id += 1
		work.tag = Territory.owner_tag(g, hex)
		work.hex = hex
		work.action = Works.BARRACKS
		work.family = ImproveRules.SETTLEMENT
		work.started_turn = g.turn
		work.seasons = 4
		work.seasons_left = 4
		g.state.works.append(work)
		works.append(work)
	g.version += 1
	var seen := TileView.of(g, GEN, pair[0])
	assert_true(_building_names(seen).has("barracks: building 1 of 4 seasons"), str(_building_names(seen)))
	assert_eq((seen["job"] as Dictionary)["label"], "barracks")
	assert_eq(TileView.of(g, GEN, pair[1]), light_without, "no row, no job line out of sight")
	assert_eq(WorksView.at(g, pair[1], GEN), {})
	assert_eq(HexCard.work_text(g, pair[1]), "")
	assert_false(WorksView.told(g, works[1], GEN))
	assert_true(WorksView.told(g, works[1], works[1].tag), "its owner is told")
	assert_ne(WorksView.at(g, pair[1]), {}, "the viewer \"\" sees all")
	works[1].action = Works.UPGRADE
	works[1].level_to = 5
	g.version += 1
	assert_true(WorksView.told(g, works[1], GEN), "another work is a fact of the land, as before (R18)")


# ----- the words ------------------------------------------------------------------------------------------------------


func _line(g: Game, kind: String) -> String:
	for n: int in range(g.chronicle.entries.size() - 1, -1, -1):
		var entry: Dictionary = g.chronicle.entries[n]
		if str(entry.get("kind", "")) == kind:
			return str(LogLines.line_of(g, entry, MLO).get("text", ""))
	return ""


func test_the_log_and_the_report_say_barracks_begun_at_the_place() -> void:
	var g := _game()
	var town := _settlement(g)
	var at := Words.at(g, town)
	assert_true(at.begins_with("at "), at)
	g.act("build_barracks", {"hex": town, "tag": MLO})
	assert_eq(_line(g, "work_started"), "Barracks begun %s. Ready Spring 1481. (−150 ducats)" % at)
	assert_eq(WorksView.headline(g, g.state.work_at(town), "begun", "Work begun"), "Barracks begun %s" % at)
	g.act("cancel_work", {"hex": town, "tag": MLO})
	assert_eq(_line(g, "work_cancelled"), "Barracks cancelled %s. (+150 ducats back)" % at)
	g.act("build_barracks", {"hex": town, "tag": MLO})
	Season.run(g)
	var report := JSON.stringify(SeasonSummary.of(g, MLO, g.turn - 1))
	assert_string_contains(report, "Barracks begun %s" % at)
	assert_false(report.contains("Work begun"), "the spending line says it too")
	assert_false(report.contains("Begun: barracks"))
	assert_eq(LogLines.cancelled_text("Barracks cancelled %s" % at, "lost", ""),
		"Barracks cancelled %s, the land was lost." % at)
	assert_eq(LogLines.cancelled_text("Cancelled: x", "blocked", "no room"), "Cancelled: x: no room.")


func test_another_works_headline_is_unchanged() -> void:
	var g := _game()
	var work := Work.new()
	work.hex = MILAN
	work.action = Works.UPGRADE
	work.family = ImproveRules.SETTLEMENT
	work.level_to = 5
	assert_eq(WorksView.headline(g, work, "begun", "Work begun"), "Work begun: walled town to city, Milan (9, 9)")
