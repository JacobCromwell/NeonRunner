// The Floating Head's face screen (GDD §10: the ship's back is a giant cybernetic propaganda face
// watching over the city). FloatingHeadBody drives the uniforms; the mesh is one quad whose UV runs
// 0-1 across and up as the viewer sees it.
// DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 83): the face's look. Placeholder: the cult's screen
// language (the cyborgs' screen heads, the cult's feed) at the size of a building: a cold white face
// in LED dots on a dark screen, big stern eyes whose pupils follow the runner, heavy brows, a nose
// line and circuit traces down the cheeks, with soft static and a slow rolling bar.
// Rules: it glows only in cold white, and red only in its eyes while they charge (the eye lasers'
// warning, task E1b: enemy-attack red); nothing strobes: powering on is a line opening into the
// picture, and with Reduced flashing the static, the rolling bar and the tearing hold still.
// Unshaded, no textures: the same on Forward+, Mobile and Compatibility.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform vec3 face_color : source_color = vec3(0.86, 0.91, 1.0);
uniform vec3 charge_color : source_color = vec3(1.0, 0.12, 0.08);
uniform vec3 screen_dark : source_color = vec3(0.03, 0.035, 0.05);
// The lit screen behind the face: a faint cold glow.
uniform vec3 screen_lit : source_color = vec3(0.05, 0.06, 0.09);
// How far above the bloom threshold the face's bright lines glow.
uniform float brightness = 3.2;
// The screen's width over its height.
uniform float aspect = 1.3;
// LED dots per screen height.
uniform float dots = 56.0;
// Powering on, 0 (off: dark glass) to 1 (the face): a bright line opens into static, then the face.
uniform float power = 0.0;
// Where the pupils look, -1 to 1 across and up.
uniform vec2 look = vec2(0.0);
// 0 stern, 1 furious: the brows and upper lids come down at the inner corners.
uniform float anger = 0.35;
// Eyelids: 0 open, 1 shut.
uniform float blink = 0.0;
// The eye lasers' warning (task E1b): the eyes turn red and glow brighter.
uniform float eye_charge = 0.0;
// Picture break-up (the defeat, task E1d): rows tear and static floods in.
uniform float glitch = 0.0;
// The propaganda's caption band (task E1d; FloatingHeadBody shows the slogan's text over it): 0 off,
// 1 shown. It covers the screen from its bottom edge up to caption_top (screen heights from its
// centre), under the eyes (the lasers' warning), the face's lines dimmed behind a dark band with a
// light rule along its top.
uniform float caption = 0.0;
uniform float caption_top = -0.17;
// The wreck (task E1d): the dead screen lying in the street, its glass cracked from where it hit and
// the face faintly burnt into it. Nothing moves on it.
uniform float broken = 0.0;
const vec2 CRACK_AT = vec2(0.16, -0.12);

float fh_fill(float d, float aa) {
	return 1.0 - smoothstep(-aa, aa, d);
}

float fh_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Approximate signed distance to an ellipse with radii r (good for strokes and fills).
float fh_ellipse(vec2 p, vec2 r) {
	float k0 = length(p / r);
	float k1 = length(p / (r * r));
	return k0 * (k0 - 1.0) / max(k1, 1e-5);
}

// One eye (side -1: the viewer's left, +1: right): x = its outline and lid line, y = the open eye's
// inside, z = the iris (bright) around the dark pupil.
vec3 fh_eye(vec2 p, float side, float aa) {
	vec2 q = p - vec2(side * 0.26, 0.02);
	// Mirrored, so +x runs to the outer corner on both sides.
	q.x *= side;
	vec2 r = vec2(0.17, 0.095);
	float d = fh_ellipse(q, r);
	// The upper lid comes down: all along it as it blinks, at the inner corner in anger.
	float inner = clamp((r.x - q.x) / (2.0 * r.x), 0.0, 1.0);
	float lid = r.y * (1.0 - 2.0 * blink) - anger * (0.012 + 0.052 * inner);
	float lid_d = q.y - lid;
	float open_d = max(d, lid_d);
	float outline = max(abs(d) - 0.018, lid_d);
	float lid_line = max(abs(lid_d) - 0.018, d);
	vec2 ic = vec2(look.x * side * 0.07, look.y * 0.03 - 0.008);
	float iris = length(q - ic) - 0.064;
	float pupil = length(q - ic) - 0.026;
	float inside = fh_fill(open_d, aa);
	return vec3(fh_fill(min(outline, lid_line), aa), inside, fh_fill(iris, aa) * (1.0 - fh_fill(pupil, aa)) * inside);
}

