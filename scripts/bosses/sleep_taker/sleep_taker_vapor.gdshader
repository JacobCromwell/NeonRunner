// The Sleep Taker's vapour (SleepTakerModel): the shroud around its heads, the skirt it trails down to
// the street and the pool it spreads there. Translucent, so the lanes beyond stay visible through it.
// UV.x the part (Part: SHROUD, SKIRT, POOL), UV.y the weight (the skirt: 0 at its top, 1 at the
// street); COLOR.rgb its colour and COLOR.a its opacity.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform float inhale = 0.0;
uniform float lunge = 0.0;
uniform float fade = 0.0;
uniform float attack = 0.0;
uniform float seed = 0.0;
uniform vec4 rim_color : source_color = vec4(0.58, 0.28, 1.0, 1.0);

const float SHROUD = 8.0;
const float SKIRT = 9.0;
const float POOL = 10.0;
const vec3 CLUSTER = vec3(0.0, 10.6, 0.0);

varying float v_kind;

void vertex() {
	float part = floor(UV.x + 0.5);
	float w = UV.y;
	float t = TIME + seed * 5.1;
	vec3 v = VERTEX;
	v_kind = part;
	if (part < SKIRT - 0.5) {
		// The shroud breathes, flares when it attacks, and draws in as it inhales.
		v = CLUSTER + (v - CLUSTER) * (1.0 + 0.03 * sin(t * 1.7 + v.y * 0.6) + 0.06 * attack - 0.1 * inhale);
	} else if (part < POOL - 0.5) {
		// The skirt writhes and streams back along the street.
		v.x += sin(t * 1.3 + v.y * 0.7) * 0.5 * w * w;
		v.z -= 1.6 * w * w * w + sin(t * 1.0 + v.y * 0.9) * 0.3 * w;
	} else {
		// The pool on the street creeps and swells.
		v.xz *= 1.0 + 0.05 * sin(t * 0.8 + atan(v.z, v.x) * 3.0) + 0.08 * inhale;
	}
	v.z += lunge * 1.6 * smoothstep(3.0, 9.0, VERTEX.y);
	v.y -= fade * fade * 1.5;
	VERTEX = v;
}

void fragment() {
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	float shape;
	if (v_kind < SKIRT - 0.5) {
		shape = pow(edge, 2.2);
	} else if (v_kind < POOL - 0.5) {
		shape = 0.3 + 0.7 * edge;
	} else {
		shape = 1.0;
	}
	ALBEDO = mix(COLOR.rgb, rim_color.rgb * 1.6, edge * edge * step(v_kind, POOL - 0.5));
	ALPHA = clamp(COLOR.a * shape * (1.0 - fade), 0.0, 1.0);
}
