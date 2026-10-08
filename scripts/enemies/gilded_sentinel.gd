class_name GildedSentinel
extends Enemy
## A Gilded Sentinel (GDD §9.11), the Golden Zone's live statue: a golden guardian with a halberd (the
## zone's statue kit, GoldenStatue) standing in a niche at wall-run height, its eyes glowing red. The
## decorative statues stand only on the ledges far above (GoldenSkin.statue_min_height), so a statue at
## wall-run height is always a live one (safe things look safe). Numbers: data/enemies/gilded_sentinel.tres
## (GildedSentinelTuning); DESIGN-TBD, docs/questions/c4.md.
## - Where: a wall enemy (`side`, not a lane). Its niche goes into the wall, and the statue stands in it
##   with its front just behind the wall face, so nothing of it reaches out over the wall-run path (a
##   wall runner's body lies along the wall face): only its swing does. The Golden Zone's skins open the
##   niche in their walls (GoldenSkin.note_wall_enemies, GoldenStatue.recess); in any other skin (quick
##   play) it stands in front of the wall in the kit's niche as a review stand-in, its hitboxes the same.
##   Task H1 (GDD §9.11, owner, October 8, 2026): it stands almost flush with the face (placed by its real
##   outline, reach_out()), in a shallower, wider niche whose inside is lit bronze, not black (the skins draw
##   it with GoldenStatue.recess(lit)); its warning is 0.6 s. Nothing of it goes in front of the face.
## - The attack, once, as the runner approaches: when they are warning_seconds (plus a moment) at their
##   speed from the stretch it guards, its eyes flare, stone grinds (gilded_sentinel_grind) and the red
##   marks of what it will cut light up: a band of its wall (GildedSentinelTuning.band, the heights around
##   the free wall-entry height) and the outer floor lane beside it, filling toward the runner; it draws
##   its halberd back. Then it swings (gilded_sentinel_swing) across its wall section and the outer lane
##   as the runner reaches the stretch (a slower runner: it holds, raised, up to hold_max_seconds): for
##   strike_seconds the cut is live: the band on its wall, from the face out over a wall runner's body,
##   and the outer lane from the floor up to the band's top (above any jump). A Sentinel that swings twice
##   (params.swings 2) cuts the stretch before its niche, then swings back across the stretch past it.
## - Dodges: on the wall, be above or below the band (entering the wall right before it puts the runner
##   in it; a jump onto the wall or a ramp passes above, an early entry below, GDD §3); on the floor, be
##   out of the outer lane. The cut never reaches the lane beside it, nor a wall runner above or below.
## - Protection (DamageRules, declared properties only): its cut is an enemy attack, so armor or the
##   shield blocks it ("armor blocks the halberd"); the dash passes through it unharmed (dash_kills off:
##   a cut isn't its body, as the Resonator's wave isn't). Its body is solid (GDD §9.11, proposed): a
##   `body` hitbox where the statue stands, which armor doesn't stop (nothing in play reaches into the
##   niche, though).
## - Killing it: weapons (17 laser tier 1 shots: health 15 and G4's tier 1 rule) or a kick (GDD §9.11,
##   proposed: a stomp from a wall jump): a wall jump made right by its head, on its wall, stomps its
##   helmet (its `top` hitbox through DamageRules: defeated, the runner bounces). A wall jump leaps out
##   toward the lanes and never comes down on a statue in the wall, so the kick is the push-off itself
##   (DESIGN-TBD, docs/questions/c4.md). Defeated, its eyes go dark and it slumps in its niche.
## - Big attacks take turns (GDD §9): its attack counts as one, from its eyes' flare until its last swing
##   is over (is_major_attack_active), so the others wait for it. It can't wait itself (a statue gets one
##   chance as the runner passes), so it claims its turn claim_seconds before its warning (claiming(): it
##   reports itself from then on, and another type's attack that gets ready meanwhile waits), then asks
##   the director as its warning would start: if another type's big attack begun before its claim is
##   still on, it lets the runner pass (no warning, no swing), so its cut never overlaps another's. The
##   generator keeps the Octodog's planned charges and floor cuts off its stretch, and every big attack
##   off the level's first (gilded_sentinel_rules.gd), so that one always swings (DESIGN-TBD,
##   docs/questions/c4.md).
## - Cheap: the statue is one mesh of two surfaces (the gold, and the eyes' own glowing material), its
##   frames baked once from the kit and shared by every Sentinel; the marks and slashes are a few quads;
##   it does constant work a frame (where the runner is against its trigger) and hears a wall jump as an
##   event (Player.movement_event).
## Spawn params: swings (1 or 2; default 1), health (float; tests).

enum State { IDLE, WARNING, HOLD, STRIKE, RECOVER, DONE, DOWN }

