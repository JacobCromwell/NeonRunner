class_name SportsCarModel
extends Node3D
## The Gangland outro's sports car (the owner's beat, October 9, 2026: "a sleek, flashy car ... an angular,
## almost triangular car that is sleek, shiny, like a Lambo"). Built by code, low-poly and faceted: a wedge
## lofted through cross-sections from a blade of a nose, up a long raked hood and windshield to a short roof,
## down over the engine cover to a cut-off tail with a wing; flared fenders over the wheels, a dark intake
## behind the door. One scissor door on the driver's side (the left) swings up from its front edge
## (set_door), showing the cabin and its two seats, the courtesy lights in it coming on (set_interior: glowing
## strips and the piping on the seats, and a warm light on whoever is in it). Its lights (head, tail, running
## lights along the sills, the glow under it and the headlights' pools on the road) come on together
## (set_lights), and its wheels turn with the distance it has driven (set_travelled), which also streams the
## street's reflections over it. Visual only: no collision. Its panels are one-sided, so a camera can sit in the
## cabin and look about it.
##
## The paint (sports_car.gdshader) is unshaded with a fake key light and a fake street mirrored in it, so it
## shines alike on every renderer. Draw calls: the body, the door, four wheels and the glow cards (7).
## Faces -z (like the game's other models), its wheels on y = 0, centred on its wheelbase's middle.
## DESIGN-TBD (docs/questions/f2d.md): its look, colours and size.

