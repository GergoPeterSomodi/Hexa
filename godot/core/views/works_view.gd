## What the works under way look like to the player: their labels, dates and slots (docs/architecture/m3-build-spec.md
## 4.3 and 5.6). Pure core/views/ code: reads Works, Game and HexCard's word tables; writes nothing.
class_name WorksView
extends RefCounted

const NO_HEX := Vector2i(-1, -1)


## "vineyard, first stage"; "walled town to city"; "vineyard, first to second stage"; "clearing the vineyard".
## The level words are HexCard's.
static func label(_game: Game, work: Work) -> String:
	var piece := FamilyIds.NAMES[clampi(work.family, 0, FamilyIds.COUNT - 1)]
	if work.action == Works.CLEAR:
		return "clearing the %s" % piece
	if HexCard.LEVEL_WORDS.has(piece):
		var words: Array = HexCard.LEVEL_WORDS[piece]
		if work.action == Works.BUILD:
			return str(words[clampi(work.level_to, 0, words.size() - 1)])
		return "%s to %s" % [words[clampi(work.level_to - 1, 0, words.size() - 1)],
			words[clampi(work.level_to, 0, words.size() - 1)]]
	if work.action == Works.BUILD:
		return "%s, %s" % [piece, HexCard.word(HexCard.STAGE_WORDS, 1)]
	return "%s, %s to %s" % [piece, _stage(work.level_to - 1), HexCard.word(HexCard.STAGE_WORDS, work.level_to)]


## The label with its place: "vineyard, first stage, near Savona (7, 12)".
static func line(game: Game, work: Work) -> String:
	return "%s, %s" % [label(game, work), Words.place(game, work.hex)]


## The work on `hex` as {label, tag, progress ("1 of 4 seasons"), ready ("Spring 1481"), ready_turn, halted (halted in
## the current season), started_turn}; {} when none. The progress counts the season under way.
static func at(game: Game, hex: Vector2i) -> Dictionary:
	if game == null or game.state == null:
		return {}
	for work: Work in game.state.works:
		if work.hex == hex:
			return _entry(game, work)
	return {}


## The season from which the work stands (Works.ready_turn: halted seasons are skipped).
static func ready_turn(game: Game, work: Work) -> int:
	return Works.ready_turn(game, work)


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
		"ready": Calendar.date_text(ready, game.start_year),
		"ready_turn": ready,
		"halted": Works.halted(game, work, game.turn),
		"started_turn": work.started_turn,
	}


static func _stage(level: int) -> String:
	return HexCard.word(HexCard.STAGE_WORDS, level).trim_suffix(" stage")
