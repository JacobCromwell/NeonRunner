shader_type spatial;
// The cyborgs' material on the shared HumanoidRig (built by CyborgSuit). Like humanoid_body.gdshader,
// the vertex colour is the albedo (already linear) and UV.x the glow, so plain parts and neon trim
// share one material. A few pieces are marked by a glow value above 9 instead, so the same material,
// and so a single draw call per body segment, also draws:
//   glow 10  the LED visor screen: a pixel face (`face`) shown as round LED dots, with the host's
//            purple static and jumping rows (`glitch`) and the scavenger's flicker and crack;
//   glow 20  the arm cannon's emitter ring, brightening with `charge` (the attack telegraph);
//   glow 30  the charge orb at the muzzle, grown from nothing by `charge` in the vertex stage.
// Each cyborg has its own copy (its face, charge, hit flash and death are its own).
// Plain spatial shading: works on Forward+, Mobile and Compatibility (web, low-end Android).

uniform float glow_energy = 2.6;
// Multiplies all trim glow: 0 once dead.
uniform float glow_boost = 1.0;
// Tint over the body (hit flash, death). Alpha = strength.
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.45;
uniform float metallic : hint_range(0.0, 1.0) = 0.12;

uniform sampler2D face : filter_nearest;
uniform vec4 led_color : source_color = vec4(1.0, 0.62, 0.14, 1.0);
uniform vec4 glitch_color : source_color = vec4(0.72, 0.25, 1.0, 1.0);
uniform float led_energy = 3.2;
uniform float glitch = 0.0;
uniform float flicker = 0.0;
uniform float crack = 0.0;
uniform float seed = 0.0;
// The screen's rectangle in the head segment's space: (x min, y min, x max, y max).
uniform vec4 screen_rect = vec4(-0.109, 0.067, 0.109, 0.186);

uniform vec4 charge_color : source_color = vec4(1.0, 0.15, 0.1, 1.0);
uniform float charge = 0.0;
// The orb's centre in the cannon forearm's space.
uniform vec3 orb_center = vec3(0.0, -0.43, 0.0);

varying vec3 v_local;
varying flat float v_kind;

const vec2 GRID = vec2(13.0, 7.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_local = VERTEX;
	float g = UV.x;
	v_kind = g > 29.5 ? 3.0 : (g > 19.5 ? 2.0 : (g > 9.5 ? 1.0 : 0.0));
	if (v_kind > 2.5) {
		float s = 0.0;
		if (charge > 0.02) {
			s = mix(0.3, 1.7, charge);
			if (charge > 0.95) {
				s += 0.25 * sin(TIME * 60.0);
			}
		}
		VERTEX = orb_center + (VERTEX - orb_center) * s;
	}
}

void fragment() {
	vec3 base = COLOR.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	if (v_kind < 0.5) {
		ALBEDO = mix(base, tint.rgb, tint.a);
		EMISSION = base * UV.x * glow_energy * glow_boost + tint.rgb * (tint.a * 0.6);
	} else if (v_kind < 1.5) {
		// The face, seen from the front: u runs from the cyborg's right to its left.
		vec2 uv = vec2((screen_rect.z - v_local.x) / (screen_rect.z - screen_rect.x),
			(screen_rect.w - v_local.y) / (screen_rect.w - screen_rect.y));
		uv = clamp(uv, vec2(0.0), vec2(0.999));
		float t = TIME + seed * 13.7;
		vec2 cell = floor(uv * GRID);
		float tick = floor(t * 12.0);
		float jump = step(1.0 - 0.3 * glitch, hash(vec2(cell.y, tick)));
		cell.x = mod(cell.x + jump * floor((hash(vec2(tick, cell.y + 3.0)) - 0.5) * 7.0), GRID.x);
		float on = texture(face, (cell + 0.5) / GRID).r;
		vec2 f = fract(uv * GRID) - 0.5;
		float dot_mask = smoothstep(0.5, 0.28, length(f));
		vec3 col = led_color.rgb * on;
		float stat = step(0.8, hash(cell + vec2(tick * 1.7, tick))) * glitch;
		col = mix(col, glitch_color.rgb * max(on, 0.7), clamp(stat + glitch * 0.5 * on, 0.0, 1.0));
		float drop = step(0.72, hash(vec2(floor(t * 9.0), seed + 1.0)));
		col *= 1.0 - flicker * drop * 0.8;
		float crack_d = abs(uv.y - (1.05 - uv.x * 1.25) - 0.035 * sin(uv.x * 57.0));
		float cracked = crack * (1.0 - smoothstep(0.025, 0.055, crack_d));
		col *= 1.0 - cracked;
		ALBEDO = vec3(0.015, 0.012, 0.02) + vec3(0.18) * cracked;
		ROUGHNESS = 0.15;
		EMISSION = col * led_energy * dot_mask * (1.0 - cracked);
	} else if (v_kind < 2.5) {
		ALBEDO = charge_color.rgb * 0.25;
		EMISSION = charge_color.rgb * mix(0.5, 4.0, charge) * max(glow_boost, 0.25);
	} else {
		ALBEDO = charge_color.rgb;
		EMISSION = charge_color.rgb * 5.0;
	}
}
