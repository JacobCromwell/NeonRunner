class_name CasinoPerson
extends Node3D
## One person of the Casino's boss intro (CasinoPeople's looks) on the shared HumanoidRig, posed by the cinematic's own
## clock: it never moves itself between frames. Each frame the cinematic calls stand() or walk() (they set every joint
## afresh, so nothing builds up), then any of the overlays, each blended in by its k (0-1): cheer(), clap(), drink(),
## hold_glass(), look_at_point(), gesture_flick(), lean_back_elbows(). The Wealthy Woman in Red keeps her cocktail glass
## upright in her left hand through stand() and walk() (hold_glass(1, -1)), and an overlay only blends away from that.
## Rig convention (HumanoidPiece): metres at design scale, +y up, -z forward (where the person faces), +x their right.
## Every pose is a function of the clock `t` and (for the walk) the phase kept from the distance moved: standing, then
## any overlay, on a rig that never walked gives the same pose every time (a pose may be baked into a static mesh).
## DESIGN-TBD: the poses are hand-set placeholders.

## How fast the walk's pace follows the speed asked for (s), as CineActorNode smooths it.
const GAIT_SMOOTH: float = 0.15
## Looking at a point: how the turn is shared up the spine (chest, neck, head), the most the person turns (radians) and tips.
const LOOK_SHARE: Array[float] = [0.25, 0.3, 0.45]
const LOOK_JOINTS: Array[StringName] = [&"chest", &"neck", &"head"]
const LOOK_LIMIT: float = 1.2
const TIP_LIMIT: float = 0.5
## Cheering: how fast the fists pump (Hz) and how high the little hop is (metres at the figure's own size).
const CHEER_HZ: float = 2.6
const CHEER_HOP: float = 0.025
## Clapping: how often the hands meet (Hz) and how far apart they open (metres at design scale, each side of the middle).
const CLAP_HZ: float = 3.2
const CLAP_OPEN: float = 0.07

var rig: HumanoidRig
var look: CasinoPeople.Look

var _pose := HumanoidPose.new()
var _phase: float = 0.0
var _gait: float = -1.0
var _glass: bool = false


## Builds the person `height` metres tall (feet to the top of the head), facing -z. A look with panels (a skirt or a
## coat) gets its own copy of the body material, as every rig with panels must. `parts_override` builds the rig from
## those parts instead of CasinoPeople.parts(look) (a repainted copy of the look, say): the height is still fitted to the
## look's design height, and the panels and the glass are handled as for the look.
func setup(p_look: CasinoPeople.Look, height: float, parts_override: HumanoidParts = null) -> void:
	look = p_look
	name = "Person"
	rig = HumanoidRig.new()
	rig.name = "Rig"
	add_child(rig)
	var parts: HumanoidParts = parts_override if parts_override != null else CasinoPeople.parts(look)
	var material: Material = CitizenRig.material()
	if CasinoPeople.has_panels(look) or not parts.panels.is_empty():
		material = material.duplicate()
	var anim := load(PlayerAvatar.ANIM_TUNING_PATH) as HumanoidAnimTuning
	anim = anim.duplicate() as HumanoidAnimTuning if anim != null else HumanoidAnimTuning.new()
	anim.panel_leg_clearance = CasinoPeople.panel_clearance(look)
	rig.build(parts, material, anim)
	rig.scale = Vector3.ONE * (height / CasinoPeople.design_height(look))
	for mi: Node in rig.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glass = CasinoPeople.has_glass(look)
	stand(0.0, 0.0)


## Standing at ease at time `t` (the cinematic's clock; `delta` the step): a breath, her or his weight shifting from foot
## to foot (the runner's standing, CinePoses.walk at a standstill). Settles out of a walk if it was walking.
func stand(t: float, delta: float) -> void:
	_step(0.0, 0.0, t, delta)


## Walking at `speed` (m/s), having moved `distance_moved` metres this step: the runner's walk (CinePoses.walk), its
## stride following the ground covered (this keeps its own phase), the feet not skating. Slowing to nothing it settles
## into standing.
func walk(distance_moved: float, speed: float, t: float, delta: float) -> void:
	_step(distance_moved, speed, t, delta)


## Cheering (a win at the table): both arms thrown up, the fists pumping a little, a small hop, the head back.
func cheer(k: float, t: float) -> void:
	if k <= 0.0:
		return
	for side: int in [1, -1]:
		var pump: float = sin(TAU * CHEER_HZ * t + (0.0 if side > 0 else PI * 0.7))
		_arm(side, Vector3(-6.0 + 12.0 * pump, 0.0, 146.0 + 6.0 * pump), Vector3(18.0 + 32.0 * maxf(pump, 0.0), 0.0, 0.0), k)
	_tilt(&"chest", 4.0 * k)
	_tilt(&"head", 8.0 * k)
	rig.position.y = CHEER_HOP * absf(sin(PI * CHEER_HZ * 0.5 * t)) * k


