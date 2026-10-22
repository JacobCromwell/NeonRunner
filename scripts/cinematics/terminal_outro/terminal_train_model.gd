class_name TerminalTrainModel
extends Node3D
## The Terminal outro's abandoned metro train (the owner, October 21, 2026: "the train should be a more modern looking
## train, but just dirty and run down. Not a steam train!"; it "looks like it is still in working order"). Built by
## code, low-poly and faceted like the mesh kit: a modern metro, a string of articulated cars (the two ends are cabs)
## with smooth boxy-streamlined bodies, big flat windows, double-leaf sliding doors, a rain gutter and a stripe, rubber
## gangway bellows between the cars, a skirt over the bogies, air-conditioning units and a folded pantograph on the
## roof; the cab's front is a raked, tapered nose with two windscreens either side of a central front door (a leaf
## with a window in it, a handle bar on its left stile, a step plate under it), headlights and a destination board (dark, wordless).
## It is dirty and run down (terminal_train.gdshader: faded paint, rain streaks, rust, flaked paint, grimed glass,
## a few vines hanging off the roof) but intact. Its front door slides open (set_door) onto a cab vestibule (dim with
## the emergency light, then lit), and the door's window is clear glass (terminal_train_glass.gdshader) so what is
## behind it shows. Its lights come on together (set_lights: headlights, tail lights, the glow on the track ahead),
## then its saloon's (set_interior).
## Faces -z (like the game's other models), its wheels on y = 0, its nose's front face on z = 0 and the cars
## running back along +z, centred across on x = 0.
## Draw calls: the body, the door leaf, its glass and the glow cards (4).
## DESIGN-TBD (docs/questions/f2l.md): its look, colours and size.

## The finishes (terminal_train.gdshader, UV2.x) and the light groups (UV2.y).
const PAINT: int = 0
const GLASS: int = 1
const TRIM: int = 2
const STEEL: int = 3
const VINE: int = 4
const LAMP: int = 5
const INSIDE: int = 6
const ALWAYS: float = 0.0
const EXTERIOR: float = 1.0
const SALOON: float = 2.0
const CAB: float = 3.0

## Metres: an intermediate car, a cab car, the bellows between cars, and how far a cab's nose runs back from its face.
const CAR_LENGTH: float = 14.0
const CAB_LENGTH: float = 14.6
const GANGWAY: float = 0.9
const NOSE_LENGTH: float = 1.6
## The body's cross-section: (half-width, height) up its right side: the skirt's lower edge, the floor line, the top of
## the side wall, the roof's shoulder, its upper slope and its crown. The sides are flat between the floor line and the
## top of the wall.
const PROFILE: Array[Vector2] = [Vector2(1.46, 0.26), Vector2(1.62, 0.42), Vector2(1.66, 2.76), Vector2(1.46, 3.24),
	Vector2(0.84, 3.48), Vector2(0.0, 3.54)]
const WALL: float = 1.66
## The cab's nose, from its front face (distance back, the same cross-section's points): it widens and rises to the body's.
const NOSE: Array = [
	[0.0, [Vector2(1.24, 0.30), Vector2(1.46, 0.42), Vector2(1.46, 2.80), Vector2(1.30, 3.02), Vector2(0.78, 3.12),
		Vector2(0.0, 3.16)]],
	[0.45, [Vector2(1.34, 0.28), Vector2(1.54, 0.42), Vector2(1.58, 2.78), Vector2(1.40, 3.14), Vector2(0.82, 3.30),
		Vector2(0.0, 3.34)]],
	[1.0, [Vector2(1.42, 0.27), Vector2(1.62, 0.42), Vector2(1.65, 2.77), Vector2(1.45, 3.22), Vector2(0.84, 3.44),
		Vector2(0.0, 3.50)]],
	[1.6, [Vector2(1.46, 0.26), Vector2(1.62, 0.42), Vector2(1.66, 2.76), Vector2(1.46, 3.24), Vector2(0.84, 3.48),
		Vector2(0.0, 3.54)]],
]
## The bellows between cars: a slightly smaller cross-section.
const BELLOWS: Array[Vector2] = [Vector2(1.30, 0.50), Vector2(1.40, 0.52), Vector2(1.42, 2.70), Vector2(1.26, 3.10),
	Vector2(0.76, 3.30), Vector2(0.0, 3.34)]
## The front door: its opening (half-width, floor, top), the leaf (half-width, depth it sits back), its window (half-width,
## bottom, top), and the step plate under it.
const DOOR_HALF: float = 0.50
const FLOOR: float = 0.42
const DOOR_TOP: float = 2.62
const LEAF_HALF: float = 0.46
const LEAF_BACK: float = 0.07
const LEAF_THICK: float = 0.07
const WINDOW_HALF: float = 0.28
const WINDOW_LOW: float = 1.12
const WINDOW_HIGH: float = 1.92
const STEP_TOP: float = 0.2
const STEP_DEPTH: float = 0.5
const STEP_WIDTH: float = 2.2
## How far the leaf slides open (metres, toward the train's left).
const SLIDE: float = 0.95
## The cab vestibule behind the door: its half-width, its depth to the back wall, and the floor it stands on.
const VESTIBULE_HALF: float = 0.9
const VESTIBULE_DEPTH: float = 1.9
## Decals sit this far off the surface they're on.
const DECAL: float = 0.008

## Its look.
var cars: int = 4
var paint: Color = Color(0.72, 0.68, 0.56)
var stripe: Color = Color(0.2, 0.34, 0.4)
var grime: float = 0.9
var rust: float = 0.5
var vines: int = 6
var body: MeshInstance3D
## The door leaf (it slides about its own node), its mesh, its glass and the glow cards.
var door_node: Node3D
var door: MeshInstance3D
var door_glass: MeshInstance3D
var glow_cards: MeshInstance3D
## The cab's light (a warm omni in the vestibule).
var cab_light: OmniLight3D
## Now: the door (0 shut, 1 open), the leaf's rattle (metres, model space), the lights, the saloon's lights and the
## cab's emergency light (0-1).
var door_open: float = 0.0
var rattle := Vector3.ZERO
var lights: float = 0.0
var interior: float = 0.0
var emergency: float = 0.0

var _glow_material: ShaderMaterial

static var _cache: Dictionary = {}
static var _shader: Shader
static var _glass_shader: Shader


