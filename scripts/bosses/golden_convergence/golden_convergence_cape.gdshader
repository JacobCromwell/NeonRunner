// The Golden Convergence's cape (GDD §10: "The cape doesn't have to follow physics: a huge, undulating cloud
// of burgundy cloth with lots of black folds and shadows, billowing from the boss's back. It never glows (the
// colour rule, §5), so red hazards and warnings stay readable. It's scenery, not an attack.").
// GoldenConvergenceModel's cape mesh: two sheets of a grid (UV.x across, UV.y out from the shoulders' back;
// UV2.x the sheet: 0 the cape, 1 the billow further out), VERTEX its cloud at rest, fanned out behind the suit.
// Here it gets its pleats (folds radiating from the shoulders, swaying slowly) and billows (waves rolling
// across and out, growing toward the hem, on TIME: the same on every renderer); its folds turn black in their
// troughs; and for the entrance it's gathered into a bundle at the shoulders and unrolls outward (unfurl 0
// to 1).
// Never glowing: unshaded, its colour no brighter than lit burgundy velvet (well under the bloom threshold),
// a deep wine red far from the enemy attacks' bright red and the fences' pink, and nothing flashes. The
// Compatibility renderer gets the same look less one fine ripple (and GoldenConvergenceModel gives it a
// coarser mesh); colours are authored in sRGB (kit_common's to_linear), so both renderers match.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

// Where the cape hangs from (the suit's local space): along the shoulders' back.
uniform float anchor_y = 14.6;
uniform float anchor_z = -3.6;
uniform float anchor_half = 11.0;
// 0: gathered at the shoulders; 1: its whole cloud.
uniform float unfurl = 1.0;
// How hard it billows (1 its usual roll), and how fast.
uniform float billow = 1.0;
uniform float time_scale = 1.0;
// The pleats across the cloth (radiating from the shoulders), and how deep they get at the hem.
uniform float pleats = 7.0;
uniform float pleat_depth = 2.4;
// Burgundy velvet and the black of its folds (sRGB).
uniform vec3 cloth_color = vec3(0.46, 0.06, 0.11);
uniform vec3 fold_color = vec3(0.025, 0.01, 0.015);
// Where its light comes from (the suit's space, roughly the court's warm overhead light).
uniform vec3 light_dir = vec3(0.25, 0.85, 0.45);

varying float v_wave;
varying float v_fold;
varying float v_v;
varying float v_sheet;

void vertex() {
	float u = UV.x;
	float v = UV.y;
	float sheet = UV2.x;
	float t = TIME * time_scale;
	// Waves rolling across and down the cloth, growing toward the hem; the billow sheet rolls harder.
	float amp = (0.5 + 3.6 * v * v) * billow * (1.0 + 0.45 * sheet);
	float w1 = sin(u * 9.0 + t * 0.85 + v * 3.0);
	float w2 = sin(u * 4.3 - t * 0.55 + v * 6.5 + sheet * 1.7);
	float w3 = sin(v * 10.0 - t * 1.25 + u * 2.3 + sheet);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	float w4 = 0.0;
#else
	float w4 = 0.35 * sin(u * 17.0 + v * 9.0 + t * 1.6);
#endif
	float wave = w1 * 0.55 + w2 * 0.45 + w3 * 0.3 + w4;
	// The pleats, swaying a little as the cloth rolls.
	float pleat = sin(u * 6.2832 * pleats + 1.1 * sin(v * 3.5 - t * 0.45 + sheet * 2.0) + sheet * 1.9);
	float pleat_amp = (0.25 + pleat_depth * v) * billow;
	// Mostly out and back (the cloth billowing), a little across and up.
	vec3 full = VERTEX + vec3(0.25 * w2 * amp, 0.4 * w3 * amp, wave * amp + pleat * pleat_amp);
	// Gathered at the shoulders' back, unrolling outward as it unfurls (the hem last).
	vec3 gathered = vec3((u * 2.0 - 1.0) * anchor_half * 0.7, anchor_y - v * 5.0, anchor_z - 0.8 - v * 0.6);
	float k = smoothstep(v * 0.55, v * 0.55 + 0.45, unfurl);
	VERTEX = mix(gathered, full, k);
	v_wave = wave;
	v_fold = smoothstep(0.25, -0.9, pleat) * smoothstep(0.0, 0.3, v);
	v_v = v;
	v_sheet = sheet;
}

void fragment() {
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	vec3 l = normalize((MODEL_MATRIX * vec4(light_dir, 0.0)).xyz);
	// Velvet: lit softly from above, its folds' troughs black, darker toward the hem and on the billow
	// sheet's inside, and a faint sheen at grazing angles.
	float lit = 0.32 + 0.68 * max(dot(n, l), 0.0);
	float trough = smoothstep(0.05, -0.85, v_wave);
	float fold = clamp(max(trough * 0.8, v_fold * 0.92) + v_v * 0.18 + v_sheet * 0.14, 0.0, 1.0);
	vec3 col = mix(to_linear(cloth_color), to_linear(fold_color), fold) * lit;
	float rim = pow(1.0 - clamp(dot(nv, normalize(-VERTEX)), 0.0, 1.0), 3.0);
	col += to_linear(cloth_color) * rim * 0.25 * (1.0 - fold);
	ALBEDO = col;
}
