## The calendar (docs/architecture/m3-build-spec.md 4.1, 5.3): turn 1 is Spring of the start year, four seasons a year.
## Its phase adds one to the turn and nothing else.
class_name Calendar
extends RefCounted

const OWNS: Array[String] = ["turn"]
const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const SPRING := 0
const SUMMER := 1
const AUTUMN := 2
const WINTER := 3
const FIRST_TURN := 1
const DEFAULT_YEAR := 1480


## 0 Spring, 1 Summer, 2 Autumn, 3 Winter.
static func season_of(turn: int) -> int:
	return posmod(turn - 1, 4)


static func year_of(turn: int, start_year: int) -> int:
	return start_year + floori((turn - 1) / 4.0)


## The turn of a season in a year; the inverse of season_of and year_of.
static func turn_of(season_index: int, year: int, start_year: int) -> int:
	return (year - start_year) * 4 + season_index + 1


## "Winter 1480".
static func date_text(turn: int, start_year: int) -> String:
	return "%s %d" % [season_name(turn), year_of(turn, start_year)]


static func season_name(turn: int) -> String:
	return SEASON_NAMES[season_of(turn)]


static func is_winter(turn: int) -> bool:
	return season_of(turn) == WINTER


## The calendar phase: the next season.
static func season(game: Game) -> void:
	game.turn += 1
