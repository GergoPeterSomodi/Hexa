## The odds card of a march (docs/architecture/m7-build-spec.md 4.6, 4.7, 4.15, 5.6, 6.4; M7 B23). For an army of the viewer and a
## target hex it gives what the march would be and the word of its odds: an attack on an enemy army (&"attack"), a siege of a
## fortress with a garrison (&"siege"), a storm of one (&"storm", the storm flag), a walk in on open or fallen land (&"walk_in"),
## a walk in on land a standing castle holds (&"held": it moves in but cannot take it), or none (&"none"). The word is Combat's
## odds (strength ratio over the ground factor; the garrison's weight behind a field army or alone, D50). Fog: the viewer's own
## army exact; an enemy army the viewer sees is banded and its morale rounded to 5 %; a garrison the viewer sees is rounded to
## 100 (exact for its owner and for the viewer ""); a hidden defender gives no number and no word (4.15). A refusal is the
## check's reason, in sentences. Pure core/views/ code: a function of the game and the viewer; no nodes, no engine calls, no luck.
@warning_ignore_start("integer_division")
class_name OddsView
extends RefCounted

const KIND_ATTACK := &"attack"
const KIND_SIEGE := &"siege"
const KIND_STORM := &"storm"
const KIND_WALK_IN := &"walk_in"
const KIND_HELD := &"held"
const KIND_NONE := &"none"
const ACCESS_EXACT := &"exact"
const ACCESS_SEEN := &"seen"
const ACCESS_HIDDEN := &"hidden"
const TONE_GOOD := &"good"
const TONE_BAD := &"bad"
const TONE_PLAIN := &"plain"
const ROUND_MEN := 100
const ROUND_MORALE := 50
const PERCENT := 10
const UNIT := 1000
const MINUS := "−"
const NO_WORD := ""
const TOO_FEW_TEXT := "too few men to take it"
const OPEN_KEY := "open"
const WHOLE := -1


## The odds card of the army `army_id` of `viewer` against `hex`; with `storm`, the storm's card. Keys: kind, ok, reason,
## title (the place), kind_text ("Attack · Favourable"), word, tone, notes ([String]), hint, ratio_permille (-1 unless a battle
## is worked out), factor_permille, attack {men, morale, strength}, defence {access, men, morale, strength, garrison {men,
## weight_permille, cut}}, chips ([{text, helps}]), besiege {seasons, need, rate, stores, too_few_text}, storm_word, opens
## (districts a fortress taken opens), held_by {hex, name, distance}. {} for a viewer "" or no countries. Cached in the view
## cache by [&"odds", version, viewer, army, hex, storm].
## `stand` is the hex the army strikes from (the penultimate hex of its route; the army's own hex when NO_HEX): the uphill and
## the crossing chips read it. A hex the viewer does not see (Knowledge.sees, or not its own land nor held by it) gives the
## same card as any unseen hex: kind none, no numbers, no words (4.15).
static func of(game: Game, viewer: StringName, army_id: int, hex: Vector2i, storm: bool = false,
		stand: Vector2i = Army.NO_HEX) -> Dictionary:
	if game == null or game.map == null or game.defs == null or game.defs.war == null or not game.has_countries() \
			or viewer == &"":
		return {}
	var key: Array = [&"odds", game.version, viewer, army_id, hex, storm, stand]
	return game.view_cache.get_or_make(key, func() -> Dictionary: return _make(game, viewer, army_id, hex, storm, stand)) as Dictionary


## The odds word of a value (ratio x 1,000 / factor, in permille): Combat.odds_word with the game's war numbers.
static func word(game: Game, ratio_over_factor_permille: int) -> String:
	return Combat.odds_word(game.defs.war, ratio_over_factor_permille)


