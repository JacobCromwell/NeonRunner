// The Terminal outro's metro train (TerminalTrainModel): faded paint under dirt, rust coming through, matte
// rubber and trim, bare steel, vine, dark window glass and the train's lights, faceted like the mesh kit (each
// face's normal from screen-space derivatives) and unshaded, so it costs the same on the Compatibility renderer
// (web, low-end Android) as on Forward+. It is lit the way the Terminal's hall is: the work lamps' pools are painted
// from where the fixtures hang (the same functions as kit_terminal.gdshaderinc's tm_burn, tm_pool and tm_lit: change
// them together), so the lamps' light slides over it as it drives.
//   COLOR.rgb  albedo (sRGB)            COLOR.a  glow: 0 = a lit surface, above 0 = emissive (x glow_scale)
//   UV2.x      finish: 0 paint, 1 glass, 2 matte trim, 3 steel, 4 vine, 5 lamp (emissive), 6 inside the cab
//   UV2.y      light group: 0 always as it is, 1 its exterior lights (x `lights`), 2 its saloon's lights (x
//              `interior`), 3 the cab's emergency light (x the larger of `emergency` and `interior`)
// Its dirt is painted from the position on the train (model space), so it travels with it.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

// A level's darker lighting and the street's light under a level's sky (as the kit's shaders).
global uniform float scenery_light;
global uniform vec3 scenery_tint;
global uniform float reduced_flashing;

uniform float glow_scale = 3.0;
// Its lights (head, tail and marker lights), its saloon's lights, and the cab's dim emergency light, 0 (off) to 1 (on).
instance uniform float lights = 0.0;
instance uniform float interior = 0.0;
instance uniform float emergency = 0.0;
// How dirty it is (0 clean, 1 filthy) and how much rust shows.
uniform float grime = 0.7;
uniform float rust_amount = 0.55;
// The hall's colours and lamps, as the skin sets them on its own material (plain sRGB values, TerminalSkin.srgb()).
uniform vec3 tm_lamp = vec3(0.98, 0.6, 0.08);
uniform vec3 tm_haze = vec3(0.42, 0.26, 0.14);
uniform vec3 tm_rust = vec3(0.4, 0.2, 0.09);
uniform vec3 tm_vine = vec3(0.14, 0.27, 0.09);
uniform float tm_pitch = 18.0;
uniform float tm_lamp_y = 8.4;
uniform float tm_lamp_gain = 1.0;
// The key light's direction (toward it) and how much of the albedo shows away from it.
uniform vec3 light_dir = vec3(-0.25, 0.9, 0.35);
uniform float ambient = 0.7;

varying vec3 v_model;
varying vec3 v_world;

