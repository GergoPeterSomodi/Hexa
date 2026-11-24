## BattleView (docs/architecture/m7-build-spec.md 4.6, 4.15, 5.6, M7 B14): the battle as a viewer may see it. Genoa (GEN, the
## player) and Savoy (SAV) and a third country (MLO) fight in made records (CombatFixture inputs, fought with a fixed luck
## stream). Planted faults (P): an unwitnessed foreign battle is absent (of, sites); a seen battle has no unit or army ids,
## no stances; the witness reads the exact numbers too (R22); the sides see exact numbers; a kept-less battle gives its chronicle
## totals only.
extends GutTest

const SAV := &"SAV"
const MLO := &"MLO"

var _g: Game
var _hex: Vector2i


func before_each() -> void:
	_g = ArmyFixture.game()
	_hex = ArmyFixture.find_town(_g)


## A battle record of Savoy's pikemen (two companies) against one company of pikemen and one of knights, fought with a fixed
## luck stream. The record is kept in the game and carries the witnesses given.
func _battle(attacker: StringName, defender: StringName, witnesses: PackedStringArray, narrow: bool = false) -> BattleRecord:
	var war := CombatFixture.war()
	var fighters := [CombatFixture.pikemen(101, 0), CombatFixture.pikemen(102, 0), CombatFixture.pikemen(201, 1),
		CombatFixture.knights(202, 1)]
	var input := CombatFixture.input_of(war, fighters, 0, false, narrow)
	# B8's input form: every fighter names its kind (a UnitDef id) and its army.
	for f: Dictionary in fighters:
		for ud: UnitDef in _g.defs.units:
			if String(ud.branch) == str(f["branch"]):
				f["kind"] = ud.id
				break
		f["army"] = 1 if int(f["side"]) == 0 else 2
	input["attacker"] = String(attacker)
	input["defender"] = String(defender)
	var rng := Rng.new()
	rng.seed_with(1480)
	var before: int = rng.get_state()
	var out: Dictionary = Combat.fight(war, input, rng)
	var r := BattleRecord.new()
	r.id = _g.next_record_id
	_g.next_record_id += 1
	r.turn = _g.turn
	r.hex = _hex
	r.name = "Battle of Test, 1480"
	r.year = 1480
	r.attacker = attacker
	r.defender = defender
	r.input = input.duplicate(true)
	r.luck_before = before
	r.frames.assign(out["frames"])
	r.end = out["end"]
	r.witnesses = witnesses
	_g.battle_records.append(r)
	return r


## True when a key of this name appears anywhere in a view (dictionaries and lists, recursively).
func _has_key(value: Variant, name: String) -> bool:
	if value is Dictionary:
		for k: Variant in value:
			if str(k) == name or _has_key((value as Dictionary)[k], name):
				return true
	elif value is Array:
		for item: Variant in value:
			if _has_key(item, name):
				return true
	return false


func _sum_men(r: BattleRecord, frame_index: int, side: int) -> int:
	var total := 0
	for f: Dictionary in r.input["fighters"]:
		if int(f["side"]) == side:
			total += int((r.frames[frame_index]["men"] as Dictionary).get(int(f["key"]), 0))
	return total


func test_unwitnessed_foreign_battle_is_absent() -> void:
	var r := _battle(SAV, MLO, PackedStringArray())
	r.turn = _g.turn - 1
	assert_eq(BattleView.access(_g, ArmyFixture.TAG, r), &"hidden")
	assert_true(BattleView.of(_g, ArmyFixture.TAG, r.id).is_empty(), "P: an unseen foreign battle is absent")
	assert_true(BattleView.sites(_g, ArmyFixture.TAG).is_empty(), "P: and it is no badge")


func test_empty_viewer_and_a_side_see_exact() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	assert_eq(BattleView.access(_g, &"", r), &"exact")
	assert_eq(BattleView.access(_g, ArmyFixture.TAG, r), &"exact", "the attacker is a side")
	assert_eq(BattleView.access(_g, SAV, r), &"exact", "the defender is a side")
	var v := BattleView.of(_g, ArmyFixture.TAG, r.id)
	assert_eq(v.viewer_side, &"attacker")
	assert_eq(int(v.side[String(ArmyFixture.TAG)].men), _sum_men(r, r.frames.size() - 1, 0), "the side's men exact")
	assert_eq(int(v.side[String(SAV)].men), _sum_men(r, r.frames.size() - 1, 1), "the other side's men exact too")
	assert_true(_has_key(v, "key"), "a side sees its companies by id")
	assert_eq(String(v.side[String(ArmyFixture.TAG)].stance_text).begins_with("Fought on:"), true)


