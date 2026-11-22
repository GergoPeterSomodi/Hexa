## Pure view helpers and word tables for a hex's hover card and side panel (docs/architecture/ui-and-controls-spec.md
## sections 3.6 and 7). Reads MapData, MapState and Improve; makes no engine or scene-tree calls.
class_name HexCard
extends RefCounted

## The words for a level, per family (docs/design/map/pieces/GUIDE.md section 8); other families use STAGE_WORDS.
const LEVEL_WORDS := FamilyIds.LEVEL_WORDS
const STAGE_WORDS: Array[String] = FamilyIds.STAGE_WORDS
const COVER_WORDS: Array[String] = ["farmland", "grassland", "woods", "marsh", "rock", "snow", "tundra", "sand"]
const RELIEF_WORDS: Array[String] = ["sea", "lowland", "plain", "hills", "highland", "mountains", "high peaks"]
const CLIMATE_WORDS: Array[String] = ["snow", "frost", "mild"]
const DEPTH_WORDS: Array[String] = ["shelf", "open sea", "deep sea"]
const RIVER_WORDS: Array[String] = ["none", "river", "river", "river", "stream"]
const ROAD_WORDS: Array[String] = ["none", "track", "road", "highway"]
const CROSSING_WORDS: Array[String] = ["none", "ford", "wood bridge", "stone bridge", "ferry", "pass"]
const DIRECTIONS: Array[String] = ["E", "NE", "NW", "W", "SW", "SE"]
const EDGES: Array[String] = ["coast", "river", "road", "pass"]


## Clamped lookup in a word table; "" when the table is empty.
static func word(list: Array[String], index: int) -> String:
	if list.is_empty():
		return ""
	return list[clampi(index, 0, list.size() - 1)]


## The ground cover word for a MapData cover byte ("sea" for COVER_SEA).
static func cover_words(cover: int) -> String:
	if cover == MapData.COVER_SEA:
		return "sea"
	return word(COVER_WORDS, cover)


## The pass on a hex with its height in metres (e.g. "Giovi (472 m)"), or "" when none.
static func pass_of(map: MapData, hex: Vector2i) -> String:
	if map == null or not map.has(hex):
		return ""
	var i := map.index_of(hex)
	var p := int(map.pass_id[i]) if i < map.pass_id.size() else -1
	if p < 0 or p >= map.passes.size():
		return ""
	var entry: Dictionary = map.passes[p]
	var name := str(entry.get("name", ""))
	if name == "":
		return ""
	var metres := int(entry.get("metres", 0))
	return "%s (%d m)" % [name, metres] if metres > 0 else name


## Summary of the six edges of `hex` for `kind` ("river", "road", "crossing", "crest", "pass_edge"):
## e.g. "river (E, NW)", "highway (E), road (SW)", or "none".
static func edge_summary(map: MapData, hex: Vector2i, kind: String) -> String:
	if map == null or not map.has(hex):
		return "none"
	var order: Array[String] = []
	var dirs_by_word: Dictionary = {}
	for d: int in DIRECTIONS.size():
		var e := map.edge_index(hex, d)
		if e < 0:
			continue
		var label := _edge_word(map, e, kind)
		if label == "" or label == "none":
			continue
		if not dirs_by_word.has(label):
			order.append(label)
			dirs_by_word[label] = PackedStringArray()
		var list: PackedStringArray = dirs_by_word[label]
		list.append(DIRECTIONS[d])
		dirs_by_word[label] = list
	if order.is_empty():
		return "none"
	var parts := PackedStringArray()
	for label: String in order:
		var list: PackedStringArray = dirs_by_word[label]
		parts.append("%s (%s)" % [label, ", ".join(list)])
	return ", ".join(parts)


## Summary of the road crossings on the six edges of `hex` (e.g. "stone bridge (E)" or "none").
static func crossing_summary(map: MapData, hex: Vector2i) -> String:
	return edge_summary(map, hex, "crossing")


