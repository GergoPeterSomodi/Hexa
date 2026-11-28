## Recruiting (docs/design/recruitment-queue.md sections 4 and 5): where companies are raised. So far the barracks
## alone: which settlements a new game gives one, and the one a developer puts. No rule reads it yet. Writes
## `state.barracks` and nothing else.
class_name Recruiting
extends RefCounted

const OWNS: Array[String] = ["barracks"]


## The barracks of a new scenario game (4.1): the settlements the scenario lists, or every capital on the map when it
## lists none; whatever their size (decision 17).
static func setup(game: Game, scenario: ScenarioDef) -> void:
	game.state.barracks.resize(game.map.hex_count())
	game.state.barracks.fill(0)
	var hexes := scenario.barracks if not scenario.barracks.is_empty() else scenario.capitals
	for hex: Vector2i in hexes:
		put(game, hex)  # a capital off the map is no settlement


## Whether a barracks stands on a hex.
static func has_barracks(game: Game, hex: Vector2i) -> bool:
	var i := game.map.index_of(hex)
	return i >= 0 and i < game.state.barracks.size() and game.state.barracks[i] != 0


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
