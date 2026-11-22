## Attaches the computer's players to a game (docs/architecture/m8-build-spec.md 4.2, 5.5): the OrdersHook of the ai_orders phase.
## The hook is not state: Session.start_game, the tools and the tests attach it; Game.new_scenario attaches none.
class_name AiPlayers
extends RefCounted


## game.orders = a new AiTurn (its `passive` seats given); returns it.
static func attach(game: Game, passive: Array[StringName] = []) -> AiTurn:
	var turn_hook := AiTurn.new()
	turn_hook.passive = passive.duplicate()
	game.orders = turn_hook
	return turn_hook


## The temperament the scenario gives a country (scenario.tempers[id - 1]); null for a game with none.
static func temper_of(game: Game, tag: StringName) -> AiTemperDef:
	var c := Countries.by_tag(game, tag)
	if c == null or game.scenario == null or game.defs == null:
		return null
	if c.id < 1 or c.id > game.scenario.tempers.size():
		return null
	return game.defs.temper(game.scenario.tempers[c.id - 1])
