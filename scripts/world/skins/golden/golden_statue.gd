class_name GoldenStatue
extends RefCounted
## The Golden Zone's statue kit (GDD §9.11: "the Golden Zone's walls are lined with golden statues
## holding halberds, most of them decorative"): a gilded guardian in ceremonial armour (a long plated
## robe, a breastplate, pauldrons, a crested helmet with a visor slit) holding a halberd, built in code
## from mesh-kit pieces in reflective gold (MeshKit.PAT_GOLD), on a marble pedestal. Faceted, sleek
## plates rather than historical ornament: the elite's guard in the same future as every zone.
## Shared by:
## - the Golden Zone's skin (GoldenFacades), which lines the palaces' ledges with decorative statues:
##   mesh() gives one merged template per pose to append into a wall's mesh (cheap: a statue costs no
##   draw call of its own). They always stand above the wall-run band (GoldenSkin.statue_min_height:
##   safe things look safe).
## - the Gilded Sentinels (task C4): a live statue stands in a niche at wall-run height with glowing
##   red eyes and swings its halberd across its wall section and the outer lane. rig() builds it as
##   nodes (the body; the head on its neck pivot, with the eyes as their own mesh; each arm on its
##   shoulder pivot with the forearm on the elbow pivot; the halberd on the right hand's grip pivot),
##   so the enemy can pose and animate it (apply_pose() with a pose or a blend_poses() of two, or turn
##   the pivots itself) and give the eyes a glowing material of its own (the decorative eyes are dark
##   and unlit). niche() is a niche in the facades' look standing proud of any wall; recess() is the
##   one set into the wall that the Golden Zone's skins open where a live one stands
##   (GoldenSkin.note_wall_enemies), so nothing of the statue reaches out over the wall-run path.
##
## Statue space: the pedestal's foot at the origin (the statue's feet, without a pedestal), facing +Z,
## +Y up, metres at scale 1: the figure is STATURE tall (feet to crest), the halberd HALBERD_LENGTH
## long, the pedestal PEDESTAL_HEIGHT tall. The statue's right is -X (it faces +Z).
##
## Poses are Dictionaries of joint angles in degrees; a key left out keeps REST's value:
##   shoulder_r / shoulder_l  Vector3  the upper arm at the shoulder: x > 0 raises it forward, y turns
##                                     it (+ toward the statue's left), z > 0 swings it out to its side
##   elbow_r / elbow_l        float    the forearm's bend at the elbow (> 0 bends it forward)
##   grip                     Vector3  the halberd in the right hand (Euler degrees, YXZ as Godot's):
##                                     its shaft runs along the grip's +Y, the blade toward its +Z; with
##                                     the forearm pointing forward, (90, 0, 0) holds it upright
##   head                     Vector3  the helmet: x > 0 nods it down, y > 0 turns it to its left
## POSES: the decorative &"guard" (upright at its right side, the butt by its foot), &"vigil" (planted
## before it, both hands on the shaft) and &"salute" (upright, the left fist on its chest, head high);
## and two for a Sentinel's swing, &"raise" (drawn back high over its right shoulder) and &"strike"
## (chopped down in front of it and across toward its left, the blade down, into the lane before its
## niche), proposals for task C4 to tune.

enum Part { BODY, HEAD, EYES, UPPER_ARM_R, FOREARM_R, UPPER_ARM_L, FOREARM_L, HALBERD, PEDESTAL }

## The figure's height, feet to the top of the crest, at scale 1.
const STATURE: float = 2.6
const HALBERD_LENGTH: float = 2.95
## Where the right hand holds the shaft, from its butt.
const GRIP_AT: float = 1.46
const PEDESTAL_HEIGHT: float = 0.42
const PEDESTAL_SIZE := Vector3(0.66, PEDESTAL_HEIGHT, 0.56)
## Joints in figure space (feet at the origin): the shoulders (the right one at -X), the neck; the
## upper arm and forearm lengths (the hand's grip at the forearm's end).
const SHOULDER_R := Vector3(-0.3, 1.8, 0.0)
const SHOULDER_L := Vector3(0.3, 1.8, 0.0)
const NECK := Vector3(0.0, 1.95, 0.0)
const UPPER_ARM: float = 0.36
const FOREARM: float = 0.36
## The polish of its gold (MeshKit.PAT_GOLD's parameter): burnished plates, polished trims.
const POLISH_PLATE: float = 0.7
const POLISH_TRIM: float = 0.95

