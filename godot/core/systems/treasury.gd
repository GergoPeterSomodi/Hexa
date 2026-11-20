## The money door (docs/architecture/m4-build-spec.md 4.9, 4.12 and 5.3): every change of a country's treasury is a
## Treasury.move with a reason and, for a district's money, its hex; the season's lines are closed into ledger_closed.
## The only writer of Country.treasury, ledger_open, ledger_from and ledger_closed.
class_name Treasury
extends RefCounted

const OWNS: Array[String] = ["treasury", "ledger_open", "ledger_from", "ledger_closed"]
const NO_HEX := Vector2i(-1, -1)
## The reasons of a money line; append-only (M6 army, M10 trade, M12 interest).
const WHY: Array[StringName] = [
	&"tax_people", &"tax_goods", &"port_dues", &"upkeep_districts", &"upkeep_walls", &"work", &"refund", &"dev",
]
## Lines that are a choice of the player and not the season's income (left_over leaves them out, with dev).
const SPENDING: Array[StringName] = [&"work", &"refund"]
## The treasury and every line stay within this many ducats either way; a move past it is refused.
const LIMIT := 2000000000


## Game start (4.12): every country's start treasury, ledger_from the treasury, the ledgers empty.
static func setup(game: Game) -> void:
	if game == null:
		return
	for c: Country in game.countries:
		c.treasury = start_amount(game, c.tag)
		c.ledger_open = []
		c.ledger_from = c.treasury
		c.ledger_closed = {}


## start_treasury_base + start_treasury_per_1000 x (all its people / 1,000); 0 for an unknown tag or no defs.
static func start_amount(game: Game, tag: StringName) -> int:
	if Countries.by_tag(game, tag) == null or game.defs == null:
		return 0
	var people := Stores.start_people(game, tag)
	return game.defs.start_treasury_base + game.defs.start_treasury_per_1000 * int((people.x + people.y) / 1000.0)


## THE ONLY WRITER OF A TREASURY. False (and nothing changes) for an unknown tag or a why not in WHY. An amount of 0 adds
## no line; a sum past LIMIT is refused too; else treasury += amount and the line (why, hex) gains amount and count (a new line keeps first-added order).
static func move(game: Game, tag: StringName, amount: int, why: StringName, hex: Vector2i = NO_HEX, count: int = 1) -> bool:
	var c := Countries.by_tag(game, tag)
	if c == null or not WHY.has(why):
		return false
	if amount == 0:
		return true
	if absi(amount) > LIMIT or absi(c.treasury + amount) > LIMIT:
		return false
	for line: Dictionary in c.ledger_open:
		if line["why"] == why and line["hex"] == hex:
			if absi(int(line["amount"]) + amount) > LIMIT:
				return false
			c.treasury += amount
			line["amount"] = int(line["amount"]) + amount
			line["count"] = int(line["count"]) + count
			return true
	c.treasury += amount
	c.ledger_open.append({
		"why": why, "hex": hex, "amount": amount, "count": count,
	})
	return true


## The stats phase: every country's lines are closed into ledger_closed {turn, opening, closing, lines}; the lines start
## again empty and ledger_from is the treasury now.
static func close_ledger(game: Game) -> void:
	if game == null:
		return
	for c: Country in game.countries:
		var lines: Array[Dictionary] = []
		for line: Dictionary in c.ledger_open:
			lines.append(line.duplicate())
		c.ledger_closed = {"turn": game.turn, "opening": c.ledger_from, "closing": c.treasury, "lines": lines}
		c.ledger_open = []
		c.ledger_from = c.treasury


## True when the treasury holds `ducats`; false for an unknown tag.
static func can_pay(game: Game, tag: StringName, ducats: int) -> bool:
	var c := Countries.by_tag(game, tag)
	return c != null and c.treasury >= ducats


## The lines' sum without the spending lines (work, refund) and the console's: what the season itself earned.
static func left_over(lines: Array[Dictionary]) -> int:
	var total := 0
	for line: Dictionary in lines:
		var why: StringName = line["why"]
		if not SPENDING.has(why) and why != &"dev":
			total += int(line["amount"])
	return total
