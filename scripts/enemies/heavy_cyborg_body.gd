class_name HeavyCyborgBody
extends CyborgBody
## The Heavy Cyborg's body (GDD §9.16: "a bigger, bulkier, beefier cyborg, with much bigger arms, body and legs,
## carrying a big gatling gun"). Its zone's cyborg (CyborgBody: the same rig and poses, the CRT screen head and its
## cold white LED face, the look's clothes and colours, one material for the whole body) in a heavy build:
## - bulked out: each segment's mesh is drawn wider and deeper (BULK; never longer, so the skeleton, every pose and
##   the walk keep their reach), on shoulders and hips set wider (SHOULDER_SPREAD, HIP_SPREAD);
## - armoured: its look's armour set over its clothes (CyborgSuit.heavy_set, cyborg_looks/heavy.gd), merged into the
##   same segment meshes;
## - drawn bigger as a whole (HeavyCyborg sets its scale: the zone's cyborg_draw_scale times
##   HeavyCyborgTuning.model_scale);
## - carrying a big gatling at the hip (GDD §9.16, proposed): six barrels on a receiver with a drum of ammunition
##   on its left, a carry handle on top that the left hand holds, and a coupling at the back of its right side that
##   the cyber arm's cannon plugs into (the arms reach the grips, two-bone, _reach). It hangs from the chest, so it
##   moves with the walk; the chest turns toward the runner as it aims and the gatling points at them.
## Its only glows are the face and the gatling's red charge-up, as on every cyborg (GDD §9.2, the arm cannon's): the
## barrels spin up and turn red-hot through the wind-up (set_charge) and a red ring grows at the muzzle; a red aim
## line runs from the muzzle to the runner, flickering faster as the wind-up ends (show_aim_line; with Reduced
## flashing it thickens steadily instead), then stays on the locked line while it fires; a flash at the muzzle with
## each round (none with Reduced flashing: the ring stays lit through the stream). The cannon's own emitter ring
## sits inside the armour's coupling and its orb never grows: the material's charge stays 0.
## Visual only, like CyborgBody: nothing here touches collision or gameplay.

const MeshBatch := preload("res://scripts/enemies/mesh_batch.gd")
## DESIGN-TBD (docs/questions/s1.md): how much bigger each segment is drawn across (x) and in depth (z); lengths stay.
const BULK: Dictionary = {
	HumanoidPose.PELVIS: Vector3(1.35, 1.0, 1.3),
	HumanoidPose.CHEST: Vector3(1.42, 1.0, 1.36),
	HumanoidPose.HEAD: Vector3(1.04, 1.04, 1.04),
	HumanoidPose.UPPER_ARM_L: Vector3(1.6, 1.0, 1.55), HumanoidPose.UPPER_ARM_R: Vector3(1.6, 1.0, 1.55),
	HumanoidPose.FOREARM_L: Vector3(1.5, 1.0, 1.5), HumanoidPose.FOREARM_R: Vector3(1.5, 1.0, 1.5),
	HumanoidPose.THIGH_L: Vector3(1.48, 1.0, 1.42), HumanoidPose.THIGH_R: Vector3(1.48, 1.0, 1.42),
	HumanoidPose.SHIN_L: Vector3(1.4, 1.0, 1.32), HumanoidPose.SHIN_R: Vector3(1.4, 1.0, 1.32),
}
## The shoulders' and hips' joints set this much wider (their x).
const SHOULDER_SPREAD: float = 1.3
const HIP_SPREAD: float = 1.3
## Where the gatling hangs, in the chest joint's space (rig: +x its right, -z forward): its back end, at the waist,
## in front of the breastplate, a little right of the middle.
const GUN_AT := Vector3(0.05, -0.03, -0.19)
## The gatling's points, in its own space (its back end at the origin, its barrels toward -z, +y up, +x its right):
## the muzzle, the carry handle (the left hand's grip) and the coupling the cyber arm's cannon plugs into.
const MUZZLE := Vector3(0.0, 0.0, -1.0)
const HANDLE := Vector3(-0.01, 0.17, -0.17)
const COUPLING := Vector3(0.12, -0.02, -0.07)
## How far along each forearm (segment space, its -y) the point that holds the gatling is: the cannon's end at the
## coupling on the right (the cyber arm's cannon reaches to -0.43), the palm on the left.
const RIGHT_REACH: float = 0.4
const LEFT_REACH: float = 0.3
## The chest turns toward the runner by at most this much (radians), and the gatling points at most this far from
## where the chest faces.
const MAX_TURN: float = 0.7
const MAX_POINT: float = 0.6
## How fast the aim comes in and goes (per second, an exponential blend).
const AIM_BLEND: float = 8.0
## The barrels' spin (radians per second): idle, and at the end of the wind-up and while firing.
const SPIN_IDLE: float = 0.0
const SPIN_FULL: float = 42.0
## The barrels turn red-hot from this far into the wind-up (as a drone's do).
const HOT_FROM: float = 0.45
## The red of the charge-up and the aim line (the drone's aim line's), and the muzzle flash's.
const HOT_COLOR := Color(1.0, 0.16, 0.08)
const LINE_COLOR := Color(1.0, 0.12, 0.08)
const FLASH_COLOR := Color(1.0, 0.8, 0.45)
const LINE_WIDTH: float = 0.06
const MUZZLE_FLASH_TIME: float = 0.05

