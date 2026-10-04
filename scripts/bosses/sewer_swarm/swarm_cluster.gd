class_name SwarmCluster
extends BossPart
## One of the Sewer Swarm's clusters (GDD §10: "4-5 gameplay entities ('clusters'), each rendered as many
## screech-variant creatures using MultiMesh plus a shader for per-creature motion"). It is one simulated
## entity: a boss part with health of its own (shares_health off) that is a swarm (is_swarm: GDD §8, the
## heavy missile's bonus, its splash included), declared, never special-cased (CLAUDE.md principle 8). Its
## hundreds of creatures are its SwarmCrowd, drawn in one call from the encounter's pool; they have no
## collision at all: the cluster hurts only through its hitboxes, its charge's and its mound's.
##
## Its stages (Stage; SewerSwarm and SwarmSurges move it, it draws itself):
## - FORMING, WAITING: risen at the roadside (its crowd heaped against a wall's foot and clinging to it),
##   pacing the runner at its station ahead; weapons don't target it (it's part of the horde). The screeches
##   clinging to the wall are an enemy attack (owner's request, docs/USER_REQUESTS.md: any swarm on a wall
##   hurts): its mound's hitboxes (MOUND_BOXES, wall_hit_depth deep off the wall, a little inside the
##   clinging screeches' ridge) are live while enough of them are shown there (MOUND_SHOWN), and a runner on
##   the wall touching them is knocked off it (SewerSwarm.repel_wall_runner). They keep their own colours;
## - GATHER: its surge's warning: it holds where it will pour in, rearing, spines up and glowing (only those
##   leaving the wall glow red: the ones still on it keep their colours);
## - POUR: pouring out of the roadside into the lane its warning line shows;
## - WAVE (phase 2, a strike from behind): its warning: a wave of screeches rising behind the runner in their
##   lane, its crest curling over them (`rise`), until it crashes down into the lane (POUR from the wave);
## - CHARGE: down that lane toward the runner as a lane-wide mass (or, from behind, along it past them:
##   `forward`); its hitbox is live (an enemy attack: armor and the shield block it, the dash passes through
##   it safely, claws don't beat it: it's the boss's);
## - SHOCKED, FALLING, SCATTER: destroyed (a live fence, a hole, weapons or the fight won) and dying away;
##   a cluster that only missed scatters out of sight and FORMING again at the back.
## Weapons hurt it from its warning until it has passed (targetable): its health thins the crowd (its
## highest ranks drop away first), and at nothing it's destroyed like a baited one. Numbers:
## SewerSwarmTuning.

enum Stage { FORMING, WAITING, GATHER, POUR, CHARGE, SHOCKED, FALLING, SCATTER, WAVE }

const STAGE_NAMES: PackedStringArray = ["forming", "waiting", "gather", "pour", "charge", "shocked", "falling",
	"scatter", "wave"]
## Its mound's hitboxes on the wall, each (a share of the mound's length, centred; its top's place along the
## mound, -0.5..0.5, where the clinging screeches' ridge is lowest over it): a long low one and a short high one.
const MOUND_BOXES: Array[Vector2] = [Vector2(0.7, 0.35), Vector2(0.4, 0.2)]
## Its mound's hitboxes are live while at least this share of its screeches is shown on it (rising as it
## forms, thinned by weapons, leaving it as it pours).
const MOUND_SHOWN: float = 0.15
## Their foot and how far under the clinging screeches' ridge they stop (metres).
const MOUND_BOTTOM: float = 0.2
const MOUND_TOP_INSET: float = 0.1
## Where a mound hitbox goes while it's off (out of every query's way, in a lane as it charges too).
const MOUND_PARKED := Vector3(0.0, -50.0, 0.0)

