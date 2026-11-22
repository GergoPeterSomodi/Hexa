## The ranks of the war lines of "What befell" (docs/architecture/m8-build-spec.md 4.14; K25b, SummaryWar.witnessed): a witnessed
## battle ranks by its killed and wounded (at least 100, rounded to a hundred as the viewer sees it), a siege 50, a capture 20, a
## war or peace 1,000. The battle is the Autumn 1480 battle of the Savoy story of test_summary_war (seed 1480, as Savoy). Its
## real witnesses are its two parties only, so a listed far witness (GEN) is added by hand, with the version bumped. Planted
## faults (P): a battle no one witnessed never appears; a small battle does not rank below 100.
extends GutTest

@warning_ignore_start("integer_division")

const SAV := &"SAV"
const MLO := &"MLO"
const GEN := &"GEN"
const STRANGER := &"TUS"
const TURIN := Vector2i(5, 9)
const IVREA := Vector2i(6, 8)
const VERCELLI := Vector2i(6, 9)
const DOMO := Vector2i(7, 6)
const ALESS := Vector2i(7, 9)
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


## Spring 1480: the declaration on Milan and the three raises and two marches of Savoy (test_summary_war's story).
func _spring_1480() -> void:
	assert_true(bool(_g.act("raise", {"hex": ALESS, "kind": 0, "count": 2, "tag": MLO})["ok"]), "Milan raises")
	assert_true(bool(_g.act("declare_war", {"target": MLO, "tag": SAV})["ok"]), "Savoy declares war on Milan")
	for h: Vector2i in [IVREA, TURIN, VERCELLI]:
		assert_true(bool(_g.act("raise", {"hex": h, "kind": 0, "count": 2, "tag": SAV})["ok"]), "two companies at %s" % str(h))
	_ivrea = Armies.at(_g, IVREA)[0].id
	_turin = Armies.at(_g, TURIN)[0].id
	_vercelli = Armies.at(_g, VERCELLI)[0].id
	assert_true(bool(_g.act("march", {"army": _ivrea, "goal": DOMO, "tag": SAV})["ok"]), "the Army of Ivrea to Domodossola")
	assert_true(bool(_g.act("march", {"army": _turin, "goal": VERCELLI, "tag": SAV})["ok"]), "the Army of Turin to Vercelli")
	_season()


## Autumn 1480: the Army of Turin joins Vercelli, which attacks Alessandria: the battle of the season.
func _to_autumn() -> void:
	_spring_1480()
	_season()
	assert_true(bool(_g.act("merge_armies", {"army": _turin, "into": _vercelli, "tag": SAV})["ok"]), "the Army of Turin joins Vercelli")
	assert_true(bool(_g.act("march", {"army": _vercelli, "goal": ALESS, "tag": SAV})["ok"]), "Vercelli attacks Alessandria")
	_season()


func _battle_entry() -> Dictionary:
	for entry: Dictionary in _g.chronicle.of_turn(AUTUMN_1480):
		if str(entry.get("kind", "")) == "battle_ended":
			return entry
	return {}


## Lists `viewer` among the witnesses of the Autumn battle: a hand edit of the chronicle entry (the producer lists the parties
## only in this fixture), with the version bumped.
func _list_witness(viewer: StringName) -> void:
	for entry: Dictionary in _g.chronicle.entries:
		if str(entry.get("kind", "")) == "battle_ended" and int(entry.get("turn", -1)) == AUTUMN_1480:
			var witnesses := PackedStringArray(entry.get("witnesses", PackedStringArray()))
			if not witnesses.has(String(viewer)):
				witnesses.append(String(viewer))
			entry["witnesses"] = witnesses
	_g.version += 1


## The line of `lines` whose text starts with `head`; {} when there is none.
func _line_starting(lines: Array[Dictionary], head: String) -> Dictionary:
	for line: Dictionary in lines:
		if str(line["text"]).begins_with(head):
			return line
	return {}


func _sum(values: Variant) -> int:
	var total := 0
	for value: Variant in values:
		total += int(value)
	return total


## The killed and wounded of both sides of the record, as the rank counts them.
func _casualties(record: BattleRecord) -> int:
	return _sum(record.end.get("killed", PackedInt32Array())) + _sum(record.end.get("wounded_total", PackedInt32Array()))


func _expected_battle_rank(total: int) -> int:
	return maxi(100, (total + 50) / 100 * 100)


func test_a_witnessed_battle_ranks_by_its_casualties_at_least_100() -> void:
	_to_autumn()
	_list_witness(GEN)
	var entry := _battle_entry()
	assert_true(Knowledge.witnessed(_g, entry, GEN), "GEN is a listed witness of the battle")
	var record := Battles.record(_g, int(entry["record"]))
	assert_not_null(record, "the record is kept")
	var line := _line_starting(SummaryWar.witnessed(_g, GEN, AUTUMN_1480), str(entry["name"]) + ": ")
	assert_false(line.is_empty(), "the witness has the battle's line")
	assert_eq(int(line["rank"]), _expected_battle_rank(_casualties(record)), "the rank is the casualties, rounded, at least 100")
	assert_true(int(line["rank"]) >= 100, "a battle ranks at least 100")


