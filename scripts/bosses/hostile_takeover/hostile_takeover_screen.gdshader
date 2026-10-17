// Hostile Takeover's merger screens (GDD §10: "'MERGER COMPLETE' flashes on every screen"; the player gets a
// glimpse of the Chairman "as the face on the 'MERGER COMPLETE' screens"): the Chairman's face
// (chairman_face.gdshaderinc, the one face of him) as a corporate broadcast, on a deep brand-blue ground
// with faint scanlines and a cold-white frame; a dark band across the top (or the bottom: band_top off)
// carries the words (a TextMesh in front: HostileTakeoverScreens). `power` (0-1) switches it on; `glitch` (0-1) tears it sideways in
// bands (the defeat), still with Reduced flashing (kit_flash: reduced_flashing), where it only dims. No
// hazard's colour anywhere: the cult's screens' cold white and the brand's blues.
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
#include "res://scripts/bosses/hostile_takeover/chairman_face.gdshaderinc"

uniform float power = 0.0;
uniform float glitch = 0.0;
// The quad's width over its height.
uniform float aspect = 1.78;
uniform float brightness = 1.6;
// The band for the words: this share of the height, along the top edge (band_top 1) or the bottom (0).
uniform float band = 0.24;
uniform float band_top = 1.0;

const vec3 GROUND_TOP = vec3(0.05, 0.1, 0.32);
const vec3 GROUND_LOW = vec3(0.015, 0.03, 0.11);
const vec3 FRAME = vec3(0.82, 0.88, 1.0);
const vec3 BAND = vec3(0.01, 0.015, 0.05);

vec3 face(vec2 p) {
	// p: the screen's middle at the origin, y up, a unit the screen's height.
	vec3 col = mix(GROUND_LOW, GROUND_TOP, smoothstep(-0.5, 0.5, p.y));
	// A soft glow behind the head.
	col += vec3(0.05, 0.08, 0.2) * (1.0 - smoothstep(0.0, 0.45, length(p - vec2(0.0, 0.08))));
	return chairman_face(p, col, FRAME);
}

void fragment() {
	if (power <= 0.001) {
		ALBEDO = vec3(0.01, 0.012, 0.02);
	} else {
		vec2 uv = UV;
		// The defeat's glitch: bands torn sideways (held still with Reduced flashing).
		float row = floor(uv.y * 14.0);
		float tick = floor(TIME * 9.0);
		float jitter = fract(sin(row * 12.9898 + tick * 78.233) * 43758.5453) - 0.5;
		uv.x += jitter * glitch * 0.18 * (1.0 - reduced_flashing);
		vec2 p = vec2((uv.x - 0.5) * aspect, 0.5 - uv.y);
		// The face sits beside the words' band.
		float side = band_top > 0.5 ? -1.0 : 1.0;
		vec2 fp = (p - vec2(0.0, side * band * 0.5)) / (1.0 - band);
		vec3 col = face(fp);
		// Faint scanlines.
		col *= 0.92 + 0.08 * sin(uv.y * 240.0);
		// The band for the words.
		col = mix(col, BAND, band_top > 0.5 ? step(uv.y, band) : step(1.0 - band, uv.y));
		// The frame.
		float inset = 0.02;
		float frame = sd_box(p, vec2(aspect * 0.5 - inset, 0.5 - inset));
		col = mix(col, FRAME, (1.0 - smoothstep(0.0, 0.006, abs(frame) - 0.004)));
		col *= brightness * clamp(power, 0.0, 1.0) * (1.0 - 0.6 * glitch * reduced_flashing);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		// No HDR there: keep the hues instead of clipping them to white.
		col /= max(1.0, max(col.r, max(col.g, col.b)));
#endif
		ALBEDO = col;
	}
}
