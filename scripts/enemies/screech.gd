class_name Screech
extends Enemy
## The Sewer Screech (GDD §9.5): slimy, diseased vermin with rows of spines, hiding under a manhole
## cover in a floor lane or in a vent at the foot of a wall.
##
## - It comes out only if the player is in its lane (for a vent: the floor lane beside it, or the
##   wall above it) while they're between trigger_seconds and min_warning_seconds away; otherwise it
##   stays hidden, harmless, and is left behind.
## - Warning first, always: the cover or vent shakes (screech_shake), then bursts open
##   (screech_burst) and it leaps out. Nothing about it can hurt until it's out.
## - Attack: a short dash straight along its lane toward the player, then one swipe (screech_swipe
##   as the claw goes up, then the strike), then it falls behind.
## - Wall vents: with the player on the floor beside it, it drops to that lane and attacks the same
##   way; with the player on the wall, it swipes up the wall from the vent (reaching
##   vent_swipe_height), then drops to the floor. Jumping off the wall escapes the swipe.
## - Dodge by switching lanes or jumping over it. Its spines hurt anyone landing on it without claws
##   (a body collision). Any weapon hit, claws or the dash kill it; armor and the shield block its
##   swipe (an enemy attack).
##
## Where it may appear is the level's business (features): "screech" allows manholes and vents,
## "screech_vents" only vents (rare, for zones whose floor has no manholes, GDD §9.5; there are none
## in the Neon City; see data/patterns/screech.json).
## Its body is ScreechModel: one mesh, one material, animated in its shader, reusable by the swarm boss.

enum Phase { HIDDEN, SHAKE, EMERGE, DASH, SWIPE, VENT_WAIT, VENT_SWIPE, DROP, DONE }

const PHASE_NAMES: PackedStringArray = ["hidden", "shake", "emerge", "dash", "swipe", "vent_wait",
	"vent_swipe", "drop", "done"]
## Hitboxes, slightly smaller than the model (GDD §3).
const BODY_SIZE := Vector3(0.52, 0.4, 0.7)
const TOP_SIZE := Vector3(0.56, 0.2, 0.74)
## How far in front of the vent's wall face the wall swipe reaches.
const WALL_SWIPE_DEPTH: float = 1.0

var phase: Phase = Phase.HIDDEN
var from_vent: bool = false
## Wall side of a vent (-1 left, +1 right); 0 for a manhole.
var side: int = 0
## Its lane: the manhole's, or the floor lane beside the vent.
var lane: int = 0
## Attacking a player on the wall from its vent (decided when it comes out).
var wall_mode: bool = false
## Phase changes as [phase name, player distance], for tests and debugging.
var history: Array = []

var _t: ScreechTuning
var _scaling: float = 0.0
## The level's pace (MovementTuning.pace): its dash (speed and length, given at the reference speed)
## is stretched by it, so in a faster zone it dashes faster, as far in time (GDD §3). Its warning and
## trigger are seconds already.
var _run_pace: float = 1.0
## Track distance and world position of the creature.
var _d: float = 0.0
var _x: float = 0.0
var _y: float = 0.0
var _lair_d: float = 0.0
var _phase_time: float = 0.0
var _dashed: float = 0.0
var _too_late: bool = false
var _emerge_from := Vector3.ZERO
var _emerge_to := Vector3.ZERO
var _swipe: float = 0.0
var _bristle: float = 0.0
var _body_on: bool = true

var _body: Hazard
var _top: Hazard
var _claw_floor: Hazard
var _claw_wall: Hazard
var _mesh: MeshInstance3D
var _lair: ScreechLair


## A screech's look and both its lairs, a vent and a manhole, for EnemyDirector.warm_up (which frees
## them): the first builds the meshes and materials every later screech shares.
static func warm_up(world: RunWorld, entry: Dictionary) -> Node:
	var variant: StringName = world.skin.enemy_variant if world.skin != null else &"city"
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = ScreechModel.mesh()
	body.material_override = ScreechModel.material(variant)
	root.add_child(body)
	for kind: ScreechLair.Kind in [ScreechLair.Kind.VENT, ScreechLair.Kind.MANHOLE]:
		var lair := ScreechLair.new()
		root.add_child(lair)
		lair.build(kind, variant, 1, int(entry.get("seed", 0)))
	return root


