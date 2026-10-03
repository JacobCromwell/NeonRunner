// Hostile Takeover's merger screens (GDD §10: "'MERGER COMPLETE' flashes on every screen"; the player gets a
// glimpse of the Chairman "as the face on the 'MERGER COMPLETE' screens"): the Chairman's face as a
// corporate broadcast, drawn as distances so it stays crisp on every renderer, on a deep brand-blue ground
// with faint scanlines and a cold-white frame; a dark band across the top (or the bottom: band_top off)
// carries the words (a TextMesh in front: HostileTakeoverScreens). `power` (0-1) switches it on; `glitch` (0-1) tears it sideways in
// bands (the defeat), still with Reduced flashing (kit_flash: reduced_flashing), where it only dims. No
// hazard's colour anywhere: the cult's screens' cold white and the brand's blues.
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform float power = 0.0;
uniform float glitch = 0.0;
// The quad's width over its height.
uniform float aspect = 1.78;
uniform float brightness = 1.6;
// The band for the words: this share of the height, along the top edge (band_top 1) or the bottom (0).
uniform float band = 0.24;
uniform float band_top = 1.0;

const vec3 GROUND_TOP = vec3(0.05, 0.1, 0.32);
const vec3 GROUND_LOW = vec3(0.015, 0.03, 0.11);
const vec3 FRAME = vec3(0.82, 0.88, 1.0);
const vec3 SKIN = vec3(0.78, 0.66, 0.58);
const vec3 SKIN_SHADE = vec3(0.56, 0.45, 0.4);
const vec3 HAIR = vec3(0.07, 0.065, 0.06);
const vec3 SUIT = vec3(0.09, 0.09, 0.11);
const vec3 SHIRT = vec3(0.88, 0.9, 0.94);
const vec3 TIE = vec3(0.12, 0.16, 0.38);
const vec3 BAND = vec3(0.01, 0.015, 0.05);

