// The volleyball (VolleyballBall): white, blue and yellow panels in three groups of three curved stripes, like a
// beach volleyball, drawn from the sphere's own directions so they turn with it as it spins. Lit like the characters
// (the runner, the rival), so it reads round against the bright sand and the sky. Never emissive: the ball is safe.
shader_type spatial;
render_mode cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

uniform vec3 white_color : source_color = vec3(0.95, 0.95, 0.93);
uniform vec3 blue_color : source_color = vec3(0.12, 0.33, 0.72);
uniform vec3 yellow_color : source_color = vec3(0.98, 0.80, 0.22);
uniform vec3 seam_color : source_color = vec3(0.35, 0.35, 0.38);

varying vec3 dir;

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	vec3 n = normalize(dir);
	vec3 a = abs(n);
	// Which of the three panel groups (the axis the point is nearest), and the coordinate its stripes run across.
	float across;
	float group;
	if (a.x >= a.y && a.x >= a.z) {
		group = 0.0;
		across = n.y / max(a.x, 0.001);
	} else if (a.y >= a.z) {
		group = 1.0;
		across = n.z / max(a.y, 0.001);
	} else {
		group = 2.0;
		across = n.x / max(a.z, 0.001);
	}
	// Three stripes per group, from -1 to 1 across it: the middle one white, the outer ones coloured, groups
	// alternating blue and yellow.
	float stripe = floor(clamp((across + 1.0) * 1.5, 0.0, 2.999));
	vec3 outer = mod(group, 2.0) < 0.5 ? blue_color : yellow_color;
	vec3 col = stripe == 1.0 ? white_color : outer;
	// The seams between stripes and between groups, thin and grey.
	float f = fract((across + 1.0) * 1.5);
	float seam = 1.0 - smoothstep(0.0, 0.06, min(f, 1.0 - f));
	float edge = 1.0 - smoothstep(0.0, 0.035, min(abs(a.x - a.y), min(abs(a.y - a.z), abs(a.x - a.z))));
	col = mix(col, seam_color, max(seam * 0.6, edge * 0.7));
	ALBEDO = to_linear(col);
	ROUGHNESS = 0.55;
}