const STATE_NAMES: PackedStringArray = ["idle", "warning", "hold", "strike", "recover", "done", "down"]
const CUT_NAME: String = "Gilded Sentinel's halberd"
## Enemy-attack red (every zone): the eyes, the marks and the slashes.
const RED := Color(1.0, 0.12, 0.08)
## The statue's poses (GoldenStatue's joints, in degrees; see its notes). At rest it holds its halberd
## upright at its side, its forearm drawn back and the blade turned out along the wall, so nothing of it
## reaches far forward and the whole statue fits in its niche; the swing's wind-up and
## strike are the kit's (D6a's proposals for this task): drawn back high over its right shoulder, then
## chopped down in front of it and across toward its left (toward the approaching runner on either wall:
## the statue is mirrored on the left wall). Defeated, it slumps.
const POSE_REST: Dictionary = {"shoulder_r": Vector3(-8.0, 0.0, 8.0), "elbow_r": 92.0, "grip": Vector3(0.0, 90.0, 84.0),
	"shoulder_l": Vector3(4.0, 0.0, 7.0), "elbow_l": 14.0, "head": Vector3(4.0, 0.0, 0.0)}
const POSE_RAISE: Dictionary = {"shoulder_r": Vector3(150.0, 20.0, 18.0), "elbow_r": 40.0, "grip": Vector3(60.0, 0.0, 0.0),
	"shoulder_l": Vector3(30.0, 0.0, 12.0), "elbow_l": 40.0, "head": Vector3(-4.0, -12.0, 0.0)}
const POSE_STRIKE: Dictionary = {"shoulder_r": Vector3(55.0, 30.0, -5.0), "elbow_r": 20.0, "grip": Vector3(200.0, 0.0, 0.0),
	"shoulder_l": Vector3(40.0, 10.0, 10.0), "elbow_l": 50.0, "head": Vector3(14.0, 18.0, 0.0)}
const POSE_HUSK: Dictionary = {"shoulder_r": Vector3(2.0, 0.0, 6.0), "elbow_r": 16.0, "grip": Vector3(104.0, 0.0, 22.0),
	"shoulder_l": Vector3(2.0, 0.0, 6.0), "elbow_l": 8.0, "head": Vector3(34.0, 6.0, 0.0)}
## Frames baked along each move (both ends included): rest to wind-up, the swing, the recovery.
const FRAMES: int = 8
enum Move { RAISE, SWING, RECOVER, HUSK }
## Seconds the halberd takes to sweep through a swing (the cut is live for strike_seconds from its start).
## (The wind-up at the end of the warning is the tuning's raise_seconds(), a share of the warning.)
const SWEEP_SECONDS: float = 0.16
## How much lighter the gold of the statue is than the kit's: the decorative statues' albedo lift
## (GoldenSkin.decorative_statue_mesh), so the live one reads against its niche as they do against theirs. It
## is albedo only: gold never glows in the Golden Zone (GDD §5), only the eyes do.
const STATUE_LIFT: float = 0.08
## The eyes: their glow at rest, during the warning (rising to full) and once it's down (dark). DESIGN-TBD
## (docs/questions/h1.md): a little more at rest than first built (0.9), so the live statue is picked out early.
const EYES_IDLE: float = 1.6
const EYES_FULL: float = 6.0
## The marks' brightness: at the warning's start, at its end, and a swing's flash (softer with Reduced
## flashing); how fast a flash and the marks fade.
const MARK_START: float = 0.35
const MARK_FULL: float = 1.0
const FLASH: float = 1.6
const FLASH_REDUCED: float = 0.7
const FADE_SECONDS: float = 0.35
## How far the marks and slashes reach past the hitboxes (GDD §3: hitboxes smaller than the visuals).
const MARK_MARGIN: float = 0.06
## The husk lingers until the runner is this far past it.
const HUSK_KEEP: float = 40.0

## Baked statue frames, shared by every Sentinel: {[kit, scale, mirrored] key: Array of [move][frame]}.
static var _frames: Dictionary = {}
## How far a frame reaches out of its wall and into it when turned (reach_out): {[mesh, turn, side]: Vector2}.
static var _reaches: Dictionary = {}
## The statue kit outside the Golden Zone's skins (quick play's review stand-in).
static var _plain_kit: GoldenStatue = null
## The cut's shader (cut_shader()) and the niche glow's (_niche_material()).
static var _cut_shader: Shader = null
static var _niche_shader: Shader = null

var tune: GildedSentinelTuning
var side: int = 1
var swings: int = 1
var state: State = State.IDLE
## What happened: [event, level time, player distance]. Events: warning, hold, swing (each, with its
## index), recover, done, pass (another big attack was on: it let the runner pass), kick, down.
var history: Array = []
## Every sound it played: [name, level time].
var sounds: Array = []
## The eyes' flare (0 at rest, 1 at full) and each swing's cut being live, for tests and the showcase.
var flare: float = 0.0