## Its place among the swarm's clusters; its side of the street follows it (even: left, odd: right).
var index: int = 0
var side: int = -1
var stage: Stage = Stage.FORMING
var tuning: SewerSwarmTuning
var crowd: SwarmCrowd
## Its anchor's track distance: its mound's middle at the roadside, or its mass's front in a lane.
var at: float = 0.0
## The lane it charges down (-1 until it lands in one), and the x its mass is in or pouring toward.
var lane: int = -1
var lane_x: float = 0.0
## Its look, eased by the encounter: poured out (0-1), reared up, spines raised and glowing.
var pour: float = 0.0
var rear: float = 0.0
var bristle: float = 0.25
## How much of it has risen (0-1), easing toward formed_target at form_speed a second.
var formed: float = 0.0
var formed_target: float = 1.0
var form_speed: float = 0.5
## The charge's speed (m/s) and, once destroyed, the seconds since.
var charge_speed: float = 0.0
var death_seconds: float = 0.0
var hitbox: Hazard
## A strike from behind: it charges forward along the lane (toward greater distances), its front ahead.
var forward: bool = false
## Its wave (a strike from behind's warning): how far it has risen (0-1), and its foot's track distance (it
## stays there as the wave crashes into the lane).
var rise: float = 0.0
var wave_at: float = 0.0
## Where it was formed from as it pours into the lane: 0 its mound at the roadside, 1 its wave.
var pour_from: int = 0
## Its mound's hitboxes on the wall (MOUND_BOXES).
var mound_boxes: Array[Hazard] = []
var _mound_at: Array[Vector3] = []

var _alive_shown: float = 1.0
var _wall_x: float = 4.0


func _build() -> void:
	var p: Dictionary = spawn.get("params", {})
	tuning = p.get("tuning") as SewerSwarmTuning
	if tuning == null:
		tuning = SewerSwarmTuning.new()
	index = int(p.get("index", 0))
	side = -1 if posmod(index, 2) == 0 else 1
	crowd = p.get("crowd") as SwarmCrowd
	shares_health = false
	is_swarm = true
	is_obstacle = true
	max_health = tuning.cluster_health
	_wall_x = world.geo.wall_x()
	var size := Vector3(world.geo.lane_width * tuning.hit_width_share, tuning.hit_height,
		tuning.mass_length * tuning.hit_length_share)
	hitbox = add_hitbox(&"attack", size, Vector3(0.0, size.y * 0.5, -(tuning.hit_front_inset + size.z * 0.5)), true)
	hitbox.hazard_name = "the Sewer Swarm"
	hitbox.set_enabled(false)
	var depth: float = tuning.wall_hit_depth
	for m: Vector2 in MOUND_BOXES:
		var top: float = mound_top(m.y) - MOUND_TOP_INSET
		var box := add_hitbox(&"attack", Vector3(depth, top - MOUND_BOTTOM, tuning.mound_length * m.x),
			Vector3(side * (0.45 - depth * 0.5), (MOUND_BOTTOM + top) * 0.5, 0.0), true)
		box.hazard_name = "the Sewer Swarm"
		box.contacted.connect(_on_mound_contact)
		mound_boxes.append(box)
		_mound_at.append(box.position)
		box.position = MOUND_PARKED
		box.set_enabled(false)
	if crowd != null:
		crowd.visible = true
		crowd.set_shapes(tuning.mound_length, tuning.mound_depth, tuning.mound_climb, tuning.mass_length,
			world.geo.lane_width * tuning.mass_width_share, tuning.mass_height)
		crowd.set_wave_shape(tuning.wave_height, tuning.wave_reach, world.geo.lane_width * 0.95)
	at = float(spawn.get("at", 0.0))
	place()


## True while it's an attack under way: from its warning until it has passed or died.
func surging() -> bool:
	return alive and stage in [Stage.GATHER, Stage.POUR, Stage.CHARGE, Stage.WAVE]


## The clinging screeches' ridge at `a` along its mound (-0.5..0.5): the highest of them there (the shader's
## mound_slot, its rank's height share at 1).
func mound_top(a: float) -> float:
	return 0.18 + tuning.mound_climb * (0.3 + 0.7 * (1.0 - 4.0 * a * a))


## The share of its screeches shown clinging to the wall in its mound now (0-1): as much of it as has risen
## and is left, less those already pouring out (a creature of rank w leaves at pour w / 2).
func mound_shown() -> float:
	if not alive or stage not in [Stage.FORMING, Stage.WAITING, Stage.GATHER, Stage.POUR] or pour_from != 0:
		return 0.0
	return maxf(minf(clampf(formed, 0.0, 1.0), _alive_shown) - 2.0 * pour, 0.0)


