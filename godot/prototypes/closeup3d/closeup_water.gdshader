// The sea of the 3D close-up test: one flat sheet, tinted by the depth of the bed and the distance to the shore (both
// read from a small data texture built from the height field), with a foam line and slow swell lines near the coast.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, specular_schlick_ggx;

#include "res://prototypes/closeup3d/closeup_hex.gdshaderinc"

// r: height of the bed in world units (negative under water), g: distance to the shore in km (0 on land).
uniform sampler2D field_tex : filter_linear, repeat_disable;
uniform vec2 field_origin = vec2(0.0);
uniform float field_step = 0.5;
uniform vec2 field_size = vec2(1.0);
uniform vec2 grid_origin_km = vec2(0.0);
uniform float hex_w = 28.0;
uniform float grid_strength = 0.2;
uniform float grid_half_width = 0.13;

uniform vec3 shore_colour : source_color = vec3(0.36, 0.68, 0.88);
uniform vec3 shelf_colour : source_color = vec3(0.20, 0.48, 0.80);
uniform vec3 deep_colour : source_color = vec3(0.11, 0.30, 0.62);
uniform vec3 foam_colour : source_color = vec3(0.97, 0.98, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 uv = ((p - field_origin) / field_step + 0.5) / field_size;
	vec2 data = texture(field_tex, uv).rg;
	float bed = -data.r;
	float off = data.g;

	float swell = fbm(p * 0.22 + vec2(TIME * 0.02, TIME * 0.013));
	float ripple = value_noise(p * 1.6 + vec2(-TIME * 0.11, TIME * 0.07));

	vec3 col = mix(shelf_colour, deep_colour, smoothstep(0.06, 1.2, bed + (swell - 0.5) * 0.25));
	col = mix(shore_colour, col, smoothstep(0.2, 3.2, off + (swell - 0.5) * 1.2));
	col *= 0.95 + 0.10 * swell;

	// Foam on the shore and two fading swell lines that walk toward it.
	float wobble = (ripple - 0.5) * 0.25;
	float foam = 1.0 - smoothstep(0.16, 0.34, off + wobble);
	float phase = off * 1.1 + TIME * 0.12 + swell * 1.3;
	float band = smoothstep(0.86, 0.96, fract(phase)) * (1.0 - smoothstep(0.5, 2.4, off));
	foam = max(foam, band * 0.55 * smoothstep(0.35, 0.6, ripple + 0.2));
	// Sparse wave marks on the open sea.
	float marks = smoothstep(0.80, 0.86, value_noise(p * vec2(0.9, 3.4) + vec2(TIME * 0.05, 0.0))) * smoothstep(0.62, 0.8, ripple);
	foam = max(foam, marks * 0.16 * smoothstep(2.0, 6.0, off));
	col = mix(col, foam_colour, foam);

	float line = hex_line(p + grid_origin_km, hex_w, grid_half_width);
	col = mix(col, vec3(0.05, 0.16, 0.36), line * grid_strength);

	ALBEDO = col;
	ROUGHNESS = mix(0.42, 0.9, foam);
	SPECULAR = 0.3;
	vec2 tilt = vec2(value_noise(p * 0.9 + TIME * 0.05) - 0.5, value_noise(p * 0.9 + 31.7 - TIME * 0.04) - 0.5) * 0.10;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(tilt.x, 1.0, tilt.y)), 0.0)).xyz);
	// Clear water over the sand at the very edge; land (off = 0) shows no sheet at all.
	ALPHA = mix(0.55, 0.97, smoothstep(0.0, 1.6, off));
}