## Builds it (meshes cached by look); `skin` is the hall's (its lamps and colours reach the paint).
func build(p_cars: int, p_paint: Color, p_stripe: Color, p_grime: float, p_rust: float, p_vines: int,
		skin: ZoneSkin = null) -> void:
	cars = clampi(p_cars, 2, 8)
	paint = p_paint
	stripe = p_stripe
	grime = p_grime
	rust = p_rust
	vines = p_vines
	for child: Node in get_children():
		remove_child(child)
		child.free()
	var meshes: Dictionary = meshes_for(cars, paint, stripe, vines)
	var mat: ShaderMaterial = material(grime, rust, skin)
	body = MeshBatch.add_instance(self, meshes["body"], "Body")
	body.material_override = mat
	door_node = Node3D.new()
	door_node.name = "Door"
	add_child(door_node)
	door = MeshBatch.add_instance(door_node, meshes["door"], "Leaf")
	door.material_override = mat
	door_glass = MeshBatch.add_instance(door_node, meshes["glass"], "Glass")
	door_glass.material_override = glass_material(grime, skin)
	door_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := MeshKit.glow({"glow_scale": 2.0, "fade_begin": 50.0, "fade_end": 190.0})
	_glow_material = glow.duplicate() as ShaderMaterial
	glow_cards = MeshBatch.add_instance(self, meshes["glow"], "Glow")
	glow_cards.material_override = _glow_material
	glow_cards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cab_light = OmniLight3D.new()
	cab_light.name = "CabLight"
	cab_light.position = Vector3(0.0, 2.1, 0.95)
	cab_light.light_color = Color(1.0, 0.84, 0.6)
	cab_light.omni_range = 3.6
	cab_light.shadow_enabled = false
	add_child(cab_light)
	set_door(door_open)
	set_lights(lights)
	set_interior(interior)
	set_emergency(emergency)


## Metres from the nose to the tail.
func length() -> float:
	return length_of(cars)


static func length_of(p_cars: int) -> float:
	var total: float = 0.0
	for i: int in p_cars:
		total += _car_length(i, p_cars)
	return total + GANGWAY * float(maxi(p_cars - 1, 0))


static func _car_length(i: int, p_cars: int) -> float:
	return CAB_LENGTH if i == 0 or i == p_cars - 1 else CAR_LENGTH


## Where car `i` starts (its front end's z).
static func car_start(i: int, p_cars: int) -> float:
	var z: float = 0.0
	for k: int in i:
		z += _car_length(k, p_cars) + GANGWAY
	return z


## The door: 0 shut, 1 slid all the way open (eased at both ends).
func set_door(open: float) -> void:
	door_open = clampf(open, 0.0, 1.0)
	_place_door()


## The leaf rattling (a small offset in model space).
func set_rattle(offset: Vector3) -> void:
	rattle = offset
	_place_door()


func _place_door() -> void:
	if door_node == null:
		return
	var k: float = smoothstep(0.0, 1.0, door_open)
	door_node.position = Vector3(-SLIDE * k, 0.0, 0.0) + rattle
	if cab_light != null:
		cab_light.position = Vector3(0.0, 2.1, 0.95)


## Its lights: 0 off, 1 on (the headlights, the tail lights, the glow on the track ahead).
func set_lights(on: float) -> void:
	lights = clampf(on, 0.0, 1.0)
	_instance_param(&"lights", lights)
	if _glow_material != null:
		_glow_material.set_shader_parameter(&"state_glow", lights)
		glow_cards.visible = lights > 0.001


## Its saloon's lights (the windows glow) and the cab's own: 0 off, 1 on.
func set_interior(on: float) -> void:
	interior = clampf(on, 0.0, 1.0)
	_instance_param(&"interior", interior)
	_light_cab()


## The cab's dim emergency light (a batteries-still-have-a-little-in-them glow): 0 off, 1 on.
func set_emergency(on: float) -> void:
	emergency = clampf(on, 0.0, 1.0)
	_instance_param(&"emergency", emergency)
	_light_cab()


func _light_cab() -> void:
	if cab_light == null:
		return
	var level: float = maxf(emergency * 0.45, interior)
	cab_light.light_energy = 1.5 * level
	cab_light.visible = level > 0.001


func _instance_param(param: StringName, value: float) -> void:
	for g: GeometryInstance3D in [body, door]:
		if g != null:
			g.set_instance_shader_parameter(param, value)


## Draw calls it adds (each visible mesh's surfaces).
func draw_call_count() -> int:
	var count: int = 0
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.is_visible_in_tree() and m.mesh != null:
			count += m.mesh.get_surface_count()
	return count


# --- Where things are (model space) -------------------------------------------------------------------------

## The door handle's middle (a vertical bar on the leaf's left-hand stile, standing proud of it).
static func handle_point() -> Vector3:
	return Vector3(-0.4, 1.05, LEAF_BACK - 0.09)


## Where the door's window shows, its middle.
static func window_point() -> Vector3:
	return Vector3(0.0, (WINDOW_LOW + WINDOW_HIGH) * 0.5, LEAF_BACK + LEAF_THICK * 0.5)


## The door's face, a point on its lower panel at `height` (the runner's fist bangs on it).
static func panel_point(height: float, across: float = 0.0) -> Vector3:
	return Vector3(across, height, LEAF_BACK - 0.0)


## The cab vestibule's floor, the middle of its width a little inside the door (where the screech waits).
static func vestibule_point(depth: float = 0.55) -> Vector3:
	return Vector3(0.0, FLOOR + 0.005, LEAF_BACK + LEAF_THICK + depth)


## The step plate's top in front of the door (the runner steps up onto it, then in).
static func step_point() -> Vector3:
	return Vector3(0.0, STEP_TOP, -STEP_DEPTH * 0.5)


## The back wall's doorway into the saloon (middle, floor).
static func doorway_point() -> Vector3:
	return Vector3(0.0, FLOOR, VESTIBULE_DEPTH)


# --- Materials ----------------------------------------------------------------------------------------------

## The paint's material (terminal_train.gdshader), shared by its dirt and rust and the hall's lamps and colours (copied
## from the skin's solid material).
static func material(p_grime: float, p_rust: float, skin: ZoneSkin = null) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://scripts/cinematics/terminal_outro/terminal_train.gdshader") as Shader
	var key: String = "material %s %s %s" % [p_grime, p_rust, _skin_key(skin)]
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter(&"grime", p_grime)
		m.set_shader_parameter(&"rust_amount", p_rust)
		_copy_hall(m, skin, [&"tm_lamp", &"tm_haze", &"tm_rust", &"tm_vine", &"tm_pitch", &"tm_lamp_y", &"tm_lamp_gain"])
		_cache[key] = m
	return _cache[key]


