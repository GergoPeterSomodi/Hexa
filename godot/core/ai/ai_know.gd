## THE DOOR (docs/architecture/m8-build-spec.md 4.3, 5.5): every read of the game and every act of the AI goes through a function
## of this class. The other core/ai files read only what these functions return, the definitions and plain values
## (tests/core/test_ai_door.gd scans them for the game's own fields and the systems' names). The fog rule (fog build):
## a country's own state is exact. Another country's men, armies and garrisons come only through Knowledge, which gives
## them exact when the viewer sees or has discovered the place and hides them otherwise. The land facts of another
## country (its districts and what it holds) are gated by discovery in AiWar and AiBrief, the functions that read them;
## this door does not yet gate every public read by discovery, since R33's literal door gate is a later task. Nothing
## else is readable. The AI acts only through act(), which asks the same check the player's door asks, never acts on a
## refusal and tells the turn.
## Pure core/ai/ code: no engine calls; luck only through the game's own AI stream.
class_name AiKnow
extends RefCounted

# ----- own country ---------------------------------------------------------------------------------------------------


static func treasury(game: Game, tag: StringName) -> int:
	var c := Countries.by_tag(game, tag)
	return c.treasury if c != null else 0


## The country's money this season at tax level `tax` (-1: its own level), calm weather: EconomyPreview with one season.
## Memoised by the game's version and the resolved level (a version moves on every change, so a read never sees an old net);
## the own level reads the two-season preview of `_two`, which the brief's upkeep and food alarm share.
static func preview_net(game: Game, tag: StringName, tax: int = -1) -> int:
	var c := Countries.by_tag(game, tag)
	if c == null:
		return 0
	var level := tax if tax >= 0 and tax <= 2 else c.tax
	if level == c.tax:
		var own := _two(game, tag)
		return int((own[0] as Dictionary)["net"]) if not own.is_empty() else 0
	return int(game.view_cache.get_or_make([&"ai_net", game.version, tag, level], func() -> int:
		var list: Array = EconomyPreview.with(game, tag, {"tax": level}, 1)["seasons"]
		return int((list[0] as Dictionary)["net"]) if not list.is_empty() else 0))


## The next two seasons of the country's own preview (calm, its own tax, lines on), kept for the game's version. Season 0 is
## the one-season preview (its net, its lines and its used goods equal the one-season ask to the unit: EconomyPreview.with's
## count only cuts the walk), season 1 is the food alarm's second season. One walk serves the brief's net, upkeep and alarms.
static func _two(game: Game, tag: StringName) -> Array:
	return game.view_cache.get_or_make([&"ai_two", game.version, tag], func() -> Array:
		return EconomyPreview.with(game, tag, {}, 2)["seasons"]) as Array


## The negative lines of the season's preview (districts, walls, army), as a positive number.
static func upkeep(game: Game, tag: StringName) -> int:
	var own := _two(game, tag)
	var entry: Dictionary = own[0] if not own.is_empty() else {}
	var total := 0
	for line: Dictionary in entry.get("lines", []):
		var amount := int(line["amount"])
		if amount < 0:
			total -= amount
	return total


static func army_upkeep(game: Game, tag: StringName) -> int:
	return Military.upkeep_country(game, tag)


static func men(game: Game, tag: StringName) -> int:
	return Wars.men_under_arms(game, tag)


## The people on the country's land.
static func people(game: Game, tag: StringName) -> int:
	var c := Countries.by_tag(game, tag)
	if c == null:
		return 0
	var total := 0
	for i: int in Territory.districts(game, c.id):
		total += int(game.state.people[i])
	return total


static func tax_level(game: Game, tag: StringName) -> int:
	var c := Countries.by_tag(game, tag)
	return c.tax if c != null else 1


## The country's armies, id order. Read only.
static func own_armies(game: Game, tag: StringName) -> Array[Army]:
	return Armies.of_country(game, tag)


## The lowest morale of the army's companies (1000 when it has none).
static func morale_of(army: Army) -> int:
	var low := Unit.MAX_MORALE
	for u: Unit in army.units:
		low = mini(low, u.morale)
	return low


static func slots_free(game: Game, tag: StringName) -> int:
	return maxi(0, Works.slots(game, tag) - Works.in_use(game, tag))


