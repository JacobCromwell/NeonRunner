class_name CyborgBody
extends GunModel
## The cyborgs' body (GDD §9.2) on the shared HumanoidRig (scripts/characters/), with CyborgSuit's
## parts: one skeleton for every cyborg, the look switched in as an attachment set (the zone's look:
## the ragged "Static TV Head" base or one of its zone variants, CyborgSuit.look_for), the screen's
## face (on the look's screen, in its face set), the host's purple glitch and veins (GDD §9.7) and the
## weapon's charge glow all drawn by one material per cyborg (cyborg_body.gdshader): 11 draw calls for
## a whole cyborg, 7 for a window cyborg's upper body. Visual only: it never touches collision or
## gameplay, and its randomness never uses the enemy's gameplay random stream.
##
## It poses the rig itself (HumanoidRig.apply_pose with HumanoidPoses and CyborgPoses, blended), so
## nothing here changes how the player's avatar moves. The posture is hunched and the walk a shamble;
## the twitches and the free hand's tremor are added after the blend so they stay sharp.
##
## API (unchanged from the pre-rig body):
##   build(variant, host, upper_body_only, visual_seed)   variant: the skin's enemy_variant
##   set_pose(pose), set_move_speed(m/s), aim_at(world point) / clear_aim()
##   head_turn (yaw, pitch radians: its head turned on top of the pose), snap(), advance(delta)
##   set_expression(face), set_charge(0–1: the arm cannon's charge glow, the attack telegraph)
##   muzzle_position(), flash() (hit), die(cause) (death animation; emits `death_finished`)
##   draw_call_count()
## The local front is +Z (the cyborg faces the player at rotation 0).

signal death_finished

## LIE (lying still, its screen dark) and CROUCH (crouched low over something in front of it) are for
## cinematics (CineActorNode).
enum Pose { IDLE, WALK, AIM, RUN_AWAY, COWER, LIE, CROUCH }

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
const Poses = preload("res://scripts/enemies/cyborg_poses.gd")
## Height of the hip joint (the rig's pelvis) above the soles.
const HIP_Y: float = 0.7
## A weapon hit's white flash. With Settings > Reduced flashing it's a softer tint held longer, so
## rapid hits hold it steady instead of strobing.
const FLASH_TIME: float = 0.08
const SOFT_FLASH_TIME: float = 0.3
## A host's corrupted faces: chance per second and how long each shows (s); rarer and held longer
## with Reduced flashing, where its own face also shows for at least SOFT_GLITCH_TIME.x in between,
## so the face never changes more than about twice a second.
const GLITCH_RATE: float = 1.6
const GLITCH_TIME := Vector2(0.12, 0.45)
const SOFT_GLITCH_RATE: float = 0.6
const SOFT_GLITCH_TIME := Vector2(0.6, 1.0)
const BLEND_SPEED: float = 14.0
## A defeated cyborg's screen shows ERR for ERR_TIME seconds, then switches off over SCREEN_OFF_TIME
## (the picture collapses to a line and goes dark; with Reduced flashing it just fades). Both fit in
## the quickest death animation, the claws' and the dash's.
## DESIGN-TBD (docs/questions/p2.md 1): the brief proposes the ERR; whether to keep it, and how long.
const ERR_TIME: float = 0.2
const SCREEN_OFF_TIME: float = 0.14
const FLASH_TINT := Color(1.0, 0.95, 0.9, 0.75)
const SOFT_FLASH_TINT := Color(1.0, 0.95, 0.9, 0.3)
const DEAD_TINT := Color(0.03, 0.03, 0.035, 0.55)
## Leg joints, hidden for a window cyborg's upper body.
const LEG_JOINTS: Array[int] = [HumanoidPose.THIGH_L, HumanoidPose.SHIN_L, HumanoidPose.FOOT_L,
	HumanoidPose.THIGH_R, HumanoidPose.SHIN_R, HumanoidPose.FOOT_R]
## How head_turn is shared out: chest, neck, head.
const HEAD_JOINTS: Array[int] = [HumanoidPose.CHEST, HumanoidPose.NECK, HumanoidPose.HEAD]
const HEAD_TURN_SHARE: Array[float] = [0.25, 0.3, 0.45]
const HEAD_TIP_SHARE: Array[float] = [0.2, 0.35, 0.45]

