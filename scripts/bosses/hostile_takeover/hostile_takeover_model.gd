class_name HostileTakeoverModel
extends RefCounted
## Hostile Takeover's meshes (GDD §10), built once in code, low-poly and merged (one draw per material):
## - the military gunship pacing the train overhead (gunship()): an armoured olive and gunmetal hull over a
##   wide, flat belly (the ceiling the runner rides in phase 2: as wide as the lanes, flush from its stern
##   to its front, BELLY_STERN to BELLY_FRONT, nothing hanging below it), sponsons along the belly's sides
##   with their guns, a chin turret, stub wings with engine pods, twin tail fins, the corporation's mark
##   on the belly (its three docking clamps are their own meshes: clamp_folded, clamp_body), steady
##   cold-white running lights and its engines' cold blue glow toward the runner behind it. Its guns are
##   dark: nothing on it glows in a hazard colour (a strafe's tracers are the strafe's own:
##   HostileTakeoverStrafes). Its drop bay (bay_open(): the bay open, glowing the weak points' red, phase
##   2's weak point) and the green chevrons before it on the belly (belly_cue()) are meshes of their own;
## - the locomotive leading the train (locomotive()): an armoured power car as wide as the train, rising
##   over the carriages' roofs, the corporation's mark glowing in the brand's blue over its rear window,
##   cold-white marker lamps (never a tail light's red), and behind the window the Chairman's suite, lit
##   cold white, with the Chairman standing at the glass (chairman(): a man in a dark suit, hands behind
##   his back, watching the runner; GDD §10: "the player gets a glimpse of him");
## - a carriage coupling (coupling_*): two coupler arms from the carriages' ends meeting in a knuckle in the
##   middle of the gap, its red dome on top (the weak points' language, the hover truck's: it glows red when
##   live), and the take-off cue: the zone's green ramp chevrons on the roof in its lane, where a jump comes
##   down on it (the Floating Head's way-up language);
## - the armored carriage of phase 2 (armored()): a dark armored car body over a carriage's roof, its front
##   a sheer wall framed in the solid obstacles' yellow and black, no ladder, no hatch (no roof access).
## Moving models use plain colours only (the kit's patterns are drawn in world space and would slide over a
## moving hull); details are geometry. Space: x across the track, y up, +z toward the runner (behind),
## so -z is the way the train runs.

## The Corporate zone's palette (CorporateSkin): the military olive and gunmetal, the express's white, the
## brand's paint and glow, the cold white of its lights, its engines' blue.
const OLIVE := Color(0.29, 0.3, 0.21)
const OLIVE_DARK := Color(0.21, 0.22, 0.16)
const GUNMETAL := Color(0.19, 0.2, 0.23)
const GUNMETAL_LIGHT := Color(0.3, 0.31, 0.34)
const STEEL_DARK := Color(0.1, 0.105, 0.12)
const EXPRESS := Color(0.62, 0.64, 0.68)
const BRAND_PAINT := Color(0.11, 0.18, 0.46)
const BRAND_GLOW := Color(0.14, 0.27, 1.0)
const COLD_WHITE := Color(0.86, 0.92, 1.0)
const ENGINE := Color(0.55, 0.66, 1.0)
const GLASS := Color(0.03, 0.035, 0.045)
## The weak points' red (the hover truck's and the Floating Head's).
const WEAK := Color(1.0, 0.08, 0.1)
## The Chairman: a charcoal suit, a white shirt, a navy tie (nothing red), pale skin, dark hair.
const SUIT := Color(0.07, 0.07, 0.085)
const SHIRT := Color(0.88, 0.9, 0.94)
const TIE := Color(0.08, 0.11, 0.26)
const SKIN := Color(0.78, 0.66, 0.58)
const HAIR := Color(0.06, 0.055, 0.05)

## The gunship's length and its hull's height over its belly (its belly is at y = 0 in its own space).
const GUNSHIP_LENGTH: float = 30.0
const GUNSHIP_HULL_HEIGHT: float = 3.4
## Its belly's flat underside runs from BELLY_FRONT ahead of its middle to BELLY_STERN behind it (the
## ceiling the runner rides), and its drop bay is centred BAY_AHEAD ahead of its middle, BAY_HALF either
## way along it. A Buzz Overdrive hangs under the bay with its blade's foot SAW_HANG below the belly.
const BELLY_FRONT: float = 10.5
const BELLY_STERN: float = 11.5
const BAY_AHEAD: float = 3.5
const BAY_HALF: float = 2.0
const SAW_HANG: float = 3.1
## The solid obstacles' warning colour (signs: the yellow of the yellow-and-black frame).
const SOLID_WARN := Color(1.0, 0.78, 0.1)
## The locomotive's height over the roofs, its length, and its rear window (bottom, top).
const LOCO_HEIGHT: float = 6.6
const LOCO_LENGTH: float = 40.0
const LOCO_WINDOW := Vector2(1.0, 4.6)
## The suite behind the window: how deep it is, and where the Chairman stands in it (from the window).
const SUITE_DEPTH: float = 3.4
const CHAIRMAN_BACK: float = 1.2
## The Chairman's height (over life size: he's seen from far down the train).
const CHAIRMAN_HEIGHT: float = 2.4

static var _cache: Dictionary = {}


## The kit's solid material in the Corporate zone's light (the skin's, when there is one) and its glow.
static func solid_material(skin: ZoneSkin = null) -> ShaderMaterial:
	if skin is CorporateSkin:
		return (skin as CorporateSkin).solid_material()
	return MeshKit.solid({"glow_scale": 4.0, "sheen_color": Color(0.3, 0.34, 0.42), "sheen_strength": 0.2})


static func glow_material(skin: ZoneSkin = null) -> ShaderMaterial:
	if skin is CorporateSkin:
		return (skin as CorporateSkin).glow_material()
	return MeshKit.glow({"fade_begin": 18.0, "fade_end": 190.0})


# --- The gunship ---------------------------------------------------------------------------------

