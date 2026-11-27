## The seam of the End season battle prompt (docs/architecture/moves-build-spec.md R74, D40; battle-board-build-spec.md R47):
## how many of the viewer's battles would wait in the End season. Until the battle board exists it is 0, so the shell asks
## nothing and the Options row "Battles at End season" stays hidden. The battle board build replaces these two bodies: this is
## the one place that says whether the board is there. Pure core/views/ code: it reads, draws no luck and writes nothing.
class_name BattlesAtEnd
extends RefCounted


## True once the battle board can play a battle: the Options row "Battles at End season" shows. False until then.
static func available() -> bool:
	return false


## The number of battles in the End season's battles phase that need the viewer's choice. 0 until the battle board.
static func count(_game: Game, _viewer: StringName) -> int:
	return 0
