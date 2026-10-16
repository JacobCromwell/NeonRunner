class_name CityIntroWindow
extends Node3D
## The breakable window of the City intro (CityIntro; the owner's October 16, 2026 beat: "the glass bursts just behind"
## the searchlight as it sweeps past, and the runner leaps out of it): a lit window in a building's face, a frame
## round a pane of dark glass over a warm-lit room; at the moment it bursts the pane is gone, the room is a dark opening
## with a few jagged teeth of glass left in the frame, and the glass flies out into the street as a spray of shards that
## tumble, fall and lie on the road. Visual only: no collision and no gameplay; the shards' flight is worked out from
## the clock, so stepping or skipping shows the same.
##
## World space (see CityIntroStreet): y = 0 the road, x = 0 the street's middle, a track distance z is world z = -z.

const FRAME := Color(0.11, 0.11, 0.15)
const GLASS_DARK := Color(0.035, 0.05, 0.1)
const ROOM_LIGHT := Color(1.0, 0.86, 0.66)
const GRAVITY: float = 9.8
## The road the shards land on, and how long they take to lie flat once they have.
const GROUND: float = 0.04
const FLATTEN_SECONDS: float = 0.12

## The window: its side (-1 left), where it is (track distance of its middle), its sill and its size.
var side: int = -1
var z: float = 0.0
var sill: float = 0.0
var width: float = 0.0
var height: float = 0.0
## The wall's face x, and when it bursts.
var wall_x: float = 0.0
var burst_time: float = 0.0
var shards: MultiMeshInstance3D
var multi: MultiMesh
var intact: MeshInstance3D
var broken: MeshInstance3D
var frame: MeshInstance3D

## Each shard: where it starts, its velocity, its tumble (axis and rate), its size and where it lies flat.
var _start: Array[Vector3] = []
var _velocity: Array[Vector3] = []
var _axis: Array[Vector3] = []
var _rate := PackedFloat32Array()
var _size := PackedFloat32Array()
var _land := PackedFloat32Array()
var _yaw := PackedFloat32Array()