## The gunship over lanes `belly_width` wide (its belly as wide as the lanes, between 7 and 16 m), in its
## own space: its belly's middle at the origin, its nose toward -z (the way the train runs), its stern and
## engines toward +z (the runner behind it). Cached per width and skin.
static func gunship(belly_width: float, skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "gunship_%.2f_%d" % [belly_width, skin.get_instance_id() if skin != null else 0]
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material(skin))
	var g: MeshLayer = batch.layer(glow_material(skin))
	var bw: float = clampf(belly_width, 7.0, 16.0)
	var hw: float = maxf(bw * 0.52, 5.0)
	var h: float = GUNSHIP_HULL_HEIGHT
	var half_l: float = GUNSHIP_LENGTH * 0.5
	# The belly: a wide armoured slab (its underside the ceiling the runner rides in phase 2), plates told
	# apart by tone, all flush (nothing hangs below y = 0 between its front and its stern).
	s.box(Vector3(0.0, 0.45, (BELLY_STERN - BELLY_FRONT) * 0.5), Vector3(bw, 0.9, BELLY_STERN + BELLY_FRONT), GUNMETAL, 0.0,
		MeshKit.PAT_PLAIN)
	var bay0: float = -BAY_AHEAD - BAY_HALF
	var bay1: float = -BAY_AHEAD + BAY_HALF
	for i: int in 5:
		var z: float = -9.0 + i * 4.4 + 0.6
		if z + 1.9 > bay0 - 0.2 and z - 1.9 < bay1 + 0.2:
			continue
		for xs: float in [-1.0, 1.0]:
			s.box(Vector3(xs * bw * 0.24, -0.02, z), Vector3(bw * 0.42, 0.04, 3.8),
				GUNMETAL.lightened(0.04 + 0.04 * float((i + int(xs > 0.0)) % 2)), 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_NY)
	# The drop bay's closed doors: two plates meeting down the middle, a dark seam round them.
	for xs: float in [-1.0, 1.0]:
		s.box(Vector3(xs * bw * 0.25, -0.02, -BAY_AHEAD), Vector3(bw * 0.48, 0.04, BAY_HALF * 2.0 - 0.2),
			GUNMETAL_LIGHT.darkened(0.12), 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_NY)
	s.box(Vector3(0.0, -0.01, -BAY_AHEAD), Vector3(bw - 0.3, 0.02, BAY_HALF * 2.0), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_NY)
	# The corporation's mark on the belly, seen from the train below.
	s.quad_uv(Vector3(-2.2, -0.06, 2.8), Vector3(-2.2, -0.06, 7.2), Vector3(2.2, -0.06, 7.2), Vector3(2.2, -0.06, 2.8),
		Vector2(-1.0, 1.0), Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), BRAND_PAINT, 0.0, MeshKit.PAT_CORP_LOGO, 3.0)
	# The hull over the belly, tapering to its nose.
	var z_nose: float = -half_l
	var z_body: float = -half_l + 5.0
	var z_stern: float = half_l - 2.0
	s.box(Vector3(0.0, 0.9 + h * 0.5, (z_body + z_stern) * 0.5), Vector3(hw, h, z_stern - z_body), OLIVE, 0.0, MeshKit.PAT_PLAIN)
	# Its upper flanks in the lighter olive, a gunmetal spine.
	s.box(Vector3(0.0, 0.9 + h + 0.25, (z_body + z_stern) * 0.5), Vector3(hw * 0.55, 0.5, z_stern - z_body - 2.0), GUNMETAL, 0.0,
		MeshKit.PAT_PLAIN)
	var nb := Vector3(hw * 0.5, 0.9, z_body)
	var nt := Vector3(hw * 0.5, 0.9 + h, z_body)
	var tip_b := Vector3(hw * 0.22, 1.1, z_nose)
	var tip_t := Vector3(hw * 0.22, 0.9 + h * 0.55, z_nose)
	# The nose: its sides, top, underside and its blunt tip.
	s.quad(Vector3(nb.x, nb.y, nb.z), Vector3(nt.x, nt.y, nt.z), Vector3(tip_t.x, tip_t.y, tip_t.z), Vector3(tip_b.x, tip_b.y, tip_b.z), OLIVE)
	s.quad(Vector3(-tip_b.x, tip_b.y, tip_b.z), Vector3(-tip_t.x, tip_t.y, tip_t.z), Vector3(-nt.x, nt.y, nt.z), Vector3(-nb.x, nb.y, nb.z), OLIVE)
	s.quad(Vector3(-nt.x, nt.y, nt.z), Vector3(-tip_t.x, tip_t.y, tip_t.z), Vector3(tip_t.x, tip_t.y, tip_t.z), Vector3(nt.x, nt.y, nt.z),
		OLIVE.lightened(0.06))
	s.quad(Vector3(-tip_b.x, tip_b.y, tip_b.z), Vector3(-nb.x, nb.y, nb.z), Vector3(nb.x, nb.y, nb.z), Vector3(tip_b.x, tip_b.y, tip_b.z), GUNMETAL)
	s.quad(Vector3(-tip_b.x, tip_b.y, tip_b.z), Vector3(tip_b.x, tip_b.y, tip_b.z), Vector3(tip_t.x, tip_t.y, tip_t.z), Vector3(-tip_t.x, tip_t.y, tip_t.z),
		OLIVE_DARK)
	# The cockpit: a dark glass band over the nose, lit cold white inside.
	s.quad(Vector3(-nt.x + 0.3, nt.y + 0.02, nt.z - 0.2), Vector3(-tip_t.x + 0.2, tip_t.y + 0.02, tip_t.z + 2.0),
		Vector3(tip_t.x - 0.2, tip_t.y + 0.02, tip_t.z + 2.0), Vector3(nt.x - 0.3, nt.y + 0.02, nt.z - 0.2), GLASS, 0.0, MeshKit.PAT_GLASS)
	s.box(Vector3(0.0, nt.y + 0.06, nt.z - 1.6), Vector3(hw * 0.5, 0.04, 0.12), COLD_WHITE, 0.35, MeshKit.PAT_PLAIN, MeshKit.FACE_PY)
	# The chin turret under the nose, its twin barrels pointing ahead (dark: it fires in phase 2).
	var turret := Vector3(0.0, 0.2, z_body - 1.0)
	s.box(turret, Vector3(1.8, 1.0, 1.8), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN)
	for xs: float in [-0.35, 0.35]:
		s.box(turret + Vector3(xs, -0.05, -2.0), Vector3(0.22, 0.22, 2.6), GUNMETAL, 0.0, MeshKit.PAT_PLAIN)
	# The sponsons along the belly's sides, each with a gun pod pointing ahead.
	for xs: float in [-1.0, 1.0]:
		var sx: float = xs * (bw * 0.5 - 0.9)
		s.box(Vector3(sx, 1.2, -1.0), Vector3(1.8, 1.4, 16.0), OLIVE_DARK, 0.0, MeshKit.PAT_PLAIN)
		s.box(Vector3(sx, 0.7, -9.6), Vector3(1.1, 0.9, 2.0), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN)
		s.box(Vector3(sx, 0.7, -11.6), Vector3(0.24, 0.24, 2.4), GUNMETAL, 0.0, MeshKit.PAT_PLAIN)
		# A running light at each sponson's tail: steady cold white.
		s.box(Vector3(sx, 0.4, 7.2), Vector3(0.24, 0.24, 0.24), COLD_WHITE, 0.8)
		g.rect(Vector3(sx - 0.6, -0.2, 7.4), Vector3(1.2, 0.0, 0.0), Vector3(0.0, 1.2, 0.0), COLD_WHITE, 0.22, MeshKit.SHAPE_RADIAL)
	# The stern: the hull narrowing to a sloped tail over the belly's end.
	var stern_z: float = z_stern
	var tail_y: float = 0.9 + h
	var low: float = 0.9 + h * 0.45
	var end_z: float = stern_z + 2.4
	s.quad(Vector3(hw * 0.5, tail_y, stern_z), Vector3(hw * 0.3, low, end_z), Vector3(-hw * 0.3, low, end_z),
		Vector3(-hw * 0.5, tail_y, stern_z), OLIVE_DARK)
	s.quad(Vector3(hw * 0.3, low, end_z), Vector3(hw * 0.3, 0.9, end_z), Vector3(-hw * 0.3, 0.9, end_z), Vector3(-hw * 0.3, low, end_z),
		GUNMETAL)
	s.quad(Vector3(hw * 0.5, tail_y, stern_z), Vector3(hw * 0.5, 0.9, stern_z), Vector3(hw * 0.3, 0.9, end_z),
		Vector3(hw * 0.3, low, end_z), OLIVE)
	s.quad(Vector3(-hw * 0.3, low, end_z), Vector3(-hw * 0.3, 0.9, end_z), Vector3(-hw * 0.5, 0.9, stern_z),
		Vector3(-hw * 0.5, tail_y, stern_z), OLIVE)
	# Two big engine nacelles along its shoulders on stub wings, their exhausts glowing a dim cold blue
	# toward the runner behind it.
	for xs: float in [-1.0, 1.0]:
		var nx: float = xs * (hw * 0.5 + 1.7)
		var ny: float = 0.9 + h * 0.55
		s.box(Vector3(xs * (hw * 0.5 + 0.8), ny, 3.0), Vector3(1.8, 0.5, 5.0), GUNMETAL, 0.0, MeshKit.PAT_PLAIN)
		s.prism_xform(Transform3D(Basis(Vector3(1.35, 0.0, 0.0), Vector3(0.0, 0.0, 13.0), Vector3(0.0, 1.35, 0.0)),
			Vector3(nx, ny, stern_z - 9.5)), 10, OLIVE_DARK, 0.0, MeshKit.PAT_PLAIN)
		s.prism_xform(Transform3D(Basis(Vector3(1.15, 0.0, 0.0), Vector3(0.0, 0.0, 0.8), Vector3(0.0, 1.15, 0.0)),
			Vector3(nx, ny, stern_z + 3.5)), 10, STEEL_DARK, 0.0, MeshKit.PAT_PLAIN, false)
		s.prism_xform(Transform3D(Basis(Vector3(0.85, 0.0, 0.0), Vector3(0.0, 0.0, 0.05), Vector3(0.0, 0.85, 0.0)),
			Vector3(nx, ny, stern_z + 3.6)), 10, ENGINE, 0.35)
		g.rect(Vector3(nx - 1.3, ny - 1.3, stern_z + 3.8), Vector3(2.6, 0.0, 0.0), Vector3(0.0, 2.6, 0.0), ENGINE, 0.16, MeshKit.SHAPE_RADIAL)
		# The V-tail's fin on this side, leaning out, a small cold-white light at its tip.
		var fin := Transform3D(Basis(Vector3.BACK, -xs * 0.42) * Basis.from_scale(Vector3(0.3, 3.4, 3.6)),
			Vector3(xs * hw * 0.32, tail_y + 1.5, stern_z - 1.2))
		s.box_xform(fin, OLIVE, 0.0, MeshKit.PAT_PLAIN)
		s.box(fin * Vector3(0.0, 0.5, 0.3), Vector3(0.2, 0.2, 0.2), COLD_WHITE, 0.6)
	# A searchlight on the nose, pointing ahead along the line (never down at the lanes).
	s.box(Vector3(0.0, tip_b.y - 0.1, z_nose + 0.6), Vector3(0.5, 0.4, 0.5), COLD_WHITE, 0.9)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


