class_name SwarmIntroSwarm
extends Node3D
## The swarm of the Gangland boss intro (SewerSwarmIntro): the wall of screeches that rises behind the runner and
## runs them down, and the cut's dark heart. Visual only, moved by the cinematic's clock (update).
## - The wall: two of the Sewer Swarm's own crowds (SwarmCrowd, its MultiMesh and shader, so it looks as it
##   does in the fight): a wave across the street curling over the runner (a cluster's wave, as its strike from
##   behind, as wide as the street) and the rest of the swarm behind it (a cluster's mass, charging). They rise
##   as the wall forms (SewerSwarmIntro.wall_rise), close in on the runner (wall_gap) and heat toward enemy-attack
##   red as they do (an attack is coming: the fight's colour language).
## - The heart, from the cut: a dark hollow in the wall's middle (an unlit bowl opening toward the camera), a
##   mound of screeches heaped round its rim and crawling over it (the screech's crowd body in a MultiMesh), the
##   Host held up inside it in the dark (SwarmHostPerson on the humanoid rig, its look darkened; its implants'
##   red still glowing), and the glint of the implant at its temple: one quick glint (glint_at), a slow, faint
##   glow instead with Reduced flashing.

const GLINT_SHADER: Shader = preload("res://scripts/cinematics/sewer_swarm_intro/swarm_intro_glint.gdshader")
## The person's height (as the fight's Host: SwarmHost.PERSON_HEIGHT) and the implant at its temple (on its
## head, the rig's design units: SwarmHostPerson's plate), the glint's place.
const PERSON_HEIGHT: float = 1.75
const TEMPLE := Vector3(0.093, 0.035, -0.02)
## The glint: in this long, out over this long. With Reduced flashing: up to SOFT_PEAK, rising and falling over
## SOFT_SECONDS (CineOverlay's soft flash), so nothing flashes.
const GLINT_RISE: float = 0.07
const GLINT_FALL: float = 0.4
const SOFT_PEAK: float = 0.4
const SOFT_SECONDS: float = CineOverlay.SOFT_FLASH_MIN_TIME + 0.2
## The bowl's rings and sides, and its colours (rim to back: a sickly near-black to black).
const MAW_RINGS: int = 6
const MAW_SIDES: int = 28
const MAW_RIM := Color(0.07, 0.065, 0.04)
const MAW_BACK := Color(0.004, 0.004, 0.003)
## The faint edge of the Host's silhouette in the dark (the sewer mist's sickly green, dimmed).
const HOST_RIM := Color(0.32, 0.45, 0.26)
## The mound's spines: raised, glowing less than the crowd's (it's the dark heart).
const MOUND_BRISTLE: float = 0.35

var intro: SewerSwarmIntro
var n: SewerSwarmIntroTuning
## The wall (its root at the foot of the wave, in the street's middle) and its two crowds.
var wall: Node3D
var wave: SwarmCrowd
var mass: SwarmCrowd
## The heart (its root at the middle of the hollow's mouth): the bowl, the mound, the Host and the glint.
var heart: Node3D
var maw: MeshInstance3D
var mound: MultiMeshInstance3D
var host: HumanoidRig
var glint: MeshInstance3D
## The glint's brightness now (0-1; tests).
var glint_strength: float = 0.0

var _glint_material: ShaderMaterial
var _mound_count: int = 0
var _mound_buffer := PackedFloat32Array()
var _scale: float = SwarmIntroScreeches.CROWD_SCALE


