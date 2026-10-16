class_name CityIntroCrowd
extends Node3D
## The City intro's pedestrians (CityIntro; the owner's October 16, 2026 beats: "lots of people ... on the streets"):
## a few hundred people on both sidewalks, walking both ways, some with a strip of neon on their shoulders. The
## Marketplace's citizens (CitizenRig) are baked flipbook cards that stand and cheer in shop windows; they never walk, so
## these are a new low-poly person of the same plain, ordinary kind (skin tones and everyday clothes in muted tones, never
## a hazard's hue, never a cyborg's cold white), all in one MultiMesh and walked by a vertex shader (city_intro_crowd.gdshader):
## the CPU's cost per frame is one uniform, however many there are.
##
## World space (see CityIntroStreet): the sidewalks between the kerbs and the walls; a track distance z is world z = -z.

const SHADER: String = "res://scripts/cinematics/city_intro/city_intro_crowd.gdshader"
## The person: parts as the shader's vertex colour tags them.
const TORSO: int = 0
const LEG_L: int = 1
const LEG_R: int = 2
const ARM_L: int = 3
const ARM_R: int = 4
const HEAD: int = 5
const HAIR: int = 6
const TRIM: int = 7

var multi: MultiMesh
var node: MultiMeshInstance3D
var material: ShaderMaterial
var count: int = 0
## Where each person starts (world space) and its walking speed along world z (the sign its way).
var starts: Array[Vector3] = []
var velocities := PackedFloat32Array()
var loop_low: float = 0.0
var loop_length: float = 0.0


## Builds `per_side` people on each sidewalk of a street whose kerbs are `road_half` and walls `wall_half` from its middle,
## walking a loop from track distance `z_lo` to `z_hi`, at speeds in `speeds` (m/s).
func build(road_half: float, wall_half: float, z_lo: float, z_hi: float, per_side: int, speeds: Vector2) -> void:
	loop_low = -z_hi
	loop_length = z_hi - z_lo
	count = per_side * 2
	multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = _person()
	multi.instance_count = count
	material = ShaderMaterial.new()
	material.shader = load(SHADER) as Shader
	material.set_shader_parameter(&"loop_low", loop_low)
	material.set_shader_parameter(&"loop_length", loop_length)
	node = MultiMeshInstance3D.new()
	node.name = "People"
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-wall_half, -0.1, loop_low), Vector3(wall_half * 2.0, 2.2, loop_length))
	add_child(node)
	var i: int = 0
	for side: int in [-1, 1]:
		for k: int in per_side:
			var key: int = MeshKit.hash_i(side + 3, k, 91)
			var lane: float = road_half + 0.55 + (wall_half - road_half - 1.1) * MeshKit.hash01(side + 3, k, 92)
			var x: float = side * lane
			var z: float = loop_low + loop_length * MeshKit.hash01(side + 3, k, 93)
			var going: float = 1.0 if MeshKit.hash01(side + 3, k, 94) < 0.5 else -1.0
			var speed: float = lerpf(speeds.x, speeds.y, MeshKit.hash01(side + 3, k, 95))
			var size: float = 0.9 + 0.12 * MeshKit.hash01(side + 3, k, 96)
			var xf := Transform3D(Basis(Vector3.UP, 0.0 if going > 0.0 else PI), Vector3(x, 0.0, z))
			multi.set_instance_transform(i, xf)
			multi.set_instance_custom_data(i, Color(MeshKit.hash01(key, 97), MeshKit.hash01(key, 98), going * speed, size))
			starts.append(xf.origin)
			velocities.append(going * speed)
			i += 1


## The clock: where everyone is at time `t` follows (the vertex shader walks them).
func update(t: float) -> void:
	if material != null:
		material.set_shader_parameter(&"u_time", t)


## Where person `i` is at time `t` (world space), as the shader places them.
func position_at(i: int, t: float) -> Vector3:
	var p: Vector3 = starts[i]
	p.z = loop_low + fposmod(p.z - loop_low + velocities[i] * t, loop_length)
	return p


## One person, feet on y = 0, facing +z, about 1.7 m: legs, torso, arms, head, hair and a shoulder strip, the parts tagged
## for the shader in the UV2 the kit keeps its pattern ids in.
func _person() -> ArrayMesh:
	var batch := MeshBatch.new()
	var l: MeshLayer = batch.layer(null)
	_part(l, Vector3(-0.1, 0.4, 0.0), Vector3(0.15, 0.8, 0.18), LEG_L)
	_part(l, Vector3(0.1, 0.4, 0.0), Vector3(0.15, 0.8, 0.18), LEG_R)
	_part(l, Vector3(0.0, 1.12, 0.0), Vector3(0.44, 0.6, 0.24), TORSO)
	_part(l, Vector3(-0.29, 1.1, 0.0), Vector3(0.11, 0.6, 0.13), ARM_L)
	_part(l, Vector3(0.29, 1.1, 0.0), Vector3(0.11, 0.6, 0.13), ARM_R)
	_part(l, Vector3(0.0, 1.56, 0.0), Vector3(0.2, 0.24, 0.22), HEAD)
	_part(l, Vector3(0.0, 1.69, -0.01), Vector3(0.215, 0.1, 0.24), HAIR)
	_part(l, Vector3(0.0, 1.42, 0.0), Vector3(0.47, 0.05, 0.27), TRIM)
	return batch.to_mesh()


func _part(layer: MeshLayer, center: Vector3, size: Vector3, part: int) -> void:
	layer.box(center, size, Color.WHITE, 0.0, part)
