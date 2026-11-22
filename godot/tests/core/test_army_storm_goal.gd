## A saved storm order needs its goal on the map, as a march does (review of B2; armies.gd _army_ok): a forged goal off the
## map is refused, and a storm whose goal is on the map reads back.
extends GutTest


func test_a_storm_order_needs_its_goal_on_the_map() -> void:
	var g := ArmyFixture.game()
	var hex := ArmyFixture.find_town(g)
	ArmyFixture.army(g, ArmyFixture.TAG, hex, 0, 2)
	var saved := JSON.stringify(Armies.to_dict(g))
	var d: Dictionary = JSON.parse_string(saved)
	var army: Dictionary = (d["list"] as Array)[0]
	army["order"] = "storm"
	army["goal"] = [99999, 99999]
	var on_map: Dictionary = JSON.parse_string(saved)
	var kept: Dictionary = (on_map["list"] as Array)[0]
	kept["order"] = "storm"
	kept["goal"] = [hex.x, hex.y]
	g.armies = []
	assert_ne(Armies.from_dict(d, g), "", "P: a storm goal off the map is refused, as a march's is")
	g.armies = []
	assert_eq(Armies.from_dict(on_map, g), "", "a storm whose goal is on the map reads")
