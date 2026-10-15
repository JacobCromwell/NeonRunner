// Golden Zone surfaces for the solid kit shader (kit_solid.gdshader): pattern ids 50-59
// (MeshKit.PAT_GOLD ...), in their own file so other zones' patterns never collide with them.
// Included after cult_mark() (the emblems use it). Each function takes the fragment's world position
// `w`, world normal `n`, the eye vector `eye` (world, from the surface toward the camera), UV and the
// pattern parameter, and returns the albedo (sRGB, like COLOR); the kit then lights it like any lit
// surface. Nothing here glows: gold is reflective metal, never neon (GDD §5, §11), red is deep and
// unlit, and water is scenery.
// Pixel footprints are taken at the top of each pattern's function, where every pixel of a face runs
// the same code, and passed down (docs/ARCHITECTURE.md, Zone skins: the kit's shader rules); the
// emblem's texture is read with explicit mip levels (cult_mark), so it is safe in any branch.

// The skin sets every colour below as an sRGB Vector3 (GoldenSkin.srgb()), like vertex colours: a
// Color would arrive already linear on Forward+ but not on the Compatibility renderer.
// Polished gold: its highlights turn toward this pale champagne (never toward a yellow), and the
// direction of the afterglow it glints toward.
uniform vec3 golden_shine = vec3(0.97, 0.93, 0.83);
uniform vec3 golden_sun = vec3(-0.34, 0.3, -0.89);
// The walkways (PAT_WALKWAY): the polished rails along each lane's edges, the dark joint between
// neighbouring walkways, the deck's plates (metres along the track) and how polished the deck is.
uniform vec3 golden_rail = vec3(0.78, 0.66, 0.42);
uniform vec3 golden_joint = vec3(0.1, 0.085, 0.07);
uniform float golden_plate = 3.6;
uniform float golden_polish = 0.55;
// The cream marble of the walkways' medallions, and the veins in every marble.
uniform vec3 golden_inlay = vec3(0.86, 0.82, 0.72);
uniform vec3 golden_vein = vec3(0.6, 0.55, 0.48);
// The canal below (PAT_CANAL) flows toward the player at this speed (m/s): a motion cue in the gaps. The sky it
// reflects and the lamps on it, as sRGB (added to its dark colour).
uniform float golden_flow = 1.4;
uniform float golden_canal_y = -5.5;
uniform vec3 golden_canal_sky = vec3(0.06, 0.065, 0.1);
uniform vec3 golden_canal_lamp = vec3(0.07, 0.055, 0.035);
// What the quay's and the water's patterns may add, at their very brightest, is exactly these colours (every
// coefficient below is at most 1 and the results are capped at COLOR plus them): the Golden skin suite's
// contrast guard counts exactly these peaks (test_golden_skin.gd, _gaps), so a hole stays clearly darker
// than the walkways whatever glints on it.
// Falling water's foam, and the gold of trims woven or set into other patterns (banner edges, the
// coffers' rosettes, the boutique boards' lettering) and the cream of the coffers' ribs.
uniform vec3 golden_foam = vec3(0.9, 0.92, 0.92);
uniform vec3 golden_trim = vec3(0.78, 0.66, 0.42);
uniform vec3 golden_rib = vec3(0.84, 0.8, 0.72);
// The dusk's light on the Golden Zone's lit surfaces (golden_light()): the street's lamplight at the
// walkways, the floodlights at the ledges.
uniform float golden_light_street = 1.0;
uniform float golden_light_flood = 1.0;

