## The tile window's read model (tile-window spec R1 to R4, R10 to R12, R14 facts, R18 land facts, R28 picture facts and
## the cases of 3.9): what one hex shows to one viewer. Pure: no nodes, no engine calls, no luck. Every fact goes through a
## function that takes the viewer (Knowledge, PeopleView, WorksView, ArmyView.visible, BattleView.sites, MapModes.food_year,
## HexCard.war_rows_for, ...), never the player; the door scan (tests/core/test_tile_door.gd) keeps the names out of this file.
## Light (R1): no EconomyPreview base of its own and no raise check; the food line is MapModes.food_year, which the view cache
## shares. Cached per game.version in game.view_cache under [&"tile", version, viewer, hex]. The own tile's income chip (issue 436
## round 3, the owner's decision: this tile's income a year, not the treasury) is not in the light view: it reads the country's
## worth of the four seasons ahead (EconomyPreview.worth_seasons_shared, the map hover's Worth line and the Yields mode share it),
## so strip_cells adds it for the window and `of` stays light.
@warning_ignore_start("integer_division")
class_name TileView
extends RefCounted

## The settlement kinds of the picture by level (R28): level 1 hamlet .. 5 city.
const SETTLEMENT_KINDS: Array[String] = ["", "hamlet", "village", "town", "walled_town", "city"]
const CASTLE_KIND := "castle"
## The food years of MapModes (its four seasons of a year).
const FOOD_SEASONS := 4
## The title of land with no place name: an owner's ("Land of Genoa"), or no one's (M2: not the ground word twice).
const WILD_LAND := "Wild land"
const LAND_OF := "Land of %s"


