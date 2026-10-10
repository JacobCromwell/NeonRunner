class_name FenceGenerator
extends Enemy
## A fence generator (GDD §9.1): an occasional machine in a floor lane that powers a group of
## electric fences just ahead of it (most fences have none; patterns place it with its fences). It
## shows what it powers with the fence hazard language: pink energy coils and pulsing pink conduits
## running to each of its fences.
## - Destroyed by a **stomp** or the **dash** only. **Weapons never set it off** (GDD §9.1, decided
##   September 26, 2026): immune_to_weapons keeps it off auto-fire's target list and blocks all
##   weapon damage (a direct hit, a stray shot aimed elsewhere, a homing missile, or splash), so an
##   EMP is always the player's choice (hosts had the same rule until October 8, 2026; weapons now hit
##   them, GDD §9.7). Claws and plain contact don't destroy it (FB 73); its body is solid, so
##   running into it kills, unless armor (which absorbs the hit, armor_blocks_solid) or the shield is up.
## - Destroying it sets off an EMP (RunWorld.emp): every fence within emp_radius (DESIGN-TBD, in
##   data/enemies/generator.tres) switches off for the rest of the level, and every enemy hears it
##   (the Cyborg's Bad Dream dissolves, GDD §9.7).
## - A destructible obstacle, not a creature (is_obstacle): it scores but doesn't count as a kill.
## The wreck stays, dark and harmless, until the player is far past.

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
## Hitboxes stay inside the machine's silhouette (its core is 0.88 m wide at the foot).
const BODY_SIZE := Vector3(0.8, 0.7, 0.8)
## The stomp zone: its bottom sits at the stomp line (top - stomp tolerance), where the body ends.
const TOP_SIZE := Vector3(0.8, 0.45, 0.8)
const TOP_Y: float = 0.925
const HUSK_KEEP: float = 40.0
## Its fireball (RunEffects.fireball, radius in metres; GDD §11), inside the EMP's cyan ring (World.emp): the runner
## is usually standing on it (a stomp, a dash, claws), so it is small, held in and quick, with no smoke (it must not
## hide the runner or the lanes and fences the EMP has just switched off).
const FIRE_SIZE: float = 1.2
const FIRE_SPREAD: float = 0.5
const FIRE_PACE: float = 1.5
const CABLE_Y: float = 0.02

var tuning: FenceGeneratorTuning
var lane: int = 0
## The layout fences its conduits feed: every fence ahead of it within the EMP's reach.
var powered: Array[Dictionary] = []

var _body: MeshInstance3D
var _energy: MeshInstance3D
var _cable_core: MeshInstance3D
var _husk: bool = false


## A fence generator's look (its body, energy rings and a stretch of cable), for EnemyDirector.warm_up
## (which frees it) and ShaderWarmup: the first builds the kit's meshes and shaders it uses.
static func warm_up(world: RunWorld, _entry: Dictionary) -> Node:
	var c: Variant = world.skin.get(&"fence_color") if world.skin != null else null
	var pink: Color = c if c is Color else Kit.FENCE_PINK
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = Kit.mesh("generator/body", _body_mesh)
	body.material_override = Kit.part_material(&"normal")
	root.add_child(body)
	var energy := MeshInstance3D.new()
	energy.mesh = Kit.mesh("generator/energy", _energy_mesh)
	energy.material_override = Kit.energy_material(pink)
	root.add_child(energy)
	var core := Kit.Builder.new()
	core.box(Vector3.ZERO, Vector3(0.5, 0.02, 0.035), Color.WHITE)
	var cable := MeshInstance3D.new()
	cable.mesh = core.commit()
	var material := ShaderMaterial.new()
	material.shader = Kit.shader("cable")
	material.set_shader_parameter(&"color", pink)
	cable.material_override = material
	root.add_child(cable)
	return root


func _build() -> void:
	tuning = tuning_res as FenceGeneratorTuning
	if tuning == null:
		tuning = FenceGeneratorTuning.new()
	display_name = "generator"
	is_obstacle = true
	claw_immune = true
	stompable = true
	dash_kills = true
	immune_to_weapons = true
	lane = clampi(int(spawn.get("lane", 0)), 0, world.geo.lane_count - 1)
	var at: float = float(spawn.get("at", 0.0))
	position = world.lane_point(lane, at)
	# Armor absorbs a collision with the body like any other damage it works against (owner, October 10, 2026).
	add_hitbox(&"body", BODY_SIZE, Vector3(0.0, BODY_SIZE.y * 0.5, 0.0)).armor_blocks_solid = true
	add_hitbox(&"top", TOP_SIZE, Vector3(0.0, TOP_Y, 0.0))
	powered = fences_in_reach(world.layout, world.geo, at, lane, tuning.emp_radius)
	_build_visuals()