## The clear glass's material (terminal_train_glass.gdshader).
static func glass_material(p_grime: float, skin: ZoneSkin = null) -> ShaderMaterial:
	if _glass_shader == null:
		_glass_shader = load("res://scripts/cinematics/terminal_outro/terminal_train_glass.gdshader") as Shader
	var key: String = "glass %s %s" % [p_grime, _skin_key(skin)]
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = _glass_shader
		m.set_shader_parameter(&"grime", p_grime)
		_copy_hall(m, skin, [&"tm_haze"])
		_cache[key] = m
	return _cache[key]


static func _skin_key(skin: ZoneSkin) -> String:
	return "-" if skin == null else str(skin.get_instance_id())


## The hall's values on the skin's solid material, set on `m` where the skin has them (the defaults are the Terminal's).
static func _copy_hall(m: ShaderMaterial, skin: ZoneSkin, names: Array[StringName]) -> void:
	if skin == null or not skin.has_method(&"solid_material"):
		return
	var solid := skin.call(&"solid_material") as ShaderMaterial
	if solid == null:
		return
	for param: StringName in names:
		var v: Variant = solid.get_shader_parameter(param)
		if v != null:
			m.set_shader_parameter(param, v)


## Its meshes (cached by look): "body", "door" (the leaf, at the door's node), "glass" (the door's window, ditto) and
## "glow".
static func meshes_for(p_cars: int, p_paint: Color, p_stripe: Color, p_vines: int) -> Dictionary:
	var key: String = var_to_str([p_cars, p_paint, p_stripe, p_vines])
	if _cache.has(key):
		return _cache[key]
	var out: Dictionary = {
		"body": _body_mesh(p_cars, p_paint, p_stripe, p_vines),
		"door": _leaf_mesh(p_paint, p_stripe),
		"glass": _glass_mesh(),
		"glow": _glow_mesh(p_cars),
	}
	_cache[key] = out
	return out


# --- The body -----------------------------------------------------------------------------------------------

static func _body_mesh(p_cars: int, p_paint: Color, p_stripe: Color, p_vines: int) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(null)
	var dark := Color(0.07, 0.065, 0.06)
	for i: int in p_cars:
		var start: float = car_start(i, p_cars)
		var len: float = _car_length(i, p_cars)
		var front: bool = i == 0
		var back: bool = i == p_cars - 1
		var car := MeshLayer.new()
		_car(car, len, front, back, p_paint, p_stripe, dark)
		m.append(car, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, start)))
		# The bellows to the next car.
		if i < p_cars - 1:
			_bellows(m, start + len, dark)
		_roof(m, start, len, i, p_cars)
		for bz: float in [3.0, len - 3.0]:
			_bogie(m, start + bz)
	_vines(m, p_cars, p_vines)
	return batch.to_mesh()


## One car in its own space (z from its front end back): the loft of its body, its ends (a nose on a cab's, a plain
## dark cap on the end that meets a bellows), its side decals.
static func _car(m: MeshLayer, len: float, front: bool, back: bool, p_paint: Color, p_stripe: Color, dark: Color) -> void:
	var flat_from: float = NOSE_LENGTH if front else 0.0
	var flat_to: float = len - NOSE_LENGTH if back else len
	var profile: Array[Vector2] = PROFILE
	_loft(m, [[flat_from, profile], [flat_to, profile]], p_paint)
	if front:
		var nose := MeshLayer.new()
		_nose(nose, false, p_paint, p_stripe, dark)
		m.append(nose)
	else:
		_end_cap(m, 0.0, Vector3.FORWARD, dark)
	if back:
		var nose := MeshLayer.new()
		_nose(nose, true, p_paint, p_stripe, dark)
		m.append(nose, Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, len)))
	else:
		_end_cap(m, len, Vector3.BACK, dark)
	# The underside.
	_face(m, Vector3(PROFILE[0].x, PROFILE[0].y, flat_from), Vector3(-PROFILE[0].x, PROFILE[0].y, flat_from),
		Vector3(-PROFILE[0].x, PROFILE[0].y, flat_to), Vector3(PROFILE[0].x, PROFILE[0].y, flat_to), Vector3.DOWN, dark, 0.0,
		TRIM)
	_sides(m, len, front, back, flat_from, flat_to, p_paint, p_stripe, dark)


## The body lofted through sections ([z, profile] pairs): a quad for each segment of the cross-section on each side.
static func _loft(m: MeshLayer, sections: Array, color: Color, finish: int = PAINT) -> void:
	for i: int in sections.size() - 1:
		var pa: Array = sections[i][1]
		var pb: Array = sections[i + 1][1]
		var za: float = float(sections[i][0])
		var zb: float = float(sections[i + 1][0])
		for side: float in [-1.0, 1.0]:
			for k: int in pa.size() - 1:
				var a := Vector3(side * float(pa[k].x), float(pa[k].y), za)
				var b := Vector3(side * float(pa[k + 1].x), float(pa[k + 1].y), za)
				var c := Vector3(side * float(pb[k + 1].x), float(pb[k + 1].y), zb)
				var d := Vector3(side * float(pb[k].x), float(pb[k].y), zb)
				var e: Vector2 = Vector2(float(pa[k + 1].x) - float(pa[k].x), float(pa[k + 1].y) - float(pa[k].y))
				_face(m, a, b, c, d, Vector3(side * e.y, -e.x, 0.0), color, 0.0, finish)


## A cap closing the end of a car at `z` (facing `outward`): the whole cross-section, one dark fan.
static func _end_cap(m: MeshLayer, z: float, outward: Vector3, color: Color) -> void:
	var ring: Array[Vector3] = []
	for k: int in PROFILE.size():
		ring.append(Vector3(PROFILE[k].x, PROFILE[k].y, z))
	for k: int in range(PROFILE.size() - 2, -1, -1):
		ring.append(Vector3(-PROFILE[k].x, PROFILE[k].y, z))
	var middle := Vector3(0.0, 1.6, z)
	for k: int in ring.size():
		_tri(m, middle, ring[k], ring[(k + 1) % ring.size()], outward, color, 0.0, TRIM)


