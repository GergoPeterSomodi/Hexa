## Works-card samples: the REAL ImprovePreview.of output (core/views/improve_preview.gd, 4.17) for the spec 4.15 (c), (d) and
## (e) cases, as literal data. Generated from the north Italy scenario (EconomyFixture.game): the vineyard at (7, 12) as a
## build of the vineyard family; Genoa (8, 13) as an upgrade to city (refused for money); Savona (6, 13) as an upgrade to a
## walled town (refused by a pair rule). Both gain measures are in every field (spec 5.0 R2).
## Plain data: no game, no engine calls beyond Vector2i and the typed array constructors, so the card can be drawn and
## tested without a session. When the preview's numbers change, regenerate these samples from ImprovePreview.of.
class_name PreviewSample
extends RefCounted

## 4.15 (c): the vineyard, first stage, near Savona (7, 12), in Spring 1480; accepted.
static func vineyard() -> Dictionary:
	return {
		"verdict": _vineyard_verdict(),
		"blocked_by": _vineyard_blocked_by(),
		"title": _vineyard_title(),
		"subtitle": _vineyard_subtitle(),
		"reason_words": _vineyard_reason_words(),
		"brings": _vineyard_brings(),
		"by_season": _vineyard_by_season(),
		"year": _vineyard_year(),
		"lands": _vineyard_lands(),
		"cost": _vineyard_cost(),
		"requirements": _vineyard_requirements(),
		"payback": _vineyard_payback(),
		"next_stages": _vineyard_next_stages(),
		"chips": _vineyard_chips(),
		"expensive": _vineyard_expensive(),
		"map_marks": _vineyard_map_marks(),
		"ghost": _vineyard_ghost(),
	}


static func _vineyard_verdict() -> Variant:
	return {
	"ok": true,
	"reason": ""
	}


static func _vineyard_blocked_by() -> Variant:
	return &""


static func _vineyard_title() -> Variant:
	return "Vineyard, first stage"


static func _vineyard_subtitle() -> Variant:
	return "near Savona (7, 12) · farmland, 665 m · frost winter · a river on the W edge"


static func _vineyard_reason_words() -> Variant:
	return ""


static func _vineyard_brings() -> Variant:
	return [{
	"after": 12,
	"before": 0,
	"field": &"wine",
	"label": "Wine",
	"per": &"year"
	}, {
	"after": 2,
	"before": 6,
	"field": &"grain",
	"label": "Grain",
	"per": &"year"
	}, {
	"after": 1000,
	"before": 0,
	"field": &"jobs",
	"label": "Jobs",
	"per": &""
	}, {
	"after": 1,
	"before": 0,
	"field": &"upkeep",
	"label": "Upkeep, a season",
	"per": &""
	}]


static func _vineyard_by_season() -> Variant:
	return [{
	"after": 94,
	"after_realm": 94,
	"after_treasury": 87,
	"before": 96,
	"before_realm": 96,
	"before_treasury": 88,
	"gain": -2,
	"gain_realm": -2,
	"gain_treasury": -1,
	"goods": [{
	"after": 0,
	"before": 1,
	"name": "grain"
	}],
	"note": "",
	"now": true,
	"season": "Spring",
	"turn": 1
	}, {
	"after": 102,
	"after_realm": 102,
	"after_treasury": 93,
	"before": 105,
	"before_realm": 105,
	"before_treasury": 95,
	"gain": -3,
	"gain_realm": -3,
	"gain_treasury": -2,
	"goods": [{
	"after": 1,
	"before": 3,
	"name": "grain"
	}],
	"note": "",
	"now": false,
	"season": "Summer",
	"turn": 2
	}, {
	"after": 168,
	"after_realm": 168,
	"after_treasury": 128,
	"before": 140,
	"before_realm": 140,
	"before_treasury": 114,
	"gain": 28,
	"gain_realm": 28,
	"gain_treasury": 14,
	"goods": [{
	"after": 12,
	"before": 0,
	"name": "wine"
	}, {
	"after": 1,
	"before": 2,
	"name": "grain"
	}],
	"note": "",
	"now": false,
	"season": "Autumn",
	"turn": 3
	}, {
	"after": 169,
	"after_realm": 169,
	"after_treasury": 135,
	"before": 170,
	"before_realm": 170,
	"before_treasury": 136,
	"gain": -1,
	"gain_realm": -1,
	"gain_treasury": -1,
	"goods": [],
	"note": "frost: nothing grows",
	"now": false,
	"season": "Winter",
	"turn": 4
	}]


static func _vineyard_year() -> Variant:
	return {
	"after": 533,
	"after_realm": 533,
	"after_treasury": 443,
	"before": 511,
	"before_realm": 511,
	"before_treasury": 433,
	"gain": 22,
	"gain_realm": 22,
	"gain_treasury": 10
	}


