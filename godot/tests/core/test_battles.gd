## The battles of M7 B8 (docs/architecture/m7-build-spec.md 4.6, 4.7, 5.3; M7 plan B8): the check and the start of a battle, joins and
## the stack limit, storms, the battles phase with its books and records, the beaten side's retreat or surrender, names, the records
## kept, the save body and its refusals, the sack, and the Armies door's morale, experience, standing and ranks. Every game comes
## from WarFixture (the 1480 scenario with copied definitions), so a planted number never reaches the committed war.
extends GutTest

const OUTCOMES: Array[String] = ["broke", "withdrew", "surrendered", "destroyed", "gone"]

var _g: Game
var _a: StringName
var _b: StringName
var _ha: Vector2i
var _hb: Vector2i


func before_each() -> void:
	_g = WarFixture.game()
	Occupation.setup(_g)  # B13 wires this into new_scenario; until then the fixture sets the garrisons
	_a = ArmyFixture.TAG
	_b = WarFixture.neighbour_of(_g, _a)
	var pair := _border(_g, _a, _b)
	assert_eq(pair.size(), 2, "Genoa shares a border with a neighbour")
	if pair.size() == 2:
		_ha = pair[0]
		_hb = pair[1]
	WarFixture.at_war(_g, _a, _b)


## Two adjacent land hexes: the first held by a, the second by b (empty when none).
func _border(g: Game, a: StringName, b: StringName) -> Array[Vector2i]:
	for i: int in g.map.hex_count():
		var h := g.map.hex_of(i)
		if not g.map.is_land(h) or Territory.owner_tag(g, h) != a:
			continue
		for d: int in 6:
			var n := g.map.neighbour(h, d)
			if g.map.has(n) and g.map.is_land(n) and Territory.owner_tag(g, n) == b:
				return [h, n]
	return []


## A land hex held by tag with a garrisoned fortress (Army.NO_HEX when none).
func _fortress_of(tag: StringName) -> Vector2i:
	for i: int in _g.map.hex_count():
		var h := _g.map.hex_of(i)
		if _g.map.is_land(h) and Occupation.fortress_level(_g, h) > 0 and Occupation.controller_tag(_g, h) == tag \
				and Occupation.garrison_of(_g, h) > 0:
			return h
	return Army.NO_HEX


func _kinds() -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in _g.events:
		out.append(str(e.get("kind", "")))
	return out


## An attack of two companies on the defender's two companies at _hb: the attacker stands on _hb.
func _start_battle() -> Army:
	var att := WarFixture.army_at(_g, _a, _ha, 2)
	WarFixture.army_at(_g, _b, _hb, 2)
	assert_true(Battles.engage(_g, att, _hb, 1, -1), "the attack starts a battle")
	return att


# --- the check and the start ----------------------------------------------------------------------------------------


func test_engage_check_names_each_refusal() -> void:
	assert_eq(Battles.engage_check(_g, {}).reason, "no army given")
	var att := WarFixture.army_at(_g, _a, _ha, 2)
	assert_eq(Battles.engage_check(_g, {"army": 999999, "tag": _a}).reason, "no army 999999")
	assert_true(str(Battles.engage_check(_g, {"army": att.id, "tag": _b}).reason).begins_with("not your army:"))
	var stranger := WarFixture.stranger_of(_g, _a)
	assert_ne(stranger, &"", "a country shares no border with Genoa")
	WarFixture.army_at(_g, stranger, _hb, 1)
	assert_true(str(Battles.engage_check(_g, {"army": att.id, "hex": _hb, "tag": _a}).reason).begins_with(
		"another country's army stands at"))


func test_engage_check_refuses_a_shaken_army() -> void:
	var att := WarFixture.army_at(_g, _a, _ha, 2)
	WarFixture.army_at(_g, _b, _hb, 2)
	for u: Unit in att.units:
		u.morale = 100
	var v := Battles.engage_check(_g, {"army": att.id, "hex": _hb, "tag": _a})
	assert_false(v.ok)
	assert_true(str(v.reason).begins_with("too shaken to attack: morale 10 %, 50 % needed"), str(v.reason))
	assert_false(Battles.engage(_g, att, _hb, 1, -1), "a refused attack changes nothing")
	assert_eq(att.hex, _ha)


