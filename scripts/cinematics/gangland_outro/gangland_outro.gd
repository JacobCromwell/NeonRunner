class_name GanglandOutro
extends CinematicSequencer
## Gangland's outro, after the Sewer Swarm (the owner's beats, October 9, 2026; GDD §6 Cinematics):
## 1. The Host lies in the rubble where the fight ended, freed, their implants dark. A few screeches sniff at them
##    for a moment, look up as the runner comes walking down the street, and scuttle away into the gutters.
## 2. The runner walks over (the camera over their shoulder) and stops beside the Host.
## 3. The Host trembles, looks up at them and, with a shaking hand, holds up a golden key; it glints; the runner
##    takes it, and the Host sinks back. The runner looks at the key. Fade to black.
## 4. Cut to another stretch of the street: a sleek, flashy sports car, angular and almost triangular, like a
##    Lambo (SportsCarModel), parked there. The runner walks up holding out the key; the car unlocks with a chirp
##    of its lights, its scissor door swings up, they get in, and the door comes down. Its lights come on and
##    its engine starts.
## 5. At road level behind it, it launches and drives off down the street into the distance. Fade to black;
##    the Marketplace's intro follows.
##
## A script on the toolkit, its numbers data (`numbers`, by default data/cinematics/gangland_outro_tuning.tres,
## GanglandOutroTuning). Both stretches pick up where the fight ended (CineStageDef.after_fight: the arena's look
## and the sky the fight was under), on the level's lanes. The rubble, the Host and the screeches are the first
## scene's props (GanglandOutroSet), the car the second's; the key is the cinematic's own, since it goes from the
## first scene into the second. Everything is worked out from the time (_on_advance), so stepping or skipping
## shows the same. DESIGN-TBD (docs/questions/f2c.md): the staging the beats leave open.

const NUMBERS_PATH: String = "res://data/cinematics/gangland_outro_tuning.tres"
## The runner walks up to the car this fast, a little brisker than to the Host.
const CAR_WALK_SPEED: float = 2.1
## The runner's arms and head, overridden on top of their pose: how quickly each move blends in and out.
const ARM_BLEND: float = 0.3
## Leaning in to take the key (radians, forward from the hips).
const REACH_LEAN: float = 0.5
## The key in a hand: where it sits in the hand joint's space (metres) and how it's turned there.
const KEY_IN_HAND := Vector3(0.0, -0.07, -0.02)
const KEY_TURN := Vector3(-1.2, 0.0, 0.0)
## The key's handover from the Host's hand to the runner's takes this long.
const HANDOVER_SECONDS: float = 0.25
## The glint: its halo's size and how long it swells and fades (a slow glow, so it suits Reduced flashing too).
const GLINT_SIZE: float = 0.55
const GLINT_SECONDS: float = 0.9
## The unlock's blink: two quick blinks of the lights (with Reduced flashing, one slow glow, half as bright).
const UNLOCK_SECONDS: float = 0.7
const UNLOCK_SOFT: float = 0.5
## The shots looking back up the street see this far (metres; Gangland's fog is full by about 165 m): the street
## stays built from LOOK_BACK + 30 m behind (TrackBuilder.KEEP_BEHIND).
const LOOK_BACK: float = 140.0
## Where the runner's hips sit in the car (metres up, in a car 1 m tall): high enough that their coat stays inside it.
const SEAT_HEIGHT: float = 0.36
## The engine idling before the launch: a fine shudder (metres) and the squat as it launches (degrees).
const IDLE_SHAKE: float = 0.004
const LAUNCH_SQUAT: float = 1.2
## The wheels spin up this much faster than the car goes for a moment at the launch (metres of extra turn).
const WHEELSPIN: float = 2.5

## Its numbers (null: NUMBERS_PATH's).
@export var numbers: GanglandOutroTuning

var n: GanglandOutroTuning
## The first scene's props, the car, and the key (with its glint).
var props: GanglandOutroSet
var car: SportsCarModel
var key: Node3D
var key_glint: MeshInstance3D
## True once it has cut to the car's street.
var at_car: bool = false
## Where things are (track space): the Host's middle, where the runner stops by them, the car's middle (parked),
## the runner's place at its door, and their seat in it.
var host_point := Vector3.ZERO
var stop_point := Vector3.ZERO
var car_point := Vector3.ZERO
var door_point := Vector3.ZERO
var seat_point := Vector3.ZERO
## When things happen (seconds): the runner reaches the Host, the key is taken, the cut, the runner reaches the
## car's door, and is gone into it.
var t_arrive: float = 0.0
var t_take: float = 0.0
var t_cut: float = 0.0
var t_at_door: float = 0.0
var t_inside: float = 0.0
## Who holds the key now: &"host", &"runner" or &"" (no one: it's out of sight).
var key_holder: StringName = &"host"
## How far the car has driven now (metres).
var driven: float = 0.0

