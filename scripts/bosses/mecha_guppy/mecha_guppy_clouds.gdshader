// A layer of low cloud far below Mecha Guppy and Captain Cogs' climb (MechaGuppyWaterfall's cloud layers; GDD §10: the
// climb must read as climbing high). Soft patches at one world height, sunset-lit on top, drifting slowly, kept clear of
// the climb itself (the lanes and the chasms are never hidden), fading out toward the camera's far plane. A layer only
// shows once the runner is above it (opacity, set by the script), so clouds are always something left below.
// Unshaded and fog-free (its own fade with distance); nothing glows or flickers.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform vec3 cloud_color : source_color = vec3(0.98, 0.88, 0.86);
uniform vec3 shadow_color : source_color = vec3(0.74, 0.6, 0.7);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// No cloud within this far of the climb's line (metres), a soft edge this wide beyond it.
uniform float clear_half_width = 30.0;
uniform float seed = 0.0;

varying vec3 world_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Wrapped world coordinates (a seam every 4 km, far past any view) so the pattern stays sharp however far the runner goes.
	vec2 p = mod(world_pos.xz, vec2(4096.0)) * 0.011 + vec2(seed * 17.3, seed * 5.1 + TIME * 0.003);
	float n = value_noise(p) * 0.55 + value_noise(p * 2.3 + 7.0) * 0.3 + value_noise(p * 5.1 + 3.0) * 0.15;
	float cover = smoothstep(0.5, 0.7, n);
	float clear = smoothstep(clear_half_width, clear_half_width + 30.0, abs(world_pos.x));
	float dist = length(world_pos.xz - CAMERA_POSITION_WORLD.xz);
	float edge = 1.0 - smoothstep(280.0, 420.0, dist);
	ALBEDO = mix(shadow_color, cloud_color, smoothstep(0.55, 0.85, n));
	ALPHA = cover * clear * edge * opacity * 0.85;
}
