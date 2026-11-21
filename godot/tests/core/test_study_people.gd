## StudyPeople (docs/architecture/m5-build-spec.md 5.6, 6.6, 4.11 (a)): the page's view of Genoa in Summer 1480 equals the
## worked numbers and its series equal Stats.
extends GutTest

const GEN := &"GEN"
const GENOA := Vector2i(8, 13)
const SAVONA := Vector2i(6, 13)


func test_before_a_season_has_ended() -> void:
	var g := PeopleFixture.genoa()
	var p := StudyPeople.of(g, GEN, 12)
	assert_false(bool(p["has_data"]))
	assert_eq(p["date"], "Spring 1480")
	assert_eq(int((p["head"] as Dictionary)["people"]), 82700)
	assert_eq((p["food"] as Dictionary)["text"], "No season has ended yet.")
	assert_eq((p["rows"] as Array).size(), 2)
	assert_eq(int(((p["rows"] as Array)[0] as Dictionary)["change"]), 0)
	assert_eq((p["labels"] as Array).size(), 0)


func test_summer_1480_numbers() -> void:
	var g := PeopleFixture.genoa()
	Season.run(g)
	var p := StudyPeople.of(g, GEN, 12)
	assert_true(bool(p["has_data"]))
	assert_eq(p["date"], "Summer 1480")
	var head: Dictionary = p["head"]
	assert_eq(int(head["people"]), 83285)
	assert_eq(int(head["change"]), 585)
	assert_eq(int(head["towns"]), 40400)
	assert_eq(int(head["countryside"]), 42885)
	assert_eq(int(head["room_left"]), 32415)
	assert_eq(int(head["expected"]), 589)
	var rows: Array = p["rows"]
	assert_eq(rows.size(), 2)
	var genoa: Dictionary = rows[0]
	assert_eq(genoa["hex"], GENOA)
	assert_eq(genoa["place"], "Genoa (8, 13)")
	assert_eq(genoa["what"], "walled town · port")
	assert_eq(int(genoa["people"]), 30300)
	assert_eq(int(genoa["room"]), 45000)
	assert_eq(int(genoa["change"]), 300)
	assert_eq(genoa["outlook"], "Room for 14,700 more; a city would give room for 100,000.")
	var savona: Dictionary = rows[1]
	assert_eq(savona["hex"], SAVONA)
	assert_eq(int(savona["people"]), 10100)
	assert_eq(int(savona["change"]), 100)
	var country: Dictionary = p["countryside"]
	assert_eq(int(country["count"]), 12)
	assert_eq(int(country["people"]), 42885)
	assert_eq(int(country["room"]), 50700)
	assert_eq(int(country["change"]), 185)
	var food: Dictionary = p["food"]
	assert_eq(int(food["need"]), 4)
	assert_eq(int(food["fed"]), 1000)
	assert_true(str(food["text"]).begins_with("Food: "), food["text"])
	assert_true(str(food["text"]).contains("Fed, "), food["text"])
	assert_eq(food["lasts_text"], "over 8 seasons")


func test_series_equal_stats_and_labels() -> void:
	var g := PeopleFixture.genoa()
	PeopleFixture.play(g, 3)
	var p := StudyPeople.of(g, GEN, 12)
	var series: Dictionary = p["series"]
	var names := {"people": "people", "towns": "people_towns", "grew": "people_grew", "starved": "people_starved",
		"left": "people_left", "food_made": "food_made", "food_eaten": "food_eaten", "food_need": "food_need"}
	for key: String in names:
		assert_eq(series[key], g.stats.series(GEN, names[key], 12), key)
		assert_eq((series[key] as PackedInt32Array).size(), 3, key)
	assert_eq(p["labels"], ["Spring 1480", "Summer 1480", "Autumn 1480"])
	assert_eq((series["people"] as PackedInt32Array)[0], 83285)
	assert_eq(StudyPeople.of(g, GEN, 2)["labels"], ["Summer 1480", "Autumn 1480"])


func test_rows_are_sorted_by_people() -> void:
	var g := PeopleFixture.genoa()
	g.state.people[g.map.index_of(SAVONA)] = 44000
	g.version += 1
	var rows: Array = StudyPeople.of(g, GEN, 12)["rows"]
	assert_eq((rows[0] as Dictionary)["hex"], SAVONA, "people descending")
	assert_eq((rows[1] as Dictionary)["hex"], GENOA)


func test_food_line_forms() -> void:
	var g := PeopleFixture.genoa()
	Season.run(g)
	var c := Countries.by_tag(g, GEN)
	assert_eq(StudyPeople.food_line(c, 8, 4, 20, 0), "Food: 8 made for 4 eaten. Fed, 4 to spare.")
	assert_eq(StudyPeople.food_line(c, 3, 5, 12, 0), "Food: 3 made for 5 eaten. Fed from the stores: 12 left.")
	c.food_fed = 500
	c.food_need = 9
	assert_eq(StudyPeople.food_line(c, 8, 8, 0, 404), "Food: 8 made for 9 needed. 1 short: your towns lost 404 people to hunger.")


func test_foreign_country_gets_the_empty_page() -> void:
	var g := PeopleFixture.genoa()
	var p := StudyPeople.of(g, &"MLO", 12)
	assert_false(bool(p["has_data"]))
	assert_eq((p["rows"] as Array).size(), 0)
	assert_eq(int((p["head"] as Dictionary)["people"]), 0)


func test_the_page_writes_nothing() -> void:
	var g := PeopleFixture.genoa()
	Season.run(g)
	var before := g.digest()
	StudyPeople.of(g, GEN, 12)
	StudyPeople.of(g, GEN, 40)
	assert_eq(g.digest(), before)