## Its mound's live hitboxes' boxes in world space.
func mound_hit_boxes() -> Array[AABB]:
	var out: Array[AABB] = []
	for box: Hazard in mound_boxes:
		if box.is_active():
			out.append(AABB(box.global_position - box.size * 0.5, box.size))
	return out


## True while it waits at the roadside (or is still rising there): it can be the next to surge.
func ready_to_surge() -> bool:
	return alive and stage in [Stage.FORMING, Stage.WAITING]


## Rises at the roadside over `seconds` (its formation, or re-forming after a surge that missed), after
## `delay` seconds.
func form(seconds: float, delay: float = 0.0) -> void:
	stage = Stage.FORMING
	lane = -1
	pour = 0.0
	rear = 0.0
	rise = 0.0
	pour_from = 0
	forward = false
	bristle = 0.25
	formed = -delay / maxf(seconds, 0.05)
	formed_target = 1.0
	form_speed = 1.0 / maxf(seconds, 0.05)


## Its surge's warning: it makes for `p_at` at the roadside (SwarmSurges eases it there: it's at most a
## station away) and holds there, rearing up.
func gather(_p_at: float) -> void:
	stage = Stage.GATHER
	formed = maxf(formed, 0.0)


## A strike from behind's warning: it leaves its station (sinking into the gutter there, out of the runner's
## sight) and rises as a wave behind them, its foot at `p_at` in the lane at `x` (SwarmSurges moves it with
## the runner and raises it, `rise`).
func wave(p_at: float, x: float) -> void:
	stage = Stage.WAVE
	at = p_at
	wave_at = p_at
	lane_x = x
	rise = 0.0
	pour = 0.0
	pour_from = 1
	formed = 1.0
	formed_target = 1.0


## Lands in `p_lane` and charges down it at `speed` m/s (toward the runner, or with `p_forward` along it
## past them, a strike from behind): its hitbox goes live, its length behind its front.
func charge(p_lane: int, speed: float, p_forward: bool = false) -> void:
	stage = Stage.CHARGE
	lane = p_lane
	lane_x = world.geo.lane_x(p_lane)
	charge_speed = speed
	forward = p_forward
	if not p_forward:
		pour = 1.0
	var size: Vector3 = hitbox.size
	hitbox.position = Vector3(0.0, size.y * 0.5, (1.0 if p_forward else -1.0) * (tuning.hit_front_inset + size.z * 0.5))
	hitbox.set_enabled(true)


## A surge that missed: out of sight, it's gone at once (it re-forms at the back).
func vanish() -> void:
	hitbox.set_enabled(false)
	_set_mound_live(false)
	stage = Stage.FORMING
	formed = 0.0
	formed_target = 0.0
	lane = -1
	pour = 0.0
	rise = 0.0
	forward = false


## Puts it where it is now: its mass's front in its lane, its wave's foot, or its mound at its wall's foot.
func place() -> void:
	if stage in [Stage.POUR, Stage.CHARGE, Stage.SHOCKED, Stage.FALLING, Stage.WAVE]:
		position = Vector3(lane_x, 0.0, TrackGeometry.world_z(at))
	else:
		position = Vector3(side * (_wall_x - 0.45), 0.0, TrackGeometry.world_z(at))


# --- Enemy ---------------------------------------------------------------------------------------

## Weapons target it only while it surges, and only in front of the runner: waiting at the roadside it's
## part of the horde, and a wave behind them is out of their line of fire until it has charged past.
func targetable() -> bool:
	if not super.targetable() or not surging() or stage == Stage.WAVE:
		return false
	return not forward or world == null or at > world.player.distance + 1.0


## Weapon damage thins it only while it surges, like its targeting (a stray shot or a splash reaching it at
## the roadside does nothing); its health is its own (BossPart, shares_health off).
## DESIGN-TBD (docs/OPEN_QUESTIONS.md 326): a cluster thinned to nothing by weapons counts like a baited one.
func take_damage(amount: float, source: StringName, splash: bool = false) -> void:
	if not surging():
		return
	super.take_damage(amount, source, splash)