## Clapping in front of the chest: the hands meeting and opening again.
func clap(k: float, t: float) -> void:
	if k <= 0.0:
		return
	var open: float = CLAP_OPEN * (0.5 + 0.5 * cos(TAU * CLAP_HZ * t))
	for side: int in [1, -1]:
		var shoulder: Vector3 = _joint_at(side, &"upper_arm")
		var wrist := Vector3(side * (0.012 + open), shoulder.y - 0.1, -(rig.parts.upper_arm_length + rig.parts.forearm_length) * 0.62)
		_reach(side, wrist, Vector3(side * 0.7, -1.0, 0.4), k)


## A sip: the hand on `side` (1 right, -1 left) raised to the mouth, the head tipping back a little.
func drink(k: float, side: int) -> void:
	if k <= 0.0:
		return
	var mouth: Vector3 = rig.joint(&"neck").position + rig.joint(&"head").position
	_reach(side, mouth + Vector3(side * 0.03, -0.05, -0.065), Vector3(side * 0.6, -1.0, 0.3), k, Vector3(0.0, 0.45, 0.9))
	_tilt(&"head", 7.0 * k)


## The hand on `side` held at chest height, the forearm forward, as if holding a glass (its back down, its front up: the
## glass in the Wealthy Woman in Red's left hand stands upright).
func hold_glass(k: float, side: int) -> void:
	if k <= 0.0:
		return
	var shoulder: Vector3 = _joint_at(side, &"upper_arm")
	var l1: float = rig.parts.upper_arm_length
	var l2: float = rig.parts.forearm_length
	var wrist := shoulder + Vector3(-side * 0.075, -0.88 * l1, -(0.42 * l1 + 0.98 * l2))
	_reach(side, wrist, Vector3(side * 0.4, -1.0, 0.2), k, Vector3.UP)


## The head (shared over the chest, neck and head, as MarketplaceIntroVendor does) turned toward `target` (world
## space) by k. The caller passes the target every frame; nothing here eases, and the turn is limited.
func look_at_point(target: Vector3, k: float) -> void:
	if k <= 0.0:
		return
	var head: Node3D = rig.joint(&"head")
	var local: Vector3 = global_transform.affine_inverse() * target
	var from: Vector3 = global_transform.affine_inverse() * head.global_position
	var d: Vector3 = local - from
	if d.length_squared() < 0.0001:
		return
	var turn: float = clampf(atan2(-d.x, -d.z), -LOOK_LIMIT, LOOK_LIMIT) * k
	var tip: float = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -TIP_LIMIT, TIP_LIMIT) * k
	for i: int in LOOK_JOINTS.size():
		var j: Node3D = rig.joint(LOOK_JOINTS[i])
		j.rotate_object_local(Vector3.UP, turn * LOOK_SHARE[i])
		j.rotate_object_local(Vector3.RIGHT, tip * LOOK_SHARE[i])


## A curt flick of the right hand out to the side (the Chairman ordering his guards): the arm lifts out from the body and
## the hand snaps outward. `k` 0-1 is the flick, `t` the clock for the wrist's tremor at its end.
func gesture_flick(k: float, t: float) -> void:
	if k <= 0.0:
		return
	var snap: float = smoothstep(0.55, 1.0, k)
	_arm(1, Vector3(26.0 * k, -10.0 * k, 28.0 + 30.0 * snap), Vector3(78.0 - 44.0 * snap, 0.0, 0.0), k)
	var hand: Node3D = rig.joint(&"hand_r")
	BeachOutroBar._blend(hand, VolleyballRival._limb(1, Vector3(-28.0 * snap + 3.0 * sin(TAU * 9.0 * t) * snap, 0.0, 24.0 * snap)), k)
	_tilt(&"head", 3.0 * k)


## Leaning back with both elbows resting behind on a counter (the bar): the chest a little back, the upper arms swung
## back and out, the forearms bent forward.
func lean_back_elbows(k: float) -> void:
	if k <= 0.0:
		return
	for side: int in [1, -1]:
		_arm(side, Vector3(-38.0, 0.0, 26.0), Vector3(62.0, 0.0, 0.0), k)
	_tilt(&"chest", 14.0 * k)
	_tilt(&"head", -7.0 * k)


## The head's world position (where a camera or a look aims).
func head_point() -> Vector3:
	return rig.joint(&"head").global_position


## The middle of the hand on `side` (1 right, -1 left), world space.
func hand_point(side: int) -> Vector3:
	var hand: Node3D = rig.joint(&"hand_l" if side < 0 else &"hand_r")
	return hand.global_transform * Vector3(0.0, -0.05, 0.0)


