// The Golden Convergence's Missile Barrage (GDD §10; GoldenConvergenceMissiles): what it shows, by `shape`:
//   0 a flame: crossed quads standing on the floor (UV.y up), a tongue of fire, hot at its foot and red at its
//     tip, its edges licking upward; seeded by where it stands;
//   1 the burning floor under the flames: a flat quad over a lane's stretch, a red glow with embers;
//   2 a missile's fiery trail: crossed quads from its tail back along its path (UV.y 0 at the missile), hot
//     near it and fading out behind;
//   3 a target mark's ring on the floor: a flat quad, a red ring at its edge;
//   4 a target mark's fill: a flat quad, a red disc (its size is how far it has filled in).
// The enemy attacks' red, the same in every zone. Additive and unshaded, so it works the same on Forward+,
// Mobile and Compatibility (lifted there to read as brightly); it fades out far away itself, since fog would
// brighten an additive surface. With Reduced flashing (the global `reduced_flashing`) nothing in it flickers:
// the flames' licking slows to a sway and their brightness holds steady.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform int shape = 0;
uniform vec3 fire_color : source_color = vec3(1.0, 0.18, 0.06);
uniform vec3 core_color : source_color = vec3(1.0, 0.78, 0.42);
uniform vec3 mark_color : source_color = vec3(1.0, 0.12, 0.08);
// How high the fire stands (0 out, 1 full): it dies down after its burn.
uniform float level = 1.0;
uniform float strength = 1.0;
uniform float fade_begin = 90.0;
uniform float fade_end = 320.0;

varying vec3 world_pos;
varying float seed;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 origin = MODEL_MATRIX[3].xyz;
	seed = hash12(origin.xz * 0.37 + vec2(13.1, 7.7));
}

void fragment() {
	float still = 1.0 - reduced_flashing;
	vec3 col;
	float a;
	if (shape == 0) {
		float y = clamp(UV.y, 0.0, 1.0);
		float x = abs(UV.x * 2.0 - 1.0);
		// Licking upward: noise scrolling up the tongue (slow, a sway, with Reduced flashing).
		float speed = mix(0.35, 2.4, still);
		float n = value_noise(vec2(UV.x * 3.0 + seed * 17.0, y * 2.6 - TIME * speed + seed * 5.0));
		float w = 0.5 * (1.0 - pow(y, 1.4)) * (0.7 + 0.55 * n);
		a = (1.0 - smoothstep(w * 0.55, w, x)) * pow(1.0 - y, 0.6);
		// Its brightness flickers (held steady with Reduced flashing).
		a *= 1.0 + 0.25 * still * sin(TIME * 13.0 + seed * 40.0);
		col = mix(core_color, fire_color, smoothstep(0.05, 0.7, y));
		a *= level * 1.6;
	} else if (shape == 1) {
		float across = abs(UV.x * 2.0 - 1.0);
		float glow = 1.0 - smoothstep(0.55, 1.0, across);
		float ember = value_noise(vec2(world_pos.x * 2.2, world_pos.z * 0.9 + TIME * 1.4 * still));
		a = glow * (0.35 + 0.4 * ember) * level;
		col = mix(fire_color, core_color, ember * 0.35);
	} else if (shape == 2) {
		float y = clamp(UV.y, 0.0, 1.0);
		float x = abs(UV.x * 2.0 - 1.0);
		a = pow(1.0 - y, 1.6) * (1.0 - x * x) * 1.4;
		col = mix(core_color, fire_color, smoothstep(0.0, 0.5, y));
	} else if (shape == 3) {
		float r = length(UV * 2.0 - 1.0);
		a = smoothstep(0.66, 0.78, r) * (1.0 - smoothstep(0.9, 1.0, r)) * 1.7;
		col = mark_color;
	} else {
		float r = length(UV * 2.0 - 1.0);
		a = (1.0 - smoothstep(0.82, 1.0, r)) * 0.6;
		col = mark_color;
	}
	float fade = 1.0 - smoothstep(fade_begin, fade_end, length(VERTEX));
	float k = max(a * strength * fade, 0.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// Compatibility adds light in sRGB space, where faint additive light reads far dimmer than on
	// Forward+: lift it so the attack reads as brightly.
	k = pow(k, 0.4545);
#endif
	ALBEDO = to_linear(col) * k;
}
