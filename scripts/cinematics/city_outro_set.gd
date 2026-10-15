class_name CityOutroSet
extends Node3D
## The City outro's props (CityOutro): visual only, no collision and no gameplay, built from the game's own
## models so they read as the enemies the player has met (GDD §6, Cinematics: the owner's beats, October 8,
## 2026). CityOutro places them and moves them on the cinematic's clock; positions are world space (the
## sequencer sits at the origin, CineStage converts track space).
## - The Floating Head's ship (FloatingHeadModel's hull, face screen, jaw, bay doors and weak-point covers;
##   the fight's face shader): it hangs dying in the air, its face tearing into static (held still with
##   Reduced flashing), loses power and plunges into the street, where it becomes the fight's wreck, its
##   torn-off face falling flat before it, with grey dust and smoke (no flash), as in the fight's defeat.
## - The roadblock in a side street on the left (DESIGN-TBD, docs/OPEN_QUESTIONS.md §D, items 370-373): the
##   zone's own floor laid across the side street (ZoneSkin.floor_segment, so it follows the skin: the City's
##   truck roofs), a low barricade of concrete blocks with police-blue and white rails, Barnacle Turrets
##   standing in it on the floor like cannons (BarnacleTurretModel, turned over), a battle truck behind
##   (EnforcerTruckModel, its light bar alternating red and blue, steady with Reduced flashing) and a heli
##   drone over it (the drone's own model). The five cyborgs are the cinematic's actors (CineActor), not props.
## - The roadblock's shots (enemy-fire red bolts) and the blast they make behind the runner as they leap: one of
##   the game's shared yellow-and-red fireballs (FireballPool; GDD §11, the owner, October 8, 2026: every explosion
##   is one), from a pool of the props' own built with them (a cinematic has no RunEffects), softened by Reduced
##   flashing (no white-hot core, a fire that swells up instead of popping).
## Every colour keeps the game's language: red only on the enemies' charge-ups, their fire and the light
## bar; the rest matte; nothing flickers with Reduced flashing.

const FACE_SHADER: String = "res://scripts/bosses/floating_head/floating_head_face.gdshader"
const DroneScript := preload("res://scripts/enemies/drone.gd")
const DRONE_TUNING_PATH: String = "res://data/enemies/drone.tres"
const TRUCK_TUNING_PATH: String = "res://data/enemies/enforcer_truck.tres"
## The run's effect numbers, for its blast's fireball (build_blast).
const SPEED_FX_PATH: String = "res://data/tuning/speed_fx.tres"
## The shots look like enemy fire in play (ProjectilePool's enemy bolt: its size, red and glow).
const BOLT_LOOK: StringName = &"enemy_bolt"
## The barricade: concrete blocks, and rails in the Enforcer's police paint (navy and white, never a hazard
## colour), with a cold-white floodlight at each end facing the street.
const CONCRETE := Color(0.4, 0.4, 0.43)
const RAIL_NAVY := Color(0.1, 0.13, 0.26)
const RAIL_WHITE := Color(0.82, 0.84, 0.88)
const LAMP_WHITE := Color(0.86, 0.91, 1.0)
const BLOCK_SIZE := Vector3(1.3, 0.85, 0.6)
## Dust and smoke: soft grey puffs (the fight's).
const DUST := Color(0.36, 0.35, 0.38)
const SMOKE := Color(0.22, 0.22, 0.25)

var shape: FloatingHeadModel.Shape
## The ship: `ship` at its face's belly (world space), `ship_xf` its pitch (FloatingHeadModel.ship_transform).
var ship: Node3D
var ship_xf: Node3D
var hull: MeshInstance3D
var screen: MeshInstance3D
var face: ShaderMaterial
var jaw: Node3D
var wrecked: bool = false
## Seconds since it crashed (its face falling flat).
var since_crash: float = 0.0
var side_street: Node3D
var barricade: MeshInstance3D
var turrets: Array[BarnacleTurretModel] = []
var truck: EnforcerTruckModel
var drone: Node3D
var drone_rotors: Array[MeshInstance3D] = []
var bolts: Array[MeshInstance3D] = []
## The pool its blast is drawn from (build_blast).
var fireballs: FireballPool

