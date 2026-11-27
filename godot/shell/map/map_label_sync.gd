## The country names and the map labels follow the camera (split from map_scene.gd to keep it under 800 lines, M8 K28): the
## camera's transform and the view's size go to CountryLabels, then the labels take its obstacles. Pure over the nodes the scene
## passes in; with no size (the scene is not in the tree) the 1280 x 720 view is used. The parchment's names are laid out
## with the same transform and size (MapSceneParchment.relayout).
class_name MapLabelSync
extends RefCounted

const FALLBACK_SIZE := Vector2(1280.0, 720.0)


## The view's size, FALLBACK_SIZE when there is none.
static func view_size(vp_size: Vector2) -> Vector2:
	return vp_size if vp_size.x > 0.0 and vp_size.y > 0.0 else FALLBACK_SIZE


## Map px to screen px for the camera in a view of `size`.
static func transform_of(camera: Camera2D, size: Vector2) -> Transform2D:
	var z := camera.zoom.x
	return Transform2D(Vector2(z, 0.0), Vector2(0.0, z), size * 0.5 - camera.position * z)


static func sync(country_labels: CountryLabels, labels: MapLabels, camera: Camera2D, vp_size: Vector2) -> void:
	if country_labels == null or camera == null:
		return
	var size := view_size(vp_size)
	country_labels.set_view(transform_of(camera, size), camera.zoom.x, size)
	block(labels, country_labels)


## The place plates keep off the country names' boxes; names faded out (under the parchment) block none.
static func block(labels: MapLabels, country_labels: CountryLabels) -> void:
	if labels == null or country_labels == null:
		return
	var none: Array[Rect2] = []
	labels.set_obstacles(country_labels.obstacles() if country_labels.modulate.a > 0.0 else none)