// Reflective gold (PAT_GOLD, and the gold in every other pattern): a fake reflection of the zone at
// dusk, tinted by the metal: the street's lamplit shade below the horizon, the warm afterglow bright
// at it (broken by the towers' silhouettes), the deep blue sky above (darker, and cooling the gold), a
// glint toward the afterglow, and more of it all at grazing angles (a polished floor gleams toward
// the horizon and stays deep gold underfoot). Highlights turn toward pale champagne and shadows
// toward a greyed bronze, so only the mid tone sits near a yellow (the tonemapper saturates dark
// golds toward orange if their shadows keep the hue), and it is lit, never emissive: kept apart from
// sign yellow and gap-edge orange (test_golden_skin). `polish` 0 is satin, 1 a mirror finish.
vec3 golden_metal(vec3 base, vec3 n, vec3 eye, float polish) {
	vec3 r = reflect(-eye, n);
	float p = clamp(polish, 0.0, 1.0);
	float below = 1.0 - smoothstep(-0.07, 0.08, r.y);
	float horizon = smoothstep(-0.07, 0.08, r.y) * (1.0 - smoothstep(0.08, 0.5, r.y));
	float zenith = smoothstep(0.08, 0.6, r.y);
	// Towers against the afterglow, reflected as soft vertical bands (no atan: r may point straight up).
	float across = r.x / (abs(r.z) + 0.35);
	float towers = 1.0 - 0.35 * smoothstep(0.35, 0.9, 0.5 + 0.5 * sin(across * 5.0 + 1.3)) * horizon;
	float seen = 0.42 * below + horizon * towers + 0.5 * zenith;
	float grazing = pow(1.0 - clamp(dot(n, eye), 0.0, 1.0), 4.0);
	// Polish adds contrast around a lit mid tone rather than darkening the metal.
	float env = 0.64 + p * (seen - 0.5) * 1.1 + grazing * p * 0.3;
	vec3 grey = vec3(dot(base, vec3(0.3, 0.55, 0.15)));
	vec3 dark = mix(base, grey, 0.25) * 0.5;
	vec3 col = mix(dark, base * 1.08, clamp(env, 0.0, 1.0));
	col *= mix(vec3(1.0), vec3(0.92, 0.95, 1.05), zenith * p * 0.5);
	float glint = pow(max(dot(r, normalize(golden_sun)), 0.0), 16.0) * p;
	col = mix(col, golden_shine, clamp(glint * 0.8 + max(env - 0.95, 0.0) * 2.0, 0.0, 0.8));
	return clamp(col, 0.0, 1.0);
}

// The emblem at p (emblem space: the mark's square spans -1 to 1; `fw` a pixel's footprint there,
// taken outside branches), as the Golden Zone shows it (GDD §5): the texture's polished gold (lit as
// reflective metal) meeting at its small red centre stone, embossed as a relief lit from the upper
// left. Returns the colour and the coverage (0 where the mark isn't, or once it is too small on
// screen: cult_mark fades it out below about 24 pixels, the radiation-trefoil rule).
vec4 golden_mark(vec2 p, float fw, vec3 n, vec3 eye) {
	vec4 m = cult_mark(p, fw);
	if (m.a <= 0.001) {
		return vec4(0.0);
	}
	float d = 0.035;
	float ax = cult_mark(p + vec2(d, 0.0), fw).a;
	float ay = cult_mark(p + vec2(0.0, d), fw).a;
	float emboss = clamp(1.0 + 2.2 * (ax - ay), 0.55, 1.45);
	float stone = smoothstep(0.2, 0.32, m.r - m.g);
	vec3 gold = golden_metal(m.rgb, n, eye, 0.85) * emboss;
	vec3 gem = m.rgb * mix(0.75, 1.3, clamp(emboss - 0.55, 0.0, 1.0));
	return vec4(clamp(mix(gold, gem, stone), 0.0, 1.0), m.a);
}

// Polished marble (PAT_MARBLE): white and cream stone for cornices, pedestals, balustrades, kerbs
// and the faces of bridges: soft veins, slabs with fine joints (param 1: smaller blocks). COLOR is
// the stone; the kit adds its sheen at grazing angles.
vec3 golden_marble(vec3 base, vec3 w, vec3 n, float param) {
	vec2 p = abs(n.y) > 0.5 ? w.xz : (abs(n.x) > 0.5 ? w.zy : w.xy);
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float detail = 1.0 - smoothstep(0.02, 0.12, max(fwp.x, fwp.y));
	float warp = value_noise(p * 1.3 + 3.0);
	float v = value_noise(p * vec2(0.45, 0.8) + warp * 1.5);
	float vein = (1.0 - smoothstep(0.0, 0.045, abs(v - 0.5))) * detail;
	vec3 col = base * (0.95 + 0.07 * value_noise(p * 0.35 + 11.0));
	col = mix(col, golden_vein, vein * 0.35);
	vec2 slab = param > 0.5 ? vec2(0.9, 0.45) : vec2(1.8, 0.9);
	float joints = max(filtered_pulse(p.x / slab.x, fwp.x / slab.x, 0.0, 0.008),
		filtered_pulse(p.y / slab.y, fwp.y / slab.y, 0.0, 0.016));
	return col * (1.0 - 0.22 * joints);
}