func setup(p_intro: SewerSwarmIntro) -> void:
	intro = p_intro
	n = intro.n
	name = "Swarm"
	var variant: StringName = intro.stage.skin.enemy_variant
	var grime: float = 0.0 if variant == &"city" else 1.0
	var boss_tuning := intro.zone.boss.tuning as SewerSwarmTuning if intro.zone != null and intro.zone.boss != null else null
	_scale = boss_tuning.creature_scale if boss_tuning != null else SwarmIntroScreeches.CROWD_SCALE
	var width: float = intro.stage.wall_x(1) - intro.stage.wall_x(-1) - 2.0 * n.wall_inset
	wall = Node3D.new()
	wall.name = "Wall"
	wall.visible = false
	add_child(wall)
	wave = SwarmCrowd.make(SwarmCrowd.Kind.CLUSTER, n.wave_creatures_low_end if intro.low_end else n.wave_creatures,
		hash("swarm_intro_wave"), grime, _scale)
	wave.name = "Wave"
	wave.set_wave_shape(n.wave_height, n.wave_reach, width)
	wave.set_wave(1, 0.0, 0.0, 0.0)
	wave.custom_aabb = AABB(Vector3(-12.0, -2.0, -n.wave_reach - 4.0), Vector3(24.0, n.wave_height + 6.0, n.wave_reach + 8.0))
	wall.add_child(wave)
	mass = SwarmCrowd.make(SwarmCrowd.Kind.CLUSTER, n.mass_creatures_low_end if intro.low_end else n.mass_creatures,
		hash("swarm_intro_mass"), grime, _scale)
	mass.name = "Mass"
	mass.set_shapes(4.6, 0.9, 1.7, n.mass_length, width, n.mass_height)
	# Its front at the wave's foot, the rest of it behind, charging after the runner (toward -z, down the track).
	mass.set_formation(-width * 0.5, -1, 0.0, 0.0, 0.0, -1.0)
	mass.custom_aabb = AABB(Vector3(-12.0, -2.0, -4.0), Vector3(24.0, n.mass_height + 4.0, n.mass_length + 8.0))
	wall.add_child(mass)
	_build_heart(variant)


func _build_heart(variant: StringName) -> void:
	heart = Node3D.new()
	heart.name = "Heart"
	heart.visible = false
	wall.add_child(heart)
	heart.position = Vector3(0.0, n.maw_height, -n.maw_forward)
	maw = MeshInstance3D.new()
	maw.name = "Maw"
	maw.mesh = maw_mesh(n.maw_size)
	maw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.vertex_color_use_as_albedo = true
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	dark.disable_fog = true
	maw.material_override = dark
	heart.add_child(maw)
	# The Host, held up in the dark at the back of the hollow, facing out of it (the rig faces -z, as the camera
	# looks back at it).
	host = HumanoidRig.new()
	host.name = "Host"
	heart.add_child(host)
	var look := SwarmHostPerson.material().duplicate() as ShaderMaterial
	look.set_shader_parameter(&"tint", Color(0.0, 0.0, 0.0, n.host_shade))
	# Just made out in the dark: a faint sickly edge to its silhouette.
	look.set_shader_parameter(&"rim_color", HOST_RIM)
	look.set_shader_parameter(&"rim_strength", 0.5)
	host.build(SwarmHostPerson.parts(), look)
	host.scale = Vector3.ONE * (PERSON_HEIGHT / 1.3)
	host.position = Vector3(0.0, -PERSON_HEIGHT * 0.86, n.maw_size.z * 0.45)
	host.apply_pose(SwarmHostPerson.held(0.0))
	glint = MeshInstance3D.new()
	glint.name = "Glint"
	var quad := QuadMesh.new()
	quad.size = Vector2(n.glint_size, n.glint_size)
	glint.mesh = quad
	_glint_material = ShaderMaterial.new()
	_glint_material.shader = GLINT_SHADER
	glint.material_override = _glint_material
	glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glint.visible = false
	heart.add_child(glint)
	# The mound round the rim.
	_mound_count = n.mound_creatures_low_end if intro.low_end else n.mound_creatures
	mound = MultiMeshInstance3D.new()
	mound.name = "Mound"
	mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mound.material_override = ScreechModel.multimesh_material(variant)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = ScreechModel.crowd_mesh()
	mm.instance_count = _mound_count
	mound.multimesh = mm
	mound.custom_aabb = AABB(Vector3(-5.0, -4.0, -2.0), Vector3(10.0, 8.0, 6.0))
	heart.add_child(mound)
	_mound_buffer.resize(_mound_count * 20)