func test_witness_sees_exact_numbers_and_no_ids() -> void:
	var r := _battle(SAV, MLO, PackedStringArray([String(ArmyFixture.TAG)]))
	var v := BattleView.of(_g, ArmyFixture.TAG, r.id)
	assert_eq(v.access, &"seen")
	var last := r.frames.size() - 1
	var exact_men := _sum_men(r, last, 0)
	var shown := int(_side_of(v, "attacker").men)
	assert_eq(shown, exact_men, "P: a witness reads the exact men (R22)")
	assert_eq(int(_side_of(v, "attacker").front), int((r.frames[last]["front"] as PackedInt32Array)[0]),
		"P: and the exact morale (R22)")
	assert_eq(String(_side_of(v, "attacker").stance_text), "", "P: stances hidden")
	assert_false(_has_key(v, "key"), "P: no company ids leak to a witness")
	assert_false(_has_key(v, "armies"), "P: no army ids leak to a witness")
	assert_eq(String(v.viewer_side), "", "a witness is not a side")


func test_reserve_and_routed_carry_no_ids_for_a_witness() -> void:
	var r := _battle(SAV, MLO, PackedStringArray([String(ArmyFixture.TAG)]))
	var v := BattleView.of(_g, ArmyFixture.TAG, r.id)
	for side: Dictionary in [_side_of(v, "attacker"), _side_of(v, "defender")]:
		for entry: Dictionary in side.reserve:
			assert_false(entry.has("key"), "P: a reserve company has no id for a witness")
		for entry: Dictionary in side.lanes:
			assert_false(entry.has("key"), "P: a lane has no id for a witness")


func test_witness_reserve_is_one_entry_with_the_exact_total() -> void:
	var r := _battle(SAV, MLO, PackedStringArray([String(ArmyFixture.TAG)]))
	var last := r.frames.size() - 1
	var exact := BattleView.of(_g, SAV, r.id)
	var seen := BattleView.of(_g, ArmyFixture.TAG, r.id)
	for role: String in ["attacker", "defender"]:
		var exact_reserve: Array = _side_of(exact, role).reserve
		var seen_reserve: Array = _side_of(seen, role).reserve
		assert_true(seen_reserve.size() <= 1, "P: a witness gets at most one reserve entry, got %d" % seen_reserve.size())
		var exact_total := 0
		for e: Dictionary in exact_reserve:
			exact_total += int(e.men)
		var shown_total := 0
		for e: Dictionary in seen_reserve:
			shown_total += int(e.men)
			assert_false(e.has("key"), "P: no company id in the aggregate")
		assert_eq(shown_total, exact_total, "P: the sum is the exact total")
	for role: String in ["attacker", "defender"]:
		var lanes: Array = _side_of(seen, role).lanes
		assert_eq(lanes.size(), 3, "one entry per lane")
	assert_eq(last, r.frames.size() - 1)


func test_day_frames_and_the_default_last_day() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	var days := r.frames.size()
	var first := BattleView.of(_g, ArmyFixture.TAG, r.id, 1)
	assert_eq(int(first.day), 1)
	assert_eq(int(first.index), 0)
	assert_eq((first.log as Array).size(), 1, "the log runs to the shown day")
	var last := BattleView.of(_g, ArmyFixture.TAG, r.id)
	assert_eq(int(last.day), int(r.frames[days - 1].day), "-1 shows the last day")
	assert_eq((last.log as Array).size(), days)
	assert_eq(int(last.days), int(r.end.days))


func test_log_line_is_the_spec_sentence() -> void:
	var r := BattleRecord.new()
	r.attacker = SAV
	r.defender = MLO
	var frame := {"day": 2, "killed": PackedInt32Array([48, 61]), "wounded": PackedInt32Array([46, 59]),
		"broke": 1, "cause": "centre", "withdrew": 0}
	var line := BattleView.log_line(r, frame, {"SAV": "Savoy", "MLO": "Milan"})
	assert_eq(line, "Day 2: Savoy 48 killed, 46 wounded; Milan 61 killed, 59 wounded. Milan broke (centre).")


