// The Grand Court's giant feed screens on the palace's towers (GDD §10, the arena: "Giant screens hung on the
// towers show the feed: the cult's emblem and the calm golden face in stage 1, The Magnate's roaring face in
// stage 2"). One material for every tower's screen (GoldenCourtSkin.court_feed_material), its handles the
// fight's to drive (GoldenCourtSkin.set_feed and set_feed_blackout):
//   feed_mode    0: stage 1, the calm golden face and the emblem in turn; 1: stage 2 (E5d-d), The Magnate
//                (DESIGN-TBD: a placeholder here, the face darkened, its mouth open);
//   feed_power   1 on, 0 a dead dark screen (the defeat: "the feed cuts out on every screen");
//   feed_glitch  0-1: tearing bands and a roll (only dimming with Reduced flashing);
//   blackout_center, blackout_radius: every screen within the radius of the centre (world space) is dark,
//                so the screens go dark one after another outward as the radius grows (E5d-d).
//   UV     0-1 across the screen (y up)      UV2.y  the screen's aspect (width / height)
//   COLOR  a = brightness (0-1)
// The colour rule (GDD §5): it glows only in the feed's cold white, the emblem's warm white and a pale
// champagne gold, never a hazard hue; the face's tear is a dull red drawn darker than the face around it
// (it never glows), nothing strobes (slow cross-fades; Reduced flashing stills the scanline drift and the
// glitch's tearing). Colours are sRGB (kit_common's to_linear): the same on both renderers.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform float feed_mode = 0.0;
uniform float feed_power = 1.0;
uniform float feed_glitch = 0.0;
uniform vec3 blackout_center = vec3(0.0, 0.0, 0.0);
uniform float blackout_radius = -1.0;
// How far above the bloom threshold its brightest parts glow.
uniform float feed_brightness = 1.6;
uniform vec3 feed_color : source_color = vec3(0.86, 0.91, 1.0);
uniform vec3 feed_dark : source_color = vec3(0.13, 0.11, 0.1);
uniform vec3 face_color : source_color = vec3(0.95, 0.86, 0.66);
uniform vec3 face_shadow : source_color = vec3(0.42, 0.33, 0.2);
uniform vec3 tear_color : source_color = vec3(0.32, 0.06, 0.07);
uniform vec3 emblem_color : source_color = vec3(1.0, 0.93, 0.82);
// The chosen emblem's coverage in alpha (CultFeed.emblem_texture()).
uniform sampler2D feed_emblem : filter_linear_mipmap, repeat_disable;
// One loop: the face, then the emblem.
uniform float feed_loop = 16.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float window(float k, float a, float b, float f) {
	return smoothstep(a, a + f, k) * (1.0 - smoothstep(b - f, b, k));
}

// A soft line of half-width w at signed distance d, anti-aliased over aa.
float stroke(float d, float w, float aa) {
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

// The calm golden face at p (the screen's middle at 0, its height 1): rgb, coverage in a.
vec4 calm_face(vec2 p, float aa, float roar) {
	vec2 r = vec2(0.25, 0.36);
	float e = length(p / r);
	float head = 1.0 - smoothstep(1.0 - aa * 4.0, 1.0 + aa * 4.0, e);
	// Lit like a cast mask: bright on the brow and the cheeks, deeper toward its edges.
	float lit = clamp(1.05 - 0.75 * e * e + 0.18 * p.y + 0.12 * exp(-pow((abs(p.x) - 0.11) / 0.06, 2.0) - pow((p.y + 0.02) / 0.06, 2.0)), 0.0, 1.0);
	vec3 col = mix(face_shadow, face_color, lit);
	// Closed eyes: gentle arcs curving down; brows above them (knitted for the roar).
	float lines = 0.0;
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		vec2 c = vec2(sx * 0.1, 0.075);
		vec2 q = (p - c) * vec2(1.0, 2.6);
		float lid = stroke(length(q) - 0.055, 0.006, aa) * step(p.y, c.y);
		vec2 b = p - vec2(sx * 0.1, 0.135 - roar * 0.02);
		float brow = stroke(length(b * vec2(1.0, 2.2)) - 0.075, 0.007, aa) * step(0.0, b.y) * (1.0 - roar)
			+ stroke(b.y + sx * b.x * 0.35 * roar, 0.008, aa) * step(abs(b.x), 0.07) * roar;
		lines = max(lines, max(lid, brow));
	}
	// The nose: a ridge and its base.
	lines = max(lines, stroke(p.x, 0.005, aa) * step(-0.09, p.y) * step(p.y, 0.05) * 0.7);
	lines = max(lines, stroke(length((p - vec2(0.0, -0.095)) * vec2(1.0, 2.8)) - 0.04, 0.006, aa) * step(p.y, -0.09));
	// The lips: a calm line with the faintest smile, or a roaring mouth (stage 2's placeholder).
	float smile = p.y + 0.18 - 0.6 * p.x * p.x;
	lines = max(lines, stroke(smile, 0.007, aa) * step(abs(p.x), 0.08) * (1.0 - roar));
	col = mix(col, face_shadow * 0.55, lines);
	float mouth = 1.0 - smoothstep(1.0 - aa * 6.0, 1.0 + aa * 6.0, length((p - vec2(0.0, -0.19)) / vec2(0.09, 0.06)));
	col = mix(col, vec3(0.04, 0.03, 0.03), mouth * roar);
	// The tear: from under its left eye (on the screen's right) down its cheek, a dull red, darker than
	// the gold around it: it never glows.
	float k = clamp((0.045 - p.y) / 0.21, 0.0, 1.0);
	float tx = mix(0.105, 0.122, k);
	float streak = stroke(p.x - tx, mix(0.006, 0.009, k), aa) * step(-0.17, p.y) * step(p.y, 0.045);
	float drop = 1.0 - smoothstep(0.016 - aa, 0.016 + aa, length(p - vec2(0.124, -0.175)));
	col = mix(col, tear_color, max(streak, drop));
	return vec4(col, head);
}

