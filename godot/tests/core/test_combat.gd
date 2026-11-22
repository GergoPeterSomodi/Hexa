@warning_ignore_start("integer_division")
## The pure battle's numbers (docs/architecture/m7-build-spec.md 4.6, 5.3): the worked hit (33 men), the apply of a hit, the odds
## words and the odds card (Savoy's "Favourable"), the ground, the validation of an input, the stances, and that fight does not
## change its input. Every war a test changes is a copy (CombatFixture.war); the spread draw is a stub (CombatFixture.FlatRng).
extends GutTest


func _state(war: WarDef, fighters: Array, roll_a: int = 4, roll_d: int = 4) -> CombatState:
	var st := CombatInput.state(war, CombatFixture.input_of(war, fighters), CombatFixture.FlatRng.new())
	st.day = 1
	st.rolls = PackedInt32Array([roll_a, roll_d])
	return st


## 4.6: pikemen on Attack against pikemen on Hold, farmland, both at full, roll 4, spread 1,000: 33 men (16 wounded, 17 killed).
func test_worked_hit_is_33_men() -> void:
	var war := CombatFixture.war()
	var st := _state(war, [CombatFixture.pikemen(1, 0), CombatFixture.pikemen(2, 1)])
	assert_eq(CombatHit.hit(st, 1, 2, war.shock_permille, 1000), 33, "the worked hit of 4.6")


## The same hit with the dice of roll 1 (700): 500 x 80 x 4,000 / 5,000 x 1,200 / 1,000 x 800 / 1,000 x 700 / 1,000 = 21.
func test_dice_changes_the_hit() -> void:
	var war := CombatFixture.war()
	var st := _state(war, [CombatFixture.pikemen(1, 0), CombatFixture.pikemen(2, 1)], 1, 1)
	assert_eq(CombatHit.hit(st, 1, 2, war.shock_permille, 1000), 21, "roll 1 is 700 permille")


## A planted fault: a changed dice number in WarDef changes the worked hit (the copy is changed, the committed war is not).
func test_planted_dice_fault_changes_the_hit() -> void:
	var war := CombatFixture.war()
	war.dice_permille = PackedInt32Array([700, 800, 900, 1000, 1200, 1400])
	var st := _state(war, [CombatFixture.pikemen(1, 0), CombatFixture.pikemen(2, 1)])
	assert_eq(CombatHit.hit(st, 1, 2, war.shock_permille, 1000), 30, "a roll of 4 at 1,000 permille gives 30")
	assert_eq(CombatFixture.war().dice_permille[3], 1100, "the committed war keeps its 1,100")


## Apply: the men lost are the hit's, a wounded share returns as wounded, the rest is killed, and the totals book them.
func test_apply_books_killed_and_wounded() -> void:
	var war := CombatFixture.war()
	var st := _state(war, [CombatFixture.pikemen(1, 0), CombatFixture.pikemen(2, 1)])
	CombatHit.apply(st, [[2, 33, war.wounded_share_permille]])
	assert_eq(int(st.fighter(2)["men"]), 467, "33 men leave the company")
	assert_eq(st.killed_total[1], 17, "17 killed")
	assert_eq(st.wounded_total[1], 16, "16 wounded")
	assert_eq(int(st.wounded_by_key[2]), 16, "the company's wounded")


## A hit never takes more than the target has left.
func test_apply_caps_at_men_left() -> void:
	var war := CombatFixture.war()
	var st := _state(war, [CombatFixture.pikemen(1, 0), CombatFixture.pikemen(2, 1, 40)])
	CombatHit.apply(st, [[2, 900, 0]])
	assert_eq(int(st.fighter(2)["men"]), 0, "the company is at 0")
	assert_eq(st.killed_total[1], 40, "only its 40 men are booked")
	assert_false(st.live(2), "a company at 0 is not live")


## The odds word bands (4.6, D50): Hopeless below 800, Poor, Even, Favourable from 1,200, Overwhelming from 2,500.
func test_odds_words_by_band() -> void:
	var war := CombatFixture.war()
	assert_eq(Combat.odds_word(war, 0), "Hopeless")
	assert_eq(Combat.odds_word(war, 799), "Hopeless")
	assert_eq(Combat.odds_word(war, 800), "Poor")
	assert_eq(Combat.odds_word(war, 999), "Poor")
	assert_eq(Combat.odds_word(war, 1000), "Even")
	assert_eq(Combat.odds_word(war, 1199), "Even")
	assert_eq(Combat.odds_word(war, 1200), "Favourable")
	assert_eq(Combat.odds_word(war, 2499), "Favourable")
	assert_eq(Combat.odds_word(war, 2500), "Overwhelming")