static func _make(game: Game, viewer: StringName, army_id: int, hex: Vector2i, storm: bool, stand: Vector2i) -> Dictionary:
	var a := Armies.by_id(game, army_id)
	if a == null or a.tag != viewer:
		return _shell(game, hex, KIND_NONE, false, "no army of yours")
	if game.map.index_of(hex) < 0 or not game.map.is_land(hex):
		return _shell(game, hex, KIND_NONE, false, "no way there by land")
	if not _in_view(game, viewer, hex):
		return _shell(game, hex, KIND_NONE, false, "")
	var from := stand if stand != Army.NO_HEX else a.hex
	var kind := _kind_of(game, viewer, hex, storm)
	var by_storm := storm and kind != KIND_ATTACK
	var verdict: Dictionary = Movement.storm_check(game, {"army": a.id, "goal": hex, "tag": viewer}) if by_storm \
		else Movement.march_check(game, {"army": a.id, "goal": hex, "tag": viewer})
	var ok := bool(verdict.ok)
	var reason := "" if ok else _sentence(str(verdict.reason))
	if not ok and str(verdict.reason).to_lower().begins_with("too shaken"):
		reason = _shaken_sentences(game, a)
	var out := _shell(game, hex, kind, ok, reason)
	if kind != KIND_NONE:
		_fill(game, viewer, a, hex, kind, out, from)
	return out


## What a march of the viewer to hex would be (4.7): an enemy army on it, a hostile fortress with men (a siege or, with the
## storm flag, a storm), hostile land a standing castle holds (held), other hostile land (walk in), or none.
static func _kind_of(game: Game, viewer: StringName, hex: Vector2i, storm: bool) -> StringName:
	if not _enemies_at(game, viewer, hex).is_empty():
		return KIND_ATTACK
	var holder := Occupation.controller_tag(game, hex)
	if holder == &"" or holder == viewer or not Wars.at_war(game, viewer, holder):
		return KIND_NONE
	var fortress := Occupation.fortress_level(game, hex) > 0
	var garrisoned := _garrisoned(game, viewer, hex)
	if storm:
		return KIND_STORM if fortress and garrisoned else KIND_NONE
	if fortress and garrisoned:
		return KIND_SIEGE
	if fortress:
		return KIND_WALK_IN
	var held := AreaLines.held_by(game, hex)
	return KIND_HELD if held["state"] == &"held" else KIND_WALK_IN


## True when the viewer may take the fortress on hex to hold men (D49, the fog rule of M8 4.3): the holder and the viewer ""
## read the exact garrison, a viewer who sees the hex reads it rounded to 100 (a garrison under 50 reads as none: the card must
## not tell it from an empty fortress), and the garrison of a fortress it cannot see is the full one (assumed).
static func _garrisoned(game: Game, viewer: StringName, hex: Vector2i) -> bool:
	return int(Knowledge.garrison_known(game, viewer, hex)["men"]) > 0


## The output shell: the place, the kind, the verdict and the card's keys, empty numbers included.
static func _shell(game: Game, hex: Vector2i, kind: StringName, ok: bool, reason: String) -> Dictionary:
	return {
		"kind": kind, "ok": ok, "reason": reason,
		"title": Words.place(game, hex) if game.map.has(hex) else "",
		"kind_text": "", "word": NO_WORD, "tone": TONE_PLAIN if ok else TONE_BAD,
		"notes": [] as Array[String], "hint": "",
		"ratio_permille": -1, "factor_permille": UNIT,
		"attack": {"men": 0, "morale": 0, "strength": 0},
		"defence": _defence_empty(),
		"chips": [] as Array[Dictionary],
		"besiege": {"seasons": -1, "need": 0, "rate": 0, "stores": 0, "too_few_text": ""},
		"storm_word": NO_WORD, "opens": 0, "held_by": {"hex": Army.NO_HEX, "name": "", "distance": -1},
	}


## The numbers, the word and the notes of one kind of march.
static func _fill(game: Game, viewer: StringName, a: Army, hex: Vector2i, kind: StringName, out: Dictionary,
		stand: Vector2i) -> void:
	var key := String(Battles.ground_at(game, hex).get("key", OPEN_KEY))
	out.attack = {"men": a.men(), "morale": Armies.morale_of(a),
		"strength": Combat.odds_side(game.defs.war, _companies(a), {}, false)}
	out.factor_permille = Combat.odds_factor(game.defs.war, key, false)
	if kind == KIND_ATTACK:
		_attack(game, viewer, a, hex, stand, key, out)
	elif kind == KIND_STORM:
		_storm(game, viewer, a, hex, key, out)
	elif kind == KIND_SIEGE:
		_siege(game, viewer, a, hex, out)
	elif kind == KIND_HELD:
		_held(game, viewer, a, hex, out)
	else:
		out.kind_text = "Walk in"
		out.notes = ["Takes it at the end of the season."] as Array[String]