static func _edge_word(map: MapData, e: int, kind: String) -> String:
	match kind:
		"river", "rivers":
			return word(RIVER_WORDS, int(map.river[e])) if e < map.river.size() else "none"
		"road", "roads":
			return word(ROAD_WORDS, int(map.road[e])) if e < map.road.size() else "none"
		"crossing", "crossings":
			return word(CROSSING_WORDS, int(map.crossing[e])) if e < map.crossing.size() else "none"
		"crest":
			return "crest" if e < map.crest.size() and int(map.crest[e]) > 0 else "none"
		"pass", "pass_edge":
			return "pass" if e < map.pass_edge.size() and int(map.pass_edge[e]) > 0 else "none"
	return "none"


## Title of a hex for its hover card: the place name when one stands there, else "Hex (c, r)" or "Sea (c, r)".
static func title_of(map: MapData, hex: Vector2i) -> String:
	if map == null or not map.has(hex):
		return ""
	if not map.is_land(hex):
		return "Sea (%d, %d)" % [hex.x, hex.y]
	var place := Improve.place_of(map, hex)
	var place_name := str(place.get("name", ""))
	if place_name != "":
		return place_name
	return "Hex (%d, %d)" % [hex.x, hex.y]


## Subtitle of a hex for its hover card: "(c, r) · Land" (with capital, port, pass tags) or "(c, r) · Sea".
static func subtitle_of(map: MapData, hex: Vector2i) -> String:
	if map == null or not map.has(hex):
		return ""
	var parts := PackedStringArray(["(%d, %d)" % [hex.x, hex.y]])
	if not map.is_land(hex):
		parts.append("Sea")
		return " · ".join(parts)
	parts.append("Land")
	var place := Improve.place_of(map, hex)
	if bool(place.get("capital", false)):
		parts.append("capital")
	if bool(place.get("port", false)):
		parts.append("port")
	if pass_of(map, hex) != "":
		parts.append("pass")
	return " · ".join(parts)


## Key-value rows `[key, value]` describing the ground of `hex`.
static func ground_rows(map: MapData, hex: Vector2i) -> Array[Array]:
	var rows: Array[Array] = []
	if map == null or not map.has(hex):
		return rows
	var i := map.index_of(hex)
	if map.land[i] == 0:
		rows.append(["Depth", word(DEPTH_WORDS, int(map.depth[i]))])
		rows.append(["Relief", word(RELIEF_WORDS, int(map.relief[i]))])
		return rows
	rows.append(["Ground", cover_words(int(map.cover[i]))])
	rows.append(["Height", "%d m" % int(map.height_m[i])])
	rows.append(["Relief", word(RELIEF_WORDS, int(map.relief[i]))])
	rows.append(["Winter", word(CLIMATE_WORDS, int(map.climate[i]))])
	var facts := Improve.facts_of(map, hex)
	var edges: Array[String] = []
	for edge: String in EDGES:
		if bool(facts[edge]):
			edges.append(edge)
	if not edges.is_empty():
		rows.append(["Edges", ", ".join(PackedStringArray(edges))])
	return rows


## Key-value rows `[key, value]` describing what stands on a hex (`Improve.piece_at`).
static func piece_rows(piece: Dictionary) -> Array[Array]:
	var rows: Array[Array] = []
	if piece.is_empty():
		rows.append(["Stands on it", "nothing (wild land)"])
		return rows
	var family := str(piece["family"])
	rows.append(["Piece", family_word(family, str(piece["extra"]))])
	rows.append(["Level", level_word(family, int(piece["level"]))])
	if int(piece["addon"]) > 0:
		rows.append(["Harbour", "%s (%s)" % [level_word("harbour", int(piece["addon"])), str(piece["addon_mode"])]])
	rows.append(["Layout", "%d%s" % [int(piece["variant"]) + 1, ", mirrored" if bool(piece["mirror"]) else ""]])
	return rows


