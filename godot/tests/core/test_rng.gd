## Sample GUT test: the luck source of core/ is repeatable and can be saved and resumed.
extends GutTest

const Rng := preload("res://core/rng.gd")


func test_same_seed_gives_the_same_numbers() -> void:
	var first := Rng.new()
	var second := Rng.new()
	first.seed_with(1480)
	second.seed_with(1480)
	var a: Array[int] = []
	var b: Array[int] = []
	for i in 20:
		a.append(first.randi_range(0, 1000))
		b.append(second.randi_range(0, 1000))
	assert_eq(a, b, "the same seed gives the same sequence")


func test_saved_state_resumes_the_sequence() -> void:
	var rng := Rng.new()
	rng.seed_with(7)
	rng.randi_range(0, 9)
	var saved := rng.get_state()
	var expected := rng.randi_range(0, 1000000)
	var resumed := Rng.new()
	resumed.set_state(saved)
	assert_eq(resumed.randi_range(0, 1000000), expected, "a restored state draws the same next number")
