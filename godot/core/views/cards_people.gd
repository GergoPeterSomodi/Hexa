## The top bar's People and Food chips and their hover cards (docs/architecture/m5-build-spec.md 5.6 and 6.3), for the
## player's own country (nothing banded). Each card is {value, change, title, lines, hint} with `lines` as [text, tone,
## amount text] rows for HoverCard (a ["", &"rule", ""] row is a rule). The People card's lines sum to its change: the
## flows the last season closed (grew, starved, left, and "Other" for anything else, a console edit or a transfer) add up
## to people_end - people_start. Pure core/views/ code: read-only, no engine calls.
class_name PeopleCards
extends RefCounted

const UP := "▲"
const DOWN := "▼"
const HINT := "Click: the People page"


## {} for an unknown country, a country that is not the player's, or a game without people.
static func people(game: Game, tag: StringName) -> Dictionary:
	var c := Countries.by_tag(game, tag) if game != null else null
	if c == null or _foreign(game, tag):
		return {}
	var sums := PeopleView.totals(game, tag)
	if sums.is_empty():
		return {}
	var lines: Array = [
		["Towns", &"plain", Words.number(int(sums["towns"]))],
		["Countryside", &"plain", Words.number(int(sums["countryside"]))],
		["", &"rule", ""],
	]
	var change := int(sums["change"])
	if c.people_closed.is_empty():
		lines.append(["No season has ended yet.", &"muted", ""])
	else:
		var flows: PackedInt32Array = c.people_closed["flows"]
		var grew := _flow(flows, People.GREW)
		var starved := _flow(flows, People.STARVED)
		var left := _flow(flows, People.LEFT)
		lines.append(["Grew", _tone(grew), _arrow(grew)])
		if starved != 0:
			lines.append(["Starved", &"bad", _arrow(starved)])
		if left != 0:
			lines.append(["Left", &"bad", _arrow(left)])
		var other := change - grew - starved - left
		if other != 0:
			lines.append(["Other", _tone(other), _arrow(other)])
	lines.append(["Room for %s more" % Words.number(int(sums["room_left"])), &"plain", ""])
	return {"value": int(sums["people"]), "change": change, "title": "People", "lines": lines, "hint": HINT}


## {value (grain + fish in store), change (their change over the last closed season), title "Food", tone (bad when the towns
## went hungry), lines, hint}. {} as for `people`, and for a game without goods.
static func food(game: Game, tag: StringName) -> Dictionary:
	var c := Countries.by_tag(game, tag) if game != null else null
	if c == null or _foreign(game, tag) or game.defs == null or game.defs.goods.is_empty() \
			or c.stock.size() != game.defs.goods.size():
		return {}
	var goods: Array[int] = [game.defs.good_id(&"grain"), game.defs.good_id(&"fish")]
	var stock := 0
	var change := 0
	var made := 0
	var eaten := 0
	var sold := 0
	for g: int in goods:
		if g < 0:
			continue
		stock += c.stock[g]
		if not c.goods_closed.is_empty():
			change += int((c.goods_closed["closing"] as PackedInt32Array)[g]) - int((c.goods_closed["opening"] as PackedInt32Array)[g])
			made += maxi(Stores.flow(c, g, &"made", true), 0)
			eaten += absi(Stores.flow(c, g, &"used", true))
			sold += absi(Stores.flow(c, g, &"sold", true))
	var lines: Array = []
	if c.goods_closed.is_empty():
		lines.append(["No season has ended yet.", &"muted", ""])
	else:
		lines.append(["Made %d · Eaten %d · Sold %d" % [made, eaten, sold], &"plain", ""])
	var need := People.food_need_of(game, StateView.of(game.state), tag)
	lines.append(["Your towns need %d a season" % need, &"plain", ""])
	var lasts := str((StudyEconomy.lasts(game, tag).get(goods[0], {}) as Dictionary).get("text", "—"))
	if lasts == "over %d seasons" % Reminders.WINDOW:
		lines.append(["Lasts %s" % lasts, &"plain", ""])
	elif lasts == "none left":
		lines.append(["None left in store", &"bad", ""])
	elif lasts != "—":
		lines.append(["Runs short %s" % lasts, &"warn", ""])
	return {"value": stock, "change": change, "title": "Food", "tone": &"bad" if c.food_fed < 1000 else &"plain",
		"lines": lines, "hint": HINT}


static func _foreign(game: Game, tag: StringName) -> bool:
	return game.has_countries() and game.player != &"" and tag != game.player


static func _flow(flows: PackedInt32Array, at: int) -> int:
	return flows[at] if at < flows.size() else 0


static func _tone(n: int) -> StringName:
	return &"good" if n > 0 else (&"bad" if n < 0 else &"plain")


static func _arrow(n: int) -> String:
	if n == 0:
		return "0"
	return "%s %s" % [UP if n > 0 else DOWN, Words.signed(n)]
