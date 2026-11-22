## A war between two countries (docs/architecture/m7-build-spec.md 5.2, 4.2, 4.9). Pure state: written only by Wars (B5)
## and read back by from_dict. A war with end_turn 0 is live; an ended one keeps its terms and its counts. The truce is
## derived from the newest ended war between two countries (Wars.truce_until), so it has no field of its own.
class_name War
extends RefCounted

const SCHEMA := "hexa-godot/war/1"
## The terms an ended war carries (4.9): take, white peace, the surrender term, or the timer (40 seasons).
const ENDED_TERMS: Array[StringName] = [&"take", &"white", &"yield", &"timer"]

var id: int = 0
## Who declared the war.
var a: StringName = &""
var b: StringName = &""
var start_turn: int = 0
## 0 while the war lasts.
var end_turn: int = 0
## &"" while live; one of ENDED_TERMS once ended.
var terms: StringName = &""
## Battles won by a and by b.
var won_a: int = 0
var won_b: int = 0
## Men a and b lost in battle (killed, wounded not returned, flight, surrender).
var lost_a: int = 0
var lost_b: int = 0
## Districts that changed owner at the peace.
var moved: int = 0


func live() -> bool:
	return end_turn == 0


## The other party of the war, or &"" when tag is not in it.
func other(tag: StringName) -> StringName:
	if tag == a:
		return b
	if tag == b:
		return a
	return &""


## The live war between a and b, in either order, or null. The one loop that Wars.at_war, Wars.war_between and
## Occupation.besieged share; an ended war is never returned.
static func live_between(wars: Array[War], a_tag: StringName, b_tag: StringName) -> War:
	for w: War in wars:
		if w.live() and ((w.a == a_tag and w.b == b_tag) or (w.a == b_tag and w.b == a_tag)):
			return w
	return null


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA, "id": id, "a": String(a), "b": String(b), "start_turn": start_turn, "end_turn": end_turn,
		"terms": String(terms), "won_a": won_a, "won_b": won_b, "lost_a": lost_a, "lost_b": lost_b, "moved": moved,
	}


## Null on a wrong schema, a missing or mistyped field, a negative count, a war with a party against itself, an ended
## war without a term (or a live one with one), or an end before its start. JSON numbers (floats) are read as whole ints.
static func from_dict(d: Dictionary) -> War:
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var w := War.new()
	var nums := {}
	for key: String in ["id", "start_turn", "end_turn", "won_a", "won_b", "lost_a", "lost_b", "moved"]:
		var value: Variant = Unit.int32(d.get(key, null))
		if value == null or int(value) < 0:
			return null
		nums[key] = int(value)
	var texts := {}
	for key: String in ["a", "b", "terms"]:
		var value: Variant = d.get(key, null)
		if not (value is String or value is StringName):
			return null
		texts[key] = str(value)
	if nums["id"] < 1 or nums["start_turn"] < 1 or texts["a"] == texts["b"]:
		return null
	if not Unit.tag_ok(texts["a"]) or not Unit.tag_ok(texts["b"]):
		return null
	var terms_name := StringName(texts["terms"])
	if nums["end_turn"] == 0:
		if terms_name != &"":
			return null
	elif not ENDED_TERMS.has(terms_name) or nums["end_turn"] < nums["start_turn"]:
		return null
	w.id = nums["id"]
	w.a = StringName(texts["a"])
	w.b = StringName(texts["b"])
	w.start_turn = nums["start_turn"]
	w.end_turn = nums["end_turn"]
	w.terms = terms_name
	w.won_a = nums["won_a"]
	w.won_b = nums["won_b"]
	w.lost_a = nums["lost_a"]
	w.lost_b = nums["lost_b"]
	w.moved = nums["moved"]
	return w


## "id|a|b|start|end|terms|won_a|won_b|lost_a|lost_b|moved".
func digest_text() -> String:
	return "%d|%s|%s|%d|%d|%s|%d|%d|%d|%d|%d" % [id, String(a), String(b), start_turn, end_turn, String(terms), won_a,
		won_b, lost_a, lost_b, moved]
