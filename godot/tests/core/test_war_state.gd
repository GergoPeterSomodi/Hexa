## The war state classes (core/state/war.gd, battle.gd, battle_record.gd, siege.gd; docs/architecture/m7-build-spec.md 5.2, 9):
## round trips through a dict and through JSON, digest_text moves with every field, the live-war lookup, and the refusals
## of a hostile dict. Every planted fault starts from a fresh dict (the helpers build one each call), so no case shares a
## sub-resource with another.
extends GutTest


func _war() -> War:
	var w := War.new()
	w.id = 2
	w.a = &"SAV"
	w.b = &"MLO"
	w.start_turn = 5
	w.end_turn = 9
	w.terms = &"white"
	w.won_a = 2
	w.won_b = 1
	w.lost_a = 300
	w.lost_b = 410
	w.moved = 0
	return w


func _battle() -> Battle:
	var b := Battle.new()
	b.hex = Vector2i(10, 9)
	b.attacker = &"SAV"
	b.defender = &"MLO"
	b.start_turn = 12
	b.assault = true
	b.armies = {"SAV": PackedInt32Array([4, 7]), "MLO": PackedInt32Array([9])}
	b.tick = 3
	b.name = "Battle of Pavia"
	b.crossing = true
	b.uphill = false
	b.river = true
	b.storm_from = 120
	b.storm_cut = 40
	return b


func _frame(day: int) -> Dictionary:
	return {
		"day": day, "rolls": PackedInt32Array([12, 7]),
		"lanes": [PackedInt32Array([3, 4, -2]), PackedInt32Array([-1, 5, 6])],
		"men": {3: 40, 4: 30, -1: 200}, "morale": {3: 900, 4: 850, 5: 1000},
		"routed": PackedInt32Array(), "shaken": PackedInt32Array([4]), "killed": PackedInt32Array([2, 3]),
		"wounded": PackedInt32Array([1, 0]), "front": PackedInt32Array([3, 5]), "broke": 0, "cause": "lane", "withdrew": 0,
	}


func _end() -> Dictionary:
	return {
		"how": "rout", "cause": "morale", "winner": 0, "loser": "MLO", "days": 2, "men": {3: 40, 4: 30},
		"morale": {3: 900, 4: 200}, "wounded": {3: 3}, "killed": PackedInt32Array([2, 3]),
		"wounded_total": PackedInt32Array([1, 0]), "lost_whole": PackedInt32Array(), "garrison": {},
		"retreat": {7: Vector2i(11, 9)}, "surrendered": PackedInt32Array([5]), "returned": {4: 6}, "stormed": false,
		"sacked": 0,
	}


func _record() -> BattleRecord:
	var r := BattleRecord.new()
	r.id = 3
	r.turn = 12
	r.hex = Vector2i(10, 9)
	r.name = "Battle of Pavia"
	r.year = 1480
	r.attacker = &"SAV"
	r.defender = &"MLO"
	r.input = {"hex": [10, 9], "stance": {"att": "attack", "def": "hold"}, "fighters": [{"key": 3, "side": 0, "men": 40}]}
	r.luck_before = 9007199254740993
	var frames: Array[Dictionary] = [_frame(0), _frame(1)]
	r.frames = frames
	r.end = _end()
	r.witnesses = PackedStringArray(["SAV", "MLO"])
	return r


func _siege() -> Siege:
	var s := Siege.new()
	s.hex = Vector2i(12, 10)
	s.besieger = &"SAV"
	s.progress = 340
	s.seasons = 2
	s.name = "Siege of Alba"
	s.started_turn = 14
	return s