var _glint_material: ShaderMaterial
var _sink_height: float = -1.0


func _numbers() -> GanglandOutroTuning:
	if numbers == null:
		numbers = load(NUMBERS_PATH) as GanglandOutroTuning
	return numbers


func _stage_def() -> CineStageDef:
	n = _numbers()
	_plan()
	var d := CineStageDef.new()
	d.length = n.stage_length
	d.after_fight = true
	return d


## Where and when things happen, from the numbers.
func _plan() -> void:
	host_point = Vector3(n.host_x, 0.0, n.host_at)
	stop_point = host_point + n.stop_offset
	t_arrive = n.walk_from + n.walk_back / maxf(n.walk_speed, 0.1)
	t_take = n.reach_at + n.reach_seconds
	t_cut = n.black_at + n.black_seconds + n.black_hold
	car_point = Vector3(n.car_x, 0.0, n.car_at)
	# Car space runs along world z, against track space's z.
	var step: Vector3 = SportsCarModel.door_step_of(n.car_size)
	door_point = car_point + Vector3(step.x - n.door_gap, 0.0, -step.z)
	var seat: Vector3 = SportsCarModel.seat_of(n.car_size)
	seat_point = car_point + Vector3(seat.x, 0.0, -seat.z)
	var approach: Vector3 = car_point + n.approach_from
	t_at_door = t_cut + approach.distance_to(door_point) / CAR_WALK_SPEED
	# Out of sight once the door is half down: the cabin behind it is dark.
	t_inside = n.door_down_at + n.door_seconds * 0.45


func _make_timeline() -> CineTimeline:
	var t := CineTimeline.new()
	t.duration = n.duration
	t.letterbox = true
	props = GanglandOutroSet.new()
	stage.add_child(props)
	props.setup(self)
	_build_key()
	_runner(t)
	_camera(t)
	_events(t)
	return t


func _build_key() -> void:
	key = Node3D.new()
	key.name = "Key"
	add_child(key)
	var mesh := MeshBatch.add_instance(key, GanglandOutroSet.key_mesh(n.key_length), "Gold")
	mesh.material_override = SportsCarModel.material()
	_glint_material = (MeshKit.glow({"glow_scale": 2.0}).duplicate()) as ShaderMaterial
	key_glint = MeshBatch.add_instance(key, GanglandOutroSet.glint_mesh(GLINT_SIZE), "Glint")
	key_glint.material_override = _glint_material
	key_glint.visible = false


# --- The runner ------------------------------------------------------------------------------------

## Where the runner is on the first stretch at `t` (track space): walking down the street toward the Host at
## an even pace, slowing over the last half second, then standing beside them.
func runner_track(t: float) -> Vector3:
	var settle: float = 0.5
	var v: float = n.walk_speed
	var behind: float = 0.0
	if t < t_arrive - settle:
		behind = v * (t_arrive - settle - t) + v * settle * 0.5
	elif t < t_arrive:
		var e: float = t_arrive - t
		behind = v * e * e / (2.0 * settle)
	return stop_point - Vector3(0.0, 0.0, behind)