static func _vineyard_lands() -> Variant:
	return {
	"country": {
	"after": 533,
	"after_treasury": 443,
	"before": 511,
	"before_treasury": 433
	},
	"district": {
	"after": 32,
	"before": 6
	},
	"ring": [{
	"text": "Ring of six: nothing changes"
	}],
	"upkeep": 4
	}


static func _vineyard_cost() -> Variant:
	return {
	"ducats": 40,
	"first_yield_turn": 7,
	"goods": [],
	"ready_turn": 5,
	"seasons": 4,
	"text": "40 ducats · 4 seasons · ready Spring 1481 · first vintage Autumn 1481"
	}


static func _vineyard_requirements() -> Variant:
	return [{
	"ok": true,
	"text": "farmland or meadow, 100–900 m, no snow winter"
	}, {
	"ok": true,
	"text": "a free work slot: 0 of 2 in use"
	}, {
	"ok": true,
	"text": "40 of 610 ducats"
	}]


static func _vineyard_payback() -> Variant:
	return {
	"prestige": false,
	"prestige_treasury": false,
	"seasons": 10,
	"seasons_treasury": 18,
	"text": "Pays back in Autumn 1482, 10 seasons from now (at today's prices).",
	"text_treasury": "Autumn 1484, 18 seasons from now.",
	"turn": 11,
	"turn_treasury": 19
	}


static func _vineyard_next_stages() -> Variant:
	return [{
	"level": 2,
	"ok": true,
	"text": "Stage 2 possible (Savona (6, 13) 1 hex away)."
	}, {
	"level": 3,
	"ok": true,
	"text": "Stage 3 possible (a town within two hexes, under 1,200 m)."
	}]


static func _vineyard_chips() -> Variant:
	return [{
	"amount": 12,
	"amount_realm": 12,
	"amount_treasury": 12,
	"kind": &"good",
	"text": "wine +12 a year",
	"text_realm": "wine +12 a year",
	"text_treasury": "wine +12 a year",
	"tone": &"good"
	}, {
	"amount": 22,
	"amount_realm": 22,
	"amount_treasury": 10,
	"kind": &"gain",
	"text": "+22 a year",
	"text_realm": "+22 a year",
	"text_treasury": "+10 a year",
	"tone": &"good"
	}]


static func _vineyard_expensive() -> Variant:
	return false


static func _vineyard_map_marks() -> Variant:
	return {
	Vector2i(7, 12): {
	"delta": 22,
	"label": "+12 wine"
	}
	}


static func _vineyard_ghost() -> Variant:
	return {
	"hex": Vector2i(7, 12),
	"tiles": {
	"piece_back": "piece/vineyard/1/1/1/-/back",
	"piece_front": "piece/vineyard/1/1/1/-/front",
	"piece_ground": "piece/vineyard/1/1/1/-/ground",
	"piece_shadow": "piece/vineyard/1/1/1/-/shadow"
	}
	}

## 4.15 (d): Genoa, walled town to city, refused for money (610 of 1,000 ducats); the card shows everything with its refusal bar.
static func genoa_city_refused() -> Dictionary:
	return {
		"verdict": _genoa_city_refused_verdict(),
		"blocked_by": _genoa_city_refused_blocked_by(),
		"title": _genoa_city_refused_title(),
		"subtitle": _genoa_city_refused_subtitle(),
		"reason_words": _genoa_city_refused_reason_words(),
		"brings": _genoa_city_refused_brings(),
		"by_season": _genoa_city_refused_by_season(),
		"year": _genoa_city_refused_year(),
		"lands": _genoa_city_refused_lands(),
		"cost": _genoa_city_refused_cost(),
		"requirements": _genoa_city_refused_requirements(),
		"payback": _genoa_city_refused_payback(),
		"next_stages": _genoa_city_refused_next_stages(),
		"chips": _genoa_city_refused_chips(),
		"expensive": _genoa_city_refused_expensive(),
		"map_marks": _genoa_city_refused_map_marks(),
		"ghost": _genoa_city_refused_ghost(),
	}


static func _genoa_city_refused_verdict() -> Variant:
	return {
	"ok": false,
	"reason": "not enough ducats: 1000 needed, 610 in the treasury"
	}


static func _genoa_city_refused_blocked_by() -> Variant:
	return &"ducats"


static func _genoa_city_refused_title() -> Variant:
	return "Genoa, walled town to city"


static func _genoa_city_refused_subtitle() -> Variant:
	return "Genoa (8, 13) · woods, 368 m · mild winter · a stream on the E edge · a port"


