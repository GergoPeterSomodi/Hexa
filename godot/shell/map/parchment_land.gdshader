// The parchment's land (docs/architecture/map-overview-build-spec.md R6, R7, R12, R14, D3), for Compatibility GLES 3.0.
// One mesh a chunk of every hex's outline: UV.x is the hex's index (row * cols + col), UV.y 1 for land and 0 for sea.
// The textures hold one texel a hex, already masked by the fog (ParchmentView): the owner's country id (0 no one, 255
// undiscovered) and the goods (good id + 1, stage). Land out of sight is drawn as land in sight (R14). A sea hex the
// viewer has discovered draws nothing: the sea and its hatch below show through. Colours are uniforms (ParchmentTokens).
shader_type canvas_item;

uniform sampler2D owners : filter_nearest, repeat_disable;
uniform sampler2D goods : filter_nearest, repeat_disable;
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform int cols;
uniform bool goods_mode;
uniform int good;
uniform float owner_strength;

uniform vec4 land_colour;
uniform vec4 unknown_colour;
uniform vec4 goods_1_colour;
uniform vec4 goods_2_colour;
uniform vec4 goods_3_colour;

const int UNKNOWN = 255;

varying vec4 fill;

void vertex() {
	int hex = int(UV.x + 0.5);
	ivec2 cell = ivec2(hex % cols, hex / cols);
	int owner = int(texelFetch(owners, cell, 0).r * 255.0 + 0.5);
	fill = unknown_colour;
	if (owner != UNKNOWN) {
		if (UV.y < 0.5) {
			// A discovered sea hex: every corner to one point, so no triangle is drawn.
			fill = vec4(0.0);
			VERTEX = vec2(0.0);
		} else {
			fill = land_colour;
			if (goods_mode) {
				ivec2 made = ivec2(texelFetch(goods, cell, 0).rg * 255.0 + vec2(0.5));
				if (made.y > 0 && made.x == good) {
					fill = made.y == 1 ? goods_1_colour : (made.y == 2 ? goods_2_colour : goods_3_colour);
				}
			} else if (owner > 0) {
				fill.rgb = mix(fill.rgb, texelFetch(palette, ivec2(owner, 0), 0).rgb, owner_strength);
			}
		}
	}
}

void fragment() {
	// COLOR.a carries the parchment's own alpha.
	COLOR = vec4(fill.rgb, fill.a * COLOR.a);
}
