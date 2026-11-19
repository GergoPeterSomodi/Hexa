## The stats phase (docs/architecture/m3-build-spec.md 4.6, 5.3). Y1 creates the owner list and an empty phase;
## R5 fills it.
class_name StatsSystem
extends RefCounted

const OWNS: Array[String] = ["stats"]


## The stats phase (4.6).
static func season(_game: Game) -> void:
	pass
