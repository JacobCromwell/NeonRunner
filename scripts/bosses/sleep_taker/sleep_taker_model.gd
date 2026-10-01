class_name SleepTakerModel
extends Node3D
## The Sleep Taker's look (GDD §10): the Dead Zone's Bad Dreams fused over the years into one colossal
## nightmare, black with purple highlights like the Bad Dream (BadDreamModel) but vast: a cluster of
## bulbous heads, fused, with dozens of circular maws of spiked teeth, a great maw in the middle (its
## shriek is the giant slash's warning), two long arms ending in long clawed fingers, four tendrils of
## clawed fingers hanging below its heads, and a shroud and a skirt of vapour trailing down to the
## street. Every maw faces forward, toward the runner.
##
## Procedural and low-poly (CLAUDE.md Assets), built once at its reference size (REF_WIDTH wide, about
## REF_HEIGHT tall, the origin on the street under its middle, facing +Z) and shared by every fight: ONE
## opaque mesh for the liquid parts and ONE translucent mesh for the vapour, each with one shader that
## animates it in its vertex stage (sleep_taker_liquid.gdshader, sleep_taker_vapor.gdshader), plus two
## CPUParticles3D (its drips, and the light streaming into it as it inhales): four draw calls for the
## whole nightmare, fine on the Compatibility renderer (web, low-end Android). The fight scales it
## uniformly to the street's width (SleepTakerBody), so its maws stay round.
##
## Colour language: the GDD's black and purple, leaning violet (pink is the fences', GDD §9.1); only an
## attack reads in enemy-attack red (the great maw's throat and the claws heat up while it shrieks and
## slashes; a hand's claws as it bursts up), like every enemy attack. Reduced flashing: no glitch flicker
## in its glow. Visual only: nothing here touches collision or gameplay.
##
## Also here: a grasping hand's mesh (hand_mesh(), sleep_taker_hand.gdshader) and the mist it rises out
## of (mist_material(), sleep_taker_mist.gdshader), for SleepTakerHands.
##
## Vertex data: COLOR.rgb albedo, COLOR.a glow (liquid) or opacity (vapour); UV.x the part (Part) plus a
## small id (a maw's or a tendril's, its fraction * 64); UV.y the weight along a part (0 at its root, 1 at
## its tip; 2 marks a maw's throat); UV2 a maw vertex's offset from its maw's centre.

const PURPLE := BadDreamModel.PURPLE
const ATTACK_RED := BadDreamModel.ATTACK_RED
## The reference size the meshes are built at: its width across the arms at rest, and its height.
const REF_WIDTH: float = 12.8
const REF_HEIGHT: float = 20.0

const LIQUID_SHADER: String = "res://scripts/bosses/sleep_taker/sleep_taker_liquid.gdshader"
const VAPOR_SHADER: String = "res://scripts/bosses/sleep_taker/sleep_taker_vapor.gdshader"
const HAND_SHADER: String = "res://scripts/bosses/sleep_taker/sleep_taker_hand.gdshader"
const MIST_SHADER: String = "res://scripts/bosses/sleep_taker/sleep_taker_mist.gdshader"

enum Part { HEAD, BIG_MAW, MAW, TORSO, ARM_L, ARM_R, TENDRIL, DRIP, SHROUD, SKIRT, POOL }