// PAT_WALKWAY (51): a golden walkway along one lane (GDD §5: golden walkways over water): a deck of
// burnished gold plates, their seams streaming past underfoot (the still floor's own motion cue),
// polished rails along both edges and, where a neighbouring lane's walkway runs beside it, a dark
// joint between the two, so every lane reads as its own walkway. UV.x is metres across the lane from
// its left edge, UV.y metres along; param = flags (1 a joint on the left, 2 on the right, 4 a
// medallion at the piece's centre) + 8 * the lane's width in centimetres. A medallion is the cult's
// emblem shown openly (GDD §5): polished gold meeting at its red stone on a disc of cream marble in
// a gold ring, inlaid flush in the deck.
vec3 golden_walkway(vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv, float param) {
	vec2 fw = max(fwidth(uv), vec2(1e-4));
	float fz = max(fwidth(w.z), 1e-4);
	float code = floor(param + 0.5);
	float width = max(floor(code / 8.0) * 0.01, 0.5);
	float flags = mod(code, 8.0);
	float left = mod(flags, 2.0);
	float right = mod(floor(flags / 2.0), 2.0);
	float medallion = floor(flags / 4.0);
	float x = uv.x;
	float e = min(x, width - x);
	// The deck: plates of polished gold, each a slightly different tone, finished in bands across the
	// lane that catch the light in turn (a jeweller's engine-turned finish, streaming past underfoot).
	float along = -w.z / golden_plate;
	float plate = floor(along);
	float tone = 0.94 + 0.08 * hash12(vec2(plate, floor(w.x / 2.4 + 0.5) * 7.3));
	float turned = filtered_pulse(-w.z / 1.2, fz / 1.2, 0.0, 0.5);
	vec3 col = golden_metal(base * tone * (0.975 + 0.045 * turned), n, eye, golden_polish);
	float seam = filtered_pulse(along, fz / golden_plate, 0.0, 0.025 / golden_plate);
	float bevel_seam = filtered_pulse(along + 0.025 / golden_plate, fz / golden_plate, 0.0, 0.015 / golden_plate);
	col = mix(col, golden_joint, seam * 0.8);
	col = mix(col, golden_shine, bevel_seam * 0.4);
	// Polished rails along the edges, a bright bevel on their inner side.
	float rail = 1.0 - smoothstep(0.17 - fw.x, 0.17 + fw.x, e);
	float bevel = band(e, 0.145, 0.17, fw.x);
	col = mix(col, golden_metal(golden_rail, n, eye, 0.9), rail);
	col = mix(col, golden_shine, bevel * 0.45);
	// The joint to a neighbouring walkway.
	float joint = max(left * (1.0 - smoothstep(0.024 - fw.x, 0.024 + fw.x, x)),
		right * (1.0 - smoothstep(0.024 - fw.x, 0.024 + fw.x, width - x)));
	col = mix(col, golden_joint, joint);
	if (medallion > 0.5) {
		// The medallion, centred on the piece: the builder gives a medallion its own square piece, one
		// lane wide and as long (UV.y 0 to the width, running away from the player, so the emblem
		// stands upright as the runner sees it).
		vec2 c = vec2(x - width * 0.5, uv.y - width * 0.5);
		float r = width * 0.4;
		float fr = max(fw.x, fw.y);
		float dist = length(c);
		float disc = 1.0 - smoothstep(r - fr, r + fr, dist);
		float ring = band(dist, r - 0.07, r + 0.02, fr);
		vec3 stone = golden_marble(golden_inlay, w, n, 0.0);
		col = mix(col, stone, disc);
		col = mix(col, golden_metal(golden_rail, n, eye, 0.9), ring);
		float s = r * 0.78;
		vec4 mark = golden_mark(c / s, fr / s, n, eye);
		col = mix(col, mark.rgb, mark.a * disc);
	}
	return col;
}

