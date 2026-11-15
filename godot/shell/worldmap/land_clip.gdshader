// The piece grounds of the north Italy map: nothing of a field or a yard shows on the water. The land mask is the
// baked land_mask.png laid over the whole map; the vertex position is the map pixel (the layer sits at the origin).
shader_type canvas_item;

uniform sampler2D land_mask : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(1280.0, 720.0);

varying vec2 map_px;

void vertex() {
	map_px = VERTEX;
}

void fragment() {
	COLOR.a *= smoothstep(0.35, 0.65, texture(land_mask, map_px / map_size).r);
}