// The face at p (height units, centred: y from -0.5 to 0.5): x = bright lines, y = dim lines,
// z = the eyes' insides (where the charge glows).
vec3 fh_face(vec2 p, float aa) {
	vec3 left = fh_eye(p, -1.0, aa);
	vec3 right = fh_eye(p, 1.0, aa);
	float bright = max(max(left.x, right.x), max(left.z, right.z));
	for (int i = 0; i < 2; i++) {
		float side = i == 0 ? -1.0 : 1.0;
		vec2 a = vec2(side * 0.09, 0.165 - anger * 0.055);
		vec2 b = vec2(side * 0.43, 0.215 + anger * 0.012);
		bright = max(bright, fh_fill(fh_segment(p, a, b) - 0.032, aa));
	}
	// A nose line with a short base, and circuit traces down the cheeks and across the forehead.
	float dim = fh_fill(fh_segment(p, vec2(0.0, -0.04), vec2(0.0, -0.2)) - 0.01, aa);
	dim = max(dim, fh_fill(fh_segment(p, vec2(-0.055, -0.21), vec2(0.055, -0.21)) - 0.01, aa));
	vec2 m = vec2(abs(p.x), p.y);
	float traces = fh_segment(m, vec2(0.34, -0.1), vec2(0.34, -0.3));
	traces = min(traces, fh_segment(m, vec2(0.34, -0.3), vec2(0.25, -0.39)));
	traces = min(traces, fh_segment(m, vec2(0.25, -0.39), vec2(0.25, -0.5)));
	traces = min(traces, fh_segment(m, vec2(0.44, -0.04), vec2(0.44, -0.5)));
	traces = min(traces, fh_segment(m, vec2(0.12, 0.3), vec2(0.4, 0.3)));
	traces = min(traces, fh_segment(m, vec2(0.4, 0.3), vec2(0.46, 0.24)));
	dim = max(dim, fh_fill(traces - 0.007, aa));
	float nodes = min(length(m - vec2(0.34, -0.1)), length(m - vec2(0.44, -0.04)));
	nodes = min(nodes, length(m - vec2(0.12, 0.3)));
	dim = max(dim, fh_fill(nodes - 0.018, aa));
	return vec3(bright, dim * 0.55, max(left.y, right.y));
}

// The broken glass's cracks at p: rays out of the point it hit, each kinked twice, and a ring round it.
float fh_cracks(vec2 p, float aa) {
	float d = abs(length(p - CRACK_AT) - 0.05);
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		float a = fi * 0.698 + 0.3 * sin(fi * 3.7);
		vec2 dir = vec2(cos(a), sin(a));
		vec2 side = vec2(-dir.y, dir.x);
		vec2 p1 = CRACK_AT + dir * (0.16 + 0.1 * fract(sin(fi * 12.3) * 43.7)) + side * 0.03 * sin(fi * 5.1);
		vec2 p2 = p1 + dir * (0.22 + 0.25 * fract(sin(fi * 7.9) * 31.3)) - side * 0.05 * cos(fi * 2.3);
		d = min(d, fh_segment(p, CRACK_AT, p1));
		d = min(d, fh_segment(p, p1, p2));
	}
	return fh_fill(d - 0.004, aa);
}

