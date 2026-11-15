// The game's map grid as a line mask: pointy-top hexes `hex_w` km wide, laid out like core/worldmap (odd rows shifted
// half a hex right; the first hex centre at (hex_w / 2, hex_w / sqrt(3)) in grid kilometres).
// Returns the distance to the nearest hex edge in km.
float hex_edge_km(vec2 grid_km, float hex_w) {
	vec2 q = (grid_km - vec2(hex_w * 0.5, hex_w * 0.57735027)) / hex_w;
	vec2 s = vec2(1.0, 1.7320508);
	vec4 centre = floor(vec4(q, q - vec2(0.5, 0.8660254)) / s.xyxy) + 0.5;
	vec4 off = vec4(q - centre.xy * s, q - (centre.zw + 0.5) * s);
	vec2 local = abs(dot(off.xy, off.xy) < dot(off.zw, off.zw) ? off.xy : off.zw);
	float d = max(local.x, dot(local, vec2(0.5, 0.8660254)));
	return (0.5 - d) * hex_w;
}

float hex_line(vec2 grid_km, float hex_w, float half_width_km) {
	float e = hex_edge_km(grid_km, hex_w);
	float aa = max(fwidth(e), 0.0001);
	return 1.0 - smoothstep(half_width_km - aa, half_width_km + aa, e);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * value_noise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v / 0.9375;
}
