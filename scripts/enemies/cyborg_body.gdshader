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
//   glow 40  a host's purple veins, pulsing slowly;
//   glow 50  a small secondary screen (the Broadcast Brute's side monitors): dark glass with a dim X
//            in the face's cold white over faint static (purple on a host), switching off with it;
//   glow 60  an unlit medallion showing the cult's emblem (`emblem`, the Golden Zone's variant), faded
//            out while it is small on screen, like the skins' hidden marks;
//   glow 70  an unlit pinstripe cloth: thin `stripe_color` stripes running along the segment.
// A zone variant sets its own screen (`screen_rect`, `face_grid`), wear (`flicker`, `crack`,
// `static_amount`), LED dots (`led_shape`: round or diamond), how dark the tube's corners go
// (`vignette`), and how metallic its polished pieces are (`polish_metallic`; the base's dull metal is
// barely metallic).
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
// How metallic a fully polished piece is (a look's gold or chrome); pieces between take their share.
uniform float polish_metallic : hint_range(0.0, 1.0) = 0.06;

// The face's pixel image (one texel per LED, with mipmaps for the far view).
uniform sampler2D face : filter_linear_mipmap, repeat_disable;
uniform vec2 face_grid = vec2(13.0, 9.0);
uniform vec4 led_color : source_color = vec4(0.86, 0.91, 1.0, 1.0);
uniform vec4 glitch_color : source_color = vec4(0.72, 0.25, 1.0, 1.0);
// Emission of a lit LED over its colour, and the static's brightness at most (seen, 0-1).
// DESIGN-TBD (docs/questions/p2.md 3): how much static; the host's purple below (p2.md 4).
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
// The LED dots' shape (0 round, 1 a diamond of the same area) and how much the tube darkens toward
// its corners.
uniform float led_shape = 0.0;
uniform float vignette = 0.45;

// A secondary screen (glow 50): its centre (|x|, y) and half size in the head segment's space (the
// screens come in mirrored pairs), and its brightness (well below the face's).
uniform vec4 glass_rect = vec4(0.25, 0.17, 0.03, 0.025);
uniform float glass_energy = 0.5;

// The emblem's medallion (glow 60): the emblem's picture (sRGB colours, alpha its coverage, with
// mipmaps), its centre (x, y) and half size (z) in the chest segment's space, facing forward, and how
// metallic and smooth its polished mark is.
uniform sampler2D emblem : filter_linear_mipmap, repeat_disable;
uniform vec3 emblem_rect = vec3(0.0, 0.3, 0.07);
uniform float emblem_metallic = 0.7;

// A pinstripe cloth (glow 70): the stripes' colour (unlit), their spacing (metres) and width (a share
// of the spacing).
uniform vec4 stripe_color : source_color = vec4(0.6, 0.5, 0.33, 1.0);
uniform float stripe_spacing = 0.03;
uniform float stripe_width = 0.14;

uniform vec4 charge_color : source_color = vec4(1.0, 0.15, 0.1, 1.0);
uniform float charge = 0.0;
// The orb's centre in the cannon forearm's space.
uniform vec3 orb_center = vec3(0.0, -0.43, 0.0);

// A host's veins: emission over their colour, and the pulse's rate (Hz) and depth. Kept near 1: much
// brighter and the purple's blue clips first, drifting it toward the fences' pink.
uniform float vein_energy = 1.0;
uniform float vein_rate = 1.1;
uniform float vein_depth = 0.3;

// The share of a cell an LED dot's light fills (in linear light), for the face far away.
const float DOT_FILL = 0.42;

varying vec3 v_local;
varying vec3 v_normal;
varying flat float v_kind;

float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// The emblem's colours (rgb, sRGB) and coverage (a) at p in emblem space (the mark's square spans
// -1..1, +y up); `fw` is a pixel's footprint there, taken outside branches. The mip level comes from
// it, and the mark fades out before it spans fewer than about 24 pixels, where its three-fold
// silhouette could read like a radiation trefoil (kit_solid.gdshader's cult_mark(), the same rule).
vec4 emblem_mark(vec2 p, float fw) {
	float size = float(textureSize(emblem, 0).x);
	float lod = log2(max(fw * 0.5 * size, 1.0));
	vec4 t = textureLod(emblem, vec2(p.x, -p.y) * 0.5 + 0.5, lod);
	float inside = step(abs(p.x), 1.0) * step(abs(p.y), 1.0);
	return vec4(t.rgb, t.a * inside * (1.0 - smoothstep(0.055, 0.085, fw)));
}

