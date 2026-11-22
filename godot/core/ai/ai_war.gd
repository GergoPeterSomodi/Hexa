## The AI's war steps (docs/architecture/m8-build-spec.md 5.5): the signatures of group C's functions with empty bodies. A step
## reads only AiKnow and AiBrief (never another step module) and acts only through AiKnow.act.
class_name AiWar
extends RefCounted


@warning_ignore("unused_parameter")
static func war(turn: AiTurn, game: Game, brief: AiBrief, arg: int) -> void:
	pass


@warning_ignore("unused_parameter")
static func war_army(turn: AiTurn, game: Game, brief: AiBrief, arg: int) -> void:
	pass


## 4.10's aims of an army, best first.
@warning_ignore("unused_parameter")
static func aims(game: Game, brief: AiBrief, army: Army) -> Array[Dictionary]:
	return []
