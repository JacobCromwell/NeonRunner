class_name CityIntroHead
extends Node3D
## The Floating Head in the City intro (CityIntro; GDD §6, Cinematics, the owner's October 16, 2026 beats): the fight's
## own ship and face (FloatingHeadModel's hull, face screen under the fight's face shader, jaw, searchlight and bay
## doors), hanging in the street with its face showing, watching over the cyborgs with its searchlight (cold white
## always: red is the bombs'), then startled (wide eyes, an "O" for a mouth: the face shader's `surprise`), angry, and
## yelling (the jaw wide open). Visual only: no hitboxes, no gameplay, no encounter; CityIntro drives it from the
## cinematic's clock (`express`, `light`), so stepping or skipping shows the same. FloatingHeadBody is the fight's and needs
## a run to live in; this is the same parts, driven the same way (its `_animate`), for a set with none.
##
## World space (see CityIntroStreet): y = 0 the road; the ship's space is the fight's: +z (the stern, where the face is) toward
## the start of the track, the bow toward the end.

const FACE_SHADER: String = "res://scripts/bosses/floating_head/floating_head_face.gdshader"
const LENS_WHITE := Color(0.85, 0.92, 1.0)
const FACE_WHITE := Color(0.86, 0.91, 1.0)
## The light fades out within this many metres of the camera (the light shader's near_fade): the camera is in the street it shines
## down, and the beam and its spot never fill the picture.
const NEAR_FADE: float = 9.0

var shape: FloatingHeadModel.Shape
var ship: Node3D
var hull: MeshInstance3D
var screen: MeshInstance3D
var face: ShaderMaterial
var jaw: Node3D
var lip: MeshInstance3D
var mouth_glow: MeshInstance3D
var lamp_head: Node3D
var lens: MeshInstance3D
var beam: MeshInstance3D
var spot: MeshInstance3D
var floor_glow: MeshInstance3D

var _mouth_material: StandardMaterial3D
var _beam_material: ShaderMaterial
var _spot_material: ShaderMaterial
var _doors: Array[Node3D] = []
## The expression now (express()).
var jaw_open: float = 0.0
var surprise: float = 0.0
var anger: float = 0.35
var glitch: float = 0.0
## Where the face looks (the pupils), -1 to 1 across and up.
var look := Vector2.ZERO


## Builds the ship for `geo`'s street (as wide as the fight's, FloatingHeadModel.shape_for).
func build(geo: TrackGeometry, boss_tuning: FloatingHeadTuning) -> void:
	shape = FloatingHeadModel.shape_for(geo.wall_x() * 2.0, geo.lane_count, boss_tuning, geo.lane_width)
	var meshes: Dictionary = FloatingHeadModel.meshes(shape)
	ship = Node3D.new()
	ship.name = "Ship"
	add_child(ship)
	hull = MeshBatch.add_instance(ship, meshes["hull"], "Hull")
	screen = MeshBatch.add_instance(ship, meshes["screen"], "Screen", shape.screen_center)
	face = ShaderMaterial.new()
	face.shader = load(FACE_SHADER) as Shader
	face.set_shader_parameter(&"aspect", shape.screen_size.x / shape.screen_size.y)
	face.set_shader_parameter(&"power", 1.0)
	screen.material_override = face
	jaw = Node3D.new()
	jaw.name = "Jaw"
	jaw.position = shape.jaw_hinge
	ship.add_child(jaw)
	MeshBatch.add_instance(jaw, meshes["jaw"])
	lip = MeshBatch.add_instance(jaw, meshes["lip"], "Lip")
	lip.material_override = GreyboxMaterials.glow(FACE_WHITE, 2.6)
	# The mouth's inside lights up in the face's cold white as the jaw drops open, as in the fight's cyborg drop.
	_mouth_material = StandardMaterial3D.new()
	_mouth_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mouth_material.emission_enabled = true
	_mouth_material.emission = FACE_WHITE
	var quad := QuadMesh.new()
	quad.size = Vector2(shape.mouth_half * 2.0, shape.mouth_top - shape.mouth_bottom)
	mouth_glow = MeshInstance3D.new()
	mouth_glow.name = "MouthGlow"
	mouth_glow.mesh = quad
	mouth_glow.material_override = _mouth_material
	mouth_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mouth_glow.position = Vector3(0.0, (shape.mouth_bottom + shape.mouth_top) * 0.5, 0.08)
	mouth_glow.visible = false
	ship.add_child(mouth_glow)
	lamp_head = Node3D.new()
	lamp_head.name = "Searchlight"
	lamp_head.position = shape.lamp_pivot
	ship.add_child(lamp_head)
	MeshBatch.add_instance(lamp_head, meshes["lamp"])
	lens = MeshBatch.add_instance(lamp_head, meshes["lens"], "Lens")
	lens.material_override = GreyboxMaterials.glow(LENS_WHITE, 4.0)
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "BayDoor"
		hinge.position = Vector3(side * shape.bay_half, -0.02, shape.bay_center.z)
		hinge.rotation.y = 0.0 if side < 0.0 else PI
		ship.add_child(hinge)
		MeshBatch.add_instance(hinge, meshes["door"])
		_doors.append(hinge)
	for p: Vector3 in shape.weak_points:
		MeshBatch.add_instance(ship, meshes["cover"], "WeakPointCover", p)
	_build_light()
	_build_floor_glow()


