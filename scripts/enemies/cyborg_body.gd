class_name CyborgBody
extends Node3D
## The cyborgs' body (GDD §9.2) on the shared HumanoidRig (scripts/characters/), with CyborgSuit's
## parts: one skeleton for every cyborg, the zone look switched in as an attachment set (the sleek
## &"city" citizen or the patched-together &"scavenger" with a cracked, flickering visor), the LED
## visor face, the host's purple glitch (GDD §9.7) and the arm cannon's charge glow all drawn by one
## material per cyborg (cyborg_body.gdshader): 11 draw calls for a whole cyborg, 7 for a window
## cyborg's upper body. Visual only: it never touches collision or gameplay, and its randomness never
## uses the enemy's gameplay random stream.
##
## It poses the rig itself (HumanoidRig.apply_pose with HumanoidPoses and CyborgPoses, blended), so
## nothing here changes how the player's avatar moves.
##
## API (unchanged from the pre-rig body):
##   build(variant, host, upper_body_only, visual_seed)
##   set_pose(pose), set_move_speed(m/s), aim_at(world point) / clear_aim()
##   set_expression(face), set_charge(0–1: the arm cannon's charge glow, the attack telegraph)
##   muzzle_position(), flash() (hit), die(cause) (death animation; emits `death_finished`)
##   draw_call_count()
## The local front is +Z (the cyborg faces the player at rotation 0).

signal death_finished

enum Pose { IDLE, WALK, AIM, RUN_AWAY, COWER }

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
const Poses = preload("res://scripts/enemies/cyborg_poses.gd")
## Height of the hip joint (the rig's pelvis) above the soles.
const HIP_Y: float = 0.7
const FLASH_TIME: float = 0.08
const BLEND_SPEED: float = 14.0
## The scavenger stands hunched (degrees).
const HUNCH: float = 8.0
const FLASH_TINT := Color(1.0, 0.95, 0.9, 0.75)
const DEAD_TINT := Color(0.03, 0.03, 0.035, 0.55)
## Leg joints, hidden for a window cyborg's upper body.
const LEG_JOINTS: Array[int] = [HumanoidPose.THIGH_L, HumanoidPose.SHIN_L, HumanoidPose.FOOT_L,
	HumanoidPose.THIGH_R, HumanoidPose.SHIN_R, HumanoidPose.FOOT_R]

var variant: StringName = &"city"
var host: bool = false
var upper_body_only: bool = false
var pose: Pose = Pose.IDLE
var face: Kit.Face = Kit.Face.NEUTRAL
var charge: float = 0.0
var move_speed: float = 0.0
## Extra forward lean of the upper body (radians): the window cyborg leans out over the sill.
var lean: float = 0.0
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
var _vis_rng := RandomNumberGenerator.new()
var _glitch_left: float = 0.0
var _flash_left: float = 0.0
var _dead: bool = false


## Builds the body. `visual_seed` only varies visuals (glitch timing, idle sway).
func build(p_variant: StringName, p_host: bool = false, p_upper_body_only: bool = false,
		visual_seed: int = 0) -> void:
	variant = p_variant if p_variant == &"scavenger" else &"city"
	host = p_host
	upper_body_only = p_upper_body_only
	_vis_rng.seed = visual_seed
	_t = _vis_rng.randf() * 10.0
	_root = Node3D.new()
	_root.name = "Root"
	add_child(_root)
	material = CyborgSuit.new_material(variant, host, visual_seed)
	rig = HumanoidRig.new()
	rig.name = "Rig"
	rig.rotation.y = PI  # The rig faces -z; this body faces +z.
	_root.add_child(rig)
	rig.build(CyborgSuit.parts(), material, CyborgSuit.walk_tuning())
	var sets: Array[StringName] = [variant]
	rig.set_attachments(sets)
	if upper_body_only:
		var parts: Array[MeshInstance3D] = rig.part_instances()
		for joint: int in LEG_JOINTS:
			parts[joint].visible = false
	set_charge(0.0)
	set_expression(Kit.Face.NEUTRAL)
	_snap = true
	_animate(0.0)


func set_pose(p: Pose) -> void:
	pose = p


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
		material.set_shader_parameter(&"face", Kit.face_texture(f))


## The arm cannon's charge glow (0 = idle, 1 = about to fire): the visual half of the telegraph.
func set_charge(amount: float) -> void:
	charge = clampf(amount, 0.0, 1.0)
	if material != null:
		material.set_shader_parameter(&"charge", charge)


## World position of the arm cannon's tip (visual; gameplay shots use the enemy's own muzzle point).
func muzzle_position() -> Vector3:
	return rig.joint(&"forearm_r").global_transform * CyborgSuit.MUZZLE


## A short white flash when hit by a weapon.
func flash() -> void:
	if _dead:
		return
	_flash_left = FLASH_TIME
	material.set_shader_parameter(&"tint", FLASH_TINT)


## Draw calls of the visible body (one per segment mesh).
func draw_call_count() -> int:
	return rig.draw_call_count()


## The death animation (visual only). `cause`: &"stomp" squashes, &"claws" and &"dash" fling it out of
## the lane, anything else knocks it over. The window cyborg's upper body slumps over the sill and stays.
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
	if rig == null:
		return
	_t += delta
	_update_flash(delta)
	_update_visor(delta)
	if _dead and not upper_body_only:
		return  # The death tween moves the whole body; the pose holds.
	_animate(delta)


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
	if _glitch_left > 0.0:
		_glitch_left -= delta
		if _glitch_left <= 0.0:
			material.set_shader_parameter(&"face", Kit.face_texture(face))
		return
	if _vis_rng.randf() < delta * 1.6:
		_glitch_left = _vis_rng.randf_range(0.12, 0.45)
		var corrupt: Kit.Face = Kit.Face.CORRUPT_GRIN if _vis_rng.randf() < 0.5 else Kit.Face.CORRUPT_BROKEN
		material.set_shader_parameter(&"face", Kit.face_texture(corrupt))


## Builds this frame's target pose, blends toward it, poses the rig, then aims the cannon arm.
func _animate(delta: float) -> void:
	var walk: HumanoidAnimTuning = CyborgSuit.walk_tuning()
	var hunch: float = HUNCH if variant == &"scavenger" else 0.0
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
	_aim_arm(k)


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
