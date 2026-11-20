## Contact sheet of the complete InkChart (task I1, M4.5): LINE, STACKED_BAR and SPARK in light (vellum) and dark (slot)
## grounds, the five fills as swatches and as stacked columns, the legend and the cursor, as one PNG for the art director.
## Windowed (nothing renders headless):
##   godot --path godot -s res://tools/ui/sheet_ink_chart.gd -- [--out=/abs/path/ink_chart_sheet.png] [--scale=2]
## The default output is ink_chart_sheet.png in the user folder (user://), which the tool prints.
extends SceneTree

const SHEET_SIZE := Vector2i(1280, 800)
const SEASONS: PackedStringArray = ["Spr 1480", "Sum 1480", "Aut 1480", "Win 1480", "Spr 1481", "Sum 1481", "Aut 1481", "Win 1481"]

var _out := "user://ink_chart_sheet.png"
var _frames := 0
var _built := false


func _initialize() -> void:
	var scale_factor := 1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--scale="):
			scale_factor = maxi(1, arg.substr(8).to_int())
	DisplayServer.window_set_size(SHEET_SIZE * scale_factor)
	root.size = SHEET_SIZE * scale_factor
	root.content_scale_factor = float(scale_factor)


func _process(_delta: float) -> bool:
	_frames += 1
	if not _built:
		_build()
		_built = true
		return false
	if _frames < 12:
		return false
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("sheet_ink_chart: empty viewport image (must run windowed, not --headless)")
		quit(1)
		return true
	var path := ProjectSettings.globalize_path(_out) if _out.begins_with("user://") else _out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	if err != OK:
		printerr("sheet_ink_chart: save_png(%s) failed with %d" % [path, err])
		quit(1)
		return true
	print("sheet_ink_chart: wrote %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	quit(0)
	return true


func _build() -> void:
	var theme := KitTheme.load_for(1.0)
	var back := ColorRect.new()
	back.color = Tokens.BG
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.theme = theme
	root.add_child(back)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 16)
	grid.add_theme_constant_override(&"v_separation", 16)
	grid.position = Vector2(16.0, 16.0)
	back.add_child(grid)

	for ground: InkChart.Ground in [InkChart.Ground.VELLUM, InkChart.Ground.SLOT]:
		var holder := PanelContainer.new()
		holder.theme_type_variation = &"PanelVellumInset" if ground == InkChart.Ground.VELLUM else &"PanelDebug"
		var col := VBoxContainer.new()
		holder.add_child(col)
		col.add_child(_line_chart(ground))
		col.add_child(_stacked_chart(ground))
		col.add_child(_fills_row(ground))
		col.add_child(_spark_row(ground))
		grid.add_child(holder)


func _chart(kind: InkChart.Kind, ground: InkChart.Ground, caption: String, height: float) -> InkChart:
	var c := InkChart.new()
	c.kind = kind
	c.ground = ground
	c.caption = caption
	c.custom_minimum_size = Vector2(600.0, height)
	c.x_labels = SEASONS
	c.legend = kind != InkChart.Kind.SPARK
	return c


func _line_chart(ground: InkChart.Ground) -> InkChart:
	var c := _chart(InkChart.Kind.LINE, ground, "Treasury", 190.0)
	c.set_series([
		{"name": "Genoa", "values": PackedInt32Array([696, 760, 820, 790, 900, 980, 940, 1068]), "ink": 0},
		{"name": "Milan", "values": PackedInt32Array([500, 540, 520, 600, 650, 640, 700, 720]), "ink": 1},
		{"name": "Venice", "values": PackedInt32Array([300, 380, 450, 430, 400, 520, 610, 580]), "ink": 2},
		{"name": "Pisa", "values": PackedInt32Array([200, 210, 260, 300, 280, 350, 330, 390]), "ink": 3},
		{"name": "Florence", "values": PackedInt32Array([120, 160, 150, 220, 260, 240, 300, 310]), "ink": 4},
	])
	c.set_marks([{"index": 3, "text": "Works done", "tone": &"good"}, {"index": 6, "text": "Plague", "tone": &"bad"}])
	c.set_cursor(4)
	return c


func _stacked_chart(ground: InkChart.Ground) -> InkChart:
	var c := _chart(InkChart.Kind.STACKED_BAR, ground, "Money in and out", 210.0)
	c.set_series([
		{"name": "Taxes", "values": PackedInt32Array([60, 62, 64, 66, 70, 72, 74, 76]), "ink": 0, "role": "in"},
		{"name": "Trade", "values": PackedInt32Array([20, 24, 22, 30, 34, 30, 36, 40]), "ink": 1, "role": "in"},
		{"name": "Buildings", "values": PackedInt32Array([10, 10, 12, 12, 14, 14, 16, 16]), "ink": 2, "role": "in"},
		{"name": "Upkeep", "values": PackedInt32Array([40, 44, 48, 52, 50, 54, 58, 60]), "ink": 3, "role": "out"},
		{"name": "Works", "values": PackedInt32Array([0, 30, 0, 20, 0, 40, 0, 10]), "ink": 4, "role": "out"},
	])
	c.set_marks([{"index": 5, "text": "Big works", "tone": &"bad"}])
	return c


## The five fills as a row of swatches with their names, each as a fill and as a line swatch.
func _fills_row(ground: InkChart.Ground) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	for cue: int in 5:
		var sw := _SwatchBox.new()
		sw.cue = cue
		sw.ground = ground
		sw.custom_minimum_size = Vector2(104.0, 34.0)
		row.add_child(sw)
	return row


func _spark_row(ground: InkChart.Ground) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	var shapes: Array = [
		PackedInt32Array(),
		PackedInt32Array([5]),
		PackedInt32Array([1, 3, 2, 5, 4, 6, 8, 7, 9, 12, 11, 13, 12, 15, 14, 18, 17, 16, 20, 19, 22, 21, 25, 24, 23, 27, 26, 30, 29, 28, 33, 31, 35, 34, 38, 36, 40, 39, 42, 41]),
	]
	for i: int in shapes.size():
		var c := InkChart.new()
		c.kind = InkChart.Kind.SPARK
		c.ground = ground
		c.custom_minimum_size = Vector2(160.0, 40.0)
		c.set_series([{"name": "Spark %d" % i, "values": shapes[i], "ink": i}])
		row.add_child(c)
	return row


## One swatch of each cue: as a fill and as a line, so the sheet shows ink AND pattern together.
class _SwatchBox:
	extends Control
	var cue: int = 0
	var ground: InkChart.Ground = InkChart.Ground.VELLUM

	func _draw() -> void:
		var ink := InkChart.colour_of(self, StringName("ink_%d" % cue), ground)
		InkMarks.swatch(self, Rect2(0.0, 2.0, 40.0, 14.0), ink, cue, true)
		InkMarks.swatch(self, Rect2(48.0, 2.0, 40.0, 14.0), ink, cue, false)
		var font := get_theme_default_font()
		draw_string(font, Vector2(0.0, 32.0), String(InkMarks.FILLS[cue]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