// PAT_UNDERDECK (53): everything under the walkways, seen only through gaps and cuts (the walkways' side
// and end faces, their piers, the building faces down to the water). It stays far darker than any walkway
// (a gap reads as a hole at a glance; nothing lit or deck-like in it), but (task H3, GDD §9.9: "inside
// the cut, the player sees the zone's own scenery below the street ... the canal") it shows what is
// there, so the runner's camera, which sees little more than the first few metres of a hole's walls,
// reads a canal: the quay under the deck, a masonry wall of round arches on piers, one every 4.8 m
// (recessed and dark inside, with a dark joint around each and courses on the stone), going down to the water,
// and near the water the canal's light wavering on the stone in a net of ripples that fades out a metre
// and a half up. Steady (a slow drift, never a flash), all albedo. COLOR is the stone's brightest (the
// pattern only darkens it) and the water's light adds at most golden_canal_sky:
// the peak test_golden_skin counts. The water is at world height golden_canal_y.
vec3 golden_under(vec3 base, vec3 w, vec3 n, float t) {
	bool side = abs(n.x) > 0.5;
	float h = side ? w.z : w.x;
	float fh = max(fwidth(h), 1e-4);
	float fy = max(fwidth(w.y), 1e-4);
	float aa = max(fh, fy) * 1.5;
	// A face across a lane (a deck's end) shows one arch a lane; a long side one every two lanes.
	float period = side ? 4.8 : 2.4;
	float u = (fract(h / period) - 0.5) * period;
	vec2 c = vec2(u, w.y + 2.4);
	float r = period * 0.3;
	// The opening: a round head over straight sides, down to the water.
	float head = (1.0 - smoothstep(r - aa, r + aa, length(c))) * step(0.0, c.y);
	float legs = (1.0 - smoothstep(r - aa, r + aa, abs(u))) * step(c.y, 0.0) * step(golden_canal_y - 0.5, w.y);
	float opening = clamp(head + legs, 0.0, 1.0);
	// Its rim: a band of lighter stone just outside it, and the stone's courses.
	float rim_d = max(length(c) * step(0.0, c.y), abs(u) * step(c.y, 0.0));
	float rim = (1.0 - smoothstep(0.0, 0.1 + aa, abs(rim_d - r - 0.09))) * (1.0 - opening);
	float course = filtered_pulse(w.y / 0.4, fy / 0.4, 0.0, 0.07);
	float fascia = 1.0 - smoothstep(-0.05 - aa, 0.05 + aa, w.y + 0.85);
	float low = smoothstep(0.0, golden_canal_y, w.y);
	vec3 stone = base * (1.0 - 0.3 * course - 0.12 * rim) * mix(1.0, 0.55, low);
	// The canal's light moving on the stone: under an arch a shimmer, brighter toward the water.
	float above = w.y - golden_canal_y;
	float net = value_noise(vec2(h * 2.2 + t * 0.35, w.y * 2.6 - t * 0.25)) * 0.6
		+ value_noise(vec2(h * 5.1 - t * 0.5, w.y * 5.5 + 4.0)) * 0.4;
	float web = smoothstep(0.42, 0.8, net);
	vec3 shimmer = golden_canal_sky * (0.3 + 0.7 * web) * (0.5 + 0.5 * low);
	vec3 col = mix(stone, base * 0.18 + shimmer, opening * (1.0 - fascia));
	// And on the stone itself a metre or so up from the water.
	col += golden_canal_sky * (1.0 - smoothstep(0.1, 1.3, above)) * (0.15 + 0.85 * web) * 0.7
		* (1.0 - opening);
	return min(col, base + golden_canal_sky);
}

