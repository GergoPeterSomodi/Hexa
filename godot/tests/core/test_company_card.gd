## CompanyCard (docs/architecture/tilewin-build-spec.md R26, R22, R8, R9; TW7): the men and the fighting, what raising takes, the
## afterwards lines, the ok verdict ("You can raise N here this season."), a refusal in bad tone that keeps the whole card (P:
## the cost lines stay), the own-settlement rule, and the absent M9.5 arms section. Genoa (GEN) is the player on the army fixture.
extends GutTest

const KNIGHTS_NAME := "Knights"


func _unit_id(g: Game, name: String) -> int:
	for ud: UnitDef in g.defs.units:
		if ud != null and ud.name == name:
			return ud.id
	return -1


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


func _town_game(level: int) -> Array:
	var g := ArmyFixture.game()
	var hex := ArmyFixture.find_town(g)
	ArmyFixture.town(g, hex, level, 20000)
	ArmyFixture.rich(g)
	return [g, hex]


func test_an_ok_kind_says_how_many_it_raises() -> void:
	var pair := _town_game(5)
	var g: Game = pair[0]
	var hex: Vector2i = pair[1]
	var kind := _unit_id(g, "Pikemen")
	var card := CompanyCard.of(g, ArmyFixture.TAG, hex, kind)
	assert_false(card.is_empty())
	assert_eq(card["title"], "Pikemen")
	var verdict: Dictionary = card["verdict"]
	assert_eq(verdict["ok"], true)
	assert_eq(verdict["tone"], &"good")
	assert_true(str(verdict["text"]).begins_with("You can raise "), str(verdict["text"]))
	assert_true(str(verdict["text"]).ends_with("here this season."))
	assert_true(_has_label(_lines(card, "Men"), "Men"))
	assert_true(_has_label(_lines(card, "To raise"), "Ducats"))
	assert_true(_has_label(_lines(card, "Afterwards"), "Upkeep a season"))


func test_can_raise_is_the_largest_count_that_passes() -> void:
	var pair := _town_game(5)
	var g: Game = pair[0]
	var hex: Vector2i = pair[1]
	var kind := _unit_id(g, "Pikemen")
	var n := CompanyCard.can_raise(g, ArmyFixture.TAG, hex, kind)
	assert_true(n >= 1)
	assert_true(bool(Military.raise_check(g, {"hex": hex, "kind": kind, "count": n, "tag": ArmyFixture.TAG})["ok"]))
	var over := Military.raise_check(g, {"hex": hex, "kind": kind, "count": n + 1, "tag": ArmyFixture.TAG})
	assert_false(bool(over["ok"]), "n + 1 is refused")


func test_refused_kind_is_in_bad_tone_and_keeps_its_whole_card() -> void:
	var pair := _town_game(1)
	var g: Game = pair[0]
	var hex: Vector2i = pair[1]
	var kind := _unit_id(g, KNIGHTS_NAME)
	var card := CompanyCard.of(g, ArmyFixture.TAG, hex, kind)
	assert_false(card.is_empty(), "a refused kind still has its card")
	var verdict: Dictionary = card["verdict"]
	assert_eq(verdict["ok"], false)
	assert_eq(verdict["tone"], &"bad")
	assert_true(str(verdict["text"]).contains("raised in a"), str(verdict["text"]))
	assert_true(_has_label(_lines(card, "To raise"), "Ducats"), "a refused card keeps the ducat line (P)")
	assert_true(_has_label(_lines(card, "Afterwards"), "Upkeep a season"), "a refused card keeps the upkeep (P)")


func test_missing_horses_name_the_goods_in_the_refusal() -> void:
	var pair := _town_game(5)
	var g: Game = pair[0]
	var hex: Vector2i = pair[1]
	var c := Countries.by_tag(g, ArmyFixture.TAG)
	var horses := g.defs.good_id(&"horses")
	c.stock[horses] = 0
	var card := CompanyCard.of(g, ArmyFixture.TAG, hex, _unit_id(g, KNIGHTS_NAME))
	var verdict: Dictionary = card["verdict"]
	assert_eq(verdict["ok"], false)
	assert_eq(verdict["tone"], &"bad")
	assert_true(str(verdict["text"]).to_lower().contains("horses"), str(verdict["text"]))
	var lines := _lines(card, "To raise")
	assert_true(_has_label(lines, "Horses"), "the horses line stays in the card")


func test_no_card_where_the_viewer_cannot_raise() -> void:
	var pair := _town_game(5)
	var g: Game = pair[0]
	assert_true(CompanyCard.of(g, ArmyFixture.TAG, Vector2i(0, 0), _unit_id(g, "Pikemen")).is_empty(), "not a settlement of its own")
	assert_true(CompanyCard.of(g, ArmyFixture.other_tag(g), pair[1], _unit_id(g, "Pikemen")).is_empty(), "another country's town (R9)")


func test_optional_arms_section_is_absent() -> void:
	var pair := _town_game(5)
	var g: Game = pair[0]
	var card := CompanyCard.of(g, ArmyFixture.TAG, pair[1], _unit_id(g, "Pikemen"))
	for section: Variant in card["sections"]:
		var head := str((section as Dictionary)["head"])
		assert_false(head.contains("Arms"), "no arms section before M9.5")
