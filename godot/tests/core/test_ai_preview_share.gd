## AiKnow's economy reads share one EconomyPreview walk per version (step 1 of #440): preview_net, upkeep and the food alarm
## equal the direct previews to the unit on many states, a version move serves a fresh value (stale-cache), and the one
## two-season walk's season 0 equals the one-season ask. Nothing here times anything.
extends GutTest


func _food_direct(game: Game, tag: StringName) -> bool:
	var food: Array[int] = []
	for g: int in game.defs.goods.size():
		if game.defs.goods[g].kind == &"food":
			food.append(g)
	for entry: Dictionary in EconomyPreview.with(game, tag, {"lines": false}, 2)["seasons"]:
		var used: PackedInt32Array = entry["used"]
		var taken := 0
		for g: int in food:
			taken += used[g] if g < used.size() else 0
		if taken < int(EconomySeason.needs_for(game, int(entry["town"]))["food"]):
			return true
	return false


func _upkeep_direct(game: Game, tag: StringName) -> int:
	var total := 0
	for line: Dictionary in EconomyPreview.expected(game, tag).get("lines", []):
		if int(line["amount"]) < 0:
			total -= int(line["amount"])
	return total


func _check_state(game: Game, label: String) -> void:
	for c: Country in game.countries:
		if not c.alive:
			continue
		var tag := c.tag
		var where := "%s %s" % [label, String(tag)]
		var one := EconomyPreview.with(game, tag, {}, 1)["seasons"] as Array
		var own_net := int((one[0] as Dictionary)["net"]) if not one.is_empty() else 0
		assert_eq(AiKnow.preview_net(game, tag), own_net, where + " own-level net")
		assert_eq(AiKnow.preview_net(game, tag, -1), own_net, where + " tax -1 is the own level")
		for level: int in 3:
			var at := EconomyPreview.with(game, tag, {"tax": level}, 1)["seasons"] as Array
			var net_at := int((at[0] as Dictionary)["net"]) if not at.is_empty() else 0
			assert_eq(AiKnow.preview_net(game, tag, level), net_at, "%s net at tax %d" % [where, level])
		assert_eq(AiKnow.upkeep(game, tag), _upkeep_direct(game, tag), where + " upkeep")
		assert_eq(bool(AiKnow.alarms(game, tag)["food_soon"]), _food_direct(game, tag), where + " food soon")


func test_the_shared_walk_equals_the_direct_previews_over_played_seasons() -> void:
	var g := AiFixture.watch()
	_check_state(g, "start")
	for k: int in 3:
		Season.run(g)
		_check_state(g, "season %d" % (k + 1))


func test_a_version_move_serves_a_fresh_net() -> void:
	var g := AiFixture.watch()
	var tag := AiFixture.GENOA
	var before := AiKnow.preview_net(g, tag)
	var version := g.version
	Season.run(g)
	assert_gt(g.version, version, "the season moved the version")
	var after := int((EconomyPreview.with(g, tag, {}, 1)["seasons"][0] as Dictionary)["net"])
	assert_eq(AiKnow.preview_net(g, tag), after, "the net is the new version's, not the old one (before %d)" % before)
	assert_eq(AiKnow.preview_net(g, tag), AiKnow.preview_net(g, tag), "a second read in one version agrees")


func test_the_own_level_walk_is_shared_across_reads_of_one_version() -> void:
	var g := AiFixture.watch()
	var tag := AiFixture.GENOA
	var a := AiKnow._two(g, tag)
	assert_true(is_same(a, AiKnow._two(g, tag)), "one walk per version and country")
	g.version += 1
	assert_false(is_same(a, AiKnow._two(g, tag)), "a new version walks again")
	assert_eq(AiKnow._two(g, tag).size(), 2)
