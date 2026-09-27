shader_type spatial;
// The cyborgs' material on the shared HumanoidRig (built by CyborgSuit). Like humanoid_body.gdshader,
// the vertex colour is the albedo (stored linear; humanoid_color.gdshaderinc shows it right on every
// renderer, the Compatibility one included), its alpha 1 - the piece's shine, and UV.x the glow. A few
// pieces are marked by a glow value above 9 instead, so the same material, and so a single draw call
// per body segment, also draws:
//   glow 10  the screen head's CRT screen, the face (GDD §9.2): a pixel face (`face`) as round LED dots
//            in cold white under scanlines and faint static, on a tube darkened toward its rounded
//            corners; a host's purple static and jumping rows (`glitch`, GDD §9.7); flicker and a crack
//            for zone variants (`flicker`, `crack`; the base has neither); and the switch-off of a
//            defeated cyborg (`screen_power`: the picture collapses to a line, then goes dark);
//   glow 20  the arm cannon's emitter ring, brightening with `charge` (the attack telegraph);
//   glow 30  the charge orb at the muzzle, grown from nothing by `charge` in the vertex stage;
//   glow 40  a host's purple veins, pulsing slowly.
// Each cyborg has its own copy (its face, charge, hit flash and death are its own).
// Far away the LED dots, scanlines and static fade to their average, so the face's shape still reads
// when the screen is a few pixels tall instead of breaking up into flickering dots.
// Settings > Reduced flashing (the global `reduced_flashing`): the static holds still, a host's static
// and row jumps change at most 2.5 times a second, a flickering screen dims steadily, the veins glow
// steadily, the full charge orb swells slowly instead of throbbing, and the switch-off fades out
// without its bright line.
// Plain spatial shading: works on Forward+, Mobile and Compatibility (web, low-end Android).

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
#include "res://scripts/characters/humanoid_color.gdshaderinc"

uniform float glow_energy = 2.6;
// Multiplies the trim glow (the cannon's idle ring, a host's veins): 0 once dead.
uniform float glow_boost = 1.0;
// Tint over the body (hit flash, death). Alpha = strength.
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
// Cloth and grime are rough; the dull metal (HumanoidPiece.shine, in the vertex colour's alpha) a
// little less.
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float polished_roughness : hint_range(0.0, 1.0) = 0.3;
uniform float metallic : hint_range(0.0, 1.0) = 0.06;

// The face's pixel image (one texel per LED, with mipmaps for the far view).
uniform sampler2D face : filter_linear_mipmap, repeat_disable;
uniform vec2 face_grid = vec2(13.0, 9.0);
uniform vec4 led_color : source_color = vec4(0.86, 0.91, 1.0, 1.0);
uniform vec4 glitch_color : source_color = vec4(0.72, 0.25, 1.0, 1.0);
// Emission of a lit LED over its colour, and the static's share of it.
uniform float led_energy = 2.6;
uniform float static_amount = 0.16;
uniform float glitch = 0.0;
uniform float flicker = 0.0;
uniform float crack = 0.0;
// 1 = on; falling to 0 switches the screen off.
uniform float screen_power = 1.0;
uniform float seed = 0.0;
// The screen's rectangle in the head segment's space: (x min, y min, x max, y max).
uniform vec4 screen_rect = vec4(-0.165, 0.04, 0.165, 0.27);

uniform vec4 charge_color : source_color = vec4(1.0, 0.15, 0.1, 1.0);
uniform float charge = 0.0;
// The orb's centre in the cannon forearm's space.
uniform vec3 orb_center = vec3(0.0, -0.43, 0.0);

// A host's veins: emission over their colour, and the pulse's rate (Hz) and depth.
uniform float vein_energy = 2.0;
uniform float vein_rate = 1.1;
uniform float vein_depth = 0.35;

// The share of a cell an LED dot's light fills (in linear light), for the face far away.
const float DOT_FILL = 0.42;

varying vec3 v_local;
varying flat float v_kind;

