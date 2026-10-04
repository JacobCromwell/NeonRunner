// The Sewer Swarm's crowds (GDD §10: clusters "rendered as many screech-variant creatures using MultiMesh
// plus a shader for per-creature motion"; SwarmCrowd). One MultiMesh of the sewer screech's crowd mesh
// (ScreechModel.crowd_mesh: its parts, colours and part ids) per crowd; every creature is placed and
// animated here, so nothing per creature runs on the CPU. Its instance transforms are the identity (a
// cluster's or a band's creatures are placed from the uniforms) or a lair's place (a spill's).
// Per creature, INSTANCE_CUSTOM = (u, v, w, rank): three random numbers in [0, 1) placing it in its
// formation, and its rank (evenly spread over [0, 1)): creatures leave the mound for the lane in rank order,
// and a thinned cluster loses its highest ranks first.
// Kinds of crowd (`kind`):
//   0 a cluster: piled against a wall at the roadside (its mound, rearing while it gathers), or risen behind
//     the runner as a wave curling over their lane (a strike from behind, `form_from` 1, `wave`), pouring out
//     into a lane (`pour`), charging down it as a lane-wide mass (toward the runner, or along the lane past
//     them: `mass_dir`), then shocked on a fence, falling into a hole or scattering (`life`.z); thinned by
//     weapons (`life`.x) and rising as it forms (`life`.y);
//   1 a roadside band: the horde in a gutter, from `band`.y ahead to `band`.z behind, drifting back;
//   2 a spill: screeches pouring out of a lair as it bursts (INSTANCE_CUSTOM = (burst clock, side, w, rank));
//   3 a climb: the swarm covering a wall (`climb`), rising up it and sinking back (`climb_shape`.z), parting
//     over a stretch of it (`climb_hole`);
//   4 the Host's bulk: screeches latched over it (`host_shape`), standing, rearing, charging or crouched long
//     and low (`host`), knocked off a share at each hit (`life`.x), scattering when it's freed (`life`.z).
// A cluster flung by the Host is a ball (`form_from` 2, `ball`) until it splats into a short mass.
// The look is the screech's (its vertex colours: skin, belly, the red-orange spine tips and the yellow
// eyes glowing), weathered for the zone (`grime`), its skin lifted toward a sickly pale (`skin_lift`: the
// screech's dark olive on Gangland's dark asphalt would vanish in a crowd). Its colours are authored in
// sRGB, so they're taken to linear light on Forward+ and Mobile (to_linear), and the crowd looks the same on
// every renderer. A massed crowd glows less per creature than a lone screech (emission_strength). Only an
// attack heats it to enemy-attack red (motion.z, bristle: a cluster's surge, from its warning on): its spines
// and eyes burn red and its silhouette glows red, so the cluster coming down a lane stands out from the
// horde at the roadside, whose spines only smoulder. Screeches on a wall (a mound's clinging ones, a climb)
// never glow red, harmful as they are (owner's request, docs/USER_REQUESTS.md): a mound's raise their spines
// as it gathers but keep their own colours until they leave the wall. Nothing here flashes: a shock's
// crackle is a steady glow with Reduced flashing. On the Compatibility renderer (no tonemapping) an
// over-bright glow is scaled down whole, so the spines' red-orange never clips toward yellow.
shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

uniform int kind = 0;
// Zone weathering: 0 = city (dark and slick), 1 = scavenger zones (grimier, more diseased).
uniform float grime = 1.0;
uniform float emission_strength = 2.0;
// How far the skin is lifted toward skin_pale (0: the screech's own).
uniform float skin_lift = 0.45;
uniform vec4 skin_pale : source_color = vec4(0.5, 0.47, 0.36, 1.0);
uniform float creature_scale = 0.62;
// The fight's clock (seconds): a spill's creatures come out by it.
uniform float clock = 0.0;

