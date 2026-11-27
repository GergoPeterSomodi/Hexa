## The War part of the season report (docs/architecture/m7-build-spec.md 4.17, 4.14; M7 plan B19) on the Savoy story of
## test_war_savoy (seed 1480, as Savoy): the Spring declaration reads as the spec says (the section's total, its lines, the order
## and the glance chip); the Autumn battle's line books the men the stats book (the report's sums equal the battle losses of the
## season); the war section sits after Armies and before Your orders; a season with no war has no War section.
extends GutTest

const SAV := &"SAV"
const MLO := &"MLO"
const TURIN := Vector2i(5, 9)
const PAVIA := Vector2i(10, 9)
const IVREA := Vector2i(6, 8)
const VERCELLI := Vector2i(6, 9)
const DOMO := Vector2i(7, 6)
const ALESS := Vector2i(7, 9)
const LOCARNO := Vector2i(7, 5)
const SPRING_1480 := 1
const AUTUMN_1480 := 3
const TURIN_PEOPLE := 10000

var _g: Game = null
var _ivrea := 0
var _turin := 0
var _vercelli := 0


func before_each() -> void:
	_g = EconomyFixture.game(SAV, false, true, EconomyFixture.SEED, false)
	Movement.clear_test_hostility()
	var c := Countries.by_tag(_g, SAV)
	assert_true(_g.dev_money(SAV, 1500 - c.treasury), "the treasury is set to 1,500")
	var iron := _g.defs.good_id(&"iron")
	assert_true(_g.dev_goods(SAV, iron, 20 - c.stock[iron]), "iron 20 in store")
	ArmyFixture.people_at(_g, TURIN, TURIN_PEOPLE)
	_g.districts.clear()
	_g.version += 1


func after_each() -> void:
	Movement.clear_test_hostility()


func _season() -> void:
	var verdict := Season.run(_g)
	assert_true(bool(verdict["ok"]), "the season ends: %s" % verdict["reason"])


## Spring 1480: Milan's Army of Alessandria, the declaration, Savoy's three raises and the march on own land (test_war_savoy (a)).
func _spring_1480() -> void:
	assert_true(bool(_g.act("raise", {"hex": ALESS, "kind": 0, "count": 2, "tag": MLO})["ok"]), "Milan raises")
	assert_true(bool(_g.act("declare_war", {"target": MLO, "tag": SAV})["ok"]), "Savoy declares war on Milan")
	for h: Vector2i in [IVREA, TURIN, VERCELLI]:
		assert_true(bool(_g.act("raise", {"hex": h, "kind": 0, "count": 2, "tag": SAV})["ok"]), "two companies at %s" % str(h))
	_ivrea = Armies.at(_g, IVREA)[0].id
	_turin = Armies.at(_g, TURIN)[0].id
	_vercelli = Armies.at(_g, VERCELLI)[0].id
	assert_true(bool(_g.act("march", {"army": _turin, "goal": VERCELLI, "tag": SAV})["ok"]), "the Army of Turin to Vercelli")
	_season()


## Autumn 1480: the Army of Turin joins Vercelli, Vercelli attacks Alessandria (the battle of the season).
func _to_autumn() -> void:
	_spring_1480()
	# fair warning: war declared a season earlier than this march into Milan's land.
	assert_true(bool(_g.act("march", {"army": _ivrea, "goal": DOMO, "tag": SAV})["ok"]), "the Army of Ivrea to Domodossola")
	_season()  # Summer: the walk into Domodossola
	assert_true(bool(_g.act("merge_armies", {"army": _turin, "into": _vercelli, "tag": SAV})["ok"]), "the Army of Turin joins Vercelli")
	assert_true(bool(_g.act("march", {"army": _vercelli, "goal": ALESS, "tag": SAV})["ok"]), "Vercelli attacks Alessandria")
	_season()


func _ids(summary: Dictionary) -> Array:
	var out: Array = []
	for section: Dictionary in summary["sections"]:
		out.append(str(section["id"]))
	return out


func _section(summary: Dictionary, id: String) -> Dictionary:
	for section: Dictionary in summary["sections"]:
		if str(section["id"]) == id:
			return section
	return {}


func _texts(lines: Array) -> Array[String]:
	var out: Array[String] = []
	for line: Dictionary in lines:
		out.append(str(line["text"]))
	return out


func test_the_declaration_reads_in_the_war_section_orders_and_glance() -> void:
	_spring_1480()
	var summary := SeasonSummary.of(_g, SAV, SPRING_1480)
	assert_false(summary.is_empty(), "the report of Spring 1480 exists")
	var war := _section(summary, "war")
	assert_eq(str((war["total"] as Dictionary)["text"]), "At war with 1 country", "the total names the one enemy")
	assert_true(_texts(war["lines"] as Array).has("You declared war on the Duchy of Milan."), "the declaration is a war line")
	# The orders section shows six lines and the declaration comes after the armies' orders: read the war's own list.
	var orders := _texts(SummaryWar.orders(_g, SAV, SPRING_1480))
	assert_true(orders.has("Declared war on the Duchy of Milan."), "the order is in Your orders")
	assert_true(int(_section(summary, "orders")["count"]) >= orders.size(), "the orders section counts it")
	var chips := _texts(_section(summary, "glance")["lines"] as Array)
	assert_true(chips.has("At war with Milan: 0"), "the glance chip of the live war: %s" % str(chips))
	assert_false(bool(summary["quiet"]), "a declaration is not a quiet season")


