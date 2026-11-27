// The parchment's sand sea (docs/architecture/map-overview-build-spec.md R2, D8), for Compatibility GLES 3.0: one quad
// over the map and a screen around it, a flat colour with a faint speckle, at most one dot in each cell of `cell` map
// px, placed and sized by an integer hash of the cell. The dots fade out far away, where they would only shimmer.
shader_type canvas_item;

uniform vec4 sea_colour;
uniform vec4 speckle_colour;
uniform float cell;
uniform float radius;
uniform float zoom;

varying vec2 map_px;

void vertex() {
	map_px = VERTEX;
}

void fragment() {
	ivec2 at = ivec2(floor(map_px / cell));
	uint h = uint(at.x) * 0x27d4eb2du + uint(at.y) * 0x165667b1u + 0x61c88647u;
	h = (h ^ (h >> 15u)) * 0x2c1b3c6du;
	h = (h ^ (h >> 12u)) * 0x297a2d39u;
	h = h ^ (h >> 15u);
	float size = radius * (0.2 + 0.8 * float(h & 255u) / 255.0);
	vec2 place = vec2(float((h >> 8u) & 255u), float((h >> 16u) & 255u)) / 255.0;
	vec2 centre = vec2(at) * cell + vec2(radius) + place * (cell - 2.0 * radius);
	float px = max(length(vec2(dFdx(map_px.x), dFdy(map_px.x))), 0.000001);
	float cover = clamp((size - distance(map_px, centre)) / px + 0.5, 0.0, 1.0);
	float near = smoothstep(0.1, 0.3, zoom);
	vec3 colour = mix(sea_colour.rgb, speckle_colour.rgb, speckle_colour.a * cover * near);
	// COLOR.a carries the parchment's own alpha.
	COLOR = vec4(colour, sea_colour.a * COLOR.a);
}
