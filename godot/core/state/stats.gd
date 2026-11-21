## The numbers of a game over time (docs/architecture/m3-build-spec.md 4.6, 5.2): a ring of the last RING seasons for
## every country, and one row a year for the whole game. The chronicle is not here (it is its own class). Written only
## by StatsSystem.
class_name Stats
extends RefCounted

const SCHEMA := "hexa-godot/stats/1"
## Seasons kept in the ring.
const RING := 40
## The columns, append-only: a column is found by name, and a save written with fewer loads the rest as zeros.
const SERIES: Array[String] = [
	"treasury", "income_people", "income_goods", "income_dues", "income_trade", "upkeep_districts", "upkeep_walls",
	"upkeep_army", "spending", "people", "food_made", "food_eaten", "land", "army_men", "losses", "war_score",
	"prestige", "score", "research", "works_running", "works_finished",
	"districts_settlements", "districts_castles", "districts_wheat", "districts_hemp", "districts_silk",
	"districts_dyes", "districts_vineyard", "districts_olives", "districts_grazing", "districts_timber",
	"districts_mines", "districts_quarry", "districts_salt", "districts_harbour",
	"people_towns", "people_grew", "people_starved", "people_left", "food_need",
	"army_raised", "army_starved",
]
## The first of the districts_<family> columns; the column of family f (1 to 14) is DISTRICTS_FIRST + f - 1.
const DISTRICTS_FIRST := 21
## The parts of a goods ring row (goods_value and goods_series): [(c * RING + turn % RING) * G + g) * 3 + part].
const MADE := 0
const USED := 1
const STOCK := 2

## Country tags in id order; [""] in a map-only game.
var tags: PackedStringArray = PackedStringArray()
## Rows written (seasons recorded).
var count: int = 0
## The newest row's turn; 0 when none.
var last_turn: int = 0
## [(c * RING + turn % RING) * S + s].
var ring: PackedInt32Array = PackedInt32Array()
## [(y * C + c) * S + s], y = year - start_year; one block each Winter.
var years: PackedInt32Array = PackedInt32Array()
## Goods tracked; 0 until M4.
var goods: int = 0
## [((c * RING + turn % RING) * G + g) * 3 + (made, used, stock)].
var goods_ring: PackedInt32Array = PackedInt32Array()


static func create(p_tags: PackedStringArray, p_goods: int) -> Stats:
	var out := Stats.new()
	out.tags = p_tags.duplicate()
	out.goods = maxi(p_goods, 0)
	out.ring.resize(p_tags.size() * RING * SERIES.size())
	out.ring.fill(0)
	out.goods_ring.resize(p_tags.size() * RING * out.goods * 3)
	out.goods_ring.fill(0)
	return out


## The column of a series, or -1.
static func column(p_name: String) -> int:
	return SERIES.find(p_name)


func index_of(tag: StringName) -> int:
	return tags.find(String(tag))


## Writes one country's row for `turn` at its ring slot. A short row leaves the rest zero; a long one is cut.
func set_row(c: int, turn: int, values: PackedInt32Array) -> void:
	if c < 0 or c >= tags.size():
		return
	var s := SERIES.size()
	var base := (c * RING + posmod(turn, RING)) * s
	for i: int in s:
		ring[base + i] = values[i] if i < values.size() else 0


## Marks the row of `turn` complete (every country written).
func commit(turn: int) -> void:
	count += 1
	last_turn = turn


## Appends the newest row of every country as one year block (the Winter's).
func append_year() -> void:
	var s := SERIES.size()
	for c: int in tags.size():
		var base := (c * RING + posmod(last_turn, RING)) * s
		years.append_array(ring.slice(base, base + s))


## True when the ring still holds a row for `turn`.
func has_row(turn: int) -> bool:
	return count > 0 and turn >= 1 and turn <= last_turn and turn > last_turn - RING and turn > last_turn - count


## The row of a country at a turn; empty when not written or out of the ring.
func row(tag: StringName, turn: int) -> PackedInt32Array:
	var c := index_of(tag)
	if c < 0 or not has_row(turn):
		return PackedInt32Array()
	var base := (c * RING + posmod(turn, RING)) * SERIES.size()
	return ring.slice(base, base + SERIES.size())


## One value; 0 when absent (unknown tag, name or turn).
func value(tag: StringName, turn: int, p_name: String) -> int:
	var col := column(p_name)
	var r := row(tag, turn)
	if col < 0 or r.is_empty():
		return 0
	return r[col]