func test_narrow_ground_closes_the_right_lane() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray(), true)
	var v := BattleView.of(_g, ArmyFixture.TAG, r.id)
	assert_eq(int(v.ground.lanes_open), 2)
	var lanes: Array = v.side[String(ArmyFixture.TAG)].lanes
	assert_true(bool(lanes[2].closed), "the right lane is closed on narrow ground")
	assert_false(bool(lanes[1].closed))


func test_result_text_names_the_retreat() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	r.end["winner"] = 0
	r.end["how"] = "broke"
	r.end["cause"] = "centre"
	r.end["days"] = 4
	r.end["retreat"] = {5: Vector2i(8, 8)}
	var v := BattleView.of(_g, ArmyFixture.TAG, r.id)
	assert_true(str(v.result.text).ends_with("broke (centre) and fled to (8, 8)."), str(v.result.text))
	assert_true(str(v.result.text).contains("won in 4 days: "), str(v.result.text))
	assert_eq(str(v.result.winner), String(ArmyFixture.TAG))


func test_latest_of_and_sites_for_last_season() -> void:
	assert_eq(BattleView.latest_of(_g, ArmyFixture.TAG), -1, "no battle yet")
	var old := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	var newer := _battle(SAV, ArmyFixture.TAG, PackedStringArray())
	assert_eq(BattleView.latest_of(_g, ArmyFixture.TAG), newer.id, "the newest record the country fought in")
	old.turn = _g.turn - 1
	newer.turn = _g.turn
	var badges := BattleView.sites(_g, ArmyFixture.TAG)
	assert_eq(badges.size(), 1, "sites are the last season's records only")
	assert_eq(int(badges[0].record), old.id)
	assert_eq((badges[0].front as PackedInt32Array).size(), 2)
	assert_eq(int(badges[0].attacker_colour_id), Countries.by_tag(_g, ArmyFixture.TAG).id)


func test_gone_battle_gives_its_chronicle_totals() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray([String(ArmyFixture.TAG)]))
	var id := r.id
	_g.battle_records.erase(r)
	_g.chronicle.entries.append({"kind": "battle_ended", "turn": _g.turn, "tag": String(ArmyFixture.TAG),
		"attacker": String(ArmyFixture.TAG), "defender": String(SAV), "winner": String(ArmyFixture.TAG),
		"loser": String(SAV), "how": "broke", "cause": "centre", "days": 2, "record": id, "name": "Battle of Test, 1480",
		"year": 1480, "hex": _hex, "killed": {String(ArmyFixture.TAG): 40, String(SAV): 60},
		"wounded": {String(ArmyFixture.TAG): 10, String(SAV): 20}, "witnesses": PackedStringArray([String(ArmyFixture.TAG)])})
	var v := BattleView.of(_g, ArmyFixture.TAG, id)
	assert_false(bool(v.kept))
	assert_eq(str(v.note), BattleView.GONE_NOTE)
	assert_eq(int(v.totals.killed[String(SAV)]), 60)
	assert_true(str(v.result.text).contains("won in 2 days: "))
	assert_true(BattleView.of(_g, MLO, id).is_empty(), "P: a chronicle entry is told only to its witnesses")

func test_company_kind_is_read_from_the_fighter() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	var fighters: Array = r.input["fighters"]
	for f: Dictionary in fighters:
		assert_true(f.has("kind") and f.has("army"), "B8: every fighter carries its kind and army")
	# Re-label one pikeman as knights: the view follows the recorded kind, not the stats.
	var knights := _g.defs.units[2]
	(fighters[0] as Dictionary)["kind"] = knights.id
	var v := BattleView.of(_g, ArmyFixture.TAG, r.id, 1)
	var found := false
	var entries: Array = (v.side[String(ArmyFixture.TAG)].lanes as Array).duplicate()
	entries.append_array(v.side[String(ArmyFixture.TAG)].reserve as Array)
	for entry: Dictionary in entries:
		if entry.has("key") and int(entry.key) == int((fighters[0] as Dictionary)["key"]):
			found = true
			assert_eq(int(entry.kind), knights.id, "the recorded kind is read")
			assert_eq(entry.figure, knights.figure)
	assert_true(found, "the re-labelled company is on the field")


func test_old_record_without_kind_falls_back_to_branch_and_stats() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	for f: Dictionary in r.input["fighters"]:
		f.erase("kind")
		f.erase("army")
	var v := BattleView.of(_g, ArmyFixture.TAG, r.id)
	var pikes := _g.defs.units[0]
	var lanes: Array = v.side[String(ArmyFixture.TAG)].lanes
	for lane: Dictionary in lanes:
		if lane.has("key"):
			assert_eq(int(lane.kind), pikes.id, "an old fighter is matched by branch and stats")
			assert_eq(lane.figure, pikes.figure)