float sd_box(vec2 p, vec2 half_size) {
	vec2 q = abs(p) - half_size;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

float sd_round_box(vec2 p, vec2 half_size, float r) {
	return sd_box(p, half_size - vec2(r)) - r;
}

float sd_ellipse(vec2 p, vec2 r) {
	// Approximate: a scaled circle (good enough at these sizes).
	float k = min(r.x, r.y);
	return (length(p / r) - 1.0) * k;
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// 1 inside the shape of distance `d`, smoothed over a pixel.
float fill(float d) {
	float aa = max(fwidth(d), 0.0015);
	return 1.0 - smoothstep(-aa, aa, d);
}

vec3 face(vec2 p) {
	// p: the screen's middle at the origin, y up, a unit the screen's height.
	vec3 col = mix(GROUND_LOW, GROUND_TOP, smoothstep(-0.5, 0.5, p.y));
	// A soft glow behind the head.
	col += vec3(0.05, 0.08, 0.2) * (1.0 - smoothstep(0.0, 0.45, length(p - vec2(0.0, 0.08))));
	// Shoulders and the suit.
	float shoulders = sd_round_box(p - vec2(0.0, -0.5), vec2(0.42, 0.22), 0.14);
	col = mix(col, SUIT, fill(shoulders));
	// The shirt's V and the tie.
	float v = max(abs(p.x) - (p.y + 0.42) * 0.42, -(p.y + 0.42));
	v = max(v, p.y + 0.2);
	col = mix(col, SHIRT, fill(v));
	float tie = max(abs(p.x) - 0.022 - (p.y + 0.24) * -0.05, max(p.y + 0.22, -(p.y + 0.42)));
	col = mix(col, TIE, fill(tie));
	// The neck.
	float neck = sd_box(p - vec2(0.0, -0.18), vec2(0.075, 0.06));
	col = mix(col, SKIN_SHADE, fill(neck));
	// Ears.
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		col = mix(col, SKIN_SHADE, fill(sd_ellipse(p - vec2(sx * 0.165, 0.06), vec2(0.028, 0.05))));
	}
	// The head: square-jawed, a little narrower at the chin.
	vec2 hp = p - vec2(0.0, 0.07);
	float taper = mix(1.0, 0.82, smoothstep(0.02, -0.2, hp.y));
	float head = sd_round_box(vec2(hp.x / taper, hp.y), vec2(0.16, 0.2), 0.07);
	col = mix(col, SKIN, fill(head));
	// Slicked-back hair over the top, its parting on his right.
	float cap = max(sd_round_box(p - vec2(0.0, 0.2), vec2(0.175, 0.11), 0.09), -(p.y - 0.17 + 0.03 * abs(p.x) * 4.0));
	col = mix(col, HAIR, fill(cap));
	col = mix(col, SKIN_SHADE * 0.9, fill(sd_segment(p, vec2(-0.06, 0.29), vec2(-0.075, 0.2)) - 0.004) * fill(cap));
	// Brows, low and level toward the middle: a cold stare.
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		col = mix(col, HAIR, fill(sd_segment(p, vec2(sx * 0.03, 0.115), vec2(sx * 0.125, 0.128)) - 0.011));
		// The eyes: dark, narrow, a cold glint.
		col = mix(col, HAIR, fill(sd_ellipse(p - vec2(sx * 0.075, 0.08), vec2(0.034, 0.012))));
		col = mix(col, FRAME, fill(length(p - vec2(sx * 0.075 + 0.01, 0.083)) - 0.0045));
	}
	// The nose's shadow and the smirk.
	col = mix(col, SKIN_SHADE, fill(sd_segment(p, vec2(0.0, 0.06), vec2(0.016, -0.015)) - 0.006));
	col = mix(col, SKIN_SHADE * 0.8, fill(sd_segment(p, vec2(-0.012, -0.03), vec2(0.03, -0.026)) - 0.005));
	float smirk = min(sd_segment(p, vec2(-0.055, -0.075), vec2(0.02, -0.078)), sd_segment(p, vec2(0.02, -0.078), vec2(0.07, -0.06)));
	col = mix(col, vec3(0.3, 0.16, 0.15), fill(smirk - 0.006));
	return col;
}

void fragment() {
	if (power <= 0.001) {
		ALBEDO = vec3(0.01, 0.012, 0.02);
	} else {
		vec2 uv = UV;
		// The defeat's glitch: bands torn sideways (held still with Reduced flashing).
		float row = floor(uv.y * 14.0);
		float tick = floor(TIME * 9.0);
		float jitter = fract(sin(row * 12.9898 + tick * 78.233) * 43758.5453) - 0.5;
		uv.x += jitter * glitch * 0.18 * (1.0 - reduced_flashing);
		vec2 p = vec2((uv.x - 0.5) * aspect, 0.5 - uv.y);
		// The face sits beside the words' band.
		float side = band_top > 0.5 ? -1.0 : 1.0;
		vec2 fp = (p - vec2(0.0, side * band * 0.5)) / (1.0 - band);
		vec3 col = face(fp);
		// Faint scanlines.
		col *= 0.92 + 0.08 * sin(uv.y * 240.0);
		// The band for the words.
		col = mix(col, BAND, band_top > 0.5 ? step(uv.y, band) : step(1.0 - band, uv.y));
		// The frame.
		float inset = 0.02;
		float frame = sd_box(p, vec2(aspect * 0.5 - inset, 0.5 - inset));
		col = mix(col, FRAME, (1.0 - smoothstep(0.0, 0.006, abs(frame) - 0.004)));
		col *= brightness * clamp(power, 0.0, 1.0) * (1.0 - 0.6 * glitch * reduced_flashing);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		// No HDR there: keep the hues instead of clipping them to white.
		col /= max(1.0, max(col.r, max(col.g, col.b)));
#endif
		ALBEDO = col;
	}
}