## Its size (metres): width, height, length. The runner is about 1.3 m tall in play, so it's a little larger
## for them than a real one would be (they can sit in it).
const DEFAULT_SIZE := Vector3(1.95, 1.0, 4.3)
## The cross-sections it's lofted through, front to back, in a 1.95 x 1.0 x 4.3 m car (scaled to `size`):
## each [z, half-widths and heights of five points up its right side: the sill's underside, the sill (or, over a
## wheel, the inside of the wheel well), the beltline (or the fender's lip), the shoulder (or the fender's
## crown) and the top's edge, and whether a wheel is under it]. The top is flat between the two top edges.
const SECTIONS: Array = [
	[-2.15, [Vector2(0.56, 0.15), Vector2(0.64, 0.19), Vector2(0.72, 0.25), Vector2(0.68, 0.3), Vector2(0.4, 0.31)], false],
	[-1.7, [Vector2(0.5, 0.17), Vector2(0.52, 0.52), Vector2(0.92, 0.54), Vector2(0.91, 0.6), Vector2(0.5, 0.52)], true],
	[-1.3, [Vector2(0.5, 0.17), Vector2(0.52, 0.62), Vector2(0.97, 0.65), Vector2(0.94, 0.72), Vector2(0.53, 0.62)], true],
	[-0.92, [Vector2(0.5, 0.17), Vector2(0.52, 0.62), Vector2(0.98, 0.67), Vector2(0.94, 0.75), Vector2(0.56, 0.67)], true],
	[-0.78, [Vector2(0.74, 0.13), Vector2(0.83, 0.25), Vector2(0.98, 0.55), Vector2(0.93, 0.74), Vector2(0.57, 0.71)], false],
	[0.02, [Vector2(0.76, 0.13), Vector2(0.85, 0.25), Vector2(0.98, 0.58), Vector2(0.86, 0.76), Vector2(0.48, 1.0)], false],
	[0.62, [Vector2(0.77, 0.13), Vector2(0.86, 0.25), Vector2(0.98, 0.6), Vector2(0.9, 0.79), Vector2(0.48, 0.97)], false],
	[0.92, [Vector2(0.52, 0.18), Vector2(0.54, 0.64), Vector2(0.99, 0.7), Vector2(0.96, 0.82), Vector2(0.62, 0.88)], true],
	[1.3, [Vector2(0.52, 0.18), Vector2(0.54, 0.66), Vector2(1.0, 0.72), Vector2(0.97, 0.83), Vector2(0.66, 0.82)], true],
	[1.7, [Vector2(0.52, 0.18), Vector2(0.54, 0.62), Vector2(0.99, 0.68), Vector2(0.96, 0.8), Vector2(0.68, 0.78)], true],
	[2.15, [Vector2(0.7, 0.2), Vector2(0.82, 0.28), Vector2(0.94, 0.62), Vector2(0.92, 0.76), Vector2(0.68, 0.76)], false],
]
## Which sections the door spans (from its front edge, where it's hinged, to its back), and the cabin's.
const DOOR_FROM: int = 4
const DOOR_TO: int = 6
## Sections the windshield and the rear window run between (the top's finish; the roof between is paint).
const WINDSHIELD: int = 4
const REAR_WINDOW: int = 6
## The intake behind the door: the side between these sections is dark.
const INTAKE: int = 6
## The wheels: hubs along the car (metres, in the 4.3 m car), radii, width.
const FRONT_HUB: float = -1.3
const REAR_HUB: float = 1.3
const FRONT_RADIUS: float = 0.34
const REAR_RADIUS: float = 0.36
const WHEEL_WIDTH: float = 0.3
## How far the door swings: up from its front edge, and out.
const DOOR_LIFT_DEGREES: float = 72.0
const DOOR_OUT_DEGREES: float = 9.0
## The finishes (sports_car.gdshader, UV2.x) and the light group (UV2.y).
const PAINT: int = 0
const GLASS: int = 1
const TRIM: int = 2
const CHROME: int = 3
const LIT: float = 1.0
## The cabin's courtesy lights, on while its door is up (set_interior: UV2.y 2).
const INTERIOR: float = 2.0
## Fixed colours: glass, trim, chrome, the cabin, the headlights and taillights.
const GLASS_COLOR := Color(0.05, 0.06, 0.08)
const TRIM_COLOR := Color(0.07, 0.07, 0.08)
const TIRE_COLOR := Color(0.05, 0.05, 0.05)
const CHROME_COLOR := Color(0.78, 0.8, 0.88)
const CABIN_COLOR := Color(0.1, 0.09, 0.1)
## Its seats: tan leather, piped in the accent colour (glowing with the courtesy lights).
const SEAT_COLOR := Color(0.5, 0.36, 0.25)
## The seats' piping (the accent's cyan, softer).
const PIPING := Color(0.4, 0.8, 0.95)
## The courtesy lights' warm white, and the light they cast in the cabin (energy, reach in metres): it lights
## whoever is in it.
const COURTESY := Color(1.0, 0.86, 0.66)
const CABIN_LIGHT: float = 1.6
const CABIN_LIGHT_RANGE: float = 1.6
const HEADLIGHT := Color(0.85, 0.92, 1.0)
const TAILLIGHT := Color(1.0, 0.12, 0.1)
## The driver's seat (on the left) in the 1.95 x 1.0 x 4.3 m car: its cushion's middle.
const SEAT := Vector3(-0.38, 0.3, 0.18)
## Faces of a decal sit this far off the surface they're on.
const DECAL_OFFSET: float = 0.008

## Its size, paint and accent (running lights, glow under it, wheel hubs).
var size: Vector3 = DEFAULT_SIZE
var paint: Color = Color(0.3, 0.12, 0.9)
var accent: Color = Color(0.35, 0.85, 1.0)
var body: MeshInstance3D
## The door's hinge (it turns about it) and its mesh.
var door_hinge: Node3D
var door: MeshInstance3D
var wheels: Array[MeshInstance3D] = []
var glow_cards: MeshInstance3D
## The courtesy lights' light in the cabin.
var cabin_light: OmniLight3D
## Now: the door (0 shut, 1 open), the lights (0-1), metres driven, and how far the wheels have turned (metres
## at their rims).
var door_open: float = 0.0
var lights: float = 0.0
var interior: float = 0.0
var travelled: float = 0.0
var wheel_turn: float = 0.0

var _glow_material: ShaderMaterial
var _wheel_radius: Array[float] = []
var _wheel_side: Array[float] = []

static var _cache: Dictionary = {}
static var _shader: Shader


