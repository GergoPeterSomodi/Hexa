## The stages of the Europe build: the labels, the progress, and that running them one by one gives the same map as the
## single call (the shell shows the stages, so they must not change the result).
extends GutTest


func test_stages_run_in_order_and_report_progress() -> void:
	var steps := MapBuildSteps.new(EuropeData.load_europe())
	assert_eq(steps.next_label(), "Land and sea", "the first stage")
	assert_almost_eq(steps.progress(), 0.0, 0.0001, "nothing done")
	var ran := 0
	var last := -1.0
	while steps.run_next():
		ran += 1
		assert_true(steps.progress() > last, "progress grows at every stage")
		last = steps.progress()
	assert_eq(ran, MapBuildSteps.LABELS.size(), "every stage ran once")
	assert_true(steps.is_done(), "done")
	assert_eq(steps.next_label(), "", "no label after the last stage")
	assert_false(steps.run_next(), "nothing runs after the last stage")


func test_stepped_build_is_the_same_map_as_the_single_call() -> void:
	var data := EuropeData.load_europe()
	var stepped := MapBuildSteps.new(data)
	while stepped.run_next():
		pass
	var single := MapBuilder.build_europe(data)
	assert_eq(stepped.map.terrain.size(), single.terrain.size(), "hexes")
	assert_eq(stepped.map.provinces.size(), single.provinces.size(), "provinces")
	assert_eq(stepped.map.countries.size(), single.countries.size(), "countries")
	assert_eq(stepped.map.roads.size(), single.roads.size(), "road hexes")
	assert_eq(stepped.map.units.size(), single.units.size(), "starting units")
	assert_eq(stepped.map.city_names.size(), single.city_names.size(), "cities")
