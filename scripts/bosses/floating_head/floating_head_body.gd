class_name FloatingHeadBody
extends BossPart
## The Floating Head's ship (GDD §10), the fight's body: the hull and face (FloatingHeadModel), and
## the parts that move: the face screen (its eyes glowing red as they charge a laser: eye_charge), the
## jaw (it opens for the cyborg drop: jaw_open), the searchlight on its gimbal, the bomb-bay doors, the
## weak points' covers (they swing open and the red domes rise out, pulsing, for a stomp window:
## weak_open), and a glow its lift pads throw on the street below. The encounter (FloatingHead) flies it
## and says what each part does; this draws it.
## Hitboxes: the hull is solid (a boss's body: claws never defeat it, the dash passes through), out of
## reach while it flies and off while it's pinned (set_hull_solid: the pinned ship is the floor of the
## ways onto its head). A weak point over each lane near the crown's middle (a generous stomp box over
## each red dome) and the crown's deck (a surface to stand on, exactly where the hull is drawn) stay off
## until a stomp window opens (set_weak_points_enabled, set_top_solid). Weapons aim at its face.
## Its propaganda's slogans show on a caption band across the bottom of its face screen (show_slogan:
## a Label3D in the face's cold white; FloatingHeadVoice says when). Beaten, it stays: the encounter
## plays its defeat (FloatingHead): its power dies (power: its lights, pads and trim fade), and after
## the crash it's a wreck (wreck(): its fins and masts broken off, its crown's deck a floor the runner
## runs across); no hitbox of it is live any more.

const FACE_SHADER: String = "res://scripts/bosses/floating_head/floating_head_face.gdshader"
## The searchlight's lens: off, sweeping (cold white) or lingering (enemy-attack red).
enum Lamp { OFF, SWEEP, LOCK }
const LENS_WHITE := Color(0.85, 0.92, 1.0)
const LENS_RED := Color(1.0, 0.16, 0.1)
## The face's cold white (the cult's screens): its lip line lights up with the face.
const FACE_WHITE := Color(0.86, 0.91, 1.0)
## A weak point's stomp box starts this far under its socket's top (and reaches stomp_top above it).
const STOMP_BELOW: float = 0.2
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 160): opening, a cover swings back this far about
## its back edge (lying back on the crown behind its socket) and the red dome rises out of the socket.
const COVER_OPEN_DEGREES: float = 150.0
const DOME_SUNK: float = 0.45
## The open domes pulse this fast, between these glows (a steady glow with Reduced flashing).
const PULSE_HZ: float = 1.4
const PULSE_LOW: float = 0.85
const PULSE_HIGH: float = 1.45
## The slogans' font (the UI's display face) and how bright they glow (above the bloom threshold, like
## the face's lines).
const CAPTION_FONT: String = "res://assets/fonts/orbitron/Orbitron[wght].ttf"
const CAPTION_WEIGHT: int = 800
const CAPTION_GLOW: float = 2.2
## The caption band: from the screen's bottom edge up to this share of its height below its centre
## (under the eyes, which carry the lasers' warning, and above the mouth, the cyborg drop's), its text
## at most this share of the screen's width and of a line's height.
const CAPTION_TOP: float = -0.17
const CAPTION_WIDTH: float = 0.88
const CAPTION_LINE: float = 0.125
## Sizes the caption's glyphs are drawn at (then scaled to fit the band).
const CAPTION_FONT_SIZE: int = 96
## The wreck's torn-off face falls flat into the street this fast.
const FACE_FALL_SECONDS: float = 0.4

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
## The weak points' covers: 0 shut, 1 swung open with the red domes out (a stomp window).
var weak_open: float = 0.0
## The ship's power, 1 (running) to 0 (dead, its defeat): its lights, trim, lift pads and their glow on
## the street fade with it (the face screen has its own, screen_power).
var power: float = 1.0
## The slogan on the face screen's caption band ("" for none), and how much of it shows (0-1: the band
## and its text fade in and out together).
var slogan: String = ""
var caption: float = 0.0

