class_name BeachSplash
extends Node3D
## A splash where the runner (or anything that falls) goes into a Beach pool's water (BeachWaterWatch spawns it; the
## owner, October 9, 2026: "a fall makes a splash"): a crown of white foam that jumps up and falls back, droplets
## thrown into the air, and two rings of foam spreading over the water. Scenery only: no collision, no gameplay,
## unlit white (no glow, nothing near a hazard's colour, no flash: every part rises and fades smoothly), a
## one-shot that frees itself after LIFE seconds, built on demand from a handful of shared static meshes and a few
## nodes (CPUParticles3D for the droplets, which the Compatibility renderer draws too).
## Placed with its origin on the water's surface at the entry point.
## It is the water's own foam, so it takes the street's light as the water does (G8): its colour is multiplied by the
## light a level sets, `ZoneSkin.scenery_light_now` (a level's darkness) and `scenery_tint_now` (a level sky's street
## light, the Beach's sunset warms it), once when it is made (a splash lives 1.2 s). It is not a kit shader, so it
## can't read the global uniforms; the two values are the ones `ZoneSkin.set_scenery_light` and `set_scenery_tint`
## keep beside them. Its glow stays none and it still ignores the sun: foam is white paint on the water.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md, item 559): the splash's look (a crown, droplets and two rings, 1.2 s) and its
## `splash` sound are placeholders.

## How long it lives, seconds.
const LIFE: float = 1.2
## The foam and the droplets' colour in the zone's own light (a touch of aqua so it sits in the water; under the
## glow threshold); the splash wears it in the street's light (in_street_light).
const FOAM := Color(0.93, 0.98, 0.97)
## The ring's reach (radius, metres) and how long it spreads.
const RING_REACH: float = 2.4
const RING_TIME: float = 0.9
## The crown's height, and how long it takes to rise and to fall back.
const CROWN_HEIGHT: float = 1.3
const CROWN_RISE: float = 0.26
const CROWN_FALL: float = 0.55
const DROPLETS: int = 30

static var _ring_mesh: ArrayMesh
static var _crown_mesh: ArrayMesh
static var _drop_mesh: SphereMesh

## Seconds since it was made (advance() moves it on; _process does while the game runs).
var age: float = 0.0
## FOAM in the street's light as it was when the splash was made.
var foam: Color = FOAM
var _ring: MeshInstance3D
var _ring_late: MeshInstance3D
var _crown: MeshInstance3D
var _drops: CPUParticles3D
var _foam_mat: StandardMaterial3D


func _init() -> void:
	name = "BeachSplash"
	foam = in_street_light(FOAM)
	_foam_mat = _material()
	_ring = _part(_ring_mesh_shared(), _foam_mat)
	_ring_late = _part(_ring_mesh_shared(), _foam_mat)
	_crown = _part(_crown_mesh_shared(), _foam_mat)
	_drops = CPUParticles3D.new()
	_drops.amount = DROPLETS
	_drops.lifetime = 0.95
	_drops.one_shot = true
	_drops.explosiveness = 0.9
	_drops.direction = Vector3.UP
	_drops.spread = 38.0
	_drops.initial_velocity_min = 3.0
	_drops.initial_velocity_max = 6.0
	_drops.gravity = Vector3(0.0, -9.8, 0.0)
	_drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_drops.emission_sphere_radius = 0.18
	_drops.mesh = _drop_mesh_shared()
	_drops.material_override = _particle_material()
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.95))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	_drops.color_ramp = fade
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_drops.emitting = true
	add_child(_drops)
	advance(0.0)


func _process(delta: float) -> void:
	advance(delta)


## Moves the splash on by `delta` seconds: the rings spread and fade, the crown jumps up and falls back; at LIFE
## it frees itself.
func advance(delta: float) -> void:
	age += delta
	var t: float = age
	# The first ring spreads fast and slows, fading as it goes; the second follows 0.12 s later, smaller.
	_spread(_ring, t, RING_TIME, RING_REACH, 0.8)
	_spread(_ring_late, t - 0.12, RING_TIME, RING_REACH * 0.7, 0.55)
	# The crown: up with a rush, then back, its foam widening and thinning.
	var rise: float = clampf(t / CROWN_RISE, 0.0, 1.0)
	var fall: float = clampf((t - CROWN_RISE) / CROWN_FALL, 0.0, 1.0)
	var height: float = (1.0 - pow(1.0 - rise, 2.0)) * (1.0 - fall * fall)
	var width: float = 0.5 + 0.6 * clampf(t / (CROWN_RISE + CROWN_FALL), 0.0, 1.0)
	_crown.scale = Vector3(width, maxf(height * CROWN_HEIGHT, 0.001), width)
	_crown.visible = t < CROWN_RISE + CROWN_FALL
	# Every part's own fade is in its material (they share one: the crown thins as the rings do).
	var life: float = clampf(t / LIFE, 0.0, 1.0)
	_foam_mat.albedo_color = Color(foam, 0.75 * (1.0 - life * life))
	if age >= LIFE:
		queue_free()