## The path of the first place two values differ in their bytes ("" when they do not), for a failing round trip.
func _first_diff(a: Variant, b: Variant, path: String) -> String:
	if typeof(a) != typeof(b):
		return "%s: type %d vs %d" % [path, typeof(a), typeof(b)]
	if a is Dictionary:
		var keys_a: Array = (a as Dictionary).keys()
		var keys_b: Array = (b as Dictionary).keys()
		if keys_a != keys_b:
			return "%s: keys %s vs %s (types %s vs %s)" % [path, str(keys_a), str(keys_b),
				str(typeof(keys_a[0]) if keys_a.size() else -1), str(typeof(keys_b[0]) if keys_b.size() else -1)]
		for key: Variant in keys_a:
			var found := _first_diff((a as Dictionary)[key], (b as Dictionary)[key], "%s/%s" % [path, str(key)])
			if found != "":
				return found
		return ""
	if a is Array:
		if (a as Array).size() != (b as Array).size():
			return "%s: size" % path
		for i: int in (a as Array).size():
			var found := _first_diff((a as Array)[i], (b as Array)[i], "%s[%d]" % [path, i])
			if found != "":
				return found
		return ""
	if var_to_bytes(a) != var_to_bytes(b):
		return "%s: %s vs %s" % [path, var_to_str(a), var_to_str(b)]
	return ""


## The dict as a save writes and reads it: JSON, so numbers come back as floats and keys as text.
func _json(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d)) as Dictionary


# --- war ----------------------------------------------------------------------------------------------------------------


func test_war_round_trip() -> void:
	var back := War.from_dict(_json(_war().to_dict()))
	assert_not_null(back)
	assert_eq(back.digest_text(), _war().digest_text())
	assert_eq(back.terms, &"white")
	assert_false(back.live())
	var live := _war()
	live.end_turn = 0
	live.terms = &""
	assert_true(War.from_dict(_json(live.to_dict())).live())


func test_war_digest_moves_with_every_field() -> void:
	var seen := {_war().digest_text(): true}
	var edits: Array[Callable] = [
		func(w: War) -> void: w.id = 3,
		func(w: War) -> void: w.a = &"GEN",
		func(w: War) -> void: w.b = &"GEN",
		func(w: War) -> void: w.start_turn = 6,
		func(w: War) -> void: w.end_turn = 10,
		func(w: War) -> void: w.terms = &"take",
		func(w: War) -> void: w.won_a = 3,
		func(w: War) -> void: w.won_b = 2,
		func(w: War) -> void: w.lost_a = 301,
		func(w: War) -> void: w.lost_b = 411,
		func(w: War) -> void: w.moved = 1,
	]
	for edit: Callable in edits:
		var w := _war()
		edit.call(w)
		assert_false(seen.has(w.digest_text()), "one field moves the digest")
		seen[w.digest_text()] = true


func test_live_between_either_order_and_never_an_ended_one() -> void:
	var live := _war()
	live.end_turn = 0
	live.terms = &""
	var wars: Array[War] = [_war(), live]
	assert_eq(War.live_between(wars, &"SAV", &"MLO"), live)
	assert_eq(War.live_between(wars, &"MLO", &"SAV"), live, "the other order")
	assert_null(War.live_between(wars, &"SAV", &"GEN"), "no war between these two")
	var ended_only: Array[War] = [_war()]
	assert_null(War.live_between(ended_only, &"SAV", &"MLO"), "an ended war is not live")
	assert_eq(live.other(&"SAV"), &"MLO")
	assert_eq(live.other(&"GEN"), &"", "a tag not in the war has no other side")


func test_war_refusals() -> void:
	assert_not_null(War.from_dict(_war().to_dict()))
	var wrong := _war().to_dict()
	wrong["schema"] = "hexa-godot/war/2"
	assert_null(War.from_dict(wrong), "P: a wrong schema")
	var text := _war().to_dict()
	text["won_a"] = "2"
	assert_null(War.from_dict(text), "P: a string for won_a")
	var neg := _war().to_dict()
	neg["lost_b"] = -1
	assert_null(War.from_dict(neg), "P: a negative count")
	var frac := _war().to_dict()
	frac["moved"] = 1.5
	assert_null(War.from_dict(frac), "P: a fraction")
	var self_war := _war().to_dict()
	self_war["b"] = "SAV"
	assert_null(War.from_dict(self_war), "P: a war against itself")
	var no_terms := _war().to_dict()
	no_terms["terms"] = ""
	assert_null(War.from_dict(no_terms), "P: an ended war with no term")
	var bad_terms := _war().to_dict()
	bad_terms["terms"] = "charity"
	assert_null(War.from_dict(bad_terms), "P: a term not in the list")
	var live_term := _war().to_dict()
	live_term["end_turn"] = 0
	assert_null(War.from_dict(live_term), "P: a live war that carries a term")
	var backwards := _war().to_dict()
	backwards["end_turn"] = 4
	assert_null(War.from_dict(backwards), "P: an end before the start")
	var no_id := _war().to_dict()
	no_id["id"] = 0
	assert_null(War.from_dict(no_id), "P: id below 1")