func test_no_army_value_anywhere_in_a_witness_or_side_view() -> void:
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray([String(ArmyFixture.TAG), "MLO"]))
	var witness := BattleView.of(_g, &"MLO", r.id)
	assert_eq(witness.access, &"seen")
	assert_false(_has_key(witness, "army"), "P: no army key in a witness view")
	assert_false(_has_key(witness, "key"), "P: no company key in a witness view")
	assert_false(_has_key(BattleView.sites(_g, &"MLO"), "army"), "P: no army key in the badges")
	var side := BattleView.of(_g, ArmyFixture.TAG, r.id)
	assert_false(_has_key(side, "army"), "a side view carries no army key either")
	assert_false(_has_key(BattleView.of(_g, &"", r.id), "army"))


func _peace_entry(name: String) -> Dictionary:
	return {"kind": "battle_ended", "turn": _g.turn, "tag": "GEN", "attacker": "GEN", "defender": "SAV",
		"winner": "", "loser": "", "how": "peace", "cause": "", "days": 0, "record": -1, "name": name,
		"year": 1480, "hex": _hex, "killed": {}, "wounded": {}, "witnesses": PackedStringArray(["GEN"])}


func _real_name(tag: StringName) -> String:
	var d := Countries.def_of(_g, tag)
	if d != null and not d.long_name.is_empty():
		return d.long_name
	return String(tag)


func test_peace_ended_battles_are_not_found_by_id_minus_one() -> void:
	_g.chronicle.entries.append(_peace_entry("Battle of One, 1480"))
	_g.chronicle.entries.append(_peace_entry("Battle of Two, 1480"))
	assert_true(BattleView.of(_g, &"", -1).is_empty(), "P: id -1 is nothing for the omniscient viewer")
	assert_true(BattleView.of(_g, ArmyFixture.TAG, -1).is_empty(), "P: nor for a witness")
	var r := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	assert_eq(int(BattleView.of(_g, ArmyFixture.TAG, r.id).id), r.id, "a kept battle is still found by its id")


func test_a_hostile_record_never_raises_and_gives_nothing_it_cannot_read() -> void:
	var odd := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	var fighters: Array = odd.input["fighters"]
	(fighters[0] as Dictionary)["kind"] = {"not": "a number"}
	fighters[1] = "junk"
	fighters.append(7)
	assert_false(BattleView.of(_g, ArmyFixture.TAG, odd.id).is_empty(), "a odd fighter list is read, its bad entries skipped")

	var kinds := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	var kf: Array = kinds.input["fighters"]
	(kf[0] as Dictionary)["kind"] = 999
	(kf[1] as Dictionary)["kind"] = -5
	assert_false(BattleView.of(_g, ArmyFixture.TAG, kinds.id).is_empty(), "a kind out of range falls back to the stats")

	var huge := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	for f: Variant in huge.input["fighters"]:
		(f as Dictionary)["men"] = 9223372036854775807
	for k: Variant in huge.frames[0]["men"]:
		huge.frames[0]["men"][k] = 9223372036854775807
	huge.end["killed"] = PackedInt32Array([2147483647, 2147483647])
	huge.frames[0]["rolls"] = PackedInt32Array([2147483647, -2147483648])
	assert_false(BattleView.of(_g, ArmyFixture.TAG, huge.id).is_empty(), "huge numbers are read without an error")

	var missing := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	missing.frames[0].erase("men")
	assert_true(BattleView.of(_g, ArmyFixture.TAG, missing.id).is_empty(), "a frame without its fields gives nothing")

	var no_end := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	no_end.end = {}
	assert_true(BattleView.of(_g, ArmyFixture.TAG, no_end.id).is_empty(), "an empty end gives nothing")

	var bad_lanes := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	bad_lanes.frames[0]["lanes"] = [PackedInt32Array([1, 2]), PackedInt32Array([1, 2, 3])]
	assert_true(BattleView.of(_g, ArmyFixture.TAG, bad_lanes.id).is_empty(), "a lane of two keys gives nothing")

	var bogus := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	bogus.input["fighters"] = "bogus"
	assert_false(BattleView.of(_g, ArmyFixture.TAG, bogus.id).is_empty(), "a bogus fighter list reads as no fighters")


