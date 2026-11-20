## The top bar's resource chips and their hover cards (docs/architecture/m4-build-spec.md 5.6 and 6.3): Ducats and
## Stores, for the player's own country (nothing banded). Each card is {value, change, title, lines, hint} with `lines`
## as [text, tone, amount text] rows for HoverCard (a ["", &"rule"] row is a rule). Pure core/views/ code: read-only,
## no engine calls, no Settings (the treasury-only switch is the shell's choice: the Ducats card carries the treasury's
## measure, which is the chip's).
class_name EconomyCards
extends RefCounted

@warning_ignore_start("integer_division")

const UP := "▲"
const DOWN := "▼"
const DUCATS_HINT := "L: the Economy page"
const STORES_HINT := "The reserve keeps four seasons of the towns' needs; the rest is sold."


## {value (the treasury), change (the last closed season's closing - opening; 0 before the first), title "Ducats",
## lines (every line of the closed ledger with its amount, so they sum to `change`; then a rule and "Expected this
## season"), hint}. {} for an unknown country.
static func ducats(game: Game, tag: StringName) -> Dictionary:
	var c := Countries.by_tag(game, tag) if game != null else null
	if c == null:
		return {}
	var lines: Array = []
	var change := 0
	if c.ledger_closed.is_empty():
		lines.append(["No season has ended yet.", &"muted"])
	else:
		change = int(c.ledger_closed["closing"]) - int(c.ledger_closed["opening"])
		for entry: Dictionary in StudyEconomy.entries(game, c.ledger_closed["lines"] as Array):
			lines.append([entry["label"], _tone(int(entry["amount"])), _arrow(int(entry["amount"]))])
	lines.append(["", &"rule"])
	var net := int(EconomyPreview.expected(game, tag).get("net", 0))
	lines.append(["Expected this season", _tone(net), _arrow(net)])
	return {"value": c.treasury, "change": change, "title": "Ducats", "lines": lines, "hint": DUCATS_HINT}


## {value (the stock's worth at price), change (the worth's change over the last closed season; 0 before the first),
## title "Stores", lines ([good name, tone, "stock (▲ +n)"] for each good in store or changed in the last season, in good
## order), hint}. {} for an unknown country or a game without goods.
static func stores(game: Game, tag: StringName) -> Dictionary:
	var c := Countries.by_tag(game, tag) if game != null else null
	if c == null or game.defs == null or game.defs.goods.is_empty() or c.stock.size() != game.defs.goods.size():
		return {}
	var closed := c.goods_closed
	var lines: Array = []
	var change := 0
	if not closed.is_empty():
		change = worth(game, closed["closing"] as PackedInt32Array) - worth(game, closed["opening"] as PackedInt32Array)
	for g: int in c.stock.size():
		var delta := 0
		if not closed.is_empty():
			delta = int((closed["closing"] as PackedInt32Array)[g]) - int((closed["opening"] as PackedInt32Array)[g])
		if c.stock[g] == 0 and delta == 0:
			continue
		var text := Words.number(c.stock[g])
		if delta != 0:
			text += " (%s)" % _arrow(delta)
		lines.append([game.defs.good(g).name, _tone(delta) if delta != 0 else &"plain", text])
	if lines.is_empty():
		lines.append(["The stores are empty.", &"muted"])
	return {"value": worth(game, c.stock), "change": change, "title": "Stores", "lines": lines, "hint": STORES_HINT}


## The worth of `stock` (loads by good id) at the goods' prices, in whole ducats (thousandths cut off at the end).
static func worth(game: Game, stock: PackedInt32Array) -> int:
	var milli := 0
	for g: int in mini(stock.size(), game.defs.goods.size()):
		milli += stock[g] * game.defs.good(g).price_milli
	return milli / 1000


static func _tone(n: int) -> StringName:
	return &"good" if n > 0 else (&"bad" if n < 0 else &"plain")


## "▲ +65", "▼ −12", "0".
static func _arrow(n: int) -> String:
	if n == 0:
		return "0"
	return "%s %s" % [UP if n > 0 else DOWN, Words.signed(n)]