func test_attack_starts_a_battle_and_a_join_takes_a_company() -> void:
	var att := _start_battle()
	var b := Battles.at(_g, _hb)
	assert_not_null(b)
	assert_eq(b.attacker, _a)
	assert_eq(b.defender, _b)
	assert_eq(att.hex, _hb, "the attacker stands on the battle hex")
	assert_eq(att.order, Army.ORDER_NONE, "the march ends in the battle")
	assert_true(b.name.begins_with("Battle of") or b.name.begins_with("Battle at"), b.name)
	assert_true(_kinds().has("battle_started"))
	var second := WarFixture.army_at(_g, _a, _ha, 1)
	assert_true(Battles.engage(_g, second, _hb, 2, -1), "a company of the same side joins")
	assert_eq((b.armies[String(_a)] as PackedInt32Array).size(), 2)
	assert_true(_kinds().has("battle_joined"))


func test_a_ninth_company_is_refused() -> void:
	_start_battle()
	var limit: int = _g.defs.stack_limit
	var big := WarFixture.army_at(_g, _a, _ha, limit - 1)
	var v := Battles.engage_check(_g, {"army": big.id, "hex": _hb, "tag": _a})
	assert_false(v.ok)
	assert_eq(v.reason, "no room: 2 of %d companies of yours stand there already" % limit)


func test_a_plain_step_changes_nothing() -> void:
	var att := WarFixture.army_at(_g, _a, _ha, 2)
	var before := Armies.digest(_g)
	assert_false(Battles.engage(_g, att, _ha, 0, -1))
	assert_eq(Armies.digest(_g), before)
	assert_true(_g.battles.is_empty())


func test_a_storm_order_on_a_hostile_fortress_starts_an_assault() -> void:
	var fort := Army.NO_HEX
	var holder: StringName = &""
	for i: int in _g.war_cache.fortresses(_g):
		var h := _g.map.hex_of(i)
		if Occupation.garrison_of(_g, h) > 0 and Occupation.controller_tag(_g, h) != _a \
				and Occupation.controller_tag(_g, h) != &"":
			fort = h
			holder = Occupation.controller_tag(_g, h)
			break
	assert_ne(fort, Army.NO_HEX, "the 1480 map has a garrisoned fortress of another country")
	if fort == Army.NO_HEX:
		return
	WarFixture.at_war(_g, _a, holder)
	var att := WarFixture.army_at(_g, _a, _ha, 3)
	Armies.set_hex(_g, att, fort, att.hex)
	Armies.set_order(_g, att, Army.ORDER_STORM, fort, PackedInt32Array())
	assert_true(Battles.engage(_g, att, fort, 0, -1))
	var b := Battles.at(_g, fort)
	assert_not_null(b)
	if b == null:
		return
	assert_true(b.assault)
	assert_eq(b.defender, holder)
	assert_eq(b.armies.size(), 1, "only the attacker is in the storm")
	assert_eq(att.order, Army.ORDER_NONE)


func test_a_repeat_battle_is_named_second() -> void:
	var first := Battles.name_for(_g, _hb)
	var second := Battles.name_for(_g, _hb)
	assert_true(first.begins_with("Battle"), first)
	assert_true(second.begins_with("Second Battle"), second)
	assert_true(second.ends_with(", %d" % Calendar.year_of(_g.turn, _g.start_year)), second)


# --- the battles phase ----------------------------------------------------------------------------------------------


func test_the_phase_fights_books_and_keeps_a_record() -> void:
	_start_battle()
	var before := Armies.men_of_country(_g, _a) + Armies.men_of_country(_g, _b)
	Battles.season(_g)
	assert_true(_g.battles.is_empty(), "no battle is left after the phase")
	assert_eq(_g.battle_records.size(), 1)
	var rec: BattleRecord = _g.battle_records[0]
	assert_eq(rec.frames.size(), int(rec.end["days"]), "one frame a day")
	assert_true(OUTCOMES.has(str(rec.end["how"])), str(rec.end["how"]))
	assert_true(_kinds().has("battle_fought"))
	assert_true(_kinds().has("battle_ended"))
	var after := Armies.men_of_country(_g, _a) + Armies.men_of_country(_g, _b)
	var w: War = _g.wars[0]
	assert_eq(before - after, w.lost_a + w.lost_b, "the war books every man the armies lost")