func _runner(t: CineTimeline) -> void:
	var r: CineActor = t.actor(&"runner")
	# The walk up to the Host: a key every half second (straight moves at the pace), then facing them.
	var at: float = 0.0
	var first: bool = true
	while at < t_arrive - 0.001:
		r.at(at, runner_track(at), &"run" if first else &"")
		first = false
		at = minf(at + 0.5, t_arrive)
	r.at(t_arrive, stop_point)
	var to_host: Vector3 = host_point - stop_point
	var facing: float = -rad_to_deg(atan2(to_host.x, to_host.z))
	_turned(_eased(r.at(t_arrive + 0.45, stop_point)), facing, 0.0)
	_turned(r.at(t_cut - 0.02, stop_point), facing, 0.0)
	# Cut to the car's street: walking up to its door, then facing it.
	var approach: Vector3 = car_point + n.approach_from
	var come: CineActorKey = r.at(t_cut, approach)
	come.move = CinePath.Move.CUT
	come.face_path = true
	# Slowing over the last 0.4 s (an eased stop covers half the ground the pace would).
	var slowing: float = 0.4 * CAR_WALK_SPEED * 0.5
	r.at(t_at_door - 0.4, door_point + (approach - door_point).normalized() * slowing)
	_eased(r.at(t_at_door, door_point), Tween.TRANS_QUAD, Tween.EASE_OUT)
	_turned(_eased(r.at(t_at_door + 0.35, door_point)), -90.0, 0.0)
	_turned(r.at(n.get_in_at, door_point), -90.0, 0.0)
	# In: across the sill to the seat, turning to face down the street (_on_advance sits them down).
	_turned(_eased(r.at(n.get_in_at + n.get_in_seconds, seat_point)), 0.0, 0.0)
	r.leave = t_inside


## A key eased in and out (a LINEAR move with a sine curve), or with the curve given.
static func _eased(k: CineActorKey, trans: Tween.TransitionType = Tween.TRANS_SINE,
		easing: Tween.EaseType = Tween.EASE_IN_OUT) -> CineActorKey:
	k.trans = trans
	k.easing = easing
	return k


## A key that holds a heading (`body` degrees, + left) and a look (`head` degrees, + left).
static func _turned(k: CineActorKey, body: float, head: float) -> CineActorKey:
	k.face_path = false
	k.yaw = body
	k.look = head
	return k


# --- The camera ------------------------------------------------------------------------------------

func _camera(t: CineTimeline) -> void:
	var h: Vector3 = host_point
	# Low beside the Host, looking back up the street as the runner comes and the screeches scatter.
	t.shot(0.0, h + n.rubble_cam, h + n.rubble_look, CinePath.Move.SMOOTH, n.rubble_fov)
	t.shot(n.follow_at - 0.004, h + n.rubble_cam_end, h + n.rubble_look, CinePath.Move.SMOOTH, n.rubble_fov)
	# Cut: over the runner's shoulder as they walk up to the Host.
	var follow: CineCameraKey = t.shot(n.follow_at, n.follow_cam, h + Vector3(0.0, 0.45, 0.0), CinePath.Move.CUT,
		n.follow_fov)
	follow.follow = &"runner"
	var follow_end: CineCameraKey = t.shot(n.handoff_at - 0.004, n.follow_cam + Vector3(0.0, -0.1, 0.3),
		h + Vector3(0.0, 0.4, 0.0), CinePath.Move.SMOOTH, n.follow_fov)
	follow_end.follow = &"runner"
	# Cut: close and low across the Host for the key, pushing in, then up a little to the runner holding it.
	t.shot(n.handoff_at, h + n.handoff_cam, h + n.handoff_look, CinePath.Move.CUT, n.handoff_fov)
	t.shot(n.admire_at, h + n.handoff_cam.lerp(n.handoff_cam_end, 0.6), h + n.handoff_look + Vector3(0.0, 0.1, 0.0),
		CinePath.Move.SMOOTH, n.handoff_fov)
	t.shot(t_cut - 0.004, h + n.handoff_cam_end, h + n.handoff_look + Vector3(-0.15, 0.3, -0.1), CinePath.Move.SMOOTH,
		n.handoff_fov)
	# Cut (under black): low off the car's front corner, gliding round to its side as the runner comes to it.
	var c: Vector3 = car_point
	t.shot(t_cut, c + n.reveal_cam, c + n.reveal_look, CinePath.Move.CUT, n.reveal_fov)
	t.shot(n.road_at - 0.004, c + n.reveal_cam_end, c + n.reveal_look_end, CinePath.Move.SMOOTH, n.reveal_fov)
	# Cut: on the road behind it, at road level, as it drives off into the distance.
	t.shot(n.road_at, c + n.road_cam, c + n.road_look, CinePath.Move.CUT, n.road_fov)
	t.shot(n.duration, c + n.road_cam, c + n.road_look + Vector3(0.0, -0.1, 40.0), CinePath.Move.SMOOTH,
		n.road_fov - 4.0)


## The street stays built far enough back up it for the shots that look back up it (the first, at the runner
## coming, and the car's reveal): the track builder keeps only 30 m behind the nearest point and builds 180 m
## ahead of it, so after those shots it builds on ahead for the ones looking down the street.
func _stage_near(near: float) -> float:
	if not at_car and time < n.follow_at:
		return minf(near, n.host_at - LOOK_BACK)
	if at_car and time < n.road_at:
		return minf(near, n.car_at - LOOK_BACK)
	return near


