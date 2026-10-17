class_name CityIntroBillboard
extends Node3D
## The feed billboard of the City intro (CityIntro; the owner's October 16, 2026 beats, GDD §6 Cinematics, "Zone 1 intro": the
## runner bursts out through a billboard showing the feed, the Floating Head's face, rather than a plain window): a big
## screen in a dark frame on a building's face a floor up, showing the Head's face under the fight's own face shader (stern
## in its LED dots, the pupils following the searchlight as it sweeps over), its cold-white trim and spill lighting the wall.
## The light sweeps past, the picture tears for a moment, and the screen bursts: the glass flies out into the street as a
## spray of shards that tumble, fall and lie on the road, a burst of cold-white sparks and a flare go up where it was, and
## what is left is the dark frame with a few teeth of broken screen, dangling cables, no light on it: the feed is broken.
## Visual only: no collision and no gameplay; the flight of every shard and spark is worked out from the clock, so stepping or
## skipping shows the same. Reduced flashing (Settings): the burst is fewer sparks, and the flare a slow faint glow instead
## of a pop (and the face shader holds its static still, as everywhere).
##
## World space (see CityIntroStreet): y = 0 the road, x = 0 the street's middle, a track distance z is world z = -z.

const FACE_SHADER: String = "res://scripts/bosses/floating_head/floating_head_face.gdshader"
const FRAME := Color(0.17, 0.18, 0.24)
const FRAME_EDGE := Color(0.38, 0.4, 0.5)
## The feed's colour: the Head's face, cold white (never a hazard's).
const FEED_WHITE := Color(0.86, 0.91, 1.0)
## The teeth of broken screen left in the frame: pale glass catching the street's light.
const GLASS_EDGE := Color(0.7, 0.82, 1.0)
const GRAVITY: float = 9.8
## The road the shards land on, and how long they take to lie flat once they have.
const GROUND: float = 0.04
const FLATTEN_SECONDS: float = 0.12
## How far the screen stands out of the wall, and the frame's border round it.
const OUT: float = 0.45
const BORDER: float = 0.26
## How much of the sparks a viewer with Reduced flashing gets, and the flare's peak then.
const REDUCED_SPARKS: float = 0.35
const REDUCED_FLARE: float = 0.4
## The flare: how long it takes to rise and to die (s), normally and with Reduced flashing (a slow glow).
const FLARE_RISE: float = 0.03
const FLARE_FALL: float = 0.3
const FLARE_RISE_REDUCED: float = 0.3
const FLARE_FALL_REDUCED: float = 0.8
## How far the picture tears (the face shader's `glitch`) as the screen is about to burst.
const GLITCH_PEAK: float = 0.75
## The glass shards' look: the effects' shared see-through glow (GreyboxMaterials.glow, one shader for every such look, which
## the warm-up compiles while the intro fades in), pale blue-white.
const SHARD_COLOR := Color(0.74, 0.88, 1.0)
const SHARD_ENERGY: float = 1.1
const SHARD_ALPHA: float = 0.78
## The sparks' shader: additive and unshaded, so cold white and bright in any renderer; one Shader shared by every play (a
## Shader made each time would be compiled each time).
const SPARK_SHADER_CODE: String = "shader_type spatial;\nrender_mode unshaded, blend_add, cull_disabled, depth_draw_never;\n" \
	+ "uniform vec3 spark_color : source_color = vec3(0.8, 0.92, 1.0);\nuniform float energy = 2.4;\n" \
	+ "void fragment() { ALBEDO = spark_color * energy; }\n"

static var _spark_shader: Shader

## The billboard: its side (-1 left), where it is (track distance of its middle), its sill and its size.
var side: int = -1
var z: float = 0.0
var sill: float = 0.0
var width: float = 0.0
var height: float = 0.0
## The wall's face x, when the screen bursts, and how long before it the picture starts to tear.
var wall_x: float = 0.0
var burst_time: float = 0.0
var glitch_seconds: float = 0.0
## The parts: the whole feed that goes at the burst (screen and trim), and what is left (frame, opening).
var intact: Node3D
var broken: Node3D
var frame: MeshInstance3D
var screen: MeshInstance3D
var face: ShaderMaterial
var shards: MultiMeshInstance3D
var multi: MultiMesh
var sparks: MultiMeshInstance3D
var spark_multi: MultiMesh
var flare: MeshInstance3D
## Where the face looks now (-1 to 1 across and up) and how far it is torn (0-1).
var look := Vector2.ZERO
var glitch: float = 0.0
## The flare's scale now (0: gone).
var flare_scale: float = 0.0