## An attack on the enemy army standing on hex; its garrison joins when the hex is a garrisoned fortress (an assault, 4.6).
static func _attack(game: Game, viewer: StringName, a: Army, hex: Vector2i, stand: Vector2i, key: String,
		out: Dictionary) -> void:
	var war := game.defs.war
	var enemies := _enemies_at(game, viewer, hex)
	var holder := Occupation.controller_tag(game, hex)
	var assault := Battles.assault_at(game, hex, enemies[0].tag)
	var garrison := _garrison_entry(game, viewer, hex, holder, WHOLE, assault, true)
	var defence := _defence_of(game, viewer, enemies, garrison, assault, true)
	out.defence = defence
	out.factor_permille = Combat.odds_factor(war, key, assault)
	var chips := _chips(game, stand, hex, key, assault, garrison)
	chips.append_array(_edge_chips(game, stand, hex, String(holder)))
	out.chips = chips
	out.kind_text = "Attack"
	_word_of(game, out, assault, key, defence)


## The storm of the fortress on hex: the army against its garrison alone (4.6, 4.7, D19).
static func _storm(game: Game, viewer: StringName, a: Army, hex: Vector2i, key: String, out: Dictionary) -> void:
	var holder := Occupation.controller_tag(game, hex)
	var garrison := _garrison_entry(game, viewer, hex, holder, Occupation.storm_garrison(game, hex, viewer), true, false)
	var defence := _defence_of(game, viewer, [], garrison, true, false)
	out.defence = defence
	out.factor_permille = Combat.odds_factor(game.defs.war, key, true)
	out.chips = _chips(game, a.hex, hex, key, true, garrison)
	out.kind_text = "Storm"
	_word_of(game, out, true, key, defence)
	out.storm_word = out.word
	out.notes = _fortress_notes(game, hex, out) as Array[String]


## The siege of a garrisoned fortress by the army alone: the forecast season (4.5); a siege has no odds word of its own.
## An undiscovered fortress gives the unseen sentence and no numbers (R19, R21): the card never reads its garrison.
static func _siege(game: Game, viewer: StringName, a: Army, hex: Vector2i, out: Dictionary) -> void:
	var besiege := _besiege(game, viewer, a, hex)
	out.besiege = besiege
	if bool(besiege.hidden):
		out.word = Movement.UNSEEN_TEXT
		out.kind_text = "Besiege"
		out.tone = TONE_PLAIN
		out.storm_word = NO_WORD
		out.opens = 0
		out.notes = [] as Array[String]
		return
	var seasons := int(besiege.seasons)
	out.word = besiege.too_few_text if seasons < 0 else "falls in about %s" % _seasons_text(seasons)
	out.kind_text = "Besiege · " + str(out.word)
	out.tone = TONE_BAD if seasons < 0 else TONE_PLAIN
	out.storm_word = _storm_word(game, viewer, a, hex)
	out.opens = maxi(0, Occupation.members(game, hex).size() - 1)
	out.notes = _fortress_notes(game, hex, out) as Array[String]


## Held land (4.3): the army walks in, but the standing castle holds it; the hint is the siege of that castle.
static func _held(game: Game, viewer: StringName, a: Army, hex: Vector2i, out: Dictionary) -> void:
	var held := AreaLines.held_by(game, hex)
	var fortress: Vector2i = held["fortress"]
	var distance := int(held["distance"])
	var where := "%s (%d, %d)" % [str(held["name"]), fortress.x, fortress.y]
	out.held_by = {"hex": fortress, "name": str(held["name"]), "distance": distance}
	out.kind_text = "Held"
	out.notes = ["Moves in, but cannot take it: held by %s, %d %s away." % [where, distance,
		"hex" if distance == 1 else "hexes"]] as Array[String]
	var besiege := _besiege(game, viewer, a, fortress)
	out.besiege = besiege
	if bool(besiege.hidden):
		return
	var seasons := int(besiege.seasons)
	out.hint = "Besiege it: %s." % ("falls in about %s" % _seasons_text(seasons) if seasons >= 0 else TOO_FEW_TEXT)


