// The Marketplace citizens (MarketPeople; task L7): every person in a shop window, drawn from one shared low-poly mesh
// (assets/models/market_person.res, baked from the shared HumanoidRig by tools/asset_gen/citizen_person_gen.gd) as one
// MultiMesh instance each, dressed and moved by this shader alone: the CPU's cost per frame is one uniform (u_state), and
// a second only when something cheers (u_event).
//   per instance  its transform (where it stands in its window and the way it faces: local -z is the front, scaled to its
//                 height and build), INSTANCE_CUSTOM = (look seed 0-1, sway phase 0-1, its own lateness 0-1, unused)
//   per vertex    UV2.x = colour class (0 trousers, 1 shirt, 2 skin, 3 hair, 4 shoes, 5 eyes),
//                 UV2.y = what moves it (0 the body, 1 the head, 2 the left arm, 3 the right arm)
// They stand at ease (a slow sway about the feet and a breath), their heads turning to watch the runner come (and go),
// and when something cheers (a big pickup, a big enemy's defeat) those within range of the runner hop once with both arms
// thrown up, a ripple out from the runner; a flinch (The House's duck) crouches them with their arms up. All of it is a
// slow, smooth movement: nothing flickers or flashes, so Reduced flashing needs nothing here.
// Colours: plain clothes in muted tones and skin tones, from the palettes MarketPeople passes in (never a hazard's hue),
// lit with the kit's fake light and never glowing, so they read as the shop's people and never as a window cyborg's screen
// or a warning. Unshaded on every renderer, the same on the Compatibility renderer.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

// The street's light under the level's sky, as every scenery shader (ZoneSkin.apply_darkness, set_scenery_tint).
global uniform float scenery_light;
global uniform vec3 scenery_tint;

// x the crowd's clock (s, the sum of the frames' time: it stops while the game is paused), y and z the runner's world x and z,
// w 1 when there is a runner to watch (a crowd outside any run, such as the Marketplace intro's street, faces forward).
uniform vec4 u_state = vec4(0.0);
// What is happening: x the clock when it began (a long time ago: nothing), y the runner's world z when it began, z its kind
// (0 a cheer, 1 a flinch). The one before it is kept too (u_event_prev), so a reaction begun while another is under way adds
// to it as it eases in from nothing, and the one it follows eases out: nothing snaps.
uniform vec4 u_event = vec4(-1000.0, 0.0, 0.0, 0.0);
uniform vec4 u_event_prev = vec4(-1000.0, 0.0, 0.0, 0.0);
// A cheer: x its length (s), y the hop's height (m), z how far ahead of the runner it reaches (m), w how far behind.
uniform vec4 u_cheer = vec4(0.9, 0.28, 48.0, 12.0);
// x the ripple (s a metre), y the lateness a person has of their own (s), z the distance the heads turn fully within (m),
// w the distance they begin to turn from (m).
uniform vec4 u_motion = vec4(0.012, 0.18, 16.0, 52.0);
// x how far round a head turns (radians), y the sway (radians), z a flinch's length (s).
uniform vec4 u_limits = vec4(1.25, 0.024, 0.8, 0.0);
// Where the head turns about, and each shoulder, in the mesh's own space (the mesh's meta: MarketPeople).
uniform vec3 u_neck = vec3(0.0, 1.11, 0.0);
uniform vec3 u_shoulder_l = vec3(-0.165, 1.015, 0.0);
uniform vec3 u_shoulder_r = vec3(0.165, 1.015, 0.0);
// The palettes (sRGB, as authored; MarketPeople.SKINS and the others, the arrays' sizes pinned by its test).
uniform vec4 skins[6];
uniform vec4 hairs[5];
uniform vec4 shirts[8];
uniform vec4 pants[6];
uniform vec4 shoes[3];

varying flat float v_class;
varying flat float v_seed;

// MarketPeople.posed() and MarketPeople.reaction() are GDScript mirrors of what follows (a test keeps the constants the same
// and checks the arm roots stay on the body through a cheer and a flinch): change them together.
const float ARMS_CHEER = 2.65;
const float ARMS_FLINCH = 2.35;
const float CROUCH = 0.26;
const float TIP = 0.25;

vec2 rot(vec2 d, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(d.x * c - d.y * s, d.x * s + d.y * c);
}