## The gunship's drop bay, open (phase 2: the weak point the runner on its belly stomps): over the bay's
## stretch of a belly `belly_width` wide, the dark opening, its rim and the release clamps hanging `depth`
## below the belly, glowing the weak points' red. Own space as gunship(). Cached.
static func bay_open(belly_width: float, depth: float) -> ArrayMesh:
	var key: String = "bay_%.2f_%.2f" % [belly_width, depth]
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	var bw: float = clampf(belly_width, 7.0, 16.0)
	var z0: float = -BAY_AHEAD - BAY_HALF
	var z1: float = -BAY_AHEAD + BAY_HALF
	# The opening: a near-black well over the bay, lit red deep inside.
	s.box(Vector3(0.0, -0.035, -BAY_AHEAD), Vector3(bw - 0.4, 0.02, BAY_HALF * 2.0 - 0.3), Color(0.05, 0.01, 0.01), 0.0,
		MeshKit.PAT_PLAIN, MeshKit.FACE_NY)
	s.box(Vector3(0.0, -0.04, -BAY_AHEAD), Vector3(bw - 2.4, 0.02, BAY_HALF * 2.0 - 1.6), WEAK.darkened(0.55), 0.6,
		MeshKit.PAT_PLAIN, MeshKit.FACE_NY)
	# Its rim, glowing red all round.
	for z: float in [z0 + 0.12, z1 - 0.12]:
		s.box(Vector3(0.0, -0.06, z), Vector3(bw - 0.3, 0.06, 0.18), WEAK, 0.9, MeshKit.PAT_PLAIN)
	for xs: float in [-1.0, 1.0]:
		s.box(Vector3(xs * (bw * 0.5 - 0.27), -0.06, -BAY_AHEAD), Vector3(0.18, 0.06, BAY_HALF * 2.0 - 0.1), WEAK, 0.9, MeshKit.PAT_PLAIN)
	# The release clamps: a rail across the bay hanging `depth` down on struts, glowing red.
	var y: float = -depth + 0.08
	for z: float in [-BAY_AHEAD - 0.7, -BAY_AHEAD + 0.7]:
		s.box(Vector3(0.0, y, z), Vector3(bw - 1.2, 0.16, 0.3), WEAK, 1.1, MeshKit.PAT_PLAIN)
		for i: int in 5:
			var x: float = lerpf(-(bw * 0.5 - 1.0), bw * 0.5 - 1.0, i / 4.0)
			s.box(Vector3(x, (y - 0.06) * 0.5, z), Vector3(0.12, absf(y) + 0.02, 0.12), STEEL_DARK.lightened(0.1), 0.0, MeshKit.PAT_PLAIN)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


## The take-off cue on the gunship's belly (the green chevrons of the ways up, pointing ahead at the bay):
## where a jump from the belly comes back up onto the open bay, from `from_z` to `to_z` along it (own
## space as gunship(): toward the front is -z), `width` wide, facing down at a runner hanging below.
static func belly_cue(width: float, from_z: float, to_z: float, color: Color, skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "belly_cue_%.2f_%.2f_%.2f_%s_%d" % [width, from_z, to_z, color, skin.get_instance_id() if skin != null else 0]
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material(skin))
	var hw: float = width * 0.5
	var y: float = -0.05
	var near: float = maxf(from_z, to_z)
	var far: float = minf(from_z, to_z)
	# Facing down (u × v toward -y), UV.x along the belly toward its front (the chevrons point at the bay).
	s.rect(Vector3(-hw, y, near), Vector3(0.0, 0.0, -(near - far)), Vector3(width, 0.0, 0.0), color, 0.8, MeshKit.PAT_CHEVRON,
		Vector2.ZERO, Vector2.ONE, 1.0)
	for xs: float in [-1.0, 1.0]:
		s.box(Vector3(xs * (hw + 0.04), y, (near + far) * 0.5), Vector3(0.06, 0.02, near - far), color, 1.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_NY)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