void fragment() {
	// Derivatives first, outside any branch (the kit's shader rules).
	vec2 fw = fwidth(UV);
	float on = clamp(power, 0.0, 1.0);
	float still = 1.0 - reduced_flashing;
	float tick = mod(floor(TIME * 12.0), 97.0) * still;
	vec2 uv = UV;
	// Tearing rows (the glitch).
	float row = floor(uv.y * 36.0);
	float tear = step(0.55, hash12(vec2(row * 1.7, tick + 3.0))) * (hash12(vec2(row, tick * 1.3)) - 0.5);
	uv.x += tear * glitch * 0.22;
	vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
	float aa = max(fw.x * aspect, fw.y) * 1.5 + 1e-4;

	vec3 face = fh_face(p, aa) * smoothstep(0.5, 1.0, on);
	// LED dots, fading to their average where they get smaller than a couple of pixels.
	vec2 cell = fract(p * dots) - 0.5;
	float detail = 1.0 - smoothstep(0.25, 0.6, aa * dots);
	float led = mix(0.85, 1.0 - smoothstep(0.32, 0.48, length(cell)), detail);
	// The caption band: the face's lines give way to a dark band under the slogan, with a light rule
	// along its top edge.
	float cap_band = clamp(caption, 0.0, 1.0) * (1.0 - smoothstep(caption_top - aa, caption_top + aa, p.y));
	float cap_rule = clamp(caption, 0.0, 1.0) * (1.0 - smoothstep(0.004, 0.004 + aa * 2.0, abs(p.y - caption_top - 0.012)));
	face.xy *= 1.0 - cap_band * 0.85;
	float lines = max(max(face.x, face.y) * led, cap_rule * (0.6 + 0.3 * detail));
	vec3 col = mix(screen_lit * (1.0 - cap_band * 0.6), face_color, lines);
	// The eyes charging: their insides fill with red and glow.
	float charge = clamp(eye_charge, 0.0, 1.0) * face.z;
	col = mix(col, charge_color * (0.55 + 0.45 * led), charge);
	// Soft static and a slow rolling bar, still with Reduced flashing; more static while it powers on
	// and as it breaks up.
	float noise = smoothstep(0.15, 0.45, on) * (1.0 - smoothstep(0.7, 1.0, on)) + glitch * 0.8;
	float grain = hash12(floor(uv * vec2(aspect * 110.0, 110.0)) + vec2(tick * 7.13, 11.0));
	// Up close the static is grain; far away it averages out to a grey wash, so it still shows.
	col += face_color * ((grain - 0.5) * (0.07 + 0.6 * noise) * detail + noise * 0.3);
	float roll = fract(uv.y + TIME / 7.0 * still) - 0.5;
	col *= 1.0 + 0.1 * exp(-roll * roll * 80.0);
	// Powering on: a thin hot line opens into the picture.
	float open = smoothstep(0.0, 0.35, on);
	float band = mix(0.004, 0.52, open * open);
	float lit = 1.0 - smoothstep(band - aa, band + aa, abs(p.y));
	float line = (1.0 - open) * step(0.001, on) * exp(-abs(p.y) / max(band, 0.004) * 1.5);
	col = mix(screen_dark * 0.7, col, lit) + face_color * line * 1.5;
	// Off: dark glass with a faint diagonal reflection of the city.
	float sheen = smoothstep(0.35, 0.0, abs(p.x * 0.6 + p.y - 0.15)) * 0.05;
	vec3 glass = screen_dark * 0.8 + vec3(0.02, 0.022, 0.035) * sheen * 10.0;
	if (broken > 0.0) {
		// The dead screen: dull grey glass (a panel, not a hole in the street), the face burnt faintly
		// into it, cracked from where it hit.
		vec3 ghost = fh_face(p, aa);
		glass = mix(glass, vec3(0.1, 0.11, 0.14) + sheen * 0.6, broken);
		glass = mix(glass, face_color * 0.26, max(ghost.x, ghost.y) * 0.6 * broken);
		glass += face_color * 0.32 * fh_cracks(p, aa) * broken;
	}
	col = mix(glass, col, step(0.001, on));
	// The curved tube: darker toward the corners, and rounded like a visor (rounder at the chin).
	vec2 v = p / vec2(aspect * 0.5, 0.5);
	col *= 1.0 - 0.25 * dot(v, v) * 0.5;
	float corner = mix(0.09, 0.2, step(p.y, 0.0));
	vec2 qb = abs(p) - vec2(aspect * 0.5, 0.5) + corner;
	float visor = length(max(qb, 0.0)) + min(max(qb.x, qb.y), 0.0) - corner;
	float inside = 1.0 - smoothstep(-aa, aa, visor);
	col = mix(vec3(0.02, 0.02, 0.028), col, inside);
	float glow = (max(lines, charge) * lit * step(0.001, on) + line) * inside;
	ALBEDO = to_linear(col) * mix(1.0, brightness * (1.0 + 1.5 * charge), clamp(glow, 0.0, 1.0));
}
