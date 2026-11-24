## What the player sees of the people (docs/architecture/m5-build-spec.md 5.6, 6.3, 4.19): a hex's people line with the fog
## (`at`), the outlook of a hex's people (`outlook`, the table of 6.3), the seasons until a hex is full (`seasons_to_full`),
## the ribbons of the last season (`ribbons`) and the sums of a country's people (`totals`, shared by the cards and the
## People page). Pure core/views/ code: reads the game, writes nothing, calls no engine; the sums are kept in the game's
## view cache.
class_name PeopleView
extends RefCounted

const UP := "▲"
const DOWN := "▼"
## Seasons `seasons_to_full` steps before it gives up.
const HORIZON := 400


## {} at sea, off the map, in a game without people; else {shown, exact, people, room, change (people_end - people_start,
## the last season's), text}. Yours (viewer is the owner): exact, "30,300 · room 45,000 · ▲ +300"; another country's hex the
## viewer has discovered (light fog too, R18): exact, the number alone; unowned land and the viewer "": exact, the number
## alone; "none" where no one can live; an undiscovered hex (D18, R18): shown false and nothing else (no text, no figures).
static func at(game: Game, viewer: StringName, hex: Vector2i) -> Dictionary:
	if game == null or game.map == null or game.state == null or game.defs == null or not game.map.has(hex):
		return {}
	var i := game.map.index_of(hex)
	if game.map.land[i] == 0 or game.state.people.size() != game.map.hex_count():
		return {}
	var owner_tag := Territory.owner_tag(game, hex) if game.has_countries() else &""
	var out := {"shown": true, "exact": true, "people": 0, "room": 0, "change": 0, "text": ""}
	if game.has_countries() and not Knowledge.discovered(game, viewer, hex):
		out["shown"] = false
		return out
	var foreign := owner_tag != &"" and viewer != &"" and owner_tag != viewer
	var people := int(game.state.people[i])
	var room := People.room_at(game, StateView.of(game.state), hex)
	if people == 0 and room == 0:
		out["text"] = "none"
		return out
	if foreign:
		out["people"] = people
		out["text"] = Words.number(people)
		return out
	out["people"] = people
	if owner_tag == &"" or viewer == &"":
		out["text"] = Words.number(people)
		return out
	var change := int(game.state.people_end[i]) - int(game.state.people_start[i])
	out["room"] = room
	out["change"] = change
	var text := "%s · room %s" % [Words.number(people), Words.number(room)]
	if change != 0:
		text += " · %s %s" % [UP if change > 0 else DOWN, Words.signed(change)]
	out["text"] = text
	return out


## {text, tone} for the hex's owner (the table of 6.3); {} at sea, off the map, on unowned land, in a game without people.
## The fog: with a player in a game with countries, only the player's own hexes have an outlook (others give {}); the
## viewer "" (no player, the sandbox) sees every hex.
static func outlook(game: Game, hex: Vector2i) -> Dictionary:
	if game == null or game.map == null or game.state == null or game.defs == null or not game.map.has(hex):
		return {}
	var i := game.map.index_of(hex)
	if game.map.land[i] == 0 or game.state.people.size() != game.map.hex_count():
		return {}
	var c := Countries.by_id(game, int(game.state.owner[i])) if game.has_countries() else null
	if game.has_countries() and c == null:
		return {}
	if c != null and game.player != &"" and c.tag != game.player:
		return {}
	var view := StateView.of(game.state)
	var room := People.room_i(game, view, i)
	var people := int(game.state.people[i])
	var fed := c.food_fed if c != null else 1000
	if room == 0 and people == 0:
		return _say("No one lives here.", &"plain")
	if game.state.main_use[i] != People.SETTLEMENTS:
		return _countryside(game, view, i, c, room, people, fed)
	if fed < 1000:
		return _say("Hungry: it loses people each season until your towns are fed.", &"bad")
	if game.state.work_at(hex) != null:
		return _say("A work is under way here.", &"plain")
	return _town(game, view, hex, room, people)


static func _say(text: String, tone: StringName) -> Dictionary:
	return {"text": text, "tone": tone}


static func _countryside(game: Game, view: StateView, i: int, c: Country, room: int, people: int, fed: int) -> Dictionary:
	var hex := game.map.hex_of(i)
	var step := People.change_at(game, view, hex, Calendar.season_of(game.turn), c.tax if c != null else 1, fed)
	if people > room:
		return _say("Crowded: about %s leave each season." % Words.number(-step.x), &"warn")
	if people == room:
		return _say("Full: the land holds %s." % Words.number(room), &"plain")
	var more := "Room for %s more" % Words.number(room - people)
	if step.y == People.GREW and step.x > 0:
		return _say("%s: about %s come each season." % [more, Words.number(step.x)], &"plain")
	return _say("%s: none come this season." % more, &"plain")


