// The parchment's lines (docs/architecture/map-overview-build-spec.md R4, R5, R13, D3), for Compatibility GLES 3.0:
// district lines, borders, coast and mountain marks, each `width_px` screen px wide at every zoom.
//
// A land edge (district, border) is 3 points drawn twice: UV.x = hex a * 8 + code, UV.y = hex b. Codes 0 to 2 are the
// points on one side, 3 to 5 the same on the other. The vertex moves out along the normal from a's centre to b's; the
// fragment measures its distance from the line by the slope of `side`, so the width holds where a wobbled edge does
// not run square to that normal. Its ends are butt ends.
//
// A coast segment is a quad: UV.x = land hex * 8 + code (1 the side, 2 the segment's end), UV.y = the angle steps of
// its course * 256 + its length in half map px. It is a stroke with round ends, so segments meet in round joins.
//
// A mountain mark is one strip with mitred corners: UV.x = hex * 8 + side, UV.y = the angle steps of the corner's
// mitre * 256 + its reach in 64ths of the half width.
//
// `owners` is masked by the fog (255 undiscovered). A line shows: coast when its land hex is discovered; district when
// both hexes are and their owners match; border when both are and the owners differ; a mountain mark when its hex is.
// A line that does not show is folded to one point.
shader_type canvas_item;

uniform sampler2D owners : filter_nearest, repeat_disable;
uniform int cols;
uniform int kind;
uniform vec2 cell_size;
uniform float row_height;
uniform float edge_length;
uniform float zoom;
uniform float width_px;
uniform float dash_px;
uniform float gap_px;
uniform vec4 ink;

const int UNKNOWN = 255;
const int DISTRICT = 0;
const int COAST = 2;
const int MOUNTAIN = 3;
// Room for the slant of a wobbled edge against the normal it is widened along.
const float SPREAD = 1.3;
// ParchmentMap.ANGLE_STEPS, COAST_STEPS and MITRE_STEPS.
const float ANGLE_STEP = TAU / 4096.0;
const float COAST_STEPS = 2.0;
const float MITRE_STEPS = 64.0;

varying float side;
// Screen px along and across a coast segment (from its first point); across only, of a mountain mark's stroke.
varying vec2 local_px;
varying float length_px;
varying float along_px;
varying vec2 at_px;

int owner_of(int hex) {
	return int(texelFetch(owners, ivec2(hex % cols, hex / cols), 0).r * 255.0 + 0.5);
}

// MapTiles.cell_centre of a hex index.
vec2 centre_of(int hex) {
	int row = hex / cols;
	return vec2(cell_size.x * (float(hex % cols) + 0.5 + 0.5 * float(row & 1)),
			cell_size.y * 0.5 + row_height * float(row));
}

void vertex() {
	int packed = int(UV.x + 0.5);
	int a = packed / 8;
	int code = packed - a * 8;
	int owner = owner_of(a);
	bool shown = owner != UNKNOWN;
	// The half width and a px of room for the soft rim.
	float reach_px = width_px * 0.5 + 1.0;
	side = 0.0;
	local_px = vec2(0.0);
	length_px = 0.0;
	along_px = 0.0;
	if (kind == COAST || kind == MOUNTAIN) {
		int data = int(UV.y + 0.5);
		float angle = float(data / 256) * ANGLE_STEP;
		float value = float(data % 256);
		vec2 way = vec2(cos(angle), sin(angle));
		float across = (code & 1) != 0 ? 1.0 : -1.0;
		if (kind == COAST) {
			// `way` is the segment's course; the quad reaches past each of its points for the round end.
			float end = (code & 2) != 0 ? 1.0 : -1.0;
			length_px = value / COAST_STEPS * zoom;
			VERTEX += (vec2(-way.y, way.x) * across + way * end) * reach_px / zoom;
			local_px = vec2(end > 0.0 ? length_px + reach_px : -reach_px, across * reach_px);
		} else {
			// `way` is the mitre of this corner of the zig-zag.
			VERTEX += way * across * (value / MITRE_STEPS) * reach_px / zoom;
			local_px = vec2(0.0, across * reach_px);
		}
	} else {
		int b = int(UV.y + 0.5);
		int other = owner_of(b);
		shown = shown && other != UNKNOWN && ((other == owner) == (kind == DISTRICT));
		vec2 from = centre_of(a);
		vec2 normal = normalize(centre_of(b) - from);
		vec2 course = vec2(-normal.y, normal.x);
		side = code < 3 ? 1.0 : -1.0;
		VERTEX += normal * side * reach_px * SPREAD / zoom;
		// The dash pattern starts about at the edge's first corner. An edge shorter on screen than a dash and a gap takes
		// its own place in the pattern, so a far border stays dashed.
		along_px = (dot(VERTEX - from, course) + edge_length * 0.5) * zoom;
		float period = dash_px + gap_px;
		if (edge_length * zoom < period) {
			along_px += float((a * 7 + b * 3) % 16) / 16.0 * period;
		}
	}
	at_px = VERTEX * zoom;
	if (!shown) {
		VERTEX = vec2(0.0);
	}
}

void fragment() {
	// Screen px a fragment.
	float px = max(length(vec2(dFdx(at_px.x), dFdy(at_px.x))), 0.000001);
	float away;
	if (kind == COAST) {
		away = length(vec2(max(max(-local_px.x, local_px.x - length_px), 0.0), local_px.y));
	} else if (kind == MOUNTAIN) {
		away = abs(local_px.y);
	} else {
		float slope = max(length(vec2(dFdx(side), dFdy(side))), 0.000001);
		away = abs(side) / slope * px;
	}
	float cover = clamp((width_px * 0.5 - away) / px + 0.5, 0.0, 1.0);
	if (gap_px > 0.0) {
		float period = dash_px + gap_px;
		float at = mod(along_px, period);
		float inside = max(min(at, dash_px - at), at - period);
		cover *= clamp(inside / px + 0.5, 0.0, 1.0);
	}
	COLOR = vec4(ink.rgb, ink.a * cover * COLOR.a);
}
