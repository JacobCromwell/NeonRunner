class_name CineActorNode
extends Node3D
## An actor of a playing cinematic (CinematicSequencer): the runner's model (PlayerAvatar, Razor Echo) or
## a cyborg's (CyborgBody, in its zone's look), moved along its CineActor's keys and posed from them.
## The runner's stride keeps pace with the ground it covers and it leans into sideways moves, as in play;
## in the poses play never needs (CinePoses: lying, getting up, climbing out over an edge) its rig is posed
## from the keys' progress instead, and while it climbs its hands hold on to the keys' position. A cyborg
## walks, aims, cowers, falls, lies still or crouches. Either turns its head by the keys' look and
## look_up. Visual only: no collision and no gameplay.

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
## Below this speed (m/s) an actor that faces the way it moves keeps its heading.
const TURN_MIN_SPEED: float = 0.3
## How quickly it turns toward its heading (1/s): a quick sideways step barely turns it.
const TURN_RATE: float = 10.0
## Moving sideways faster than this (m/s), the runner leans into it, as into a lane switch.
const LEAN_SPEED: float = 1.5
## Further than this from the floor (m), above it or below it (falling past its edge), the runner is in
## the air.
const AIR_HEIGHT: float = 0.03
## Where a cyborg aims on another actor: this high above its feet (m).
const AIM_HEIGHT: float = 0.9
## A frame's move longer than this (m) is a jump cut, not ground covered. On its first frame, and after a jump cut,
## it moves as its path goes on from there (JUMP_LOOK ahead), so it faces that way at once and starts in its stride.
const MAX_STEP: float = 5.0
const JUMP_LOOK: float = 0.1
## A walk's pace and stride follow its movement over about this long (s), so a sudden change in its speed or its
## turning never jumps its pose in one frame.
const GAIT_SMOOTH: float = 0.15
## How the runner's look (CineActorKey.look) is shared out up its spine: chest, neck, head.
const LOOK_SHARE: Array[float] = [0.25, 0.3, 0.45]
const LOOK_JOINTS: Array[StringName] = [&"chest", &"neck", &"head"]
## How its tip (CineActorKey.look_up) is shared out over the same joints.
const TIP_SHARE: Array[float] = [0.0, 0.4, 0.6]
## Where a hand grips: this far along it from the wrist (the rig's units, before its size fit).
const GRIP_REACH: float = 0.07

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
## Its heading now, radians (0 faces down the track, + turns left), and how fast it's turning (rad/s).
var yaw: float = 0.0
var turn_speed: float = 0.0
## Its head turn now, radians (+ looks left; CineActorKey.look), and its tip (+ looks up; look_up).
var look: float = 0.0
var look_up: float = 0.0
## How far through a pose that plays out over time it is now (CineActorKey.progress, 0-1).
var progress: float = 0.0

var _started: bool = false
var _airborne: bool = false
var _died: bool = false
## Its keys' positions, looks, tips and progress, in order (built on first use).
var _points: Array = []
var _looks := PackedFloat32Array()
var _tips: Array = []
var _progress: Array = []
## The runner's pose in CinePoses' poses, a scratch pose for its steps, and its legs' phase as it steps.
var _cine_pose := HumanoidPose.new()
var _step_pose := HumanoidPose.new()
var _step_phase: float = 0.0
## The walk's phase through its gait cycle (CinePoses.walk), its pace (m/s, smoothed; below 0 until it walks) and
## the share of it that's ground covered (the rest is stepping round as it turns; smoothed); how fast an eased turn
## is turning now (rad/s).
var _walk_phase: float = 0.0
var _gait: float = -1.0
var _covering: float = 0.0
var _yaw_speed: float = 0.0


## Builds the model. `variant` dresses a cyborg that names no look of its own (the stage skin's
## enemy_variant); `visual_seed` varies only visuals (a cyborg's twitches and glitches).
func setup(p_actor: CineActor, p_stage: CineStage, tuning: MovementTuning, variant: StringName, visual_seed: int) -> void:
	actor = p_actor
	stage = p_stage
	name = String(actor.id).validate_node_name()
	match actor.kind:
		CineActor.Kind.RUNNER:
			avatar = PlayerAvatar.new()
			avatar.fit_to(tuning.visual_size)
			add_child(avatar)
			_hold_models()
		CineActor.Kind.CYBORG:
			body = CyborgBody.new()
			body.name = "Body"
			add_child(body)
			body.build(actor.look if actor.look != &"" else variant, actor.host, false, visual_seed)
			_hold_models()


