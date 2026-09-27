class_name FloatingHeadBody
extends BossPart
## The Floating Head's ship (GDD §10), the fight's body: the hull and face (FloatingHeadModel), and
## the parts that move: the face screen (its eyes glowing red as they charge a laser: eye_charge), the
## jaw (it opens for the cyborg drop: jaw_open), the searchlight on its gimbal, the bomb-bay doors, the
## weak points' covers, and a glow its lift pads throw on the street below. The encounter
## (FloatingHead) flies it and says what each part does; this draws it.
## Hitboxes: the hull is solid (a boss's body: claws never defeat it, the dash passes through), out of
## reach while it flies. Three weak points on its crown and the crown's top (a surface to stand on)
## stay off until it's pinned (task E1c). Weapons aim at its face.

const FACE_SHADER: String = "res://scripts/bosses/floating_head/floating_head_face.gdshader"
## The searchlight's lens: off, sweeping (cold white) or lingering (enemy-attack red).
enum Lamp { OFF, SWEEP, LOCK }
const LENS_WHITE := Color(0.85, 0.92, 1.0)
const LENS_RED := Color(1.0, 0.16, 0.1)
## The face's cold white (the cult's screens): its lip line lights up with the face.
const FACE_WHITE := Color(0.86, 0.91, 1.0)

var tuning: FloatingHeadTuning
var shape: FloatingHeadModel.Shape
## The face screen powering on (0 off, 1 the face) and its expression (FloatingHead drives these).
var screen_power: float = 0.0
var anger: float = 0.35
var eye_charge: float = 0.0
var glitch: float = 0.0
var lamp: Lamp = Lamp.OFF
## Where the searchlight points (world space) while it's on.
var lamp_target := Vector3.ZERO
var bay_open: bool = false
## The mouth: 0 shut, 1 open (the cyborg drop).
var jaw_open: float = 0.0
## Where the face looks (world space) instead of at the runner, while look_override is on (the eye
## lasers' aim).
var look_point := Vector3.ZERO
var look_override: bool = false

var _ship: Node3D
var _screen: MeshInstance3D
var _screen_material: ShaderMaterial
var _jaw: Node3D
var _lip: MeshInstance3D
var _lamp_head: Node3D
var _lens: MeshInstance3D
var _doors: Array[Node3D] = []
var _covers: Array[MeshInstance3D] = []
var _domes: Array[MeshInstance3D] = []
var _hull_box: Hazard
var _top: StaticBody3D
var _floor_glow: MeshInstance3D
var _floor_glow_material: ShaderMaterial
var _door_open: float = 0.0
var _look := Vector2.ZERO
var _time: float = 0.0


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as FloatingHeadTuning
	if tuning == null:
		tuning = FloatingHeadTuning.new()
	# GDD §9: big attacks take turns (EnemyDirector.major_attack_blocked): other enemies hold theirs
	# while its lasers or a bomb's warning are on.
	exclusive_major_attack = true
	shape = FloatingHeadModel.shape_for(world.geo.wall_x() * 2.0, world.geo.lane_count, tuning)
	var meshes: Dictionary = FloatingHeadModel.meshes(shape)
	_ship = Node3D.new()
	_ship.name = "Ship"
	add_child(_ship)
	MeshBatch.add_instance(_ship, meshes["hull"], "Hull")
	_screen = MeshBatch.add_instance(_ship, meshes["screen"], "Screen", shape.screen_center)
	_screen_material = ShaderMaterial.new()
	_screen_material.shader = load(FACE_SHADER) as Shader
	_screen_material.set_shader_parameter(&"aspect", shape.screen_size.x / shape.screen_size.y)
	_screen.material_override = _screen_material
	_jaw = Node3D.new()
	_jaw.name = "Jaw"
	_jaw.position = shape.jaw_hinge
	_ship.add_child(_jaw)
	MeshBatch.add_instance(_jaw, meshes["jaw"])
	_lip = MeshBatch.add_instance(_jaw, meshes["lip"], "Lip")
	_lamp_head = Node3D.new()
	_lamp_head.name = "Searchlight"
	_lamp_head.position = shape.lamp_pivot
	_ship.add_child(_lamp_head)
	MeshBatch.add_instance(_lamp_head, meshes["lamp"])
	_lens = MeshBatch.add_instance(_lamp_head, meshes["lens"], "Lens")
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "BayDoor"
		hinge.position = Vector3(side * shape.bay_half, -0.02, shape.bay_center.z)
		hinge.rotation.y = 0.0 if side < 0.0 else PI
		_ship.add_child(hinge)
		MeshBatch.add_instance(hinge, meshes["door"])
		_doors.append(hinge)
	for p: Vector3 in shape.weak_points:
		_covers.append(MeshBatch.add_instance(_ship, meshes["cover"], "WeakPointCover", p))
		var dome: MeshInstance3D = MeshBatch.add_instance(_ship, meshes["weak"], "WeakPoint", p)
		dome.visible = false
		_domes.append(dome)
		add_weak_point(Vector3(1.5, 0.6, 1.5), p + Vector3(0.0, 0.3, 0.0), _ship)
	set_weak_points_enabled(false)
	# The hull: solid, like any enemy's body. The crown's top: a surface to land on once it's pinned.
	_hull_box = add_hitbox(&"body", Vector3(shape.width * 0.9, shape.height * 0.88, shape.length * 0.85),
		Vector3(0.0, shape.height * 0.5, -shape.length * 0.425), false, _ship)
	_hull_box.hazard_name = "Floating Head"
	_top = add_surface(shape.top_size, shape.top_center, false, _ship)
	set_top_solid(false)
	_build_floor_glow()
	_update_lens()
	_lip.material_override = GreyboxMaterials.flat(Color(0.08, 0.08, 0.1))


