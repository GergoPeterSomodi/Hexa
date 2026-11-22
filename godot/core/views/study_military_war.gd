## The war part of the Military page's read model (docs/architecture/m7-build-spec.md 6.9; M7 B19): the viewer's wars (live first,
## then ended, newest first) and its last battles (the newest 12 it fought, kept records only). StudyMilitary asks for them;
## this file lives apart to keep that one small. Pure core/views/ code: it reads the game and writes nothing.
class_name StudyMilitaryWar
extends RefCounted

const BATTLE_ROWS := 12


## One row per war of `viewer`: {tag, country, since_text, state_text, score (the viewer's), won, lost (battles the viewer won and
## lost), yours_lost, theirs_lost (men booked), held_theirs, held_yours (districts the viewer holds of theirs, and they of
## its), tone (good, bad or plain by the score), war (the id)}.
static func wars(game: Game, viewer: StringName) -> Array[Dictionary]:
	var live: Array[Dictionary] = []
	var ended: Array[Dictionary] = []
	if game == null or game.state == null or not game.has_countries() or Countries.by_tag(game, viewer) == null:
		return live
	var all: Array[War] = Wars.of_country(game, viewer)
	for i: int in range(all.size() - 1, -1, -1):
		var row := _row(game, viewer, all[i])
		if all[i].live():
			live.append(row)
		else:
			ended.append(row)
	live.append_array(ended)
	return live


## The newest battles `viewer` fought (kept records): {record, name, result, yours_lost, theirs_lost, tone}.
static func battles(game: Game, viewer: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null or game.state == null or not game.has_countries() or Countries.by_tag(game, viewer) == null:
		return out
	var records: Array[BattleRecord] = Battles.records_of(game, viewer)
	for r: BattleRecord in records.slice(0, BATTLE_ROWS):
		var side := SummaryWar.SIDE_ATTACKER if r.attacker == viewer else SummaryWar.SIDE_DEFENDER
		var winner := int(r.end.get("winner", -1))
		var how := str(r.end.get("how", ""))
		var days := Words.plural(int(r.end.get("days", 0)), "day", "days")
		var result := ""
		var tone := "plain"
		if how == "peace":
			result = "the fight ended with the peace"
		elif winner == side:
			result = "you won in %s" % days
			tone = "good"
		elif winner < 0:
			result = "no side won in %s" % days
		else:
			result = "you lost in %s" % days
			tone = "bad"
		out.append({"record": r.id, "name": r.name, "result": result,
			"yours_lost": SummaryWar.men_booked(game, r, side),
			"theirs_lost": SummaryWar.men_booked(game, r, 1 - side), "tone": tone})
	return out


static func _row(game: Game, viewer: StringName, w: War) -> Dictionary:
	var enemy := w.other(viewer)
	var mine_a := w.a == viewer
	var score := Wars.score(game, viewer, enemy)
	var tone := "good" if score > 0 else ("bad" if score < 0 else "plain")
	return {
		"tag": enemy, "country": LogLines.short_name(game, enemy), "war": w.id,
		"since_text": Calendar.date_text(w.start_turn, game.start_year), "state_text": _state(game, viewer, w, enemy),
		"score": score,
		"won": w.won_a if mine_a else w.won_b, "lost": w.won_b if mine_a else w.won_a,
		"yours_lost": w.lost_a if mine_a else w.lost_b, "theirs_lost": w.lost_b if mine_a else w.lost_a,
		"held_theirs": Wars.occupied_count(game, viewer, enemy), "held_yours": Wars.occupied_count(game, enemy, viewer),
		"tone": tone if w.live() else "plain",
	}


## "at war"; "peace: took 2" or "peace: gave up 2" (a take or a yield, from the peace's own entry); "white peace"; "truce until
## Spring 1483" while an ended war's truce runs.
static func _state(game: Game, viewer: StringName, w: War, enemy: StringName) -> String:
	if w.live():
		return "at war"
	var truce := Wars.truce_until(game, viewer, enemy)
	if truce > game.turn:
		return "truce until %s" % Calendar.date_text(truce, game.start_year)
	match str(w.terms):
		"take", "yield":
			var actor := _actor_of(game, w.id)
			var took := (w.terms == &"take" and actor == viewer) or (w.terms == &"yield" and actor != viewer)
			return "peace: %s %s" % ["took" if took else "gave up", Words.number(w.moved)]
		"timer":
			return "the timer ended the war"
	return "white peace"


## The party that made the peace of war `id` (the actor of its peace_made entry); &"" when the chronicle keeps none.
static func _actor_of(game: Game, id: int) -> StringName:
	var entries := game.chronicle.entries
	for i: int in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i]
		if str(entry.get("kind", "")) == "peace_made" and int(entry.get("war", -1)) == id:
			return StringName(str(entry.get("tag", "")))
	return &""
