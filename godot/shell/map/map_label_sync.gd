## The country names and the map labels follow the camera (split from map_scene.gd to keep it under 800 lines, M8 K28): the
## camera's transform and the view's size go to CountryLabels, then the labels take its obstacles. Pure over the nodes the scene
## passes in; with no size (the scene is not in the tree) the 1280 x 720 view is used.
class_name MapLabelSync
extends RefCounted

const FALLBACK_SIZE := Vector2(1280.0, 720.0)


static func sync(country_labels: CountryLabels, labels: MapLabels, camera: Camera2D, vp_size: Vector2) -> void:
	if country_labels == null or camera == null:
		return
	var z := camera.zoom.x
	var size := vp_size if vp_size.x > 0.0 and vp_size.y > 0.0 else FALLBACK_SIZE
	var xform := Transform2D(Vector2(z, 0.0), Vector2(0.0, z), size * 0.5 - camera.position * z)
	country_labels.set_view(xform, z, size)
	if labels != null:
		labels.set_obstacles(country_labels.obstacles())