## The spec's example: Savoy's 2,000 men against Milan's 1,000 on farmland is ratio 2,000, factor 1,000, "Favourable".
func test_savoy_odds_card_is_favourable() -> void:
	var war := CombatFixture.war()
	var attack: int = Combat.odds_side(war, [{"men": 2000, "morale": 1000}], {}, false)
	var defence: int = Combat.odds_side(war, [{"men": 1000, "morale": 1000}], {}, false)
	var card: Dictionary = Combat.odds_card(war, attack, defence, "open", false)
	assert_eq(card["ratio"], 2000)
	assert_eq(card["factor"], 1000)
	assert_eq(card["word"], "Favourable")


## The odds factor: the hex's ground key, 1,000 in an assault; a hill is 1,340 and a mountain 3,390.
func test_odds_factor_by_ground_and_assault() -> void:
	var war := CombatFixture.war()
	assert_eq(Combat.odds_factor(war, "hills", false), 1340)
	assert_eq(Combat.odds_factor(war, "mountains", false), 3390)
	assert_eq(Combat.odds_factor(war, "mountains", true), 1000, "an assault uses 1,000")


## A garrison's weight: with a field army of its side 3,100 permille, alone 1,800 at level 1 and none at level 0.
func test_garrison_odds_weight() -> void:
	var war := CombatFixture.war()
	var garrison: Dictionary = {"men": 1000, "level": 1}
	assert_eq(Combat.odds_side(war, [], garrison, false), 1800, "alone at level 1")
	assert_eq(Combat.odds_side(war, [], garrison, true), 3100, "with a field army")
	assert_eq(Combat.odds_side(war, [], {"men": 1000, "level": 0}, false), 0, "alone at level 0 weighs nothing")
	assert_eq(Combat.odds_strength(500, 800), 400, "men x morale / 1,000")


## The ground: relief 3 is rough (hills), relief 5 is narrow (mountains); the relief adds its defence and its elevation.
func test_ground_from_cover_and_relief() -> void:
	var war := CombatFixture.war()
	var hills: Dictionary = Combat.make_ground(war, 250, false, false, 3, "hills")
	assert_true(bool(hills["rough"]), "hills are rough")
	assert_false(bool(hills["narrow"]), "hills are not narrow")
	assert_eq(hills["defence"], 300, "woods' 250 is not here; the relief adds 50")
	assert_eq(hills["elevation"], 1)
	var mountain: Dictionary = Combat.make_ground(war, 0, false, false, 5, "mountains")
	assert_true(bool(mountain["narrow"]), "mountains are narrow")
	assert_eq(mountain["defence"], 300, "relief 5 adds 300")


## Validation: a good input has no problem; a morale over 1,000, an unknown branch, a missing key and a repeated tag each
## give a message.
func test_validate_names_each_problem() -> void:
	var war := CombatFixture.war()
	var good := CombatFixture.input_of(war, [CombatFixture.pikemen(1, 0), CombatFixture.pikemen(2, 1)])
	assert_eq(CombatInput.validate(war, good), [] as Array[String], "a good input is valid")
	var morale := CombatFixture.input_of(war, [CombatFixture.pikemen(1, 0, 500, 1001), CombatFixture.pikemen(2, 1)])
	assert_false(CombatInput.validate(war, morale).is_empty(), "morale 1,001 is refused")
	var branch := CombatFixture.input_of(war, [CombatFixture.company(1, 0, "dragoons", 100, 4, 4), CombatFixture.pikemen(2, 1)])
	assert_false(CombatInput.validate(war, branch).is_empty(), "an unknown branch is refused")
	var missing := good.duplicate(true)
	missing.erase("ground")
	assert_false(CombatInput.validate(war, missing).is_empty(), "a missing key is refused")
	var same := good.duplicate(true)
	same["defender"] = "SAV"
	assert_false(CombatInput.validate(war, same).is_empty(), "the same tag on both sides is refused")


## A withdrawal with no retreat is a hold; with a retreat it stays a withdrawal.
func test_withdraw_needs_a_retreat() -> void:
	var war := CombatFixture.war()
	var input := CombatFixture.input_of(war, [CombatFixture.pikemen(1, 0), CombatFixture.pikemen(2, 1)])
	input["stance"]["def"] = "withdraw"
	assert_eq(CombatInput.state(war, input, Rng.new()).stance[1], "hold", "no retreat: a hold")
	input["can_retreat"]["def"] = true
	assert_eq(CombatInput.state(war, input, Rng.new()).stance[1], "withdraw", "a retreat: a withdrawal")


## fight does not change its input: the plain snapshot is the same before and after.
func test_fight_does_not_change_its_input() -> void:
	var war := CombatFixture.war()
	var input := CombatFixture.assault_input(war, [CombatFixture.pikemen(1, 0), CombatFixture.knights(2, 1)], 800, 2)
	var before: Dictionary = input.duplicate(true)
	Combat.fight(war, input, CombatFixture.FlatRng.new())
	assert_eq(input, before, "the input is unchanged")