// A cluster. mound: x = its wall's x (the side times the wall's distance), y = its middle's z, z = its side
// (-1 left, +1 right). mound_shape: length, depth out from the wall, climb up the wall.
uniform vec4 mound = vec4(-4.0, 0.0, -1.0, 0.0);
uniform vec4 mound_shape = vec4(4.6, 0.9, 1.7, 0.0);
// mass: x = its lane's x, y = its front's z, z = its length, w = its width; mass_height: its pile's height;
// mass_dir: 1 charging toward +z (at the runner, from ahead), -1 toward -z (along the lane, from behind).
uniform vec4 mass = vec4(0.0, 0.0, 5.2, 2.0);
uniform float mass_height = 0.95;
uniform float mass_dir = 1.0;
// What a cluster pours into its lane from: 0 its mound, 1 its wave (a strike from behind).
uniform int form_from = 0;
// A wave: x = its lane's x, y = its foot's z, z = how far it has risen (0-1); wave_shape: its height, how far
// its crest curls forward (toward -z) and its width.
uniform vec4 wave = vec4(0.0);
uniform vec4 wave_shape = vec4(6.75, 11.0, 2.3, 0.0);
// A climb: x = its wall's x (signed), y = metres ahead, z = metres behind, w = drift back (m/s); climb_shape:
// x = its height, y = its side, z = how far it has risen (0-1).
uniform vec4 climb = vec4(-4.0, 50.0, 12.0, 3.0);
uniform vec4 climb_shape = vec4(4.8, -1.0, 0.0, 0.0);
// A climb's hole (a phase 3 ramp's way up): from local z x to y its screeches part, z of the way (0-1), thinning
// back to full cover over w metres at its ends.
uniform vec4 climb_hole = vec4(0.0, 0.0, 0.0, 1.0);
// The Host: host_shape = its bulk's width, height and depth (crouched: its crouch's length) and an attack's
// heat (0-1: only while it attacks, never as it drops, leaps or crouches); host = crouched, rearing, charging
// (each 0-1) and a shock's glow (0-1). +z faces the runner.
uniform vec4 host_shape = vec4(2.8, 4.0, 2.4, 0.0);
uniform vec4 host = vec4(0.0);
// A flung cluster's ball: its radius (metres).
uniform float ball = 1.1;
// motion: x = pour (0 all in the mound .. 1 all in the lane), y = rear (gathering), z = bristle (spines up
// and glowing: an attack's warning), w = charge (0 still .. 1 charging).
uniform vec4 motion = vec4(0.0);
// life: x = alive (the share weapons left), y = formed (the share risen so far), z = death (0 none,
// 1 shocked, 2 falling, 3 scattering), w = seconds since it died.
uniform vec4 life = vec4(1.0, 1.0, 0.0, 0.0);
// death_at: x = the charge's speed (m/s) when it died.
uniform vec4 death_at = vec4(0.0);
// A band. band: x = its wall's x (signed), y = metres ahead, z = metres behind, w = drift back (m/s).
// band_shape: x = depth out from the wall, y = climb, z = its side, w = the spacing of its heaps (metres).
uniform vec4 band = vec4(-4.0, 110.0, 14.0, 2.5);
uniform vec4 band_shape = vec4(0.8, 0.75, -1.0, 7.0);
// A shocked creature's glow: the fence's pink, burnt white.
uniform vec4 shock_color : source_color = vec4(1.0, 0.62, 0.86, 1.0);
// An attack's heat: enemy-attack red (BossProps.WARNING_COLOR), and how bright its silhouette glows.
uniform vec4 attack_color : source_color = vec4(1.0, 0.12, 0.08, 1.0);
uniform float heat_energy = 1.6;

varying float v_bristle;
varying float v_lesion;
varying float v_shock;

float rnd(float rank, float k) {
	return fract(sin(rank * 127.1 + k * 311.7) * 43758.5453);
}

// An orthonormal frame for a creature facing `fwd` with its back toward `up` (the mesh faces -Z).
mat3 frame(vec3 fwd, vec3 up) {
	vec3 z = -normalize(fwd);
	vec3 x = cross(up, z);
	x = length(x) < 0.001 ? vec3(1.0, 0.0, 0.0) : normalize(x);
	vec3 y = cross(z, x);
	return mat3(x, y, z);
}

