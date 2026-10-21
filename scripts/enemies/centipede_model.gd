class_name CentipedeModel
extends Node3D
## The Cybernetic Centipede's look (task O3; GDD §9.15 and the owner's reference image docs/art/reference/centipede.jpg:
## "a long, segmented body of riveted brass and steel bands, many sharp jointed steel legs, a welder-mask head with
## hooked mandibles and glowing green lenses, and green glass tubes and canisters of glowing fluid on its back, trailing
## a little steam"), low-poly and cheap to draw:
## - the body: SEGMENTS shells (a brass drum with a steel band and rivets at its front, a dark belly), one multimesh, the
##   last few tapering to the tail, its sting;
## - its legs: a pair to a segment, sharp jointed steel, one multimesh, animated in code (a wave of steps down the body as
##   it runs, folded while it waits);
## - green glass on every other segment: a canister of glowing fluid with a dark cap, one multimesh, and a little steam
##   from the last one;
## - its head: a welder's mask of dark steel plates with a visor slot, two big round lenses glowing green in brass rims, a
##   brass dome behind with cables, feelers, and two hooked mandibles that swing open; a red glow inside its jaws while
##   they stand open (its bite's warning, with the head rearing; the hazard red of every zone's attack warnings);
## - wounded (a dash's first): one canister cracked, its glow out, leaking green, and sparks (none with Reduced flashing).
## The glass, the lenses and the maw are the only parts that glow, in hazard colours (green as drawn, the colour rule's
## hazard green; red in its open jaws); the rest is matte metal. About ten draw calls and 5,000 triangles. Built once per
## look (static caches) and shared. The parts are posed in world space by Centipede (pose()), the model a child of the
## centipede's node at its head. DESIGN-TBD (docs/questions/o3.md): the look.

## The body's colours (vertex colours under one matte metal material).
const BRASS := Color(0.6, 0.43, 0.19)
const STEEL := Color(0.58, 0.6, 0.62)
const DARK := Color(0.11, 0.1, 0.09)
const RUST := Color(0.42, 0.25, 0.13)
## The glowing glass and lenses (GDD §9.15: green as drawn; a hazard colour), and its open jaws' warning glow.
const GLOW := Color(0.35, 1.0, 0.3)
const MAW := Color(1.0, 0.14, 0.07)
## A segment's drum: width, height, length (metres), and its middle's height above the floor.
const SHELL := Vector3(0.8, 0.7, 0.6)
const SHELL_Y: float = 0.52
## Segments from the tail that taper (each smaller), and the tail's own scale.
const TAPER: int = 3
const TAIL_SCALE: float = 0.55
## A leg's reach out from the body's side and its stride (radians either way).
const LEG_REACH: float = 0.95
const STRIDE: float = 0.42
## Steps a metre of travel (the gait's pace).
const STEPS_PER_METRE: float = 1.6
## How high its head rears for a bite (metres) and how far it tips back (radians), and its mandibles' swing open. Its
## first REAR_SEGMENTS segments lift with it, a ramp up to its neck (a centipede rearing its front).
const REAR_HEIGHT: float = 0.8
const REAR_PITCH: float = 0.55
const REAR_SEGMENTS: int = 2
const JAW_OPEN: float = 0.95
const JAW_CLOSED: float = 0.12
## The head's size against its meshes' (GDD §9.15's reference: its head is bigger than its body is round).
const HEAD_SCALE: float = 1.3
## Its face tips up this much (radians), toward the camera above, and its right mandible's hinge (head frame; the left's is
## mirrored), under its mask.
const FACE_TILT: float = 0.2
const JAW_HINGE := Vector3(0.16, -0.04, -0.34)
## Where its right lens sits (head frame; the left's is mirrored) and its size across (metres, before HEAD_SCALE).
const LENS := Vector3(0.27, 0.27, -0.33)
const LENS_SIZE: float = 0.25
## How far the parts may stray from the head (metres): the multimeshes' bounds.
const BOUNDS: float = 9.0

## Meshes and materials per look, built once: {shell, leg, canister, head, lenses, mandible, maw, cracked}.
static var _meshes: Dictionary = {}
static var _body_material: StandardMaterial3D
static var _jaw_material: StandardMaterial3D
static var _leg_material: StandardMaterial3D
static var _steam_material: StandardMaterial3D
static var _prims: Dictionary = {}