// PAT_CANAL (54): the canal far below the walkways, seen only through gaps and cuts: dark water
// flowing toward the player (golden_flow m/s) that reads as water, dim and never lit like the walkways
// (task H3, GDD §9.9: "inside the cut, the player sees the zone's own scenery below the street ...
// the canal in the Golden Zone"): slow ripples; the dusk's sky laid on it more the lower the eye (a
// still sheen), broken into glints that slide with the current; and the walkways' lamps wavering
// on it, warm white and faint. All of it is albedo (never emissive) and steady, so it needs nothing for
// Reduced flashing. COLOR is the water's brightest (the ripples only darken it), and the sky and the lamps
// add at most golden_canal_sky and golden_canal_lamp: the peak test_golden_skin counts.
vec3 golden_canal(vec3 base, vec3 w, vec3 eye, float t) {
	vec2 p = vec2(w.x, w.z - t * golden_flow);
	float ripple = value_noise(p * vec2(1.1, 0.3)) * 0.6 + value_noise(p * vec2(2.9, 0.9) + 7.0) * 0.4;
	vec3 col = base * (0.55 + 0.45 * ripple);
	// The sky on the water: a sheen toward the horizon, and sparse glints where a ripple faces it.
	float fres = pow(1.0 - clamp(eye.y, 0.0, 1.0), 2.0);
	float glint = smoothstep(0.7, 0.93, value_noise(p * vec2(4.6, 1.5) + 11.0));
	col += golden_canal_sky * (0.25 + 0.75 * fres) * (0.22 + 0.78 * glint) * (0.6 + 0.4 * ripple);
	// The lamps' reflections: one in some cells of a 7 m x 4.8 m grid, drifting with the current.
	vec2 cell = vec2(w.x / 4.8 + 0.5, p.y / 7.0);
	vec2 id = floor(cell);
	float here = step(0.45, hash12(id + 31.0));
	vec2 at = vec2(0.5 + 0.25 * (hash12(id + 5.0) - 0.5), 0.5);
	vec2 d = (fract(cell) - at) * vec2(1.6, 3.2);
	col += golden_canal_lamp * here * (1.0 - smoothstep(0.0, 0.55, length(d)))
		* (0.7 + 0.3 * value_noise(p * 3.0));
	return min(col, base + golden_canal_sky + golden_canal_lamp);
}

// PAT_WATER (55): falling water, scenery only (GDD §5: waterfalls and fountains off the ceilings):
// UV.x metres across the sheet, UV.y 0 at its lip to 1 at its foot. Streaks slide down, foam churns
// at the foot. COLOR is the water; pale and unlit (no hazard or "safe" hue), and nothing flashes (a
// steady slide). param 1: a thin jet (streaks only, no foam).
vec3 golden_water(vec3 base, vec2 uv, float param, float t) {
	// Long streaks, narrow across and stretched down the fall.
	float s1 = value_noise(vec2(uv.x * 9.0, uv.y * 1.2 - t * 1.7));
	float s2 = value_noise(vec2(uv.x * 23.0 + 3.0, uv.y * 2.1 - t * 2.4));
	float streak = s1 * 0.65 + s2 * 0.35;
	vec3 col = mix(base * 0.6, mix(base, golden_foam, 0.55), smoothstep(0.42, 0.72, streak));
	// Brighter where it spills over the lip, churning foam at the foot.
	col = mix(col, golden_foam, (1.0 - smoothstep(0.0, 0.1, uv.y)) * 0.45);
	float foot = param > 0.5 ? 0.0 : smoothstep(0.8, 1.0, uv.y);
	float foam = foot * (0.6 + 0.4 * value_noise(vec2(uv.x * 9.0, t * 2.5)));
	col = mix(col, golden_foam, foam * 0.8);
	return clamp(col, 0.0, 1.0);
}

// Heavy red cloth at the world position w on a face with normal n: soft vertical folds.
vec3 golden_folds(vec3 base, vec3 w, vec3 n) {
	float h = abs(n.x) > 0.5 ? w.z : w.x;
	float fold = 0.5 + 0.5 * sin(h * 6.5 + 0.8 * sin(w.y * 0.9 + h * 1.7));
	return base * (0.8 + 0.28 * fold) * (0.93 + 0.07 * value_noise(vec2(h * 3.0, w.y * 0.4)));
}

