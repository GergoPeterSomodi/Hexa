## Prints the M4 economy tables from data/defs/game_defs.tres (docs/architecture/m4-build-spec.md sections 4.2 to 4.12):
## the goods, the families' numbers, the settlements, the wild yield and the cover people, and the money, weather and
## tax numbers, and the people tables (M5 spec 4.4 to 4.6). The row builders are static so
## tests/core/test_economy_defs.gd can check them against the spec.
## Run: godot --headless --path godot -s res://tools/economy_tables.gd   (exit 1 when the defs do not validate)
extends SceneTree

const DEFS_PATH := "res://data/defs/game_defs.tres"
const COVERS: Array[String] = ["farmland", "grassland", "woods", "marsh", "rock", "snow", "tundra", "sand"]
const SLOTS: Array[String] = ["spring", "summer", "autumn", "winter snow", "winter frost", "winter mild"]
const TAX_LEVELS: Array[String] = ["Low", "Normal", "High"]


func _initialize() -> void:  # not _init: the classes are known to the parser only from here on
	var defs := ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	if defs == null:
		printerr("economy_tables: cannot load " + DEFS_PATH)
		quit(1)
		return
	for line: String in tables(defs):
		print(line)
	var errors := defs.validate()
	for err: String in errors:
		printerr("economy_tables: " + err)
	quit(1 if not errors.is_empty() else 0)