## The bellows between two cars: a darker, slightly smaller loft over the gap, with its underside.
static func _bellows(m: MeshLayer, z: float, color: Color) -> void:
	var profile: Array[Vector2] = BELLOWS
	_loft(m, [[z - 0.05, profile], [z + GANGWAY + 0.05, profile]], color, TRIM)
	_face(m, Vector3(profile[0].x, profile[0].y, z), Vector3(-profile[0].x, profile[0].y, z),
		Vector3(-profile[0].x, profile[0].y, z + GANGWAY), Vector3(profile[0].x, profile[0].y, z + GANGWAY), Vector3.DOWN,
		color, 0.0, TRIM)


# --- A cab's nose -------------------------------------------------------------------------------------------

## A cab's nose in its own space (the front face on z = 0 facing -z, the body running back along +z): the loft, the
## face's pieces around the door's opening, the windscreens and lamps, the step plate. `rear`: the tail's end, with red
## tail lights and a shut door.
static func _nose(m: MeshLayer, rear: bool, p_paint: Color, p_stripe: Color, dark: Color) -> void:
	_loft(m, NOSE, p_paint)
	# Its flanks' skirt, gutter and stripe, along the sides of the loft.
	for side: float in [-1.0, 1.0]:
		_nose_band(m, side, FLOOR, 0.64, dark, DECAL, TRIM)
		_nose_band(m, side, 2.70, 2.78, dark, DECAL, TRIM)
		_nose_band(m, side, 0.98, 1.14, p_stripe, DECAL * 4.0, PAINT)
	# The face: left and right of the door, above it, the roof strip, the bumper band.
	var h: float = DOOR_HALF
	_quad_z(m, 0.0, -1.46, -h, FLOOR, 2.80, p_paint)
	_quad_z(m, 0.0, h, 1.46, FLOOR, 2.80, p_paint)
	_quad_z(m, 0.0, -h, h, DOOR_TOP, 2.80, p_paint)
	var strip: Array[Vector2] = [Vector2(-1.46, 2.80), Vector2(1.46, 2.80), Vector2(1.30, 3.02), Vector2(0.78, 3.12),
		Vector2(0.0, 3.16), Vector2(-0.78, 3.12), Vector2(-1.30, 3.02)]
	for k: int in strip.size():
		_tri(m, Vector3(0.0, 2.9, 0.0), Vector3(strip[k].x, strip[k].y, 0.0), Vector3(strip[(k + 1) % strip.size()].x,
			strip[(k + 1) % strip.size()].y, 0.0), Vector3.FORWARD, p_paint, 0.0, PAINT)
	_quad_z(m, 0.0, -1.24, 1.24, 0.30, FLOOR, dark, 0.0, TRIM)
	for side: float in [-1.0, 1.0]:
		_tri(m, Vector3(side * 1.24, 0.30, 0.0), Vector3(side * 1.46, FLOOR, 0.0), Vector3(side * 1.24, FLOOR, 0.0),
			Vector3.FORWARD, dark, 0.0, TRIM)
	# The stripe across the face, both sides of the door.
	var d: float = -DECAL * 2.0
	_quad_z(m, d, -1.46, -h, 0.98, 1.14, p_stripe)
	_quad_z(m, d, h, 1.46, 0.98, 1.14, p_stripe)
	# The windscreens, in dark frames: a slightly raked top edge, a clear dirty glass (dark, the cab's lights glowing
	# behind when it is lit).
	for side: float in [-1.0, 1.0]:
		var frame := PackedVector3Array([Vector3(side * 1.40, 1.21, -DECAL), Vector3(side * 0.58, 1.21, -DECAL),
			Vector3(side * 0.62, 2.70, -DECAL), Vector3(side * 1.36, 2.70, -DECAL)])
		_face(m, frame[0], frame[3], frame[2], frame[1], Vector3.FORWARD, dark, 0.0, TRIM)
		var gl := PackedVector3Array([Vector3(side * 1.35, 1.27, d * 1.5), Vector3(side * 0.63, 1.27, d * 1.5),
			Vector3(side * 0.67, 2.64, d * 1.5), Vector3(side * 1.31, 2.64, d * 1.5)])
		_face(m, gl[0], gl[3], gl[2], gl[1], Vector3.FORWARD, Color(0.035, 0.045, 0.05), 0.0, GLASS, SALOON)
		# A wiper arm sweeping up the glass.
		_face(m, Vector3(side * 0.95, 1.30, d * 2.0), Vector3(side * 0.99, 1.30, d * 2.0), Vector3(side * 1.18, 2.1, d * 2.0),
			Vector3(side * 1.14, 2.1, d * 2.0), Vector3.FORWARD, dark, 0.0, TRIM)
		# The lamps low on the face: a dark bezel and the lamp (white at the front, red at the tail).
		_quad_z(m, d, side * 0.8, side * 1.3, 0.58, 0.94, dark, 0.0, TRIM)
		var lamp: Color = Color(1.0, 0.1, 0.08) if rear else Color(1.0, 0.95, 0.82)
		_quad_z(m, d * 2.0, side * 0.86, side * 1.24, 0.64, 0.88, lamp, 1.1, LAMP, EXTERIOR)
	# The destination board: dark glass in a frame, wordless, dead.
	_quad_z(m, d, -0.74, 0.74, 2.84, 3.06, dark, 0.0, TRIM)
	_quad_z(m, d * 2.0, -0.7, 0.7, 2.87, 3.03, Color(0.03, 0.035, 0.035), 0.0, GLASS)
	# The opening's jambs and sill, in dark rubber.
	var depth: float = LEAF_BACK + LEAF_THICK
	_face(m, Vector3(-h, FLOOR, 0.0), Vector3(-h, DOOR_TOP, 0.0), Vector3(-h, DOOR_TOP, depth), Vector3(-h, FLOOR, depth),
		Vector3.RIGHT, dark, 0.0, TRIM)
	_face(m, Vector3(h, FLOOR, 0.0), Vector3(h, DOOR_TOP, 0.0), Vector3(h, DOOR_TOP, depth), Vector3(h, FLOOR, depth),
		Vector3.LEFT, dark, 0.0, TRIM)
	_face(m, Vector3(-h, DOOR_TOP, 0.0), Vector3(h, DOOR_TOP, 0.0), Vector3(h, DOOR_TOP, depth), Vector3(-h, DOOR_TOP, depth),
		Vector3.DOWN, dark, 0.0, TRIM)
	_face(m, Vector3(-h, FLOOR, 0.0), Vector3(h, FLOOR, 0.0), Vector3(h, FLOOR, depth), Vector3(-h, FLOOR, depth),
		Vector3.UP, Color(0.3, 0.28, 0.26), 0.0, STEEL)
	# The step plate under it: tread plate on two brackets.
	m.box(Vector3(0.0, STEP_TOP - 0.04, -STEP_DEPTH * 0.5), Vector3(STEP_WIDTH, 0.08, STEP_DEPTH), Color(0.34, 0.33, 0.31), 0.0, STEEL)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(side * (STEP_WIDTH * 0.5 - 0.08), 0.11, -0.04), Vector3(0.05, 0.12, 0.08), dark, 0.0, TRIM)
		m.box(Vector3(side * (STEP_WIDTH * 0.5 - 0.08), 0.1, -STEP_DEPTH + 0.05), Vector3(0.05, 0.1, 0.08), dark, 0.0, TRIM)
	# A bumper under the face, with a coupler cover.
	m.box(Vector3(0.0, 0.22, -0.08), Vector3(2.5, 0.16, 0.16), dark, 0.0, TRIM)
	m.box(Vector3(0.0, 0.32, -0.14), Vector3(0.34, 0.22, 0.1), Color(0.3, 0.27, 0.24), 0.0, STEEL)
	if rear:
		# Shut: the leaf fills the doorway, its window dark.
		var leaf := MeshLayer.new()
		_leaf(leaf, p_paint, p_stripe)
		m.append(leaf)
		_quad_z(m, depth * 0.6, -WINDOW_HALF, WINDOW_HALF, WINDOW_LOW, WINDOW_HIGH, Color(0.04, 0.045, 0.05), 0.0, GLASS)
	else:
		_vestibule(m)