static func _genoa_city_refused_reason_words() -> Variant:
	return "Not enough ducats: 1,000 needed, 610 in the treasury."


static func _genoa_city_refused_brings() -> Variant:
	return [{
	"after": 60000,
	"before": 30000,
	"field": &"people",
	"label": "People",
	"per": &"season"
	}, {
	"after": 95,
	"before": 65,
	"field": &"tax",
	"label": "Taxes on people (the country)",
	"per": &"season"
	}, {
	"after": 45,
	"before": 30,
	"field": &"port_dues",
	"label": "Port dues",
	"per": &"spring"
	}, {
	"after": 10,
	"before": 6,
	"field": &"fish",
	"label": "Fish",
	"per": &"season"
	}, {
	"after": 7,
	"before": 4,
	"field": &"food",
	"label": "Towns' food",
	"per": &"season"
	}, {
	"after": 11,
	"before": 6,
	"field": &"upkeep",
	"label": "Upkeep and walls",
	"per": &"season"
	}]


static func _genoa_city_refused_by_season() -> Variant:
	return [{
	"after": 138,
	"after_realm": 138,
	"after_treasury": 126,
	"before": 93,
	"before_realm": 93,
	"before_treasury": 86,
	"gain": 45,
	"gain_realm": 45,
	"gain_treasury": 40,
	"goods": [{
	"after": 10,
	"before": 6,
	"name": "fish"
	}],
	"note": "",
	"now": true,
	"season": "Spring",
	"turn": 1
	}, {
	"after": 146,
	"after_realm": 146,
	"after_treasury": 130,
	"before": 100,
	"before_realm": 100,
	"before_treasury": 91,
	"gain": 46,
	"gain_realm": 46,
	"gain_treasury": 39,
	"goods": [{
	"after": 10,
	"before": 6,
	"name": "fish"
	}],
	"note": "",
	"now": false,
	"season": "Summer",
	"turn": 2
	}, {
	"after": 241,
	"after_realm": 241,
	"after_treasury": 173,
	"before": 196,
	"before_realm": 196,
	"before_treasury": 147,
	"gain": 45,
	"gain_realm": 45,
	"gain_treasury": 26,
	"goods": [{
	"after": 10,
	"before": 6,
	"name": "fish"
	}],
	"note": "",
	"now": false,
	"season": "Autumn",
	"turn": 3
	}, {
	"after": 208,
	"after_realm": 208,
	"after_treasury": 170,
	"before": 168,
	"before_realm": 168,
	"before_treasury": 134,
	"gain": 40,
	"gain_realm": 40,
	"gain_treasury": 36,
	"goods": [{
	"after": 7,
	"before": 4,
	"name": "fish"
	}],
	"note": "port dues 30 % lower",
	"now": false,
	"season": "Winter",
	"turn": 4
	}]


static func _genoa_city_refused_year() -> Variant:
	return {
	"after": 733,
	"after_realm": 733,
	"after_treasury": 599,
	"before": 557,
	"before_realm": 557,
	"before_treasury": 458,
	"gain": 176,
	"gain_realm": 176,
	"gain_treasury": 141
	}


static func _genoa_city_refused_lands() -> Variant:
	return {
	"country": {
	"after": 733,
	"after_treasury": 599,
	"before": 557,
	"before_treasury": 458
	},
	"district": {
	"after": 207,
	"before": 136
	},
	"ring": [{
	"delta": 5,
	"foreign": false,
	"hex": Vector2i(9, 13),
	"name": "near Genoa (9, 13)",
	"text": "timber near Genoa (9, 13): +1 a season, +2 in winter (the city's market)"
	}],
	"upkeep": 20
	}


static func _genoa_city_refused_cost() -> Variant:
	return {
	"ducats": 1000,
	"first_yield_turn": 0,
	"goods": [{
	"good": &"timber",
	"n": 20,
	"name": "timber"
	}, {
	"good": &"stone",
	"n": 40,
	"name": "stone"
	}],
	"ready_turn": 9,
	"seasons": 8,
	"text": "1,000 ducats · 20 timber · 40 stone · 8 seasons · ready Spring 1482 if begun now"
	}


static func _genoa_city_refused_requirements() -> Variant:
	return [{
	"ok": true,
	"text": "no other town beside it"
	}, {
	"ok": true,
	"text": "no castle against a town's wall"
	}, {
	"ok": true,
	"text": "a free work slot: 0 of 2 in use"
	}, {
	"ok": false,
	"text": "1,000 of 610 ducats"
	}, {
	"ok": true,
	"text": "20 of 40 timber"
	}, {
	"ok": true,
	"text": "40 of 40 stone"
	}]


