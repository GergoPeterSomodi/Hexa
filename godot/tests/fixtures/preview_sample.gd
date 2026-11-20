## Works-card samples in the ImprovePreview output shape (ui-style-and-feedback-spec.md section 7.1; m4-build-spec.md
## 4.15 c, d and e; both gain measures per 5.0 R2). Plain data: no game, no engine calls beyond Vector2i, so the card
## can be drawn and tested without a session.
##
## Where spec 4.15 gives no before and after level for a season (Genoa, (d)), the level is 0 and the after level is the
## gain, so the chart shows the gains only; the numbers are the spec's, the levels are not (see the report).
class_name PreviewSample
extends RefCounted


## 4.15 (c): the vineyard, first stage, near Savona (7, 12), in Spring 1480 (the fixture); accepted.
static func vineyard() -> Dictionary:
	return {
		"verdict": {"ok": true, "reason": ""},
		"blocked_by": &"",
		"title": "Vineyard, first stage",
		"subtitle": "near Savona (7, 12) · farmland, 665 m · frost winter · a river on the W edge",
		"reason_words": "",
		"brings": [
			{"field": &"wine", "label": "Wine", "before": 0, "after": 12, "per": &"year"},
			{"field": &"grain", "label": "Grain", "before": 6, "after": 2, "per": &"year"},
			{"field": &"jobs", "label": "Jobs", "before": 0, "after": 1000, "per": &""},
			{"field": &"upkeep", "label": "Upkeep, a season", "before": 0, "after": 1, "per": &""},
		],
		"by_season": [
			{"season": "Spring", "now": true, "note": "", "goods": [{"name": "grain", "before": 1, "after": 0}],
				"before": 96, "after": 94, "gain": -2, "gain_realm": -2, "gain_treasury": -1},
			{"season": "Summer", "now": false, "note": "", "goods": [{"name": "grain", "before": 3, "after": 1}],
				"before": 105, "after": 102, "gain": -3, "gain_realm": -3, "gain_treasury": -2},
			{"season": "Autumn", "now": false, "note": "", "goods": [{"name": "wine", "before": 0, "after": 12},
				{"name": "grain", "before": 2, "after": 1}],
				"before": 140, "after": 168, "gain": 28, "gain_realm": 28, "gain_treasury": 14},
			{"season": "Winter", "now": false, "note": "frost: nothing grows", "goods": [{"name": "wine", "before": 0, "after": 0}],
				"before": 170, "after": 169, "gain": -1, "gain_realm": -1, "gain_treasury": -1},
		],
		"year": {"before": 511, "after": 533, "gain": 22, "gain_realm": 22, "gain_treasury": 10},
		"lands": {
			"district": {"before": 6, "after": 32},
			"upkeep": 4,
			"ring": [{"text": "Ring of six: nothing changes"}],
			"country": {"before": 511, "after": 533},
		},
		"cost": {"text": "40 ducats · 4 seasons · ready Spring 1481 · first vintage Autumn 1481",
			"ducats": 40, "seasons": 4},
		"requirements": [
			{"text": "farmland or meadow, 100–900 m, no snow winter", "ok": true},
			{"text": "a free work slot: 0 of 2 in use", "ok": true},
			{"text": "40 of 610 ducats", "ok": true},
		],
		"payback": {
			"seasons": 10,
			"turn": 0,
			"text": "Pays back in Autumn 1482, 10 seasons from now (at today's prices).",
			"text_treasury": "Autumn 1484, 18 seasons from now.",
			"prestige": false,
		},
		"next_stages": [
			{"level": 2, "ok": true, "text": "Stage 2 possible (Savona (6, 13) 1 hex away)."},
			{"level": 3, "ok": true, "text": "stage 3 possible (a town within two hexes, under 1,200 m)."},
		],
		"chips": [{"text": "wine +12 a year", "amount": 12, "tone": &"good"}],
		"expensive": false,
	}


