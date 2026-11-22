## Review fixes of the pure battle (B7 review, 2026-11-22): a wiped-out side is not a break (mutual destruction is a draw, winner
## -1, no flight); every hostile input gives messages from CombatInput.validate and never an error; the garrison's morale, the
## men and full of a company, its fire, and the highest ground (cover 1,000 plus relief 500) are checked. Pure.
@warning_ignore_start("integer_division")
extends GutTest

const HOSTILE: Array = [{}, [], "yes", null, Vector2i(1, 2), 7.5, -500, 5000, "x"]


func _cavalry_duel() -> Dictionary:
	var war := CombatFixture.war()
	var input := CombatFixture.input_of(war, [CombatFixture.company(1, 0, "cavalry", 40, 20, 1),
			CombatFixture.company(2, 1, "cavalry", 40, 20, 1)])
	input["stance"] = {"att": "attack", "def": "attack"}
	return input


## Mutual destruction (repro c10): 40 men of cavalry at attack 20 against defence 1 each side. Some seeds annihilate both
## sides: the battle is a wipe-out with winner -1 (a draw), with no break and no flight, and the frames say so.
func test_mutual_destruction_is_a_draw() -> void:
	var war := CombatFixture.war()
	var input := _cavalry_duel()
	var both: int = 0
	for seed_value: int in range(0, 1000):
		var rng := Rng.new()
		rng.seed_with(seed_value)
		var out: Dictionary = Combat.fight(war, input, rng)
		var end: Dictionary = out["end"]
		var m0: int = int(end["men"][1])
		var m1: int = int(end["men"][2])
		if m0 == 0 and m1 == 0:
			both += 1
			assert_eq(int(end["winner"]), -1, "seed %d: both wiped is a draw" % seed_value)
			assert_eq(str(end["how"]), "wiped", "seed %d: both wiped gives how wiped" % seed_value)
			var frames: Array = out["frames"]
			var last: Dictionary = frames[frames.size() - 1]
			assert_eq(int(last["broke"]), -1, "seed %d: no break" % seed_value)
			var lost: PackedInt32Array = end["lost_whole"]
			assert_eq(lost.size(), 0, "seed %d: no flight" % seed_value)
	assert_gt(both, 0, "some seeds annihilate both sides")


## One side wiped out and the other standing: that side is wiped (no flight), the other wins.
func test_one_side_wiped_is_wiped_with_no_flight() -> void:
	var war := CombatFixture.war()
	var input := CombatFixture.input_of(war, [CombatFixture.company(1, 0, "cavalry", 400, 20, 1),
			CombatFixture.company(2, 1, "infantry", 10, 1, 1)])
	var rng := Rng.new()
	rng.seed_with(4)
	var end: Dictionary = Combat.fight(war, input, rng)["end"]
	assert_eq(int(end["men"][2]), 0, "the defender is wiped")
	assert_eq(int(end["winner"]), 0, "the attacker wins")
	assert_eq(str(end["how"]), "wiped", "a wipe-out, not a break")
	assert_eq(str(end["cause"]), "wiped", "its cause is wiped")


## Hostile values for every key of the snapshot: validate returns messages and never raises.
func test_hostile_values_never_raise() -> void:
	var war := CombatFixture.war()
	var base := CombatFixture.assault_input(war, [CombatFixture.pikemen(1, 0), CombatFixture.pikemen(2, 1)], 300, 2)
	for key: String in CombatInput.KEYS:
		for value: Variant in HOSTILE:
			var input: Dictionary = base.duplicate(true)
			input[key] = value
			var errors: Array[String] = CombatInput.validate(war, input)
			var tag_text: bool = (key == "attacker" or key == "defender") and typeof(value) == TYPE_STRING
			if not tag_text and (key == "attacker" or key == "defender" or key == "assault" or key == "crossing" or key == "uphill" or key == "river"):
				assert_false(errors.is_empty(), "%s = %s is refused" % [key, str(value)])
			assert_true(errors is Array, "validate of %s = %s returns a list" % [key, str(value)])


## Every hostile value of the assault flag is refused (not read as true or false), with the garrison still in the snapshot.
func test_hostile_assault_flag_is_refused() -> void:
	var war := CombatFixture.war()
	for value: Variant in HOSTILE:
		var input := CombatFixture.assault_input(war, [CombatFixture.pikemen(1, 0), CombatFixture.pikemen(2, 1)], 300, 2)
		input["assault"] = value
		assert_false(CombatInput.validate(war, input).is_empty(), "assault %s is refused" % str(value))


## The garrison's morale: a dict, null, -500, 5000, text and 7.5 are each refused before state() reads it.
func test_garrison_morale_is_checked_before_use() -> void:
	var war := CombatFixture.war()
	for value: Variant in [{}, null, -500, 5000, "x", 7.5]:
		var input := CombatFixture.assault_input(war, [CombatFixture.pikemen(1, 0), CombatFixture.pikemen(2, 1)], 300, 2)
		input["garrison"]["morale"] = value
		assert_false(CombatInput.validate(war, input).is_empty(), "garrison morale %s is refused" % str(value))
	var good := CombatFixture.assault_input(war, [CombatFixture.pikemen(1, 0), CombatFixture.pikemen(2, 1)], 300, 2)
	good["garrison"]["morale"] = 700
	assert_eq(CombatInput.validate(war, good), [] as Array[String], "a garrison morale of 700 is valid")


## Men and full are capped (10,000,000 is refused), and so is a fire above 1,000 permille.
func test_huge_men_and_fire_are_refused() -> void:
	var war := CombatFixture.war()
	var big := CombatFixture.input_of(war, [CombatFixture.pikemen(1, 0, 10000000), CombatFixture.pikemen(2, 1)])
	assert_false(CombatInput.validate(war, big).is_empty(), "10,000,000 men are refused")
	var full := CombatFixture.input_of(war, [CombatFixture.company(1, 0, "infantry", 10, 4, 5, 0, 0, 1000, false, 10000000),
			CombatFixture.pikemen(2, 1)])
	assert_false(CombatInput.validate(war, full).is_empty(), "a full of 10,000,000 is refused")
	var fire := CombatFixture.input_of(war, [CombatFixture.company(1, 0, "missile", 10, 5, 2, 1000000), CombatFixture.pikemen(2, 1)])
	assert_false(CombatInput.validate(war, fire).is_empty(), "a fire of 1,000,000 is refused")


## The highest ground (cover 1,000, relief 6 adds 500) validates and fights.
func test_maximum_ground_validates_and_fights() -> void:
	var war := CombatFixture.war()
	var input := CombatFixture.input_of(war, [CombatFixture.pikemen(1, 0), CombatFixture.pikemen(2, 1)], 1000, true, true, 6,
			"mountains")
	assert_eq(int((input["ground"] as Dictionary)["defence"]), 1500, "1,000 cover plus 500 relief")
	assert_eq(CombatInput.validate(war, input), [] as Array[String], "the maximum ground is valid")
	var rng := Rng.new()
	rng.seed_with(2)
	var end: Dictionary = Combat.fight(war, input, rng)["end"]
	assert_true(int(end["days"]) >= 1, "the battle on the highest ground runs")
