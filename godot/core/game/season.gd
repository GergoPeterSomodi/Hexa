## The season table (docs/architecture/m3-build-spec.md 4.2, 5.4): what happens, in order, when a season ends.
## M5's phases: production, income, works, people, stats, calendar (m5-build-spec.md 4.8). A milestone adds its rows
## where the spec's table puts them.
class_name Season
extends RefCounted

const PHASES: Array[StringName] = [&"production", &"income", &"works", &"people", &"stats", &"calendar"]


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
