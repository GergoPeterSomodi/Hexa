## The replay (docs/architecture/m3-build-spec.md 4.5, 5.4): the same game started again and the action log played in
## order. The same seed and the same log give the same digest.
class_name Replay
extends RefCounted


## The game after the log, or null when the scenario id is not in the definitions. Records that are refused are skipped
## (the digest then differs from the original's).
static func run(map: MapData, defs: GameDefs, scenario_id: String, seed_value: int, log: Array[Dictionary]) -> Game:
	var game: Game = null
	if scenario_id.is_empty():
		game = Game.new_game(map, seed_value, defs)
	else:
		var scenario := defs.scenario(scenario_id)
		if scenario == null:
			return null
		game = Game.new_scenario(map, defs, scenario, seed_value)
	for record: Dictionary in log:
		var action := str(record.get("action", ""))
		var args: Dictionary = record["args"] if record.get("args") is Dictionary else {}
		match action:
			"end_season":
				Season.run(game)
			"dev_money":
				game.dev_money(StringName(str(args.get("tag", ""))), int(args.get("amount", 0)))
			"dev_goods":
				game.dev_goods(StringName(str(args.get("tag", ""))), int(args.get("good", -1)), int(args.get("amount", 0)))
			"dev_transfer":
				game.dev_transfer(_hexes(args.get("hexes")), int(args.get("to_id", 0)))
			_:
				game.act(action, args)
	return game


static func _hexes(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if raw is Array:
		for item: Variant in raw as Array:
			if item is Vector2i:
				out.append(item as Vector2i)
	return out