## Builds it (meshes cached by look).
func build(p_size: Vector3 = DEFAULT_SIZE, p_paint: Color = Color(0.3, 0.12, 0.9),
		p_accent: Color = Color(0.35, 0.85, 1.0)) -> void:
	size = p_size
	paint = p_paint
	accent = p_accent
	for child: Node in get_children():
		remove_child(child)
		child.free()
	wheels.clear()
	_wheel_radius.clear()
	_wheel_side.clear()
	var meshes: Dictionary = meshes_for(size, paint, accent)
	var mat: ShaderMaterial = material()
	body = MeshBatch.add_instance(self, meshes["body"], "Body")
	body.material_override = mat
	var s: Vector3 = scale_of(size)
	door_hinge = Node3D.new()
	door_hinge.name = "DoorHinge"
	door_hinge.position = hinge_point(size)
	add_child(door_hinge)
	door = MeshBatch.add_instance(door_hinge, meshes["door"], "Door")
	door.material_override = mat
	for hub: Array in [[FRONT_HUB, FRONT_RADIUS], [REAR_HUB, REAR_RADIUS]]:
		for side: float in [-1.0, 1.0]:
			var r: float = float(hub[1]) * s.y
			var w := MeshBatch.add_instance(self, meshes["wheel_front" if hub[0] < 0.0 else "wheel_rear"],
				"Wheel%s%s" % ["F" if hub[0] < 0.0 else "R", "L" if side < 0.0 else "R"])
			w.material_override = mat
			w.position = Vector3(side * (size.x * 0.5 - WHEEL_WIDTH * s.x * 0.5 - 0.01), r, float(hub[0]) * s.z)
			# The rim on the outside: the left wheels are the right ones turned round.
			w.rotation.y = PI if side < 0.0 else 0.0
			wheels.append(w)
			_wheel_radius.append(r)
			_wheel_side.append(side)
	var glow := MeshKit.glow({"glow_scale": 2.0, "fade_begin": 60.0, "fade_end": 240.0})
	_glow_material = glow.duplicate() as ShaderMaterial
	glow_cards = MeshBatch.add_instance(self, meshes["glow"], "Glow")
	glow_cards.material_override = _glow_material
	cabin_light = OmniLight3D.new()
	cabin_light.name = "CabinLight"
	cabin_light.position = Vector3(0.0, 0.82 * s.y, SEAT.z * s.z)
	cabin_light.light_color = COURTESY
	cabin_light.omni_range = CABIN_LIGHT_RANGE
	cabin_light.shadow_enabled = false
	add_child(cabin_light)
	set_door(door_open)
	set_lights(lights)
	set_interior(interior)
	set_travelled(travelled, wheel_turn - travelled)


## The door: 0 shut, 1 swung all the way up (it eases at both ends).
func set_door(open: float) -> void:
	door_open = clampf(open, 0.0, 1.0)
	if door_hinge == null:
		return
	var k: float = smoothstep(0.0, 1.0, door_open)
	# Out a little (its back toward -x), then up about its front edge (its back rising).
	door_hinge.basis = Basis(Vector3.RIGHT, -deg_to_rad(DOOR_LIFT_DEGREES) * k) \
		* Basis(Vector3.UP, -deg_to_rad(DOOR_OUT_DEGREES) * k)


## Its courtesy lights in the cabin: 0 off, 1 on (they come on as its door goes up).
func set_interior(on: float) -> void:
	interior = clampf(on, 0.0, 1.0)
	for g: GeometryInstance3D in _car_meshes():
		g.set_instance_shader_parameter(&"interior", interior)
	if cabin_light != null:
		cabin_light.light_energy = CABIN_LIGHT * interior
		cabin_light.visible = interior > 0.001


## Its lights: 0 off, 1 on.
func set_lights(on: float) -> void:
	lights = clampf(on, 0.0, 1.0)
	for g: GeometryInstance3D in _car_meshes():
		g.set_instance_shader_parameter(&"lights", lights)
	if _glow_material != null:
		_glow_material.set_shader_parameter(&"state_glow", lights)
		glow_cards.visible = lights > 0.001