## The gatling's meshes, built once: {receiver, barrels, ring} ArrayMeshes.
static var _gatling: Dictionary = {}

## Firing (the stream is under way): the barrels spin flat out and stay hot; HeavyCyborg sets it each tick.
var firing: bool = false

var _gun: Node3D
var _barrels: MeshInstance3D
var _ring: MeshInstance3D
var _flash: MeshInstance3D
var _muzzle: Node3D
var _handle: Node3D
var _coupling: Node3D
var _aim_line: MeshInstance3D
var _gun_aim := Vector3.ZERO
var _gun_aiming: bool = false
var _gun_w: float = 0.0
var _spin: float = 0.0
var _muzzle_flash_left: float = 0.0
var _line_target := Vector3.ZERO
var _line_progress: float = 0.0
var _line_time: float = 0.0
var _dying: bool = false


func build(p_variant: StringName, _p_host: bool = false, _p_upper_body_only: bool = false, visual_seed: int = 0) -> void:
	# Never a host and never in a window (GDD §9.16): a whole body, its look's armour over it.
	super.build(p_variant, false, false, visual_seed)
	var sets: Array[StringName] = CyborgSuit.attachment_sets(look, false)
	sets.append(CyborgSuit.heavy_set(look))
	rig.set_attachments(sets)
	var parts: Array[MeshInstance3D] = rig.part_instances()
	for joint: int in BULK:
		parts[joint].scale = BULK[joint]
	for joint_name: StringName in [&"upper_arm_l", &"upper_arm_r"]:
		rig.joint(joint_name).position.x *= SHOULDER_SPREAD
	for joint_name: StringName in [&"thigh_l", &"thigh_r"]:
		rig.joint(joint_name).position.x *= HIP_SPREAD
	_build_gatling()
	_animate_heavy(0.0)


## A Heavy Cyborg's charge-up is its gatling's (the barrels' spin and heat, the muzzle's ring): the arm cannon's orb
## never grows (the material's charge stays 0).
func set_charge(amount: float) -> void:
	charge = clampf(amount, 0.0, 1.0)


## The gatling points at `world_point` (the gun's aim, while it winds up and fires) until clear_aim().
func aim_at(world_point: Vector3) -> void:
	_gun_aim = world_point
	_gun_aiming = true


func clear_aim() -> void:
	_gun_aiming = false
	hide_aim_line()


## The red aim line from the gatling's muzzle to `target` (world), `progress` (0–1) into the wind-up: it flickers
## faster as the wind-up ends (thickens steadily with Reduced flashing); 1 while firing, steady. The gatling points
## where the line ends.
func show_aim_line(target: Vector3, progress: float) -> void:
	if _dying:
		return
	_line_target = target
	_line_progress = clampf(progress, 0.0, 1.0)
	if not _aim_line.visible:
		_line_time = 0.0
	_aim_line.visible = true
	_gun_aim = target
	_gun_aiming = true


func hide_aim_line() -> void:
	if _aim_line != null:
		_aim_line.visible = false


## A round leaves the muzzle: a short flash (none with Reduced flashing, where the ring stays lit while it fires).
func flash_muzzle() -> void:
	if _dying or Settings.flashing_reduced:
		return
	_muzzle_flash_left = MUZZLE_FLASH_TIME


## World position of the gatling's muzzle (visual; the rounds start at the enemy's own muzzle point).
func muzzle_position() -> Vector3:
	return _muzzle.global_position


## Whether the aim line is showing (tests).
func aim_line_shown() -> bool:
	return _aim_line != null and _aim_line.visible


## The aim line's far end (world), for tests: where it's drawn to.
func aim_line_target() -> Vector3:
	return _line_target


## Whether the barrels glow red-hot (the visual half of the wind-up), for tests.
func barrels_hot() -> bool:
	return _barrels != null and _barrels.material_override != null