func test_the_beaten_side_retreats_or_surrenders() -> void:
	var att := WarFixture.army_at(_g, _a, _ha, 4)
	var d := WarFixture.army_at(_g, _b, _hb, 1)
	d.units[0].men = 40
	assert_true(Battles.engage(_g, att, _hb, 1, -1))
	Battles.season(_g)
	var rec: BattleRecord = _g.battle_records[0]
	var still := Armies.by_id(_g, d.id)
	if still == null:
		assert_true(str(rec.end["how"]) == "surrendered" or str(rec.end["how"]) == "destroyed", str(rec.end["how"]))
	else:
		assert_ne(still.hex, _hb, "the beaten army leaves the battle hex")
		assert_eq(still.halt_why, &"defeated")
		assert_true((rec.end["retreat"] as Dictionary).has(d.id))


func test_a_retreat_path_avoids_the_enemy() -> void:
	var d := WarFixture.army_at(_g, _b, _hb, 2)
	WarFixture.army_at(_g, _a, _ha, 2)
	var list: Array[Army] = [d]
	var path := Battles.retreat_path(_g, _b, list, _hb, false)
	assert_false(path.is_empty(), "the defender has land to fall back on")
	assert_false(path.has(_ha), "never into the attacker's hex")
	for h: Vector2i in path:
		for a: Army in Armies.at(_g, h):
			assert_false(Wars.at_war(_g, _b, a.tag), "no enemy on the way")


func test_the_records_kept_are_the_newest() -> void:
	_g.defs.war.battle_records_kept = 2
	for _k: int in 3:
		var att := WarFixture.army_at(_g, _a, _ha, 2)
		WarFixture.army_at(_g, _b, _hb, 2)
		assert_true(Battles.engage(_g, att, _hb, 1, -1))
		Battles.season(_g)
	assert_eq(_g.battle_records.size(), 2)
	assert_eq(_g.battle_records[1].id, 3)
	assert_eq(_g.battle_records[0].id, 2)


func test_the_battle_is_deterministic_under_the_same_seed() -> void:
	var first := _outcome_digest()
	_g = WarFixture.game()
	Occupation.setup(_g)
	_a = ArmyFixture.TAG
	_b = WarFixture.neighbour_of(_g, _a)
	var pair := _border(_g, _a, _b)
	_ha = pair[0]
	_hb = pair[1]
	WarFixture.at_war(_g, _a, _b)
	assert_eq(_outcome_digest(), first)


func _outcome_digest() -> String:
	_start_battle()
	Battles.season(_g)
	return Battles.digest(_g) + "|" + str(_g.battle_records[0].end["days"]) + "|" + str(_g.luck.world.get_state())


# --- the save body and its refusals ----------------------------------------------------------------------------------


func test_the_digest_moves_and_a_pending_battle_reads_back() -> void:
	var before := Battles.digest(_g)
	_start_battle()
	var pending := Battles.digest(_g)
	assert_ne(before, pending)
	var saved := Battles.to_dict(_g)
	assert_eq(Battles.from_dict(saved, _g), "", "a saved pending battle reads back")
	assert_eq(Battles.digest(_g), pending)


func test_a_battle_with_an_unknown_army_is_refused() -> void:
	_start_battle()
	var saved := Battles.to_dict(_g)
	var pending := Battles.digest(_g)
	((saved["battles"] as Array)[0]["armies"] as Dictionary)[String(_a)] = [999999]
	assert_eq(Battles.from_dict(saved, _g), Battles.PROBLEM_BODY)
	assert_eq(Battles.digest(_g), pending, "a refused body changes nothing")


# --- the sack and the Armies door -----------------------------------------------------------------------------------


