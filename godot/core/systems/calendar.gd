## The calendar (docs/architecture/m3-build-spec.md 4.1, 5.3; m4-build-spec.md 4.6): turn 1 is Spring of the start year,
## four seasons a year. Its phase adds one to the turn and draws the weather of the season that begins.
class_name Calendar
extends RefCounted

const OWNS: Array[String] = ["turn", "weather"]
## The climates in the order the weather is drawn and stored (snow, frost, mild), and where each is named.
const PLACES: Array[String] = ["in the high valleys", "inland", "on the coast"]
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


## The calendar phase: the next season, and its weather.
static func season(game: Game) -> void:
	game.turn += 1
	draw_weather(game)


## 4.6: one draw of luck.world for each climate in the order snow, frost, mild: calm up to the first odds, good up to the
## first two together, poor beyond. Nothing is drawn in a game without countries (the sandbox stays calm).
static func draw_weather(game: Game) -> void:
	if not game.has_countries() or game.defs == null or game.defs.weather_odds.size() != 3:
		return
	var odds := game.defs.weather_odds
	for climate: int in 3:
		var r := game.luck.world.randi_range(1, 100)
		var kind := 0
		if r > odds[0]:
			kind = 1 if r <= odds[0] + odds[1] else 2
		game.weather[climate] = kind


## 4.6: "Summer: good on the coast, poor in the high valleys (crops +20 %, −25 %)." for the season that is now: the
## climates where `tag` holds land and the weather is not calm; "" when all of it is calm.
static func weather_text(game: Game, tag: StringName) -> String:
	var c := Countries.by_tag(game, tag)
	if c == null or game.defs == null or game.defs.weather_permille.size() != 3:
		return ""
	var held: Array[bool] = [false, false, false]
	for i: int in Territory.districts(game, c.id):
		held[clampi(int(game.map.climate[i]), 0, 2)] = true
	var parts: PackedStringArray = []
	var effects: PackedStringArray = []
	for kind: int in [1, 2]:
		var places: PackedStringArray = []
		for climate: int in 3:
			if held[climate] and int(game.weather[climate]) == kind:
				places.append(PLACES[climate])
		if places.is_empty():
			continue
		parts.append("%s %s" % ["good" if kind == 1 else "poor", " and ".join(places)])
		@warning_ignore("integer_division")
		var percent := (game.defs.weather_permille[kind] - 1000) / 10
		var sign_text := "+" if percent >= 0 else "−"
		effects.append("%s%d %%" % [sign_text, absi(percent)])
	if parts.is_empty():
		return ""
	return "%s: %s (crops %s)." % [season_name(game.turn), ", ".join(parts), ", ".join(effects)]