# --- Sounds, effects and cues -------------------------------------------------------------------------

func _events(t: CineTimeline) -> void:
	t.effect(0.0, CineEvent.FADE_IN, n.fade_in)
	# The fight's music fades out: a quiet aftermath. DESIGN-TBD (docs/questions/f2c.md): no music of its own.
	t.music(0.0, &"", n.music_fade)
	t.sound(0.35, &"screech_sniff")
	t.sound(1.1, &"host_short")
	t.sound(n.scuttle_at, &"swarm_scatter")
	t.cue(n.scuttle_at, &"scuttle")
	t.sound(n.glint_at, &"key_glint")
	t.cue(n.glint_at, &"glint")
	t.cue(t_take, &"take")
	t.effect(n.black_at, CineEvent.FADE_OUT, n.black_seconds)
	t.cue(t_cut, &"car")
	t.effect(t_cut, CineEvent.FADE_IN, n.fade_in)
	t.sound(n.unlock_at, &"car_unlock")
	t.cue(n.unlock_at, &"unlock")
	t.sound(n.door_up_at, &"car_door")
	t.sound(n.door_down_at, &"car_door")
	t.sound(n.lights_at, &"car_start")
	t.cue(n.lights_at, &"lights")
	t.sound(n.launch_at, &"car_drive")
	t.cue(n.launch_at, &"launch")
	t.effect(n.launch_at, CineEvent.SHAKE, 0.5, 0.05)
	t.effect(n.duration - n.fade_out, CineEvent.FADE_OUT, n.fade_out)


func _on_cue(cue_name: StringName) -> void:
	if cue_name == &"car":
		_to_car()


## Under black: cuts to another stretch of the fight's street, the car parked on it.
func _to_car() -> void:
	var d := CineStageDef.new()
	d.length = n.stage_length
	d.after_fight = true
	switch_stage(d)
	at_car = true
	props = null
	car = SportsCarModel.new()
	car.name = "Car"
	stage.add_child(car)
	car.build(n.car_size, n.car_paint, n.car_accent)
	car.global_position = stage.point(car_point)


## Over (played out or skipped): the key goes with the rest of it.
func _finish() -> void:
	if key != null and not done:
		key.visible = false
	super()


# --- On the clock ------------------------------------------------------------------------------------

func _on_advance(_delta: float) -> void:
	if n == null:
		return
	if props != null and not at_car:
		props.update(time)
	var runner := actors.get(&"runner") as CineActorNode
	if runner != null and runner.avatar != null and runner.visible:
		_pose_runner(runner)
	if car != null:
		_drive_car()
	_place_key(runner)


## The runner's arms and head on top of their pose: reaching for the key and looking at it; holding it out to
## the car; sitting down in it.
func _pose_runner(runner: CineActorNode) -> void:
	var rig: HumanoidRig = runner.avatar.rig
	if not at_car:
		var reach: float = _window(time, n.reach_at, t_take, n.admire_at, n.admire_at + ARM_BLEND)
		if reach > 0.0 and props != null:
			# Leaning in and down to the Host's hand, then reaching for it.
			_lean(rig, reach)
			aim_arm(rig, &"r", props.host_hand().global_position, reach)
		var admire: float = smoothstep(n.admire_at, n.admire_at + 0.5, time)
		if admire > 0.0:
			_hold_up(rig, admire, 100.0)
			_nod(rig, admire * 0.45)
		return
	# Holding the key out to the car as it unlocks.
	var raise: float = _window(time, n.unlock_at - 0.35, n.unlock_at, n.unlock_at + 0.45, n.unlock_at + 0.8)
	if raise > 0.0:
		aim_arm(rig, &"r", stage.point(car_point + Vector3(0.0, 0.6, 0.0)), raise)
	# Sitting down into the seat, lowered as their legs fold.
	var sit: float = smoothstep(n.get_in_at, n.get_in_at + n.get_in_seconds, time)
	if sit > 0.0:
		if _sink_height < 0.0:
			_sink_height = rig.joint(&"pelvis").global_position.y - runner.global_position.y
		_sit(rig, sit)
		var seat_y: float = SEAT_HEIGHT * SportsCarModel.scale_of(n.car_size).y
		runner.position.y -= (_sink_height - seat_y) * sit
		# Over the sill on the way in.
		runner.position.y += 0.25 * sin(PI * sit)


