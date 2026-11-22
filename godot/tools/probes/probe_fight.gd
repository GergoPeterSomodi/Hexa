## The fight's speed and the scenario table of docs/architecture/m7-build-spec.md 4.6 (B7's probe): 1,000 fights of 8 companies
## against 8, timed, and the attacker's win share of the starting pairs on farmland and in woods, over 100 seeds each.
## Run: godot --headless --path godot -s res://tools/probes/probe_fight.gd   (prints; always exits 0)
extends SceneTree


func _initialize() -> void:  # not _init: the classes are known to the parser only from here on
	var war := CombatFixture.war()
	var sample := _battle(war, 8, 8, 0, false)
	var started := Time.get_ticks_usec()
	for seed_value: int in 1000:
		var rng := Rng.new()
		rng.seed_with(seed_value)
		Combat.fight(war, sample, rng)
	var per_fight := float(Time.get_ticks_usec() - started) / 1000.0 / 1000.0
	print("fight_ms 8 v 8, 1,000 fights: %.3f ms a battle" % per_fight)
	print("pair farmland woods (attacker win % over 100 seeds)")
	for pair: Array in [[3, 3], [4, 3], [6, 4], [4, 2], [6, 3]]:
		print("%d v %d   %3d%%   %3d%%" % [int(pair[0]), int(pair[1]), _win_pct(war, int(pair[0]), int(pair[1]), 0, false),
				_win_pct(war, int(pair[0]), int(pair[1]), 250, true)])
	quit(0)


func _battle(war: WarDef, attackers: int, defenders: int, cover: int, rough: bool) -> Dictionary:
	var fighters: Array = []
	for i: int in attackers:
		fighters.append(CombatFixture.pikemen(1 + i, 0))
	for i: int in defenders:
		fighters.append(CombatFixture.pikemen(10 + i, 1))
	return CombatFixture.input_of(war, fighters, cover, rough)


func _win_pct(war: WarDef, attackers: int, defenders: int, cover: int, rough: bool) -> int:
	var input := _battle(war, attackers, defenders, cover, rough)
	var wins: int = 0
	for seed_value: int in range(1, 101):
		var rng := Rng.new()
		rng.seed_with(seed_value)
		if int(Combat.fight(war, input, rng)["end"]["winner"]) == 0:
			wins += 1
	return wins