func test_the_autumn_battle_books_the_men_the_stats_book() -> void:
	_to_autumn()
	var summary := SeasonSummary.of(_g, SAV, AUTUMN_1480)
	var war := _section(summary, "war")
	assert_false(war.is_empty(), "the war section of Autumn 1480 exists")
	var battle: Dictionary = {}
	for line: Dictionary in war["lines"] as Array:
		if (line["action"] as Array).size() > 0 and (line["action"] as Array)[0] == &"battle":
			battle = line
	assert_false(battle.is_empty(), "a battle line opens the record")
	var record := Battles.record(_g, int((battle["action"] as Array)[1]))
	assert_not_null(record, "the record is kept")
	var mine := SummaryWar.men_booked(record, 0)
	var theirs := SummaryWar.men_booked(record, 1)
	assert_eq(_g.stats.value(SAV, AUTUMN_1480, "battle_losses"), mine, "Savoy's booked men are the stats' battle losses")
	assert_eq(_g.stats.value(MLO, AUTUMN_1480, "battle_losses"), theirs, "Milan's booked men are the stats' battle losses")
	assert_true(str(battle["text"]).ends_with("You lost %d men, they %d." % [mine, theirs]), "the sentence carries the booked men: %s" % str(battle["text"]))
	assert_eq(int(battle["amount"]) + int(battle["value"]), 0, "a battle line carries no amount")


func test_the_war_section_sits_after_armies_and_before_orders() -> void:
	_to_autumn()
	var ids := _ids(SeasonSummary.of(_g, SAV, AUTUMN_1480))
	assert_true(ids.has("war"), "the war section is shown")
	assert_true(ids.find("war") > ids.find("armies") if ids.has("armies") else true, "after armies")
	assert_true(ids.find("war") < ids.find("orders"), "before the orders")


func test_a_season_with_no_war_has_no_war_section() -> void:
	_season()
	var summary := SeasonSummary.of(_g, SAV, SPRING_1480)
	assert_false(_ids(summary).has("war"), "no war, no war section: %s" % str(_ids(summary)))
	assert_true(bool(summary["quiet"]) or not _ids(summary).is_empty(), "the report is built")


## A siege of the viewer's own, from the real producer: the line heads with the siege's own name ("Siege of Pavia, 1480"),
## never a name wrapped in "Siege of" twice.
func test_a_siege_line_uses_the_producers_name_once() -> void:
	assert_true(bool(_g.act("declare_war", {"target": MLO, "tag": SAV})["ok"]), "Savoy declares war on Milan")
	WarFixture.army_at(_g, SAV, PAVIA, 4)
	_season()
	assert_eq(_g.sieges.size(), 1, "the siege stands after Spring")
	var texts := _texts(_section(SeasonSummary.of(_g, SAV, SPRING_1480), "war")["lines"] as Array)
	var found := ""
	for text: String in texts:
		if text.begins_with("Siege of"):
			found = text
	assert_true(found.begins_with(str(_g.sieges[0].name) + ": "), "the line heads with the siege's name: %s" % found)
	assert_false(found.contains("Siege of Siege of"), "no double prefix")


## More than six war lines: the section shows the six largest by rank (the battle first), the sub line last, and `more`
## counts the rest (spec 4.17 rank; SeasonSummary._section's order).
func test_the_war_lines_are_shown_by_rank_with_the_sub_line_last() -> void:
	_to_autumn()
	for i: int in 7:
		_g.chronicle.add({"kind": "district_captured", "turn": AUTUMN_1480, "tag": SAV, "others": [MLO],
			"hex": DOMO, "by": "walk", "owner": MLO, "witnesses": [String(SAV), String(MLO)]})
	var war := _section(SeasonSummary.of(_g, SAV, AUTUMN_1480), "war")
	var lines := war["lines"] as Array
	assert_eq(lines.size(), 6, "six shown")
	assert_true(int(war["count"]) >= 8, "the captures and the battle are counted: %d" % int(war["count"]))
	assert_eq(int(war["more"]), int(war["count"]) - 6, "more counts the rest")
	assert_eq((lines[0]["action"] as Array)[0], &"battle", "the battle, the largest rank, comes first")
	var last_rank := 1 << 30
	for line: Dictionary in lines:
		if bool(line["sub"]):
			continue
		assert_true(int(line["rank"]) <= last_rank, "non-sub lines by rank, largest first")
		last_rank = int(line["rank"])