## Each shard: where it starts, its velocity, its tumble (axis and rate), its size and where it lies flat.
var _start: Array[Vector3] = []
var _velocity: Array[Vector3] = []
var _axis: Array[Vector3] = []
var _rate := PackedFloat32Array()
var _size := PackedFloat32Array()
var _land := PackedFloat32Array()
var _yaw := PackedFloat32Array()
## Each spark: where it starts, its velocity, its life, its size.
var _spark_start: Array[Vector3] = []
var _spark_velocity: Array[Vector3] = []
var _spark_life := PackedFloat32Array()
var _spark_size := PackedFloat32Array()


## Builds the billboard on the wall whose face is at x = side * wall_half, from `n`'s numbers (the City intro's tuning), in
## `skin`'s look.
func build(skin: CitySkin, wall_half: float, n: CityIntroTuning) -> void:
	side = n.billboard_side
	z = n.billboard_z
	sill = n.billboard_sill
	width = n.billboard_width
	height = n.billboard_height
	wall_x = side * wall_half
	burst_time = n.burst_at
	glitch_seconds = n.billboard_glitch_seconds
	var z0: float = z - width * 0.5
	var z1: float = z + width * 0.5
	var y0: float = sill
	var y1: float = sill + height
	var mid: float = (y0 + y1) * 0.5
	_build_frame(skin, z0, z1, y0, y1)
	_build_feed(skin, z0, z1, y0, y1, mid)
	_build_opening(skin, z0, z1, y0, y1)
	_build_shards(n.shard_count)
	_build_sparks(n.spark_count)
	_build_flare(skin, mid)
	update(0.0, Vector3(0.0, mid, -z))


## The frame: four dark bars standing out of the wall round the screen, edged lighter, and a cable box on top.
func _build_frame(skin: CitySkin, z0: float, z1: float, y0: float, y1: float) -> void:
	var batch := MeshBatch.new()
	var solid: MeshLayer = batch.layer(skin.solid_material())
	_bar(solid, z0 - BORDER, z1 + BORDER, y1, y1 + BORDER, FRAME)
	_bar(solid, z0 - BORDER, z1 + BORDER, y0 - BORDER, y0, FRAME)
	_bar(solid, z0 - BORDER, z0, y0, y1, FRAME)
	_bar(solid, z1, z1 + BORDER, y0, y1, FRAME)
	# A lighter edge along the frame's front, a cable box on its top and a pair of brackets under it.
	_rect(solid, OUT + 0.01, z0 - BORDER, z1 + BORDER, y1 + BORDER - 0.04, y1 + BORDER, FRAME_EDGE)
	_rect(solid, OUT + 0.01, z0 - BORDER, z1 + BORDER, y0 - BORDER, y0 - BORDER + 0.04, FRAME_EDGE)
	solid.box(_at(OUT * 0.5, z1 - 0.7, y1 + BORDER + 0.18), Vector3(OUT * 0.8, 0.36, 1.1), FRAME_EDGE)
	for k: int in 2:
		var bz: float = lerpf(z0, z1, 0.2 + 0.6 * float(k))
		solid.box(_at(OUT * 0.5, bz, y0 - BORDER - 0.35), Vector3(OUT * 0.7, 0.7, 0.14), FRAME_EDGE)
	frame = batch.commit(self, "Frame")


