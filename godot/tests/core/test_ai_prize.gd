## The AI's prize (docs/architecture/m8-build-spec.md 4.9): AiWar.prize_of reads the seat's near-land field (AiKnow.land_field,
## kept by AiBrief.near_land per game version). This file keeps the old brute-force test (every target hex against every own hex)
## as the reference, and checks the field against it on the duel, on a seasoned AI game and after the land changes. Timing is
## not asserted here (tools/perf_core.gd does that).
@warning_ignore_start("integer_division")
extends GutTest

const S := preload("res://tests/core/ai_war_scene.gd")
const M := AiWarScene.M
const GEN := AiWarScene.GEN
const SWI := &"SWI"


## Test-only reference: the prize as the brute force had it before the field (the same tests, the same numbers).
static func brute_prize(game: Game, brief: AiBrief, target: StringName) -> int:
	var own: Array[Vector2i] = []
	for i: int in AiKnow.land_of(game, brief.tag):
		own.append(AiKnow.hex_of(game, i))
	var total := 0
	for i: int in AiKnow.land_of(game, target):
		var hex := AiKnow.hex_of(game, i)
		if not AiKnow.is_land(game, hex) or AiKnow.controller_of(game, hex) == brief.tag:
			continue
		var state := AiKnow.area_state(game, hex)
		if (state == AiWar.STATE_OPEN or state == AiWar.STATE_FALLEN or state == AiWar.STATE_HELD) and _brute_within(hex, own, brief.ai.prize_range):
			total += 1
	for hex: Vector2i in AiKnow.fortresses_of(game, target):
		if AiKnow.fortress_level(game, hex) >= 2 and _brute_within(hex, own, brief.ai.prize_range):
			total += 2
	return total


static func _brute_within(hex: Vector2i, hexes: Array[Vector2i], range_hexes: int) -> bool:
	for other: Vector2i in hexes:
		if AiKnow.hex_distance(hex, other) <= range_hexes:
			return true
	return false


func _others(game: Game, tag: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: Country in game.countries:
		if c != null and c.alive and c.tag != tag and c.tag != &"":
			out.append(c.tag)
	return out


func test_the_field_is_the_brute_force_on_the_duel_for_several_ranges() -> void:
	var g := S.ready_duel()
	for range_hexes: int in [0, 1, 2, 3, 5]:
		S.ai(g, {"prize_range": range_hexes})
		var b := S.brief(g)
		for target: StringName in _others(g, M):
			assert_eq(AiWar.prize_of(g, b, target), brute_prize(g, b, target),
				"prize of %s within %d" % [target, range_hexes])


func test_the_field_is_the_brute_force_on_a_seasoned_ai_game() -> void:
	var g := AiFixture.watch()
	var seats := AiKnow.living(g)
	for k: int in mini(seats.size(), 6):
		var tag := seats[k]
		var b := AiBrief.make(g, tag)
		for target: StringName in _others(g, tag):
			assert_eq(AiWar.prize_of(g, b, target), brute_prize(g, b, target), "%s's prize of %s" % [tag, target])


func test_the_field_holds_the_land_at_zero_and_nothing_beyond_the_range() -> void:
	var g := S.ready_duel()
	var field := AiKnow.land_field(g, M, 2)
	for i: int in AiKnow.land_of(g, M):
		assert_eq(field.get(AiKnow.hex_of(g, i)), 0, "own land at distance 0")
	for hex: Vector2i in field:
		assert_lte(int(field[hex]), 2, "no key beyond the range")
	var far := Vector2i(-50, -50)
	assert_false(field.has(far), "a hex far from the land is no key")


func test_the_near_field_follows_the_land_after_a_version_bump() -> void:
	var g := S.ready_duel()
	S.ai(g, {"prize_range": 2})
	var b := S.brief(g)
	# One Genoese hex within the range of Milan's land becomes Milan's: the field must now hold it (the same brief, a new version).
	var near := AiKnow.land_field(g, M, 2)
	var gained: Vector2i = Army.NO_HEX
	for i: int in AiKnow.land_of(g, GEN):
		var hex := AiKnow.hex_of(g, i)
		if near.has(hex) and not AiKnow.land_of(g, M).has(AiKnow.index_of(g, hex)):
			gained = hex
			break
	assert_ne(gained, Vector2i(Army.NO_HEX), "a Genoese hex in range of Milan")
	var hexes: Array[Vector2i] = [gained]
	Territory.transfer(g, hexes, Countries.by_tag(g, M).id)
	g.version += 1
	assert_true(b.near_land().has(gained), "the field is rebuilt for the new version")
	assert_eq(int(b.near_land()[gained]), 0, "the hex is now the seat's own land")
	assert_eq(AiWar.prize_of(g, b, GEN), brute_prize(g, b, GEN), "the prize follows the land")
