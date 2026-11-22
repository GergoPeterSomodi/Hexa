## The soak's expected ranges and tables (docs/architecture/m8-build-spec.md 4.17): over a suite's game records, the table of measures
## against their ranges (starting values the tuning task measures and keeps), the per-country medians and the games' table, all as
## Markdown. A range is judged only over a full suite (FULL games: ai 100, passive 20, europe 4); a shorter run prints its values.
## Tools only.
@warning_ignore_start("integer_division")
class_name SoakRanges
extends RefCounted

const FULL := {"ai": 100, "passive": 20, "europe": 4}


## The rows {measure, value, range, ok (bool), judged (bool)} of the suite's ranges over `games`.
static func rows(suite: String, games: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var judged := games.size() >= int(FULL.get(suite, 1))
	var n := games.size()
	var played: Array = games.filter(func(r: Dictionary) -> bool: return int(r["played"]) > 0)
	if played.is_empty():
		return out
	match suite:
		"ai":
			var with_war := _count(played, func(r: Dictionary) -> bool: return int(r["wars"]) >= 1)
			_row(out, "games with a war declared", "%d of %d" % [with_war, n], ">= 80 %", with_war * 100 >= 80 * n, judged)
			_med(out, "wars declared a game (median)", played, "wars", 2.0, 12.0, judged)
			var ended := _total(played, "ended")
			var by_peace := _total(played, "ended_by_peace")
			_row(out, "ended wars ended by an AI's peace", "%d of %d" % [by_peace, ended], ">= 50 %", by_peace * 2 >= ended, judged)
			_med(out, "battles a game (median)", played, "battles", 2.0, 1e9, judged)
			_med(out, "largest country's land share, permille (median)", played, "share_max", 0.0, 300.0, judged)
			_row(out, "largest country's land share, permille (worst)", str(_max(played, "share_max")), "<= 600", _max(played, "share_max") <= 600, judged)
			var neg := _total(played, "negative")
			var cg := _total(played, "countries")
			_row(out, "country-games with a treasury under 0", "%d of %d" % [neg, cg], "<= 20 %", neg * 5 <= cg, judged)
			_row(out, "the largest treasury (worst)", str(_max(played, "treasury_max")), "<= 30000", _max(played, "treasury_max") <= 30000, judged)
			_med(out, "all people, permille of the start (median)", played, "people_permille", 900.0, 2000.0, judged)
			_med(out, "men under arms, permille of the people (median)", played, "men_permille", 5.0, 60.0, judged)
			_med(out, "works begun a country a year (median)", played, "works_per_country_year", 0.5, 1e9, judged)
			_med(out, "refused checks a seat a season (median)", played, "refused_per_seat", 0.0, 3.0, judged)
			_med(out, "order changes an army a season (median)", played, "orders_per_army", 0.0, 0.5, judged)
			_row(out, "the AI season, worst ms", "%.0f" % _fmax(played, "ai_ms_worst"), "<= 400", _fmax(played, "ai_ms_worst") <= 400.0, judged)
			_row(out, "the stats phase, worst ms", "%.1f" % _fmax(played, "stats_ms_worst"), "<= 60", _fmax(played, "stats_ms_worst") <= 60.0, judged)
			_row(out, "the save at the last season, worst bytes", str(_max(played, "save_bytes")), "<= 2000000", _max(played, "save_bytes") <= 2000000, judged)
			_med(out, "seasons the chronicle covers (median)", played, "chronicle_seasons", 24.0, 1e9, judged)
		"passive":
			var declared := _count(played, func(r: Dictionary) -> bool: return bool(r["passive_declared"]))
			var lost := _count(played, func(r: Dictionary) -> bool: return bool(r["passive_lost"]))
			_row(out, "a war declared on the passive seat", "%d of %d" % [declared, n], ">= 15 of 20", declared * 20 >= 15 * n, judged)
			_row(out, "the passive seat loses a war", "%d of %d" % [lost, n], ">= 5 of 20", lost * 20 >= 5 * n, judged)
		"europe":
			var mean := 0.0
			for r: Dictionary in played:
				mean += float(r["ai_ms_mean"])
			mean /= float(played.size())
			_row(out, "the AI season, mean ms", "%.0f" % mean, "<= 3000", mean <= 3000.0, judged)
	return out


## True when a judged row is outside its range.
static func failed(table: Array[Dictionary]) -> bool:
	for r: Dictionary in table:
		if bool(r["judged"]) and not bool(r["ok"]):
			return true
	return false


static func _row(out: Array[Dictionary], measure: String, value: String, range_text: String, ok: bool, judged: bool) -> void:
	out.append({"measure": measure, "value": value, "range": range_text, "ok": ok, "judged": judged})


static func _med(out: Array[Dictionary], measure: String, games: Array, key: String, low: float, high: float, judged: bool) -> void:
	var m := _median(games.map(func(r: Dictionary) -> float: return float(r[key])))
	var range_text := ">= %s" % str(low) if high >= 1e9 else ("<= %s" % str(high) if low <= 0.0 else "%s to %s" % [str(low), str(high)])
	_row(out, measure, "%.2f" % m, range_text, m >= low and m <= high, judged)


static func _count(games: Array, test: Callable) -> int:
	return games.filter(test).size()


static func _total(games: Array, key: String) -> int:
	var n := 0
	for r: Dictionary in games:
		n += int(r[key])
	return n


static func _max(games: Array, key: String) -> int:
	var n := 0
	for r: Dictionary in games:
		n = maxi(n, int(r[key]))
	return n


static func _fmax(games: Array, key: String) -> float:
	var n := 0.0
	for r: Dictionary in games:
		n = maxf(n, float(r[key]))
	return n


static func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])


