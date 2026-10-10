// The waterfall backdrop of Mecha Guppy and Captain Cogs' climb (MechaGuppyWaterfall; GDD §10). One wide card far
// down the track that follows the camera: a great cascade between dark basalt cliffs, its lip always well above the
// view (the climb never reaches the top), thin falls down the cliffs, spray under the lip, all hazed toward the run's
// fog colour by distance. The water's streaks come from world height plus time, so they stream past as the runner
// climbs as well as falling on their own. Unshaded and fog-free, the same on every renderer; nothing glows (every
// colour stays under the glow threshold: GDD §5's colour rule) and nothing flickers (smooth scrolling only).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

// The run's fog colour (sRGB), the haze of distance; how far it's faded in (1) or out (0).
uniform vec3 haze_color = vec3(0.86, 0.68, 0.7);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
// The card's size (metres), its lip's height over the card's middle, the main fall's half width.
uniform vec2 card_size = vec2(760.0, 520.0);
uniform float lip_height = 104.0;
uniform float fall_half_width = 150.0;
// How fast the streaks fall (m/s), and the colours (sRGB).
uniform float fall_speed = 11.0;
uniform vec3 water_deep = vec3(0.18, 0.36, 0.42);
uniform vec3 water_foam = vec3(0.86, 0.88, 0.86);
uniform vec3 water_warm = vec3(0.98, 0.78, 0.62);
uniform vec3 rock_color = vec3(0.13, 0.12, 0.13);
uniform vec3 moss_color = vec3(0.16, 0.22, 0.15);

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Metres across the card (0 at the track's line) and up from its middle.
	float x = (UV.x - 0.5) * card_size.x;
	float h = (0.5 - UV.y) * card_size.y;
	// The lip: a ragged cliff top, lower at the far sides.
	float lip = lip_height + 10.0 * value_noise(vec2(x * 0.018, 1.7)) + 4.0 * value_noise(vec2(x * 0.08, 5.3))
		- 0.00012 * x * x;
	if (h > lip) {
		discard;
	}
	// The flow's coordinate: world height plus time, wrapped (a seam every few minutes, far past any view).
	float flow = mod(world_pos.y + TIME * fall_speed, 4096.0);
	float edge = fall_half_width + 14.0 * value_noise(vec2(h * 0.02, 3.1)) + 6.0 * value_noise(vec2(h * 0.07, 9.7));
	float in_fall = 1.0 - smoothstep(edge - 6.0, edge + 6.0, abs(x));
	// Thin falls down the cliffs, here and there.
	float lane = floor(x / 46.0);
	float thin = step(0.62, hash12(vec2(lane, 4.0))) * (1.0 - smoothstep(1.2, 3.2, abs(x - (lane + 0.5) * 46.0)));
	float water = max(in_fall, thin * step(fall_half_width + 20.0, abs(x)));
	// The rock: basalt columns and ledges, moss in the cracks.
	float cols = value_noise(vec2(x * 0.35, h * 0.012));
	float ledges = value_noise(vec2(x * 0.02, h * 0.15));
	vec3 rock = rock_color * (0.75 + 0.5 * cols) * (0.85 + 0.3 * ledges);
	rock = mix(rock, moss_color, smoothstep(0.55, 0.8, value_noise(vec2(x * 0.05, h * 0.05))) * 0.6);
	// The water: falling streaks, brighter and foamier near the lip and at the fall's edges, warm where the low sun
	// catches it.
	float streak = value_noise(vec2(x * 0.6, flow * 0.05)) * 0.6 + value_noise(vec2(x * 2.1, flow * 0.11)) * 0.4;
	float foam = smoothstep(0.45, 0.95, streak);
	foam = max(foam, 1.0 - smoothstep(0.0, 26.0, lip - h));
	foam = max(foam, smoothstep(edge - 18.0, edge, abs(x)) * in_fall * 0.8);
	vec3 w = mix(water_deep, water_foam, foam);
	w = mix(w, water_warm, 0.18 * smoothstep(-0.2, 0.9, streak) * (0.4 + 0.6 * smoothstep(-120.0, lip, h)));
	vec3 col = mix(rock, w, water);
	// Spray under the lip: a soft pale band.
	float spray = (1.0 - smoothstep(0.0, 70.0, lip - h)) * 0.25 * water;
	col = mix(col, water_foam, spray);
	// The haze of distance, thicker toward the bottom (the falls' mist rising).
	float haze = 0.42 + 0.38 * smoothstep(0.0, -220.0, h);
	col = mix(col, haze_color, haze);
	ALBEDO = to_linear(min(col, vec3(0.92)));
	ALPHA = fade;
}