## DESIGN-TBD (docs/questions/h1.md): the live Sentinel's niche inside (recess(), lit): a chamber of warm stone rather than a black hole, so the
## gold statue and its red eyes read against it from far down the street (GDD §9.11, owner, October 8, 2026).
## Plain lit surfaces, never the glow channel (GDD §5: gold, stone and cloth never glow, and only hazards glow
## in a hazard's colours; the eyes' flare washes the niche red): the kit shades them at about 0.6 to 0.7 of
## these colours (kit_solid.gdshader), so on screen the back is a mid bronze and the sides, the surface seen
## through the opening from down the street, a little lighter, both darker than the gold they set off.
const LIT_BACK := Color(0.60, 0.44, 0.30)
const LIT_SIDES := Color(0.78, 0.60, 0.41)
const LIT_CEILING := Color(0.52, 0.38, 0.26)
const LIT_FLOOR := Color(0.9, 0.9, 0.9)
## How much of its colour the kit's shading leaves a lit surface facing the street, at the least.
const LIT_SHADE: float = 0.65

const REST: Dictionary = {"shoulder_r": Vector3(6.0, 0.0, 6.0), "elbow_r": 8.0, "shoulder_l": Vector3(6.0, 0.0, 6.0),
	"elbow_l": 8.0, "grip": Vector3(0.0, 0.0, 0.0), "head": Vector3.ZERO}
const POSES: Dictionary = {
	&"guard": {"shoulder_r": Vector3(16.0, 0.0, 8.0), "elbow_r": 74.0, "grip": Vector3(90.0, 0.0, 0.0),
		"shoulder_l": Vector3(4.0, 0.0, 7.0), "elbow_l": 14.0, "head": Vector3(4.0, 0.0, 0.0)},
	&"vigil": {"shoulder_r": Vector3(34.0, 22.0, -4.0), "elbow_r": 62.0, "grip": Vector3(90.0, -22.0, 0.0),
		"shoulder_l": Vector3(34.0, -22.0, -4.0), "elbow_l": 62.0, "head": Vector3(12.0, 0.0, 0.0)},
	&"salute": {"shoulder_r": Vector3(16.0, 0.0, 8.0), "elbow_r": 74.0, "grip": Vector3(90.0, 0.0, 0.0),
		"shoulder_l": Vector3(22.0, -38.0, -6.0), "elbow_l": 118.0, "head": Vector3(-6.0, 0.0, 0.0)},
	&"raise": {"shoulder_r": Vector3(150.0, 20.0, 18.0), "elbow_r": 40.0, "grip": Vector3(60.0, 0.0, 0.0),
		"shoulder_l": Vector3(30.0, 0.0, 12.0), "elbow_l": 40.0, "head": Vector3(-4.0, -12.0, 0.0)},
	&"strike": {"shoulder_r": Vector3(55.0, 30.0, -5.0), "elbow_r": 20.0, "grip": Vector3(200.0, 0.0, 0.0),
		"shoulder_l": Vector3(40.0, 10.0, 10.0), "elbow_l": 50.0, "head": Vector3(14.0, 18.0, 0.0)},
}
## The decorative poses the skin picks from.
const DECORATIVE: Array[StringName] = [&"guard", &"vigil", &"salute"]

var material: Material
var gold: Color
var stone: Color
## The visor slit of a decorative statue: dark bronze, unlit.
var eye_color: Color
var _parts: Dictionary = {}
var _merged: Dictionary = {}