func draw_call_count() -> int:
	var n: int = super.draw_call_count()
	for mesh: MeshInstance3D in [_gun.get_child(0) as MeshInstance3D, _barrels, _ring, _flash, _aim_line]:
		if mesh != null and mesh.is_visible_in_tree() and mesh.mesh != null:
			n += mesh.mesh.get_surface_count()
	return n


func die(cause: StringName) -> void:
	if _dying:
		return
	_dying = true
	firing = false
	hide_aim_line()
	_ring.visible = false
	_flash.visible = false
	_barrels.material_override = null
	super.die(cause)


## Everything shown at once (the wind-up's heat and ring, a flash, the aim line), for EnemyDirector.warm_up's look.
func show_everything() -> void:
	firing = true
	charge = 1.0
	_muzzle_flash_left = MUZZLE_FLASH_TIME
	show_aim_line(Vector3(0.0, 1.0, 12.0), 1.0)
	_animate_heavy(0.0)
	_flash.visible = true


func advance(delta: float) -> void:
	super.advance(delta)
	if rig != null and not _dying:
		_animate_heavy(delta)


## After the rig is posed: the chest turns toward the aim, the gatling points there (or ahead), the arms reach its
## grips, and the barrels, the ring, the flash and the aim line follow the charge. Outside the tree (a warm-up's
## look) only the gatling's own parts change: nothing there has a place in the world.
func _animate_heavy(delta: float) -> void:
	var k: float = 1.0 - exp(-AIM_BLEND * delta) if delta > 0.0 else 1.0
	_gun_w = lerpf(_gun_w, 1.0 if _gun_aiming else 0.0, k)
	if is_inside_tree():
		_hold_gatling()
	_update_gatling(delta)


## The chest turns toward the aim (blended in by _gun_w), the gatling points at it (or ahead and a little down), and
## the arms reach its grips.
func _hold_gatling() -> void:
	var chest: Node3D = rig.joint(&"chest")
	var forward: Vector3 = global_basis.z.normalized()
	var flat: Vector3 = Vector3(_gun_aim.x - chest.global_position.x, 0.0, _gun_aim.z - chest.global_position.z)
	if _gun_w > 0.001 and flat.length_squared() > 0.01:
		var yaw: float = clampf(forward.signed_angle_to(flat.normalized(), Vector3.UP), -MAX_TURN, MAX_TURN)
		chest.global_rotate(Vector3.UP, yaw * _gun_w)
	# Where the chest faces now (the rig faces its -z), and the gatling: ahead and a little down, or at the aim.
	var facing: Vector3 = -chest.global_basis.z.normalized()
	facing = Vector3(facing.x, 0.0, facing.z).normalized() if absf(facing.y) < 0.99 else forward
	var rest: Vector3 = (facing - Vector3.UP * 0.12).normalized()
	var want: Vector3 = rest
	var to_aim: Vector3 = _gun_aim - _gun.global_position
	if _gun_w > 0.001 and to_aim.length_squared() > 0.25:
		var at: Vector3 = to_aim.normalized()
		var off: float = facing.angle_to(at)
		if off > MAX_POINT:
			at = facing.slerp(at, MAX_POINT / off)
		want = rest.slerp(at, _gun_w).normalized()
	_gun.look_at(_gun.global_position + want, Vector3.UP if absf(want.y) < 0.99 else Vector3.FORWARD)
	# The arms hold it: the cannon plugged into the coupling, the left hand on the carry handle; elbows out and back.
	var right: Vector3 = chest.global_basis.x.normalized()
	var back: Vector3 = chest.global_basis.z.normalized()
	_reach(rig.joint(&"upper_arm_r"), rig.joint(&"forearm_r"), RIGHT_REACH, _coupling.global_position,
		right + back * 0.5 - Vector3.UP * 0.3)
	_reach(rig.joint(&"upper_arm_l"), rig.joint(&"forearm_l"), LEFT_REACH, _handle.global_position,
		-right + back * 0.4 - Vector3.UP * 0.2)


