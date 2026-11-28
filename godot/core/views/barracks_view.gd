## What the tile window and the works cards share about the barracks (docs/design/recruitment-queue.md sections 4 and 8;
## task RQ3): its words, the option of its tile, where the tile shows, its upkeep a year (the Town tab and the cards count
## money a year), a settlement's own figures with that upkeep left out, and the barracks' part of the works card
## (ImprovePreview.of calls it). Pure core/views/ code: reads Recruiting and the card parts; writes nothing.
class_name BarracksView
extends RefCounted

const NAME := "Barracks"
## The family name a barracks tile asks its Kit icon by (BuildingRow.FAMILY_ICONS).
const ICON := "barracks"
## The `kind` of a barracks row of TileBuildings.
const KIND := &"barracks"
## The hover card's sentence (section 8). The 5 is the queue limit of decision 15; RQ6 brings it as data.
const ABOUT := "Companies are raised here: up to 5 queued, one ready a season."
const SEASONS_A_YEAR := 4


## The option of the barracks' tile, as the works rule and the cards take it.
static func option() -> Dictionary:
	return {"action": Works.BARRACKS, "family": 0}


## Whether a barracks may be offered on `hex`: a settlement with none, none being built, in a game that has its numbers.
## Whether it may be built now is the check's (Works.barracks_check).
static func offered(game: Game, hex: Vector2i) -> bool:
	var i := game.map.index_of(hex)
	if Recruiting.def_of(game) == null or i < 0 or int(game.state.main_use[i]) != ImproveRules.SETTLEMENT:
		return false
	var work := game.state.work_at(hex)
	return not Recruiting.has_barracks(game, hex) and (work == null or work.action != Works.BARRACKS)


## "needs a town": the words of a tile locked by the settlement's size.
static func needs_words(game: Game) -> String:
	var def := Recruiting.def_of(game)
	var words: Array = FamilyIds.LEVEL_WORDS["settlements"]
	var level := def.min_level if def != null else 0
	return "needs %s" % Words.with_article(str(words[clampi(level, 0, words.size() - 1)]))


## The ducats a year of a barracks (its upkeep a season, four times); 0 in a game without countries or its numbers.
static func upkeep_a_year(game: Game) -> int:
	var def := Recruiting.def_of(game)
	return def.upkeep * SEASONS_A_YEAR if def != null and game.has_countries() else 0


## The clearing card of the settlement on `hex` with the barracks' upkeep left out of its year and its upkeep: the
## barracks has its own tile, so a built settlement's figures do not count it again. The card itself where no barracks
## stands or it has no figures; else a copy (the cached card is never written).
static func settlement_alone(game: Game, hex: Vector2i, card: Dictionary) -> Dictionary:
	var share := upkeep_a_year(game)
	if share == 0 or not Recruiting.has_barracks(game, hex):
		return card
	var out := card.duplicate(true)
	var year: Dictionary = out.get("year", {})
	for key: String in ["gain", "gain_realm", "gain_treasury"]:
		if year.has(key):
			year[key] = int(year[key]) - share  # clearing saves the barracks' upkeep too: not the settlement's gain
	var lands: Dictionary = out.get("lands", {})
	if lands.has("upkeep"):
		lands["upkeep"] = int(lands["upkeep"]) + share
	return out


## The barracks' part of a works card that ImprovePreview has begun (a card no rule refuses): what it needs, its upkeep a
## year and what it is for. It changes no output, so the card has no year, seasons, chart or payback.
static func fill_card(game: Game, tag: StringName, hex: Vector2i, cost: Dictionary, card: Dictionary) -> void:
	var needs: Array[Dictionary] = [{"text": needs_words(game).trim_prefix("needs ") + " or larger",
		"ok": Recruiting.size_reason(game, hex) == ""}]
	needs.append_array(ImproveCardParts.requirements(game, tag, hex, Works.BARRACKS, {"family": 0, "level_to": 0}, cost))
	card["requirements"] = needs
	if upkeep_a_year(game) != 0:
		card["lands"] = {"upkeep": upkeep_a_year(game)}
	card["next_stages"] = [{"level": 0, "ok": true, "text": ABOUT}]