## `p_material`: the solid kit material the statue is drawn with (a skin's solid_material(), or
## MeshKit.solid() outside the Golden Zone); `p_gold` its gold, `p_stone` its pedestal's marble.
func _init(p_material: Material = null, p_gold: Color = Color(0.74, 0.6, 0.35), p_stone: Color = Color(0.87, 0.86, 0.82)) -> void:
	material = p_material if p_material != null else MeshKit.solid()
	gold = p_gold
	stone = p_stone
	eye_color = Color(p_gold.r * 0.32, p_gold.g * 0.3, p_gold.b * 0.3)


## `pose` with every joint REST leaves out filled in.
static func full_pose(pose: Dictionary) -> Dictionary:
	var out: Dictionary = REST.duplicate()
	out.merge(pose, true)
	return out


## A pose between two (t 0 = a, 1 = b), joint by joint: for a Sentinel's wind-up and swing.
static func blend_poses(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var fa: Dictionary = full_pose(a)
	var fb: Dictionary = full_pose(b)
	var out: Dictionary = {}
	for key: String in fa:
		out[key] = lerp(fa[key], fb[key], t)
	return out


## Where each part sits for `pose`, in statue space (with or without the pedestal): {Part: Transform3D}.
## The meshes of part() placed by these make up the statue.
static func part_transforms(pose: Dictionary, with_pedestal: bool = true) -> Dictionary:
	var p: Dictionary = full_pose(pose)
	var feet := Transform3D(Basis.IDENTITY, Vector3(0.0, PEDESTAL_HEIGHT if with_pedestal else 0.0, 0.0))
	var out: Dictionary = {Part.BODY: feet, Part.PEDESTAL: Transform3D.IDENTITY}
	var head: Transform3D = feet * Transform3D(_joint_basis(p["head"], 1.0), NECK)
	out[Part.HEAD] = head
	out[Part.EYES] = head
	for right: bool in [true, false]:
		var shoulder: Vector3 = SHOULDER_R if right else SHOULDER_L
		var sv: Vector3 = p["shoulder_r" if right else "shoulder_l"]
		var upper: Transform3D = feet * Transform3D(_joint_basis(sv, -1.0 if right else 1.0), shoulder)
		var elbow: float = p["elbow_r" if right else "elbow_l"]
		var fore: Transform3D = upper * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-elbow)), Vector3(0.0, -UPPER_ARM, 0.0))
		out[Part.UPPER_ARM_R if right else Part.UPPER_ARM_L] = upper
		out[Part.FOREARM_R if right else Part.FOREARM_L] = fore
		if right:
			var g: Vector3 = p["grip"]
			var grip := Basis.from_euler(Vector3(deg_to_rad(g.x), deg_to_rad(g.y), deg_to_rad(g.z)))
			out[Part.HALBERD] = fore * Transform3D(grip, Vector3(0.0, -FOREARM, 0.0))
	return out


## A joint's rotation from a pose's angles (see the class notes); `out` is the side "out" points to
## (-1 for the right arm, whose side is -X; 1 for the left arm and the head).
static func _joint_basis(v: Vector3, out: float) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(-v.x), deg_to_rad(v.y), deg_to_rad(v.z * out)))