var _meshes: Dictionary = {}
var _belly_parts: Array[Node3D] = []
var _power_materials: Array[ShaderMaterial] = []
var _power: float = -1.0
var _face_from := Transform3D.IDENTITY
var _face_rest := Transform3D.IDENTITY
## Each bolt: [from, to, launch time, flight seconds].
var _bolt_paths: Array[Array] = []
var _drone_base := Vector3.ZERO


# --- The ship ------------------------------------------------------------------------------------

## Builds the ship for `stage`'s street (as wide as the fight's: FloatingHeadModel.shape_for).
func build_ship(stage: CineStage, boss_tuning: FloatingHeadTuning) -> void:
	var geo: TrackGeometry = stage.geo
	shape = FloatingHeadModel.shape_for(geo.wall_x() * 2.0, geo.lane_count, boss_tuning, geo.lane_width)
	_meshes = FloatingHeadModel.meshes(shape)
	ship = Node3D.new()
	ship.name = "Ship"
	add_child(ship)
	ship_xf = Node3D.new()
	ship_xf.name = "Pitch"
	ship.add_child(ship_xf)
	hull = MeshBatch.add_instance(ship_xf, _meshes["hull"], "Hull")
	screen = MeshBatch.add_instance(ship_xf, _meshes["screen"], "Screen", shape.screen_center)
	face = ShaderMaterial.new()
	face.shader = load(FACE_SHADER) as Shader
	face.set_shader_parameter(&"aspect", shape.screen_size.x / shape.screen_size.y)
	face.set_shader_parameter(&"anger", 1.0)
	screen.material_override = face
	jaw = Node3D.new()
	jaw.name = "Jaw"
	jaw.position = shape.jaw_hinge
	ship_xf.add_child(jaw)
	MeshBatch.add_instance(jaw, _meshes["jaw"])
	var lip: MeshInstance3D = MeshBatch.add_instance(jaw, _meshes["lip"], "Lip")
	lip.material_override = GreyboxMaterials.flat(Color(0.08, 0.08, 0.1))
	_belly_parts.append(jaw)
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "BayDoor"
		hinge.position = Vector3(side * shape.bay_half, -0.02, shape.bay_center.z)
		hinge.rotation.y = 0.0 if side < 0.0 else PI
		ship_xf.add_child(hinge)
		MeshBatch.add_instance(hinge, _meshes["door"])
		_belly_parts.append(hinge)
	for p: Vector3 in shape.weak_points:
		MeshBatch.add_instance(ship_xf, _meshes["cover"], "WeakPointCover", p)
	set_ship_power(1.0)


## Flies it: its face at track distance `face_at` (the street's middle), its belly `belly` up, nose down
## by `dive` (radians); `screen_power` and `glitch` drive its face (0-1).
func pose_ship(face_at: float, belly: float, dive: float, screen_power: float, glitch: float) -> void:
	ship.position = Vector3(0.0, belly, TrackGeometry.world_z(face_at))
	ship_xf.transform = FloatingHeadModel.ship_transform(shape, -dive, 0.0)
	face.set_shader_parameter(&"power", clampf(screen_power, 0.0, 1.0))
	face.set_shader_parameter(&"glitch", glitch)


## Its lights (every kit material on it but the face's): a smooth fade, never a flicker.
func set_ship_power(level: float) -> void:
	level = clampf(level, 0.0, 1.0)
	if is_equal_approx(level, _power):
		return
	if _power_materials.is_empty():
		for node: Node in ship_xf.find_children("*", "MeshInstance3D", true, false):
			var m := node as MeshInstance3D
			if m == screen or m.mesh == null or m.material_override != null:
				continue
			for i: int in m.mesh.get_surface_count():
				var mat := m.mesh.surface_get_material(i) as ShaderMaterial
				if mat != null:
					var copy := mat.duplicate() as ShaderMaterial
					m.set_surface_override_material(i, copy)
					_power_materials.append(copy)
	for mat: ShaderMaterial in _power_materials:
		mat.set_shader_parameter(&"state_glow", level)
	_power = level