var _at: float = 0.0
var _band := Vector2.ZERO
var _lane_end: float = 0.0
var _state_time: float = 0.0
var _swing_started: Array[float] = []
var _clock: float = 0.0
## Its swings' hitboxes: [[wall band, outer lane], ...].
var _cuts: Array = []
var _body: Hazard
var _top: Hazard
var _statue: MeshInstance3D
var _statue_root: Node3D
var _eyes: StandardMaterial3D
var _marks: Array[MeshInstance3D] = []
## The eyes' red light in the niche (its far side and back), rising with their flare: what a runner sees
## of the warning from far down the street, where the wall is seen almost edge-on.
var _glow: MeshInstance3D
var _slashes: Array[MeshInstance3D] = []
var _mark_strength: float = 0.0
var _mark_fill: float = 0.0
var _flashes: Array[float] = []
var _frame_key: Vector2i = Vector2i(-1, -1)
var _move_set: Array = []
var _husk: bool = false
var _down_t: float = 0.0


## A Gilded Sentinel's look, for EnemyDirector.warm_up (which frees it) and ShaderWarmup (task PERF1):
## bakes the statue's frames for both walls with the skin's kit (the first Sentinel on each wall baked
## them in its spawn's frame) and shows the statue with its eyes, and a strip of its cut's red marks
## (their shader was first drawn at the first warning).
static func warm_up(world: RunWorld, _entry: Dictionary) -> Node:
	var tune := EnemyDirector.tuning_for("gilded_sentinel") as GildedSentinelTuning
	if tune == null:
		tune = GildedSentinelTuning.new()
	var kit: GoldenStatue = (world.skin as GoldenSkin).statues() if world.skin is GoldenSkin else plain_kit()
	var root := Node3D.new()
	for mirrored: bool in [false, true]:
		var statue := MeshInstance3D.new()
		statue.mesh = (frames_for(kit, tune.statue_scale, mirrored)[Move.RAISE] as Array)[0]
		statue.set_surface_override_material(1, _eyes_material())
		statue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(statue)
	# The marks' own vertex format (positions and UVs, _strip), so the sample matches what they draw.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_strip(st, Vector3.ZERO, Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0))
	var cut := MeshInstance3D.new()
	cut.mesh = st.commit()
	cut.material_override = _cut_material()
	cut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cut)
	# The niche's glow has a shader of its own (only in the Golden Zone's skins, which open the niche).
	var glow := MeshInstance3D.new()
	glow.mesh = cut.mesh
	glow.material_override = _niche_material()
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	return root


func _build() -> void:
	tune = tuning_res as GildedSentinelTuning if tuning_res is GildedSentinelTuning else GildedSentinelTuning.new()
	display_name = "Gilded Sentinel"
	# The dash passes through its cut, as through the Resonator's wave (a cut isn't its body); nothing
	# reaches its body in its niche.
	dash_kills = false
	var p: Dictionary = spawn.get("params", {})
	if not (tuning_res is EnemyTuning):
		max_health = tune.health_early
		score_value = tune.score_value
	if p.has("health"):
		max_health = float(p["health"])
	side = -1 if int(spawn.get("side", 1)) < 0 else 1
	swings = clampi(int(p.get("swings", 1)), 1, 2)
	_at = float(spawn.get("at", 0.0))
	position = Vector3(side * world.geo.wall_x(), 0.0, TrackGeometry.world_z(_at))
	_band = tune.band(world.tuning)
	_lane_end = world.tuning.wall_margin + world.tuning.lane_width - tune.lane_margin
	_build_statue()
	_build_hitboxes()
	_build_marks()
	if world.player != null:
		world.player.movement_event.connect(_on_player_event)


# --- Building -------------------------------------------------------------------------------

## The statue in its niche: one mesh (the gold, and the eyes on a material of their own), turned toward
## the approaching runner, its front statue_inset behind the wall face. Outside the Golden Zone's skins,
## which open the niche in their walls, it stands in front of the wall in the kit's niche instead.
func _build_statue() -> void:
	var opens: bool = world.skin is GoldenSkin
	var kit: GoldenStatue = (world.skin as GoldenSkin).statues() if opens else plain_kit()
	_move_set = frames_for(kit, tune.statue_scale, side < 0)
	_statue_root = Node3D.new()
	_statue_root.name = "Statue"
	add_child(_statue_root)
	var turn := Basis(Vector3.UP, -side * (PI * 0.5 - tune.statue_turn))
	var rest: ArrayMesh = (_move_set[Move.RAISE] as Array)[0]
	# How far the rest pose reaches toward the street and back into the wall from the statue's origin.
	var reach: Vector2 = reach_out(rest, turn, side)
	var depth: float = tune.statue_inset + reach.x if opens else -(reach.y + 0.04)
	_statue_root.transform = Transform3D(turn, Vector3(side * depth, tune.niche_sill, 0.0))
	_statue = MeshInstance3D.new()
	_statue.name = "Body"
	_statue.mesh = rest
	_statue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_eyes = _eyes_material()
	_statue.set_surface_override_material(1, _eyes)
	_statue_root.add_child(_statue)
	_frame_key = Vector2i(Move.RAISE, 0)
	if opens:
		_glow = MeshInstance3D.new()
		_glow.name = "NicheGlow"
		_glow.mesh = _niche_glow_mesh()
		_glow.material_override = _niche_material()
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glow.visible = false
		add_child(_glow)
	if not opens:
		var niche := MeshBatch.new()
		niche.layer(kit.material).append(kit.niche(tune.niche_width, tune.niche_height),
			Transform3D(Basis(Vector3.UP, -side * PI * 0.5), Vector3(0.0, tune.niche_sill, 0.0)))
		niche.commit(self, "Niche")


