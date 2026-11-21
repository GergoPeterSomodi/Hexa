## EconomyCards (docs/architecture/m4-build-spec.md 5.6, 6.3): the Ducats card's lines sum to the chip's change, the
## Stores card is consistent with goods_closed, and Genoa's start numbers (610 ducats, expected +86; grain 16, oil 4,
## wine 4, salt 4, timber 40, stone 40, iron 20).
extends GutTest

const GEN := &"GEN"
const GRAIN := 0
const OIL := 2
const WINE := 3
const SALT := 4
const TIMBER := 11
const STONE := 12
const IRON := 13


## "▲ +65" or "▼ −12" as a number.
func _number(text: String) -> int:
	var clean := text.replace("▲", "").replace("▼", "").replace("+", "").replace("−", "-").replace(",", "").strip_edges()
	return int(clean)


func test_ducats_card_at_the_start() -> void:
	var g := EconomyFixture.game(GEN)
	var card := EconomyCards.ducats(g, GEN)
	assert_eq(int(card["value"]), 610)
	assert_eq(int(card["change"]), 0)
	assert_eq(card["title"], "Ducats")
	assert_eq(card["hint"], "L: the Economy page")
	var lines: Array = card["lines"]
	var last: Array = lines[lines.size() - 1]
	assert_eq(last[0], "Expected this season")
	assert_eq(last[1], &"good")
	assert_eq(last[2], "▲ +86")
	assert_eq((lines[lines.size() - 2] as Array)[1], &"rule")


func test_ducats_lines_sum_to_the_change() -> void:
	var g := EconomyFixture.game(GEN, true)
	assert_true(bool(g.act("build", {"hex": EconomyFixture.VINEYARD_HEX, "family": ImproveRules.VINEYARD, "tag": GEN})["ok"]))
	for n: int in 3:
		assert_true(bool(Season.run(g)["ok"]))
		var card := EconomyCards.ducats(g, GEN)
		var c := Countries.by_tag(g, GEN)
		assert_eq(int(card["value"]), c.treasury)
		assert_eq(int(card["change"]), int(c.ledger_closed["closing"]) - int(c.ledger_closed["opening"]))
		var total := 0
		var lines: Array = card["lines"]
		var rule := -1
		for k: int in lines.size():
			if (lines[k] as Array)[1] == &"rule":
				rule = k
		assert_gt(rule, 0)
		for k: int in rule:
			total += _number(str((lines[k] as Array)[2]))
		assert_eq(total, int(card["change"]), "season %d" % (n + 1))
		var expected := int(EconomyPreview.expected(g, GEN)["net"])
		assert_eq(_number(str((lines[lines.size() - 1] as Array)[2])), expected)


func test_stores_card_at_the_start() -> void:
	var g := EconomyFixture.game(GEN)
	var card := EconomyCards.stores(g, GEN)
	assert_eq(card["title"], "Stores")
	assert_eq(int(card["change"]), 0)
	var c := Countries.by_tag(g, GEN)
	assert_eq(int(card["value"]), EconomyCards.worth(g, c.stock))
	assert_gt(int(card["value"]), 0)
	var shown := {}
	for line: Array in card["lines"]:
		shown[line[0]] = line[2]
	assert_eq(shown, {"Grain": "16", "Olive oil": "4", "Wine": "4", "Salt": "4", "Horses": "10", "Timber": "40", "Stone": "40", "Iron": "20", "Copper": "5"})
	assert_eq(c.stock[GRAIN], 16)
	assert_eq(c.stock[OIL], 4)
	assert_eq(c.stock[WINE], 4)
	assert_eq(c.stock[SALT], 4)
	assert_eq(c.stock[TIMBER], 40)
	assert_eq(c.stock[STONE], 40)
	assert_eq(c.stock[IRON], 20)


func test_stores_card_follows_goods_closed() -> void:
	var g := EconomyFixture.game(GEN)
	var c := Countries.by_tag(g, GEN)
	for n: int in 4:
		assert_true(bool(Season.run(g)["ok"]))
		var card := EconomyCards.stores(g, GEN)
		var closed := c.goods_closed
		var opening: PackedInt32Array = closed["opening"]
		var closing: PackedInt32Array = closed["closing"]
		assert_eq(int(card["value"]), EconomyCards.worth(g, c.stock))
		assert_eq(int(card["change"]), EconomyCards.worth(g, closing) - EconomyCards.worth(g, opening))
		var rows := {}
		for line: Array in card["lines"]:
			rows[line[0]] = line
		for good: int in c.stock.size():
			var good_name := g.defs.good(good).name
			var delta := closing[good] - opening[good]
			if c.stock[good] == 0 and delta == 0:
				assert_false(rows.has(good_name), "%s absent, season %d" % [good_name, n + 1])
				continue
			assert_true(rows.has(good_name), "%s shown, season %d" % [good_name, n + 1])
			var text := str((rows[good_name] as Array)[2])
			assert_true(text.begins_with(Words.number(c.stock[good])), text)
			if delta == 0:
				assert_false(text.contains("("), text)
			else:
				var inside := text.substr(text.find("(") + 1).trim_suffix(")")
				assert_eq(_number(inside), delta, text)


func test_unknown_country() -> void:
	var g := EconomyFixture.game(GEN)
	assert_eq(EconomyCards.ducats(g, &"XXX"), {})
	assert_eq(EconomyCards.stores(g, &"XXX"), {})
