## The AI's peace step (docs/architecture/m8-build-spec.md 4.11, D27, 5.5). A step reads only AiKnow and AiBrief (never another step
## module) and acts only through AiKnow.act. The acceptance of a peace is M7's check, the same for every country: the AI only picks
## the terms it would ask and asks them, one terms a war a season; a refusal (told to the turn by AiKnow.act) ends that war's step.
@warning_ignore_start("integer_division")
class_name AiPeace
extends RefCounted

const TAKE := &"take"
const WHITE := &"white"
const YIELD := &"yield"


## For each live war of the seat, the first terms its rule picks (`terms_for`), asked once through the door.
static func peace(turn: AiTurn, game: Game, brief: AiBrief, _arg: int) -> void:
	if brief.temper == null or brief.ai == null:
		return
	for war: Dictionary in AiKnow.wars_of(game, brief.tag):
		var terms := terms_for(game, brief, war["enemy"] as StringName, int(war["start_turn"]))
		if terms != &"":
			AiKnow.act(turn, game, brief.tag, "make_peace", {"target": war["enemy"], "terms": terms})


## 4.11's table: &"take", &"white" or &"yield" for the war against `enemy` begun in season `start_turn`; &"" when none applies.
## `s` the score, `age` the seasons of war, `men_e` the enemy's banded men, `M` the seat's men, `T` its treasury.
static func terms_for(game: Game, brief: AiBrief, enemy: StringName, start_turn: int) -> StringName:
	var t := brief.temper
	var s := AiKnow.score(game, brief.tag, enemy)
	var age := AiKnow.turn(game) - start_turn
	var men_e := AiKnow.men_of(game, brief.tag, enemy)
	var tired := age >= t.tired_seasons
	if s >= t.take_score or (tired and s >= 1):
		return TAKE
	if s <= 0 and (tired or men_e * 1000 > brief.men * t.sue_ratio or brief.treasury < 0):
		return WHITE
	if s <= -3 and age >= t.yield_after and men_e * 1000 > brief.men * brief.ai.yield_ratio:
		return YIELD
	return &""
