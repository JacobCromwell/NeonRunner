shader_type spatial;
// The Gilded Sentinel's cut (GildedSentinel): the red marks of what its halberd cuts, the band on its wall
// and the outer floor lane, lit during its warning and flashing as it swings, and the slash of a swing.
// Additive, unshaded and without textures, so it works on every renderer (Compatibility included). The
// enemy-attack red of every zone (only hazards glow in hazard colours).
// UV.x runs along the stretch, 0 at its end nearest the approaching runner and 1 at the far end; UV.y
// across the strip (0 and 1 at its edges). The marks light up from the far end toward the runner as the
// swing nears (`fill`), like the Bad Dream's lit lanes.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.12, 0.08, 1.0);
// Overall brightness of the lit part (0 = off).
uniform float strength = 0.0;
// How much of the stretch is lit, from its far end toward the runner (0 none, 1 all).
uniform float fill = 1.0;
// A swing's flash over the whole strip, on top (a single smooth rise and fall, never a strobe).
uniform float flash = 0.0;
// The strip's bright border, as a share of its width.
uniform float border = 0.1;

void fragment() {
	float lit = smoothstep(1.0 - fill - 0.04, 1.0 - fill + 0.001, UV.x);
	float edge = min(UV.y, 1.0 - UV.y);
	float rim = 1.0 - smoothstep(0.0, border, edge);
	float ends = smoothstep(0.0, 0.02, UV.x) * smoothstep(0.0, 0.02, 1.0 - UV.x);
	float a = strength * lit * (0.3 + 0.7 * rim) + flash * (0.55 + 0.45 * rim);
	ALBEDO = color.rgb * a * ends;
}
