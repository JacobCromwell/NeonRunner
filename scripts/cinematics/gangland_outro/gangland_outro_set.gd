class_name GanglandOutroSet
extends Node3D
## The props of the Gangland outro's first scene (GanglandOutro), built on its stage (so they hide with it) and
## moved by the cinematic's clock (update): everything is worked out from the time, so stepping or skipping it
## shows the same. Visual only: no hitboxes.
## - The rubble: broken slabs, chunks of concrete and asphalt, bricks and rebar heaped behind the Host and strewn
##   round them, in the street's own kit material (MeshKit.solid), so a level's light reaches it. One draw call.
## - The Host, freed (GDD §10: "the screeches scatter, the implants short out, and the person slumps free"): the
##   fight's person (SwarmHostPerson on the humanoid rig), their implants dimmed, lying back against the heap.
##   They breathe and tremble, look up at the runner, hold the key up to them with a shaking hand, and sink back.
## - The screeches sniffing at the Host (the sewer screech's own body, ScreechModel, as in play): noses down,
##   shuffling; they look up at the runner coming, bristle, and scuttle away into the gutters.
## The key (GanglandOutro.key) is the cinematic's own, since it goes on into the second scene.

## Where the screeches sniff (from the Host's middle, track space) and which way each scuttles off (degrees
## from straight down the street, + to the right): away from the runner coming up the street, and clear of the
## first shot's camera.
const SNIFF_SPOTS: Array[Vector3] = [Vector3(-0.95, 0.0, -0.35), Vector3(0.45, 0.0, -1.25), Vector3(-0.45, 0.0, -1.2),
	Vector3(-1.25, 0.0, 0.45), Vector3(0.9, 0.0, -0.6), Vector3(-1.5, 0.0, -0.9), Vector3(0.1, 0.0, -1.8),
	Vector3(1.1, 0.0, 0.3)]
const FLEE_DEGREES: Array[float] = [-95.0, 25.0, -55.0, -120.0, 105.0, -80.0, 40.0, 130.0]
## A screech sniffs this fast (cycles a second), its nose dipping this far (radians).
const SNIFF_RATE: float = 1.7
const SNIFF_DIP: float = 0.22
## Seconds a screech takes to reach its full scuttle, how far from a wall's face it drops into the gutter, and
## how far down.
const SCUTTLE_RAMP: float = 0.35
const GUTTER_IN: float = 0.3
const GUTTER_DROP: float = 0.6
## The Host's rig is built at the humanoid rig's design height.
const RIG_HEIGHT: float = 1.3
## The rubble's colours (sRGB): concrete, darker concrete, asphalt, brick, rebar.
const RUBBLE_COLORS: Array[Color] = [Color(0.36, 0.34, 0.3), Color(0.27, 0.25, 0.23), Color(0.15, 0.14, 0.13),
	Color(0.4, 0.22, 0.15), Color(0.31, 0.29, 0.26)]
const REBAR := Color(0.2, 0.13, 0.09)
## The key: gold, and the glint's warm white.
const GOLD := Color(1.0, 0.76, 0.3)
const KEY_GLOW: float = 0.3
const GLINT := Color(1.0, 0.9, 0.6)

var outro: GanglandOutro
var n: GanglandOutroTuning
## The Host's middle (track space), the rubble, the Host's rig and the screeches.
var host_point := Vector3.ZERO
var rubble: MeshInstance3D
var host: HumanoidRig
var screeches: Array[MeshInstance3D] = []
## Where each screech is now (track space) and whether it shows (tests).
var screech_positions := PackedVector3Array()
var screech_shown := PackedByteArray()
## How far the Host is holding the key up (0-1) and their tremble now (degrees).
var offering: float = 0.0
var trembling: float = 0.0

var _pose := HumanoidPose.new()


func setup(p_outro: GanglandOutro) -> void:
	outro = p_outro
	n = outro.n
	name = "Rubble"
	host_point = Vector3(n.host_x, 0.0, n.host_at)
	rubble = MeshBatch.add_instance(self, rubble_mesh(n, outro.stage.wall_x(-1), outro.stage.wall_x(1)), "Heap")
	rubble.position = outro.stage.point(host_point)
	_build_host()
	_build_screeches()


