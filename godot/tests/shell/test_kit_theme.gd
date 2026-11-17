## Tests for KitTheme.load_for scale switching (1x, 2x ImageTexture size override, and plain/high-contrast)
## (docs/architecture/ui-style-and-feedback-spec.md sections 4.8, 4.9 and 11).
extends GutTest


func _load_pieces() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KitTheme.KIT_JSON))
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	return (parsed as Dictionary).get("pieces", {}) as Dictionary


func test_load_for_1x_at_auto_low_scale_and_explicit_1x() -> void:
	var t_auto := KitTheme.load_for(1.0, &"auto")
	var t_125 := KitTheme.load_for(1.25, &"auto")
	var t_1x := KitTheme.load_for(2.0, &"1x")
	assert_not_null(t_auto)
	assert_not_null(t_125)
	assert_not_null(t_1x)

	for t: Theme in [t_auto, t_125, t_1x]:
		var sb := t.get_stylebox(&"panel", &"PanelContainer") as StyleBoxTexture
		assert_not_null(sb)
		assert_true(sb.texture.resource_path.begins_with(KitTheme.KIT_1X_DIR), "uses 1x panel_frame")
		assert_eq(sb.texture.get_size(), Vector2(160.0, 160.0), "1x panel_frame logical size")

		var seal := t.get_icon(&"seal", &"Kit")
		assert_not_null(seal)
		assert_true(seal.resource_path.begins_with(KitTheme.KIT_1X_DIR), "uses 1x seal")
		assert_eq(seal.get_size(), Vector2(72.0, 72.0))


func test_load_for_2x_swaps_to_image_texture_with_size_override_and_preserves_1x() -> void:
	var pieces := _load_pieces()
	var t_2x := KitTheme.load_for(2.0, &"auto")
	var t_15x := KitTheme.load_for(1.5, &"auto")
	var t_forced := KitTheme.load_for(1.0, &"2x")

	for t: Theme in [t_2x, t_15x, t_forced]:
		assert_not_null(t)
		var sb_panel := t.get_stylebox(&"panel", &"PanelContainer") as StyleBoxTexture
		assert_not_null(sb_panel)
		var itex := sb_panel.texture as ImageTexture
		assert_not_null(itex, "2x panel_frame texture is wrapped in ImageTexture")
		assert_eq(itex.get_size(), Vector2(160.0, 160.0), "2x panel_frame reports 1x logical size")
		assert_eq(itex.get_image().get_size(), Vector2i(320, 320), "2x panel_frame backing image is 2x")
		assert_eq(sb_panel.texture_margin_left, 32.0, "9-slice margin stays logical")

		var sb_btn := t.get_stylebox(&"normal", &"Button") as StyleBoxTexture
		assert_not_null(sb_btn)
		var btn_tex := sb_btn.texture as ImageTexture
		assert_not_null(btn_tex, "2x button texture is ImageTexture")
		assert_eq(btn_tex.get_size(), Vector2(64.0, 40.0), "2x button reports 1x logical size")
		assert_eq(btn_tex.get_image().get_size(), Vector2i(128, 80), "2x button backing image is 2x")

		var seal_tex := t.get_icon(&"seal", &"Kit") as ImageTexture
		assert_not_null(seal_tex, "2x seal icon is ImageTexture")
		assert_eq(seal_tex.get_size(), Vector2(72.0, 72.0), "2x seal reports 1x logical size")
		assert_eq(seal_tex.get_image().get_size(), Vector2i(144, 144), "2x seal backing image is 2x")

		var arrow_down := t.get_icon(&"arrow_down", &"Kit") as ImageTexture
		assert_not_null(arrow_down, "2x icons_base slice is ImageTexture")
		assert_eq(arrow_down.get_size(), Vector2(16.0, 16.0), "2x slice reports 16x16 logical size")
		assert_eq(arrow_down.get_image().get_size(), Vector2i(32, 32), "2x slice backing image is 32x32")
		assert_gt(arrow_down.get_image().get_pixel(16, 16).a, 0.5, "2x arrow_down center pixel is opaque")

	# Confirm every StyleBoxTexture in 2x was swapped and reports its 1x logical size from ui_kit.json
	for type_name: StringName in t_2x.get_stylebox_type_list():
		for sb_name: StringName in t_2x.get_stylebox_list(type_name):
			var sb := t_2x.get_stylebox(sb_name, type_name)
			if sb is StyleBoxTexture:
				var tex := (sb as StyleBoxTexture).texture as ImageTexture
				assert_not_null(tex, "%s/%s swapped to ImageTexture" % [type_name, sb_name])

	# Confirm 1x theme.tres in ResourceLoader cache was not mutated
	var t_1x_after := KitTheme.load_for(1.0, &"auto")
	var sb_1x := t_1x_after.get_stylebox(&"panel", &"PanelContainer") as StyleBoxTexture
	assert_true(sb_1x.texture.resource_path.begins_with(KitTheme.KIT_1X_DIR), "1x theme stays untouched")
	var expected_sz: Array = (pieces["panel_frame"] as Dictionary)["size"]
	assert_eq(sb_1x.texture.get_size(), Vector2(float(expected_sz[0]), float(expected_sz[1])))


func test_load_for_plain_and_high_contrast_return_flat_theme() -> void:
	for t: Theme in [
		KitTheme.load_for(1.0, &"plain"),
		KitTheme.load_for(2.0, &"plain"),
		KitTheme.load_for(2.0, &"auto", true),
		KitTheme.load_for(1.0, &"2x", true),
	]:
		assert_not_null(t)
		var panel_sb := t.get_stylebox(&"panel", &"PanelContainer") as StyleBoxFlat
		assert_not_null(panel_sb, "plain/high_contrast returns StyleBoxFlat")
		assert_eq(panel_sb.bg_color, Color("#000000"))
		assert_eq(panel_sb.border_color, Color("#ffd646"))
		assert_eq(t.get_color(&"font_color", &"Label"), Color("#ffffff"))
		for type_name: StringName in t.get_stylebox_type_list():
			for sb_name: StringName in t.get_stylebox_list(type_name):
				assert_false(
					t.get_stylebox(sb_name, type_name) is StyleBoxTexture,
					"plain/HC has no StyleBoxTexture at %s/%s" % [type_name, sb_name]
				)
