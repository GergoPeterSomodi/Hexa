// The next-season reach of the selected army on the drawn map (docs/architecture/map-overview-build-spec.md, amendment
// of 2026-11-28): diagonal stripes, a dark ink and a pale line beside it, so they read on any land colour and are told
// from this season's flat fill by their pattern. The stripes are spaced in screen px and held to the map. The layer's
// alpha (the drawn map's) is theirs.
shader_type canvas_item;

uniform vec4 ink : source_color;
uniform vec4 light : source_color;
uniform float zoom = 1.0;
uniform float period_px = 9.0;
uniform float ink_px = 2.5;
uniform float light_px = 1.5;

varying vec2 map_px;


void vertex() {
	map_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


// How much of a screen px at `at` (across the stripes) a stripe `width` wide round `middle` covers.
float stripe(float at, float middle, float width) {
	float off = abs(at - middle);
	off = min(off, period_px - off);
	return clamp(width * 0.5 - off + 0.5, 0.0, 1.0);
}


void fragment() {
	float at = mod((map_px.x + map_px.y) * 0.70710678 * zoom, period_px);
	float dark = ink.a * stripe(at, ink_px * 0.5, ink_px);
	float pale = light.a * stripe(at, ink_px + light_px * 0.5, light_px) * (1.0 - dark);
	float cover = dark + pale;
	vec3 colour = (ink.rgb * dark + light.rgb * pale) / max(cover, 0.001);
	// COLOR holds the hex tile's own alpha times the layer's.
	COLOR = vec4(colour, cover * COLOR.a);
}