# --- the tables -------------------------------------------------------------------------------------------------------------


## The Markdown of a suite: the ranges, the games, and for `ai` the per-country medians.
static func markdown(suite: String, games: Array, table: Array[Dictionary]) -> String:
	var out := "## Soak, suite %s: %d game(s)\n\n" % [suite, games.size()]
	out += "| Measure | Value | Range | |\n|---|---|---|---|\n"
	for r: Dictionary in table:
		var mark := "not judged" if not bool(r["judged"]) else ("ok" if bool(r["ok"]) else "OUT OF RANGE")
		out += "| %s | %s | %s | %s |\n" % [r["measure"], r["value"], r["range"], mark]
	out += "\n| Seed | Seasons | Wars | Battles | Land share % | People % | Men ‰ | AI ms worst | Result |\n|---|---|---|---|---|---|---|---|---|\n"
	for r: Dictionary in games:
		var failure: Array = r["failure"]
		var result := "ok" if failure.is_empty() else "BROKEN: " + str(failure[0])
		out += "| %d | %d | %d | %d | %.1f | %.0f | %d | %.0f | %s |\n" % [int(r["seed"]), int(r["played"]), int(r.get("wars", 0)),
			int(r.get("battles", 0)), float(r.get("share_max", 0)) / 10.0, float(r.get("people_permille", 0)) / 10.0,
			int(r.get("men_permille", 0)), float(r.get("ai_ms_worst", 0.0)), result]
	if suite != "europe":
		out += _countries(games)
	return out


## Per country over the games, the medians the tuning reads.
static func _countries(games: Array) -> String:
	var tags: Array[String] = []
	for r: Dictionary in games:
		if r.has("rows"):
			for tag: String in r["rows"]:
				if not tags.has(tag):
					tags.append(tag)
	if tags.is_empty():
		return ""
	var out := "\n| Country | Land 20 | Land 40 | Land 80 | Land end | Declared | Won | Lost | Treasury | Men | Works | Tax L/N/H % |\n"
	out += "|---|---|---|---|---|---|---|---|---|---|---|---|\n"
	for tag: String in tags:
		var cells: Array[String] = []
		for at: String in ["20", "40", "80"]:
			var lands: Array = []
			for r: Dictionary in games:
				var by_season: Dictionary = r.get("land_at", {})
				if by_season.has(at) and (by_season[at] as Dictionary).has(tag):
					lands.append(float(by_season[at][tag]))
			cells.append("%.0f" % _median(lands) if not lands.is_empty() else "-")
		var per := {"land": [], "declared": [], "won": [], "lost": [], "treasury": [], "men": [], "works": []}
		var tax := [0, 0, 0]
		for r: Dictionary in games:
			var row: Dictionary = (r.get("rows", {}) as Dictionary).get(tag, {})
			if row.is_empty():
				continue
			for key: String in per:
				(per[key] as Array).append(float(row[key]))
			for k: int in 3:
				tax[k] += int(row["tax"][k])
		var sum_tax := maxi(tax[0] + tax[1] + tax[2], 1)
		out += "| %s | %s | %s | %s | %.0f | %.0f | %.0f | %.0f | %.0f | %.0f | %.0f | %d/%d/%d |\n" % [tag, cells[0], cells[1], cells[2],
			_median(per["land"]), _median(per["declared"]), _median(per["won"]), _median(per["lost"]), _median(per["treasury"]),
			_median(per["men"]), _median(per["works"]), 100 * tax[0] / sum_tax, 100 * tax[1] / sum_tax, 100 * tax[2] / sum_tax]
	return out
