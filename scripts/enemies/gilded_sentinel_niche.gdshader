shader_type spatial;
// The Gilded Sentinel's niche glow (GildedSentinel): the red its flaring eyes cast on the far side and the back
// of the niche, what a runner sees of the warning from far down the street, where the wall is seen almost edge-on.
// It tints what is behind it red rather than adding red to it: the niche is a chamber of warm bronze stone
// (GoldenStatue.recess), and red added to that goes orange, which is a hazard's colour of its own (gap edges).
// The tint is a dark red laid over it (blend_mix), rising fast to nearly opaque (GildedSentinel.niche_tint_alpha),
// so it passes through orange only for the first moments and the niche is Sentinel red for the rest of the
// warning (the suite measures the blended colour's hue). Unshaded and without textures, so it works on every
// renderer (Compatibility included). The enemy-attack red of every zone (only hazards glow in hazard colours).
// `tint` is in linear light and a plain vec3, not a source_color, so both renderers show the same colour (see
// GoldenSkin.srgb).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 tint = vec3(0.716, 0.0015, 0.0023);
// How strongly the niche is tinted: the blend's alpha (0 = not at all).
uniform float strength = 0.0;

void fragment() {
	ALBEDO = tint;
	ALPHA = clamp(strength, 0.0, 1.0);
}