void vertex() {
	v_local = VERTEX;
	v_normal = NORMAL;
	// The marked kinds: glow 10 → 1 (screen), 20 → 2 (ring), ... 70 → 7 (stripes); plain glows (0-3) → 0.
	v_kind = floor(UV.x * 0.1 + 0.5);
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
	METALLIC = mix(polish_metallic, metallic, COLOR.a);
	// Pixel footprints, taken outside the branches (neighbouring pixels at a piece's edge may take
	// different ones): the screens' and the emblem's (x, y), and the stripes' (x or z).
	vec3 footprint3 = fwidth(v_local);
	vec2 footprint = footprint3.xy;
	if (v_kind < 0.5 || v_kind > 5.5) {
		// A plain piece (its glow in UV.x), or an unlit one with a pattern.
		float glow = v_kind < 0.5 ? UV.x : 0.0;
		if (v_kind > 6.5) {
			// Pinstripes running along the segment: across whichever of x and z the face spans.
			bool side = abs(v_normal.x) > abs(v_normal.z);
			float across = side ? v_local.z : v_local.x;
			float fw = (side ? footprint3.z : footprint3.x) / stripe_spacing;
			float stripe = filtered_pulse(across / stripe_spacing, fw, 0.5 - stripe_width * 0.5, 0.5 + stripe_width * 0.5);
			base = mix(base, stripe_color.rgb, stripe * 0.85);
		} else if (v_kind > 5.5) {
			// The emblem on its medallion, as seen from the front (the picture is never mirrored).
			vec2 p = vec2(emblem_rect.x - v_local.x, v_local.y - emblem_rect.y) / emblem_rect.z;
			vec4 mark = emblem_mark(p, max(footprint.x, footprint.y) / emblem_rect.z);
			base = mix(base, to_linear(mark.rgb), mark.a);
			METALLIC = mix(METALLIC, emblem_metallic, mark.a);
			ROUGHNESS = mix(ROUGHNESS, polished_roughness, mark.a);
		}
		ALBEDO = mix(base, tint.rgb, tint.a);
		EMISSION = base * glow * glow_energy * glow_boost + tint.rgb * (tint.a * 0.6);
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
		// A round dot, or a diamond of the same area (the same light far away).
		float dot_d = mix(length(f), (abs(f.x) + abs(f.y)) * 0.8, step(0.5, led_shape));
		float dot_shape = smoothstep(0.5, 0.28, dot_d);
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
		shade *= 1.0 - vignette * dot(c, c);
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
	} else if (v_kind < 4.5) {
		float beat = mix(1.0 + vein_depth * 0.5 * sin(TIME * 6.2832 * vein_rate + seed), 1.0, reduced_flashing);
		ALBEDO = humanoid_glow(glitch_color.rgb, 0.3);
		EMISSION = humanoid_glow(glitch_color.rgb, vein_energy * beat * glow_boost);
	} else {
		// A secondary screen: a dim X over faint static and scanlines (a host's static is purple),
		// switching off with the face.
		vec2 g = (vec2(abs(v_local.x), v_local.y) - glass_rect.xy) / glass_rect.zw;
		float fwg = max(footprint.x / glass_rect.z, footprint.y / glass_rect.w);
		float arms = min(abs(g.x - g.y), abs(g.x + g.y)) * 0.7071;
		float x_mark = (1.0 - smoothstep(0.13 - fwg, 0.13 + fwg, arms)) * step(max(abs(g.x), abs(g.y)), 0.62);
		float t = TIME + seed * 13.7;
		float grain_tick = mod(floor(t * 14.0), 89.0) * (1.0 - reduced_flashing);
		float grain = hash12(floor(g * 7.0) + vec2(grain_tick * 5.31, seed * 2.7 + 3.0));
		grain = mix(0.5, grain, 1.0 - smoothstep(0.1, 0.3, fwg));
		float scan = 1.0 - 0.3 * filtered_pulse(g.y * 5.0, fwg * 5.0, 0.0, 0.4);
		float inside = 1.0 - smoothstep(0.9 - fwg, 0.9 + fwg, max(abs(g.x), abs(g.y)));
		float power = clamp(screen_power, 0.0, 1.0) * inside * scan;
		float white = (x_mark + 0.25 * grain * (1.0 - glitch)) * power;
		float purple = glitch * 0.3 * grain * power;
		ALBEDO = to_linear(vec3(0.05, 0.052, 0.056));
		ROUGHNESS = 0.4;
		SPECULAR = 0.25;
		EMISSION = humanoid_glow(led_color.rgb, glass_energy * humanoid_to_linear(vec3(white)).x)
			+ glitch_color.rgb * to_linear(vec3(purple));
	}
}