## Metres driven: the street's reflections stream back over the paint, and the wheels turn by it, plus
## `spin` metres more (wheelspin: never less than it was, or they'd turn back).
func set_travelled(metres: float, spin: float = 0.0) -> void:
	travelled = metres
	wheel_turn = metres + spin
	for i: int in wheels.size():
		# Rolling forward (-z) turns a wheel's top forward: about -x for a right wheel, +x for a left one
		# (turned round).
		wheels[i].rotation.x = -_wheel_side[i] * wheel_turn / maxf(_wheel_radius[i], 0.05)
	for g: GeometryInstance3D in _car_meshes():
		g.set_instance_shader_parameter(&"travelled", travelled)


## Draw calls it adds (each visible mesh's surfaces).
func draw_call_count() -> int:
	var count: int = 0
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.is_visible_in_tree() and m.mesh != null:
			count += m.mesh.get_surface_count()
	return count


func _car_meshes() -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for g: GeometryInstance3D in [body, door]:
		if g != null:
			out.append(g)
	for w: MeshInstance3D in wheels:
		out.append(w)
	return out


# --- Its shape ------------------------------------------------------------------------------------------

## The scale from the 1.95 x 1.0 x 4.3 m car the sections describe to `p_size`.
static func scale_of(p_size: Vector3) -> Vector3:
	return Vector3(p_size.x / DEFAULT_SIZE.x, p_size.y / DEFAULT_SIZE.y, p_size.z / DEFAULT_SIZE.z)


## Where the driver sits in a car of `p_size` (car space: the seat cushion's middle).
static func seat_of(p_size: Vector3) -> Vector3:
	return SEAT * scale_of(p_size)


## The door's opening in a car of `p_size` (car space): on the ground at the side, halfway along the door.
static func door_step_of(p_size: Vector3) -> Vector3:
	var middle: float = (float(SECTIONS[DOOR_FROM][0]) + float(SECTIONS[DOOR_TO][0])) * 0.5
	return Vector3(-p_size.x * 0.5, 0.0, middle * scale_of(p_size).z)


## Where the door is hinged: at its front edge, at the beltline.
static func hinge_point(p_size: Vector3) -> Vector3:
	return _hinge(scale_of(p_size))


static func _hinge(s: Vector3) -> Vector3:
	var p: Vector2 = SECTIONS[DOOR_FROM][1][2]
	return Vector3(-p.x * s.x, (p.y + 0.05) * s.y, SECTIONS[DOOR_FROM][0] * s.z)


## Point `k` (0-4) of section `i` on `side` (-1 left, 1 right), in metres.
static func point(i: int, k: int, side: float, s: Vector3) -> Vector3:
	var p: Vector2 = SECTIONS[i][1][k]
	return Vector3(side * p.x * s.x, p.y * s.y, float(SECTIONS[i][0]) * s.z)


## Its shared material (sports_car.gdshader; each mesh sets its own lights and travel).
static func material() -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://scripts/cinematics/gangland_outro/sports_car.gdshader") as Shader
	var key: String = "material"
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = _shader
		_cache[key] = m
	return _cache[key]


## Its meshes (cached by look): "body", "door" (about its hinge), "wheel_front", "wheel_rear" and "glow".
static func meshes_for(p_size: Vector3, p_paint: Color, p_accent: Color) -> Dictionary:
	var key: String = var_to_str([p_size, p_paint, p_accent])
	if _cache.has(key):
		return _cache[key]
	var s: Vector3 = scale_of(p_size)
	var out: Dictionary = {
		"body": _body_mesh(s, p_paint, p_accent),
		"door": _door_mesh(s, p_paint),
		"wheel_front": _wheel_mesh(FRONT_RADIUS * s.y, WHEEL_WIDTH * s.x, p_accent),
		"wheel_rear": _wheel_mesh(REAR_RADIUS * s.y, WHEEL_WIDTH * s.x, p_accent),
		"glow": _glow_mesh(s, p_size, p_accent),
	}
	_cache[key] = out
	return out