func _ready() -> void:
	_hold_models()


## The models are driven by update() on the cinematic's clock, never by themselves between frames
## (PlayerAvatar carries on from its last state when it isn't fed for two physics ticks, which a frame
## at 30 fps spans; a cyborg's body moves on by update()'s steps, CyborgBody.advance, so stepping the clock
## shows the same). A node's processing comes back on when it's ready, so this runs once it is.
func _hold_models() -> void:
	if avatar != null and avatar.is_inside_tree():
		avatar.set_physics_process(false)
	if body != null and body.is_inside_tree():
		body.set_process(false)


## Where its path puts it at time `t`, in track space (what a camera key riding with it follows).
func track_point_at(t: float) -> Vector3:
	if actor.keys.is_empty():
		return Vector3.ZERO
	if _points.size() != actor.keys.size():
		_points.clear()
		for k: CineActorKey in actor.keys:
			_points.append(k.position)
	return CinePath.sample(actor.keys, _points, t)


## Where its path puts it at time `t`, in world space.
func point_at(t: float) -> Vector3:
	var p: Vector3 = track_point_at(t)
	return stage.point(p) if stage != null else Vector3(p.x, p.y, -p.z)


## Moves and poses it for time `t` (`delta` since the last update; 0 the first time). `others` finds
## the other actors by id (a cyborg's aim).
func update(t: float, delta: float, others: Dictionary) -> void:
	visible = t >= actor.enter and (actor.leave < 0.0 or t < actor.leave)
	if actor.keys.is_empty():
		return
	var p: Vector3 = track_point_at(t)
	var step: Vector3 = p - track_position if _started else Vector3.ZERO
	var jumped: bool = step.length() > MAX_STEP
	if jumped:
		step = Vector3.ZERO
	var velocity: Vector3 = step / delta if delta > 0.0 else Vector3.ZERO
	if not _started or jumped:
		# Its first frame here: moving as its path goes on from here, so it starts in its stride.
		var ahead: Vector3 = track_point_at(t + JUMP_LOOK) - p
		if ahead.length() < MAX_STEP:
			velocity = ahead / JUMP_LOOK
		_gait = -1.0
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
	elif speed > TURN_MIN_SPEED or ((not _started or jumped) and speed > 0.001):
		# Track space runs along +z, which is world -z: heading 0.
		heading = atan2(-velocity.x, velocity.z)
	var rate: float = actor.turn_rate if actor.turn_rate > 0.0 else TURN_RATE
	var turned_from: float = yaw
	if not _started or jumped:
		yaw = heading
		_yaw_speed = 0.0
	elif actor.turn_rate > 0.0:
		# Eased into the turn and out of it: a critically damped turn, worked out exactly over the step.
		var off: float = angle_difference(heading, yaw)
		var fade: float = exp(-rate * delta)
		var carry: float = _yaw_speed + rate * off
		yaw = wrapf(heading + (off + carry * delta) * fade, -PI, PI)
		_yaw_speed = (_yaw_speed - rate * carry * delta) * fade
	else:
		yaw = lerp_angle(yaw, heading, 1.0 - exp(-rate * delta))
	turn_speed = absf(angle_difference(turned_from, yaw)) / delta if _started and not jumped and delta > 0.0 else 0.0
	var first: bool = not _started
	_started = true
	_sample_look(t)
	progress = _progress_at(t)
	if avatar != null:
		if CinePoses.is_cine_pose(pose):
			_pose_runner(t, delta)
		else:
			avatar.position = Vector3.ZERO
			_update_runner(delta, velocity)
			_turn_head()
	elif body != null:
		if first:
			body.snap()
		_update_cyborg(i, others)
		body.advance(delta)


func _update_runner(delta: float, velocity: Vector3) -> void:
	avatar.rotation.y = yaw
	var airborne: bool = absf(track_position.y) > AIR_HEIGHT
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


