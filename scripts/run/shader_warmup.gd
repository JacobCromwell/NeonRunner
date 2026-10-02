class_name ShaderWarmup
extends Node3D
## Draws, while a level loads, one tiny copy of each look the level may show for the first time later
## (task PERF1). A renderer prepares a shader the first time it draws it: the Compatibility renderer
## (the web demo, low-end phones) compiles it then, Forward+ and Mobile build its pipelines. Mid-run that
## was a long frame each time something new came: a kind of enemy, the weapon's first shot, the first
## sparks, a fence's warning flicker, the finish line.
##
## What it draws, each once (by shader and mesh kind):
## - every material on the run's hidden nodes: what waits in pools (shots, the weapon's effects) and
##   the runner's protections and power-ups not shown yet;
## - the shared effects' glow (sparks and debris, lines and warnings, opaque and see-through);
## - one look of every enemy kind the level brings (EnemyDirector.warm_looks), every part of it shown
##   (a muzzle's charge, a lunge line);
## - one of each track piece the zone skin dresses: fences full and gapped in each of their states,
##   wall fences, a sign, a pad, a ramp, a speed pad, full and narrow ceilings, every doodad size, gap
##   edges and the finish line.
## They sit in front of the camera, far too small to see (SCALE), for DRAWN_FRAMES drawn frames, then go.
## Visual only: nothing in it collides, plays or moves the run on. A headless run draws nothing, so
## LevelRun only adds it when the game renders (needed()).

## Frames the samples stay drawn: the first compiles, the second catches what a renderer defers by one.
const DRAWN_FRAMES: int = 2
## How small the samples are drawn: the widest, a ceiling across the street, is a hundredth of a pixel.
const SCALE: float = 0.00001
## How far in front of the camera they sit.
const AHEAD: float = 2.0

## Samples made so far, by what they draw (shader key, mesh kind, instancing).
var keys: Dictionary = {}
var _frames_left: int = DRAWN_FRAMES


## True when the game renders (not a headless run): only then is there anything to compile.
static func needed() -> bool:
	return DisplayServer.get_name() != "headless"


## Builds the samples for `world`'s level in front of `camera` (it becomes the camera's child).
func setup(world: RunWorld, camera: Camera3D) -> void:
	name = "ShaderWarmup"
	camera.add_child(self)
	position = Vector3(0.0, 0.0, -AHEAD)
	scale = Vector3.ONE * SCALE
	_sample_hidden(world)
	_sample_effects()
	for look: Node in world.director.warm_looks():
		add_child(look)
	_sample_track(world)
	_show_all()
	RenderingServer.frame_post_draw.connect(_on_drawn)


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_drawn):
		RenderingServer.frame_post_draw.disconnect(_on_drawn)


func _on_drawn() -> void:
	_frames_left -= 1
	if _frames_left <= 0:
		RenderingServer.frame_post_draw.disconnect(_on_drawn)
		queue_free()


## Samples the materials of every hidden mesh, multimesh and particle node in the run.
func _sample_hidden(world: RunWorld) -> void:
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var geometry := node as GeometryInstance3D
		if geometry != null and not geometry.is_visible_in_tree():
			_sample_geometry(geometry)


