class_name HunterModel
extends Node3D
## The Hunter's look (GDD §9.17, the owner, October 23, 2026, and the reference image from the design session): "a torso
## coming out of its cybernetically grafted hover platform", with "large slashing red scimitars attached to its arms"
## reaching past the elbow and past the hand. From the reference: a muscular grey-skinned torso in a riveted black armour
## vest, a gas-mask face with three glowing orange-red eyes, breathing hoses from the mask and from the disc into its body;
## a thick round riveted dark-steel hover disc, frosted and worn, a thruster pod on each side and blue-white hover jets
## glowing underneath; long serrated cleaver blades fixed to bracers on its forearms. (Proposed, GDD §9.17: the blades are
## red, deadly parts looking deadly, and the jets' blue-white stays a small glow under the disc.)
## Built in code from boxes, cylinders, domes and spikes, each moving part one mesh in vertex colours under one matte
## material (one draw call a part); only the eyes, the blades and the jets glow (the eyes' orange-red, the blades' hazard
## red, the jets' blue-white, well off the safe cyan). Works the same on the Compatibility renderer (standard materials
## only, no shader of its own). Meshes and materials are built once and shared (static caches), so a Hunter spawned in
## play builds none: Hunter.warm_up builds them with the level.
##
## Model space: it faces -z (the way the runner runs); the origin is on the floor under the middle of its disc. Its rig
## (the disc and everything on it) hovers hover_height up and bobs; the torso turns at its graft in the disc toward the
## runner (face_yaw) and leans in to cut (lean); each arm swings at its shoulder (raise: both blades up for a flurry's
## warning; cut: the flurry, the arms chopping in turn). Its pose is set by the fields below and applied by animate().
##
## DESIGN-TBD (docs/questions/s2.md, item 17, and the sweep's item): the look as a whole awaits the owner (its shapes,
## proportions and colours from the reference image, the blades' red proposed in GDD §9.17), and so do its lunge toward
## the lane it cuts (LUNGE) and the see-through red sweep of its cuts over that lane (slash_mesh, SLASH; task S2's review:
## what its cuts' hitbox reaches is drawn).

## Its colours: the grey skin, the vest's black and its rivets, the mask's rubber and its filters' steel, the hoses, the
## disc's dark steel, its worn edges and frost, the bracers.
const SKIN := Color(0.42, 0.43, 0.45)
const SKIN_DARK := Color(0.3, 0.31, 0.33)
const VEST := Color(0.07, 0.07, 0.08)
const RIVET := Color(0.42, 0.42, 0.44)
const MASK := Color(0.12, 0.12, 0.13)
const FILTER := Color(0.3, 0.31, 0.33)
const HOSE := Color(0.1, 0.1, 0.11)
const STEEL := Color(0.18, 0.19, 0.21)
const STEEL_WORN := Color(0.34, 0.33, 0.32)
const FROST := Color(0.7, 0.76, 0.82)
const BRACER := Color(0.13, 0.13, 0.14)
## The glowing parts: its three eyes (orange-red), its blades (the hazard red every enemy attack wears) and its jets.
const EYE := Color(1.0, 0.34, 0.08)
const BLADE := Color(1.0, 0.09, 0.06)
const JET := Color(0.8, 0.88, 1.0)
## The red of the warning mark on the runner's lane (every floor warning's red: the Enforcer Truck's line, BossProps').
const WARNING_COLOR := Color(1.0, 0.12, 0.08)
## Its disc: radius and thickness; where the torso's graft sits on it; the arms' shoulders in the torso's space.
const DISC_RADIUS: float = 0.78
const DISC_THICK: float = 0.3
const WAIST_Y: float = 0.32
const SHOULDER := Vector3(0.43, 1.0, 0.02)
## Its height over the floor at rest (the head's top), with the disc at Hunter's hover_height.
const TOP: float = 1.86
## An arm's pose (shoulder pitch, radians) at rest, raised for a warning, and at the end of a cut.
const ARM_REST: float = 0.18
const ARM_RAISED: float = 2.55
const ARM_CUT: float = -0.35
## DESIGN-TBD: how far its rig lunges toward the lane it cuts through a flurry (metres across the track, `reach` 1).
const LUNGE: float = 0.5
## DESIGN-TBD: the slash's red: the blades' hazard red, see-through (its sweep over the lane it cuts: slash_mesh).
const SLASH := Color(1.0, 0.1, 0.06)

