## Recruiting (docs/design/recruitment-queue.md sections 4 to 6): where companies are raised. The barracks: which
## settlements a new game gives one, where one may be built (Works runs the work), the finished and the developer's one,
## and its upkeep. The queue: so far only the saved form and the digest of its entries (game.musters, RQ5); no rule makes
## or reads one yet, and raising reads neither. Writes `state.barracks`, `musters` and `next_muster_id` and nothing else.
## No change of owner writes the barracks: it stands through capture and passes with ceded land (section 13, question 4).
class_name Recruiting
extends RefCounted

const OWNS: Array[String] = ["barracks", "musters", "next_muster_id"]
## The queue's saved body.
const SCHEMA := "hexa-godot/musters/1"
## The problem a refused body reports (Snapshot's word for an unreadable body).
const PROBLEM_BODY := "body"
const NO_SETTLEMENT := "no settlement here: a barracks is built in one"
const ALREADY := "a barracks stands here already"


## The barracks of a new scenario game (4.1): the settlements the scenario lists, or every capital on the map when it
## lists none; whatever their size (decision 17).
static func setup(game: Game, scenario: ScenarioDef) -> void:
	game.state.barracks.resize(game.map.hex_count())
	game.state.barracks.fill(0)
	var hexes := scenario.barracks if not scenario.barracks.is_empty() else scenario.capitals
	for hex: Vector2i in hexes:
		put(game, hex)  # a capital off the map is no settlement
	if game.districts != null:
		game.districts.clear()  # a hex read before its barracks stood would keep the old upkeep


## Whether a barracks stands on a hex.
static func has_barracks(game: Game, hex: Vector2i) -> bool:
	var i := game.map.index_of(hex)
	return i >= 0 and i < game.state.barracks.size() and game.state.barracks[i] != 0


## The barracks' numbers; null in a game without definitions, or with definitions that hold none.
static func def_of(game: Game) -> BarracksDef:
	return game.defs.barracks if game.defs != null else null


## The ducats a season that the barracks of hex index `i` costs in `view` (4.2: paid with the settlement's own upkeep);
## 0 with none there.
static func upkeep_at(defs: GameDefs, view: StateView, i: int) -> int:
	if defs.barracks == null or not view.barracks_at(i):
		return 0
	return defs.barracks.upkeep


## The place's rows of the build check (4.2), the first refusal as the verdict {ok, reason}: a settlement, no barracks
## there yet, a town or larger (any settlement for a country with no town and no barracks: decision 25). The owner, the
## work under way, war, the slot and the payment are Works.barracks_check's.
static func site_check(game: Game, hex: Vector2i) -> Dictionary:
	var def := def_of(game)
	if def == null:
		return _refusal("no barracks data: this game's definitions hold none")
	var i := game.map.index_of(hex)
	if i < 0 or int(game.state.main_use[i]) != ImproveRules.SETTLEMENT:
		return _refusal(NO_SETTLEMENT)
	if has_barracks(game, hex):
		return _refusal(ALREADY)
	var small := size_reason(game, hex)
	if small != "":
		return _refusal(small)
	return {"ok": true, "reason": ""}


## "" when the size rule lets a barracks be built on the settlement of `hex` (or there are no numbers or no hex to ask
## about), else the town rule's words: the tile window locks the tile by them. The rule passes a town or larger, and any
## settlement of an owner with no town and no barracks (decision 25). The answer tells of the owner's whole land, so it
## is asked for the owner's own screens and orders only: every caller has passed the owner row first.
static func size_reason(game: Game, hex: Vector2i) -> String:
	var def := def_of(game)
	var i := game.map.index_of(hex)
	if def == null or i < 0 or int(game.state.level[i]) >= def.min_level \
			or lacks_town_and_barracks(game, int(game.state.owner[i])):
		return ""
	var words: Array = FamilyIds.LEVEL_WORDS["settlements"]
	return "a barracks is built in a %s or larger" % str(words[clampi(def.min_level, 0, words.size() - 1)])


## Decision 25: whether country `id` has no town and no barracks on the land it owns, occupied or not: no settlement of
## the barracks' level or larger, no barracks standing and none being built (its own work: one that a former owner left
## there is lost in the next works step). False for no country and without the barracks' numbers. Read from the state
## each time (nothing is kept); it stops at the first town or barracks.
static func lacks_town_and_barracks(game: Game, id: int) -> bool:
	var def := def_of(game)
	var country := Countries.by_id(game, id)
	if def == null or country == null:
		return false
	for i: int in Territory.districts(game, id):
		if game.state.barracks[i] != 0:
			return false
		if int(game.state.main_use[i]) == ImproveRules.SETTLEMENT and int(game.state.level[i]) >= def.min_level:
			return false
	for work: Work in game.state.works:
		if work.action == Works.BARRACKS and work.tag == country.tag \
				and int(game.state.owner[game.map.index_of(work.hex)]) == id:
			return false
	return true


