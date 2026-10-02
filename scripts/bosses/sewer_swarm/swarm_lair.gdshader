// The Sewer Swarm's lairs (SwarmLairs; GDD §10, the Rising: "manholes and wall vents shake all along both
// sides, and screeches pour out"): every manhole of the arena in one MultiMesh and every vent in another,
// built like the sewer screech's own (ScreechLair: a rusted cover with four slots, a grille over a dark
// opening with red eyes behind it). UV.x is the part: 0 still (the rim, the hole, the vent's frame and
// eyes), 1 the lid (the cover with its slots, the grille). Vertex colours: rgb albedo, a glow.
// INSTANCE_CUSTOM = (rattle 0-1, open 0-1, unused, seed): the lid rattles (the screech's warning: its
// slots glow brighter, steadily, never blinking), then bursts open: a cover flips up and clangs back down
// askew over the hole (no open hole is left to look like a gap), a grille flies out and is gone.
shader_type spatial;
render_mode cull_disabled;

// 0 a manhole, 1 a vent (built for the right wall: its face at x = 0, the street toward -x).
uniform int kind = 0;
uniform float glow_energy = 3.0;

varying float v_glow;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float part = floor(UV.x + 0.5);
	vec3 v = VERTEX;
	float rattle = c.x;
	float open = c.y;
	if (part > 0.5) {
		float t = TIME * 33.0 + c.w * 17.0;
		vec3 jitter = vec3(sin(t) * 0.012, abs(sin(t * 1.7)) * 0.05, cos(t * 1.3) * 0.012) * rattle * (1.0 - open);
		if (kind == 0) {
			float tilt = sin(t * 0.9) * 0.12 * rattle * (1.0 - open);
			v = vec3(v.x, v.y * cos(tilt) - v.z * sin(tilt), v.y * sin(tilt) + v.z * cos(tilt));
			// Bursting: up in a spin, then back down over the hole, knocked askew.
			float k = smoothstep(0.0, 1.0, open);
			float lift = sin(3.1416 * clamp(open * 1.15, 0.0, 1.0)) * 0.9;
			float a = 6.2832 * k;
			vec3 p = vec3(v.x, v.y * cos(a) - v.z * sin(a), v.y * sin(a) + v.z * cos(a));
			float yaw = 0.45 * k;
			p = vec3(p.x * cos(yaw) + p.z * sin(yaw), p.y, -p.x * sin(yaw) + p.z * cos(yaw));
			v = p + vec3(0.1 * k, lift, 0.08 * k);
		} else {
			// The grille flies out onto the street, lands and is gone.
			float k = clamp(open, 0.0, 1.0);
			float fade = 1.0 - smoothstep(0.7, 1.0, k);
			vec3 pivot = vec3(-0.09, 0.35, 0.0);
			v = pivot + (v - pivot) * fade;
			v += vec3(-1.6 * k, 2.2 * k * (1.0 - k) - 0.33 * k, 0.2 * k);
		}
		v += jitter;
	}
	VERTEX = v;
	// The slots and eyes glow dim at rest, bright while it rattles, and die away once it's open.
	v_glow = COLOR.a * (0.25 + 0.75 * rattle) * (1.0 - 0.7 * smoothstep(0.0, 0.4, open));
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
	METALLIC = 0.35;
	vec3 glow = COLOR.rgb * v_glow * glow_energy;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	glow /= max(1.0, max(glow.r, max(glow.g, glow.b)));
#endif
	EMISSION = glow;
}
