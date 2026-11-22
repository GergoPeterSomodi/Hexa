## The Military page's read model (docs/architecture/m6-build-spec.md 5.6 and 6.9; L12): the head (men under arms, armies,
## companies, upkeep and its share of the income), the viewer's armies (its table, men descending), the foreign armies in
## sight (banded, no ids, no orders: 4.12) and the series of the charts over a span of seasons. Own country only: another
## country's tag, or a game without countries, gives the empty page (as StudyPeople). Pure core/views/ code: it reads the game
## and writes nothing. Cached in game.view_cache by [&"study_military", version, viewer, span].
class_name StudyMilitary
extends RefCounted

@warning_ignore_start("integer_division")

const SERIES: Array[String] = ["army_men", "upkeep_army", "losses", "army_starved", "battle_losses"]


## {has_data (a season has ended), head: {men, armies, units, upkeep (the army's upkeep a season now), share (permille of
## the last season's income before army upkeep that the army took), income (the last season's left-over income)},
## rows: [{id, name, place, hex, men, units, upkeep, supply_text, order_text, tone}] (own armies, men descending, ties by id),
## seen: [{tag, country, hex, place, men_text}] (foreign armies in sight, banded), labels (season titles of the series, oldest
## first), series: {army_men, upkeep_army, losses, army_starved, battle_losses, income} (PackedInt32Array; losses and starved as Stats
## keep them), wars and battles (M7: StudyMilitaryWar's rows)}.
static func of(game: Game, viewer: StringName, span: int) -> Dictionary:
	if game == null or game.view_cache == null or game.state == null or game.defs == null:
		return _empty()
	if game.has_countries() and viewer != game.player:
		return _empty()
	var key: Array = [&"study_military", game.version, viewer, span]
	var cached := game.view_cache.get_or_make(key, func() -> Dictionary: return _build(game, viewer, span)) as Dictionary
	return cached.duplicate(true)


static func _empty() -> Dictionary:
	var series: Dictionary = {"income": PackedInt32Array()}
	for name: String in SERIES:
		series[name] = PackedInt32Array()
	return {
		"has_data": false,
		"head": {"men": 0, "armies": 0, "units": 0, "upkeep": 0, "share": 0, "income": 0},
		"rows": [] as Array[Dictionary], "seen": [] as Array[Dictionary],
		"wars": [] as Array[Dictionary], "battles": [] as Array[Dictionary],
		"labels": [] as Array[String], "series": series,
	}


static func _build(game: Game, viewer: StringName, span: int) -> Dictionary:
	var out := _empty()
	if not game.has_countries() or Countries.by_tag(game, viewer) == null:
		return out
	var stats := game.stats
	var has_data := stats != null and stats.count > 0
	out["has_data"] = has_data
	var last := stats.last_turn if has_data else 0
	var income := StudyRankings.income_of(stats, viewer, last) if has_data else 0
	var upkeep_last := stats.value(viewer, last, "upkeep_army") if has_data else 0
	var units := 0
	for a: Army in Armies.of_country(game, viewer):
		units += a.units.size()
	out["head"] = {
		"men": Armies.men_of_country(game, viewer),
		"armies": Armies.of_country(game, viewer).size(),
		"units": units,
		"upkeep": Military.upkeep_country(game, viewer),
		"share": upkeep_last * 1000 / maxi(1, income + upkeep_last),
		"income": income,
	}
	out["rows"] = _rows(game, viewer)
	out["seen"] = _seen(game, viewer)
	out["wars"] = StudyMilitaryWar.wars(game, viewer)
	out["battles"] = StudyMilitaryWar.battles(game, viewer)
	_series(game, viewer, span, out)
	return out


## One row per army of the viewer: its place, men, companies, upkeep and its supply and order as the Army panel words them.
static func _rows(game: Game, viewer: StringName) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for a: Army in Armies.of_country(game, viewer):
		var panel := ArmyView.panel(game, viewer, a.id)
		var supply := panel.get("supply", {}) as Dictionary
		var order := panel.get("order", {}) as Dictionary
		var state := int(supply.get("state", Supply.FED))
		rows.append({"id": a.id, "name": a.name, "place": Words.place(game, a.hex), "hex": a.hex, "men": a.men(),
			"units": a.units.size(), "upkeep": Military.upkeep_of(game, a), "supply_text": str(supply.get("text", "")),
			"order_text": str(order.get("text", "")), "tone": _tone(state)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["men"]) != int(b["men"]):
			return int(a["men"]) > int(b["men"])
		return int(a["id"]) < int(b["id"]))
	return rows


## The foreign armies the viewer sees (its sight, and a country it knows): banded men, no army id.
static func _seen(game: Game, viewer: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in Knowledge.armies_seen(game, viewer):
		var a := item["army"] as Army
		if a == null or a.tag == viewer or not ArmyView.visible(game, viewer, a):
			continue
		out.append({"tag": a.tag, "country": LogLines.short_name(game, a.tag), "hex": a.hex,
			"place": Words.place(game, a.hex), "men_text": Knowledge.band_text(a.men(), "men")})
	return out


static func _tone(state: int) -> String:
	if state == Supply.HUNGRY:
		return "bad"
	return "warn" if state == Supply.FORAGED else "plain"


## The series over the last `span` seasons (oldest first) and their labels; the income is StudyRankings' (the left-over).
static func _series(game: Game, viewer: StringName, span: int, out: Dictionary) -> void:
	var stats := game.stats
	if stats == null or stats.count == 0 or stats.index_of(viewer) < 0:
		return
	var series: Dictionary = out["series"]
	for name: String in SERIES:
		series[name] = stats.series(viewer, name, span)
	var n := mini(mini(span, Stats.RING), stats.count)
	var labels: Array[String] = []
	var income := PackedInt32Array()
	for t: int in range(stats.last_turn - n + 1, stats.last_turn + 1):
		labels.append(Calendar.date_text(t, game.start_year))
		income.append(StudyRankings.income_of(stats, viewer, t))
	series["income"] = income
	out["labels"] = labels