## Adds a sample of what `geometry` draws (its mesh with each of its materials), unless one is there.
func _sample_geometry(geometry: GeometryInstance3D) -> void:
	var particles := geometry as CPUParticles3D
	var multimesh_node := geometry as MultiMeshInstance3D
	var mesh_node := geometry as MeshInstance3D
	var mesh: Mesh = null
	var kind: String = "mesh"
	if particles != null:
		mesh = particles.mesh
		kind = "particles"
	elif multimesh_node != null and multimesh_node.multimesh != null:
		mesh = multimesh_node.multimesh.mesh
		kind = "multimesh%d%d" % [int(multimesh_node.multimesh.use_colors), int(multimesh_node.multimesh.use_custom_data)]
	elif mesh_node != null:
		mesh = mesh_node.mesh
	if mesh == null:
		return
	var materials: Array[Material] = []
	if geometry.material_override != null:
		materials.append(geometry.material_override)
	else:
		for s: int in mesh.get_surface_count():
			var m: Material = mesh_node.get_surface_override_material(s) if mesh_node != null else null
			if m == null:
				m = mesh.surface_get_material(s)
			if m != null:
				materials.append(m)
	for m: Material in materials:
		var key: String = "%s|%s|%s" % [kind, mesh.get_class(), shader_key(m)]
		if keys.has(key):
			continue
		keys[key] = true
		if particles != null:
			_add_multimesh(mesh, m, true, true)
		elif multimesh_node != null:
			_add_multimesh(mesh, m, multimesh_node.multimesh.use_colors, multimesh_node.multimesh.use_custom_data)
		else:
			var inst := MeshInstance3D.new()
			inst.mesh = mesh
			inst.material_override = m
			add_child(inst)


## The shared effects' glow (RunEffects' sparks and debris, as particles; lines and floor warnings, as
## boxes), opaque and see-through: their materials are only set when one plays.
func _sample_effects() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	sphere.radial_segments = 6
	sphere.rings = 3
	for alpha: float in [1.0, 0.75]:
		var glow: StandardMaterial3D = GreyboxMaterials.glow(Color.WHITE, 3.0, alpha)
		_add_multimesh(sphere, glow, true, true)
		var box := MeshInstance3D.new()
		box.mesh = GreyboxMaterials.unit_box()
		box.material_override = glow
		add_child(box)


