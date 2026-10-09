// What the Golden Convergence's Missile Barrage lays on the floor (GDD §10; GoldenConvergenceMissiles), in the
// enemy attacks' red (BossProps' red lines, the fist's red square): a see-through glowing colour laid over the
// floor, not added light, so it reads red on the Grand Court's white marble; by `shape`:
//   1 the burning floor under the flames: a flat quad over what burns of a lane's stretch, a deep red-orange
//     glow edge to edge (two lanes' meet with no seam) with embers drifting through it (still with Reduced
//     flashing), dying down with `level`;
//   3 a target mark's ring: a flat quad, a red ring at its edge;
//   4 a target mark's fill: a flat quad, a red disc (its size is how far it has filled in).
// The part pulses the marks (steady with Reduced flashing); nothing here flickers. Blended, not added, so it
// reads the same on Forward+, Mobile and Compatibility; it fades out far away itself.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform int shape = 3;
// Authored in sRGB, like the kit's colours (to_linear converts where the renderer lights in linear space).
uniform vec3 mark_color = vec3(1.0, 0.12, 0.08);
uniform vec3 fire_color = vec3(0.95, 0.16, 0.04);
uniform vec3 ember_color = vec3(1.0, 0.55, 0.12);
// Over 1 it blooms like the red lines' glow where the renderer has bloom.
uniform float energy = 1.6;
uniform float ring_alpha = 0.9;
uniform float fill_alpha = 0.45;
uniform float burn_alpha = 0.72;
// How hot the floor still burns (0 out, 1 full): it dies down after the burn.
uniform float level = 1.0;
uniform float fade_begin = 90.0;
uniform float fade_end = 320.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = mark_color;
	float a;
	if (shape == 1) {
		float still = 1.0 - reduced_flashing;
		float ember = value_noise(vec2(world_pos.x * 2.2, world_pos.z * 0.9 + TIME * 1.4 * still));
		a = (0.8 + 0.2 * ember) * burn_alpha * level;
		col = mix(fire_color, ember_color, smoothstep(0.45, 0.95, ember));
	} else if (shape == 3) {
		float r = length(UV * 2.0 - 1.0);
		a = smoothstep(0.62, 0.72, r) * (1.0 - smoothstep(0.92, 1.0, r)) * ring_alpha;
	} else {
		float r = length(UV * 2.0 - 1.0);
		a = (1.0 - smoothstep(0.86, 1.0, r)) * fill_alpha;
	}
	float fade = 1.0 - smoothstep(fade_begin, fade_end, length(VERTEX));
	ALBEDO = to_linear(col) * energy;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