## Points the arm's joints (bones along their -y) so the point `reach` along the forearm (segment space) comes to
## `target` (world), the elbow bending toward `pole` (a world direction): two-bone, by the law of cosines, each
## joint turned the shortest way from its pose so its twist stays. Out of reach, the arm points straight at it.
func _reach(upper: Node3D, fore: Node3D, reach: float, target: Vector3, pole: Vector3) -> void:
	var shoulder: Vector3 = upper.global_position
	var u: float = fore.global_position.distance_to(shoulder)
	var f: float = (fore.global_basis * Vector3(0.0, -reach, 0.0)).length()
	var to: Vector3 = target - shoulder
	if u < 0.001 or f < 0.001 or to.length_squared() < 0.000001:
		return
	var d: float = clampf(to.length(), absf(u - f) + 0.001, u + f - 0.001)
	var dir: Vector3 = to.normalized()
	var cos_a: float = clampf((u * u + d * d - f * f) / (2.0 * u * d), -1.0, 1.0)
	var bend: Vector3 = pole - dir * pole.dot(dir)
	if bend.length_squared() < 0.000001:
		bend = dir.cross(Vector3.UP) if absf(dir.y) < 0.99 else dir.cross(Vector3.RIGHT)
	var elbow: Vector3 = shoulder + dir * (u * cos_a) + bend.normalized() * (u * sqrt(1.0 - cos_a * cos_a))
	_point(upper, elbow - shoulder)
	_point(fore, shoulder + dir * d - fore.global_position)


## Turns `joint` the shortest way so its -y points along `dir` (world).
static func _point(joint: Node3D, dir: Vector3) -> void:
	var b: Basis = joint.global_basis
	var now: Vector3 = -b.y.normalized()
	var want: Vector3 = dir.normalized()
	if now.dot(want) < -0.9999:
		return
	joint.global_basis = Basis(Quaternion(now, want)) * b


## The barrels' spin and heat, the muzzle's ring, the flash and the aim line, from the charge (0–1 through the
## wind-up) and whether it's firing.
func _update_gatling(delta: float) -> void:
	var heat: float = 1.0 if firing else charge
	var target_spin: float = lerpf(SPIN_IDLE, SPIN_FULL, heat * heat) if heat > 0.0 else SPIN_IDLE
	_spin = target_spin if heat > 0.0 else move_toward(_spin, SPIN_IDLE, 30.0 * delta)
	_barrels.rotate_z(_spin * delta)
	_barrels.material_override = _hot_material() if heat >= HOT_FROM else null
	_ring.visible = heat > 0.02
	if _ring.visible:
		_ring.scale = Vector3.ONE * lerpf(0.35, 1.0, heat)
	_muzzle_flash_left -= delta
	_flash.visible = _muzzle_flash_left > 0.0
	if _aim_line.visible:
		_line_time += delta
		if is_inside_tree():
			_place_aim_line()


## The aim line from the muzzle to its target: a thin red bar, flickering faster as the wind-up ends (with Reduced
## flashing it thickens steadily instead), steady while firing. As the heli drone's (GDD §9.6).
func _place_aim_line() -> void:
	var from: Vector3 = _muzzle.global_position
	var d: Vector3 = _line_target - from
	var length: float = d.length()
	if length < 0.1:
		return
	var width: float = 1.0
	if _line_progress < 1.0:
		if Settings.flashing_reduced:
			width = lerpf(0.55, 1.0, _line_progress)
		else:
			width = 0.55 + 0.45 * absf(sin(_line_time * lerpf(6.0, 22.0, _line_progress)))
	var up: Vector3 = Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	_aim_line.global_transform = Transform3D(
		Basis.looking_at(d / length, up).scaled_local(Vector3(LINE_WIDTH * width, LINE_WIDTH * width, length)),
		from + d * 0.5)


func _build_gatling() -> void:
	var model: Dictionary = _gatling_model()
	_gun = Node3D.new()
	_gun.name = "Gatling"
	_gun.position = GUN_AT
	rig.joint(&"chest").add_child(_gun)
	var receiver := MeshInstance3D.new()
	receiver.mesh = model["receiver"]
	receiver.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gun.add_child(receiver)
	_barrels = MeshInstance3D.new()
	_barrels.mesh = model["barrels"]
	_barrels.position = Vector3(0.0, 0.0, -0.36)
	_barrels.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gun.add_child(_barrels)
	_muzzle = Node3D.new()
	_muzzle.position = MUZZLE
	_gun.add_child(_muzzle)
	_ring = MeshInstance3D.new()
	_ring.mesh = model["ring"]
	_ring.position = MUZZLE + Vector3(0.0, 0.0, 0.03)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	_gun.add_child(_ring)
	_flash = GreyboxMaterials.add_box(_gun, MUZZLE + Vector3(0.0, 0.0, -0.06), Vector3(0.26, 0.26, 0.2),
		GreyboxMaterials.glow(FLASH_COLOR, 5.0))
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	_handle = Node3D.new()
	_handle.position = HANDLE
	_gun.add_child(_handle)
	_coupling = Node3D.new()
	_coupling.position = COUPLING
	_gun.add_child(_coupling)
	_aim_line = MeshInstance3D.new()
	_aim_line.mesh = GreyboxMaterials.unit_box()
	_aim_line.material_override = GreyboxMaterials.glow(LINE_COLOR, 3.0, 0.6)
	_aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim_line.top_level = true
	_aim_line.visible = false
	add_child(_aim_line)


