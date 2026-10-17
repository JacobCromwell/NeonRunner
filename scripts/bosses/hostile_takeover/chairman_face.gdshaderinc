// The Chairman's face (GDD §10: one of the villain's inner circle; Hostile Takeover's), head and shoulders, drawn as
// distances so it stays crisp on every renderer. One face for everything that shows him: the fight's merger screens
// (hostile_takeover_screen.gdshader) and the photo the runner shows round in the Marketplace's intro
// (marketplace_intro_card.gdshader). Also the distance helpers both use.
//
// chairman_face(p, col, glint): p is the picture's middle at the origin, y up, a unit the picture's height; `col` is
// the picture behind him (returned with him drawn over it); `glint` the cold glint in his eyes.

// His look (the owner's reference, October 17, 2026; simplified): a lean, hard face with a cybernetic implant at
// his left temple, its traces running over his brow and down his cheek; dark hair in an undercut, the top swept
// back; a long black coat with a tall turned-up collar over armoured shoulder plates and a tactical vest, a tech
// brace round his throat. The tech's lights are the brand's blue (the reference's cyan is a hazard colour, GDD §2).
const vec3 CHAIRMAN_SKIN = vec3(0.76, 0.64, 0.56);
const vec3 CHAIRMAN_SKIN_SHADE = vec3(0.54, 0.43, 0.38);
const vec3 CHAIRMAN_HAIR = vec3(0.07, 0.065, 0.06);
const vec3 CHAIRMAN_COAT = vec3(0.075, 0.075, 0.085);
const vec3 CHAIRMAN_COAT_EDGE = vec3(0.17, 0.17, 0.19);
const vec3 CHAIRMAN_ARMOR = vec3(0.2, 0.21, 0.24);
const vec3 CHAIRMAN_VEST = vec3(0.12, 0.125, 0.14);
const vec3 CHAIRMAN_TECH = vec3(0.3, 0.5, 1.0);

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

vec2 chairman_rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
}

