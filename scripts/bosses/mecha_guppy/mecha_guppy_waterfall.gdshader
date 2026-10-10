// The waterfall of Mecha Guppy and Captain Cogs' climb (MechaGuppyWaterfall; GDD §10): a flat-topped massif far down
// the track with a great cascade in its middle, falling from its lip (lip_y, a world height) into the sea (sea_y),
// mist billowing where it lands. Everything is drawn in world height: the rock's ledges and columns, the lip, the
// mist; so as the runner climbs, the cliffs slide down past them, the falls' foot sinks below, and in the end they
// look down on the lip. Its outer flanks slope down to the sea, so the horizon stays in view beside it. The water's
// streaks scroll with time (wrapped: a seam every few minutes, far past any view). Unshaded and fog-free (its own
// haze toward the run's fog colour), the same on every renderer; nothing glows (every colour stays under the glow
// threshold: GDD §5's colour rule) and nothing flickers (smooth scrolling only: Reduced flashing has nothing to calm).
// With `plateau` on, the same massif's top: a flat card at the lip's height behind it, the river running to the lip.
// DESIGN-TBD: the backdrop's look (docs/questions/e5e.md).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

// The run's fog colour (sRGB), the haze of distance; how far it's faded in (1) or out (0).
uniform vec3 haze_color = vec3(0.86, 0.68, 0.7);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
// World heights of the falls' lip and of the sea; the massif's half width and the main fall's (metres, across the
// track from its line); 0 the cliff face, 1 the top behind the lip.
uniform float lip_y = 150.0;
uniform float sea_y = -2.0;
uniform float half_width = 280.0;
uniform float fall_half_width = 95.0;
uniform float plateau = 0.0;
// The plateau's world z where it meets the lip, and its depth back (metres).
uniform float lip_z = 0.0;
uniform float plateau_depth = 160.0;
// How fast the streaks fall (m/s), and the colours (sRGB).
uniform float fall_speed = 11.0;
uniform vec3 water_deep = vec3(0.18, 0.36, 0.42);
uniform vec3 water_foam = vec3(0.86, 0.88, 0.86);
uniform vec3 water_warm = vec3(0.98, 0.78, 0.62);
uniform vec3 rock_color = vec3(0.24, 0.2, 0.2);
uniform vec3 moss_color = vec3(0.2, 0.27, 0.18);
uniform vec3 jungle_color = vec3(0.12, 0.2, 0.13);

varying vec3 world_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec3 to_linear(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(2.2));
}

// The massif's skyline over `x` (world height): its flat top at the lip, a little ragged, sloping down to the sea over
// its outer flanks.
float skyline(float x) {
	float ax = abs(x);
	float top = lip_y + 3.0 * value_noise(vec2(x * 0.03, 1.7)) + 1.5 * value_noise(vec2(x * 0.11, 5.3));
	float flank = smoothstep(half_width, half_width - 110.0, ax);
	float slope = mix(sea_y + 6.0, top, flank * flank * (3.0 - 2.0 * flank));
	return ax < fall_half_width + 20.0 ? top : slope;
}