var _ship: Node3D
var _hull: MeshInstance3D
var _screen: MeshInstance3D
var _screen_material: ShaderMaterial
var _jaw: Node3D
var _lip: MeshInstance3D
var _lamp_head: Node3D
var _lens: MeshInstance3D
var _doors: Array[Node3D] = []
var _covers: Array[MeshInstance3D] = []
var _domes: Array[MeshInstance3D] = []
var _dome_material: ShaderMaterial
var _hull_box: Hazard
var _deck: StaticBody3D
var _floor_glow: MeshInstance3D
var _floor_glow_material: ShaderMaterial
## The mouth's inside, lit up while it's open.
var _mouth_glow: MeshInstance3D
var _mouth_material: StandardMaterial3D
var _door_open: float = 0.0
var _look := Vector2.ZERO
var _time: float = 0.0
## Per-instance copies of its parts' kit materials, whose state_glow follows `power` (made the first
## time the power drops), and the power they show.
var _power_materials: Array[ShaderMaterial] = []
var _power_shown: float = 1.0
var _caption_label: Label3D
var _caption_text: String = ""
var _wrecked: bool = false
## Its torn-off face falling into the street (the wreck): from, to (world space), and how far (0-1).
var _face_from := Transform3D.IDENTITY
var _face_rest := Transform3D.IDENTITY
var _face_fall: float = 1.0


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as FloatingHeadTuning
	if tuning == null:
		tuning = FloatingHeadTuning.new()
	# GDD §9: big attacks take turns (EnemyDirector.major_attack_blocked): other enemies hold theirs
	# while its lasers or a bomb's warning are on.
	exclusive_major_attack = true
	shape = FloatingHeadModel.shape_for(world.geo.wall_x() * 2.0, world.geo.lane_count, tuning, world.geo.lane_width)
	var meshes: Dictionary = FloatingHeadModel.meshes(shape)
	_ship = Node3D.new()
	_ship.name = "Ship"
	add_child(_ship)
	_hull = MeshBatch.add_instance(_ship, meshes["hull"], "Hull")
	_screen = MeshBatch.add_instance(_ship, meshes["screen"], "Screen", shape.screen_center)
	_screen_material = ShaderMaterial.new()
	_screen_material.shader = load(FACE_SHADER) as Shader
	_screen_material.set_shader_parameter(&"aspect", shape.screen_size.x / shape.screen_size.y)
	_screen_material.set_shader_parameter(&"caption_top", CAPTION_TOP)
	_screen.material_override = _screen_material
	_build_caption()
	_jaw = Node3D.new()
	_jaw.name = "Jaw"
	_jaw.position = shape.jaw_hinge
	_ship.add_child(_jaw)
	MeshBatch.add_instance(_jaw, meshes["jaw"])
	_lip = MeshBatch.add_instance(_jaw, meshes["lip"], "Lip")
	# The mouth's inside lights up in the face's cold white as the jaw drops open (the cyborg drop's
	# warning).
	_mouth_material = StandardMaterial3D.new()
	_mouth_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mouth_material.emission_enabled = true
	_mouth_material.emission = FACE_WHITE
	var quad := QuadMesh.new()
	quad.size = Vector2(shape.mouth_half * 2.0, shape.mouth_top - shape.mouth_bottom)
	_mouth_glow = MeshInstance3D.new()
	_mouth_glow.name = "MouthGlow"
	_mouth_glow.mesh = quad
	_mouth_glow.material_override = _mouth_material
	_mouth_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mouth_glow.position = Vector3(0.0, (shape.mouth_bottom + shape.mouth_top) * 0.5, 0.08)
	_mouth_glow.visible = false
	_ship.add_child(_mouth_glow)
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
	# The weak points: red domes (their own material, so they can pulse) under armoured covers, and a
	# generous stomp box over each: the dome and some room around it, from just under the socket's top to
	# stomp_top above it.
	_dome_material = FloatingHeadModel.solid_material().duplicate() as ShaderMaterial
	var stomp_height: float = tuning.stomp_top + STOMP_BELOW
	for p: Vector3 in shape.weak_points:
		_covers.append(MeshBatch.add_instance(_ship, meshes["cover"], "WeakPointCover", p))
		var dome: MeshInstance3D = MeshBatch.add_instance(_ship, meshes["weak"], "WeakPoint", p)
		dome.material_override = _dome_material
		dome.visible = false
		_domes.append(dome)
		add_weak_point(Vector3(tuning.stomp_width, stomp_height, tuning.stomp_depth),
			p + Vector3(0.0, stomp_height * 0.5 - STOMP_BELOW, 0.0), _ship)
	set_weak_points_enabled(false)
	# The hull: solid, like any enemy's body. The crown's deck: a surface to land on once it's pinned.
	_hull_box = add_hitbox(&"body", Vector3(shape.width * 0.9, shape.height * 0.88, shape.length * 0.85),
		Vector3(0.0, shape.height * 0.5, -shape.length * 0.425), false, _ship)
	_hull_box.hazard_name = "Floating Head"
	_deck = _build_deck()
	set_top_solid(false)
	_build_floor_glow()
	_update_lens()
	_lip.material_override = GreyboxMaterials.flat(Color(0.08, 0.08, 0.1))