func update(t: float) -> void:
	var on: bool = t >= n.wall_from
	wall.visible = on
	if not on:
		return
	var foot: float = intro.wall_foot_z(t)
	wall.global_position = intro.stage.point(Vector3(intro.street_middle(), 0.0, foot))
	var rise: float = intro.wall_rise(t)
	var heat: float = lerpf(n.heat_from, n.heat_cut, smoothstep(n.wall_from, n.cut_at, t))
	wave.set_wave(1, 0.0, 0.0, rise)
	wave.set_motion(0.0, 0.0, heat, 1.0)
	wave.set_life(1.0, rise, 0, 0.0)
	# Only the risen are drawn (their ranks run with the instance index).
	wave.show_up_to(rise)
	var formed: float = clampf(rise * 1.3, 0.0, 1.0)
	mass.set_motion(1.0, 0.0, heat, 1.0)
	mass.set_life(1.0, formed, 0, 0.0)
	mass.show_up_to(formed)
	# The heart is the cut's, in the middle of the wall (the runner's lane, as the cut looks back down it).
	var cut: bool = t >= n.cut_at
	heart.visible = cut
	if not cut:
		glint_strength = 0.0
		return
	heart.position = Vector3(-intro.street_middle(), n.maw_height, -n.maw_forward)
	host.apply_pose(SwarmHostPerson.held(fmod((t - n.cut_at) * 0.35, 1.0)))
	_update_mound(t)
	glint_strength = glint_at(t)
	glint.visible = glint_strength > 0.001
	if glint.visible:
		var head: Node3D = host.joint(&"head")
		var at: Vector3 = head.global_transform * TEMPLE if head != null else heart.global_position
		# A little toward the camera, so it's never inside the head.
		glint.global_position = at + Vector3(0.0, 0.0, -0.15)
		_glint_material.set_shader_parameter(&"strength", glint_strength)


## How bright the glint is at `t` (0-1): one quick glint `glint_after` into the cut; with Reduced flashing a slow,
## faint glow instead.
func glint_at(t: float) -> float:
	var g: float = t - (n.cut_at + n.glint_after)
	if g < 0.0:
		return 0.0
	if Settings.flashing_reduced:
		return SOFT_PEAK * sin(PI * g / SOFT_SECONDS) if g < SOFT_SECONDS else 0.0
	if g < GLINT_RISE:
		return g / GLINT_RISE
	var k: float = clampf(1.0 - (g - GLINT_RISE) / GLINT_FALL, 0.0, 1.0)
	return k * k


