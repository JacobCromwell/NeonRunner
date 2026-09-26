class_name CyborgBody
extends Node3D
## The cyborgs' body (GDD §9.2): a procedural low-poly humanoid with an LED visor face, built from
## cached meshes (one draw call per body part) and animated procedurally. Visual only: it never
## touches collision or gameplay, and its randomness never uses the enemy's gameplay random stream.
##
## Zone variants (world.skin.enemy_variant): the sleek &"city" citizen, or the patched-together
## &"scavenger" with mismatched plates and a cracked, flickering visor. Hosts' visors glitch with
## purple static and corrupted expressions (GDD §9.7).
##
## A small API, so the orchestrator can move it onto the shared humanoid rig later (GDD §11):
##   build(variant, host, upper_body_only, visual_seed)
##   set_pose(pose), set_move_speed(m/s), aim_at(world point) / clear_aim()
##   set_expression(face), set_charge(0–1: the arm cannon's charge glow, the attack telegraph)
##   muzzle_position(), flash() (hit), die(cause) (death animation; emits `death_finished`)
## The local front is +Z (the cyborg faces the player at rotation 0).

signal death_finished

enum Pose { IDLE, WALK, AIM, RUN_AWAY, COWER }

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
const HIP_Y: float = 0.7
## The head is drawn a little large so the LED face reads from a distance.
const HEAD_SCALE: float = 1.15
const FLASH_TIME: float = 0.08
const RING_STEPS: int = 5

var variant: StringName = &"city"
var host: bool = false
var upper_body_only: bool = false
var pose: Pose = Pose.IDLE
var face: Kit.Face = Kit.Face.NEUTRAL
var charge: float = 0.0
var move_speed: float = 0.0
## Extra forward lean of the upper body (radians): the window cyborg leans out over the sill.
var lean: float = 0.0

var _root: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _shoulder_l: Node3D
var _shoulder_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _parts: Array[MeshInstance3D] = []
var _visor: MeshInstance3D
var _visor_mat: ShaderMaterial
var _ring: MeshInstance3D
var _orb: MeshInstance3D
var _muzzle: Node3D
var _aim: Vector3 = Vector3.ZERO
var _aiming: bool = false
var _t: float = 0.0
var _gait: float = 0.0
var _vis_rng := RandomNumberGenerator.new()
var _glitch_left: float = 0.0
var _flash_left: float = 0.0
var _dead: bool = false
var _hips_drop: float = 0.0