## Flies it to `pos` (the stern's belly, world space), nose up by `pitch` and banked by `roll` about its
## crown over the weak points (FloatingHeadModel.ship_transform).
func set_pose(pos: Vector3, pitch: float = 0.0, roll: float = 0.0) -> void:
	position = pos
	_ship.transform = FloatingHeadModel.ship_transform(shape, pitch, roll)


## The crown's deck as a floor surface: out of reach in flight, on while a stomp window is open (and
## while it shakes free with the runner still on it).
func set_top_solid(on: bool) -> void:
	_deck.collision_layer = TrackBuilder.LAYER_FLOOR if on else 0


func top_solid() -> bool:
	return _deck.collision_layer != 0


## The hull's solid hitbox on or off: off while it's pinned and shaking free, when the pinned ship is
## the floor of the ways onto its head (the window closes before the runner can reach its face).
func set_hull_solid(on: bool) -> void:
	_hull_box.set_enabled(on)


func hull_solid() -> bool:
	return _hull_box.is_active()


## How high the crown is (world) on its centre line over the weak points.
func top_height() -> float:
	return _ship.to_global(shape.roll_pivot + Vector3(0.0, 0.0, FloatingHeadModel.WEAK_Z)).y


## Where weak point `i`'s socket top is (world space).
func weak_point_world(i: int) -> Vector3:
	return _ship.to_global(shape.weak_points[i])


## The ship's space to world, as it is now.
func ship_global() -> Transform3D:
	return _ship.global_transform


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


## Beaten, it keeps drawing itself (the encounter flies it through its defeat); Enemy stops ticking a
## defeated enemy.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not alive and world != null:
		_animate(delta)


func _tick(delta: float) -> void:
	_animate(delta)


## The fight is won: the encounter plays the defeat (FloatingHead: the glitch, the fall, the crash and
## the wreck), so the body stays; its hitboxes are already off (Enemy.defeat).
func _on_defeated(_cause: StringName) -> void:
	pass


