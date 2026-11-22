@warning_ignore_start("integer_division")
## The pure battle's properties and bands (docs/architecture/m7-build-spec.md 4.6): men conservation, morale bounds, no negative
## men, the frames and the end's days, the same input and luck giving the same result, the replay of a record (in memory and
## through its dict), the lane rules of narrow ground and of the garrison, the withdrawal, and the starting bands of 4.6.
extends GutTest


## A random battle of a seed: 1 to 6 companies a side of the four kinds, random morale and hunger, random ground, and in
## some seeds an assault on a fortress of level 1 to 3.
func _random_input(war: WarDef, seed_value: int) -> Dictionary:
	var pick := Rng.new()
	pick.seed_with(seed_value)
	var fighters: Array = []
	var key: int = 1
	for side: int in 2:
		var count: int = 1 + pick.randi_range(0, 5)
		for i: int in count:
			var kind: int = pick.randi_range(0, 3)
			var men: int = 100 + pick.randi_range(0, 400)
			var morale: int = 600 + pick.randi_range(0, 400)
			var hungry: bool = pick.randi_range(0, 4) == 0
			var rank: int = pick.randi_range(0, 2)
			match kind:
				0: fighters.append(CombatFixture.company(key, side, "infantry", men, 4, 5, 0, rank, morale, hungry))
				1: fighters.append(CombatFixture.company(key, side, "missile", men, 5, 2, 25, rank, morale, hungry))
				2: fighters.append(CombatFixture.company(key, side, "cavalry", men / 2 + 1, 6, 3, 0, rank, morale, hungry))
				_: fighters.append(CombatFixture.company(key, side, "artillery", men / 4 + 1, 6, 1, 50, rank, morale, hungry))
			key += 1
	var cover: int = [0, 250, 150, 50][pick.randi_range(0, 3)]
	var relief: int = pick.randi_range(0, 6)
	var rough: bool = pick.randi_range(0, 1) == 1
	var narrow: bool = pick.randi_range(0, 2) == 0
	var input := CombatFixture.input_of(war, fighters, cover, rough, narrow, relief, "open")
	input["crossing"] = pick.randi_range(0, 1) == 1
	input["uphill"] = pick.randi_range(0, 1) == 1
	input["river"] = pick.randi_range(0, 1) == 1
	input["can_retreat"] = {"att": true, "def": pick.randi_range(0, 1) == 1}
	input["stance"] = {"att": "attack", "def": "withdraw" if input["can_retreat"]["def"] else "hold"}
	if pick.randi_range(0, 2) == 0:
		input["assault"] = true
		var level: int = pick.randi_range(1, 3)
		input["garrison"] = {"men": 200 + pick.randi_range(0, 800), "full": 1000, "level": level, "morale": 1000}
	return input


func _men_of(input: Dictionary, side: int) -> int:
	var total: int = 0
	for f: Variant in input["fighters"]:
		if int((f as Dictionary)["side"]) == side:
			total += int((f as Dictionary)["men"])
	if side == 1 and bool(input["assault"]) and not (input["garrison"] as Dictionary).is_empty():
		total += int((input["garrison"] as Dictionary)["men"])
	return total


## Men conservation: each side's men at the start are its men at the end, plus its killed and its wounded.
func test_men_are_conserved_across_seeds() -> void:
	var war := CombatFixture.war()
	for seed_value: int in range(1, 61):
		var input := _random_input(war, seed_value)
		assert_eq(CombatInput.validate(war, input), [] as Array[String], "seed %d: a valid input" % seed_value)
		var rng := Rng.new()
		rng.seed_with(seed_value * 7919)
		var out: Dictionary = Combat.fight(war, input, rng)
		var end: Dictionary = out["end"]
		var left: Array = [0, 0]
		for key: Variant in end["men"]:
			var k: int = int(key)
			var side: int = 1 if k == -1 else _side_of(input, k)
			left[side] += int(end["men"][key])
		for side: int in 2:
			assert_eq(left[side] + int(end["killed"][side]) + int(end["wounded_total"][side]), _men_of(input, side),
					"seed %d side %d: men are conserved" % [seed_value, side])


func _side_of(input: Dictionary, key: int) -> int:
	for f: Variant in input["fighters"]:
		if int((f as Dictionary)["key"]) == key:
			return int((f as Dictionary)["side"])
	return 0


## Morale stays 0 to 1,000 and men never go negative, in every frame and at the end.
func test_morale_and_men_stay_in_bounds() -> void:
	var war := CombatFixture.war()
	for seed_value: int in range(1, 41):
		var out: Dictionary = Combat.fight(war, _random_input(war, seed_value), CombatFixture.FlatRng.new())
		for frame: Variant in out["frames"]:
			for key: Variant in (frame as Dictionary)["morale"]:
				var m: int = int((frame as Dictionary)["morale"][key])
				assert_true(m >= 0 and m <= 1000, "seed %d: morale %d in bounds" % [seed_value, m])
			for key: Variant in (frame as Dictionary)["men"]:
				assert_true(int((frame as Dictionary)["men"][key]) >= 0, "seed %d: no negative men" % seed_value)


