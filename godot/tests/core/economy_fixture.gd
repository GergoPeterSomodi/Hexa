## The 1480 scenario for the economy's tests (docs/architecture/m4-build-spec.md 4.15): "Italy, 1480" on seed 1480 with
## calm weather forced in a copy of the definitions (`weather_odds` 100, 0, 0), as Genoa when asked. The "fixture" of 4.15
## is the same game with (7, 12) made wild before turn 1: the search put a second-stage vineyard there, and the
## mockup's example builds a first one. The map and the committed definitions are loaded once.
class_name EconomyFixture
extends RefCounted

const DEFS_PATH := "res://data/defs/game_defs.tres"
const MAP_PATH := "res://data/maps/north_italy.tres"
const SEED := 1480
const VINEYARD_HEX := Vector2i(7, 12)

static var _map: MapData = null
static var _committed: GameDefs = null


static func map() -> MapData:
	if _map == null:
		_map = ResourceLoader.load(MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MapData
	return _map


## The committed definitions, shared and read-only (a test that changes a number takes defs()).
static func committed() -> GameDefs:
	if _committed == null:
		_committed = ResourceLoader.load(DEFS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameDefs
	return _committed


## A copy of the definitions that is yours to change; calm weather unless `calm` is false. People never change unless
## `still` is false: M4's and M4.5's numbers are about the economy alone (PeopleFixture.still); a test of the people's
## growth takes PeopleFixture.genoa or passes `still` false.
static func defs(calm: bool = true, still: bool = true) -> GameDefs:
	var out := PeopleFixture.still(committed()) if still else committed().duplicate() as GameDefs
	out.war = war_copy(out.war)
	if calm:
		out.weather_odds = PackedInt32Array([100, 0, 0])
	return out


## A copy of the war that a test may change: every dictionary, array and word of it is copied, so a change to
## `g.defs.war.x` (or to a nested odds word or fight row) never reaches the committed war. Null stays null.
static func war_copy(war: WarDef) -> WarDef:
	if war == null:
		return null
	var out := war.duplicate(true) as WarDef
	var attack: Dictionary[StringName, PackedInt32Array] = {}
	for branch: StringName in war.fight_attack:
		attack[branch] = PackedInt32Array(war.fight_attack[branch])
	out.fight_attack = attack
	var defence: Dictionary[StringName, PackedInt32Array] = {}
	for branch: StringName in war.fight_defence:
		defence[branch] = PackedInt32Array(war.fight_defence[branch])
	out.fight_defence = defence
	var dealt: Dictionary[StringName, int] = {}
	for stance: StringName in war.stance_dealt:
		dealt[stance] = war.stance_dealt[stance]
	out.stance_dealt = dealt
	var taken: Dictionary[StringName, int] = {}
	for stance: StringName in war.stance_taken:
		taken[stance] = war.stance_taken[stance]
	out.stance_taken = taken
	var ground: Dictionary[StringName, int] = {}
	for key: StringName in war.odds_ground:
		ground[key] = war.odds_ground[key]
	out.odds_ground = ground
	var words: Array[Dictionary] = []
	for entry: Dictionary in war.odds_words:
		words.append(entry.duplicate())
	out.odds_words = words
	return out


## The 1480 scenario game on seed 1480; `tag` is chosen as the player when given. `fixture` makes (7, 12) wild.
static func game(tag: StringName = &"", fixture: bool = false, calm: bool = true, seed_value: int = SEED,
		still: bool = true) -> Game:
	var d := defs(calm, still)
	var g := Game.new_scenario(map(), d, d.scenarios[d.scenarios.size() - 1], seed_value)
	if fixture:
		g.improvement.clear(VINEYARD_HEX)
		g.districts.clear()
		g.version += 1
	if tag != &"":
		g.act("choose_country", {"tag": tag})
	return g


## The money lines of a closed ledger as {"why": amount} (a why with several hexes added up).
static func totals(lines: Array) -> Dictionary:
	var out := {}
	for line: Dictionary in lines:
		var key := str(line["why"])
		out[key] = int(out.get(key, 0)) + int(line["amount"])
	return out