## The crash (the defeat): the hull becomes the wreck (FloatingHeadModel's: its stern half, torn open at
## both ends), its face tears off and falls flat into the street before it (to `face_rest`, world space,
## over FACE_FALL_SECONDS: the dead screen, cracked, the face faintly burnt into it), and the parts that
## went with its face and bow (the jaw, the searchlight, the bay doors) are gone. No deck: the lanes run
## through it on the roofs.
func wreck(face_rest: Transform3D) -> void:
	_wrecked = true
	_hull.mesh = FloatingHeadModel.meshes(shape)["wreck"]
	# The new mesh's surfaces take dimmed copies of their materials again.
	_power_materials.clear()
	_power_shown = -1.0
	weak_open = 0.0
	lamp = Lamp.OFF
	jaw_open = 0.0
	bay_open = false
	_jaw.visible = false
	_lamp_head.visible = false
	for door: Node3D in _doors:
		door.visible = false
	set_top_solid(false)
	slogan = ""
	caption = 0.0
	_face_from = _screen.global_transform
	_face_rest = face_rest
	_face_fall = 0.0
	_screen_material.set_shader_parameter(&"broken", 1.0)
	_build_face_frame()


## The torn-off face's frame: its bezel, torn out of the stern with it (a raised rim round the dead
## glass, so it reads as a fallen screen and not a hole in the street).
func _build_face_frame() -> void:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(FloatingHeadModel.solid_material())
	var sw: float = shape.screen_size.x
	var sh: float = shape.screen_size.y
	var b: float = FloatingHeadModel.BEZEL_WIDTH
	var rim: Color = FloatingHeadModel.HULL_LIGHT.darkened(0.2)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.0, side * (sh + b) * 0.5, 0.02), Vector3(sw + b * 2.0, b, 0.12), rim)
		m.box(Vector3(side * (sw + b) * 0.5, 0.0, 0.02), Vector3(b, sh, 0.12), rim)
	batch.commit(_screen, "FaceFrame")


func is_wreck() -> bool:
	return _wrecked


## Where its face screen is now (world space; on the wreck, where it fell).
func face_transform() -> Transform3D:
	return _screen.global_transform


## Dark smoke rising from the wreck's crown near both its torn ends (soft grey puffs, never a glow).
## CPU particles, so the Compatibility renderer draws them too.
func start_smoke(length: float) -> void:
	for spot: Vector2 in [Vector2(-0.18, -1.5), Vector2(0.2, -length + 1.5)]:
		var z: float = spot.y
		var p: CPUParticles3D = _puffs("Smoke", Color(0.22, 0.22, 0.25), 2.2)
		p.amount = 16
		p.lifetime = 3.2
		p.spread = 14.0
		p.gravity = Vector3(0.0, 0.8, 0.0)
		p.initial_velocity_min = 1.0
		p.initial_velocity_max = 2.0
		p.position = Vector3(spot.x * shape.width, FloatingHeadModel.crown_height(shape, spot.x, z), z)
		p.emitting = true
		_ship.add_child(p)


## The crash's dust (the defeat): a cloud of soft grey puffs bursting out along the wreck, `length`
## long, from the roofs `floor_height` up its hull (a one-shot, no flash).
func crash_dust(length: float, floor_height: float) -> void:
	var p: CPUParticles3D = _puffs("CrashDust", Color(0.36, 0.35, 0.38), 3.0)
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 32
	p.lifetime = 1.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(shape.width * 0.5, 0.4, length * 0.6)
	p.spread = 75.0
	p.gravity = Vector3(0.0, -1.0, 0.0)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.position = Vector3(0.0, floor_height + 0.6, -length * 0.4)
	p.emitting = true
	_ship.add_child(p)


## Soft round puffs (grey, fading in and out and growing as they go): the wreck's smoke and dust.
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
	p.mesh = quad
	p.randomness = 0.4
	p.local_coords = false
	p.direction = Vector3.UP
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.6
	p.scale_amount_curve = grow
	p.color_ramp = fade
	return p


## A soft round puff (a radial fade, made in code): the smoke's texture.
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


## Shows `text` on the face screen's caption band ("" clears it); `caption` fades it in and out.
func show_slogan(text: String) -> void:
	slogan = text


## The caption's label (tests and reviews read it).
func caption_label() -> Label3D:
	return _caption_label


