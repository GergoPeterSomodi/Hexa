@warning_ignore_start("integer_division")
## Inputs for the battle tests (docs/architecture/m7-build-spec.md 4.6, 5.3): a fresh copy of the committed war, companies of the
## kinds of 4.6 (pikemen, crossbowmen, knights, bombards), plain battle inputs for Combat.fight, and a stub luck stream whose
## spread draw is always 1,000 (the middle), for the worked hit. Every war a test changes comes from war() (a copy).
class_name CombatFixture
extends RefCounted

const WAR_PATH := "res://data/defs/war.tres"


## A fresh copy of the committed war: a test may change any field of it.
static func war() -> WarDef:
	var loaded := ResourceLoader.load(WAR_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as WarDef
	return EconomyFixture.war_copy(loaded)


## One company as the plain form of a fighter (the keys of CombatInput.FIGHTER_KEYS).
static func company(key: int, side: int, branch: String, men: int, attack: int, defence: int, fire: int = 0,
		rank: int = 0, morale: int = 1000, hungry: bool = false, full: int = -1) -> Dictionary:
	return {
		"key": key, "side": side, "branch": branch, "men": men, "full": men if full < 0 else full,
		"attack": attack, "defence": defence, "fire": fire, "rank": rank, "morale": morale, "hungry": hungry,
	}


static func pikemen(key: int, side: int, men: int = 500, morale: int = 1000) -> Dictionary:
	return company(key, side, "infantry", men, 4, 5, 0, 0, morale)


static func crossbowmen(key: int, side: int, men: int = 500) -> Dictionary:
	return company(key, side, "missile", men, 5, 2, 25)


static func knights(key: int, side: int, men: int = 250) -> Dictionary:
	return company(key, side, "cavalry", men, 6, 3)


static func bombards(key: int, side: int, men: int = 100) -> Dictionary:
	return company(key, side, "artillery", men, 6, 1, 50)


## A battle input on the given ground (open farmland by default), with the stances and retreats, and no garrison.
static func input_of(war: WarDef, fighters: Array, cover_defence: int = 0, rough: bool = false, narrow: bool = false,
		relief: int = 0, odds_key: String = "open") -> Dictionary:
	return {
		"attacker": "SAV", "defender": "MLO", "assault": false,
		"ground": Combat.make_ground(war, cover_defence, rough, narrow, relief, odds_key),
		"crossing": false, "uphill": false, "river": false,
		"stance": {"att": "attack", "def": "hold"},
		"can_retreat": {"att": false, "def": false},
		"fighters": fighters, "garrison": {},
	}


## An assault on a fortress of the given level: the garrison holds the defender's centre (4.6), on walls (ground open).
static func assault_input(war: WarDef, fighters: Array, men: int, level: int) -> Dictionary:
	var input := input_of(war, fighters)
	input["assault"] = true
	input["garrison"] = {"men": men, "full": men, "level": level, "morale": 1000}
	return input


## A stub luck stream: the spread draw is always the middle, 1,000 permille.
class FlatRng extends Rng:
	func randi_range(low: int, high: int) -> int:
		return (low + high) / 2


## A battle record in memory with the given input and the luck state before its first day (for replay tests).
static func record_of(war: WarDef, input: Dictionary, luck_seed: int) -> BattleRecord:
	var rng := Rng.new()
	rng.seed_with(luck_seed)
	var before: int = rng.get_state()
	var out: Dictionary = Combat.fight(war, input, rng)
	var rec := BattleRecord.new()
	rec.id = 1
	rec.turn = 1
	rec.hex = Vector2i(7, 9)
	rec.name = "Battle of Test, 1480"
	rec.year = 1480
	rec.attacker = &"SAV"
	rec.defender = &"MLO"
	rec.input = input.duplicate(true)
	rec.luck_before = before
	rec.frames.assign(out["frames"])
	rec.end = out["end"]
	return rec