## The skin's enemy_variant it was built for, and the look that dresses it (CyborgSuit.look_for).
var variant: StringName = &"city"
var look: StringName = CyborgSuit.BASE
var host: bool = false
var upper_body_only: bool = false
var pose: Pose = Pose.IDLE
var face: Kit.Face = Kit.Face.NEUTRAL
var charge: float = 0.0
var move_speed: float = 0.0
## Extra forward lean of the upper body (radians): the window cyborg leans out over the sill.
var lean: float = 0.0
## The screen's power (1 on, 0 dark): a defeated cyborg's switches off.
var screen_power: float = 1.0
## Its head turned on top of its pose (radians): x left (+) or right about its upright, y up (+) or down in the
## head's own frame. Its chest, neck and head share the turn (HEAD_TURN_SHARE) and the tip (HEAD_TIP_SHARE: the
## chest a little, so a crouched one straightens to look up).
var head_turn := Vector2.ZERO
## The shared rig and this cyborg's own material.
var rig: HumanoidRig
var material: ShaderMaterial

var _root: Node3D
var _cur := HumanoidPose.new()
var _tgt := HumanoidPose.new()
var _mix := HumanoidPose.new()
var _snap: bool = true
var _aim := Vector3.ZERO
var _aiming: bool = false
var _aim_w: float = 0.0
var _aim_q := Quaternion.IDENTITY
var _t: float = 0.0
var _phase: float = 0.0
var _twitch_phase: float = 0.0
var _vis_rng := RandomNumberGenerator.new()
var _glitch_left: float = 0.0
var _glitch_rest: float = 0.0
var _flash_left: float = 0.0
var _dead: bool = false
## Which way round it lies (Pose.LIE), from its visual seed, so two bodies don't lie alike.
var _lie_mirrored: bool = false


## Builds the body. `p_variant` is the skin's enemy_variant; `visual_seed` only varies visuals (glitch
## timing, idle sway, twitches).
func build(p_variant: StringName, p_host: bool = false, p_upper_body_only: bool = false,
		visual_seed: int = 0) -> void:
	variant = p_variant
	look = CyborgSuit.look_for(p_variant)
	host = p_host
	upper_body_only = p_upper_body_only
	_vis_rng.seed = visual_seed
	_lie_mirrored = visual_seed % 2 == 1
	_t = _vis_rng.randf() * 10.0
	_twitch_phase = _vis_rng.randf() * 10.0
	_root = Node3D.new()
	_root.name = "Root"
	add_child(_root)
	material = CyborgSuit.new_material(look, host, visual_seed)
	rig = HumanoidRig.new()
	rig.name = "Rig"
	rig.rotation.y = PI  # The rig faces -z; this body faces +z.
	_root.add_child(rig)
	rig.build(CyborgSuit.parts(), material, CyborgSuit.walk_tuning())
	rig.set_attachments(CyborgSuit.attachment_sets(look, host))
	if upper_body_only:
		var parts: Array[MeshInstance3D] = rig.part_instances()
		for joint: int in LEG_JOINTS:
			parts[joint].visible = false
	set_charge(0.0)
	set_expression(Kit.Face.NEUTRAL)
	_snap = true
	_animate(0.0)


func set_pose(p: Pose) -> void:
	if p == pose:
		return
	# Lying still, its screen is dark; up again, it comes back on.
	if p == Pose.LIE and not _dead:
		_set_screen_power(0.0)
	elif pose == Pose.LIE and not _dead:
		_set_screen_power(1.0)
	pose = p


## The next animation step snaps to its pose instead of blending into it (a cinematic's first frame).
func snap() -> void:
	_snap = true


## Walking or running speed, for the stride.
func set_move_speed(speed: float) -> void:
	move_speed = speed


## Points the arm cannon at a world point until clear_aim().
func aim_at(world_point: Vector3) -> void:
	if not _aiming:
		_aim_q = rig.joint(&"upper_arm_r").quaternion
	_aim = world_point
	_aiming = true


func clear_aim() -> void:
	_aiming = false


func set_expression(f: Kit.Face) -> void:
	face = f
	if material != null and _glitch_left <= 0.0:
		material.set_shader_parameter(&"face", CyborgSuit.face_texture(look, f))


## The arm cannon's charge glow (0 = idle, 1 = about to fire): the visual half of the telegraph.
func set_charge(amount: float) -> void:
	charge = clampf(amount, 0.0, 1.0)
	if material != null:
		material.set_shader_parameter(&"charge", charge)


## World position of the arm cannon's tip (visual; gameplay shots use the enemy's own muzzle point).
func muzzle_position() -> Vector3:
	return rig.joint(&"forearm_r").global_transform * CyborgSuit.MUZZLE


## A short white flash when hit by a weapon (softer and steady with Reduced flashing).
func flash() -> void:
	if _dead:
		return
	var soft: bool = Settings.flashing_reduced
	_flash_left = SOFT_FLASH_TIME if soft else FLASH_TIME
	material.set_shader_parameter(&"tint", SOFT_FLASH_TINT if soft else FLASH_TINT)


