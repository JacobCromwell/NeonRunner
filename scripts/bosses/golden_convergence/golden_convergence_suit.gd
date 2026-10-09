class_name GoldenConvergenceSuit
extends BossPart
## The golden suit (GDD §10: "a giant mechanical construct, a golden exoskeleton that the villain rides
## inside: a gaudy, almost religious relic, but entirely man-made. It floats in the distance ahead of the
## runner. The man inside isn't visible until the second stage"), the fight's body: it shares the fight's
## health, so weapons chip it (up to BossDef.weapon_share_cap), aimed at its chest (aim_point: within the
## best weapons' 70 m at GoldenConvergenceTuning.suit_ahead), and nothing else hurts it until E5d-c's Refill
## Ship. Out of reach: no hitbox, no weak point (yet), nothing to touch.
## Its model (GoldenConvergenceModel, built once and shared) on nodes, one per moving part, which the
## encounter and the later steps drive through these handles:
## - unfurl (0-1): the cape gathered at the shoulders (the entrance) or its whole cloud; the cape billows on
##   its own (golden_convergence_cape.gdshader, never glowing);
## - reel (0-1): it lurches back from a blast (a later phase's intro, GDD §10 proposed);
## - arms (E5d-b, the Fist Slam): set_arm(side, target, blend, extend, fist): the arm on `side` (-1 its right,
##   as the runner sees it on the left; 1 its left) swings from hanging at its side to point at `target`
##   (world space) by `blend`, its golden segments telescoping out of the forearm by `extend` (0-1 nested,
##   up to EXTEND_MAX with the sleeves stretching: the Fist Slam reaches the track from where it floats;
##   extend_for() solves the reach), its hand a fist or open; hand_point(side) is where its hand is;
## - pipes (E5d-b, the Missile Barrage): pipes_open[side] (0-1) swings the hatch over a shoulder's pipes open;
##   pipe_mouth(side) is where missiles leave and the feed line plugs in (E5d-c);
## - damage (E5d-c): set_pipes_broken(side) blows a shoulder's pipes out (torn stubs); burst (0-1, E5d-d)
##   swings the chest's front plates open, the suit bursting;
## - cape_point(i): where drone i of the squadron comes out of and goes back into the cape;
## - head_point(): its face (sounds, the look down the causeway).
## Sizes: GoldenConvergenceModel's at suit_scale. draw_stats() counts what it draws (a budget in the tests).

## Its pieces: the arm's rest pose (hanging at its side a little out and forward), the head's look down the
## causeway, the halo behind the head, the plates' hinges.
const ARM_REST_OUT: float = 0.2
const ARM_REST_FORWARD: float = -0.1
const ELBOW_REST: float = -0.42
const HEAD_LOOK_DOWN: float = 0.2
const HALO_AT := Vector3(0.0, 20.6, -2.8)
const HALO_SPIN: float = 0.05
## The pipes' hatch swings this far open (radians).
const CAP_OPEN: float = 1.9
## E5d-b: how far an arm's segments telescope at most (1: each slid out of the one before, nested; beyond it
## the sleeves stretch with them, so the fist reaches the track from where the suit floats). DESIGN-TBD
## (docs/questions/e5d.md, E5d-b 6: a stretched arm, or the suit leaning in for its slams).
const EXTEND_MAX: float = 2.4
## Where the squadron's drones come out of the cape and go back in (its cloud beside and above the shoulders, in
## the suit's space; cape_point).
const CAPE_POINTS: Array[Vector3] = [Vector3(-24.0, 6.0, -15.0), Vector3(24.0, 6.0, -15.0), Vector3(0.0, 24.0, -16.0)]

var tuning: GoldenConvergenceTuning
var unfurl: float = 1.0
var reel: float = 0.0
var burst: float = 0.0
## Per side, index 0 its right (x < 0), 1 its left (x > 0).
var pipes_open: Array[float] = [0.0, 0.0]
var pipes_broken: Array[bool] = [false, false]
var arm_target: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var arm_blend: Array[float] = [0.0, 0.0]
var arm_extend: Array[float] = [0.0, 0.0]
var fist: Array[bool] = [false, false]

