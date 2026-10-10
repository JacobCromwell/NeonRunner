class_name CarPassenger
extends Node3D
## The sports car's passenger in the Gangland outro (the owner, October 10, 2026: "in the seat next to them, a
## screech is sitting nice and cute on the seat"): a sewer screech, small, sat up on the passenger seat like a
## pet. It's a screech as a pet (pet_mesh): ScreechModel's skin, parts and shader (so it moves like one), sitting
## up on its haunches like a meerkat, with a big round head, big round shining eyes, a short snout and big ears,
## short soft spines laid back along it, its front paws held up in front of its chest, its tail curled round on
## the seat, and no fangs or talons. It sits facing ahead, breathing, the tip of its tail twitching; as the
## runner gets in it looks round at them with a curious tilt of its head, and as they sit down it gives a happy
## little wriggle and lifts a paw to them. A child of the car (it rides
## along), moved by the cinematic's clock (update): everything is worked out from the time. Visual only.
## DESIGN-TBD (docs/questions/f2d.md): its look, its pose and its greeting.

## Its size (the fight's creatures are 0.7) and how far it sits up (its body tipped up about its hind legs; its
## head, paws, hind feet and tail are built for that, pet_mesh).
const SIZE: float = 0.58
const SIT_UP_DEGREES: float = 60.0
## Where its hind legs are along its body (the mesh's units: it faces -z, about 1.4 m long at size 1).
const HIND := Vector3(0.0, 0.0, 0.22)
## It looks round this far toward the driver, its head tilting this far, this often.
const LOOK_DEGREES: float = 50.0
const TILT_DEGREES: float = 12.0
const TILT_RATE: float = 0.45
## Its breath (a share of its height, Hz).
const BREATH: float = 0.025
const BREATH_RATE: float = 0.6
## The wriggle: a hop this high, over this long, a paw raised in greeting for that long (ScreechModel's swipe,
## held at the top of its raise: the strike never comes).
const HOP: float = 0.02
const HOP_SECONDS: float = 0.8
const WAVE_RAISE: float = 0.42
## Its eyes' and spines' glow (ScreechModel's emission_strength is 2.4).
const GLOW: float = 1.0
## Its colours beyond ScreechModel's: its spines' tips (soft, barely glowing: nothing about it looks deadly), its
## eyes' pupils and their highlights, and its nose.
const SOFT_TIP := Color(0.7, 0.36, 0.26, 0.2)
const PUPIL := Color(0.03, 0.02, 0.03, 0.0)
const SPARKLE := Color(1.0, 1.0, 1.0, 1.0)
const NOSE := Color(0.55, 0.28, 0.32, 0.0)

static var _pet_mesh: ArrayMesh

var screech: MeshInstance3D
## Where it sits (car space: its hind legs on the passenger seat's cushion).
var seat := Vector3.ZERO
## Now: how far round it's looking (0-1) and how far through its wriggle (0-1, 0 before and after).
var looking: float = 0.0
var wriggle: float = 0.0

var _material: ShaderMaterial


## Builds it on the passenger seat of a car of `car_size`, in the zone's screech look (`variant`).
func setup(car_size: Vector3, variant: StringName) -> void:
	name = "Passenger"
	var cushion: Vector3 = SportsCarModel.seat_of(car_size)
	# The passenger's seat is the driver's mirrored; it sits back on the cushion.
	seat = Vector3(-cushion.x, cushion.y, cushion.z + 0.06 * SportsCarModel.scale_of(car_size).z)
	screech = MeshInstance3D.new()
	screech.name = "Screech"
	screech.mesh = pet_mesh()
	_material = ScreechModel.material(variant).duplicate() as ShaderMaterial
	_material.set_shader_parameter(&"emission_strength", GLOW)
	screech.material_override = _material
	screech.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screech)
	screech.set_instance_shader_parameter(&"seed", 4.2)
	screech.set_instance_shader_parameter(&"bristle", 0.0)
	update(0.0, INF, INF)


