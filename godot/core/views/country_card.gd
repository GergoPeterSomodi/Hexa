## Country summary read model for CountryPanel and CountryPick (docs/architecture/m2-build-spec.md
## sections 5.7, 7.4, and 7.5). Pure core/views/ code: no nodes, no engine calls.
class_name CountryCard
extends RefCounted


## Summary dictionary for `tag` in `game`, or `{}` when `game` has no countries or `tag` is unknown.
static func of(game: Game, tag: StringName) -> Dictionary:
	if game == null or not game.has_countries() or game.map == null or game.state == null or tag == &"":
		return {}
	var country := Countries.by_tag(game, tag)
	if country == null:
		return {}
	var cdef := Countries.def_of(game, tag)
	var short_name := cdef.name if cdef != null and not cdef.name.is_empty() else String(country.tag)
	var long_name := cdef.long_name if cdef != null and not cdef.long_name.is_empty() else short_name
	var adjective := cdef.adjective if cdef != null else ""
	var colour := cdef.colour if cdef != null else Color()

	var dists := Territory.districts(game, country.id)
	var towns := 0
	var cities := 0
	var cover_counts: Dictionary[String, int] = {}
	for idx: int in dists:
		var cover_word := HexCard.cover_words(int(game.map.cover[idx]))
		cover_counts[cover_word] = int(cover_counts.get(cover_word, 0)) + 1
		if idx < game.state.main_use.size() and int(game.state.main_use[idx]) == ImproveRules.SETTLEMENT:
			towns += 1
			if idx < game.state.level.size() and int(game.state.level[idx]) >= 4:
				cities += 1

	return {
		"tag": country.tag,
		"name": short_name,
		"long_name": long_name,
		"adjective": adjective,
		"colour": colour,
		"arms": _arms_dict(game, cdef),
		"relation": _relation_of(game, country),
		"capital": _capital_dict(game, country, cdef, short_name),
		"focus": focus_hex(game, country),
		"districts": dists.size(),
		"towns": towns,
		"cities": cities,
		"land": _sorted_land(cover_counts),
		"neighbours": _neighbours_list(game, country.id),
		"passes": _passes_list(game, country.id),
		"playable": Countries.playable(game, country.tag),
		"play_reason": _play_reason(country, short_name, cdef),
		"tip": cdef.tip if cdef != null else "",
		"treasury": _treasury(game, country),
		"people": _people(game, country),
		"army": _army(game, country),
		"war": _war(game, country),
	}


## The war section of the country card (M7, 4.2, 4.9, 6.7), from the viewer's side. {state (&"none" with no player,
## &"self", &"war", &"truce", &"peace"), since_text, score (the viewer's, at war), held_theirs, held_yours (districts
## occupied either way, at war), truce_text, declare: {verdict} (not at war), peace: [{terms, label, verdict, moves, text}]
## (at war; take, white, yield), wars: [{tag, name}] and truces: [{tag, name, text}] (your own card only)}. Wars are public
## (4.15): the viewer sees every country's wars.
static func _war(game: Game, country: Country) -> Dictionary:
	var out := {"state": &"none", "since_text": "", "score": 0, "held_theirs": 0, "held_yours": 0, "truce_text": "",
		"declare": {}, "peace": [], "wars": [], "truces": []}
	var viewer := game.player
	if viewer == &"":
		return out
	if country.tag == viewer:
		out["state"] = &"self"
		out["wars"] = _own_wars(game, country)
		out["truces"] = _own_truces(game, country)
		return out
	var war := Wars.war_between(game, viewer, country.tag)
	if war != null:
		out["state"] = &"war"
		out["since_text"] = "At war since " + Calendar.date_text(war.start_turn, game.start_year)
		out["score"] = Wars.score(game, viewer, country.tag)
		out["held_theirs"] = Wars.occupied_count(game, viewer, country.tag)
		out["held_yours"] = Wars.occupied_count(game, country.tag, viewer)
		out["peace"] = _peace_options(game, viewer, war, country.tag)
		return out
	out["declare"] = {"verdict": Wars.declare_war_check(game, {"target": country.tag, "tag": viewer})}
	out["state"] = &"peace"
	var until := Wars.truce_until(game, viewer, country.tag)
	if until > game.turn:
		out["state"] = &"truce"
		out["truce_text"] = "Truce until %s (%d more seasons)" % [Calendar.date_text(until, game.start_year),
			until - game.turn]
	return out


const PEACE_TERMS: Array[StringName] = [&"take", &"white", &"yield"]
const PEACE_LABELS := {&"take": "Take what you hold", &"white": "White peace", &"yield": "Yield"}


