class_name CarPassenger
extends Node3D
## The sports car's passenger in the Gangland outro (the owner, October 10, 2026: "in the seat next to them, a
## screech is sitting nice and cute on the seat"; then: "make it look like the other ones pretty much, but ...
## still have it sit there. And when the player character comes in, the screech and the player character nod at
## each other"): one of the sewer screeches, the very body they have in play (ScreechModel.mesh(): its head and
## snout, its small glowing eyes, its spines, its talons, its long tail, in the zone's look, calm), sitting up on
## its haunches on the passenger seat like a rat (sitting_meshes: the same triangles, posed). It sits facing
## ahead, breathing, its tail's tip twitching; as the runner gets in it looks round at them, its head tilting,
## and once they're sat it nods to them. A child of the car (it rides along), moved by the cinematic's clock
## (update): everything is worked out from the time. Visual only.
## DESIGN-TBD (docs/questions/f2d.md): its pose, its size and its greeting.

## Its size (the fight's creatures are 0.7).
const SIZE: float = 0.55
## The pose (in ScreechModel's mesh, lying: facing -z, its feet on y = 0): its body tips up this far about its
## hind hips, hunched; its head is turned back to look ahead (tipped up a little), its front paws held up in
## front of its chest and its front legs tucked under it, its hind legs reach forward to the seat, and its tail
## lies back along the seat, curling round toward the driver (degrees: forward of straight down for the limbs;
## round, at its tip, for the tail).
const SIT_UP_DEGREES: float = 45.0
const HIPS := Vector3(0.0, 0.2, 0.22)
const NECK := Vector3(0.0, 0.27, -0.24)
const HEAD_UP: float = 6.0
const SHOULDER := Vector3(0.0, 0.27, -0.25)
const ARM_HANG: float = 50.0
const FRONT_HIP := Vector3(0.0, 0.22, -0.17)
const FRONT_LEG_HANG: float = -25.0
const HIND_HIP := Vector3(0.0, 0.22, 0.22)
const HIND_LEG_REACH: float = 56.0
const TAIL_ROOT := Vector3(0.0, 0.24, 0.38)
const TAIL_CURL: float = -100.0
## Each limb's lie in the mesh (forward of straight down, degrees): the arms reach forward to swipe, the legs
## stand nearly straight; and the tail's slope down from its root.
const ARM_LIE: float = 55.7
const LEG_LIE: float = 8.5
const TAIL_SLOPE: float = 15.8
## It looks round toward the driver: its body turns this far, its head this much further, tilting this far,
## this often.
const BODY_TURN: float = 15.0
const HEAD_TURN: float = 38.0
const TILT_DEGREES: float = 10.0
const TILT_RATE: float = 0.4
## Its breath (a share of its height, Hz).
const BREATH: float = 0.025
const BREATH_RATE: float = 0.6
## Its nod: its head dips this far, over this long.
const NOD_DEGREES: float = 24.0
const NOD_SECONDS: float = 0.7
## Its legs and tail move a little (ScreechModel's scurry), as a calm screech's do.
const SCURRY: float = 0.05

static var _body_mesh: ArrayMesh
static var _head_mesh: ArrayMesh
static var _neck_sat := Vector3.ZERO

## Its body and its head (one mesh each, the same material: the head turns and nods on its own).
var screech: MeshInstance3D
var head: MeshInstance3D
## Where it sits (car space: its hips on the passenger seat's cushion).
var seat := Vector3.ZERO
## Now: how far round it's looking (0-1) and how far its head is down in its nod (0-1).
var looking: float = 0.0
var nodding: float = 0.0


## Builds it on the passenger seat of a car of `car_size`, in the zone's screech look (`variant`).
func setup(car_size: Vector3, variant: StringName) -> void:
	name = "Passenger"
	var cushion: Vector3 = SportsCarModel.seat_of(car_size)
	# The passenger's seat is the driver's mirrored; it sits back on the cushion.
	seat = Vector3(-cushion.x, cushion.y, cushion.z + 0.06 * SportsCarModel.scale_of(car_size).z)
	sitting_meshes()
	var material: ShaderMaterial = ScreechModel.material(variant)
	screech = _part("Screech", _body_mesh, material)
	head = _part("Head", _head_mesh, material)
	update(0.0, INF, INF)


func _part(part_name: String, mesh: ArrayMesh, material: ShaderMaterial) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = part_name
	m.mesh = mesh
	m.material_override = material
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.set_instance_shader_parameter(&"seed", 4.2)
	m.set_instance_shader_parameter(&"bristle", 0.0)
	m.set_instance_shader_parameter(&"swipe", 0.0)
	m.set_instance_shader_parameter(&"scurry", SCURRY)
	return m