## {hungry, food_soon, town_full: Array[Vector2i]}: the reminders' view of the seat's own country. food_soon is food running
## out within two seasons (the line's words are all the reminder gives of it); town_full are the hexes of 4.5.
static func alarms(game: Game, tag: StringName) -> Dictionary:
	var out := {"hungry": false, "food_soon": false, "town_full": [] as Array[Vector2i]}
	var c := Countries.by_tag(game, tag)
	if c == null or not c.alive:
		return out
	out["hungry"] = not Reminders.hunger(game, tag).is_empty()
	out["food_soon"] = _food_soon(game, tag)
	out["town_full"] = _full_towns(game, c)
	return out


## Reminders' goods_running_out for food, asked of the next two seasons only (the reminder looks eight ahead, which costs a
## preview of eight seasons a seat): the towns take less than their need in one of them, in the calm preview.
static func _food_soon(game: Game, tag: StringName) -> bool:
	var food: Array[int] = []
	for g: int in game.defs.goods.size():
		if game.defs.goods[g].kind == &"food":
			food.append(g)
	for entry: Dictionary in _two(game, tag):
		var used: PackedInt32Array = entry["used"]
		var taken := 0
		for g: int in food:
			taken += used[g] if g < used.size() else 0
		if taken < int(EconomySeason.needs_for(game, int(entry["town"]))["food"]):
			return true
	return false


static func _full_towns(game: Game, c: Country) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if game.districts == null:
		return out
	var top := game.defs.people_top_level
	var city := FamilyIds.LEVEL_WORDS["settlements"].size() - 1
	var open := game.districts.open_hexes(game)
	var keys := open.keys()
	keys.sort()
	for i: int in keys:
		var level := int(game.state.level[i])
		if int(game.state.owner[i]) != c.id or int(game.state.main_use[i]) != People.SETTLEMENTS:
			continue
		if level < top or level >= city or int(game.state.people[i]) < int(open[i]):
			continue
		var hex := game.map.hex_of(i)
		if game.state.work_at(hex) == null:
			out.append(hex)
	return out


