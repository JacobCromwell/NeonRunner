class_name HumanoidRig
extends Node3D
## A segmented low-poly humanoid: 16 joints (Node3D), each carrying one rigid part (MeshInstance3D)
## built from a HumanoidParts description, animated procedurally (code-driven joint rotations, no
## imported animation). The player (PlayerAvatar) uses it now; the enemy cyborgs will use it with
## other parts (GDD §9.2: one shared body and skeleton with swappable parts).
##
## Hierarchy: HumanoidRig (its scale fits the figure to a size) → Body (the ground point under the
## pelvis: whole-body lean, collapse and squash) → pelvis → chest → neck → head; chest → upper_arm_l/r
## → forearm → hand; pelvis → thigh_l/r → shin → foot. Each joint's mesh is its child "Part".
## The rig faces -z with +y away from the surface it stands on.
##
## animate(state, delta) picks an activity from a movement state (the keys PlayerAvatar documents),
## blends the activity poses from HumanoidPoses at the tuning's blend speeds, adds the lane-switch lean
## and the landing squash, then puts the body on the ground: its lowest point at y = 0, plus the
## stride's flight phase. The run cycle advances with the distance run, not with time.

enum Activity { IDLE, RUN, WALL, AIR, SLIDE, DASH, STOMP, DEAD }
const ACTIVITY_COUNT: int = 8

const JOINT_NAMES: Array[StringName] = [&"pelvis", &"chest", &"neck", &"head",
	&"upper_arm_l", &"forearm_l", &"hand_l", &"upper_arm_r", &"forearm_r", &"hand_r",
	&"thigh_l", &"shin_l", &"foot_l", &"thigh_r", &"shin_r", &"foot_r"]
## Parent joint of each joint (-1 = the Body node). Parents come before their children.
const PARENT: Array[int] = [-1, 0, 1, 2, 1, 4, 5, 1, 7, 8, 0, 10, 11, 0, 13, 14]
const SEGMENT: Array[StringName] = [&"pelvis", &"chest", &"neck", &"head",
	&"upper_arm", &"forearm", &"hand", &"upper_arm", &"forearm", &"hand",
	&"thigh", &"shin", &"foot", &"thigh", &"shin", &"foot"]
const LIMB_SIDE: Array[int] = [0, 0, 0, 0, -1, -1, -1, 1, 1, 1, -1, -1, -1, 1, 1, 1]
## Distance jumps larger than this between two frames (restart, teleport) don't move the legs.
const MAX_STEP_DISTANCE: float = 5.0

var parts: HumanoidParts
var tuning: HumanoidAnimTuning
## Applied to every mesh's body surface (vertex colour + glow), usually a humanoid_body.gdshader copy.
var material: Material
## The activity the rig is blending toward.
var activity: Activity = Activity.IDLE

var _body: Node3D
var _joints: Array[Node3D] = []
var _meshes: Array[MeshInstance3D] = []
var _rest := PackedVector3Array()
var _support: Array[PackedVector3Array] = []
var _xf: Array[Transform3D] = []
var _attachments: Array[StringName] = []
var _weights := PackedFloat32Array()
var _poses: Array[HumanoidPose] = []
var _out := HumanoidPose.new()
var _phase: float = 0.0
var _last_distance: float = NAN
var _time: float = 0.0
var _death_t: float = 0.0
var _land_t: float = 0.0
var _lean: float = 0.0
var _lead: int = 1
var _was_supported: bool = true
var _snap: bool = true


## Builds (or rebuilds) the body from `p_parts`. Meshes come from the parts' static cache.
func build(p_parts: HumanoidParts, p_material: Material, p_tuning: HumanoidAnimTuning = null) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	parts = p_parts
	material = p_material
	tuning = p_tuning if p_tuning != null else HumanoidAnimTuning.new()
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_rest = _rest_positions()
	_joints.clear()
	_meshes.clear()
	_support.clear()
	_xf.clear()
	for i: int in JOINT_NAMES.size():
		var joint := Node3D.new()
		joint.name = JOINT_NAMES[i]
		joint.position = _rest[i]
		(_body if PARENT[i] < 0 else _joints[PARENT[i]]).add_child(joint)
		_joints.append(joint)
		var part := MeshInstance3D.new()
		part.name = "Part"
		joint.add_child(part)
		_meshes.append(part)
		_support.append(parts.support_points(SEGMENT[i], LIMB_SIDE[i]))
		_xf.append(Transform3D.IDENTITY)
	_weights.resize(ACTIVITY_COUNT)
	_poses.clear()
	for i: int in ACTIVITY_COUNT:
		_poses.append(HumanoidPose.new())
	_refresh_meshes()
	reset_pose()


## The joint node carrying a segment, e.g. &"hand_r" (attach props to it).
func joint(joint_name: StringName) -> Node3D:
	var i: int = JOINT_NAMES.find(joint_name)
	return _joints[i] if i >= 0 else null


## Switches the named attachment sets of the parts on (all others off). Their pieces are merged
## into the segment meshes, so equipment costs triangles but no extra draw calls.
func set_attachments(names: Array[StringName]) -> void:
	var sorted_names: Array[StringName] = names.duplicate()
	sorted_names.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	if sorted_names == _attachments:
		return
	_attachments = sorted_names
	_refresh_meshes()