## Owner label for a land hex in a scenario game: the owner's long name (with ", yours" when the player holds it),
## "no one" for unowned land, or "" at sea, off-map, or in a map-only game.
static func owner_of(game: Game, hex: Vector2i) -> String:
	if game == null or not game.has_countries() or game.map == null or not game.map.is_land(hex):
		return ""
	var otag := Territory.owner_tag(game, hex)
	if otag == &"":
		return "no one"
	var cdef := Countries.def_of(game, otag)
	var label := String(otag)
	if cdef != null:
		if not cdef.long_name.is_empty():
			label = cdef.long_name
		elif not cdef.name.is_empty():
			label = cdef.name
	if game.player != &"" and otag == game.player:
		label += ", yours"
	return label


## Hover-card model for `hex` in `game` (spec sections 3.5 and 7); `{}` when `game` or `game.map` is null or `hex` is off the map.
static func of(game: Game, hex: Vector2i) -> Dictionary:
	if game == null or game.map == null or not game.map.has(hex):
		return {}
	var map := game.map
	var i := map.index_of(hex)
	var is_land := map.land[i] == 1
	var cover := cover_words(int(map.cover[i])) if is_land else word(DEPTH_WORDS, int(map.depth[i]))
	var height_m := int(map.height_m[i]) if is_land else 0
	var relief := word(RELIEF_WORDS, int(map.relief[i])) if is_land else RELIEF_WORDS[0]
	var climate := word(CLIMATE_WORDS, int(map.climate[i]))
	var place := Improve.place_of(map, hex) if is_land else {}
	var place_name := str(place.get("name", ""))
	var pass_name := pass_of(map, hex) if is_land else ""
	var owner_text := owner_of(game, hex) if is_land else ""
	var rivers := edge_summary(map, hex, "river")
	var roads := edge_summary(map, hex, "road")
	var crossings := crossing_summary(map, hex)
	var piece := Improve.piece_at(game, hex) if is_land else {}
	var gives := gives_text(game, hex) if is_land else ""
	var weather_now := weather_text(game, hex) if is_land else ""
	var lines: Array = [
		["Hex", &"muted", "(%d, %d)" % [hex.x, hex.y]],
	]
	if is_land:
		if owner_text != "":
			lines.append(["Owner", &"plain", owner_text])
		if place_name != "":
			lines.append(["Place", &"plain", place_name])
		lines.append_array(war_rows(game, hex))
		lines.append(["Cover", &"plain", cover])
		lines.append(["Height", &"plain", "%d m" % height_m])
		lines.append(["Relief", &"plain", relief])
		lines.append(["Winter", &"plain", climate])
		if weather_now != "":
			lines.append(["Weather", &"plain", weather_now])
		if pass_name != "":
			lines.append(["Pass", &"plain", pass_name])
		if rivers != "none":
			lines.append(["Rivers", &"plain", rivers])
		if roads != "none":
			lines.append(["Roads", &"plain", roads])
		if crossings != "none":
			lines.append(["Crossings", &"plain", crossings])
		if piece.is_empty():
			lines.append(["Stands on it", &"muted", "nothing (wild land)"])
		else:
			lines.append(["", &"rule", ""])
			for row: Array in piece_rows(piece):
				lines.append([str(row[0]), &"plain", str(row[1])])
		var people_view := PeopleView.at(game, game.player, hex)
		if bool(people_view.get("shown", false)):
			lines.append(["People", &"plain", str(people_view["text"])])
		var armies_line := ArmyView.hex_text(game, game.player, hex)
		if armies_line != "":
			lines.append(["Armies", &"plain", armies_line])
		var supply_view := SupplyView.at(game, game.player, hex)
		if bool(supply_view.get("shown", false)):
			lines.append(["Supply", &"plain", str(supply_view["text"])])
		var food_text := food_text_of(game, hex)
		if food_text != "":
			lines.append(["Food", &"plain", food_text])
		if gives != "":
			lines.append(["Gives", &"plain", gives])
		var worth_line := worth_row(game, hex)
		if not worth_line.is_empty():
			lines.append(worth_line)
		var work_line := work_text(game, hex)
		if work_line != "":
			lines.append(["Work", &"warn", work_line])
	else:
		lines.append(["Depth", &"plain", cover])
		lines.append(["Relief", &"plain", relief])
		lines.append(["Winter", &"plain", climate])
	return {
		"hex": hex,
		"title": title_of(map, hex),
		"subtitle": subtitle_of(map, hex),
		"is_land": is_land,
		"cover": cover,
		"height_m": height_m,
		"relief": relief,
		"climate": climate,
		"place": place_name,
		"pass_name": pass_name,
		"owner": owner_text,
		"rivers": rivers,
		"roads": roads,
		"crossings": crossings,
		"piece": piece,
		"gives": gives,
		"weather": weather_now,
		"lines": lines,
	}


