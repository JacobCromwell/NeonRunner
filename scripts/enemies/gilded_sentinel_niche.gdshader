shader_type spatial;
// The Gilded Sentinel's niche glow (GildedSentinel): the red its flaring eyes cast on the far side and the back
// of the niche, what a runner sees of the warning from far down the street, where the wall is seen almost edge-on.
// It tints what is behind it red rather than adding red to it: the niche is a lit chamber of warm stone
// (GoldenStatue.recess, lit), and red added to that goes orange, which is a hazard's colour of its own (gap
// edges). Unshaded and without textures, so it works on every renderer (Compatibility included). The
// enemy-attack red of every zone (only hazards glow in hazard colours).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.05, 0.03, 1.0);
// How strongly the niche is tinted (0 = not at all; 1 = the eyes at full flare).
uniform float strength = 0.0;
// Share of the tint that is brighter than the stone it covers (a red lamp, not a red paint).
uniform float lamp = 0.35;

void fragment() {
	// Stronger toward the middle of the niche's height (where the eyes are), softer toward its floor and arch.
	float h = 1.0 - abs(UV.y * 2.0 - 1.0);
	float k = 0.55 + 0.45 * smoothstep(0.0, 0.6, h);
	ALBEDO = color.rgb * (1.0 + lamp * 1.5);
	ALPHA = clamp(strength * k * 0.8, 0.0, 0.85);
}
