class_name HumanoidPose
extends RefCounted
## One pose of a HumanoidRig: a rotation per joint plus a few whole-body channels. Poses blend by
## weighted sums (accumulate + finish), so the rig can mix several activities smoothly.
##
## Joint rotations are Euler angles (YXZ, like Node3D.rotation) relative to the rest pose, in
## radians. Limb values use one convention for both sides: +x swings the limb forward, +z moves it
## out to the side, +y turns it inward. set_limb() mirrors y and z for the left side.
## Centre joints use plain values: +x tilts back, +y turns left, +z tilts left.

enum { PELVIS, CHEST, NECK, HEAD, UPPER_ARM_L, FOREARM_L, HAND_L, UPPER_ARM_R, FOREARM_R, HAND_R,
	THIGH_L, SHIN_L, FOOT_L, THIGH_R, SHIN_R, FOOT_R }

const JOINT_COUNT: int = 16
## Left joint index = right joint index - SIDE_STRIDE.
const SIDE_STRIDE: int = 3
const DEG: float = PI / 180.0

var rot := PackedVector3Array()
## Added to the pelvis joint's rest position.
var pelvis_offset := Vector3.ZERO
## Whole body, about the ground point under the pelvis: position, rotation (radians) and scale.
var root_offset := Vector3.ZERO
var root_rot := Vector3.ZERO
var root_scale := Vector3.ONE
## Height added after the body is put on the ground (flight phase of a stride).
var lift: float = 0.0
## 1 = shift the body so its lowest point touches y = 0; 0 = leave it where the joints put it.
var ground: float = 1.0


func _init() -> void:
	rot.resize(JOINT_COUNT)


func reset() -> void:
	rot.fill(Vector3.ZERO)
	pelvis_offset = Vector3.ZERO
	root_offset = Vector3.ZERO
	root_rot = Vector3.ZERO
	root_scale = Vector3.ONE
	lift = 0.0
	ground = 1.0


static func is_left(joint: int) -> bool:
	return (joint >= UPPER_ARM_L and joint <= HAND_L) or (joint >= THIGH_L and joint <= FOOT_L)


static func is_limb(joint: int) -> bool:
	return joint >= UPPER_ARM_L


## The joint of a limb on one side: `right_joint` is the right-side index, `side` -1 (left) or 1.
static func limb(right_joint: int, side: int) -> int:
	return right_joint if side > 0 else right_joint - SIDE_STRIDE


## Sets a centre joint, or a limb joint by its own index, from degrees (limb convention for limbs).
func set_deg(joint: int, degrees: Vector3) -> void:
	rot[joint] = _to_local(joint, degrees)


func add_deg(joint: int, degrees: Vector3) -> void:
	rot[joint] += _to_local(joint, degrees)


## Sets a limb joint on one side from degrees in the limb convention.
func set_limb(right_joint: int, side: int, degrees: Vector3) -> void:
	set_deg(limb(right_joint, side), degrees)


func add_limb(right_joint: int, side: int, degrees: Vector3) -> void:
	add_deg(limb(right_joint, side), degrees)


## Adds a pose table ({joint: Vector3 degrees, "pelvis_offset" / "root_rot" (degrees) / "lift": ...})
## scaled by `weight`. `mirrored` swaps left and right (and flips the centre joints' turn and tilt).
func add_table(table: Dictionary, weight: float, mirrored: bool = false) -> void:
	for key: Variant in table:
		if key is int:
			var joint: int = key
			var degrees: Vector3 = table[key]
			if mirrored:
				if is_limb(joint):
					joint = joint + SIDE_STRIDE if is_left(joint) else joint - SIDE_STRIDE
				else:
					degrees = Vector3(degrees.x, -degrees.y, -degrees.z)
			rot[joint] += _to_local(joint, degrees) * weight
		elif key == "pelvis_offset":
			var off: Vector3 = table[key]
			pelvis_offset += Vector3(-off.x if mirrored else off.x, off.y, off.z) * weight
		elif key == "root_rot":
			var r: Vector3 = table[key]
			root_rot += Vector3(r.x, -r.y if mirrored else r.y, -r.z if mirrored else r.z) * DEG * weight
		elif key == "lift":
			lift += float(table[key]) * weight


## Weighted accumulation for blending: call clear_sum(), accumulate() each pose, then finish().
func clear_sum() -> void:
	rot.fill(Vector3.ZERO)
	pelvis_offset = Vector3.ZERO
	root_offset = Vector3.ZERO
	root_rot = Vector3.ZERO
	root_scale = Vector3.ZERO
	lift = 0.0
	ground = 0.0


func accumulate(other: HumanoidPose, weight: float) -> void:
	for i: int in JOINT_COUNT:
		rot[i] += other.rot[i] * weight
	pelvis_offset += other.pelvis_offset * weight
	root_offset += other.root_offset * weight
	root_rot += other.root_rot * weight
	root_scale += other.root_scale * weight
	lift += other.lift * weight
	ground += other.ground * weight


func finish(total_weight: float) -> void:
	if total_weight <= 0.0:
		reset()
		return
	var k: float = 1.0 / total_weight
	for i: int in JOINT_COUNT:
		rot[i] *= k
	pelvis_offset *= k
	root_offset *= k
	root_rot *= k
	root_scale *= k
	lift *= k
	ground *= k


func copy_from(other: HumanoidPose) -> void:
	rot = other.rot.duplicate()
	pelvis_offset = other.pelvis_offset
	root_offset = other.root_offset
	root_rot = other.root_rot
	root_scale = other.root_scale
	lift = other.lift
	ground = other.ground


func is_finite() -> bool:
	for r: Vector3 in rot:
		if not r.is_finite():
			return false
	return pelvis_offset.is_finite() and root_offset.is_finite() and root_rot.is_finite() \
		and root_scale.is_finite() and is_finite_f(lift) and is_finite_f(ground)


static func is_finite_f(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _to_local(joint: int, degrees: Vector3) -> Vector3:
	if is_left(joint):
		return Vector3(degrees.x, -degrees.y, -degrees.z) * DEG
	return degrees * DEG
