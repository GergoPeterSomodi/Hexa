## The worked example of docs/architecture/m7-build-spec.md 4.16 on "Italy, 1480", seed 1480, as Savoy, calm weather, Normal
## taxes (done-when 1 to 5 of the spec's M7 section; M7 plan B17). Every number is produced by the real code through Game.act
## and Season.run. The fixture only sets the Pavia army (WarFixture.army_at), which the action log does not carry, so the
## replay test runs the story without it. Numbers the spec gave by hand that the rules do not give are corrected in the spec
## text (4.16 (e): three districts and +3, not two and +2) and pinned here. Fair warning (moves-build-spec.md R73): the march into
## Milan's land (Domodossola) is ordered in Summer, a season after the Spring declaration; the new companies muster through
## Spring either way, so every pinned number stands.
extends GutTest

const SAV := &"SAV"
const MLO := &"MLO"
const VEN := &"VEN"
const TURIN := Vector2i(5, 9)
const IVREA := Vector2i(6, 8)
const VERCELLI := Vector2i(6, 9)
const DOMO := Vector2i(7, 6)
const ALESS := Vector2i(7, 9)
const LOCARNO := Vector2i(7, 5)
const PAVIA := Vector2i(10, 9)
const TREASURY := 1500
const IRON := 20
const TURIN_PEOPLE := 10000
const SPRING_1480 := 1
const SUMMER_1480 := 2
const AUTUMN_1480 := 3
const WINTER_1480 := 4
const SPRING_1481 := 5
const BATTLE_NAME := "Battle of Alessandria, 1480"
const SIEGE_NAME := "Siege of Pavia, 1480"
const TRUCE := "a truce with the Duchy of Milan holds until Spring 1483 (8 more seasons)"
const OPENED: Array[Vector2i] = [Vector2i(11, 9), Vector2i(11, 10), Vector2i(12, 8), Vector2i(12, 9), Vector2i(12, 10), Vector2i(11, 11)]

var _g: Game = null
var _milan_army := 0
var _ivrea := 0
var _turin := 0
var _vercelli := 0


func before_each() -> void:
	_g = EconomyFixture.game(SAV, false, true, EconomyFixture.SEED, false)
	Movement.clear_test_hostility()
	var c := Countries.by_tag(_g, SAV)
	assert_true(_g.dev_money(SAV, TREASURY - c.treasury), "the treasury is set to 1,500")
	var iron := _g.defs.good_id(&"iron")
	assert_true(_g.dev_goods(SAV, iron, IRON - c.stock[iron]), "iron 20 in store")
	ArmyFixture.people_at(_g, TURIN, TURIN_PEOPLE)
	_g.districts.clear()
	_g.version += 1


func after_each() -> void:
	Movement.clear_test_hostility()


func _season() -> void:
	var verdict := Season.run(_g)
	assert_true(bool(verdict["ok"]), "the season ends: %s" % verdict["reason"])