## A one-instance multimesh of `mesh` in `material` (a particle system draws as one).
func _add_multimesh(mesh: Mesh, material: Material, colors: bool, custom: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = material
	add_child(inst)


## Shows every part of every sample (an enemy's muzzle glow or charge, only an attack shows), kept in
## the stage's tiny space (no top-level part), lights off (they'd light the street for a frame), and
## particle systems sampled as particles (a stopped one draws nothing).
func _show_all() -> void:
	var stack: Array[Node] = get_children()
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var node3d := node as Node3D
		if node3d == null:
			continue
		if node3d.top_level:
			# Turned off in the tree, a top-level node keeps its place in the world (and its size): put it
			# back in the stage's tiny space.
			node3d.top_level = false
			node3d.transform = Transform3D.IDENTITY
		node3d.visible = not node is Light3D
		if node is CPUParticles3D:
			_sample_geometry(node as CPUParticles3D)


## One of each track piece the zone skin dresses, at the track's start, on parents that collide with
## nothing (TrackBuilder sizes them the same way).
func _sample_track(world: RunWorld) -> void:
	var skin: ZoneSkin = world.skin
	if skin == null:
		return
	var t: MovementTuning = world.tuning
	var geo: TrackGeometry = world.geo
	for gapped: bool in [false, true]:
		var bottom: float = t.fence_gapped_bottom if gapped else 0.0
		var top: float = t.fence_gapped_top if gapped else t.fence_full_top
		var size := Vector3(geo.lane_width - 0.2, top - bottom, t.fence_depth)
		for state: Hazard.State in [Hazard.State.ON, Hazard.State.WARNING, Hazard.State.OFF]:
			var hazard := _hazard_look(Vector3(0.0, (bottom + top) * 0.5, 0.0), size)
			skin.fence(hazard, size, -(bottom + top) * 0.5, gapped)
			_show_state(hazard, state)
	for band: String in WallFencePlan.BANDS:
		var box: AABB = WallFencePlan.hitbox({"side": 1, "band": band, "at": 0.0}, t, geo)
		for state: Hazard.State in [Hazard.State.ON, Hazard.State.WARNING]:
			var wall_hazard := _hazard_look(box.get_center(), box.size)
			skin.wall_fence(wall_hazard, box.size, 1, StringName(band), -box.get_center().y)
			_show_state(wall_hazard, state)
	var sign_size := Vector3(t.sign_depth, 2.0, 4.0)
	skin.wall_sign(_hazard_look(Vector3.ZERO, sign_size), sign_size)
	var pad_size := Vector3(geo.lane_width * 0.7, 0.5, t.pad_length)
	skin.pad(_area_look(), pad_size)
	skin.ramp(_area_look(), Vector3(geo.lane_width * 0.8, 1.0, t.ramp_length), 1)
	skin.speed_pad(_area_look(), Vector3(geo.lane_width * 0.7, 0.5, t.speed_pad_length))
	for lanes: Vector2i in [Vector2i(0, geo.lane_count - 1), Vector2i(0, 0)]:
		var root := Node3D.new()
		add_child(root)
		skin.ceiling_section(root, CeilingSection.make(geo, t.ceiling_height, TrackBuilder.HULL_THICKNESS, 0.0, 20.0, lanes))
	for size_class: StringName in LevelLayout.DOODAD_SIZES:
		var box_size: Vector3 = t.doodad_size(size_class)
		var body := Node3D.new()
		add_child(body)
		skin.doodad(body, Vector3(box_size.x, box_size.y, 4.0), size_class, 1, 0)
	var floor_root := Node3D.new()
	add_child(floor_root)
	var span: Vector2 = geo.lane_floor_span(0)
	skin.floor_segment(floor_root, Vector3((span.x + span.y) * 0.5, -TrackBuilder.FLOOR_THICKNESS * 0.5, -5.0),
		Vector3(span.y - span.x, TrackBuilder.FLOOR_THICKNESS, 10.0), geo.lane_x(0), true, true)
	var finish := Node3D.new()
	add_child(finish)
	skin.finish_line(finish, geo.half_width() * 2.0, 0.0)


## A hazard to dress that collides with nothing.
func _hazard_look(at: Vector3, size: Vector3) -> Hazard:
	var hazard := Hazard.new()
	hazard.size = size
	hazard.collision_layer = 0
	hazard.collision_mask = 0
	hazard.monitoring = false
	hazard.monitorable = false
	hazard.position = at
	add_child(hazard)
	return hazard


## A trigger's place to dress that collides with nothing.
func _area_look() -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	add_child(area)
	return area


## Shows a hazard's look in `state` (its warning flicker, off), as its HazardStateVisual follows it.
static func _show_state(hazard: Hazard, state: Hazard.State) -> void:
	if state != hazard.state:
		hazard.state = state
		hazard.state_changed.emit(state)


## What makes a material's shader: a shader material's own shader, or a standard material's features
## (the ones that change the shader Godot generates for it).
static func shader_key(m: Material) -> String:
	var parts: PackedStringArray = []
	var current: Material = m
	while current != null:
		var sm := current as ShaderMaterial
		var b := current as BaseMaterial3D
		if sm != null:
			parts.append("shader%d" % (sm.shader.get_instance_id() if sm.shader != null else 0))
		elif b != null:
			var flags: PackedStringArray = []
			for f: int in BaseMaterial3D.FLAG_MAX:
				flags.append("1" if b.get_flag(f) else "0")
			for f: int in BaseMaterial3D.FEATURE_MAX:
				flags.append("1" if b.get_feature(f) else "0")
			for p: int in BaseMaterial3D.TEXTURE_MAX:
				flags.append("1" if b.get_texture(p) != null else "0")
			parts.append("std%d.%d.%d.%d.%d.%d.%d.%d.%s" % [b.transparency, b.shading_mode, b.blend_mode, b.cull_mode,
				b.depth_draw_mode, b.diffuse_mode, b.specular_mode, b.billboard_mode, "".join(flags)])
		else:
			parts.append(current.get_class())
		current = current.next_pass
	return "+".join(parts)
