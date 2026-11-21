// Per-hex map mode overlay shader (Terrain tint, Owner, Relief, Yields, Food, Supply) and the sight veil, for Compatibility
// GLES 3.0. Mirrors MapModes.hex_at_px, MapModes.colour_of and MapModes.colour_at without any screen texture read.
shader_type canvas_item;

uniform sampler2D owner_ids : filter_nearest, repeat_disable;
uniform sampler2D heights : filter_nearest, repeat_disable;
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform sampler2D ramp : filter_nearest, repeat_disable;
uniform sampler2D yields : filter_nearest, repeat_disable;
uniform sampler2D yield_ramp : filter_nearest, repeat_disable;
uniform sampler2D food : filter_nearest, repeat_disable;
uniform sampler2D food_ramp : filter_nearest, repeat_disable;
uniform sampler2D supply : filter_nearest, repeat_disable;
uniform sampler2D supply_ramp : filter_nearest, repeat_disable;
uniform sampler2D sight : filter_nearest, repeat_disable;

uniform int mode = 0;
uniform bool tint_on = true;
uniform int hot_id = 0;
uniform bool from_uv = false;
uniform vec2 map_size = vec2(0.0, 0.0);
uniform ivec2 grid_size = ivec2(0, 0);
uniform bool sight_veil_on = false;

uniform float tint_alpha = 0.14;
uniform float owner_alpha = 0.55;
uniform float relief_alpha = 0.65;
uniform float hot_alpha = 0.20;
uniform float hot_lighten = 0.15;
uniform float yield_alpha = 0.70;
uniform float food_alpha = 0.70;
uniform float supply_alpha = 0.70;
uniform float veil_alpha = 0.45;
uniform float sight_alpha = 0.25;
uniform float stripe_px = 6.0;
uniform vec4 veil_colour = vec4(0.109804, 0.078431, 0.050980, 1.0);

varying vec2 map_px;

// The sight veil laid over c by source-over (MapModes._veiled): a = av + am (1 - av), rgb = (VEIL av + c am (1 - av)) / a.
vec4 veiled(vec4 c) {
	float am = c.a;
	float a = sight_alpha + am * (1.0 - sight_alpha);
	vec3 rgb = (veil_colour.rgb * sight_alpha + c.rgb * am * (1.0 - sight_alpha)) / a;
	return vec4(rgb, a);
}

void vertex() {
	map_px = from_uv ? (UV * map_size) : VERTEX;
}

