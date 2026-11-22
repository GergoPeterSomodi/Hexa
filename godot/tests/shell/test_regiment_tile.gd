## RegimentTile (docs/architecture/m7-build-spec.md 6.5; M7 B22): a company shows its marks (routed, shaken, fires); an empty,
## closed or broken lane shows its words and no company content.
extends GutTest


func test_company_marks_follow_its_flags() -> void:
	var tile := RegimentTile.new()
	add_child_autofree(tile)
	tile.set_entry({"empty": false, "name": "Pikemen", "figure": "", "men": 400, "full": 500, "morale": 800,
		"routed": true, "shaken": true, "fires": false})
	assert_eq(tile.kind(), "", "a company is not an empty lane")
	assert_eq(tile.mark_texts(), PackedStringArray(["Routed", "Shaken"]), "routed and shaken, not fires")


func test_empty_lanes_show_their_words() -> void:
	var tile := RegimentTile.new()
	add_child_autofree(tile)
	tile.set_entry({"empty": true, "closed": true, "broken": false})
	assert_eq(tile.kind(), "closed")
	assert_eq(tile.accessibility_name, "Closed lane")
	tile.set_entry({"empty": true, "closed": false, "broken": true})
	assert_eq(tile.kind(), "broken")
	assert_eq(tile.accessibility_name, "Broken lane")
	tile.set_entry({"empty": true, "closed": false, "broken": false})
	assert_eq(tile.kind(), "empty")
	assert_eq(tile.accessibility_name, "Empty lane")