## The siege numbers of an army on a fortress (Sieges.terms and forecast_for with the army's men and guns and the garrison the
## viewer may read, R19). An undiscovered fortress gives no numbers at all: {hidden: true}. Sieges reads the real garrison for
## a -1 garrison, so -1 is never passed on here. Nothing written.
static func _besiege(game: Game, viewer: StringName, a: Army, fortress: Vector2i) -> Dictionary:
	var estimate := Knowledge.garrison_known(game, viewer, fortress)
	if estimate.access == &"hidden":
		return {"hidden": true, "seasons": -1, "need": 0, "rate": 0, "stores": 0, "too_few_text": ""}
	var men := a.men()
	var guns := _guns(game, a)
	var garrison := int(estimate.men)
	var t := Sieges.terms(game, fortress, viewer, men, guns, garrison)
	var seasons := Sieges.forecast_for(game, fortress, garrison, men, guns, 0, 0)
	return {"hidden": false, "seasons": seasons, "need": int(t.need), "rate": int(t.rate), "stores": int(t.stores),
		"too_few_text": TOO_FEW_TEXT if seasons < 0 else ""}


## The storm's word for the fortress on hex: the army against its garrison alone; "" when the viewer cannot read the garrison.
static func _storm_word(game: Game, viewer: StringName, a: Army, hex: Vector2i) -> String:
	if Occupation.fortress_level(game, hex) <= 0 or not _garrisoned(game, viewer, hex):
		return NO_WORD
	var holder := Occupation.controller_tag(game, hex)
	if holder == viewer or holder == &"" or not Wars.at_war(game, viewer, holder):
		return NO_WORD
	var garrison := _garrison_entry(game, viewer, hex, holder, Occupation.storm_garrison(game, hex, viewer), true, false)
	if str(garrison.get("access", ACCESS_HIDDEN)) == ACCESS_HIDDEN:
		return NO_WORD
	var key := String(Battles.ground_at(game, hex).get("key", OPEN_KEY))
	var card := Combat.odds_card(game.defs.war, Combat.odds_side(game.defs.war, _companies(a), {}, false),
		Combat.odds_side(game.defs.war, [], _garrison_numbers(garrison), false), key, true)
	return str(card.word)