func is_major_attack_active() -> bool:
	return surging()


func aim_point() -> Vector3:
	if stage in [Stage.POUR, Stage.CHARGE]:
		return Vector3(lane_x, 0.55, TrackGeometry.world_z(at + (-1.0 if forward else 1.0)))
	if stage == Stage.WAVE:
		return Vector3(lane_x, 1.0, TrackGeometry.world_z(at))
	return Vector3(side * (_wall_x - 0.45), 0.6, TrackGeometry.world_z(at))


func hit_radius() -> float:
	return 1.3


func _tick(_delta: float) -> void:
	place()
	_set_mound_live(mound_shown() >= MOUND_SHOWN)
	if not mound_hit_boxes().is_empty():
		_repel_touching()


func _set_mound_live(on: bool) -> void:
	for i: int in mound_boxes.size():
		var box: Hazard = mound_boxes[i]
		var want: Vector3 = _mound_at[i] if on else MOUND_PARKED
		if box.position != want:
			box.position = want
		if box.is_active() != on:
			box.set_enabled(on)


## A runner on its wall touching its mound's screeches is hurt by them first (the touch resolved now, so being
## knocked off can't dodge it), then knocked off the wall, even one nothing can hurt now (grace, god mode, the
## dash).
func _repel_touching() -> void:
	var p: Player = world.player
	if not p.alive or p.surface != Player.Surface.WALL or p.wall_side != side:
		return
	var body: AABB = p.hurtbox_aabb()
	for box: Hazard in mound_boxes:
		if box.is_active() and AABB(box.global_position - box.size * 0.5, box.size).intersects(body):
			p.receive_hit(box)
			_on_mound_contact(0)
			return


func _on_mound_contact(_outcome: int) -> void:
	if encounter != null and is_instance_valid(encounter) and encounter.has_method(&"repel_wall_runner"):
		encounter.call(&"repel_wall_runner", side, "mound")


## Destroyed: a live fence shocks it, a hole swallows it; weapons (or the fight won) scatter it. The
## encounter plays its sound and deals the boss its hit (SewerSwarm._on_part_defeated); here it dies away.
func _on_defeated(cause: StringName) -> void:
	hitbox.set_enabled(false)
	_set_mound_live(false)
	death_seconds = 0.0
	match cause:
		&"fence":
			stage = Stage.SHOCKED
		&"hole":
			stage = Stage.FALLING
		_:
			stage = Stage.SCATTER
	place()


# --- The look ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if crowd == null or world == null:
		return
	formed = move_toward(formed, formed_target, form_speed * delta)
	if alive:
		_alive_shown = move_toward(_alive_shown, health_ratio(), delta / 0.35)
	var death: int = 0
	match stage:
		Stage.SHOCKED:
			death = 1
		Stage.FALLING:
			death = 2
		Stage.SCATTER:
			death = 3
	if death > 0:
		death_seconds += delta
		var over: float = tuning.shock_seconds if death == 1 else (tuning.fall_seconds if death == 2 else 1.2)
		if death_seconds >= over:
			_release()
			return
	crowd.global_position = Vector3(0.0, 0.0, TrackGeometry.world_z(at))
	crowd.set_formation(side * _wall_x, side, 0.0, lane_x, 0.0, -1.0 if forward else 1.0)
	# A wave stays where it rose (its foot's track distance) while its mass charges off from the crash.
	crowd.set_wave(pour_from, lane_x, at - wave_at, rise)
	crowd.set_motion(pour, rear, bristle, 1.0 if stage == Stage.CHARGE or death > 0 else 0.0)
	crowd.set_life(_alive_shown, clampf(formed, 0.0, 1.0), death, death_seconds, charge_speed)
	crowd.show_up_to(minf(clampf(formed, 0.0, 1.0), _alive_shown))


## Its death has played out: its crowd goes back to the encounter's pool and it leaves play.
func _release() -> void:
	if crowd != null:
		crowd.visible = false
		if encounter != null and is_instance_valid(encounter) and encounter.has_method(&"release_crowd"):
			encounter.call(&"release_crowd", crowd)
		crowd = null
	queue_free()
