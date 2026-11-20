## The developer console's command table (docs/architecture/m3-build-spec.md section 6.13; m4-build-spec.md 6.11 adds money,
## goods and tax): `parse` reads a line into a plain description or a problem, `run` does it and returns the words to print.
## No node here: the console shows the text. After money and goods, which send no event, `run` asks the App to refresh the
## chips (request &"refresh_hud").
class_name DevCommands
extends RefCounted

const MAX_END := 40
const DIGEST_CHARS := 12
## A typed number has at most this many digits: 64-bit values never reach to_int or a Vector2i.
const MAX_DIGITS := 9
## The words after `look`: a season's index, or -1 for the calendar's own season.
const LOOK_WORDS: Dictionary[String, int] = {
	"spring": 0, "summer": 1, "autumn": 2, "winter": 3, "calendar": -1,
}
## The word for "no country" in `give`: the land is freed.
const FREE_WORD := "none"
const HELP_LINES: Array[String] = [
	"build c r family   upgrade c r   clear c r   cancel c r",
	"choose TAG   end [n]   goto c r   look spring|summer|autumn|winter|calendar",
	"give c r [c r ...] TAG|none   digest   seed   help",
	"money N [TAG]   goods KEY N [TAG]   tax low|normal|high",
]
## The tax words of `tax`, by level.
const TAX_WORDS: Array[String] = ["low", "normal", "high"]


## Reads a line: {kind, action, args, problem}. `kind` is &"act", &"end", &"goto", &"look", &"give", &"money", &"goods",
## &"digest", &"seed", &"help" or &"" (a problem, whose words are in `problem`).
static func parse(text: String, game: Game) -> Dictionary:
	var words := text.strip_edges().split(" ", false)
	if words.is_empty():
		return _problem("Type a command; help lists them.")
	var head := words[0].to_lower()
	var rest := words.slice(1)
	match head:
		"build":
			return _parse_build(rest, game)
		"upgrade", "clear", "cancel":
			return _parse_hex_act(head, rest, game)
		"choose":
			return _parse_choose(rest, game)
		"end":
			return _parse_end(rest, game)
		"goto":
			return _parse_goto(rest, game)
		"look":
			return _parse_look(rest, game)
		"give":
			return _parse_give(rest, game)
		"money":
			return _parse_money(rest, game)
		"goods":
			return _parse_goods(rest, game)
		"tax":
			return _parse_tax(rest, game)
		"digest", "seed", "help":
			if not rest.is_empty():
				return _problem("%s takes no arguments." % head)
			if head != "help" and game == null:
				return _problem("There is no game.")
			return _made(StringName(head), "", {})
	return _problem("Unknown command '%s'; help lists them." % words[0])


## Parses and does the line. Returns the text to print: the verdict of an action, a note of a request sent, or the problem.
static func run(text: String, ctx: ShellContext) -> String:
	var parsed := parse(text, Session.game)
	var problem := str(parsed["problem"])
	if not problem.is_empty():
		return problem
	var args: Dictionary = parsed["args"]
	match parsed["kind"] as StringName:
		&"act":
			var verdict := Session.act(str(parsed["action"]), args)
			if bool(verdict.get("ok", false)):
				return "Done: %s." % text.strip_edges()
			return "Refused: %s" % str(verdict.get("reason", ""))
		&"end":
			var count := int(args["count"])
			ctx.request(&"end_seasons", args)
			return "Ending %d season%s." % [count, "" if count == 1 else "s"]
		&"goto":
			ctx.request(&"look_at", args)
			var hex: Vector2i = args["hex"]
			return "Going to %d %d." % [hex.x, hex.y]
		&"look":
			ctx.request(&"dev_look", args)
			var season := int(args["season"])
			return "Looking at the calendar's season." if season < 0 else "Looking at %s." % LOOK_WORDS.find_key(season)
		&"give":
			var tag: StringName = args["tag"]
			var hexes: Array[Vector2i] = []
			hexes.assign(args["hexes"])
			var changed := Session.dev_transfer(hexes, tag)
			var to_words := "no one" if tag == &"" else String(tag)
			return "%d hex%s given to %s." % [changed, "" if changed == 1 else "es", to_words]
		&"money":
			var tag_m: StringName = args["tag"]
			var amount := int(args["amount"])
			var done := Session.dev_money(tag_m, amount)
			ctx.request(&"refresh_hud")
			if not done:
				return "Refused: %s has no treasury to change." % String(tag_m)
			return "Done: %s to %s." % [Words.signed_ducats(amount), String(tag_m)]
		&"goods":
			var tag_g: StringName = args["tag"]
			var loads := int(args["amount"])
			var good := int(args["good"])
			var made := Session.dev_goods(tag_g, good, loads)
			ctx.request(&"refresh_hud")
			if not made:
				return "Refused: %s has no stores to change." % String(tag_g)
			return "Done: %s %s to %s." % [Words.signed(loads), Session.game.defs.good(good).name.to_lower(), String(tag_g)]
		&"digest":
			return Session.game.digest().substr(0, DIGEST_CHARS)
		&"seed":
			return str(Session.game.seed_value)
		&"help":
			return "\n".join(HELP_LINES)
	return "Unknown command."