## Poses it at time `t`: looking round at the driver from `look_at` (s), wriggling from `wriggle_at` (s).
func update(t: float, look_at: float, wriggle_at: float) -> void:
	looking = smoothstep(look_at, look_at + 0.7, t)
	var w: float = (t - wriggle_at) / HOP_SECONDS
	wriggle = sin(PI * w) if w > 0.0 and w < 1.0 else 0.0
	var tilt: float = deg_to_rad(TILT_DEGREES) * looking * sin(TAU * TILT_RATE * (t - look_at))
	var turn: float = deg_to_rad(LOOK_DEGREES) * looking
	var breath: float = 1.0 + BREATH * sin(TAU * BREATH_RATE * t)
	# Sat up about its hind legs, turned and tilted about them, its hind legs on the cushion.
	var sit := Basis(Vector3.RIGHT, deg_to_rad(SIT_UP_DEGREES))
	var hind: Vector3 = HIND * SIZE
	var sat := Transform3D(sit, hind - sit * hind)
	var look := Transform3D(Basis(Vector3.UP, turn) * Basis(Vector3.FORWARD, tilt), Vector3.ZERO)
	var sized := Transform3D(Basis.from_scale(Vector3(SIZE, SIZE * breath, SIZE)), Vector3.ZERO)
	screech.transform = Transform3D(Basis.IDENTITY, seat + Vector3(0.0, HOP * wriggle, 0.0)) * look \
		* Transform3D(Basis.IDENTITY, -hind) * sat * sized
	screech.set_instance_shader_parameter(&"scurry", 0.06 + 0.5 * wriggle)
	screech.set_instance_shader_parameter(&"swipe", WAVE_RAISE * smoothstep(0.0, 0.35, wriggle))