func attachments() -> Array[StringName]:
	return _attachments.duplicate()


## Forgets the motion history: the next animate() snaps to its pose instead of blending.
func reset_pose() -> void:
	_phase = 0.0
	_last_distance = NAN
	_death_t = 0.0
	_land_t = 0.0
	_lean = 0.0
	_lead = 1
	_snap = true


## Advances the animation by `delta` seconds from a movement state (keys: surface, grounded, vh,
## sliding, distance, speed, wall_side, switch_dir, alive, dashing, stomping, just_landed; see
## PlayerAvatar). Missing keys fall back to standing still on the floor.
func animate(state: Dictionary, delta: float) -> void:
	var t: HumanoidAnimTuning = tuning
	var surface: String = String(state.get("surface", "floor"))
	var on_wall: bool = surface == "wall"
	var grounded: bool = bool(state.get("grounded", true))
	var alive: bool = bool(state.get("alive", true))
	var sliding: bool = bool(state.get("sliding", false))
	var dashing: bool = bool(state.get("dashing", false))
	var stomping: bool = bool(state.get("stomping", false))
	var speed: float = float(state.get("speed", 0.0))
	var vh: float = float(state.get("vh", 0.0))
	var wall_side: int = int(state.get("wall_side", 1))
	var switch_dir: float = float(state.get("switch_dir", 0))
	if surface == "ceiling":
		switch_dir = -switch_dir  # The pivot is rolled 180°: world right is the rig's left.
	var distance: float = float(state.get("distance", 0.0 if is_nan(_last_distance) else _last_distance))

	_time += delta
	_death_t = _death_t + delta if not alive else 0.0

	# The leg cycle follows the distance run (not time), so the stride keeps pace with the ground.
	var moved: float = 0.0 if is_nan(_last_distance) else distance - _last_distance
	_last_distance = distance
	if moved < 0.0 or moved > MAX_STEP_DISTANCE:
		moved = 0.0
	var supported: bool = grounded or on_wall
	var amount: float = clampf(speed / t.full_stride_speed, 0.0, 1.0)
	if supported and alive and not sliding:
		# A shorter stride at low speed (the amplitude shrinks with `amount`), capped cadence at speed.
		var cadence: float = t.max_cadence * (t.dash_cadence_scale if dashing else 1.0)
		var stride: float = maxf(t.stride_length * maxf(amount, 0.2), speed / cadence)
		_phase = fposmod(_phase + moved / stride, 1.0)

	# Takeoff: the leg that is forward drives the jump. Touchdown: squash.
	if _was_supported and not supported:
		_lead = HumanoidPoses.leading_leg(_phase)
	var landed: bool = bool(state.get("just_landed", false)) or (grounded and not _was_supported)
	if landed and alive and not _snap:
		_land_t = t.land_squash_time
	_was_supported = supported
	_land_t = maxf(0.0, _land_t - delta)

	activity = _pick(alive, dashing, on_wall, stomping, sliding, grounded, speed)
	var fast: bool = activity == Activity.SLIDE or activity == Activity.STOMP or activity == Activity.DEAD
	var k: float = 1.0 if _snap else 1.0 - exp(-(t.fast_blend_speed if fast else t.blend_speed) * delta)
	for i: int in ACTIVITY_COUNT:
		_weights[i] = lerpf(_weights[i], 1.0 if i == activity else 0.0, k)
	var lean_k: float = 1.0 if _snap else 1.0 - exp(-t.switch_lean_speed * delta)
	_lean = lerpf(_lean, clampf(switch_dir, -1.0, 1.0) if alive else 0.0, lean_k)
	_snap = false

	var total: float = 0.0
	_out.clear_sum()
	for i: int in ACTIVITY_COUNT:
		var w: float = _weights[i]
		if w < 0.002:
			continue
		var p: HumanoidPose = _poses[i]
		match i:
			Activity.IDLE:
				HumanoidPoses.idle(p, _time, t)
			Activity.RUN:
				HumanoidPoses.run(p, _phase, amount, t)
			Activity.WALL:
				HumanoidPoses.wall(p, _phase, amount, t, wall_side)
			Activity.AIR:
				HumanoidPoses.air(p, vh / t.jump_pose_speed, _lead, t)
			Activity.SLIDE:
				HumanoidPoses.slide(p, t)
			Activity.DASH:
				HumanoidPoses.dash(p, _phase, t)
			Activity.STOMP:
				HumanoidPoses.stomp(p, t)
			Activity.DEAD:
				HumanoidPoses.dead(p, _death_t / t.death_time, t)
		_out.accumulate(p, w)
		total += w
	_out.finish(total)
	HumanoidPoses.add_lean(_out, _lean, t)
	HumanoidPoses.add_landing(_out, _landing_curve(), t)
	apply_pose(_out)


## Blend weight of an activity (0–1).
func weight(which: Activity) -> float:
	return _weights[which]


## The leg cycle phase (0–1), for tests and effects.
func phase() -> float:
	return _phase


