// Trees of the 3D close-up test: colours from the vertices times the instance colour, plus the game's hex grid projected
// straight down, so the grid line runs over the tree tops as it runs over the ground.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://prototypes/closeup3d/closeup_hex.gdshaderinc"

uniform vec2 grid_origin_km = vec2(0.0);
uniform float hex_w = 28.0;
uniform float grid_strength = 0.45;
uniform float grid_half_width = 0.13;
uniform vec3 grid_colour : source_color = vec3(0.14, 0.22, 0.10);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	float line = hex_line(world_pos.xz + grid_origin_km, hex_w, grid_half_width);
	ALBEDO = mix(col, grid_colour, line * grid_strength);
	ROUGHNESS = 1.0;
}
