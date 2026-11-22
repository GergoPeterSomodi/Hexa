## The three war reminders of the task flag and the report's "Before" section (docs/architecture/m7-build-spec.md 4.18; M7 B19):
## `besieged` (a fortress of the player is besieged: severity 2), `occupied` (an enemy holds districts of the player: 1, one line
## an enemy) and `war_timer` (a war of the player has lasted the warning's seasons: 1). Reminders' _build asks for them in the
## order of its RULES; this file lives apart to keep that one small. Pure core/views/ code: it reads the game and writes nothing.
class_name RemindersWar
extends RefCounted


## {} when no fortress of `tag` is besieged; else one line: "Pavia (10, 9) is besieged by Savoy: 6 of 10; it falls in about 1
## season." (two or more: "2 of your fortresses are besieged: Pavia (10, 9) and 1 more.").
static func besieged(game: Game, tag: StringName) -> Dictionary:
	if game == null or game.state == null or not game.has_countries() or Countries.by_tag(game, tag) == null:
		return {}
	var mine: Array[Siege] = []
	for s: Siege in game.sieges:
		if Occupation.controller_tag(game, s.hex) == tag and Occupation.besieged(game, s.hex):
			mine.append(s)
	if mine.is_empty():
		return {}
	var first := mine[0]
	var text := ""
	if mine.size() == 1:
		var view := SiegeView.at(game, tag, first.hex)
		var falls := ""
		if int(view.get("falls_in", -1)) > 0:
			falls = "; it falls in about %s" % Words.seasons(int(view["falls_in"]))
		text = "%s is besieged by %s: %s of %s%s." % [Words.place(game, first.hex), LogLines.short_name(game, first.besieger),
			Words.number(first.progress), Words.number(int(view.get("need", 0))), falls]
	else:
		text = "%s of your fortresses are besieged: %s and %s more." % [Words.number(mine.size()),
			Words.place(game, first.hex), Words.number(mine.size() - 1)]
	return {
		"kind": &"besieged", "severity": 2, "text": text, "hint": "", "hex": first.hex,
		"action": [&"look_at", first.hex], "action_label": "Go to %s" % SummaryWar.plain_place(game, first.hex),
	}


## One line per enemy that holds districts of `tag`: "The Duchy of Milan holds 2 of your districts: Asti (8, 10) and 1 more."
static func occupied(game: Game, tag: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null or game.state == null or not game.has_countries() or Countries.by_tag(game, tag) == null:
		return out
	var held := Countries.by_tag(game, tag)
	for enemy: StringName in Wars.enemies(game, tag):
		var count := Wars.occupied_count(game, enemy, tag)
		if count <= 0:
			continue
		var occupant := Countries.by_tag(game, enemy)
		var first := WorksView.NO_HEX
		for i: int in Territory.districts(game, held.id):
			if i < game.state.occupier.size() and int(game.state.occupier[i]) == occupant.id:
				first = game.map.hex_of(i)
				break
		var noun := "district" if count == 1 else "districts"
		var more := " and %s more" % Words.number(count - 1) if count > 1 else ""
		var text := "%s holds %s of your %s: %s%s." % [LogLines.capital(Words.country_the(game, enemy)), Words.number(count),
			noun, Words.place(game, first), more]
		out.append({
			"kind": &"occupied", "severity": 1, "text": text, "hint": "", "hex": first,
			"action": [&"look_at", first], "action_label": "Show the district",
		})
	return out


## One line per live war of `tag` that has lasted `war_timer_warning` seasons or more: "The war with the Duchy of Milan ends in a
## white peace in 8 seasons." (the timer is `war_timer_seasons` from its declaration).
static func war_timer(game: Game, tag: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null or game.state == null or not game.has_countries() or game.defs == null or game.defs.war == null:
		return out
	var numbers := game.defs.war
	for w: War in Wars.of_country(game, tag):
		if not w.live():
			continue
		var lasted := game.turn - w.start_turn
		if lasted < numbers.war_timer_warning:
			continue
		var enemy := w.other(tag)
		var left := maxi(w.start_turn + numbers.war_timer_seasons - game.turn, 1)
		out.append({
			"kind": &"war_timer", "severity": 1,
			"text": "The war with %s ends in a white peace in %s." % [Words.country_the(game, enemy), Words.seasons(left)],
			"hint": "", "hex": WorksView.NO_HEX, "action": [&"country", enemy],
			"action_label": "Show %s" % LogLines.short_name(game, enemy),
		})
	return out