## The great maw (the giant slash's warning) gapes in its belly, low enough to show under a refuge's
## bridge as the runner nears it: its centre and radius, facing the runner.
const BIG_MAW_CENTER := Vector3(0.0, 5.0, 2.16)
const BIG_MAW_RADIUS: float = 1.3
## The main head, hunched over its chest and waist, and the smaller fused heads around it, each with
## a maw on its front: [centre, radii, the maw's offset from the head's front point
## (a share of its radii), maw radius].
const MAIN_HEAD: Array = [Vector3(0.0, 14.2, 0.2), Vector3(3.3, 3.5, 2.9)]
const CHEST: Array = [Vector3(0.0, 9.6, 0.3), Vector3(3.7, 3.4, 2.6)]
const WAIST: Array = [Vector3(0.0, 5.6, 0.2), Vector3(2.5, 2.6, 2.0)]
const HEADS: Array = [
	[Vector3(-3.4, 16.6, -0.6), Vector3(1.8, 1.7, 1.6), Vector2(0.15, -0.1), 0.5],
	[Vector3(3.0, 17.4, -0.9), Vector3(1.6, 1.5, 1.4), Vector2(-0.1, -0.05), 0.45],
	[Vector3(0.4, 18.6, -1.4), Vector3(1.5, 1.4, 1.3), Vector2(0.0, 0.1), 0.4],
	[Vector3(-4.6, 12.6, 0.0), Vector3(1.9, 1.8, 1.7), Vector2(0.2, -0.05), 0.55],
	[Vector3(4.8, 13.2, -0.2), Vector3(1.8, 1.7, 1.6), Vector2(-0.2, 0.0), 0.52],
	[Vector3(-2.4, 10.4, 2.0), Vector3(1.4, 1.3, 1.3), Vector2(0.05, -0.1), 0.42],
	[Vector3(2.7, 9.8, 1.9), Vector3(1.5, 1.4, 1.3), Vector2(-0.05, -0.08), 0.44],
	[Vector3(-4.2, 8.4, 0.8), Vector3(1.2, 1.2, 1.1), Vector2(0.2, 0.0), 0.34],
	[Vector3(4.4, 8.0, 0.7), Vector3(1.25, 1.2, 1.1), Vector2(-0.2, 0.0), 0.35],
	[Vector3(0.0, 7.9, 2.2), Vector3(1.3, 1.2, 1.2), Vector2(0.0, 0.05), 0.4],
	[Vector3(-2.7, 5.0, 1.2), Vector3(1.0, 1.0, 1.0), Vector2(0.0, -0.1), 0.3],
	[Vector3(2.8, 4.6, 1.1), Vector3(1.0, 0.95, 0.95), Vector2(0.0, -0.1), 0.3],
]
## More maws, scattered: on the main head and on the chest ([offset (a share of its radii), radius]),
## and second ones on some of the small heads ([head index, offset, radius]).
const HEAD_MAWS: Array = [[Vector2(0.0, -0.12), 0.8], [Vector2(-0.55, 0.35), 0.38], [Vector2(0.5, 0.42), 0.34],
	[Vector2(-0.62, -0.35), 0.3], [Vector2(0.6, -0.3), 0.36], [Vector2(0.05, 0.62), 0.3], [Vector2(-0.3, 0.68), 0.25], [Vector2(0.33, -0.66), 0.26]]
const CHEST_MAWS: Array = [[Vector2(-0.35, 0.25), 0.34], [Vector2(0.38, 0.3), 0.3], [Vector2(-0.12, -0.22), 0.36],
	[Vector2(0.45, -0.35), 0.28], [Vector2(-0.5, -0.3), 0.3]]
const SECOND_MAWS: Array = [[0, Vector2(-0.5, 0.42), 0.27], [3, Vector2(-0.5, 0.45), 0.28], [4, Vector2(0.5, -0.4), 0.27]]
## Where the arms hang from (the right one; the left mirrors it): long, hanging wide of the middle lanes
## down to the street, their claws in front of it.
const SHOULDER := Vector3(4.9, 11.0, 0.4)
const ELBOW := Vector3(5.8, 6.6, 1.8)
const WRIST := Vector3(5.2, 3.0, 4.2)
## The tendrils of clawed fingers hanging below the heads: [root, end].
const TENDRILS: Array = [[Vector3(-2.4, 9.2, 2.6), Vector3(-2.8, 5.2, 3.6)], [Vector3(2.7, 8.6, 2.5), Vector3(3.0, 4.8, 3.4)],
	[Vector3(-4.2, 7.3, 1.2), Vector3(-4.6, 3.8, 2.4)], [Vector3(4.4, 7.0, 1.1), Vector3(4.8, 3.6, 2.3)]]
## How far in front of its centre its claws reach at rest (the lunge brings them to the runner).
const CLAW_REACH: float = 6.8