vec3 chairman_face(vec2 p, vec3 col, vec3 glint) {
	float ax = abs(p.x);
	// The collar's lining behind his neck.
	col = mix(col, CHAIRMAN_COAT * 0.6, fill(sd_box(p - vec2(0.0, -0.2), vec2(0.15 + (-0.08 - p.y) * 0.2, 0.12))));
	// The coat over his shoulders.
	float coat = sd_round_box(p - vec2(0.0, -0.53), vec2(0.45, 0.24), 0.12);
	col = mix(col, CHAIRMAN_COAT, fill(coat));
	// The vest, between the coat's open fronts (widening down his chest), its plate and its lights.
	float vest = max(ax - 0.07 - (-0.2 - p.y) * 0.32, p.y + 0.2);
	col = mix(col, CHAIRMAN_COAT_EDGE, fill(vest - 0.008) * fill(coat));
	col = mix(col, CHAIRMAN_VEST, fill(vest) * fill(coat));
	float plate = sd_round_box(p - vec2(0.0, -0.33), vec2(0.075, 0.05), 0.015);
	col = mix(col, CHAIRMAN_ARMOR * 0.8, fill(plate));
	col = mix(col, CHAIRMAN_TECH, fill(sd_box(p - vec2(0.0, -0.3), vec2(0.006, 0.025))));
	for (int i = 0; i < 3; i++) {
		col = mix(col, CHAIRMAN_TECH * 0.8, fill(sd_box(p - vec2(0.045, -0.31 - float(i) * 0.016), vec2(0.014, 0.004))));
	}
	// Armoured plates on his shoulders, a blue light along each.
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		vec2 sp = chairman_rot(p - vec2(sx * 0.3, -0.315), sx * 0.22);
		float pad = sd_round_box(sp, vec2(0.105, 0.048), 0.04);
		col = mix(col, CHAIRMAN_ARMOR * 0.55, fill(pad));
		col = mix(col, CHAIRMAN_ARMOR, fill(pad + 0.008));
		col = mix(col, CHAIRMAN_TECH, fill(sd_box(sp - vec2(-sx * 0.02, 0.0), vec2(0.04, 0.005))));
	}
	// The neck and the tech brace round his throat.
	float neck = sd_box(p - vec2(0.0, -0.15), vec2(0.07, 0.07));
	col = mix(col, CHAIRMAN_SKIN_SHADE, fill(neck));
	float brace = sd_round_box(p - vec2(0.0, -0.2), vec2(0.09, 0.035), 0.015);
	col = mix(col, CHAIRMAN_ARMOR * 0.75, fill(brace));
	col = mix(col, CHAIRMAN_TECH, fill(sd_box(p - vec2(0.0, -0.2), vec2(0.06, 0.004))));
	// The coat's tall collar, turned up either side of the brace and flaring out.
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		vec2 cp = chairman_rot(p - vec2(sx * 0.135, -0.185), -sx * 0.3);
		float flap = sd_round_box(cp, vec2(0.05, 0.125), 0.02);
		col = mix(col, CHAIRMAN_COAT_EDGE, fill(flap));
		col = mix(col, CHAIRMAN_COAT, fill(flap + 0.008));
	}
	// Ears.
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		col = mix(col, CHAIRMAN_SKIN_SHADE, fill(sd_ellipse(p - vec2(sx * 0.158, 0.06), vec2(0.024, 0.045))));
	}
	// The head: lean and hard, narrowing to a square chin.
	vec2 hp = p - vec2(0.0, 0.07);
	float taper = mix(1.0, 0.76, smoothstep(0.03, -0.2, hp.y));
	float head = sd_round_box(vec2(hp.x / taper, hp.y), vec2(0.152, 0.2), 0.05);
	col = mix(col, CHAIRMAN_SKIN, fill(head));
	// Hollow cheeks and the jaw's shadow.
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		col = mix(col, CHAIRMAN_SKIN_SHADE, 0.35 * fill(sd_segment(p, vec2(sx * 0.1, 0.02), vec2(sx * 0.088, -0.04)) - 0.008));
	}
	// The undercut: his sides shaved close, the top swept back with a hard parting on his right.
	float sides = max(head, max(0.13 - p.y, -(ax - 0.1)));
	col = mix(col, mix(CHAIRMAN_SKIN_SHADE, CHAIRMAN_HAIR, 0.55), fill(sides));
	float top = sd_round_box(p - vec2(0.022, 0.262), vec2(0.13, 0.065), 0.055);
	top = max(top, -(p.y - 0.2 + (p.x + 0.11) * 0.25));
	col = mix(col, CHAIRMAN_HAIR, fill(top));
	col = mix(col, CHAIRMAN_HAIR * 2.4, fill(sd_segment(p, vec2(-0.02, 0.29), vec2(0.1, 0.27)) - 0.003) * fill(top + 0.01));
	// Brows, heavy and drawn down toward the middle: a cold stare.
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		col = mix(col, CHAIRMAN_HAIR, fill(sd_segment(p, vec2(sx * 0.028, 0.108), vec2(sx * 0.12, 0.13)) - 0.012));
		// The eyes: dark, narrow, a cold glint.
		col = mix(col, CHAIRMAN_HAIR, fill(sd_ellipse(p - vec2(sx * 0.072, 0.08), vec2(0.032, 0.0105))));
		col = mix(col, glint, fill(length(p - vec2(sx * 0.072 + 0.009, 0.082)) - 0.0042));
	}
	// The implant at his left temple, its traces over the brow and down the cheek.
	col = mix(col, CHAIRMAN_ARMOR, fill(sd_round_box(p - vec2(0.128, 0.155), vec2(0.016, 0.03), 0.006)));
	float traces = min(sd_segment(p, vec2(0.124, 0.18), vec2(0.1, 0.205)), sd_segment(p, vec2(0.1, 0.205), vec2(0.05, 0.205)));
	traces = min(traces, min(sd_segment(p, vec2(0.13, 0.125), vec2(0.12, 0.04)), sd_segment(p, vec2(0.12, 0.04), vec2(0.1, 0.0))));
	traces = min(traces, min(length(p - vec2(0.05, 0.205)), length(p - vec2(0.1, 0.0))) - 0.005);
	col = mix(col, CHAIRMAN_TECH, fill(traces - 0.0032));
	// The nose's shadow and a hard, level mouth.
	col = mix(col, CHAIRMAN_SKIN_SHADE, fill(sd_segment(p, vec2(0.0, 0.06), vec2(0.014, -0.015)) - 0.006));
	col = mix(col, CHAIRMAN_SKIN_SHADE * 0.8, fill(sd_segment(p, vec2(-0.012, -0.028), vec2(0.026, -0.024)) - 0.005));
	float mouth = sd_segment(p, vec2(-0.045, -0.072), vec2(0.045, -0.074));
	col = mix(col, vec3(0.3, 0.16, 0.15), fill(mouth - 0.005));
	col = mix(col, CHAIRMAN_SKIN_SHADE, 0.5 * fill(sd_segment(p, vec2(-0.02, -0.105), vec2(0.02, -0.105)) - 0.006));
	return col;
}
