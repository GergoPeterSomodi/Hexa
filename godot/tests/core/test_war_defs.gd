## WarDef and the war part of GameDefs (core/defs/war_def.gd; docs/architecture/m7-build-spec.md sections 4.3 to 4.9, 5.1 and
## 9): data/defs/war.tres against the spec's numbers, the rows of tools/war_tables.gd, and planted faults (P). Every planted
## fault works on a fresh load (CACHE_MODE_IGNORE): a shared sub-resource would pollute later tests.
extends GutTest

const WarTables := preload("res://tools/war_tables.gd")


func _has(errors: Array[String], fragment: String) -> bool:
	for e: String in errors:
		if e.contains(fragment):
			return true
	return false


func _load_war() -> WarDef:
	return ResourceLoader.load("res://data/defs/war.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as WarDef


func _committed_defs() -> GameDefs:
	return ResourceLoader.load(
		"res://data/defs/game_defs.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	) as GameDefs


func test_committed_war_loads_and_validates() -> void:
	var w := _load_war()
	assert_not_null(w, "war.tres loads")
	assert_eq(w.validate(), [] as Array[String], "war.tres validates")
	var defs := _committed_defs()
	assert_not_null(defs.war, "GameDefs lists the war")
	assert_eq(defs.validate(), [] as Array[String], "committed defs validate with the war")


## 4.6: the combat bases, the fight tables, the stances and the dice.
func test_fight_numbers_equal_spec() -> void:
	var w := _load_war()
	assert_eq(w.shock_permille, 80)
	assert_eq(w.backline_permille, 40)
	assert_eq(w.flank_permille, 1250)
	assert_eq(w.pikes_vs_horse_permille, 1250)
	assert_eq(w.fight_attack[&"infantry"], PackedInt32Array([1000, 1000, 1000]))
	assert_eq(w.fight_attack[&"missile"], PackedInt32Array([1000, 900, 800]))
	assert_eq(w.fight_attack[&"cavalry"], PackedInt32Array([1400, 700, 500]))
	assert_eq(w.fight_attack[&"artillery"], PackedInt32Array([1000, 600, 2000]))
	assert_eq(w.fight_defence[&"infantry"], PackedInt32Array([1000, 1100, 1300]))
	assert_eq(w.fight_defence[&"missile"], PackedInt32Array([800, 900, 900]))
	assert_eq(w.fight_defence[&"cavalry"], PackedInt32Array([1000, 800, 800]))
	assert_eq(w.fight_defence[&"artillery"], PackedInt32Array([500, 500, 800]))
	assert_eq(w.stance_dealt, {&"attack": 1200, &"hold": 900, &"withdraw": 1000} as Dictionary[StringName, int])
	assert_eq(w.stance_taken, {&"attack": 1100, &"hold": 800, &"withdraw": 1000} as Dictionary[StringName, int])
	assert_eq(w.dice_permille, PackedInt32Array([700, 800, 900, 1100, 1200, 1400]))
	assert_eq(w.hit_spread_permille, 500)


## 4.6 morale, days, ground, ranks and experience.
func test_morale_days_ground_and_ranks_equal_spec() -> void:
	var w := _load_war()
	assert_eq([w.morale_per_loss, w.front_drain, w.reserve_drain, w.hunger_drain], [5, 20, 30, 30])
	assert_eq([w.reserve_shaken_permille, w.flank_morale, w.centre_shock], [500, 100, 250])
	assert_eq([w.flee_morale, w.flee_pursuit_permille, w.flee_morale_left], [100, 150, 150])
	assert_eq([w.withdraw_day, w.withdraw_pursuit_permille, w.withdraw_pursuit_attacker_permille], [2, 50, 100])
	assert_eq([w.withdraw_morale, w.battle_days, w.wounded_share_permille, w.wounded_return_permille], [250, 8, 500, 500])
	assert_eq([w.attack_morale, w.morale_recovery, w.retreat_range], [500, 250, 6])
	assert_eq([w.crossing_penalty_permille, w.uphill_penalty_permille, w.river_penalty_permille], [300, 50, 200])
	assert_eq(w.relief_defence_add, PackedInt32Array([0, 0, 0, 50, 150, 300, 500]))
	assert_eq([w.relief_rough_from, w.relief_narrow_from], [3, 5])
	assert_eq(w.relief_elevation, PackedInt32Array([0, 0, 0, 1, 1, 2, 2]))
	assert_eq(w.rank_xp, PackedInt32Array([0, 3, 7]))
	assert_eq(w.rank_permille, PackedInt32Array([1000, 1100, 1200]))
	assert_eq(w.rank_names, PackedStringArray(["", "Veteran", "Elite"]))
	assert_eq([w.xp_win, w.xp_lose], [2, 1])


## 4.3, 4.5 and 4.4: garrisons, sieges, occupation, the storm cut and the area reaches.
func test_garrison_siege_and_occupation_equal_spec() -> void:
	var w := _load_war()
	assert_eq([w.garrison_attack, w.garrison_defence, w.garrison_defence_per_level], [3, 3, 2])
	assert_eq([w.castle_defence_permille, w.garrison_per_level, w.garrison_regen_per_level], [250, 400, 100])
	assert_eq(w.battle_records_kept, 60)
	assert_eq([w.siege_base_need, w.siege_per_level, w.siege_min_seasons], [4, 3, 2])
	assert_eq([w.siege_hunger, w.siege_rate_max], [2, 6])
	assert_eq(w.crowd_bands, PackedInt32Array([2000, 4000]))
	assert_eq([w.storm_cut_permille, w.militia_men], [500, 250])
	assert_eq(w.area_reach, PackedInt32Array([0, 1, 2, 3]))
	assert_eq([w.unsupported_seasons, w.support_range], [6, 3])
	assert_eq([w.occupied_output_permille, w.occupied_tax_permille, w.sack_permille], [500, 500, 150])


## 4.9 and 4.2: the peace, the score and the truce; 4.6 the odds.
func test_peace_score_and_odds_equal_spec() -> void:
	var w := _load_war()
	assert_eq([w.peace_min_seasons, w.take_score, w.take_score_weak], [4, 3, 1])
	assert_eq([w.white_score_min, w.capital_score, w.truce_seasons], [-1, 3, 8])
	assert_eq([w.war_timer_seasons, w.war_timer_warning], [40, 32])
	var words: Array[String] = []
	var froms: Array[int] = []
	for entry: Dictionary in w.odds_words:
		words.append(entry["word"])
		froms.append(entry["from"])
	assert_eq(words, ["Hopeless", "Poor", "Even", "Favourable", "Overwhelming"] as Array[String])
	assert_eq(froms, [0, 800, 1000, 1200, 2500] as Array[int])
	assert_eq(w.odds_ground, {&"open": 1000, &"hills": 1340, &"woods": 1400, &"marsh": 2080, &"mountains": 3390, &"snow": 2920} as Dictionary[StringName, int])
	assert_eq(w.garrison_odds_permille, 3100)
	assert_eq(w.garrison_odds_alone, PackedInt32Array([0, 1800, 1100, 1000]))


## Table 4.3 (the fortresses): the three pieces and their garrisons, reaches and regrowth.
func test_fortress_rows_equal_table_4_3() -> void:
	var rows := WarTables.fortress_rows(_committed_defs())
	assert_eq(rows.size(), 6, "header and five fortress levels")
	assert_true(String(rows[1]).begins_with("settlements"), "walled town first")
	assert_true(String(rows[1]).contains("fortress 2 garrison   800 holds 2 regrows 200"), "walled town 800")
	assert_true(String(rows[2]).contains("fortress 3 garrison  1200 holds 3 regrows 300"), "city 1,200")
	assert_true(String(rows[3]).contains("level 1 fortress 1 garrison   400 holds 1 regrows 100"), "watchtower 400")
	assert_true(String(rows[5]).contains("level 3 fortress 3 garrison  1200 holds 3 regrows 300"), "fortress 1,200")


## Table 4.5: the need on plain ground with a full garrison is 7, 10 and 13; the stores are 1 + level.
func test_siege_rows_equal_table_4_5_terms() -> void:
	var rows := WarTables.siege_rows(_committed_defs())
	assert_eq(rows.size(), 4, "header and three levels")
	assert_true(String(rows[1]).contains("fortress 1 need 7 stores 2"), "watchtower need 7")
	assert_true(String(rows[2]).contains("fortress 2 need 10 stores 3"), "castle need 10")
	assert_true(String(rows[3]).contains("fortress 3 need 13 stores 4"), "fortress need 13")


## Table 4.6: the fight tables by branch, the stances, the dice and the four kinds of company.
func test_fight_rows_equal_table_4_6() -> void:
	var rows := WarTables.fight_rows(_committed_defs())
	assert_true(String(rows[1]).begins_with("infantry"), "infantry first")
	assert_true(String(rows[2]).contains("attack [1000, 900, 800] | defence [800, 900, 900]"), "missile row")
	assert_true(String(rows[4]).contains("attack [1000, 600, 2000]"), "artillery attack")
	assert_true(String(rows[5]).contains("dice [700, 800, 900, 1100, 1200, 1400]"), "dice")
	assert_true(String(rows[6]).contains("pikemen"), "kinds listed after the stances")
	assert_true(String(rows[9]).contains("bombards    men 100 attack  6 defence 1 fire  50 siege 1"), "bombards row")


func test_war_tables_are_pure_builders() -> void:
	assert_eq(WarTables.tables(_committed_defs()).size(), 6 + 4 + 10, "rows of the three tables")


func test_planted_fault_war_not_set() -> void:
	var defs := _committed_defs()
	defs.war = null
	assert_true(_has(defs.validate(), "war is not set"), "a missing war refused")


func test_planted_fault_fight_table_of_two_entries() -> void:
	var w := _load_war()
	w.fight_attack[&"infantry"] = PackedInt32Array([1000, 1000])
	assert_true(_has(w.validate(), "fight_attack infantry has 2 entries, expected 3"), "two entries refused")
	w = _load_war()
	w.fight_defence.erase(&"artillery")
	var errors := w.validate()
	assert_true(_has(errors, "fight_defence has 3 entries, expected 4"), "a missing branch counted")
	assert_true(_has(errors, "fight_defence has no branch 'artillery'"), "a missing branch named")


func test_planted_fault_fight_value_out_of_range() -> void:
	var w := _load_war()
	w.fight_defence[&"cavalry"] = PackedInt32Array([1000, 0, 800])
	assert_true(_has(w.validate(), "fight_defence cavalry[1] is 0, expected 1 to 4000"), "zero refused")


func test_planted_fault_dice_not_ascending() -> void:
	var w := _load_war()
	w.dice_permille = PackedInt32Array([700, 800, 800, 1100, 1200, 1400])
	assert_true(_has(w.validate(), "dice_permille[2] is 800, not above 800"), "a flat step refused")
	w = _load_war()
	w.dice_permille = PackedInt32Array([700, 800, 900, 1100, 1200])
	assert_true(_has(w.validate(), "dice_permille has 5 entries, expected 6"), "five dice refused")


func test_planted_fault_withdraw_day_at_the_last_day() -> void:
	var w := _load_war()
	w.withdraw_day = 8
	assert_true(_has(w.validate(), "withdraw_day 8 should be under battle_days 8"), "withdraw on the last day refused")
	w = _load_war()
	w.battle_days = 21
	assert_true(_has(w.validate(), "battle_days is 21, expected 1 to 8"), "21 days refused")


func test_planted_fault_odds_word_out_of_order() -> void:
	var w := _load_war()
	w.odds_words[2]["from"] = 700
	assert_true(_has(w.validate(), "odds_words[2] starts at 700, not above 800"), "out of order refused")
	w = _load_war()
	w.odds_words[0]["from"] = 5
	assert_true(_has(w.validate(), "odds_words[0] starts at 5, expected 0"), "first word not at 0 refused")


func test_planted_fault_missing_odds_ground_key() -> void:
	var w := _load_war()
	w.odds_ground.erase(&"marsh")
	assert_true(_has(w.validate(), "odds_ground has no key 'marsh'"), "a missing ground refused")


func test_planted_fault_area_reach_not_ascending() -> void:
	var w := _load_war()
	w.area_reach = PackedInt32Array([0, 2, 1, 3])
	assert_true(_has(w.validate(), "area_reach[2] is 1, not above 2"), "area reach out of order refused")


func test_planted_fault_negative_counts_and_the_score_exception() -> void:
	var w := _load_war()
	w.battle_records_kept = -1
	assert_true(_has(w.validate(), "battle_records_kept is -1, expected 1 to 1000"), "a negative count refused")
	w = _load_war()
	w.white_score_min = -5
	assert_false(_has(w.validate(), "white_score_min"), "a negative score is allowed")
	w = _load_war()
	w.sack_permille = 1001
	assert_true(_has(w.validate(), "sack_permille is 1001, expected 0 to 1000"), "a share over 1,000 refused")


func test_planted_fault_stance_missing() -> void:
	var w := _load_war()
	w.stance_dealt.erase(&"hold")
	var errors := w.validate()
	assert_true(_has(errors, "stance_dealt has 2 entries, expected 3"), "two stances counted")
	assert_true(_has(errors, "stance_dealt has no stance 'hold'"), "the missing stance named")


func test_planted_fault_garrison_odds_sizes() -> void:
	var w := _load_war()
	w.garrison_odds_alone = PackedInt32Array([0, 1800, 1100])
	assert_true(_has(w.validate(), "garrison_odds_alone has 3 entries, expected 4"), "three levels refused")
	w = _load_war()
	w.relief_elevation = PackedInt32Array([0, 0, 0, 1, 1, 2])
	assert_true(_has(w.validate(), "relief_elevation has 6 entries, expected 7"), "six relief levels refused")


## Review fix: a bad odds word gives a message, never an exception (every entry is type-checked before use).
func test_planted_fault_odds_entries_of_the_wrong_type() -> void:
	var cases: Array = [
		[[{"from": 0, "word": "x"}, {"from": 5, "word": 7}], "odds_words[1] has no word of text"],
		[[{"from": 0, "word": "x"}, {"from": 5}], "odds_words[1] has no word of text"],
		[[{"from": 0, "word": "x"}, {"from": 5, "word": ""}], "odds_words[1] has an empty word"],
		[[{"from": 0, "word": "x"}, {"from": null, "word": "y"}], "odds_words[1] has no whole number 'from'"],
		[[{"from": 0, "word": "x"}, {"from": 5.5, "word": "y"}], "odds_words[1] has no whole number 'from'"],
		[[{"from": 0, "word": "x"}, {"from": "abc", "word": "y"}], "odds_words[1] has no whole number 'from'"],
		[[{"from": 0, "word": "x"}, {"from": 4000000000000000000, "word": "y"}], "odds_words[1] from is"],
		[[{"from": 0, "word": "x"}, {"from": 5, "word": "y"}, {"from": 3, "word": "z"}], "odds_words[2] starts at 3, not above 5"],
	]
	for case: Array in cases:
		var w := _load_war()
		var words: Array[Dictionary] = []
		for entry: Dictionary in case[0]:
			words.append(entry)
		w.odds_words = words
		var errors := w.validate()
		assert_true(_has(errors, case[1]), "refused: %s" % case[1])


## Review fix: every count that divides or loops starts at 1; a zero or negative one is refused.
func test_planted_fault_divisors_and_loops_start_at_one() -> void:
	for field: String in ["siege_base_need", "siege_per_level", "siege_rate_max", "garrison_per_level",
			"war_timer_seasons", "battle_records_kept"]:
		var w := _load_war()
		w.set(field, 0)
		assert_true(_has(w.validate(), "%s is 0, expected 1 to" % field), "%s at 0 refused" % field)
	var w := _load_war()
	w.garrison_odds_alone = PackedInt32Array([0, 0, 0, 0])
	assert_true(_has(w.validate(), "garrison_odds_alone[1] is 0, expected 1 to 10000"), "all-zero odds refused")
	w = _load_war()
	w.garrison_odds_alone = PackedInt32Array([-5, -5, -5, -5])
	assert_true(_has(w.validate(), "garrison_odds_alone[0] is -5, expected 0 to 10000"), "negative odds refused")


## Review fix: the orderings of the timer and the weak take score.
func test_planted_fault_orderings() -> void:
	var w := _load_war()
	w.war_timer_warning = 99
	assert_true(_has(w.validate(), "war_timer_warning 99 should not be over war_timer_seasons 40"), "warning after the timer")
	w = _load_war()
	w.take_score_weak = 50
	assert_true(_has(w.validate(), "take_score_weak 50 should not be over take_score 3"), "weak take over take")


## Review fix: the arrays and scalars have ranges (no negative or huge values, shares within 1,000, floors on the fight).
func test_planted_fault_ranges_of_arrays_and_scalars() -> void:
	var w := _load_war()
	w.relief_defence_add = PackedInt32Array([0, 0, 0, 50, 150, 300, 2000000000])
	assert_true(_has(w.validate(), "relief_defence_add[6] is 2000000000, expected 0 to 1000"), "huge defence refused")
	w = _load_war()
	w.relief_defence_add = PackedInt32Array([-9000, 0, 0, 0, 0, 0, 0])
	assert_true(_has(w.validate(), "relief_defence_add[0] is -9000, expected 0 to 1000"), "negative defence refused")
	w = _load_war()
	w.crowd_bands = PackedInt32Array([-5, -1])
	assert_true(_has(w.validate(), "crowd_bands[0] is -5, expected 1 to 10000"), "negative crowd refused")
	w = _load_war()
	w.rank_xp = PackedInt32Array([-9, 3, 7])
	assert_true(_has(w.validate(), "rank_xp[0] is -9, expected 0 to 100000"), "negative experience refused")
	w = _load_war()
	w.rank_xp = PackedInt32Array([5, 6, 7])
	assert_true(_has(w.validate(), "rank_xp[0] is 5, expected 0"), "a first rank with experience refused")
	w = _load_war()
	w.shock_permille = 0
	assert_true(_has(w.validate(), "shock_permille is 0, expected 1 to 1000"), "shock 0 refused")
	w = _load_war()
	w.flank_permille = 999
	assert_true(_has(w.validate(), "flank_permille is 999, expected 1000 to 4000"), "flank under 1,000 refused")
	w = _load_war()
	w.hit_spread_permille = 5000000
	assert_true(_has(w.validate(), "hit_spread_permille is 5000000, expected 1 to 1000"), "huge spread refused")
	w = _load_war()
	w.flee_morale = 5000
	assert_true(_has(w.validate(), "flee_morale is 5000, expected 0 to 1000"), "morale over 1,000 refused")
	w = _load_war()
	w.attack_morale = 5000
	assert_true(_has(w.validate(), "attack_morale is 5000, expected 0 to 1000"), "attack morale over 1,000 refused")


## Review fix: odds_ground is exactly the six grounds.
func test_planted_fault_odds_ground_exactly_six() -> void:
	var w := _load_war()
	w.odds_ground[&"swamp"] = 5
	assert_true(_has(w.validate(), "odds_ground has 7 keys, expected the six grounds"), "an extra ground refused")


## Review fix: the cap of a battle is BattleRecord.MAX_DAYS; WarDef keeps the same value (defs cannot read state).
func test_battle_days_cap_is_the_battle_record_cap() -> void:
	assert_eq(WarDef.MAX_BATTLE_DAYS, BattleRecord.MAX_DAYS, "WarDef and BattleRecord agree on the days")
	var w := _load_war()
	w.battle_days = 9
	assert_true(_has(w.validate(), "battle_days is 9, expected 1 to 8"), "a ninth day refused")
	w = _load_war()
	w.battle_days = 12
	assert_true(_has(w.validate(), "battle_days is 12, expected 1 to 8"), "a twelfth day refused")


## Review fix (d): a test that changes its game's defs.war, nested words and rows included, leaves the committed war alone.
func test_fixtures_copy_the_war_and_leave_the_committed_one() -> void:
	var committed := EconomyFixture.committed().war
	var copies: Array[GameDefs] = [EconomyFixture.defs(), ArmyFixture.defs(), PathFixture.defs_copy()]
	for d: GameDefs in copies:
		assert_ne(d.war, committed, "a copy of the war, not the committed one")
		d.war.odds_words[2]["from"] = 7
		var row := d.war.fight_attack[&"infantry"]
		row[0] = 1
		d.war.fight_attack[&"infantry"] = row
		d.war.odds_ground[&"open"] = 2
		d.war.stance_dealt[&"hold"] = 5
		d.war.battle_days = 3
		assert_eq(d.war.validate().is_empty(), false, "the copy's change is seen by its own validation")
	assert_eq(committed.odds_words[2]["from"], 1000, "committed odds untouched")
	assert_eq(committed.fight_attack[&"infantry"][0], 1000, "committed fight row untouched")
	assert_eq(committed.odds_ground[&"open"], 1000, "committed ground untouched")
	assert_eq(committed.stance_dealt[&"hold"], 900, "committed stance untouched")
	assert_eq(committed.battle_days, 8, "committed days untouched")
	assert_eq(committed.validate(), [] as Array[String], "the committed war still validates")