## Draw calls of the visible body (one per segment mesh).
func draw_call_count() -> int:
	return rig.draw_call_count()


## The death animation (visual only). The screen shows ERR, then switches off. `cause`: &"stomp"
## squashes, &"claws" and &"dash" fling it out of the lane, anything else knocks it over. The window
## cyborg's upper body slumps over the sill and stays, its screen dark.
func die(cause: StringName) -> void:
	if _dead:
		return
	_dead = true
	_flash_left = 0.0
	_glitch_left = 0.0
	_aiming = false
	set_charge(0.0)
	set_expression(Kit.Face.DEAD)
	material.set_shader_parameter(&"glitch", 0.0)
	material.set_shader_parameter(&"tint", DEAD_TINT)
	material.set_shader_parameter(&"glow_boost", 0.0)
	var screen := create_tween()
	screen.tween_interval(ERR_TIME)
	screen.tween_method(_set_screen_power, 1.0, 0.0, SCREEN_OFF_TIME)
	var tween := create_tween()
	if upper_body_only:
		tween.tween_interval(0.35)
		tween.tween_callback(func() -> void: death_finished.emit())
		return
	if cause == &"stomp":
		tween.tween_property(_root, "scale", Vector3(1.35, 0.3, 1.35), 0.1).set_trans(Tween.TRANS_QUAD)
		tween.tween_interval(0.25)
	elif cause == &"claws" or cause == &"dash":
		# Knocked aside out of the lane at once, so the body doesn't block the view as the player
		# runs through it.
		var s: float = -1.0 if _vis_rng.randf() < 0.5 else 1.0
		tween.tween_property(_root, "position", Vector3(s * 1.3, 0.35, -0.6), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_root, "rotation", Vector3(-0.6, 0.0, -s * 1.4), 0.18)
	else:
		tween.tween_property(_root, "rotation", Vector3(-1.45, 0.0, 0.0), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_interval(0.12)
	tween.tween_property(_root, "scale", Vector3(0.05, 0.05, 0.05), 0.16)
	tween.tween_callback(func() -> void: death_finished.emit())


func _process(delta: float) -> void:
	advance(delta)


## Moves it on by `delta` seconds: its twitches, glitches and flashes, and its pose blending toward the one set.
## It runs by itself each frame (_process); a cinematic drives it on its own clock instead (CineActorNode, with
## processing off), so stepping the clock shows the same.
func advance(delta: float) -> void:
	if rig == null:
		return
	_t += delta
	_update_flash(delta)
	_update_visor(delta)
	if _dead and not upper_body_only:
		return  # The death tween moves the whole body; the pose holds.
	_animate(delta)


func _set_screen_power(value: float) -> void:
	screen_power = value
	material.set_shader_parameter(&"screen_power", value)


func _update_flash(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left <= 0.0 and not _dead:
		material.set_shader_parameter(&"tint", Color(1.0, 1.0, 1.0, 0.0))


## Hosts cycle through corrupted faces now and then (GDD §9.7).
func _update_visor(delta: float) -> void:
	if not host or _dead:
		return
	var soft: bool = Settings.flashing_reduced
	if _glitch_left > 0.0:
		_glitch_left -= delta
		if _glitch_left <= 0.0:
			material.set_shader_parameter(&"face", CyborgSuit.face_texture(look, face))
			_glitch_rest = SOFT_GLITCH_TIME.x if soft else 0.0
		return
	if _glitch_rest > 0.0:
		_glitch_rest -= delta
		return
	if _vis_rng.randf() < delta * (SOFT_GLITCH_RATE if soft else GLITCH_RATE):
		var span: Vector2 = SOFT_GLITCH_TIME if soft else GLITCH_TIME
		_glitch_left = _vis_rng.randf_range(span.x, span.y)
		var corrupt: Kit.Face = Kit.Face.CORRUPT_GRIN if _vis_rng.randf() < 0.5 else Kit.Face.CORRUPT_BROKEN
		material.set_shader_parameter(&"face", CyborgSuit.face_texture(look, corrupt))


## Builds this frame's target pose, blends toward it, poses the rig, adds the twitches and the tremor,
## then aims the cannon arm.
func _animate(delta: float) -> void:
	var walk: HumanoidAnimTuning = CyborgSuit.walk_tuning()
	var hunch: float = Poses.HUNCH
	var speed: float = move_speed
	if upper_body_only:
		if _dead:
			Poses.slump(_tgt)
		else:
			Poses.window(_tgt, _t, walk, rad_to_deg(lean))
	else:
		match pose:
			Pose.WALK:
				_advance_phase(speed, delta, walk)
				Poses.walk(_tgt, _phase, clampf(speed / walk.full_stride_speed, 0.0, 1.0), walk, hunch)
			Pose.AIM:
				Poses.aim(_tgt, _t, walk, hunch)
			Pose.RUN_AWAY:
				var run: HumanoidAnimTuning = CyborgSuit.run_tuning()
				_advance_phase(speed, delta, run)
				Poses.run_away(_tgt, _phase, _t, run)
			Pose.COWER:
				Poses.cower(_tgt, _t)
			Pose.LIE:
				Poses.lie(_tgt, _lie_mirrored)
			Pose.CROUCH:
				# Turning its head to look up from its work, it stops.
				Poses.crouch(_tgt, _t + _twitch_phase, 1.0 - smoothstep(0.2, 0.8, absf(head_turn.x)))
			_:
				Poses.idle(_tgt, _t, walk, hunch)
	if _aiming and pose != Pose.RUN_AWAY and not _dead:
		_tgt.rot[HumanoidPose.CHEST].y += _aim_yaw()
	var k: float = 1.0 if _snap else 1.0 - exp(-BLEND_SPEED * delta)
	_snap = false
	_mix.clear_sum()
	_mix.accumulate(_cur, 1.0 - k)
	_mix.accumulate(_tgt, k)
	_mix.finish(1.0)
	var tmp: HumanoidPose = _cur
	_cur = _mix
	_mix = tmp
	rig.apply_pose(_cur)
	_add_jitter()
	_turn_head()
	_aim_arm(k)


## The twitches (standing, walking, crouching and in a window; not while aiming, fleeing, cowering, lying
## still or dead) and the tremor (not while fleeing, lying still or dead), straight onto the posed joints.
func _add_jitter() -> void:
	if _dead or (not upper_body_only and (pose == Pose.RUN_AWAY or pose == Pose.LIE)):
		return
	var twitching: bool = upper_body_only or pose == Pose.IDLE or pose == Pose.WALK or pose == Pose.CROUCH
	var extra: Dictionary = Poses.jitter(_t, _twitch_phase, twitching and not _aiming)
	for joint: int in extra:
		var node: Node3D = rig.joint(HumanoidRig.JOINT_NAMES[joint])
		node.rotation += extra[joint]


## head_turn, straight onto the posed joints: the head lifted in its own frame, then turned about the upright,
## so a bowed head (crouched) turns to look without rolling over.
func _turn_head() -> void:
	if head_turn == Vector2.ZERO or _dead or not is_inside_tree():
		return
	for j: int in HEAD_JOINTS.size():
		var node: Node3D = rig.joint(HumanoidRig.JOINT_NAMES[HEAD_JOINTS[j]])
		node.rotate_object_local(Vector3.RIGHT, head_turn.y * HEAD_TIP_SHARE[j])
		var up: Vector3 = global_basis.y.normalized()
		node.global_rotate(up, head_turn.x * HEAD_TURN_SHARE[j])


## The stride follows the ground covered (like the player's), so the feet don't skate.
func _advance_phase(speed: float, delta: float, t: HumanoidAnimTuning) -> void:
	var amount: float = clampf(speed / t.full_stride_speed, 0.0, 1.0)
	var stride: float = maxf(t.stride_length * maxf(amount, 0.2), speed / t.max_cadence)
	_phase = fposmod(_phase + speed * delta / stride, 1.0)


## The chest turns toward the aim point (limited); the arm does the rest.
func _aim_yaw() -> float:
	var pelvis: Node3D = rig.joint(&"pelvis")
	var local: Vector3 = pelvis.global_transform.affine_inverse() * _aim
	return clampf(atan2(-local.x, -local.z), -1.0, 1.0)


## Points the cannon arm straight at the aim point, blended in and out smoothly.
func _aim_arm(k: float) -> void:
	_aim_w = lerpf(_aim_w, 1.0 if _aiming and not _dead else 0.0, k)
	if _aim_w < 0.001:
		return
	var shoulder: Node3D = rig.joint(&"upper_arm_r")
	var chest: Node3D = rig.joint(&"chest")
	var dir: Vector3 = _aim - shoulder.global_position
	if dir.length_squared() > 0.0001:
		var local: Vector3 = (chest.global_basis.orthonormalized().inverse() * dir).normalized()
		_aim_q = _aim_q.slerp(Quaternion(Vector3.DOWN, local), k)
	shoulder.quaternion = shoulder.quaternion.slerp(_aim_q, _aim_w)
	var fore: Node3D = rig.joint(&"forearm_r")
	fore.quaternion = fore.quaternion.slerp(Quaternion.IDENTITY, _aim_w)