## A barracks stands from now (a finished work, or the developer's): put, then a hex_changed, so that the district's
## upkeep is read again and the hex is shown anew. No level is asked (a town that shrank keeps its work). {ok, reason};
## a refusal changes nothing.
static func finish(game: Game, hex: Vector2i) -> Dictionary:
	if has_barracks(game, hex):
		return _refusal(ALREADY)
	if not put(game, hex):
		return _refusal(NO_SETTLEMENT)
	game.emit({"kind": "hex_changed", "hex": hex})
	return {"ok": true, "reason": ""}


## Puts a barracks on a settlement. False, with nothing changed, off the map, on a hex with no settlement and where one
## stands already. No level, owner or payment is asked: those are the building action's rules.
static func put(game: Game, hex: Vector2i) -> bool:
	var i := game.map.index_of(hex)
	if i < 0 or i >= game.state.barracks.size() or int(game.state.main_use[i]) != ImproveRules.SETTLEMENT:
		return false
	if game.state.barracks[i] != 0:
		return false
	game.state.barracks[i] = 1
	return true


# --- the queue's save and digest -------------------------------------------------------------------------------------


## {schema, next_muster_id, list: [Muster.to_dict] in id order}.
static func to_dict(game: Game) -> Dictionary:
	var list: Array = []
	for m: Muster in game.musters:
		list.append(m.to_dict())
	return {"schema": SCHEMA, "next_muster_id": game.next_muster_id, "list": list}


## Fills game.musters and next_muster_id from a saved body, or refuses with PROBLEM_BODY and changes nothing. It refuses a
## wrong schema, a next id out of int32 or below 1, an entry that fails Muster.from_dict, an id not ascending from 1 or not
## below the next id, a tag that is no country of the game, a hex off the map or at sea, a kind that is no UnitDef, a
## queued_turn before the first season or after this one, and a levy that is not the company's full men taken, each source
## once, from land on the hex and its ring. Who holds the hex and what stands on it are not asked here.
static func from_dict(d: Dictionary, game: Game) -> String:
	if game == null or game.map == null or game.defs == null or str(d.get("schema", "")) != SCHEMA:
		return PROBLEM_BODY
	var next_id: Variant = Unit.int32(d.get("next_muster_id", null))
	var raw: Variant = d.get("list", null)
	if next_id == null or int(next_id) < 1 or not (raw is Array):
		return PROBLEM_BODY
	var list: Array[Muster] = []
	var last_id := 0
	for item: Variant in raw as Array:
		if not (item is Dictionary):
			return PROBLEM_BODY
		var m := Muster.from_dict(item as Dictionary)
		if m == null or m.id <= last_id or m.id >= int(next_id) or not _muster_ok(game, m):
			return PROBLEM_BODY
		last_id = m.id
		list.append(m)
	game.musters = list
	game.next_muster_id = int(next_id)
	return ""


## "next_muster_id" then each entry's digest text in id order, one per line.
static func digest(game: Game) -> String:
	var lines := PackedStringArray()
	for m: Muster in game.musters:
		lines.append(m.digest_text())
	return "%d\n%s" % [game.next_muster_id, "\n".join(lines)]


## One saved entry against the game: its tag, its hex on land, its kind, its turn and its levy.
static func _muster_ok(game: Game, m: Muster) -> bool:
	var ud := game.defs.unit_def(m.kind)
	if Countries.by_tag(game, m.tag) == null or not game.map.is_land(m.hex) or ud == null:
		return false
	if m.queued_turn < Calendar.FIRST_TURN or m.queued_turn > game.turn:
		return false
	return _levy_ok(game, m, ud.men)


## The levy of a saved entry: every source land on the entry's hex or beside it, none twice, `men` in all.
static func _levy_ok(game: Game, m: Muster, men: int) -> bool:
	var ring: Array[Vector2i] = [m.hex]
	for d: int in 6:
		ring.append(ImproveRules.neighbour(m.hex, d))
	var seen := {}
	var total := 0
	for source: Array in m.levy:
		var spot: Vector2i = source[0]
		if not ring.has(spot) or not game.map.is_land(spot) or seen.has(spot):
			return false
		seen[spot] = true
		total += int(source[1])
	return total == men


static func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
