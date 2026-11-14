## Puts two pictures side by side in one PNG (the v1 and v2 comparisons of the map prototype).
## Run: godot --headless --path godot -s res://tools/worldmap/compose_side_by_side.gd -- --left=<png> --right=<png> --out=<png>
extends SceneTree


func _initialize() -> void:
	var left_path := ""
	var right_path := ""
	var out_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--left="):
			left_path = arg.substr("--left=".length())
		elif arg.begins_with("--right="):
			right_path = arg.substr("--right=".length())
		elif arg.begins_with("--out="):
			out_path = arg.substr("--out=".length())
	var left := Image.load_from_file(left_path)
	var right := Image.load_from_file(right_path)
	if left == null or right == null or out_path == "":
		printerr("compose_side_by_side: give --left, --right and --out (absolute paths)")
		quit(1)
		return
	left.convert(Image.FORMAT_RGBA8)
	right.convert(Image.FORMAT_RGBA8)
	var gap := 12
	var height := maxi(left.get_height(), right.get_height())
	var out := Image.create(left.get_width() + gap + right.get_width(), height, false, Image.FORMAT_RGBA8)
	out.fill(Color.WHITE)
	out.blit_rect(left, Rect2i(Vector2i.ZERO, left.get_size()), Vector2i.ZERO)
	out.blit_rect(right, Rect2i(Vector2i.ZERO, right.get_size()), Vector2i(left.get_width() + gap, 0))
	var err := out.save_png(out_path)
	print("compose_side_by_side: " + out_path + " (" + str(err) + ")")
	quit(0 if err == OK else 1)
