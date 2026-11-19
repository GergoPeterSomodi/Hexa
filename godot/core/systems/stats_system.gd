## The stats phase (docs/architecture/m3-build-spec.md 4.6, 5.3): the row of the season that is ending, for every
## country in id order (the pseudo-country "" in a map-only game), into the ring, and in Winter into the year rows.
class_name StatsSystem
extends RefCounted

const OWNS: Array[String] = ["stats"]


## Stats.create(the countries' tags, or [""] in a map-only game, 0 goods); at game start.
static func setup(game: Game) -> void:
	game.stats = Stats.create(_tags_of(game), 0)


## The stats phase (4.6): writes the row of `game.turn` for every country; in Winter also the year block.
static func season(game: Game) -> void:
	if game.stats == null:
		setup(game)
	var stats := game.stats
	var rows := _rows(game, stats)
	for c: int in rows.size():
		stats.set_row(c, game.turn, rows[c])
	stats.commit(game.turn)
	if Calendar.is_winter(game.turn):
		stats.append_year()


## The values as the phase would write them for one country now; empty for an unknown tag.
static func row_now(game: Game, tag: StringName) -> PackedInt32Array:
	var tags := _tags_of(game)
	var c := tags.find(String(tag))
	if c < 0:
		return PackedInt32Array()
	return _rows(game, Stats.create(tags, 0))[c]


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
	return rows
