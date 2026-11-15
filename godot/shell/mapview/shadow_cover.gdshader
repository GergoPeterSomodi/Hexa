// The shadow pass of the north Italy map. The baked shadows are flat shapes at the frame's shadow alpha (46 of 255);
// here they are drawn at full cover into the shadow group, which is then laid over the map once at that alpha, so two
// shadows that overlap are no darker than one (the compositor's one shadow layer).
shader_type canvas_item;

const float BAKED_ALPHA = 46.0 / 255.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(c.rgb, clamp(c.a / BAKED_ALPHA, 0.0, 1.0));
}