var _root: Node3D
var _head: Node3D
var _halo: Node3D
var _tentacles: Node3D
var _cape: MeshInstance3D
var _cape_material: ShaderMaterial
var _plates: Array[Node3D] = []
## Per side: {shoulder, elbow, segments: Array[Node3D], wrist, hand, fist, pipes, caps: Array[Node3D],
## torn}
var _arms: Array[Dictionary] = []
var _time: float = 0.0


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as GoldenConvergenceTuning
	if tuning == null:
		tuning = GoldenConvergenceTuning.new()
	var encounter_ref: GoldenConvergence = params.get("encounter") as GoldenConvergence
	var material: Material = encounter_ref.solid_material() if encounter_ref != null else GoldenSkin.new().solid_material()
	var low: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var m: Dictionary = GoldenConvergenceModel.meshes(material, low)
	_root = Node3D.new()
	_root.name = "Suit"
	_root.scale = Vector3.ONE * tuning.suit_scale
	add_child(_root)
	MeshBatch.add_instance(_root, m["torso"], "Torso")
	for side: int in [-1, 1]:
		var hinge := Vector3(side * 7.2, GoldenConvergenceModel.CHEST.y, 0.8)
		var pivot := Node3D.new()
		pivot.name = "Plate%s" % ("R" if side < 0 else "L")
		pivot.position = hinge
		_root.add_child(pivot)
		MeshBatch.add_instance(pivot, m["plates_left" if side < 0 else "plates_right"], "Plate", -hinge)
		_plates.append(pivot)
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0, 16.0, 0.0)
	_root.add_child(_head)
	MeshBatch.add_instance(_head, m["head"], "Face", Vector3(0.0, -16.0, 0.0))
	_halo = Node3D.new()
	_halo.name = "Halo"
	_halo.position = HALO_AT
	_root.add_child(_halo)
	MeshBatch.add_instance(_halo, m["halo"], "Rings")
	_tentacles = Node3D.new()
	_tentacles.name = "Tentacles"
	_tentacles.position = Vector3(0.0, -2.0, 0.0)
	_root.add_child(_tentacles)
	MeshBatch.add_instance(_tentacles, m["tentacles"], "Pipes", Vector3(0.0, 2.0, 0.0))
	_cape_material = GoldenConvergenceModel.cape_material()
	_cape = MeshBatch.add_instance(_root, m["cape"], "Cape")
	_cape.material_override = _cape_material
	# The cape's cloud is far bigger than its rest shape's box (it billows): never culled while in view.
	_cape.extra_cull_margin = 16.0
	for side: int in [-1, 1]:
		_arms.append(_build_arm(m, side))


func _build_arm(m: Dictionary, side: int) -> Dictionary:
	var s: Vector3 = GoldenConvergenceModel.SHOULDER
	var shoulder := Node3D.new()
	shoulder.name = "Shoulder%s" % ("R" if side < 0 else "L")
	shoulder.position = Vector3(side * s.x, s.y, s.z)
	_root.add_child(shoulder)
	MeshBatch.add_instance(shoulder, m["upper_arm"], "UpperArm")
	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position = Vector3(0.0, -GoldenConvergenceModel.UPPER_ARM, 0.0)
	shoulder.add_child(elbow)
	MeshBatch.add_instance(elbow, m["forearm"], "Forearm")
	var segments: Array[Node3D] = []
	var sleeves: Array[Node3D] = []
	var parent: Node3D = elbow
	for k: int in GoldenConvergenceModel.SEGMENTS:
		var seg := Node3D.new()
		seg.name = "Segment%d" % k
		parent.add_child(seg)
		var inst: MeshInstance3D = MeshBatch.add_instance(seg, m["segment"], "Sleeve")
		inst.scale = Vector3(1.0 - 0.07 * k, 1.0, 1.0 - 0.07 * k)
		segments.append(seg)
		sleeves.append(inst)
		parent = seg
	var wrist := Node3D.new()
	wrist.name = "Wrist"
	parent.add_child(wrist)
	var hand: MeshInstance3D = MeshBatch.add_instance(wrist, m["hand"], "Hand")
	var fist_mesh: MeshInstance3D = MeshBatch.add_instance(wrist, m["fist"], "Fist")
	fist_mesh.visible = false
	# Its shoulder's pipes, on the pauldron.
	var p: Vector3 = GoldenConvergenceModel.PIPES_AT
	var pipes := Node3D.new()
	pipes.name = "Pipes%s" % ("R" if side < 0 else "L")
	pipes.position = Vector3(side * p.x, p.y, p.z)
	_root.add_child(pipes)
	var cluster: MeshInstance3D = MeshBatch.add_instance(pipes, m["pipes"], "Cluster")
	var torn: MeshInstance3D = MeshBatch.add_instance(pipes, m["pipes_torn"], "Torn")
	torn.visible = false
	# The hatch over the pipes' mouths, hinged at its back edge (GoldenConvergenceModel.hatch_hinge()).
	var hatch := Node3D.new()
	hatch.name = "Hatch"
	hatch.transform = GoldenConvergenceModel.hatch_hinge()
	pipes.add_child(hatch)
	MeshBatch.add_instance(hatch, m["pipe_cap"], "Lid")
	var caps: Array[Node3D] = [hatch]
	return {"shoulder": shoulder, "elbow": elbow, "segments": segments, "sleeves": sleeves, "wrist": wrist, "hand": hand, "fist": fist_mesh,
		"pipes": pipes, "cluster": cluster, "caps": caps, "torn": torn, "side": side}


