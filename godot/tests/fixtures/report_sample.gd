## Season report sample in the SeasonSummary.of shape (docs/architecture/game-feedback-screens.md A.3; style spec 6.4;
## docs/architecture/m4-build-spec.md 4.15 b): the Genoa example with all ten sections, and a quiet season. Lets the report screen be drawn and tested without a
## game. Plain data: no game, no engine calls beyond Vector2i.
class_name ReportSample
extends RefCounted

const NO_HEX := Vector2i(-1, -1)
const SECTION_IDS: Array[StringName] = [&"glance", &"before", &"treasury", &"goods", &"works", &"people", &"armies",
	&"war", &"orders", &"befell", &"standing"]


## The report of Spring 1480 on the economy fixture (docs/architecture/m4-build-spec.md 4.15 b), the vineyard at (7, 12)
## begun that season: ten sections, the top three lines marked, lines with links and actions. The People section is the one of M5's 4.11 (b); 4.15 b of M4 has
## no What befell, so that section is a fixture of M3.
static func genoa_spring() -> Dictionary:
	return {
		"turn": 1,
		"title": "Spring 1480",
		"next": "Summer 1480",
		"lede": "The Chancellor's report to the Doge of Genoa. Summer 1480 begins.",
		"seal_letter": "G",
		"quiet": false,
		"serious": false,
		"swing_permille": 78,
		"toast": "Spring 1480 ended: ▲ +48 ducats. J: the report",
		"sections": [
			_section(&"glance", "At a glance", [
				_line("Treasury", "good", {"detail": "658", "amount": 48, "value": 658}),
				_line("People", "good", {"detail": "83,205", "amount": 505, "value": 83205}),
				_line("Works", "plain", {"detail": "1 under way"}),
				_line("Wine", "bad", {"detail": "3", "amount": -1, "value": 3}),
				_line("Olive oil", "bad", {"detail": "3", "amount": -1, "value": 3}),
			], 5),
			_section(&"before", "Before Summer", [
				_line("Wine runs out in 4 seasons; the first vintage is Autumn 1481.", "warn", {
					"hex": Vector2i(7, 12), "action": [&"look_at", Vector2i(7, 12)], "action_label": "Go to (7, 12)"}),
				_line("Salt runs out in 4 seasons; none of your land makes it.", "warn", {
					"hex": Vector2i(8, 13), "action": [&"look_at", Vector2i(8, 13)], "action_label": "Show Genoa"}),
				_line("A work slot is free: 1 of 2 in use.", "warn", {
					"hex": Vector2i(8, 13), "action": [&"look_at", Vector2i(8, 13)], "action_label": "Show Genoa"}),
			], 3),
			_section(&"treasury", "Treasury", [
				_line("Taxes on people", "good", {"amount": 65, "rank": 65, "top": true}),
				_line("Taxes on goods", "good", {"amount": 7, "rank": 7}),
				_line("Port dues, Genoa", "good", {"amount": 30, "rank": 30}),
				_line("District upkeep, 4 districts", "bad", {"amount": -10, "rank": 10}),
				_line("Walls of Genoa", "bad", {"amount": -4, "rank": 4}),
				_line("Work begun: vineyard, first stage, near Savona (7, 12)", "bad", {
					"amount": -40, "rank": 40, "top": true, "hex": Vector2i(7, 12)}),
				_line("Left over each season", "good", {"amount": 88, "sub": true}),
				_line("With your spending", "good", {"amount": 48, "sub": true}),
			], 6, "", _line("610 → 658", "good", {"from": 610, "to": 658, "amount": 48})),
			_section(&"goods", "Goods", [
				_line("Wine 3", "bad", {"detail": "(drunk 1)", "amount": -1, "value": 3, "rank": 3}),
				_line("Olive oil 3", "bad", {"detail": "(used 1)", "amount": -1, "value": 3, "rank": 3}),
				_line("Salt 3", "bad", {"detail": "(used 1)", "amount": -1, "value": 3, "rank": 2}),
				_line("Timber 40", "plain", {"detail": "(made 6, sold 6)", "value": 40}),
				_line("Fish 0", "plain", {"detail": "(caught 6, eaten 4, sold 2)"}),
				_line("Grain 16", "plain", {"detail": "(made 3, sold 3)", "value": 16}),
			], 6, "Unchanged: stone, iron"),
			_section(&"works", "Works", [
				_line("Begun: vineyard, first stage, near Savona (7, 12). Ready Spring 1481. (−40 ducats)",
					"plain", {"hex": Vector2i(7, 12), "rank": 4, "top": true}),
			], 1),
			_section(&"people", "People", [
				_line("Genoa (8, 13) 30,300", "good", {"amount": 300, "hex": Vector2i(8, 13)}),
				_line("Savona (6, 13) 10,100", "good", {"amount": 100, "hex": Vector2i(6, 13)}),
				_line("The countryside, 12 places, 42,805", "good", {"amount": 105}),
				_line("Food: 9 made for 4 eaten. Fed, 5 to spare.", "good", {"sub": true}),
			], 3, "", _line("82,700 → 83,205", "good", {"from": 82700, "to": 83205, "amount": 505})),
			_section(&"armies", "Armies", [
				_line("Army of Genoa: Genoa (8, 13) → Savona (6, 13), 900 men.", "plain", {
					"hex": Vector2i(6, 13), "action": [&"select_army", 1]}),
				_line("Army of Genoa at (7, 12): 900 men ▼ −100, out of supply.", "bad", {
					"hex": Vector2i(7, 12), "action": [&"select_army", 1], "amount": -100, "top": true}),
				_line("Upkeep: 12 ducats a season.", "plain", {"sub": true}),
				_line("Your armies ate 1 grain from the stores.", "plain", {"sub": true}),
			], 4, "", _line("Men under arms 1,000 → 900", "bad", {"from": 1000, "to": 900, "amount": -100})),
			_section(&"war", "War", [
				_line("Battle of Alessandria, 1480: you won in 4 days. You lost 120 men, they 410.", "good", {
					"hex": Vector2i(7, 9), "action": [&"battle", 1], "action_label": "Open the battle", "rank": 410, "top": true}),
				_line("Siege of Pavia, 1480: 6 of 10, +2 a season; falls in about 2 seasons.", "good", {
					"hex": Vector2i(10, 9), "action": [&"look_at", Vector2i(10, 9)], "action_label": "Go to Pavia", "rank": 4}),
				_line("Milan besieges your Asti (8, 10): 3 of 10.", "bad", {
					"hex": Vector2i(8, 10), "action": [&"look_at", Vector2i(8, 10)], "action_label": "Go to Asti", "rank": 3}),
				_line("War score with Milan +2: you hold 2 of their districts, they hold none of yours.", "plain", {"sub": true}),
			], 4, "", _line("At war with 1 country", "plain")),
			_section(&"orders", "Your orders", [
				_line("Ordered to build: vineyard near Savona (7, 12).", "plain", {"hex": Vector2i(7, 12)}),
				_line("Ordered to march: the Army of Genoa to Savona (6, 13).", "plain", {"hex": Vector2i(6, 13)}),
				_line("Raised 2 companies of pikemen at Genoa (8, 13) (▼ −50).", "plain", {"hex": Vector2i(8, 13)}),
			], 3),
			_section(&"befell", "What befell Genoa", [
				_line("Milan finished a vineyard at (9, 11).", "plain", {"hex": Vector2i(9, 11)}),
				_line("The Duchy of Milan took 3 districts from the Republic of Venice: Bergamo (11, 8) and 2 more.",
					"warn", {"hex": Vector2i(11, 8)}),
				_line("A Milanese army of about 1,000 men stands at Alessandria (7, 9).", "plain", {
					"hex": Vector2i(7, 9), "action": [&"look_at", Vector2i(7, 9)]}),
			], 3),
			_section(&"standing", "Standing", [
				_line("Among the 3 countries you know, you are 3rd in land (14 districts), 3rd in income (+88 a season) and 3rd in people (83,205).",
					"plain", {}),
				_line("Savoy: about 58 districts, about +240, about 260,000 people.", "plain", {}),
				_line("Milan: about 52 districts, about +260, about 250,000 people.", "plain", {}),
			], 3),
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


## One section dictionary: id, title, count, total (a line, for the Treasury), lines, more, unchanged.
static func _section(id: StringName, title: String, lines: Array, count: int, unchanged: String = "",
		total: Dictionary = {}) -> Dictionary:
	var typed: Array[Dictionary] = []
	for line: Variant in lines:
		typed.append(line as Dictionary)
	return {"id": id, "title": title, "count": count, "total": total, "lines": typed, "more": 0, "unchanged": unchanged}


## One line dictionary with every key of the SeasonSummary line shape; `extra` overrides the defaults.
static func _line(text: String, tone: String, extra: Dictionary = {}) -> Dictionary:
	var line := {
		"text": text, "detail": "", "amount": 0, "unit": &"", "tone": tone, "value": 0, "from": 0, "to": 0,
		"hex": NO_HEX, "rank": 0, "top": false, "sub": false, "action": [], "action_label": "",
	}
	for key: String in extra:
		line[key] = extra[key]
	return line