func _animate(delta: float) -> void:
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
	# The jaw drops open (sliding down below the mouth, its chin tipping toward the runner), and the
	# mouth's inside lights up.
	var open: float = smoothstep(0.0, 1.0, clampf(jaw_open, 0.0, 1.0))
	var jaw_height: float = shape.mouth_top - shape.mouth_bottom + 0.16
	_jaw.position = shape.jaw_hinge + Vector3(0.0, -(jaw_height + 0.3) * open, 0.3 * open)
	_jaw.rotation.x = -deg_to_rad(14.0) * open
	_mouth_glow.visible = open > 0.01
	_mouth_material.albedo_color = Color(FACE_WHITE.r * open, FACE_WHITE.g * open, FACE_WHITE.b * open)
	_mouth_material.emission_energy_multiplier = 2.2 * open
	# The lift pads' glow on the street below, brighter the lower it flies (none once it's down).
	var height: float = global_position.y
	_floor_glow.visible = height > 0.5 and power > 0.02
	_floor_glow.position = Vector3(0.0, 0.04 - height, -shape.length * 0.5)
	_floor_glow_material.set_shader_parameter(&"state_glow", clampf((16.0 - height) / 12.0, 0.0, 1.0) * power)
	_update_weak_points()
	_update_power()
	_update_caption()
	if _wrecked:
		_update_fallen_face(delta)


## The wreck's torn-off face tips forward off its stern and falls flat into the street before it.
func _update_fallen_face(delta: float) -> void:
	_face_fall = minf(_face_fall + delta / FACE_FALL_SECONDS, 1.0)
	var k: float = _face_fall * _face_fall
	var turn: Quaternion = _face_from.basis.get_rotation_quaternion().slerp(_face_rest.basis.get_rotation_quaternion(), k)
	var at: Vector3 = _face_from.origin.lerp(_face_rest.origin, k)
	_screen.global_transform = Transform3D(Basis(turn), at)


## Its lights follow `power`: every kit material on its parts (not the face screen, which has its own
## power, nor the red domes) gets a copy of its own the first time the power drops, whose glow scales
## with it; a smooth fade, never a flicker.
func _update_power() -> void:
	var level: float = clampf(power, 0.0, 1.0)
	if is_equal_approx(level, _power_shown):
		return
	if _power_materials.is_empty():
		for node: Node in _ship.find_children("*", "MeshInstance3D", true, false):
			var m := node as MeshInstance3D
			if m == _screen or _domes.has(m) or m == _mouth_glow or m.mesh == null or m.material_override != null:
				continue
			for i: int in m.mesh.get_surface_count():
				var mat := m.mesh.surface_get_material(i) as ShaderMaterial
				if mat == null:
					continue
				var copy := mat.duplicate() as ShaderMaterial
				m.set_surface_override_material(i, copy)
				_power_materials.append(copy)
	for mat: ShaderMaterial in _power_materials:
		mat.set_shader_parameter(&"state_glow", level)
	_power_shown = level


## The slogan on the caption band: the band (drawn by the face shader) and its text fade in and out
## with `caption`, and only show on a lit face. The text is sized to fit the band (its widest line
## within CAPTION_WIDTH of the screen, each line within CAPTION_LINE of its height). While the face
## glitches, the text jumps sideways with the tearing rows (it holds still with Reduced flashing).
func _update_caption() -> void:
	var shown: float = clampf(caption, 0.0, 1.0) * smoothstep(0.75, 1.0, screen_power)
	if slogan == "":
		shown = 0.0
	_screen_material.set_shader_parameter(&"caption", shown)
	_caption_label.visible = shown > 0.01
	if not _caption_label.visible:
		return
	if slogan != _caption_text:
		_caption_text = slogan
		_caption_label.text = slogan
		_fit_caption()
	var c: Color = FACE_WHITE * CAPTION_GLOW
	c.a = shown
	_caption_label.modulate = c
	var jump: float = 0.0
	if glitch > 0.05 and not Settings.flashing_reduced:
		var tick: float = floorf(_time * 12.0)
		jump = (fposmod(sin(tick * 12.9898 + 4.1) * 43758.5453, 1.0) - 0.5) * glitch * 0.22 * shape.screen_size.x
	_caption_label.position.x = jump


