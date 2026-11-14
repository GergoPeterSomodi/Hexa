## The political helpers on a small fixture: owners, borders, capitals and the points where country names go, plus the
## settlement and castle rule of the town layer.
extends GutTest


func _province(pos: Vector2i, owner: String) -> Province:
	var prov := Province.new()
	prov.pos = pos
	prov.terrain = "plains"
	prov.owner = owner
	return prov


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
	var por := Country.new()
	por.tag = "POR"
	por.name = "Portugal"
	por.capital = Vector2i(1, 0)
	map.countries["POR"] = por
	map.country_order.append("POR")
	var cas := Country.new()
	cas.tag = "CAS"
	cas.name = "Castile"
	cas.capital = Vector2i(2, 0)
	map.countries["CAS"] = cas
	map.country_order.append("CAS")
	return map


func test_owners_skip_unowned_hexes() -> void:
	var owned := Political.owners(_fixture())
	assert_eq(owned.size(), 3, "three owned hexes")
	assert_eq(owned[Vector2i(2, 0)], "CAS", "owner of (2, 0)")
	assert_false(owned.has(Vector2i(3, 0)), "(3, 0) has no owner")


func test_borders_are_the_edges_between_different_owners() -> void:
	var map := _fixture()
	var edges := Political.border_edges(map)
	# POR | CAS at (1, 0)-(2, 0), and CAS | nobody at (2, 0)-(3, 0). Not POR | POR, and nothing on the sea.
	assert_eq(edges.size(), 2, "two border edges")
	assert_true(edges.has(HexGrid.edge_key(Vector2i(1, 0), Vector2i(2, 0))), "POR-CAS border")
	assert_true(edges.has(HexGrid.edge_key(Vector2i(2, 0), Vector2i(3, 0))), "CAS-nobody border")


func test_capitals_follow_the_country_order() -> void:
	var caps := Political.capitals(_fixture())
	assert_eq(caps, [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i], "capitals in order")


func test_name_points_sit_on_an_owned_hex_of_the_country() -> void:
	var points := Political.name_points(_fixture())
	assert_eq(points.size(), 2, "two countries with land")
	assert_eq(points[0]["name"], "Portugal", "first name")
	var at: Vector2i = points[0]["at"]
	assert_eq(Political.owner_of(_fixture(), at), "POR", "the name sits on Portugal")


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