## The runner in one of CinePoses' poses: its rig posed from the keys' progress (and put on the ground), its
## head turned, then, while it climbs, moved so its hands hold on to the keys' position.
func _pose_runner(t: float, delta: float) -> void:
	avatar.rotation.y = yaw
	avatar.position = Vector3.ZERO
	var rig: HumanoidRig = avatar.rig
	if pose == &"walk":
		# Its stride follows the ground covered, and it steps as it turns on the spot; its planted foot goes back
		# under it at its pace (none, stepping in place), in the rig's own units. Its pace and the share of it
		# covering ground are smoothed (GAIT_SMOOTH); its steps keep time with the ground covered.
		var gait: float = speed + turn_speed * CinePoses.TURN_STEP
		var covering: float = speed / gait if gait > 0.001 else 0.0
		var follow: float = 1.0 - exp(-delta / GAIT_SMOOTH) if _gait >= 0.0 else 1.0
		_gait = lerpf(maxf(_gait, 0.0), gait, follow)
		_covering = lerpf(_covering, covering, follow)
		var stride: float = CinePoses.walk_stride(_gait)
		_walk_phase = CinePoses.walk_phase(_walk_phase, gait * delta, stride)
		CinePoses.walk(_cine_pose, _walk_phase, CinePoses.walk_amount(_gait), t, stride * _covering,
			CinePoses.WALK_CYCLE / maxf(rig.scale.z, 0.01), rig.parts.thigh_length, rig.parts.shin_length)
	else:
		_gait = -1.0
		CinePoses.runner(_cine_pose, pose, progress, t, rig.parts.pelvis_height())
	var hold: float = CinePoses.hand_hold(pose, progress)
	# Moved along meanwhile (a stagger forward as it gets up), its legs step.
	_step_phase = CinePoses.step_phase(_step_phase, speed * delta, speed, avatar.anim_tuning)
	CinePoses.add_steps(_cine_pose, _step_pose, _step_phase, speed, avatar.anim_tuning,
		smoothstep(CinePoses.STEP_SPEED.x, CinePoses.STEP_SPEED.y, speed) * (1.0 - hold)
		* CinePoses.steps_while_moving(pose))
	rig.apply_pose(_cine_pose)
	_turn_head()
	if hold > 0.0:
		avatar.position = -grip_point() * hold
	rig.update_panels(delta)
	_airborne = false


## Where the runner's hands grip, in this node's space: between its palms (GRIP_REACH along each hand
## from its wrist). While it climbs, the keys' position.
func grip_point() -> Vector3:
	var sum := Vector3.ZERO
	for hand: StringName in [&"hand_l", &"hand_r"]:
		var joint: Node3D = avatar.rig.joint(hand)
		sum += to_local(joint.global_transform * Vector3(0.0, -GRIP_REACH, 0.0))
	return sum * 0.5


## Its look and its tip at time `t`, from its keys.
func _sample_look(t: float) -> void:
	if _looks.size() != actor.keys.size():
		_looks.clear()
		_tips.clear()
		for k: CineActorKey in actor.keys:
			_looks.append(deg_to_rad(k.look))
			_tips.append(deg_to_rad(k.look_up))
	look = CinePath.sample_angle(actor.keys, _looks, t)
	look_up = float(CinePath.sample(actor.keys, _tips, t))


## How far through its pose it is at time `t`: its keys' progress, a key below 0 keeping the one before.
func _progress_at(t: float) -> float:
	if _progress.size() != actor.keys.size():
		_progress.clear()
		var last: float = 0.0
		for k: CineActorKey in actor.keys:
			last = k.progress if k.progress >= 0.0 else last
			_progress.append(last)
	return clampf(float(CinePath.sample(actor.keys, _progress, t)), 0.0, 1.0)


## The runner's look and tip turned into its chest, neck and head on top of the pose just set (the rig
## sets every joint afresh each update, so nothing builds up).
func _turn_head() -> void:
	if pose == &"dead" or (is_zero_approx(look) and is_zero_approx(look_up)):
		return
	for j: int in LOOK_JOINTS.size():
		var joint: Node3D = avatar.rig.joint(LOOK_JOINTS[j])
		if joint == null:
			continue
		joint.rotate_object_local(Vector3.UP, look * LOOK_SHARE[j])
		joint.rotate_object_local(Vector3.RIGHT, look_up * TIP_SHARE[j])


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
		&"lie":
			body.set_pose(CyborgBody.Pose.LIE)
		&"crouch":
			body.set_pose(CyborgBody.Pose.CROUCH)
		_:
			body.set_pose(CyborgBody.Pose.WALK if speed > 0.1 else CyborgBody.Pose.IDLE)
	body.set_move_speed(speed)
	body.head_turn = Vector2(look, look_up)
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
