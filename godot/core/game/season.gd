## The season table (docs/architecture/m3-build-spec.md 4.2, 5.4): what happens, in order, when a season ends.
## M6's phases (m6-build-spec.md 4.10, D39): movement, supply, production, income, works, people, stats, calendar, then
## ready_units and vision in the new turn (5.0 R1). A milestone adds its rows where the spec's table puts them.
## The armies' systems are called by reference (A14): a typed call from core/game into a system would make the two
## scripts need each other to parse.
class_name Season
extends RefCounted

const PHASES: Array[StringName] = [&"movement", &"supply", &"production", &"income", &"works", &"people", &"stats",
	&"calendar", &"ready_units", &"vision"]


## {ok, reason}: may the season end now?
static func end_check(game: Game) -> Dictionary:
	if game.has_countries() and game.player == &"":
		return {"ok": false, "reason": "choose your country first"}
	return {"ok": true, "reason": ""}


## The action log's end_season record.
static func begin(game: Game) -> void:
	game.action_log.append({"turn": game.turn, "action": "end_season", "args": {}})


static func run_phase(game: Game, phase: StringName) -> void:
	match phase:
		&"movement":
			MovementPhase.season.call(game)
		&"supply":
			Supply.season.call(game)
		&"production":
			EconomySeason.production(game)
		&"income":
			EconomySeason.income(game)
		&"works":
			Works.season(game)
		&"people":
			People.season(game)
		&"stats":
			StatsSystem.season(game)
		&"calendar":
			Calendar.season(game)
		&"ready_units":
			Military.refill.call(game)
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