## 0 before `a`, rising to 1 by `b`, 1 until `c`, falling to 0 by `d` (eased).
static func _window(t: float, a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, maxf(b, a + 0.001), t) * (1.0 - smoothstep(c, maxf(d, c + 0.001), t))


## Turns a rig's arm (`side` &"l" or &"r") toward `target` (world space) by `k` (0-1), the forearm straightening:
## the upper arm hangs along -y at rest, so it turns the shortest way from there to the target.
static func aim_arm(rig: HumanoidRig, side: StringName, target: Vector3, k: float) -> void:
	var upper: Node3D = rig.joint(StringName("upper_arm_%s" % side))
	var fore: Node3D = rig.joint(StringName("forearm_%s" % side))
	if upper == null or k <= 0.0:
		return
	var parent := upper.get_parent() as Node3D
	var dir: Vector3 = target - upper.global_position
	if dir.length_squared() < 0.0001:
		return
	var local_dir: Vector3 = (parent.global_basis.inverse() * dir).normalized()
	if local_dir.dot(Vector3.UP) > 0.999:
		return
	upper.quaternion = upper.quaternion.slerp(Quaternion(Vector3.DOWN, local_dir), k)
	if fore != null:
		fore.quaternion = fore.quaternion.slerp(Quaternion.IDENTITY, k)


## The right hand brought up in front of the chest (the elbow bent `bend` degrees), by `k`.
static func _hold_up(rig: HumanoidRig, k: float, bend: float) -> void:
	_blend_joint(rig, &"upper_arm_r", Vector3(30.0, -25.0, 8.0), k)
	_blend_joint(rig, &"forearm_r", Vector3(bend, 0.0, 0.0), k)
	_blend_joint(rig, &"hand_r", Vector3(-10.0, 0.0, 0.0), k)


## Leaning forward from the hips (to reach down to someone lying there), by `k`.
static func _lean(rig: HumanoidRig, k: float) -> void:
	var chest: Node3D = rig.joint(&"chest")
	if chest != null:
		chest.rotate_object_local(Vector3.RIGHT, -REACH_LEAN * k)


## The head tipped down (toward what they hold), by `k` (radians at 1).
static func _nod(rig: HumanoidRig, k: float) -> void:
	var head: Node3D = rig.joint(&"head")
	if head != null:
		head.rotate_object_local(Vector3.RIGHT, -0.5 * k)


## Seated low (driving): thighs forward, legs stretched out ahead, leaning back a little, hands forward on the
## wheel, by `k`.
static func _sit(rig: HumanoidRig, k: float) -> void:
	for side: String in ["l", "r"]:
		var s: float = 1.0 if side == "r" else -1.0
		_blend_joint(rig, StringName("thigh_%s" % side), Vector3(84.0, 0.0, 6.0 * s), k)
		_blend_joint(rig, StringName("shin_%s" % side), Vector3(-28.0, 0.0, 0.0), k)
		_blend_joint(rig, StringName("upper_arm_%s" % side), Vector3(38.0, 0.0, 8.0 * s), k)
		_blend_joint(rig, StringName("forearm_%s" % side), Vector3(42.0, 0.0, 0.0), k)
	_blend_joint(rig, &"chest", Vector3(20.0, 0.0, 0.0), k)


## A joint blended toward a rotation (degrees, Euler as Node3D.rotation; the left side's y and z mirrored by
## the caller), by `k`.
static func _blend_joint(rig: HumanoidRig, joint_name: StringName, degrees: Vector3, k: float) -> void:
	var j: Node3D = rig.joint(joint_name)
	if j == null:
		return
	var target := Quaternion.from_euler(degrees * (PI / 180.0))
	j.quaternion = j.quaternion.slerp(target, clampf(k, 0.0, 1.0))