func test_a_small_battle_floors_at_100() -> void:
	_to_autumn()
	_list_witness(GEN)
	var entry := _battle_entry()
	var record := Battles.record(_g, int(entry["record"]))
	record.end["killed"] = PackedInt32Array([1, 2])
	record.end["wounded_total"] = PackedInt32Array([0, 1])
	_g.version += 1
	var line := _line_starting(SummaryWar.witnessed(_g, GEN, AUTUMN_1480), str(entry["name"]) + ": ")
	assert_false(line.is_empty(), "the battle's line is still there")
	assert_eq(int(line["rank"]), 100, "four casualties rank at the floor of 100")


func test_a_battle_with_many_casualties_outranks_a_siege_and_a_capture() -> void:
	_to_autumn()
	_list_witness(GEN)
	var entry := _battle_entry()
	var record := Battles.record(_g, int(entry["record"]))
	record.end["killed"] = PackedInt32Array([300, 300])
	record.end["wounded_total"] = PackedInt32Array([100, 100])
	var witnesses := [String(GEN), String(SAV), String(MLO)]
	_g.chronicle.add({"kind": "siege_started", "turn": AUTUMN_1480, "tag": MLO, "others": [SAV], "hex": DOMO, "name": "Domodossola",
		"need": 10, "level": 2, "garrison": 800, "men": 1000, "witnesses": witnesses})
	_g.chronicle.add({"kind": "district_captured", "turn": AUTUMN_1480, "tag": MLO, "others": [SAV], "hex": ALESS, "by": "walk",
		"owner": SAV, "witnesses": witnesses})
	_g.version += 1
	var lines := SummaryWar.witnessed(_g, GEN, AUTUMN_1480)
	var battle := _line_starting(lines, str(entry["name"]) + ": ")
	assert_false(battle.is_empty(), "the battle is witnessed")
	# Killed 600 and wounded 200 across both sides: 800 casualties, rounded to a hundred.
	assert_eq(int(battle["rank"]), _expected_battle_rank(800), "the battle ranks by its casualties: %d" % int(battle["rank"]))
	var ranks: Array[int] = []
	for line: Dictionary in lines:
		ranks.append(int(line["rank"]))
	assert_true(ranks.has(SummaryWar.RANK_SIEGE), "a witnessed siege ranks 50: %s" % str(ranks))
	assert_true(ranks.has(SummaryWar.RANK_CAPTURE), "a witnessed capture ranks 20: %s" % str(ranks))
	for rank: int in ranks:
		if rank != int(battle["rank"]):
			assert_true(int(battle["rank"]) > rank, "the battle outranks %d" % rank)


func test_a_declaration_of_others_is_witnessed_at_the_war_rank() -> void:
	_to_autumn()
	var lines := SummaryWar.witnessed(_g, GEN, SPRING_1480)
	assert_false(lines.is_empty(), "GEN knows both parties: the declaration is witnessed")
	for line: Dictionary in lines:
		assert_eq(int(line["rank"]), SummaryWar.RANK_WAR, "a war line of others ranks %d" % SummaryWar.RANK_WAR)


func test_planted_a_battle_no_one_witnessed_never_appears() -> void:
	_to_autumn()
	_list_witness(GEN)
	var entry := _battle_entry()
	assert_false(Knowledge.witnessed(_g, entry, STRANGER), "the stranger does not witness the battle")
	var lines := SummaryWar.witnessed(_g, STRANGER, AUTUMN_1480)
	assert_true(_line_starting(lines, str(entry["name"]) + ": ").is_empty(), "P: an unwitnessed battle is absent")
	assert_false(_line_starting(SummaryWar.witnessed(_g, GEN, AUTUMN_1480), str(entry["name"]) + ": ").is_empty(),
		"the same battle is there for the listed witness")


## "What befell" of the report sorts its lines by rank (SeasonSummary._section): the battle of others comes before the lower
## ranks, and the ranks never go up down the section.
func test_what_befell_sorts_the_war_lines_by_rank() -> void:
	_to_autumn()
	_list_witness(GEN)
	var entry := _battle_entry()
	var befell := {}
	for section: Dictionary in SeasonSummary.of(_g, GEN, AUTUMN_1480)["sections"]:
		if section["id"] == &"befell":
			befell = section
	assert_false(befell.is_empty(), "GEN has What befell this season")
	var lines := befell["lines"] as Array
	var battle := _line_starting(_lines_of(lines), str(entry["name"]) + ": ")
	assert_false(battle.is_empty(), "the battle of others is in What befell")
	var last := 1 << 30
	for line: Dictionary in lines:
		assert_true(int(line["rank"]) <= last, "What befell is in rank order: %s" % str(line["text"]))
		last = int(line["rank"])


func _lines_of(lines: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: Variant in lines:
		out.append(line as Dictionary)
	return out
