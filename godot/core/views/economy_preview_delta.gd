## The delta method of the preview (economy_preview.gd, 5.0 R5): a change re-runs the district on its hex and the six round
## it and replaces that part of a record (adjust); the land ring round a hex (around), the bases of a view and their
## signatures (base, signature), and the sorted {hex, amount} lists (set_entry, copy_of). Split out of economy_preview.gd
## (B10 step 1); pure core/views/ code.
class_name EconomyPreviewDelta
extends RefCounted

@warning_ignore_start("integer_division")


## The land hexes (sea left out) of `indices` and the six round each, ascending and once each.
static func around(game: Game, indices: Array) -> PackedInt32Array:
	var seen: Dictionary = {}
	for key: Variant in indices:
		var i := int(key)
		seen[i] = true
		for j: int in EconomyPreview.ring(game.map, i):
			if j >= 0:
				seen[j] = true
	var out := PackedInt32Array()
	for i: Variant in seen:
		if game.map.land[int(i)] == 1:
			out.append(int(i))
	out.sort()
	return out


## Replaces the part of each hex in `hexes` (land indices) in `rec`: its goods, dues, upkeep, walls and people go from
## what `from_view` gives to what `to_view` gives. Only the hexes of country `c` count in the country's sums; `touched`
## (when given) receives every hex's before and after for `season`. `from_own`: from_view is the game's own state, so the
## DistrictCache answers it.
static func adjust(game: Game, c: Country, rec: Dictionary, from_view: StateView, to_view: StateView, hexes: PackedInt32Array,
		season: int, tax: int, touched: Array, from_own: bool, lists: bool, memo: Dictionary) -> void:
	var map := game.map
	var defs := game.defs
	var made: PackedInt32Array = rec["made"]
	var goods := defs.goods.size()
	for i: int in hexes:
		var hex := map.hex_of(i)
		var slot := Economy.slot_for(int(map.climate[i]), season)
		var owner_id := int(game.state.owner[i])
		var level := tax if owner_id == c.id else EconomyPreview.owner_tax(game, owner_id)
		var from_base := base(game, from_view, i, from_own, memo)
		var to_base := base(game, to_view, i, false, memo)
		if same(from_base, to_base):
			continue  # nothing of this hex changes (a wild hex beside a change): it needs no part in the delta
		var from_goods := PackedInt32Array()
		from_goods.resize(goods)
		var to_goods := PackedInt32Array()
		to_goods.resize(goods)
		var from_out := Economy.add_output(from_base, slot, Economy.CALM, level, defs, from_goods)
		var to_out := Economy.add_output(to_base, slot, Economy.CALM, level, defs, to_goods)
		touched.append({
			"hex": hex, "i": i, "owner": owner_id, "from": from_base, "to": to_base, "from_goods": from_goods,
			"to_goods": to_goods, "from_dues": int(from_out["ducats"]), "to_dues": int(to_out["ducats"]),
			"from_cost": int(from_out["upkeep"]) + int(from_out["walls"]), "to_cost": int(to_out["upkeep"]) + int(to_out["walls"]),
		})
		if owner_id != c.id:
			continue
		for g: int in goods:
			made[g] += to_goods[g] - from_goods[g]
		rec["dues_sum"] = int(rec["dues_sum"]) + int(to_out["ducats"]) - int(from_out["ducats"])
		rec["walls_sum"] = int(rec["walls_sum"]) + int(to_out["walls"]) - int(from_out["walls"])
		if lists:
			set_entry(rec["dues"] as Array, map, i, int(to_out["ducats"]))
			set_entry(rec["walls"] as Array, map, i, int(to_out["walls"]))
		rec["upkeep"] = int(rec["upkeep"]) + int(to_out["upkeep"]) - int(from_out["upkeep"])
		rec["upkeep_count"] = int(rec["upkeep_count"]) + int(int(to_out["upkeep"]) > 0) - int(int(from_out["upkeep"]) > 0)
		var from_people := int(from_base["people"])
		var to_people := int(to_base["people"])
		if int(from_base["family"]) == Economy.SETTLEMENTS:
			rec["town"] = int(rec["town"]) - from_people
		else:
			rec["rest"] = int(rec["rest"]) - from_people
		if int(to_base["family"]) == Economy.SETTLEMENTS:
			rec["town"] = int(rec["town"]) + to_people
		else:
			rec["rest"] = int(rec["rest"]) + to_people


## Whether two bases hold the same numbers.
static func same(a: Dictionary, b: Dictionary) -> bool:
	for key: String in Economy.BASE_FIELDS:
		if a[key] != b[key]:
			return false
	return a["good"] == b["good"] and a["people"] == b["people"] and a["staffing"] == b["staffing"] and a["a0"] == b["a0"]


## A hex's base in `view`; the game's own state reads the DistrictCache.
static func base(game: Game, view: StateView, i: int, own: bool, memo: Dictionary) -> Dictionary:
	var key := i if own else signature(game, view, i)
	if memo.has(key):
		return memo[key]
	var base: Dictionary = game.districts.base_of(game, i) if own else Economy.district_base(game, view, game.map.hex_of(i))
	memo[key] = base
	return base


## A negative key that stands for everything a hex's base reads from a view: its barracks, the piece and the people of the
## hex and the six round it (the owner never changes within a version). The same numbers in another view (the next season's, an option's)
## share one base instead of working it out again.
static func signature(game: Game, view: StateView, i: int) -> int:
	var h := i + 1
	h = h * 1000003 + view.main_use_at(i)
	h = h * 1000003 + view.level_at(i)
	h = h * 1000003 + view.people_at(i)
	h = h * 1000003 + int(view.barracks_at(i))
	for j: int in Economy.ring_of(game.map, i):
		if j >= 0:
			h = h * 1000003 + view.main_use_at(j)
			h = h * 1000003 + view.level_at(j)
			h = h * 1000003 + view.people_at(j)
		else:
			h = h * 1000003 - 1
	return -1 - (h & 0x3FFFFFFFFFFFFFFF)


## Sets the {hex, amount} entry of hex index `i` in a list kept in ascending hex index order: replaced, removed for 0, or
## inserted.
static func set_entry(list: Array, map: MapData, i: int, amount: int) -> void:
	var hex := map.hex_of(i)
	var at := list.size()
	for n: int in list.size():
		var entry: Dictionary = list[n]
		if entry["hex"] == hex:
			if amount > 0:
				entry["amount"] = amount
			else:
				list.remove_at(n)
			return
		if at == list.size() and map.index_of(entry["hex"] as Vector2i) > i:
			at = n
	if amount > 0:
		list.insert(at, {"hex": hex, "amount": amount})


## The record with its own made array; with `lists` also its own dues and walls lists.
static func copy_of(rec: Dictionary, lists: bool) -> Dictionary:
	var out := rec.duplicate()
	out["made"] = (rec["made"] as PackedInt32Array).duplicate()
	if not lists:
		return out
	var dues: Array = []
	for entry: Dictionary in rec["dues"]:
		dues.append(entry.duplicate())
	out["dues"] = dues
	var walls: Array = []
	for entry: Dictionary in rec["walls"]:
		walls.append(entry.duplicate())
	out["walls"] = walls
	return out