func _build_host() -> void:
	var look := SwarmHostPerson.material().duplicate() as ShaderMaterial
	look.set_shader_parameter(&"glow_energy", n.host_glow)
	host = HumanoidRig.new()
	host.name = "Host"
	add_child(host)
	host.build(SwarmHostPerson.parts(), look)
	host.scale = Vector3.ONE * (n.host_height / RIG_HEIGHT)
	host.position = outro.stage.point(host_point)
	# Facing back up the street, toward the runner coming (the rig faces -z; the street runs along world -z).
	host.rotation.y = PI
	update_host(0.0)


func _build_screeches() -> void:
	var variant: StringName = outro.stage.skin.enemy_variant
	var count: int = mini(n.sniffers, SNIFF_SPOTS.size())
	screech_positions.resize(count)
	screech_shown.resize(count)
	for i: int in count:
		var s := MeshInstance3D.new()
		s.name = "Screech%d" % i
		s.mesh = ScreechModel.mesh()
		s.material_override = ScreechModel.material(variant)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.set_instance_shader_parameter(&"seed", float(i) * 3.7)
		add_child(s)
		screeches.append(s)
	update_screeches(0.0)


## Everything at time `t`.
func update(t: float) -> void:
	update_host(t)
	update_screeches(t)


# --- The Host -------------------------------------------------------------------------------------

## The Host's pose at `t`: lying back against the heap, breathing; trembling; looking up at the runner; holding
## the key up to them; sinking back once it's taken.
func update_host(t: float) -> void:
	var take: float = n.reach_at + n.reach_seconds
	var up: float = smoothstep(n.offer_at, n.offer_at + n.offer_seconds, t)
	var down: float = smoothstep(take + 0.15, take + 0.15 + n.sink_seconds, t)
	offering = up * (1.0 - down)
	var looking: float = smoothstep(n.host_looks_at, n.host_looks_at + 0.8, t) * (1.0 - 0.6 * down)
	trembling = n.tremble + (n.tremble_offering - n.tremble) * offering
	var p: HumanoidPose = _pose
	p.reset()
	var breath: float = sin(TAU * 0.32 * t)
	# Lying back against the heap, a little to one side, slumped; sitting up a little to hold the key out.
	p.root_rot = Vector3(deg_to_rad(lerpf(50.0, 30.0, offering)), 0.0, deg_to_rad(-5.0))
	p.set_deg(HumanoidPose.CHEST, Vector3(-14.0 + 2.5 * breath - 16.0 * offering, -10.0 * offering, 3.0))
	p.set_deg(HumanoidPose.NECK, Vector3(-8.0, 0.0, 0.0))
	# Their head hangs to one side; it lifts and turns to the runner (on their right) as they look up.
	p.set_deg(HumanoidPose.HEAD, Vector3(lerpf(-26.0, 6.0, looking), lerpf(10.0, -18.0, looking),
		lerpf(12.0, 2.0, looking)))
	# One leg out straight, the other knee up.
	p.set_limb(HumanoidPose.THIGH_R, 1, Vector3(52.0, 0.0, 8.0))
	p.set_limb(HumanoidPose.SHIN_R, 1, Vector3(-6.0, 0.0, 0.0))
	p.set_limb(HumanoidPose.THIGH_R, -1, Vector3(80.0, 0.0, 14.0))
	p.set_limb(HumanoidPose.SHIN_R, -1, Vector3(-74.0, 0.0, 0.0))
	# The left arm limp on the rubble; the right in their lap, then held up to the runner.
	p.set_limb(HumanoidPose.UPPER_ARM_R, -1, Vector3(14.0, 0.0, 26.0))
	p.set_limb(HumanoidPose.FOREARM_R, -1, Vector3(22.0, 0.0, 0.0))
	p.set_limb(HumanoidPose.UPPER_ARM_R, 1, Vector3(lerpf(22.0, 78.0, offering), lerpf(0.0, -12.0, offering),
		lerpf(14.0, 18.0, offering)))
	p.set_limb(HumanoidPose.FOREARM_R, 1, Vector3(lerpf(48.0, 12.0, offering), 0.0, 0.0))
	p.set_limb(HumanoidPose.HAND_R, 1, Vector3(lerpf(0.0, -20.0, offering), 0.0, 0.0))
	_tremble(p, t)
	p.ground = 1.0
	host.apply_pose(p)
	# The hand held out to where the key changes hands, shaking.
	if offering > 0.0:
		GanglandOutro.aim_arm(host, &"r", outro.stage.point(host_point + n.handoff_point), offering)
		var a: float = deg_to_rad(trembling) * offering
		var shake: float = sin(TAU * 13.0 * t) * 0.6 + sin(TAU * 22.0 * t + 1.3) * 0.4
		host.joint(&"upper_arm_r").rotate_object_local(Vector3.RIGHT, a * shake)
		host.joint(&"hand_r").rotate_object_local(Vector3.FORWARD, a * 1.4 * sin(TAU * 17.0 * t + 0.6))