const BLACK := Color(0.012, 0.007, 0.02, 0.0)
const SHEEN := Color(0.06, 0.018, 0.1, 0.06)
const HIGHLIGHT := Color(0.34, 0.2, 1.0, 1.0)
## A maw's lip: the purple highlight, dimmer (dozens of them).
const LIP := Color(0.34, 0.2, 1.0, 0.5)
const BONE := Color(0.72, 0.66, 0.82, 0.12)
const CLAW := Color(0.8, 0.7, 1.0, 0.75)
const THROAT := Color(0.2, 0.08, 0.72, 1.0)
const THROAT_RIM := Color(0.07, 0.025, 0.24, 1.0)
const VAPOR := Color(0.06, 0.02, 0.12, 0.8)
const SHROUD := Color(0.2, 0.08, 0.42, 0.16)
const POOL_COLOR := Color(0.07, 0.025, 0.14, 0.42)
## The mist's purple (the nightmare's own, never a hazard colour) and its darker core.
const MIST_COLOR := Color(0.6, 0.3, 1.0)
const MIST_CORE := Color(0.22, 0.07, 0.5)

static var _liquid_mesh: ArrayMesh
static var _vapor_mesh: ArrayMesh
static var _hand_mesh: ArrayMesh
static var _maws: PackedVector3Array = PackedVector3Array()
static var _shaders: Dictionary = {}

## Animation inputs, set by the body each frame (see sleep_taker_liquid.gdshader).
var shriek: float = 0.0
var maws: float = 0.35
var inhale: float = 0.0
var swallowed: float = 0.0
var raise: float = 0.0
var slash: float = 0.0
var reach: float = 1.0
var attack: float = 0.0
var lunge: float = 0.0
var fade: float = 0.0

var _liquid: MeshInstance3D
var _vapor: MeshInstance3D
var _drips: CPUParticles3D
var _streams: CPUParticles3D
var _liquid_material: ShaderMaterial
var _vapor_material: ShaderMaterial


func build(p_seed: float) -> void:
	_liquid_material = ShaderMaterial.new()
	_liquid_material.shader = shader(LIQUID_SHADER)
	_liquid_material.set_shader_parameter(&"seed", p_seed)
	_vapor_material = ShaderMaterial.new()
	_vapor_material.shader = shader(VAPOR_SHADER)
	_vapor_material.set_shader_parameter(&"seed", p_seed)
	_liquid = MeshInstance3D.new()
	_liquid.name = "Liquid"
	_liquid.mesh = liquid_mesh()
	_liquid.material_override = _liquid_material
	_liquid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shaders move vertices (arms reach out over the lanes, the lunge): keep it from being culled.
	_liquid.extra_cull_margin = 8.0
	add_child(_liquid)
	_vapor = MeshInstance3D.new()
	_vapor.name = "Vapor"
	_vapor.mesh = vapor_mesh()
	_vapor.material_override = _vapor_material
	_vapor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vapor.extra_cull_margin = 4.0
	add_child(_vapor)
	_drips = _particles("Drips", 26, 1.2, Vector3(0.0, 11.0, 1.2), Vector3(4.4, 4.6, 1.6))
	_drips.direction = Vector3(0.0, -1.0, 0.0)
	_drips.spread = 20.0
	_drips.gravity = Vector3(0.0, -7.0, 0.0)
	_drips.initial_velocity_min = 0.2
	_drips.initial_velocity_max = 1.0
	var drop := SphereMesh.new()
	drop.radius = 0.08
	drop.height = 0.2
	drop.radial_segments = 5
	drop.rings = 2
	_drips.mesh = drop
	_drips.material_override = GreyboxMaterials.glow(PURPLE, 2.0)
	# The light streaming into its maws as it inhales (lights out's warning): wisps drawn in from all
	# around it.
	_streams = _particles("Inhale", 90, 1.4, Vector3(0.0, 12.5, 2.5), Vector3.ZERO)
	_streams.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	_streams.emission_sphere_radius = 13.0
	_streams.gravity = Vector3.ZERO
	_streams.radial_accel_min = -16.0
	_streams.radial_accel_max = -11.0
	_streams.initial_velocity_min = 0.0
	_streams.initial_velocity_max = 0.0
	_streams.damping_min = 1.0
	_streams.damping_max = 3.0
	var wisp := QuadMesh.new()
	wisp.size = Vector2(0.5, 0.5)
	_streams.mesh = wisp
	_streams.material_override = wisp_material(Color(0.42, 0.24, 0.85, 0.55))
	_streams.emitting = false
	animate()


