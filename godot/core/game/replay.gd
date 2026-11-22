## The replay (docs/architecture/m3-build-spec.md 4.5, 5.4): the same game started again and the action log played in
## order. The same seed and the same log give the same digest. M8 (4.15): an end_season record plays the AI records after it
## through a LogOrders (no AI runs), and a watch record through Game.watch. It needs a whole log (a trimmed save's is not).
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
	var i := 0
	while i < log.size():
		var record := log[i]
		i += 1
		var action := str(record.get("action", ""))
		var args: Dictionary = record["args"] if record.get("args") is Dictionary else {}
		match action:
			"end_season":
				# M8 (4.15): the AI's records after it are played by a LogOrders, which resumes the replay after the mark.
				var orders := LogOrders.over(log, i)
				game.orders = orders
				Season.run(game)
				game.orders = null
				i = orders.index()
			"orders_done":
				pass
			"watch":
				game.watch()
			"dev_money":
				game.dev_money(StringName(str(args.get("tag", ""))), int(args.get("amount", 0)))
			"dev_goods":
				game.dev_goods(StringName(str(args.get("tag", ""))), int(args.get("good", -1)), int(args.get("amount", 0)))
			"dev_people":
				game.dev_people(_hex(args.get("hex")), int(args.get("people", 0)))
			"dev_transfer":
				game.dev_transfer(_hexes(args.get("hexes")), int(args.get("to_id", 0)))
			_:
				game.act(action, args)
	return game


static func _hex(raw: Variant) -> Vector2i:
	return raw as Vector2i if raw is Vector2i else People.NO_HEX


static func _hexes(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if raw is Array:
		for item: Variant in raw as Array:
			if item is Vector2i:
				out.append(item as Vector2i)
	return out