void vertex() {
	v_model = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// How brightly work lamp `k` burns (0 to 1) at time t (kit_terminal.gdshaderinc's tm_burn).
float tm_burn(float k, float t) {
	float r = hash11(k * 0.917 + 3.1);
	if (r < 0.18) {
		return 0.0;
	}
	if (r < 0.5) {
		float ph = fract(t * 0.31 + r * 9.0);
		float dip = smoothstep(0.0, 0.03, ph) * (1.0 - smoothstep(0.07, 0.22, ph));
		return mix(0.52, 0.66 - 0.5 * dip, 1.0 - reduced_flashing);
	}
	return 1.0;
}

// The light of the crown lamps on point `w` facing `n` (kit_terminal.gdshaderinc's tm_pool).
float tm_pool(vec3 w, vec3 n, float t) {
	float k0 = floor(-w.z / tm_pitch - 0.5);
	float lit = 0.0;
	for (int i = 0; i < 2; i++) {
		float k = k0 + float(i);
		vec3 d = vec3(0.0, tm_lamp_y, -(k + 0.5) * tm_pitch) - w;
		float d2 = dot(d, d);
		float facing = 0.5 + 0.5 * clamp(dot(n, d * inversesqrt(max(d2, 1e-3))), 0.0, 1.0);
		lit += tm_burn(k, t) * facing * exp(-d2 / 52.0);
	}
	return lit * tm_lamp_gain;
}

// A lit colour: the albedo warmed and brightened by the light that reaches it (kit_terminal.gdshaderinc's tm_lit).
vec3 tm_lit(vec3 base, float lit) {
	vec3 warm = mix(vec3(1.0), mix(tm_lamp, vec3(1.0), 0.2) * 1.15, clamp(lit * 1.7, 0.0, 0.85));
	return min(base * warm * (0.62 + 1.5 * lit), vec3(0.9));
}

// Where on the train's surface a point is, in metres: along it and up a side, across it and up an end, across and along
// a top.
vec2 surface_coords(vec3 m, vec3 n) {
	vec3 a = abs(n);
	if (a.x > 0.6) {
		return vec2(m.z, m.y);
	}
	if (a.z > 0.6) {
		return vec2(m.x, m.y);
	}
	return vec2(m.x, m.z);
}

// Faded paint under dirt: rain streaks from the roof line, grime thickening toward the foot, rust blooming in patches
// and along the edges, flaked paint showing primer.
vec3 weathered_paint(vec3 base, vec2 uv, vec3 m, vec3 n) {
	float soot = 1.0 - smoothstep(0.0, 2.9, m.y);
	float top = smoothstep(2.3, 3.5, m.y);
	// The panels have faded unevenly (each about 1.75 m wide): some paler, some dull, the odd one a repair in another batch.
	float panel = hash12(vec2(floor(uv.x / 1.75), floor(uv.y / 1.2)));
	vec3 col = mix(base, vec3(dot(base, vec3(0.33))), 0.2) * (0.6 + 0.3 * value_noise(uv * 1.3 + 4.0))
		* (0.8 + 0.3 * value_noise(uv * 0.35 + 11.0)) * (0.9 + 0.2 * panel);
	// Rain streaks down from the roof and the sills: long thin ones and broad stains.
	float streak = value_noise(vec2(uv.x * 11.0, uv.y * 0.38 + floor(uv.x * 11.0) * 0.37));
	float broad = value_noise(vec2(uv.x * 2.4 + 3.0, uv.y * 0.16));
	float run = smoothstep(0.36, 0.82, streak) * (0.3 + 0.7 * smoothstep(0.3, 3.3, m.y));
	col = mix(col, vec3(0.17, 0.12, 0.08) * (0.7 + 0.6 * streak), clamp(run * 0.75 + smoothstep(0.45, 0.8, broad) * 0.45, 0.0, 1.0) * grime);
	// Dark stains running down from under the windows' sills (they stand at 1.22 m).
	float sill = step(m.y, 1.22) * (1.0 - smoothstep(0.0, 0.6, 1.22 - m.y)) * smoothstep(0.3, 0.75, value_noise(vec2(uv.x * 6.0, uv.y * 0.5 + 2.0)));
	col = mix(col, vec3(0.13, 0.095, 0.065), sill * 0.7 * grime);
	// The foot is dirty with road grime and brake dust, thickly.
	col = mix(col, vec3(0.1, 0.09, 0.08), clamp(soot * (0.8 + 0.4 * value_noise(uv * 3.1 + 9.0)), 0.0, 1.0) * grime);
	// Rust blooms in patches, thickest low down and along the top edge, running into the dirt.
	float patch_n = value_noise(uv * vec2(0.9, 1.6) + 2.0) * 0.65 + value_noise(uv * vec2(3.4, 5.2) + 7.0) * 0.35;
	float bloom = smoothstep(0.48, 0.76, patch_n) * rust_amount * (0.45 + 1.1 * soot + 0.5 * top);
	col = mix(col, tm_rust * (0.55 + 0.6 * value_noise(uv * 6.0)), clamp(bloom, 0.0, 0.9));
	// Paint flaking away: primer grey, a few small scabs.
	float flake = step(0.8, value_noise(uv * 9.0 + 3.0)) * step(0.45, value_noise(uv * 1.4 + 6.0)) * grime;
	col = mix(col, vec3(0.28, 0.27, 0.25), flake * 0.75);
	// The roof: soot-dark and streaked.
	col = mix(col, vec3(0.12, 0.11, 0.1) * (0.7 + 0.5 * value_noise(uv * 2.0)), top * step(0.5, n.y) * 0.7 * grime);
	return col;
}

void fragment() {
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	vec3 eye = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	vec3 base = COLOR.rgb;
	float glow = COLOR.a;
	int finish = int(UV2.x + 0.5);
	int group = int(UV2.y + 0.5);
	float t = TIME;
	vec2 uv = surface_coords(v_model, n);
	float lit = tm_pool(v_world, n, t);
	float level = group == 1 ? lights : (group == 2 ? interior : (group == 3 ? max(emergency, interior) : 1.0));
	vec3 col;
	if (finish == 5 || glow > 0.002) {
		// A lamp or a lit panel: emissive by its group; off, a dull lens that catches the hall's lamps.
		float g = max(glow, 0.2) * glow_scale * level;
		vec3 lens = tm_lit(mix(base, vec3(0.3, 0.3, 0.3), 0.6) * 0.3, lit);
		col = mix(to_linear(lens), to_linear(base) * g, clamp(level, 0.0, 1.0));
		ALBEDO = col * light_factor(scenery_light) * scenery_tint;
	} else {
		vec3 l = normalize(light_dir);
		float lambert = ambient + (1.0 - ambient) * max(dot(n, l), 0.0);
		float facing = clamp(dot(n, eye), 0.0, 1.0);
		float graze = pow(1.0 - facing, 3.0);
		vec3 c;
		if (finish == 0) {
			c = weathered_paint(base, uv, v_model, n) * lambert * 1.45;
			c = tm_lit(c, lit);
		} else if (finish == 1) {
			// Dark glass, dirty: streaks of grime over it, the haze caught at a glance. A lit saloon glows behind it,
			// its seat backs a dark band at the foot and its poles dark bars.
			float dirt = smoothstep(0.35, 0.8, value_noise(vec2(uv.x * 7.0, uv.y * 0.6) + 5.0)) * grime;
			c = mix(base, vec3(0.16, 0.14, 0.11), dirt * 0.5) * (0.7 + 0.5 * lambert);
			c += tm_haze * (0.12 + 0.55 * graze) * 0.5;
			float shine = group == 2 ? interior : 0.0;
			float seats = smoothstep(1.36, 1.5, v_model.y) * (1.0 - smoothstep(2.35, 2.5, v_model.y));
			float poles = 1.0 - 0.85 * step(0.93, abs(fract(uv.x * 0.45) * 2.0 - 1.0));
			vec3 room = vec3(1.0, 0.86, 0.58) * (0.5 + 0.35 * value_noise(uv * 3.0)) * seats * poles;
			c = mix(c, room * 0.9, shine * (1.0 - dirt * 0.4));
			c = tm_lit(c, lit * 0.5) ;
		} else if (finish == 2) {
			// Matte trim: rubber, vents, the underframe; ribbed, grimy.
			float rib = 0.82 + 0.18 * step(0.5, fract(v_model.z * 5.0));
			c = base * rib * (0.75 + 0.5 * value_noise(uv * 4.0)) * lambert;
			c = mix(c, tm_rust * 0.5, smoothstep(0.7, 0.9, value_noise(uv * 2.5 + 1.0)) * rust_amount * 0.4);
			c = tm_lit(c, lit);
		} else if (finish == 3) {
			// Steel: dull, rusting along its length.
			float rusty = smoothstep(0.35, 0.75, value_noise(uv * 3.0 + v_model.x * 2.0)) * rust_amount;
			c = mix(base * (0.8 + 0.4 * value_noise(uv * 8.0)), tm_rust * 0.85, rusty * 0.8) * lambert;
			c += vec3(0.5) * pow(max(dot(reflect(-eye, n), l), 0.0), 24.0) * 0.12 * (1.0 - rusty);
			c = tm_lit(c, lit);
		} else if (finish == 4) {
			// Foliage: dark leaves in clumps, lighter tips, gaps.
			vec3 p3 = v_world * 6.0;
			float leaf = value_noise(p3.xy + p3.z * 0.7) * 0.6 + value_noise(p3.zy * 2.1 + p3.x) * 0.4;
			float gap = smoothstep(0.7, 0.8, value_noise(p3.xy * 1.4 + p3.z * 0.6 + 7.0) * 0.6 + value_noise(p3.zy * 3.1 + p3.x) * 0.4);
			c = base * (0.22 + 0.45 * leaf);
			c = mix(c, vec3(0.03, 0.045, 0.025), gap * 0.8);
			c = mix(c, tm_vine * 1.0, smoothstep(0.65, 0.9, leaf) * 0.4);
			c = tm_lit(c, lit);
		} else {
			// Inside the cab: pale panels, grimy, lit by its own lights (dark with them off).
			float room = max(emergency * 0.3, interior);
			float dirt = value_noise(uv * 2.2 + 3.0) * grime;
			c = base * (0.82 - 0.4 * dirt) * (0.07 + 1.25 * room) * mix(vec3(1.0), vec3(1.0, 0.86, 0.62), 0.6);
			c = min(c, vec3(0.95));
		}
		col = to_linear(c) * light_factor(scenery_light) * scenery_tint;
		ALBEDO = col;
	}
}