func test_a_witness_who_does_not_know_a_side_sees_a_country() -> void:
	var stranger := WarFixture.stranger_of(_g, ArmyFixture.TAG)
	FogFixture.thin(_g, ArmyFixture.TAG, 0)
	assert_ne(stranger, &"", "the 1480 map has a country Genoa shares no border with")
	var unknown := &""
	for c: Country in _g.countries:
		if c.tag != &"" and c.tag != ArmyFixture.TAG and c.tag != stranger and not Knowledge.knows(_g, ArmyFixture.TAG, c.tag):
			unknown = c.tag
			break
	assert_ne(unknown, &"", "a second country Genoa does not know")
	var r := _battle(stranger, unknown, PackedStringArray([String(ArmyFixture.TAG)]))
	r.end["winner"] = 0
	r.end["how"] = "broke"
	r.end["cause"] = "centre"
	r.end["days"] = 2
	assert_false(Knowledge.knows(_g, ArmyFixture.TAG, stranger), "Genoa does not know it")
	var v := BattleView.of(_g, ArmyFixture.TAG, r.id)
	assert_eq(str(_side_of(v, "attacker").name), "a country", "P: an unknown side is named as a country")
	assert_eq(str(_side_of(v, "defender").name), "a country")
	assert_true(str(v.log[0].text).begins_with("Day 1: a country "), str(v.log[0].text))
	var text := str(v.result.text)
	assert_true(text.begins_with("A country won in 2 days: a country broke"), text)
	assert_false(text.contains(_real_name(stranger)), "P: its real name is not in the result")
	var exact := BattleView.of(_g, &"", r.id)
	assert_eq(str(exact.side[String(stranger)].name), _real_name(stranger), "the omniscient viewer reads the real name")
	var mine := _battle(ArmyFixture.TAG, SAV, PackedStringArray())
	var side_view := BattleView.of(_g, ArmyFixture.TAG, mine.id)
	assert_eq(str(side_view.side[String(SAV)].name), _real_name(SAV), "a side reads the other side's real name")


## The side of a view by its role (its key is its tag when the viewer may read it, else its role word).
func _side_of(v: Dictionary, role: String) -> Dictionary:
	return (v.side as Dictionary)[(v.sides as Dictionary)[role][0]]


## Every string equal to one of the tags, as a key or a value, anywhere in the view tree.
func _tag_hits(value: Variant, tags: Array, out: Array) -> void:
	if value is Dictionary:
		for k: Variant in value:
			_tag_hits(k, tags, out)
			_tag_hits((value as Dictionary)[k], tags, out)
	elif value is Array:
		for item: Variant in value:
			_tag_hits(item, tags, out)
	elif typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		if tags.has(str(value)):
			out.append(str(value))


func test_a_witness_view_carries_no_tag_of_a_country_it_does_not_know() -> void:
	var stranger := WarFixture.stranger_of(_g, ArmyFixture.TAG)
	FogFixture.thin(_g, ArmyFixture.TAG, 0)
	var unknown := &""
	for c: Country in _g.countries:
		if c.tag != &"" and c.tag != ArmyFixture.TAG and c.tag != stranger and not Knowledge.knows(_g, ArmyFixture.TAG, c.tag):
			unknown = c.tag
			break
	assert_ne(unknown, &"", "a second country Genoa does not know")
	var r := _battle(stranger, unknown, PackedStringArray([String(ArmyFixture.TAG)]))
	r.turn = _g.turn - 1
	r.end["winner"] = 0
	r.end["how"] = "broke"
	r.end["cause"] = "centre"
	r.end["days"] = 2
	var tags := [String(stranger), String(unknown)]
	var hits: Array = []
	_tag_hits(BattleView.of(_g, ArmyFixture.TAG, r.id), tags, hits)
	assert_eq(hits, [], "P: no tag of an unknown country anywhere in the witness's view")
	var badges: Array = []
	_tag_hits(BattleView.sites(_g, ArmyFixture.TAG), tags, badges)
	assert_eq(badges, [], "P: nor in the badges")
	var exact := BattleView.of(_g, &"", r.id)
	assert_eq(str((exact.sides as Dictionary)["attacker"][0]), String(stranger), "the omniscient viewer has the tag")
	assert_eq(str(_side_of(BattleView.of(_g, ArmyFixture.TAG, r.id), "attacker").name), "a country")