## The last `span` (at most RING) values of a column, newest last; fewer when fewer rows are written.
func series(tag: StringName, p_name: String, span: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var col := column(p_name)
	var c := index_of(tag)
	if col < 0 or c < 0 or count == 0:
		return out
	var n := mini(mini(span, RING), count)
	var s := SERIES.size()
	for t: int in range(last_turn - n + 1, last_turn + 1):
		out.append(ring[(c * RING + posmod(t, RING)) * s + col])
	return out


## One part (MADE, USED or STOCK) of one good of a country's goods ring row at `turn`; 0 when the row is not written or
## out of the ring, or the tag, the good or the part is unknown. Read-only.
func goods_value(tag: StringName, turn: int, good: int, part: int) -> int:
	var c := index_of(tag)
	if c < 0 or good < 0 or good >= goods or part < MADE or part > STOCK or not has_row(turn):
		return 0
	return goods_ring[(((c * RING + posmod(turn, RING)) * goods) + good) * 3 + part]


## The last `span` (at most RING) values of one part of one good, newest last; fewer when fewer rows are written, empty
## for an unknown tag, good or part. Read-only.
func goods_series(tag: StringName, good: int, part: int, span: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c := index_of(tag)
	if c < 0 or good < 0 or good >= goods or part < MADE or part > STOCK or count == 0:
		return out
	var n := mini(mini(span, RING), count)
	for t: int in range(last_turn - n + 1, last_turn + 1):
		out.append(goods_ring[(((c * RING + posmod(t, RING)) * goods) + good) * 3 + part])
	return out


## The Winter row of year `year_index` (year - start_year); empty when none.
func year_row(tag: StringName, year_index: int) -> PackedInt32Array:
	var c := index_of(tag)
	var s := SERIES.size()
	if c < 0 or year_index < 0:
		return PackedInt32Array()
	var base := (year_index * tags.size() + c) * s
	if base + s > years.size():
		return PackedInt32Array()
	return years.slice(base, base + s)


## The year blocks held.
func year_count() -> int:
	return floori(float(years.size()) / float(maxi(tags.size() * SERIES.size(), 1)))


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA, "series": PackedStringArray(SERIES), "tags": tags.duplicate(), "count": count,
		"last_turn": last_turn, "ring": ring.duplicate(), "years": years.duplicate(), "goods": goods,
		"goods_ring": goods_ring.duplicate(),
	}


## Null on a wrong schema or a mistyped or wrongly sized field. A series missing in `d` loads as zeros, an unknown
## one is dropped.
static func from_dict(d: Dictionary) -> Stats:
	if str(d.get("schema", "")) != SCHEMA:
		return null
	var raw_series: Variant = d.get("series")
	var raw_tags: Variant = d.get("tags")
	if not (raw_series is PackedStringArray or raw_series is Array):
		return null
	if not (raw_tags is PackedStringArray or raw_tags is Array):
		return null
	var saved_series: Array[String] = []
	for item: Variant in raw_series:
		if not (item is String or item is StringName):
			return null
		saved_series.append(String(item))
	var p_tags := PackedStringArray()
	for item: Variant in raw_tags:
		if not (item is String or item is StringName):
			return null
		p_tags.append(String(item))
	for key: String in ["count", "last_turn", "goods"]:
		if not (d.get(key) is int):
			return null
	for key: String in ["ring", "years", "goods_ring"]:
		if not (d.get(key) is PackedInt32Array):
			return null
	var p_goods := int(d["goods"])
	var c_n := p_tags.size()
	var old_s := saved_series.size()
	var src_ring: PackedInt32Array = d["ring"]
	var src_years: PackedInt32Array = d["years"]
	var src_goods: PackedInt32Array = d["goods_ring"]
	if p_goods < 0 or c_n == 0 or old_s == 0 or int(d["count"]) < 0 or int(d["last_turn"]) < 0:
		return null
	if src_ring.size() != c_n * RING * old_s or src_goods.size() != c_n * RING * p_goods * 3:
		return null
	if src_years.size() % (c_n * old_s) != 0:
		return null
	var out := create(p_tags, p_goods)
	out.count = int(d["count"])
	out.last_turn = int(d["last_turn"])
	out.goods_ring = src_goods.duplicate()
	var s := SERIES.size()
	var map_cols: Array[int] = []  # new column -> saved column, -1 when the save lacks it
	for series_name: String in SERIES:
		map_cols.append(saved_series.find(series_name))
	for slot: int in c_n * RING:
		for i: int in s:
			if map_cols[i] >= 0:
				out.ring[slot * s + i] = src_ring[slot * old_s + map_cols[i]]
	var blocks := floori(float(src_years.size()) / float(c_n * old_s))
	out.years.resize(blocks * c_n * s)
	out.years.fill(0)
	for slot: int in blocks * c_n:
		for i: int in s:
			if map_cols[i] >= 0:
				out.years[slot * s + i] = src_years[slot * old_s + map_cols[i]]
	return out


## SHA-256 (hex text) of everything the stats hold.
func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes([tags, PackedStringArray(SERIES), count, last_turn, ring, years, goods, goods_ring]))
	return ctx.finish().hex_encode()
