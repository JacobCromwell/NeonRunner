// The zone doodads' picture cards (DoodadCards; owner's request October 9, 2026): a box's faces and the
// cards inside it, each showing part of the zone's painted atlas (tools/asset_gen/doodad_art_gen.gd),
// its open air cut out (alpha below one half is discarded, so no sorting and no blending costs).
// Unshaded with the mesh kit's fake city light (kit_solid.gdshader), so a doodad sits in the street's
// light, dims with a level's darkness (scenery_light), takes the street's light under its level's sky
// (scenery_tint), and costs the same on the Compatibility renderer (web, low-end Android) as on
// Forward+. Never emissive: a doodad is safe, lit scenery.
// Double-sided: through a stall's open middle you see the inside of its far side.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

// A level's darker lighting (ZoneSkin.apply_darkness), as on the kit's lit surfaces.
global uniform float scenery_light;
// The street's light under a level's own sky (ZoneSkin.set_scenery_tint; white = the zone's own).
global uniform vec3 scenery_tint;
// The atlas, painted in sRGB; decoded here like the kit's vertex colours (to_linear), so the pictures
// match the street on every renderer.
uniform sampler2D atlas : filter_linear_mipmap_anisotropic, repeat_disable;
// Sky glow caught at grazing angles, as on the kit's surfaces, but neutral and soft: kit_solid's
// violet default framed the dark zones' doodads in purple edges, outlining the box.
uniform vec3 sheen_color : source_color = vec3(0.32, 0.31, 0.36);
uniform float sheen_strength = 0.15;
// The zone's overall brightness for its doodads (DoodadCards; 1 = as painted).
uniform float brightness = 1.0;

void fragment() {
	vec4 t = texture(atlas, UV);
	if (t.a < 0.5) {
		discard;
	}
	// The card's side toward the camera: lit as the face it shows.
	vec3 nv = normalize(NORMAL);
	if (dot(nv, VIEW) < 0.0) {
		nv = -nv;
	}
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	float shade = 0.62 + 0.3 * max(n.y, 0.0) + 0.08 * abs(n.x) + 0.06 * n.z - 0.04 * max(-n.y, 0.0);
	float f = 1.0 - clamp(dot(nv, VIEW), 0.0, 1.0);
	vec3 sheen = to_linear(sheen_color) * (f * f * f * sheen_strength);
	ALBEDO = (to_linear(t.rgb) * shade * brightness + sheen) * light_factor(scenery_light) * scenery_tint;
}