## One part's mesh in its own space (the joint at the origin; cached): the body and pedestal in
## figure and statue space, the head on its neck, an upper arm hanging from its shoulder (-Y), a
## forearm from its elbow with the hand's grip at -FOREARM, the halberd along +Y from its grip.
func part(which: Part) -> MeshLayer:
	if _parts.has(which):
		return _parts[which]
	var t := MeshLayer.new()
	match which:
		Part.BODY:
			_body(t)
		Part.HEAD:
			_head(t)
		Part.EYES:
			t.box(Vector3(-0.052, 0.2, 0.128), Vector3(0.07, 0.026, 0.02), eye_color, 0.0, MeshKit.PAT_PLAIN,
				MeshKit.FACE_PZ | MeshKit.FACE_PY)
			t.box(Vector3(0.052, 0.2, 0.128), Vector3(0.07, 0.026, 0.02), eye_color, 0.0, MeshKit.PAT_PLAIN,
				MeshKit.FACE_PZ | MeshKit.FACE_PY)
		Part.UPPER_ARM_R, Part.UPPER_ARM_L:
			t.box(Vector3(0.0, -UPPER_ARM * 0.5, 0.0), Vector3(0.13, UPPER_ARM + 0.04, 0.14), gold, 0.0, MeshKit.PAT_GOLD,
				MeshKit.ALL_FACES, POLISH_PLATE)
		Part.FOREARM_R, Part.FOREARM_L:
			t.box(Vector3(0.0, -FOREARM * 0.42, 0.0), Vector3(0.11, FOREARM * 0.84, 0.12), gold, 0.0, MeshKit.PAT_GOLD,
				MeshKit.ALL_FACES, POLISH_PLATE)
			t.box(Vector3(0.0, -FOREARM * 0.74, 0.0), Vector3(0.135, 0.08, 0.145), gold, 0.0, MeshKit.PAT_GOLD,
				MeshKit.ALL_FACES, POLISH_TRIM)
			t.box(Vector3(0.0, -FOREARM - 0.01, 0.0), Vector3(0.1, 0.11, 0.11), gold, 0.0, MeshKit.PAT_GOLD,
				MeshKit.ALL_FACES, POLISH_PLATE)
		Part.HALBERD:
			_halberd(t)
		Part.PEDESTAL:
			t.box(Vector3(0.0, PEDESTAL_HEIGHT * 0.4, 0.0), Vector3(PEDESTAL_SIZE.x, PEDESTAL_HEIGHT * 0.8, PEDESTAL_SIZE.z),
				stone, 0.0, MeshKit.PAT_MARBLE, MeshKit.NO_BOTTOM, 1.0)
			t.box(Vector3(0.0, PEDESTAL_HEIGHT * 0.9, 0.0), Vector3(PEDESTAL_SIZE.x + 0.06, PEDESTAL_HEIGHT * 0.2,
				PEDESTAL_SIZE.z + 0.06), gold, 0.0, MeshKit.PAT_GOLD, MeshKit.NO_BOTTOM, POLISH_TRIM)
	_parts[which] = t
	return t


## The whole statue in `pose` as one template in statue space (cached by pose): for a decorative
## statue, appended into a wall's mesh with MeshLayer.append(statue.mesh(pose), xform).
func mesh(pose: Dictionary, with_pedestal: bool = true) -> MeshLayer:
	var key: String = var_to_str(full_pose(pose)) + str(with_pedestal)
	if _merged.has(key):
		return _merged[key]
	var out := MeshLayer.new()
	var xforms: Dictionary = part_transforms(pose, with_pedestal)
	for which: Part in xforms:
		if which == Part.PEDESTAL and not with_pedestal:
			continue
		out.append(part(which), xforms[which])
	_merged[key] = out
	return out


## A decorative pose by name (POSES), for the skin.
static func pose_named(pose_name: StringName) -> Dictionary:
	return POSES.get(pose_name, {})


## A live statue as nodes under `parent` (for task C4), in `pose`: returns {&"root": the statue's
## Node3D (statue space; place and turn it), &"body", &"pedestal" (or null), &"head" (the neck pivot),
## &"eyes" (MeshInstance3D: give it a glowing material_override), &"arm_r" / &"arm_l" (shoulder
## pivots), &"elbow_r" / &"elbow_l" (elbow pivots), &"grip" (the right hand's pivot) and &"halberd"
## (MeshInstance3D)}. Turn the pivots with apply_pose(). Each part is one draw call (nine in all).
func rig(parent: Node3D, pose: Dictionary = {}, with_pedestal: bool = true) -> Dictionary:
	var root := Node3D.new()
	root.name = "Statue"
	parent.add_child(root)
	var nodes: Dictionary = {&"root": root, &"with_pedestal": with_pedestal}
	var feet := Node3D.new()
	feet.name = "Feet"
	feet.position = Vector3(0.0, PEDESTAL_HEIGHT if with_pedestal else 0.0, 0.0)
	root.add_child(feet)
	nodes[&"pedestal"] = _instance(root, Part.PEDESTAL, "Pedestal") if with_pedestal else null
	nodes[&"body"] = _instance(feet, Part.BODY, "Body")
	var head := _pivot(feet, "Head", NECK)
	nodes[&"head"] = head
	_instance(head, Part.HEAD, "Helmet")
	nodes[&"eyes"] = _instance(head, Part.EYES, "Eyes")
	for right: bool in [true, false]:
		var arm := _pivot(feet, "ArmR" if right else "ArmL", SHOULDER_R if right else SHOULDER_L)
		_instance(arm, Part.UPPER_ARM_R if right else Part.UPPER_ARM_L, "Upper")
		var elbow := _pivot(arm, "Elbow", Vector3(0.0, -UPPER_ARM, 0.0))
		_instance(elbow, Part.FOREARM_R if right else Part.FOREARM_L, "Forearm")
		nodes[&"arm_r" if right else &"arm_l"] = arm
		nodes[&"elbow_r" if right else &"elbow_l"] = elbow
		if right:
			var grip := _pivot(elbow, "Grip", Vector3(0.0, -FOREARM, 0.0))
			nodes[&"grip"] = grip
			nodes[&"halberd"] = _instance(grip, Part.HALBERD, "Halberd")
	apply_pose(nodes, pose)
	return nodes