func test_a_stormed_walled_town_loses_its_people() -> void:
	var hex := Army.NO_HEX
	for i: int in _g.map.hex_count():
		var h := _g.map.hex_of(i)
		if _g.map.is_land(h) and Occupation.fortress_level(_g, h) > 0 \
				and int(_g.state.main_use[i]) == Economy.SETTLEMENTS:
			hex = h
			break
	assert_ne(hex, Army.NO_HEX, "the 1480 map has a walled town")
	var i := _g.map.index_of(hex)
	_g.state.people[i] = 10000
	assert_eq(BattleEnd.sack(_g, hex), 1500, "15 % of the people")
	assert_eq(int(_g.state.people[i]), 8500)


func test_morale_experience_standing_and_rank() -> void:
	var a := WarFixture.army_at(_g, _a, _ha, 2)
	var u := a.units[0]
	Armies.set_morale(_g, a, u.id, 1500)
	assert_eq(u.morale, Unit.MAX_MORALE)
	Armies.set_morale(_g, a, u.id, -5)
	assert_eq(u.morale, 0)
	Armies.add_xp(_g, a, u.id, 3)
	assert_eq(Armies.rank_of(_g, u), 1, "3 experience is a Veteran")
	Armies.add_xp(_g, a, u.id, 4)
	assert_eq(Armies.rank_of(_g, u), 2, "7 experience is Elite")
	Armies.set_standing(_g, a, Army.STANDING_WITHDRAW)
	assert_eq(a.standing, Army.STANDING_WITHDRAW)


func test_recovery_is_for_fed_armies_only() -> void:
	var a := WarFixture.army_at(_g, _a, _ha, 1)
	var u := a.units[0]
	u.morale = 100
	a.supply = 0
	Armies.recover_morale(_g)
	assert_eq(u.morale, 100 + _g.defs.war.morale_recovery)
	a.supply = 2
	Armies.recover_morale(_g)
	assert_eq(u.morale, 100 + _g.defs.war.morale_recovery, "a hungry army recovers nothing")


func test_a_company_lost_in_battle_leaves_with_unit_lost() -> void:
	var a := WarFixture.army_at(_g, _a, _ha, 2)
	var uid: int = a.units[0].id
	var men: int = a.units[0].men
	assert_eq(Armies.lose_unit_men(_g, a, uid, men, &"battle"), men)
	assert_eq(a.units.size(), 1)
	assert_true(_kinds().has("unit_lost"))
	var last := a.units[0].id
	Armies.lose_unit_men(_g, a, last, a.units[0].men, &"battle")
	assert_null(Armies.by_id(_g, a.id), "an army with no company is removed")


# --- a peace ends the battles of the pair (4.9, D30) -----------------------------------------------------------------


