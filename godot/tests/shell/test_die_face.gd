## DieFace (docs/architecture/m7-build-spec.md 6.5; M7 B22): the bone die's pips follow the value (1 to 6, anything else
## clamped) and the multiplier under it widens the face when it is wider than the die.
extends GutTest


func test_pips_follow_the_face_value() -> void:
	var die := DieFace.new()
	add_child_autofree(die)
	for face: int in range(1, 7):
		die.set_face(face, "×1.0")
		assert_eq(die.pip_count(), face, "face %d has %d pips" % [face, face])
		assert_eq(die.value, face)


func test_out_of_range_faces_are_clamped() -> void:
	var die := DieFace.new()
	add_child_autofree(die)
	die.set_face(0, "")
	assert_eq(die.value, 1, "below 1 shows 1")
	die.set_face(9, "")
	assert_eq(die.value, 6, "above 6 shows 6")


func test_multiplier_under_the_die_adds_height_and_width_when_wider() -> void:
	var die := DieFace.new()
	add_child_autofree(die)
	die.set_face(3, "")
	var bare := die.custom_minimum_size
	die.set_face(3, "×1.1")
	assert_gt(die.custom_minimum_size.y, bare.y, "the multiplier adds a line under the face")
	die.set_face(3, "×12345.6789 with a long word")
	assert_gt(die.custom_minimum_size.x, DieFace.FACE_PX, "a long multiplier widens the face")