## Builds the body. `visual_seed` only varies visuals (glitch timing, idle sway).
func build(p_variant: StringName, p_host: bool = false, p_upper_body_only: bool = false,
		visual_seed: int = 0) -> void:
	variant = p_variant if p_variant == &"scavenger" else &"city"
	host = p_host
	upper_body_only = p_upper_body_only
	_vis_rng.seed = visual_seed
	_t = _vis_rng.randf() * 10.0
	var v: String = String(variant)
	_root = _joint(self, Vector3.ZERO)
	_hips = _joint(_root, Vector3(0.0, HIP_Y, 0.0))
	_part(_hips, v, "pelvis")
	_torso = _joint(_hips, Vector3(0.0, 0.06, 0.0))
	_part(_torso, v, "torso")
	_head = _joint(_torso, Vector3(0.0, 0.48, 0.0))
	_head.scale = Vector3.ONE * HEAD_SCALE
	_part(_head, v, "head")
	# The visor sits on the helmet's face plate.
	_visor = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.19, 0.104)
	_visor.mesh = quad
	_visor.position = Vector3(0.0, 0.11, 0.138)
	_visor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var scav: bool = variant == &"scavenger"
	_visor_mat = Kit.new_visor_material(Kit.LED_SCAVENGER if scav else Kit.LED_COLOR,
		1.0 if host else 0.0, 0.8 if scav else 0.0, 1.0 if scav else 0.0, float(visual_seed % 997))
	_visor.material_override = _visor_mat
	_head.add_child(_visor)
	# Arms: the left arm is at +X (the body faces +Z); the right forearm carries the arm cannon.
	_shoulder_l = _joint(_torso, Vector3(0.23, 0.4, 0.0))
	_part(_shoulder_l, v, "upper_arm_l")
	_elbow_l = _joint(_shoulder_l, Vector3(0.0, -0.28, 0.0))
	_part(_elbow_l, v, "forearm")
	_shoulder_r = _joint(_torso, Vector3(-0.23, 0.4, 0.0))
	_part(_shoulder_r, v, "upper_arm_r")
	_elbow_r = _joint(_shoulder_r, Vector3(0.0, -0.28, 0.0))
	_part(_elbow_r, v, "cannon")
	_muzzle = _joint(_elbow_r, Vector3(0.0, -0.43, 0.0))
	_ring = MeshInstance3D.new()
	_ring.mesh = Kit.mesh("cannon_ring", _build_ring)
	_ring.position = Vector3(0.0, -0.405, 0.0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_elbow_r.add_child(_ring)
	_orb = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.075
	sphere.height = 0.15
	sphere.radial_segments = 8
	sphere.rings = 4
	_orb.mesh = sphere
	_orb.material_override = Kit.glow_material(Kit.CHARGE_COLOR, 1.6)
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb.visible = false
	_muzzle.add_child(_orb)
	if not upper_body_only:
		_hip_l = _joint(_hips, Vector3(0.085, -0.05, 0.0))
		_part(_hip_l, v, "thigh_l")
		_knee_l = _joint(_hip_l, Vector3(0.0, -0.33, 0.0))
		_part(_knee_l, v, "shin_l")
		_hip_r = _joint(_hips, Vector3(-0.085, -0.05, 0.0))
		_part(_hip_r, v, "thigh_r")
		_knee_r = _joint(_hip_r, Vector3(0.0, -0.33, 0.0))
		_part(_knee_r, v, "shin_r")
	set_charge(0.0)
	set_expression(Kit.Face.NEUTRAL)


func set_pose(p: Pose) -> void:
	pose = p


## Walking or running speed, for the stride rate.
func set_move_speed(speed: float) -> void:
	move_speed = speed


## Points the arm cannon at a world point until clear_aim().
func aim_at(world_point: Vector3) -> void:
	_aim = world_point
	_aiming = true


func clear_aim() -> void:
	_aiming = false


func set_expression(f: Kit.Face) -> void:
	face = f
	if _visor_mat != null and _glitch_left <= 0.0:
		_visor_mat.set_shader_parameter(&"face", Kit.face_texture(f))


## The arm cannon's charge glow (0 = idle, 1 = about to fire): the visual half of the telegraph.
func set_charge(amount: float) -> void:
	charge = clampf(amount, 0.0, 1.0)
	if _ring == null:
		return
	var step: int = int(round(charge * (RING_STEPS - 1)))
	_ring.material_override = Kit.glow_material(Kit.CHARGE_COLOR, lerpf(0.35, 1.6, float(step) / (RING_STEPS - 1)))
	_orb.visible = charge > 0.02
	_orb.scale = Vector3.ONE * lerpf(0.3, 1.7, charge)


## World position of the arm cannon's tip (visual; gameplay shots use the enemy's own muzzle point).
func muzzle_position() -> Vector3:
	return _muzzle.global_position if _muzzle != null else global_position + Vector3(0.0, 1.1, 0.3)


## A short white flash when hit by a weapon.
func flash() -> void:
	if _dead:
		return
	_flash_left = FLASH_TIME
	_set_part_material(Kit.part_material(&"flash"))


## The death animation (visual only). `cause`: &"stomp" squashes, anything else knocks it over.
## The window cyborg's upper body slumps over the sill and stays.
func die(cause: StringName) -> void:
	if _dead:
		return
	_dead = true
	_flash_left = 0.0
	_glitch_left = 0.0
	set_charge(0.0)
	set_expression(Kit.Face.DEAD)
	_visor_mat.set_shader_parameter(&"glitch", 0.0)
	_set_part_material(Kit.part_material(&"dead"))
	var tween := create_tween()
	if upper_body_only:
		tween.tween_property(_torso, "rotation", Vector3(0.95, 0.0, 0.0), 0.3).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(_shoulder_r, "rotation", Vector3(-0.3, 0.0, -0.2), 0.3)
		tween.parallel().tween_property(_shoulder_l, "rotation", Vector3(-0.3, 0.0, 0.2), 0.3)
		tween.tween_callback(func() -> void: death_finished.emit())
		return
	if cause == &"stomp":
		tween.tween_property(_root, "scale", Vector3(1.35, 0.3, 1.35), 0.1).set_trans(Tween.TRANS_QUAD)
		tween.tween_interval(0.25)
	else:
		tween.tween_property(_root, "rotation", Vector3(-1.45, 0.0, 0.0), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_interval(0.12)
	tween.tween_property(_root, "scale", Vector3(0.05, 0.05, 0.05), 0.16)
	tween.tween_callback(func() -> void: death_finished.emit())


func _process(delta: float) -> void:
	if _root == null:
		return
	_t += delta
	_update_flash(delta)
	_update_visor(delta)
	if charge > 0.95:
		# Fully charged: the orb shimmers, the last beat before the burst.
		_orb.scale = Vector3.ONE * (1.7 + 0.25 * sin(_t * 60.0))
	if _dead:
		return
	var k: float = 1.0 - exp(-14.0 * delta)
	_animate(delta, k)


func _update_flash(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left <= 0.0 and not _dead:
		_set_part_material(Kit.part_material(&"normal"))


## Hosts cycle through corrupted faces now and then (GDD §9.7).
func _update_visor(delta: float) -> void:
	if not host or _dead:
		return
	if _glitch_left > 0.0:
		_glitch_left -= delta
		if _glitch_left <= 0.0:
			_visor_mat.set_shader_parameter(&"face", Kit.face_texture(face))
		return
	if _vis_rng.randf() < delta * 1.6:
		_glitch_left = _vis_rng.randf_range(0.12, 0.45)
		var corrupt: Kit.Face = Kit.Face.CORRUPT_GRIN if _vis_rng.randf() < 0.5 else Kit.Face.CORRUPT_BROKEN
		_visor_mat.set_shader_parameter(&"face", Kit.face_texture(corrupt))


## Procedural poses, blended toward their targets (factor `k`).
func _animate(delta: float, k: float) -> void:
	var breathe: float = sin(_t * 2.1) * 0.025
	var torso := Vector3(breathe + lean, 0.0, 0.0)
	var head := Vector3(-breathe, 0.0, 0.0)
	var sh_l := Vector3(-0.05, 0.0, 0.14)
	var sh_r := Vector3(-0.05, 0.0, -0.14)
	var el_l := Vector3(-0.25, 0.0, 0.0)
	var el_r := Vector3(-0.2, 0.0, 0.0)
	var hip_l := Vector3.ZERO
	var hip_r := Vector3.ZERO
	var kn_l := Vector3.ZERO
	var kn_r := Vector3.ZERO
	var drop: float = 0.0
	if variant == &"scavenger":
		torso.x += 0.14  # hunched
		head.x -= 0.1
	match pose:
		Pose.WALK:
			_gait += delta * (2.0 + move_speed * 3.4)
			var s: float = sin(_gait)
			hip_l.x = -s * 0.45
			hip_r.x = s * 0.45
			kn_l.x = maxf(0.0, s) * 0.8
			kn_r.x = maxf(0.0, -s) * 0.8
			sh_l.x = s * 0.35
			sh_r.x = -s * 0.35
			drop = -absf(cos(_gait)) * 0.025
		Pose.AIM:
			hip_l = Vector3(-0.15, 0.0, 0.12)
			hip_r = Vector3(0.25, 0.0, -0.1)
			kn_l.x = 0.25
			kn_r.x = 0.2
			drop = 0.04
			sh_l = Vector3(-0.9, 0.0, 0.25)
			el_l = Vector3(-1.2, 0.0, 0.0)
		Pose.RUN_AWAY:
			_gait += delta * (6.0 + move_speed * 1.4)
			var s: float = sin(_gait)
			torso.x += 0.35
			hip_l.x = -s * 0.9
			hip_r.x = s * 0.9
			kn_l.x = maxf(0.0, s) * 1.4 + 0.2
			kn_r.x = maxf(0.0, -s) * 1.4 + 0.2
			drop = -absf(cos(_gait)) * 0.05
			# Panic: the free arm flails overhead; the head twists back to watch the player.
			sh_l = Vector3(-2.5 + sin(_t * 17.0) * 0.45, 0.0, 0.35 + sin(_t * 11.0) * 0.2)
			el_l = Vector3(-0.5 + sin(_t * 13.0) * 0.4, 0.0, 0.0)
			sh_r = Vector3(1.9, 0.0, -0.25)
			el_r = Vector3.ZERO
			head = Vector3(-0.35, PI * 0.82 + sin(_t * 9.0) * 0.12, 0.0)
		Pose.COWER:
			drop = 0.2
			hip_l = Vector3(-0.95, 0.0, 0.15)
			hip_r = Vector3(-0.95, 0.0, -0.15)
			kn_l.x = 1.55
			kn_r.x = 1.55
			torso.x += 0.3
			sh_l = Vector3(-2.3, 0.0, -0.35)
			el_l = Vector3(-1.7, 0.0, 0.0)
			head.x -= 0.25
			head.y = sin(_t * 23.0) * 0.08  # trembling
	if _aiming:
		if pose != Pose.RUN_AWAY:
			torso.y = _aim_yaw()
		_aim_pose(k)
	else:
		_blend(_shoulder_r, sh_r, k)
		_blend(_elbow_r, el_r, k)
	_blend(_torso, torso, k)
	_blend(_head, head, k)
	_blend(_shoulder_l, sh_l, k)
	_blend(_elbow_l, el_l, k)
	if not upper_body_only:
		_blend(_hip_l, hip_l, k)
		_blend(_hip_r, hip_r, k)
		_blend(_knee_l, kn_l, k)
		_blend(_knee_r, kn_r, k)
		_hips_drop = lerpf(_hips_drop, drop, k)
		_hips.position.y = HIP_Y - _hips_drop


## Turns the torso toward the aim point (limited) and points the cannon arm straight at it.
func _aim_pose(k: float) -> void:
	var dir_world: Vector3 = _aim - _shoulder_r.global_position
	if dir_world.length_squared() < 0.0001:
		return
	var dir_local: Vector3 = (_torso.global_basis.inverse() * dir_world).normalized()
	var q := Quaternion(Vector3.DOWN, dir_local)
	_shoulder_r.quaternion = _shoulder_r.quaternion.slerp(q, k)
	_elbow_r.quaternion = _elbow_r.quaternion.slerp(Quaternion.IDENTITY, k)


func _aim_yaw() -> float:
	var local: Vector3 = _hips.global_transform.affine_inverse() * _aim
	return clampf(atan2(local.x, local.z), -1.0, 1.0)


func _blend(joint: Node3D, euler: Vector3, k: float) -> void:
	joint.quaternion = joint.quaternion.slerp(Quaternion.from_euler(euler), k)


func _joint(parent: Node3D, offset: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = offset
	parent.add_child(n)
	return n


func _part(joint: Node3D, v: String, part_name: String) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = Kit.mesh(v + "/" + part_name, _build_part.bind(v, part_name))
	inst.material_override = Kit.part_material(&"normal")
	joint.add_child(inst)
	_parts.append(inst)


func _set_part_material(m: Material) -> void:
	for p: MeshInstance3D in _parts:
		p.material_override = m


static func _build_ring() -> ArrayMesh:
	var b := Kit.Builder.new()
	b.prism(Vector3.ZERO, 0.068, 0.03, 8, Color.WHITE)
	return b.commit()


# --- Part meshes (built once per variant) -----------------------------------------------------

static func _build_part(v: String, part_name: String) -> ArrayMesh:
	var b := Kit.Builder.new()
	if v == "scavenger":
		_scavenger_part(b, part_name)
	else:
		_city_part(b, part_name)
	return b.commit()


## The sleek city citizen: glossy graphite armour, pale panels and amber trim lines.
static func _city_part(b: Kit.Builder, part_name: String) -> void:
	var armor := Color(0.4, 0.45, 0.56)
	var panel := Color(0.86, 0.88, 0.93)
	var joint := Color(0.09, 0.09, 0.11)
	var trim := Kit.LED_COLOR
	match part_name:
		"pelvis":
			b.box(Vector3(0.0, 0.0, 0.0), Vector3(0.3, 0.15, 0.19), armor, 0.0, Vector2(1.08, 1.0))
			b.box(Vector3(0.0, 0.055, 0.097), Vector3(0.26, 0.022, 0.006), trim, 1.0)
		"torso":
			b.box(Vector3(0.0, 0.1, 0.0), Vector3(0.22, 0.2, 0.15), joint, 0.0, Vector2(1.2, 1.1))
			b.box(Vector3(0.0, 0.31, 0.0), Vector3(0.3, 0.26, 0.21), armor, 0.0, Vector2(1.35, 1.0))
			b.box(Vector3(0.0, 0.33, 0.105), Vector3(0.24, 0.17, 0.02), panel, 0.0, Vector2(1.25, 1.0))
			b.box(Vector3(0.0, 0.225, 0.113), Vector3(0.28, 0.016, 0.01), trim, 1.0)
			b.box(Vector3(0.0, 0.3, -0.11), Vector3(0.18, 0.2, 0.03), armor)  # back plate
			b.box(Vector3(0.0, 0.47, 0.0), Vector3(0.08, 0.06, 0.08), joint)
		"head":
			b.box(Vector3(0.0, 0.12, 0.0), Vector3(0.24, 0.24, 0.26), armor, 0.0, Vector2(0.82, 0.86))
			b.box(Vector3(0.0, 0.11, 0.124), Vector3(0.215, 0.135, 0.02), joint)
			b.box(Vector3(0.0, 0.245, -0.01), Vector3(0.035, 0.035, 0.2), trim, 0.9)
			for s: float in [-1.0, 1.0]:
				b.box(Vector3(s * 0.123, 0.11, 0.0), Vector3(0.02, 0.09, 0.11), panel)
		"upper_arm_l", "upper_arm_r":
			var s: float = 1.0 if part_name == "upper_arm_l" else -1.0
			b.box(Vector3(s * 0.02, -0.02, 0.0), Vector3(0.15, 0.1, 0.17), panel, 0.0, Vector2(0.7, 0.8))
			b.box(Vector3(0.0, -0.14, 0.0), Vector3(0.09, 0.22, 0.09), armor, 0.0, Vector2(1.1, 1.1))
			b.box(Vector3(s * 0.078, -0.02, 0.0), Vector3(0.006, 0.05, 0.12), trim, 1.0)
			b.box(Vector3(0.0, -0.27, 0.0), Vector3(0.07, 0.05, 0.07), joint)
		"forearm":
			b.box(Vector3(0.0, -0.12, 0.0), Vector3(0.075, 0.22, 0.075), armor, 0.0, Vector2(1.2, 1.2))
			b.box(Vector3(0.0, -0.265, 0.0), Vector3(0.07, 0.07, 0.06), joint)
		"cannon":
			b.box(Vector3(0.0, -0.1, 0.0), Vector3(0.085, 0.18, 0.085), armor, 0.0, Vector2(1.2, 1.2))
			b.prism(Vector3(0.0, -0.25, 0.0), 0.062, 0.3, 8, panel, 0.0, 0.85)
			b.prism(Vector3(0.0, -0.375, 0.0), 0.05, 0.06, 8, joint)
			b.box(Vector3(0.058, -0.25, 0.0), Vector3(0.006, 0.2, 0.025), trim, 1.0)
			b.box(Vector3(-0.058, -0.25, 0.0), Vector3(0.006, 0.2, 0.025), trim, 1.0)
		"thigh_l", "thigh_r":
			b.box(Vector3(0.0, -0.16, 0.0), Vector3(0.125, 0.3, 0.135), armor, 0.0, Vector2(1.25, 1.2))
			b.box(Vector3(0.0, -0.325, 0.012), Vector3(0.09, 0.06, 0.1), panel)
		"shin_l", "shin_r":
			b.box(Vector3(0.0, -0.15, 0.0), Vector3(0.09, 0.28, 0.1), armor, 0.0, Vector2(1.2, 1.15))
			b.box(Vector3(0.0, -0.13, 0.055), Vector3(0.07, 0.19, 0.02), panel, 0.0, Vector2(1.15, 1.0))
			b.box(Vector3(0.0, -0.06, 0.068), Vector3(0.05, 0.014, 0.006), trim, 1.0)
			b.box(Vector3(0.0, -0.31, 0.03), Vector3(0.1, 0.06, 0.2), joint, 0.0, Vector2(0.9, 0.85))


## The patched-together scavenger: mismatched rusty and olive plates, exposed frame, bolts, a
## bulky welded cannon and dimmer, broken trim.
static func _scavenger_part(b: Kit.Builder, part_name: String) -> void:
	var rust := Color(0.66, 0.36, 0.17)
	var olive := Color(0.5, 0.53, 0.31)
	var steel := Color(0.55, 0.57, 0.6)
	var frame := Color(0.12, 0.11, 0.1)
	var bolt := Color(0.82, 0.78, 0.7)
	var trim := Kit.LED_SCAVENGER
	match part_name:
		"pelvis":
			b.box(Vector3(0.0, 0.0, 0.0), Vector3(0.3, 0.14, 0.19), frame)
			b.box(Vector3(0.07, -0.01, 0.1), Vector3(0.12, 0.12, 0.03), olive, 0.0, Vector2.ONE, Basis(Vector3.BACK, 0.2))
			b.box(Vector3(-0.1, -0.05, 0.06), Vector3(0.09, 0.1, 0.1), rust)  # pouch
		"torso":
			b.box(Vector3(0.0, 0.1, 0.0), Vector3(0.2, 0.2, 0.14), frame, 0.0, Vector2(1.3, 1.1))
			b.box(Vector3(0.055, 0.31, 0.0), Vector3(0.2, 0.27, 0.22), rust, 0.0, Vector2(1.15, 1.0))
			b.box(Vector3(-0.1, 0.3, 0.0), Vector3(0.17, 0.24, 0.2), steel, 0.0, Vector2(1.15, 1.0), Basis(Vector3.BACK, -0.08))
			b.box(Vector3(0.02, 0.35, 0.112), Vector3(0.14, 0.1, 0.02), olive, 0.0, Vector2.ONE, Basis(Vector3.BACK, 0.25))
			for p: Vector3 in [Vector3(-0.04, 0.39, 0.124), Vector3(0.08, 0.31, 0.124), Vector3(-0.04, 0.31, 0.124), Vector3(0.08, 0.39, 0.124)]:
				b.box(p, Vector3(0.018, 0.018, 0.012), bolt)
			b.box(Vector3(-0.02, 0.215, 0.11), Vector3(0.12, 0.014, 0.01), trim, 0.7)
			# A vent stack on the back.
			b.prism(Vector3(0.08, 0.38, -0.13), 0.035, 0.24, 6, frame)
			b.box(Vector3(0.08, 0.5, -0.13), Vector3(0.05, 0.02, 0.05), trim, 0.5)
			b.box(Vector3(0.0, 0.47, 0.0), Vector3(0.09, 0.06, 0.09), frame)
		"head":
			b.box(Vector3(0.0, 0.12, 0.0), Vector3(0.25, 0.23, 0.25), steel, 0.0, Vector2(0.95, 0.9))
			b.box(Vector3(0.0, 0.11, 0.123), Vector3(0.215, 0.135, 0.02), frame)
			b.box(Vector3(0.0, 0.2, 0.0), Vector3(0.27, 0.035, 0.27), rust)  # riveted strap
			b.box(Vector3(0.1, 0.3, -0.05), Vector3(0.012, 0.18, 0.012), frame)  # antenna
			b.box(Vector3(0.1, 0.39, -0.05), Vector3(0.025, 0.025, 0.025), trim, 0.8)
			b.box(Vector3(-0.13, 0.12, 0.0), Vector3(0.03, 0.1, 0.12), olive)
		"upper_arm_l":
			b.box(Vector3(0.0, -0.13, 0.0), Vector3(0.08, 0.24, 0.08), olive)
			b.box(Vector3(0.0, -0.27, 0.0), Vector3(0.07, 0.05, 0.07), frame)
		"upper_arm_r":
			b.box(Vector3(-0.03, -0.03, 0.0), Vector3(0.18, 0.12, 0.19), rust, 0.0, Vector2(0.75, 0.85))
			b.box(Vector3(-0.1, 0.02, 0.07), Vector3(0.02, 0.02, 0.02), bolt)
			b.box(Vector3(0.0, -0.15, 0.0), Vector3(0.1, 0.22, 0.1), steel)
			b.box(Vector3(0.0, -0.27, 0.0), Vector3(0.08, 0.05, 0.08), frame)
		"forearm":
			b.box(Vector3(0.0, -0.12, 0.0), Vector3(0.075, 0.22, 0.075), steel)
			b.box(Vector3(0.0, -0.1, 0.0), Vector3(0.085, 0.05, 0.085), rust)  # wrapped patch
			b.box(Vector3(0.0, -0.265, 0.0), Vector3(0.07, 0.07, 0.06), frame)
		"cannon":
			b.box(Vector3(0.0, -0.09, 0.0), Vector3(0.1, 0.18, 0.1), frame)
			b.prism(Vector3(0.0, -0.25, 0.0), 0.075, 0.32, 6, steel)
			b.prism(Vector3(0.05, -0.2, 0.05), 0.03, 0.26, 5, rust)  # strapped canister
			b.box(Vector3(0.0, -0.2, 0.0), Vector3(0.17, 0.03, 0.17), rust)  # clamp
			b.prism(Vector3(0.0, -0.39, 0.0), 0.055, 0.05, 6, frame)
			b.box(Vector3(-0.07, -0.3, 0.0), Vector3(0.008, 0.12, 0.02), trim, 0.6)
		"thigh_l":
			b.box(Vector3(0.0, -0.16, 0.0), Vector3(0.125, 0.3, 0.13), steel, 0.0, Vector2(1.2, 1.15))
			b.box(Vector3(0.0, -0.325, 0.015), Vector3(0.09, 0.06, 0.1), frame)
		"thigh_r":
			b.box(Vector3(0.0, -0.16, 0.0), Vector3(0.13, 0.3, 0.14), rust, 0.0, Vector2(1.2, 1.1))
			b.box(Vector3(0.0, -0.325, 0.02), Vector3(0.11, 0.08, 0.11), olive)  # knee brace
		"shin_l", "shin_r":
			var c: Color = olive if part_name == "shin_l" else steel
			b.box(Vector3(0.0, -0.15, 0.0), Vector3(0.09, 0.28, 0.1), c, 0.0, Vector2(1.2, 1.15))
			b.box(Vector3(0.0, -0.12, 0.056), Vector3(0.06, 0.12, 0.02), frame)
			b.box(Vector3(0.0, -0.31, 0.03), Vector3(0.11, 0.06, 0.21), frame, 0.0, Vector2(0.9, 0.85))