// Turns `v` about `axis` (unit) by `a` radians.
vec3 turn(vec3 v, vec3 axis, float a) {
	float c = cos(a);
	float s = sin(a);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

// A cluster's creature in its mound: heaped in the gutter against the wall, or clinging to it, climbing.
vec3 mound_slot(vec4 c, out vec3 fwd, out vec3 up) {
	float side = mound.z;
	float a = c.x - 0.5;
	float ridge = 1.0 - 4.0 * a * a;
	float t = TIME * 0.9 + c.w * 37.0;
	float z = mound.y + a * mound_shape.x;
	if (c.z < 0.55) {
		float k = c.z / 0.55;
		float out_dist = 0.1 + c.y * mound_shape.y * (0.35 + 0.65 * ridge);
		float y = k * 0.5 * ridge * (1.0 - 0.6 * c.y);
		float yaw = rnd(c.w, 1.0) * 6.2832 + sin(t * 0.7) * 0.7;
		fwd = vec3(sin(yaw), 0.6 * motion.y, -cos(yaw));
		up = vec3(0.0, 1.0, 0.0);
		return vec3(mound.x - side * out_dist + sin(t * 1.3) * 0.05, y, z + sin(t) * 0.16);
	}
	float k = (c.z - 0.55) / 0.45;
	float h = 0.18 + k * mound_shape.z * (0.3 + 0.7 * ridge);
	float lean = (rnd(c.w, 2.0) - 0.5) * 1.4 + sin(t * 0.8) * 0.3;
	fwd = vec3(0.0, cos(lean), sin(lean));
	up = vec3(-side, 0.0, 0.0);
	return vec3(mound.x - side * (0.07 + 0.05 * motion.y), h + sin(t * 1.3) * 0.07, z + cos(t) * 0.1);
}

// A cluster's creature in its lane: a mass heaped in the middle, its front the way it charges (+z toward the
// runner, mass_dir 1; -z along the lane, -1).
vec3 mass_slot(vec4 c, out vec3 fwd, out vec3 up) {
	float along = c.x;
	float across = c.y * 2.0 - 1.0;
	float taper = 0.55 + 0.45 * sin(3.1416 * clamp(along * 0.85 + 0.12, 0.0, 1.0));
	float t = TIME * 6.0 + c.w * 53.0;
	float x = mass.x + across * mass.w * 0.5 * taper + sin(t * 0.7) * 0.06;
	float z = mass.y - mass_dir * along * mass.z + sin(t) * 0.18 * motion.w;
	float hmax = mass_height * (1.0 - across * across) * (1.0 - 0.5 * along);
	float y = c.z * hmax + abs(sin(t * 1.7)) * 0.07 * motion.w;
	fwd = vec3((rnd(c.w, 3.0) - 0.5) * 0.7, (rnd(c.w, 4.0) - 0.5) * 0.3 - 0.2 * c.z, mass_dir);
	up = vec3(0.0, 1.0, 0.0);
	return vec3(x, y, z);
}

// A cluster's creature in its wave (a strike from behind): a sheet of screeches rising from its foot behind
// the runner, over their lane and curling forward and down like a breaking wave or a scorpion's stinger,
// tapering to its tip; it grows as it rises (wave.z). Its spine is a cubic curve in (z, y).
vec3 wave_slot(vec4 c, out vec3 fwd, out vec3 up) {
	float grow = smoothstep(0.0, 1.0, clamp(wave.z, 0.0, 1.0));
	float height = wave_shape.x * (0.25 + 0.75 * grow);
	float reach = wave_shape.y * (0.15 + 0.85 * grow);
	float sway = sin(TIME * 2.3) * 0.3 * grow;
	vec2 p0 = vec2(0.0, 0.0);
	vec2 p1 = vec2(0.7, height * 0.78);
	vec2 p2 = vec2(-reach * 0.32, height * 1.2);
	vec2 p3 = vec2(-reach, height * 0.58 + sway);
	float u = pow(c.x, 0.85);
	float a = 1.0 - u;
	vec2 sp = a * a * a * p0 + 3.0 * a * a * u * p1 + 3.0 * a * u * u * p2 + u * u * u * p3;
	vec2 tg = normalize(3.0 * a * a * (p1 - p0) + 6.0 * a * u * (p2 - p1) + 3.0 * u * u * (p3 - p2) + vec2(0.0001, 0.0));
	// Its outside (behind the foot, above the crest, ahead of the curled tip).
	vec2 nrm = vec2(tg.y, -tg.x);
	float across = (c.y - 0.5) * wave_shape.z * (1.0 - 0.7 * u);
	float thick = (c.z - 0.5) * 1.15 * (1.0 - 0.55 * u);
	float t = TIME * 1.9 + c.w * 23.0;
	fwd = normalize(vec3((rnd(c.w, 30.0) - 0.5) * 0.6, tg.y, tg.x));
	up = vec3(0.0, nrm.y, nrm.x);
	return vec3(wave.x + across + sin(t) * 0.07, sp.y + nrm.y * thick + sin(t * 1.3) * 0.07,
		wave.y + sp.x + nrm.x * thick + cos(t) * 0.1);
}

// A flung cluster's creature: balled up around the node, tumbling.
vec3 ball_slot(vec4 c, out vec3 fwd, out vec3 up) {
	float theta = c.x * 6.2832;
	float phi = acos(1.0 - 2.0 * c.y);
	vec3 n = vec3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta));
	n = turn(n, normalize(vec3(1.0, 0.25, 0.1)), TIME * 4.5);
	float r = ball * (0.45 + 0.55 * pow(c.z, 0.33));
	fwd = normalize(cross(n, vec3(0.0, 1.0, 0.0)) + vec3(0.0001, 0.0, 0.0));
	up = n;
	return n * r;
}