## The war rows of a land hex (M7, 6.8, 4.15): "Held by" on occupied land (public), "Fortress" on a fortress (its garrison
## exact to its owner, rounded to a hundred while the viewer sees the hex, else "a garrison"), "Siege" (exact to its besieger
## and defender, and to a viewer who sees the hex; nothing else), and "Castle area" while a war of the viewer is on. The
## viewer "" sees everything.
static func war_rows(game: Game, hex: Vector2i) -> Array:
	var rows: Array = []
	var viewer := game.player
	if Occupation.is_occupied(game, hex):
		rows.append(["Held by", &"warn", "the " + Occupation.occupier_long_name(game, hex) + _since_text(game, hex)])
	var level := Occupation.fortress_level(game, hex)
	if level > 0:
		rows.append(["Fortress", &"plain", _fortress_text(game, viewer, hex, level)])
	var siege := Occupation.siege_at(game, hex)
	if siege != null and _sees_siege(game, viewer, hex, siege):
		rows.append(["Siege", &"warn", "%s is besieged by %s: %d of %d" % [_siege_place(siege), _short_name(game, siege.besieger), siege.progress, Occupation.siege_need(game, hex)]])
	if viewer != &"" and not Wars.enemies(game, viewer).is_empty():
		var area := _area_text(game, hex)
		if area != "":
			rows.append(["Castle area", &"plain", area])
	return rows


## "Walled town · garrison 800 of 800" (the level's word, then the garrison); others see it rounded or as "a garrison".
static func _fortress_text(game: Game, viewer: StringName, hex: Vector2i, level: int) -> String:
	var family := str(Improve.piece_at(game, hex).get("family", ""))
	var label := level_label(family, level)
	var head := label if label != "" else "level %d" % level
	var full := Occupation.garrison_full(game, hex)
	var men := Occupation.garrison_of(game, hex)
	if viewer == &"" or Territory.owner_tag(game, hex) == viewer:
		return "%s · garrison %d of %d" % [head, men, full]
	if Knowledge.sees(game, viewer, hex):
		return "%s · garrison about %d of %d" % [head, roundi(float(men) / 100.0) * 100, full]
	return "%s · a garrison" % head


## " since Summer 1480": the season of the newest capture of this hex by its present occupier (the chronicle's district_captured);
## "" when the chronicle holds none.
static func _since_text(game: Game, hex: Vector2i) -> String:
	var tag := String(Occupation.controller_tag(game, hex))
	for k: int in range(game.chronicle.entries.size() - 1, -1, -1):
		var e: Dictionary = game.chronicle.entries[k]
		if str(e.get("kind", "")) == "district_captured" and e.get("hex") == hex and str(e.get("tag", "")) == tag:
			return " since " + Calendar.date_text(int(e.get("turn", 0)), game.start_year)
	return ""


static func _sees_siege(game: Game, viewer: StringName, hex: Vector2i, siege: Siege) -> bool:
	return viewer == &"" or siege.besieger == viewer or Occupation.controller_tag(game, hex) == viewer \
		or Knowledge.sees(game, viewer, hex)


static func _siege_place(siege: Siege) -> String:
	return siege.name if not siege.name.is_empty() else "This fortress"