## The crash (the fight's _crash): the hull becomes the wreck, sunk to `belly`, the parts that went with its
## bow are gone, and its face tears off and falls flat into the street before it (update_face), dead and
## cracked; a burst of dust along it and smoke rising from its torn ends.
func wreck_ship(face_at: float, belly: float) -> void:
	wrecked = true
	since_crash = 0.0
	pose_ship(face_at, belly, 0.0, 0.0, 0.0)
	hull.mesh = _meshes["wreck"]
	for i: int in hull.get_surface_override_material_count():
		hull.set_surface_override_material(i, null)
	_power_materials.clear()
	_power = -1.0
	set_ship_power(0.0)
	for part: Node3D in _belly_parts:
		part.visible = false
	face.set_shader_parameter(&"broken", 1.0)
	_face_from = screen.global_transform
	var sh: float = shape.screen_size.y
	var flat := Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0))
	_face_rest = Transform3D(Basis(Vector3.UP, deg_to_rad(4.0)) * flat,
		Vector3(0.0, 0.05, TrackGeometry.world_z(face_at - FloatingHead.FACE_GAP - sh * 0.5)))
	_face_frame()
	var length: float = FloatingHeadModel.WRECK_LENGTH * shape.length
	var dust: CPUParticles3D = _puffs("CrashDust", DUST, 3.0)
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = 32
	dust.lifetime = 1.8
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(shape.width * 0.5, 0.4, length * 0.6)
	dust.spread = 75.0
	dust.gravity = Vector3(0.0, -1.0, 0.0)
	dust.initial_velocity_min = 3.0
	dust.initial_velocity_max = 8.0
	dust.damping_min = 2.0
	dust.damping_max = 3.0
	dust.position = Vector3(0.0, -belly + 0.6, -length * 0.4)
	ship_xf.add_child(dust)
	dust.emitting = true
	for spot: Vector2 in [Vector2(-0.18, -1.5), Vector2(0.2, -length + 1.5)]:
		var smoke: CPUParticles3D = _puffs("Smoke", SMOKE, 2.2)
		smoke.amount = 16
		smoke.lifetime = 3.2
		smoke.spread = 14.0
		smoke.gravity = Vector3(0.0, 0.8, 0.0)
		smoke.initial_velocity_min = 1.0
		smoke.initial_velocity_max = 2.0
		smoke.position = Vector3(spot.x * shape.width, FloatingHeadModel.crown_height(shape, spot.x, spot.y), spot.y)
		ship_xf.add_child(smoke)
		smoke.emitting = true


## The torn-off face tips forward off the stern and falls flat into the street (the fight's timing).
func update_face(delta: float) -> void:
	if not wrecked:
		return
	since_crash += delta
	var k: float = minf(since_crash / FloatingHeadBody.FACE_FALL_SECONDS, 1.0)
	k *= k
	var turn: Quaternion = _face_from.basis.get_rotation_quaternion().slerp(_face_rest.basis.get_rotation_quaternion(), k)
	screen.global_transform = Transform3D(Basis(turn), _face_from.origin.lerp(_face_rest.origin, k))


## The fallen screen's bezel (FloatingHeadBody's): a raised rim, so it reads as a fallen screen.
func _face_frame() -> void:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(FloatingHeadModel.solid_material())
	var sw: float = shape.screen_size.x
	var sh: float = shape.screen_size.y
	var b: float = FloatingHeadModel.BEZEL_WIDTH
	var rim: Color = FloatingHeadModel.HULL_LIGHT.darkened(0.2)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.0, side * (sh + b) * 0.5, 0.02), Vector3(sw + b * 2.0, b, 0.12), rim)
		m.box(Vector3(side * (sw + b) * 0.5, 0.0, 0.02), Vector3(b, sh, 0.12), rim)
	batch.commit(screen, "FaceFrame")


# --- The roadblock -------------------------------------------------------------------------------