static func _body_mesh(s: Vector3, p_paint: Color, p_accent: Color) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(null)
	var last: int = SECTIONS.size() - 1
	for i: int in last:
		var arch: bool = bool(SECTIONS[i][2]) or bool(SECTIONS[i + 1][2])
		for side: float in [-1.0, 1.0]:
			for k: int in 4:
				# The door's panels are the door's.
				if side < 0.0 and i >= DOOR_FROM and i < DOOR_TO and k >= 1:
					continue
				var finish: int = _side_finish(i, k, arch)
				var color: Color = p_paint if finish == PAINT else (GLASS_COLOR if finish == GLASS else TRIM_COLOR)
				_panel(m, i, k, side, s, color, finish)
		# The top, flat between its two edges, and the underside.
		var top_finish: int = GLASS if i == WINDSHIELD or i == REAR_WINDOW else PAINT
		_face(m, point(i, 4, 1.0, s), point(i, 4, -1.0, s), point(i + 1, 4, -1.0, s), point(i + 1, 4, 1.0, s),
			Vector3.UP, GLASS_COLOR if top_finish == GLASS else p_paint, 0.0, top_finish)
		_face(m, point(i, 0, 1.0, s), point(i, 0, -1.0, s), point(i + 1, 0, -1.0, s), point(i + 1, 0, 1.0, s),
			Vector3.DOWN, TRIM_COLOR, 0.0, TRIM)
	_cap(m, 0, Vector3.FORWARD, s)
	_cap(m, last, Vector3.BACK, s)
	_cabin(m, s)
	_details(m, s, p_paint, p_accent)
	return batch.to_mesh()


## A side's finish between sections i and i + 1, segment k: the sill and the wheel wells dark, the side
## windows glass, the intake behind the door dark, the rest paint.
static func _side_finish(i: int, k: int, arch: bool) -> int:
	if k == 0 or (k == 1 and arch):
		return TRIM
	if i == INTAKE and k <= 2:
		return TRIM
	if k == 3 and i >= DOOR_FROM and i < DOOR_TO:
		return GLASS
	return PAINT


## The panel of segment k (points k to k + 1) between sections i and i + 1 on one side.
static func _panel(m: MeshLayer, i: int, k: int, side: float, s: Vector3, color: Color, finish: int,
		glow: float = 0.0, group: float = 0.0) -> void:
	var a: Vector3 = point(i, k, side, s)
	var b: Vector3 = point(i, k + 1, side, s)
	var c: Vector3 = point(i + 1, k + 1, side, s)
	var d: Vector3 = point(i + 1, k, side, s)
	_face(m, a, b, c, d, _outward(i, k, side, s), color, glow, finish, group)


## A side panel's outward direction: across the profile's segment, away from the car's inside.
static func _outward(i: int, k: int, side: float, s: Vector3) -> Vector3:
	var e: Vector3 = (point(i, k + 1, 1.0, s) - point(i, k, 1.0, s)) \
		+ (point(i + 1, k + 1, 1.0, s) - point(i + 1, k, 1.0, s))
	return Vector3(side * e.y, -e.x, 0.0)


## A four-cornered face, turned to face `outward` (Godot's front faces wind clockwise).
static func _face(m: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color,
		glow: float = 0.0, finish: int = PAINT, group: float = 0.0) -> void:
	var n: Vector3 = (b - a).cross(c - a) + (c - a).cross(d - a)
	if n.dot(outward) > 0.0:
		m.quad(a, d, c, b, color, glow, finish, group)
	else:
		m.quad(a, b, c, d, color, glow, finish, group)


static func _tri(m: MeshLayer, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, color: Color,
		glow: float = 0.0, finish: int = PAINT, group: float = 0.0) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	var verts := PackedVector3Array([a, c, b] if n.dot(outward) > 0.0 else [a, b, c])
	m.verts.append_array(verts)
	var col := Color(color, glow)
	m.colors.append_array(PackedColorArray([col, col, col]))
	m.uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2(0, 1), Vector2(1, 1)]))
	var p := Vector2(finish, group)
	m.uv2s.append_array(PackedVector2Array([p, p, p]))


