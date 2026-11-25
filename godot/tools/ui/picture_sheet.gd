## Writes the settlement picture contact sheet as SVG, headless (tilewin spec R28, R29; TW8).
## Rows: the eight recipes (hamlet, village, town, walled town, city, castle levels 1 to 3). Columns: harbour 0 to 3.
## Left block: no snow; right block: snow on the roofs. The pennant is the LAPIS token colour in both.
##
## Run (from the repository root, the output folder outside the repository):
##   "$GODOT" --headless --path godot -s res://tools/ui/picture_sheet.gd -- --out=<folder>/picture_sheet.svg
extends SceneTree

const ROWS: Array = [
	[&"hamlet", 1], [&"village", 1], [&"town", 1], [&"walled_town", 1],
	[&"city", 1], [&"castle", 1], [&"castle", 2], [&"castle", 3],
]
const OWNER_TOKEN := Tokens.LAPIS
const MARGIN := 40.0
const CELL_GAP := 16.0
const ROW_GAP := 12.0
const LABEL_W := 120.0
const HEAD_H := 40.0
const BLOCK_GAP := 40.0


func _initialize() -> void:
	var out := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	if out == "":
		printerr("picture_sheet: pass --out=<file.svg> (outside the repository)")
		quit(2)
		return
	var text := build_svg()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		printerr("picture_sheet: cannot write %s" % out)
		quit(1)
		return
	file.store_string(text)
	file.close()
	print("picture_sheet: wrote %s (%d bytes)" % [out, text.length()])
	quit(0)


## The whole sheet as one SVG document.
static func build_svg() -> String:
	var cell_w := SettlementPicture.LOGICAL_SIZE.x
	var cell_h := SettlementPicture.LOGICAL_SIZE.y
	var block_w := LABEL_W + 4.0 * (cell_w + CELL_GAP)
	var block_h := HEAD_H + ROWS.size() * (cell_h + ROW_GAP)
	var width := MARGIN * 2.0 + block_w * 2.0 + BLOCK_GAP
	var height := MARGIN * 2.0 + block_h
	var parts: PackedStringArray = []
	parts.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % [
		int(width), int(height), int(width), int(height)])
	parts.append('<rect x="0" y="0" width="%d" height="%d" fill="%s"/>' % [int(width), int(height), _hex(Tokens.BG)])
	for block: int in 2:
		var snow := block == 1
		var x0 := MARGIN + float(block) * (block_w + BLOCK_GAP)
		_block(parts, x0, MARGIN, snow)
	parts.append("</svg>")
	return "\n".join(parts) + "\n"


static func _block(parts: PackedStringArray, x0: float, y0: float, snow: bool) -> void:
	var title := "SNOW ON THE ROOFS" if snow else "NO SNOW"
	_text(parts, x0, y0 + 22.0, title, Tokens.GOLD, 16)
	for col: int in 4:
		var cx := x0 + LABEL_W + float(col) * (SettlementPicture.LOGICAL_SIZE.x + CELL_GAP)
		_text(parts, cx, y0 + 36.0, "harbour %d" % col if col > 0 else "no harbour", Tokens.MUTED, 13)
	for row: int in ROWS.size():
		var spec: Array = ROWS[row]
		var kind: StringName = spec[0]
		var level: int = spec[1]
		var ry := y0 + HEAD_H + float(row) * (SettlementPicture.LOGICAL_SIZE.y + ROW_GAP)
		var label := str(kind) if kind != &"castle" else "castle %d" % level
		_text(parts, x0, ry + 40.0, label, Tokens.TEXT, 14)
		for col: int in 4:
			var cx := x0 + LABEL_W + float(col) * (SettlementPicture.LOGICAL_SIZE.x + CELL_GAP)
			var rec := SettlementPicture.recipe(kind, level, col, snow, OWNER_TOKEN)
			_picture(parts, cx, ry, rec)


static func _picture(parts: PackedStringArray, x: float, y: float, rec: Array[Dictionary]) -> void:
	parts.append('<g transform="translate(%s,%s)">' % [_num(x), _num(y)])
	for shape: Dictionary in rec:
		_shape(parts, shape)
	parts.append("</g>")


static func _shape(parts: PackedStringArray, shape: Dictionary) -> void:
	var kind: StringName = shape["shape"]
	var pts: PackedVector2Array = shape["points"]
	var col: Color = shape["colour"]
	if kind == &"line":
		parts.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="1.5" stroke-linecap="round"%s/>' % [
			_num(pts[0].x), _num(pts[0].y), _num(pts[1].x), _num(pts[1].y), _hex(col), _opacity(col, "stroke")])
		return
	var poly := pts
	if kind == &"rect":
		var a := pts[0]
		var b := pts[1]
		poly = PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])
	var coords: PackedStringArray = []
	for p: Vector2 in poly:
		coords.append("%s,%s" % [_num(p.x), _num(p.y)])
	var stroke := ' stroke="%s" stroke-width="1" stroke-linejoin="round"' % _hex(Tokens.INK) if shape["ink"] else ""
	parts.append('<polygon points="%s" fill="%s"%s%s/>' % [" ".join(coords), _hex(col), _opacity(col, "fill"), stroke])


static func _text(parts: PackedStringArray, x: float, y: float, text: String, col: Color, size: int) -> void:
	parts.append('<text x="%s" y="%s" font-family="Georgia, serif" font-size="%d" fill="%s">%s</text>' % [
		_num(x), _num(y), size, _hex(col), text.xml_escape()])


static func _hex(col: Color) -> String:
	return "#" + col.to_html(false)


static func _opacity(col: Color, prop: String) -> String:
	if col.a >= 1.0:
		return ""
	return ' %s-opacity="%s"' % [prop, "%.3f" % col.a]


static func _num(v: float) -> String:
	return "%.2f" % v
