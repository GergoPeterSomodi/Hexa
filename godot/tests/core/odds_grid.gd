@warning_ignore_start("integer_division")
## The odds calibration grid (docs/architecture/m7-build-spec.md 4.6 and D50; M7 plan B18): for every pair of companies
## counts (attacker A and defender D, 1 to SIZES_MAX companies of 500 pikemen, morale 1,000) on every ground key of
## data/defs/war.tres, the odds card's word (Combat.odds_card) and the attacker's win share over SEEDS fixed seeds (the
## battle fought as the engine fights it: the attacker on Attack, the defender on Hold). Shared by tests/core/test_odds_calibration.gd
## and tools/probes/probe_odds.gd, so the probe prints the table the test pins. Pure: no engine, no autoload.
class_name OddsGrid
extends RefCounted

const SEEDS := 100
const SIZES_MAX := 6
const MEN := 500
const GROUNDS: Array[String] = ["open", "hills", "woods", "marsh", "mountains", "snow"]
const TERRAIN := "res://data/defs/terrain/%s.tres"


## The ground parameters of a key for Combat.make_ground: cover defence, rough, narrow, relief (the relief's share is the
## fight's, the key is the odds'). Woods, marsh and snow read their cover from data/defs/terrain; hills are relief 3, mountains
## relief 5 on open cover (the same shape as Battles._ground).
static func params_of(key: String) -> Dictionary:
	match key:
		"hills":
			return {"cover": 0, "rough": false, "narrow": false, "relief": 3, "key": key}
		"mountains":
			return {"cover": 0, "rough": true, "narrow": true, "relief": 5, "key": key}
		"woods", "marsh", "snow":
			var t := ResourceLoader.load(TERRAIN % key, "", ResourceLoader.CACHE_MODE_IGNORE) as TerrainDef
			return {"cover": t.defence_permille, "rough": t.rough, "narrow": t.narrow, "relief": 0, "key": key}
	return {"cover": 0, "rough": false, "narrow": false, "relief": 0, "key": "open"}


## A side of `count` companies of pikemen (MEN men, morale 1,000) as the fight's plain fighters, from `first_key`.
static func side_of(count: int, side: int, first_key: int) -> Array:
	var out: Array = []
	for i: int in count:
		out.append(CombatFixture.pikemen(first_key + i, side, MEN))
	return out


## One cell of the grid: {attackers, defenders, ground, attack, defence, ratio, value, word, wins, win_pct}. `seeds` may be lower
## for a faster test; the win share is wins x 100 / seeds (integer).
static func cell(war: WarDef, attackers: int, defenders: int, key: String, seeds: int = SEEDS) -> Dictionary:
	var g := params_of(key)
	var att: int = Combat.odds_side(war, _companies(attackers), {}, false)
	var dfn: int = Combat.odds_side(war, _companies(defenders), {}, false)
	var card := Combat.odds_card(war, att, dfn, key, false)
	var input := CombatFixture.input_of(war, side_of(attackers, 0, 1) + side_of(defenders, 1, 10),
			int(g["cover"]), bool(g["rough"]), bool(g["narrow"]), int(g["relief"]), key)
	var wins := 0
	for seed_value: int in range(1, seeds + 1):
		var rng := Rng.new()
		rng.seed_with(seed_value)
		var end: Dictionary = Combat.fight(war, input, rng)["end"]
		if int(end["winner"]) == 0:
			wins += 1
	return {"attackers": attackers, "defenders": defenders, "ground": key, "attack": att, "defence": dfn,
		"ratio": int(card["ratio"]), "value": int(card["value"]), "word": str(card["word"]),
		"wins": wins, "win_pct": wins * 100 / seeds}


## The whole grid: one cell for every pair of counts 1 to SIZES_MAX and every ground, in that order.
static func grid(war: WarDef, seeds: int = SEEDS, sizes: int = SIZES_MAX, grounds: Array[String] = GROUNDS) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: String in grounds:
		for a: int in range(1, sizes + 1):
			for d: int in range(1, sizes + 1):
				out.append(cell(war, a, d, key, seeds))
	return out


## Per odds word (in the order of war.odds_words): the cells, the mean, the lowest and the highest win share, and the value
## range. A word with no cell has cells 0 and the rest -1.
static func by_word(war: WarDef, cells: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in war.odds_words:
		var word: String = str((entry as Dictionary)["word"])
		var sum := 0
		var low := 101
		var high := -1
		var vlow := 1000000
		var vhigh := -1
		var n := 0
		for c: Dictionary in cells:
			if str(c["word"]) != word:
				continue
			n += 1
			sum += int(c["win_pct"])
			low = mini(low, int(c["win_pct"]))
			high = maxi(high, int(c["win_pct"]))
			vlow = mini(vlow, int(c["value"]))
			vhigh = maxi(vhigh, int(c["value"]))
		out.append({"word": word, "cells": n, "mean": sum / n if n > 0 else -1, "low": low if n > 0 else -1,
			"high": high, "value_low": vlow if n > 0 else -1, "value_high": vhigh})
	return out


## The companies of a side for the odds: `count` pikemen at full men and morale (Combat.odds_side reads men and morale).
static func _companies(count: int) -> Array:
	var out: Array = []
	for i: int in count:
		out.append({"men": MEN, "morale": 1000})
	return out