func _build() -> void:
	display_name = "Sewer Screech"
	stompable = false  # GDD §9.5: landing on its spines without claws hurts.
	immune_to_weapons = true  # hidden until it bursts out
	_t = tuning_res as ScreechTuning if tuning_res is ScreechTuning else ScreechTuning.new()
	_scaling = world.config.enemy_scaling if world.config != null else 0.0
	_run_pace = world.tuning.pace()
	var p: Dictionary = spawn.get("params", {})
	var geo: TrackGeometry = world.geo
	side = signi(int(spawn.get("side", 0)))
	from_vent = String(p.get("source", "vent" if side != 0 else "manhole")) == "vent"
	if from_vent and side == 0:
		side = 1 if int(spawn.get("lane", 0)) >= geo.lane_count / 2 else -1
	lane = world.layout.outer_lane(side) if from_vent else clampi(int(spawn.get("lane", 0)), 0, geo.lane_count - 1)
	_lair_d = float(spawn.get("at", 0.0))
	_d = _lair_d
	if from_vent:
		_x = side * (geo.wall_x() + 0.5)
		_y = 0.0
	else:
		_x = geo.lane_x(lane)
		_y = -0.7
	# Spines and body: a solid collision, armor doesn't block it (FB 83). The swipe: an attack.
	_body = add_hitbox(&"body", BODY_SIZE, Vector3(0.0, BODY_SIZE.y * 0.5 + 0.03, 0.0))
	_top = add_hitbox(&"top", TOP_SIZE, Vector3(0.0, BODY_SIZE.y + TOP_SIZE.y * 0.5 - 0.02, 0.0))
	_claw_floor = add_hitbox(&"body", Vector3(0.9, _t.swipe_height, _t.swipe_reach),
		Vector3(0.0, _t.swipe_height * 0.5, BODY_SIZE.z * 0.5 + _t.swipe_reach * 0.5), true)
	_claw_floor.hazard_name = "Sewer Screech swipe"
	_claw_wall = add_hitbox(&"body", Vector3(WALL_SWIPE_DEPTH, _t.vent_swipe_height, _t.swipe_reach + 0.5),
		Vector3(side * (0.4 - WALL_SWIPE_DEPTH * 0.5), _t.vent_swipe_height * 0.5, _t.swipe_reach * 0.5 - 0.15), true)
	_claw_wall.hazard_name = "Sewer Screech swipe"
	_claw_floor.set_enabled(false)
	_claw_wall.set_enabled(false)
	_set_body(false)
	_build_visuals()
	_place()


func _build_visuals() -> void:
	var variant: StringName = world.skin.enemy_variant if world.skin != null else &"city"
	_mesh = MeshInstance3D.new()
	_mesh.name = "Body"
	_mesh.mesh = ScreechModel.mesh()
	_mesh.material_override = ScreechModel.material(variant)
	_mesh.rotation.y = PI
	_mesh.visible = false
	add_child(_mesh)
	_mesh.set_instance_shader_parameter(&"seed", rng.randf() * 10.0)
	_lair = ScreechLair.new()
	_lair.name = "Lair"
	add_child(_lair)
	_lair.build(ScreechLair.Kind.VENT if from_vent else ScreechLair.Kind.MANHOLE, variant, side, int(spawn.get("seed", 0)))
	if from_vent:
		_lair.global_position = Vector3(side * world.geo.wall_x(), 0.0, TrackGeometry.world_z(_lair_d))
	else:
		_lair.global_position = Vector3(world.geo.lane_x(lane), 0.0, TrackGeometry.world_z(_lair_d))


# --- Behaviour ------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	var player: Player = world.player
	var v: float = maxf(player.speed, 1.0)
	var rel: float = _d - player.distance
	_phase_time += delta
	match phase:
		Phase.HIDDEN:
			_hidden(rel, v)
		Phase.SHAKE:
			if _phase_time >= _t.shake_time(_scaling):
				_burst_out()
		Phase.EMERGE:
			var k: float = clampf(_phase_time / _t.emerge_time, 0.0, 1.0)
			var p: Vector3 = _emerge_from.lerp(_emerge_to, k)
			_x = p.x
			_y = p.y + 0.4 * sin(PI * k)
			if k >= 1.0:
				_y = _emerge_to.y
				_set_body(true)
				_set_phase(Phase.VENT_WAIT if wall_mode else Phase.DASH)
		Phase.DASH:
			_dash(delta, rel, v)
		Phase.SWIPE, Phase.VENT_SWIPE:
			_swiping()
		Phase.VENT_WAIT:
			if rel <= _t.swipe_start_distance(v, 0.0):
				_start_swipe(Phase.VENT_SWIPE)
			elif rel < -2.0:
				_set_phase(Phase.DROP)
		Phase.DROP:
			var k: float = clampf(_phase_time / _t.vent_drop_time, 0.0, 1.0)
			_x = lerpf(side * (world.geo.wall_x() - 0.4), world.geo.lane_x(lane), k)
			_y = 0.35 * sin(PI * k)
			if k >= 1.0:
				_y = 0.0
				_set_phase(Phase.DONE)
	_place()


func _set_phase(next: Phase) -> void:
	phase = next
	_phase_time = 0.0
	history.append([PHASE_NAMES[next], world.player.distance])


## GDD §9.5: out only if the player is in its lane, with time for the warning; otherwise hidden.
func _hidden(rel: float, v: float) -> void:
	if _too_late:
		return
	var seconds: float = rel / v
	if seconds > _t.trigger_seconds:
		return
	if seconds < _t.min_warning_seconds:
		_too_late = true
		return
	var player: Player = world.player
	if not player.alive:
		return
	var mode: int = _lane_mode(player)
	if mode < 0:
		return
	wall_mode = mode == 1
	_set_phase(Phase.SHAKE)
	_lair.set_shaking(true)
	world.play_sfx_at(&"screech_shake", _lair.global_position + Vector3(0.0, 0.3, 0.0))