## Places the suit (its waist) at `xform` (the encounter flies it).
func set_pose(xform: Transform3D) -> void:
	global_transform = xform


func _process(delta: float) -> void:
	# Its look follows the encounter's handles every drawn frame (also while the fight holds for a death).
	_time += delta
	_apply(delta)


func _apply(_delta: float) -> void:
	_cape_material.set_shader_parameter(&"unfurl", clampf(unfurl, 0.0, 1.0))
	_root.rotation = Vector3(-reel * tuning.reel_tilt, 0.0, 0.0)
	_head.rotation = Vector3(HEAD_LOOK_DOWN, 0.0, 0.0)
	_halo.rotation = Vector3(0.0, 0.0, _time * HALO_SPIN)
	_tentacles.rotation = Vector3(0.05 * sin(_time * 0.6), 0.0, 0.04 * sin(_time * 0.45 + 1.0))
	for i: int in _plates.size():
		var side: int = -1 if i == 0 else 1
		_plates[i].rotation = Vector3(0.0, side * 1.25 * clampf(burst, 0.0, 1.0), 0.0)
	for i: int in _arms.size():
		_apply_arm(i)


func _apply_arm(i: int) -> void:
	var arm: Dictionary = _arms[i]
	var side: int = int(arm["side"])
	var shoulder: Node3D = arm["shoulder"]
	var rest := Basis(Vector3.BACK, side * ARM_REST_OUT) * Basis(Vector3.RIGHT, ARM_REST_FORWARD)
	var blend: float = clampf(arm_blend[i], 0.0, 1.0)
	var basis: Basis = rest
	if blend > 0.0:
		# Pointing at its target (world space): the arm's -y toward it, from the shoulder.
		var local: Vector3 = (_root.global_transform.affine_inverse() * arm_target[i]) - shoulder.position
		if local.length_squared() > 0.01:
			var aim := Basis(Quaternion(Vector3.DOWN, local.normalized()))
			basis = Basis(rest.get_rotation_quaternion().slerp(aim.get_rotation_quaternion(), blend))
	shoulder.basis = basis
	(arm["elbow"] as Node3D).rotation = Vector3(ELBOW_REST * (1.0 - blend), 0.0, 0.0)
	var extend: float = clampf(arm_extend[i], 0.0, EXTEND_MAX)
	# E5d-b: past a full telescope (the Fist Slam's long reach) each sleeve stretches back up into the one
	# before it, so the arm stays whole however far it reaches.
	var stretch: float = maxf(extend, 1.0)
	var segments: Array = arm["segments"]
	var seg_len: float = GoldenConvergenceModel.SEGMENT
	for k: int in segments.size():
		var seg: Node3D = segments[k]
		# Nested in the forearm at rest (each ending at its cuff), each sliding out of the one before.
		var start: float = -(GoldenConvergenceModel.FOREARM - seg_len) if k == 0 else 0.0
		seg.position = Vector3(0.0, start - extend * seg_len * 0.92, 0.0)
		# Its sleeve only while out (the wrist and hand hang from the last segment, always shown).
		var sleeve: Node3D = arm["sleeves"][k]
		sleeve.visible = extend > 0.001
		sleeve.scale.y = stretch
		sleeve.position.y = (stretch - 1.0) * seg_len
	(arm["wrist"] as Node3D).position = Vector3(0.0, -seg_len, 0.0)
	(arm["hand"] as Node3D).visible = not fist[i]
	(arm["fist"] as Node3D).visible = fist[i]
	var open: float = clampf(pipes_open[i], 0.0, 1.0)
	var hinge: Transform3D = GoldenConvergenceModel.hatch_hinge()
	for cap: Node3D in arm["caps"]:
		cap.transform = Transform3D(hinge.basis * Basis(Vector3.RIGHT, open * CAP_OPEN), hinge.origin)
	var broken: bool = pipes_broken[i]
	(arm["cluster"] as Node3D).visible = not broken
	(arm["torn"] as Node3D).visible = broken
	for cap: Node3D in arm["caps"]:
		cap.visible = not broken