## A band along a flank of the nose's loft, from `y0` to `y1` up its side wall (a decal `off` proud of it).
static func _nose_band(m: MeshLayer, side: float, y0: float, y1: float, color: Color, off: float, finish: int) -> void:
	for i: int in NOSE.size() - 1:
		var pa: Array = NOSE[i][1]
		var pb: Array = NOSE[i + 1][1]
		var za: float = float(NOSE[i][0])
		var zb: float = float(NOSE[i + 1][0])
		var at := func(z: float, y: float) -> Vector3:
			var u: float = (z - za) / (zb - za)
			var va: float = (y - FLOOR) / (float(pa[2].y) - FLOOR)
			var vb: float = (y - FLOOR) / (float(pb[2].y) - FLOOR)
			var x: float = lerpf(lerpf(float(pa[1].x), float(pa[2].x), va), lerpf(float(pb[1].x), float(pb[2].x), vb), u)
			return Vector3(side * (x + off), y, z)
		_face(m, at.call(za, y0), at.call(za, y1), at.call(zb, y1), at.call(zb, y0), Vector3(side, 0.0, 0.0), color, 0.0, finish)


## A rectangle in the plane z facing -z (outward from a cab's front).
static func _quad_z(m: MeshLayer, z: float, x0: float, x1: float, y0: float, y1: float, color: Color, glow: float = 0.0,
		finish: int = PAINT, group: float = 0.0) -> void:
	_face(m, Vector3(x0, y0, z), Vector3(x0, y1, z), Vector3(x1, y1, z), Vector3(x1, y0, z), Vector3.FORWARD, color, glow,
		finish, group)


## The door leaf, in the nose's space (a flat panel `LEAF_BACK` behind the face): the lower and upper panels and the
## stiles round its window (an opening: the door's glass fills it, or, shut at the tail, the nose's own), the stripe
## across its lower panel, rubber at its edges, and a handle bar standing off its left-hand stile.
static func _leaf(m: MeshLayer, p_paint: Color, p_stripe: Color) -> void:
	var z: float = LEAF_BACK
	var c: Color = p_paint.darkened(0.06)
	var dark := Color(0.07, 0.065, 0.06)
	var l: float = LEAF_HALF
	var w: float = WINDOW_HALF
	_quad_z(m, z, -l, l, 0.46, WINDOW_LOW, c)
	_quad_z(m, z, -l, l, WINDOW_HIGH, 2.58, c)
	_quad_z(m, z, -l, -w, WINDOW_LOW, WINDOW_HIGH, c)
	_quad_z(m, z, w, l, WINDOW_LOW, WINDOW_HIGH, c)
	_quad_z(m, z - DECAL, -l, l, 0.98, 1.14, p_stripe)
	# The leaf's edges and the window's reveal, in dark rubber.
	var back: float = z + LEAF_THICK
	_face(m, Vector3(l, 0.46, z), Vector3(l, 2.58, z), Vector3(l, 2.58, back), Vector3(l, 0.46, back), Vector3.RIGHT, dark, 0.0, TRIM)
	_face(m, Vector3(-l, 0.46, z), Vector3(-l, 2.58, z), Vector3(-l, 2.58, back), Vector3(-l, 0.46, back), Vector3.LEFT, dark, 0.0, TRIM)
	_face(m, Vector3(-w, WINDOW_LOW, z), Vector3(w, WINDOW_LOW, z), Vector3(w, WINDOW_LOW, back), Vector3(-w, WINDOW_LOW, back),
		Vector3.UP, dark, 0.0, TRIM)
	_face(m, Vector3(-w, WINDOW_HIGH, z), Vector3(w, WINDOW_HIGH, z), Vector3(w, WINDOW_HIGH, back), Vector3(-w, WINDOW_HIGH, back),
		Vector3.DOWN, dark, 0.0, TRIM)
	_face(m, Vector3(-w, WINDOW_LOW, z), Vector3(-w, WINDOW_HIGH, z), Vector3(-w, WINDOW_HIGH, back), Vector3(-w, WINDOW_LOW, back),
		Vector3.RIGHT, dark, 0.0, TRIM)
	_face(m, Vector3(w, WINDOW_LOW, z), Vector3(w, WINDOW_HIGH, z), Vector3(w, WINDOW_HIGH, back), Vector3(w, WINDOW_LOW, back),
		Vector3.LEFT, dark, 0.0, TRIM)
	# The handle: a vertical steel bar on two brackets.
	var h: Vector3 = handle_point()
	m.box(Vector3(h.x, h.y, h.z), Vector3(0.035, 0.68, 0.035), Color(0.42, 0.4, 0.37), 0.0, STEEL)
	for end: float in [-0.3, 0.3]:
		m.box(Vector3(h.x, h.y + end, z - 0.045), Vector3(0.03, 0.03, 0.09), Color(0.36, 0.34, 0.32), 0.0, STEEL)
	# A dark seam all round (four strips just behind its edges, so the window stays open).
	_quad_z(m, z + 0.004, -l - 0.025, -l, 0.435, 2.605, dark, 0.0, TRIM)
	_quad_z(m, z + 0.004, l, l + 0.025, 0.435, 2.605, dark, 0.0, TRIM)
	_quad_z(m, z + 0.004, -l, l, 0.435, 0.46, dark, 0.0, TRIM)
	_quad_z(m, z + 0.004, -l, l, 2.58, 2.605, dark, 0.0, TRIM)


