## BuildingCard (docs/architecture/tilewin-build-spec.md R25, R8, R9; TW7): the buildable card's sections and lines, the ok verdict
## in good tone, a refusal in bad tone that keeps the cost lines (P), a standing piece's card (no cost), the own-only rule (R9)
## and the absent optional sections. Genoa (GEN) is the player on the economy fixture; the vineyard hex is its own.
extends GutTest

const GEN := &"GEN"
const HEADS_ALLOWED: Array[String] = ["", "Each year it would", "Each year it makes", "To build"]


func _game() -> Game:
	return EconomyFixture.game(GEN, true)


func _heads(card: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for section: Variant in card["sections"]:
		out.append(str((section as Dictionary)["head"]))
	return out


func _lines(card: Dictionary, head: String) -> Array:
	for section: Variant in card["sections"]:
		if str((section as Dictionary)["head"]) == head:
			return (section as Dictionary)["lines"]
	return []


func _has_label(lines: Array, label: String) -> bool:
	for line: Variant in lines:
		if str((line as Array)[0]) == label:
			return true
	return false


func _vineyard_option() -> Dictionary:
	return {"action": Works.BUILD, "family": ImproveRules.VINEYARD}


func test_buildable_card_has_its_title_kind_and_cost_lines() -> void:
	var g := _game()
	var card := BuildingCard.of(g, GEN, EconomyFixture.VINEYARD_HEX, _vineyard_option())
	assert_false(card.is_empty())
	assert_true(str(card["title"]).contains(" in "), "title names the piece and the place")
	assert_ne(str(card["kind"]), "")
	assert_true(_heads(card).has("To build"))
	var cost := _lines(card, "To build")
	assert_true(_has_label(cost, "Building time"), "the building time is always a cost line")
	var verdict: Dictionary = card["verdict"]
	assert_eq(verdict["ok"], true)
	assert_eq(verdict["tone"], &"good")
	assert_true(str(verdict["text"]).begins_with("You can build this"))


func test_refused_card_is_in_bad_tone_and_keeps_its_cost_lines() -> void:
	var g := _game()
	var c := Countries.by_tag(g, GEN)
	c.treasury = 0
	var card := BuildingCard.of(g, GEN, EconomyFixture.VINEYARD_HEX, _vineyard_option())
	var verdict: Dictionary = card["verdict"]
	assert_eq(verdict["ok"], false)
	assert_eq(verdict["tone"], &"bad", "a refusal is never in plain tone")
	assert_true(str(verdict["text"]).begins_with("You cannot afford this yet"), str(verdict["text"]))
	assert_true(str(verdict["text"]).contains("more ducats"))
	var cost := _lines(card, "To build")
	assert_true(_has_label(cost, "Ducats"), "a refused card keeps the ducat line (P)")
	assert_true(_has_label(cost, "Building time"), "a refused card keeps the building time (P)")


func test_optional_sections_are_absent_before_their_data() -> void:
	var g := _game()
	var card := BuildingCard.of(g, GEN, EconomyFixture.VINEYARD_HEX, _vineyard_option())
	for head: String in _heads(card):
		assert_true(HEADS_ALLOWED.has(head), "unexpected section '%s'" % head)
		assert_false(head.contains("Arms"))
		assert_false(head.contains("Slots"))
		assert_false(head.contains("Market"))


func test_foreign_hex_gives_nothing() -> void:
	var g := _game()
	var hex := Vector2i(-99, -99)
	assert_true(BuildingCard.of(g, GEN, hex, _vineyard_option()).is_empty(), "off the map")
	for c: Country in g.countries:
		if c.tag == GEN:
			continue
		var districts := Territory.districts(g, c.id)
		if districts.is_empty():
			continue
		var foreign := g.map.hex_of(districts[0])
		assert_true(BuildingCard.of(g, GEN, foreign, _vineyard_option()).is_empty(), "another country's land (R9)")
		return
	pending("no other country owns a district in this fixture")


func test_standing_piece_has_what_it_makes_and_no_cost() -> void:
	var g := _game()
	assert_true(bool(g.act("build", {"hex": EconomyFixture.VINEYARD_HEX, "family": ImproveRules.VINEYARD, "tag": GEN})["ok"]))
	for n: int in 12:
		if not Improve.piece_at(g, EconomyFixture.VINEYARD_HEX).is_empty():
			break
		assert_true(bool(Season.run(g)["ok"]))
	var card := BuildingCard.of(g, GEN, EconomyFixture.VINEYARD_HEX, {})
	assert_false(card.is_empty())
	assert_false(_heads(card).has("To build"), "a built piece has no cost lines")
	var verdict: Dictionary = card["verdict"]
	assert_eq(verdict["ok"], true)
	assert_eq(verdict["tone"], &"good")
