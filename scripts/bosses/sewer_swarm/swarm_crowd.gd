class_name SwarmCrowd
extends MultiMeshInstance3D
## One crowd of the Sewer Swarm (GDD §10: "rendered as many screech-variant creatures using MultiMesh plus a
## shader for per-creature motion. It looks like hundreds, but only 4-5 are simulated"; CLAUDE.md: MultiMesh
## plus shaders for crowds, simulate few entities, render many): ONE MultiMesh of the sewer screech's crowd
## mesh (ScreechModel.crowd_mesh) with ONE material of its own, drawn in one call however many creatures it
## holds. No node, script or physics per creature: swarm_crowd.gdshader places and animates every one of
## them from a few uniforms this node sets (only when they change). Three kinds (Kind):
## - CLUSTER: a swarm cluster's creatures (SwarmCluster: its mound at the roadside, the pour into a lane,
##   the charging mass, its death; thinned by weapons, rising as it forms);
## - BAND: the roadside horde in one gutter (SwarmHorde), following the runner;
## - SPILL: screeches pouring out of the lairs as they burst (SwarmHorde), each instance placed at its lair.
## Crowds are made before the fight (SewerSwarm's pool, SwarmHorde) and reused, so a fight makes no mesh or
## material mid-fight; `made` counts the crowds made (tests). The crowd size is the look only: the fight
## never reads it.

enum Kind { CLUSTER, BAND, SPILL }

const SHADER: Shader = preload("res://scripts/bosses/sewer_swarm/swarm_crowd.gdshader")

## Crowds made so far (tests: a fight makes none after it has begun).
static var made: int = 0

var kind: Kind = Kind.CLUSTER
var count: int = 0
var material: ShaderMaterial

## The uniforms as last set (set_shader_parameter is only called when one changes).
var _sent: Dictionary = {}
## A cluster's mass's length and width (set_shapes), sent with its place (set_formation).
var _mass_length: float = 5.2
var _mass_width: float = 2.0


## A crowd of `p_count` creatures of `kind`, placed by `seed_value` (the same crowd every time), in the
## zone's weathering (`grime`: 1 for Gangland's scavenger look) at `scale` (a sewer screech's size = 1).
static func make(p_kind: Kind, p_count: int, seed_value: int, grime: float = 1.0, scale: float = 0.62) -> SwarmCrowd:
	var crowd := SwarmCrowd.new()
	crowd.kind = p_kind
	crowd.name = "SwarmCrowd"
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crowd.material = ShaderMaterial.new()
	crowd.material.shader = SHADER
	crowd.material_override = crowd.material
	crowd.multimesh = MultiMesh.new()
	crowd.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	# White instance colours, never changed: the Compatibility renderer multiplies a MultiMesh's vertex
	# colours (the screech's colours and glow mask) by its instance colour even when it has none, which is
	# then zero (a crowd with custom data only drew colourless there, its glow gone).
	crowd.multimesh.use_colors = true
	crowd.multimesh.use_custom_data = true
	crowd.multimesh.mesh = ScreechModel.crowd_mesh()
	crowd.resize(p_count, seed_value)
	crowd.set_param(&"kind", int(p_kind))
	crowd.set_param(&"grime", grime)
	crowd.set_param(&"creature_scale", scale)
	if p_kind != Kind.SPILL:
		# Its creatures are placed by the shader around the node, never by their instance transforms (the
		# identity), so it can't work out its own bounds: these hold every formation (a cluster pouring
		# across the widest street, flung by a shock; a band's length).
		crowd.custom_aabb = AABB(Vector3(-12.0, -6.0, -12.0), Vector3(24.0, 12.0, 24.0)) if p_kind == Kind.CLUSTER \
			else AABB(Vector3(-12.0, -1.0, -200.0), Vector3(24.0, 4.0, 240.0))
	else:
		crowd.extra_cull_margin = 3.0
	made += 1
	return crowd