## The feed: the screen (the Head's face under the fight's face shader), a thin cold-white trim just inside the frame and the
## light it spills on the wall round it. All of it goes at the burst.
func _build_feed(skin: CitySkin, z0: float, z1: float, y0: float, y1: float, mid: float) -> void:
	intact = Node3D.new()
	intact.name = "Feed"
	add_child(intact)
	var batch := MeshBatch.new()
	var glow: MeshLayer = batch.layer(skin.glow_material())
	var t: float = 0.05
	_rect(glow, OUT + 0.03, z0 - 0.02, z1 + 0.02, y1 - t + 0.02, y1 + 0.02, FEED_WHITE, 0.5, MeshKit.SHAPE_FLAT)
	_rect(glow, OUT + 0.03, z0 - 0.02, z1 + 0.02, y0 - 0.02, y0 + t - 0.02, FEED_WHITE, 0.5, MeshKit.SHAPE_FLAT)
	_rect(glow, OUT + 0.03, z0 - 0.02, z0 + t - 0.02, y0, y1, FEED_WHITE, 0.5, MeshKit.SHAPE_FLAT)
	_rect(glow, OUT + 0.03, z1 - t + 0.02, z1 + 0.02, y0, y1, FEED_WHITE, 0.5, MeshKit.SHAPE_FLAT)
	# The spill on the wall round the frame: a cold-white halo.
	_rect(glow, 0.06, z - width * 0.95, z + width * 0.95, mid - height * 1.1, mid + height * 1.1, FEED_WHITE, 0.2,
		MeshKit.SHAPE_RADIAL)
	MeshBatch.add_instance(intact, batch.to_mesh(), "Trim")
	var screen_batch := MeshBatch.new()
	var l: MeshLayer = screen_batch.layer(null)
	l.rect(Vector3(-width * 0.5, -height * 0.5, 0.0), Vector3(width, 0, 0), Vector3(0, height, 0), Color.WHITE, 1.0, 0,
		Vector2.ZERO, Vector2.ONE, width / height)
	screen = MeshBatch.add_instance(intact, screen_batch.to_mesh(), "Screen", _at(OUT, z, mid))
	screen.rotation.y = -float(side) * PI * 0.5
	face = ShaderMaterial.new()
	face.shader = load(FACE_SHADER) as Shader
	face.set_shader_parameter(&"aspect", width / height)
	face.set_shader_parameter(&"power", 1.0)
	face.set_shader_parameter(&"anger", 0.35)
	screen.material_override = face


## What is left once the screen has burst: the dark recess, a few teeth of the broken screen standing in the frame, cables
## dangling, the feed's last light leaking low in it (static, dim).
func _build_opening(skin: CitySkin, z0: float, z1: float, y0: float, y1: float) -> void:
	broken = Node3D.new()
	broken.name = "Opening"
	broken.visible = false
	add_child(broken)
	var batch := MeshBatch.new()
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var glow: MeshLayer = batch.layer(skin.glow_material())
	_rect(solid, 0.05, z0, z1, y0, y1, Color(0.025, 0.025, 0.035))
	var teeth: int = 11
	for k: int in teeth:
		var u: float = (float(k) + 0.5) / float(teeth)
		var tooth: float = 0.2 + 0.4 * MeshKit.hash01(k, 3, 201)
		var cz: float = lerpf(z0, z1, u)
		# A tooth hanging from the top bar and one standing on the bottom one: a thin triangle each.
		_triangle(glow, OUT - 0.02, cz - 0.13, cz + 0.13, cz + 0.04, y1, y1 - tooth, GLASS_EDGE, 0.35)
		if k % 2 == 0:
			var tooth2: float = 0.12 + 0.3 * MeshKit.hash01(k, 4, 202)
			_triangle(glow, OUT - 0.02, cz - 0.15, cz + 0.15, cz + 0.03, y0, y0 + tooth2, GLASS_EDGE, 0.35)
	# Cables torn out of the top bar, hanging a little crooked.
	for k: int in 4:
		var cz: float = lerpf(z0, z1, 0.15 + 0.7 * MeshKit.hash01(k, 5, 203))
		var drop: float = 0.5 + 0.9 * MeshKit.hash01(k, 6, 204)
		var lean: float = (MeshKit.hash01(k, 7, 205) - 0.5) * 0.3
		var xform := Transform3D(Basis(Vector3.RIGHT, lean), _at(OUT - 0.05, cz, y1 - drop * 0.5))
		solid.box_xform(Transform3D(xform.basis * Basis.from_scale(Vector3(0.05, drop, 0.05)), xform.origin), FRAME_EDGE)
	MeshBatch.add_instance(broken, batch.to_mesh(), "Recess")


## The flare: a soft cold-white glow over where the screen was, which pops and dies (`update`).
func _build_flare(skin: CitySkin, mid: float) -> void:
	var batch := MeshBatch.new()
	var glow: MeshLayer = batch.layer(skin.glow_material())
	glow.rect(Vector3(-width * 1.1, -height * 1.1, 0.0), Vector3(width * 2.2, 0, 0), Vector3(0, height * 2.2, 0), FEED_WHITE,
		0.8, MeshKit.SHAPE_RADIAL)
	flare = MeshBatch.add_instance(self, batch.to_mesh(), "Flare", _at(OUT + 0.1, z, mid))
	flare.rotation.y = -float(side) * PI * 0.5
	flare.visible = false