## A family's id from its name (ImproveRules.NAMES) or its number; 0 when there is none.
static func family_id(word: String) -> int:
	var low := word.to_lower()
	var at := ImproveRules.NAMES.find(low)
	if at > 0:
		return at
	if low.is_valid_int():
		var n := low.to_int()
		if n > 0 and n < ImproveRules.FAMILIES:
			return n
	return 0


static func _parse_build(rest: PackedStringArray, game: Game) -> Dictionary:
	if rest.size() != 3:
		return _problem("Use: build c r family")
	var hex: Variant = _hex_of(rest[0], rest[1], game)
	if hex == null:
		return _bad_hex(rest[0], rest[1], game)
	var family := family_id(rest[2])
	if family <= 0:
		return _problem("No family '%s'." % rest[2])
	return _made(&"act", "build", {"hex": hex, "family": family})


static func _parse_hex_act(head: String, rest: PackedStringArray, game: Game) -> Dictionary:
	if rest.size() != 2:
		return _problem("Use: %s c r" % head)
	var hex: Variant = _hex_of(rest[0], rest[1], game)
	if hex == null:
		return _bad_hex(rest[0], rest[1], game)
	var action := "cancel_work" if head == "cancel" else head
	return _made(&"act", action, {"hex": hex})


static func _parse_choose(rest: PackedStringArray, game: Game) -> Dictionary:
	if rest.size() != 1:
		return _problem("Use: choose TAG")
	if game == null or not game.has_countries():
		return _problem("This map has no countries.")
	var tag := StringName(rest[0].to_upper())
	if game.scenario.id_of(tag) == 0:
		return _problem("No country %s." % rest[0].to_upper())
	return _made(&"act", "choose_country", {"tag": tag})


static func _parse_end(rest: PackedStringArray, game: Game) -> Dictionary:
	if game == null:
		return _problem("There is no game.")
	var count := 1
	if rest.size() > 1:
		return _problem("Use: end [n]")
	if rest.size() == 1:
		if not rest[0].is_valid_int():
			return _problem("'%s' is not a number." % rest[0])
		if not is_small_int(rest[0]):
			return _problem("end takes 1 to %d seasons." % MAX_END)
		count = rest[0].to_int()
	if count < 1 or count > MAX_END:
		return _problem("end takes 1 to %d seasons." % MAX_END)
	return _made(&"end", "", {"count": count})


static func _parse_goto(rest: PackedStringArray, game: Game) -> Dictionary:
	if rest.size() != 2:
		return _problem("Use: goto c r")
	var hex: Variant = _hex_of(rest[0], rest[1], game)
	if hex == null:
		return _bad_hex(rest[0], rest[1], game)
	return _made(&"goto", "", {"hex": hex, "select": true})


static func _parse_look(rest: PackedStringArray, game: Game) -> Dictionary:
	if game == null:
		return _problem("There is no game.")
	if rest.size() != 1 or not LOOK_WORDS.has(rest[0].to_lower()):
		return _problem("Use: look spring|summer|autumn|winter|calendar")
	return _made(&"look", "", {"season": LOOK_WORDS[rest[0].to_lower()]})


static func _parse_give(rest: PackedStringArray, game: Game) -> Dictionary:
	if rest.size() < 3 or rest.size() % 2 == 0:
		return _problem("Use: give c r [c r ...] TAG")
	var word := rest[rest.size() - 1]
	var tag := &""
	if word.to_lower() != FREE_WORD:
		if game == null or not game.has_countries():
			return _problem("This map has no countries.")
		tag = StringName(word.to_upper())
		if game.scenario.id_of(tag) == 0:
			return _problem("No country %s." % word.to_upper())
	var hexes: Array[Vector2i] = []
	for i: int in range(0, rest.size() - 1, 2):
		var hex: Variant = _hex_of(rest[i], rest[i + 1], game)
		if hex == null:
			return _bad_hex(rest[i], rest[i + 1], game)
		hexes.append(hex as Vector2i)
	return _made(&"give", "", {"hexes": hexes, "tag": tag})