## The frames are one a day from day 1, as many as the end's days, and the battle lasts 1 to 8 days.
func test_frames_match_the_days() -> void:
	var war := CombatFixture.war()
	for seed_value: int in range(1, 41):
		var out: Dictionary = Combat.fight(war, _random_input(war, seed_value), CombatFixture.FlatRng.new())
		var frames: Array = out["frames"]
		var days: int = int(out["end"]["days"])
		assert_eq(frames.size(), days, "seed %d: one frame a day" % seed_value)
		assert_true(days >= 1 and days <= war.battle_days, "seed %d: %d days in 1 to 8" % [seed_value, days])
		for i: int in frames.size():
			assert_eq(int((frames[i] as Dictionary)["day"]), i + 1, "seed %d: day numbers rise from 1" % seed_value)


## The same input and the same luck give the same frames and end; a different seed may not.
func test_same_input_and_luck_give_the_same_battle() -> void:
	var war := CombatFixture.war()
	var input := _random_input(war, 12)
	var first: Dictionary = Combat.replay(war, CombatFixture.record_of(war, input, 99))
	var second: Dictionary = Combat.replay(war, CombatFixture.record_of(war, input, 99))
	assert_eq(first, second, "equal input and luck: equal result")


## Replay: a record's frames and end come again from its input and luck_before, and from its dict too.
func test_replay_equals_the_record() -> void:
	var war := CombatFixture.war()
	for seed_value: int in range(1, 16):
		var record := CombatFixture.record_of(war, _random_input(war, seed_value), seed_value)
		var again: Dictionary = Combat.replay(war, record)
		assert_eq(again["frames"], record.frames, "seed %d: frames replay" % seed_value)
		assert_eq(again["end"], record.end, "seed %d: end replays" % seed_value)
		var back := BattleRecord.from_dict(record.to_dict())
		assert_not_null(back, "seed %d: the record reads back" % seed_value)
		if back != null:
			assert_eq(Combat.replay(war, back)["frames"], record.frames, "seed %d: a saved record replays" % seed_value)


## Lanes: the narrow ground never holds a company in its right lane; the garrison only ever holds the defender's centre.
func test_lane_rules_hold_in_every_frame() -> void:
	var war := CombatFixture.war()
	for seed_value: int in range(1, 41):
		var input := _random_input(war, seed_value)
		var narrow: bool = bool((input["ground"] as Dictionary)["narrow"])
		var out: Dictionary = Combat.fight(war, input, CombatFixture.FlatRng.new())
		for frame: Variant in out["frames"]:
			var lanes: Array = (frame as Dictionary)["lanes"]
			if narrow:
				assert_eq(int(lanes[0][2]), -2, "seed %d: narrow ground, no right lane (attacker)" % seed_value)
				assert_eq(int(lanes[1][2]), -2, "seed %d: narrow ground, no right lane (defender)" % seed_value)
			assert_true(int(lanes[0][1]) != -1 and int(lanes[0][0]) != -1 and int(lanes[0][2]) != -1,
					"seed %d: the attacker has no garrison" % seed_value)
			assert_true(int(lanes[1][0]) != -1 and int(lanes[1][2]) != -1, "seed %d: the garrison holds the centre only" % seed_value)


## Only bombards are lost whole, and only in a flight.
func test_only_bombards_are_lost_whole() -> void:
	var war := CombatFixture.war()
	for seed_value: int in range(1, 41):
		var input := _random_input(war, seed_value)
		var out: Dictionary = Combat.fight(war, input, CombatFixture.FlatRng.new())
		for key: Variant in out["end"]["lost_whole"]:
			var k: int = int(key)
			var branch: String = ""
			for f: Variant in input["fighters"]:
				if int((f as Dictionary)["key"]) == k:
					branch = str((f as Dictionary)["branch"])
			assert_eq(branch, "artillery", "seed %d: a whole loss is a bombard" % seed_value)


## A withdrawal on Withdraw happens at day 2 (the stance) or at the day cap (the timer), and never before day 2.
func test_withdrawal_comes_on_day_two_or_at_the_cap() -> void:
	var war := CombatFixture.war()
	var stance_seen: int = 0
	for seed_value: int in range(1, 81):
		var input := _random_input(war, seed_value)
		input["stance"] = {"att": "attack", "def": "withdraw"}
		input["can_retreat"] = {"att": true, "def": true}
		input["assault"] = false
		input["garrison"] = {}
		var out: Dictionary = Combat.fight(war, input, CombatFixture.FlatRng.new())
		var end: Dictionary = out["end"]
		if str(end["how"]) == "withdraw" and str(end["cause"]) == "stance":
			stance_seen += 1
			assert_eq(int(end["days"]), 2, "seed %d: a stance withdrawal ends on day 2" % seed_value)
		elif str(end["how"]) == "withdraw":
			assert_eq(int(end["days"]), war.battle_days, "seed %d: the timer ends on the cap" % seed_value)
	assert_true(stance_seen > 0, "some battles end on a day-2 withdrawal")
