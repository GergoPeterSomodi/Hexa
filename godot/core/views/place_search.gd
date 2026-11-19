## Pure search index and ranking for places, countries, and mountain passes
## (docs/architecture/m2-build-spec.md sections 5.7 and 7.9).
## Pure core/views/ code: no nodes, no engine calls.
class_name PlaceSearch
extends RefCounted

const LIMIT := 8

const FOLD: Dictionary[String, String] = {
	"à": "a", "á": "a", "â": "a", "ä": "a",
	"è": "e", "é": "e", "ê": "e",
	"ì": "i", "í": "i",
	"ò": "o", "ó": "o", "ô": "o", "ö": "o",
	"ù": "u", "ú": "u", "ü": "u",
	"ç": "c", "ñ": "n", "ł": "l", "ń": "n", "ś": "s",
	"ź": "z", "ż": "z", "ı": "i", "ğ": "g", "ş": "s",
	"ø": "o", "å": "a", "ß": "ss",
}


## Lowercases `text`, folds European diacritics via `FOLD`, collapses spaces, and trims edges.
static func fold(text: String) -> String:
	var lowered := text.to_lower()
	var out := ""
	var prev_space := true
	for i: int in lowered.length():
		var cp := lowered.unicode_at(i)
		if cp >= 0x0300 and cp <= 0x036F:
			continue
		var ch := lowered[i]
		if ch == " " or ch == "\t" or ch == "\n" or ch == "\r":
			if not prev_space:
				out += " "
				prev_space = true
			continue
		prev_space = false
		out += FOLD[ch] if FOLD.has(ch) else ch
	if out.ends_with(" "):
		out = out.substr(0, out.length() - 1)
	return out


## Finds up to `limit` matching countries, named places, and passes in `game`, ranked by prefix,
## then word start, then substring; within a rank: countries, places by level desc, passes, name, hex index.
static func find(game: Game, text: String, limit: int = LIMIT) -> Array[Dictionary]:
	var query := fold(text)
	if query.is_empty() or limit <= 0 or game == null or game.map == null:
		return []
	var hits: Array[Dictionary] = []
	if game.has_countries():
		_collect_countries(game, query, hits)
	_collect_places(game, query, hits)
	_collect_passes(game, query, hits)
	hits.sort_custom(_compare_hits)
	var count := mini(hits.size(), limit)
	var out: Array[Dictionary] = []
	for i: int in count:
		out.append(hits[i]["entry"] as Dictionary)
	return out


static func _collect_countries(game: Game, query: String, hits: Array[Dictionary]) -> void:
	for country: Country in game.countries:
		if country == null:
			continue
		var cdef := Countries.def_of(game, country.tag)
		var cname := cdef.name if cdef != null and not cdef.name.is_empty() else String(country.tag)
		var folded := fold(cname)
		var rank := _match_rank(folded, query)
		if rank < 0:
			continue
		var hex := CountryCard.focus_hex(game, country)
		var districts := Territory.count(game, country.id)
		var detail := "country, %d %s" % [districts, "district" if districts == 1 else "districts"]
		hits.append({
			"entry": {
				"kind": &"country",
				"name": cname,
				"hex": hex,
				"tag": country.tag,
				"detail": detail,
			},
			"rank": rank,
			"kind_order": 0,
			"level": 0,
			"folded": folded,
			"hex_index": game.map.index_of(hex),
		})


