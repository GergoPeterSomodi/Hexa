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


func test_fires_is_an_icon_with_its_word_in_the_tooltip() -> void:
	var tile := RegimentTile.new()
	add_child_autofree(tile)
	tile.set_entry({"empty": false, "name": "Pikemen", "figure": "", "men": 400, "full": 500, "morale": 800,
		"routed": false, "shaken": false, "fires": true})
	assert_eq(tile.mark_texts(), PackedStringArray(["Fires"]), "the mark's word is its tooltip")
	for lbl_node: Node in tile.find_children("*", "Label", true, false):
		assert_lte((lbl_node as Label).text.length(), 12, "a short text, never a vertical word")


func test_long_unit_names_stay_on_one_line_at_both_scales() -> void:
	for scale: float in [1.0, 2.0]:
		for unit_name: String in ["Pikemen", "Arquebusiers", "Cuirassiers", "Supply wagon", "Mounted Crossbowmen"]:
			var tile := RegimentTile.new()
			add_child_autofree(tile)
			tile.custom_minimum_size.x = 120.0 * scale
			tile.set_entry({"empty": false, "name": unit_name, "figure": "", "men": 446, "full": 500, "morale": 800,
				"routed": true, "shaken": true, "fires": true})
			tile.size = Vector2(120.0 * scale, 10.0)
			await get_tree().process_frame
			for lbl_node: Node in tile.find_children("*", "Label", true, false):
				var lbl := lbl_node as Label
				assert_eq(lbl.autowrap_mode, TextServer.AUTOWRAP_OFF, "'%s' does not wrap" % lbl.text)
				assert_lte(lbl.get_line_count(), 1, "'%s' is one line at scale %s" % [lbl.text, scale])