## The leaf, for its own mesh (at the door's node).
static func _leaf_mesh(p_paint: Color, p_stripe: Color) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(null)
	_leaf(m, p_paint, p_stripe)
	return batch.to_mesh()


## The door's window glass: one pane in the reveal, clear (terminal_train_glass.gdshader), faintly tinted.
static func _glass_mesh() -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(null)
	var z: float = LEAF_BACK + LEAF_THICK * 0.5
	var w: float = WINDOW_HALF
	var tint := Color(0.1, 0.13, 0.12, 0.1)
	m.quad_uv(Vector3(-w, WINDOW_LOW, z), Vector3(-w, WINDOW_HIGH, z), Vector3(w, WINDOW_HIGH, z), Vector3(w, WINDOW_LOW, z),
		Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), tint)
	# A quad's winding faces it toward +z: turn it round to face the front (-z).
	m.verts.reverse()
	m.uvs.reverse()
	m.colors.reverse()
	m.uv2s.reverse()
	return batch.to_mesh()


## The cab vestibule behind the front door: floor, ceiling and side walls, a back wall with a doorway into the dark saloon
## behind it, a strip light, a pole; surfaces facing in, so they show only through the doorway.
static func _vestibule(m: MeshLayer) -> void:
	var z0: float = LEAF_BACK + LEAF_THICK
	var z1: float = VESTIBULE_DEPTH
	var half: float = VESTIBULE_HALF
	var floor_c := Color(0.2, 0.18, 0.16)
	var wall_c := Color(0.74, 0.72, 0.64)
	var top: float = 2.55
	var door_half: float = 0.46
	_face(m, Vector3(-half, FLOOR + 0.01, z0), Vector3(half, FLOOR + 0.01, z0), Vector3(half, FLOOR + 0.01, z1),
		Vector3(-half, FLOOR + 0.01, z1), Vector3.UP, floor_c, 0.0, INSIDE)
	_face(m, Vector3(-half, top, z0), Vector3(half, top, z0), Vector3(half, top, z1), Vector3(-half, top, z1), Vector3.DOWN,
		wall_c, 0.0, INSIDE)
	_face(m, Vector3(-half, FLOOR, z0), Vector3(-half, top, z0), Vector3(-half, top, z1), Vector3(-half, FLOOR, z1), Vector3.RIGHT,
		wall_c, 0.0, INSIDE)
	_face(m, Vector3(half, FLOOR, z0), Vector3(half, top, z0), Vector3(half, top, z1), Vector3(half, FLOOR, z1), Vector3.LEFT,
		wall_c, 0.0, INSIDE)
	# The back wall, with the doorway.
	_face(m, Vector3(-half, FLOOR, z1), Vector3(-half, top, z1), Vector3(-door_half, top, z1), Vector3(-door_half, FLOOR, z1),
		Vector3.FORWARD, wall_c, 0.0, INSIDE)
	_face(m, Vector3(door_half, FLOOR, z1), Vector3(door_half, top, z1), Vector3(half, top, z1), Vector3(half, FLOOR, z1),
		Vector3.FORWARD, wall_c, 0.0, INSIDE)
	_face(m, Vector3(-door_half, 2.2, z1), Vector3(-door_half, top, z1), Vector3(door_half, top, z1), Vector3(door_half, 2.2, z1),
		Vector3.FORWARD, wall_c, 0.0, INSIDE)
	# The saloon beyond: nearly black.
	var dark := Color(0.02, 0.018, 0.016)
	var z2: float = z1 + 1.8
	_face(m, Vector3(-door_half, FLOOR, z1), Vector3(door_half, FLOOR, z1), Vector3(door_half, FLOOR, z2), Vector3(-door_half, FLOOR, z2),
		Vector3.UP, dark, 0.0, TRIM)
	_face(m, Vector3(-door_half, 2.2, z1), Vector3(door_half, 2.2, z1), Vector3(door_half, 2.2, z2), Vector3(-door_half, 2.2, z2),
		Vector3.DOWN, dark, 0.0, TRIM)
	_face(m, Vector3(-door_half, FLOOR, z1), Vector3(-door_half, 2.2, z1), Vector3(-door_half, 2.2, z2), Vector3(-door_half, FLOOR, z2),
		Vector3.RIGHT, dark, 0.0, TRIM)
	_face(m, Vector3(door_half, FLOOR, z1), Vector3(door_half, 2.2, z1), Vector3(door_half, 2.2, z2), Vector3(door_half, FLOOR, z2),
		Vector3.LEFT, dark, 0.0, TRIM)
	_face(m, Vector3(-door_half, FLOOR, z2), Vector3(-door_half, 2.2, z2), Vector3(door_half, 2.2, z2), Vector3(door_half, FLOOR, z2),
		Vector3.FORWARD, dark, 0.0, TRIM)
	# The cab's strip light (dim with the emergency light, bright with the saloon's) and a pole by the doorway.
	_face(m, Vector3(-0.16, top - 0.006, 0.45), Vector3(0.16, top - 0.006, 0.45), Vector3(0.16, top - 0.006, 1.5),
		Vector3(-0.16, top - 0.006, 1.5), Vector3.DOWN, Color(1.0, 0.9, 0.7), 1.0, LAMP, CAB)
	m.prism(Vector3(-0.62, FLOOR, 1.62), 0.022, 2.1, 6, Color(0.5, 0.48, 0.44), 0.0, STEEL, true)