## The mound: screeches heaped round the hollow's rim, sloping back from it to the wall, crawling round it.
func _update_mound(t: float) -> void:
	var rx: float = n.maw_size.x * 0.5
	var ry: float = n.maw_size.y * 0.5
	var mouth_back: float = n.maw_forward - 0.5
	for i: int in _mound_count:
		var u: float = _hash(i, 1)
		var out: float = _hash(i, 2)
		var dir: float = -1.0 if _hash(i, 3) < 0.5 else 1.0
		var a: float = u * TAU + dir * (0.12 + 0.1 * _hash(i, 4)) * t
		var ring := Vector2(cos(a), sin(a))
		# A ragged heap: its rim's own raggedness (maw_mesh), some hanging in over the dark.
		var ragged: float = 1.0 + 0.12 * sin(a * 5.0 + 1.3) + 0.07 * sin(a * 11.0) - 0.12 * float(_hash(i, 8) < 0.15)
		var r: float = ragged + out * n.mound_width / maxf(minf(rx, ry), 0.1)
		var local := Vector3(ring.x * rx * r, ring.y * ry * r, -0.08 + out * mouth_back)
		# Heaped on the street below the hollow, never under it.
		local.y = maxf(local.y, -n.maw_height + 0.05 + _hash(i, 5) * 0.3)
		var up := Vector3(ring.x * 0.6, ring.y * 0.6, -1.0).normalized()
		# Crawling round it, each its own way across the heap (never all in step).
		var tangent := Vector3(-ring.y * dir, ring.x * dir, 0.0).rotated(up, (_hash(i, 9) - 0.5) * 2.4 + sin(t * 1.3 + u * 20.0) * 0.3)
		var basis := Basis.looking_at(tangent, up)
		var s: float = _scale * (0.8 + 0.4 * _hash(i, 6))
		basis = basis.scaled(Vector3(s, s, s))
		# MultiMesh's layout: the basis by rows and the origin, then the colour, then the custom data.
		var o: int = i * 20
		_mound_buffer[o] = basis.x.x
		_mound_buffer[o + 1] = basis.y.x
		_mound_buffer[o + 2] = basis.z.x
		_mound_buffer[o + 3] = local.x
		_mound_buffer[o + 4] = basis.x.y
		_mound_buffer[o + 5] = basis.y.y
		_mound_buffer[o + 6] = basis.z.y
		_mound_buffer[o + 7] = local.y
		_mound_buffer[o + 8] = basis.x.z
		_mound_buffer[o + 9] = basis.y.z
		_mound_buffer[o + 10] = basis.z.z
		_mound_buffer[o + 11] = local.z
		_mound_buffer[o + 12] = 1.0
		_mound_buffer[o + 13] = 1.0
		_mound_buffer[o + 14] = 1.0
		_mound_buffer[o + 15] = 1.0
		_mound_buffer[o + 16] = 0.0
		_mound_buffer[o + 17] = MOUND_BRISTLE
		_mound_buffer[o + 18] = 0.8
		_mound_buffer[o + 19] = _hash(i, 7) * 10.0
	mound.multimesh.buffer = _mound_buffer


## The hollow: the inside of half an ellipsoid `size` (width, height, depth) opening toward -z (its mouth at
## z = 0, its back at +z), its rim ragged; near-black at the rim to black at the back (vertex colours).
static func maw_mesh(size: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array[PackedVector3Array] = []
	for ring: int in MAW_RINGS + 1:
		var phi: float = 0.5 * PI * float(ring) / MAW_RINGS
		var row := PackedVector3Array()
		for s: int in MAW_SIDES:
			var a: float = TAU * float(s) / MAW_SIDES
			var ragged: float = 1.0 + (0.12 * sin(a * 5.0 + 1.3) + 0.07 * sin(a * 11.0)) * (1.0 - float(ring) / MAW_RINGS)
			row.append(Vector3(cos(phi) * cos(a) * size.x * 0.5 * ragged, cos(phi) * sin(a) * size.y * 0.5 * ragged,
				sin(phi) * size.z))
		grid.append(row)
	for ring: int in MAW_RINGS:
		var c0: Color = MAW_RIM.lerp(MAW_BACK, float(ring) / MAW_RINGS)
		var c1: Color = MAW_RIM.lerp(MAW_BACK, float(ring + 1) / MAW_RINGS)
		for s: int in MAW_SIDES:
			var s1: int = (s + 1) % MAW_SIDES
			var quad: Array[Vector3] = [grid[ring][s], grid[ring][s1], grid[ring + 1][s1], grid[ring + 1][s]]
			var cols: Array[Color] = [c0, c0, c1, c1]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				st.set_color(cols[idx])
				st.set_normal(Vector3(0.0, 0.0, -1.0))
				st.add_vertex(quad[idx])
	return st.commit()


func _hash(i: int, k: int) -> float:
	return float(posmod(hash([i, k, "swarm_intro_mound"]), 10007)) / 10007.0