## The arm on `side` (-1 its right, 1 its left): pointing at `target` (world space) by `blend` (0 hanging at
## its side), its segments telescoped out by `extend` (0-1), its hand a fist or open (E5d-b's Fist Slam).
func set_arm(side: int, target: Vector3, blend: float, extend: float, as_fist: bool) -> void:
	var i: int = 0 if side < 0 else 1
	arm_target[i] = target
	arm_blend[i] = blend
	arm_extend[i] = extend
	fist[i] = as_fist


## E5d-b (the Fist Slam): the extend that brings the hand on `side` (its fist's middle, hand_point) to `target`
## (world space) with the arm pointing straight at it (set_arm's blend 1), at most EXTEND_MAX; with the suit
## placed at `pose` (a Transform3D: where the encounter puts it this frame, GoldenConvergence.suit_transform)
## or where it is now.
func extend_for(side: int, target: Vector3, pose: Variant = null) -> float:
	var shoulder: Node3D = _arms[0 if side < 0 else 1]["shoulder"]
	var root: Transform3D = (pose as Transform3D) * _root.transform if pose is Transform3D else _root.global_transform
	var reach: float = (root.affine_inverse() * target - shoulder.position).length()
	# Shoulder to hand point: the upper arm, the forearm's lip past the first segment, five slides, the last
	# sleeve and the wrist to the fist's middle.
	var fixed: float = GoldenConvergenceModel.UPPER_ARM + (GoldenConvergenceModel.FOREARM - GoldenConvergenceModel.SEGMENT) \
		+ GoldenConvergenceModel.SEGMENT + 2.0
	var per: float = GoldenConvergenceModel.SEGMENTS * GoldenConvergenceModel.SEGMENT * 0.92
	return clampf((reach - fixed) / per, 0.0, EXTEND_MAX)


## Blows a shoulder's pipes out (E5d-c: "the first blows out one shoulder's pipes, the second the other's").
func set_pipes_broken(side: int, broken: bool = true) -> void:
	pipes_broken[0 if side < 0 else 1] = broken


## Where its hand on `side` is (world space).
func hand_point(side: int) -> Vector3:
	var wrist: Node3D = _arms[0 if side < 0 else 1]["wrist"]
	return wrist.global_transform * Vector3(0.0, -2.0, 0.0)


## The middle of a shoulder's pipe mouths (world space): where missiles leave, where the feed line plugs in.
func pipe_mouth(side: int) -> Vector3:
	var pipes: Node3D = _arms[0 if side < 0 else 1]["pipes"]
	return pipes.global_transform * (GoldenConvergenceModel.pipe_axis() * GoldenConvergenceModel.PIPE_LENGTH)


## Its face's middle (world space).
func head_point() -> Vector3:
	return _root.global_transform * GoldenConvergenceModel.HEAD


## Where drone `i` of the squadron comes out of (and goes back into) the cape: in its cloud beside and above
## the shoulders (world space).
func cape_point(i: int) -> Vector3:
	return _root.global_transform * CAPE_POINTS[i % CAPE_POINTS.size()]


## Weapons aim at its chest (within the best weapons' reach at its distance).
func aim_point() -> Vector3:
	var c: Vector3 = GoldenConvergenceModel.CHEST
	return _root.global_transform * Vector3(0.0, c.y, GoldenConvergenceModel.chest_z(0.0, c.y))


func hit_radius() -> float:
	return 6.0 * tuning.suit_scale


## The cape's shader material (tests: it never glows).
func cape_material() -> ShaderMaterial:
	return _cape_material


## What it draws: {instances, surfaces, vertices}.
func draw_stats() -> Dictionary:
	var instances: int = 0
	var surfaces: int = 0
	var vertices: int = 0
	for node: Node in _root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		instances += 1
		for s: int in mi.mesh.get_surface_count():
			surfaces += 1
			vertices += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return {"instances": instances, "surfaces": surfaces, "vertices": vertices}


## Every mesh it shows (tests: the colour rule).
func meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node: Node in _root.find_children("*", "MeshInstance3D", true, false):
		out.append(node as MeshInstance3D)
	return out


## Never defeated but by the fight's end; then it stays where it is (E5d-d plays the defeat).
func _on_defeated(_cause: StringName) -> void:
	pass