## Sets the joints from a pose, then puts the body on the ground.
func apply_pose(p: HumanoidPose) -> void:
	for i: int in _joints.size():
		_joints[i].rotation = p.rot[i]
	_joints[0].position = _rest[0] + p.pelvis_offset
	_body.transform = Transform3D(Basis.from_euler(p.root_rot) * Basis.from_scale(p.root_scale), p.root_offset)
	if p.ground > 0.0:
		_body.position.y -= _lowest_point() * p.ground
	_body.position.y += p.lift


## Bounds of the visible meshes (equipment included) in the rig's parent space.
func bounds() -> AABB:
	var out := AABB()
	var first: bool = true
	var base: Transform3D = transform * _body.transform
	for i: int in _joints.size():
		_xf[i] = (base if PARENT[i] < 0 else _xf[PARENT[i]]) * _joints[i].transform
		var mesh: Mesh = _meshes[i].mesh
		if mesh == null or not _meshes[i].visible:
			continue
		for point: Vector3 in mesh.get_meta(&"points", PackedVector3Array()):
			var v: Vector3 = _xf[i] * point
			if first:
				out = AABB(v, Vector3.ZERO)
				first = false
			else:
				out = out.expand(v)
	return out


func triangle_count() -> int:
	var n: int = 0
	for m: MeshInstance3D in _meshes:
		if m.mesh != null and m.visible:
			n += int(m.mesh.get_meta(&"triangles", 0))
	return n


func draw_call_count() -> int:
	var n: int = 0
	for m: MeshInstance3D in _meshes:
		if m.mesh != null and m.visible:
			n += m.mesh.get_surface_count()
	return n


## Every part mesh instance, in joint order (for tints, overlays, visibility).
func part_instances() -> Array[MeshInstance3D]:
	return _meshes.duplicate()


func _pick(alive: bool, dashing: bool, on_wall: bool, stomping: bool, sliding: bool, grounded: bool,
		speed: float) -> Activity:
	if not alive:
		return Activity.DEAD
	if dashing:
		return Activity.DASH
	if on_wall:
		return Activity.WALL
	if stomping and not grounded:
		return Activity.STOMP
	if sliding:
		return Activity.SLIDE
	if not grounded:
		return Activity.AIR
	if speed < tuning.idle_speed:
		return Activity.IDLE
	return Activity.RUN


## 0 at touchdown, peaking quickly, then easing back to 0 over land_squash_time.
func _landing_curve() -> float:
	if _land_t <= 0.0:
		return 0.0
	var u: float = 1.0 - _land_t / tuning.land_squash_time
	return smoothstep(0.0, 0.2, u) if u < 0.2 else 1.0 - smoothstep(0.2, 1.0, u)


func _lowest_point() -> float:
	var low: float = INF
	var body_xf: Transform3D = _body.transform
	for i: int in _joints.size():
		_xf[i] = (body_xf if PARENT[i] < 0 else _xf[PARENT[i]]) * _joints[i].transform
		for point: Vector3 in _support[i]:
			low = minf(low, (_xf[i] * point).y)
	return low if low < INF else 0.0


func _refresh_meshes() -> void:
	for i: int in _meshes.size():
		var mesh: ArrayMesh = parts.segment_mesh(SEGMENT[i], LIMB_SIDE[i], _attachments)
		_meshes[i].mesh = mesh
		if mesh != null and int(mesh.get_meta(&"body_surface", -1)) == 0 and material != null:
			_meshes[i].set_surface_override_material(0, material)


func _rest_positions() -> PackedVector3Array:
	var r := PackedVector3Array()
	r.resize(JOINT_NAMES.size())
	var sh: Vector3 = parts.shoulder_offset
	var hip: Vector3 = parts.hip_offset
	var upper := Vector3(0.0, -parts.upper_arm_length, 0.0)
	var fore := Vector3(0.0, -parts.forearm_length, 0.0)
	var thigh := Vector3(0.0, -parts.thigh_length, 0.0)
	var shin := Vector3(0.0, -parts.shin_length, 0.0)
	r[HumanoidPose.PELVIS] = Vector3(0.0, parts.pelvis_height(), 0.0)
	r[HumanoidPose.CHEST] = parts.chest_offset
	r[HumanoidPose.NECK] = parts.neck_offset
	r[HumanoidPose.HEAD] = parts.head_offset
	r[HumanoidPose.UPPER_ARM_L] = Vector3(-sh.x, sh.y, sh.z)
	r[HumanoidPose.FOREARM_L] = upper
	r[HumanoidPose.HAND_L] = fore
	r[HumanoidPose.UPPER_ARM_R] = sh
	r[HumanoidPose.FOREARM_R] = upper
	r[HumanoidPose.HAND_R] = fore
	r[HumanoidPose.THIGH_L] = Vector3(-hip.x, hip.y, hip.z)
	r[HumanoidPose.SHIN_L] = thigh
	r[HumanoidPose.FOOT_L] = shin
	r[HumanoidPose.THIGH_R] = hip
	r[HumanoidPose.SHIN_R] = thigh
	r[HumanoidPose.FOOT_R] = shin
	return r