var segments: int = 9
var awake: bool = false
var wounded: bool = false
var _shells: MultiMeshInstance3D
var _legs: MultiMeshInstance3D
var _glass: MultiMeshInstance3D
var _head: Node3D
var _head_mesh: MeshInstance3D
var _lenses: MeshInstance3D
var _jaws: Array[Node3D] = []
var _maw: MeshInstance3D
var _crack: MeshInstance3D
var _leak: CPUParticles3D
var _sparks: CPUParticles3D
var _steam: CPUParticles3D
var _lens_rest: Material
var _lens_awake: Material
var _lens_flare: Material
## The segment the cracked canister stands on.
var _crack_at: int = 3
## Every part shown (warm-up), and sparks kept off (Reduced flashing).
var _all_parts: bool = false
var _sparks_off: bool = false


## Builds the look for a zone's enemy variant (ZoneSkin.enemy_variant: the weathered looks rust it a little more) with
## `p_segments` segments. `all_parts` shows every part it may show (the crack, the leak, the sparks: EnemyDirector's
## warm-up builds every shader it will need).
func build(variant: StringName, p_segments: int, all_parts: bool = false) -> void:
	segments = maxi(p_segments, 2)
	_crack_at = clampi(3, 1, segments - 1)
	var m: Dictionary = meshes_for(variant)
	_shells = _multimesh(m["shell"], segments, "shells")
	_legs = _multimesh(m["leg"], segments * 2, "legs")
	_glass = _multimesh(m["canister"], _glass_count(), "glass")
	_head = Node3D.new()
	_head.name = "Head"
	add_child(_head)
	_head_mesh = _part(_head, m["head"], "head")
	_lenses = _part(_head, m["lenses"], "lenses")
	_lens_rest = GreyboxMaterials.glow(GLOW, 1.8)
	_lens_awake = GreyboxMaterials.glow(GLOW, 3.2)
	_lens_flare = GreyboxMaterials.glow(Color(0.7, 1.0, 0.6), 5.5)
	_lenses.material_override = _lens_rest
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = JAW_HINGE * Vector3(side, 1.0, 1.0)
		_head.add_child(pivot)
		var jaw: MeshInstance3D = _part(pivot, m["mandible"], "mandible")
		jaw.scale = Vector3(side, 1.0, 1.0)
		_jaws.append(pivot)
	_maw = _part(_head, m["maw"], "maw")
	_maw.visible = false
	_crack = _part(self, m["cracked"], "cracked glass")
	_crack.visible = all_parts
	_leak = _particles(GLOW, 0.07, 0.7, 18, Vector3(0.0, 1.0, 0.0), 2.2, -9.0)
	_leak.spread = 50.0
	_sparks = _particles(Color(1.0, 0.85, 0.5), 0.035, 0.35, 14, Vector3(0.0, 1.0, 0.0), 3.0, -6.0)
	_steam = _particles(Color(0.75, 0.75, 0.72, 0.5), 0.16, 1.4, 6, Vector3(0.0, 1.0, 0.2), 0.5, 0.5)
	_all_parts = all_parts
	_start_particles()


func _ready() -> void:
	_start_particles()


## Particles start once the model is built and in the tree (they need its transform).
func _start_particles() -> void:
	if _leak == null or not is_inside_tree():
		return
	_leak.emitting = _all_parts or wounded
	_sparks.emitting = _all_parts or (wounded and not _sparks_off)
	_steam.emitting = true


func _glass_count() -> int:
	return (segments + 1) / 2


## Every other segment, from the first, carries a canister.
func _carries_glass(i: int) -> bool:
	return i % 2 == 0 and i < segments - 1


func _multimesh(mesh: Mesh, count: int, part_name: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var mi := MultiMeshInstance3D.new()
	mi.name = part_name
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-BOUNDS, -1.0, -BOUNDS), Vector3(BOUNDS * 2.0, 5.0, BOUNDS * 2.0))
	add_child(mi)
	return mi