func aim_point() -> Vector3:
	return global_position + Vector3(0.0, 0.55, 0.0)


func hit_radius() -> float:
	return 0.6


## Fences ahead of a generator at track distance `at` in `lane` that its EMP reaches (the same
## distance test as TrackBuilder.disable_fences_near).
static func fences_in_reach(layout: LevelLayout, geo: TrackGeometry, at: float, p_lane: int,
		radius: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var center := Vector3(geo.lane_x(p_lane), 0.0, TrackGeometry.world_z(at))
	for f: Dictionary in layout.fences:
		if float(f["at"]) < at - 0.5:
			continue
		var pos := Vector3(geo.lane_x(f["lane"]), 0.0, TrackGeometry.world_z(f["at"]))
		if pos.distance_to(center) <= radius:
			out.append(f)
	return out


func _on_defeated(_cause: StringName) -> void:
	_husk = true
	world.emp(aim_point(), tuning.emp_radius)
	world.effects.fireball(global_position + Vector3(0.0, 0.9, 0.0), FIRE_SIZE, false, FIRE_PACE, FIRE_SPREAD)
	world.effects.burst(global_position + Vector3(0.0, 0.9, 0.0), Color(1.0, 0.55, 0.9), 30, 1.0)
	_body.material_override = Kit.part_material(&"dead")
	_energy.visible = false
	if _cable_core != null:
		_cable_core.visible = false


func _process(_delta: float) -> void:
	if _husk and world != null and world.player != null \
			and world.player_distance() - track_distance() > HUSK_KEEP:
		queue_free()


func _build_visuals() -> void:
	var pink: Color = _fence_color()
	_body = MeshInstance3D.new()
	_body.mesh = Kit.mesh("generator/body", _body_mesh)
	_body.material_override = Kit.part_material(&"normal")
	add_child(_body)
	_energy = MeshInstance3D.new()
	_energy.mesh = Kit.mesh("generator/energy", _energy_mesh)
	_energy.material_override = Kit.energy_material(pink)
	_energy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_energy)
	_build_cables(pink)


## Conduits: a trunk along the lane seam next to the generator up to its fences, then a branch
## along the foot of each fence to its lane. Flat on the floor and dark-cased, so they read as
## cables, not as a barrier.
func _build_cables(pink: Color) -> void:
	if powered.is_empty():
		return
	var geo: TrackGeometry = world.geo
	var my_x: float = geo.lane_x(lane)
	var centre_x: float = 0.0
	var far_d: float = 0.0
	for f: Dictionary in powered:
		centre_x += geo.lane_x(f["lane"])
		far_d = maxf(far_d, float(f["at"]))
	centre_x /= powered.size()
	var seam_side: float = 1.0 if centre_x >= my_x else -1.0
	if lane == (geo.lane_count - 1 if seam_side > 0.0 else 0):
		seam_side = -seam_side
	var seam_x: float = seam_side * geo.lane_width * 0.5  # local x of the lane seam
	var at: float = track_distance()
	var casing := Kit.Builder.new()
	var core := Kit.Builder.new()
	var dark := Color(0.06, 0.05, 0.07)
	# From the generator's side to the seam, then forward along it.
	var start_z: float = -0.2
	_cable(casing, core, Vector3(seam_side * 0.45, 0.0, start_z), Vector3(seam_x, 0.0, start_z), dark)
	var end_z: float = -(far_d - at) + 0.25
	_cable(casing, core, Vector3(seam_x, 0.0, start_z), Vector3(seam_x, 0.0, end_z), dark)
	# One branch per fence row, from the seam across to its outermost fence.
	var rows: Dictionary = {}
	for f: Dictionary in powered:
		var key: float = snappedf(float(f["at"]), 0.01)
		var fx: float = geo.lane_x(f["lane"]) - my_x
		var span: Vector2 = rows.get(key, Vector2(seam_x, seam_x))
		rows[key] = Vector2(minf(span.x, fx), maxf(span.y, fx))
	for key: float in rows:
		var fz: float = -(key - at) + world.tuning.fence_depth * 0.5 + 0.12
		var span: Vector2 = rows[key]
		_cable(casing, core, Vector3(span.x, 0.0, fz), Vector3(span.y, 0.0, fz), dark)
	var casing_inst := MeshInstance3D.new()
	casing_inst.mesh = casing.commit()
	casing_inst.material_override = Kit.part_material(&"normal")
	casing_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(casing_inst)
	_cable_core = MeshInstance3D.new()
	_cable_core.mesh = core.commit()
	var m := ShaderMaterial.new()
	m.shader = Kit.shader("cable")
	m.set_shader_parameter(&"color", pink)
	m.set_shader_parameter(&"origin", global_position)
	_cable_core.material_override = m
	_cable_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cable_core)