## The view of `hex` for `viewer` ("" sees all): {} off the map; see the module comment for the keys. An unexplored hex
## carries only case, hex, sight and header (R3).
static func of(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary:
	if game == null or game.map == null or not game.map.has(hex):
		return {}
	var key: Array = [&"tile", game.version, viewer, hex]
	return game.view_cache.get_or_make(key, func() -> Dictionary: return _make(game, viewer, hex)) as Dictionary


## The case of R2: unexplored (an undiscovered hex, sea too), sea, sandbox (no countries), unowned, own or foreign.
static func case_of(game: Game, viewer: StringName, hex: Vector2i) -> StringName:
	if game.has_countries() and not Knowledge.discovered(game, viewer, hex):
		return &"unexplored"
	if not game.map.is_land(hex):
		return &"sea"
	if not game.has_countries():
		return &"sandbox"
	var owner := Territory.owner_tag(game, hex)
	if owner == &"":
		return &"unowned"
	if owner == viewer:
		return &"own"
	return &"foreign"


## R4: undiscovered, light (discovered, not in sight) or sight. The sandbox and the viewer "" see everything.
static func sight_of(game: Game, viewer: StringName, hex: Vector2i) -> StringName:
	if not game.has_countries():
		return &"sight"
	if not Knowledge.discovered(game, viewer, hex):
		return &"undiscovered"
	return &"sight" if Knowledge.sees(game, viewer, hex) else &"light"


static func _make(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary:
	var case_id := case_of(game, viewer, hex)
	var sight := sight_of(game, viewer, hex)
	if case_id == &"unexplored":
		return {"case": case_id, "hex": hex, "sight": sight, "header": _unexplored_header(hex)}
	return {
		"case": case_id,
		"hex": hex,
		"sight": sight,
		"header": _header(game, viewer, hex, case_id),
		"strip": _strip(game, viewer, hex, case_id),
		"job": _job(game, viewer, hex, case_id),
		"land": _land(game, viewer, hex, case_id, sight),
		"build": _build(game, viewer, hex, case_id),
		"army": _army(game, viewer, hex, case_id, sight),
		"own_port": case_id == &"own" and Improve.is_port(game, hex),
	}


static func _unexplored_header(hex: Vector2i) -> Dictionary:
	return {"title": "Unexplored", "place": "", "subtitle": "Hex %d, %d" % [hex.x, hex.y], "owner": {}, "stars": 0,
		"picture": {}, "badges": []}


# --- header (R11, R12's badges, R28) -------------------------------------------------------------------------------------


static func _header(game: Game, viewer: StringName, hex: Vector2i, case_id: StringName) -> Dictionary:
	var map := game.map
	var i := map.index_of(hex)
	var is_sea := case_id == &"sea"
	var piece: Dictionary = {} if is_sea else Improve.piece_at(game, hex)
	var family_id := int(piece.get("family_id", ImproveRules.NONE))
	var level := int(piece.get("level", 0))
	var place_name := "" if is_sea else str(Improve.place_of(map, hex).get("name", ""))
	var owner := Territory.owner_tag(game, hex) if case_id in [&"own", &"foreign", &"unowned"] else &""
	var title := ""
	var subtitle := ""
	if is_sea:
		title = "Coastal sea" if _beside_land(game, hex) else "Open sea"
		subtitle = "%s · hex %d, %d" % [HexCard.word(HexCard.DEPTH_WORDS, int(map.depth[i])), hex.x, hex.y]
	else:
		var ground := HexCard.cover_words(int(map.cover[i]))
		title = place_name
		if title == "":
			title = LAND_OF % _short_name(game, owner) if owner != &"" else WILD_LAND
		subtitle = "%s · hex %d, %d" % [ground, hex.x, hex.y]
	var parts := PackedStringArray()
	if not is_sea and family_id in [ImproveRules.SETTLEMENT, ImproveRules.CASTLE]:
		var kind := HexCard.level_label(str(piece.get("family", "")), level)
		parts.append(kind.substr(0, 1).to_upper() + kind.substr(1))  # "Walled town", as a sentence (not "Walled Town")
	if owner != &"":
		parts.append(_long_name(game, owner))
	return {
		"title": title,
		"place": " · ".join(parts),
		"subtitle": subtitle,
		"owner": _owner(game, viewer, owner, case_id),
		"stars": level if family_id == ImproveRules.SETTLEMENT else 0,
		"picture": _picture(game, hex, case_id, piece, owner),
		"badges": _badges(game, viewer, hex, case_id),
	}


## The owner block: {} on sea, sandbox and unexplored; relation yours, at_war, foreign or no_one.
static func _owner(game: Game, viewer: StringName, owner: StringName, case_id: StringName) -> Dictionary:
	if case_id == &"sea" or case_id == &"sandbox":
		return {}
	if case_id == &"unowned":
		return {"tag": "", "name": "no one", "relation": &"no_one"}
	var relation := &"yours" if owner == viewer else (&"at_war" if Wars.at_war(game, viewer, owner) else &"foreign")
	return {"tag": owner, "name": _long_name(game, owner), "relation": relation}


## The picture facts (R28) on a settlement or castle hex that the viewer has discovered; {} else.
static func _picture(game: Game, hex: Vector2i, case_id: StringName, piece: Dictionary, owner: StringName) -> Dictionary:
	if case_id == &"sea":
		return {}
	var family_id := int(piece.get("family_id", ImproveRules.NONE))
	if family_id != ImproveRules.SETTLEMENT and family_id != ImproveRules.CASTLE:
		return {}
	var level := int(piece.get("level", 0))
	var kind := CASTLE_KIND
	if family_id == ImproveRules.SETTLEMENT:
		kind = SETTLEMENT_KINDS[clampi(level, 0, SETTLEMENT_KINDS.size() - 1)]
	var i := game.map.index_of(hex)
	return {
		"kind": kind,
		"level": level,
		"harbour": int(piece.get("addon", 0)),
		"cover": int(game.map.cover[i]),
		"season": Calendar.season_of(game.turn),
		"climate": int(game.map.climate[i]),
		"seed": ((hex.x * 73856093) ^ (hex.y * 19349663)) & 0xffff,
		"owner_tag": String(owner),
	}


## The badges in order (R11): Occupied, Besieged, Battle here, then Enemy army or Foreign army. Each only as the viewer
## may know it: a siege by its access, a battle by BattleView.sites (witnessed), an army by ArmyView.visible.
static func _badges(game: Game, viewer: StringName, hex: Vector2i, case_id: StringName) -> Array:
	var out: Array = []
	if Occupation.is_occupied(game, hex):
		out.append({"text": "Occupied by " + Occupation.occupier_long_name(game, hex), "tone": &"warn"})
	var access := Knowledge.siege_access(game, viewer, hex)
	if access == &"exact" or access == &"seen":
		out.append({"text": "Besieged by " + _short_name(game, Occupation.siege_at(game, hex).besieger), "tone": &"bad"})
	elif access == &"land":
		out.append({"text": "Besieged", "tone": &"bad"})
	for site: Dictionary in BattleView.sites(game, viewer):
		if site["hex"] == hex:
			out.append({"text": "Battle here, " + Calendar.date_text(game.turn - 1, game.start_year), "tone": &"bad"})
			break
	var enemy := false
	var foreign := false
	for army: Army in _armies_here(game, viewer, hex):
		if army.tag == viewer:
			continue
		foreign = true
		enemy = enemy or Wars.at_war(game, viewer, army.tag)
	if enemy:
		out.append({"text": "Enemy army here", "tone": &"bad"})
	elif foreign:
		out.append({"text": "Foreign army here", "tone": &"plain"})
	return out


# --- the number strip (R10) ----------------------------------------------------------------------------------------------


static func _strip(game: Game, viewer: StringName, hex: Vector2i, case_id: StringName) -> Array:
	match case_id:
		&"own":
			return _own_strip(game, viewer, hex)
		&"sea":
			return _sea_strip(game, viewer, hex)
		&"foreign", &"unowned":
			return _other_strip(game, viewer, hex)
		&"sandbox":
			return _sandbox_strip(game, viewer, hex)
	return []


static func _own_strip(game: Game, viewer: StringName, hex: Vector2i) -> Array:
	var food := MapModes.food_year(game, viewer, hex)
	var net := food.x - food.y
	var slots := WorksView.slots(game, viewer)
	return [
		_cell("people", _people_text(PeopleView.at(game, viewer, hex)), "People", &"plain"),
		_cell("food", Words.signed(net), "Food", _sign_tone(net)),
		_cell("works", "%s of %s" % [Words.number(int(slots["used"])), Words.number(int(slots["total"]))], "Works", &"plain"),
	]


## The chips the window shows: the view's strip, and on own land the tile's income a year as the fourth (see the module comment).
static func strip_cells(game: Game, viewer: StringName, hex: Vector2i, view: Dictionary) -> Array:
	var cells: Array = (view.get("strip", []) as Array).duplicate()
	if StringName(str(view.get("case", ""))) == &"own":
		cells.append(income_cell(game, viewer, hex))
	return cells


## The own tile's income a year: what the hex gives in the four seasons ahead (its goods at price, its dues and taxes, less its
## upkeep and walls), as the map hover's Worth line sums it. 0 for a hex that gives and costs nothing.
static func income_cell(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary:
	var year := 0
	var i := game.map.index_of(hex)
	var worth := EconomyPreview.worth_seasons_shared(game, viewer, FOOD_SEASONS)
	var hexes: PackedInt32Array = worth.get("hexes", PackedInt32Array())
	var h := hexes.bsearch(i)
	if h < hexes.size() and hexes[h] == i:
		var seasons := int(worth["seasons"])
		var values: PackedInt32Array = worth["worth"]
		for k: int in seasons:
			year += values[h * seasons + k]
	return _cell("income", Words.signed(year), "Income a year", _sign_tone(year))


## The sea's chips (M6): the depth, the winter, and who holds the coast beside it (a discovered land neighbour's owner; "-"
## when no one's or no land is known).
static func _sea_strip(game: Game, viewer: StringName, hex: Vector2i) -> Array:
	var i := game.map.index_of(hex)
	var coast := "-"
	for d: int in 6:
		var n := ImproveRules.neighbour(hex, d)
		if not game.map.has(n) or not game.map.is_land(n) or not Knowledge.discovered(game, viewer, n):
			continue
		var owner := Territory.owner_tag(game, n)
		if owner != &"":
			coast = _short_name(game, owner)
			break
	return [
		_cell("depth", HexCard.word(HexCard.DEPTH_WORDS, int(game.map.depth[i])), "Depth", &"plain"),
		_cell("winter", HexCard.word(HexCard.CLIMATE_WORDS, int(game.map.climate[i])), "Winter", &"plain"),
		_cell("coast", coast, "Coast held by", &"plain"),
	]


## Foreign and unowned land: people, garrison, buildings and armies in sight ("fog" out of sight). No owner's money.
static func _other_strip(game: Game, viewer: StringName, hex: Vector2i) -> Array:
	var garrison := Knowledge.garrison_known(game, viewer, hex)
	var garrison_text := "-"
	if garrison["access"] == &"exact":
		garrison_text = "%s of %s" % [Words.number(int(garrison["men"])), Words.number(Occupation.garrison_full(game, hex))]
	var sight := sight_of(game, viewer, hex)
	var armies_text := str(_armies_here(game, viewer, hex).size()) if sight == &"sight" else "fog"
	return [
		_cell("people", _people_text(PeopleView.at(game, viewer, hex)), "People", &"plain"),
		_cell("garrison", garrison_text, "Garrison", &"plain"),
		_cell("buildings", str(_built_count(game, hex)), "Buildings", &"plain"),
		_cell("armies", armies_text, "Armies", &"plain"),
	]


static func _sandbox_strip(game: Game, viewer: StringName, hex: Vector2i) -> Array:
	var food := _sandbox_food(game, viewer, hex)
	var net := food.x - food.y
	return [
		_cell("people", _people_text(PeopleView.at(game, viewer, hex)), "People", &"plain"),
		_cell("food", Words.signed(net), "Food", _sign_tone(net)),
	]


static func _cell(key: String, value: String, label: String, tone: StringName) -> Dictionary:
	return {"key": key, "value": value, "label": label, "tone": tone}


static func _people_text(people: Dictionary) -> String:
	if not bool(people.get("shown", false)):
		return "-"
	return Words.number(int(people.get("people", 0)))


static func _sign_tone(net: int) -> StringName:
	return &"good" if net > 0 else (&"bad" if net < 0 else &"plain")


# --- the job line (R12) --------------------------------------------------------------------------------------------------


## The work under way on the hex: label, progress, ready, halted, tag, cancel (own work only). On own or sandbox land with
## no work, {idle: true} for "No work under way". {} at sea, unexplored, and on foreign or unowned land with no work.
static func _job(game: Game, viewer: StringName, hex: Vector2i, case_id: StringName) -> Dictionary:
	if case_id == &"sea" or case_id == &"unexplored":
		return {}
	var work := WorksView.at(game, hex, viewer)
	if work.is_empty():
		if case_id == &"own" or case_id == &"sandbox":
			return {"idle": true, "label": "No work under way", "progress": "", "ready": "", "halted": false,
				"tag": viewer, "cancel": false}
		return {}
	var mine: bool = work.get("tag", &"") == viewer and (case_id == &"own" or case_id == &"sandbox")
	return {"label": str(work["label"]), "progress": str(work["progress"]), "ready": str(work["ready"]),
		"halted": bool(work["halted"]), "tag": StringName(str(work["tag"])), "cancel": mine, "idle": false}


# --- the land tab's facts (R18) ----------------------------------------------------------------------------------------


static func _land(game: Game, viewer: StringName, hex: Vector2i, case_id: StringName, sight: StringName) -> Dictionary:
	var out := {"people": PeopleView.at(game, viewer, hex), "food": {}, "made": [], "buildings": [], "ground_rows": [],
		"war": false, "war_rows": [], "battle": {}, "armies_hidden": false, "supply": false, "castle_area": false,
		"sea_rows": []}
	if case_id == &"sea":
		out["sea_rows"] = _sea_rows(game, hex)
		return out
	out["ground_rows"] = HexCard.ground_rows(game.map, hex)
	var war := HexCard.war_rows_for(game, viewer, hex)
	out["war_rows"] = war
	out["war"] = not war.is_empty()
	out["battle"] = _battle_row(game, viewer, hex)
	out["armies_hidden"] = (case_id == &"foreign" or case_id == &"unowned") and sight != &"sight"
	out["supply"] = bool(SupplyView.at(game, viewer, hex).get("shown", false))
	out["castle_area"] = AreaLines.held_by(game, hex)["fortress"] != Army.NO_HEX
	out["made"] = _made(game, viewer, hex, case_id)
	out["food"] = _food(game, viewer, hex, case_id)
	if case_id == &"foreign" or case_id == &"unowned":
		out["buildings"] = _other_buildings(game, viewer, hex)
	return out


## One row per good made in a calm year (the four seasons' loads). Own land adds the value at the good's price.
static func _made(game: Game, viewer: StringName, hex: Vector2i, case_id: StringName) -> Array:
	var rows: Array = []
	var year := HexCard._year_of(game, hex)
	for g: int in game.defs.goods.size():
		var loads := 0
		for output: Dictionary in year:
			loads += _loads_of(output, g)
		if loads <= 0:
			continue
		var good := game.defs.goods[g]
		var value: Variant = loads * good.price_milli / 1000 if case_id == &"own" else null
		rows.append({"good": g, "name": good.name.to_lower(), "loads": loads, "value": value})
	return rows


## Food made and eaten a year on own land (MapModes.food_year of the viewer) or on the sandbox; {} else.
static func _food(game: Game, viewer: StringName, hex: Vector2i, case_id: StringName) -> Dictionary:
	var food := MapModes.food_year(game, viewer, hex) if case_id == &"own" else Vector2i.ZERO
	if case_id == &"sandbox":
		food = _sandbox_food(game, viewer, hex)
	if food == Vector2i.ZERO:
		return {}
	return {"made": food.x, "eaten": food.y}


## The sandbox has no country and so no food_year: made is the grain and fish loads of a calm year, eaten is the
## settlement's people at the food need (MapModes' rule).
static func _sandbox_food(game: Game, viewer: StringName, hex: Vector2i) -> Vector2i:
	var made := 0
	for output: Dictionary in HexCard._year_of(game, hex):
		made += _loads_of(output, Economy.GRAIN) + _loads_of(output, Economy.FISH)
	var eaten := 0
	var piece := Improve.piece_at(game, hex)
	if int(piece.get("family_id", ImproveRules.NONE)) == ImproveRules.SETTLEMENT:
		var people := PeopleView.at(game, viewer, hex)
		eaten = int(people.get("people", 0)) * game.defs.food_need_milli * FOOD_SEASONS / 1000000
	return Vector2i(made, eaten)


static func _loads_of(output: Dictionary, good: int) -> int:
	var goods: PackedInt32Array = output["goods"]
	return int(goods[good]) if good >= 0 and good < goods.size() else 0


## The buildings of foreign and unowned land: each built piece (working) and the work under way (building, its progress).
static func _other_buildings(game: Game, viewer: StringName, hex: Vector2i) -> Array:
	var rows: Array = []
	var piece := Improve.piece_at(game, hex)
	if not piece.is_empty():
		rows.append({"name": HexCard.family_word(str(piece["family"]), str(piece["extra"])), "state_text": "working"})
	var work := WorksView.at(game, hex, viewer)
	if not work.is_empty():
		rows.append({"name": str(work["label"]), "state_text": "building " + str(work["progress"])})
	return rows


static func _battle_row(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary:
	for site: Dictionary in BattleView.sites(game, viewer):
		if site["hex"] == hex:
			return {"record": int(site["record"]), "name": str(site["name"])}
	return {}


static func _sea_rows(game: Game, hex: Vector2i) -> Array:
	var map := game.map
	var i := map.index_of(hex)
	var rows: Array = HexCard.ground_rows(map, hex)
	rows.append(["Winter", HexCard.word(HexCard.CLIMATE_WORDS, int(map.climate[i]))])
	var coasts := HexCard.edge_summary(map, hex, "coast")
	if coasts != "none":
		rows.append(["Coasts", coasts])
	var crossings := HexCard.crossing_summary(map, hex)
	if crossings != "none":
		rows.append(["Crossings", crossings])
	return rows


# --- building and army (R14 facts) ----------------------------------------------------------------------------------------


## Buildings is offered where Territory.at_home_check accepts the viewer's action on this land; its reason otherwise.
static func _build(game: Game, viewer: StringName, hex: Vector2i, case_id: StringName) -> Dictionary:
	if case_id == &"sea" or case_id == &"unexplored":
		return {"offered": false, "reason": ""}
	var home := Territory.at_home_check(game, viewer, hex)
	return {"offered": bool(home["ok"]), "reason": str(home["reason"])}


## Army: raise_offered (own settlement, Military.raise_offered), the armies this viewer sees on the hex, and the reason
## the tab is dimmed when neither holds.
static func _army(game: Game, viewer: StringName, hex: Vector2i, case_id: StringName, sight: StringName) -> Dictionary:
	var raise := Military.raise_offered(game, viewer, hex)
	var seen := _armies_here(game, viewer, hex).size()
	var reason := ""
	if not raise and seen == 0 and case_id != &"sea" and case_id != &"sandbox":
		if case_id == &"own":
			reason = "Raising needs a village or larger"
		elif sight == &"sight":
			reason = "No armies here"
		else:
			reason = "Out of sight: no armies are shown"
	return {"raise_offered": raise, "reason": reason, "armies_seen": seen}


# --- helpers ----------------------------------------------------------------------------------------------------------------


## The armies of the hex the viewer sees (ArmyView.visible: its own, or a foreign one in sight). Reads the game's list
## through the viewer's test only.
static func _armies_here(game: Game, viewer: StringName, hex: Vector2i) -> Array[Army]:
	var out: Array[Army] = []
	for army: Army in game.armies:
		if army != null and army.hex == hex and ArmyView.visible(game, viewer, army):
			out.append(army)
	return out


static func _built_count(game: Game, hex: Vector2i) -> int:
	return 0 if Improve.piece_at(game, hex).is_empty() else 1


static func _beside_land(game: Game, hex: Vector2i) -> bool:
	for d: int in 6:
		var n := ImproveRules.neighbour(hex, d)
		if game.map.has(n) and game.map.is_land(n):
			return true
	return false


static func _long_name(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	if cdef == null:
		return String(tag)
	return cdef.long_name if not cdef.long_name.is_empty() else cdef.name


static func _short_name(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	if cdef == null:
		return String(tag)
	return cdef.name if not cdef.name.is_empty() else String(tag)