func _part(parent: Node3D, mesh: Mesh, part_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Particles in `color`: glowing quads (the leak and sparks), or with a see-through colour, puffs of steam that swell and
## fade as they rise; `gravity` pulls them up or down (m/s²).
func _particles(color: Color, size: float, lifetime: float, amount: int, direction: Vector3, speed: float,
		gravity: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	if color.a >= 0.99:
		var quad := QuadMesh.new()
		quad.size = Vector2(size, size)
		p.mesh = quad
		p.material_override = GreyboxMaterials.glow(color, 2.0)
	else:
		var puff := SphereMesh.new()
		puff.radius = size * 0.5
		puff.height = size
		puff.radial_segments = 6
		puff.rings = 3
		p.mesh = puff
		p.material_override = steam_material()
		var swell := Curve.new()
		swell.add_point(Vector2(0.0, 0.5))
		swell.add_point(Vector2(1.0, 1.6))
		p.scale_amount_curve = swell
		var fade := Gradient.new()
		fade.set_color(0, Color(1.0, 1.0, 1.0, 0.8))
		fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		p.color_ramp = fade
	p.amount = amount
	p.lifetime = lifetime
	p.direction = direction
	p.spread = 25.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, gravity, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.particle_flag_align_y = false
	p.local_coords = false
	p.emitting = false
	add_child(p)
	return p


## Poses the whole body: its head at world `head_xform` (its origin on the floor under the head's middle, -z where it
## looks), its segments at `segment_xforms` (each on the floor under its middle, -z toward the head), its legs stepping by
## how far it has gone (`gait`, metres) at `moving` (0 still, 1 its full speed), its head rearing by `rear` (0–1) with its
## jaws `open` (0–1).
func pose(head_xform: Transform3D, segment_xforms: Array[Transform3D], gait: float, moving: float, rear: float,
		open: float, _delta: float) -> void:
	var to_local: Transform3D = global_transform.affine_inverse() if is_inside_tree() else Transform3D.IDENTITY
	rear = clampf(rear, 0.0, 1.0)
	var head_up := Vector3(0.0, Centipede.HEAD_HEIGHT - 0.1 + rear * REAR_HEIGHT, 0.0)
	_head.transform = to_local * Transform3D(head_xform.basis * Basis(Vector3.RIGHT, rear * REAR_PITCH)
		* Basis.from_scale(Vector3.ONE * HEAD_SCALE), head_xform.origin + head_up)
	var swing: float = lerpf(JAW_CLOSED, JAW_OPEN, clampf(open, 0.0, 1.0))
	for i: int in _jaws.size():
		_jaws[i].rotation = Vector3(0.0, (1.0 if i == 0 else -1.0) * swing, 0.0)
	_maw.visible = open > 0.05
	if _maw.visible:
		_maw.scale = Vector3.ONE * clampf(open, 0.2, 1.0)
	_lenses.material_override = _lens_flare if rear > 0.3 else (_lens_awake if awake else _lens_rest)
	var glass_i: int = 0
	var phase: float = gait * STEPS_PER_METRE * TAU
	var step_amount: float = clampf(moving, 0.0, 1.0) if awake else 0.0
	for i: int in segments:
		var s: Transform3D = segment_xforms[i] if i < segment_xforms.size() else segment_xforms[-1]
		var k: float = 1.0
		if i >= segments - TAPER:
			k = lerpf(1.0, TAIL_SCALE, float(i - (segments - TAPER) + 1) / TAPER)
		if rear > 0.0 and i < REAR_SEGMENTS:
			# Rearing: it lifts and tips up, a ramp from the body behind up to its neck.
			var lift: float = _lift(i, rear)
			var tip: float = atan2(_lift(i - 1, rear) - _lift(i + 1, rear), 2.0 * Centipede.SEGMENT_SPACING)
			s = Transform3D(s.basis * Basis(Vector3.RIGHT, tip), s.origin + Vector3(0.0, lift, 0.0))
		var shell := Transform3D(s.basis.scaled(Vector3(k, k, 1.0)), s.origin + Vector3(0.0, SHELL_Y * k, 0.0))
		_shells.multimesh.set_instance_transform(i, to_local * shell)
		for side: int in 2:
			var sx: float = -1.0 if side == 0 else 1.0
			var leg_phase: float = phase - i * 0.9 + (PI if side == 1 else 0.0)
			var stride: float = sin(leg_phase) * STRIDE * step_amount
			var lift: float = maxf(cos(leg_phase), 0.0) * 0.35 * step_amount
			var fold: float = 0.0 if awake else 0.9
			var hip: Vector3 = s.origin + s.basis * Vector3(sx * SHELL.x * 0.42 * k, SHELL_Y * k, 0.0)
			# The leg's frame: +x out from the body's side, swung forward and back about the vertical, lifted, folded.
			var b := Basis(Vector3.UP, sx * stride) * Basis(Vector3.BACK, sx * (lift + fold))
			var leg_basis: Basis = s.basis * Basis.from_scale(Vector3(sx, 1.0, 1.0)) * b * Basis.from_scale(Vector3(k, k, k))
			_legs.multimesh.set_instance_transform(i * 2 + side, to_local * Transform3D(leg_basis, hip))
		if _carries_glass(i) and glass_i < _glass.multimesh.instance_count:
			var shown: bool = not (wounded and i == _crack_at)
			var g := Transform3D(s.basis.scaled(Vector3.ONE * (k if shown else 0.001)), s.origin + Vector3(0.0, (SHELL_Y + SHELL.y * 0.5) * k, 0.0))
			_glass.multimesh.set_instance_transform(glass_i, to_local * g)
			glass_i += 1
		if i == _crack_at:
			var top: Vector3 = s.origin + Vector3(0.0, (SHELL_Y + SHELL.y * 0.5) * k, 0.0)
			_crack.transform = to_local * Transform3D(s.basis, top)
			# Its leak spurts up out of the crack and splashes down round it.
			_leak.position = to_local * (top + Vector3(0.0, 0.14, 0.0))
			_sparks.position = to_local * (top + Vector3(0.0, 0.3, 0.0))
		if i == segments - 2:
			_steam.position = to_local * (s.origin + Vector3(0.0, (SHELL_Y + SHELL.y) * k + 0.2, 0.0))


## How high segment `i` lifts as it rears by `rear` (0–1): the head (-1) by REAR_HEIGHT, the first REAR_SEGMENTS less
## and less, the rest not at all.
func _lift(i: int, rear: float) -> float:
	if i < 0:
		return rear * REAR_HEIGHT
	return rear * REAR_HEIGHT * maxf(1.0 - float(i + 1) / (REAR_SEGMENTS + 1), 0.0) * 0.8


## The top of its head drawn at full rear, above the floor (metres): its bite's hitbox stays under it
## (CentipedeTuning.bite_height; GDD §3, hitboxes smaller than what's drawn).
func reared_top() -> float:
	var head_aabb: AABB = (_head_mesh.mesh as Mesh).get_aabb()
	return Centipede.HEAD_HEIGHT - 0.1 + REAR_HEIGHT + HEAD_SCALE * head_aabb.end.y


## How far in front of its head's middle its mandibles' tips are drawn, at rest (metres): its bite's hitbox, with the
## lunge, stays within them and their lunge.
func jaw_reach() -> float:
	var jaw_aabb: AABB = (_jaws[0].get_child(0) as MeshInstance3D).mesh.get_aabb()
	return HEAD_SCALE * (-_jaws[0].position.z - jaw_aabb.position.z)


## Awake (lenses brighter, legs out) or waiting (legs folded under it, lenses dim) or given up.
func set_awake(on: bool) -> void:
	awake = on


## Wounded (a dash's first): its cracked canister, leaking green, sparking (not with Reduced flashing, which keeps the
## leak alone: nothing flickers).
func set_wounded(on: bool, reduced_flashing: bool = false) -> void:
	wounded = on
	_sparks_off = reduced_flashing
	_crack.visible = on
	if is_inside_tree():
		_leak.emitting = on
		_sparks.emitting = on and not reduced_flashing


## True while its open jaws' red glow shows.
func maw_visible() -> bool:
	return _maw.visible


## True while its sparks fly (or would, out of the tree).
func sparking() -> bool:
	return _sparks.emitting or (not is_inside_tree() and wounded and not _sparks_off)


## True while its wound leaks.
func leaking() -> bool:
	return _leak.emitting or (not is_inside_tree() and wounded)


func draw_call_count() -> int:
	var n: int = 0
	for mi: GeometryInstance3D in _geometry():
		var mesh: Mesh = (mi as MeshInstance3D).mesh if mi is MeshInstance3D else (mi as MultiMeshInstance3D).multimesh.mesh
		n += mesh.get_surface_count()
	return n


func triangle_count() -> int:
	var n: int = 0
	for mi: GeometryInstance3D in _geometry():
		var mesh: Mesh
		var copies: int = 1
		if mi is MeshInstance3D:
			mesh = (mi as MeshInstance3D).mesh
		else:
			mesh = (mi as MultiMeshInstance3D).multimesh.mesh
			copies = (mi as MultiMeshInstance3D).multimesh.instance_count
		for s: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			var idx: Variant = arrays[Mesh.ARRAY_INDEX]
			var tris: int = (idx as PackedInt32Array).size() / 3 if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			n += tris * copies
	return n


## Every material it draws with, and its part (tests: only the glass, the lenses and the maw glow).
func materials() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mi: GeometryInstance3D in _geometry():
		var mesh: Mesh = (mi as MeshInstance3D).mesh if mi is MeshInstance3D else (mi as MultiMeshInstance3D).multimesh.mesh
		for s: int in mesh.get_surface_count():
			out.append({"part": String(mi.name), "material": mesh.surface_get_material(s)})
	for m: Material in [_lens_rest, _lens_awake, _lens_flare]:
		out.append({"part": "lenses", "material": m})
	return out


func _geometry() -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = [_shells, _legs, _glass, _head_mesh, _lenses, _maw, _crack]
	for pivot: Node3D in _jaws:
		out.append(pivot.get_child(0) as GeometryInstance3D)
	return out


# --- The meshes ---------------------------------------------------------------------------------

## The meshes for a look (see the header), cached.
static func meshes_for(variant: StringName) -> Dictionary:
	var weathered: bool = variant == &"burned" or variant == &"scavenger"
	var key: String = "weathered" if weathered else "clean"
	if _meshes.has(key):
		return _meshes[key]
	var glow: Material = GreyboxMaterials.glow(GLOW, 2.6)
	var out := {
		"shell": _shell(weathered),
		"leg": _leg(),
		"canister": _canister(glow),
		"head": _head_body(weathered),
		"lenses": _lens_mesh(),
		"mandible": _mandible(),
		"maw": _maw_mesh(),
		"cracked": _cracked(),
	}
	_meshes[key] = out
	return out


## The matte metal the body is drawn in (its colours are the vertices').
static func body_material() -> StandardMaterial3D:
	if _body_material == null:
		_body_material = StandardMaterial3D.new()
		_body_material.vertex_color_use_as_albedo = true
		_body_material.vertex_color_is_srgb = true
		_body_material.roughness = 0.55
		_body_material.metallic = 0.35
	return _body_material


## The body's metal seen from both sides, for its mandibles (the left one is the right one mirrored).
static func jaw_material() -> StandardMaterial3D:
	if _jaw_material == null:
		_jaw_material = body_material().duplicate() as StandardMaterial3D
		_jaw_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _jaw_material


## Its steam: a pale, see-through grey, lit like the scene (it doesn't glow: it's no hazard), fading as each puff ages
## (the particles' colour ramp, through the vertex colour).
static func steam_material() -> StandardMaterial3D:
	if _steam_material == null:
		_steam_material = StandardMaterial3D.new()
		_steam_material.albedo_color = Color(0.78, 0.78, 0.76, 0.5)
		_steam_material.vertex_color_use_as_albedo = true
		_steam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_steam_material.roughness = 1.0
	return _steam_material


## The legs' steel, seen from both sides (a left leg is a right one mirrored).
static func leg_material() -> StandardMaterial3D:
	if _leg_material == null:
		_leg_material = StandardMaterial3D.new()
		_leg_material.albedo_color = Color(0.5, 0.52, 0.55)
		_leg_material.roughness = 0.45
		_leg_material.metallic = 0.5
		_leg_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _leg_material


## A unit primitive: a box, an eight-sided cylinder along y, a low dome, or a four-sided spike along y.
static func _prim(kind: StringName) -> Mesh:
	if not _prims.has(kind):
		match kind:
			&"box":
				var b := BoxMesh.new()
				b.size = Vector3.ONE
				_prims[kind] = b
			&"cylinder":
				var c := CylinderMesh.new()
				c.top_radius = 0.5
				c.bottom_radius = 0.5
				c.height = 1.0
				c.radial_segments = 8
				c.rings = 1
				_prims[kind] = c
			&"dome":
				var s := SphereMesh.new()
				s.radius = 0.5
				s.height = 1.0
				s.radial_segments = 10
				s.rings = 4
				s.is_hemisphere = true
				_prims[kind] = s
			_:
				var p := CylinderMesh.new()
				p.top_radius = 0.0
				p.bottom_radius = 0.5
				p.height = 1.0
				p.radial_segments = 4
				p.rings = 1
				_prims[kind] = p
	return _prims[kind]


## A segment's drum (its local frame: -z toward the head, its middle at the origin): a brass drum lying along the body,
## a steel band round its front with rivets, a dark belly under it and a dark joint behind.
static func _shell(weathered: bool) -> ArrayMesh:
	var b := ColorBatch.new()
	var brass: Color = BRASS.lerp(RUST, 0.35) if weathered else BRASS
	var w: float = SHELL.x
	var h: float = SHELL.y
	var l: float = SHELL.z
	b.add(brass, &"cylinder", Vector3.ZERO, Vector3(w, l * 0.82, h), Vector3(PI * 0.5, 0.0, 0.0))
	b.add(STEEL, &"cylinder", Vector3(0.0, 0.0, -l * 0.36), Vector3(w * 1.06, l * 0.16, h * 1.06), Vector3(PI * 0.5, 0.0, 0.0))
	b.add(DARK, &"cylinder", Vector3(0.0, 0.0, l * 0.46), Vector3(w * 0.7, l * 0.12, h * 0.7), Vector3(PI * 0.5, 0.0, 0.0))
	b.add(DARK, &"box", Vector3(0.0, -h * 0.4, 0.0), Vector3(w * 0.6, h * 0.16, l * 0.8))
	for k: int in 5:
		var a: float = -PI * 0.5 + PI * float(k) / 4.0
		var p := Vector3(sin(a) * w * 0.54, cos(a) * h * 0.54, -l * 0.36)
		b.add(RUST if weathered else DARK, &"box", p, Vector3(0.06, 0.06, 0.06))
	# A brass plate on its back, riveted.
	b.add(brass.darkened(0.1), &"box", Vector3(0.0, h * 0.47, 0.06), Vector3(w * 0.42, 0.05, l * 0.5))
	return b.commit(body_material())


## A leg (its local frame: the hip at the origin, +x out from the body): a steel thigh up and out to the knee, a joint,
## and a sharp shin down to the floor, a hooked tip.
static func _leg() -> ArrayMesh:
	var b := MeshBatchScript.new()
	var steel: Material = leg_material()
	var knee := Vector3(LEG_REACH * 0.5, 0.28, 0.0)
	var foot := Vector3(LEG_REACH, -Centipede.HEAD_HEIGHT + 0.05, 0.0)
	_strut(b, steel, Vector3.ZERO, knee, 0.09)
	b.box(steel, knee, Vector3(0.13, 0.13, 0.13))
	var shin: Vector3 = foot - knee
	b.spike(steel, knee, shin.length(), 0.1, Vector3(0.0, 0.0, atan2(-shin.x, shin.y)))
	return b.commit()


## The turn (Euler, Basis.from_euler's order) that points +y along `direction`.
static func toward(direction: Vector3) -> Vector3:
	if direction.length() < 0.0001:
		return Vector3.ZERO
	var d: Vector3 = direction.normalized()
	if d.dot(Vector3.UP) < -0.9999:
		return Vector3(PI, 0.0, 0.0)
	return Basis(Quaternion(Vector3.UP, d)).get_euler()


## A box from `a` to `b` (a strut `thick` thick), into batch `b`.
static func _strut(batch: RefCounted, material: Material, a: Vector3, c: Vector3, thick: float) -> void:
	var d: Vector3 = c - a
	var rot := Vector3(0.0, 0.0, atan2(d.y, d.x))
	(batch as MeshBatchScript).box(material, (a + c) * 0.5, Vector3(d.length(), thick, thick), rot)


## A canister of glowing fluid on a segment's back (its frame: its foot at the origin): green glass, a dark cap and foot.
static func _canister(glow: Material) -> ArrayMesh:
	var b := MeshBatchScript.new()
	var dark: Material = GreyboxMaterials.flat(DARK)
	b.cylinder(dark, Vector3(0.0, 0.03, 0.0), Vector3(0.24, 0.06, 0.24))
	b.cylinder(glow, Vector3(0.0, 0.2, 0.0), Vector3(0.18, 0.3, 0.18))
	b.cylinder(dark, Vector3(0.0, 0.38, 0.0), Vector3(0.22, 0.06, 0.22))
	# A glowing tube from it back toward the next segment.
	b.box(glow, Vector3(0.0, 0.08, 0.28), Vector3(0.05, 0.05, 0.5))
	return b.commit()


## Its cracked canister (a dash's first wound): the glass broken down to a jagged stump, its glow out.
static func _cracked() -> ArrayMesh:
	var b := MeshBatchScript.new()
	var dark: Material = GreyboxMaterials.flat(DARK)
	var dull: Material = GreyboxMaterials.flat(Color(0.18, 0.35, 0.16))
	b.cylinder(dark, Vector3(0.0, 0.03, 0.0), Vector3(0.24, 0.06, 0.24))
	b.cylinder(dull, Vector3(0.0, 0.1, 0.0), Vector3(0.18, 0.12, 0.18))
	for k: int in 4:
		var a: float = TAU * k / 4.0 + 0.3
		b.spike(dull, Vector3(sin(a) * 0.07, 0.15, cos(a) * 0.07), 0.1 + 0.04 * (k % 2), 0.05, Vector3(0.2 * cos(a), 0.0, -0.2 * sin(a)))
	return b.commit()


## The head (its frame: -z where it looks, the origin under its middle at its rest height): a brass dome riveted with a
## steel band, a welder's mask of dark steel on its face (tipped up a little, FACE_TILT) with its visor slot and a chin
## guard, cheek plates holding brass rims for its two big lenses, cables, feelers and a gauge.
static func _head_body(weathered: bool) -> ArrayMesh:
	var b := ColorBatch.new()
	var brass: Color = BRASS.lerp(RUST, 0.35) if weathered else BRASS
	var mask := Color(0.2, 0.19, 0.18)
	var face := Vector3(FACE_TILT, 0.0, 0.0)
	# The dome: the back and top of its head, brass, with a steel band.
	b.add(brass, &"dome", Vector3(0.0, 0.04, 0.08), Vector3(0.86, 0.7, 0.84))
	b.add(STEEL.darkened(0.2), &"cylinder", Vector3(0.0, 0.04, 0.08), Vector3(0.88, 0.1, 0.86))
	b.add(STEEL.darkened(0.1), &"box", Vector3(0.0, 0.3, 0.08), Vector3(0.1, 0.06, 0.8), Vector3(0.0, 0.0, 0.0))
	# The mask: a dark plate on its face, its visor slot, and a chin guard under it.
	b.add(mask, &"box", Vector3(0.0, 0.14, -0.33), Vector3(0.4, 0.46, 0.1), face)
	b.add(DARK, &"box", Vector3(0.0, 0.2, -0.385), Vector3(0.3, 0.06, 0.03), face)
	b.add(mask, &"box", Vector3(0.0, -0.1, -0.3), Vector3(0.3, 0.14, 0.18))
	for sx: float in [-1.0, 1.0]:
		# Cheek plates beside the mask, and the brass rims of its lenses on them, looking out a little.
		b.add(mask, &"box", Vector3(sx * 0.3, 0.05, -0.14), Vector3(0.14, 0.34, 0.3), Vector3(0.0, sx * 0.35, 0.0))
		b.add(brass, &"cylinder", LENS * Vector3(sx, 1.0, 1.0), Vector3(LENS_SIZE + 0.07, 0.06, LENS_SIZE + 0.07),
			_lens_turn(sx))
		# Feelers, sweeping up and forward, rust at their tips.
		var root := Vector3(sx * 0.14, 0.42, -0.1)
		var knee := Vector3(sx * 0.3, 0.85, -0.3)
		b.strut(STEEL, root, knee, 0.04)
		b.strut(RUST, knee, Vector3(sx * 0.42, 0.75, -0.75), 0.035)
		# Cables from the dome down into its neck.
		b.add(DARK, &"cylinder", Vector3(sx * 0.3, 0.0, 0.32), Vector3(0.07, 0.4, 0.07), Vector3(0.6, 0.0, sx * 0.3))
	# A gauge on its brow.
	b.add(STEEL, &"cylinder", Vector3(0.0, 0.43, -0.18), Vector3(0.12, 0.04, 0.12), Vector3(-0.6, 0.0, 0.0))
	# The neck, into the first segment.
	b.add(DARK, &"cylinder", Vector3(0.0, -0.05, 0.4), Vector3(0.45, 0.3, 0.4), Vector3(PI * 0.5, 0.0, 0.0))
	return b.commit(body_material())


## A lens's turn (Euler, from a cylinder along y): facing forward, tipped up with its face (FACE_TILT), and out to its
## side (`sx`).
static func _lens_turn(sx: float) -> Vector3:
	return Vector3(PI * 0.5 + FACE_TILT, -sx * 0.35, 0.0)


## Its two big lenses, glowing green.
static func _lens_mesh() -> ArrayMesh:
	var b := MeshBatchScript.new()
	var glow: Material = GreyboxMaterials.glow(GLOW, 1.8)
	for sx: float in [-1.0, 1.0]:
		var at: Vector3 = LENS * Vector3(sx, 1.0, 1.0)
		var out: Vector3 = Basis.from_euler(_lens_turn(sx)) * Vector3(0.0, -0.025, 0.0)
		b.cylinder(glow, at + out, Vector3(LENS_SIZE, 0.04, LENS_SIZE), _lens_turn(sx))
	return b.commit()


## A hooked mandible (its frame: the hinge at the origin; the right one, which reaches forward along -z and curls in
## toward -x; the left is it mirrored): a steel blade down and forward, a hook curving in, its rusted tip, and teeth on its
## inner edge.
static func _mandible() -> ArrayMesh:
	var b := ColorBatch.new()
	var elbow := Vector3(0.07, -0.1, -0.3)
	var bend := Vector3(-0.04, -0.15, -0.47)
	var tip := Vector3(-0.17, -0.17, -0.52)
	b.strut(STEEL, Vector3.ZERO, elbow, 0.09)
	b.strut(STEEL, elbow, bend, 0.08)
	b.spike(RUST, bend, tip, 0.045)
	for k: int in 2:
		var at: Vector3 = Vector3.ZERO.lerp(elbow, 0.45 + 0.3 * k)
		b.spike(RUST, at, at + Vector3(-0.09, -0.02, -0.03), 0.025)
	return b.commit(jaw_material())


## The red glow inside its open jaws (its bite's warning), between its mandibles under its mask.
static func _maw_mesh() -> ArrayMesh:
	var b := MeshBatchScript.new()
	b.box(GreyboxMaterials.glow(MAW, 3.0), Vector3(0.0, -0.06, -0.4), Vector3(0.26, 0.14, 0.05))
	return b.commit()


const MeshBatchScript := preload("res://scripts/enemies/mesh_batch.gd")


## Merges primitives into one surface in vertex colours under one material (one draw call whatever its colours).
class ColorBatch:
	var _st := SurfaceTool.new()

	func _init() -> void:
		_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## A primitive (CentipedeModel._prim: box, cylinder, dome, spike) of `size` centred at `center`, rotated by
	## `rotation` (Euler, radians), in `color`.
	func add(color: Color, kind: StringName, center: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
		var mesh: Mesh = CentipedeModel._prim(kind)
		var xform := Transform3D(Basis.from_euler(rotation) * Basis.from_scale(size), center)
		var arrays: Array = mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var normal_basis: Basis = xform.basis.inverse().transposed()
		_st.set_color(color)
		for i: int in idx:
			_st.set_normal((normal_basis * normals[i]).normalized())
			_st.add_vertex(xform * verts[i])

	## A box `thick` thick from `a` to `c`.
	func strut(color: Color, a: Vector3, c: Vector3, thick: float) -> void:
		add(color, &"box", (a + c) * 0.5, Vector3(thick, a.distance_to(c), thick), CentipedeModel.toward(c - a))

	## A spike from its base at `base` to its point at `point`, `radius` round at its base.
	func spike(color: Color, base: Vector3, point: Vector3, radius: float) -> void:
		add(color, &"spike", (base + point) * 0.5, Vector3(radius * 2.0, base.distance_to(point), radius * 2.0),
			CentipedeModel.toward(point - base))

	func commit(material: Material) -> ArrayMesh:
		var mesh: ArrayMesh = _st.commit()
		mesh.surface_set_material(0, material)
		return mesh