## `money N [TAG]`: ducats (a negative number takes them) for the player, or the country TAG.
static func _parse_money(rest: PackedStringArray, game: Game) -> Dictionary:
	if rest.is_empty() or rest.size() > 2:
		return _problem("Use: money N [TAG]")
	var shut := _economy_problem(game)
	if shut != "":
		return _problem(shut)
	if not is_small_int(rest[0]):
		return _problem("'%s' is not a number." % rest[0] if not rest[0].is_valid_int() else "'%s' is too large." % rest[0])
	var tag := _tag_word(rest[1] if rest.size() == 2 else "", game)
	if tag == &"":
		return _problem("No country %s." % rest[1] if rest.size() == 2 else "Choose your country first.")
	return _made(&"money", "", {"tag": tag, "amount": rest[0].to_int()})


## `goods KEY N [TAG]`: loads of a good (by its key: grain, salt, timber, ...) for the player, or the country TAG.
static func _parse_goods(rest: PackedStringArray, game: Game) -> Dictionary:
	if rest.size() < 2 or rest.size() > 3:
		return _problem("Use: goods KEY N [TAG]")
	var shut := _economy_problem(game)
	if shut != "":
		return _problem(shut)
	var good := game.defs.good_id(StringName(rest[0].to_lower()))
	if good < 0:
		return _problem("No good '%s'." % rest[0])
	if not is_small_int(rest[1]):
		return _problem("'%s' is not a number." % rest[1] if not rest[1].is_valid_int() else "'%s' is too large." % rest[1])
	var tag := _tag_word(rest[2] if rest.size() == 3 else "", game)
	if tag == &"":
		return _problem("No country %s." % rest[2] if rest.size() == 3 else "Choose your country first.")
	return _made(&"goods", "", {"tag": tag, "good": good, "amount": rest[1].to_int()})


## `tax low|normal|high`: the player's tax level, through the set_tax action.
static func _parse_tax(rest: PackedStringArray, game: Game) -> Dictionary:
	if rest.size() != 1 or not TAX_WORDS.has(rest[0].to_lower()):
		return _problem("Use: tax low|normal|high")
	var shut := _economy_problem(game)
	if shut != "":
		return _problem(shut)
	return _made(&"act", "set_tax", {"level": TAX_WORDS.find(rest[0].to_lower())})


## Why the money commands cannot run (no game, or a map without countries), else "".
static func _economy_problem(game: Game) -> String:
	if game == null:
		return "There is no game."
	if not game.has_countries():
		return "This map has no countries."
	return ""


## The country of an optional TAG word (upper-cased), the player when the word is "", &"" when there is none such.
static func _tag_word(word: String, game: Game) -> StringName:
	if word == "":
		return game.player
	var tag := StringName(word.to_upper())
	return tag if game.scenario.id_of(tag) != 0 else &""


## Whether the word is an integer of at most MAX_DIGITS digits (a sign does not count).
static func is_small_int(word: String) -> bool:
	if not word.is_valid_int():
		return false
	return word.lstrip("+-").length() <= MAX_DIGITS


## The hex of two words, or null when they are not numbers or lie off the map (or there is no game).
static func _hex_of(c_word: String, r_word: String, game: Game) -> Variant:
	if game == null or game.map == null or not is_small_int(c_word) or not is_small_int(r_word):
		return null
	var hex := Vector2i(c_word.to_int(), r_word.to_int())
	return hex if game.map.has(hex) else null


static func _bad_hex(c_word: String, r_word: String, game: Game) -> Dictionary:
	if game == null:
		return _problem("There is no game.")
	if not c_word.is_valid_int() or not r_word.is_valid_int():
		return _problem("'%s %s' is not a hex: use two numbers." % [c_word, r_word])
	if not is_small_int(c_word) or not is_small_int(r_word):
		return _problem("'%s %s' is not on the map: the numbers are too large." % [c_word, r_word])
	return _problem("Hex %s %s is not on the map." % [c_word, r_word])


static func _made(kind: StringName, action: String, args: Dictionary) -> Dictionary:
	return {"kind": kind, "action": action, "args": args, "problem": ""}


static func _problem(words: String) -> Dictionary:
	return {"kind": &"", "action": "", "args": {}, "problem": words}