## How far a statue mesh, turned by `turn`, reaches toward the street (x) and back into the wall (y) from
## its origin, along the wall's normal on wall `side`: its real vertices (the bounds of a turned figure's
## box overstate it by a hand's breadth, and the statue stands that much further back for it). Measured
## once for each frame and turn: every Sentinel on a wall shares them.
static func reach_out(mesh: Mesh, turn: Basis, side: int) -> Vector2:
	var key: Array = [mesh.get_instance_id(), turn, side]
	if _reaches.has(key):
		return _reaches[key]
	var out := Vector2(-INF, -INF)
	var street := Vector3(-side, 0.0, 0.0)
	for s: int in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v: Vector3 in verts:
			var along: float = (turn * v).dot(street)
			out.x = maxf(out.x, along)
			out.y = maxf(out.y, -along)
	_reaches[key] = out
	return out


## Its hitboxes: the body and the helmet in the niche (behind the wall face), and for each swing the
## band on its wall and the outer lane over its stretch, off until it swings.
func _build_hitboxes() -> void:
	var s: float = tune.statue_scale
	var tall: float = tune.statue_height()
	var deep: float = maxf(tune.niche_depth - 0.1, 0.2)
	_body = add_hitbox(&"body", Vector3(deep, tall - 0.45 * s, 0.8 * s),
		Vector3(side * (deep * 0.5 + 0.02), tune.niche_sill + (tall - 0.45 * s) * 0.5, 0.0))
	_top = add_hitbox(&"top", Vector3(deep, 0.45 * s, 0.6 * s),
		Vector3(side * (deep * 0.5 + 0.02), tune.niche_sill + tall - 0.225 * s, 0.0))
	# Only the kick reaches it (never a dash): a kick while dashing still stomps (DamageRules' dash rule
	# would otherwise pass through it, dash_kills being off).
	_top.dash_passes = false
	for i: int in swings:
		var stretch: Vector2 = tune.swing_stretch(_at, swings, i)
		var length: float = stretch.y - stretch.x
		var z: float = -((stretch.x + stretch.y) * 0.5 - _at)
		var wall: Hazard = add_hitbox(&"attack", Vector3(tune.wall_reach, _band.y - _band.x, length),
			Vector3(-side * tune.wall_reach * 0.5, (_band.x + _band.y) * 0.5, z), true)
		var lane_width: float = _lane_end - tune.wall_reach
		var lane: Hazard = add_hitbox(&"attack", Vector3(lane_width, _band.y, length),
			Vector3(-side * (tune.wall_reach + lane_width * 0.5), _band.y * 0.5, z), true)
		for h: Hazard in [wall, lane]:
			h.hazard_name = CUT_NAME
			h.set_enabled(false)
		_cuts.append([wall, lane])
		_swing_started.append(-1.0)
		_flashes.append(0.0)


## The red marks of each swing's cut (the band on its wall, the outer lane's floor) and its slash, a
## little larger than its hitboxes, hidden until the warning.
func _build_marks() -> void:
	for i: int in swings:
		var stretch: Vector2 = tune.swing_stretch(_at, swings, i)
		var mark := MeshInstance3D.new()
		mark.name = "Marks%d" % i
		mark.mesh = _marks_mesh(stretch)
		mark.material_override = _cut_material()
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.visible = false
		add_child(mark)
		_marks.append(mark)
		var slash := MeshInstance3D.new()
		slash.name = "Slash%d" % i
		slash.mesh = _slash_mesh(stretch)
		slash.material_override = _cut_material()
		slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		slash.visible = false
		add_child(slash)
		_slashes.append(slash)


## The eyes' own material at rest (each Sentinel flares its own, _process).
static func _eyes_material() -> StandardMaterial3D:
	var eyes := StandardMaterial3D.new()
	eyes.albedo_color = Color(0.12, 0.02, 0.02)
	eyes.emission_enabled = true
	eyes.emission = RED
	eyes.emission_energy_multiplier = EYES_IDLE
	return eyes


static func _cut_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = cut_shader()
	return m


## The niche glow's material: its own shader (a red tint over the lit niche, not red added to it).
static func _niche_material() -> ShaderMaterial:
	if _niche_shader == null:
		_niche_shader = load("res://scripts/enemies/gilded_sentinel_niche.gdshader") as Shader
	var m := ShaderMaterial.new()
	m.shader = _niche_shader
	return m


## The marks' and slashes' shader, loaded once and kept (task PERF1: loaded afresh, it was parsed again by
## the first Sentinel after the level's warm-up had let it go).
static func cut_shader() -> Shader:
	if _cut_shader == null:
		_cut_shader = load("res://scripts/enemies/gilded_sentinel_cut.gdshader") as Shader
	return _cut_shader


