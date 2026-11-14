// Draws a map of hexes from a small texture with one texel per hex (the far maps and the countries overlay).
// The hex under a pixel is the nearest hex centre (pointy-top, the hexgrid of core/hexgrid.gd at radius 60, see
// core/views/map_geometry.gd), so the picture is hex-shaped, not square. Texels are read with texelFetch: no filtering.
shader_type canvas_item;

uniform sampler2D hex_colours : filter_nearest, repeat_disable;
uniform vec2 grid = vec2(203.0, 150.0);
uniform float hex_w = 103.92304845413264;
uniform float row_h = 90.0;
uniform float hex_y0 = 60.62177826491071;
uniform float opacity = 1.0;

varying vec2 world;

void vertex() {
	world = VERTEX;
}

void fragment() {
	float r0 = floor((world.y - hex_y0) / row_h + 0.5);
	float best = 1e20;
	vec2 pick = vec2(-1.0, -1.0);
	for (int dr = -1; dr <= 1; dr++) {
		float r = r0 + float(dr);
		float shift = mod(r, 2.0) * hex_w * 0.5;
		float c0 = floor((world.x - shift - hex_w * 0.5) / hex_w + 0.5);
		for (int dc = -1; dc <= 1; dc++) {
			float c = c0 + float(dc);
			vec2 centre = vec2(c * hex_w + shift + hex_w * 0.5, r * row_h + hex_y0);
			vec2 d = world - centre;
			float dist = dot(d, d);
			if (dist < best) {
				best = dist;
				pick = vec2(c, r);
			}
		}
	}
	if (pick.x < 0.0 || pick.y < 0.0 || pick.x >= grid.x || pick.y >= grid.y) {
		COLOR = vec4(0.0);
	} else {
		vec4 c = texelFetch(hex_colours, ivec2(pick), 0);
		COLOR = vec4(c.rgb, c.a * opacity);
	}
}
