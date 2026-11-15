// Ground colours of the 3D close-up test, from height and slope alone (no textures): light green lowland with a faint
// patchwork of fields, darker wooded slopes, rock on the steep faces, pale grass on the tops, a strip of beach, the sea bed.
// The game's hex grid is drawn as a faint line on top.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://prototypes/closeup3d/closeup_hex.gdshaderinc"

uniform float exaggeration = 7.0;
uniform vec2 grid_origin_km = vec2(0.0);
uniform float hex_w = 28.0;
uniform float grid_strength = 0.55;
uniform float grid_half_width = 0.13;
uniform vec4 towns[8];
uniform int town_count = 0;

uniform vec3 plain_a : source_color = vec3(0.64, 0.80, 0.33);
uniform vec3 plain_b : source_color = vec3(0.73, 0.84, 0.38);
uniform vec3 field_wheat : source_color = vec3(0.83, 0.82, 0.42);
uniform vec3 field_dark : source_color = vec3(0.52, 0.72, 0.30);
uniform vec3 hill : source_color = vec3(0.50, 0.71, 0.28);
uniform vec3 wood : source_color = vec3(0.30, 0.52, 0.22);
uniform vec3 top : source_color = vec3(0.66, 0.72, 0.40);
uniform vec3 rock : source_color = vec3(0.60, 0.56, 0.50);
uniform vec3 rock_dark : source_color = vec3(0.45, 0.42, 0.39);
uniform vec3 sand : source_color = vec3(0.86, 0.79, 0.58);
uniform vec3 sea_bed : source_color = vec3(0.16, 0.36, 0.56);
uniform vec3 town_ground : source_color = vec3(0.80, 0.74, 0.58);
uniform vec3 grid_colour : source_color = vec3(0.14, 0.22, 0.10);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = world_pos.xz;
	float metres = world_pos.y / exaggeration * 1000.0;
	float slope = 1.0 - normalize(world_normal).y;
	float broad = fbm(p * 0.09);
	float fine = value_noise(p * 1.7);

	// Lowland, with fields: blocks of a turned grid, each with its own tint.
	vec3 col = mix(plain_a, plain_b, broad);
	vec2 turned = mat2(vec2(0.94, 0.34), vec2(-0.34, 0.94)) * p + vec2(broad * 3.0, 0.0);
	vec2 block = floor(turned / vec2(2.6, 1.7));
	float pick = hash21(block);
	vec2 in_block = fract(turned / vec2(2.6, 1.7));
	float hedge = smoothstep(0.0, 0.06, min(min(in_block.x, 1.0 - in_block.x), min(in_block.y, 1.0 - in_block.y)));
	vec3 field = pick < 0.30 ? field_wheat : (pick < 0.55 ? field_dark : col);
	float flat_low = (1.0 - smoothstep(180.0, 320.0, metres)) * (1.0 - smoothstep(0.004, 0.02, slope));
	col = mix(col, mix(field_dark * 0.82, field, hedge), flat_low * 0.55);

	// Hills and woods.
	col = mix(col, hill, smoothstep(140.0, 420.0, metres + broad * 160.0));
	float wooded = smoothstep(0.02, 0.10, slope) * smoothstep(60.0, 260.0, metres) * (0.55 + 0.45 * fine);
	col = mix(col, wood, wooded * 0.75);
	col = mix(col, top, smoothstep(1150.0, 1600.0, metres + fine * 150.0) * 0.8);

	// Rock on the steep faces.
	float steep = smoothstep(0.36, 0.52, slope + (fine - 0.5) * 0.10);
	col = mix(col, mix(rock_dark, rock, fine), steep * 0.85);

	// Town ground.
	for (int k = 0; k < town_count; k++) {
		float d = distance(p, towns[k].xy);
		float inside = 1.0 - smoothstep(towns[k].z * 0.55, towns[k].z, d + (fine - 0.5) * 1.2);
		col = mix(col, town_ground, inside * 0.7 * (1.0 - steep));
	}

	// The beach, then the bed under the water.
	float beach = 1.0 - smoothstep(7.0, 20.0, metres + (fine - 0.5) * 8.0);
	col = mix(col, sand, beach);
	col = mix(col, sea_bed, smoothstep(0.0, -0.12, world_pos.y));

	// A little mottling, so large flat areas are not one flat colour.
	col *= 0.94 + 0.12 * fine;

	float line = hex_line(p + grid_origin_km, hex_w, grid_half_width);
	col = mix(col, grid_colour, line * grid_strength * step(0.0, world_pos.y));

	ALBEDO = col;
	ROUGHNESS = 1.0;
}