## Every table, in print order.
static func tables(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = []
	lines.append_array(goods_rows(defs))
	lines.append_array(family_rows(defs))
	lines.append_array(settlement_rows(defs))
	lines.append_array(level_rows(defs))
	lines.append_array(people_rows(defs))
	lines.append_array(wild_rows(defs))
	lines.append_array(money_rows(defs))
	return lines


## One row per good in id order, then the header: id, key, name, kind, price, need, weight, reserve, harvest word, icon.
static func goods_rows(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = ["goods (id key name kind price need weight reserve harvest icon)"]
	for g: GoodDef in defs.goods:
		if g == null:
			lines.append("(null good)")
			continue
		# Spec 4.2: grain keeps four seasons of food, a staple four seasons of its need, a material its fixed reserve.
		var reserve := str(g.reserve_fixed)
		if g.key == &"grain" or g.kind == &"staple":
			reserve = "%d seasons" % defs.reserve_seasons
		lines.append("%2d %-7s %-14s %-8s price %5d need %3d weight %3d reserve %-10s '%s' %s" % [
			g.id, String(g.key), g.name, String(g.kind), g.price_milli, g.need_milli, g.need_weight, reserve,
			g.harvest_word, String(g.icon),
		])
	return lines


## One row per family in id order: key, the good or the extras, base, season percents, weather, keep, jobs, upkeep,
## walls, cost and the ground line.
static func family_rows(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = ["families (key good|extras base season weather keep jobs upkeep walls cost)"]
	var ordered: Array[FamilyDef] = defs.families.duplicate()
	ordered.sort_custom(func(a: FamilyDef, b: FamilyDef) -> bool: return a.id < b.id)
	for f: FamilyDef in ordered:
		if f == null:
			lines.append("(null family)")
			continue
		var what := String(f.good)
		if not f.by_extra.is_empty():
			what = "extras " + str(f.by_extra)
		lines.append("%-10s %-24s base %s season %s weather %s keep %s jobs %s upkeep %s walls %s cost %s" % [
			String(f.key), what, str(Array(f.base)), str(Array(f.season_percent)), str(f.weather_bound),
			str(Array(f.keep_wild)), str(Array(f.jobs)), str(Array(f.upkeep)), str(Array(f.walls)),
			str(Array(f.cost)),
		])
		if f.ground_text != "":
			lines.append("           ground: %s" % f.ground_text)
	return lines


## The settlement levels 1 to 5: people, keep wild, upkeep, walls, ring lift, port fish and port dues.
static func settlement_rows(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = ["settlements (level people keep upkeep walls lift fish dues)"]
	var f := defs.family(1)
	if f == null:
		lines.append("(no settlements family)")
		return lines
	for level: int in range(1, f.people.size()):
		lines.append("  %d %6d %3d %3d %3d %4d %3d %3d" % [
			level, f.people[level], f.keep_wild[level], f.upkeep[level], f.walls[level],
			f.ring_lift[level], f.port_fish[level], f.port_dues[level],
		])
	return lines


## The level rows of the settlements (spec 4.5, 4.6): level, start people, room, the people under which it falls (never at
## 0), and the cost to reach the level (ducats and goods).
static func level_rows(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = ["settlement levels (level, start people, room, falls below, cost in ducats and goods)"]
	var f := defs.family(1)
	if f == null:
		lines.append("(no settlements family)")
		return lines
	for level: int in range(1, f.people.size()):
		var below := _at(f.falls_below, level)
		var parts: Array[String] = []
		if level < f.cost_goods.size():
			for key: Variant in f.cost_goods[level]:
				parts.append("%s %d" % [String(key), int(f.cost_goods[level][key])])
		var goods_text := ", ".join(parts) if not parts.is_empty() else "no goods"
		lines.append("  %d start %d room %d falls %s cost %d %s" % [
			level, f.people[level], _at(f.room, level), "never" if below == 0 else str(below),
			_at(f.cost, level), goods_text,
		])
	return lines


## The people numbers (spec 4.4): growth by tax level and by slot, hunger by slot, crowding, the town floor, the top level
## the people raise, and M6's levy share.
static func people_rows(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = ["people (growth by tax Low, Normal, High; growth and hunger by slot)"]
	lines.append("  growth_bp %s; growth_percent %s" % [str(Array(defs.growth_bp)), str(Array(defs.growth_percent))])
	lines.append("  hunger_bp %d; hunger_percent %s" % [defs.hunger_bp, str(Array(defs.hunger_percent))])
	lines.append("  left_bp %d; town_floor %d; people_top_level %d; levy_permille %d" % [
		defs.left_bp, defs.town_floor, defs.people_top_level, defs.levy_permille,
	])
	return lines


## The value at an index of a per-level array, 0 past its end.
static func _at(values: PackedInt32Array, index: int) -> int:
	return values[index] if index < values.size() else 0


## The wild yield per cover (loads a season per slot) with its good and its people.
static func wild_rows(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = ["wild output (cover good people | %s)" % ", ".join(SLOTS)]
	for cover: int in mini(COVERS.size(), defs.wild_good.size()):
		var values: Array[int] = []
		for slot: int in SLOTS.size():
			var index := cover * SLOTS.size() + slot
			values.append(defs.wild_yield[index] if index < defs.wild_yield.size() else -1)
		lines.append("%-10s %-8s %5d | %s" % [
			COVERS[cover], String(defs.wild_good[cover]), defs.country_people[cover] if cover < defs.country_people.size() else -1,
			str(values),
		])
	return lines


## The tax levels, the money numbers, the weather odds and the fishing and port percents.
static func money_rows(defs: GameDefs) -> Array[String]:
	var lines: Array[String] = []
	lines.append("tax levels (level taxes on people, share of goods sold, districts' output)")
	for level: int in mini(TAX_LEVELS.size(), defs.tax_permille.size()):
		lines.append("  %-7s %5d %5d %5d" % [
			TAX_LEVELS[level], defs.tax_permille[level], defs.goods_share_permille[level], defs.output_permille[level],
		])
	lines.append("people tax %d town, %d countryside; food need %d, food weight %d, content floor %d, reserve %d seasons"
		% [defs.town_tax_milli, defs.country_tax_milli, defs.food_need_milli, defs.food_weight, defs.content_floor,
			defs.reserve_seasons])
	lines.append("start treasury %d + %d per 1,000 people; hands %d permille; expensive: %d permille or %d seasons"
		% [defs.start_treasury_base, defs.start_treasury_per_1000, defs.hands_permille, defs.expensive_permille,
			defs.expensive_seasons])
	lines.append("weather odds calm/good/poor %s; permille %s" % [str(Array(defs.weather_odds)), str(Array(defs.weather_permille))])
	lines.append("port dues percent %s" % str(Array(defs.port_dues_percent)))
	lines.append("fishing percent %s" % str(Array(defs.fishing_percent)))
	return lines