## The first two land hexes from index 200 that are not in taken.
func _free_land(taken: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in range(200, _g.map.hex_count()):
		var h := _g.map.hex_of(i)
		if _g.map.is_land(h) and not taken.has(h):
			out.append(h)
			if out.size() == 2:
				break
	return out


func _peace_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _g.events:
		if str(e.get("kind", "")) == "battle_ended" and str(e.get("how", "")) == "peace":
			out.append(e)
	return out


func test_a_peace_ends_the_battle_of_the_pair_and_no_other() -> void:
	var att := _start_battle()
	var stranger := WarFixture.stranger_of(_g, _a)
	assert_ne(stranger, &"", "a country shares no border with Genoa")
	WarFixture.at_war(_g, _a, stranger)
	var taken: Array[Vector2i] = [_ha, _hb]
	var spots := _free_land(taken)
	assert_eq(spots.size(), 2, "two free land hexes")
	if spots.size() < 2:
		return
	WarFixture.army_at(_g, _a, spots[0], 2)
	WarFixture.army_at(_g, stranger, spots[1], 2)
	var att2 := Armies.at(_g, spots[0])[0]
	assert_true(Battles.engage(_g, att2, spots[1], 1, -1), "the other battle starts")
	var other := Battles.at(_g, spots[1])
	assert_not_null(other)
	_g.events.clear()
	assert_eq(_g.battles.size(), 2)
	assert_eq(Battles.end_all(_g, _a, _b), 1, "one battle of the pair ends")
	assert_null(Battles.at(_g, _hb), "the battle of the pair is gone")
	assert_eq(_g.battles.size(), 1)
	assert_true(_g.battles.has(other), "a battle of others is untouched")
	assert_not_null(Armies.by_id(_g, att.id), "the attacker still exists")
	assert_eq(Armies.at(_g, _hb).size(), 2, "both armies still stand on the hex")
	assert_eq(att.order, Army.ORDER_NONE)
	var ended := _peace_events()
	assert_eq(ended.size(), 1)
	if ended.size() == 1:
		assert_eq(int(ended[0]["record"]), -1, "a battle with no day has no record")
		assert_eq(ended[0]["winner"], &"", "a draw has no winner")
		assert_eq(ended[0]["loser"], &"", "a draw has no loser")
		assert_eq(int(ended[0]["days"]), 0)
		assert_true(ended[0].has("witnesses"))
	assert_true(_g.battle_records.is_empty(), "no day fought, no record")


func test_a_peace_with_no_battle_is_a_no_op() -> void:
	var events := _g.events.size()
	assert_eq(Battles.end_all(_g, _a, _b), 0)
	assert_eq(_g.events.size(), events, "nothing is queued")
	assert_true(_g.battles.is_empty())


# --- a forged save is refused (the loader's cross-checks) -----------------------------------------------------------


## A saved body with one pending battle, and the state's digest before any load.
func _pending_saved() -> Dictionary:
	_start_battle()
	return Battles.to_dict(_g)


## The body is refused and the state is left as it was.
func _refused_unchanged(d: Dictionary, why: String) -> void:
	var before := Battles.digest(_g)
	assert_eq(Battles.from_dict(d, _g), Battles.PROBLEM_BODY, why)
	assert_eq(Battles.digest(_g), before, "%s: the state is unchanged" % why)


func test_two_battles_on_one_hex_are_refused() -> void:
	var d := _pending_saved()
	var extra := WarFixture.army_at(_g, _a, _hb, 1)
	var second := ((d["battles"] as Array)[0] as Dictionary).duplicate(true)
	second["armies"] = {String(_a): [extra.id]}
	(d["battles"] as Array).append(second)
	_refused_unchanged(d, "a second battle on the same hex")


func test_a_battle_between_countries_at_peace_is_refused() -> void:
	var d := _pending_saved()
	_g.wars.clear()
	_refused_unchanged(d, "no war between the two sides")


func test_a_battle_from_a_future_turn_is_refused() -> void:
	var d := _pending_saved()
	((d["battles"] as Array)[0] as Dictionary)["start_turn"] = _g.turn + 5
	_refused_unchanged(d, "a start_turn after the game's turn")


func test_storm_fields_must_match_the_fortress() -> void:
	var d := _pending_saved()
	var b: Dictionary = (d["battles"] as Array)[0]
	b["assault"] = true
	b["storm_from"] = 100000
	b["storm_cut"] = 99999
	_refused_unchanged(d, "a storm cut on a hex with no fortress")


func test_the_name_table_is_capped() -> void:
	var d := _pending_saved()
	var many := {}
	for k: int in Battles.NAMES_MAX + 1:
		many["place %d" % k] = 1
	d["names"] = many
	_refused_unchanged(d, "more places than the table keeps")
	var huge := _pending_saved()
	huge["names"] = {"Pavia": 9223372036854775807}
	_refused_unchanged(huge, "a count of int64 size")


func test_a_battle_the_fight_cannot_take_ends_as_a_draw() -> void:
	var att := _start_battle()
	var def_men: int = _g.defs.unit_def(att.units[0].kind).men
	att.units[0].men = def_men + 1  # more men than the company's full strength: the input is not valid
	Battles.season(_g)
	assert_true(_g.battles.is_empty(), "no battle is left after the phase")
	assert_true(_g.battle_records.is_empty(), "no day is fought, so no record")
	assert_eq(_peace_events().size(), 1, "the battle ends as a draw")
	assert_not_null(Armies.by_id(_g, att.id), "the armies are not lost")
	assert_eq(Armies.at(_g, _hb).size(), 2, "both armies still stand on the hex, released")
