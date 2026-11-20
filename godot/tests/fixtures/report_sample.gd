## Season report sample in the SeasonSummary.of shape (docs/architecture/game-feedback-screens.md A.3; style spec 6.4):
## the Genoa example with all nine sections, and a quiet season. Lets the report screen be drawn and tested without a
## game. Plain data: no game, no engine calls beyond Vector2i.
class_name ReportSample
extends RefCounted

const NO_HEX := Vector2i(-1, -1)
const SECTION_IDS: Array[StringName] = [&"glance", &"before", &"treasury", &"goods", &"works", &"people", &"orders",
	&"befell", &"standing"]


## The Genoa spring of A.3: nine sections, the top three lines marked, one line a link, one with an action.
static func genoa_spring() -> Dictionary:
	return {
		"turn": 3,
		"title": "Spring 1480",
		"next": "Summer 1480",
		"lede": "The Chancellor's report to the Doge of Genoa. Summer 1480 begins.",
		"seal_letter": "G",
		"quiet": false,
		"serious": true,
		"swing_permille": 0,
		"toast": "Spring 1480 ended: 1 work finished. J: the report",
		"sections": [
			_section(&"glance", "At a glance", [
				_line("Treasury", "good", {"detail": "1,240", "amount": 86}),
				_line("Grain", "good", {"detail": "320", "amount": 14}),
				_line("Fish", "good", {"detail": "64", "amount": 9}),
				_line("Wine", "bad", {"detail": "41", "amount": -6}),
				_line("Works", "good", {"detail": "1 done"}),
			], 5),
			_section(&"before", "Before Summer", [
				_line("Wine runs out in 6 seasons; the first vintage is Autumn 1481.", "bad", {
					"detail": "", "hex": Vector2i(7, 12), "action": [&"look_at", Vector2i(7, 12)],
					"action_label": "Go to (7, 12)", "rank": 0}),
				_line("A work slot is free: 1 of 2 in use.", "plain", {
					"action": [&"look_at", Vector2i(8, 13)], "action_label": "Show Genoa"}),
			], 2),
			_section(&"treasury", "Treasury", [
				_line("1,154 → 1,240", "good", {"amount": 86, "top": false}),
				_line("Taxes on people", "good", {"amount": 64, "rank": 64, "top": true}),
				_line("Taxes on goods", "good", {"amount": 52, "rank": 52, "top": true}),
				_line("Port dues, Genoa", "good", {"amount": 35, "rank": 35}),
				_line("District upkeep, 31 districts", "bad", {"amount": -16, "rank": 16}),
				_line("Walls of Genoa and Savona", "bad", {"amount": -9, "rank": 9}),
				_line("Vineyard begun above Savona (7, 12)", "bad", {
					"amount": -40, "rank": 40, "top": true, "hex": Vector2i(7, 12)}),
				_line("Left over each season +126; with your spending +86", "plain", {"sub": true}),
			], 7),
			_section(&"goods", "Goods", [
				_line("Grain 320 ▲ +14 (made 96, eaten 82)", "good", {"amount": 14, "rank": 14}),
				_line("Fish 64 ▲ +9 (caught 31, eaten 22)", "good", {"amount": 9, "rank": 9}),
				_line("Wine 41 ▼ −6 (made 0: the vines rest in spring; drunk 6)", "bad", {"amount": -6, "rank": 6}),
				_line("Timber 58 ▲ +4 (first cut at the Polcevera woods)", "good", {"amount": 4, "rank": 4}),
				_line("Salt 22 ▲ +3", "good", {"amount": 3, "rank": 3}),
			], 5, "Unchanged: stone, hemp"),
			_section(&"works", "Works", [
				_line("Finished: logging camp, Polcevera woods (9, 13), first stage. Brings timber +4 in spring, +6 in winter; upkeep −1.",
					"good", {"hex": Vector2i(9, 13), "rank": 3, "top": true}),
				_line("Under way: vineyard above Savona (7, 12), 1 of 4 seasons. Ready Spring 1481; first vintage Autumn 1481.",
					"plain", {"hex": Vector2i(7, 12), "rank": 2}),
			], 2),
			_section(&"people", "People", [
				_line("Genoa 62,000 ▲ +700 · Savona 14,000 ▲ +150 · the countryside 136,000 ▲ +450.",
					"plain", {"rank": 0}),
				_line("Food: 127 made for 104 eaten: fed, 23 to spare.", "good", {"rank": 0}),
			], 2),
			_section(&"orders", "Your orders", [
				_line("Built 1: vineyard above Savona.", "plain", {"hex": Vector2i(7, 12)}),
			], 1),
			_section(&"befell", "What befell Genoa", [
				_line("Milan finished a vineyard at (9, 11).", "plain", {"hex": Vector2i(9, 11)}),
				_line("The Duchy of Milan took 3 districts from the Republic of Venice: Bergamo (11, 8) and 2 more.",
					"warn", {"hex": Vector2i(11, 8)}),
			], 2),
			_section(&"standing", "Standing", [
				_line("Among the 6 countries you know: land 4th (38 districts), income 2nd (▲ +151 a season).",
					"plain", {}),
			], 1),
		],
	}


## A quiet season: one glance line (a link to the capital) and the before list; no other section.
static func quiet_season() -> Dictionary:
	return {
		"turn": 5,
		"title": "Summer 1480",
		"next": "Autumn 1480",
		"lede": "A quiet season.",
		"seal_letter": "G",
		"quiet": true,
		"serious": false,
		"swing_permille": 0,
		"toast": "Summer 1480 ended: a quiet season. J: the report",
		"sections": [
			_section(&"glance", "At a glance", [
				_line("2 works under way; nothing else of note.", "plain", {
					"hex": Vector2i(8, 13), "action": [&"look_at", Vector2i(8, 13)], "action_label": "Show Genoa"}),
			], 0),
		],
	}


## One section dictionary: id, title, count, total, lines, more, unchanged.
static func _section(id: StringName, title: String, lines: Array, count: int, unchanged: String = "") -> Dictionary:
	var typed: Array[Dictionary] = []
	for line: Variant in lines:
		typed.append(line as Dictionary)
	return {"id": id, "title": title, "count": count, "total": {}, "lines": typed, "more": 0, "unchanged": unchanged}


## One line dictionary with every key of the SeasonSummary line shape; `extra` overrides the defaults.
static func _line(text: String, tone: String, extra: Dictionary = {}) -> Dictionary:
	var line := {
		"text": text, "detail": "", "amount": 0, "unit": &"", "tone": tone, "value": 0, "from": 0, "to": 0,
		"hex": NO_HEX, "rank": 0, "top": false, "sub": false, "action": [], "action_label": "",
	}
	for key: String in extra:
		line[key] = extra[key]
	return line
