@warning_ignore_start("integer_division")
## The starting bands of the battle (docs/architecture/m7-build-spec.md 4.6, the table "Starting expectations"): the attacker's win
## share of each starting pair of pikemen (500 men a company, the attacker on Attack, the defender on Hold) on farmland and in
## woods, over the fixed seeds 1 to 500 (deterministic), with the day-cap and day rules of 4.6. The woods cover is read from
## data/defs/terrain/woods.tres. Calibrated in B7 (2026-11-22, probes/probe_calibrate.gd): woods 250 -> 350 for the woods gap.
## One band cannot be met with the pinned worked hit and the allowed data: 4 v 2 on farmland (see the pending test).
extends GutTest

const WOODS_PATH := "res://data/defs/terrain/woods.tres"
const SEEDS := 500


func _woods_cover() -> int:
	var woods := ResourceLoader.load(WOODS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TerrainDef
	return woods.defence_permille


## One starting pair: [attacker win %, day-cap %, days 1 to 8 only (bool)] over the fixed seeds.
func _pair(war: WarDef, attackers: int, defenders: int, cover: int, rough: bool) -> Array:
	var fighters: Array = []
	for i: int in attackers:
		fighters.append(CombatFixture.pikemen(1 + i, 0))
	for i: int in defenders:
		fighters.append(CombatFixture.pikemen(10 + i, 1))
	var input := CombatFixture.input_of(war, fighters, cover, rough)
	var wins: int = 0
	var capped: int = 0
	var days_ok: bool = true
	for seed_value: int in range(1, SEEDS + 1):
		var rng := Rng.new()
		rng.seed_with(seed_value)
		var end: Dictionary = Combat.fight(war, input, rng)["end"]
		if int(end["winner"]) == 0:
			wins += 1
		var days: int = int(end["days"])
		if days >= war.battle_days:
			capped += 1
		if days < 1 or days > war.battle_days:
			days_ok = false
	return [wins * 100 / SEEDS, capped * 100 / SEEDS, days_ok]


func test_farmland_bands() -> void:
	var war := CombatFixture.war()
	var table: Array = [[3, 3, 35, 55], [4, 3, 60, 85], [6, 4, 60, 90], [6, 3, 65, 95]]
	for row: Array in table:
		var pct: int = int(_pair(war, int(row[0]), int(row[1]), 0, false)[0])
		assert_true(pct >= int(row[2]) and pct <= int(row[3]),
				"%d v %d farmland: %d%% in %d to %d" % [int(row[0]), int(row[1]), pct, int(row[2]), int(row[3])])


func test_woods_are_at_least_ten_points_lower() -> void:
	var war := CombatFixture.war()
	var cover: int = _woods_cover()
	for pair: Array in [[3, 3], [4, 3], [6, 4], [6, 3]]:
		var farm: int = int(_pair(war, int(pair[0]), int(pair[1]), 0, false)[0])
		var woods: int = int(_pair(war, int(pair[0]), int(pair[1]), cover, true)[0])
		assert_true(woods <= farm - 10, "%d v %d: woods %d%% against farmland %d%%" % [int(pair[0]), int(pair[1]), woods, farm])


func test_day_cap_and_days_rules() -> void:
	var war := CombatFixture.war()
	var cover: int = _woods_cover()
	for pair: Array in [[3, 3], [4, 3], [6, 4], [4, 2], [6, 3]]:
		var farm: Array = _pair(war, int(pair[0]), int(pair[1]), 0, false)
		var woods: Array = _pair(war, int(pair[0]), int(pair[1]), cover, true)
		assert_true(bool(farm[2]) and bool(woods[2]), "every battle ends in 1 to 8 days")
		assert_true(int(farm[1]) < 10 and int(woods[1]) < 10, "the day cap ends under 10%% of battles (%d v %d)" % [int(pair[0]), int(pair[1])])


## Known open: 4 v 2 on farmland is 100% under every data value that keeps the worked hit (33 men) and the other bands. The
## band (65 to 95) needs an owner decision (a unit or formula change outside this task). The value is pinned, not the band.
func test_known_open_four_v_two_on_farmland() -> void:
	var war := CombatFixture.war()
	var pct: int = int(_pair(war, 4, 2, 0, false)[0])
	assert_eq(pct, 100, "4 v 2 farmland measured at 100%% (spec band 65 to 95): known open")
	pending("4 v 2 farmland band 65 to 95 not met: owner decision (see the B7 report)")