// How far through reaction `ev` the person standing at world z `z` is, as (arms thrown up 0-1 in a cheer, hop 0-1, flinch
// 0-1): k runs 0 to 1 over it, later the farther the person is from where the runner was, and later by their own lateness
// `late`; only those within the cheer's reach of that place take part. Every amount is 0 at k = 0 and k = 1.
vec3 reaction(vec4 ev, float z, float late, float t) {
	float dz = z - ev.y;
	float in_reach = step(-u_cheer.z, dz) * step(dz, u_cheer.w);
	float is_flinch = step(0.5, ev.z);
	float k = (t - ev.x - abs(dz) * u_motion.x - late * u_motion.y) / mix(u_cheer.x, u_limits.z, is_flinch);
	float on = in_reach * step(0.0, k) * step(k, 1.0);
	float arms_up = smoothstep(0.0, 0.22, k) * (1.0 - smoothstep(0.72, 1.0, k));
	float hk = clamp((k - 0.08) / 0.72, 0.0, 1.0);
	float bump = sin(3.14159 * clamp(k, 0.0, 1.0));
	return on * vec3(arms_up * (1.0 - is_flinch), 4.0 * hk * (1.0 - hk) * (1.0 - is_flinch), bump * is_flinch);
}

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	v_class = floor(UV2.x + 0.5);
	v_seed = cd.x;
	float moves = floor(UV2.y + 0.5);
	vec3 p = VERTEX;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float height_scale = length(MODEL_MATRIX[1].xyz);
	float t = u_state.x;
	float phase = cd.y * 6.2832;

	// A cheer or a flinch under way (two at most, added).
	vec3 r = min(reaction(u_event, origin.z, cd.z, t) + reaction(u_event_prev, origin.z, cd.z, t), vec3(1.0));
	float flinch = r.z;
	float arms = min(r.x * ARMS_CHEER + flinch * ARMS_FLINCH, ARMS_CHEER);

	// The head and the arms turn about their pivots at the person's own size, standing straight...
	if (moves > 0.5 && moves < 1.5) {
		// The head turns about the neck toward the runner: the angle to them from straight ahead of this person's body
		// (local -z), held to what a neck can do, and less the farther they are.
		vec3 to = vec3(u_state.y - origin.x, 0.0, u_state.z - origin.z);
		float lx = dot(to, normalize(MODEL_MATRIX[0].xyz));
		float lz = dot(to, normalize(MODEL_MATRIX[2].xyz));
		float follow = u_state.w * (1.0 - smoothstep(u_motion.z, u_motion.w, length(to)));
		float turn = -clamp(atan(lx, -lz), -u_limits.x, u_limits.x) * follow;
		vec3 d = p - u_neck;
		d.xz = vec2(d.x * cos(turn) + d.z * sin(turn), -d.x * sin(turn) + d.z * cos(turn));
		d.yz = rot(d.yz, flinch * TIP);
		p = u_neck + d;
	} else if (moves > 1.5) {
		// An arm swings about its shoulder, up and out: thrown up in a cheer, up over the head in a flinch.
		bool right = moves > 2.5;
		vec3 sh = right ? u_shoulder_r : u_shoulder_l;
		vec3 d = p - sh;
		d.xy = rot(d.xy, arms * (right ? 1.0 : -1.0));
		p = sh + d;
	}
	// ...then the whole body: a breath, the crouch of a flinch (about the feet, so the arms' roots go down with the
	// shoulders they hang from), a slow sway about the feet, and the hop.
	p.y *= (1.0 + 0.004 * sin(t * 1.9 + phase * 1.3)) * (1.0 - CROUCH * flinch);
	p.x += p.y * u_limits.y * sin(t * 0.7 + phase);
	p.y += r.y * u_cheer.y / height_scale;
	VERTEX = p;
}

void fragment() {
	int cls = int(v_class + 0.5);
	float s = v_seed;
	vec3 col;
	if (cls == 0) {
		col = pants[int(hash11(s * 41.0 + 3.0) * 6.0)].rgb;
	} else if (cls == 1) {
		col = shirts[int(hash11(s * 29.0 + 1.0) * 8.0)].rgb;
	} else if (cls == 2) {
		col = skins[int(hash11(s * 17.0 + 7.0) * 6.0)].rgb;
	} else if (cls == 3) {
		col = hairs[int(hash11(s * 53.0 + 5.0) * 5.0)].rgb;
	} else if (cls == 4) {
		col = shoes[int(hash11(s * 61.0 + 2.0) * 3.0)].rgb;
	} else {
		col = vec3(0.07, 0.07, 0.09);
	}
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	// The kit's fake light: lighter on top and toward the street's far end (where the camera is), as the facades are.
	float shade = 0.78 + 0.25 * max(n.y, 0.0) + 0.08 * abs(n.x) + 0.06 * n.z;
	ALBEDO = to_linear(col) * shade * light_factor(scenery_light) * scenery_tint;
}