static func _genoa_city_refused_payback() -> Variant:
	return {
	"prestige": false,
	"prestige_treasury": false,
	"seasons": 32,
	"seasons_treasury": 37,
	"text": "Pays back in Spring 1488, 32 seasons from now (at today's prices).",
	"text_treasury": "Summer 1489, 37 seasons from now.",
	"turn": 33,
	"turn_treasury": 38
	}


static func _genoa_city_refused_next_stages() -> Variant:
	return [{
	"level": 5,
	"ok": false,
	"text": "None: Genoa is at its top level."
	}]


static func _genoa_city_refused_chips() -> Variant:
	return [{
	"amount": 176,
	"amount_realm": 176,
	"amount_treasury": 141,
	"kind": &"gain",
	"text": "+176 a year",
	"text_realm": "+176 a year",
	"text_treasury": "+141 a year",
	"tone": &"good"
	}, {
	"amount": 30000,
	"amount_realm": 30000,
	"amount_treasury": 30000,
	"kind": &"people",
	"text": "people +30,000",
	"text_realm": "people +30,000",
	"text_treasury": "people +30,000",
	"tone": &"good"
	}]


static func _genoa_city_refused_expensive() -> Variant:
	return true


static func _genoa_city_refused_map_marks() -> Variant:
	return {
	Vector2i(8, 13): {
	"delta": 51,
	"label": "+15 fish"
	},
	Vector2i(9, 13): {
	"delta": 5,
	"label": "+5 timber"
	}
	}


static func _genoa_city_refused_ghost() -> Variant:
	return {
	"hex": Vector2i(8, 13),
	"tiles": {
	"addon": "piece/harbour_addon/3/1/0/carved/front",
	"addon_ground": "piece/harbour_addon/3/1/0/carved/ground",
	"addon_shadow": "piece/harbour_addon/3/1/0/carved/shadow",
	"piece_back": "piece/settlements/5/1/0/-/back",
	"piece_front": "piece/settlements/5/1/0/-/front",
	"piece_ground": "piece/settlements/5/1/0/-/ground",
	"piece_shadow": "piece/settlements/5/1/0/-/shadow"
	}
	}

## 4.15 (e): Savona, town to walled town, refused by a rule: only the refusal shows.
static func savona_walls_refused() -> Dictionary:
	return {
		"verdict": _savona_walls_refused_verdict(),
		"blocked_by": _savona_walls_refused_blocked_by(),
		"title": _savona_walls_refused_title(),
		"subtitle": _savona_walls_refused_subtitle(),
		"reason_words": _savona_walls_refused_reason_words(),
		"brings": _savona_walls_refused_brings(),
		"by_season": _savona_walls_refused_by_season(),
		"year": _savona_walls_refused_year(),
		"lands": _savona_walls_refused_lands(),
		"cost": _savona_walls_refused_cost(),
		"requirements": _savona_walls_refused_requirements(),
		"payback": _savona_walls_refused_payback(),
		"next_stages": _savona_walls_refused_next_stages(),
		"chips": _savona_walls_refused_chips(),
		"expensive": _savona_walls_refused_expensive(),
		"map_marks": _savona_walls_refused_map_marks(),
		"ghost": _savona_walls_refused_ghost(),
	}


static func _savona_walls_refused_verdict() -> Variant:
	return {
	"ok": false,
	"reason": "a town needs its own countryside: no two towns side by side (settlements 3 at 5, 13)"
	}


static func _savona_walls_refused_blocked_by() -> Variant:
	return &"rule"


static func _savona_walls_refused_title() -> Variant:
	return "Savona, town to walled town"


static func _savona_walls_refused_subtitle() -> Variant:
	return "Savona (6, 13) · farmland, 363 m · frost winter · a river on the NW, W and SW edges"


static func _savona_walls_refused_reason_words() -> Variant:
	return "Cuneo (5, 13) is a town beside Savona: two towns may not stand side by side."


static func _savona_walls_refused_brings() -> Variant:
	return []


static func _savona_walls_refused_by_season() -> Variant:
	return []


static func _savona_walls_refused_year() -> Variant:
	return {}


static func _savona_walls_refused_lands() -> Variant:
	return {}


static func _savona_walls_refused_cost() -> Variant:
	return {
	"text": ""
	}


static func _savona_walls_refused_requirements() -> Variant:
	return []


static func _savona_walls_refused_payback() -> Variant:
	return {}


static func _savona_walls_refused_next_stages() -> Variant:
	return []


static func _savona_walls_refused_chips() -> Variant:
	return []


static func _savona_walls_refused_expensive() -> Variant:
	return false


static func _savona_walls_refused_map_marks() -> Variant:
	return {}


static func _savona_walls_refused_ghost() -> Variant:
	return {}