## 4.15 (d): Genoa, walled town to city, refused for money (610 of 1,000 ducats); the card shows everything with its
## refusal bar.
static func genoa_city_refused() -> Dictionary:
	return {
		"verdict": {"ok": false, "reason": "not enough ducats: 1,000 needed, 610 in the treasury"},
		"blocked_by": &"ducats",
		"title": "Genoa, walled town to city",
		"subtitle": "Genoa (8, 13) · woods, mild · a port",
		"reason_words": "",
		"brings": [
			{"field": &"people", "label": "People", "before": 30000, "after": 60000, "per": &"season"},
			{"field": &"tax", "label": "Taxes on people (the country)", "before": 65, "after": 95, "per": &"season"},
			{"field": &"port_dues", "label": "Port dues", "before": 30, "after": 45, "per": &"spring"},
			{"field": &"fish", "label": "Fish", "before": 6, "after": 10, "per": &"season"},
			{"field": &"food", "label": "Towns' food", "before": 4, "after": 7, "per": &"season"},
			{"field": &"upkeep", "label": "Upkeep and walls", "before": 6, "after": 11, "per": &"season"},
		],
		"by_season": [
			{"season": "Spring", "now": true, "note": "", "goods": [], "before": 0, "after": 45,
				"gain": 45, "gain_realm": 45, "gain_treasury": 40},
			{"season": "Summer", "now": false, "note": "", "goods": [], "before": 0, "after": 46,
				"gain": 46, "gain_realm": 46, "gain_treasury": 39},
			{"season": "Autumn", "now": false, "note": "", "goods": [], "before": 0, "after": 45,
				"gain": 45, "gain_realm": 45, "gain_treasury": 26},
			{"season": "Winter", "now": false, "note": "port dues 30 % lower", "goods": [], "before": 0, "after": 40,
				"gain": 40, "gain_realm": 40, "gain_treasury": 36},
		],
		"year": {"before": 557, "after": 733, "gain": 176, "gain_realm": 176, "gain_treasury": 141},
		"lands": {
			"district": {"before": 0, "after": 0},
			"upkeep": 5,
			"ring": [{"text": "timber near Genoa (9, 13): +1 a season, +2 in winter (the city's market)"}],
			"country": {"before": 557, "after": 733},
		},
		"cost": {"text": "1,000 ducats · 20 timber · 40 stone · 8 seasons · ready Spring 1482 if begun now",
			"ducats": 1000, "seasons": 8},
		"requirements": [
			{"text": "no other town beside it, no castle against its wall", "ok": true},
			{"text": "a free work slot", "ok": true},
			{"text": "1,000 of 610 ducats", "ok": false},
			{"text": "20 of 40 timber", "ok": true},
			{"text": "40 of 40 stone", "ok": true},
		],
		"payback": {
			"seasons": 32,
			"turn": 0,
			"text": "Pays back in Spring 1488, 32 seasons from now.",
			"text_treasury": "Summer 1489, 37 seasons from now.",
			"prestige": false,
		},
		"next_stages": [{"level": 3, "ok": false, "text": "None: Genoa is at its top level."}],
		"chips": [],
		"expensive": true,
	}


## 4.15 (e): Savona, town to walled town, refused by a rule: only the refusal shows.
static func savona_walls_refused() -> Dictionary:
	return {
		"verdict": {"ok": false, "reason": "settlements 3 at 5, 13: a town needs its own countryside"},
		"blocked_by": &"rule",
		"title": "Savona: town to walled town",
		"subtitle": "",
		"reason_words": "Cuneo (5, 13) is a town beside Savona: two towns may not stand side by side.",
		"brings": [],
		"by_season": [],
		"year": {},
		"lands": {},
		"cost": {"text": ""},
		"requirements": [],
		"payback": {},
		"next_stages": [],
		"chips": [],
		"expensive": false,
	}