## A point `depth` out of the wall (toward the street), at track distance `a` and height `y`.
func _at(depth: float, a: float, y: float) -> Vector3:
	return Vector3(wall_x - side * depth, y, -a)


## A bar of the frame standing out of the wall between track distances a and b and heights y0 and y1.
func _bar(layer: MeshLayer, a: float, b: float, y0: float, y1: float, color: Color) -> void:
	layer.box(_at(OUT * 0.5, (a + b) * 0.5, (y0 + y1) * 0.5), Vector3(OUT, y1 - y0, b - a), color)


## A rectangle facing the street, `depth` out of the wall, between track distances a and b and heights y0 and y1.
func _rect(layer: MeshLayer, depth: float, a: float, b: float, y0: float, y1: float, color: Color, glow: float = 0.0,
		pattern: int = 0) -> void:
	var x: float = wall_x - side * depth
	if side < 0:
		layer.rect(Vector3(x, y0, -a), Vector3(0.0, 0.0, -(b - a)), Vector3(0.0, y1 - y0, 0.0), color, glow, pattern)
	else:
		layer.rect(Vector3(x, y0, -b), Vector3(0.0, 0.0, b - a), Vector3(0.0, y1 - y0, 0.0), color, glow, pattern)


## A thin triangle facing the street: its base from track distance a to b at height y_base, its tip at c, y_tip.
func _triangle(layer: MeshLayer, depth: float, a: float, b: float, c: float, y_base: float, y_tip: float, color: Color,
		glow: float = 0.0) -> void:
	var x: float = wall_x - side * depth
	var pa := Vector3(x, y_base, -a)
	var pb := Vector3(x, y_base, -b)
	var pc := Vector3(x, y_tip, -c)
	layer.verts.append_array(PackedVector3Array([pa, pc, pb] if side < 0 else [pa, pb, pc]))
	var col := Color(color, glow)
	layer.colors.append_array(PackedColorArray([col, col, col]))
	layer.uvs.append_array(PackedVector2Array([Vector2(0, 0), Vector2(0.5, 1), Vector2(1, 0)]))
	var p := Vector2(MeshKit.PAT_PLAIN, 0.0)
	layer.uv2s.append_array(PackedVector2Array([p, p, p]))


func _build_shards(count: int) -> void:
	# A triangle seen from both sides (its back is a second triangle wound the other way, so the shared glow material needs no
	# double-sided shader of its own).
	var tri := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var top := Vector3(0.0, 0.6, 0.0)
	var left := Vector3(-0.4, -0.4, 0.0)
	var right := Vector3(0.4, -0.4, 0.0)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([top, left, right, top, right, left])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.FORWARD, Vector3.FORWARD,
		Vector3.FORWARD])
	tri.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	tri.surface_set_material(0, GreyboxMaterials.glow(SHARD_COLOR, SHARD_ENERGY, SHARD_ALPHA))
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
		var start := Vector3(wall_x - side * (OUT + 0.02), sill + height * v, -(z + (u - 0.5) * width))
		# Out into the street, up or down a little, along the wall either way; the middle of the screen flies furthest.
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
	_place_shards(0.0)


## The sparks' shader, made once a process (not once a play).
static func spark_shader() -> Shader:
	if _spark_shader == null:
		_spark_shader = Shader.new()
		_spark_shader.code = SPARK_SHADER_CODE
	return _spark_shader