# --- The sides ----------------------------------------------------------------------------------------------

## Where a car's doors and windows are along its side, from its front end (z spans): [doors, windows]. A cab car has its
## cab's side window and two doors, an intermediate car three doors; the tail car's are the head car's mirrored.
static func _layout(len: float, front: bool, back: bool) -> Array:
	var doors: Array = []
	var windows: Array = []
	if front or back:
		doors = [[4.3, 5.7], [9.1, 10.5]]
		windows = [[1.85, 3.75], [6.1, 8.7], [10.9, 13.5]]
		if back and not front:
			var d2: Array = []
			var w2: Array = []
			for span: Array in doors:
				d2.append([len - float(span[1]), len - float(span[0])])
			for span: Array in windows:
				w2.append([len - float(span[1]), len - float(span[0])])
			doors = d2
			windows = w2
	else:
		doors = [[1.9, 3.3], [6.3, 7.7], [10.7, 12.1]]
		windows = [[0.4, 1.6], [3.55, 6.05], [7.95, 10.45], [12.4, 13.6]]
	return [doors, windows]


static func _sides(m: MeshLayer, len: float, front: bool, back: bool, z0: float, z1: float, p_paint: Color, p_stripe: Color,
		dark: Color) -> void:
	var layout: Array = _layout(len, front, back)
	var door_color: Color = p_paint.darkened(0.07)
	var glass := Color(0.035, 0.045, 0.05)
	for side: float in [-1.0, 1.0]:
		# The skirt, the gutter and the stripe along the flat side.
		_side_rect(m, side, z0, z1, FLOOR, 0.64, dark, DECAL, 0.0, TRIM)
		_side_rect(m, side, z0, z1, 2.70, 2.78, dark, DECAL, 0.0, TRIM)
		for span: Array in layout[0]:
			var a: float = float(span[0])
			var b: float = float(span[1])
			# The door pair: a frame, two leaves, a seam, a window each.
			_side_rect(m, side, a - 0.06, b + 0.06, 0.46, 2.68, dark, DECAL, 0.0, TRIM)
			_side_rect(m, side, a, b, 0.5, 2.64, door_color, DECAL * 2.0, 0.0, PAINT)
			_side_rect(m, side, (a + b) * 0.5 - 0.012, (a + b) * 0.5 + 0.012, 0.5, 2.64, dark, DECAL * 3.0, 0.0, TRIM)
			for leaf: float in [0.0, 1.0]:
				var l0: float = lerpf(a, (a + b) * 0.5, leaf) + 0.12
				var l1: float = lerpf((a + b) * 0.5, b, leaf) - 0.12
				_side_rect(m, side, l0 - 0.03, l1 + 0.03, 1.25, 2.4, dark, DECAL * 2.5, 0.0, TRIM)
				_side_rect(m, side, l0, l1, 1.28, 2.37, glass, DECAL * 3.0, 0.0, GLASS, SALOON)
		for span: Array in layout[1]:
			var panes: int = maxi(1, ceili((float(span[1]) - float(span[0])) / 1.3))
			var pane_w: float = (float(span[1]) - float(span[0]) - 0.12 * float(panes - 1)) / float(panes)
			_side_rect(m, side, float(span[0]) - 0.05, float(span[1]) + 0.05, 1.22, 2.56, dark, DECAL, 0.0, TRIM)
			for k: int in panes:
				var a: float = float(span[0]) + float(k) * (pane_w + 0.12)
				_side_rect(m, side, a, a + pane_w, 1.28, 2.5, glass, DECAL * 2.0, 0.0, GLASS, SALOON)
		_side_rect(m, side, z0, z1, 0.98, 1.14, p_stripe, DECAL * 4.0, 0.0, PAINT)


## A rectangle on the flat side wall (x = side * WALL + the decal offset), from z0 to z1 and y0 to y1 (a car's space).
static func _side_rect(m: MeshLayer, side: float, z0: float, z1: float, y0: float, y1: float, color: Color, off: float,
		glow: float, finish: int, group: float = 0.0) -> void:
	var x: float = side * (WALL + off)
	_face(m, Vector3(x, y0, z0), Vector3(x, y1, z0), Vector3(x, y1, z1), Vector3(x, y0, z1), Vector3(side, 0.0, 0.0), color, glow,
		finish, group)


# --- Roof, underframe, vines --------------------------------------------------------------------------------

## Two air-conditioning units on a car's roof, vents, and on the middle cars a folded pantograph.
static func _roof(m: MeshLayer, start: float, len: float, i: int, p_cars: int) -> void:
	var unit := Color(0.2, 0.19, 0.17)
	for f: float in [0.3, 0.72]:
		var z: float = start + len * f
		m.box(Vector3(0.0, 3.54 + 0.14, z), Vector3(1.5, 0.28, 2.2), unit, 0.0, TRIM)
		m.box(Vector3(0.0, 3.54 + 0.3, z), Vector3(1.3, 0.04, 2.0), Color(0.16, 0.15, 0.14), 0.0, TRIM)
		for k: int in 4:
			m.box(Vector3(0.0, 3.54 + 0.17, z - 0.75 + float(k) * 0.5), Vector3(1.52, 0.1, 0.05), Color(0.1, 0.09, 0.08), 0.0, TRIM)
	# Cable ducts along the roof's crown.
	m.box(Vector3(0.0, 3.57, start + len * 0.5), Vector3(0.12, 0.05, len * 0.9), Color(0.08, 0.075, 0.07), 0.0, TRIM)
	if i > 0 and i < p_cars - 1:
		# A folded pantograph: base frame on insulators, two arms lying nearly flat, a collector bar across.
		var z: float = start + len * 0.5
		var steel := Color(0.28, 0.25, 0.22)
		for side: float in [-1.0, 1.0]:
			m.box(Vector3(side * 0.5, 3.54 + 0.08, z), Vector3(0.1, 0.16, 1.5), Color(0.55, 0.5, 0.42), 0.0, PAINT)
			m.box_xform(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(8.0)) * Basis.from_scale(Vector3(0.05, 0.05, 1.5)),
				Vector3(side * 0.42, 3.54 + 0.26, z)), steel, 0.0, STEEL)
			m.box_xform(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-6.0)) * Basis.from_scale(Vector3(0.05, 0.05, 1.3)),
				Vector3(side * 0.42, 3.54 + 0.34, z + 0.1)), steel, 0.0, STEEL)
		m.box(Vector3(0.0, 3.54 + 0.4, z - 0.6), Vector3(1.7, 0.05, 0.08), Color(0.12, 0.1, 0.09), 0.0, TRIM)