## A fast, uneven tremble through the Host's body, strongest in the arm they hold up.
func _tremble(p: HumanoidPose, t: float) -> void:
	var a: float = trembling
	var shake := func(rate: float, phase: float) -> float:
		return sin(TAU * rate * t + phase) * 0.6 + sin(TAU * rate * 1.73 * t + phase * 2.1) * 0.4
	p.add_deg(HumanoidPose.CHEST, Vector3(a * 0.35 * shake.call(9.0, 0.3), 0.0, a * 0.3 * shake.call(11.0, 1.2)))
	p.add_deg(HumanoidPose.HEAD, Vector3(a * 0.5 * shake.call(12.5, 2.0), 0.0, a * 0.4 * shake.call(8.5, 0.7)))
	p.add_limb(HumanoidPose.UPPER_ARM_R, 1, Vector3(a * shake.call(13.0, 0.9), 0.0, a * 0.7 * shake.call(10.0, 2.4)))
	p.add_limb(HumanoidPose.FOREARM_R, 1, Vector3(a * 0.8 * shake.call(15.0, 1.7), 0.0, 0.0))
	p.add_limb(HumanoidPose.HAND_R, 1, Vector3(a * shake.call(17.0, 0.4), 0.0, a * 0.6 * shake.call(14.0, 2.9)))


## The Host's right hand (the one that holds the key), world space.
func host_hand() -> Node3D:
	return host.joint(&"hand_r")


# --- The screeches ------------------------------------------------------------------------------------

## The screeches at `t`: sniffing round the Host, nose down; looking up at the runner, bristling; scuttling
## away, dropping into the gutter at the wall (or out of sight down the street).
func update_screeches(t: float) -> void:
	var runner := outro.runner_track(t)
	for i: int in screeches.size():
		var s: MeshInstance3D = screeches[i]
		var home: Vector3 = host_point + SNIFF_SPOTS[i]
		var scale_k: float = n.sniffer_scale * (0.92 + 0.16 * fposmod(float(i) * 0.618, 1.0))
		var start: float = n.scuttle_at + 0.09 * float(i)
		var alert: float = smoothstep(n.look_up_at + 0.05 * i, n.look_up_at + 0.05 * i + 0.25, t)
		var pos: Vector3 = home
		var yaw: float
		var pitch: float
		var shown: bool = true
		if t < start:
			# Facing the Host's middle, nose dipping and lifting, shuffling a little.
			var to_host: Vector3 = host_point + Vector3(0.0, 0.0, 0.15) - home
			var sniff_yaw: float = atan2(to_host.x, to_host.z)
			var to_runner: Vector3 = runner - home
			var runner_yaw: float = atan2(to_runner.x, to_runner.z)
			yaw = lerp_angle(sniff_yaw, runner_yaw, alert * 0.7)
			var dip: float = 0.5 + 0.5 * sin(TAU * SNIFF_RATE * t + float(i) * 1.9)
			pitch = lerpf(-SNIFF_DIP * dip - 0.08, 0.14, alert)
			pos += Vector3(sin(yaw), 0.0, cos(yaw)) * 0.05 * sin(TAU * 0.6 * t + float(i))
			s.set_instance_shader_parameter(&"scurry", lerpf(0.12, 0.3, alert))
			s.set_instance_shader_parameter(&"bristle", lerpf(0.15, 1.0, alert))
		else:
			# Away, speeding up to its scuttle, bobbing; into the gutter at the wall.
			var e: float = t - start
			var run: float = n.scuttle_speed * (e - SCUTTLE_RAMP * 0.5) if e > SCUTTLE_RAMP \
				else n.scuttle_speed * e * e / (2.0 * SCUTTLE_RAMP)
			yaw = deg_to_rad(FLEE_DEGREES[i])
			var dir := Vector3(sin(yaw), 0.0, cos(yaw))
			var dist: float = run
			var limit: float = n.scuttle_distance
			if absf(dir.x) > 0.01:
				# As far as the wall it's heading for: into the gutter at its foot.
				var gutter: float = outro.stage.wall_x(int(signf(dir.x))) - signf(dir.x) * GUTTER_IN
				limit = minf(limit, (gutter - home.x) / dir.x)
			limit = maxf(limit, 0.5)
			pos = home + dir * minf(dist, limit)
			pos.y = 0.05 * absf(sin(TAU * 4.0 * e))
			if dist > limit:
				pos.y -= GUTTER_DROP * clampf((dist - limit) / 0.6, 0.0, 1.0)
			shown = dist < limit + 0.6
			pitch = -0.05
			s.set_instance_shader_parameter(&"scurry", 1.0)
			s.set_instance_shader_parameter(&"bristle", 1.0)
		s.visible = shown
		# The body faces -z; heading `yaw` (0 down the street) is world -z turned by -yaw.
		var basis := Basis(Vector3.UP, -yaw) * Basis(Vector3.RIGHT, pitch) * Basis.from_scale(Vector3.ONE * scale_k)
		s.global_transform = Transform3D(basis, outro.stage.point(pos))
		screech_positions[i] = pos
		screech_shown[i] = 1 if shown else 0