void fragment() {
	vec2 u = map_px - vec2(52.0, 51.0);
	float r = u.y / 76.5;
	float q = u.x / 104.0 - 0.5 * r;
	float s = -q - r;
	float rq = floor(q + 0.5);
	float rr = floor(r + 0.5);
	float rs = floor(s + 0.5);
	float dq = abs(rq - q);
	float dr = abs(rr - r);
	float ds = abs(rs - s);
	if (dq > dr && dq > ds) {
		rq = -rr - rs;
	} else if (dr > ds) {
		rr = -rq - rs;
	}
	int row = int(floor(rr + 0.5));
	int col = int(floor(rq + 0.5)) + int(floor(rr * 0.5));

	if (col < 0 || row < 0 || col >= grid_size.x || row >= grid_size.y) {
		COLOR = vec4(0.0);
	} else {
		ivec2 cell = ivec2(col, row);
		int height_byte = clamp(int(floor(texelFetch(heights, cell, 0).r * 255.0 + 0.5)), 0, 255);
		if (height_byte == 0) {
			COLOR = vec4(0.0);
		} else {
			int owner_id = clamp(int(floor(texelFetch(owner_ids, cell, 0).r * 255.0 + 0.5)), 0, 255);
			// true where the mode draws the veil itself (its byte 0 or past its colours): the sight veil does not go over it again
			bool by_mode_veil = false;
			vec4 out_col = vec4(0.0);
			if (mode == 0) {
				if (tint_on && owner_id > 0) {
					out_col = texelFetch(palette, ivec2(owner_id, 0), 0);
					out_col.a = tint_alpha;
					if (hot_id > 0 && owner_id == hot_id) {
						out_col.rgb = mix(out_col.rgb, vec3(1.0), hot_lighten);
						out_col.a += hot_alpha;
					}
				}
			} else if (mode == 1) {
				out_col = texelFetch(palette, ivec2(owner_id, 0), 0);
				out_col.a = owner_alpha;
				if (hot_id > 0 && owner_id == hot_id) {
					out_col.rgb = mix(out_col.rgb, vec3(1.0), hot_lighten);
					out_col.a += hot_alpha;
				}
			} else if (mode == 2) {
				out_col = texelFetch(ramp, ivec2(height_byte, 0), 0);
				out_col.a = relief_alpha;
				if (hot_id > 0 && owner_id == hot_id) {
					out_col.rgb = mix(out_col.rgb, vec3(1.0), hot_lighten);
					out_col.a += hot_alpha;
				}
			} else if (mode == 3) {
				// Yields: your land by its band (1 a loss, 2 to 9), the veil on every other hex.
				int yield_byte = clamp(int(floor(texelFetch(yields, cell, 0).r * 255.0 + 0.5)), 0, 255);
				out_col = vec4(veil_colour.rgb, veil_alpha);
				by_mode_veil = true;
				if (yield_byte >= 1 && yield_byte <= 9) {
					by_mode_veil = false;
					out_col = texelFetch(yield_ramp, ivec2(yield_byte, 0), 0);
					out_col.a = yield_alpha;
					if (yield_byte == 1) {
						// Stripes of madder and veil, measured from the hex's middle.
						vec2 mid = vec2(104.0 * (float(col) + 0.5 + 0.5 * float(row & 1)), 51.0 + 76.5 * float(row));
						vec2 d = map_px - mid;
						if (mod(floor((d.x + d.y + 3.0) / stripe_px), 2.0) > 0.5) {
							out_col = vec4(veil_colour.rgb, veil_alpha);
						}
					}
				}
			} else if (mode == 4) {
				// Food: your land by food made less eaten (bytes 1 and 2 a shortfall, striped), the veil on every other hex.
				int food_byte = clamp(int(floor(texelFetch(food, cell, 0).r * 255.0 + 0.5)), 0, 255);
				out_col = vec4(veil_colour.rgb, veil_alpha);
				by_mode_veil = true;
				if (food_byte >= 1 && food_byte <= 8) {
					by_mode_veil = false;
					out_col = texelFetch(food_ramp, ivec2(food_byte, 0), 0);
					out_col.a = food_alpha;
					if (food_byte <= 2) {
						vec2 mid = vec2(104.0 * (float(col) + 0.5 + 0.5 * float(row & 1)), 51.0 + 76.5 * float(row));
						vec2 d = map_px - mid;
						if (mod(floor((d.x + d.y + 3.0) / stripe_px), 2.0) > 0.5) {
							out_col = vec4(veil_colour.rgb, veil_alpha);
						}
					}
				}
			} else if (mode == 5) {
				// Supply: your land by what feeds the army (bytes 1 to 6, 1 the starving stripes), the veil on every other hex.
				int supply_byte = clamp(int(floor(texelFetch(supply, cell, 0).r * 255.0 + 0.5)), 0, 255);
				out_col = vec4(veil_colour.rgb, veil_alpha);
				by_mode_veil = true;
				if (supply_byte >= 1 && supply_byte <= 6) {
					by_mode_veil = false;
					out_col = texelFetch(supply_ramp, ivec2(supply_byte, 0), 0);
					out_col.a = supply_alpha;
					if (supply_byte == 1) {
						// Stripes of madder and veil, measured from the hex's middle.
						vec2 mid = vec2(104.0 * (float(col) + 0.5 + 0.5 * float(row & 1)), 51.0 + 76.5 * float(row));
						vec2 d = map_px - mid;
						if (mod(floor((d.x + d.y + 3.0) / stripe_px), 2.0) > 0.5) {
							out_col = vec4(veil_colour.rgb, veil_alpha);
						}
					}
				}
			}
			// The sight veil (A13): over every land hex the viewer does not see, in every mode, unless the mode drew its veil.
			if (sight_veil_on && !by_mode_veil && int(floor(texelFetch(sight, cell, 0).r * 255.0 + 0.5)) == 0) {
				out_col = veiled(out_col);
			}
			COLOR = out_col;
		}
	}
}