## Pushes this frame's animation inputs to the materials.
func animate() -> void:
	if _liquid_material == null:
		return
	for pair: Array in [[&"shriek", shriek], [&"maws", maws], [&"inhale", inhale], [&"swallowed", swallowed],
			[&"raise", raise], [&"slash", slash], [&"reach", reach], [&"attack", attack], [&"lunge", lunge],
			[&"fade", fade]]:
		_liquid_material.set_shader_parameter(pair[0], pair[1])
	for pair: Array in [[&"inhale", inhale], [&"lunge", lunge], [&"fade", fade], [&"attack", attack]]:
		_vapor_material.set_shader_parameter(pair[0], pair[1])
	_drips.emitting = fade < 0.7
	_drips.speed_scale = 1.0 + attack * 1.5
	_streams.emitting = inhale > 0.05 and fade < 0.5


func liquid_material() -> ShaderMaterial:
	return _liquid_material


func vapor_material() -> ShaderMaterial:
	return _vapor_material


func streams() -> CPUParticles3D:
	return _streams


func _particles(node_name: String, amount: int, lifetime: float, at: Vector3, box: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = true
	if box != Vector3.ZERO:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = box
	p.position = at
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.15))
	p.scale_amount_curve = curve
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


# --- Shared resources ----------------------------------------------------------------------------

static func shader(path: String) -> Shader:
	if not _shaders.has(path):
		_shaders[path] = load(path) as Shader
	return _shaders[path]