## The searchlight's beam and its spot: the fight's own meshes and shader (additive, cold white).
func _build_light() -> void:
	var shader := load("res://scripts/bosses/floating_head/floating_head_light.gdshader") as Shader
	_beam_material = ShaderMaterial.new()
	_beam_material.shader = shader
	_beam_material.set_shader_parameter(&"shape", 0)
	_beam_material.set_shader_parameter(&"light_color", FloatingHeadBombing.LIGHT_WHITE)
	_beam_material.set_shader_parameter(&"near_fade", NEAR_FADE)
	_spot_material = ShaderMaterial.new()
	_spot_material.shader = shader
	_spot_material.set_shader_parameter(&"shape", 1)
	_spot_material.set_shader_parameter(&"light_color", FloatingHeadBombing.LIGHT_WHITE)
	_spot_material.set_shader_parameter(&"near_fade", NEAR_FADE)
	beam = MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = FloatingHeadBombing.beam_mesh()
	beam.material_override = _beam_material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.top_level = true
	beam.visible = false
	add_child(beam)
	spot = MeshInstance3D.new()
	spot.name = "Spot"
	spot.mesh = FloatingHeadBombing.spot_mesh()
	spot.material_override = _spot_material
	spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spot.top_level = true
	spot.visible = false
	add_child(spot)


## The lift pads' glow on the street under the ship, as in the fight (it shows lower the lower it flies).
func _build_floor_glow() -> void:
	var batch := MeshBatch.new()
	var glow_material: ShaderMaterial = FloatingHeadModel.glow_material().duplicate() as ShaderMaterial
	glow_material.set_shader_parameter(&"state_glow", 0.4)
	var g: MeshLayer = batch.layer(glow_material)
	var hw: float = shape.width * 0.62
	var hl: float = shape.length * 0.55
	g.rect(Vector3(-hw, 0.0, -hl), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, hl * 2.0), FloatingHeadModel.ENGINE, 0.45,
		MeshKit.SHAPE_RADIAL)
	floor_glow = batch.commit(self, "FloorGlow")
	floor_glow.top_level = true


## Where the ship is: its face's plane at track distance `face_at`, its belly `belly` metres up (the middle of the
## street).
func place(face_at: float, belly: float) -> void:
	ship.position = Vector3(0.0, belly, TrackGeometry.world_z(face_at))
	var road_z: float = ship.position.z - shape.length * 0.5
	floor_glow.global_position = Vector3(0.0, 0.07, road_z)