# --- Meshes ------------------------------------------------------------------------------------------

## The rubble round the Host's middle (its origin): the heap they lie back against (behind them, further down
## the street) and pieces strewn round, clear of where the runner walks up and stands. Within the walls
## (`left`, `right`: their x, from the Host's).
static func rubble_mesh(t: GanglandOutroTuning, left: float, right: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(MeshKit.solid({"glow_scale": 4.0}))
	var seed: int = 4021
	var placed: int = 0
	var tries: int = 0
	# The heap: big slabs leaning in against each other behind them, the tallest in the middle.
	for k: int in 7:
		var h01: float = MeshKit.hash01(seed, k, 1)
		var across: float = (float(k) - 3.0) * 0.42
		var size := Vector3(0.6 + 0.4 * h01, 0.1 + 0.08 * MeshKit.hash01(seed, k, 2),
			0.5 + 0.35 * MeshKit.hash01(seed, k, 3))
		var lean: float = deg_to_rad(28.0 + 30.0 * MeshKit.hash01(seed, k, 4)) * (1.0 - absf(across) * 0.3)
		var basis := Basis(Vector3.UP, deg_to_rad(-25.0 + 50.0 * MeshKit.hash01(seed, k, 5))) * Basis(Vector3.RIGHT, -lean)
		var at := Vector3(across, t.heap_height * (0.55 - 0.12 * absf(across)), -(0.95 + 0.25 * MeshKit.hash01(seed, k, 6)))
		m.box_xform(Transform3D(basis * Basis.from_scale(size), at), RUBBLE_COLORS[k % 2], 0.0, MeshKit.PAT_CONCRETE)
		if k % 3 == 1:
			# Rebar out of a broken edge.
			var bar_basis: Basis = basis * Basis(Vector3.FORWARD, deg_to_rad(20.0 * (k - 3))) \
				* Basis.from_scale(Vector3(0.025, 0.65, 0.025))
			var bar := Transform3D(bar_basis, at + basis * Vector3(0.0, 0.3, 0.2))
			m.box_xform(bar, REBAR)
	# Chunks under and round the heap.
	for k: int in 6:
		var at := Vector3((float(k) - 2.5) * 0.5, 0.12, -(1.5 + 0.4 * MeshKit.hash01(seed, k, 9)))
		_chunk(m, at, 0.35 + 0.25 * MeshKit.hash01(seed, k, 10), seed + k * 7)
	# Pieces strewn round, smaller further out, clear of the runner's way up (in front of the Host and to their
	# right, where the runner stands) and inside the walls.
	while placed < t.rubble_pieces and tries < t.rubble_pieces * 10:
		tries += 1
		var a: float = TAU * MeshKit.hash01(seed, tries, 11)
		var r: float = 0.7 + (t.rubble_spread - 0.7) * sqrt(MeshKit.hash01(seed, tries, 12))
		var at := Vector3(sin(a) * r, 0.0, -cos(a) * r)
		# Clear of the runner's way up and where they stand (track z runs against the mesh's z).
		var stand := Vector2(t.stop_offset.x, -t.stop_offset.z)
		var lane_clear: bool = at.z > stand.y - 0.5 and at.x > stand.x - 0.6 and at.x < stand.x + 0.45
		# Clear of the first shot's camera too (track z runs against the mesh's z).
		var cam := Vector2(t.rubble_cam.x, -t.rubble_cam.z)
		var cam_end := Vector2(t.rubble_cam_end.x, -t.rubble_cam_end.z)
		var near_cam: bool = Geometry2D.get_closest_point_to_segment(Vector2(at.x, at.z), cam, cam_end).distance_to(
			Vector2(at.x, at.z)) < 1.1
		if lane_clear or near_cam or at.x < left - t.host_x + 0.5 or at.x > right - t.host_x - 0.5:
			continue
		var size: float = lerpf(0.32, 0.12, (r - 0.7) / maxf(t.rubble_spread - 0.7, 0.1)) \
			* (0.7 + 0.6 * MeshKit.hash01(seed, tries, 13))
		at.y = size * 0.35
		_chunk(m, at, size, seed + tries * 13)
		placed += 1
	return batch.to_mesh()


## A chunk of rubble: a tumbled box of concrete, asphalt or brick.
static func _chunk(m: MeshLayer, at: Vector3, size: float, s: int) -> void:
	var basis := Basis.from_euler(Vector3(MeshKit.hash01(s, 1) * 0.9 - 0.45, MeshKit.hash01(s, 2) * TAU,
		MeshKit.hash01(s, 3) * 0.9 - 0.45))
	var dims := Vector3(size * (0.8 + 0.6 * MeshKit.hash01(s, 4)), size * (0.5 + 0.4 * MeshKit.hash01(s, 5)),
		size * (0.7 + 0.6 * MeshKit.hash01(s, 6)))
	var color: Color = RUBBLE_COLORS[MeshKit.hash_i(s, 7) % RUBBLE_COLORS.size()]
	m.box_xform(Transform3D(basis * Basis.from_scale(dims), at), color, 0.0, MeshKit.PAT_CONCRETE if size > 0.25 else 0)


## The golden key (along -z from its bow, `length` long): an ornate bow (a ring of facets round a hole), a
## shaft and its teeth, glowing gold (so it reads as gold, small as it is, in the street's dim red light).
static func key_mesh(length: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(null)
	var bow: float = length * 0.22
	var thick: float = length * 0.06
	for k: int in 8:
		var a: float = TAU * k / 8.0
		var piece := Transform3D(Basis(Vector3.UP, a) * Basis.from_scale(Vector3(bow * 0.85, thick, thick * 1.4)),
			Vector3(sin(a) * bow, 0.0, cos(a) * bow))
		m.box_xform(piece, GOLD, KEY_GLOW)
	m.box(Vector3(0.0, 0.0, -bow - length * 0.32), Vector3(thick * 1.2, thick, length * 0.62), GOLD, KEY_GLOW)
	m.box(Vector3(thick * 1.3, 0.0, -length * 0.88), Vector3(thick * 1.6, thick, thick * 1.4), GOLD, KEY_GLOW * 0.8)
	m.box(Vector3(thick * 1.1, 0.0, -length * 0.74), Vector3(thick * 1.2, thick, thick * 1.1), GOLD, KEY_GLOW * 0.8)
	# A jewel in the bow's middle, glowing faintly.
	m.box(Vector3.ZERO, Vector3(bow * 0.6, thick * 0.8, bow * 0.6), Color(1.0, 0.85, 0.45), 0.6, SportsCarModel.PAINT)
	return batch.to_mesh()


## The key's glint: a soft round halo (MeshKit's glow material, faded in and out by the cinematic).
static func glint_mesh(size: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var g: MeshLayer = batch.layer(null)
	g.rect(Vector3(-size * 0.5, -size * 0.5, 0.0), Vector3(size, 0.0, 0.0), Vector3(0.0, size, 0.0), GLINT, 1.0,
		MeshKit.SHAPE_RADIAL)
	return batch.to_mesh()
