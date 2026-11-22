@warning_ignore_start("integer_division")
## The working state of one battle while Combat fights it (docs/architecture/m7-build-spec.md 4.6 and 5.3): the fighters, each
## side's three lanes, what has held or broken, the day's dawn and losses, and the end. CombatInput builds it, CombatHit and
## CombatDay work on it, and Combat returns the frames; it is never saved (the record keeps the frames). Fighters are
## dictionaries read and written with brackets, so a morale is never a dotted field. Pure: no engine calls.
class_name CombatState
extends RefCounted

const EMPTY := -2
const GARRISON := -1
const CENTRE := 1
const LANE_COUNT := 3
const FILL_ORDER: PackedInt32Array = [1, 0, 2]
const ATTACKER := 0
const DEFENDER := 1
const NARROW_LANE := 2

var war: WarDef
var rng: Rng
## The two tags, attacker then defender.
var tags: PackedStringArray = PackedStringArray()
var assault := false
var castle_level := 0
## The ground's facts: defence (cover plus relief, permille), rough, narrow, relief, key, elevation.
var ground: Dictionary = {}
var crossing := false
var uphill := false
var river := false
## The effective stance of each side: "attack", "hold" or "withdraw" (a withdraw without a retreat is a hold).
var stance: PackedStringArray = PackedStringArray(["attack", "hold"])
var can_retreat: Array = [false, false]
## Every fighter, the garrison last; each is a dictionary with key, side, branch, men, full, attack, defence, fire, rank,
## morale, hungry.
var fighters: Array[Dictionary] = []
## fighter key -> its position in fighters.
var index: Dictionary = {}
## Per side: an Array of 3 keys (EMPTY, GARRISON or a unit id).
var lanes: Array = []
## Per side: an Array of 3 flags, 1 once a company has stood in that lane.
var held: Array = []
## Per side: the open lanes broken at the last dawn.
var broken: Array = []
## Fighters that routed: they stay on the hex, out of the lanes and the reserve.
var routed: Dictionary = {}
## Companies moved up into a lane today (after day 1): their hits are shaken.
var shaken: Dictionary = {}
var dawn: Dictionary = {}
var lost_today: Dictionary = {}
var day := 0
var rolls: PackedInt32Array = PackedInt32Array([0, 0])
var killed_day: PackedInt32Array = PackedInt32Array([0, 0])
var wounded_day: PackedInt32Array = PackedInt32Array([0, 0])
var killed_total: PackedInt32Array = PackedInt32Array([0, 0])
var wounded_total: PackedInt32Array = PackedInt32Array([0, 0])
var wounded_by_key: Dictionary = {}
var lost_whole: Array = []
var over := false
var how := ""
var cause := ""
## The winning side (0 attacker, 1 defender), -1 when both are wiped out.
var winner := -1
## The side that broke today, -1 for none.
var broke := -1
## 0 for none, else the side that withdrew today plus 1.
var withdrew := 0


func fighter(key: int) -> Dictionary:
	return fighters[int(index[key])]


func has_fighter(key: int) -> bool:
	return index.has(key)


## A fighter with men left.
func live(key: int) -> bool:
	return index.has(key) and int(fighter(key)["men"]) > 0


## A field company that has routed (out of the lanes and the reserve, still on the hex).
func is_routed(key: int) -> bool:
	return routed.has(key)


func side_of(key: int) -> int:
	return int(fighter(key)["side"])


func garrison_fights() -> bool:
	return assault and live(GARRISON) and int(fighter(GARRISON)["morale"]) > 0


func rough() -> bool:
	return bool(ground["rough"])


func lane_open(lane: int) -> bool:
	return not (lane == NARROW_LANE and bool(ground["narrow"]))


func in_lanes(side: int, key: int) -> bool:
	return (lanes[side] as Array).has(key)


## The lane a side holds a key in, or -1.
func lane_of(side: int, key: int) -> int:
	return (lanes[side] as Array).find(key)


## A side's live keys: the garrison too (when present), routed companies too unless field_only excludes them.
func live_keys(side: int, field_only: bool = false) -> Array:
	var out: Array = []
	for f: Dictionary in fighters:
		var key: int = int(f["key"])
		if int(f["side"]) != side or int(f["men"]) <= 0:
			continue
		if field_only and key == GARRISON:
			continue
		out.append(key)
	out.sort()
	return out


## The field companies of a side that are alive, not routed and not in a lane: the reserve, lowest key first.
func reserve(side: int) -> Array:
	var out: Array = []
	for key: Variant in live_keys(side, true):
		var k: int = int(key)
		if not is_routed(k) and not in_lanes(side, k):
			out.append(k)
	return out


## Whether a side still has men on the hex: a live field company (routed too) or a live garrison (men left, whatever its morale).
func has_men(side: int) -> bool:
	return not live_keys(side).is_empty()


## The men-weighted morale (permille) of the companies in a side's lanes; -1 when no man stands in a lane.
func front_morale(side: int) -> int:
	var men_total: int = 0
	var weighted: int = 0
	for lane: int in LANE_COUNT:
		var key: int = int((lanes[side] as Array)[lane])
		if key == EMPTY or not index.has(key):
			continue
		var men: int = int(fighter(key)["men"])
		men_total += men
		weighted += men * int(fighter(key)["morale"])
	if men_total <= 0:
		return -1
	return weighted / men_total