# --- The armored carriage --------------------------------------------------------------------------

## Phase 2's armored carriage over a roof `length` long and `width` wide, `height` tall, in its own space:
## its front face (toward the runner, +z) at z = 0 with its bottom middle at the origin on the roofs'
## plane, its body running on to z = -length (the way the train runs). Dark armour plates, rib strips and
## firing slits; its front a sheer wall with the solid obstacles' yellow-and-black frame round it; no
## ladder, no hatch. Cached.
static func armored(length: float, width: float, height: float, skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "armored_%.2f_%.2f_%.2f_%d" % [length, width, height, skin.get_instance_id() if skin != null else 0]
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material(skin))
	var hw: float = width * 0.5
	# The body: a gunmetal slab with a lighter olive armour band along each side.
	s.box(Vector3(0.0, height * 0.5, -length * 0.5), Vector3(width, height, length), GUNMETAL, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	var plates: int = maxi(int(length / 6.0), 1)
	for i: int in plates:
		var z: float = -(i + 0.5) * length / plates
		var plate_l: float = length / plates - 0.3
		# Roof plates told apart by tone, and a raised rib between them.
		s.box(Vector3(0.0, height + 0.02, z), Vector3(width - 0.6, 0.04, plate_l),
			GUNMETAL.lightened(0.03 + 0.04 * float(i % 2)), 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PY)
		s.box(Vector3(0.0, height + 0.06, z - plate_l * 0.5 - 0.15), Vector3(width - 0.4, 0.12, 0.2), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN)
		for xs: float in [-1.0, 1.0]:
			s.box(Vector3(xs * (hw + 0.03), height * 0.55, z), Vector3(0.06, height * 0.6, plate_l), OLIVE_DARK, 0.0, MeshKit.PAT_PLAIN,
				MeshKit.FACE_PX if xs > 0.0 else MeshKit.FACE_NX)
	# The front: a sheer armoured wall, a heavy olive plate with dark firing slits across it.
	s.box(Vector3(0.0, height * 0.5, 0.03), Vector3(width - 0.5, height - 0.5, 0.06), OLIVE, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	for i: int in 5:
		var x: float = lerpf(-hw + 1.2, hw - 1.2, i / 4.0)
		s.box(Vector3(x, height * 0.62, 0.07), Vector3(0.9, 0.12, 0.02), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	# The solid obstacles' yellow-and-black frame round the front (the signs' language: solid, deadly).
	var rail: float = 0.24
	for y: float in [height - rail * 0.5, rail * 0.5]:
		s.box(Vector3(0.0, y, 0.1), Vector3(width, rail, 0.2), SOLID_WARN, 0.55, MeshKit.PAT_STRIPES)
	for xs: float in [-1.0, 1.0]:
		s.box(Vector3(xs * (hw - rail * 0.5), height * 0.5, 0.1), Vector3(rail, height - rail * 2.0, 0.2), SOLID_WARN, 0.55,
			MeshKit.PAT_STRIPES, MeshKit.ALL_FACES & ~(MeshKit.FACE_PY | MeshKit.FACE_NY))
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


# --- The locomotive and the Chairman -------------------------------------------------------------

## The locomotive leading a train `width` wide (wall to wall), in its own space: its rear face's bottom
## middle at the origin on the roofs' plane, the runner behind it (+z), its nose ahead (-z). The
## Chairman stands in the suite behind its rear window (chairman(), added by the part). Cached.
static func locomotive(width: float, skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "loco_%.2f_%d" % [width, skin.get_instance_id() if skin != null else 0]
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material(skin))
	var g: MeshLayer = batch.layer(glow_material(skin))
	var hw: float = maxf(width * 0.5 - 0.2, 2.5)
	var h: float = LOCO_HEIGHT
	var depth: float = 3.2
	var length: float = LOCO_LENGTH
	var win: Vector2 = LOCO_WINDOW
	var wx: float = minf(hw * 0.55, 4.2)
	# The skirt below the roofs' plane (in the dark like the carriages' bodies), and the body over it.
	s.box(Vector3(0.0, -depth * 0.5, -length * 0.5), Vector3(hw * 2.0, depth, length), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN)
	# The rear face around the window: armour plates, the window's frame, the plaque above.
	var face_z: float = 0.0
	s.rect(Vector3(-hw, 0.0, face_z), Vector3(hw - wx, 0.0, 0.0), Vector3(0.0, h, 0.0), GUNMETAL)
	s.rect(Vector3(wx, 0.0, face_z), Vector3(hw - wx, 0.0, 0.0), Vector3(0.0, h, 0.0), GUNMETAL)
	s.rect(Vector3(-wx, 0.0, face_z), Vector3(wx * 2.0, 0.0, 0.0), Vector3(0.0, win.x, 0.0), GUNMETAL)
	s.rect(Vector3(-wx, win.y, face_z), Vector3(wx * 2.0, 0.0, 0.0), Vector3(0.0, h - win.y, 0.0), GUNMETAL)
	# An olive band of armour across the face under the window, the express's white stripe over it.
	s.box(Vector3(0.0, 0.35, face_z + 0.05), Vector3(hw * 2.0, 0.5, 0.1), OLIVE, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	s.box(Vector3(0.0, 0.66, face_z + 0.05), Vector3(hw * 2.0, 0.12, 0.1), EXPRESS, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	# The window's frame and its mullions (the window is open: the suite's light shows through it).
	for xm: float in [-wx, -wx * 0.34, wx * 0.34, wx]:
		s.box(Vector3(xm, (win.x + win.y) * 0.5, face_z + 0.04), Vector3(0.16, win.y - win.x, 0.12), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN)
	for ym: float in [win.x, win.y]:
		s.box(Vector3(0.0, ym, face_z + 0.04), Vector3(wx * 2.0 + 0.16, 0.16, 0.12), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN)
	# The suite behind it: floor, ceiling and side walls dim, its far wall lit cold white (the Chairman stands
	# against it).
	var back: float = face_z - SUITE_DEPTH
	s.rect(Vector3(-wx, win.x, face_z), Vector3(wx * 2.0, 0.0, 0.0), Vector3(0.0, 0.0, -SUITE_DEPTH), GUNMETAL_LIGHT.darkened(0.3))
	s.rect(Vector3(wx, win.y, face_z), Vector3(-wx * 2.0, 0.0, 0.0), Vector3(0.0, 0.0, -SUITE_DEPTH), STEEL_DARK)
	s.rect(Vector3(-wx, win.x, back), Vector3(0.0, 0.0, SUITE_DEPTH), Vector3(0.0, win.y - win.x, 0.0), GUNMETAL_LIGHT)
	s.rect(Vector3(wx, win.x, face_z), Vector3(0.0, 0.0, -SUITE_DEPTH), Vector3(0.0, win.y - win.x, 0.0), GUNMETAL_LIGHT)
	s.rect(Vector3(-wx, win.x, back), Vector3(wx * 2.0, 0.0, 0.0), Vector3(0.0, win.y - win.x, 0.0), COLD_WHITE, 0.55)
	# A strip of light along the suite's ceiling.
	s.box(Vector3(0.0, win.y - 0.08, back * 0.5), Vector3(wx * 1.6, 0.06, SUITE_DEPTH * 0.6), COLD_WHITE, 0.9, MeshKit.PAT_PLAIN,
		MeshKit.FACE_NY)
	g.rect(Vector3(-wx * 1.25, win.x - 0.6, face_z + 0.2), Vector3(wx * 2.5, 0.0, 0.0), Vector3(0.0, win.y - win.x + 1.2, 0.0), COLD_WHITE,
		0.12, MeshKit.SHAPE_FLAT)
	# The corporation's mark over the window, glowing in the brand's blue on a dark plaque.
	var plaque_y: float = win.y + (h - win.y) * 0.5
	s.box(Vector3(0.0, plaque_y, face_z + 0.08), Vector3(2.4, 1.2, 0.12), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN)
	s.quad_uv(Vector3(-0.55, plaque_y - 0.5, face_z + 0.15), Vector3(-0.55, plaque_y + 0.5, face_z + 0.15),
		Vector3(0.55, plaque_y + 0.5, face_z + 0.15), Vector3(0.55, plaque_y - 0.5, face_z + 0.15),
		Vector2(-1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, -1.0), BRAND_GLOW, 0.9, MeshKit.PAT_CORP_LOGO, 1.0)
	# Marker lamps at its lower corners: cold white (a tail light's red would be a hazard's colour).
	for xs: float in [-1.0, 1.0]:
		var lamp := Vector3(xs * (hw - 0.6), 1.2, face_z + 0.1)
		s.box(lamp, Vector3(0.4, 0.4, 0.12), COLD_WHITE, 1.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
		g.rect(lamp + Vector3(-1.2, -1.2, 0.1), Vector3(2.4, 0.0, 0.0), Vector3(0.0, 2.4, 0.0), COLD_WHITE, 0.4, MeshKit.SHAPE_RADIAL)
	# The body running ahead: its flanks, its roof with a sensor mast, its wedge nose.
	var nose_z: float = -length
	s.rect(Vector3(-hw, 0.0, nose_z), Vector3(0.0, 0.0, length), Vector3(0.0, h, 0.0), GUNMETAL)
	s.rect(Vector3(hw, 0.0, face_z), Vector3(0.0, 0.0, -length), Vector3(0.0, h, 0.0), GUNMETAL)
	for xs: float in [-1.0, 1.0]:
		s.box(Vector3(xs * (hw + 0.02), 0.9, -length * 0.5), Vector3(0.06, 0.7, length - 1.0), OLIVE, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PX if xs > 0.0 else MeshKit.FACE_NX)
		s.box(Vector3(xs * (hw + 0.03), 1.4, -length * 0.5), Vector3(0.06, 0.1, length - 1.0), EXPRESS, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PX if xs > 0.0 else MeshKit.FACE_NX)
	s.rect(Vector3(-hw, h, face_z), Vector3(hw * 2.0, 0.0, 0.0), Vector3(0.0, 0.0, -length), GUNMETAL_LIGHT)
	s.box(Vector3(0.0, h + 0.4, -6.0), Vector3(hw * 1.2, 0.8, 7.0), OLIVE_DARK, 0.0, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	s.box(Vector3(0.0, h + 1.6, -5.0), Vector3(0.25, 1.6, 0.25), STEEL_DARK)
	s.box(Vector3(0.0, h + 2.5, -5.0), Vector3(0.36, 0.3, 0.36), COLD_WHITE, 1.0)
	g.rect(Vector3(-1.4, h + 1.1, -4.8), Vector3(2.8, 0.0, 0.0), Vector3(0.0, 2.8, 0.0), COLD_WHITE, 0.35, MeshKit.SHAPE_RADIAL)
	# The levitation's glow along its skirts, in the brand's blue.
	for xs: float in [-1.0, 1.0]:
		g.rect(Vector3(xs * (hw + 0.1), -0.6, -1.0), Vector3(0.0, 0.0, -length + 2.0), Vector3(0.0, 1.0, 0.0), BRAND_GLOW, 0.25,
			MeshKit.SHAPE_STREAK)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


## Where the Chairman stands, in the locomotive's space: in the middle of the suite, on its floor.
static func chairman_spot() -> Vector3:
	return Vector3(0.0, LOCO_WINDOW.x, -CHAIRMAN_BACK)


## The Chairman (GDD §10: one of the villain's inner circle, glimpsed in the locomotive's window): a man in
## a charcoal suit with a white shirt and a navy tie, hands clasped behind his back, standing square to
## the window and watching the runner. In his own space: his feet at the origin, facing +z.
static func chairman(skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "chairman_%d" % (skin.get_instance_id() if skin != null else 0)
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material(skin))
	var k: float = CHAIRMAN_HEIGHT / 1.85
	# Legs and shoes.
	for xs: float in [-1.0, 1.0]:
		s.box(Vector3(xs * 0.11, 0.45, 0.0) * k, Vector3(0.17, 0.9, 0.2) * k, SUIT, 0.0, MeshKit.PAT_PLAIN)
		s.box(Vector3(xs * 0.11, 0.04, 0.05) * k, Vector3(0.15, 0.08, 0.3) * k, HAIR, 0.0, MeshKit.PAT_PLAIN)
	# The jacket: hips, chest and broad shoulders.
	s.box(Vector3(0.0, 1.05, 0.0) * k, Vector3(0.42, 0.34, 0.24) * k, SUIT, 0.0, MeshKit.PAT_PLAIN)
	s.box(Vector3(0.0, 1.38, 0.0) * k, Vector3(0.5, 0.36, 0.27) * k, SUIT, 0.0, MeshKit.PAT_PLAIN)
	s.box(Vector3(0.0, 1.55, -0.01) * k, Vector3(0.6, 0.08, 0.26) * k, SUIT, 0.0, MeshKit.PAT_PLAIN)
	# The shirt's V and the tie, on the jacket's front.
	s.quad(Vector3(-0.1, 1.56, 0.136) * k, Vector3(0.0, 1.56, 0.136) * k, Vector3(0.0, 1.3, 0.136) * k, Vector3(-0.02, 1.3, 0.136) * k, SHIRT)
	s.quad(Vector3(0.0, 1.56, 0.136) * k, Vector3(0.1, 1.56, 0.136) * k, Vector3(0.02, 1.3, 0.136) * k, Vector3(0.0, 1.3, 0.136) * k, SHIRT)
	s.box(Vector3(0.0, 1.38, 0.14) * k, Vector3(0.05, 0.3, 0.01) * k, TIE, 0.0, MeshKit.PAT_PLAIN)
	# Arms down at his sides, the hands clasped behind his back.
	for xs: float in [-1.0, 1.0]:
		s.box(Vector3(xs * 0.3, 1.32, -0.03) * k, Vector3(0.12, 0.42, 0.14) * k, SUIT, 0.0, MeshKit.PAT_PLAIN)
		s.box(Vector3(xs * 0.22, 1.02, -0.12) * k, Vector3(0.11, 0.3, 0.12) * k, SUIT, 0.0, MeshKit.PAT_PLAIN)
	s.box(Vector3(0.0, 0.92, -0.17) * k, Vector3(0.2, 0.1, 0.08) * k, SKIN, 0.0, MeshKit.PAT_PLAIN)
	# The neck, the head (square-jawed, slicked dark hair).
	s.box(Vector3(0.0, 1.62, 0.0) * k, Vector3(0.12, 0.1, 0.12) * k, SKIN, 0.0, MeshKit.PAT_PLAIN)
	s.box(Vector3(0.0, 1.76, 0.01) * k, Vector3(0.2, 0.24, 0.22) * k, SKIN, 0.0, MeshKit.PAT_PLAIN)
	s.box(Vector3(0.0, 1.9, -0.02) * k, Vector3(0.22, 0.07, 0.24) * k, HAIR, 0.0, MeshKit.PAT_PLAIN)
	s.box(Vector3(0.0, 1.8, -0.1) * k, Vector3(0.22, 0.2, 0.06) * k, HAIR, 0.0, MeshKit.PAT_PLAIN)
	# His eyes: two dark bars under the brow (he's watching).
	for xs: float in [-1.0, 1.0]:
		s.box(Vector3(xs * 0.05, 1.79, 0.122) * k, Vector3(0.05, 0.02, 0.01) * k, HAIR, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


# --- A coupling ----------------------------------------------------------------------------------

## A coupling's mechanism over a gap `gap` long in a lane `lane_width` wide, in its own space: the middle of
## the gap in its lane, on the roofs' plane (the carriages' ends at z = ±gap / 2). Its two halves, each
## a carriage's coupler arm and its half of the knuckle (`rear`: the carriage behind, toward +z; it breaks
## away). Plain steel: the red dome on top is coupling_dome(). Cached.
static func coupling_half(gap: float, lane_width: float, rear: bool, skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "coupling_%.2f_%.2f_%s_%d" % [gap, lane_width, rear, skin.get_instance_id() if skin != null else 0]
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material(skin))
	var dir: float = 1.0 if rear else -1.0
	var end_z: float = dir * gap * 0.5
	var knuckle_half: float = 0.55
	# The draft gear housing at the carriage's end, just under the roof.
	s.box(Vector3(0.0, -0.55, end_z - dir * 0.25), Vector3(minf(lane_width * 0.5, 1.1), 0.7, 0.5), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN)
	# The coupler arm, rising toward the knuckle in the middle of the gap.
	var a := Vector3(0.0, -0.6, end_z - dir * 0.4)
	var b := Vector3(0.0, -0.18, dir * knuckle_half)
	var along: Vector3 = b - a
	var basis := Basis(Vector3(0.42, 0.0, 0.0), Vector3(0.0, 0.36, 0.0), along)
	basis.y = along.cross(Vector3.RIGHT).normalized() * 0.36
	s.box_xform(Transform3D(basis, (a + b) * 0.5), GUNMETAL, 0.0, MeshKit.PAT_PLAIN)
	# Hydraulic lines along it.
	for xs: float in [-0.26, 0.26]:
		s.box_xform(Transform3D(Basis(Vector3(0.06, 0.0, 0.0), basis.y.normalized() * 0.06, along), (a + b) * 0.5 + Vector3(xs, 0.05, 0.0)),
			OLIVE, 0.0, MeshKit.PAT_PLAIN)
	# Its half of the knuckle: a heavy housing meeting the other half in the middle.
	s.box(Vector3(0.0, -0.1, dir * knuckle_half * 0.5), Vector3(1.0, 0.56, knuckle_half - 0.02), GUNMETAL_LIGHT, 0.0, MeshKit.PAT_PLAIN)
	s.box(Vector3(0.0, 0.2, dir * knuckle_half * 0.5), Vector3(1.04, 0.06, knuckle_half - 0.02), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


## The coupling's red dome on top of its knuckle (the weak points' language: glowing red while it's
## live, dark otherwise: its material says which). Own space as coupling_half(). Cached.
static func coupling_dome() -> ArrayMesh:
	if _cache.has("coupling_dome"):
		return _cache["coupling_dome"]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	s.prism(Vector3(0.0, 0.23, 0.0), 0.42, 0.12, 10, WEAK, 1.0, MeshKit.PAT_PLAIN, true)
	s.prism(Vector3(0.0, 0.35, 0.0), 0.3, 0.1, 10, WEAK.lightened(0.15), 1.2, MeshKit.PAT_PLAIN, true)
	# A band of red around the knuckle's waist, seen from behind and the sides.
	s.box(Vector3(0.0, 0.02, 0.0), Vector3(1.06, 0.12, 1.12), WEAK, 0.8, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache["coupling_dome"] = mesh
	return mesh


## The same dome dark (a coupling not live: plain steel, nothing glowing). Cached.
static func coupling_dome_dark(skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "coupling_dome_dark_%d" % (skin.get_instance_id() if skin != null else 0)
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material(skin))
	s.prism(Vector3(0.0, 0.23, 0.0), 0.42, 0.12, 10, STEEL_DARK, 0.0, MeshKit.PAT_PLAIN, true)
	s.prism(Vector3(0.0, 0.35, 0.0), 0.3, 0.1, 10, GUNMETAL, 0.0, MeshKit.PAT_PLAIN, true)
	s.box(Vector3(0.0, 0.02, 0.0), Vector3(1.06, 0.12, 1.12), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


## The dome's halo: a red glow card standing over it, facing the runner (kit glow). Cached.
static func coupling_halo(skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "coupling_halo_%d" % (skin.get_instance_id() if skin != null else 0)
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var g: MeshLayer = batch.layer(glow_material(skin))
	g.rect(Vector3(-1.6, -1.1, 0.0), Vector3(3.2, 0.0, 0.0), Vector3(0.0, 3.2, 0.0), WEAK, 0.7, MeshKit.SHAPE_RADIAL)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


## The take-off cue on the roof in the coupling's lane (the zone's green ramp chevrons, pointing ahead at
## the gap): from `from` to `to` metres before the gap's near edge, `width` wide, in the coupling's own
## space (the gap's near edge at z = gap / 2). Panels with a bright edge line along each side. Cached.
static func coupling_cue(gap: float, from: float, to: float, width: float, color: Color, skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "cue_%.2f_%.2f_%.2f_%.2f_%s_%d" % [gap, from, to, width, color, skin.get_instance_id() if skin != null else 0]
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material(skin))
	var z_far: float = gap * 0.5 + minf(from, to)
	var z_near: float = gap * 0.5 + maxf(from, to)
	var hw: float = width * 0.5
	var y: float = 0.012
	# UV.x runs along the track toward the gap (ahead), so the chevrons point and stream at it.
	s.rect(Vector3(hw, y, z_near), Vector3(0.0, 0.0, -(z_near - z_far)), Vector3(-width, 0.0, 0.0), color, 0.8, MeshKit.PAT_CHEVRON,
		Vector2.ZERO, Vector2.ONE, 1.0)
	for xs: float in [-1.0, 1.0]:
		s.box(Vector3(xs * (hw + 0.04), y, (z_near + z_far) * 0.5), Vector3(0.06, 0.02, z_near - z_far), color, 1.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PY)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


# --- Phase 3: the docking clamps and arms, the screens' pylons, the lobby tower and its sculpture ---

## A docking clamp folded flush into the gunship's belly (until phase 3 opens it), `width` by `length`, in
## clamp_body's space: a dark hatch with a seam down its middle, nothing below the belly. Cached.
static func clamp_folded(width: float, length: float, skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "clamp_folded_%.2f_%.2f_%d" % [width, length, skin.get_instance_id() if skin != null else 0]
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material(skin))
	s.box(Vector3(0.0, -0.02, 0.0), Vector3(width - 0.2, 0.04, length), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_NY)
	for xs: float in [-1.0, 1.0]:
		s.box(Vector3(xs * (width * 0.25), -0.03, 0.0), Vector3(width * 0.44, 0.04, length - 0.3), GUNMETAL_LIGHT.darkened(0.2), 0.0,
			MeshKit.PAT_PLAIN, MeshKit.FACE_NY)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


## One of phase 3's docking clamps hanging under the gunship's belly over a third of it, `width` wide,
## `length` along the belly and `depth` deep, in its own space: its spot on the belly's underside at the
## origin, hanging down (-y), the belly's front toward -z. A dark mount plate flush with the belly, a hinge
## block at each end of its width and two heavy jaws closing across it round its lock (clamp_core: the
## weak points' red), hydraulic rams along it. Solid kit colours, nothing glowing. Cached.
static func clamp_body(width: float, length: float, depth: float, skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "clamp_%.2f_%.2f_%.2f_%d" % [width, length, depth, skin.get_instance_id() if skin != null else 0]
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material(skin))
	var hw: float = width * 0.5
	var hl: float = length * 0.5
	s.box(Vector3(0.0, -0.05, 0.0), Vector3(width, 0.1, length), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
	for xs: float in [-1.0, 1.0]:
		s.box(Vector3(xs * (hw - 0.3), -0.3, 0.0), Vector3(0.5, 0.45, length * 0.85), GUNMETAL, 0.0, MeshKit.PAT_PLAIN)
		# The jaw: a heavy slab from the hinge down and in, its lip under the lock.
		var jaw := Transform3D(Basis(Vector3.BACK, xs * 0.55) * Basis.from_scale(Vector3(0.32, depth * 0.95, length * 0.72)),
			Vector3(xs * (hw - 0.75), -depth * 0.5, 0.0))
		s.box_xform(jaw, OLIVE_DARK, 0.0, MeshKit.PAT_PLAIN)
		s.box(Vector3(xs * (hw * 0.5), -depth + 0.06, 0.0), Vector3(0.5, 0.12, length * 0.6), GUNMETAL_LIGHT, 0.0, MeshKit.PAT_PLAIN)
	for z: float in [-hl * 0.62, hl * 0.62]:
		s.box(Vector3(0.0, -0.2, z), Vector3(width * 0.78, 0.12, 0.14), GUNMETAL_LIGHT, 0.0, MeshKit.PAT_PLAIN)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


## A docking clamp's lock (clamp_body's own space), glowing the weak points' red: a bar across between
## its jaws near their lips, and a lamp on each hinge. For a material that pulses (like the drop bay's).
## Cached.
static func clamp_core(width: float, length: float, depth: float) -> ArrayMesh:
	var key: String = "clamp_core_%.2f_%.2f_%.2f" % [width, length, depth]
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	var hw: float = width * 0.5
	s.box(Vector3(0.0, -depth + 0.2, 0.0), Vector3(maxf(width - 1.5, 0.6), 0.26, length * 0.55), WEAK, 1.0, MeshKit.PAT_PLAIN)
	for xs: float in [-1.0, 1.0]:
		s.box(Vector3(xs * (hw - 0.3), -0.54, 0.0), Vector3(0.3, 0.06, length * 0.4), WEAK, 1.0, MeshKit.PAT_PLAIN, MeshKit.FACE_NY)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


## One of the three huge arms the docked gunship grips the locomotive with (they look the part; its weak
## points are the clamps under its belly), in its own space: its hinge at the origin on the gunship's
## belly, the arm reaching `out` across (+x; a negative `out` reaches the other way; 0 for the middle one,
## which reaches ahead, -z) and then `down` over the locomotive's edge, a claw hooked under it. Cached.
static func dock_arm(out: float, down: float, skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "dock_arm_%.2f_%.2f_%d" % [out, down, skin.get_instance_id() if skin != null else 0]
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material(skin))
	var middle: bool = is_zero_approx(out)
	var reach := Vector3(out, 0.0, -4.0 if middle else -0.6)
	# The hinge, the beam out to the elbow, the arm down, the claw hooked under the edge.
	s.box(Vector3(0.0, -0.3, 0.0), Vector3(1.1, 0.7, 1.1), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN)
	s.box_between(Vector3(0.0, -0.65, 0.35), reach + Vector3(0.0, 0.05, -0.35), GUNMETAL, 0.0, MeshKit.PAT_PLAIN)
	s.box(reach + Vector3(0.0, -down * 0.5, 0.0), Vector3(0.75, down + 0.6, 0.9), OLIVE_DARK, 0.0, MeshKit.PAT_PLAIN)
	var hook := Vector3(0.0, -down - 0.15, 0.45) if middle else Vector3(-0.55 * signf(out), -down - 0.15, 0.0)
	s.box(reach + hook, Vector3(0.75 if middle else 0.9, 0.3, 0.9), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN)
	# A hydraulic ram along the beam.
	s.box_between(Vector3(0.0, -0.05, 0.25), reach * 0.8 + Vector3(0.0, 0.25, 0.1), GUNMETAL_LIGHT, 0.0, MeshKit.PAT_PLAIN)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


## A pylon carrying one of the city's ad screens beyond the sound barriers (the merger's screens), in its
## own space: its foot at the origin (far below, out of sight behind the barrier), its screen's housing a
## little bigger than `size` (width, height), its middle `y` up, facing +z; a thin cold-white rim round
## the screen. Cached.
static func screen_pylon(size: Vector2, y: float, skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "pylon_%.2f_%.2f_%.2f_%d" % [size.x, size.y, y, skin.get_instance_id() if skin != null else 0]
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material(skin))
	var bottom: float = y - size.y * 0.5
	s.box(Vector3(0.0, (bottom - 14.0) * 0.5, -0.4), Vector3(0.7, bottom + 14.0, 0.7), GUNMETAL, 0.0, MeshKit.PAT_PLAIN)
	s.box(Vector3(0.0, y, -0.12), Vector3(size.x + 0.5, size.y + 0.5, 0.3), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN)
	for ys: float in [-1.0, 1.0]:
		s.box(Vector3(0.0, y + ys * (size.y * 0.5 + 0.15), 0.06), Vector3(size.x + 0.3, 0.06, 0.04), COLD_WHITE, 0.6, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PZ)
	for xs: float in [-1.0, 1.0]:
		s.box(Vector3(xs * (size.x * 0.5 + 0.15), y, 0.06), Vector3(0.06, size.y + 0.36, 0.04), COLD_WHITE, 0.6, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PZ)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


## The corporate tower whose sky lobby the derailed locomotive ploughs through (the defeat), in its own
## space: the lobby's floor at the origin on the roofs' plane, the lobby facing +z, the tower `width` wide
## and `depth` deep rising high over it: dark glass with lit floors, the brand's mark near its top, the
## lobby a tall glass atrium lit cold white; its trunk going on down toward the street far below. Placed
## once and still (so the kit's world-space patterns stay put). Cached.
static func lobby_tower(width: float, depth: float, skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "lobby_%.2f_%.2f_%d" % [width, depth, skin.get_instance_id() if skin != null else 0]
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material(skin))
	var g: MeshLayer = batch.layer(glow_material(skin))
	var hw: float = width * 0.5
	var lobby_h: float = 9.0
	var top: float = 70.0
	s.box(Vector3(0.0, (lobby_h + top) * 0.5, -depth * 0.5), Vector3(width, top - lobby_h, depth), GLASS, 0.0, MeshKit.PAT_GLASS)
	s.box(Vector3(0.0, -20.0, -depth * 0.5), Vector3(width * 0.8, 40.0, depth * 0.8), GUNMETAL, 0.0, MeshKit.PAT_PLAIN)
	for i: int in 12:
		var fy: float = lobby_h + 4.0 + i * 5.0
		s.box(Vector3(0.0, fy, 0.03), Vector3(width - 1.0, 0.25, 0.06), COLD_WHITE, 0.35, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	# The lobby: its floor, its lit back wall, a glass front with mullions, a steel soffit over it.
	s.box(Vector3(0.0, -0.4, -depth * 0.5), Vector3(width, 0.8, depth), GUNMETAL_LIGHT, 0.0, MeshKit.PAT_PLAIN)
	s.rect(Vector3(-hw + 0.5, 0.0, -depth + 1.0), Vector3(width - 1.0, 0.0, 0.0), Vector3(0.0, lobby_h, 0.0), COLD_WHITE, 0.5)
	s.rect(Vector3(-hw + 0.5, 0.0, -1.5), Vector3(width - 1.0, 0.0, 0.0), Vector3(0.0, lobby_h, 0.0), GLASS, 0.0, MeshKit.PAT_GLASS)
	for i: int in 7:
		var x: float = lerpf(-hw + 0.5, hw - 0.5, i / 6.0)
		s.box(Vector3(x, lobby_h * 0.5, -1.45), Vector3(0.25, lobby_h, 0.25), STEEL_DARK, 0.0, MeshKit.PAT_PLAIN)
	s.box(Vector3(0.0, lobby_h + 0.3, -1.0), Vector3(width, 0.6, 2.0), EXPRESS, 0.0, MeshKit.PAT_PLAIN)
	g.rect(Vector3(-hw, 0.3, -1.3), Vector3(width, 0.0, 0.0), Vector3(0.0, lobby_h * 0.8, 0.0), COLD_WHITE, 0.18, MeshKit.SHAPE_FLAT)
	# The brand's mark high on its face, glowing blue.
	var my: float = top - 9.0
	s.quad_uv(Vector3(-6.0, my - 6.0, 0.08), Vector3(-6.0, my + 6.0, 0.08), Vector3(6.0, my + 6.0, 0.08), Vector3(6.0, my - 6.0, 0.08),
		Vector2(-1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, -1.0), BRAND_GLOW, 0.9, MeshKit.PAT_CORP_LOGO, 1.0)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


## The giant, soulless logo sculpture on the lobby's plaza (GDD §10): the brand's mark as a vast polished
## steel disc standing on a stepped plinth, the mark painted on both its faces, a faint blue glow round it.
## In its own space: the plinth's front edge (toward +z) at the origin, so it topples forward about it.
## Cached.
static func logo_sculpture(skin: ZoneSkin = null) -> ArrayMesh:
	var key: String = "logo_sculpture_%d" % (skin.get_instance_id() if skin != null else 0)
	if _cache.has(key):
		return _cache[key]
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid_material(skin))
	var g: MeshLayer = batch.layer(glow_material(skin))
	s.box(Vector3(0.0, 0.6, -3.0), Vector3(8.0, 1.2, 6.0), GUNMETAL_LIGHT, 0.0, MeshKit.PAT_PLAIN)
	s.box(Vector3(0.0, 1.5, -3.0), Vector3(6.0, 0.6, 4.4), EXPRESS, 0.0, MeshKit.PAT_PLAIN)
	var r: float = 6.0
	var cy: float = 1.8 + r
	# The disc: an octagonal slab on its edge, its faces toward ±z.
	var disc := Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(r, 0.9, r)), Vector3(0.0, cy, -2.55))
	s.prism_xform(disc, 8, EXPRESS.lightened(0.1), 0.0, MeshKit.PAT_PLAIN)
	var k: float = r * 0.7
	for zs: float in [-1.0, 1.0]:
		var z: float = -3.0 + zs * 0.47
		var a := Vector3(-k, cy - k, z)
		var b := Vector3(-k, cy + k, z)
		var c := Vector3(k, cy + k, z)
		var d := Vector3(k, cy - k, z)
		if zs > 0.0:
			s.quad_uv(d, c, b, a, Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(-1.0, -1.0), BRAND_PAINT, 0.0,
				MeshKit.PAT_CORP_LOGO, 2.0)
		else:
			s.quad_uv(a, b, c, d, Vector2(-1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, -1.0), BRAND_PAINT, 0.0,
				MeshKit.PAT_CORP_LOGO, 2.0)
	g.rect(Vector3(-r * 1.1, cy - r * 1.1, -2.0), Vector3(r * 2.2, 0.0, 0.0), Vector3(0.0, r * 2.2, 0.0), BRAND_GLOW, 0.16, MeshKit.SHAPE_RADIAL)
	var mesh: ArrayMesh = batch.to_mesh()
	_cache[key] = mesh
	return mesh


## The vertex count of a mesh (budgets in tests).
static func vertices(mesh: ArrayMesh) -> int:
	if mesh == null:
		return 0
	var total: int = 0
	for i: int in mesh.get_surface_count():
		total += (mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return total