## The screech as a pet, built once (about 400 triangles) with ScreechModel's mesh helpers, skin and parts (UV.x,
## so its shader moves it the same: its legs paddling, its tail's tip twitching, the swiping arm lifting a paw
## in greeting). Its body, spines and haunches are built lying, as a screech's are (facing -z, its feet on
## y = 0), and sit up SIT_UP_DEGREES about HIND; its head, front paws, hind feet and tail are placed as they
## are once it sits (level, hanging, flat on the seat), then turned back.
static func pet_mesh() -> ArrayMesh:
	if _pet_mesh != null:
		return _pet_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var skin: Color = ScreechModel.SKIN
	var belly: Color = ScreechModel.BELLY
	var head: int = ScreechModel.Part.HEAD
	var sit := Basis(Vector3.RIGHT, deg_to_rad(SIT_UP_DEGREES))
	# From where a point is once it sits to where it's built, and back.
	var built := func(p: Vector3) -> Vector3: return HIND + sit.inverse() * (p - HIND)
	var sat := func(p: Vector3) -> Vector3: return HIND + sit * (p - HIND)
	# A round body, short soft spines laid back along it in three rows, and its haunches.
	ScreechModel._blob(st, Vector3(0.0, 0.24, 0.06), Vector3(0.18, 0.15, 0.27), 8, 5, ScreechModel.Part.TORSO, 0.04)
	for row: int in 3:
		var x: float = (row - 1) * 0.08
		var crest: float = 0.24 + 0.13 * sqrt(maxf(0.0, 1.0 - pow(x / 0.18, 2.0))) - 0.02
		for i: int in 4:
			var z: float = -0.12 + i * 0.1
			var base := Vector3(x, crest + 0.03 * cos(z * 3.0), z)
			var h: float = (0.09 if row == 1 else 0.065) * (0.85 + 0.3 * sin(float(i) * 1.7 + row))
			var tip: Vector3 = base + Vector3(x * 0.8, 0.8, 1.0).normalized() * h
			ScreechModel._cone(st, base, tip, 0.026, 4, ScreechModel.SPINE_BASE, SOFT_TIP, ScreechModel.Part.SPINE,
				1.0)
	# A big round head on top, level, looking ahead.
	var c: Vector3 = sat.call(Vector3(0.0, 0.3, -0.27))
	ScreechModel._blob(st, built.call(c), Vector3(0.155, 0.14, 0.15), 8, 5, head, 0.0)
	# A short snout and a little nose.
	ScreechModel._cone(st, built.call(c + Vector3(0.0, -0.03, -0.09)), built.call(c + Vector3(0.0, -0.05, -0.19)),
		0.065, 6, skin, skin, head, 0.0, 0.03)
	_ball(st, built.call(c + Vector3(0.0, -0.045, -0.195)), 0.026, NOSE, head)
	for sx: float in [-1.0, 1.0]:
		# Big round eyes, each with a big dark pupil and a highlight.
		_ball(st, built.call(c + Vector3(sx * 0.072, 0.03, -0.1)), 0.05, Color(ScreechModel.EYE, 1.0), head)
		_ball(st, built.call(c + Vector3(sx * 0.07, 0.027, -0.135)), 0.032, PUPIL, head)
		_ball(st, built.call(c + Vector3(sx * 0.058, 0.042, -0.162)), 0.01, SPARKLE, head)
		# Big ears.
		ScreechModel._cone(st, built.call(c + Vector3(sx * 0.09, 0.09, 0.02)),
			built.call(c + Vector3(sx * 0.17, 0.21, 0.05)), 0.058, 4, skin, ScreechModel.EAR, head, 0.0)
	# Its front paws held up in front of its chest. The left one, toward the driver, lifts in greeting: it's the
	# swiping arm (the shader turns it about a line across the shoulders, so either side can be).
	for arm: Array in [[ScreechModel.Part.SWIPE_ARM, -1.0], [ScreechModel.Part.OTHER_ARM, 1.0]]:
		var sx: float = float(arm[1])
		var shoulder := Vector3(sx * 0.12, 0.27, -0.2)
		var wrist: Vector3 = built.call(sat.call(shoulder) + Vector3(sx * 0.01, -0.12, -0.07))
		ScreechModel._cone(st, shoulder, wrist, 0.045, 4, skin, belly, int(arm[0]), 0.7, 0.03)
		_ball(st, wrist, 0.035, belly, int(arm[0]))
	# Its hind legs folded under it, their feet flat on the seat in front.
	for leg: Array in [[ScreechModel.Part.LEG_BL, -1.0], [ScreechModel.Part.LEG_BR, 1.0]]:
		var sx: float = float(leg[1])
		var hip: Vector3 = built.call(Vector3(sx * 0.1, 0.09, 0.06))
		var foot: Vector3 = built.call(Vector3(sx * 0.12, 0.03, -0.06))
		ScreechModel._cone(st, hip, foot, 0.06, 4, skin, belly, int(leg[0]), 1.0, 0.035)
		_ball(st, foot, 0.04, belly, int(leg[0]))
	# Its tail curled round on the seat beside it, toward the driver.
	var curl: Array[Vector3] = [Vector3(0.0, 0.06, 0.28), Vector3(-0.1, 0.035, 0.31), Vector3(-0.2, 0.025, 0.23),
		Vector3(-0.24, 0.025, 0.1), Vector3(-0.21, 0.025, -0.02), Vector3(-0.14, 0.03, -0.08)]
	for i: int in curl.size() - 1:
		var s0: float = float(i) / (curl.size() - 1)
		var s1: float = float(i + 1) / (curl.size() - 1)
		ScreechModel._cone(st, built.call(curl[i]), built.call(curl[i + 1]), lerpf(0.045, 0.012, s0), 4, skin, skin,
			ScreechModel.Part.TAIL, s1, lerpf(0.045, 0.012, s1), s0)
	_pet_mesh = st.commit()
	return _pet_mesh


## A small low-poly ball (eight sides, four rings) of one colour.
static func _ball(st: SurfaceTool, center: Vector3, r: float, color: Color, part: int) -> void:
	var rows: int = 4
	var sides: int = 8
	var grid: Array[PackedVector3Array] = []
	for ri: int in rows + 1:
		var lat: float = PI * float(ri) / rows - PI * 0.5
		var row := PackedVector3Array()
		for k: int in sides:
			var lon: float = TAU * float(k) / sides
			row.append(center + Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon)) * r)
		grid.append(row)
	var colors: Array = [color, color, color]
	for ri: int in rows:
		for k: int in sides:
			var k1: int = (k + 1) % sides
			ScreechModel._tri(st, [grid[ri][k], grid[ri][k1], grid[ri + 1][k1]], colors, part, [0.0, 0.0, 0.0], center)
			ScreechModel._tri(st, [grid[ri][k], grid[ri + 1][k1], grid[ri + 1][k]], colors, part, [0.0, 0.0, 0.0],
				center)
