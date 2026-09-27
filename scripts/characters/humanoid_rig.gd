class_name HumanoidRig
extends Node3D
## A segmented low-poly humanoid: 16 joints (Node3D), each carrying one rigid part (MeshInstance3D)
## built from a HumanoidParts description, animated procedurally (code-driven joint rotations, no
## imported animation). The player (PlayerAvatar, driving it with animate()) and the enemy cyborgs
## (CyborgBody, posing it with apply_pose()) use it with their own parts (GDD §9.2: one shared body
## and skeleton with swappable parts).
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
##
## Panels (optional; HumanoidParts.panels, e.g. a coat's skirt): stiff flaps hinged at the waist. All
## of them are one mesh on the pelvis joint ("Panels", one draw call); each frame update_panels()
## (called by animate()) swings each one by a pitch (forward/back) and a roll (outward) about its
## hinge, and the body shader turns the panel's vertices by that rotation (humanoid_panels.gdshaderinc),
## so the rig's material must be its own (PlayerAvatar duplicates it). A panel hangs toward the feet
## in the rig's frame (so on the ceiling too; on a wall it sags a little toward real gravity), follows
## its thigh through a damped spring, trails in the wind of the run, flares when falling, and is then
## pushed clear of the leg on its side and kept above the surface. Looks without panels are untouched.

enum Activity { IDLE, RUN, WALL, AIR, SLIDE, DASH, STOMP, DEAD }
const ACTIVITY_COUNT: int = 8
## Panels a rig can swing (the size of the shader's panel arrays).
const MAX_PANELS: int = 8
## Pitch range of a panel behind the leg and of one in front of it (radians; + = swung backward):
## a back panel may trail straight back along the ground (a slide), a front one flips up at most
## past level (a tucked jump), never over onto the body.
const BACK_PANEL_RANGE := Vector2(-1.92, 2.97)
const FRONT_PANEL_RANGE := Vector2(-2.0, 1.92)
## Roll range (radians; + = out to the side).
const PANEL_ROLL_RANGE := Vector2(-0.14, 1.22)
## Above this speed (m/s) a panel pushed by the ground trails backward (the ground drags it).
const MOVING_SPEED: float = 2.0

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

var _panels: MeshInstance3D
var _panel_count: int = 0
var _panel_hinges := PackedVector3Array()
## Per panel: pitch and roll (radians) and their speeds, and the rotation they make.
var _panel_pitch := PackedFloat32Array()
var _panel_pitch_v := PackedFloat32Array()
var _panel_roll := PackedFloat32Array()
var _panel_roll_v := PackedFloat32Array()
var _panel_q: Array[Quaternion] = []
var _panel_rot := PackedVector4Array()
var _panel_snap: bool = true
## Each panel's extreme points relative to its hinge (as built): what must stay off the surface.
var _panel_support: Array[PackedVector3Array] = []
## Heel and toe of each foot in its joint's space (left, right): points the panels keep clear of.
var _heel_toe: Array[PackedVector3Array] = []


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
		var node := Node3D.new()
		node.name = JOINT_NAMES[i]
		node.position = _rest[i]
		(_body if PARENT[i] < 0 else _joints[PARENT[i]]).add_child(node)
		_joints.append(node)
		var part := MeshInstance3D.new()
		part.name = "Part"
		node.add_child(part)
		_meshes.append(part)
		_support.append(parts.support_points(SEGMENT[i], LIMB_SIDE[i]))
		_xf.append(Transform3D.IDENTITY)
	_weights.resize(ACTIVITY_COUNT)
	_poses.clear()
	for i: int in ACTIVITY_COUNT:
		_poses.append(HumanoidPose.new())
	_refresh_meshes()
	_build_panels()
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
	_panel_snap = true


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
	if _panel_count > 0:
		# Panels hang toward the feet (the ceiling too); on a wall they sag toward real gravity,
		# which points along -wall_side × x in the rolled rig's frame (see HumanoidPoses.wall).
		var down := Vector3.DOWN
		if on_wall:
			down = (down + Vector3(-float(wall_side if wall_side != 0 else 1), 0.0, 0.0) \
				* tan(deg_to_rad(t.panel_wall_sag))).normalized()
		var airborne: bool = alive and not grounded and not on_wall
		update_panels(delta, {"speed": speed if alive else 0.0, "vh": vh if airborne else 0.0,
			"dashing": dashing and alive, "gravity": down})


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


## Bounds of the visible meshes (equipment and panels included) in the rig's parent space.
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
	if _panels_visible():
		var pelvis: Transform3D = _xf[HumanoidPose.PELVIS]
		var points: PackedVector3Array = _panels.mesh.get_meta(&"points")
		var owners: PackedInt32Array = _panels.mesh.get_meta(&"point_panels")
		for k: int in points.size():
			var v: Vector3 = pelvis * _panel_point(owners[k], points[k])
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
	if _panels_visible():
		n += int(_panels.mesh.get_meta(&"triangles", 0))
	return n