void fragment() {
	float aspect = max(UV2.y, 0.1);
	vec2 p = vec2((UV.x - 0.5) * aspect, UV.y - 0.5);
	vec2 fw = fwidth(UV);
	float aa = max(fw.x * aspect, fw.y);
	float t = TIME;
	// A glitch tears it in bands and rolls it (held still with Reduced flashing: it only dims).
	float still = reduced_flashing;
	float band = floor(UV.y * 9.0 + floor(t * 7.0) * (1.0 - still));
	float tear = (hash12(vec2(band, floor(t * 5.0))) - 0.5) * 0.25 * feed_glitch * (1.0 - still);
	p.x += tear;
	float k = fract(t / feed_loop);
	float face_w = window(k, 0.0, 0.58, 0.06);
	float emblem_w = window(k, 0.6, 0.99, 0.06);
	float roar = clamp(feed_mode, 0.0, 1.0);
	vec3 col = feed_dark;
	float glow = 0.0;
	vec4 face = calm_face(p, aa, roar);
	float fw_face = face.a * mix(face_w, 1.0, roar);
	col = mix(col, face.rgb * (roar > 0.5 ? 0.6 : 1.0), fw_face);
	glow = max(glow, fw_face * 0.85);
	// The emblem: the cult's mark in its warm white (stage 1 only), with a soft glow behind it.
	float half_size = 0.34;
	vec2 eu = p / (half_size * 2.0) + 0.5;
	float lod = log2(max(aa / (half_size * 2.0) * float(textureSize(feed_emblem, 0).x), 1.0));
	float mark = 0.0;
	if (eu.x > 0.0 && eu.x < 1.0 && eu.y > 0.0 && eu.y < 1.0) {
		mark = textureLod(feed_emblem, vec2(eu.x, 1.0 - eu.y), lod).a;
	}
	float em = mark * emblem_w * (1.0 - roar);
	col = mix(col, emblem_color, em);
	col += emblem_color * 0.08 * exp(-dot(p, p) * 9.0) * emblem_w * (1.0 - roar);
	glow = max(glow, em);
	// Soft scanlines, drifting (still with Reduced flashing).
	float scan = 0.92 + 0.08 * sin((UV.y * 140.0 + t * 3.0 * (1.0 - still)) * 3.14159);
	col *= scan;
	// The broadcast's power: dark when off, dark within the blackout's reach, dimmer while glitching.
	float out_of = blackout_radius >= 0.0 ? step(distance(v_world, blackout_center), blackout_radius) : 0.0;
	float power = clamp(feed_power, 0.0, 1.0) * (1.0 - out_of) * (1.0 - 0.35 * feed_glitch);
	vec3 dead = vec3(0.025, 0.022, 0.02);
	col = mix(dead, col, power);
	float bright = mix(1.0, feed_brightness, glow * power);
	ALBEDO = to_linear(col) * COLOR.a * bright;
}