## The sparks: short bright streaks of the feed's cold white, thrown out of the screen, falling and dying within a second.
func _build_sparks(count: int) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = spark_shader()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = mat
	spark_multi = MultiMesh.new()
	spark_multi.transform_format = MultiMesh.TRANSFORM_3D
	spark_multi.mesh = box
	spark_multi.instance_count = count
	sparks = MultiMeshInstance3D.new()
	sparks.name = "Sparks"
	sparks.multimesh = spark_multi
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.visible = false
	add_child(sparks)
	var out: float = -float(side)
	for i: int in count:
		var u: float = MeshKit.hash01(i, 1, 241)
		var v: float = MeshKit.hash01(i, 2, 242)
		_spark_start.append(Vector3(wall_x - side * (OUT + 0.04), sill + height * v, -(z + (u - 0.5) * width)))
		var speed: float = 2.0 + 5.5 * MeshKit.hash01(i, 3, 243)
		_spark_velocity.append(Vector3(out * speed, (v - 0.4) * 3.5 + MeshKit.hash01(i, 4, 244) * 2.5,
			(u - 0.5) * 5.0 + (MeshKit.hash01(i, 5, 245) - 0.5) * 3.0))
		_spark_life.append(0.3 + 0.55 * MeshKit.hash01(i, 6, 246))
		_spark_size.append(0.1 + 0.14 * MeshKit.hash01(i, 7, 247))
	_place_sparks(INF)


## The billboard as it is at time `t`: the feed before it bursts (the face looking at `watching`, a world point, the picture
## tearing a little in the moment before), the opening, the flying glass, the sparks and the flare after.
func update(t: float, watching: Vector3) -> void:
	var bursting: bool = t >= burst_time
	intact.visible = not bursting
	broken.visible = bursting
	shards.visible = bursting
	sparks.visible = bursting
	if not bursting:
		var eye: Vector3 = screen.to_local(watching)
		look = Vector2(clampf(eye.x / (width * 1.6), -1.0, 1.0), clampf(eye.y / (height * 1.2), -1.0, 1.0))
		glitch = GLITCH_PEAK * smoothstep(burst_time - glitch_seconds, burst_time, t)
		face.set_shader_parameter(&"look", look)
		face.set_shader_parameter(&"glitch", glitch)
		flare_scale = 0.0
		flare.visible = false
		return
	var age: float = t - burst_time
	_place_shards(age)
	_place_sparks(age)
	flare_scale = flare_at(age)
	flare.visible = flare_scale > 0.001
	flare.scale = Vector3.ONE * maxf(flare_scale, 0.001)


## How big the flare is `age` seconds after the burst (0-1): a pop and a quick fade; with Reduced flashing a slow, faint glow.
static func flare_at(age: float) -> float:
	if age < 0.0:
		return 0.0
	var reduced: bool = Settings.flashing_reduced
	var rise: float = FLARE_RISE_REDUCED if reduced else FLARE_RISE
	var fall: float = FLARE_FALL_REDUCED if reduced else FLARE_FALL
	var peak: float = REDUCED_FLARE if reduced else 1.0
	return peak * smoothstep(0.0, rise, age) * (1.0 - smoothstep(rise, rise + fall, age))


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


## Where spark `i` is `age` seconds after the burst (world space).
func spark_position(i: int, age: float) -> Vector3:
	return _spark_start[i] + _spark_velocity[i] * age + Vector3(0.0, -0.5 * GRAVITY * age * age, 0.0)


## Whether spark `i` is in the air `age` seconds after the burst (it dies within its life, and a viewer with Reduced flashing
## gets only a share of them).
func spark_alive(i: int, age: float) -> bool:
	return i < active_sparks() and age >= 0.0 and age < _spark_life[i]


## How many of the sparks fly: all of them, or the Reduced flashing share.
func active_sparks() -> int:
	var count: int = spark_multi.instance_count
	return roundi(count * REDUCED_SPARKS) if Settings.flashing_reduced else count


func _place_shards(age: float) -> void:
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


## Each spark is a thin streak along its flight, shrinking to nothing as its life runs out.
func _place_sparks(age: float) -> void:
	for i: int in spark_multi.instance_count:
		if not spark_alive(i, age):
			spark_multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		var k: float = 1.0 - age / _spark_life[i]
		var vel: Vector3 = _spark_velocity[i] + Vector3(0.0, -GRAVITY * age, 0.0)
		var thin: float = 0.04 * (0.4 + 0.6 * k)
		var length: float = _spark_size[i] * 1.3 * (0.4 + 0.6 * k)
		var up: Vector3 = Vector3.UP if absf(vel.normalized().y) < 0.98 else Vector3.RIGHT
		var basis := Basis.looking_at(vel.normalized(), up) * Basis.from_scale(Vector3(thin, thin, length))
		spark_multi.set_instance_transform(i, Transform3D(basis, spark_position(i, age)))