## The key in the hand holding it: the Host's until the runner takes it (handed over smoothly), then the
## runner's; out of sight with the runner once they're in the car.
func _place_key(runner: CineActorNode) -> void:
	if key == null:
		return
	var host_xf: Transform3D = _in_hand(props.host_hand()) if props != null and not at_car else Transform3D()
	var runner_xf: Transform3D = Transform3D()
	var runner_hand: Node3D = runner.avatar.rig.joint(&"hand_r") if runner != null and runner.avatar != null else null
	if runner_hand != null:
		runner_xf = _in_hand(runner_hand)
	var handed: float = clampf((time - t_take) / HANDOVER_SECONDS, 0.0, 1.0)
	if at_car:
		key_holder = &"runner" if runner != null and runner.visible else &""
		key.visible = key_holder != &""
		key.global_transform = runner_xf
	elif handed <= 0.0:
		key_holder = &"host"
		key.visible = true
		key.global_transform = host_xf
	else:
		key_holder = &"runner"
		key.visible = true
		var e: float = smoothstep(0.0, 1.0, handed)
		key.global_transform = Transform3D(host_xf.basis.slerp(runner_xf.basis, e),
			host_xf.origin.lerp(runner_xf.origin, e))
	# The glint: a soft halo swelling and fading over the key once.
	var g: float = clampf((time - n.glint_at) / GLINT_SECONDS, 0.0, 1.0)
	var glow: float = sin(PI * g) if time >= n.glint_at and g < 1.0 else 0.0
	key_glint.visible = glow > 0.001 and key.visible
	_glint_material.set_shader_parameter(&"state_glow", glow)
	if key_glint.visible and camera != null:
		# Facing the camera.
		key_glint.global_basis = camera.global_basis


## Where the key sits in a hand joint (world space, unscaled).
static func _in_hand(hand: Node3D) -> Transform3D:
	if hand == null:
		return Transform3D()
	var b: Basis = hand.global_basis.orthonormalized()
	return Transform3D(b * Basis.from_euler(KEY_TURN), hand.global_position + b * KEY_IN_HAND)


## The car: its lights blinking as it unlocks and coming on, its door up and down, idling, then launching and
## driving off down the street, its wheels turning (and spinning up at the launch).
func _drive_car() -> void:
	var lights: float = 0.0
	var u: float = (time - n.unlock_at) / UNLOCK_SECONDS
	if u >= 0.0 and u < 1.0:
		if Settings.flashing_reduced:
			lights = UNLOCK_SOFT * sin(PI * u)
		else:
			lights = clampf(sin(TAU * u) * 1.6, 0.0, 1.0) if u < 0.5 else clampf(sin(TAU * (u - 0.5)) * 1.6, 0.0, 1.0)
	lights = maxf(lights, smoothstep(n.lights_at, n.lights_at + 0.35, time))
	car.set_lights(lights)
	var up: float = smoothstep(n.door_up_at, n.door_up_at + n.door_seconds, time)
	var down: float = smoothstep(n.door_down_at, n.door_down_at + n.door_seconds, time)
	car.set_door(up * (1.0 - down))
	driven = car_distance(time)
	var spin: float = 0.0
	if time > n.launch_at:
		spin = WHEELSPIN * smoothstep(0.0, 0.25, time - n.launch_at) * (1.0 - smoothstep(0.25, 0.8, time - n.launch_at))
	car.set_travelled(driven + spin)
	var pos: Vector3 = car_point + Vector3(0.0, 0.0, driven)
	var shudder: float = 0.0
	if time > n.lights_at and time < n.launch_at + 0.3:
		shudder = IDLE_SHAKE * sin(TAU * 31.0 * time)
	var squat: float = 0.0
	if time > n.launch_at:
		squat = deg_to_rad(LAUNCH_SQUAT) * sin(PI * clampf((time - n.launch_at) / 0.9, 0.0, 1.0))
	car.global_transform = Transform3D(Basis(Vector3.RIGHT, squat), stage.point(pos + Vector3(0.0, shudder, 0.0)))


## How far the car has driven by `t` (metres): nothing until the launch, then accelerating to its top speed.
func car_distance(t: float) -> float:
	var e: float = t - n.launch_at
	if e <= 0.0:
		return 0.0
	var a: float = n.acceleration
	var reach: float = n.top_speed / a
	if e <= reach:
		return 0.5 * a * e * e
	return 0.5 * a * reach * reach + n.top_speed * (e - reach)


## Draw calls its props add now (each visible mesh's surfaces): tests.
func props_draw_calls() -> int:
	var count: int = 0
	var roots: Array[Node] = [key]
	if props != null:
		roots.append(props)
	if car != null:
		roots.append(car)
	for root: Node in roots:
		if root == null:
			continue
		for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
			var g := node as MeshInstance3D
			if g == null or not g.is_visible_in_tree() or g.mesh == null:
				continue
			count += g.mesh.get_surface_count()
	return count
