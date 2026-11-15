## The settlement names of the map prototype (shell/worldmap/world_labels.gd): a name takes the first free spot around its
## marker, a crowded name moves to another spot, the higher-ranked name is placed first, a name with no free spot is dropped,
## and a name stays inside the bounds of the map.
extends GutTest

const HALF := 9.0
const SIZE := 12.0


func _item(label: String, at: Vector2, width: float, rank: int) -> Dictionary:
	return {"name": label, "at": at, "width": width, "size": SIZE, "rank": rank, "half": HALF}


func _bounds() -> Rect2:
	return Rect2(0.0, 0.0, 1000.0, 800.0)


func test_a_name_takes_the_spot_right_and_above_its_marker_when_it_is_free() -> void:
	var placed := WorldLabels.place([_item("Como", Vector2(400.0, 300.0), 40.0, 30)], [], _bounds())
	assert_eq(placed.size(), 1, "the name is placed")
	var box: Rect2 = placed[0]["box"]
	assert_almost_eq(box.position.x, 400.0 + HALF + WorldLabels.GAP, 0.001, "to the right of the marker")
	assert_lt(box.position.y + box.size.y, 300.0, "above the marker's centre")


func test_a_crowded_name_moves_to_another_spot() -> void:
	var at := Vector2(400.0, 300.0)
	var right_up := WorldLabels.box_at(WorldLabels.Spot.RIGHT_UP, _item("Como", at, 40.0, 30))
	var placed := WorldLabels.place([_item("Como", at, 40.0, 30)], [right_up], _bounds())
	assert_eq(placed.size(), 1, "the name is still placed")
	var box: Rect2 = placed[0]["box"]
	assert_false(box.intersects(right_up), "it avoids the obstacle")
	assert_false(WorldLabels.box_at(WorldLabels.Spot.RIGHT_UP, _item("Como", at, 40.0, 30)) == box, "it is another spot")


func test_a_name_with_no_free_spot_is_dropped_and_the_higher_ranked_name_is_placed_first() -> void:
	var at := Vector2(400.0, 300.0)
	# A wall of obstacles round the marker: every spot is taken, so both names find no room and are dropped.
	var wall := Rect2(at.x - 200.0, at.y - 200.0, 400.0, 400.0)
	var none := WorldLabels.place([_item("Lodi", at, 30.0, 10), _item("Milan", at, 40.0, 50)], [wall], _bounds())
	assert_eq(none.size(), 0, "no free spot: both names are dropped")
	# Without obstacles both fit (right-above and right-below of one marker), and the higher rank comes first.
	var both := WorldLabels.place([_item("Lodi", at, 30.0, 10), _item("Milan", at, 40.0, 50)], [], _bounds())
	assert_eq(both.size(), 2, "both names fit round the marker")
	assert_eq(str(both[0]["name"]), "Milan", "the higher-ranked name is placed first")
	assert_false((both[0]["box"] as Rect2).intersects(both[1]["box"] as Rect2), "and the two boxes do not overlap")


func test_names_do_not_overlap_each_other() -> void:
	var items: Array[Dictionary] = []
	for i: int in 12:
		items.append(_item("Town %d" % i, Vector2(400.0 + float(i % 3) * 6.0, 300.0 + floorf(float(i) / 3.0) * 4.0), 50.0, i))
	var placed := WorldLabels.place(items, [], _bounds())
	for i: int in placed.size():
		for j: int in range(i + 1, placed.size()):
			var a: Rect2 = placed[i]["box"]
			var b: Rect2 = placed[j]["box"]
			assert_false(a.intersects(b), "%s and %s do not overlap" % [placed[i]["name"], placed[j]["name"]])
	assert_lt(placed.size(), items.size(), "a crowded group drops its lowest-ranked names")
	assert_gt(placed.size(), 0, "and keeps some")


func test_a_name_stays_inside_the_bounds() -> void:
	var placed := WorldLabels.place([_item("Venice", Vector2(995.0, 300.0), 50.0, 50)], [], _bounds())
	assert_eq(placed.size(), 1, "the name is placed")
	var box: Rect2 = placed[0]["box"]
	assert_true(_bounds().encloses(box), "the box is inside the map")
	assert_lt(box.position.x + box.size.x, 1000.0, "not past the right edge")