## Poses it at time `t`: looking round at the driver from `look_at` (s), nodding to them at `nod_at` (s).
func update(t: float, look_at: float, nod_at: float) -> void:
	looking = smoothstep(look_at, look_at + 0.7, t)
	var u: float = (t - nod_at) / NOD_SECONDS
	nodding = sin(PI * u) if u > 0.0 and u < 1.0 else 0.0
	var breath: float = 1.0 + BREATH * sin(TAU * BREATH_RATE * t)
	# Its hips on the seat, turned about them; sized, breathing.
	var hips := Vector3(HIPS.x, 0.0, HIPS.z)
	var body := Transform3D(Basis(Vector3.UP, deg_to_rad(BODY_TURN) * looking), seat) \
		* Transform3D(Basis.from_scale(Vector3(SIZE, SIZE * breath, SIZE)), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -hips)
	screech.transform = body
	# Its head turns further, tilting curiously (still while it nods), and dips in its nod.
	var since: float = t - look_at if looking > 0.0 else 0.0
	var tilt: float = deg_to_rad(TILT_DEGREES) * looking * (1.0 - nodding) * sin(TAU * TILT_RATE * since)
	var turn := Basis(Vector3.UP, deg_to_rad(HEAD_TURN) * looking) * Basis(Vector3.FORWARD, tilt) \
		* Basis(Vector3.RIGHT, -deg_to_rad(NOD_DEGREES) * nodding)
	head.transform = body * Transform3D(turn, _neck_sat - turn * _neck_sat)


## Where its head turns and nods about (world space): its neck.
func neck_point() -> Vector3:
	return head.global_transform * _neck_sat


## The screech's body and head sitting (built once): ScreechModel.mesh()'s triangles, each part turned about its
## joint (the head, limbs and tail), then the whole body tipped up SIT_UP_DEGREES about its hips and set with its
## lowest point on y = 0. Its parts (UV.x), colours and shader are the screech's own, so it looks and breathes
## like one. [body, head].
static func sitting_meshes() -> Array[ArrayMesh]:
	if _body_mesh != null:
		return [_body_mesh, _head_mesh]
	var arrays: Array = ScreechModel.mesh().surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var sit := Basis(Vector3.RIGHT, deg_to_rad(SIT_UP_DEGREES))
	var posed := PackedVector3Array()
	var turned := PackedVector3Array()
	var low: float = INF
	for i: int in verts.size():
		var part: int = int(roundf(uvs[i].x))
		var w: float = uvs[i].y
		# Turned about its joint (in the lying mesh), so that once the body tips up it sits so.
		var joint: Vector3 = Vector3.ZERO
		var pre := Basis.IDENTITY
		match part:
			ScreechModel.Part.HEAD:
				joint = NECK
				pre = _pitch(HEAD_UP - SIT_UP_DEGREES)
			ScreechModel.Part.SWIPE_ARM, ScreechModel.Part.OTHER_ARM:
				joint = SHOULDER
				pre = _pitch(ARM_HANG - ARM_LIE - SIT_UP_DEGREES)
			ScreechModel.Part.LEG_FL, ScreechModel.Part.LEG_FR:
				joint = FRONT_HIP
				pre = _pitch(FRONT_LEG_HANG - LEG_LIE - SIT_UP_DEGREES)
			ScreechModel.Part.LEG_BL, ScreechModel.Part.LEG_BR:
				joint = HIND_HIP
				pre = _pitch(HIND_LEG_REACH - LEG_LIE - SIT_UP_DEGREES)
			ScreechModel.Part.TAIL:
				joint = TAIL_ROOT
				# Back along the seat, level (a backward slope turns up the other way round).
				pre = _pitch(-SIT_UP_DEGREES) * _pitch(-TAIL_SLOPE)
		var v: Vector3 = joint + pre * (verts[i] - joint)
		var n: Vector3 = pre * normals[i]
		v = HIPS + sit * (v - HIPS)
		n = sit * n
		if part == ScreechModel.Part.TAIL:
			# Curling round toward the driver along its length.
			var root: Vector3 = HIPS + sit * (TAIL_ROOT - HIPS)
			var curl := Basis(Vector3.UP, deg_to_rad(TAIL_CURL) * w)
			v = root + curl * (v - root)
			n = curl * n
		posed.append(v)
		turned.append(n.normalized())
		low = minf(low, v.y)
	var lift := Vector3(0.0, -low, 0.0)
	_neck_sat = HIPS + sit * (NECK - HIPS) + lift
	var body := SurfaceTool.new()
	var head_tool := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	head_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri: int in range(0, posed.size(), 3):
		var tool: SurfaceTool = head_tool if int(roundf(uvs[tri].x)) == ScreechModel.Part.HEAD else body
		for k: int in 3:
			tool.set_normal(turned[tri + k])
			tool.set_color(colors[tri + k])
			tool.set_uv(uvs[tri + k])
			tool.add_vertex(posed[tri + k] + lift)
	_body_mesh = body.commit()
	_head_mesh = head_tool.commit()
	return [_body_mesh, _head_mesh]


## A turn about x: + tips a thing pointing down forward (a limb), or a thing pointing ahead up (the head).
static func _pitch(degrees: float) -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(degrees))
