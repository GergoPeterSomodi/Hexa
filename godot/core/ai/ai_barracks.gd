## The AI's barracks step (docs/design/recruitment-queue.md section 7; task RQ4). It stands before the works steps, so a
## barracks gets the first claim on a free work slot and on the money. The seat wants one barracks for every
## `companies_per_barracks` companies of its war goal of men (in peace too), rounded up, at least 1. It counts its usable
## barracks and those under way. With none it builds as soon as it can pay, its reserve waived; with fewer than wanted it
## builds one at a time and keeps its reserve. The place is a settlement the barracks' check allows (a town or larger):
## off the front, nearest the front first; on the front only when no other will do, farthest from the enemy first. The step
## reads only AiKnow and AiBrief (never another step module) and acts only through AiKnow.act.
@warning_ignore_start("integer_division")
class_name AiBarracks
extends RefCounted


static func barracks(turn: AiTurn, game: Game, brief: AiBrief, _arg: int) -> void:
	var tag := brief.tag
	var want := wanted(game, brief)
	var usable := AiKnow.usable_barracks(game, tag).size()
	var under_way := AiKnow.barracks_under_way(game, tag)
	var have := usable + under_way
	var head := "barracks: wanted %d, usable %d, under way %d" % [want, usable, under_way]
	if have >= want:
		turn.note(tag, head + ": enough")
		return
	if have > 0 and under_way > 0:
		turn.note(tag, head + ": one at a time")
		return
	if AiKnow.slots_free(game, tag) <= 0:
		turn.note(tag, head + ": no free work slot")
		return
	for hex: Vector2i in place_order(game, brief):
		var card := AiKnow.barracks_card(game, tag, hex)
		var verdict: Dictionary = card["verdict"]
		if not bool(verdict.get("ok", false)):
			# The money is the last of the check's rows and the same at every place: no other place can do better.
			if card["blocked_by"] == &"ducats" or card["blocked_by"] == &"goods":
				turn.note(tag, "%s: cannot pay (%s)" % [head, verdict.get("reason", "")])
				return
			continue
		var cost := int(card["ducats"])
		var treasury := AiKnow.treasury(game, tag)
		if have > 0 and treasury - cost < brief.reserve:
			turn.note(tag, "%s: T %d - cost %d under the reserve R %d" % [head, treasury, cost, brief.reserve])
			return
		turn.note(tag, "%s: builds at (%d, %d), cost %d, T %d, R %d%s" % [head, hex.x, hex.y, cost, treasury, brief.reserve,
			" (waived: it has none)" if have == 0 else ""])
		AiKnow.act(turn, game, tag, "build_barracks", {"hex": hex})
		return
	turn.note(tag, head + ": no place for one")


## The barracks the seat wants: its war goal of men over the men of `companies_per_barracks` companies, rounded up; at
## least 1. The war goal is the brief's goal of men at the temperament's war share, whether or not there is a war.
static func wanted(game: Game, brief: AiBrief) -> int:
	var share := brief.temper.war_army_permille if brief.temper != null else 0
	var goal := maxi(brief.ai.min_army_men, brief.people * share / 1000)
	var served := maxi(1, brief.ai.companies_per_barracks * AiKnow.company_men(game))
	return maxi(1, (goal + served - 1) / served)


## The seat's settlements in the order a barracks is tried: first those off the front, nearest the front first (the capital
## when there is no front); then those on the front, farthest from the enemy first; ties: lower hex index. The enemy is
## the settlements of the threats that the seat has discovered and the enemy armies it sees.
static func place_order(game: Game, brief: AiBrief) -> Array[Vector2i]:
	var front: Array[Vector2i] = []
	var on_front := {}
	for i: int in brief.front:
		front.append(AiKnow.hex_of(game, i))
		on_front[i] = true
	if front.is_empty():
		var home := AiKnow.capital_of(game, brief.tag)
		if home != Army.NO_HEX:
			front.append(home)
	var enemy: Array[Vector2i] = []
	if not on_front.is_empty():
		for threat: StringName in brief.threats:
			enemy.append_array(AiKnow.known_settlements(game, brief.tag, threat))
		for seen: Dictionary in brief.seen:
			enemy.append(seen["hex"] as Vector2i)
	var rows: Array[Dictionary] = []
	for hex: Vector2i in AiKnow.settlements(game, brief.tag):
		var index := AiKnow.index_of(game, hex)
		var behind := not on_front.has(index)
		# One key, ascending: the distance to the front behind it; on it, the distance to the enemy turned round.
		var key := _nearest(hex, front) if behind else -_nearest(hex, enemy)
		rows.append({"hex": hex, "behind": behind, "key": key, "index": index})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["behind"] != b["behind"]:
			return bool(a["behind"])
		if a["key"] != b["key"]:
			return int(a["key"]) < int(b["key"])
		return int(a["index"]) < int(b["index"]))
	var out: Array[Vector2i] = []
	for row: Dictionary in rows:
		out.append(row["hex"])
	return out


## The least hex distance from `from` to a hex of `places`; 0 with none.
static func _nearest(from: Vector2i, places: Array[Vector2i]) -> int:
	var best := -1
	for hex: Vector2i in places:
		var d := AiKnow.hex_distance(from, hex)
		if best < 0 or d < best:
			best = d
	return maxi(best, 0)
