## The goods door (docs/architecture/m4-build-spec.md 4.8, 4.12 and 5.3): every change of a country's stock is a
## Stores.move with a flow, and the season's flows are closed into goods_closed. The only writer of Country.stock,
## flows_open, stock_from and goods_closed.
class_name Stores
extends RefCounted

const OWNS: Array[String] = ["stock", "flows_open", "stock_from", "goods_closed"]
## The reasons a stock changes; append-only. The index is the flow in Country.flows_open.
const FLOWS: Array[StringName] = [&"made", &"used", &"sold", &"work", &"refund", &"dev"]
## The settlements family id (FamilyIds); its hexes hold the town people.
const SETTLEMENTS := 1
## A stock or a flow cell stays within this many loads either way (a dev_goods of 3,000,000,000 is refused).
const LIMIT := 2000000000


## Game start (4.12): every country's stock at its reserve, flows zero, stock_from the stock. A game without the
## economy's goods (a defs file without them) leaves the stores empty.
static func setup(game: Game) -> void:
	if game == null:
		return
	for c: Country in game.countries:
		c.stock = reserve_at_start(game, c.tag)
		c.flows_open = PackedInt32Array()
		c.flows_open.resize(c.stock.size() * FLOWS.size())
		c.stock_from = c.stock.duplicate()
		c.goods_closed = {}


## THE ONLY WRITER OF A STOCK. False (and nothing changes) for an unknown tag or good, a why not in FLOWS, or a stock that
## would fall below 0 or past LIMIT (the flow cell too); else stock[good] += amount and the flow of the season gains amount.
static func move(game: Game, tag: StringName, good: int, amount: int, why: StringName) -> bool:
	var c := Countries.by_tag(game, tag)
	var flow_id := FLOWS.find(why)
	if c == null or flow_id < 0 or good < 0 or good >= c.stock.size():
		return false
	var slot := flow_id * c.stock.size() + good
	if slot >= c.flows_open.size() or c.stock[good] + amount < 0 or c.stock[good] + amount > LIMIT:
		return false
	if absi(c.flows_open[slot] + amount) > LIMIT:
		return false
	c.stock[good] += amount
	c.flows_open[slot] += amount
	return true


## The stats phase: every country's season is closed into goods_closed {turn, opening, closing, flows}; the flows
## start again from zero and stock_from is the stock now.
static func close(game: Game) -> void:
	if game == null:
		return
	for c: Country in game.countries:
		c.goods_closed = {
			"turn": game.turn, "opening": c.stock_from.duplicate(), "closing": c.stock.duplicate(),
			"flows": c.flows_open.duplicate(),
		}
		c.flows_open.fill(0)
		c.stock_from = c.stock.duplicate()


## "" when the stores hold `goods` ({good key: loads}), else "not enough stone: 40 needed, 12 in store" for the first
## short good in good id order. An unknown tag holds nothing.
static func short_of(game: Game, tag: StringName, goods: Dictionary) -> String:
	var c := Countries.by_tag(game, tag)
	for i: int in _good_count(game):
		var g := game.defs.good(i)
		var need := _loads_in(goods, g.key)
		var have := c.stock[i] if c != null and i < c.stock.size() else 0
		if need > have:
			return "not enough %s: %d needed, %d in store" % [g.name.to_lower(), need, have]
	return ""


## The flow `why` of the good in the open season, or in the last closed one; 0 for an unknown flow or good.
static func flow(country: Country, good: int, why: StringName, closed: bool = false) -> int:
	var flow_id := FLOWS.find(why)
	if country == null or flow_id < 0 or good < 0:
		return 0
	var flows := country.flows_open
	if closed:
		if country.goods_closed.is_empty():
			return 0
		flows = country.goods_closed["flows"]
	var slot := flow_id * country.stock.size() + good
	return flows[slot] if slot < flows.size() else 0


## The town and the countryside people of a country at the start of a game (4.3), from EconomySeason (one source):
## x is the town, y the countryside. Zero for an unknown tag or a game without defs.
static func start_people(game: Game, tag: StringName) -> Vector2i:
	if Countries.by_tag(game, tag) == null or game.defs == null or game.state == null:
		return Vector2i.ZERO
	var view := StateView.of(game.state)
	return Vector2i(EconomySeason.town_people(game, view, tag), EconomySeason.country_people(game, view, tag))


## The loads a season of one need: ceil(town people x need_milli / 1,000,000); 0 town people need nothing.
static func need_of(town_people: int, need_milli: int) -> int:
	return EconomySeason.need_loads(town_people, need_milli)


## The reserve per good id at the start of a game (4.2): EconomySeason.reserve_of. Empty for an unknown tag or a game
## without goods.
static func reserve_at_start(game: Game, tag: StringName) -> PackedInt32Array:
	if Countries.by_tag(game, tag) == null or game.defs == null or game.defs.goods.is_empty() or game.state == null:
		return PackedInt32Array()
	return EconomySeason.reserve_of(game, StateView.of(game.state), tag)


static func _good_count(game: Game) -> int:
	return game.defs.goods.size() if game != null and game.defs != null else 0


## The loads a cost names for a good key (the dictionary may key by String or StringName).
static func _loads_in(goods: Dictionary, key: StringName) -> int:
	if goods.has(String(key)):
		return int(goods[String(key)])
	return int(goods.get(key, 0))
