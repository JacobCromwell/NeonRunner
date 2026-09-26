// Solid low-poly kit surfaces (MeshLayer data). Unshaded with a cheap fake city light, so it costs
// the same on the Compatibility renderer (web, low-end Android) as on Forward+.
//   COLOR.rgb  albedo (sRGB)      COLOR.a  glow: 0 = lit surface, > 0 = emissive (x glow_scale)
//   UV2.x      pattern id (MeshKit.PAT_*), UV2.y pattern parameter
// Patterns use world position, so seams and stripes line up across meshes and chunk cuts.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

uniform float glow_scale = 4.0;
// Sky glow caught at grazing angles: distant roofs and hulls pick up the neon haze.
uniform vec3 sheen_color : source_color = vec3(0.35, 0.25, 0.6);
uniform float sheen_strength = 0.35;
uniform vec3 stripe_dark : source_color = vec3(0.03, 0.03, 0.035);
uniform vec3 panel_dark : source_color = vec3(0.015, 0.015, 0.03);
// Hazard states (HazardStateVisual swaps materials): glow multiplier, and a flicker rate for WARNING.
uniform float state_glow = 1.0;
uniform float flicker_hz = 0.0;

varying vec3 v_world;

// Thin lines every `period` metres along `coord`, box-filtered so they fade to their average
// coverage instead of shimmering when they get dense on screen.
float grid_line(float coord, float period, float half_width) {
	float h = half_width / period;
	return filtered_pulse(coord / period + 0.5, fwidth(coord) / period, 0.5 - h, 0.5 + h);
}

// Two coordinates in the plane of the face, picked by its dominant axis.
vec2 face_coords(vec3 n) {
	return abs(n.y) > 0.5 ? v_world.xz : (abs(n.x) > 0.5 ? v_world.zy : v_world.xy);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	vec3 base = COLOR.rgb;
	float glow = COLOR.a;
	int pattern = int(UV2.x + 0.5);
	float glass = 0.0;

	if (pattern == 1) {
		// ROOF: transverse panel seams and slight plate tones.
		float z = v_world.z + UV2.y;
		base *= 1.0 - 0.4 * grid_line(z, 1.6, 0.025);
		base *= 1.0 - 0.12 * grid_line(z, 0.4, 0.06);
		base *= 0.93 + 0.14 * hash12(vec2(floor(z / 1.6), floor(v_world.x * 0.4)));
	} else if (pattern == 2) {
		// RIBS: vertical corrugation along the face.
		float c = abs(n.x) > 0.5 ? v_world.z : v_world.x;
		base *= 1.0 - 0.35 * grid_line(c, 0.32, 0.045);
	} else if (pattern == 3) {
		// STRIPES: hazard diagonals, the colour glowing between dark bands.
		vec2 p = face_coords(n);
		float s = (p.x + p.y) * 2.2;
		float on = filtered_pulse(s, fwidth(s), 0.0, 0.5);
		base = mix(stripe_dark, base, on);
		glow *= on;
	} else if (pattern == 4) {
		// GLASS: dark, catching soft diagonal reflections of the sky.
		glass = 0.55 + 0.45 * sin((v_world.x * 0.9 + v_world.y * 1.7 + v_world.z * 0.4) * 2.3);
	} else if (pattern == 5) {
		// HULL: plating with panel lines and tone variation.
		vec2 p = face_coords(n);
		float lines = max(grid_line(p.y, 3.2, 0.03), 0.6 * grid_line(p.x + 0.6, 2.4, 0.025));
		base *= (0.88 + 0.24 * hash12(floor(vec2(p.x / 2.4, p.y / 3.2)))) * (1.0 - 0.45 * lines);
	} else if (pattern == 6) {
		// CHECKER: light squares glow.
		vec2 p = face_coords(n) / 0.6;
		vec2 fw = fwidth(p);
		float a = filtered_pulse(p.x, fw.x, 0.0, 0.5);
		float b = filtered_pulse(p.y, fw.y, 0.0, 0.5);
		float on = a * b + (1.0 - a) * (1.0 - b);
		base = mix(stripe_dark, base, on);
		glow *= on;
	} else if (pattern == 7) {
		// GRILLE: horizontal slats.
		base *= 1.0 - 0.6 * grid_line(v_world.y, 0.09, 0.02);
	} else if (pattern == 8) {
		// GLYPHS: rows of neon glyphs on a dark panel; UV in metres, UV2.y scrolls (m/s).
		vec2 uv = vec2(UV.x + TIME * UV2.y + NODE_POSITION_WORLD.z * 0.37, UV.y);
		vec2 cs = vec2(0.55, 0.8);
		vec2 cell = floor(uv / cs);
		vec2 g = (fract(uv / cs) - vec2(0.14, 0.12)) / vec2(0.72, 0.76);
		float inside = step(0.0, g.x) * step(g.x, 1.0) * step(0.0, g.y) * step(g.y, 1.0);
		vec2 gs = clamp(g, 0.0, 0.999) * vec2(2.0, 3.0);
		vec2 sub = floor(gs);
		vec2 sf = fract(gs);
		float r = hash12(cell * 7.13 + sub * 1.37);
		float stroke = r < 0.4 ? step(abs(sf.y - 0.5), 0.17) : (r < 0.75 ? step(abs(sf.x - 0.5), 0.22) : 0.0);
		float on = inside * stroke * step(0.18, hash12(cell.yx * 3.7 + 1.3));
		float fw = max(fwidth(uv.x), fwidth(uv.y));
		on = mix(on, 0.25, clamp((fw - 0.05) * 10.0, 0.0, 1.0));
		base = mix(panel_dark, base, on);
		glow *= on;
	} else if (pattern == 9) {
		// CHEVRONS: arrows along UV.x (0-1 over the face) pointing to UV2.y = +1 or -1, scrolling.
		float a = (UV.x * UV2.y - abs(UV.y - 0.5) * 0.9) * 3.0 - TIME * 1.6;
		float on = filtered_pulse(a, fwidth(a), 0.0, 0.34);
		base = mix(stripe_dark, base, on);
		glow *= on;
	}

	vec3 col;
	if (glow > 0.002) {
		float g = glow * glow_scale * state_glow;
		if (flicker_hz > 0.0) {
			g *= 0.2 + 0.8 * step(0.5, fract(TIME * flicker_hz));
		}
		col = to_linear(base) * g;
	} else {
		// Fake city light: tops catch the sky glow, sides the street, undersides the traffic below.
		float shade = 0.62 + 0.3 * max(n.y, 0.0) + 0.08 * abs(n.x) + 0.06 * n.z - 0.04 * max(-n.y, 0.0);
		float f = 1.0 - clamp(dot(nv, VIEW), 0.0, 1.0);
		vec3 sheen = to_linear(sheen_color) * (f * f * f * sheen_strength + glass * 0.15);
		col = to_linear(base) * shade + sheen;
	}
	ALBEDO = col;
}