# --- battle -------------------------------------------------------------------------------------------------------------


func test_battle_round_trip_and_armies_keep_their_ids() -> void:
	var back := Battle.from_dict(_json(_battle().to_dict()))
	assert_not_null(back)
	assert_eq(back.digest_text(), _battle().digest_text())
	assert_eq(back.armies["SAV"], PackedInt32Array([4, 7]), "the ids come back as whole numbers")


func test_battle_digest_moves_with_every_field() -> void:
	var seen := {_battle().digest_text(): true}
	var edits: Array[Callable] = [
		func(b: Battle) -> void: b.hex = Vector2i(10, 10),
		func(b: Battle) -> void: b.attacker = &"MLO",
		func(b: Battle) -> void: b.defender = &"GEN",
		func(b: Battle) -> void: b.start_turn = 13,
		func(b: Battle) -> void: b.assault = false,
		func(b: Battle) -> void: b.armies = {"SAV": PackedInt32Array([4]), "MLO": PackedInt32Array([9])},
		func(b: Battle) -> void: b.tick = 4,
		func(b: Battle) -> void: b.name = "Battle of Alba",
		func(b: Battle) -> void: b.crossing = false,
		func(b: Battle) -> void: b.uphill = true,
		func(b: Battle) -> void: b.river = false,
		func(b: Battle) -> void: b.storm_from = 121,
		func(b: Battle) -> void: b.storm_cut = 41,
	]
	for edit: Callable in edits:
		var b := _battle()
		edit.call(b)
		assert_false(seen.has(b.digest_text()), "one field moves the digest")
		seen[b.digest_text()] = true


func test_battle_refusals() -> void:
	assert_not_null(Battle.from_dict(_battle().to_dict()))
	var wrong := _battle().to_dict()
	wrong["schema"] = "hexa-godot/battle/2"
	assert_null(Battle.from_dict(wrong), "P: a wrong schema")
	var bad_hex := _battle().to_dict()
	bad_hex["hex"] = "10,9"
	assert_null(Battle.from_dict(bad_hex), "P: a string for hex")
	var flag := _battle().to_dict()
	flag["river"] = "yes"
	assert_null(Battle.from_dict(flag), "P: a string for a flag")
	var zero_army := _battle().to_dict()
	zero_army["armies"] = {"SAV": [0]}
	assert_null(Battle.from_dict(zero_army), "P: an army id below 1")
	var same := _battle().to_dict()
	same["defender"] = "SAV"
	assert_null(Battle.from_dict(same), "P: a battle between a side and itself")
	var cut := _battle().to_dict()
	cut["storm_cut"] = 500
	assert_null(Battle.from_dict(cut), "P: a storm cut above the garrison it cuts")
	var neg := _battle().to_dict()
	neg["tick"] = -1
	assert_null(Battle.from_dict(neg), "P: a negative tick")


# --- battle record ------------------------------------------------------------------------------------------------------