## The face's state at this moment. `watching`: where it looks (world space; the pupils follow it as in the fight);
## `jaw`: the mouth, 0 shut to 1 wide open; `time` the clock (it blinks now and then, as in the fight).
func express(time: float, watching: Vector3, p_anger: float, p_surprise: float, p_jaw: float, p_glitch: float) -> void:
	anger = p_anger
	surprise = p_surprise
	jaw_open = p_jaw
	glitch = p_glitch
	var eye: Vector3 = ship.to_local(watching) - shape.screen_center
	look = Vector2(clampf(eye.x / 7.0, -1.0, 1.0), clampf(eye.y / 10.0, -1.0, 1.0))
	var blink: float = clampf(1.0 - absf(fmod(time, 4.7) - 0.09) / 0.09, 0.0, 1.0) * (1.0 - surprise)
	face.set_shader_parameter(&"look", look)
	face.set_shader_parameter(&"anger", anger)
	face.set_shader_parameter(&"surprise", surprise)
	face.set_shader_parameter(&"blink", blink)
	face.set_shader_parameter(&"glitch", glitch)
	# The jaw drops open (sliding down below the mouth, its chin tipping toward the street), the mouth's inside lighting up.
	var open: float = smoothstep(0.0, 1.0, clampf(jaw_open, 0.0, 1.0))
	var jaw_height: float = shape.mouth_top - shape.mouth_bottom + 0.16
	jaw.position = shape.jaw_hinge + Vector3(0.0, -(jaw_height + 0.3) * open, 0.3 * open)
	jaw.rotation.x = -deg_to_rad(14.0) * open
	mouth_glow.visible = open > 0.01
	_mouth_material.albedo_color = Color(FACE_WHITE.r * open, FACE_WHITE.g * open, FACE_WHITE.b * open)
	_mouth_material.emission_energy_multiplier = 2.2 * open
	for door: Node3D in _doors:
		door.rotation.z = 0.0


## The searchlight: on or off, shining at `target` (world space) where the surface there faces `normal`, its spot `radius`
## wide, `strength` 0-1 (it fades in and out with it). Cold white: its colour never changes.
func light(target: Vector3, normal: Vector3, radius: float, strength: float) -> void:
	var on: bool = strength > 0.001
	beam.visible = on
	spot.visible = on
	var aim: Vector3 = target if on else ship.to_global(shape.lamp_pivot + Vector3(0.0, -4.0, 1.5))
	var dir: Vector3 = aim - lamp_head.global_position
	if dir.length() > 0.1:
		var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.BACK
		lamp_head.look_at(aim, up)
	if not on:
		return
	# The spot: a soft disc on the surface the light lands on (the road, or a wall).
	var n: Vector3 = normal.normalized()
	var tangent: Vector3 = n.cross(Vector3.RIGHT)
	if tangent.length() < 0.2:
		tangent = n.cross(Vector3.BACK)
	tangent = tangent.normalized()
	var bitangent: Vector3 = n.cross(tangent).normalized()
	spot.global_transform = Transform3D(Basis(tangent * radius * 1.15, n, bitangent * radius * 1.15), target + n * 0.03)
	_spot_material.set_shader_parameter(&"strength", 1.6 * strength * (1.0 - 0.35 * absf(n.dot(Vector3.RIGHT))))
	var from: Vector3 = lens_world()
	var along: Vector3 = target - from
	var length: float = along.length()
	if length > 0.5:
		var up2: Vector3 = Vector3.UP if absf(along.normalized().y) < 0.98 else Vector3.BACK
		var r: float = radius * 0.8
		beam.global_transform = Transform3D(Basis.looking_at(along, up2) * Basis.from_scale(Vector3(r, r, length)), from)
	_beam_material.set_shader_parameter(&"strength", strength)


## The searchlight's lens (world space), where its beam starts.
func lens_world() -> Vector3:
	return lens.global_position if is_inside_tree() else global_position


## The face screen's centre (world space) and one eye's (`side` -1 the viewer's left).
func screen_world() -> Vector3:
	return screen.global_position


func eye_world(side: int) -> Vector3:
	var sh: float = shape.screen_size.y
	return ship.to_global(shape.screen_center + Vector3(side * 0.26 * sh, 0.02 * sh, 0.05))


## The mouth's opening (world space).
func mouth_world() -> Vector3:
	return ship.to_global(Vector3(0.0, (shape.mouth_bottom + shape.mouth_top) * 0.5, shape.mouth_front + 0.4))