## Builds the window on `p_side`'s wall (whose face is at x = side * wall_half), `p_z` along the track, its sill `p_sill` up,
## `p_width` x `p_height` metres, with `shard_count` shards of glass for when it bursts at `p_burst`.
func build(skin: CitySkin, wall_half: float, p_side: int, p_z: float, p_sill: float, p_width: float, p_height: float,
		shard_count: int, p_burst: float) -> void:
	side = p_side
	z = p_z
	sill = p_sill
	width = p_width
	height = p_height
	wall_x = side * wall_half
	burst_time = p_burst
	var z0: float = z - width * 0.5
	var z1: float = z + width * 0.5
	var y0: float = sill
	var y1: float = sill + height
	var fx: float = wall_x - side * 0.05
	# The frame: a sill, a lintel, jambs and a mullion down the middle.
	var fb := MeshBatch.new()
	var fs: MeshLayer = fb.layer(skin.solid_material())
	var t: float = 0.12
	_rect(fs, fx - side * 0.03, z0 - t, z1 + t, y0 - t, y0, FRAME)
	_rect(fs, fx - side * 0.03, z0 - t, z1 + t, y1, y1 + t, FRAME)
	_rect(fs, fx - side * 0.03, z0 - t, z0, y0, y1, FRAME)
	_rect(fs, fx - side * 0.03, z1, z1 + t, y0, y1, FRAME)
	_rect(fs, fx - side * 0.03, z - 0.04, z + 0.04, y0, y1, FRAME)
	_rect(fs, fx - side * 0.03, z0 - t - 0.1, z1 + t + 0.1, y0 - t - 0.08, y0 - t, FRAME.lightened(0.15))
	frame = fb.commit(self, "Frame")
	# The pane, intact: the lit room behind it (a warm light in the dark), a pale diagonal sheen of the street across the glass.
	var ib := MeshBatch.new()
	var is_: MeshLayer = ib.layer(skin.solid_material())
	var ig: MeshLayer = ib.layer(skin.glow_material())
	_rect(is_, fx - side * 0.02, z0, z1, y0, y1, ROOM_LIGHT.darkened(0.25), 0.5)
	_rect(is_, fx - side * 0.03, z0, z1, y0, y0 + height * 0.18, ROOM_LIGHT.darkened(0.6), 0.3)
	_rect(ig, fx - side * 0.04, z0 - 0.3, z1 + 0.3, y0 - 0.3, y1 + 0.3, ROOM_LIGHT, 0.25, MeshKit.SHAPE_RADIAL)
	for k: int in 2:
		var sz: float = lerpf(z0, z1, 0.2 + 0.4 * float(k))
		_rect(ig, fx - side * 0.045, sz, sz + 0.35, y0 + 0.1, y1 - 0.1, Color(0.8, 0.9, 1.0), 0.1, MeshKit.SHAPE_FLAT)
	intact = ib.commit(self, "Pane")
	# Burst: the room a dark opening (its warm light low in it), a few jagged teeth of glass left in the frame.
	var bb := MeshBatch.new()
	var bs: MeshLayer = bb.layer(skin.solid_material())
	var bg: MeshLayer = bb.layer(skin.glow_material())
	_rect(bs, fx - side * 0.02, z0, z1, y0, y1, Color(0.03, 0.025, 0.04))
	_rect(bg, fx - side * 0.025, z0 + 0.3, z1 - 0.3, y0, y0 + height * 0.45, ROOM_LIGHT, 0.14, MeshKit.SHAPE_FLAT)
	for k: int in 7:
		var u: float = (float(k) + 0.5) / 7.0
		var tooth: float = 0.18 + 0.3 * MeshKit.hash01(k, 3, 201)
		var cz: float = lerpf(z0, z1, u)
		# A tooth hanging from the lintel and one standing on the sill: a thin triangle each.
		_triangle(bs, fx - side * 0.045, cz - 0.1, cz + 0.1, cz, y1, y1 - tooth, GLASS_DARK.lightened(0.5))
		if k % 2 == 0:
			var tooth2: float = 0.1 + 0.25 * MeshKit.hash01(k, 4, 202)
			_triangle(bs, fx - side * 0.045, cz - 0.12, cz + 0.12, cz + 0.03, y0, y0 + tooth2, GLASS_DARK.lightened(0.5))
	broken = bb.commit(self, "Opening")
	broken.visible = false
	_build_shards(shard_count)


## A rectangle on the wall at x, between track distances a and b and heights y0 and y1, facing the street.
func _rect(layer: MeshLayer, x: float, a: float, b: float, y0: float, y1: float, color: Color, glow: float = 0.0,
		pattern: int = 0) -> void:
	if side < 0:
		layer.rect(Vector3(x, y0, -a), Vector3(0.0, 0.0, -(b - a)), Vector3(0.0, y1 - y0, 0.0), color, glow, pattern)
	else:
		layer.rect(Vector3(x, y0, -b), Vector3(0.0, 0.0, b - a), Vector3(0.0, y1 - y0, 0.0), color, glow, pattern)


## A thin triangle on the wall: its base from track distance a to b at height y_base, its tip at c, y_tip.
func _triangle(layer: MeshLayer, x: float, a: float, b: float, c: float, y_base: float, y_tip: float, color: Color) -> void:
	var pa := Vector3(x, y_base, -a)
	var pb := Vector3(x, y_base, -b)
	var pc := Vector3(x, y_tip, -c)
	layer.verts.append_array(PackedVector3Array([pa, pc, pb] if side < 0 else [pa, pb, pc]))
	var col := Color(color, 0.0)
	layer.colors.append_array(PackedColorArray([col, col, col]))
	layer.uvs.append_array(PackedVector2Array([Vector2(0, 0), Vector2(0.5, 1), Vector2(1, 0)]))
	var p := Vector2(MeshKit.PAT_PLAIN, 0.0)
	layer.uv2s.append_array(PackedVector2Array([p, p, p]))