func test_record_round_trip_keeps_its_digest() -> void:
	var saved := _record()
	var back := BattleRecord.from_dict(_json(saved.to_dict()))
	assert_not_null(back)
	var before := saved.to_dict()
	var after := back.to_dict()
	assert_eq(_first_diff(before, after, ""), "", "the first place the two dicts differ in bytes")
	assert_eq(back.digest(), saved.digest(), "a record saved and read back has the same digest")
	assert_eq(back.to_dict(), saved.to_dict(), "and the same dict")
	assert_eq(back.frames[0]["men"][-1], 200, "the garrison's key is an int again")
	assert_eq(back.end["retreat"][7], Vector2i(11, 9), "the retreat spot is a hex again")
	assert_eq(back.luck_before, 9007199254740993, "a 64-bit luck state survives a save exactly")


func test_record_witnesses_are_not_in_the_digest() -> void:
	var seen := _record()
	var other := _record()
	other.witnesses = PackedStringArray(["GEN"])
	assert_eq(seen.digest(), other.digest(), "who witnessed it does not change what happened")
	var changed := _record()
	changed.end["sacked"] = 4
	assert_ne(seen.digest(), changed.digest(), "the end does")


func test_record_planted_frame_faults_are_refused() -> void:
	assert_not_null(BattleRecord.from_dict(_record().to_dict()))
	var no_lanes := _record().to_dict()
	var first: Dictionary = (no_lanes["frames"] as Array)[0]
	first.erase("lanes")
	assert_null(BattleRecord.from_dict(no_lanes), "P: a record frame without lanes")
	var extra := _record().to_dict()
	(extra["frames"] as Array)[1]["surprise"] = 1
	assert_null(BattleRecord.from_dict(extra), "P: a frame with a key the schema does not have")
	var morale := _record().to_dict()
	((morale["frames"] as Array)[0] as Dictionary)["morale"] = {"3": 1001}
	assert_null(BattleRecord.from_dict(morale), "P: a morale above 1000")
	var day := _record().to_dict()
	((day["frames"] as Array)[0] as Dictionary)["day"] = 9
	assert_null(BattleRecord.from_dict(day), "P: a day above the eight of a battle")
	var lane_key := _record().to_dict()
	(((lane_key["frames"] as Array)[0] as Dictionary)["lanes"] as Array)[0] = [3, 4, -3]
	assert_null(BattleRecord.from_dict(lane_key), "P: a lane key below the empty lane")
	var broke := _record().to_dict()
	((broke["frames"] as Array)[0] as Dictionary)["broke"] = 2
	assert_null(BattleRecord.from_dict(broke), "P: a break that is not -1, 0 or 1")
	var men_text := _record().to_dict()
	((men_text["frames"] as Array)[0] as Dictionary)["men"] = {"x": 3}
	assert_null(BattleRecord.from_dict(men_text), "P: a men key that is not an id")


func test_record_planted_end_faults_are_refused() -> void:
	var missing := _record().to_dict()
	(missing["end"] as Dictionary).erase("garrison")
	assert_null(BattleRecord.from_dict(missing), "P: an end missing a key")
	var winner := _record().to_dict()
	(winner["end"] as Dictionary)["winner"] = 2
	assert_null(BattleRecord.from_dict(winner), "P: a winner out of range")
	var days := _record().to_dict()
	(days["end"] as Dictionary)["days"] = 0
	assert_null(BattleRecord.from_dict(days), "P: a battle of no days")
	var stormed := _record().to_dict()
	(stormed["end"] as Dictionary)["stormed"] = 1
	assert_null(BattleRecord.from_dict(stormed), "P: stormed as a number")
	var garrison := _record().to_dict()
	(garrison["end"] as Dictionary)["garrison"] = {"men": 5}
	assert_null(BattleRecord.from_dict(garrison), "P: a garrison with no morale")
	var schema := _record().to_dict()
	schema["schema"] = "hexa-godot/battle-record/0"
	assert_null(BattleRecord.from_dict(schema), "P: a wrong schema")
	var no_input := _record().to_dict()
	no_input["input"] = "x"
	assert_null(BattleRecord.from_dict(no_input), "P: an input that is not a dict")


# --- siege --------------------------------------------------------------------------------------------------------------