## Sets every joint for a stance or a walk: the pace is smoothed, the phase follows the ground covered.
func _step(moved: float, speed: float, t: float, delta: float) -> void:
	var follow: float = 1.0 - exp(-delta / GAIT_SMOOTH) if _gait >= 0.0 and delta > 0.0 else 1.0
	_gait = lerpf(maxf(_gait, 0.0), speed, follow)
	var stride: float = CinePoses.walk_stride(_gait) * CasinoPeople.stride_scale(look)
	_phase = CinePoses.walk_phase(_phase, moved, stride)
	# The stride in the rig's own units (a rig fitted to a size scales its legs), the planted foot going back under the
	# hip at the body's pace so it stays put on the ground.
	var covering: float = clampf(speed / _gait, 0.0, 1.0) if _gait > 0.001 else 0.0
	CinePoses.walk(_pose, _phase, CinePoses.walk_amount(_gait), t, stride * covering,
		CinePoses.WALK_CYCLE / maxf(rig.scale.z, 0.01), rig.parts.thigh_length, rig.parts.shin_length)
	rig.apply_pose(_pose)
	rig.position = Vector3.ZERO
	rig.update_panels(delta)
	if _glass:
		hold_glass(1.0, -1)


## Adds a tilt of `degrees` about x to a centre joint (+ back), on top of the pose just set.
func _tilt(joint_name: StringName, degrees: float) -> void:
	rig.joint(joint_name).rotate_object_local(Vector3.RIGHT, deg_to_rad(degrees))


## Poses one arm (`side` 1 right, -1 left) in degrees (HumanoidPose's limb convention: +x swings it forward and up, +z
## out to the side), blended over the rig's pose by `k`.
func _arm(side: int, upper: Vector3, fore: Vector3, k: float) -> void:
	var pre: String = "_l" if side < 0 else "_r"
	BeachOutroBar._blend(rig.joint(StringName("upper_arm" + pre)), VolleyballRival._limb(side, upper), k)
	BeachOutroBar._blend(rig.joint(StringName("forearm" + pre)), VolleyballRival._limb(side, fore), k)


## A limb joint's rest position in the chest joint's space (the shoulder, for the upper arm).
func _joint_at(side: int, segment: String) -> Vector3:
	return rig.joint(StringName(segment + ("_l" if side < 0 else "_r"))).position


## Reaches the wrist of the arm on `side` to `wrist` (the chest joint's space, design metres) by `k`: a two-bone solution
## with the elbow bent toward `elbow` (a direction), the forearm bending as an elbow does. With `held` (a direction in the
## chest's space) the hand is rolled so its front (-z) points that way as far as the forearm allows: a glass held
## upright, tipped toward the mouth.
func _reach(side: int, wrist: Vector3, elbow: Vector3, k: float, held: Vector3 = Vector3.ZERO) -> void:
	var pre: String = "_l" if side < 0 else "_r"
	var upper: Node3D = rig.joint(StringName("upper_arm" + pre))
	var fore: Node3D = rig.joint(StringName("forearm" + pre))
	var hand: Node3D = rig.joint(StringName("hand" + pre))
	var l1: float = rig.parts.upper_arm_length
	var l2: float = rig.parts.forearm_length
	var shoulder: Vector3 = upper.position
	var to: Vector3 = wrist - shoulder
	var dist: float = clampf(to.length(), absf(l1 - l2) + 0.005, l1 + l2 - 0.003)
	var dir: Vector3 = to.normalized() if to.length_squared() > 0.000001 else Vector3.DOWN
	# The elbow: where the two bones' circles meet, on the side the hint points to.
	var along: float = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var out: Vector3 = elbow - dir * elbow.dot(dir)
	out = out.normalized() if out.length_squared() > 0.000001 else Vector3.DOWN
	var joint_at: Vector3 = shoulder + dir * along + out * sqrt(maxf(l1 * l1 - along * along, 0.0))
	var u: Vector3 = (joint_at - shoulder).normalized()
	var f: Vector3 = (shoulder + dir * dist - joint_at).normalized()
	# The upper arm turned so the forearm, bending about its own x, reaches: its y along -u, its z away from the bend.
	var ey: Vector3 = -u
	var perp: Vector3 = f - ey * f.dot(ey)
	var bend: float = atan2(perp.length(), f.dot(u))
	var ez: Vector3 = -perp.normalized() if perp.length_squared() > 0.000001 else Vector3.BACK
	var upper_basis := Basis(ey.cross(ez), ey, ez)
	var fore_basis: Basis = upper_basis * Basis(Vector3.RIGHT, bend)
	_slerp(upper, upper_basis.get_rotation_quaternion(), k)
	_slerp(fore, Quaternion(Vector3.RIGHT, bend), k)
	if held != Vector3.ZERO:
		# Roll the hand about the forearm so its front points as near `held` as it can.
		var axis: Vector3 = fore_basis.y
		var want: Vector3 = -(held - axis * held.dot(axis))
		if want.length_squared() > 0.000001:
			want = want.normalized()
			var roll: float = atan2(fore_basis.z.cross(want).dot(axis), fore_basis.z.dot(want))
			_slerp(hand, Quaternion(Vector3.UP, roll), k)


func _slerp(joint: Node3D, to: Quaternion, k: float) -> void:
	joint.quaternion = joint.quaternion.slerp(to, clampf(k, 0.0, 1.0))
