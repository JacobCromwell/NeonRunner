class_name SwarmCluster
extends BossPart
## One of the Sewer Swarm's clusters (GDD §10: "4-5 gameplay entities ('clusters'), each rendered as many
## screech-variant creatures using MultiMesh plus a shader for per-creature motion"). It is one simulated
## entity: a boss part with health of its own (shares_health off) that is a swarm (is_swarm: GDD §8, the
## heavy missile's bonus, its splash included), declared, never special-cased (CLAUDE.md principle 8). Its
## hundreds of creatures are its SwarmCrowd, drawn in one call from the encounter's pool; they have no
## collision at all: the cluster hurts only through its one hitbox.
##
## Its stages (Stage; SewerSwarm and SwarmSurges move it, it draws itself):
## - FORMING, WAITING: risen at the roadside (its crowd heaped against a wall's foot and clinging to it),
##   pacing the runner at its station ahead; harmless, and weapons don't target it (it's part of the horde);
## - GATHER: its surge's warning: it holds where it will pour in, rearing, spines up and glowing;
## - POUR: pouring out of the roadside into the lane its warning line shows;
## - CHARGE: down that lane toward the runner as a lane-wide mass; its hitbox is live (an enemy attack:
##   armor and the shield block it, the dash passes through it safely, claws don't beat it: it's the boss's);
## - SHOCKED, FALLING, SCATTER: destroyed (a live fence, a hole, weapons or the fight won) and dying away;
##   a cluster that only missed scatters out of sight behind the runner and FORMING again at the back.
## Weapons hurt it from its warning until it has passed (targetable): its health thins the crowd (its
## highest ranks drop away first), and at nothing it's destroyed like a baited one. Numbers:
## SewerSwarmTuning.

enum Stage { FORMING, WAITING, GATHER, POUR, CHARGE, SHOCKED, FALLING, SCATTER }

const STAGE_NAMES: PackedStringArray = ["forming", "waiting", "gather", "pour", "charge", "shocked", "falling",
	"scatter"]

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
	if crowd != null:
		crowd.visible = true
		crowd.set_shapes(tuning.mound_length, tuning.mound_depth, tuning.mound_climb, tuning.mass_length,
			world.geo.lane_width * tuning.mass_width_share, tuning.mass_height)
	at = float(spawn.get("at", 0.0))
	place()


## True while it's an attack under way: from its warning until it has passed or died.
func surging() -> bool:
	return alive and stage in [Stage.GATHER, Stage.POUR, Stage.CHARGE]


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
	bristle = 0.25
	formed = -delay / maxf(seconds, 0.05)
	formed_target = 1.0
	form_speed = 1.0 / maxf(seconds, 0.05)


## Its surge's warning: it makes for `p_at` at the roadside (SwarmSurges eases it there: it's at most a
## station away) and holds there, rearing up.
func gather(_p_at: float) -> void:
	stage = Stage.GATHER
	formed = maxf(formed, 0.0)


## Lands in `p_lane` and charges down it at `speed` m/s: its hitbox goes live.
func charge(p_lane: int, speed: float) -> void:
	stage = Stage.CHARGE
	lane = p_lane
	lane_x = world.geo.lane_x(p_lane)
	pour = 1.0
	charge_speed = speed
	hitbox.set_enabled(true)


## A surge that missed: out of sight behind the runner, it's gone at once (it re-forms at the back).
func vanish() -> void:
	hitbox.set_enabled(false)
	stage = Stage.FORMING
	formed = 0.0
	formed_target = 0.0
	lane = -1
	pour = 0.0


## Puts it where it is now: its mass's front in its lane, or its mound at its wall's foot.
func place() -> void:
	if stage in [Stage.POUR, Stage.CHARGE, Stage.SHOCKED, Stage.FALLING]:
		position = Vector3(lane_x, 0.0, TrackGeometry.world_z(at))
	else:
		position = Vector3(side * (_wall_x - 0.45), 0.0, TrackGeometry.world_z(at))


# --- Enemy ---------------------------------------------------------------------------------------

## Weapons target it only while it surges: waiting at the roadside it's part of the horde.
func targetable() -> bool:
	return super.targetable() and surging()


## Weapon damage thins it only while it surges, like its targeting (a stray shot or a splash reaching it at
## the roadside does nothing); its health is its own (BossPart, shares_health off).
## DESIGN-TBD (docs/questions/e4.md, 3): a cluster thinned to nothing by weapons counts like a baited one.
func take_damage(amount: float, source: StringName, splash: bool = false) -> void:
	if not surging():
		return
	super.take_damage(amount, source, splash)


func is_major_attack_active() -> bool:
	return surging()


func aim_point() -> Vector3:
	if stage in [Stage.POUR, Stage.CHARGE]:
		return Vector3(lane_x, 0.55, TrackGeometry.world_z(at + 1.0))
	return Vector3(side * (_wall_x - 0.45), 0.6, TrackGeometry.world_z(at))


func hit_radius() -> float:
	return 1.3


func _tick(_delta: float) -> void:
	place()


## Destroyed: a live fence shocks it, a hole swallows it; weapons (or the fight won) scatter it. The
## encounter plays its sound and deals the boss its hit (SewerSwarm._on_part_defeated); here it dies away.
func _on_defeated(cause: StringName) -> void:
	hitbox.set_enabled(false)
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
	crowd.set_formation(side * _wall_x, side, 0.0, lane_x, 0.0)
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