// The main fall's ragged edge at height `y` (half width, metres).
float fall_edge(float y) {
	return fall_half_width + 12.0 * value_noise(vec2(y * 0.02, 3.1)) + 5.0 * value_noise(vec2(y * 0.07, 9.7));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float x = world_pos.x;
	float y = world_pos.y;
	vec3 col;
	if (plateau > 0.5) {
		// The top: rock and jungle, the river running to the lip, hazier further back.
		float back = clamp((lip_z - world_pos.z) / plateau_depth, 0.0, 1.0);
		float ax = abs(x);
		if (ax > half_width - 110.0 * (1.0 - back * 0.3)) {
			discard;
		}
		float flow = mod(-world_pos.z + TIME * fall_speed * 0.6, 4096.0);
		float river_edge = fall_half_width * (1.0 - 0.45 * back) + 8.0 * value_noise(vec2(world_pos.z * 0.03, 2.0));
		float river = 1.0 - smoothstep(river_edge - 4.0, river_edge + 4.0, ax);
		float streak = value_noise(vec2(x * 0.5, flow * 0.06));
		vec3 w = mix(water_deep, water_foam, smoothstep(0.55, 0.95, streak) * 0.7);
		vec3 land = mix(rock_color, jungle_color, smoothstep(0.35, 0.7, value_noise(vec2(x * 0.04, world_pos.z * 0.04))));
		col = mix(land, w, river);
		col = mix(col, haze_color, 0.45 + 0.4 * back);
		ALBEDO = to_linear(min(col, vec3(0.92)));
		ALPHA = fade * (1.0 - smoothstep(0.85, 1.0, back));
	} else {
		float top = skyline(x);
		if (y > top || y < sea_y) {
			discard;
		}
		// The flow's coordinate: world height plus time, wrapped.
		float flow = mod(y + TIME * fall_speed, 4096.0);
		float edge = fall_edge(y);
		float in_fall = 1.0 - smoothstep(edge - 6.0, edge + 6.0, abs(x));
		// Thin falls down the cliffs, here and there.
		float lane = floor(x / 46.0);
		float thin = step(0.62, hash12(vec2(lane, 4.0))) * (1.0 - smoothstep(1.2, 3.2, abs(x - (lane + 0.5) * 46.0)));
		float water = max(in_fall, thin * step(fall_half_width + 20.0, abs(x)) * step(y, top - 4.0));
		// The rock: basalt columns and ledges at fixed heights, moss in the cracks, the low sun warm on its faces
		// toward the left and the ledges' tops.
		float cols = value_noise(vec2(x * 0.35, y * 0.012));
		float ledges = value_noise(vec2(x * 0.02, y * 0.15));
		float strata = smoothstep(0.55, 0.75, value_noise(vec2(x * 0.004, y * 0.09)));
		vec3 rock = rock_color * (0.7 + 0.55 * cols) * (0.8 + 0.4 * ledges);
		rock = mix(rock, rock * vec3(1.45, 1.2, 1.05), strata * 0.6);
		rock *= 0.9 + 0.25 * smoothstep(half_width, -half_width, x);
		rock = mix(rock, moss_color, smoothstep(0.55, 0.8, value_noise(vec2(x * 0.05, y * 0.05))) * 0.6);
		// Jungle along the top's edge.
		rock = mix(rock, jungle_color, (1.0 - smoothstep(0.0, 9.0, top - y)) * 0.8);
		// The water: falling streaks, foamier near the lip and at the fall's edges, warm where the low sun catches it.
		float streak = value_noise(vec2(x * 0.6, flow * 0.05)) * 0.6 + value_noise(vec2(x * 2.1, flow * 0.11)) * 0.4;
		float foam = smoothstep(0.45, 0.95, streak);
		foam = max(foam, 1.0 - smoothstep(0.0, 26.0, top - y));
		foam = max(foam, smoothstep(edge - 18.0, edge, abs(x)) * in_fall * 0.8);
		vec3 w = mix(water_deep, water_foam, foam);
		w = mix(w, water_warm, 0.18 * smoothstep(-0.2, 0.9, streak));
		col = mix(rock, w, water);
		// Spray under the lip, and the mist billowing up where the falls land in the sea.
		col = mix(col, water_foam, (1.0 - smoothstep(0.0, 60.0, top - y)) * 0.22 * water);
		float rise = 40.0 + 18.0 * value_noise(vec2(x * 0.02, TIME * 0.05));
		float mist = (1.0 - smoothstep(sea_y, sea_y + rise, y)) * (0.45 + 0.55 * (1.0 - smoothstep(fall_half_width,
			fall_half_width + 120.0, abs(x))));
		col = mix(col, water_foam, mist * 0.55);
		// The haze of distance, thicker in the mist and toward its foot, which dissolves into the sea's haze.
		float foot = 1.0 - smoothstep(sea_y, sea_y + 70.0, y);
		col = mix(col, haze_color, clamp(0.38 + 0.3 * mist + 0.32 * foot * foot, 0.0, 0.94));
		ALBEDO = to_linear(min(col, vec3(0.92)));
		ALPHA = fade;
	}
}