func _build_shards(count: int) -> void:
	var tri := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0.0, 0.6, 0.0), Vector3(-0.4, -0.4, 0.0), Vector3(0.4, -0.4, 0.0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	tri.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.74, 0.88, 1.0, 0.78)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.75, 1.0)
	mat.emission_energy_multiplier = 1.1
	tri.surface_set_material(0, mat)
	multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = tri
	multi.instance_count = count
	shards = MultiMeshInstance3D.new()
	shards.name = "Shards"
	shards.multimesh = multi
	shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shards.visible = false
	add_child(shards)
	var out: float = -float(side)
	for i: int in count:
		var u: float = MeshKit.hash01(i, 1, 211)
		var v: float = MeshKit.hash01(i, 2, 212)
		var start := Vector3(wall_x - side * 0.1, sill + height * v, -(z + (u - 0.5) * width))
		# Out into the street, up or down a little, along the wall either way; the middle of the pane flies furthest.
		var speed: float = 1.5 + 4.5 * MeshKit.hash01(i, 3, 213)
		var along: float = (u - 0.5) * 5.0 + (MeshKit.hash01(i, 4, 214) - 0.5) * 2.0
		var vel := Vector3(out * speed, 2.2 * (v - 0.35) + MeshKit.hash01(i, 5, 215) * 1.6, along)
		_start.append(start)
		_velocity.append(vel)
		_axis.append(Vector3(MeshKit.hash01(i, 6, 216) - 0.5, MeshKit.hash01(i, 7, 217) - 0.5,
			MeshKit.hash01(i, 8, 218) - 0.5).normalized())
		_rate.append(4.0 + 10.0 * MeshKit.hash01(i, 9, 219))
		_size.append(0.06 + 0.2 * MeshKit.hash01(i, 10, 220) * MeshKit.hash01(i, 11, 221) + 0.04)
		_yaw.append(TAU * MeshKit.hash01(i, 12, 222))
		# The time it lands: y(t) = y0 + vy t - g t^2 / 2 = GROUND.
		var disc: float = vel.y * vel.y + 2.0 * GRAVITY * (start.y - GROUND)
		_land.append((vel.y + sqrt(maxf(disc, 0.0))) / GRAVITY)
	_place(0.0)


## The window as it is at time `t`: intact before it bursts, the opening and the flying glass after.
func update(t: float) -> void:
	var bursting: bool = t >= burst_time
	intact.visible = not bursting
	broken.visible = bursting
	shards.visible = bursting
	if bursting:
		_place(t - burst_time)


## Where shard `i` is `age` seconds after the burst (world space).
func shard_position(i: int, age: float) -> Vector3:
	var at: float = minf(age, _land[i])
	var p: Vector3 = _start[i] + _velocity[i] * at + Vector3(0.0, -0.5 * GRAVITY * at * at, 0.0)
	# After it lands it skids a little, then lies still.
	if age > _land[i]:
		var slide: float = 1.0 - exp(-4.0 * (age - _land[i]))
		p += Vector3(_velocity[i].x, 0.0, _velocity[i].z) * 0.08 * slide
		p.y = GROUND
	return p


func _place(age: float) -> void:
	for i: int in multi.instance_count:
		var p: Vector3 = shard_position(i, age)
		var spin := Basis(_axis[i], _rate[i] * minf(age, _land[i]))
		if age > _land[i]:
			# Down on the road: tipped flat, turned to a place of its own.
			var flat := Basis(Vector3.UP, _yaw[i]) * Basis(Vector3.RIGHT, -PI * 0.5)
			var k: float = smoothstep(0.0, 1.0, clampf((age - _land[i]) / FLATTEN_SECONDS, 0.0, 1.0))
			spin = Basis(spin.get_rotation_quaternion().slerp(flat.get_rotation_quaternion(), k))
		var xf := Transform3D(spin.scaled(Vector3.ONE * _size[i] * 1.6), p)
		multi.set_instance_transform(i, xf)
