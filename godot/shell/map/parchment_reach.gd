## The army's next-season reach over the drawn map (docs/architecture/map-overview-build-spec.md, amendment of
## 2026-11-28; used by MapSceneParchment): the tile view's pale fill is too faint on the paper, so while the drawn map
## shows, the hexes only the next season reaches (the view's reach_ahead layer, MapArmies) are hatched
## (parchment_reach.gdshader, colours ParchmentTokens'). With the drawn map hidden that layer is not drawn, and the tile
## view's reach is untouched either way. This season's reach stays a flat fill. Keeping the reach off unexplored hexes
## while the drawn map shows is MapArmies' (it fills the layers). It holds no rules and reads no game.
class_name ParchmentReach
extends RefCounted

const SHADER := preload("res://shell/map/parchment_reach.gdshader")
const LAYER := "reach_ahead"

var _material: ShaderMaterial = null


## Hatches the next season's reach of `view` as far as the drawn map shows: `alpha` is the parchment's (0 hidden), `zoom`
## the camera's.
func apply(view: TileMapView, alpha: float, zoom: float, high_contrast: bool) -> void:
	var layer := view.layer(LAYER)
	layer.modulate.a = alpha  # at 0 the renderer skips it
	if alpha <= 0.0:
		return
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	var colours := ParchmentTokens.colours(high_contrast)
	_material.set_shader_parameter(&"ink", colours[&"reach_ink"])
	_material.set_shader_parameter(&"light", colours[&"reach_light"])
	_material.set_shader_parameter(&"period_px", ParchmentTokens.REACH_PERIOD_PX)
	_material.set_shader_parameter(&"ink_px", ParchmentTokens.reach_ink_px(high_contrast))
	_material.set_shader_parameter(&"light_px", ParchmentTokens.REACH_LIGHT_PX)
	_material.set_shader_parameter(&"zoom", zoom)
	if layer.material != _material:
		layer.material = _material