## Turns a rig()'s pivots to `pose` (their positions stay).
static func apply_pose(nodes: Dictionary, pose: Dictionary) -> void:
	var p: Dictionary = full_pose(pose)
	(nodes[&"head"] as Node3D).basis = _joint_basis(p["head"], 1.0)
	for right: bool in [true, false]:
		(nodes[&"arm_r" if right else &"arm_l"] as Node3D).basis = _joint_basis(p["shoulder_r" if right else "shoulder_l"],
			-1.0 if right else 1.0)
		(nodes[&"elbow_r" if right else &"elbow_l"] as Node3D).basis = Basis(Vector3.RIGHT,
			deg_to_rad(-float(p["elbow_r" if right else "elbow_l"])))
	var g: Vector3 = p["grip"]
	(nodes[&"grip"] as Node3D).basis = Basis.from_euler(Vector3(deg_to_rad(g.x), deg_to_rad(g.y), deg_to_rad(g.z)))


## The niche a live statue stands in (task C4), in the facades' look: a dark recess panel under a
## rounded head, framed in polished gold, with a marble sill; `width` and `height` of the opening
## (metres, sill to the top of its head). Niche space: the wall face at z = 0, the niche facing +Z
## (turn it to face the street like a statue); the pieces stand a few centimetres proud of the wall,
## so they overlay any facade (the skin doesn't know where a Sentinel stands, like a window cyborg's
## window). One template per size, for the solid material.
func niche(width: float, height: float) -> MeshLayer:
	var key: String = "niche_%s_%s" % [width, height]
	if _merged.has(key):
		return _merged[key]
	var t := MeshLayer.new()
	var hw: float = width * 0.5
	var spring: float = maxf(height - hw, 0.2)
	var dark := Color(0.13, 0.11, 0.1)
	var z: float = 0.03
	# The recess: its straight part and its rounded head as a fan of slices.
	t.rect(Vector3(-hw, 0.0, z), Vector3(width, 0.0, 0.0), Vector3(0.0, spring, 0.0), dark, 0.0, MeshKit.PAT_MARBLE)
	var steps: int = 10
	for i: int in steps:
		var a0: float = PI * float(i) / steps
		var a1: float = PI * float(i + 1) / steps
		var p0 := Vector3(cos(a0) * hw, spring + sin(a0) * hw, z)
		var p1 := Vector3(cos(a1) * hw, spring + sin(a1) * hw, z)
		t.quad(Vector3(0.0, spring, z), p1, p0, p0, dark, 0.0, MeshKit.PAT_MARBLE)
	# The gold frame round it: two jambs and the arch's rim.
	var f: float = 0.14
	for sx: float in [-1.0, 1.0]:
		t.box(Vector3(sx * (hw + f * 0.5), spring * 0.5, z + 0.03), Vector3(f, spring, 0.08), gold, 0.0, MeshKit.PAT_GOLD,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, POLISH_TRIM)
	for i: int in steps:
		var a: float = PI * (float(i) + 0.5) / steps
		var r: float = hw + f * 0.5
		var seg := Basis(Vector3.BACK, a).scaled_local(Vector3(f, PI * r / steps + 0.02, 0.08))
		t.box_xform(Transform3D(seg, Vector3(cos(a) * r, spring + sin(a) * r, z + 0.03)), gold, 0.0, MeshKit.PAT_GOLD,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, POLISH_TRIM)
	# The sill.
	t.box(Vector3(0.0, -0.06, z + 0.12), Vector3(width + f * 2.0 + 0.1, 0.12, 0.3), stone, 0.0, MeshKit.PAT_MARBLE,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 1.0)
	_merged[key] = t
	return t


