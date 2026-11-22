## The battle marks of the movement replay (docs/architecture/m7-build-spec.md 6.5 and 5.6; B20): the battles that began in the
## season's movement, each with the movement tick it began at and whether the viewer may see it. Read-only: it reads the
## walks the replay kept, the battle events the shell heard and the game (BattleView.sites for the viewer's access, Knowledge
## for the fog). A battle with no walk that ends on its hex has no tick and is left out.
class_name ReplayMarks
extends RefCounted


## The battles of the season: `events` are {hex, tag} as Events.battle_started (tag: the attacker) or battle_joined (the
## joiner) reported them; `records` are the replay's walks {tag, path, ticks}. Returns {hex, tick, shown} in event order.
## `shown` is true when the viewer has a battle site on the hex (BattleView.sites: the battle is one the viewer may see)
## and sees the hex now (the strict fog of ReplayPlan).
static func battles(records: Array[Dictionary], events: Array[Dictionary], game: Game, viewer: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in events:
		var hex := e["hex"] as Vector2i
		var tick := _tick_of(records, StringName(e["tag"]), hex)
		if tick < 1:
			continue
		out.append({"hex": hex, "tick": tick, "shown": _shown(game, viewer, hex)})
	return out


## The tick of the step that ends on `hex` in a walk of `tag` (the last step of the walk that stopped there); -1 when none.
static func _tick_of(records: Array[Dictionary], tag: StringName, hex: Vector2i) -> int:
	for r: Dictionary in records:
		if StringName(r["tag"]) != tag:
			continue
		var path := r["path"] as Array[Vector2i]
		var ticks := r["ticks"] as PackedInt32Array
		if path.is_empty() or path[path.size() - 1] != hex or ticks.is_empty():
			continue
		return ticks[ticks.size() - 1]
	return -1


static func _shown(game: Game, viewer: StringName, hex: Vector2i) -> bool:
	if game == null or game.map == null or not Knowledge.sees(game, viewer, hex):
		return false
	for site: Dictionary in BattleView.sites(game, viewer):
		if site["hex"] == hex:
			return true
	return false