## The nose's or the tail's end: a fan round the section's middle, dark (the intake, the rear fascia).
static func _cap(m: MeshLayer, i: int, outward: Vector3, s: Vector3) -> void:
	var ring: Array[Vector3] = []
	for k: int in 5:
		ring.append(point(i, k, 1.0, s))
	for k: int in range(4, -1, -1):
		ring.append(point(i, k, -1.0, s))
	var middle := Vector3.ZERO
	for p: Vector3 in ring:
		middle += p
	middle /= float(ring.size())
	for k: int in ring.size():
		_tri(m, middle, ring[k], ring[(k + 1) % ring.size()], outward, TRIM_COLOR, 0.0, TRIM)


## The cabin seen through the open door: its floor, far side, dash, bulkhead and headlining facing in, and the
## driver's seat, all dark; the dash's instruments glow with the lights.
static func _cabin(m: MeshLayer, s: Vector3) -> void:
	var z0: float = float(SECTIONS[DOOR_FROM][0]) * s.z + 0.06
	var z1: float = float(SECTIONS[DOOR_TO][0]) * s.z - 0.04
	var x0: float = -0.8 * s.x
	var x1: float = 0.8 * s.x
	var y0: float = 0.16 * s.y
	var y1: float = 0.9 * s.y
	var dark: Color = CABIN_COLOR
	_face(m, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3.UP, dark,
		0.0, TRIM)
	_face(m, Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3.LEFT, dark,
		0.0, TRIM)
	_face(m, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1 * 0.72, z0), Vector3(x0, y1 * 0.72, z0),
		Vector3.BACK, dark, 0.0, TRIM)
	_face(m, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.FORWARD, dark,
		0.0, TRIM)
	_face(m, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.DOWN, dark,
		0.0, TRIM)
	# The instruments: a strip along the dash's top.
	_face(m, Vector3(x0 + 0.1, y1 * 0.66, z0 + 0.005), Vector3(-0.05 * s.x, y1 * 0.66, z0 + 0.005),
		Vector3(-0.05 * s.x, y1 * 0.7, z0 + 0.005), Vector3(x0 + 0.1, y1 * 0.7, z0 + 0.005), Vector3.BACK,
		Color(0.45, 0.85, 1.0), 0.9, PAINT, LIT)
	# The courtesy lights: a warm strip along the headlining over each seat, on while the door is up.
	for side: float in [-1.0, 1.0]:
		var lx: float = side * SEAT.x * s.x
		_face(m, Vector3(lx - 0.12, y1 - 0.004, z0 + 0.2), Vector3(lx + 0.12, y1 - 0.004, z0 + 0.2),
			Vector3(lx + 0.12, y1 - 0.004, z0 + 0.32), Vector3(lx - 0.12, y1 - 0.004, z0 + 0.32), Vector3.DOWN,
			COURTESY, 1.4, PAINT, INTERIOR)
	# The seats, the driver's (left) and the passenger's: a cushion and a raked back, piped along their edges.
	for side: float in [-1.0, 1.0]:
		var sx: float = side * -SEAT.x * s.x
		m.box(Vector3(sx, (SEAT.y - 0.06) * s.y, (SEAT.z - 0.06) * s.z), Vector3(0.46 * s.x, 0.12 * s.y, 0.5 * s.z),
			SEAT_COLOR, 0.0, TRIM)
		var back_basis := Basis(Vector3.RIGHT, deg_to_rad(22.0))
		var back := Transform3D(back_basis * Basis.from_scale(Vector3(0.46 * s.x, 0.6 * s.y, 0.1)),
			Vector3(sx, 0.52 * s.y, 0.44 * s.z))
		m.box_xform(back, SEAT_COLOR, 0.0, TRIM)
		for edge: float in [-1.0, 1.0]:
			var piping := Transform3D(back_basis * Basis.from_scale(Vector3(0.02, 0.6 * s.y, 0.104)),
				Vector3(sx + edge * 0.22 * s.x, 0.52 * s.y, 0.44 * s.z))
			m.box_xform(piping, PIPING, 0.8, PAINT, MeshKit.ALL_FACES, INTERIOR)


