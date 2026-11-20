## The save thumbnail (docs/architecture/m3-build-spec.md 6.15, risk table in section 10): a 192 x 108 picture of the map.
## Two ways to get the pixels, behind one constant: CAPTURE reads the screen after frame_post_draw (the default);
## TEXTURE is the spec-10 fallback that scales the far picture's texture and lays the overlay on it, with no screen read.
## The planner flips MODE after tools/ui/probe_capture.gd has run on the owner's machines.
class_name Thumbnail
extends RefCounted

const CAPTURE := &"capture"
const TEXTURE := &"texture"
## The way thumbnails are taken: CAPTURE or TEXTURE.
const MODE := CAPTURE

## True while a capture has the layers hidden: a second take then returns null instead of recording them as hidden.
static var _busy: bool = false


## A coroutine (await it). CAPTURE: hides the layers, forces one draw (RenderingServer.force_draw), copies the viewport, shows
## the layers again. TEXTURE: uses `far_texture` and `overlay` (an Image of the same view, may be null) and reads no
## screen. Either way the result is scaled to SaveFile.THUMB. Null when headless or the picture is empty.
static func take(viewport: Viewport, hide: Array[CanvasLayer], far_texture: Texture2D = null,
		overlay: Image = null, mode: StringName = MODE) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	if mode == TEXTURE:
		return from_texture(far_texture, overlay)
	if viewport == null:
		return null
	if _busy:
		return null
	_busy = true
	var was: Array[bool] = []
	for layer: CanvasLayer in hide:
		was.append(layer.visible)
		layer.visible = false
	# force_draw, not `await frame_post_draw`: the project runs in low-processor mode, so an idle game draws no frame
	# and that signal would never come (found by tools/ui/probe_capture.gd).
	RenderingServer.force_draw(false)
	var image: Image = null
	if viewport.get_texture() != null:
		image = viewport.get_texture().get_image()
	for i: int in hide.size():
		if is_instance_valid(hide[i]):
			hide[i].visible = was[i]
	_busy = false
	return fit(image)


## The fallback: the far picture's texture with the overlay on it, scaled. Null when there is no picture.
static func from_texture(far_texture: Texture2D, overlay: Image = null) -> Image:
	if far_texture == null:
		return null
	var image := far_texture.get_image()
	if image == null or image.is_empty() or image.is_compressed():
		return null
	image.convert(Image.FORMAT_RGBA8)
	if overlay != null and not overlay.is_empty() and not overlay.is_compressed():
		var top := overlay.duplicate() as Image
		top.convert(Image.FORMAT_RGBA8)
		top.resize(image.get_width(), image.get_height(), Image.INTERPOLATE_LANCZOS)
		image.blend_rect(top, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	return fit(image)


## Centre-crops to the 16:9 of SaveFile.THUMB, then scales to it (Lanczos). Null for a null or empty image.
static func fit(image: Image) -> Image:
	if image == null or image.is_empty() or image.is_compressed():
		return null
	var want := float(SaveFile.THUMB.x) / float(SaveFile.THUMB.y)
	var w := image.get_width()
	var h := image.get_height()
	var crop := Rect2i(0, 0, w, h)
	if float(w) / float(h) > want:
		crop.size.x = maxi(1, roundi(float(h) * want))
		crop.position.x = floori(float(w - crop.size.x) / 2.0)
	else:
		crop.size.y = maxi(1, roundi(float(w) / want))
		crop.position.y = floori(float(h - crop.size.y) / 2.0)
	var out := image.get_region(crop)
	out.convert(Image.FORMAT_RGBA8)
	out.resize(SaveFile.THUMB.x, SaveFile.THUMB.y, Image.INTERPOLATE_LANCZOS)
	return out
