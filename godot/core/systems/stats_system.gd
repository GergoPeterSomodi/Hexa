## The stats phase (docs/architecture/m3-build-spec.md 4.6, 5.3): the row of the season that is ending, for every
## country in id order (the pseudo-country "" in a map-only game), into the ring, and in Winter into the year rows. From
## M4 (m4-build-spec.md 4.20) it also writes the money and goods series, then closes the season's ledgers and flows.
class_name StatsSystem
extends RefCounted

const OWNS: Array[String] = ["stats"]


## Stats.create(the countries' tags, or [""] in a map-only game; the goods of the defs, none in a map-only game); at game
## start.
static func setup(game: Game) -> void:
	game.stats = Stats.create(_tags_of(game), _goods_of(game))


## The stats phase (4.6): writes the row of `game.turn` for every country; in Winter also the year block.
static func season(game: Game) -> void:
	if game.stats == null:
		setup(game)
	var stats := game.stats
	var rows := _rows(game, stats)
	for c: int in rows.size():
		stats.set_row(c, game.turn, rows[c])
	_write_goods(game, stats)
	stats.commit(game.turn)
	if Calendar.is_winter(game.turn):
		stats.append_year()
	Treasury.close_ledger(game)
	Stores.close(game)


## The values as the phase would write them for one country now; empty for an unknown tag.
static func row_now(game: Game, tag: StringName) -> PackedInt32Array:
	var tags := _tags_of(game)
	var c := tags.find(String(tag))
	if c < 0:
		return PackedInt32Array()
	return _rows(game, Stats.create(tags, 0))[c]


## The goods ring of the season that is ending: made, used and the closing stock of every good, per country.
static func _write_goods(game: Game, stats: Stats) -> void:
	if stats.goods == 0 or not _by_owner(game):
		return
	for c: int in game.countries.size():
		var country := game.countries[c]
		var base := (c * Stats.RING + posmod(game.turn, Stats.RING)) * stats.goods * 3
		for g: int in stats.goods:
			stats.goods_ring[base + g * 3] = maxi(Stores.flow(country, g, &"made"), 0)
			stats.goods_ring[base + g * 3 + 1] = -Stores.flow(country, g, &"used")
			stats.goods_ring[base + g * 3 + 2] = country.stock[g] if g < country.stock.size() else 0


static func _goods_of(game: Game) -> int:
	return game.defs.goods.size() if _by_owner(game) and game.defs != null else 0


static func _by_owner(game: Game) -> bool:
	return game.has_countries() and not game.countries.is_empty()


static func _tags_of(game: Game) -> PackedStringArray:
	var out := PackedStringArray()
	if _by_owner(game):
		for c: Country in game.countries:
			out.append(String(c.tag))
	else:
		out.append("")
	return out


## One row per country (index c = tag position). One pass over the hexes, one over the works, one over this turn's
## chronicle entries.
static func _rows(game: Game, stats: Stats) -> Array[PackedInt32Array]:
	var rows: Array[PackedInt32Array] = []
	for _c: int in stats.tags.size():
		var r := PackedInt32Array()
		r.resize(Stats.SERIES.size())
		r.fill(0)
		rows.append(r)
	var land_col := Stats.column("land")
	var by_owner := _by_owner(game)
	if game.map != null and game.state != null:
		var n := mini(game.map.hex_count(), game.state.owner.size())
		for i: int in n:
			if game.map.land[i] == 0:
				continue
			var c := 0
			if by_owner:
				c = int(game.state.owner[i]) - 1
				if c < 0 or c >= rows.size():
					continue
			rows[c][land_col] += 1
			var family := int(game.state.main_use[i])
			if family >= 1 and family < FamilyIds.COUNT:
				rows[c][Stats.DISTRICTS_FIRST + family - 1] += 1
	var running_col := Stats.column("works_running")
	if game.state != null:
		# Dynamic read: the works list is MapState's from Y5 on; before that there are none.
		var works: Variant = game.state.get("works")
		if works is Array:
			for w: Variant in works as Array:
				var c := stats.tags.find(str(w.tag))
				if c >= 0:
					rows[c][running_col] += 1
	var finished_col := Stats.column("works_finished")
	for entry: Dictionary in game.chronicle.of_turn(game.turn):
		if str(entry.get("kind", "")) == "work_finished":
			var c := stats.tags.find(str(entry.get("tag", "")))
			if c >= 0:
				rows[c][finished_col] += 1
	if by_owner:
		var held := SeasonProfile.table(game) if game.defs != null and game.state != null else {}
		for c: int in mini(game.countries.size(), rows.size()):
			_money_into(game, game.countries[c], rows[c])
			if game.defs != null and game.state != null:
				var live := SeasonProfile.live(game, held, game.countries[c].id)
				rows[c][Stats.column("people")] = int(live["town"]) + int(live["rest"])
	return rows


## The M4 series of one country from its open ledger (what close_ledger is about to close) and its open flows.
static func _money_into(game: Game, country: Country, row: PackedInt32Array) -> void:
	row[Stats.column("treasury")] = country.treasury
	var spent := 0
	for line: Dictionary in country.ledger_open:
		var amount := int(line["amount"])
		match line["why"]:
			&"tax_people":
				row[Stats.column("income_people")] += amount
			&"tax_goods":
				row[Stats.column("income_goods")] += amount
			&"port_dues":
				row[Stats.column("income_dues")] += amount
			&"upkeep_districts":
				row[Stats.column("upkeep_districts")] -= amount
			&"upkeep_walls":
				row[Stats.column("upkeep_walls")] -= amount
			&"work", &"refund":
				spent -= amount
	row[Stats.column("spending")] = spent
	if game.defs == null:
		return
	for key: StringName in [&"grain", &"fish"]:
		var g := game.defs.good_id(key)
		if g >= 0:
			row[Stats.column("food_made")] += maxi(Stores.flow(country, g, &"made"), 0)
			row[Stats.column("food_eaten")] += -Stores.flow(country, g, &"used")