func draw_call_count() -> int:
	var n: int = 0
	for m: MeshInstance3D in _meshes:
		if m.mesh != null and m.visible:
			n += m.mesh.get_surface_count()
	if _panels_visible():
		n += _panels.mesh.get_surface_count()
	return n


## Every part mesh instance, in joint order (for tints, overlays, visibility). The panels' mesh is
## not among them: see panel_instance().
func part_instances() -> Array[MeshInstance3D]:
	return _meshes.duplicate()


## The panels' mesh instance (a child of the pelvis joint), or null for a look without panels.
func panel_instance() -> MeshInstance3D:
	return _panels


func panel_count() -> int:
	return _panel_count


## Panel `index`'s current pitch (x; + = swung backward) and roll (y; + = out to the side), radians.
func panel_angles(index: int) -> Vector2:
	return Vector2(_panel_pitch[index], _panel_roll[index])


## The middle of panel `index`'s hem, in the rig's parent space (like bounds()).
func panel_hem(index: int) -> Vector3:
	var panel: HumanoidPanel = parts.panels[index]
	var pelvis: Transform3D = transform * _body.transform * _joints[HumanoidPose.PELVIS].transform
	return pelvis * _panel_point(index, _panel_hinges[index] + Vector3(0.0, -panel.length, 0.0))


## Panel `index`'s hinge (the middle of its top edge), in the rig's parent space.
func panel_hinge(index: int) -> Vector3:
	return transform * _body.transform * _joints[HumanoidPose.PELVIS].transform * _panel_hinges[index]


## Swings the panels for this frame (see "Panels" above). animate() calls it; a user that poses the
## rig itself with apply_pose() calls it afterwards. `motion` keys (all optional): speed (m/s, the
## wind of the run), vh (m/s away from the surface; falling flares the panels), dashing (bool, a
## stronger wind), gravity (Vector3: which way the panels hang, in the rig's frame; default -y).
func update_panels(delta: float, motion: Dictionary = {}) -> void:
	if _panel_count == 0:
		return
	var t: HumanoidAnimTuning = tuning
	var pelvis_xf: Transform3D = _body.transform * _joints[HumanoidPose.PELVIS].transform
	var to_pelvis: Basis = pelvis_xf.basis.orthonormalized().inverse()
	var down: Vector3 = motion.get("gravity", Vector3.DOWN)
	var g: Vector3 = (to_pelvis * down).normalized()
	var wind: Vector3 = to_pelvis * Vector3.BACK
	# The height above the surface (rig frame) of a vector in the pelvis frame, scale included.
	var pb: Basis = pelvis_xf.basis
	var height_of := Vector3(pb.x.y, pb.y.y, pb.z.y)
	var speed: float = float(motion.get("speed", 0.0))
	var moving: bool = speed > MOVING_SPEED
	var drag: float = t.panel_drag * clampf(speed / t.panel_drag_speed, 0.0, 1.0)
	if bool(motion.get("dashing", false)):
		drag = minf(drag * t.panel_dash_drag, 0.9)
	var fall: float = clampf(-float(motion.get("vh", 0.0)) / t.panel_flare_speed, 0.0, 1.0)
	var hang: float = atan2(g.z, -g.y)
	var wind_pitch: float = atan2(wind.z, -wind.y)
	var steps: int = clampi(ceili(delta * 60.0 - 0.001), 1, 8)
	var h: float = delta / steps
	for i: int in _panel_count:
		var panel: HumanoidPanel = parts.panels[i]
		var side: int = panel.side
		var away: float = 1.0 if panel.behind else -1.0
		var thigh: Node3D = _joints[HumanoidPose.limb(HumanoidPose.THIGH_R, side)]
		var thigh_dir: Vector3 = thigh.transform.basis * Vector3.DOWN
		# Where it wants to be: hanging, pulled along by the thigh, blown back, flared by a fall.
		var target: float = hang
		target += panel.follow * angle_difference(target, atan2(thigh_dir.z, -thigh_dir.y))
		target += drag * angle_difference(target, wind_pitch)
		target += away * deg_to_rad(t.panel_fall_flare) * fall
		var roll_target: float = asin(clampf(g.x * side, -1.0, 1.0)) + deg_to_rad(t.panel_fall_roll) * fall
		var s: float = _panel_pitch[i]
		var sv: float = _panel_pitch_v[i]
		var r: float = _panel_roll[i]
		var rv: float = _panel_roll_v[i]
		if _panel_snap:
			s = target
			r = roll_target
			sv = 0.0
			rv = 0.0
		elif delta > 0.0:
			for n: int in steps:
				sv += (t.panel_stiffness * angle_difference(s, target) - t.panel_damping * sv) * h
				s += sv * h
				rv += (t.panel_stiffness * angle_difference(r, roll_target) - t.panel_damping * rv) * h
				r += rv * h
		var range_s: Vector2 = BACK_PANEL_RANGE if panel.behind else FRONT_PANEL_RANGE
		r = clampf(r, PANEL_ROLL_RANGE.x, PANEL_ROLL_RANGE.y)
		# The leg on its side pushes it: knee, ankle, heel and toe stay on the leg's side of the panel.
		var limit: float = _leg_limit(i, side, panel, t.panel_leg_clearance)
		if panel.behind and s < limit:
			s = limit
			sv = maxf(sv, 0.0)
		elif not panel.behind and s > limit:
			s = limit
			sv = minf(sv, 0.0)
		# The surface pushes it too.
		var pushed: float = _ground_limit(pelvis_xf, height_of, i, panel, s, side * r, t.panel_ground_clearance,
			wind_pitch if moving else NAN)
		if not is_equal_approx(pushed, s):
			s = pushed
			sv = 0.0
		s = clampf(s, range_s.x, range_s.y)
		_panel_pitch[i] = s
		_panel_pitch_v[i] = sv
		_panel_roll[i] = r
		_panel_roll_v[i] = rv
		var q: Quaternion = Basis.from_euler(Vector3(-s, 0.0, side * r)).get_rotation_quaternion()
		_panel_q[i] = q
		_panel_rot[i] = Vector4(q.x, q.y, q.z, q.w)
	_panel_snap = false
	var m := material as ShaderMaterial
	if m != null:
		m.set_shader_parameter(&"panel_rot", _panel_rot)


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


