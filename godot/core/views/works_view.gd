## What the works under way look like to the player: their labels, dates and slots (docs/architecture/m3-build-spec.md
## 4.3 and 5.6). Pure core/views/ code: reads Works, Game and HexCard's word tables; writes nothing.
class_name WorksView
extends RefCounted

const NO_HEX := Vector2i(-1, -1)


## "vineyard, first stage"; "walled town to city"; "vineyard, first to second stage"; "clearing the vineyard";
## "barracks". The level words are HexCard's.
static func label(_game: Game, work: Work) -> String:
	if work.action == Works.BARRACKS:
		return "barracks"
	var piece := FamilyIds.NAMES[clampi(work.family, 0, FamilyIds.COUNT - 1)]
	if work.action == Works.CLEAR:
		return "clearing the %s" % piece_name(work.family)
	if HexCard.LEVEL_WORDS.has(piece):
		var words: Array = HexCard.LEVEL_WORDS[piece]
		if work.action == Works.BUILD:
			return str(words[clampi(work.level_to, 0, words.size() - 1)])
		return "%s to %s" % [words[clampi(work.level_to - 1, 0, words.size() - 1)],
			words[clampi(work.level_to, 0, words.size() - 1)]]
	if work.action == Works.BUILD:
		return "%s, %s" % [piece, HexCard.word(HexCard.STAGE_WORDS, 1)]
	return "%s, %s to %s" % [piece, _stage(work.level_to - 1), HexCard.word(HexCard.STAGE_WORDS, work.level_to)]


## The family as a singular noun (Words.PIECE_NOUNS): "vineyard", "pasture", "castle".
static func piece_name(family: int) -> String:
	return Words.piece_noun(FamilyIds.NAMES[clampi(family, 0, FamilyIds.COUNT - 1)])


## The label with its place: "vineyard, first stage, near Savona (7, 12)".
static func line(game: Game, work: Work) -> String:
	return "%s, %s" % [label(game, work), Words.place(game, work.hex)]


## The work on `hex` as {label, tag, progress ("1 of 4 seasons"), ready ("Spring 1481"), ready_turn, halted (halted in
## the current season), started_turn}; {} when none. The progress counts the season under way. The viewer (default "": sees
## all) gets nothing for a hex it has not discovered (R18, a foreign work is a fact of the land).
static func at(game: Game, hex: Vector2i, viewer: StringName = &"") -> Dictionary:
	if game == null or game.state == null:
		return {}
	if game.has_countries() and not Knowledge.discovered(game, viewer, hex):
		return {}
	for work: Work in game.state.works:
		if work.hex == hex:
			return _entry(game, work)
	return {}


## The season from which the work stands (Works.ready_turn: halted seasons are skipped).
static func ready_turn(game: Game, work: Work) -> int:
	return Works.ready_turn(game, work)


## The season from which a work of `seasons` seasons begun now on `hex` would stand: the works phase counts the season
## it is begun in, and a snow winter halts it (as Works.ready_turn for a work under way).
static func ready_turn_of(game: Game, hex: Vector2i, seasons: int) -> int:
	var probe := Work.new()
	probe.hex = hex
	if Occupation.is_occupied(game, hex) or Occupation.besieged(game, hex):
		return Works.NO_DATE
	var left := maxi(seasons, 1)
	var t := game.turn
	for n: int in Works.HORIZON:
		if not Works.halted(game, probe, t):
			left -= 1
			if left <= 0:
				return t + 1
		t += 1
	return t


## Seasons a build (the family), an upgrade or a clear of `hex` would take, for a button's cost text.
static func seasons_of(game: Game, action: StringName, hex: Vector2i, family: int = -1) -> int:
	if action == Works.BUILD:
		return Works.seasons_for(game, action, family, 1)
	var piece := Improve.piece_at(game, hex)
	if piece.is_empty():
		return Works.seasons_for(game, action, family, 1)
	var level_to := int(piece["level"]) + 1 if action == Works.UPGRADE else 0
	return Works.seasons_for(game, action, int(piece["family_id"]), level_to)


## {used, total} of a country's work slots; total -1: no limit.
static func slots(game: Game, tag: StringName) -> Dictionary:
	return {"used": Works.in_use(game, tag), "total": Works.slots(game, tag)}


## at() of each work of `tag`, in id order.
static func of_country(game: Game, tag: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for work: Work in game.state.works:
		if work.tag == tag:
			out.append(_entry(game, work))
	return out


## The hex of the newest work of `tag` begun this turn; NO_HEX when none.
static func last_begun(game: Game, tag: StringName) -> Vector2i:
	var best: Work = null
	for work: Work in game.state.works:
		if work.tag == tag and work.started_turn == game.turn and (best == null or work.id > best.id):
			best = work
	return NO_HEX if best == null else best.hex


static func _entry(game: Game, work: Work) -> Dictionary:
	var ready := Works.ready_turn(game, work)
	var done := clampi(work.seasons - work.seasons_left + 1, 1, maxi(work.seasons, 1))
	return {
		"label": label(game, work),
		"tag": work.tag,
		"progress": "%d of %s" % [done, Words.seasons(work.seasons)],
		"ready": Works.ready_words(game, work),
		"ready_turn": ready,
		"halted": Works.halted(game, work, game.turn),
		"started_turn": work.started_turn,
		"family": work.family,
	}


static func _stage(level: int) -> String:
	return HexCard.word(HexCard.STAGE_WORDS, level).trim_suffix(" stage")