## One straight conduit segment (local space) along x or z.
static func _cable(casing: Kit.Builder, core: Kit.Builder, a: Vector3, b: Vector3, dark: Color) -> void:
	var mid: Vector3 = (a + b) * 0.5
	var along_x: bool = absf(b.x - a.x) > absf(b.z - a.z)
	var length: float = a.distance_to(b) + 0.1
	if length < 0.12:
		return
	var size_case := Vector3(length, 0.035, 0.1) if along_x else Vector3(0.1, 0.035, length)
	var size_core := Vector3(length, 0.02, 0.035) if along_x else Vector3(0.035, 0.02, length)
	casing.box(Vector3(mid.x, CABLE_Y, mid.z), size_case, dark)
	core.box(Vector3(mid.x, CABLE_Y + 0.02, mid.z), size_core, Color.WHITE)


func _fence_color() -> Color:
	var c: Variant = world.skin.get(&"fence_color") if world.skin != null else null
	return c if c is Color else Kit.FENCE_PINK


## A squat machine: base plate, an octagonal core with vents, and two exhaust stacks.
static func _body_mesh() -> ArrayMesh:
	var b := Kit.Builder.new()
	var casing := Color(0.2, 0.21, 0.26)
	var plate := Color(0.1, 0.1, 0.12)
	var stripe := Color(0.95, 0.75, 0.2)
	b.box(Vector3(0.0, 0.06, 0.0), Vector3(1.1, 0.12, 1.1), plate, 0.0, Vector2(0.94, 0.94))
	b.prism(Vector3(0.0, 0.47, 0.0), 0.44, 0.7, 8, casing, 0.0, 0.88)
	b.box(Vector3(0.0, 0.86, 0.0), Vector3(0.62, 0.08, 0.62), plate, 0.0, Vector2(0.9, 0.9))
	for s: float in [-1.0, 1.0]:
		b.prism(Vector3(s * 0.2, 0.98, -0.12), 0.07, 0.24, 6, plate)
		# Hazard striping on the base corners (warns: solid machinery).
		b.box(Vector3(s * 0.48, 0.125, 0.48), Vector3(0.1, 0.012, 0.1), stripe)
		b.box(Vector3(s * 0.48, 0.125, -0.48), Vector3(0.1, 0.012, 0.1), stripe)
	for a: int in 4:
		var ang: float = TAU * a / 4.0 + PI * 0.25
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		b.box(dir * 0.41 + Vector3(0.0, 0.45, 0.0), Vector3(0.1, 0.36, 0.1), plate, 0.0, Vector2.ONE,
			Basis(Vector3.UP, -ang))
	return b.commit()


## The glowing parts: coil rings around the core, a core slot and the exhaust tips.
static func _energy_mesh() -> ArrayMesh:
	var b := Kit.Builder.new()
	# Rings sit just outside the tapered core (radius 0.44 at its foot, 0.387 at its top).
	for y: float in [0.3, 0.52, 0.74]:
		var r: float = lerpf(0.44, 0.44 * 0.88, (y - 0.12) / 0.7) + 0.03
		b.prism(Vector3(0.0, y, 0.0), r, 0.045, 8, Color.WHITE)
	b.prism(Vector3(0.0, 0.92, 0.0), 0.16, 0.12, 8, Color.WHITE)
	for s: float in [-1.0, 1.0]:
		b.prism(Vector3(s * 0.2, 1.12, -0.12), 0.055, 0.05, 6, Color.WHITE)
	return b.commit()