## A ring's scale and visibility at `t` seconds (negative: not yet), reaching `reach` metres over `time`.
func _spread(ring: MeshInstance3D, t: float, time: float, reach: float, start: float) -> void:
	var k: float = clampf(t / time, 0.0, 1.0)
	ring.visible = t > 0.0 and k < 1.0
	var radius: float = lerpf(start, reach, 1.0 - pow(1.0 - k, 2.0))
	ring.scale = Vector3(radius, 1.0, radius)


## A colour in the street's light: the light a level sets (its darkness) and its sky's tint multiply its linear colour,
## as the scenery's shaders multiply theirs (ZoneSkin.scenery_light_now, scenery_tint_now; white and 1 in the zone's own
## light, so the day levels' foam is FOAM as it was).
static func in_street_light(color: Color) -> Color:
	var linear: Color = color.srgb_to_linear()
	var light: float = ZoneSkin.scenery_light_now
	var tint: Color = ZoneSkin.scenery_tint_now
	return Color(linear.r * light * tint.r, linear.g * light * tint.g, linear.b * light * tint.b, color.a).linear_to_srgb()


# --- Parts and shared meshes -------------------------------------------------------------------------

func _part(mesh: Mesh, material: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Just over the water, so the opaque plane never hides it.
	inst.position = Vector3(0.0, 0.03, 0.0)
	add_child(inst)
	return inst


## Unlit, alpha-blended, both sides drawn (nothing about it needs a facing), drawn over the opaque water.
func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = foam
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = false
	m.disable_fog = false
	return m


func _particle_material() -> StandardMaterial3D:
	var m := _material()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(foam, 1.0)
	return m


## A flat ring of foam on the water's plane, soft at both edges: radius 1 outside (clear), a bright band at 0.86,
## clear again at 0.7 inside, so it reads as a ripple, not a hoop.
static func _ring_mesh_shared() -> ArrayMesh:
	if _ring_mesh == null:
		var verts := PackedVector3Array()
		var colors := PackedColorArray()
		var count: int = 28
		var radii: Array[float] = [1.0, 0.86, 0.7]
		var alphas: Array[float] = [0.0, 1.0, 0.0]
		for i: int in count:
			var a0: float = TAU * float(i) / float(count)
			var a1: float = TAU * float(i + 1) / float(count)
			for band: int in 2:
				var r0: float = radii[band]
				var r1: float = radii[band + 1]
				var c0 := Color(1, 1, 1, alphas[band])
				var c1 := Color(1, 1, 1, alphas[band + 1])
				var p00 := Vector3(cos(a0), 0.0, sin(a0)) * r0
				var p01 := Vector3(cos(a1), 0.0, sin(a1)) * r0
				var p10 := Vector3(cos(a0), 0.0, sin(a0)) * r1
				var p11 := Vector3(cos(a1), 0.0, sin(a1)) * r1
				verts.append_array(PackedVector3Array([p00, p01, p11, p00, p11, p10]))
				colors.append_array(PackedColorArray([c0, c0, c1, c0, c1, c1]))
		_ring_mesh = _mesh_of(verts, colors)
	return _ring_mesh


## A crown: twelve spikes of foam standing in a ring and leaning out, 1 m tall, 0.5 m across at the foot.
static func _crown_mesh_shared() -> ArrayMesh:
	if _crown_mesh == null:
		var verts := PackedVector3Array()
		var spikes: int = 14
		for i: int in spikes:
			var a: float = TAU * float(i) / float(spikes)
			var side: float = TAU / float(spikes) * 0.38
			var foot_a := Vector3(cos(a - side), 0.0, sin(a - side)) * 0.3
			var foot_b := Vector3(cos(a + side), 0.0, sin(a + side)) * 0.3
			var tip: Vector3 = Vector3(cos(a), 0.0, sin(a)) * 0.62 + Vector3(0.0, 1.0, 0.0)
			verts.append_array(PackedVector3Array([foot_a, foot_b, tip]))
		_crown_mesh = _mesh_of(verts, PackedColorArray())
	return _crown_mesh


## A droplet: a small low-poly sphere (it reads round from any side, no billboard needed).
static func _drop_mesh_shared() -> SphereMesh:
	if _drop_mesh == null:
		_drop_mesh = SphereMesh.new()
		_drop_mesh.radius = 0.075
		_drop_mesh.height = 0.15
		_drop_mesh.radial_segments = 6
		_drop_mesh.rings = 3
	return _drop_mesh


static func _mesh_of(verts: PackedVector3Array, colors: PackedColorArray) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	if colors.size() != verts.size():
		colors = PackedColorArray()
		colors.resize(verts.size())
		colors.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