## The three peace options at war, in PEACE_TERMS order: the verdict of make_peace_check and the districts that move (4.9).
static func _peace_options(game: Game, viewer: StringName, war: War, target: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for terms: StringName in PEACE_TERMS:
		var verdict := Wars.make_peace_check(game, {"target": target, "terms": terms, "tag": viewer})
		var moves: Array[Vector2i] = []
		if terms != &"white":
			moves = Wars.ceded(game, war, terms, viewer)
		out.append({"terms": terms, "label": PEACE_LABELS[terms], "verdict": verdict, "moves": moves,
			"text": _peace_text(game, target, terms, moves)})
	return out


## The sentence under a peace option: what moves, in the spec's words (4.9, 6.7).
static func _peace_text(game: Game, target: StringName, terms: StringName, moves: Array[Vector2i]) -> String:
	var who := "Peace with " + _the_name(game, target)
	if terms == &"white" or moves.is_empty():
		return "%s: everything returns to its owner." % who
	var names := _join_names(game, moves)
	var verb := "becomes" if moves.size() == 1 else "become"
	if terms == &"take":
		return "%s: %s %s yours; every other district returns." % [who, names, verb]
	return "%s: %s %s theirs." % [who, names, verb]


## "Domodossola (7, 6) and Locarno (7, 5)": the district names of the hexes, joined in the card's English.
static func _join_names(game: Game, hexes: Array[Vector2i]) -> String:
	var parts := PackedStringArray()
	for hex: Vector2i in hexes:
		var place_name := str(Improve.place_of(game.map, hex).get("name", ""))
		var label := "(%d, %d)" % [hex.x, hex.y]
		parts.append(label if place_name.is_empty() else "%s %s" % [place_name, label])
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[parts.size() - 1]


## The live wars of a country (your own card): {tag (the other party), name}, in war id order.
static func _own_wars(game: Game, country: Country) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: War in Wars.of_country(game, country.tag):
		if w.live():
			out.append({"tag": w.other(country.tag), "name": _short_name(game, w.other(country.tag))})
	return out


## The truces of a country (your own card): one row per other party with a truce still running.
static func _own_truces(game: Game, country: Country) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for w: War in Wars.of_country(game, country.tag):
		var other := w.other(country.tag)
		if w.live() or seen.has(other):
			continue
		seen[other] = true
		var until := Wars.truce_until(game, country.tag, other)
		if until > game.turn:
			out.append({"tag": other, "name": _short_name(game, other),
				"text": "Truce until %s" % Calendar.date_text(until, game.start_year)})
	return out


static func _short_name(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	return cdef.name if cdef != null and not cdef.name.is_empty() else String(tag)


## "the Duchy of Milan": the long name with its article (CountryDef.long_name, else the short name).
static func _the_name(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	if cdef != null and not cdef.long_name.is_empty():
		return "the " + cdef.long_name
	return "the " + _short_name(game, tag)


## The army field of the country panel (M6, 4.12): {shown, value, banded}. The player's own country: its men exact; a known
## foreign country: its men banded (Knowledge.band); an unknown country: not `shown`.
static func _army(game: Game, country: Country) -> Dictionary:
	var out := {"shown": false, "value": 0, "banded": false}
	if not Knowledge.knows(game, game.player, country.tag):
		return out
	var men := Armies.men_of_country(game, country.tag)
	out["shown"] = true
	if game.player != &"" and country.tag == game.player:
		out["value"] = men
	else:
		out["banded"] = true
		out["value"] = Knowledge.band(men)
	return out


## Focus hex for `country`: its on-map capital, or the label hex of its largest connected region.
static func focus_hex(game: Game, country: Country) -> Vector2i:
	if game == null or game.map == null or game.state == null or country == null:
		return Country.NO_HEX
	if country.capital != Country.NO_HEX:
		return country.capital
	var regs := ScenarioGrowth.regions(game.map, game.state.owner, country.id)
	if regs.is_empty():
		return Country.NO_HEX
	var best := regs[0]
	for reg: PackedInt32Array in regs:
		if reg.size() > best.size():
			best = reg
	return CountryNames.region_label_hex(game.map, best)


static func _arms_dict(game: Game, cdef: CountryDef) -> Dictionary:
	if cdef == null:
		return {"division": &"plain", "field": Color(), "charge": Color()}
	return {
		"division": cdef.arms_division,
		"field": _tincture_color(game, cdef.arms_field),
		"charge": _tincture_color(game, cdef.arms_charge),
	}


static func _tincture_color(game: Game, key: StringName) -> Color:
	if key == &"":
		return Color()
	if game != null and game.defs != null and game.defs.tinctures.has(key):
		return game.defs.tinctures[key]
	var defaults := GameDefs.default_tinctures()
	if defaults.has(key):
		return defaults[key]
	return Color()


static func _relation_of(game: Game, country: Country) -> StringName:
	if game.player != &"" and country.tag == game.player:
		return &"you"
	if country.capital == Country.NO_HEX:
		return &"outside"
	if game.player != &"":
		var player_c := Countries.by_tag(game, game.player)
		if player_c != null and Territory.neighbours(game, player_c.id).has(country.id):
			return &"neighbour"
	return &"other"


static func _capital_dict(game: Game, country: Country, cdef: CountryDef, short_name: String) -> Dictionary:
	if country.capital == Country.NO_HEX:
		var cap_name := cdef.capital_name if cdef != null and not cdef.capital_name.is_empty() else "off-map"
		return {"name": cap_name, "hex": Country.NO_HEX, "off_map": true}
	var place := Improve.place_of(game.map, country.capital)
	var cap_name := str(place.get("name", ""))
	if cap_name.is_empty():
		cap_name = cdef.capital_name if cdef != null and not cdef.capital_name.is_empty() else short_name
	return {"name": cap_name, "hex": country.capital, "off_map": false}


static func _sorted_land(cover_counts: Dictionary[String, int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cover_word: String in cover_counts.keys():
		out.append({"cover": cover_word, "count": cover_counts[cover_word]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca := int(a["count"])
		var cb := int(b["count"])
		if ca != cb:
			return ca > cb
		var sa := str(a["cover"])
		var sb := str(b["cover"])
		var ia := MapTiles.COVERS.find(sa)
		var ib := MapTiles.COVERS.find(sb)
		if ia >= 0 and ib >= 0 and ia != ib:
			return ia < ib
		return sa < sb)
	return out


static func _neighbours_list(game: Game, cid: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for nb_id: int in Territory.neighbours(game, cid):
		var nb := Countries.by_id(game, nb_id)
		if nb == null:
			continue
		var nb_def := Countries.def_of(game, nb.tag)
		var nb_name := nb_def.name if nb_def != null and not nb_def.name.is_empty() else String(nb.tag)
		out.append({"tag": nb.tag, "name": nb_name})
	return out


static func _passes_list(game: Game, cid: int) -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in game.map.passes:
		var hv: Variant = p.get("hex", Country.NO_HEX)
		if not (hv is Vector2i):
			continue
		if Territory.owner_id(game, hv as Vector2i) != cid:
			continue
		var pname := str(p.get("name", ""))
		if pname != "" and not out.has(pname):
			out.append(pname)
	return out


static func _play_reason(country: Country, short_name: String, cdef: CountryDef) -> String:
	if country.capital == Country.NO_HEX:
		var cap_name := cdef.capital_name if cdef != null and not cdef.capital_name.is_empty() else "off-map"
		return "%s cannot be played here: its capital, %s, is off this map" % [short_name, cap_name]
	if not country.alive:
		return "%s is no more" % short_name
	return ""


## The treasury fields of the country panel (spec 6.10). The viewer's own country: its exact treasury, last season's change
## (closing less opening in the closed ledger), the tax name, and `expected` (this season's net from EconomyPreview.expected,
## the treasury's measure; `expected_realm` the realm's, 5.0 R2; both null for any other country). A known foreign country (Knowledge.knows; every country for the viewer "") is banded to two figures in `value`,
## with no change and no tax. An unknown country is not `shown`.
static func _treasury(game: Game, country: Country) -> Dictionary:
	var out := {"shown": false, "value": 0, "banded": false, "change": 0, "expected": null, "expected_realm": null, "tax": ""}
	if not Knowledge.knows(game, game.player, country.tag):
		return out
	out["shown"] = true
	if game.player != &"" and country.tag == game.player:
		out["value"] = country.treasury
		out["change"] = _last_change(country)
		out["tax"] = Words.tax_name(country.tax)
		var now := EconomyPreview.expected(game, country.tag)
		if not now.is_empty():
			out["expected"] = int(now["net"])
			out["expected_realm"] = int(now["realm"])
	else:
		out["banded"] = true
		out["value"] = Knowledge.band(country.treasury)
	return out


## The last closed season's change of a country's treasury; 0 before the first season.
static func _last_change(country: Country) -> int:
	if country.ledger_closed.is_empty():
		return 0
	return int(country.ledger_closed["closing"]) - int(country.ledger_closed["opening"])


## The people fields of the country panel (spec 5.6, 4.19): {shown, value, banded, change}. The viewer's own country: exact, with
## last season's change; the viewer "" sees every country exact; a known foreign country is banded to two figures with no
## change; an unknown country is not `shown`.
static func _people(game: Game, country: Country) -> Dictionary:
	var out := {"shown": false, "value": 0, "banded": false, "change": 0}
	if not Knowledge.knows(game, game.player, country.tag):
		return out
	var sums := PeopleView.totals(game, country.tag)
	if sums.is_empty():
		return out
	out["shown"] = true
	if game.player == &"" or country.tag == game.player:
		out["value"] = int(sums["people"])
		out["change"] = int(sums["change"])
	else:
		out["banded"] = true
		out["value"] = Knowledge.band(int(sums["people"]))
	return out
