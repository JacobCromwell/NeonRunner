// The Chairman's face (GDD §10: one of the villain's inner circle; Hostile Takeover's), head and shoulders, drawn as
// distances so it stays crisp on every renderer. One face for everything that shows him: the fight's merger screens
// (hostile_takeover_screen.gdshader) and the photo the runner shows round in the Marketplace's intro
// (marketplace_intro_card.gdshader). Also the distance helpers both use.
//
// chairman_face(p, col, glint): p is the picture's middle at the origin, y up, a unit the picture's height; `col` is
// the picture behind him (returned with him drawn over it); `glint` the cold glint in his eyes.

const vec3 CHAIRMAN_SKIN = vec3(0.78, 0.66, 0.58);
const vec3 CHAIRMAN_SKIN_SHADE = vec3(0.56, 0.45, 0.4);
const vec3 CHAIRMAN_HAIR = vec3(0.07, 0.065, 0.06);
const vec3 CHAIRMAN_SUIT = vec3(0.09, 0.09, 0.11);
const vec3 CHAIRMAN_SHIRT = vec3(0.88, 0.9, 0.94);
const vec3 CHAIRMAN_TIE = vec3(0.12, 0.16, 0.38);

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

vec3 chairman_face(vec2 p, vec3 col, vec3 glint) {
	// Shoulders and the suit.
	float shoulders = sd_round_box(p - vec2(0.0, -0.5), vec2(0.42, 0.22), 0.14);
	col = mix(col, CHAIRMAN_SUIT, fill(shoulders));
	// The shirt's V and the tie.
	float v = max(abs(p.x) - (p.y + 0.42) * 0.42, -(p.y + 0.42));
	v = max(v, p.y + 0.2);
	col = mix(col, CHAIRMAN_SHIRT, fill(v));
	float tie = max(abs(p.x) - 0.022 - (p.y + 0.24) * -0.05, max(p.y + 0.22, -(p.y + 0.42)));
	col = mix(col, CHAIRMAN_TIE, fill(tie));
	// The neck.
	float neck = sd_box(p - vec2(0.0, -0.18), vec2(0.075, 0.06));
	col = mix(col, CHAIRMAN_SKIN_SHADE, fill(neck));
	// Ears.
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		col = mix(col, CHAIRMAN_SKIN_SHADE, fill(sd_ellipse(p - vec2(sx * 0.165, 0.06), vec2(0.028, 0.05))));
	}
	// The head: square-jawed, a little narrower at the chin.
	vec2 hp = p - vec2(0.0, 0.07);
	float taper = mix(1.0, 0.82, smoothstep(0.02, -0.2, hp.y));
	float head = sd_round_box(vec2(hp.x / taper, hp.y), vec2(0.16, 0.2), 0.07);
	col = mix(col, CHAIRMAN_SKIN, fill(head));
	// Slicked-back hair over the top, its parting on his right.
	float cap = max(sd_round_box(p - vec2(0.0, 0.2), vec2(0.175, 0.11), 0.09), -(p.y - 0.17 + 0.03 * abs(p.x) * 4.0));
	col = mix(col, CHAIRMAN_HAIR, fill(cap));
	col = mix(col, CHAIRMAN_SKIN_SHADE * 0.9, fill(sd_segment(p, vec2(-0.06, 0.29), vec2(-0.075, 0.2)) - 0.004) * fill(cap));
	// Brows, low and level toward the middle: a cold stare.
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		col = mix(col, CHAIRMAN_HAIR, fill(sd_segment(p, vec2(sx * 0.03, 0.115), vec2(sx * 0.125, 0.128)) - 0.011));
		// The eyes: dark, narrow, a cold glint.
		col = mix(col, CHAIRMAN_HAIR, fill(sd_ellipse(p - vec2(sx * 0.075, 0.08), vec2(0.034, 0.012))));
		col = mix(col, glint, fill(length(p - vec2(sx * 0.075 + 0.01, 0.083)) - 0.0045));
	}
	// The nose's shadow and the smirk.
	col = mix(col, CHAIRMAN_SKIN_SHADE, fill(sd_segment(p, vec2(0.0, 0.06), vec2(0.016, -0.015)) - 0.006));
	col = mix(col, CHAIRMAN_SKIN_SHADE * 0.8, fill(sd_segment(p, vec2(-0.012, -0.03), vec2(0.03, -0.026)) - 0.005));
	float smirk = min(sd_segment(p, vec2(-0.055, -0.075), vec2(0.02, -0.078)), sd_segment(p, vec2(0.02, -0.078), vec2(0.07, -0.06)));
	col = mix(col, vec3(0.3, 0.16, 0.15), fill(smirk - 0.006));
	return col;
}
