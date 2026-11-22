## The AI's economy steps (docs/architecture/m8-build-spec.md 5.5): the signatures of group C's functions with empty bodies. A step
## reads only AiKnow and AiBrief (never another step module) and acts only through AiKnow.act.
class_name AiEconomy
extends RefCounted


@warning_ignore("unused_parameter")
static func works_scan(turn: AiTurn, game: Game, brief: AiBrief, arg: int) -> void:
	pass


@warning_ignore("unused_parameter")
static func works_card(turn: AiTurn, game: Game, brief: AiBrief, arg: int) -> void:
	pass


@warning_ignore("unused_parameter")
static func works_act(turn: AiTurn, game: Game, brief: AiBrief, arg: int) -> void:
	pass


@warning_ignore("unused_parameter")
static func tax(turn: AiTurn, game: Game, brief: AiBrief, arg: int) -> void:
	pass


## 4.7's prior of an option on a hex, in permille a year of its cost.
@warning_ignore("unused_parameter")
static func prior(game: Game, brief: AiBrief, hex: Vector2i, option: Dictionary) -> int:
	return 0