## The panels' mesh on the pelvis joint, their state, and the shader's hinge array.
func _build_panels() -> void:
	_panels = null
	_panel_count = 0
	var mesh: ArrayMesh = parts.panel_mesh()
	if mesh != null:
		if parts.panels.size() > MAX_PANELS:
			push_warning("HumanoidRig: only the first %d panels swing" % MAX_PANELS)
		_panel_count = mini(parts.panels.size(), MAX_PANELS)
	_panel_hinges.resize(_panel_count)
	# (Packed arrays are values: each one is resized by name.)
	_panel_pitch.resize(_panel_count)
	_panel_pitch.fill(0.0)
	_panel_pitch_v.resize(_panel_count)
	_panel_pitch_v.fill(0.0)
	_panel_roll.resize(_panel_count)
	_panel_roll.fill(0.0)
	_panel_roll_v.resize(_panel_count)
	_panel_roll_v.fill(0.0)
	_panel_q.resize(_panel_count)
	_panel_q.fill(Quaternion.IDENTITY)
	_panel_rot.resize(MAX_PANELS)
	_panel_rot.fill(Vector4(0.0, 0.0, 0.0, 1.0))
	if _panel_count == 0:
		return
	var reach: float = 0.3
	var hinges := PackedVector4Array()
	hinges.resize(MAX_PANELS)
	for i: int in _panel_count:
		_panel_hinges[i] = parts.panels[i].placed_hinge()
		hinges[i] = Vector4(_panel_hinges[i].x, _panel_hinges[i].y, _panel_hinges[i].z, 0.0)
		reach = maxf(reach, _panel_hinges[i].length() + parts.panels[i].length + 0.1)
	# Each panel's extreme points (the corners of its sheet), relative to its hinge.
	var points: PackedVector3Array = mesh.get_meta(&"points")
	var owners: PackedInt32Array = mesh.get_meta(&"point_panels")
	_panel_support.clear()
	for i: int in _panel_count:
		var own := PackedVector3Array()
		for k: int in points.size():
			if owners[k] == i:
				own.append(points[k] - _panel_hinges[i])
		var support := PackedVector3Array()
		for dir: Vector3 in HumanoidParts.support_directions():
			var best: Vector3 = own[0]
			for p: Vector3 in own:
				if p.dot(dir) > best.dot(dir):
					best = p
			if not support.has(best):
				support.append(best)
		_panel_support.append(support)
	_heel_toe.clear()
	for side: int in [-1, 1]:
		var heel := Vector3.ZERO
		var toe := Vector3.ZERO
		for p: Vector3 in parts.support_points(&"foot", side):
			heel = p if p.z > heel.z else heel
			toe = p if p.z < toe.z else toe
		_heel_toe.append(PackedVector3Array([heel, toe]))
	_panels = MeshInstance3D.new()
	_panels.name = "Panels"
	_panels.mesh = mesh
	if material != null:
		_panels.set_surface_override_material(0, material)
	# The shader swings the panels, so the mesh's own box doesn't cover them: cull by every swing.
	_panels.custom_aabb = AABB(-Vector3.ONE * reach, Vector3.ONE * reach * 2.0)
	_joints[HumanoidPose.PELVIS].add_child(_panels)
	var m := material as ShaderMaterial
	if m != null:
		m.set_shader_parameter(&"panel_hinge", hinges)
		m.set_shader_parameter(&"panel_rot", _panel_rot)