static func _short_name(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	return cdef.name if cdef != null and not cdef.name.is_empty() else String(tag)


## The castle-area row: "Held by the castle of Pavia (10, 9), 7 hexes" (the castle's own hex: "This is ..."), "Open: the
## castle of Pavia (10, 9) has fallen", "Open land: no castle holds it"; "" on occupied land (its row says so).
static func _area_text(game: Game, hex: Vector2i) -> String:
	if Occupation.is_occupied(game, hex):
		return ""
	var info := AreaLines.held_by(game, hex)
	var fortress: Vector2i = info["fortress"]
	if fortress == Army.NO_HEX:
		return "Open land: no castle holds it"
	var where := "%s (%d, %d)" % [str(info["name"]), fortress.x, fortress.y]
	match info["state"]:
		&"castle":
			return "This is %s, %d hexes" % [where, int(info["members"])]
		&"held":
			return "Held by %s, %d hexes" % [where, int(info["members"])]
		&"fallen":
			return "Open: %s has fallen" % where
	return "Open land: no castle holds it"


## The hover card's Worth line on a land hex of the player's, in a game with countries: ["Worth", tone, "+232 a year (+60 this
## season)"], the four seasons from now and the first of them (EconomyPreview.worth_seasons); tone good above 0, bad below,
## plain at 0. [] on any other hex (another country's, unowned, sea) and without a player or countries.
static func worth_row(game: Game, hex: Vector2i) -> Array:
	if game == null or game.map == null or game.state == null or not game.has_countries() or game.player == &"" \
			or not game.map.has(hex):
		return []
	var i := game.map.index_of(hex)
	if game.map.land[i] == 0:
		return []
	var c := Countries.by_tag(game, game.player)
	if c == null or int(game.state.owner[i]) != c.id:
		return []
	var worth := EconomyPreview.worth_seasons_shared(game, game.player, 4)
	var hexes: PackedInt32Array = worth["hexes"]
	var h := hexes.bsearch(i)
	if h >= hexes.size() or hexes[h] != i:
		return []
	var seasons := int(worth["seasons"])
	var values: PackedInt32Array = worth["worth"]
	var year := 0
	for k: int in seasons:
		year += values[h * seasons + k]
	var now := values[h * seasons]
	var tone := &"good" if year > 0 else (&"bad" if year < 0 else &"plain")
	return ["Worth", tone, "%s a year (%s this season)" % [Words.signed(year), Words.signed(now)]]


## The hover card's Food line on your land that makes or eats food: "made 22, eaten 12 a year" (MapModes.food_year); "" else.
static func food_text_of(game: Game, hex: Vector2i) -> String:
	var year := MapModes.food_year(game, game.player, hex)
	if year.x == 0 and year.y == 0:
		return ""
	return "made %s, eaten %s a year" % [Words.number(year.x), Words.number(year.y)]


## The hover card's Work line: "vineyard, first stage: 1 of 4 seasons, ready Spring 1481" (": stopped for the winter,
## ready Autumn 1481" when halted this season); "" when no work stands on `hex`.
static func work_text(game: Game, hex: Vector2i) -> String:
	var work := WorksView.at(game, hex)
	if work.is_empty():
		return ""
	var middle := "stopped for the winter" if bool(work["halted"]) else str(work["progress"])
	return "%s: %s, ready %s" % [work["label"], middle, work["ready"]]


## The hover card's Gives line for an owned land hex (spec 6.10): the district's good with the season it peaks in
## ("wine 24 in autumn"), a port's fish and dues ("fish 6, dues 30 a season"), a wild hex's grain over the year
## ("grain 6 a year (wild)") and the upkeep ("upkeep 2 a season"), joined with " · "; "" when it gives nothing, or the
## hex is sea, unowned or off the map. Calm weather and the owner's tax, over the four seasons (Economy.district_output).
static func gives_text(game: Game, hex: Vector2i) -> String:
	if game == null or game.state == null or game.defs == null or game.map == null or not game.map.has(hex):
		return ""
	var map := game.map
	var i := map.index_of(hex)
	if map.land[i] == 0 or int(game.state.owner[i]) == 0:
		return ""
	var base := Economy.district_base(game, StateView.of(game.state), hex)
	var years := _year_of(game, hex)
	var pieces := PackedStringArray()
	var good := int(base["good"])
	var wild_good := int(base["wild_good"])
	if good >= 0 and good != Economy.FISH:
		var peak := _peak(years, good)
		if int(peak["loads"]) > 0:
			pieces.append("%s %s in %s" % [_good_name(game, good), Words.number(int(peak["loads"])),
				Calendar.SEASON_NAMES[int(peak["season"])].to_lower()])
	elif good < 0 and wild_good >= 0:
		var wild_total := 0
		for year: Dictionary in years:
			wild_total += _loads(year, wild_good)
		if wild_total > 0:
			pieces.append("%s %s a year (wild)" % [_good_name(game, wild_good), Words.number(wild_total)])
	if int(base["port_level"]) > 0:
		var dues := 0
		for year: Dictionary in years:
			dues = maxi(dues, int(year["ducats"]))
		var fish := int(_peak(years, Economy.FISH)["loads"])
		pieces.append("fish %s, dues %s a season" % [Words.number(fish), Words.number(dues)])
	var upkeep := int(base["upkeep"])
	if upkeep > 0:
		pieces.append("upkeep %s a season" % Words.number(upkeep))
	return " · ".join(pieces)


## The weather line of a land hex whose climate is not calm this season (4.6): "good this season: crops +20 %" or
## "poor this season: crops −25 %"; "" when calm, at sea or off the map.
static func weather_text(game: Game, hex: Vector2i) -> String:
	if game == null or game.map == null or game.defs == null or not game.map.has(hex) or not game.map.is_land(hex):
		return ""
	if game.defs.weather_permille.size() != 3:
		return ""
	var climate := clampi(int(game.map.climate[game.map.index_of(hex)]), 0, 2)
	var kind := int(game.weather[climate]) if climate < game.weather.size() else Economy.CALM
	if kind == Economy.CALM:
		return ""
	var percent := int(float(game.defs.weather_permille[kind] - 1000) / 10.0)
	return "%s this season: crops %s%d %%" % ["good" if kind == Economy.GOOD else "poor",
		"+" if percent >= 0 else "−", absi(percent)]


## The district's output in each season of the year (spring to winter, the winter slot of its climate): calm, the owner's tax.
static func _year_of(game: Game, hex: Vector2i) -> Array[Dictionary]:
	var view := StateView.of(game.state)
	var out: Array[Dictionary] = []
	for season: int in Calendar.SEASON_NAMES.size():
		out.append(Economy.district_output(game, view, hex, season, Economy.CALM, -1))
	return out


## The season of `years` with the most loads of `good`: {loads, season}, the earliest season on a tie.
static func _peak(years: Array[Dictionary], good: int) -> Dictionary:
	var best := {"loads": 0, "season": 0}
	for season: int in years.size():
		var loads := _loads(years[season], good)
		if loads > int(best["loads"]):
			best = {"loads": loads, "season": season}
	return best


static func _loads(output: Dictionary, good: int) -> int:
	var goods: PackedInt32Array = output["goods"]
	return int(goods[good]) if good >= 0 and good < goods.size() else 0


static func _good_name(game: Game, good: int) -> String:
	return game.defs.goods[good].name.to_lower() if good >= 0 and good < game.defs.goods.size() else ""


static func top_level(family_name: String) -> int:
	var id := ImproveRules.NAMES.find(family_name)
	return ImproveRules.TOP_LEVEL[id] if id >= 0 else 0


## Plain level word for `family_name` and `level` (e.g. "town", "city", "watchtower"), or "".
static func level_label(family_name: String, level: int) -> String:
	if LEVEL_WORDS.has(family_name):
		var words: Array = LEVEL_WORDS[family_name]
		if level >= 0 and level < words.size():
			return str(words[level])
	elif level >= 0 and level < STAGE_WORDS.size():
		return STAGE_WORDS[level]
	return ""


static func level_name(family_name: String, level: int) -> String:
	var label := level_label(family_name, level)
	return "%s (level %d)" % [label, level] if label != "" else "level %d" % level


static func family_word(family: String, extra: String) -> String:
	var label := family.replace("_", " ").capitalize()
	if extra != "-" and extra != "":
		label += " (" + extra + ")"
	return label


static func level_word(family: String, level: int) -> String:
	var label := level_label(family, level)
	return "level %d, %s" % [level, label] if label != "" else "level %d" % level