func _events(kind: String, from: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(from, _g.events.size()):
		var e: Dictionary = _g.events[i]
		if str(e.get("kind", "")) == kind:
			out.append(e)
	return out


## Spring 1480: Milan's Army of Alessandria, the declaration, Savoy's three raises, the Pavia army (d), and the march on own land.
func _spring_1480(with_pavia: bool = true) -> void:
	var milan := ArmyFixture.raise_now(_g, {"hex": ALESS, "kind": 0, "count": 2, "tag": MLO})
	assert_true(bool(milan["ok"]), "Milan raises its Army of Alessandria")
	_milan_army = int(milan["army"])
	assert_true(bool(_g.act("declare_war", {"target": MLO, "tag": SAV})["ok"]), "Savoy declares war on Milan")
	for h: Vector2i in [IVREA, TURIN, VERCELLI]:
		assert_true(bool(ArmyFixture.raise_now(_g, {"hex": h, "kind": 0, "count": 2, "tag": SAV})["ok"]), "two companies at %s" % str(h))
	_ivrea = Armies.at(_g, IVREA)[0].id
	_turin = Armies.at(_g, TURIN)[0].id
	_vercelli = Armies.at(_g, VERCELLI)[0].id
	if with_pavia:
		WarFixture.army_at(_g, SAV, PAVIA, 4)
	assert_true(bool(_g.act("march", {"army": _turin, "goal": VERCELLI, "tag": SAV})["ok"]), "the Army of Turin to Vercelli")
	_season()


## Summer 1480: the Army of Ivrea walks into Domodossola, the Army of Turin reaches Vercelli.
func _to_summer(with_pavia: bool = true) -> void:
	_spring_1480(with_pavia)
	# fair warning: war declared a season earlier than this march into Milan's land (refused in Spring).
	assert_true(bool(_g.act("march", {"army": _ivrea, "goal": DOMO, "tag": SAV})["ok"]), "the Army of Ivrea to Domodossola")
	_season()


## Autumn 1480: the Army of Turin joins Vercelli, Vercelli attacks Alessandria, Ivrea walks to Locarno.
func _to_autumn(with_pavia: bool = true) -> void:
	_to_summer(with_pavia)
	assert_true(bool(_g.act("merge_armies", {"army": _turin, "into": _vercelli, "tag": SAV})["ok"]), "the Army of Turin joins Vercelli")
	assert_true(bool(_g.act("march", {"army": _vercelli, "goal": ALESS, "tag": SAV})["ok"]), "Vercelli attacks Alessandria")
	assert_true(bool(_g.act("march", {"army": _ivrea, "goal": LOCARNO, "tag": SAV})["ok"]), "Ivrea marches on Locarno")
	_season()


func _through_bytes(body: Dictionary) -> Dictionary:
	return bytes_to_var(var_to_bytes(body)) as Dictionary


# ----- (a) done-when 1: the declaration -----------------------------------------------------------------------------------


func test_1_a_war_is_declared_and_its_refusals_read_as_the_spec_says() -> void:
	assert_false(Movement.open_to(_g, SAV, ALESS), "before the war, Milan's land is shut to Savoy's armies")
	var venice := _g.check("declare_war", {"target": VEN, "tag": SAV})
	assert_false(bool(venice["ok"]))
	assert_eq(str(venice["reason"]), "only neighbours go to war: the Republic of Venice shares no border with the Duchy of Savoy")
	var raised := ArmyFixture.raise_now(_g, {"hex": ALESS, "kind": 0, "count": 2, "tag": MLO})
	assert_true(bool(raised["ok"]), "Milan's army of 1,000 men at Alessandria")
	assert_eq(_g.act("declare_war", {"target": MLO, "tag": SAV}), {"ok": true, "reason": ""}, "Savoy declares war on Milan")
	var declared := _events("war_declared")
	assert_eq(declared.size(), 1, "one war_declared")
	assert_eq(declared[0]["tag"], SAV)
	assert_eq(declared[0]["target"], MLO)
	assert_eq((declared[0]["witnesses"] as Array).size(), 13, "every living country witnesses it: 13")
	assert_true(Movement.open_to(_g, SAV, ALESS), "Milan's land opens to Savoy's armies")
	assert_true(Movement.open_to(_g, MLO, VERCELLI), "Savoy's land opens to Milan's armies")
	var again := _g.check("declare_war", {"target": MLO, "tag": SAV})
	assert_eq(str(again["reason"]), "already at war with the Duchy of Milan")


# ----- (b) done-when 2: walking in -----------------------------------------------------------------------------------------


func test_2_domodossola_is_taken_by_walking_in_in_summer() -> void:
	_to_summer()
	assert_eq(Occupation.controller_tag(_g, DOMO), SAV, "Domodossola is occupied by Savoy")
	assert_eq(Territory.owner_tag(_g, DOMO), MLO, "its owner stays Milan")
	var captured := _events("district_captured")
	assert_eq(captured.size(), 1, "one district captured")
	assert_eq(captured[0]["hex"], DOMO)
	assert_eq(captured[0]["by"], &"walk", "taken by walking in")
	assert_eq(captured[0]["turn"], SUMMER_1480)
	assert_eq(_events("controllers_changed").size(), 1, "one controllers_changed")
	assert_eq(Wars.score(_g, SAV, MLO), 1, "Savoy's war score against Milan is +1")
	var ivrea := Armies.by_id(_g, _ivrea)
	assert_eq(ivrea.hex, DOMO)
	assert_eq(ivrea.men(), 1000, "no loss on the walk: Domodossola is in supply")


# ----- (c) done-when 3: the battle -----------------------------------------------------------------------------------------


func test_3_the_battle_of_alessandria_is_fought_in_autumns_battles_phase() -> void:
	_to_autumn()
	var started := _events("battle_started")
	assert_eq(started.size(), 1, "one battle_started")
	assert_eq(started[0]["name"], BATTLE_NAME)
	assert_eq(started[0]["hex"], ALESS)
	assert_eq(started[0]["tick"], 1, "it starts at tick 1 of Autumn's movement")
	var ended := _events("battle_ended")
	assert_eq(ended.size(), 1, "one battle_ended")
	var e: Dictionary = ended[0]
	assert_eq(e["winner"], SAV)
	assert_eq(e["loser"], MLO)
	assert_eq(str(e["how"]), "broke")
	assert_eq(str(e["cause"]), "centre")
	assert_eq(int(e["days"]), 1, "fought in one day")
	assert_eq(e["killed"], {SAV: 49, MLO: 200}, "killed: 49 Savoy, 200 Milan")
	assert_eq(e["wounded"], {SAV: 48, MLO: 70}, "wounded: 48 Savoy, 70 Milan")
	assert_eq(e["retreat"], Vector2i(7, 8), "Milan falls back to (7, 8)")
	var fought := _events("battle_fought")
	assert_eq(fought.size(), 1)
	assert_eq(int(fought[0]["days"]), 1, "battle_fought once, one day")
	var record := Battles.record(_g, int(e["record"]))
	assert_not_null(record, "the battle has its record")
	assert_eq(record.name, BATTLE_NAME)
	assert_eq(record.frames.size(), 1, "the record holds one day")
	assert_eq(Array(record.end["killed"]), [49, 200], "the record's killed match the event")
	assert_eq(Array(record.end["wounded_total"]), [48, 70], "the record's wounded match the event")
	assert_eq(Armies.by_id(_g, _vercelli).hex, ALESS, "the winner stands on Alessandria")
	assert_eq(Armies.by_id(_g, _vercelli).men(), 1903, "Vercelli: 2,000 less 49 killed and 48 wounded who did not return")
	# Milan's men at the battle's end: each company's fit men plus the wounded who returned, which is 1,000 less 200 killed
	# and 35 wounded who did not return. The season's ready_units then refills 50 a company, so the army has 865 by the end.
	var men: Dictionary = record.end["men"]
	var back: Dictionary = record.end["returned"]
	var milan_men := 0
	for u: Unit in Armies.by_id(_g, _milan_army).units:
		milan_men += int(men.get(u.id, 0)) + int(back.get(u.id, 0))
	assert_eq(milan_men, 765, "Milan at the battle's end: 1,000 less 200 killed and 35 wounded who did not return")
	assert_eq(Armies.by_id(_g, _milan_army).hex, Vector2i(7, 8), "Milan's army is at (7, 8)")
	assert_eq(Armies.by_id(_g, _milan_army).men(), 865, "Milan at the end of Autumn: 765 and the refill of 50 a company (2)")


func test_3b_combat_fight_from_the_records_input_and_luck_gives_the_same_day_and_totals() -> void:
	_to_autumn()
	var record := Battles.record(_g, int(_events("battle_ended")[0]["record"]))
	var rng := Rng.new()
	rng.set_state(record.luck_before)
	var out: Dictionary = Combat.fight(_g.defs.war, record.input.duplicate(true), rng)
	var frames: Array = out["frames"]
	var end: Dictionary = out["end"]
	assert_eq(frames.size(), record.frames.size(), "the same number of days")
	for i: int in record.frames.size():
		assert_eq(BattleRecord.plain(frames[i]), BattleRecord.plain(record.frames[i]), "day %d is the same" % i)
	for key: String in ["how", "cause", "winner", "loser", "days", "men", "morale", "wounded", "killed", "wounded_total"]:
		assert_eq(BattleRecord.plain(end[key]), BattleRecord.plain(record.end[key]), "end.%s is the same" % key)
	assert_eq(Armies.by_id(_g, _ivrea).hex, LOCARNO, "the Army of Ivrea takes Locarno")
	assert_eq(_events("district_captured", 0).size(), 2, "Domodossola and Locarno so far")
	assert_eq(Wars.score(_g, SAV, MLO), 2, "Savoy's war score is +2 after Locarno")


# ----- (d) done-when 4: the siege of Pavia --------------------------------------------------------------------------------


func test_4_pavia_falls_at_the_end_of_its_fourth_season_of_siege() -> void:
	_spring_1480()
	var started := _events("siege_started")
	assert_eq(started.size(), 1, "one siege_started, in spring")
	assert_eq(started[0]["name"], SIEGE_NAME)
	assert_eq(Sieges.at(_g, PAVIA).progress, 2, "Spring: the meter at 2")
	assert_eq(Occupation.siege_need(_g, PAVIA), 10, "need 4 + 3 x 2 = 10")
	assert_eq(Occupation.garrison_of(_g, PAVIA), 800, "the garrison of 800")
	_season()
	assert_eq(Sieges.at(_g, PAVIA).progress, 4, "Summer: 4")
	_season()
	assert_eq(Sieges.at(_g, PAVIA).progress, 6, "Autumn: 6")
	_season()
	assert_null(Sieges.at(_g, PAVIA), "Winter: the siege is over")
	var by_siege: Dictionary = {}
	for f: Dictionary in _events("district_captured"):
		if f.get("by") == &"siege":
			by_siege = f
	assert_eq(by_siege.get("hex"), PAVIA, "Pavia is captured by siege")
	assert_eq(by_siege.get("seasons"), 4, "after its fourth season")
	assert_eq(int(by_siege.get("garrison_lost")), 800, "the garrison of 800 is lost")
	assert_eq(Occupation.controller_tag(_g, PAVIA), SAV, "Savoy occupies Pavia")
	assert_eq(Occupation.garrison_of(_g, PAVIA), 0, "no garrison is left")
	var got: Array[Vector2i] = []
	for h: Variant in by_siege.get("opened"):
		got.append(h as Vector2i)
	got.sort()
	var want: Array[Vector2i] = OPENED.duplicate()
	want.sort()
	assert_eq(got, want, "six districts of Pavia's area lie open")


func test_4b_a_save_in_the_third_season_of_the_siege_plays_on_to_the_same_digest() -> void:
	_to_autumn()
	assert_eq(Sieges.at(_g, PAVIA).progress, 6, "the save is made in the third season of the siege")
	var body := Snapshot.of(_g)
	var loaded := Snapshot.restore(_through_bytes(body), _g.map, _g.defs)
	assert_not_null(loaded["game"], str(loaded["problem"]))
	var copy := loaded["game"] as Game
	assert_eq(copy.digest(), _g.digest(), "the loaded save has the live digest")
	assert_eq(var_to_bytes(Snapshot.of(copy)), var_to_bytes(body), "save, load, save: byte-equal")
	_season()
	_season()
	var back: Game = copy
	Season.run(back)
	Season.run(back)
	assert_eq(back.digest(), _g.digest(), "the loaded save plays on to the same digest")
	assert_eq(Occupation.controller_tag(back, PAVIA), SAV, "and Pavia falls there too")


# ----- (e) done-when 5: the peace --------------------------------------------------------------------------------------


func test_5_the_take_moves_three_districts_and_a_truce_follows() -> void:
	_to_autumn()
	_season()  # winter 1480 (game.turn 4 while it runs): Pavia falls; now game.turn is 5, Spring 1481
	assert_eq(_g.turn, SPRING_1481, "the peace is made in Spring 1481")
	assert_eq(Wars.score(_g, SAV, MLO), 3, "Savoy holds three of Milan's districts: Domodossola, Locarno and Pavia")
	var verdict := _g.act("make_peace", {"target": MLO, "terms": &"take", "tag": SAV})
	assert_true(bool(verdict["ok"]), "the take is accepted: %s" % verdict["reason"])
	assert_null(Wars.war_between(_g, SAV, MLO), "the war is over")
	var peace := _events("peace_made")
	assert_eq(peace.size(), 1)
	assert_eq(peace[0]["terms"], &"take")
	assert_eq((peace[0]["moved"] as Array).size(), 3, "three districts move: Domodossola, Locarno and Pavia")
	var owners := _events("owners_changed")
	assert_eq(owners.size(), 1, "one owners_changed")
	assert_eq(owners[0]["tag"], SAV)
	assert_eq(Territory.owner_tag(_g, DOMO), SAV)
	assert_eq(Territory.owner_tag(_g, LOCARNO), SAV)
	assert_eq(Territory.owner_tag(_g, PAVIA), SAV)
	assert_eq(Wars.occupied_count(_g, SAV, MLO), 0, "every occupation between the two is cleared")
	var army := Armies.by_id(_g, _vercelli)
	assert_eq(Territory.owner_tag(_g, army.hex), SAV, "the Army of Vercelli is back on Savoy's land")
	assert_eq(army.hex, VERCELLI, "to its nearest own hex with room: Vercelli (6, 9), one step off Alessandria")
	var refused := _g.check("declare_war", {"target": MLO, "tag": SAV})
	assert_eq(str(refused["reason"]), TRUCE)


func test_5b_a_white_peace_in_a_copy_returns_the_districts_to_milan() -> void:
	_to_autumn()
	_season()
	var body := _through_bytes(Snapshot.of(_g))
	var copy := Snapshot.restore(body, _g.map, _g.defs)["game"] as Game
	assert_true(bool(copy.act("make_peace", {"target": MLO, "terms": &"white", "tag": SAV})["ok"]), "the white peace is accepted")
	assert_eq(Occupation.controller_tag(copy, DOMO), MLO, "Domodossola goes back to Milan's control")
	assert_eq(Occupation.controller_tag(copy, PAVIA), MLO, "Pavia goes back to Milan's control")
	assert_eq(Territory.owner_tag(copy, DOMO), MLO, "its owner is Milan")
	assert_eq(Wars.occupied_count(copy, SAV, MLO), 0)


# ----- done-when 8: the log replays to the same digest; the stats of the war -------------------------------------------


func test_replay_of_the_action_log_gives_the_same_digest() -> void:
	# The story without the fixture's Pavia army (it is not in the action log).
	_to_autumn(false)
	_season()
	assert_true(bool(_g.act("make_peace", {"target": MLO, "terms": &"take", "tag": SAV})["ok"]))
	var replayed := Replay.run(_g.map, _g.defs, _g.scenario.id, _g.seed_value, _g.action_log)
	assert_not_null(replayed, "the scenario is found")
	assert_eq(replayed.digest(), _g.digest(), "the replay of the log gives the live digest")


func test_stats_of_the_war() -> void:
	_to_autumn()
	assert_eq(_g.stats.value(SAV, AUTUMN_1480, "battles_won"), 1, "Savoy won one battle")
	assert_eq(_g.stats.value(MLO, AUTUMN_1480, "battles_lost"), 1, "Milan lost one battle")
	assert_eq(_g.stats.value(SAV, AUTUMN_1480, "battles_lost"), 0, "Savoy lost none (the record's loser is a tag: fixed in stats_system)")
	assert_eq(_g.stats.value(SAV, AUTUMN_1480, "battle_losses"), 97, "Savoy's battle losses: 49 killed and 48 wounded who did not return")
	assert_eq(_g.stats.value(MLO, AUTUMN_1480, "battle_losses"), 235, "Milan's battle losses: 200 killed and 35 wounded who did not return")
	assert_eq(_g.stats.value(MLO, AUTUMN_1480, "districts_lost"), 2, "Milan lost two districts (Domodossola and Locarno)")
	assert_eq(_g.stats.value(SAV, AUTUMN_1480, "districts_lost"), 0, "Savoy lost no district")