## Meshes, built once: {disc, jets, torso, eyes, arm_l, arm_r, blade_l, blade_r}.
static var _meshes: Dictionary = {}
## Materials made once: the body's matte vertex-colour material; the eyes', blades' and jets' glows by state.
static var _materials: Dictionary = {}
static var _prims: Dictionary = {}

var rig: Node3D
var disc: MeshInstance3D
var jets: MeshInstance3D
var torso: Node3D
var eyes: MeshInstance3D
var arms: Array[Node3D] = []
var blades: Array[MeshInstance3D] = []

## Its pose (animate() applies it): how high the disc hovers, the torso's turn (radians round y, 0 facing ahead) and lean
## (toward where it faces), both blades raised for a warning (0-1), the flurry (0-1 over its cuts, -1: none), the disc's
## roll as it changes lanes (radians), whether it's alert (a warning or a flurry: eyes and blades brighter), and its lunge
## toward the lane it cuts (0-1 of LUNGE, toward x `reach_dir`, -1 or 1).
var hover: float = 0.38
var face_yaw: float = 0.0
var lean: float = 0.0
var raise: float = 0.0
var cut: float = -1.0
var cuts: int = 4
var roll: float = 0.0
var alert: bool = false
var reach: float = 0.0
var reach_dir: float = 1.0
var _bob_t: float = 0.0
var _alert_shown: int = -1


func build() -> void:
	var m: Dictionary = meshes()
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	disc = _node(rig, m["disc"], "Disc")
	jets = _node(rig, m["jets"], "Jets")
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0.0, WAIST_Y, 0.0)
	rig.add_child(torso)
	_node(torso, m["torso"], "Body")
	eyes = _node(torso, m["eyes"], "Eyes")
	for side: int in [-1, 1]:
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.position = Vector3(SHOULDER.x * side, SHOULDER.y, SHOULDER.z)
		torso.add_child(arm)
		_node(arm, m["arm_l" if side < 0 else "arm_r"], "Arm")
		blades.append(_node(arm, m["blade_l" if side < 0 else "blade_r"], "Blade"))
		arms.append(arm)
	animate(0.0)


## Applies the pose (see the fields), `delta` seconds on for its bob.
func animate(delta: float) -> void:
	_bob_t += delta
	rig.position = Vector3(reach * LUNGE * reach_dir, hover + 0.035 * sin(_bob_t * 3.1), 0.0)
	rig.rotation = Vector3(0.025 * sin(_bob_t * 2.3), 0.0, roll + 0.02 * sin(_bob_t * 1.7))
	torso.rotation = Vector3(-lean, face_yaw, 0.0)
	for i: int in arms.size():
		var side: float = -1.0 if i == 0 else 1.0
		var pitch: float = lerpf(ARM_REST, ARM_RAISED, raise)
		var spread: float = 0.28 * raise
		if cut >= 0.0:
			# The flurry: the arms chop in turn, each cut from raised down across in front of it (toward where it faces),
			# the other arm coming back up for its next.
			var phase: float = cut * cuts
			var k: int = mini(int(phase), cuts - 1)
			var u: float = clampf(phase - k, 0.0, 1.0)
			var mine: bool = (k % 2) == i
			var swing: float = smoothstep(0.0, 1.0, u)
			if mine:
				pitch = lerpf(ARM_RAISED, ARM_CUT, swing)
				spread = lerpf(0.28, -0.32, swing)
			else:
				pitch = lerpf(ARM_CUT, ARM_RAISED, swing) if k > 0 else ARM_RAISED
				spread = lerpf(-0.32, 0.28, swing) if k > 0 else 0.28
		arms[i].rotation = Vector3(pitch, 0.0, side * spread)
	var shown: int = 1 if alert else 0
	if shown != _alert_shown:
		_alert_shown = shown
		eyes.material_override = eye_material(alert)
		for b: MeshInstance3D in blades:
			b.material_override = blade_material(alert)