// Where a cluster's creature starts from as it pours into its lane: its mound, its wave or a flung ball.
vec3 start_slot(vec4 c, out vec3 fwd, out vec3 up) {
	if (form_from == 1) {
		return wave_slot(c, fwd, up);
	}
	if (form_from == 2) {
		return ball_slot(c, fwd, up);
	}
	return mound_slot(c, fwd, up);
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	vec3 fwd = vec3(0.0, 0.0, -1.0);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 pos = vec3(0.0);
	float s = creature_scale * (0.8 + 0.4 * rnd(c.w, 5.0));
	float scurry = 1.0;
	float bristle = 0.25;
	// How hot it glows (bristle's scale): wall creatures never glow attack red (their spines still rise).
	float heat_bristle = -1.0;
	v_shock = 0.0;
	if (kind == 1) {
		// The roadside horde: running with the runner, drifting back past them (wrapping out of sight). Most of
		// it is gathered in heaps every band_shape.w metres, drifting with it, piled higher up the wall.
		float span = band.y + band.z;
		float base = c.x * span;
		float heap = max(band_shape.w, 1.0);
		float centre = (floor(base / heap) + 0.5) * heap + (rnd(c.w, 21.0) - 0.5) * heap * 0.35;
		float in_heap = step(0.35, rnd(c.w, 20.0));
		float z = -band.y + mod(mix(base, centre, in_heap * 0.75) + band.w * TIME, span);
		float side = band_shape.z;
		float t = TIME * 1.1 + c.w * 29.0;
		if (c.z < 0.62 || band_shape.y <= 0.0) {
			// With no climb (Gangland's: a swarm on the wall would hurt) they're all heaped in the gutter.
			float k = band_shape.y > 0.0 ? c.z : c.z * 0.62;
			pos = vec3(band.x - side * (0.08 + c.y * band_shape.x), k * (0.3 + 0.45 * in_heap), z + sin(t) * 0.2);
			fwd = vec3((rnd(c.w, 6.0) - 0.5) * 0.8, 0.0, -1.0);
		} else {
			float h = 0.14 + (c.z - 0.62) / 0.38 * band_shape.y * (1.0 + 0.8 * in_heap);
			pos = vec3(band.x - side * 0.07, h, z + sin(t) * 0.2);
			fwd = vec3(0.0, 0.5, -1.0);
			up = vec3(-side, 0.3, 0.0);
		}
		float show = 1.0 - smoothstep(life.y * 1.05 - 0.04, life.y * 1.05, c.w);
		pos.y -= (1.0 - show) * 0.4;
		s *= show * (1.0 - smoothstep(life.x * 1.05 - 0.04, life.x * 1.05, c.w));
	} else if (kind == 2) {
		// A lair's spill: out of the hole one after another, up and over toward the wall's foot, then into the
		// horde (shrinking away).
		float side = c.y;
		float age = clock - c.x - c.w * 0.9;
		float k = clamp(age / 1.3, 0.0, 1.0);
		float hop = sin(3.1416 * clamp(age / 0.45, 0.0, 1.0));
		pos = vec3(side * (0.1 + 0.7 * smoothstep(0.15, 0.8, k)), 0.08 + hop * 0.35 - (1.0 - smoothstep(0.0, 0.25, age)) * 0.35,
			-(rnd(c.w, 7.0) - 0.25) * 3.0 * k);
		fwd = vec3(side * 0.8, 0.4 * hop, -0.6 - rnd(c.w, 8.0));
		s *= step(0.0, age) * (1.0 - smoothstep(1.2, 1.6, age));
	} else if (kind == 3) {
		// A climb: screeches covering the wall from climb.y ahead to climb.z behind, up to climb_shape.x high,
		// streaming back past the runner; rising, the high ones arrive last, and sinking they drop away.
		float span = climb.y + climb.z;
		float t = TIME * 2.3 + c.w * 31.0;
		float z = -climb.y + mod(c.x * span + climb.w * TIME, span) + sin(t * 0.7) * 0.25;
		float side = climb_shape.y;
		// In a hole (SwarmClimb's route) they sink away as if the climb fell back there, its edges thinned.
		float out_of_hole = max(max(climb_hole.x - z, z - climb_hole.y), 0.0);
		float in_hole = 1.0 - smoothstep(0.0, max(climb_hole.w, 0.001), out_of_hole);
		float rise = clamp(climb_shape.z, 0.0, 1.0) * (1.0 - clamp(climb_hole.z, 0.0, 1.0) * in_hole);
		float h = 0.12 + c.z * climb_shape.x * (0.25 + 0.75 * rise);
		pos = vec3(climb.x - side * (0.05 + 0.14 * c.y), h + sin(t) * 0.06, z);
		fwd = vec3(0.0, 0.85, -0.5 + (rnd(c.w, 40.0) - 0.5) * 0.9);
		up = vec3(-side, 0.0, 0.0);
		scurry = 1.0;
		s *= smoothstep(0.0, 0.12, rise) * (1.0 - smoothstep(rise * 1.04, rise * 1.04 + 0.06, c.z));
	} else if (kind == 4) {
		// The Host's bulk: screeches latched over an ellipsoid standing (host_shape) or crouched long and low,
		// its top leaning back as it rears and forward as it charges, crawling over it.
		vec3 r = host_shape.xyz * 0.5;
		float theta = c.x * 6.2832;
		float phi = acos(1.0 - 2.0 * c.y * 0.86);
		vec3 n = vec3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta));
		float bump = 1.0 + 0.1 * sin(theta * 3.0 + c.w * 7.0) * sin(phi * 4.0);
		float t = TIME * 3.1 + c.w * 37.0;
		vec3 p = vec3(0.0, r.y, 0.0) + n * r * bump * (0.84 + 0.16 * c.z);
		float top = max(n.y, 0.0);
		p += vec3(0.0, host.y * 0.45 * top, (host.z * 0.7 - host.y * 0.5) * top);
		pos = p + n * sin(t) * 0.06;
		fwd = normalize(cross(vec3(0.0, 1.0, 0.0), n) + vec3(0.0, 0.3 * sin(t * 0.5), 0.0001));
		up = n;
		// It heats only while it attacks (a fling's wind-up, a lunge's warning and charge).
		bristle = 0.25 + 0.75 * host_shape.w;
		scurry = 0.6 + 0.4 * host.z;
		// Knocked off: its highest ranks go first.
		s *= 1.0 - smoothstep(life.x * 1.03 - 0.025, life.x * 1.03 + 0.005, c.w);
		if (life.z > 0.5) {
			// Freed: they leap off it and scatter.
			float dt = life.w - rnd(c.w, 41.0) * 0.4;
			if (dt > 0.0) {
				vec3 away = normalize(vec3(n.x, 0.0, n.z) + vec3(0.0001, 0.0, 0.0));
				pos += away * (3.0 + 3.0 * rnd(c.w, 42.0)) * dt + vec3(0.0, 2.5 * dt - 6.0 * dt * dt, 0.0);
				pos.y = max(pos.y, 0.05);
				fwd = vec3(away.x, 0.0, away.z);
				up = vec3(0.0, 1.0, 0.0);
				s *= 1.0 - smoothstep(0.5, 1.2, dt);
			}
			bristle = 0.25;
		}
		// A shock (baited into a fence): burning pink, crackling (steady with Reduced flashing).
		v_shock = host.w * warning_flicker(step(0.5, fract(TIME * 13.0 + rnd(c.w, 43.0))), 0.35);
	} else {
		// A cluster: its mound (or its wave), the pour, its mass.
		vec3 f0;
		vec3 u0;
		vec3 f1;
		vec3 u1;
		float p = clamp((motion.x - c.w * 0.5) / 0.5, 0.0, 1.0);
		float ps = smoothstep(0.0, 1.0, p);
		if (motion.x <= 0.0) {
			pos = start_slot(c, fwd, up);
			scurry = form_from == 1 ? 1.0 : 0.3 + 0.7 * motion.y;
		} else if (motion.x >= 1.0) {
			pos = mass_slot(c, fwd, up);
			scurry = 0.4 + 0.6 * motion.w;
		} else {
			vec3 a = start_slot(c, f0, u0);
			vec3 b = mass_slot(c, f1, u1);
			pos = mix(a, b, ps) + vec3(0.0, sin(3.1416 * p) * 0.55, 0.0);
			fwd = p <= 0.0 ? f0 : (p >= 1.0 ? f1 : normalize(b - a + vec3(0.0, 0.4, 0.0)) + f1 * 0.2);
			up = (p > 0.0 && p < 1.0) ? vec3(0.0, 1.0, 0.0) : (p <= 0.0 ? u0 : u1);
		}
		bristle = motion.z;
		if (form_from == 0 && c.z >= 0.55) {
			// Clinging to the wall in its mound: its own colours until it leaves the wall for the lane.
			heat_bristle = mix(0.25, bristle, smoothstep(0.05, 0.35, p));
		}
		// Rising as it forms, and thinned by weapons: its highest ranks shrink away first.
		float show = 1.0 - smoothstep(life.y * 1.05 - 0.04, life.y * 1.05, c.w);
		float kept = 1.0 - smoothstep(life.x * 1.03 - 0.025, life.x * 1.03 + 0.005, c.w);
		pos.y -= (1.0 - show) * 0.6;
		pos.y += (1.0 - kept) * 0.35;
		s *= show * kept;
		if (life.z > 0.5) {
			float speed = max(death_at.x, 1.0);
			float d = mass_dir;
			// Creatures behind the front reach it at the charge's speed.
			float arrive = (motion.x >= 1.0 ? c.x * mass.z : 0.0) / speed;
			float dt = life.w - arrive;
			if (life.z < 1.5) {
				// Shocked: up against the fence, then flung back, spinning, glowing, burning away.
				pos.z = mass.y + d * min(d * (pos.z - mass.y) + speed * min(life.w, arrive), 0.0);
				if (dt > 0.0) {
					pos += vec3((rnd(c.w, 9.0) - 0.5) * 3.0 * dt, 4.5 * dt - 6.0 * dt * dt, -d * (2.0 + 3.0 * rnd(c.w, 10.0)) * dt);
					vec3 axis = normalize(vec3(rnd(c.w, 11.0) - 0.5, 0.3, rnd(c.w, 12.0) - 0.5));
					fwd = turn(fwd, axis, dt * 9.0);
					up = turn(up, axis, dt * 9.0);
					s *= 1.0 - smoothstep(0.45, 0.9, dt);
					float crackle = step(0.5, fract(dt * 13.0 + rnd(c.w, 13.0)));
					v_shock = (1.0 - smoothstep(0.0, 0.55, dt)) * warning_flicker(crackle, 0.35);
				}
			} else if (life.z < 2.5) {
				// Falling into the hole: on over its edge, then down, tumbling, gone into the dark.
				pos.z += d * speed * min(life.w, arrive);
				if (dt > 0.0) {
					pos.z += d * speed * dt * 0.3;
					pos.y -= 8.0 * dt * dt + 0.6 * dt;
					fwd = turn(fwd, vec3(1.0, 0.0, 0.0), -d * dt * 4.0);
					up = turn(up, vec3(1.0, 0.0, 0.0), -d * dt * 4.0);
					s *= 1.0 - smoothstep(-3.5, -2.0, -pos.y);
				}
			} else {
				// Scattering: off to the sides and away.
				float dir = rnd(c.w, 14.0) < 0.5 ? -1.0 : 1.0;
				pos += vec3(dir * (2.0 + 2.0 * rnd(c.w, 15.0)), 0.0, (rnd(c.w, 16.0) - 0.5) * 3.0) * life.w;
				fwd = vec3(dir, 0.0, rnd(c.w, 17.0) - 0.5);
				up = vec3(0.0, 1.0, 0.0);
				s *= 1.0 - smoothstep(0.25, 0.8, life.w - rnd(c.w, 18.0) * 0.25);
			}
			scurry = 1.0;
		}
	}
	// The screech's own motion (ScreechModel), lighter: breathing, scurrying legs, raised spines, a lashing tail.
	float part = floor(UV.x + 0.5);
	float w = UV.y;
	float ts = TIME * (5.0 + 16.0 * scurry) + c.w * 44.0;
	vec3 rest = VERTEX;
	vec3 v = VERTEX;
	v.y += sin(ts * 0.35 + v.z * 6.0) * 0.012;
	v.x += sin(ts * 0.5 + v.z * 4.0) * 0.015 * scurry;
	if (part > 4.5 && part < 8.5) {
		float leg = part - 5.0;
		float ph = ts + mod(leg, 2.0) * 3.1416 + (leg > 1.5 ? 1.5708 : 0.0);
		v.z += sin(ph) * 0.08 * w * (0.25 + scurry);
		v.y += max(0.0, cos(ph)) * 0.06 * w * scurry;
	} else if (part > 1.5 && part < 2.5) {
		vec3 out_dir = normalize(vec3(v.x * 3.0, 1.0, 0.35));
		v += out_dir * w * bristle * 0.12;
	} else if (part > 2.5 && part < 4.5) {
		v.z += sin(ts + part * 1.7) * 0.05 * w * scurry;
	} else if (part > 8.5) {
		v.x += sin(ts * 0.7 + w * 3.0) * 0.13 * w;
		v.y += sin(ts * 0.5 + w * 2.0) * 0.04 * w;
	}
	mat3 m = frame(fwd, up);
	VERTEX = pos + m * (v * s);
	NORMAL = m * NORMAL;
	v_bristle = heat_bristle >= 0.0 ? heat_bristle : bristle;
	vec3 q = rest * 11.0 + vec3(c.w * 31.0);
	v_lesion = smoothstep(0.55, 0.9, sin(q.x) * sin(q.y * 1.3) * sin(q.z * 0.9) * 0.5 + 0.5);
}