## The caption's size: its glyphs at CAPTION_FONT_SIZE, scaled (pixel_size) so the widest line fits
## CAPTION_WIDTH of the screen and a line's height CAPTION_LINE of it. It measures the text as shown
## (translated, if the game has translations: Label3D translates its text like the UI's labels).
func _fit_caption() -> void:
	var font: Font = _caption_label.font
	var shown: String = _caption_label.atr(slogan)
	var widest: float = 1.0
	for line: String in shown.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_FONT_SIZE).x)
	var by_width: float = shape.screen_size.x * CAPTION_WIDTH / widest
	var by_height: float = shape.screen_size.y * CAPTION_LINE / float(CAPTION_FONT_SIZE)
	_caption_label.pixel_size = minf(by_width, by_height)


## The caption's text: a Label3D in front of the screen's lower part, centred in the band, in the
## face's cold white; drawn after the screen, facing the runner like the face.
func _build_caption() -> void:
	_caption_label = Label3D.new()
	_caption_label.name = "Caption"
	var variation := FontVariation.new()
	variation.base_font = load(CAPTION_FONT) as Font
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): CAPTION_WEIGHT}
	variation.spacing_glyph = 2
	_caption_label.font = variation
	_caption_label.font_size = CAPTION_FONT_SIZE
	_caption_label.outline_size = 0
	_caption_label.shaded = false
	_caption_label.double_sided = false
	_caption_label.fixed_size = false
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption_label.line_spacing = -8.0
	_caption_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	_caption_label.render_priority = 1
	_caption_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_caption_label.position = Vector3(0.0, (-0.5 + CAPTION_TOP) * 0.5 * shape.screen_size.y, 0.06)
	_caption_label.visible = false
	_screen.add_child(_caption_label)


## The weak points' covers swing back about their back edges and the red domes rise out of their
## sockets as a stomp window opens (weak_open), pulsing while they're out (steady with Reduced
## flashing: nothing flickers).
func _update_weak_points() -> void:
	var k: float = smoothstep(0.0, 1.0, clampf(weak_open, 0.0, 1.0))
	var swing := Basis(Vector3(1.0, 0.0, 0.0), -deg_to_rad(COVER_OPEN_DEGREES) * k)
	for i: int in _covers.size():
		var p: Vector3 = shape.weak_points[i]
		var hinge: Vector3 = p + Vector3(0.0, 0.0, -0.85)
		_covers[i].transform = Transform3D(swing, hinge + swing * (p - hinge))
		_domes[i].visible = k > 0.02
		_domes[i].position = p + Vector3(0.0, -DOME_SUNK * (1.0 - k), 0.0)
	var pulse: float = 0.5 if Settings.flashing_reduced else 0.5 + 0.5 * sin(TAU * PULSE_HZ * _time)
	_dome_material.set_shader_parameter(&"state_glow", lerpf(PULSE_LOW, PULSE_HIGH, pulse) * k)


## The crown's deck: a concave shape over the hull's skin (FloatingHeadModel.deck_faces), off until a
## stomp window opens.
func _build_deck() -> StaticBody3D:
	var deck := StaticBody3D.new()
	deck.name = "Deck"
	deck.collision_layer = 0
	deck.collision_mask = 0
	var faces := ConcavePolygonShape3D.new()
	faces.set_faces(FloatingHeadModel.deck_faces(shape))
	faces.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = faces
	deck.add_child(cs)
	_ship.add_child(deck)
	return deck


func _update_lens() -> void:
	if power < 0.5:
		_lens.material_override = GreyboxMaterials.flat(Color(0.08, 0.08, 0.1))
		return
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