static func _town(game: Game, view: StateView, hex: Vector2i, room: int, people: int) -> Dictionary:
	var defs := game.defs
	var i := game.map.index_of(hex)
	var level := view.level_at(i)
	var fam := defs.family(People.SETTLEMENTS)
	if level < defs.people_top_level:
		var seen := view if people >= room else view.with_people({i: room})
		var verdict := People.grow_check(game, seen, hex, 1000)
		if bool(verdict["ok"]):
			var seasons := seasons_to_full(game, view, hex)
			var text := "Grows into %s at %s people" % [_word(level + 1), Words.number(room)]
			if seasons > 0:
				text += " (in about %s)" % Words.seasons(seasons)
			return _say(text + ".", &"good")
		var why := str(verdict["reason"])
		if int(verdict["rule"]) >= 0:
			why = ImproveRules.PAIR_WORDS[int(verdict["rule"])] % [Words.place(game, verdict["other"] as Vector2i),
				_name_of(game, hex)]
		return _say("Stays %s: %s" % [_word(level), why], &"plain")
	var full := people >= room
	var next_room := 0
	if fam != null and level + 1 < fam.room.size():
		next_room = fam.room[level + 1]
	var more := Words.number(room - people)
	match level:
		3:
			if full:
				return _say("Full at %s: walls would give it room (a work)." % Words.number(room), &"warn")
			return _say("Room for %s more; walls would give room for %s." % [more, Words.number(next_room)], &"plain")
		4:
			if full:
				return _say("Full at %s: a city would give it room (a work)." % Words.number(room), &"warn")
			return _say("Room for %s more; a city would give room for %s." % [more, Words.number(next_room)], &"plain")
	if full:
		return _say("Full: a city holds no more.", &"plain")
	return _say("Room for %s more." % more, &"plain")


## "a town", "a walled town" for a settlement level.
static func _word(level: int) -> String:
	var words: Array = FamilyIds.LEVEL_WORDS["settlements"]
	return "a %s" % str(words[clampi(level, 1, words.size() - 1)])


## The named place of a hex, else "this district".
static func _name_of(game: Game, hex: Vector2i) -> String:
	var named := str(Improve.place_of(game.map, hex).get("name", ""))
	return named if named != "" else "this district"


## Seasons until the people of the hex reach its room on the view, fed, stepping `People.change_at`'s rule at the owner's tax
## from game.turn; 0 when full already, -1 when they do not within HORIZON seasons (or never: no growth; or the hex is no land).
static func seasons_to_full(game: Game, view: StateView, hex: Vector2i) -> int:
	if game == null or game.map == null or game.state == null or game.defs == null or not game.map.has(hex):
		return -1
	var i := game.map.index_of(hex)
	if game.map.land[i] == 0:
		return -1
	var room := People.room_i(game, view, i)
	var crowd := view.people_at(i)
	var c := Countries.by_id(game, int(game.state.owner[i])) if game.has_countries() else null
	var tax := c.tax if c != null else 1
	if game.defs.growth_bp[clampi(tax, 0, 2)] <= 0:
		return 0 if crowd >= room else -1
	var settlement := view.main_use_at(i) == People.SETTLEMENTS
	var climate := int(game.map.climate[i])
	for n: int in HORIZON + 1:
		if crowd >= room:
			return n
		var rates := People.rates_of(game.defs, Economy.slot_for(climate, Calendar.season_of(game.turn + n)), tax)
		crowd += People.rule_of(game.defs, crowd, room, settlement, rates, 1000).x
	return -1


## [{hex, text, tone}] for the settlements of `tag` in the last season ended whose people moved by a hundredth or more, or
## lost people to hunger: "People +300" (good), "Hunger −120" (bad), "People −40" (bad, crowded out); index order.
## The fog: with a player in a game with countries, only the player's own tag has ribbons.
static func ribbons(game: Game, tag: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game != null and game.has_countries() and game.player != &"" and tag != game.player:
		return out
	var c := Countries.by_tag(game, tag) if game != null and game.state != null else null
	if c == null or game.state.people_start.size() != game.state.people.size():
		return out
	for i: int in Territory.districts(game, c.id):
		if game.state.main_use[i] != People.SETTLEMENTS:
			continue
		var start := int(game.state.people_start[i])
		var change := int(game.state.people_end[i]) - start
		var hunger := change < 0 and c.food_fed < 1000
		if change == 0 or (absi(change) * 100 < start and not hunger):
			continue
		out.append({"hex": game.map.hex_of(i), "text": "%s %s" % ["Hunger" if hunger else "People", Words.signed(change)],
			"tone": &"good" if change > 0 else &"bad"})
	return out


## The sums of a country's people, the game's own state (cached by [&"people_totals", version, turn, tag]): {} for an unknown
## country or a game without people; else {people, towns (in settlements), countryside, room, room_left (the sum of what
## each hex has room for), start, change (people_end - people_start over the hexes it holds now), towns_change,
## country_change, places (the countryside's hexes), country_room, country_start}.
static func totals(game: Game, tag: StringName) -> Dictionary:
	if game == null or game.view_cache == null or game.state == null or game.defs == null:
		return {}
	var key: Array = [&"people_totals", game.version, game.turn, tag]
	return (game.view_cache.get_or_make(key, func() -> Dictionary: return _make_totals(game, tag)) as Dictionary).duplicate()


static func _make_totals(game: Game, tag: StringName) -> Dictionary:
	var c := Countries.by_tag(game, tag)
	var s := game.state
	if c == null or s.people.size() != game.map.hex_count():
		return {}
	var out := {"people": 0, "towns": 0, "countryside": 0, "room": 0, "room_left": 0, "start": 0, "change": 0,
		"towns_change": 0, "country_change": 0, "places": 0, "country_room": 0, "country_start": 0}
	for i: int in Territory.districts(game, c.id):
		var p := int(s.people[i])
		var room := game.districts.room_of(game, i)
		var change := int(s.people_end[i]) - int(s.people_start[i])
		out["people"] += p
		out["room"] += room
		out["room_left"] += maxi(room - p, 0)
		out["start"] += int(s.people_start[i])
		out["change"] += change
		if s.main_use[i] == People.SETTLEMENTS:
			out["towns"] += p
			out["towns_change"] += change
		else:
			out["countryside"] += p
			out["country_change"] += change
			out["country_room"] += room
			out["country_start"] += int(s.people_start[i])
			out["places"] += 1
	return out
