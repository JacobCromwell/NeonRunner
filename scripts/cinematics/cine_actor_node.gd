class_name CineActorNode
extends Node3D
## An actor of a playing cinematic (CinematicSequencer): the runner's model (PlayerAvatar, Razor Echo) or
## a cyborg's (CyborgBody, in its zone's look), moved along its CineActor's keys and posed from them.
## The runner's stride keeps pace with the ground it covers and it leans into sideways moves, as in play;
## a cyborg walks, aims, cowers or falls. Visual only: no collision and no gameplay.

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
## Below this speed (m/s) an actor that faces the way it moves keeps its heading.
const TURN_MIN_SPEED: float = 0.3
## How quickly it turns toward its heading (1/s): a quick sideways step barely turns it.
const TURN_RATE: float = 10.0
## Moving sideways faster than this (m/s), the runner leans into it, as into a lane switch.
const LEAN_SPEED: float = 1.5
## Higher than this above the floor (m), the runner is in the air.
const AIR_HEIGHT: float = 0.03
## Where a cyborg aims on another actor: this high above its feet (m).
const AIM_HEIGHT: float = 0.9
## A frame's move longer than this (m) is a jump cut, not ground covered.
const MAX_STEP: float = 5.0

var actor: CineActor
var stage: CineStage
var avatar: PlayerAvatar
var body: CyborgBody
## Its track-space position now, its speed over the ground and its vertical speed (m/s).
var track_position := Vector3.ZERO
var speed: float = 0.0
var vertical_speed: float = 0.0
## Metres of ground covered: the runner's stride follows it.
var distance_run: float = 0.0
## Its pose now (the last one its keys named).
var pose: StringName = &""
## Its heading now, radians (0 faces down the track, + turns left).
var yaw: float = 0.0

var _started: bool = false
var _airborne: bool = false
var _died: bool = false


## Builds the model. `variant` dresses a cyborg that names no look of its own (the stage skin's
## enemy_variant); `visual_seed` varies only visuals (a cyborg's twitches and glitches).
func setup(p_actor: CineActor, p_stage: CineStage, tuning: MovementTuning, variant: StringName, visual_seed: int) -> void:
	actor = p_actor
	stage = p_stage
	name = String(actor.id).validate_node_name()
	match actor.kind:
		CineActor.Kind.RUNNER:
			avatar = PlayerAvatar.new()
			# Driven by update() on the cinematic's clock, never by itself between frames.
			avatar.set_physics_process(false)
			avatar.fit_to(tuning.visual_size)
			add_child(avatar)
		CineActor.Kind.CYBORG:
			body = CyborgBody.new()
			body.name = "Body"
			add_child(body)
			body.build(actor.look if actor.look != &"" else variant, actor.host, false, visual_seed)


## Moves and poses it for time `t` (`delta` since the last update; 0 the first time). `others` finds
## the other actors by id (a cyborg's aim).
func update(t: float, delta: float, others: Dictionary) -> void:
	visible = t >= actor.enter and (actor.leave < 0.0 or t < actor.leave)
	if actor.keys.is_empty():
		return
	var points: Array = []
	for k: CineActorKey in actor.keys:
		points.append(k.position)
	var p: Vector3 = CinePath.sample(actor.keys, points, t)
	var step: Vector3 = p - track_position if _started else Vector3.ZERO
	if step.length() > MAX_STEP:
		step = Vector3.ZERO
	var velocity: Vector3 = step / delta if delta > 0.0 else Vector3.ZERO
	speed = Vector2(velocity.x, velocity.z).length()
	vertical_speed = velocity.y
	distance_run += Vector2(step.x, step.z).length()
	track_position = p
	position = stage.point(p) if stage != null else Vector3(p.x, p.y, -p.z)
	var i: int = maxi(CinePath.index_at(actor.keys, t), 0)
	pose = _latest(i, &"pose")
	var key := actor.keys[i] as CineActorKey
	var heading: float = yaw
	if not key.face_path:
		heading = deg_to_rad(key.yaw)
	elif speed > TURN_MIN_SPEED:
		# Track space runs along +z, which is world -z: heading 0.
		heading = atan2(-velocity.x, velocity.z)
	yaw = heading if not _started else lerp_angle(yaw, heading, 1.0 - exp(-TURN_RATE * delta))
	_started = true
	if avatar != null:
		_update_runner(delta, velocity)
	elif body != null:
		_update_cyborg(i, others)


func _update_runner(delta: float, velocity: Vector3) -> void:
	avatar.rotation.y = yaw
	var airborne: bool = track_position.y > AIR_HEIGHT
	var landed: bool = _airborne and not airborne
	_airborne = airborne
	# Leaning into a sideways move as into a lane switch (world x is track x).
	var lean: int = int(signf(velocity.x)) if absf(velocity.x) > LEAN_SPEED else 0
	avatar.animate({
		"surface": "floor",
		"grounded": not airborne,
		"vh": vertical_speed,
		"sliding": pose == &"slide",
		"distance": distance_run,
		"speed": speed,
		"switch_dir": lean,
		"alive": pose != &"dead",
		"dashing": pose == &"dash",
		"stomping": pose == &"stomp",
		"just_landed": landed,
	}, delta)


func _update_cyborg(i: int, others: Dictionary) -> void:
	body.rotation.y = yaw + PI  # The body faces +z; heading 0 faces down the track (-z).
	match pose:
		&"aim":
			body.set_pose(CyborgBody.Pose.AIM)
		&"run_away":
			body.set_pose(CyborgBody.Pose.RUN_AWAY)
		&"cower":
			body.set_pose(CyborgBody.Pose.COWER)
		&"idle":
			body.set_pose(CyborgBody.Pose.IDLE)
		&"die":
			if not _died:
				_died = true
				body.die(&"shot")
		_:
			body.set_pose(CyborgBody.Pose.WALK if speed > 0.1 else CyborgBody.Pose.IDLE)
	body.set_move_speed(speed)
	var face: StringName = _latest(i, &"expression")
	if face != &"" and not _died:
		var index: int = Kit.Face.keys().find(String(face).to_upper())
		if index >= 0 and index != body.face:
			body.set_expression(index as Kit.Face)
	var aim: StringName = _latest(i, &"aim_at")
	var target := others.get(aim) as CineActorNode if aim != &"" and aim != &"none" else null
	if target != null and not _died:
		body.aim_at(target.global_position + Vector3(0.0, AIM_HEIGHT, 0.0))
	else:
		body.clear_aim()
	for k: int in range(i, -1, -1):
		var charge: float = (actor.keys[k] as CineActorKey).charge
		if charge >= 0.0:
			if not is_equal_approx(charge, body.charge):
				body.set_charge(charge)
			break


## The last non-empty value of a key's StringName `property` at or before key `i` (empty if none).
func _latest(i: int, property: StringName) -> StringName:
	for k: int in range(i, -1, -1):
		var v: StringName = actor.keys[k].get(property)
		if v != &"":
			return v
	return &""