## Flies it to `pos` (the stern's belly, world space), nose up by `pitch` and banked by `roll`.
func set_pose(pos: Vector3, pitch: float = 0.0, roll: float = 0.0) -> void:
	position = pos
	_ship.rotation = Vector3(pitch, 0.0, roll)


## The crown's top as a floor surface (it's out of reach until it's pinned, task E1c).
func set_top_solid(on: bool) -> void:
	_top.collision_layer = TrackBuilder.LAYER_FLOOR if on else 0


func top_solid() -> bool:
	return _top.collision_layer != 0


## How high the crown's top surface is (world, at its middle): where E1c's runner lands on its head.
func top_height() -> float:
	return (_top.global_transform * Vector3(0.0, shape.top_size.y * 0.5, 0.0)).y


## The searchlight's lens (world space), where its beam starts.
func lamp_world() -> Vector3:
	return _lens.global_position if is_inside_tree() else global_position


## Where bombs drop from: the middle of the bomb bay (world space).
func bay_world() -> Vector3:
	return _ship.to_global(shape.bay_center + Vector3(0.0, -0.3, 0.0))


## The face screen's centre (world space).
func screen_world() -> Vector3:
	return _screen.global_position


## One of the face's eyes (world space; `side` -1 is the viewer's left): where its laser starts. The
## face shader draws the eyes at ±0.26 and 0.02 screen heights from the screen's centre.
func eye_world(side: int) -> Vector3:
	var sh: float = shape.screen_size.y
	return _ship.to_global(shape.screen_center + Vector3(side * 0.26 * sh, 0.02 * sh, 0.05))


## The mouth's opening (world space): where the dropped cyborgs come out.
func mouth_world() -> Vector3:
	return _ship.to_global(Vector3(0.0, (shape.mouth_bottom + shape.mouth_top) * 0.5, shape.mouth_front + 0.4))


## GDD §9 (big attacks take turns): its lasers and its bombs' warnings are a major attack.
func is_major_attack_active() -> bool:
	var head := encounter as FloatingHead
	if head == null or not is_instance_valid(head):
		return false
	return (head.faceoff != null and head.faceoff.lasering()) or (head.bombing != null and not head.bombing.target.is_empty())


## The face screen's material (tests and reviews read its state).
func screen_material() -> ShaderMaterial:
	return _screen_material


func aim_point() -> Vector3:
	return screen_world() if _screen != null and is_inside_tree() else global_position


func hit_radius() -> float:
	return minf(shape.screen_size.x, shape.screen_size.y) * 0.5 + 1.2