// PAT_EMBLEM (56): the cult's emblem shown openly (GDD §5: in the Golden Zone, large, in polished gold
// meeting at a small red centre stone): the material's cult_emblem texture (CultEmblem's drawing of
// the owner's choice in the skin's gold and red, GoldenSkin), embossed and lit as reflective gold, on
// COLOR's background. UV is emblem space (the mark's square spans -1 to 1; a wider range leaves a
// margin). param: the background: 0 red cloth (a banner's folds), 1 stone (a relief on marble). When
// the mark is small on screen it fades out (cult_mark), leaving the background.
vec3 golden_emblem(vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv, float param) {
	vec2 fwv = max(fwidth(uv), vec2(1e-4));
	float fw = max(fwv.x, fwv.y);
	vec3 bg = param < 0.5 ? golden_folds(base, w, n) : golden_marble(base, w, n, 0.0);
	vec4 mark = golden_mark(uv, fw, n, eye);
	return mix(bg, mark.rgb, mark.a);
}

// PAT_COFFER (57): the gilded, coffered underside of a golden bridge or archway (world xz, seen from
// below and ridden upside down): recessed gold coffers between cream ribs, on a grid 1.2 m across (so
// the seams between lanes fall on ribs at every lane count) and `param` metres along; each coffer's
// stepped frame catches the light and a small gold rosette sits at its middle. The ribs streaming
// past carry the sense of speed on the ceiling.
vec3 golden_coffer(vec3 base, vec3 w, vec3 n, vec3 eye, float param) {
	float len = max(param, 0.6);
	vec2 p = vec2(w.x / 1.2, w.z / len);
	vec2 fw = max(fwidth(p), vec2(1e-4));
	float fwm = max(fw.x * 1.2, fw.y * len);
	float rib = max(filtered_pulse(p.x + 0.07, fw.x, 0.0, 0.14), filtered_pulse(p.y + 0.07 * 1.2 / len, fw.y, 0.0,
		0.14 * 1.2 / len));
	vec2 fm = (fract(p) - 0.5) * vec2(1.2, len);
	float d = max(abs(fm.x) - 0.42, abs(fm.y) - (len * 0.5 - 0.18));
	float frame = band(d, -0.1, -0.03, fwm);
	float rosette = 1.0 - smoothstep(0.08 - fwm, 0.08 + fwm, length(fm));
	vec3 gold = golden_metal(base, n, eye, 0.55);
	vec3 col = mix(gold * 0.82, gold * 1.08, frame);
	col = mix(col, golden_metal(golden_trim, n, eye, 0.9), rosette);
	return mix(col, golden_rib, rib);
}

// PAT_CLOTH (58): heavy red cloth (banners and their like): soft folds, a gold trim along both edges
// and a gold fringe along the hem. UV.x runs 0-1 across, UV.y metres up from the hem; param = the
// cloth's width in centimetres (for the trim's width).
vec3 golden_cloth(vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv, float param) {
	vec2 fw = max(fwidth(uv), vec2(1e-4));
	float width = max(param * 0.01, 0.2);
	float t = 0.07 / width;
	float edge = min(uv.x, 1.0 - uv.x);
	vec3 col = golden_folds(base, w, n);
	float trim = 1.0 - smoothstep(t - fw.x, t + fw.x, edge);
	float hem = 1.0 - smoothstep(0.12 - fw.y, 0.12 + fw.y, uv.y);
	vec3 gold = golden_metal(golden_trim, n, eye, 0.6);
	// The fringe: gold cords hanging from the hem.
	float cords = filtered_pulse(uv.x * width / 0.06, fw.x * width / 0.06, 0.0, 0.5);
	col = mix(col, gold, max(trim, hem * mix(1.0, cords, step(uv.y, 0.07))));
	return col;
}