## Sets how many creatures it holds (the stress scene's slider; a fight sizes its crowds once, before it
## begins). Each gets three random numbers placing it in its formation and its rank (evenly spread over
## [0, 1), shuffled against where it stands), all from `seed_value`.
func resize(p_count: int, seed_value: int) -> void:
	count = maxi(p_count, 0)
	multimesh.instance_count = 0
	multimesh.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var hidden := Transform3D(Basis.IDENTITY, Vector3(0.0, -100.0, 0.0))
	for i: int in count:
		multimesh.set_instance_transform(i, hidden if kind == Kind.SPILL else Transform3D.IDENTITY)
		multimesh.set_instance_color(i, Color.WHITE)
		var rank: float = (float(i) + 0.5) / maxf(count, 1)
		if kind == Kind.SPILL:
			# Not out of any lair yet: its burst clock long past.
			multimesh.set_instance_custom_data(i, Color(-100.0, 0.0, rng.randf(), rank))
		else:
			multimesh.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rank))
	multimesh.visible_instance_count = -1


## Sets one of the shader's uniforms, if it changed.
func set_param(param: StringName, value: Variant) -> void:
	if _sent.get(param) == value and _sent.has(param):
		return
	_sent[param] = value
	material.set_shader_parameter(param, value)


## A cluster's formation (see swarm_crowd.gdshader): its mound against the wall at `wall_x` (signed) with its
## middle at local z `mound_z`; its mass in the lane at `lane_x` with its front at local z `front_z`.
func set_formation(wall_x: float, side: int, mound_z: float, lane_x: float, front_z: float) -> void:
	set_param(&"mound", Vector4(wall_x, mound_z, float(side), 0.0))
	set_param(&"mass", Vector4(lane_x, front_z, _mass_length, _mass_width))


## A cluster's shapes: its mound's length, depth and climb; its mass's length, width and height.
func set_shapes(mound_length: float, mound_depth: float, mound_climb: float, mass_length: float, mass_width: float,
		mass_height: float) -> void:
	_mass_length = mass_length
	_mass_width = mass_width
	set_param(&"mound_shape", Vector4(mound_length, mound_depth, mound_climb, 0.0))
	set_param(&"mass_height", mass_height)


## pour (0 in the mound .. 1 in the lane), rear (gathering), bristle (an attack's warning), charge (moving).
func set_motion(pour: float, rear: float, bristle: float, charge: float) -> void:
	set_param(&"motion", Vector4(_q(pour), _q(rear), _q(bristle), _q(charge)))


## alive (the share weapons left), formed (the share risen), its death (0 none, 1 shocked, 2 falling,
## 3 scattering) and the seconds since, and the charge's speed when it died.
func set_life(alive: float, formed: float, death: int, death_seconds: float, speed: float = 0.0) -> void:
	set_param(&"life", Vector4(_q(alive), _q(formed), float(death), death_seconds))
	set_param(&"death_at", Vector4(speed, 0.0, 0.0, 0.0))


## A band: in the gutter at `wall_x` (signed) on `side`, from `ahead` metres ahead of the node to `behind`
## behind it, `depth` out from the wall, clinging up to `climb`, drifting back at `drift` m/s, most of it
## gathered in heaps every `heap` metres.
func set_band(wall_x: float, side: int, ahead: float, behind: float, depth: float, climb: float, drift: float,
		heap: float = 7.0) -> void:
	set_param(&"band", Vector4(wall_x, ahead, behind, drift))
	set_param(&"band_shape", Vector4(depth, climb, float(side), heap))


## Places spill instance `i` at a lair (world position `at`, on `side`), coming out from `burst_clock`.
func set_spill(i: int, at: Vector3, side: int, burst_clock: float) -> void:
	if i < 0 or i >= count:
		return
	var custom: Color = multimesh.get_instance_custom_data(i)
	multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
	multimesh.set_instance_custom_data(i, Color(burst_clock, float(side), custom.b, custom.a))


## Creatures drawn at a time: all of them, or for a cluster only those its formed and alive shares show
## (its ranks run with the instance index, so the rest are the tail of the buffer and needn't be drawn).
func show_up_to(share: float) -> void:
	var n: int = count if share >= 1.0 else clampi(ceili(clampf(share, 0.0, 1.0) * count * 1.05) + 2, 0, count)
	if multimesh.visible_instance_count != n:
		multimesh.visible_instance_count = n



## Values sent to the shader are rounded, so a value easing toward its target stops resending once it's
## there to the eye.
static func _q(x: float) -> float:
	return snappedf(x, 0.001)
