## Works: a build, an upgrade or a clearing takes seasons (docs/architecture/m3-build-spec.md 4.3, 5.3).
## Y1 creates the owner list and an empty phase; the work rules arrive with Y5.
class_name Works
extends RefCounted

const OWNS: Array[String] = ["works", "next_work_id"]


## The works phase (4.3).
static func season(_game: Game) -> void:
	pass