static func _collect_places(game: Game, query: String, hits: Array[Dictionary]) -> void:
	for pl: Dictionary in game.map.places:
		var pname := str(pl.get("name", ""))
		if pname.strip_edges().is_empty():
			continue
		var hv: Variant = pl.get("hex", Country.NO_HEX)
		if not (hv is Vector2i):
			continue
		var hex := hv as Vector2i
		var idx := game.map.index_of(hex)
		if idx < 0:
			continue
		var folded := fold(pname)
		var rank := _match_rank(folded, query)
		if rank < 0:
			continue
		var lv := int(pl.get("level", 0))
		if game.state != null and idx < game.state.main_use.size() \
				and int(game.state.main_use[idx]) == ImproveRules.SETTLEMENT:
			lv = int(game.state.level[idx])
		var kind_word := _place_kind_word(pl, lv)
		var owner_tag := Territory.owner_tag(game, hex)
		var detail := kind_word
		if owner_tag != &"":
			detail = "%s, %s" % [kind_word, _owner_long_name(game, owner_tag)]
		elif game.has_countries():
			detail = "%s, no one" % kind_word
		hits.append({
			"entry": {
				"kind": &"place",
				"name": pname,
				"hex": hex,
				"tag": owner_tag,
				"detail": detail,
			},
			"rank": rank,
			"kind_order": 1,
			"level": lv,
			"folded": folded,
			"hex_index": idx,
		})


static func _collect_passes(game: Game, query: String, hits: Array[Dictionary]) -> void:
	for p: Dictionary in game.map.passes:
		var pname := str(p.get("name", ""))
		if pname.strip_edges().is_empty():
			continue
		var hv: Variant = p.get("hex", Country.NO_HEX)
		if not (hv is Vector2i):
			continue
		var hex := hv as Vector2i
		var idx := game.map.index_of(hex)
		if idx < 0:
			continue
		var folded := fold(pname)
		var rank := _match_rank(folded, query)
		if rank < 0:
			continue
		var metres := int(p.get("metres", 0))
		var detail := "pass, %s m" % _format_thousands(metres) if metres > 0 else "pass"
		hits.append({
			"entry": {
				"kind": &"pass",
				"name": pname,
				"hex": hex,
				"tag": Territory.owner_tag(game, hex),
				"detail": detail,
			},
			"rank": rank,
			"kind_order": 2,
			"level": 0,
			"folded": folded,
			"hex_index": idx,
		})


static func _place_kind_word(pl: Dictionary, lv: int) -> String:
	if lv >= 1:
		var w := HexCard.level_label("settlements", clampi(lv, 1, 5))
		return w if not w.is_empty() else "town"
	var castle := int(pl.get("castle", 0))
	if castle >= 1:
		var w := HexCard.level_label("castles", clampi(castle, 1, 3))
		return w if not w.is_empty() else "castle"
	var landmark := str(pl.get("landmark", ""))
	if not landmark.is_empty():
		return landmark
	return "place"


static func _owner_long_name(game: Game, tag: StringName) -> String:
	var cdef := Countries.def_of(game, tag)
	if cdef != null:
		if not cdef.long_name.is_empty():
			return cdef.long_name
		if not cdef.name.is_empty():
			return cdef.name
	return String(tag)


static func _match_rank(folded_name: String, query: String) -> int:
	if folded_name.begins_with(query):
		return 0
	if folded_name.contains(" " + query) or folded_name.contains("-" + query):
		return 1
	if folded_name.contains(query):
		return 2
	return -1


static func _compare_hits(a: Dictionary, b: Dictionary) -> bool:
	var ra := int(a["rank"])
	var rb := int(b["rank"])
	if ra != rb:
		return ra < rb
	var ka := int(a["kind_order"])
	var kb := int(b["kind_order"])
	if ka != kb:
		return ka < kb
	if ka == 1:
		var la := int(a["level"])
		var lb := int(b["level"])
		if la != lb:
			return la > lb
	var fa := str(a["folded"])
	var fb := str(b["folded"])
	if fa != fb:
		return fa < fb
	var na := str((a["entry"] as Dictionary)["name"])
	var nb := str((b["entry"] as Dictionary)["name"])
	if na != nb:
		return na < nb
	return int(a["hex_index"]) < int(b["hex_index"])


static func _format_thousands(value: int) -> String:
	var raw := str(absi(value))
	var out := ""
	var count := 0
	for i: int in range(raw.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = raw[i] + out
		count += 1
	return ("-" + out) if value < 0 else out