## The barrels' red-hot look (shared by every Heavy Cyborg).
static func _hot_material() -> Material:
	return GreyboxMaterials.glow(HOT_COLOR, 3.0)


## The gatling's low-poly meshes, built once and shared: the receiver (with its drum, handle, coupling and the
## barrels' rear clamp), the six barrels (spinning about z, from the receiver's front), and the muzzle's ring.
## Dull gunmetal, steel and rusted iron (GDD §9.2: nothing on it glows but the charge-up).
static func _gatling_model() -> Dictionary:
	if not _gatling.is_empty():
		return _gatling
	var gunmetal: Material = GreyboxMaterials.flat(Color(0.18, 0.19, 0.2))
	var steel: Material = GreyboxMaterials.flat(Color(0.42, 0.42, 0.41))
	var rust: Material = GreyboxMaterials.flat(Color(0.33, 0.22, 0.15))
	var r := MeshBatch.new()
	# The receiver: a long box with a sloped front, and a back plate.
	r.box(gunmetal, Vector3(0.0, 0.0, -0.18), Vector3(0.2, 0.2, 0.36))
	r.box(steel, Vector3(0.0, 0.0, -0.01), Vector3(0.17, 0.17, 0.03))
	r.box(steel, Vector3(0.0, 0.105, -0.2), Vector3(0.12, 0.02, 0.28))
	# The drum of ammunition on its left side, its feed chute, and a strap round it.
	r.cylinder(rust, Vector3(-0.19, -0.05, -0.15), Vector3(0.3, 0.13, 0.3), Vector3(0.0, 0.0, PI * 0.5))
	r.cylinder(steel, Vector3(-0.19, -0.05, -0.15), Vector3(0.12, 0.15, 0.12), Vector3(0.0, 0.0, PI * 0.5))
	r.box(gunmetal, Vector3(-0.115, 0.0, -0.15), Vector3(0.05, 0.1, 0.12))
	# The carry handle on top (the left hand's).
	for z: float in [-0.08, -0.26]:
		r.box(steel, Vector3(-0.01, 0.15, z), Vector3(0.03, 0.08, 0.03))
	r.box(gunmetal, Vector3(-0.01, 0.19, -0.17), Vector3(0.04, 0.035, 0.24))
	# The coupling on its right side, where the cyber arm's cannon plugs in.
	r.cylinder(gunmetal, Vector3(0.115, -0.02, -0.07), Vector3(0.15, 0.06, 0.15), Vector3(0.0, 0.0, PI * 0.5))
	r.cylinder(steel, Vector3(0.15, -0.02, -0.07), Vector3(0.1, 0.02, 0.1), Vector3(0.0, 0.0, PI * 0.5))
	# The barrels' rear clamp at the receiver's front.
	r.cylinder(steel, Vector3(0.0, 0.0, -0.37), Vector3(0.26, 0.05, 0.26), Vector3(PI * 0.5, 0.0, 0.0))
	var receiver: ArrayMesh = r.commit()
	# Six barrels round the axis (the barrels' node sits at the clamp, z -0.36), a middle clamp and a front one.
	var b := MeshBatch.new()
	for i: int in 6:
		var a: float = TAU * i / 6.0
		b.cylinder(gunmetal, Vector3(cos(a) * 0.07, sin(a) * 0.07, -0.31), Vector3(0.05, 0.62, 0.05), Vector3(PI * 0.5, 0.0, 0.0))
	b.cylinder(gunmetal, Vector3(0.0, 0.0, -0.31), Vector3(0.06, 0.62, 0.06), Vector3(PI * 0.5, 0.0, 0.0))
	for z: float in [-0.25, -0.56]:
		b.cylinder(steel, Vector3(0.0, 0.0, z), Vector3(0.22, 0.035, 0.22), Vector3(PI * 0.5, 0.0, 0.0))
	var barrels: ArrayMesh = b.commit()
	var g := MeshBatch.new()
	g.cylinder(_hot_material(), Vector3.ZERO, Vector3(0.24, 0.03, 0.24), Vector3(PI * 0.5, 0.0, 0.0))
	var ring: ArrayMesh = g.commit()
	_gatling = {"receiver": receiver, "barrels": barrels, "ring": ring}
	return _gatling