## The niche a live Gilded Sentinel stands in, set into the wall (task C4; GildedSentinel): the Golden
## Zone's skins leave its opening out of the wall face (GoldenSkin.note_wall_enemies) and append this
## there. Niche space as niche(): the wall face at z = 0, the opening facing +Z, `width` wide and from
## its floor (y = 0) up `height`, the recess `depth` deep behind the face (-Z): a dark back and sides, a
## marble floor, and on the face a polished gold frame whose spandrels round the opening's top into an
## arch, and a marble sill line. Everything on the face stands at most a few centimetres proud, so
## nothing of it reaches out over the wall-run path. One template per size, for the solid material.
func recess(width: float, height: float, depth: float, lit: bool = false) -> MeshLayer:
	var key: String = "recess_%s_%s_%s_%s" % [width, height, depth, lit]
	if _merged.has(key):
		return _merged[key]
	var t := MeshLayer.new()
	var hw: float = width * 0.5
	var back := Color(0.07, 0.06, 0.055)
	var sides := Color(0.15, 0.13, 0.11)
	var ceiling := back
	var floor_color: Color = stone * Color(0.7, 0.7, 0.7)
	if lit:
		back = LIT_BACK
		sides = LIT_SIDES
		ceiling = LIT_CEILING
		floor_color = stone * LIT_FLOOR
	# The recess: back, sides, ceiling (all facing the opening) and the marble floor.
	t.rect(Vector3(-hw, 0.0, -depth), Vector3(width, 0.0, 0.0), Vector3(0.0, height, 0.0), back, 0.0, MeshKit.PAT_MARBLE)
	t.rect(Vector3(-hw, 0.0, -depth), Vector3(0.0, height, 0.0), Vector3(0.0, 0.0, depth), sides, 0.0, MeshKit.PAT_MARBLE)
	t.rect(Vector3(hw, 0.0, -depth), Vector3(0.0, 0.0, depth), Vector3(0.0, height, 0.0), sides, 0.0, MeshKit.PAT_MARBLE)
	t.rect(Vector3(-hw, height, -depth), Vector3(width, 0.0, 0.0), Vector3(0.0, 0.0, depth), ceiling, 0.0, MeshKit.PAT_MARBLE)
	t.rect(Vector3(-hw, 0.0, -depth), Vector3(0.0, 0.0, depth), Vector3(width, 0.0, 0.0), floor_color, 0.0, MeshKit.PAT_MARBLE)
	# The gold frame on the face: jambs and lintel, a few centimetres proud.
	var f: float = 0.12
	var z: float = 0.012
	for sx: float in [-1.0, 1.0]:
		t.box(Vector3(sx * (hw + f * 0.5), (height + f) * 0.5 - f * 0.5, z), Vector3(f, height + f, 0.024), gold, 0.0,
			MeshKit.PAT_GOLD, MeshKit.FACE_PZ | MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY, POLISH_TRIM)
	t.box(Vector3(0.0, height + f * 0.5, z), Vector3(width + f * 2.0, f, 0.024), gold, 0.0, MeshKit.PAT_GOLD,
		MeshKit.FACE_PZ | MeshKit.FACE_PY | MeshKit.FACE_NY, POLISH_TRIM)
	# The spandrels: gold filling the opening's top corners outside a half circle, so it reads as an arch.
	var spring: float = maxf(height - hw, 0.0)
	var steps: int = 8
	for sx: float in [-1.0, 1.0]:
		var corner := Vector3(sx * hw, height, z)
		for i: int in steps:
			var a0: float = PI * 0.5 * float(i) / steps
			var a1: float = PI * 0.5 * float(i + 1) / steps
			var p0 := Vector3(sx * cos(a0) * hw, spring + sin(a0) * hw, z)
			var p1 := Vector3(sx * cos(a1) * hw, spring + sin(a1) * hw, z)
			_tri(t, corner, p0, p1, gold)
			_tri(t, corner, p1, p0, gold)
	# The sill line under the opening.
	t.box(Vector3(0.0, -0.05, z), Vector3(width + f * 2.0, 0.1, 0.024), stone, 0.0, MeshKit.PAT_MARBLE,
		MeshKit.FACE_PZ | MeshKit.FACE_PY, 1.0)
	_merged[key] = t
	return t


