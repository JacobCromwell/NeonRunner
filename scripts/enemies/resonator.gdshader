// The Resonator's spire, core and halos (GDD §9.10; ResonatorModel builds the meshes). One shader for
// all of it, the same on every renderer. Vertex colours carry the surface in sRGB and what it is
// (COLOR.a): 0 a lit surface (polished gold or ivory enamel: the Golden Zone's gold is reflective metal,
// never a glow); 0.5 a trim that glows red while the Resonator warns (the halos' inner rings, the
// emitter's collar); 1 its red core, which always glows (red is enemy fire, GDD §5's colour rule).
// UV carries the surface's metallic (x) and roughness (y). The Resonator drives the uniforms: its glow
// ramps up through the warning (a steady ramp with Reduced flashing, which the Resonator applies).
shader_type spatial;
render_mode cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

uniform vec3 glow_color : source_color = vec3(1.0, 0.15, 0.1);
// The warning: how brightly the trims glow (0 at rest).
uniform float glow = 0.0;
// The core's glow (1 at rest; brighter through the warning).
uniform float core = 1.0;
// A wave leaving: a short flare over everything that glows.
uniform float flash = 0.0;
// Powered down (leaving, or shot down): every glow fades out.
uniform float dim = 0.0;
uniform float emission_strength = 2.6;

void fragment() {
	vec3 base = to_linear(COLOR.rgb);
	float kind = COLOR.a;
	float is_core = step(0.75, kind);
	float is_trim = step(0.25, kind) * (1.0 - is_core);
	float e = (is_core * (core + flash) + is_trim * (glow + flash)) * (1.0 - clamp(dim, 0.0, 1.0));
	float g = clamp(e, 0.0, 1.0);
	vec3 red = to_linear(glow_color);
	ALBEDO = mix(base, red, max(g, is_core * 0.6));
	METALLIC = UV.x * (1.0 - g);
	ROUGHNESS = UV.y;
	SPECULAR = 0.5;
	EMISSION = red * e * emission_strength;
}