## A grasping hand's material (one per hand: each rises and grasps in its own time).
static func hand_material(p_seed: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(HAND_SHADER)
	m.set_shader_parameter(&"seed", p_seed)
	return m


## A pool of mist's material (one per pool).
static func mist_material(p_seed: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(MIST_SHADER)
	m.set_shader_parameter(&"color", MIST_COLOR)
	m.set_shader_parameter(&"core_color", MIST_CORE)
	m.set_shader_parameter(&"seed", p_seed)
	return m


## A soft round wisp for particles (billboarded, unshaded, fading with the particle's colour).
static func wisp_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 32
	texture.height = 32
	m.albedo_texture = texture
	return m


## Every maw's centre in the model's space, the great maw's first ("dozens", GDD §10).
static func maw_centres() -> PackedVector3Array:
	liquid_mesh()
	return _maws


# --- The body ------------------------------------------------------------------------------------

## The liquid body, built once.
static func liquid_mesh() -> ArrayMesh:
	if _liquid_mesh != null:
		return _liquid_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_maws = PackedVector3Array()
	var head_c: Vector3 = MAIN_HEAD[0]
	var head_r: Vector3 = MAIN_HEAD[1]
	# The heads: the main one, a little sheen on its crown, hunched over its chest and waist, and the
	# smaller ones fused all over it.
	_ellipsoid(st, head_c, head_r, 12, 8, Part.HEAD, BLACK, SHEEN)
	_ellipsoid(st, CHEST[0], CHEST[1], 11, 7, Part.TORSO, BLACK, SHEEN)
	_ellipsoid(st, WAIST[0], WAIST[1], 9, 6, Part.TORSO, BLACK, BLACK)
	for h: Array in HEADS:
		_ellipsoid(st, h[0], h[1], 9, 6, Part.HEAD, BLACK, SHEEN)
	# The great maw, then a maw on every small head's front, more scattered over the main head and the
	# chest, and second maws on some heads.
	_maw(st, BIG_MAW_CENTER, BIG_MAW_RADIUS, 16, 14, Part.BIG_MAW, 0)
	var id: int = 1
	for h: Array in HEADS:
		var off: Vector2 = h[2]
		_maw(st, _front_point(h[0], h[1], off), float(h[3]), 9, 7, Part.MAW, id)
		id += 1
	for m: Array in HEAD_MAWS:
		_maw(st, _front_point(head_c, head_r, m[0]), float(m[1]), 8, 6, Part.MAW, id)
		id += 1
	for m: Array in CHEST_MAWS:
		_maw(st, _front_point(CHEST[0], CHEST[1], m[0]), float(m[1]), 8, 6, Part.MAW, id)
		id += 1
	for m: Array in SECOND_MAWS:
		var h: Array = HEADS[int(m[0])]
		_maw(st, _front_point(h[0], h[1], m[1]), float(m[2]), 8, 6, Part.MAW, id)
		id += 1
	# The two long arms with their long clawed fingers.
	for sx: float in [-1.0, 1.0]:
		_arm(st, sx)
	# The tendrils of clawed fingers hanging below the heads.
	for i: int in TENDRILS.size():
		_tendril(st, TENDRILS[i][0], TENDRILS[i][1], i)
	# Liquid dripping off the heads.
	var drips: Array = [[-2.4, 9.1, 2.6, 1.2], [2.7, 8.4, 2.5, 1.0], [0.0, 6.4, 3.0, 1.4], [-4.6, 10.8, 0.9, 1.1],
		[4.8, 11.5, 0.7, 1.3], [-1.6, 4.2, 2.0, 1.0], [1.8, 3.9, 1.9, 1.2], [0.0, 11.4, 3.0, 0.9]]
	for d: Array in drips:
		var top := Vector3(float(d[0]), float(d[1]), float(d[2]))
		_cone(st, top, top + Vector3(0.0, -float(d[3]), 0.05), 0.09, 0.0, 4, BLACK, HIGHLIGHT, Part.DRIP, 0.0, 1.0)
	_liquid_mesh = st.commit()
	return _liquid_mesh


## The vapour: the shroud around its heads, the skirt trailing down toward the street and the pool on
## it, built once.
static func vapor_mesh() -> ArrayMesh:
	if _vapor_mesh != null:
		return _vapor_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ellipsoid(st, Vector3(0.0, 13.0, -0.4), Vector3(6.6, 7.4, 4.4), 12, 7, Part.SHROUD, SHROUD, SHROUD)
	# The skirt, from under the torso down to just above the street, thinning out as it goes, so the
	# street beyond shows through it.
	var rings: Array = [[5.0, 2.6, 0.8], [3.8, 3.1, 0.6], [2.6, 3.6, 0.4], [1.4, 4.1, 0.22], [0.4, 4.6, 0.06]]
	for i: int in rings.size() - 1:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		var w0: float = float(i) / (rings.size() - 1)
		var w1: float = float(i + 1) / (rings.size() - 1)
		_cone(st, Vector3(0.0, float(a[0]), 0.0), Vector3(0.0, float(b[0]), 0.0), float(a[1]), float(b[1]), 12,
			Color(VAPOR, VAPOR.a * float(a[2])), Color(VAPOR, VAPOR.a * float(b[2])), Part.SKIRT, w0, w1)
	# A faint pool spreading on the street under it.
	var segs: int = 20
	var center := Vector3(0.0, 0.06, 0.6)
	for i: int in segs:
		var a0: float = TAU * i / segs
		var a1: float = TAU * (i + 1) / segs
		var p0: Vector3 = center + Vector3(cos(a0) * 6.0, 0.0, sin(a0) * 4.2)
		var p1: Vector3 = center + Vector3(cos(a1) * 6.0, 0.0, sin(a1) * 4.2)
		_tri(st, [center, p0, p1], [POOL_COLOR, Color(POOL_COLOR, 0.0), Color(POOL_COLOR, 0.0)], Part.POOL, [0.0, 1.0, 1.0],
			center + Vector3(0.0, -1.0, 0.0))
	_vapor_mesh = st.commit()
	return _vapor_mesh


## A point on the front of an ellipsoid (centre `c`, radii `r`) at `off` (a share of its radii across
## and up from its front-most point), pushed a little out so a maw there sits on its surface.
static func _front_point(c: Vector3, r: Vector3, off: Vector2) -> Vector3:
	var x: float = off.x * r.x
	var y: float = off.y * r.y
	var k: float = clampf(1.0 - off.x * off.x - off.y * off.y, 0.05, 1.0)
	var z: float = r.z * sqrt(k)
	# Off its front, the surface leans back: push the maw out by as much, so its rim stays outside.
	return c + Vector3(x, y, z + (1.0 - sqrt(k)) * 0.45)


## A circular maw of spiked teeth facing +Z at `c`: a throat lit from inside (glowing as it opens), a
## glowing lip and a ring of teeth pointing into it. Its vertices carry their offset from its centre
## (UV2), so the shader opens and closes it.
static func _maw(st: SurfaceTool, c: Vector3, r: float, segs: int, teeth: int, part: int, id: int) -> void:
	_maws.append(c)
	var tag: float = float(part) + float(id % 31) / 64.0
	var m: Vector3 = c + Vector3(0.0, 0.0, 0.02)
	var inside: Vector3 = m + Vector3(0.0, 0.0, -1.0)
	for i: int in segs:
		var a0: float = TAU * i / segs
		var a1: float = TAU * (i + 1) / segs
		var d0 := Vector3(cos(a0), sin(a0), 0.0)
		var d1 := Vector3(cos(a1), sin(a1), 0.0)
		_maw_tri(st, [m, m + d0 * r * 0.96, m + d1 * r * 0.96], [THROAT, THROAT_RIM, THROAT_RIM], tag, [2.0, 2.0, 2.0], c, inside)
		var r_in: float = r
		var r_out: float = r * 1.2
		var lip := Vector3(0.0, 0.0, 0.03)
		_maw_tri(st, [m + d0 * r_in + lip, m + d0 * r_out, m + d1 * r_out], [LIP, LIP, LIP], tag,
			[0.0, 0.0, 0.0], c, inside)
		_maw_tri(st, [m + d0 * r_in + lip, m + d1 * r_out, m + d1 * r_in + lip], [LIP, LIP, LIP], tag,
			[0.0, 0.0, 0.0], c, inside)
	for i: int in teeth:
		var a: float = TAU * (i + 0.5) / teeth
		var d := Vector3(cos(a), sin(a), 0.0)
		var tangent := Vector3(-sin(a), cos(a), 0.0)
		var base: Vector3 = m + d * r * 0.98 + Vector3(0.0, 0.0, 0.03)
		var length: float = r * (0.6 if i % 2 == 0 else 0.44)
		var tip: Vector3 = m + d * (r - length) + Vector3(0.0, 0.0, r * 0.32)
		var half: float = r * 0.2
		var b1: Vector3 = base - tangent * half
		var b2: Vector3 = base + tangent * half
		var b3: Vector3 = base - d * r * 0.12 + Vector3(0.0, 0.0, -r * 0.18)
		var center: Vector3 = (b1 + b2 + b3 + tip) * 0.25
		for f: Array in [[b1, b2, tip], [b2, b3, tip], [b3, b1, tip]]:
			_maw_tri(st, f, [BONE, BONE, BONE], tag, [0.0, 0.0, 1.0], c, center)


## An arm (`sx` -1 left, 1 right): a shoulder, a long upper arm and forearm, a hand, and five long
## fingers ending in hooked claws that hang in front of it, reaching toward the lanes.
static func _arm(st: SurfaceTool, sx: float) -> void:
	var part: int = Part.ARM_L if sx < 0.0 else Part.ARM_R
	var shoulder := Vector3(sx * SHOULDER.x, SHOULDER.y, SHOULDER.z)
	var elbow := Vector3(sx * ELBOW.x, ELBOW.y, ELBOW.z)
	var wrist := Vector3(sx * WRIST.x, WRIST.y, WRIST.z)
	_ellipsoid(st, shoulder, Vector3(0.75, 0.7, 0.75), 7, 4, part, BLACK, BLACK)
	_cone(st, shoulder, elbow, 0.55, 0.4, 7, BLACK, BLACK, part, 0.0, 0.3)
	_cone(st, elbow, wrist, 0.4, 0.28, 7, BLACK, SHEEN, part, 0.3, 0.55)
	_ellipsoid(st, wrist, Vector3(0.45, 0.32, 0.42), 6, 4, part, BLACK, BLACK, 0.58)
	var side := Vector3(1.0, 0.0, -0.25).normalized()
	for k: int in 5:
		var spread: float = (float(k) - 2.0) * 0.34
		var knuckle: Vector3 = wrist + side * spread * 0.9 + Vector3(0.0, -0.15, 0.3)
		var d1 := Vector3(sx * 0.08 + spread * 0.55, -0.5, 0.85).normalized()
		var d2 := Vector3(spread * 0.35, -0.85, 0.5).normalized()
		var d3 := Vector3(spread * 0.15, -0.5, 0.95).normalized()
		var long: float = 1.0 - absf(spread) * 0.25
		var mid: Vector3 = knuckle + d1 * 1.25 * long
		var tip: Vector3 = mid + d2 * 1.05 * long
		var claw: Vector3 = tip + d3 * 0.95
		_cone(st, knuckle, mid, 0.12, 0.09, 4, BLACK, SHEEN, part, 0.6, 0.72)
		_cone(st, mid, tip, 0.09, 0.07, 4, BLACK, SHEEN, part, 0.72, 0.84)
		_cone(st, tip, claw, 0.08, 0.0, 4, CLAW, Color(CLAW, 1.0), part, 0.84, 1.0)


## A tendril hanging from `root` to `end`, curling forward, ending in three clawed fingers.
static func _tendril(st: SurfaceTool, root: Vector3, end: Vector3, index: int) -> void:
	var tag: int = Part.TENDRIL
	var mid: Vector3 = (root + end) * 0.5 + Vector3(0.0, 0.0, 0.5)
	_cone_tagged(st, root, mid, 0.3, 0.2, 5, BLACK, BLACK, tag, index, 0.0, 0.4)
	_cone_tagged(st, mid, end, 0.2, 0.12, 5, BLACK, SHEEN, tag, index, 0.4, 0.75)
	for k: int in 3:
		var spread: float = (float(k) - 1.0) * 0.45
		var dir := Vector3(spread, -0.6, 0.75).normalized()
		var tip: Vector3 = end + dir * 1.1
		var claw: Vector3 = tip + Vector3(spread * 0.2, -0.25, 0.55).normalized() * 0.6
		_cone_tagged(st, end, tip, 0.07, 0.05, 4, BLACK, SHEEN, tag, index, 0.75, 0.86)
		_cone_tagged(st, tip, claw, 0.05, 0.0, 4, CLAW, Color(CLAW, 1.0), tag, index, 0.86, 1.0)


# --- A grasping hand -----------------------------------------------------------------------------

## A grasping hand rising out of the street, built once: a forearm coming up from below the street, a
## palm facing the runner (+Z) and five long fingers, their claws hooking toward the runner. Its knuckles
## sit KNUCKLE_Y up (sleep_taker_hand.gdshader curls the fingers about them); about 3.1 m to the tips and
## 1.7 m across.
const KNUCKLE_Y: float = 1.9


static func hand_mesh() -> ArrayMesh:
	if _hand_mesh != null:
		return _hand_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cone_tagged(st, Vector3(0.0, -2.2, -0.3), Vector3(0.0, 1.1, -0.05), 0.5, 0.36, 8, BLACK, BLACK, 0, 0, 0.0, 0.0)
	_ellipsoid(st, Vector3(0.0, 1.5, 0.0), Vector3(0.66, 0.55, 0.26), 9, 5, 1, BLACK, SHEEN)
	var xs: Array = [-0.6, -0.3, 0.0, 0.3, 0.6]
	for k: int in 5:
		var x: float = float(xs[k])
		var spread: float = x * 0.35
		var knuckle := Vector3(x, KNUCKLE_Y, 0.05)
		if k == 0:
			# The thumb, lower and to the side.
			knuckle = Vector3(-0.72, 1.35, 0.1)
			spread = -0.55
		var p1: Vector3 = knuckle + Vector3(spread * 0.4, 0.55, 0.12)
		var p2: Vector3 = p1 + Vector3(spread * 0.3, 0.45, 0.22)
		var p3: Vector3 = p2 + Vector3(spread * 0.1, 0.3, 0.32)
		var claw: Vector3 = p3 + Vector3(0.0, -0.02, 0.5)
		_cone_tagged(st, knuckle, p1, 0.13, 0.11, 5, BLACK, SHEEN, 2, k, 0.0, 0.35)
		_cone_tagged(st, p1, p2, 0.11, 0.09, 5, BLACK, SHEEN, 2, k, 0.35, 0.6)
		_cone_tagged(st, p2, p3, 0.09, 0.07, 5, BLACK, SHEEN, 2, k, 0.6, 0.8)
		_cone_tagged(st, p3, claw, 0.07, 0.0, 4, CLAW, Color(CLAW, 1.0), 2, k, 0.8, 1.0)
	_hand_mesh = st.commit()
	return _hand_mesh


# --- Builders --------------------------------------------------------------------------------------

## An ellipsoid; `top_color` shades the upper part. `w` is the weight its vertices carry.
static func _ellipsoid(st: SurfaceTool, center: Vector3, r: Vector3, segments: int, rings: int, part: int,
		color: Color, top_color: Color, w: float = 0.0) -> void:
	var grid: Array[PackedVector3Array] = []
	for ri: int in rings + 1:
		var lat: float = PI * float(ri) / rings - PI * 0.5
		var row := PackedVector3Array()
		for s: int in segments:
			var lon: float = TAU * float(s) / segments
			row.append(center + Vector3(cos(lat) * sin(lon) * r.x, sin(lat) * r.y, cos(lat) * cos(lon) * r.z))
		grid.append(row)
	for ri: int in rings:
		for s: int in segments:
			var s1: int = (s + 1) % segments
			var quad: Array = [grid[ri][s], grid[ri][s1], grid[ri + 1][s1], grid[ri + 1][s]]
			var c: Color = top_color if (quad[2] as Vector3).y > center.y + r.y * 0.45 else color
			_tri(st, [quad[0], quad[1], quad[2]], [c, c, c], part, [w, w, w], center)
			_tri(st, [quad[0], quad[2], quad[3]], [c, c, c], part, [w, w, w], center)


## A tapered cone (a truncated one when `r1` > 0) from `a` to `b`; the weight runs w0 → w1.
static func _cone(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, c0: Color,
		c1: Color, part: int, w0: float, w1: float) -> void:
	_cone_tagged(st, a, b, r0, r1, sides, c0, c1, part, 0, w0, w1)


## _cone with an id in the part's tag (a tendril's, a finger's).
static func _cone_tagged(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, c0: Color,
		c1: Color, part: int, id: int, w0: float, w1: float) -> void:
	var axis: Vector3 = (b - a).normalized()
	var side: Vector3 = axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up: Vector3 = axis.cross(side).normalized()
	var ring0 := PackedVector3Array()
	var ring1 := PackedVector3Array()
	for k: int in sides:
		var ang: float = TAU * k / sides
		var dir: Vector3 = side * cos(ang) + up * sin(ang)
		ring0.append(a + dir * r0)
		ring1.append(b + dir * r1)
	var mid: Vector3 = (a + b) * 0.5
	var tag: float = float(part) + float(id % 31) / 64.0
	for k: int in sides:
		var k1: int = (k + 1) % sides
		if r1 > 0.0:
			_tri_tagged(st, [ring0[k], ring1[k], ring1[k1]], [c0, c1, c1], tag, [w0, w1, w1], mid, Vector3.ZERO)
			_tri_tagged(st, [ring0[k], ring1[k1], ring0[k1]], [c0, c1, c0], tag, [w0, w1, w0], mid, Vector3.ZERO)
		else:
			_tri_tagged(st, [ring0[k], b, ring0[k1]], [c0, c1, c0], tag, [w0, w1, w0], mid, Vector3.ZERO)


static func _tri(st: SurfaceTool, p: Array, c: Array, part: int, w: Array, inside: Vector3) -> void:
	_tri_tagged(st, p, c, float(part), w, inside, Vector3.ZERO)


## A maw's triangle: each vertex carries its offset from the maw's centre `maw_c` (UV2).
static func _maw_tri(st: SurfaceTool, p: Array, c: Array, tag: float, w: Array, maw_c: Vector3, inside: Vector3) -> void:
	_tri_tagged(st, p, c, tag, w, inside, maw_c, true)


## One flat-shaded triangle facing away from `inside`. `tag` is the part plus an id; with `maw`, each
## vertex's UV2 is its offset from `maw_c` across the maw (the maws face +Z).
static func _tri_tagged(st: SurfaceTool, p: Array, c: Array, tag: float, w: Array, inside: Vector3, maw_c: Vector3,
		maw: bool = false) -> void:
	var n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	var order: Array[int] = [0, 1, 2]
	if n.dot((p[0] + p[1] + p[2]) / 3.0 - inside) > 0.0:
		order = [0, 2, 1]
	else:
		n = -n
	for i: int in order:
		var v: Vector3 = p[i]
		st.set_normal(n)
		st.set_color(c[i])
		st.set_uv(Vector2(tag, float(w[i])))
		st.set_uv2(Vector2(v.x - maw_c.x, v.y - maw_c.y) if maw else Vector2.ZERO)
		st.add_vertex(v)