func _pivot(parent: Node3D, node_name: String, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = at
	parent.add_child(pivot)
	return pivot


func _instance(parent: Node3D, which: Part, node_name: String) -> MeshInstance3D:
	var batch := MeshBatch.new()
	batch.layer(material).append(part(which))
	return batch.commit(parent, node_name)


# --- The parts --------------------------------------------------------------------------------

## The body in figure space (feet at the origin): a long plated robe widening to the hem, boots at its
## front, a belt, a tapered breastplate with a ridge, pauldrons and the gorget.
func _body(t: MeshLayer) -> void:
	_frustum(t, 0.0, 1.22, Vector2(0.34, 0.3), Vector2(0.24, 0.19), 8, gold, POLISH_PLATE, false)
	# Plated robe: two darker bands round it.
	_frustum(t, 0.36, 0.42, Vector2(0.315, 0.28), Vector2(0.31, 0.275), 8, gold * Color(0.8, 0.8, 0.8), POLISH_TRIM, false)
	_frustum(t, 0.78, 0.84, Vector2(0.285, 0.245), Vector2(0.28, 0.24), 8, gold * Color(0.8, 0.8, 0.8), POLISH_TRIM, false)
	for sx: float in [-1.0, 1.0]:
		t.box(Vector3(sx * 0.11, 0.06, 0.27), Vector3(0.12, 0.12, 0.16), gold * Color(0.85, 0.85, 0.85), 0.0,
			MeshKit.PAT_GOLD, MeshKit.NO_BOTTOM, POLISH_PLATE)
	_frustum(t, 1.18, 1.3, Vector2(0.26, 0.21), Vector2(0.26, 0.21), 8, gold * Color(0.78, 0.78, 0.78), POLISH_TRIM, false)
	_frustum(t, 1.28, 1.84, Vector2(0.22, 0.15), Vector2(0.29, 0.17), 4, gold, POLISH_PLATE, true)
	t.box(Vector3(0.0, 1.56, 0.16), Vector3(0.05, 0.48, 0.05), gold, 0.0, MeshKit.PAT_GOLD,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, POLISH_TRIM)
	for sx: float in [-1.0, 1.0]:
		var pauldron := Basis(Vector3.BACK, sx * 0.3).scaled_local(Vector3(0.22, 0.1, 0.3))
		t.box_xform(Transform3D(pauldron, Vector3(sx * 0.3, 1.84, 0.0)), gold, 0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES,
			POLISH_TRIM)
	_frustum(t, 1.82, 1.97, Vector2(0.11, 0.1), Vector2(0.09, 0.085), 6, gold * Color(0.8, 0.8, 0.8), POLISH_PLATE, false)


## The helmet on its neck pivot: a faceted dome with a visor plate at the front, cheek guards and a
## swept crest.
func _head(t: MeshLayer) -> void:
	_frustum(t, 0.0, 0.3, Vector2(0.14, 0.15), Vector2(0.12, 0.13), 6, gold, POLISH_PLATE, true)
	_frustum(t, 0.3, 0.4, Vector2(0.12, 0.13), Vector2(0.05, 0.06), 6, gold, POLISH_PLATE, true)
	t.box(Vector3(0.0, 0.2, 0.118), Vector3(0.22, 0.07, 0.03), gold * Color(0.85, 0.85, 0.85), 0.0, MeshKit.PAT_GOLD,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, POLISH_TRIM)
	var crest := Basis(Vector3.RIGHT, -0.25).scaled_local(Vector3(0.035, 0.12, 0.36))
	t.box_xform(Transform3D(crest, Vector3(0.0, 0.43, -0.03)), gold, 0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES, POLISH_TRIM)


## The halberd along +Y from its grip (the butt at -GRIP_AT): a slim shaft with gold collars, a
## crescent blade toward +Z, a back spike and a long top spike.
func _halberd(t: MeshLayer) -> void:
	var y0: float = -GRIP_AT
	var y1: float = HALBERD_LENGTH - GRIP_AT
	t.prism(Vector3(0.0, y0, 0.0), 0.024, y1 - y0 - 0.3, 6, gold * Color(0.82, 0.82, 0.82), 0.0, MeshKit.PAT_GOLD, false,
		POLISH_PLATE)
	for cy: float in [y0, y1 - 0.62, y1 - 0.36]:
		t.prism(Vector3(0.0, cy, 0.0), 0.04, 0.05, 6, gold, 0.0, MeshKit.PAT_GOLD, true, POLISH_TRIM)
	# The blade: a crescent in the shaft's plane (both faces), toward +Z.
	var b0: float = y1 - 0.62
	var pts: Array[Vector3] = [Vector3(0.0, b0, 0.0), Vector3(0.0, b0 - 0.1, 0.2), Vector3(0.0, b0 + 0.06, 0.34),
		Vector3(0.0, b0 + 0.22, 0.36), Vector3(0.0, b0 + 0.36, 0.3), Vector3(0.0, b0 + 0.3, 0.0)]
	for i: int in range(1, pts.size() - 1):
		_tri(t, pts[0], pts[i], pts[i + 1], gold)
		_tri(t, pts[0], pts[i + 1], pts[i], gold)
	# The back spike, and the top spike.
	var h: float = b0 + 0.12
	_tri(t, Vector3(0.0, h, 0.0), Vector3(0.0, h + 0.1, 0.0), Vector3(0.0, h + 0.02, -0.2), gold)
	_tri(t, Vector3(0.0, h, 0.0), Vector3(0.0, h + 0.02, -0.2), Vector3(0.0, h + 0.1, 0.0), gold)
	_frustum(t, y1 - 0.3, y1, Vector2(0.035, 0.035), Vector2(0.004, 0.004), 4, gold, POLISH_TRIM, false)


## A tapered prism of `sides` faces from y0 to y1 (elliptical rings: radii x and z at each end), in
## polished gold; `cap` closes its top.
func _frustum(t: MeshLayer, y0: float, y1: float, r0: Vector2, r1: Vector2, sides: int, color: Color, polish: float,
		cap: bool) -> void:
	var col := Color(color, 0.0)
	for i: int in sides:
		var a0: float = TAU * (float(i) + 0.5) / sides
		var a1: float = TAU * (float(i) + 1.5) / sides
		var p0 := Vector3(cos(a0) * r0.x, y0, sin(a0) * r0.y)
		var p1 := Vector3(cos(a1) * r0.x, y0, sin(a1) * r0.y)
		var q0 := Vector3(cos(a0) * r1.x, y1, sin(a0) * r1.y)
		var q1 := Vector3(cos(a1) * r1.x, y1, sin(a1) * r1.y)
		t.quad(p1, q1, q0, p0, col, 0.0, MeshKit.PAT_GOLD, polish)
		if cap:
			_tri(t, Vector3(0.0, y1, 0.0), q0, q1, color, polish)


func _tri(t: MeshLayer, a: Vector3, b: Vector3, c: Vector3, color: Color, polish: float = POLISH_TRIM) -> void:
	t.verts.append_array(PackedVector3Array([a, b, c]))
	t.colors.append_array(MeshKit.filled_colors(Color(color, 0.0), 3))
	t.uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2(0.0, 1.0), Vector2(1.0, 1.0)]))
	t.uv2s.append_array(MeshKit.filled_uv2(Vector2(MeshKit.PAT_GOLD, polish), 3))