void fragment() {
	vec3 skin = COLOR.rgb;
	float is_skin = 1.0 - step(0.05, COLOR.a);
	vec3 sore = mix(vec3(0.55, 0.5, 0.12), vec3(0.45, 0.14, 0.3), grime);
	skin = mix(skin, sore, v_lesion * is_skin * (0.35 + 0.45 * grime));
	skin *= mix(vec3(1.0), vec3(0.85, 0.75, 0.6), grime * is_skin);
	skin = mix(skin, skin_pale.rgb, skin_lift * is_skin);
	skin = to_linear(skin);
	ALBEDO = mix(skin, skin * 0.4, v_shock);
	ROUGHNESS = mix(0.15, 0.45, grime);
	SPECULAR = 0.6;
	// An attack's heat: 0 at rest (bristle 0.25) and for the horde, 1 at a surge's height.
	float heat = clamp((v_bristle - 0.25) / 0.75, 0.0, 1.0) * (1.0 - v_shock);
	vec3 hot = to_linear(attack_color.rgb);
	vec3 glow = mix(to_linear(COLOR.rgb), hot, heat) * COLOR.a * emission_strength * (1.0 + 1.2 * v_bristle);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	glow += hot * heat * (0.2 + 0.8 * rim) * heat_energy;
	glow += to_linear(shock_color.rgb) * v_shock * 2.6;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	glow /= max(1.0, max(glow.r, max(glow.g, glow.b)));
#endif
	EMISSION = glow;
}