## The lights, the running lights, the wing and the exhausts.
static func _details(m: MeshLayer, s: Vector3, p_paint: Color, p_accent: Color) -> void:
	for side: float in [-1.0, 1.0]:
		# The headlights: slanted blades along the nose's upper edge.
		_decal(m, 0, 2, side, s, Vector2(0.18, 0.7), Vector2(0.35, 0.8), HEADLIGHT, 1.2, LIT)
		_decal(m, 0, 2, side, s, Vector2(0.7, 0.92), Vector2(0.5, 0.65), HEADLIGHT, 1.0, LIT)
		# The running lights along the sills, under the door.
		for i: int in range(3, 7):
			_decal(m, i, 0, side, s, Vector2(0.0, 1.0), Vector2(0.78, 0.95), p_accent, 1.4, LIT)
	# The taillights: a bar across the tail, and a hexagonal cluster at each end.
	var tail: float = float(SECTIONS[-1][0]) * s.z + 0.012
	var y: float = 0.6 * s.y
	_face(m, Vector3(-0.78 * s.x, y, tail), Vector3(0.78 * s.x, y, tail), Vector3(0.78 * s.x, y + 0.035, tail),
		Vector3(-0.78 * s.x, y + 0.035, tail), Vector3.BACK, TAILLIGHT, 1.3, PAINT, LIT)
	for side: float in [-1.0, 1.0]:
		var c := Vector3(side * 0.72 * s.x, y - 0.06, tail + 0.002)
		var ring: Array[Vector3] = []
		for k: int in 6:
			var a: float = TAU * k / 6.0
			ring.append(c + Vector3(cos(a) * 0.12, sin(a) * 0.08, 0.0))
		for k: int in 6:
			_tri(m, c, ring[k], ring[(k + 1) % 6], Vector3.BACK, TAILLIGHT, 1.5, PAINT, LIT)
	# The exhausts: two chrome hexagons out of the fascia, dark inside.
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 0.22 * s.x, 0.3 * s.y, tail - 0.08)
		m.prism_xform(Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(0.07, 0.14, 0.07)), at), 6,
			CHROME_COLOR, 0.0, CHROME)
		m.prism_xform(Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(0.05, 0.01, 0.05)),
			at + Vector3(0.0, 0.0, 0.141)), 6, Color(0.02, 0.02, 0.02), 0.0, TRIM)
	# The wing over the tail, on two struts.
	var wz: float = 1.98 * s.z
	var wy: float = 0.95 * s.y
	m.box(Vector3(0.0, wy, wz), Vector3(1.7 * s.x, 0.04, 0.34 * s.z), p_paint, 0.0, PAINT)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(side * 0.5 * s.x, (wy + 0.76 * s.y) * 0.5, wz + 0.02), Vector3(0.05, wy - 0.76 * s.y, 0.12 * s.z),
			TRIM_COLOR, 0.0, TRIM)
		m.box(Vector3(side * 0.86 * s.x, wy + 0.05, wz), Vector3(0.03, 0.14, 0.36 * s.z), p_paint, 0.0, PAINT)


## A decal on the panel of segment k between sections i and i + 1: the part from `along.x` to `along.y` of the
## way back and `across.x` to `across.y` of the way up the segment, a little off the surface.
static func _decal(m: MeshLayer, i: int, k: int, side: float, s: Vector3, along: Vector2, across: Vector2,
		color: Color, glow: float, group: float) -> void:
	var a: Vector3 = point(i, k, side, s)
	var b: Vector3 = point(i, k + 1, side, s)
	var c: Vector3 = point(i + 1, k + 1, side, s)
	var d: Vector3 = point(i + 1, k, side, s)
	var out: Vector3 = _outward(i, k, side, s).normalized() * DECAL_OFFSET
	var at := func(u: float, v: float) -> Vector3:
		return a.lerp(d, u).lerp(b.lerp(c, u), v) + out
	_face(m, at.call(along.x, across.x), at.call(along.x, across.y), at.call(along.y, across.y), at.call(along.y, across.x),
		out, color, glow, PAINT, group)


