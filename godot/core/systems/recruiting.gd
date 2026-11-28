## Recruiting (docs/design/recruitment-queue.md sections 4 and 5): where companies are raised. So far the barracks
## alone: which settlements a new game gives one, where one may be built (Works runs the work), the finished and the
## developer's one, and its upkeep. Raising does not read it yet. Writes `state.barracks` and nothing else. No change of
## owner writes it: a barracks stands through capture and passes with ceded land (section 13, question 4).
class_name Recruiting
extends RefCounted

const OWNS: Array[String] = ["barracks"]
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


static func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