## The notes of a fortress card: the starvation (its stores), the districts a taking opens, and the storm's way in when the
## viewer's army could storm it.
static func _fortress_notes(game: Game, hex: Vector2i, out: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var stores := int((out.besiege as Dictionary).get("stores", 0))
	if stores <= 0:
		stores = 1 + Occupation.fortress_level(game, hex)
	notes.append("Garrison starves after %d seasons" % stores)
	notes.append("Taking it opens %d districts" % int(out.opens))
	if str(out.storm_word) != NO_WORD and str(out.kind_text).begins_with("Besiege"):
		notes.append("Shift+right click: storm (%s)" % str(out.storm_word))
	return notes


## The companies of an army for the odds: {men, morale} each (Combat's form), its own units exact.
static func _companies(a: Army) -> Array:
	var out: Array = []
	for u: Unit in a.units:
		out.append({"men": u.men, "morale": u.morale})
	return out


## The guns of an army: the siege points of its companies.
static func _guns(game: Game, a: Army) -> int:
	var guns := 0
	for u: Unit in a.units:
		var def := Military.unit_def(game, u.kind)
		guns += def.siege_points if def != null else 0
	return guns


## The enemy armies the viewer may fight on hex (at war with the viewer), in id order.
static func _enemies_at(game: Game, viewer: StringName, hex: Vector2i) -> Array[Army]:
	var out: Array[Army] = []
	for other: Army in Armies.at(game, hex):
		if other.tag != viewer and Wars.at_war(game, viewer, other.tag) and ArmyView.visible(game, viewer, other):
			out.append(other)
	return out


## The defending side as the viewer may read it: {access, men, morale, strength, garrison}. Enemy armies the viewer sees are
## banded (men) and rounded (morale) and count as one company; a hidden army or garrison gives no number and no word. The
## garrison joins when the battle is an assault; with_field says whether a field army stands with it (Combat's weight).
static func _defence_of(game: Game, viewer: StringName, enemies: Array[Army], garrison: Dictionary, assault: bool,
		with_field: bool) -> Dictionary:
	var access := ACCESS_EXACT
	var men := 0
	var weighted := 0
	var companies: Array = []
	for e: Army in enemies:
		if not ArmyView.visible(game, viewer, e):
			return _defence_empty()
		if viewer != &"":
			access = ACCESS_SEEN
		men += e.men()
		weighted += e.men() * Armies.morale_of(e)
		companies.append_array(_companies(e))
	var morale := Economy.floor_div(weighted, men) if men > 0 else 0
	if access == ACCESS_SEEN:
		men = Knowledge.band(men)
		morale = _round(morale, ROUND_MORALE)
		companies = [{"men": men, "morale": morale}] if men > 0 else []
	var use_garrison := assault and not garrison.is_empty()
	if use_garrison:
		var g_access := str(garrison.access)
		if g_access == ACCESS_HIDDEN:
			return _defence_empty()
		access = _worse(access, g_access)
	var numbers := _garrison_numbers(garrison) if use_garrison else {}
	if companies.is_empty() and numbers.is_empty():
		return _defence_empty()
	var strength := Combat.odds_side(game.defs.war, companies, numbers, with_field)
	return {"access": access, "men": men, "morale": morale, "strength": strength,
		"garrison": {"men": int(garrison.get("men", 0)) if use_garrison else 0,
			"weight_permille": int(garrison.get("weight_permille", 0)) if use_garrison else 0,
			"cut": int(garrison.get("cut", 0)) if use_garrison else 0}}


## A defence the viewer cannot read: no men, no morale, no strength, no garrison.
static func _defence_empty() -> Dictionary:
	return {"access": ACCESS_HIDDEN, "men": 0, "morale": 0, "strength": 0,
		"garrison": {"men": 0, "weight_permille": 0, "cut": 0}}


## The garrison of a hex in an assault as the viewer reads it: {access, men (exact, or rounded to 100 when seen), level,
## weight_permille (Combat's weight: behind a field army or alone), cut (the storm's cut)}. `faced` is the storm's garrison
## (WHOLE for the whole one). {} when there is no assault or no garrison; a hidden one has access hidden and no men.
static func _garrison_entry(game: Game, viewer: StringName, hex: Vector2i, holder: StringName, faced: int, assault: bool,
		with_field: bool) -> Dictionary:
	var war := game.defs.war
	if not assault or Occupation.fortress_level(game, hex) <= 0:
		return {}
	if not _garrisoned(game, viewer, hex):
		return {}
	var whole := Occupation.garrison_of(game, hex)
	var level := Occupation.fortress_level(game, hex)
	var access := _garrison_access(game, viewer, hex, holder)
	if access == ACCESS_HIDDEN:
		return {"access": ACCESS_HIDDEN, "men": 0, "level": level, "weight_permille": 0, "cut": 0}
	var men := whole
	var cut := 0
	if faced >= 0 and faced < whole:
		men = faced
		cut = whole - faced
	var weight := war.garrison_odds_permille if with_field else int(war.garrison_odds_alone[clampi(level, 0, 3)])
	return {"access": access, "men": men if access == ACCESS_EXACT else _round(men, ROUND_MEN), "level": level,
		"weight_permille": weight, "cut": cut}


## Exact for the viewer "" and for the holder of the fortress; seen while the viewer sees the hex; else hidden.
static func _garrison_access(game: Game, viewer: StringName, hex: Vector2i, holder: StringName) -> StringName:
	if viewer == &"" or viewer == holder:
		return ACCESS_EXACT
	if Knowledge.sees(game, viewer, hex):
		return ACCESS_SEEN
	return ACCESS_HIDDEN


## The numbers Combat.odds_side reads from a garrison entry: men and level; {} for no garrison.
static func _garrison_numbers(garrison: Dictionary) -> Dictionary:
	if garrison.is_empty():
		return {}
	return {"men": int(garrison.get("men", 0)), "level": int(garrison.get("level", 0))}


## Fills the word, the ratio, the tone and the kind text of an attack or storm (Combat.odds_card). A defence the viewer cannot
## read has no word and no ratio.
static func _word_of(game: Game, out: Dictionary, assault: bool, key: String, defence: Dictionary) -> void:
	if str(defence.access) == ACCESS_HIDDEN:
		out.word = NO_WORD
		out.ratio_permille = -1
		out.tone = TONE_PLAIN
		out.kind_text = str(out.kind_text)
		return
	var card := Combat.odds_card(game.defs.war, int(out.attack.strength), int(defence.strength), key, assault)
	out.ratio_permille = int(card.ratio)
	out.factor_permille = int(card.factor)
	out.word = str(card.word)
	out.tone = _tone_of(int(card.value))
	out.kind_text = "%s · %s" % [str(out.kind_text), out.word]


## The tone of a value over the even mark (1,000 permille): good above, bad below, plain at even.
static func _tone_of(value: int) -> StringName:
	if value > UNIT:
		return TONE_GOOD
	return TONE_BAD if value < UNIT else TONE_PLAIN


## True when the viewer may read a hex at all: it sees it (Knowledge.sees), or it is the viewer's own land or held by the viewer.
static func _in_view(game: Game, viewer: StringName, hex: Vector2i) -> bool:
	if Knowledge.sees(game, viewer, hex):
		return true
	return Occupation.controller_tag(game, hex) == viewer or Territory.owner_tag(game, hex) == viewer


## The crossing chips of an attack's first day (Battles' flags, 4.6): a pass edge between the stand and the hex costs the
## attacker the crossing penalty, a river edge with no crossing tile its river penalty. Both on day 1 only.
static func _edge_chips(game: Game, stand: Vector2i, hex: Vector2i, holder: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var m := game.map
	var from := m.index_of(stand)
	var to := m.index_of(hex)
	if from < 0 or to < 0 or from == to:
		return out
	var d := Movement.direction(m, from, to)
	if d < 0:
		return out
	var e := m.edge_index(stand, d)
	if e < 0 or e >= m.pass_edge.size():
		return out
	var war := game.defs.war
	if int(m.pass_edge[e]) != 0:
		out.append({"text": "Across a pass %s%d %% on day 1" % [MINUS, war.crossing_penalty_permille / PERCENT], "helps": holder})
	var river := int(m.river[e])
	if river >= 1 and river <= 3 and int(m.crossing[e]) == 0:
		out.append({"text": "Across the river %s%d %% on day 1" % [MINUS, war.river_penalty_permille / PERCENT], "helps": holder})
	return out


## The ground and the walls as chips: the ground's percent for the defender, the uphill penalty for an attacker standing
## lower, the garrison's weight behind its walls. Each chip's `helps` is the side it helps (the defender's tag).
static func _chips(game: Game, stand: Vector2i, hex: Vector2i, key: String, assault: bool, garrison: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var war := game.defs.war
	var holder := String(Occupation.controller_tag(game, hex))
	var factor := UNIT if assault else Combat.odds_factor(war, key, false)
	if factor != UNIT:
		var pct := absi(factor - UNIT) / PERCENT
		var sign_text := "+" if factor > UNIT else MINUS
		out.append({"text": "%s %s%d %% for them" % [key.capitalize(), sign_text, pct], "helps": holder})
	var from := game.map.index_of(stand)
	var to := game.map.index_of(hex)
	if from >= 0 and to >= 0 and int(game.map.relief[from]) < int(game.map.relief[to]):
		out.append({"text": "Uphill %s%d %% for you" % [MINUS, war.uphill_penalty_permille / PERCENT], "helps": holder})
	if assault and int(garrison.get("weight_permille", 0)) > 0:
		out.append({"text": "Garrison counts ×%.1f behind its walls" % (int(garrison.weight_permille) / 1000.0),
			"helps": holder})
	return out


## One sentence, capitalised, with a full stop. A check's reason with its parenthesis "(it recovers ...)" gives two.
static func _sentence(reason: String) -> String:
	if reason.is_empty():
		return ""
	var head := reason
	var tail := ""
	var at := reason.find(" (it ")
	if at >= 0:
		head = reason.substr(0, at)
		tail = reason.substr(at + 2).trim_suffix(")")
	var out := _cap(head) + "."
	if tail != "":
		out += " " + _cap(tail) + "."
	return out


## The shaken refusal of 6.4 in its two sentences, worked from the war numbers: the morale and the attack morale in percent, and
## the recovery of a season in percent (WarDef keeps permille). Battles' own reason prints the recovery in permille.
static func _shaken_sentences(game: Game, a: Army) -> String:
	var war := game.defs.war
	return "Too shaken to attack: morale %d %%, %d %% needed. It recovers %d a season when fed." % [
		Armies.morale_of(a) / PERCENT, war.attack_morale / PERCENT, war.morale_recovery / PERCENT]


static func _cap(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


## "1 season", "4 seasons".
static func _seasons_text(n: int) -> String:
	return "%d season%s" % [n, "" if n == 1 else "s"]


## The worse of two accesses (hidden < seen < exact).
static func _worse(a: String, b: String) -> String:
	var rank := {ACCESS_EXACT: 2, ACCESS_SEEN: 1, ACCESS_HIDDEN: 0}
	return a if int(rank.get(a, 0)) <= int(rank.get(b, 0)) else b


static func _round(n: int, step: int) -> int:
	return ((n + step / 2) / step) * step
