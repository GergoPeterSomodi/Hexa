// The parchment's hatched water (docs/architecture/map-overview-build-spec.md R2, R4, R12, D8), for Compatibility GLES
// 3.0: level wavy lines (laid out in map px, so strips that overlap draw the same lines) inside a band half a hex wide
// to each side of every coast edge. One strip an edge: UV is (how far past the edge's end, how far across), so the band
// ends round; the vertex colour is not a colour but the land hex's index, 8 bits in each of red, green and blue. A
// strip shows when that land hex is discovered; the land and the unknown fill are drawn over it. Under a few screen px
// between the lines it is one flat tint. Both colours are opaque, already laid over the sea (no darker where doubled).
shader_type canvas_item;

uniform sampler2D owners : filter_nearest, repeat_disable;
uniform int cols;
uniform vec4 line_colour;
uniform vec4 flat_colour;
uniform bool flat_tint;
uniform float radius;
uniform float spacing;
uniform float line_width;
uniform float wave_length;
uniform float wave_rise;

const int UNKNOWN = 255;

varying vec2 map_px;
varying vec2 reach;

void vertex() {
	ivec3 bytes = ivec3(COLOR.rgb * 255.0 + vec3(0.5));
	int hex = (bytes.r << 16) | (bytes.g << 8) | bytes.b;
	map_px = VERTEX;
	reach = UV;
	if (int(texelFetch(owners, ivec2(hex % cols, hex / cols), 0).r * 255.0 + 0.5) == UNKNOWN) {
		VERTEX = vec2(0.0);
	}
}

void fragment() {
	// Map px a fragment.
	float px = max(length(vec2(dFdx(map_px.x), dFdy(map_px.x))), 0.000001);
	float cover = clamp((radius - length(reach)) / px + 0.5, 0.0, 1.0);
	vec4 colour = flat_colour;
	if (!flat_tint) {
		float y = map_px.y - wave_rise * sin(map_px.x * TAU / wave_length);
		float away = abs(fract(y / spacing) - 0.5) * spacing;
		cover *= clamp((line_width * 0.5 - away) / px + 0.5, 0.0, 1.0);
		colour = line_colour;
	}
	// COLOR.a carries the parchment's own alpha; red, green and blue held the index.
	COLOR = vec4(colour.rgb, colour.a * cover * COLOR.a);
}
