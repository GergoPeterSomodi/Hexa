## A company that fights twice in one season (issue #465; moves in the month: a company fights in an act and may be attacked
## again): its wounded go back after the first battle and it is gone after the second. The returns of the first battle still
## count for its side everywhere the losses are read: the season's stats, the battle summary, the war's books and the soak's
## `men` invariant read the side from the record's input fighters (BattleRecord.returned_by_side), not from the armies alive.
## North Italy: a Milanese company on its own land, hemmed in by Savoy; a weak attack it beats, then a strong one it cannot
## leave, so it surrenders.
extends GutTest

const SAV := MovesFixture.SAVOY
const MLO := MovesFixture.MILAN
const WEAK_MEN := 300
const STRONG_COMPANIES := 6

var _g: Game
var _hex := Army.NO_HEX
var _weak: Army
var _strong: Army
var _target: Army


func before_each() -> void:
	Movement.clear_test_hostility()
	_g = ArmyFixture.game()
	WarFixture.at_war(_g, SAV, MLO)
	_hex = _pocket()
	assert_ne(_hex, Army.NO_HEX, "a Milanese hex in supply with two plain steps onto it from land Savoy may stand on")
	_target = ArmyFixture.army(_g, MLO, _hex, 0, 2)
	var sides := _plain_sides(_hex)
	_weak = ArmyFixture.army(_g, SAV, sides[0], 0, 1)
	Armies.lose_men(_g, _weak, _weak.men() - WEAK_MEN, &"rig")  # before the season's census: not a flow of the season
	_strong = ArmyFixture.army(_g, SAV, sides[1], 0, STRONG_COMPANIES)
	for d: int in 6:
		var n := _g.map.neighbour(_hex, d)
		if _g.map.index_of(n) >= 0 and _g.map.is_land(n):
			ArmyFixture.army(_g, SAV, n, 0, 1)  # on the attackers' hexes too: a hex they leave stays shut to a retreat
	Sight.refresh(_g)


func after_each() -> void:
	Movement.clear_test_hostility()


## The sides of `hex` from which one plain step leads onto it, on land Savoy may stand on.
func _plain_sides(hex: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var m := _g.map
	var steps := StepCosts.of(m, _g.defs)
	for d: int in 6:
		var n := m.neighbour(hex, d)
		if m.index_of(n) < 0 or not m.is_land(n) or not Movement.open_to(_g, SAV, n):
			continue
		var c := steps.cost(m.index_of(n), Movement.direction(m, m.index_of(n), m.index_of(hex)), false)
		if c >= 1 and c <= 6:
			out.append(n)
	return out


## The first Milanese hex without walls, in Milan's supply, with two plain sides and every land side open to Savoy.
func _pocket() -> Vector2i:
	for i: int in _g.map.hex_count():
		var hex := _g.map.hex_of(i)
		if not _g.map.is_land(hex) or Territory.owner_tag(_g, hex) != MLO or Occupation.fortress_level(_g, hex) > 0:
			continue
		if not Supply.in_supply(_g, MLO, hex, false) or _plain_sides(hex).size() < 2:
			continue
		var open := true
		for d: int in 6:
			var n := _g.map.neighbour(hex, d)
			if _g.map.index_of(n) >= 0 and _g.map.is_land(n) and not Movement.open_to(_g, SAV, n):
				open = false
		if open:
			return hex
	return Army.NO_HEX


## Both attacks, each a march walked and fought in its act; the two records (the first returns men, the second ends the army).
func _fight_twice() -> Array[BattleRecord]:
	var out: Array[BattleRecord] = []
	for a: Army in [_weak, _strong]:
		var res := _g.act("march", {"army": a.id, "goal": _hex, "tag": SAV})
		assert_true(bool(res.ok), str(res.reason))
		assert_eq(StringName(res.walk.stopped), WalkNow.FOUGHT, "the march fights")
		var rec := Battles.record(_g, int(res.walk.battle))
		assert_not_null(rec)
		out.append(rec)
	return out


func _sum(returned: Dictionary, units: PackedInt32Array) -> int:
	var out := 0
	for key: Variant in returned:
		if units.has(int(key)):
			out += int(returned[key])
	return out


func _unit_ids(army: Army) -> PackedInt32Array:
	var out := PackedInt32Array()
	for u: Unit in army.units:
		out.append(u.id)
	return out


## The scene works: Milan's companies get wounded back in the first battle and are gone after the second.
func test_the_wounded_go_back_and_the_company_dies_later_the_same_season() -> void:
	var target_units := _unit_ids(_target)
	var target_id := _target.id
	var recs := _fight_twice()
	assert_gt(_sum(recs[0].end["returned"], target_units), 0, "Milan's wounded went back after the first battle")
	assert_null(Armies.by_id(_g, target_id), "and its army is gone after the second")
	assert_eq(recs[0].turn, recs[1].turn, "in one season")


func test_the_men_invariant_holds() -> void:
	var before := Invariants.before(_g)
	_g.events.clear()
	before["events"] = 0
	_fight_twice()
	assert_true(bool(Season.run(_g).ok))
	var men := PackedStringArray()
	for line: String in Invariants.check(_g, before):
		if line.begins_with("men:"):
			men.append(line)
	assert_eq(men.size(), 0, "no man unbooked: %s" % str(men))


func test_the_stats_take_the_returned_wounded_back() -> void:
	var target_units := _unit_ids(_target)
	var recs := _fight_twice()
	var want := 0
	for rec: BattleRecord in recs:
		assert_eq(rec.defender, MLO)
		want += int(rec.end["killed"][1]) + int(rec.end["wounded_total"][1]) - _sum(rec.end["returned"], target_units)
	var ended := _g.turn
	assert_true(bool(Season.run(_g).ok))
	assert_eq(_g.stats.value(MLO, ended, "battle_losses"), want, "the season's stats")


func test_the_summary_and_the_war_books_agree() -> void:
	var target_units := _unit_ids(_target)
	var war := Wars.war_between(_g, SAV, MLO)
	var recs := _fight_twice()
	var booked := 0
	for rec: BattleRecord in recs:
		var want := int(rec.end["killed"][1]) + int(rec.end["wounded_total"][1]) - _sum(rec.end["returned"], target_units)
		assert_eq(SummaryWar.men_booked(rec, 1), want, "the summary's men of the battle at the record %d" % rec.id)
		booked += want
	assert_eq(war.lost_b, booked, "the war's books of Milan")
