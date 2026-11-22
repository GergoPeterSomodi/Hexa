## The AI's peace steps (docs/architecture/m8-build-spec.md 5.5): the signatures of group C's functions with empty bodies. A step
## reads only AiKnow and AiBrief (never another step module) and acts only through AiKnow.act.
class_name AiPeace
extends RefCounted


@warning_ignore("unused_parameter")
static func peace(turn: AiTurn, game: Game, brief: AiBrief, arg: int) -> void:
	pass
