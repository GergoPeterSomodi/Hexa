## GUT tests for the season fade's capture guard (docs/architecture/m3-build-spec.md 6.9 and 10): a capture that takes too long
## switches the fade to its fallback so the game never freezes at a season end.
extends GutTest


func test_a_slow_capture_switches_to_the_fallback() -> void:
	var fade := SeasonFade.new()
	add_child_autofree(fade)
	assert_eq(fade.method, SeasonFade.Method.PRIMARY)
	fade.note_capture_cost(SeasonFade.SLOW_CAPTURE_MS - 1.0)
	assert_eq(fade.method, SeasonFade.Method.PRIMARY, "a capture inside the limit keeps the picture fade")
	fade.note_capture_cost(SeasonFade.SLOW_CAPTURE_MS + 1.0)
	assert_eq(fade.method, SeasonFade.Method.FALLBACK, "a capture over the limit uses the fallback from then on")
	assert_almost_eq(fade.last_capture_ms, SeasonFade.SLOW_CAPTURE_MS + 1.0, 0.001)