func test_siege_round_trip_and_digest() -> void:
	var back := Siege.from_dict(_json(_siege().to_dict()))
	assert_not_null(back)
	assert_eq(back.digest_text(), _siege().digest_text())
	var edited := _siege()
	edited.progress = 341
	assert_ne(edited.digest_text(), _siege().digest_text(), "progress moves the digest")


func test_siege_refusals() -> void:
	assert_not_null(Siege.from_dict(_siege().to_dict()))
	var progress := _siege().to_dict()
	progress["progress"] = "340"
	assert_null(Siege.from_dict(progress), "P: a string for progress")
	var neg := _siege().to_dict()
	neg["seasons"] = -1
	assert_null(Siege.from_dict(neg), "P: negative seasons")
	var nobody := _siege().to_dict()
	nobody["besieger"] = ""
	assert_null(Siege.from_dict(nobody), "P: no besieger")
	var no_hex := _siege().to_dict()
	no_hex["hex"] = [12]
	assert_null(Siege.from_dict(no_hex), "P: a hex of one number")


# --- review of B2: StringName-built records, the frame and key rules, luck text, int32 limits, the battle rules ---------


func test_stringname_built_record_survives_a_save() -> void:
	var r := _record()
	r.end["how"] = &"rout"
	r.end["cause"] = &"morale"
	r.end["loser"] = &"MLO"
	r.end["killed"] = [2, 3]
	r.end["wounded_total"] = [1, 0]
	r.end["lost_whole"] = []
	r.end["surrendered"] = [5]
	r.end["men"] = {3: 40.0, 4: 30}
	r.input = {"k": &"sym", "f": 1.5, "w": 3.0, "v": Vector2i(1, 2)}
	var back := BattleRecord.from_dict(_json(r.to_dict()))
	assert_not_null(back, "a StringName loser, a list of killed and a float man read back")
	assert_eq(back.digest(), r.digest(), "the JSON round trip keeps the digest")
	var direct := BattleRecord.from_dict(r.to_dict())
	assert_not_null(direct)
	assert_eq(direct.digest(), r.digest(), "the direct round trip keeps it too")
	assert_eq(back.to_dict(), r.to_dict())


func test_record_refuses_a_loser_that_is_not_a_side() -> void:
	var d := _record().to_dict()
	(d["end"] as Dictionary)["loser"] = "GEN"
	assert_null(BattleRecord.from_dict(d), "P: the loser is not one of the two sides")


func test_record_frames_are_as_many_as_its_days_and_in_day_order() -> void:
	var none := _record().to_dict()
	none["frames"] = []
	assert_null(BattleRecord.from_dict(none), "P: no frames")
	var extra := _record().to_dict()
	(extra["end"] as Dictionary)["days"] = 1
	assert_null(BattleRecord.from_dict(extra), "P: two frames for one day")
	var order := _record().to_dict()
	var second: Dictionary = (order["frames"] as Array)[1]
	second["day"] = 0
	assert_null(BattleRecord.from_dict(order), "P: frames out of day order")


func test_record_keys_must_be_canonical() -> void:
	var dup := _record().to_dict()
	var first: Dictionary = (dup["frames"] as Array)[0]
	first["men"] = {"1": 5, "01": 6}
	assert_null(BattleRecord.from_dict(dup), "P: the keys '1' and '01' name the same unit")
	var plus := _record().to_dict()
	var second: Dictionary = (plus["frames"] as Array)[0]
	second["men"] = {"+1": 5}
	assert_null(BattleRecord.from_dict(plus), "P: a key with a plus sign")
	var neg_army := _record().to_dict()
	(neg_army["end"] as Dictionary)["retreat"] = {"-3": [1, 2]}
	assert_null(BattleRecord.from_dict(neg_army), "P: a negative army id")


func test_luck_is_canonical_int64_text() -> void:
	for bad: Variant in ["+5", "05", "99999999999999999999", "9223372036854775808", "-9223372036854775809", " 5", "", "x", 5]:
		var d := _record().to_dict()
		d["luck_before"] = bad
		assert_null(BattleRecord.from_dict(d), "P: luck %s" % str(bad))
	var low := _record().to_dict()
	low["luck_before"] = "-9223372036854775808"
	var back := BattleRecord.from_dict(low)
	assert_not_null(back)
	assert_eq(back.luck_before, -9223372036854775807 - 1, "the least int64 reads back exactly")


