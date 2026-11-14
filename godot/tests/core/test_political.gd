## The political helpers on a small fixture: owners, borders (with their shades), capitals and the points where country
## names go, plus the settlement and castle rule of the town layer.
extends GutTest


func _province(pos: Vector2i, owner: String) -> Province:
	var prov := Province.new()
	prov.pos = pos
	prov.terrain = "plains"
	prov.owner = owner
	return prov


func _country(tag: String, name: String, capital: Vector2i, colour: Color) -> Country:
	var country := Country.new()
	country.tag = tag
	country.name = name
	country.capital = capital
	country.colour = colour
	return country


func _fixture() -> MapData:
	# Three land hexes in a row: (0, 0) and (1, 0) belong to POR, (2, 0) to CAS, and (3, 0) to nobody; (4, 0) is sea.
	var map := MapData.new()
	map.cols = 5
	map.rows = 1
	for c in 4:
		map.terrain[Vector2i(c, 0)] = "plains"
	map.terrain[Vector2i(4, 0)] = MapData.OCEAN
	map.provinces[Vector2i(0, 0)] = _province(Vector2i(0, 0), "POR")
	map.provinces[Vector2i(1, 0)] = _province(Vector2i(1, 0), "POR")
	map.provinces[Vector2i(2, 0)] = _province(Vector2i(2, 0), "CAS")
	map.provinces[Vector2i(3, 0)] = _province(Vector2i(3, 0), "")
	map.countries["POR"] = _country("POR", "Portugal", Vector2i(1, 0), Color(0.2, 0.6, 0.3))
	map.country_order.append("POR")
	map.countries["CAS"] = _country("CAS", "Castile", Vector2i(2, 0), Color(0.8, 0.5, 0.1))
	map.country_order.append("CAS")
	return map


func _has_border(items: Array[Dictionary], a: Vector2i, b: Vector2i) -> bool:
	for item: Dictionary in items:
		if (item["a"] == a and item["b"] == b) or (item["a"] == b and item["b"] == a):
			return true
	return false


func test_owners_skip_unowned_hexes() -> void:
	var owned := Political.owners(_fixture())
	assert_eq(owned.size(), 3, "three owned hexes")
	assert_eq(owned[Vector2i(2, 0)], "CAS", "owner of (2, 0)")
	assert_false(owned.has(Vector2i(3, 0)), "(3, 0) has no owner")


func test_borders_are_the_edges_between_different_owners() -> void:
	var items := Political.border_items(_fixture())
	# POR | CAS at (1, 0)-(2, 0), and CAS | nobody at (2, 0)-(3, 0). Not POR | POR, and nothing on the sea.
	assert_eq(items.size(), 2, "two border edges")
	assert_true(_has_border(items, Vector2i(1, 0), Vector2i(2, 0)), "POR-CAS border")
	assert_true(_has_border(items, Vector2i(2, 0), Vector2i(3, 0)), "CAS-nobody border")


func test_border_shades_come_from_the_owner_colour() -> void:
	var items := Political.border_items(_fixture())
	var castile := Color(0.8, 0.5, 0.1)
	for item: Dictionary in items:
		if item["a"] == Vector2i(2, 0) and item["b"] == Vector2i(3, 0):
			assert_almost_eq((item["dark"] as Color).r, castile.r * 0.65, 0.001, "dark shade: 65 percent")
			assert_almost_eq((item["light"] as Color).r, castile.r + (1.0 - castile.r) * 0.35, 0.001, "light shade")


func test_capitals_follow_the_country_order() -> void:
	var caps := Political.capitals(_fixture())
	assert_eq(caps, [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i], "capitals in order")


func test_name_points_sit_on_the_largest_body() -> void:
	# Portugal: a body of four hexes in a block, and a lone hex far away (not its largest body). Castile: three hexes.
	var map := MapData.new()
	for pos: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(9, 0)]:
		map.provinces[pos] = _province(pos, "POR")
	for pos: Vector2i in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5)]:
		map.provinces[pos] = _province(pos, "CAS")
	map.countries["POR"] = _country("POR", "Portugal", Vector2i(0, 0), Color.WHITE)
	map.countries["CAS"] = _country("CAS", "Castile", Vector2i(4, 4), Color.WHITE)
	map.country_order = ["POR", "CAS"] as Array[String]
	var points := Political.name_points(map)
	assert_eq(points.size(), 2, "two countries with a body of 3 or more hexes")
	assert_eq(points[0]["name"], "Portugal", "first name")
	assert_eq(points[0]["area"], 4, "the largest body of Portugal")
	var at: Vector2i = points[0]["at"]
	assert_true(at in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
			"the name sits in the largest body, not on the lone hex: %s" % [at])


func test_settlement_pieces_follow_python() -> void:
	var village := _province(Vector2i.ZERO, "POR")
	village.settlement = 1
	assert_eq(TilePlan.settlement_pieces(village), Vector2i(2, 0), "village: level 2")
	village.castle = 2
	assert_eq(TilePlan.settlement_pieces(village), Vector2i(0, 2), "village with a castle shows the castle")
	var town := _province(Vector2i.ZERO, "POR")
	town.settlement = 2
	assert_eq(TilePlan.settlement_pieces(town), Vector2i(3, 0), "market town: level 3")
	town.castle = 1
	assert_eq(TilePlan.settlement_pieces(town), Vector2i(4, 0), "walled town with a castle: level 4")
	var city := _province(Vector2i.ZERO, "POR")
	city.settlement = 3
	city.peasants = 30.0
	assert_eq(TilePlan.settlement_pieces(city), Vector2i(5, 0), "city: level 5")
	city.peasants = 70.0
	assert_eq(TilePlan.settlement_pieces(city), Vector2i(6, 0), "great city at 60 or more people: level 6")
	var tower := _province(Vector2i.ZERO, "POR")
	tower.castle = 3
	assert_eq(TilePlan.settlement_pieces(tower), Vector2i(0, 3), "a castle alone")