## The door (about its hinge): its panels and window, and its inside, dark, for when it's up.
static func _door_mesh(s: Vector3, p_paint: Color) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(null)
	var hinge: Vector3 = _hinge(s)
	for i: int in range(DOOR_FROM, DOOR_TO):
		for k: int in range(1, 4):
			var finish: int = _side_finish(i, k, false)
			var color: Color = p_paint if finish == PAINT else (GLASS_COLOR if finish == GLASS else TRIM_COLOR)
			var a: Vector3 = point(i, k, -1.0, s) - hinge
			var b: Vector3 = point(i, k + 1, -1.0, s) - hinge
			var c: Vector3 = point(i + 1, k + 1, -1.0, s) - hinge
			var d: Vector3 = point(i + 1, k, -1.0, s) - hinge
			var out: Vector3 = _outward(i, k, -1.0, s)
			_face(m, a, b, c, d, out, color, 0.0, finish)
			# Its inside, a little in.
			var inset: Vector3 = -out.normalized() * 0.03
			_face(m, a + inset, b + inset, c + inset, d + inset, -out, CABIN_COLOR, 0.0, TRIM)
	return batch.to_mesh()


## A wheel (axle along x, rim on the +x side): an angular tyre, a chrome rim with dark spokes, and a hub
## glowing in the accent colour with the lights.
static func _wheel_mesh(r: float, w: float, p_accent: Color) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(null)
	# The unit prism (y from 0 to 1, radius 1) laid along x.
	var along_x := func(radius: float, from: float, to: float) -> Transform3D:
		return Transform3D(Basis(Vector3(0.0, radius, 0.0), Vector3(to - from, 0.0, 0.0), Vector3(0.0, 0.0, radius)),
			Vector3(from, 0.0, 0.0))
	m.prism_xform(along_x.call(r, -w * 0.5, w * 0.5), 12, TIRE_COLOR, 0.0, TRIM)
	m.prism_xform(along_x.call(r * 0.7, w * 0.5 - 0.01, w * 0.5 + 0.012), 12, CHROME_COLOR, 0.0, CHROME)
	for k: int in 5:
		var spoke := Transform3D(Basis(Vector3.RIGHT, TAU * k / 5.0) * Basis.from_scale(Vector3(0.02, 0.06, r * 1.25)),
			Vector3(w * 0.5 + 0.02, 0.0, 0.0))
		m.box_xform(spoke, Color(0.1, 0.1, 0.12), 0.0, TRIM)
	m.prism_xform(along_x.call(r * 0.16, w * 0.5 + 0.01, w * 0.5 + 0.035), 6, p_accent, 1.2, PAINT, true, LIT)
	return batch.to_mesh()


## The glow cards (MeshKit's glow material, scaled by the lights): the glow under it, the headlights' pools on
## the road ahead and the taillights' halos.
static func _glow_mesh(s: Vector3, p_size: Vector3, p_accent: Color) -> ArrayMesh:
	var batch := MeshBatch.new()
	var g: MeshLayer = batch.layer(null)
	var half: float = p_size.x * 0.62
	var front: float = float(SECTIONS[0][0]) * s.z
	var back: float = float(SECTIONS[-1][0]) * s.z
	g.rect(Vector3(-half, 0.03, back + 0.2), Vector3(half * 2.0, 0.0, 0.0), Vector3(0.0, 0.0, front - back - 0.4),
		p_accent, 0.55, MeshKit.SHAPE_FLAT)
	for side: float in [-1.0, 1.0]:
		var x: float = side * 0.5 * s.x
		g.rect(Vector3(x - 0.6, 0.025, front - 0.1), Vector3(1.2, 0.0, 0.0), Vector3(0.0, 0.0, -7.0), HEADLIGHT, 0.14,
			MeshKit.SHAPE_BEAM)
		g.rect(Vector3(side * 0.72 * s.x - 0.45, 0.6 * s.y - 0.3, back + 0.04), Vector3(0.9, 0.0, 0.0),
			Vector3(0.0, 0.5, 0.0), TAILLIGHT, 0.7, MeshKit.SHAPE_RADIAL)
	return batch.to_mesh()