## Builds the roadblock in the opening of the left wall, the side street's middle at track distance `mid`.
## The side street's own space: x across it (+x is along the main street), -z into it from the main
## street's wall line, +z toward the main street.
func build_roadblock(stage: CineStage, f: CityOutroTuning, mid: float, visual_seed: int) -> void:
	var geo: TrackGeometry = stage.geo
	side_street = Node3D.new()
	side_street.name = "SideStreet"
	side_street.position = Vector3(-geo.wall_x(), 0.0, TrackGeometry.world_z(mid))
	side_street.rotation.y = PI * 0.5
	add_child(side_street)
	var width: float = side_width(f, geo)
	for i: int in f.side_lanes:
		var lx: float = (float(i) - (f.side_lanes - 1) * 0.5) * geo.lane_width
		var floor_parent := Node3D.new()
		floor_parent.name = "Floor%d" % i
		side_street.add_child(floor_parent)
		stage.skin.floor_segment(floor_parent, Vector3(lx, -TrackBuilder.FLOOR_THICKNESS * 0.5, -f.side_depth * 0.5),
			Vector3(geo.lane_width, TrackBuilder.FLOOR_THICKNESS, f.side_depth), lx, false, true)
	_fronts(side_street, stage.skin, width * 0.5 + f.side_margin - 0.03, f.side_depth)
	var slots: Array[float] = turret_slots(f, width)
	barricade = MeshBatch.add_instance(side_street, _barricade_mesh(width, slots, f.barricade_in), "Barricade")
	for i: int in slots.size():
		var holder := Node3D.new()
		holder.name = "Turret%d" % i
		holder.position = Vector3(slots[i], 0.0, -f.barricade_in)
		side_street.add_child(holder)
		var turret := BarnacleTurretModel.new()
		turret.rotation.z = PI  # Turned over: standing on the floor, its cannon toward the street.
		holder.add_child(turret)
		turret.build(stage.skin.enemy_variant, visual_seed + i)
		turret.set_emerged(1.0)
		turrets.append(turret)
	# DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 372): the Enforcer Truck; the hover truck is the one Zone 1 has shown.
	var truck_tuning := load(TRUCK_TUNING_PATH) as EnforcerTruckTuning
	truck = EnforcerTruckModel.new()
	truck.name = "Truck"
	truck.position = Vector3(0.0, 0.0, -f.truck_in)
	truck.rotation.y = PI  # Its front toward the street.
	side_street.add_child(truck)
	truck.build(stage.skin.enemy_variant, truck_tuning.body_size if truck_tuning != null else Vector3(2.2, 2.4, 6.4))
	truck.set_riders(f.truck_riders)
	truck.set_flash(-1, true)
	var drone_tuning := load(DRONE_TUNING_PATH) as DroneTuning
	drone = Node3D.new()
	drone.name = "Drone"
	_drone_base = Vector3(0.0, f.drone_height, -f.truck_in - 2.0)
	drone.position = _drone_base
	side_street.add_child(drone)
	var parts: Dictionary = DroneScript.add_model(drone, stage.skin.enemy_variant,
		drone_tuning.model_scale if drone_tuning != null else 1.35)
	drone_rotors.assign(parts["rotors"])


## The opening in the right wall the runner leaps out of, its middle at track distance `mid` and `half` long
## each way: lined with the zone's building fronts out over the drop, so it reads as a gap between towers.
func build_opening(stage: CineStage, f: CityOutroTuning, mid: float, half: float) -> void:
	var opening := Node3D.new()
	opening.name = "Opening"
	opening.position = Vector3(stage.geo.wall_x(), 0.0, TrackGeometry.world_z(mid))
	opening.rotation.y = -PI * 0.5  # Its -z leads out of the street to the right.
	add_child(opening)
	_fronts(opening, stage.skin, half - 0.03, f.opening_depth)


## The zone's own building fronts (ZoneSkin.wall_section) along both sides of an opening off the street, in
## `parent`'s space (its -z leading out of the street), `half` either side of its middle, `depth` long: they
## close the cut walls' dark ends as a level's street never needs to.
static func _fronts(parent: Node3D, skin: ZoneSkin, half: float, depth: float) -> void:
	var none: Array[Vector2] = []
	for side: int in [-1, 1]:
		var holder := Node3D.new()
		holder.name = "FrontLeft" if side < 0 else "FrontRight"
		parent.add_child(holder)
		skin.note_wall_gaps(side, none)
		skin.wall_section(holder, side, side * half, 0.0, depth)