func test_int32_limits_refuse_before_narrowing() -> void:
	var war := _war().to_dict()
	war["won_a"] = 2147483648
	assert_null(War.from_dict(war), "P: a count above int32")
	war["won_a"] = 3000000000
	assert_null(War.from_dict(war))
	war["won_a"] = 2147483647
	assert_not_null(War.from_dict(war), "the largest int32 is allowed")
	var sg := _siege().to_dict()
	sg["progress"] = 4294967297
	assert_null(Siege.from_dict(sg), "P: progress 2^32 + 1")
	sg["progress"] = 1
	sg["hex"] = [2147483648, 1]
	assert_null(Siege.from_dict(sg), "P: a hex coordinate above int32")
	sg["hex"] = [1e300, 2]
	assert_null(Siege.from_dict(sg), "P: a hex coordinate of 1e300")
	var bt := _battle().to_dict()
	bt["armies"] = {"SAV": [3000000000]}
	assert_null(Battle.from_dict(bt), "P: an army id above int32")
	var rec := _record().to_dict()
	var f: Dictionary = (rec["frames"] as Array)[0]
	f["lanes"] = [[3000000000, -1, -2], [2, 3, -2]]
	assert_null(BattleRecord.from_dict(rec), "P: a lane key above int32")
	var men := _record().to_dict()
	var g: Dictionary = (men["frames"] as Array)[0]
	g["men"] = {"1": 3000000000}
	assert_null(BattleRecord.from_dict(men), "P: a man count above int32")
	var unit := Unit.new().to_dict()
	unit["men"] = 2147483648
	assert_null(Unit.from_dict(unit), "P: a unit of more men than int32")
	unit = Unit.new().to_dict()
	unit["home"] = [4294967297, 1]
	assert_null(Unit.from_dict(unit), "P: a home hex above int32")
	unit = Unit.new().to_dict()
	unit["morale"] = 999.9999999
	assert_null(Unit.from_dict(unit), "P: a morale that is not exactly whole")
	unit = Unit.new().to_dict()
	unit["xp"] = 1e300
	assert_null(Unit.from_dict(unit), "P: experience of 1e300")
	assert_null(Unit.whole(3.0000001), "the approximate equality is gone")


func test_battle_refuses_armies_that_do_not_add_up() -> void:
	var dup_across := _battle().to_dict()
	dup_across["armies"] = {"SAV": [4], "MLO": [4]}
	assert_null(Battle.from_dict(dup_across), "P: one army id on both sides")
	var dup_within := _battle().to_dict()
	dup_within["armies"] = {"SAV": [4, 4]}
	assert_null(Battle.from_dict(dup_within), "P: one army id twice")
	var empty_group := _battle().to_dict()
	empty_group["armies"] = {"SAV": []}
	assert_null(Battle.from_dict(empty_group), "P: a side with no army")
	var empty := _battle().to_dict()
	empty["armies"] = {}
	assert_null(Battle.from_dict(empty), "P: no armies at all")
	var stranger := _battle().to_dict()
	stranger["armies"] = {"SAV": [4], "GEN": [9]}
	assert_null(Battle.from_dict(stranger), "P: an army of a country that is not in the battle")
	var no_assault := _battle().to_dict()
	no_assault["assault"] = false
	assert_null(Battle.from_dict(no_assault), "P: a storm cut without an assault")
	var pipe := _war().to_dict()
	pipe["a"] = "SA|V"
	assert_null(War.from_dict(pipe), "P: a separator in a tag")
	var sg := _siege().to_dict()
	sg["name"] = "Alba|Siege"
	assert_null(Siege.from_dict(sg), "P: a separator in a name")
	sg = _siege().to_dict()
	sg["besieger"] = "S,V"
	assert_null(Siege.from_dict(sg), "P: a comma in a tag")
