// The cult's feed (GDD §5, "Cyborg Viewing Devices"): the cult reaches people through their
// screens, so every zone shows the same wordless broadcast on its billboards, ads and shop-window
// TVs, in sync everywhere. Shared by every skin (scripts/world/meshes/cult_feed.gd).
// DESIGN-TBD (docs/questions/d2.md): what the feed shows. Placeholder: a beat-up CRT picture in
// cold white, like the cyborgs' screen heads (task P2), with scanlines, soft static and a slow
// rolling bar, looping through a screen-head face, the cult's emblem (CultEmblem, the owner's
// choice) and rings converging on one point ("every path leads to him"), each fading out before
// the next fades in (the emblem never shares the screen with the rings: circles around a
// three-fold mark would read like the radiation trefoil).
// Rules: it glows only in cold white and the emblem's warm white (never a hazard hue, never the
// player's copper), nothing strobes (every change is a fade of more than half a second; with
// Reduced flashing the static and the rolling bar hold still), and it never glitches purple (hosts
// only). The emblem fades out where it would span fewer than about 24 pixels.
// Include after kit_common.gdshaderinc and kit_flash.gdshaderinc.

uniform vec3 feed_color : source_color = vec3(0.86, 0.91, 1.0);
uniform vec3 feed_emblem_color : source_color = vec3(1.0, 0.93, 0.82);
uniform vec3 feed_dark : source_color = vec3(0.16, 0.18, 0.21);
// The chosen emblem's coverage in alpha (CultFeed.emblem_texture()).
uniform sampler2D feed_emblem : filter_linear_mipmap, repeat_disable;
// One loop of the broadcast, in seconds.
uniform float feed_loop = 18.0;

float cf_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Coverage of the shape with signed distance d, anti-aliased over aa.
float cf_fill(float d, float aa) {
	return 1.0 - smoothstep(-aa, aa, d);
}

// A phase of the loop between fractions a and b of it, fading in and out over f.
float cf_window(float k, float a, float b, float f) {
	return smoothstep(a, a + f, k) * (1.0 - smoothstep(b - f, b, k));
}

// Where the broadcast is at time t: the weights of the face, the emblem and the rings (one at a
// time, each fading out before the next fades in), and the loop's progress in w.
vec4 cf_phases(float t) {
	float k = fract(t / feed_loop);
	float f = 0.6 / feed_loop;
	return vec4(cf_window(k, 0.0, 0.4, f), cf_window(k, 0.41, 0.7, f), cf_window(k, 0.71, 0.99, f), k);
}

// A screen-head face, as on the cyborgs (task P2): two eyes and a mouth, calm, the eyes drifting.
float cf_face(vec2 p, float t, float aa) {
	float look = 0.04 * sin(t * 0.5);
	float eyes = min(cf_round_box(p - vec2(-0.2 + look, 0.08), vec2(0.075, 0.1), 0.035),
		cf_round_box(p - vec2(0.2 + look, 0.08), vec2(0.075, 0.1), 0.035));
	float mouth = cf_round_box(p - vec2(0.0, -0.19), vec2(0.19, 0.022), 0.022);
	return cf_fill(min(eyes, mouth), aa);
}

// The emblem's coverage at p, half_size the half width of its square; aa a pixel's footprint in p.
// The mip level comes from aa (no implicit derivatives, so it is safe anywhere), and the emblem fades
// out before it spans fewer than about 24 pixels.
float cf_emblem(vec2 p, float half_size, float aa) {
	vec2 e = p / half_size;
	float px = float(textureSize(feed_emblem, 0).x);
	float lod = log2(max(aa / half_size * 0.5 * px, 1.0));
	float inside = step(abs(e.x), 1.0) * step(abs(e.y), 1.0);
	float pixels = half_size * 2.0 / max(aa / 1.5, 1e-5);
	return textureLod(feed_emblem, vec2(e.x, -e.y) * 0.5 + 0.5, lod).a * inside * smoothstep(20.0, 30.0, pixels);
}

// Rings travelling inward to a point at the centre.
float cf_rings(vec2 p, float t, float aa) {
	float r = length(p);
	float s = r * 7.0 + t * 0.9;
	float ring = filtered_pulse(s, aa * 7.0, 0.0, 0.18) * cf_fill(r - 0.44, aa) * smoothstep(0.03, 0.1, r);
	return max(ring, cf_fill(r - 0.035, aa));
}

// The feed's picture (sRGB) at uv (0-1 across the screen, y up) on a screen `aspect` wide per unit
// of height, at time t; seed varies the static from screen to screen; fw = fwidth(uv), taken by the
// caller where every pixel runs the same code. Returns the dim screen in rgb and the picture's
// bright parts (0-1) in a, for the caller to make those glow. Everything is computed and blended,
// no branches.
vec4 cult_feed(vec2 uv, float aspect, float t, float seed, vec2 fw) {
	vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
	float aa = max(fw.x * aspect, fw.y) * 1.5 + 1e-4;
	vec4 ph = cf_phases(t);
	float face = cf_face(p, t, aa) * ph.x;
	float emblem = cf_emblem(p, 0.36 * (0.92 + 0.12 * smoothstep(0.41, 0.7, ph.w)), aa) * ph.y;
	float rings = cf_rings(p, t, aa) * ph.z;
	float bright = max(max(face, rings), emblem);
	vec3 col = mix(feed_dark, mix(feed_color, feed_emblem_color, emblem / max(bright, 1e-4)), bright);
	// Scanlines; soft static and a slow rolling bar, both still with Reduced flashing. Far away the
	// scanlines and static average out.
	col *= 1.0 - 0.3 * filtered_pulse(uv.y * 96.0, fw.y * 96.0, 0.0, 0.45);
	float tick = mod(floor(t * 12.0), 97.0) * (1.0 - reduced_flashing);
	float grain = hash12(floor(uv * vec2(aspect * 90.0, 90.0)) + vec2(tick * 7.13, seed * 3.31 + 11.0));
	col += feed_color * (grain - 0.5) * 0.1 * (1.0 - smoothstep(0.2, 0.7, max(fw.x * aspect, fw.y) * 90.0));
	float roll = fract(uv.y + t / 9.0 * (1.0 - reduced_flashing)) - 0.5;
	col *= 1.0 + 0.12 * exp(-roll * roll * 90.0);
	// A curved tube: darker toward its rounded corners, framed by the bezel's inner lip.
	vec2 q = p / vec2(aspect * 0.5, 0.5);
	col *= 1.0 - 0.3 * dot(q, q) * 0.5;
	float tube = cf_fill(cf_round_box(p, vec2(aspect * 0.5 - 0.035, 0.465), 0.07), aa);
	return vec4(mix(vec3(0.025, 0.025, 0.028), col, tube), bright * tube);
}
