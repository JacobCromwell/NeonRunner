// The grasping hands' warning (SleepTakerHands): purple mist pooling in a lane where a hand will rise.
// A flat pool on the street (UV.x across the lane, UV.y along it), unshaded, so it reads as well in the
// dark of lights out as in the arena's light: the nightmare's own purple, never a hazard colour. Its
// swirl drifts slowly (nothing flashes, so Reduced flashing changes nothing here).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 color : source_color = vec4(0.58, 0.28, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.2, 0.06, 0.45, 1.0);
uniform float amount = 0.0;  // the pool forming (0-1) and fading away
uniform float surge = 0.0;   // the hand bursting up out of it
uniform float brightness = 1.6;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	// An ellipse filling the lane and the pool's length, growing with `amount`.
	float r = length(c * vec2(2.0, 2.0)) / max(amount, 0.001);
	float t = TIME * 0.6 + seed * 13.0;
	vec2 p = UV * vec2(3.0, 9.0);
	float swirl = noise(p + vec2(t, -t * 0.7)) * 0.6 + noise(p * 2.1 - vec2(t * 1.3, t * 0.4)) * 0.4;
	float body = 1.0 - smoothstep(0.55, 1.0, r + (swirl - 0.5) * 0.35);
	float core = 1.0 - smoothstep(0.0, 0.55, r);
	vec3 col = mix(color.rgb, core_color.rgb, core * 0.55) * brightness * (0.75 + 0.5 * swirl + 0.8 * surge);
	ALBEDO = col;
	ALPHA = clamp(body * (0.55 + 0.35 * swirl + 0.3 * surge) * min(amount * 1.5, 1.0), 0.0, 0.92);
}