float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void vertex() {
	v_local = VERTEX;
	float g = UV.x;
	v_kind = g > 39.5 ? 4.0 : (g > 29.5 ? 3.0 : (g > 19.5 ? 2.0 : (g > 9.5 ? 1.0 : 0.0)));
	if (v_kind > 2.5 && v_kind < 3.5) {
		float s = 0.0;
		if (charge > 0.02) {
			s = mix(0.3, 1.7, charge);
			if (charge > 0.95) {
				s += mix(0.25 * sin(TIME * 60.0), 0.08 * sin(TIME * 10.0), reduced_flashing);
			}
		}
		VERTEX = orb_center + (VERTEX - orb_center) * s;
	}
}

void fragment() {
	vec3 base = humanoid_base_color(COLOR.rgb);
	ROUGHNESS = mix(polished_roughness, roughness, COLOR.a);
	METALLIC = metallic;
	// The screen's pixel footprint, taken outside the branches (neighbouring pixels at a piece's edge
	// may take different ones).
	vec2 footprint = fwidth(v_local.xy);
	if (v_kind < 0.5) {
		ALBEDO = mix(base, tint.rgb, tint.a);
		EMISSION = base * UV.x * glow_energy * glow_boost + tint.rgb * (tint.a * 0.6);
	} else if (v_kind < 1.5) {
		// The glass, seen from the front: u runs from the cyborg's right to its left, v from the top.
		vec2 size = screen_rect.zw - screen_rect.xy;
		vec2 uv = clamp(vec2((screen_rect.z - v_local.x) / size.x, (screen_rect.w - v_local.y) / size.y),
			vec2(0.0), vec2(1.0));
		vec2 duv = footprint / size;
		float aspect = size.x / size.y;
		float t = TIME + seed * 13.7;
		// The switch-off squashes the picture into a line, then the line into a dot.
		float power = clamp(screen_power, 0.0, 1.0);
		vec2 squash = vec2(clamp(power * 5.0, 0.02, 1.0), max(power, 0.012));
		vec2 q = (uv - 0.5) / squash + 0.5;
		float shown = step(abs(uv.x - 0.5), squash.x * 0.5) * step(abs(uv.y - 0.5), squash.y * 0.5);
		// The face: one LED per cell of the face's pixel grid. A host's rows jump sideways.
		vec2 cell = floor(q * face_grid);
		float tick = mod(floor(t * mix(12.0, 2.5, reduced_flashing)), 97.0);
		float jump = step(1.0 - 0.3 * glitch, hash12(vec2(cell.y, tick) + seed));
		cell.x = mod(cell.x + jump * floor((hash12(vec2(tick, cell.y + 3.0)) - 0.5) * 7.0), face_grid.x);
		vec2 cells_per_px = duv / squash * face_grid;
		float cells_px = max(cells_per_px.x, cells_per_px.y);
		float px_per_cell = 1.0 / max(cells_px, 1e-5);
		// Close up each LED is its own texel; far away the cells under a pixel are averaged (mipmaps),
		// so a face a few pixels across keeps its shape instead of aliasing to black.
		float on_near = texelFetch(face, ivec2(clamp(cell, vec2(0.0), face_grid - 1.0)), 0).r;
		float on_far = textureLod(face, clamp(q, vec2(0.0), vec2(1.0)), log2(max(cells_px, 1.0))).r;
		float on = mix(on_near, on_far, smoothstep(0.6, 1.4, cells_px));
		vec2 f = fract(q * face_grid) - 0.5;
		float dot_shape = smoothstep(0.5, 0.28, length(f));
		float near = smoothstep(1.5, 4.0, px_per_cell);
		// Faint static in the LEDs' cold white (still with Reduced flashing), fading to its average far away.
		float grain_tick = mod(floor(t * 14.0), 89.0) * (1.0 - reduced_flashing);
		float grain = hash12(floor(uv * vec2(aspect * 54.0, 54.0)) + vec2(grain_tick * 7.13, seed * 3.31 + 11.0));
		grain = mix(0.5, grain, 1.0 - smoothstep(0.3, 0.8, max(duv.x * aspect, duv.y) * 54.0));
		float noise = static_amount * grain;
		// A host: purple static in blocks round its face, a faint purple wash, the face tinged purple.
		float blocks = step(0.8, hash12(cell + vec2(tick * 1.7, tick) + seed));
		float purple = glitch * (blocks * mix(0.45, dot_shape, near) * 0.7 * (1.0 - on) + 0.16 + 0.2 * grain);
		vec3 face_color = mix(led_color.rgb, glitch_color.rgb, 0.22 * glitch * on);
		// Zone variants: a flickering screen (steadily dimmed with Reduced flashing) and a crack.
		float drop = step(0.72, hash12(vec2(mod(floor(t * 9.0), 89.0), seed + 1.0)));
		float shade = 1.0 - flicker * mix(drop * 0.8, 0.2, reduced_flashing);
		float crack_d = abs(uv.y - (1.05 - uv.x * 1.25) - 0.035 * sin(uv.x * 57.0));
		float cracked = crack * (1.0 - smoothstep(0.025, 0.055, crack_d));
		// Scanlines (averaging out far away), and the tube: darker toward its rounded corners.
		shade *= 1.0 - 0.3 * filtered_pulse(q.y * 60.0, duv.y * 60.0 / squash.y, 0.0, 0.4);
		vec2 c = (uv - 0.5) * vec2(aspect, 1.0);
		shade *= 1.0 - 0.45 * dot(c, c);
		float aa = max(duv.x * aspect, duv.y) * 1.5 + 1e-4;
		float tube = 1.0 - smoothstep(-aa, aa, rounded_box(c, vec2(aspect * 0.5 - 0.02, 0.48), 0.09));
		shade *= shown * (1.0 - cracked) * tube * smoothstep(0.0, 0.06, power);
		// Switching off: the collapsing line brightens (not with Reduced flashing).
		float boost = mix(1.0 + 1.6 * (1.0 - power), 1.0, reduced_flashing);
		// The LEDs glow above the bloom threshold (led_energy), their light taken in linear light: each
		// dot close up, and far away the dots' average (they fill DOT_FILL of a cell), so a distant face
		// still glows as brightly as its dots would. The static and a host's purple are brightness as
		// seen (0-1), turned into light with to_linear(), so the screen looks the same on every renderer.
		float lit = mix(on * DOT_FILL * humanoid_to_linear(vec3(shade)).x,
			humanoid_to_linear(vec3(on * dot_shape * shade)).x, near);
		vec3 light = humanoid_glow(face_color, led_energy * lit)
			+ led_color.rgb * to_linear(vec3(noise * shade)) + glitch_color.rgb * to_linear(vec3(purple * shade));
		// Dark glass with a soft sheen (a glossier one mirrors the sky and washes the face out).
		ALBEDO = to_linear(mix(vec3(0.07), vec3(0.04, 0.042, 0.046) + vec3(0.3) * cracked, tube));
		ROUGHNESS = mix(0.6, 0.38, tube);
		SPECULAR = mix(0.3, 0.2, tube);
		EMISSION = light * boost;
	} else if (v_kind < 2.5) {
		ALBEDO = humanoid_glow(charge_color.rgb, 0.25);
		EMISSION = humanoid_glow(charge_color.rgb, mix(0.5, 4.0, charge) * max(glow_boost, 0.25));
	} else if (v_kind < 3.5) {
		ALBEDO = charge_color.rgb;
		EMISSION = humanoid_glow(charge_color.rgb, 5.0);
	} else {
		float beat = mix(1.0 + vein_depth * 0.5 * sin(TIME * 6.2832 * vein_rate + seed), 1.0, reduced_flashing);
		ALBEDO = humanoid_glow(glitch_color.rgb, 0.3);
		EMISSION = humanoid_glow(glitch_color.rgb, vein_energy * beat * glow_boost);
	}
}
