## The season table (docs/architecture/m3-build-spec.md 4.2, 5.4): what happens, in order, when a season ends.
## M6's phases (m6-build-spec.md 4.10, D39): movement, supply, production, income, works, people, stats, calendar, then
## ready_units and vision in the new turn (5.0 R1). A milestone adds its rows where the spec's table puts them.
## M7 (m7-build-spec.md 4.13, thirteen): battles after movement, sieges after supply, war (the timer) after sieges and
## before production; ready_units refills, then recovers morale.
## Moves in the month (moves-build-spec.md R13, R40): ready_units also refills the move points and closes the season's moves
## (moved_from for the report, season_from cleared).
## The End-turn leg (R22a, GitHub issue 474, owner playtest 2026-11-27): march_on, after people and before stats, walks the
## standing marches that took no step in the movement phase one leg with the next season's points and rules
## (MovementPhase.next_leg, its battles fought there); ready_units keeps those points (Allowance.refill). So every End turn
## moves a marching army, after the season's supply and sieges, and the season's report, stats and battles show the leg.
## M8 (m8-build-spec.md 4.2, fourteen): ai_orders first, before movement; Game.orders (an OrdersHook, or null) gives the other
## countries' orders in it, in three calls the atomic and the sliced paths share (orders_begin, orders_step, orders_end).
## The armies' systems are called by reference (A14): a typed call from core/game into a system would make the two
## scripts need each other to parse.
class_name Season
extends RefCounted

const PHASES: Array[StringName] = [&"ai_orders", &"movement", &"battles", &"supply", &"sieges", &"war", &"production",
	&"income", &"works", &"people", &"march_on", &"stats", &"calendar", &"ready_units", &"vision"]


## {ok, reason}: may the season end now?
static func end_check(game: Game) -> Dictionary:
	if game.has_countries() and game.player == &"" and not game.ai_only:
		return {"ok": false, "reason": "choose your country first"}
	return {"ok": true, "reason": ""}


## The action log's end_season record.
static func begin(game: Game) -> void:
	game.action_log.append({"turn": game.turn, "action": "end_season", "args": {}})


## The hook's turn begins (nothing without a hook).
static func orders_begin(game: Game) -> void:
	if game.orders != null:
		game.orders.begin(game)


## One step of the hook's turn; true when the turn is over (always true without a hook).
static func orders_step(game: Game) -> bool:
	return game.orders == null or game.orders.step(game)


## The mark that ends the phase's records, in every game and every season (the replay's LogOrders reads up to it).
static func orders_end(game: Game) -> void:
	game.action_log.append({"turn": game.turn, "action": LogOrders.MARK, "args": {}})


static func run_phase(game: Game, phase: StringName) -> void:
	match phase:
		&"ai_orders":
			orders_begin(game)
			while not orders_step(game):
				pass
			orders_end(game)
		&"movement":
			MovementPhase.season.call(game)
		&"battles":
			Battles.season.call(game)
		&"supply":
			Supply.season.call(game)
		&"sieges":
			Sieges.season.call(game)
		&"war":
			Wars.season.call(game)
		&"production":
			EconomySeason.production(game)
		&"income":
			EconomySeason.income(game)
		&"works":
			Works.season(game)
		&"people":
			People.season(game)
		&"march_on":
			MovementPhase.next_leg.call(game)
		&"stats":
			StatsSystem.season(game)
		&"calendar":
			Calendar.season(game)
		&"ready_units":
			Military.refill.call(game)
			Armies.recover_morale.call(game)
			Allowance.refill.call(game)
			Armies.close_season.call(game)
		&"vision":
			Sight.season.call(game)


static func finish(game: Game) -> void:
	game.version += 1


## Checks, then ends the season: every phase in order. No drain (tools, tests and replay; Session drains).
static func run(game: Game) -> Dictionary:
	var verdict := end_check(game)
	if not bool(verdict["ok"]):
		return verdict
	begin(game)
	for phase: StringName in PHASES:
		run_phase(game, phase)
	finish(game)
	return verdict