func _panels_visible() -> bool:
	return _panels != null and _panels.visible and _panels.mesh != null


## A point of panel `index` (pelvis joint space, as built) where the panel's swing puts it.
func _panel_point(index: int, point: Vector3) -> Vector3:
	var hinge: Vector3 = _panel_hinges[index]
	return hinge + _panel_q[index] * (point - hinge)


## The pitch the leg on a panel's side lets it reach: the least for a panel behind the leg, the most
## for one in front, so the middle of the thigh, the knee, ankle, heel and toe keep `clearance` from
## it. (Not the hip: that's under the belt, where the panel hangs from.)
func _leg_limit(index: int, side: int, panel: HumanoidPanel, clearance: float) -> float:
	var thigh_xf: Transform3D = _joints[HumanoidPose.limb(HumanoidPose.THIGH_R, side)].transform
	var shin_xf: Transform3D = thigh_xf * _joints[HumanoidPose.limb(HumanoidPose.SHIN_R, side)].transform
	var foot_xf: Transform3D = shin_xf * _joints[HumanoidPose.limb(HumanoidPose.FOOT_R, side)].transform
	var heel_toe: PackedVector3Array = _heel_toe[0 if side < 0 else 1]
	var hinge: Vector3 = _panel_hinges[index]
	var limit: float = -INF if panel.behind else INF
	var mid_thigh: Vector3 = (thigh_xf.origin + shin_xf.origin) * 0.5
	for p: Vector3 in [mid_thigh, shin_xf.origin, foot_xf.origin, foot_xf * heel_toe[0], foot_xf * heel_toe[1]]:
		var v: Vector3 = p - hinge
		var reach: float = Vector2(v.y, v.z).length()
		if reach < 0.001 or reach > panel.length + clearance:
			continue
		var at: float = atan2(v.z, -v.y)
		var margin: float = asin(minf(clearance / reach, 1.0))
		limit = maxf(limit, at + margin) if panel.behind else minf(limit, at - margin)
	return limit


## The pitch that keeps panel `index` `clearance` above the surface (y = 0 in the rig's frame), or
## `pitch` itself when it already clears. The panel swings until every extreme point clears: toward
## `trail` (the pitch pointing straight back) while the runner moves, as the ground rushing past drags
## the hem back (the coat trails behind a slide); otherwise the way its hem already leans from the
## point under the hinge (the front panels fold along the legs when the body falls on them). `roll`
## is the panel's signed outward turn (the Euler z angle).
func _ground_limit(pelvis_xf: Transform3D, height_of: Vector3, index: int, panel: HumanoidPanel,
		pitch: float, roll: float, clearance: float, trail: float) -> float:
	var h0: float = (pelvis_xf * _panel_hinges[index]).y
	var turn := Basis(Vector3.BACK, roll)
	var way: float = 0.0
	if not is_nan(trail):
		way = signf(angle_difference(pitch, trail))
	else:
		# The pitch that drops the hem lowest (straight down), and which side of it the panel is on.
		var hem: Vector3 = turn * Vector3(0.0, -panel.length, 0.0)
		var lowest: float = atan2(height_of.y * hem.z - height_of.z * hem.y, height_of.y * hem.y + height_of.z * hem.z) + PI
		way = signf(angle_difference(lowest, pitch))
	if way == 0.0:
		way = 1.0 if panel.behind else -1.0
	var s: float = pitch
	for attempt: int in 4:
		var moved: bool = false
		for v: Vector3 in _panel_support[index]:
			# The point (hinge-relative u after the roll) turned by the pitch is h0 + A·cos + B·sin
			# (+ a constant) high; it clears while A·cos(pitch) + B·sin(pitch) ≥ C.
			var u: Vector3 = turn * v
			var a: float = height_of.y * u.y + height_of.z * u.z
			var b: float = height_of.y * u.z - height_of.z * u.y
			var c: float = clearance - h0 - height_of.x * u.x
			var rr: float = sqrt(a * a + b * b)
			if rr < 1e-6 or absf(c / rr) >= 1.0:
				continue  # Always clear, or can't clear at any pitch: nothing to gain.
			var top: float = atan2(b, a)  # the pitch that lifts this point highest
			var w: float = acos(c / rr)
			if absf(angle_difference(top, s)) <= w:
				continue
			s = s + fposmod(top - w - s, TAU) if way > 0.0 else s - fposmod(s - (top + w), TAU)
			moved = true
		if not moved:
			break
	return s


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