## -1: the player isn't in its lane; 0: on the floor in its lane; 1: on the wall above its vent.
func _lane_mode(player: Player) -> int:
	match player.surface:
		Player.Surface.FLOOR:
			return 0 if player.lane == lane else -1
		Player.Surface.WALL:
			return 1 if from_vent and player.wall_side == side else -1
	return -1


func _burst_out() -> void:
	_set_phase(Phase.EMERGE)
	_lair.burst()
	immune_to_weapons = false
	_mesh.visible = true
	_bristle = 1.0
	var from := Vector3(_x, _y, 0.0)
	var to := Vector3(world.geo.lane_x(lane), 0.0, 0.0)
	if from_vent and wall_mode:
		to = Vector3(side * (world.geo.wall_x() - 0.4), 0.0, 0.0)
	_emerge_from = from
	_emerge_to = to
	var at := Vector3(_x, maxf(_y, 0.0) + 0.3, TrackGeometry.world_z(_d))
	world.play_sfx_at(&"screech_burst", at)
	world.effects.burst(at, ScreechLair.MIST, 18, 0.45)


func _dash(delta: float, rel: float, v: float) -> void:
	if rel <= _t.swipe_start_distance(v, BODY_SIZE.z * 0.5):
		_start_swipe(Phase.SWIPE)
		return
	if rel < -1.0:
		_set_phase(Phase.DONE)  # the player got past before it could swipe
		return
	var step: float = minf(_t.dash_speed(_scaling) * _run_pace * delta, _t.dash_max_distance * _run_pace - _dashed)
	# It stops at the edge of a hole rather than dashing into it (FB 84).
	if step > 0.0 and not world.layout.gapped_between(lane, _d - step - BODY_SIZE.z * 0.5, _d):
		_d -= step
		_dashed += step


func _start_swipe(next: Phase) -> void:
	_set_phase(next)
	world.play_sfx_at(&"screech_swipe", global_position + Vector3(0.0, 0.4, 0.0))


func _swiping() -> void:
	var t: float = _phase_time
	var claw: Hazard = _claw_wall if phase == Phase.VENT_SWIPE else _claw_floor
	var up: float = _t.swipe_windup
	var hit: float = up + _t.swipe_active
	var done: float = hit + _t.swipe_recover
	if t < up:
		_swipe = 0.45 * t / up
	elif t < hit:
		_swipe = lerpf(0.45, 0.62, (t - up) / _t.swipe_active)
		claw.set_enabled(true)
	else:
		claw.set_enabled(false)
		_swipe = lerpf(0.62, 1.0, clampf((t - hit) / _t.swipe_recover, 0.0, 1.0))
		if t >= done:
			_swipe = 0.0
			_set_phase(Phase.DROP if phase == Phase.VENT_SWIPE else Phase.DONE)


func _set_body(on: bool) -> void:
	if on == _body_on or not alive:
		return
	_body_on = on
	_body.set_enabled(on)
	_top.set_enabled(on)


func _place() -> void:
	position = Vector3(_x, _y, TrackGeometry.world_z(_d))


# --- Presentation -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if world == null or _mesh == null:
		return
	if not alive:
		# Defeated: its lair stays in view until the player has left it behind.
		if world.player_distance() - _lair_d > 35.0:
			queue_free()
		return
	var moving: float = 1.0 if phase in [Phase.DASH, Phase.EMERGE, Phase.DROP] else 0.25
	_bristle = move_toward(_bristle, 1.0 if phase in [Phase.SWIPE, Phase.VENT_SWIPE, Phase.DASH] else 0.35, delta * 3.0)
	_mesh.set_instance_shader_parameter(&"swipe", _swipe)
	_mesh.set_instance_shader_parameter(&"bristle", _bristle)
	_mesh.set_instance_shader_parameter(&"scurry", moving)
	var yaw: float = PI
	if wall_mode and phase in [Phase.VENT_WAIT, Phase.VENT_SWIPE]:
		yaw = PI + side * 0.5
	_mesh.rotation.y = lerp_angle(_mesh.rotation.y, yaw, 1.0 - exp(-12.0 * delta))


func _on_defeated(_cause: StringName) -> void:
	_claw_floor.set_enabled(false)
	_claw_wall.set_enabled(false)
	_mesh.visible = false
	world.play_sfx_at(&"enemy_death", global_position)
	world.effects.burst(aim_point(), ScreechLair.MIST, 22, 0.7)
	world.effects.burst(aim_point(), ScreechModel.SPINE_TIP, 10, 0.5)


## Auto-fire only picks it once it's out of its lair.
func targetable() -> bool:
	return super.targetable() and phase != Phase.HIDDEN and phase != Phase.SHAKE


func aim_point() -> Vector3:
	return global_position + Vector3(0.0, 0.3, 0.0)


func hit_radius() -> float:
	return 0.55