## Every mesh instance it draws with, for budget checks: {instances, surfaces, vertices} of the visible ones.
func draw_stats() -> Dictionary:
	var out := {"instances": 0, "surfaces": 0, "vertices": 0}
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		out["instances"] += 1
		out["surfaces"] += m.mesh.get_surface_count()
		for s: int in m.mesh.get_surface_count():
			out["vertices"] += (m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return out


func _tick(delta: float) -> void:
	_time += delta
	# The face: it watches the runner (its pupils follow them), or its lasers' aim, blinking now and then.
	var watched: Vector3 = look_point if look_override else world.player.global_position + Vector3(0.0, 0.8, 0.0)
	var eye: Vector3 = _ship.to_local(watched) - shape.screen_center
	var want := Vector2(clampf(eye.x / 7.0, -1.0, 1.0), clampf(eye.y / 10.0, -1.0, 1.0))
	_look = _look.lerp(want, 1.0 - exp(-5.0 * delta))
	var blink: float = clampf(1.0 - absf(fmod(_time, 4.7) - 0.09) / 0.09, 0.0, 1.0)
	_screen_material.set_shader_parameter(&"power", clampf(screen_power, 0.0, 1.0))
	_screen_material.set_shader_parameter(&"look", _look)
	_screen_material.set_shader_parameter(&"anger", anger)
	_screen_material.set_shader_parameter(&"blink", blink if screen_power >= 1.0 else 0.0)
	_screen_material.set_shader_parameter(&"eye_charge", eye_charge)
	_screen_material.set_shader_parameter(&"glitch", glitch)
	# The searchlight turns on its gimbal toward its target; at rest it points down under the chin.
	var aim: Vector3 = lamp_target if lamp != Lamp.OFF else _ship.to_global(shape.lamp_pivot + Vector3(0.0, -4.0, 1.5))
	var dir: Vector3 = aim - _lamp_head.global_position
	if dir.length() > 0.1:
		var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.BACK
		_lamp_head.look_at(aim, up)
	_update_lens()
	# The mouth's lip line lights up with the face.
	_lip.material_override = GreyboxMaterials.glow(FACE_WHITE, 2.6) if screen_power >= 0.75 \
		else GreyboxMaterials.flat(Color(0.08, 0.08, 0.1))
	# The bomb-bay doors swing open for a run.
	_door_open = move_toward(_door_open, 1.0 if bay_open else 0.0, delta * 2.5)
	for i: int in _doors.size():
		_doors[i].rotation.z = -deg_to_rad(80.0) * smoothstep(0.0, 1.0, _door_open)
	# The jaw swings down and out (its bottom toward the runner) to open the mouth.
	_jaw.rotation.x = -deg_to_rad(62.0) * smoothstep(0.0, 1.0, clampf(jaw_open, 0.0, 1.0))
	# The lift pads' glow on the street below, brighter the lower it flies (none once it's down).
	var height: float = global_position.y
	_floor_glow.visible = height > 0.5
	_floor_glow.position = Vector3(0.0, 0.04 - height, -shape.length * 0.5)
	_floor_glow_material.set_shader_parameter(&"state_glow", clampf((16.0 - height) / 12.0, 0.0, 1.0))


func _update_lens() -> void:
	match lamp:
		Lamp.OFF:
			_lens.material_override = GreyboxMaterials.flat(Color(0.12, 0.13, 0.16))
		Lamp.SWEEP:
			_lens.material_override = GreyboxMaterials.glow(LENS_WHITE, 4.0)
		Lamp.LOCK:
			_lens.material_override = GreyboxMaterials.glow(LENS_RED, 4.0)


func _build_floor_glow() -> void:
	var batch := MeshBatch.new()
	_floor_glow_material = FloatingHeadModel.glow_material().duplicate() as ShaderMaterial
	var g: MeshLayer = batch.layer(_floor_glow_material)
	var hw: float = shape.width * 0.62
	var hl: float = shape.length * 0.55
	g.rect(Vector3(-hw, 0.0, -hl), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, hl * 2.0), FloatingHeadModel.ENGINE, 0.45,
		MeshKit.SHAPE_RADIAL)
	_floor_glow = batch.commit(self, "FloorGlow")


## The fight is won (GDD §10's defeat, its crash into the street, is task E1d): for now it bursts.
func _on_defeated(_cause: StringName) -> void:
	world.play_sfx_at(&"truck_explode", screen_world())
	world.effects.burst(screen_world(), FloatingHeadModel.LIGHT, 64, 1.6)
	world.effects.burst(global_position + Vector3(0.0, shape.height * 0.3, -3.0), Color(1.0, 0.4, 0.15), 64, 1.8)
	world.effects.shake(0.5, 0.6)
	queue_free()
