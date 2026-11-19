## Luck tests (docs/architecture/m3-build-spec.md 5.2, 9).
extends GutTest


func test_seeded_is_deterministic_and_streams_differ() -> void:
	var a := Luck.seeded(1480)
	var b := Luck.seeded(1480)
	assert_eq(a.digest_text(), b.digest_text())
	assert_ne(a.world.get_state(), a.ai.get_state())
	assert_ne(a.world.get_state(), a.decor.get_state())
	assert_ne(a.ai.get_state(), a.decor.get_state())
	assert_ne(Luck.seeded(1481).digest_text(), a.digest_text())


func test_round_trip() -> void:
	var a := Luck.seeded(7)
	a.world.randi_range(0, 9)
	var b := Luck.from_dict(a.to_dict(), 7)
	assert_eq(b.digest_text(), a.digest_text())
	assert_eq(b.world.randi_range(0, 1000000), a.world.randi_range(0, 1000000))


func test_missing_stream_falls_back_to_seeded() -> void:
	var a := Luck.seeded(7)
	a.world.randi_range(0, 9)
	var d := a.to_dict()
	d.erase("ai")
	assert_eq(Luck.from_dict(d, 7).digest_text(), Luck.seeded(7).digest_text())
	assert_eq(Luck.from_dict({}, 7).digest_text(), Luck.seeded(7).digest_text())