## A strip in local space: from `a` along `along` (the stretch) and `across`; UV.x 0 at the end nearest
## the approaching runner, UV.y across.
static func _strip(st: SurfaceTool, a: Vector3, along: Vector3, across: Vector3) -> void:
	var corners: Array[Vector3] = [a, a + across, a + across + along, a + along]
	var uv: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0)]
	for k: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[k])
		st.add_vertex(corners[k])


## The marks of one swing over `stretch`: the band on its wall (on the face) and the outer lane's floor.
func _marks_mesh(stretch: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var near_z: float = -(stretch.x - MARK_MARGIN - _at)
	var along := Vector3(0.0, 0.0, -(stretch.y - stretch.x + MARK_MARGIN * 2.0))
	var out := Vector3(-side, 0.0, 0.0)
	_strip(st, Vector3(out.x * 0.015, _band.x - MARK_MARGIN, near_z), along,
		Vector3(0.0, _band.y - _band.x + MARK_MARGIN * 2.0, 0.0))
	_strip(st, Vector3(out.x * (tune.wall_reach - MARK_MARGIN), 0.03, near_z), along,
		out * (_lane_end - tune.wall_reach + MARK_MARGIN * 2.0))
	return st.commit()


## The niche's far side (the one a runner coming down the street sees, edge-on) and its back, a few
## centimetres inside, where the eyes' light falls.
func _niche_glow_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inward := Vector3(side, 0.0, 0.0)
	var y0: float = tune.niche_sill + 0.08
	var tall: float = tune.niche_height - 0.16
	var deep: float = tune.niche_depth - 0.04
	var far_z: float = -(tune.niche_width * 0.5 - 0.03)
	# The far side: from the face into the wall (UV.x 0 at the face), UV.y up it.
	_strip(st, Vector3(side * 0.02, y0, far_z), inward * (deep - 0.02), Vector3(0.0, tall, 0.0))
	# The back.
	_strip(st, Vector3(side * deep, y0, far_z), Vector3(0.0, 0.0, tune.niche_width - 0.06), Vector3(0.0, tall, 0.0))
	return st.commit()


## The slash of one swing over `stretch`: a sheet along it whose section runs from the band's top at the
## wall, down through the band's bottom where the cut leaves the wall-run path, to the floor at the outer
## lane's edge: the halberd's sweep through the band and across the lane.
func _slash_mesh(stretch: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var near_z: float = -(stretch.x - MARK_MARGIN - _at)
	var far_z: float = -(stretch.y + MARK_MARGIN - _at)
	var pts: Array[Vector2] = []
	var a := Vector2(0.03, _band.y + MARK_MARGIN)
	var b := Vector2(tune.wall_reach, _band.x)
	var c := Vector2(_lane_end + MARK_MARGIN, 0.04)
	var steps: int = 8
	for k: int in steps + 1:
		var t: float = float(k) / steps
		pts.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	for k: int in steps:
		var p0: Vector2 = pts[k]
		var p1: Vector2 = pts[k + 1]
		var v0: float = float(k) / steps
		var v1: float = float(k + 1) / steps
		var q: Array[Vector3] = [Vector3(-side * p0.x, p0.y, near_z), Vector3(-side * p1.x, p1.y, near_z),
			Vector3(-side * p1.x, p1.y, far_z), Vector3(-side * p0.x, p0.y, far_z)]
		var uv: Array[Vector2] = [Vector2(0.0, v0), Vector2(0.0, v1), Vector2(1.0, v1), Vector2(1.0, v0)]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[i])
			st.add_vertex(q[i])
	return st.commit()


# --- The statue's frames (baked once, shared) ---------------------------------------------------

## The kit used outside the Golden Zone's skins.
static func plain_kit() -> GoldenStatue:
	if _plain_kit == null:
		_plain_kit = GoldenStatue.new()
	return _plain_kit


## The statue's frames for `kit` at `scale` (mirrored for the left wall): [move][frame] ArrayMeshes, each
## the whole statue (no pedestal: the niche's floor is its base) with the eyes as a second surface left
## without a material (each Sentinel gives its own). Baked once and shared.
static func frames_for(kit: GoldenStatue, scale: float, mirrored: bool) -> Array:
	var key: Array = [kit.get_instance_id(), snappedf(scale, 0.001), mirrored]
	if _frames.has(key):
		return _frames[key]
	var moves: Array = []
	for move: int in [Move.RAISE, Move.SWING, Move.RECOVER]:
		var from: Dictionary = POSE_REST if move == Move.RAISE else (POSE_RAISE if move == Move.SWING else POSE_STRIKE)
		var to: Dictionary = POSE_RAISE if move == Move.RAISE else (POSE_STRIKE if move == Move.SWING else POSE_REST)
		var frames: Array[ArrayMesh] = []
		for f: int in FRAMES:
			frames.append(_bake(kit, scale, mirrored, GoldenStatue.blend_poses(from, to, float(f) / (FRAMES - 1))))
		moves.append(frames)
	var husk: Array[ArrayMesh] = [_bake(kit, scale, mirrored, POSE_HUSK)]
	moves.append(husk)
	_frames[key] = moves
	return moves


static func _bake(kit: GoldenStatue, scale: float, mirrored: bool, pose: Dictionary) -> ArrayMesh:
	var batch := MeshBatch.new()
	var gold: MeshLayer = batch.layer(kit.material)
	var eyes: MeshLayer = batch.layer(null)
	var base := Transform3D(Basis.from_scale(Vector3(-scale if mirrored else scale, scale, scale)), Vector3.ZERO)
	var xforms: Dictionary = GoldenStatue.part_transforms(pose, false)
	for which: int in xforms:
		if which == GoldenStatue.Part.PEDESTAL:
			continue
		var into: MeshLayer = eyes if which == GoldenStatue.Part.EYES else gold
		into.append(kit.part(which), base * (xforms[which] as Transform3D))
	# The gold a little lighter, as the decorative statues' (STATUE_LIFT): the figure reads against its niche from
	# far down the street.
	for i: int in gold.colors.size():
		if roundi(gold.uv2s[i].x) == MeshKit.PAT_GOLD:
			var c: Color = gold.colors[i]
			gold.colors[i] = Color(minf(c.r + STATUE_LIFT, 1.0), minf(c.g + STATUE_LIFT, 1.0), minf(c.b + STATUE_LIFT, 1.0), c.a)
	return batch.to_mesh()


func _show_frame(move: Move, t: float) -> void:
	var f: int = 0 if move == Move.HUSK else clampi(roundi(clampf(t, 0.0, 1.0) * (FRAMES - 1)), 0, FRAMES - 1)
	var key := Vector2i(move, f)
	if key == _frame_key:
		return
	_frame_key = key
	_statue.mesh = (_move_set[move] as Array)[f]


# --- Behaviour ------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if world == null:
		return
	_clock += delta
	if alive:
		_tick(delta)


func _tick(delta: float) -> void:
	_state_time += delta
	var pl: Player = world.player
	var v: float = maxf(pl.speed, 1.0)
	var d: float = pl.distance
	match state:
		State.IDLE:
			if d > tune.guarded_stretch(_at, swings).y:
				_set_state(State.DONE)
				_log("done")
			elif pl.alive and pl.running and d >= tune.warn_at(_at, swings, v):
				# GDD §9: big attacks take turns. A statue can't wait for one (the runner is gone by then):
				# its claim has held back the attacks that got ready since; with one begun before its claim
				# still on, it lets the runner pass instead of overlapping it.
				if world.director.major_attack_blocked(self):
					world.director.give_up_turn(self)
					_set_state(State.DONE)
					_log("pass")
				else:
					_start_warning()
		State.WARNING:
			if _state_time >= tune.warning_seconds:
				if d >= _trigger(0, v):
					_swing(0)
				else:
					_set_state(State.HOLD)
					_log("hold")
		State.HOLD:
			if d >= _trigger(0, v) or _state_time >= tune.hold_max_seconds:
				_swing(0)
		State.STRIKE:
			_update_swings(d, v)
		State.RECOVER:
			if _state_time >= tune.recover_seconds:
				_set_state(State.DONE)
				_log("done")


func _set_state(next: State) -> void:
	state = next
	_state_time = 0.0


## Where the runner is when swing `index` starts: strike_lead_seconds short of its stretch.
func _trigger(index: int, speed: float) -> float:
	return tune.swing_stretch(_at, swings, index).x - tune.strike_lead_seconds * speed


func _start_warning() -> void:
	_set_state(State.WARNING)
	_log("warning")
	_sound(&"gilded_sentinel_grind")


func _swing(index: int) -> void:
	if state != State.STRIKE:
		_set_state(State.STRIKE)
	_swing_started[index] = _clock
	_flashes[index] = 1.0
	for h: Hazard in _cuts[index]:
		h.set_enabled(true)
	history.append(["swing", world.level_time(), world.player.distance, index])
	_sound(&"gilded_sentinel_swing")


## Each live cut goes off strike_seconds after its swing started; a second swing starts once the first
## has swept through and the runner reaches its stretch (or it has held as long as it may); once every
## swing is over it recovers.
func _update_swings(d: float, v: float) -> void:
	for i: int in swings:
		var start: float = _swing_started[i]
		if start >= 0.0 and _clock - start >= tune.strike_seconds and (_cuts[i][0] as Hazard).is_active():
			for h: Hazard in _cuts[i]:
				h.set_enabled(false)
	var last: int = -1
	for i: int in swings:
		if _swing_started[i] >= 0.0:
			last = i
	if last + 1 < swings:
		var since: float = _clock - _swing_started[last]
		if since >= SWEEP_SECONDS and (d >= _trigger(last + 1, v) or since >= SWEEP_SECONDS + tune.hold_max_seconds):
			_swing(last + 1)
		return
	if _clock - _swing_started[last] >= tune.strike_seconds:
		_set_state(State.RECOVER)
		_log("recover")


## GDD §9: its attack is a big one, from its eyes' flare until its last swing's cut is over, and it
## claims its turn claim_seconds before that (claiming()), so the others hold theirs meanwhile.
func is_major_attack_active() -> bool:
	if not alive:
		return false
	return state == State.WARNING or state == State.HOLD or state == State.STRIKE \
		or (state == State.IDLE and claiming())


## True while it claims its turn before its warning: the runner, running, is within claim_seconds (at
## their speed) of where its warning starts. It stays true until the warning starts (or it lets the
## runner pass), so its own ask then finds its turn already held.
func claiming() -> bool:
	var pl: Player = world.player if world != null else null
	if pl == null or not pl.alive or not pl.running or state != State.IDLE:
		return false
	var v: float = maxf(pl.speed, 1.0)
	return pl.distance >= tune.warn_at(_at, swings, v) - tune.claim_seconds * v \
		and pl.distance <= tune.guarded_stretch(_at, swings).y


## True while swing `index`'s cut is live (tests).
func cutting(index: int = -1) -> bool:
	for i: int in swings:
		if (index < 0 or i == index) and (_cuts[i][0] as Hazard).is_active():
			return true
	return false


# --- The kick (a stomp from a wall jump, GDD §9.11, proposed) --------------------------------------

## A wall jump made right by its head, on its wall, kicks its helmet: DamageRules resolves it as a stomp
## on its `top` (the runner bounces, it's defeated). See can_kick().
func _on_player_event(kind: StringName) -> void:
	if kind != &"wall_jump" or not alive or world == null:
		return
	var pl: Player = world.player
	if can_kick(pl.wall_side, pl.h, pl.distance, pl.speed * get_physics_process_delta_time()):
		_log("kick")
		pl.receive_hit(_top, true)


## True if a runner who wall-jumps off wall `wall_side` with their feet at height `h` on it, at track
## distance `d` (running `step` metres a frame), is right by its head: on its wall, from kick_below under
## its helmet's base to kick_above over its crest, and their hitbox within kick_along of the statue
## along the track (a frame's run either way).
func can_kick(wall_side: int, h: float, d: float, step: float = 0.0) -> bool:
	if wall_side != side:
		return false
	var s: float = tune.statue_scale
	var crest: float = tune.niche_sill + tune.statue_height()
	var head: float = tune.niche_sill + GoldenStatue.NECK.y * s
	if h < head - tune.kick_below or h > crest + tune.kick_above:
		return false
	var reach: float = 0.4 * s + tune.kick_along + world.tuning.hurtbox_size.z * 0.5 + absf(step)
	return absf(d - _at) <= reach


# --- Defeat ---------------------------------------------------------------------------------------

func _on_defeated(cause: StringName) -> void:
	_set_state(State.DOWN)
	_husk = true
	_log("down")
	for i: int in swings:
		_flashes[i] = 0.0
	_mark_strength = 0.0
	var chest: Vector3 = aim_point()
	world.play_sfx_at(&"gilded_sentinel_break", chest)
	sounds.append([&"gilded_sentinel_break", world.level_time()])
	world.effects.burst(chest, Color(0.95, 0.78, 0.42), 26, 0.8)
	world.effects.burst(chest + Vector3(0.0, 0.7, 0.0), Color(0.86, 0.84, 0.8), 14, 0.6)
	world.effects.shake(0.08, 0.18)
	if cause == &"stomp":
		_log("stomped")


func aim_point() -> Vector3:
	var depth: float = tune.statue_inset + 0.25 * tune.statue_scale
	return global_position + Vector3(side * depth, tune.niche_sill + tune.statue_height() * 0.6, 0.0)


func hit_radius() -> float:
	return 0.6


func _process(delta: float) -> void:
	if world == null or _statue == null:
		return
	if _husk:
		_down_t += delta
		_show_frame(Move.HUSK, 0.0)
		_eyes.emission_energy_multiplier = 0.0
		_eyes.albedo_color = Color(0.05, 0.04, 0.04)
		if _glow != null:
			_glow.visible = false
		_fade_marks(delta)
		if world.player != null and world.player_distance() - track_distance() > HUSK_KEEP:
			queue_free()
		return
	var reduced: bool = Settings.flashing_reduced
	match state:
		State.IDLE, State.DONE:
			flare = move_toward(flare, 0.0, delta * 1.5)
			_show_frame(Move.RAISE, 0.0)
			_fade_marks(delta)
		State.WARNING:
			var k: float = clampf(_state_time / tune.warning_seconds, 0.0, 1.0)
			flare = k
			var raise: float = maxf(tune.raise_seconds(), 0.01)
			var wind: float = clampf((_state_time - (tune.warning_seconds - raise)) / raise, 0.0, 1.0)
			_show_frame(Move.RAISE, smoothstep(0.0, 1.0, wind))
			_mark_strength = lerpf(MARK_START, MARK_FULL, k)
			_mark_fill = smoothstep(0.0, 0.85, k)
		State.HOLD:
			flare = 1.0
			_show_frame(Move.RAISE, 1.0)
			_mark_strength = MARK_FULL
			_mark_fill = 1.0
		State.STRIKE:
			flare = 1.0
			_mark_strength = MARK_FULL
			_mark_fill = 1.0
			var last: int = 0
			for i: int in swings:
				if _swing_started[i] >= 0.0:
					last = i
			var t: float = clampf((_clock - _swing_started[last]) / SWEEP_SECONDS, 0.0, 1.0)
			# The second swing goes back the way the first came.
			_show_frame(Move.SWING, smoothstep(0.0, 1.0, t) if last % 2 == 0 else 1.0 - smoothstep(0.0, 1.0, t))
		State.RECOVER:
			var k: float = clampf(_state_time / tune.recover_seconds, 0.0, 1.0)
			flare = 1.0 - k
			if swings % 2 == 0:
				_show_frame(Move.RAISE, 1.0 - smoothstep(0.0, 1.0, k))
			else:
				_show_frame(Move.RECOVER, smoothstep(0.0, 1.0, k))
			_fade_marks(delta)
	# The eyes flare: a steady rise (Reduced flashing), or throbbing faster as the swing nears.
	var throb: float = 1.0
	if (state == State.WARNING or state == State.HOLD) and not reduced:
		throb = 0.8 + 0.2 * sin(TAU * _clock * lerpf(2.5, 6.0, flare))
	_eyes.emission_energy_multiplier = lerpf(EYES_IDLE, EYES_FULL, flare) * throb
	if _glow != null:
		_glow.visible = flare > 0.01
		var gm := _glow.material_override as ShaderMaterial
		gm.set_shader_parameter(&"strength", flare * throb)
	_update_marks(delta, reduced)


func _fade_marks(delta: float) -> void:
	_mark_strength = move_toward(_mark_strength, 0.0, delta / FADE_SECONDS)


func _update_marks(delta: float, reduced: bool) -> void:
	var peak: float = FLASH_REDUCED if reduced else FLASH
	for i: int in swings:
		var mark: MeshInstance3D = _marks[i]
		var slash: MeshInstance3D = _slashes[i]
		# A swing's flash rises at once and fades over its cut and FADE_SECONDS (one smooth fall, slower
		# with Reduced flashing).
		var live: bool = _swing_started[i] >= 0.0 and _clock - _swing_started[i] < tune.strike_seconds and alive
		var fade_time: float = tune.strike_seconds + FADE_SECONDS * (1.6 if reduced else 1.0)
		if not live:
			_flashes[i] = move_toward(_flashes[i], 0.0, delta / fade_time)
		var flash: float = _flashes[i] * peak
		mark.visible = _mark_strength > 0.001 or flash > 0.001
		slash.visible = flash > 0.001
		var mm := mark.material_override as ShaderMaterial
		mm.set_shader_parameter(&"strength", _mark_strength)
		mm.set_shader_parameter(&"fill", _mark_fill)
		mm.set_shader_parameter(&"flash", flash * 0.6)
		var sm := slash.material_override as ShaderMaterial
		sm.set_shader_parameter(&"strength", 0.0)
		sm.set_shader_parameter(&"flash", flash)


func _log(event: String) -> void:
	history.append([event, world.level_time(), world.player.distance if world.player != null else 0.0])


## Plays one of its sounds for everyone to hear (the grind is its warning, heard wherever the runner is)
## and notes it.
func _sound(sound: StringName) -> void:
	world.play_sfx(sound)
	sounds.append([sound, world.level_time()])


# --- For tests, the showcase and the skins -------------------------------------------------------

## The band of wall-run heights its halberd cuts (Vector2(bottom, top)).
func band() -> Vector2:
	return _band


## Its swings' hitboxes, [[wall band, outer lane], ...].
func cut_boxes() -> Array:
	return _cuts


func body_box() -> Hazard:
	return _body


func top_box() -> Hazard:
	return _top


func state_name() -> String:
	return STATE_NAMES[state]


## The events in order, as [event, level time] (tests).
func events(names: PackedStringArray) -> Array:
	var out: Array = []
	for h: Array in history:
		if names.has(String(h[0])):
			out.append([h[0], h[1]])
	return out


## Where the niche of a Sentinel entry opens in its wall: Rect2 over (track distance, height), from its
## sill to the top of its arch. The Golden Zone's skins open it (GoldenSkin.note_wall_enemies).
static func niche_rect(entry: Dictionary) -> Rect2:
	var t := EnemyDirector.tuning_for("gilded_sentinel") as GildedSentinelTuning
	if t == null:
		t = GildedSentinelTuning.new()
	var at: float = float(entry.get("at", 0.0))
	return Rect2(Vector2(at - t.niche_width * 0.5, t.niche_sill), Vector2(t.niche_width, t.niche_height))


## How deep a Sentinel's niche goes into the wall.
static func niche_depth() -> float:
	var t := EnemyDirector.tuning_for("gilded_sentinel") as GildedSentinelTuning
	return t.niche_depth if t != null else GildedSentinelTuning.new().niche_depth