## Draw calls of the whole look.
func draw_call_count() -> int:
	var n: int = 0
	for mi: MeshInstance3D in mesh_nodes():
		n += mi.mesh.get_surface_count()
	return n


## Triangles of the whole look.
func triangle_count() -> int:
	var n: int = 0
	for mi: MeshInstance3D in mesh_nodes():
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			n += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


## Every mesh node of the look.
func mesh_nodes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


## Every material the look draws with in each state, and the part it's on (tests: only the eyes, the blades and the jets
## glow, the blades in the hazard red).
func materials() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mi: MeshInstance3D in mesh_nodes():
		var mat: Material = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(0)
		out.append({"part": String(mi.get_parent().name) + "/" + String(mi.name), "material": mat})
	for on: bool in [false, true]:
		out.append({"part": "Eyes (%s)" % ("alert" if on else "calm"), "material": eye_material(on)})
		out.append({"part": "Blade (%s)" % ("alert" if on else "calm"), "material": blade_material(on)})
	return out


func _node(parent: Node3D, mesh: Mesh, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# --- Materials ---------------------------------------------------------------------------------------

## The body's matte material: lit like GreyboxMaterials.flat, its colours the vertices'.
static func body_material() -> StandardMaterial3D:
	if not _materials.has(&"body"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.72
		_materials[&"body"] = m
	return _materials[&"body"]


## Its eyes' glow, brighter while it's alert (a warning, a flurry). A change of state, never a flicker.
static func eye_material(alert: bool) -> Material:
	return GreyboxMaterials.glow(EYE, 3.6 if alert else 2.2)


## Its blades' material: a lit red steel with a red glow, brighter while it's alert. A change of state, never a flicker.
static func blade_material(alert: bool) -> StandardMaterial3D:
	var key := StringName("blade_alert" if alert else "blade")
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.62, 0.05, 0.04)
		m.metallic = 0.35
		m.roughness = 0.38
		m.emission_enabled = true
		m.emission = BLADE
		m.emission_energy_multiplier = 2.4 if alert else 0.75
		_materials[key] = m
	return _materials[key]


## The jets' blue-white glow under the disc.
static func jet_material() -> Material:
	return GreyboxMaterials.glow(JET, 1.8)


## The warning mark's material (the floor warnings' red, see-through): drawn on a unit box (GreyboxMaterials.unit_box).
static func mark_material() -> Material:
	return GreyboxMaterials.glow(WARNING_COLOR, 3.0, 0.5)


## The slash's material (slash_mesh): the blades' red glowing see-through, both faces drawn, unlit (the Compatibility
## renderer draws it the same). Steady: it never pulses or flickers.
static func slash_material() -> StandardMaterial3D:
	if not _materials.has(&"slash"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(SLASH, 0.3)
		m.emission_enabled = true
		m.emission = SLASH
		m.emission_energy_multiplier = 1.6
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[&"slash"] = m
	return _materials[&"slash"]


## The sweep of its blades through the lane it cuts (Hunter's slash fan, task S2's review: what its cuts' hitbox reaches
## is drawn): a fan in the x-y plane round its pivot, from `low` to `high` radians (0 along +x, toward the lane), from
## radius `inner` to `outer`, as two sheets `half_depth` each side of z = 0 and the band joining their outer arcs, in
## `segments` steps.
static func slash_mesh(inner: float, outer: float, low: float, high: float, half_depth: float, segments: int = 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.BACK)
	var point := func(a: float, r: float, z: float) -> Vector3: return Vector3(cos(a) * r, sin(a) * r, z)
	for z: float in [-half_depth, half_depth]:
		for i: int in segments:
			var a0: float = lerpf(low, high, float(i) / segments)
			var a1: float = lerpf(low, high, float(i + 1) / segments)
			st.add_vertex(point.call(a0, inner, z))
			st.add_vertex(point.call(a0, outer, z))
			st.add_vertex(point.call(a1, outer, z))
			st.add_vertex(point.call(a0, inner, z))
			st.add_vertex(point.call(a1, outer, z))
			st.add_vertex(point.call(a1, inner, z))
	for i: int in segments:
		var a0: float = lerpf(low, high, float(i) / segments)
		var a1: float = lerpf(low, high, float(i + 1) / segments)
		st.add_vertex(point.call(a0, outer, -half_depth))
		st.add_vertex(point.call(a0, outer, half_depth))
		st.add_vertex(point.call(a1, outer, half_depth))
		st.add_vertex(point.call(a0, outer, -half_depth))
		st.add_vertex(point.call(a1, outer, half_depth))
		st.add_vertex(point.call(a1, outer, -half_depth))
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, slash_material())
	return mesh


# --- Meshes ------------------------------------------------------------------------------------------

## The look's meshes, built once: {disc, jets, torso, eyes, arm_l, arm_r, blade_l, blade_r}.
static func meshes() -> Dictionary:
	if not _meshes.is_empty():
		return _meshes
	_meshes = {
		"disc": _disc(),
		"jets": _jets(),
		"torso": _torso(),
		"eyes": _eyes(),
		"arm_l": _arm(-1.0),
		"arm_r": _arm(1.0),
		"blade_l": _blade(-1.0),
		"blade_r": _blade(1.0),
	}
	return _meshes


## The hover disc in the rig's space (its underside at 0): thick, round, riveted dark steel, worn at its rim and frosted
## on top, a thruster pod on each side, the hub underneath, and the hoses that run from it up into the body.
static func _disc() -> ArrayMesh:
	var b := ColorBatch.new()
	var r: float = DISC_RADIUS
	b.add(STEEL, &"cylinder", Vector3(0.0, DISC_THICK * 0.5, 0.0), Vector3(r * 2.0, DISC_THICK, r * 2.0))
	# Its rim: a raised band, worn bright in places, and the rivets round it.
	b.add(STEEL_WORN.darkened(0.25), &"cylinder", Vector3(0.0, DISC_THICK - 0.02, 0.0), Vector3(r * 2.06, 0.07, r * 2.06))
	b.add(STEEL, &"cylinder", Vector3(0.0, DISC_THICK + 0.02, 0.0), Vector3(r * 1.62, 0.05, r * 1.62))
	for k: int in 16:
		var a: float = TAU * k / 16.0
		b.add(RIVET, &"box", Vector3(sin(a) * (r - 0.05), DISC_THICK + 0.025, cos(a) * (r - 0.05)), Vector3(0.05, 0.03, 0.05))
		b.add(RIVET.darkened(0.2), &"box", Vector3(sin(a) * (r + 0.015), DISC_THICK * 0.5, cos(a) * (r + 0.015)),
			Vector3(0.04, 0.04, 0.04), Vector3(0.0, a, 0.0))
	# Worn patches on its side, and frost on its top.
	for k: int in 5:
		var a: float = 0.7 + k * 1.31
		b.add(STEEL_WORN, &"box", Vector3(sin(a) * (r - 0.005), DISC_THICK * 0.45, cos(a) * (r - 0.005)),
			Vector3(0.26, 0.1, 0.02), Vector3(0.0, a, 0.0))
	for k: int in 7:
		var a: float = 0.3 + k * 0.93
		var d: float = 0.32 + 0.24 * float(k % 3) / 2.0
		b.add(FROST, &"box", Vector3(sin(a) * d, DISC_THICK + 0.05, cos(a) * d), Vector3(0.22 - 0.03 * (k % 3), 0.012,
			0.12 + 0.04 * (k % 2)), Vector3(0.0, a * 1.7, 0.0))
	# The graft's collar where the torso comes out of it.
	b.add(STEEL_WORN.darkened(0.35), &"cylinder", Vector3(0.0, DISC_THICK + 0.06, 0.0), Vector3(0.7, 0.08, 0.62))
	# The thruster pods, one each side, along the disc, nozzles at their rear.
	for sx: float in [-1.0, 1.0]:
		var at := Vector3(sx * (r + 0.07), 0.16, 0.06)
		b.add(STEEL, &"cylinder", at, Vector3(0.3, 0.62, 0.3), Vector3(PI * 0.5, 0.0, 0.0))
		b.add(STEEL_WORN, &"cylinder", at + Vector3(0.0, 0.0, 0.33), Vector3(0.24, 0.06, 0.24), Vector3(PI * 0.5, 0.0, 0.0))
		b.add(STEEL.darkened(0.4), &"cylinder", at + Vector3(0.0, 0.0, -0.33), Vector3(0.2, 0.06, 0.2), Vector3(PI * 0.5, 0.0, 0.0))
		b.add(FROST, &"box", at + Vector3(0.0, 0.15, -0.05), Vector3(0.14, 0.012, 0.28))
		b.add(STEEL.darkened(0.2), &"box", Vector3(sx * (r - 0.02), 0.16, 0.06), Vector3(0.12, 0.14, 0.34))
	# The hub underneath.
	b.add(STEEL.darkened(0.3), &"cylinder", Vector3(0.0, -0.02, 0.0), Vector3(0.62, 0.06, 0.62))
	# Hoses from the disc up into its flanks and back (ribbed: a few bands each).
	for h: Array in [[Vector3(-0.42, DISC_THICK, 0.18), Vector3(-0.2, WAIST_Y + 0.32, 0.12)],
			[Vector3(0.42, DISC_THICK, 0.18), Vector3(0.2, WAIST_Y + 0.32, 0.12)],
			[Vector3(0.0, DISC_THICK, 0.5), Vector3(0.0, WAIST_Y + 0.42, 0.16)]]:
		b.hose(HOSE, h[0], h[1], 0.045, 4)
	return b.commit(body_material())


## The hover jets: small blue-white glows under the disc, and the pods' rear nozzles.
static func _jets() -> ArrayMesh:
	var b := ColorBatch.new()
	for k: int in 4:
		var a: float = PI * 0.25 + k * PI * 0.5
		b.add(JET, &"cylinder", Vector3(sin(a) * 0.42, -0.035, cos(a) * 0.42), Vector3(0.2, 0.025, 0.2))
	for sx: float in [-1.0, 1.0]:
		b.add(JET, &"cylinder", Vector3(sx * (DISC_RADIUS + 0.07), 0.16, 0.06 + 0.36), Vector3(0.16, 0.02, 0.16),
			Vector3(PI * 0.5, 0.0, 0.0))
	return b.commit(jet_material())


## The torso in its own space (the graft at 0, turning with face_yaw): a muscular grey torso coming out of the disc's
## collar, a riveted black armour vest, big shoulders, the neck, and the gas mask with its filters and the hoses from them
## down into its chest. Its front faces -z.
static func _torso() -> ArrayMesh:
	var b := ColorBatch.new()
	# The graft: metal bands where flesh meets the disc, and the hips rising out of it.
	b.add(STEEL_WORN.darkened(0.3), &"cylinder", Vector3(0.0, 0.05, 0.0), Vector3(0.6, 0.12, 0.5))
	b.add(SKIN_DARK, &"cylinder", Vector3(0.0, 0.2, 0.0), Vector3(0.52, 0.22, 0.42))
	# Abdomen and chest, broad at the shoulders.
	b.add(SKIN, &"box", Vector3(0.0, 0.42, 0.0), Vector3(0.5, 0.3, 0.34))
	b.add(SKIN, &"box", Vector3(0.0, 0.72, 0.0), Vector3(0.74, 0.36, 0.44))
	b.add(SKIN, &"box", Vector3(0.0, 0.93, 0.02), Vector3(0.92, 0.16, 0.4))
	# The pecs and the abs showing between the vest's plates.
	for sx: float in [-1.0, 1.0]:
		b.add(SKIN.lightened(0.06), &"box", Vector3(sx * 0.16, 0.76, -0.2), Vector3(0.26, 0.2, 0.08))
		for k: int in 3:
			b.add(SKIN.darkened(0.05), &"box", Vector3(sx * 0.07, 0.34 + k * 0.08, -0.17), Vector3(0.1, 0.06, 0.04))
	# Big shoulders and the trapezius.
	for sx: float in [-1.0, 1.0]:
		b.add(SKIN, &"dome", Vector3(sx * 0.43, 0.93, 0.02), Vector3(0.36, 0.22, 0.36))
		b.add(SKIN_DARK, &"box", Vector3(sx * 0.17, 1.02, 0.06), Vector3(0.2, 0.1, 0.24), Vector3(0.0, 0.0, -sx * 0.35))
	# The riveted black armour vest: front plates either side, a back plate, straps over the shoulders.
	for sx: float in [-1.0, 1.0]:
		b.add(VEST, &"box", Vector3(sx * 0.2, 0.6, -0.2), Vector3(0.3, 0.42, 0.06))
		b.add(VEST, &"box", Vector3(sx * 0.19, 0.98, -0.03), Vector3(0.12, 0.06, 0.46))
		for k: int in 3:
			b.add(RIVET, &"box", Vector3(sx * 0.3, 0.45 + k * 0.13, -0.235), Vector3(0.03, 0.03, 0.02))
			b.add(RIVET, &"box", Vector3(sx * 0.09, 0.45 + k * 0.13, -0.235), Vector3(0.03, 0.03, 0.02))
	b.add(VEST, &"box", Vector3(0.0, 0.66, 0.22), Vector3(0.7, 0.56, 0.06))
	b.add(VEST, &"box", Vector3(0.0, 0.4, 0.0), Vector3(0.56, 0.08, 0.38))
	for k: int in 6:
		b.add(RIVET, &"box", Vector3(-0.28 + k * 0.112, 0.92, 0.255), Vector3(0.03, 0.03, 0.02))
	# The neck, and the gas mask: a rounded rubber hood, its faceplate, a snout filter and two side canisters.
	b.add(SKIN_DARK, &"cylinder", Vector3(0.0, 1.06, 0.0), Vector3(0.24, 0.14, 0.24))
	b.add(MASK, &"box", Vector3(0.0, 1.24, 0.0), Vector3(0.32, 0.3, 0.32))
	b.add(MASK, &"dome", Vector3(0.0, 1.38, 0.0), Vector3(0.32, 0.16, 0.32))
	b.add(MASK.lightened(0.08), &"box", Vector3(0.0, 1.27, -0.165), Vector3(0.28, 0.2, 0.02))
	b.add(FILTER, &"cylinder", Vector3(0.0, 1.14, -0.24), Vector3(0.14, 0.14, 0.14), Vector3(PI * 0.5, 0.0, 0.0))
	b.add(FILTER.darkened(0.3), &"cylinder", Vector3(0.0, 1.14, -0.32), Vector3(0.1, 0.02, 0.1), Vector3(PI * 0.5, 0.0, 0.0))
	for sx: float in [-1.0, 1.0]:
		b.add(FILTER, &"cylinder", Vector3(sx * 0.19, 1.16, -0.1), Vector3(0.1, 0.1, 0.1), Vector3(0.0, 0.0, PI * 0.5))
		# Breathing hoses from the mask down into the chest.
		b.hose(HOSE, Vector3(sx * 0.21, 1.1, -0.08), Vector3(sx * 0.2, 0.82, -0.25), 0.035, 3)
	return b.commit(body_material())


## Its three glowing orange-red eyes on the mask: two side by side and one above them.
static func _eyes() -> ArrayMesh:
	var b := ColorBatch.new()
	for p: Vector3 in [Vector3(-0.075, 1.27, -0.178), Vector3(0.075, 1.27, -0.178), Vector3(0.0, 1.34, -0.178)]:
		b.add(EYE, &"cylinder", p, Vector3(0.06, 0.02, 0.06), Vector3(PI * 0.5, 0.0, 0.0))
	return b.commit(eye_material(false))


## An arm in its shoulder's space (hanging down at pitch 0, its forearm bent forward): the big upper arm, the elbow, the
## forearm in its bracer (the blade's mount) and the fist. `side` -1 left, 1 right.
static func _arm(side: float) -> ArrayMesh:
	var b := ColorBatch.new()
	var elbow := Vector3(side * 0.04, -0.42, 0.02)
	var hand: Vector3 = elbow + _forearm_dir() * 0.4
	b.strut(SKIN, Vector3.ZERO, elbow, 0.2)
	b.add(SKIN, &"dome", Vector3(0.0, 0.02, 0.0), Vector3(0.26, 0.16, 0.26), Vector3(PI, 0.0, 0.0))
	b.add(SKIN_DARK, &"box", elbow, Vector3(0.17, 0.17, 0.17))
	b.strut(SKIN, elbow, hand, 0.15)
	# The bracer over the forearm, riveted, and the fist.
	var mid: Vector3 = (elbow + hand) * 0.5
	b.strut(BRACER, elbow + _forearm_dir() * 0.04, hand - _forearm_dir() * 0.02, 0.21)
	for k: int in 3:
		b.add(RIVET, &"box", mid + _forearm_dir() * (-0.1 + k * 0.1) + Vector3(side * 0.106, 0.0, 0.0), Vector3(0.02, 0.03, 0.03))
	b.add(SKIN_DARK, &"box", hand + _forearm_dir() * 0.07, Vector3(0.14, 0.15, 0.14))
	return b.commit(body_material())


## A blade in its shoulder's space: a long serrated cleaver fixed along the outside of the bracer, from past the elbow to
## well past the fist, its teeth along its back edge. `side` -1 left, 1 right.
static func _blade(side: float) -> ArrayMesh:
	var b := ColorBatch.new()
	var dir: Vector3 = _forearm_dir()
	var elbow := Vector3(side * 0.04, -0.42, 0.02)
	var from: Vector3 = elbow - dir * 0.38 + Vector3(side * 0.13, 0.0, 0.0)
	var to: Vector3 = elbow + dir * 1.12 + Vector3(side * 0.13, 0.0, 0.0)
	# The blade's flat face lies in the plane of the forearm and the arm's up: wide across `up`, thin across x.
	var up: Vector3 = Vector3(1.0, 0.0, 0.0).cross(dir).normalized()
	var length: float = from.distance_to(to)
	var basis := Basis(Vector3(1.0, 0.0, 0.0), up, -dir)
	var center: Vector3 = (from + to) * 0.5 + up * 0.04
	b.add_basis(BLADE, &"box", center, basis * Basis.from_scale(Vector3(0.035, 0.2, length)))
	# Its tip: a slanted cut forward.
	b.add_basis(BLADE, &"box", to + dir * 0.08 - up * 0.02, basis * Basis(Vector3(1.0, 0.0, 0.0), 0.6) * Basis.from_scale(Vector3(0.035, 0.16, 0.2)))
	# The serrated back edge: teeth along it.
	for k: int in 9:
		var at: Vector3 = from.lerp(to, 0.08 + 0.1 * k) + up * 0.15
		b.add_basis(BLADE, &"spike", at, basis * Basis(Vector3(1.0, 0.0, 0.0), -0.5) * Basis.from_scale(Vector3(0.035, 0.09, 0.05)))
	return b.commit(blade_material(false))


## The forearm's direction from the elbow, in the shoulder's space at pitch 0: forward and a little down.
static func _forearm_dir() -> Vector3:
	return Vector3(0.0, -0.22, -0.975).normalized()


## A unit primitive (1 x 1 x 1): a box, a cylinder along y, a dome (a half sphere standing on its base), a four-sided spike
## pointing along +y.
static func _prim(kind: StringName) -> Mesh:
	if _prims.has(kind):
		return _prims[kind]
	var mesh: PrimitiveMesh
	match kind:
		&"box":
			var bm := BoxMesh.new()
			bm.size = Vector3.ONE
			mesh = bm
		&"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 12
			c.rings = 1
			mesh = c
		&"dome":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.is_hemisphere = true
			s.radial_segments = 10
			s.rings = 3
			mesh = s
		&"spike":
			var sp := CylinderMesh.new()
			sp.top_radius = 0.0
			sp.bottom_radius = 0.5
			sp.height = 1.0
			sp.radial_segments = 4
			sp.rings = 1
			mesh = sp
	_prims[kind] = mesh
	return mesh


## A rotation that turns +y toward `dir` (for struts and hoses).
static func toward(dir: Vector3) -> Vector3:
	var d: Vector3 = dir.normalized()
	if d.is_equal_approx(Vector3.UP) or d.length_squared() < 0.0001:
		return Vector3.ZERO
	if d.is_equal_approx(Vector3.DOWN):
		return Vector3(PI, 0.0, 0.0)
	var axis: Vector3 = Vector3.UP.cross(d).normalized()
	return Basis(axis, Vector3.UP.angle_to(d)).get_euler()


## Merges primitives into one surface in vertex colours under one material (one draw call whatever its colours).
class ColorBatch:
	var _st := SurfaceTool.new()

	func _init() -> void:
		_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## A primitive (HunterModel._prim) of `size` centred at `center`, rotated by `rotation` (Euler, radians), in `color`.
	func add(color: Color, kind: StringName, center: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
		add_basis(color, kind, center, Basis.from_euler(rotation) * Basis.from_scale(size))

	## A primitive placed by `basis` (its rotation and scale) at `center`.
	func add_basis(color: Color, kind: StringName, center: Vector3, basis: Basis) -> void:
		var mesh: Mesh = HunterModel._prim(kind)
		var xform := Transform3D(basis, center)
		var arrays: Array = mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var normal_basis: Basis = basis.inverse().transposed()
		_st.set_color(color)
		for i: int in idx:
			_st.set_normal((normal_basis * normals[i]).normalized())
			_st.add_vertex(xform * verts[i])

	## A round strut `thick` across from `a` to `c`.
	func strut(color: Color, a: Vector3, c: Vector3, thick: float) -> void:
		add(color, &"cylinder", (a + c) * 0.5, Vector3(thick, a.distance_to(c), thick), HunterModel.toward(c - a))

	## A ribbed hose from `a` to `c`, `radius` round, sagging a little, in `segments` pieces with a band at each joint.
	func hose(color: Color, a: Vector3, c: Vector3, radius: float, segments: int) -> void:
		var sag := Vector3(0.0, -0.06, 0.0)
		var prev: Vector3 = a
		for k: int in segments:
			var u: float = float(k + 1) / segments
			var p: Vector3 = a.lerp(c, u) + sag * sin(PI * u)
			strut(color, prev, p, radius * 2.0)
			add(color.lightened(0.12), &"cylinder", p, Vector3(radius * 2.5, 0.025, radius * 2.5), HunterModel.toward(p - prev))
			prev = p

	func commit(material: Material) -> ArrayMesh:
		var mesh: ArrayMesh = _st.commit()
		mesh.surface_set_material(0, material)
		return mesh