## The side street's width: its lanes.
static func side_width(f: CityOutroTuning, geo: TrackGeometry) -> float:
	return f.side_lanes * geo.lane_width


## Where the turrets stand across the side street (its x): spread evenly, clear of its edges.
static func turret_slots(f: CityOutroTuning, width: float) -> Array[float]:
	var out: Array[float] = []
	for i: int in f.turrets:
		out.append(((float(i) + 0.5) / f.turrets - 0.5) * (width - 1.2))
	return out


## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 371): the barricade across the side street at `depth` in,
## concrete blocks between the turrets' places, police rails on the blocks, and a floodlight on a post at each
## end, facing the street.
static func _barricade_mesh(width: float, slots: Array[float], depth: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(MeshKit.solid())
	var half: float = width * 0.5
	var gap: float = BarnacleTurretModel.COLLAR_RADIUS * 2.0 + 0.2
	var edges: Array[float] = [-half]
	for x: float in slots:
		edges.append(x - gap * 0.5)
		edges.append(x + gap * 0.5)
	edges.append(half)
	for i: int in range(0, edges.size(), 2):
		var a: float = edges[i]
		var b: float = edges[i + 1]
		var x: float = a
		var n: int = 0
		while x < b - 0.3:
			var w: float = minf(BLOCK_SIZE.x, b - x)
			var cx: float = x + w * 0.5
			var z: float = -depth + (0.06 if n % 2 == 0 else -0.06)
			m.box(Vector3(cx, BLOCK_SIZE.y * 0.5, z), Vector3(w - 0.05, BLOCK_SIZE.y, BLOCK_SIZE.z), CONCRETE, 0.0,
				MeshKit.PAT_CONCRETE)
			var rail: Color = RAIL_NAVY if n % 2 == 0 else RAIL_WHITE
			m.box(Vector3(cx, BLOCK_SIZE.y + 0.18, z), Vector3(w - 0.1, 0.22, 0.08), rail)
			x += w
			n += 1
	for side: float in [-1.0, 1.0]:
		var px: float = side * (half - 0.25)
		m.box(Vector3(px, 1.5, -depth - 0.35), Vector3(0.1, 3.0, 0.1), Color(0.16, 0.16, 0.19))
		m.box(Vector3(px, 3.0, -depth - 0.3), Vector3(0.5, 0.3, 0.25), Color(0.16, 0.16, 0.19))
		m.box(Vector3(px, 3.0, -depth - 0.17), Vector3(0.42, 0.22, 0.02), LAMP_WHITE, 1.0)
	return batch.to_mesh()


## The roadblock at time `t` (`delta` since the last step): the light bar alternates once the siren starts
## (steady with Reduced flashing), the drone bobs and its rotors spin, the turrets watch `target` (the
## runner, world space) and glow red as they charge (`charge` 0-1).
func update_roadblock(t: float, delta: float, siren: bool, rate: float, target: Vector3, charge: float) -> void:
	if truck != null:
		truck.set_flash(int(floorf(t * rate * 2.0)) % 2 if siren else -1, Settings.flashing_reduced or not siren)
	if drone != null:
		drone.position = _drone_base + Vector3(0.0, 0.12 * sin(t * 2.1), 0.0)
		drone.rotation.z = 0.05 * sin(t * 1.3)
		for i: int in drone_rotors.size():
			drone_rotors[i].rotate_y((30.0 if i == 0 else -30.0) * delta)
	for turret: BarnacleTurretModel in turrets:
		turret.watch(target)
		turret.set_charge(charge)


# --- The shots and the blast ---------------------------------------------------------------------

## Fires a bolt (enemy-fire red) from `from` to `to` (world space), launched at `launch` and landing
## `seconds` later.
func add_bolt(from: Vector3, to: Vector3, launch: float, seconds: float) -> void:
	var bolt := MeshInstance3D.new()
	bolt.name = "Bolt%d" % bolts.size()
	var look: Dictionary = ProjectilePool.LOOKS[BOLT_LOOK]
	bolt.mesh = GreyboxMaterials.unit_box()
	bolt.material_override = GreyboxMaterials.glow(look["color"], look["energy"])
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.visible = false
	add_child(bolt)
	bolts.append(bolt)
	_bolt_paths.append([from, to, launch, maxf(seconds, 0.05)])


## The bolts at time `t`: each in flight between its launch and its landing, a streak along its way.
func update_bolts(t: float) -> void:
	for i: int in bolts.size():
		var path: Array = _bolt_paths[i]
		var u: float = (t - float(path[2])) / float(path[3])
		var bolt: MeshInstance3D = bolts[i]
		bolt.visible = u >= 0.0 and u < 1.0
		if not bolt.visible:
			continue
		var from: Vector3 = path[0]
		var to: Vector3 = path[1]
		var at: Vector3 = from.lerp(to, u)
		var dir: Vector3 = (to - from).normalized()
		var up: Vector3 = Vector3.UP if absf(dir.y) < 0.98 else Vector3.BACK
		# Stretched along its own way (scaled_local), as a bolt in play.
		var size: Vector3 = ProjectilePool.LOOKS[BOLT_LOOK]["size"]
		bolt.global_transform = Transform3D(Basis.looking_at(dir, up).scaled_local(size), at)


## Builds the pool its blast is drawn from (FireballPool, with the run's numbers, SPEED_FX_PATH, and one slot: the
## outro's only explosion), with the props, so nothing is built mid-scene.
func build_blast() -> void:
	if fireballs != null:
		return
	var fx: SpeedFxTuning = load(SPEED_FX_PATH) as SpeedFxTuning if ResourceLoader.exists(SPEED_FX_PATH) else null
	var own: SpeedFxTuning = fx.duplicate() as SpeedFxTuning if fx != null else SpeedFxTuning.new()
	own.fireball_pool = 1
	fireballs = FireballPool.new()
	fireballs.name = "Fireballs"
	add_child(fireballs)
	fireballs.setup(own)


## Sets off the blast at `at` (world space): a shared fireball `radius` metres in radius, its fire burning about
## `seconds` (FireballPool.play's pace), with its smoke after it. DESIGN-TBD (docs/OPEN_QUESTIONS.md item 670).
func start_blast(at: Vector3, radius: float, seconds: float) -> void:
	build_blast()
	fireballs.play(at, radius, true, fireballs.tuning.fireball_seconds / maxf(seconds, 0.05))


## Takes the City's props out of view (the scene has cut to another place).
func hide_city() -> void:
	for child: Node in get_children():
		if child is Node3D:
			(child as Node3D).visible = false


## Draw calls the props make now (visible meshes, one per surface): what they add to a frame.
func draw_call_count() -> int:
	var n: int = 0
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh != null and mi.is_visible_in_tree():
			n += mi.mesh.get_surface_count()
	return n


# --- Dust and smoke ------------------------------------------------------------------------------

## Soft round puffs (grey, fading in and out and growing as they go), the fight's dust and smoke. CPU
## particles, so the Compatibility renderer draws them too.
func _puffs(node_name: String, tint: Color, size: float) -> CPUParticles3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = tint
	mat.albedo_texture = _puff_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.15, Color(1.0, 1.0, 1.0, 0.7))
	fade.add_point(0.6, Color(1.0, 1.0, 1.0, 0.4))
	var grow := Curve.new()
	grow.max_value = 3.0
	grow.add_point(Vector2(0.0, 0.6))
	grow.add_point(Vector2(1.0, 2.6))
	var p := CPUParticles3D.new()
	p.name = node_name
	p.emitting = false
	p.mesh = quad
	p.randomness = 0.4
	p.local_coords = false
	p.direction = Vector3.UP
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.6
	p.scale_amount_curve = grow
	p.color_ramp = fade
	return p


static func _puff_texture() -> Texture2D:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	ramp.add_point(0.45, Color(1.0, 1.0, 1.0, 0.6))
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	return tex
