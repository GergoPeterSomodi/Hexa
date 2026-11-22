@warning_ignore_start("integer_division")
## The whole battle as a pure function (docs/architecture/m7-build-spec.md 4.6 and 5.3): fight(input, luck) gives one frame a
## day and the end, from the battle's input snapshot and the world's luck stream (the only draws: the dice and the hits).
## replay(war, record) fights a saved battle again from its input and luck_before, so a view or a test can check the frames.
## Battles
## (B8) builds the input and applies the end; this file never reads Game or an autoload. Pure.
class_name Combat
extends RefCounted

const OWNS: Array[String] = []
const LANES := CombatState.LANE_COUNT
const CENTRE := CombatState.CENTRE
const FILL_ORDER: PackedInt32Array = CombatState.FILL_ORDER
const GARRISON := CombatState.GARRISON
const EMPTY := CombatState.EMPTY
## The odds words run over this many permille (4.6).
const ODDS_UNIT := 1000


## Fights the battle described by input (CombatInput) with rng (the world's luck). Returns {frames: one frame a day
## (BattleRecord.FRAME_KEYS), end: the end (BattleRecord.END_KEYS, with retreat, surrendered, returned, stormed and sacked
## left for Battles to fill)}. The input is not changed.
static func fight(war: WarDef, input: Dictionary, rng: Rng) -> Dictionary:
	var st: CombatState = CombatInput.state(war, input, rng)
	var frames: Array = []
	for day: int in range(1, war.battle_days + 1):
		st.day = day
		_day(st)
		frames.append(CombatDay.frame(st))
		if st.over:
			break
	return {"frames": frames, "end": _end(st)}


## Fights a saved battle again from its input and luck_before (the world's luck state before its first day). The stream is
## set on a fresh Rng, so the game's own stream is not touched.
static func replay(war: WarDef, record: BattleRecord) -> Dictionary:
	var rng := Rng.new()
	rng.set_state(record.luck_before)
	return fight(war, record.input, rng)


static func _day(st: CombatState) -> void:
	CombatDay.begin(st)
	CombatDay.deploy(st)
	st.rolls = PackedInt32Array([st.rng.randi_range(1, 6), st.rng.randi_range(1, 6)])
	CombatHit.fire(st)
	CombatHit.backline(st)
	CombatHit.shock(st)
	CombatHit.flanks(st)
	CombatDay.morale(st)
	CombatDay.finish(st)


static func _end(st: CombatState) -> Dictionary:
	var men: Dictionary = {}
	var morale_out: Dictionary = {}
	var wounded: Dictionary = {}
	for f: Dictionary in st.fighters:
		var key: int = int(f["key"])
		men[key] = int(f["men"])
		morale_out[key] = int(f["morale"])
		wounded[key] = int(st.wounded_by_key.get(key, 0))
	var garrison: Dictionary = {}
	if st.has_fighter(GARRISON) and st.assault:
		garrison = {"men": int(st.fighter(GARRISON)["men"]), "morale": int(st.fighter(GARRISON)["morale"])}
	var loser_side: int = 1 - st.winner if st.winner >= 0 else 0
	var lost: Array = st.lost_whole.duplicate()
	lost.sort()
	return {
		"how": st.how, "cause": st.cause, "winner": st.winner, "loser": st.tags[loser_side], "days": st.day,
		"men": men, "morale": morale_out, "wounded": wounded,
		"killed": PackedInt32Array(st.killed_total), "wounded_total": PackedInt32Array(st.wounded_total),
		"lost_whole": PackedInt32Array(lost), "garrison": garrison, "retreat": {},
		"surrendered": PackedInt32Array(), "returned": {}, "stormed": false, "sacked": 0,
	}


## The ground of a hex for the battle (4.6): the cover's defence and its rough and narrow flags, the relief's additions and
## levels, and the odds key. The caller reads the terrain; this only adds the relief's share.
static func make_ground(war: WarDef, cover_defence: int, cover_rough: bool, cover_narrow: bool, relief: int,
		odds_key: String) -> Dictionary:
	var r: int = clampi(relief, 0, WarDef.RELIEF_LEVELS - 1)
	return {
		"defence": cover_defence + war.relief_defence_add[r],
		"relief": r,
		"rough": cover_rough or r >= war.relief_rough_from,
		"narrow": cover_narrow or r >= war.relief_narrow_from,
		"key": odds_key,
		"elevation": war.relief_elevation[r],
	}


## The strength of a company or a side for the odds (4.6): men x morale / 1,000.
static func odds_strength(men: int, morale: int) -> int:
	return men * morale / 1000


## A side's strength for the odds card: its companies by men x morale, and its garrison by its weight: with a field army of
## its side standing with it, garrison_odds_permille, else garrison_odds_alone[level]. Companies are {men, morale}.
static func odds_side(war: WarDef, companies: Array, garrison: Dictionary, with_field: bool) -> int:
	var total: int = 0
	for c: Variant in companies:
		var company: Dictionary = c
		total += odds_strength(int(company["men"]), int(company["morale"]))
	if not garrison.is_empty():
		var level: int = int(garrison["level"])
		var weight: int = war.garrison_odds_permille if with_field else int(war.garrison_odds_alone[clampi(level, 0, 3)])
		total += int(garrison["men"]) * weight / 1000
	return total


## The ratio of two strengths in permille: attack x 1,000 / defence (defence at least 1).
static func odds_ratio(attack: int, defence: int) -> int:
	return attack * ODDS_UNIT / maxi(defence, 1)


## The ground factor of the odds: the hex's key, 1,000 in an assault (the garrison's weight is in its men).
static func odds_factor(war: WarDef, ground_key: String, assault: bool) -> int:
	if assault:
		return ODDS_UNIT
	return int(war.odds_ground[StringName(ground_key)])


## The word of the odds for value (ratio x 1,000 / factor, in permille): the last band whose from is at most value.
static func odds_word(war: WarDef, value: int) -> String:
	var word: String = str(war.odds_words[0]["word"])
	for entry: Variant in war.odds_words:
		var band: Dictionary = entry
		if int(band["from"]) <= value:
			word = str(band["word"])
	return word


## The odds card's numbers for an attack and a defence strength on a ground key: ratio, factor, value and the word.
static func odds_card(war: WarDef, attack: int, defence: int, ground_key: String, assault: bool) -> Dictionary:
	var ratio: int = odds_ratio(attack, defence)
	var factor: int = odds_factor(war, ground_key, assault)
	var value: int = ratio * ODDS_UNIT / maxi(factor, 1)
	return {"ratio": ratio, "factor": factor, "value": value, "word": odds_word(war, value)}