// PAT_BOUTIQUE (59): a luxury boutique's board, the content of a hazard sign (the yellow/black frame
// around it is the hazard; this part is only decoration, never the cult's emblem): a thin gold frame
// line along its top and bottom, then a monogram in a gold ring and a word in slim gold capitals,
// repeating along it. UV in metres on the board; param = seed (0-99) + 100 * the board's height in
// decimetres. On light boards the gold turns to a deep bronze so it still reads.
vec3 golden_boutique(vec3 base, vec2 uv, float param) {
	vec2 fw = max(fwidth(uv), vec2(1e-4));
	float code = floor(param + 0.5);
	float seed = mod(code, 100.0);
	float height = max(floor(code / 100.0) * 0.1, 0.3);
	float light = step(0.5, dot(base, vec3(0.3, 0.55, 0.15)));
	vec3 ink = mix(golden_trim, golden_trim * 0.45, light);
	float line = band(uv.y, 0.07, 0.1, fw.y) + band(uv.y, height - 0.1, height - 0.07, fw.y);
	float unit = height * 3.6;
	float k = floor(uv.x / unit);
	float ux = uv.x - k * unit;
	vec2 c = vec2(ux - height * 0.6, uv.y - height * 0.5);
	float r = height * 0.28;
	float fr = max(fw.x, fw.y);
	float ring = band(length(c), r - 0.03, r, fr);
	// The monogram: two slim letters crossing in the ring (a stem and a diagonal).
	float stem = band(c.x, -0.018, 0.018, fw.x) * step(abs(c.y), r * 0.62);
	float diag = band(c.x - c.y * (hash11(seed + k) > 0.5 ? 0.6 : -0.6), -0.016, 0.016, fr) * step(abs(c.y), r * 0.55);
	// The word: slim capitals, each a stem, a second stem or a bowl-less crossbar by hash.
	float lh = height * 0.3;
	vec2 lp = vec2((ux - height * 1.1) / (lh * 0.55), (uv.y - (height - lh) * 0.5) / lh);
	float cells = floor((unit - height * 1.35) / (lh * 0.55));
	float inside = step(0.0, lp.x) * step(lp.x, cells) * step(0.0, lp.y) * step(lp.y, 1.0);
	float g = fract(lp.x);
	float pick = hash12(vec2(floor(lp.x), k + seed * 3.1));
	float stroke = band(g, 0.18, 0.3, fw.x / (lh * 0.55));
	stroke = max(stroke, step(0.45, pick) * band(g, 0.62, 0.74, fw.x / (lh * 0.55)));
	stroke = max(stroke, step(pick, 0.3) * band(lp.y, 0.45, 0.55, fw.y / lh) * step(0.18, g) * step(g, 0.74));
	stroke = max(stroke, step(0.8, pick) * band(lp.y, 0.9, 1.0, fw.y / lh) * step(0.18, g) * step(g, 0.74));
	float word = inside * stroke;
	word = mix(word, 0.25 * inside, smoothstep(0.02, 0.08, fr / lh));
	float marks = clamp(max(max(line, ring), max(max(stem, diag), word)), 0.0, 1.0);
	return mix(base * (0.94 + 0.08 * value_noise(uv * 2.0 + seed)), ink, marks);
}

// The dusk's light on a lit surface at height y (world): the street's lamplight low down, the
// floodlights brightest around the ledges over the entablature, fading higher up.
float golden_light(float y) {
	return mix(golden_light_street, golden_light_flood, smoothstep(0.0, 9.0, y)) * mix(1.0, 0.7, smoothstep(12.0, 50.0, y));
}

// Dispatches the Golden Zone's patterns (ids 50-59) for kit_solid.gdshader. Everything under the
// walkways (PAT_UNDERDECK, PAT_CANAL) stays as dark as its colour; the rest takes the dusk's light.
vec3 golden_surface(int pattern, float param, vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv, float t) {
	vec3 c = base;
	if (pattern == 53) {
		return golden_under(base, w, n, t);
	} else if (pattern == 54) {
		return golden_canal(base, w, eye, t);
	} else if (pattern == 50) {
		c = golden_metal(base, n, eye, param);
	} else if (pattern == 51) {
		c = golden_walkway(base, w, n, eye, uv, param);
	} else if (pattern == 52) {
		c = golden_marble(base, w, n, param);
	} else if (pattern == 55) {
		c = golden_water(base, uv, param, t);
	} else if (pattern == 56) {
		c = golden_emblem(base, w, n, eye, uv, param);
	} else if (pattern == 57) {
		c = golden_coffer(base, w, n, eye, param);
	} else if (pattern == 58) {
		c = golden_cloth(base, w, n, eye, uv, param);
	} else if (pattern == 59) {
		c = golden_boutique(base, uv, param);
	}
	return c * golden_light(w.y);
}