## A bogie's wheels and frame under the skirt (the part the skirt leaves showing).
static func _bogie(m: MeshLayer, z: float) -> void:
	var frame := Color(0.1, 0.095, 0.09)
	m.box(Vector3(0.0, 0.18, z), Vector3(1.9, 0.14, 2.3), frame, 0.0, TRIM)
	for side: float in [-1.0, 1.0]:
		for axle: float in [-0.95, 0.95]:
			var along_x := Transform3D(Basis(Vector3(0.0, 0.33, 0.0), Vector3(0.12, 0.0, 0.0), Vector3(0.0, 0.0, 0.33)),
				Vector3(side * 0.72 - 0.06, 0.33, z + axle))
			m.prism_xform(along_x, 8, Color(0.16, 0.14, 0.12), 0.0, STEEL, true)
		# The third-rail shoe on the side of the frame.
		m.box(Vector3(side * 1.02, 0.18, z + 0.95), Vector3(0.18, 0.1, 0.34), Color(0.12, 0.11, 0.1), 0.0, TRIM)


## Strips of vine hanging off the roof's edge and down the sides (each a few thin, ragged strands), and over the tail's face.
static func _vines(m: MeshLayer, p_cars: int, count: int) -> void:
	var total: float = length_of(p_cars)
	var vine := Color(0.14, 0.27, 0.09)
	for i: int in count:
		var side: float = -1.0 if MeshKit.hash01(i, 1, 940) < 0.5 else 1.0
		var z: float = 3.0 + (total - 6.0) * MeshKit.hash01(i, 2, 940)
		for strand: int in 3:
			var drop: float = (0.7 + 1.6 * MeshKit.hash01(i, 3, 940)) * (0.55 + 0.45 * MeshKit.hash01(i, strand, 941))
			var w: float = 0.09 + 0.1 * MeshKit.hash01(i, strand + 4, 940)
			var zs: float = z + (float(strand) - 1.0) * 0.16
			var pts: Array[Vector3] = [Vector3(side * 1.47, 3.24, zs), Vector3(side * (WALL + 0.045), 2.76, zs + 0.03)]
			var seg: int = 4
			for k: int in seg:
				var u: float = float(k + 1) / float(seg)
				pts.append(Vector3(side * (WALL + 0.045), 2.76 - drop * u, zs + 0.03 + 0.1 * sin(float(k) * 1.7 + float(i + strand))))
			for k: int in pts.size() - 1:
				var a: Vector3 = pts[k]
				var b: Vector3 = pts[k + 1]
				var taper: float = 1.0 - 0.7 * float(k) / float(pts.size() - 1)
				var ha: float = w * 0.5 * taper
				var hb: float = w * 0.5 * (taper - 0.12)
				_face(m, a + Vector3(0.0, 0.0, -ha), a + Vector3(0.0, 0.0, ha), b + Vector3(0.0, 0.0, hb), b + Vector3(0.0, 0.0, -hb),
					Vector3(side, 0.35, 0.0), vine, 0.0, VINE)
	# Over the tail's face: a few strands hanging from its roof strip, clear of its lamps.
	if count > 0:
		for j: int in 4:
			var x: float = -1.0 + 0.62 * float(j) + 0.2 * MeshKit.hash01(j, 7, 940)
			var top: float = 3.1
			var bottom: float = 2.0 - 0.5 * MeshKit.hash01(j, 8, 940)
			var zt: float = total + 0.02 + DECAL * 6.0
			_face(m, Vector3(x - 0.07, top, zt), Vector3(x + 0.07, top, zt), Vector3(x + 0.03, bottom, zt), Vector3(x - 0.03, bottom, zt),
				Vector3.BACK, vine, 0.0, VINE)


## The glow cards (MeshKit's glow material, scaled by the lights): the headlights' pools on the track ahead, halos at the
## headlights and the tail lights' halos behind.
static func _glow_mesh(p_cars: int) -> ArrayMesh:
	var batch := MeshBatch.new()
	var g: MeshLayer = batch.layer(null)
	var total: float = length_of(p_cars)
	var white := Color(1.0, 0.95, 0.82)
	for side: float in [-1.0, 1.0]:
		var x: float = side * 1.05
		# The pool on the track: bright at the nose, fading ahead of it.
		g.rect(Vector3(x - 0.7, 0.04, -0.1), Vector3(1.4, 0.0, 0.0), Vector3(0.0, 0.0, -12.0), white, 0.16, MeshKit.SHAPE_BEAM)
		g.rect(Vector3(x - 0.5, 0.76 - 0.5, -0.05), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), white, 0.45, MeshKit.SHAPE_RADIAL)
		var tail := Color(1.0, 0.12, 0.1)
		g.rect(Vector3(x - 0.5, 0.76 - 0.5, total + 0.06), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), tail, 0.5,
			MeshKit.SHAPE_RADIAL)
		g.rect(Vector3(x - 0.7, 0.04, total + 0.1), Vector3(1.4, 0.0, 0.0), Vector3(0.0, 0.0, 3.5), tail, 0.08, MeshKit.SHAPE_BEAM)
	return batch.to_mesh()


# --- Faces --------------------------------------------------------------------------------------------------

## A four-cornered face, turned to face `outward` (Godot's front faces wind clockwise).
static func _face(m: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color,
		glow: float = 0.0, finish: int = PAINT, group: float = 0.0) -> void:
	var n: Vector3 = (b - a).cross(c - a) + (c - a).cross(d - a)
	if n.dot(outward) > 0.0:
		m.quad(a, d, c, b, color, glow, finish, group)
	else:
		m.quad(a, b, c, d, color, glow, finish, group)


static func _tri(m: MeshLayer, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, color: Color, glow: float = 0.0,
		finish: int = PAINT, group: float = 0.0) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	var verts := PackedVector3Array([a, c, b] if n.dot(outward) > 0.0 else [a, b, c])
	m.verts.append_array(verts)
	var col := Color(color, glow)
	m.colors.append_array(PackedColorArray([col, col, col]))
	m.uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2(0, 1), Vector2(1, 1)]))
	var p := Vector2(finish, group)
	m.uv2s.append_array(PackedVector2Array([p, p, p]))
