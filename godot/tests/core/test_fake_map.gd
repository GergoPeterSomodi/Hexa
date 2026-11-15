## The made-up map (core/mapgen/fake_map.gd; docs/architecture/m1-build-spec.md section 9): it validates, the shares of land,
## woods and river edges are in the ranges of the spec, the same seed gives the same digest, a place sits on land, roads
## join places. Time is never asserted here (tools/perf_map.gd measures it).
extends GutTest

const COLS := 494
const ROWS := 247

var _big: MapData = null


func before_all() -> void:
	_big = FakeMap.build(COLS, ROWS, 1480)


## Every validate() message is a real fault (corner keys are exact integers since M1 group B).
func _real_errors(map: MapData, _label: String) -> Array[String]:
	return map.validate()


func test_big_map_validates() -> void:
	assert_eq(_big.cols, COLS)
	assert_eq(_big.rows, ROWS)
	assert_eq(_real_errors(_big, "494 x 247"), [] as Array[String])


func test_shares_in_the_ranges_of_the_spec() -> void:
	var land := 0
	var woods := 0
	for i: int in _big.hex_count():
		if _big.land[i] == 1:
			land += 1
			if _big.cover[i] == FakeMap.COVER_WOODS:
				woods += 1
	var rivers := 0
	for v: int in _big.river:
		if v > 0:
			rivers += 1
	var land_share := float(land) / float(_big.hex_count())
	var woods_share := float(woods) / float(land)
	var river_share := float(rivers) / float(_big.edge_count())
	gut.p("land %.3f woods %.3f (of land) %.3f (of all hexes) rivers %.4f, %d places, %d rivers drawn" % [
		land_share, woods_share, float(woods) / float(_big.hex_count()), river_share, _big.places.size(), _big.rivers.size()])
	assert_between(land_share, 0.55, 0.65, "land share")
	assert_between(woods_share, 0.12, 0.18, "woods share of the land")
	assert_between(river_share, 0.04, 0.06, "river share of the edges")


func test_places_and_roads() -> void:
	assert_gt(_big.places.size(), 1000)
	var roads := 0
	for v: int in _big.road:
		if v > 0:
			roads += 1
	assert_gt(roads, 1000)
	for p: Dictionary in _big.places:
		assert_true(_big.is_land(p["hex"]))


func test_same_seed_same_digest() -> void:
	var a := FakeMap.build(120, 80, 7)
	var b := FakeMap.build(120, 80, 7)
	var c := FakeMap.build(120, 80, 8)
	assert_eq(a.digest(), b.digest())
	assert_ne(a.digest(), c.digest())
	assert_eq(_real_errors(a, "120 x 80 seed 7"), [] as Array[String])
	assert_eq(_real_errors(c, "120 x 80 seed 8"), [] as Array[String])


func test_small_maps_validate() -> void:
	for size: Vector2i in [Vector2i(7, 5), Vector2i(21, 19), Vector2i(60, 40)]:
		for s: int in 3:
			var m := FakeMap.build(size.x, size.y, s)
			assert_eq(_real_errors(m, "%s seed %d" % [size, s]), [] as Array[String])


func test_neighbour_tables_match_hexgrid() -> void:
	var g := HexGrid.new(28.0, 111.2, 55.0, 0.0, 71.0)
	for hex: Vector2i in [Vector2i(3, 2), Vector2i(3, 3)]:
		var dirs := FakeMap._dirs(hex.y)
		for d: int in 6:
			assert_eq(hex + dirs[d], g.neighbour(hex, d))