## The settlements the country controls, hex index order.
static func settlements(game: Game, tag: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c := Countries.by_tag(game, tag)
	if c == null:
		return out
	for i: int in Occupation.controlled(game, c.id):
		if int(game.state.main_use[i]) == People.SETTLEMENTS:
			out.append(game.map.hex_of(i))
	return out


## 4.7's candidates: the seat's controlled, owned, unbesieged hexes with no work under way, in hex index order: its
## settlements and its goods districts and castles under their top level (an upgrade), and the wild hexes within 2 hexes of
## one of its settlements that some family may be built on. No clear is ever a candidate.
static func work_candidates(game: Game, tag: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c := Countries.by_tag(game, tag)
	if c == null or not c.alive or game.map == null:
		return out
	var busy := {}
	for w: Work in game.state.works:
		busy[w.hex] = true
	var near := {}
	for hex: Vector2i in settlements(game, tag):
		near[hex] = true
		for d: int in 6:
			var ring := ImproveRules.neighbour(hex, d)
			near[ring] = true
			for e: int in 6:
				near[ImproveRules.neighbour(ring, e)] = true
	for i: int in Occupation.controlled(game, c.id):
		var hex := game.map.hex_of(i)
		# R33: a candidate is discovered by the seat (its own land always is; the wild ring is checked too).
		if int(game.state.owner[i]) != c.id or not game.map.is_land(hex) or busy.has(hex) or Occupation.besieged(game, hex) \
				or not discovered(game, tag, hex):
			continue
		var family := int(game.state.main_use[i])
		if family <= ImproveRules.NONE or family >= ImproveRules.FAMILIES:
			if near.has(hex) and _may_build(game, hex):
				out.append(hex)
		elif int(game.state.level[i]) < FamilyIds.TOP_LEVEL[family]:
			out.append(hex)
	return out


static func _may_build(game: Game, hex: Vector2i) -> bool:
	for option: Dictionary in Improve.build_options(game, hex):
		if bool(option.get("ok", false)):
			return true
	return false


static func build_options(game: Game, hex: Vector2i) -> Array[Dictionary]:
	return Improve.build_options(game, hex)


## {verdict, blocked_by, payback (seasons from now; -1 never), ducats, goods} of the works card of `option` on `hex`.
static func card(game: Game, tag: StringName, hex: Vector2i, option: Dictionary) -> Dictionary:
	var c := ImprovePreview.of(game, tag, hex, option)
	var cost: Dictionary = c.get("cost", {})
	var payback: Dictionary = c.get("payback", {})
	return {"verdict": c.get("verdict", {"ok": false, "reason": ""}), "blocked_by": c.get("blocked_by", &"rule"),
		"payback": int(payback.get("seasons", -1)), "ducats": int(cost.get("ducats", 0)), "goods": cost.get("goods", [])}


static func raise_options(game: Game, tag: StringName, hex: Vector2i) -> Array[Dictionary]:
	return Military.raise_options(game, tag, hex)


static func men_at_hand(game: Game, tag: StringName, hex: Vector2i) -> int:
	return Military.men_at_hand(game, tag, hex)


static func depots(game: Game, tag: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for hex: Vector2i in settlements(game, tag):
		if Supply.is_depot(game, tag, hex):
			out.append(hex)
	return out


## The siege of `hex` as a side sees it (exact); {} when none.
static func own_siege(game: Game, tag: StringName, hex: Vector2i) -> Dictionary:
	return SiegeView.at(game, tag, hex)


## What stands on a hex: x the family id, y the level; (0, 0) for a wild hex (public: the piece is drawn on everyone's map).
static func use_at(game: Game, hex: Vector2i) -> Vector2i:
	var i := game.map.index_of(hex)
	if i < 0 or game.map.land[i] == 0:
		return Vector2i(0, 0)
	return Vector2i(int(game.state.main_use[i]), int(game.state.level[i]))


## {cover, climate} of a hex from the fixed map (climate 0 snow, 1 frost, 2 mild; cover is a WorldCover number).
static func ground(game: Game, hex: Vector2i) -> Dictionary:
	var i := game.map.index_of(hex)
	if i < 0:
		return {"cover": 0, "climate": 1}
	return {"cover": int(game.map.cover[i]), "climate": int(game.map.climate[i])}


## True when the hex is a port as the economy counts it: a place of level 1 or more with a port and a shore.
static func is_port(game: Game, hex: Vector2i) -> bool:
	var place := Improve.place_of(game.map, hex)
	return bool(place.get("port", false)) and int(place.get("level", 0)) >= 1 and game.map.coast_mask(hex) != 0


## The animal or ore (or "-") that a grazing or mines district of `family` and `level` would have on the hex.
static func piece_extra(game: Game, hex: Vector2i, family: int, level: int) -> String:
	return str(Improve.piece_for(game.map, hex, family, level).get("extra", "-"))


## 4.7's fortify candidates: the seat's controlled, owned, unbesieged land hexes with no work and a pass, beside the land of
## one of `threats`, either wild or a castle under level 3; hex index order.
static func fortify_candidates(game: Game, tag: StringName, threats: Array[StringName]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c := Countries.by_tag(game, tag)
	if c == null or not c.alive or threats.is_empty():
		return out
	var busy := {}
	for w: Work in game.state.works:
		busy[w.hex] = true
	for i: int in Occupation.controlled(game, c.id):
		var hex := game.map.hex_of(i)
		if game.map.pass_id[i] < 0 or int(game.state.owner[i]) != c.id or busy.has(hex) or Occupation.besieged(game, hex):
			continue
		var family := int(game.state.main_use[i])
		if family != ImproveRules.NONE and (family != ImproveRules.CASTLE or int(game.state.level[i]) >= FamilyIds.TOP_LEVEL[family]):
			continue
		for beside: Vector2i in land_neighbours(game, hex):
			if threats.has(owner_of(game, beside)):
				out.append(hex)
				break
	return out


# ----- public --------------------------------------------------------------------------------------------------------


static func turn(game: Game) -> int:
	return game.turn


## The living countries' tags, id order.
static func living(game: Game) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: Country in game.countries:
		if c != null and c.alive and c.tag != &"":
			out.append(c.tag)
	return out


static func id_of(game: Game, tag: StringName) -> int:
	var c := Countries.by_tag(game, tag)
	return c.id if c != null else 0


static func owner_of(game: Game, hex: Vector2i) -> StringName:
	return Territory.owner_tag(game, hex)


static func controller_of(game: Game, hex: Vector2i) -> StringName:
	return Occupation.controller_tag(game, hex)


static func area_state(game: Game, hex: Vector2i) -> StringName:
	return Occupation.area_state(game, hex)


## The hexes the country controls (land), index order.
static func controlled(game: Game, tag: StringName) -> PackedInt32Array:
	var c := Countries.by_tag(game, tag)
	return Occupation.controlled(game, c.id) if c != null else PackedInt32Array()


## The fortresses the country controls, hex index order.
static func fortresses_of(game: Game, tag: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in controlled(game, tag):
		var hex := game.map.hex_of(i)
		if Occupation.fortress_level(game, hex) > 0:
			out.append(hex)
	return out


static func fortress_level(game: Game, hex: Vector2i) -> int:
	return Occupation.fortress_level(game, hex)


## The capital's hex, Army.NO_HEX when the country's capital is off the map.
static func capital_of(game: Game, tag: StringName) -> Vector2i:
	var c := Countries.by_tag(game, tag)
	if c == null or c.capital == Country.NO_HEX or not game.map.is_land(c.capital):
		return Army.NO_HEX
	return c.capital


## The hex indices the country owns, ascending.
static func land_of(game: Game, tag: StringName) -> PackedInt32Array:
	var c := Countries.by_tag(game, tag)
	return Territory.districts(game, c.id) if c != null else PackedInt32Array()


## The hexes within `range_hexes` of the country's own land (its land included, at distance 0) as keys, each with its distance.
## A breadth-first field from the land: a hex is a key exactly when some own land hex is at most `range_hexes` away (the
## same test as hex_distance). Read only; AiBrief.near_land keeps it per game version.
static func land_field(game: Game, tag: StringName, range_hexes: int) -> Dictionary:
	var field := {}
	var frontier: Array[Vector2i] = []
	for i: int in land_of(game, tag):
		var hex := hex_of(game, i)
		if not field.has(hex):
			field[hex] = 0
			frontier.append(hex)
	for step: int in range(1, range_hexes + 1):
		var next: Array[Vector2i] = []
		for hex: Vector2i in frontier:
			for d: int in 6:
				var beside := ImproveRules.neighbour(hex, d)
				if not field.has(beside):
					field[beside] = step
					next.append(beside)
		frontier = next
	return field


## The countries sharing a land border with `tag`, id order.
static func neighbours(game: Game, tag: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var c := Countries.by_tag(game, tag)
	if c == null:
		return out
	for id: int in Territory.neighbours(game, c.id):
		var other := Countries.by_id(game, id)
		if other != null and other.alive:
			out.append(other.tag)
	return out


static func enemies(game: Game, tag: StringName) -> Array[StringName]:
	return Wars.enemies(game, tag)


## The live wars of `tag`, war id order: {enemy, start_turn, end_turn, terms}.
static func wars_of(game: Game, tag: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: War in game.wars:
		if w.live() and w.other(tag) != &"":
			out.append({"enemy": w.other(tag), "start_turn": w.start_turn, "end_turn": w.end_turn, "terms": w.terms})
	return out


static func score(game: Game, a: StringName, b: StringName) -> int:
	return Wars.score(game, a, b)


## True when `other` has a live war with a third country (not `tag`).
static func at_war_with_other(game: Game, tag: StringName, other: StringName) -> bool:
	for e: StringName in Wars.enemies(game, other):
		if e != tag:
			return true
	return false


static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	return ImproveRules.hex_distance(a, b)


## The land hexes round `hex`, in edge order.
static func land_neighbours(game: Game, hex: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: int in 6:
		var beside := ImproveRules.neighbour(hex, d)
		if game.map.is_land(beside):
			out.append(beside)
	return out


static func hex_of(game: Game, index: int) -> Vector2i:
	return game.map.hex_of(index)


static func index_of(game: Game, hex: Vector2i) -> int:
	return game.map.index_of(hex)


## The people on a hex (public: drawn on everyone's map as the piece's level; the AI uses it only for its own towns).
static func people_at(game: Game, hex: Vector2i) -> int:
	var i := game.map.index_of(hex)
	return int(game.state.people[i]) if i >= 0 else 0


# ----- others, through Knowledge -------------------------------------------------------------------------------------


## Another country's men under arms as `tag` may read them: banded, -1 when unknown.
static func men_of(game: Game, tag: StringName, other: StringName) -> int:
	return Knowledge.men_of(game, tag, other)


## The enemy armies `tag` sees now: {army (id), tag, hex, men (banded)}. Never the army itself: no kind, order or route.
static func seen_enemies(game: Game, tag: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for seen: Dictionary in Knowledge.armies_seen(game, tag):
		if Wars.at_war(game, tag, seen["tag"] as StringName):
			out.append({"army": (seen["army"] as Army).id, "tag": seen["tag"], "hex": seen["hex"], "men": int(seen["men"])})
	return out


## -1 means unknown: the hex is undiscovered by `tag`, so its garrison is not read. Callers must not read -1 as no garrison
## (a `<= 0` test would take it for an empty fortress): AiWar skips an undiscovered fortress before it asks (R33, R34).
static func garrison_estimate(game: Game, tag: StringName, hex: Vector2i) -> int:
	return int(Knowledge.garrison_known(game, tag, hex)["men"])


## Seasons until a siege of `hex` by `men` and `guns` would fall, against the garrison `tag` may take it to be (-1: never).
## True when `tag` has discovered the hex (R1): the gate of every AI read of another country's land (R33). Own land is
## always discovered.
static func discovered(game: Game, tag: StringName, hex: Vector2i) -> bool:
	return Knowledge.discovered(game, tag, hex)


## Seasons until a siege falls against what `tag` may read of the garrison; -1 (never) when the garrison is unknown (R34):
## an undiscovered fortress is never forecast against a guess.
static func forecast(game: Game, tag: StringName, hex: Vector2i, men: int, guns: int) -> int:
	var garrison := garrison_estimate(game, tag, hex)
	if garrison < 0:
		return -1
	return Sieges.forecast_for(game, hex, garrison, men, guns, 0, 0)


## The odds card's numbers of the army against `hex`.
static func odds(game: Game, tag: StringName, army: Army, hex: Vector2i, storm: bool) -> Dictionary:
	return OddsView.of(game, tag, army.id, hex, storm)


# ----- acts and luck -------------------------------------------------------------------------------------------------


## What the player's door says about the action: args plus the seat's tag, through the game's own check.
static func check(game: Game, tag: StringName, action: String, args: Dictionary) -> Dictionary:
	var full := args.duplicate()
	full["tag"] = tag
	return game.check(action, full)


## Checks first; a refusal is told to the turn and returned, never acted on. Else the act, then the judge and the trace.
static func act(turn_hook: AiTurn, game: Game, tag: StringName, action: String, args: Dictionary) -> Dictionary:
	var full := args.duplicate()
	full["tag"] = tag
	var verdict := game.check(action, full)
	if not bool(verdict.get("ok", false)):
		turn_hook.refused(tag, action, full, verdict)
		return verdict
	var result := game.act(action, full)
	turn_hook.judged(tag, action, full, verdict, result)
	return result


## A draw of 1 to 1,000 from the AI's own stream.
static func roll(game: Game) -> int:
	return game.luck.ai.randi_range(1, 1000)


## A draw of 1,000 - permille to 1,000 + permille from the AI's own stream.
static func jitter(game: Game, permille: int) -> int:
	return game.luck.ai.randi_range(1000 - permille, 1000 + permille)


# ----- war reads (4.9, 4.10) -----------------------------------------------------------------------------------------


## The season the seat's newest ended war ended (0 when none has ended): the rest before it declares again counts from it.
static func last_peace(game: Game, tag: StringName) -> int:
	var newest := 0
	for w: War in Wars.of_country(game, tag):
		if not w.live():
			newest = maxi(newest, w.end_turn)
	return newest


## True when the hex is land of the fixed map.
static func is_land(game: Game, hex: Vector2i) -> bool:
	return game.map.is_land(hex)


## The siege points (guns) of the companies of one of the seat's armies.
static func guns_of(game: Game, army: Army) -> int:
	var total := 0
	for u: Unit in army.units:
		var def := Military.unit_def(game, u.kind)
		total += def.siege_points if def != null else 0
	return total
